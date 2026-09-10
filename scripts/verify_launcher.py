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
with tempfile.TemporaryDirectory(prefix='chorusdraft-combined-') as temporary:
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
    install_home = work / 'install-home'
    install_home.mkdir()
    install_env = os.environ.copy()
    if OS == 'windows':
        install_dest = install_home / f'ChorusDraft-{VERSION}'
        install_env['LOCALAPPDATA'] = str(install_home)
        install_env['APPDATA'] = str(install_home / 'Roaming')
        install_env['USERPROFILE'] = str(install_home)
        install_cmd = [
            'pwsh', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(root / 'install.ps1'),
            '-Destination', str(install_dest),
        ]
    else:
        install_dest = install_home / f'chorusdraft-{VERSION}'
        install_env['HOME'] = str(install_home)
        install_cmd = [str(root / 'install.sh'), str(install_dest)]
    install_result = subprocess.run(
        install_cmd, cwd=root, env=install_env, capture_output=True,
        text=True, encoding='utf-8', errors='replace', timeout=120,
    )
    assert install_result.returncode == 0, (install_cmd, install_result.stdout, install_result.stderr)
    install_output = install_result.stdout + install_result.stderr
    assert 'Installed ChorusDraft in ' in install_output, install_output
    installed_root = install_dest
    assert installed_root.is_dir(), install_output
    assert (installed_root / 'elixir' / 'run.sh' if OS != 'windows' else installed_root / 'elixir' / 'run.ps1').is_file()
    # A no-argument install must land in the per-user default location.
    default_home = work / 'default-home'
    default_home.mkdir()
    default_env = os.environ.copy()
    default_env.pop('XDG_DATA_HOME', None)
    if OS == 'windows':
        default_env['LOCALAPPDATA'] = str(default_home)
        default_env['APPDATA'] = str(default_home / 'Roaming')
        default_env['USERPROFILE'] = str(default_home)
        default_cmd = [
            'pwsh', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(root / 'install.ps1'),
        ]
        default_dest = default_home / f'ChorusDraft-{VERSION}'
    else:
        default_env['HOME'] = str(default_home)
        default_cmd = [str(root / 'install.sh')]
        default_dest = (default_home / 'Library' / 'Application Support' if OS == 'macos'
                        else default_home / '.local' / 'share') / f'chorusdraft-{VERSION}'
    default_result = subprocess.run(
        default_cmd, cwd=root, env=default_env, capture_output=True,
        text=True, encoding='utf-8', errors='replace', timeout=120,
    )
    assert default_result.returncode == 0, (default_cmd, default_result.stdout, default_result.stderr)
    default_output = default_result.stdout + default_result.stderr
    assert 'Installed ChorusDraft in ' in default_output, default_output
    assert default_dest.is_dir(), default_output
    assert (default_dest / 'elixir' / ('run.ps1' if OS == 'windows' else 'run.sh')).is_file()
    if OS == 'linux':
        desktop = install_home / '.local/share/applications/chorusdraft.desktop'
        assert desktop.is_file(), 'Application menu entry is missing'
        assert str(installed_root / 'launcher/ChorusDraft') in desktop.read_text()
    elif OS == 'macos':
        apps_link = install_home / 'Applications/ChorusDraft.app'
        assert apps_link.exists(), 'Applications shortcut is missing'
    else:
        programs = Path(install_env['APPDATA']) / 'Microsoft' / 'Windows' / 'Start Menu' / 'Programs'
        shortcut = programs / 'ChorusDraft.lnk'
        command = programs / 'ChorusDraft.cmd'
        assert shortcut.is_file() or command.is_file(), 'Start menu shortcut is missing'
    gui = root / ('ChorusDraft.app/Contents/MacOS/ChorusDraft' if OS == 'macos' else
                  'launcher/ChorusDraft.exe' if OS == 'windows' else 'launcher/ChorusDraft')
    installed_gui = installed_root / ('ChorusDraft.app/Contents/MacOS/ChorusDraft' if OS == 'macos' else
                                      'launcher/ChorusDraft.exe' if OS == 'windows' else 'launcher/ChorusDraft')
    assert gui.is_file(), 'Desktop executable is missing'
    assert installed_gui.is_file(), 'Installed desktop executable is missing'
    assert not list(root.rglob('*.rb')), 'Desktop package contains obsolete Ruby source'
    configure_sandbox = OS == 'linux' and os.environ.get('CHORUSDRAFT_TEST_SANDBOX') == '1'
    sandbox = ["sudo", __import__('sys').executable, str(root / 'launcher-source/linux_sandbox.py')]
    installed_sandbox = ["sudo", __import__('sys').executable, str(installed_root / 'launcher-source/linux_sandbox.py')]
    try:
        if configure_sandbox:
            subprocess.run(sandbox, check=True)
            subprocess.run(installed_sandbox, check=True)
        run([str(gui), '--smoke-test'], work)
        run([str(installed_gui), '--smoke-test'], work)
    finally:
        if configure_sandbox:
            subprocess.run(sandbox + ['--remove'], check=True)
            subprocess.run(installed_sandbox + ['--remove'], check=True)
    command = [str(root / ('bot.bat' if OS == 'windows' else 'bot'))]
    assert 'desktop launcher' in run(command + ['help'], work)
    assert 'interactive terminal' in run(command + ['menu'], work, code=1)
    run(command + ['invalid'], work, code=1)
    for runtime in ('elixir',):
        for bot in ('bluesky', 'mastodon'):
            base = root / 'elixir' / bot
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
        steps = [(b'Platform: ', b'1\n'),
                 (b'Action: ', b'10\n'), (b'Action: ', b'b\n'),
                 (b'Platform: ', b'2\n'),
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
print('Combined archive, both platforms, setup isolation, argument forwarding, and launcher checks passed.')
