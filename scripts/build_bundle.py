#!/usr/bin/env python3
"""Package the Elixir bot with the desktop launcher."""
import gzip
import hashlib
from pathlib import Path
import platform
import shutil
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()
OS = {'Linux': 'linux', 'Darwin': 'macos', 'Windows': 'windows'}[platform.system()]
DIST = ROOT / 'dist'


def unpack(archive, destination):
    if archive.suffix == '.zip':
        with zipfile.ZipFile(archive) as packed:
            if not all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in packed.namelist()):
                raise SystemExit(f'{archive.name} contains unsafe paths')
            packed.extractall(destination)
    else:
        with tarfile.open(archive) as packed:
            packed.extractall(destination, filter='data')


def checked(archive, digest):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
        raise SystemExit(f'{archive.name} does not match its recorded SHA-256')
    return archive


suffix = '.zip' if OS == 'windows' else '.tar.gz'
elixir_name = f'ChorusDraft-elixir-{VERSION}-{OS}'
elixir_archive = ROOT / 'elixir' / 'dist' / (elixir_name + suffix)
elixir_digest, recorded_name = Path(str(elixir_archive) + '.sha256').read_text().split()
if recorded_name != elixir_archive.name:
    raise SystemExit(f'{elixir_archive.name}.sha256 names a different file')
checked(elixir_archive, elixir_digest)

with tempfile.TemporaryDirectory(prefix='chorusdraft-bundle-') as temporary:
    work = Path(temporary)
    architecture = {'amd64': 'x64', 'x86_64': 'x64', 'aarch64': 'arm64'}.get(platform.machine().lower(), platform.machine().lower())
    name = f'chorusdraft-v{VERSION}-{OS}-{architecture}'
    package = work / name
    package.mkdir()
    unpack(elixir_archive, work)
    shutil.move(str(work / elixir_name), package / 'elixir')
    source = package / 'elixir' / 'source'
    if source.exists():
        shutil.rmtree(source)
    for doc in ('README.md', 'RELEASE_NOTES.md', 'CHANGELOG.md', 'SECURITY.md', 'LICENSE', 'NOTICE', 'VERSION'):
        shutil.copy2(ROOT / doc, package / doc)
    (package / 'docs').mkdir()
    shutil.copy2(ROOT / 'docs' / 'DESKTOP.md', package / 'docs' / 'DESKTOP.md')
    launchers = ('bot.bat', 'bot.ps1') if OS == 'windows' else ('bot', 'bot.command')
    for launcher in launchers:
        shutil.copy2(ROOT / launcher, package / launcher)
    shutil.copy2(ROOT / 'assets' / 'chorusdraft-mark.svg', package / 'chorusdraft.svg')
    if OS == 'windows':
        shutil.copy2(ROOT / 'scripts' / 'install_desktop.ps1', package / 'install.ps1')
        shutil.copy2(ROOT / 'scripts' / 'install_desktop.cmd', package / 'install.cmd')
        shutil.copy2(ROOT / 'elixir' / 'scripts' / 'verify.ps1', package / 'verify.ps1')
    else:
        shutil.copy2(ROOT / 'scripts' / 'install_desktop.sh', package / 'install.sh')
        (package / 'install.sh').chmod(0o755)
        if OS == 'macos':
            command = package / 'Install ChorusDraft.command'
            shutil.copy2(ROOT / 'scripts' / 'install_desktop.command', command)
            command.chmod(0o755)
    # Native desktop runtime. Keep only the Linux sandbox helper and launcher
    # notices; rebuild the GUI from the git tree, not from this archive.
    gui = DIST / 'gui' / ('ChorusDraft.app' if OS == 'macos' else 'ChorusDraft')
    if not gui.exists():
        raise SystemExit('Build the desktop launcher with scripts/build_gui.py first')
    shutil.copytree(gui, package / ('ChorusDraft.app' if OS == 'macos' else 'launcher'), symlinks=True)
    launcher_source = package / 'launcher-source'
    launcher_source.mkdir()
    shutil.copy2(ROOT / 'launcher' / 'NOTICE', launcher_source / 'NOTICE')
    if OS == 'linux':
        shutil.copy2(ROOT / 'launcher' / 'linux_sandbox.py', launcher_source / 'linux_sandbox.py')
    files = sorted(p for p in package.rglob('*') if p.is_file())
    if not all(p.resolve().is_relative_to(package.resolve()) for p in package.rglob('*') if p.is_symlink()):
        raise SystemExit('The package contains a link that points outside it')
    private = {'.env', 'data', 'logs', 'credentials', 'activity', 'erl_crash.dump', '.git', '_build'}
    if any(set(p.relative_to(package).parts) & private for p in files):
        raise SystemExit('The package contains local state or credentials')
    manifest = package / 'MANIFEST.sha256'
    manifest.write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(package).as_posix()}\n' for p in files))
    files.append(manifest)
    archive = DIST / (name + suffix)
    if OS == 'windows':
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as packed:
            for p in files:
                # Fixed timestamp plus recorded permissions keep repacks reproducible.
                info = zipfile.ZipInfo(p.relative_to(work).as_posix(), date_time=(2020, 1, 1, 0, 0, 0))
                info.external_attr = (p.stat().st_mode & 0xFFFF) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                packed.writestr(info, p.read_bytes())
    else:
        def normalize(member):
            # Stay within what the extraction-side 'data' filter accepts (relative
            # names, no device nodes) and strip builder identity and timestamps so
            # repeated builds are byte-identical.
            if member.isdev():
                raise SystemExit(f'Cannot package device member {member.name}')
            member.mtime = 0
            member.uid = member.gid = 0
            member.uname = member.gname = ''
            return member
        with gzip.GzipFile(filename=str(archive), mode='wb', mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as packed:
                packed.add(package, arcname=name, recursive=False, filter=normalize)
                for member_path in sorted(package.rglob('*')):
                    packed.add(member_path, arcname=member_path.relative_to(work).as_posix(),
                               recursive=False, filter=normalize)
    Path(str(archive) + '.sha256').write_text(f'{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n')
    print(f'Built {archive.name}')
