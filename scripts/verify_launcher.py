#!/usr/bin/env python3
"""Exercise the combined download and menu without live account credentials."""
import hashlib
import os
from pathlib import Path
import platform
import subprocess
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()
OS = {'Linux': 'linux', 'Darwin': 'macos', 'Windows': 'windows'}[platform.system()]


def run(command, cwd, code=0, env=None):
    if OS == 'windows':
        command = 'cmd.exe /d /s /c "' + subprocess.list2cmdline(command) + '"'
    result = subprocess.run(command, cwd=cwd, env=env, input='', capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=60)
    assert result.returncode == code, (command, result.returncode, result.stdout, result.stderr)
    return result.stdout + result.stderr


architecture = {'amd64': 'x64', 'x86_64': 'x64', 'aarch64': 'arm64'}.get(platform.machine().lower(), platform.machine().lower())
name = f'chorusdraft-v{VERSION}-{OS}-{architecture}'
archive = ROOT / 'dist' / (name + ('.zip' if OS == 'windows' else '.tar.gz'))
digest, filename = Path(str(archive) + '.sha256').read_text().split()
assert filename == archive.name
assert hashlib.sha256(archive.read_bytes()).hexdigest() == digest
with tempfile.TemporaryDirectory(prefix='ChorusDraft combined test ') as temporary:
    work = Path(temporary)
    if OS == 'windows':
        with zipfile.ZipFile(archive) as packed:
            packed.extractall(work)
    else:
        with tarfile.open(archive) as packed:
            packed.extractall(work, filter='data')
    root = work / name
    for line in (root / 'MANIFEST.sha256').read_text().splitlines():
        digest, path = line.split('  ', 1)
        assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
    gui = root / ('ChorusDraft.app/Contents/MacOS/ChorusDraft' if OS == 'macos' else
                  'launcher/ChorusDraft.exe' if OS == 'windows' else 'launcher/ChorusDraft')
    assert gui.is_file(), 'Desktop executable is missing'
    run([str(gui), '--smoke-test'], work)
    command = [str(root / ('bot.bat' if OS == 'windows' else 'bot'))]
    assert 'desktop launcher' in run(command + ['help'], work)
    assert 'interactive terminal' in run(command + ['menu'], work, code=1)
    run(command + ['invalid'], work, code=1)
    for runtime in ('ruby', 'elixir'):
        for bot in ('bluesky', 'mastodon'):
            base = root / bot if runtime == 'ruby' else root / 'elixir' / bot
            assert VERSION in run(command + [runtime, bot, 'version'], work)
            assert 'review' in run(command + [runtime, bot, 'help'], work)
            run(command + [runtime, bot, 'setup'], work)
            env = base / '.env'
            env.write_text('# preserve this configuration\n')
            run(command + [runtime, bot, 'setup'], work)
            assert env.read_text() == '# preserve this configuration\n'
            assert not (base / 'data').exists()
            assert 'requires' in run(command + [runtime, bot, 'post'], work, code=1)
            assert '--publish requires' in run(command + [runtime, bot, 'draft', '--publish'], work, code=1)
    assert VERSION in run(command + ['bluesky', 'version'], work)
    # Verify shell metacharacters survive the Windows batch/PowerShell/Ruby chain.
    probe = work / 'argument_probe.rb'
    probe.write_text("require 'json'; File.write(ENV.fetch('ARGUMENT_REPORT'), JSON.generate(ARGV)); exit 0\n")
    report = work / 'arguments.json'
    environment = os.environ.copy()
    environment['RUBYOPT'] = '-rargument_probe'
    environment['RUBYLIB'] = str(work)
    environment['ARGUMENT_REPORT'] = str(report)
    text = 'spaces & pipes | dollars $HOME; (parentheses) café'
    run(command + ['ruby', 'bluesky', 'post', text], work, env=environment)
    import json
    assert json.loads(report.read_text(encoding='utf-8')) == ['post', text]
    if OS != 'windows':
        # A pseudo-terminal exercises the actual menu, back navigation and actions.
        import pty
        import select
        import time
        master, slave = pty.openpty()
        process = subprocess.Popen(command + ['menu'], cwd=work, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)
        output = b''
        deadline = time.monotonic() + 60
        steps = [(b'Implementation: ', b'1\n'), (b'Platform: ', b'1\n'),
                 (b'Action: ', b'10\n'), (b'Action: ', b'b\n'),
                 (b'Implementation: ', b'2\n'), (b'Platform: ', b'2\n'),
                 (b'Action: ', b'10\n'), (b'Action: ', b'q\n')]
        pending = b''
        try:
            while process.poll() is None and time.monotonic() < deadline:
                if select.select([master], [], [], 0.2)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError:
                        break
                    output += chunk
                    pending += chunk
                    if steps and steps[0][0] in pending:
                        _, answer = steps.pop(0)
                        os.write(master, answer)
                        pending = b''
            process.wait(timeout=5)
            assert not steps and process.returncode == 0, output.decode(errors='replace')
            assert output.count(VERSION.encode()) == 2, output.decode(errors='replace')
        finally:
            if process.poll() is None:
                process.kill()
            os.close(master)
print('Combined archive, four bot choices, setup isolation, argument forwarding, and launcher checks passed.')
