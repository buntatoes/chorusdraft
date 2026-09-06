#!/usr/bin/env python3
"""Check built archives on the current native OS; no real API calls or credentials."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()
PLATFORM = {'Linux': 'linux', 'Darwin': 'macos', 'Windows': 'windows'}[platform.system()]
RUBY = shutil.which('ruby')
assert RUBY, 'Ruby must be on PATH'


def run(command, cwd, *, env=None, code=0):
    invocation = command
    if PLATFORM == 'windows' and command[0] == 'cmd.exe':
        # cmd /c otherwise strips the first/last quotes when both the executable
        # path and an argument contain spaces. /s plus an outer pair preserves them.
        invocation = 'cmd.exe /d /s /c "' + subprocess.list2cmdline(command[3:]) + '"'
    result = subprocess.run(invocation, cwd=cwd, env=env, capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=90)
    assert result.returncode == code, (command, result.returncode, result.stdout, result.stderr)
    return result.stdout, result.stderr


# Check all six artifacts, then execute only packages for the native platform.
checksums = {}
for line in (ROOT / 'dist' / 'SHA256SUMS').read_text().splitlines():
    digest, name = line.split()
    assert Path(name).name == name and name not in checksums
    checksums[name] = digest
expected = {f'chorusdraft-{bot}-v{VERSION}-{osname}{suffix}'
            for bot in ('bluesky', 'mastodon')
            for osname, suffix in (('linux', '.tar.gz'), ('macos', '.tar.gz'), ('windows', '.zip'))}
assert set(checksums) == expected, 'Expected exactly six release archives'
for name, digest in checksums.items():
    assert hashlib.sha256((ROOT / 'dist' / name).read_bytes()).hexdigest() == digest, name

for bot in ('bluesky', 'mastodon'):
    package_name = f'chorusdraft-{bot}-v{VERSION}-{PLATFORM}'
    suffix = '.zip' if PLATFORM == 'windows' else '.tar.gz'
    archive = ROOT / 'dist' / (package_name + suffix)
    # Spaces expose path quoting bugs in both shell and batch launchers.
    with tempfile.TemporaryDirectory(prefix='ChorusDraft release test ') as temporary:
        work = Path(temporary)
        if PLATFORM == 'windows':
            with zipfile.ZipFile(archive) as packed:
                names = packed.namelist()
                assert all(n.startswith(package_name + '/') and '..' not in Path(n).parts for n in names)
                packed.extractall(work)
        else:
            with tarfile.open(archive) as packed:
                assert all(m.isfile() and m.name.startswith(package_name + '/')
                           and '..' not in Path(m.name).parts for m in packed.getmembers())
                packed.extractall(work, filter='data')
        package = work / package_name
        assert (package / 'VERSION').read_text().strip() == VERSION
        assert not any(p.name in ('.env', 'data', 'logs', 'elixir') for p in package.rglob('*'))
        launchers = ('bot.bat', 'run.bat') if PLATFORM == 'windows' else ('bot', 'run.sh')
        for launcher in launchers:
            if PLATFORM == 'windows':
                # Exercise cmd.exe, which is also how PowerShell executes .bat files.
                command = ['cmd.exe', '/d', '/c', str(package / launcher)]
            else:
                assert os.access(package / launcher, os.X_OK), launcher
                command = [str(package / launcher)]
            assert run(command + ['version'], work)[0].strip() == VERSION
            assert run(command + ['--version'], work)[0].strip() == VERSION
            assert 'review' in run(command + ['help'], work)[0]
            assert 'review' in run(command, work)[0]
            assert 'Unknown command' in run(command + ['does-not-exist'], work, code=1)[1]
            assert 'requires' in run(command + ['post'], work, code=1)[1]

        command = (['cmd.exe', '/d', '/c', str(package / 'bot.bat')]
                   if PLATFORM == 'windows' else [str(package / 'bot')])
        assert 'Created .env' in run(command + ['setup'], work)[0]
        env_file = package / '.env'
        env_file.write_text('AI_PROVIDER=local\n# Keep this configuration\n', encoding='utf-8')
        before = env_file.read_bytes()
        assert 'Preserved existing .env' in run(command + ['setup'], work)[0]
        assert env_file.read_bytes() == before
        assert not (package / 'data').exists()
        if PLATFORM != 'windows':
            assert env_file.stat().st_mode & 0o777 == 0o600
        # The test-only preload replaces network clients. Run the real launchers,
        # CLI and on-disk queue, verifying forwarded text survives shell parsing.
        bootstrap = work / 'fake_clients.rb'
        bootstrap.write_text('''require File.join(ENV.fetch('CHORUSDRAFT_TEST_PACKAGE'), 'lib/chorus_draft/cli')
class ReleaseClient
  def login = nil
  def identity = 'release-test'
  def account_key = 'https://example.org:release-test'
  def actor_aliases(actor) = [actor]
  def mentioned_actors(_text) = []
  def limit = 500
  def recent(limit:) = []
  def publish(*) = raise('Unexpected publication during release checks')
end
class ReleaseAI
  def generate(*) = 'My compiler has requested a vacation.'
end
ChorusDraft::Bluesky.define_singleton_method(:new) { ReleaseClient.new }
ChorusDraft::Mastodon.define_singleton_method(:new) { ReleaseClient.new }
ChorusDraft::AI.define_singleton_method(:new) { ReleaseAI.new }
''', encoding='utf-8')
        env = os.environ.copy()
        env['CHORUSDRAFT_TEST_PACKAGE'] = str(package)
        # RUBYLIB handles paths with spaces without Ruby option tokenization.
        env['RUBYLIB'] = str(work)
        env['RUBYOPT'] = '-rfake_clients'
        text = 'A release test with spaces & punctuation!'
        assert 'Staged manual draft' in run(command + ['post', text], work, env=env)[0]
        assert 'Staged draft' in run(command + ['draft'], work, env=env)[0]
        assert 'interactive terminal' in run(command + ['review'], work, env=env, code=1)[1]
        state_file, = (package / 'data').glob('*/state.json')
        state = json.loads(state_file.read_text(encoding='utf-8'))
        drafts = state['drafts']
        assert [d['text'] for d in drafts] == [text, 'My compiler has requested a vacation.']
        assert all(d['status'] == 'pending' for d in drafts)
        for test in ('safety_test.rb', 'cli_test.rb'):
            output, _ = run([RUBY, str(package / 'test' / test)], work)
            print(output, end='')
        print(f'PASS {package_name}: checksums, native launchers, setup, argument forwarding, queue and tests')
print(f'All {PLATFORM} release checks passed on {platform.machine()}')
