#!/usr/bin/env python3
"""Configure a path-specific AppArmor allowance for Electron's Linux sandbox."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    if sys.platform != 'linux':
        raise SystemExit('This setup is only needed on Linux systems with AppArmor.')
    root = Path(__file__).resolve().parent.parent
    executable = (root / 'launcher/ChorusDraft').resolve()
    if not executable.is_file():
        raise SystemExit('Run this script from an extracted combined Linux download.')
    # AppArmor paths support glob syntax; only allow an exact literal attachment.
    if any(char in str(executable) for char in '\n\r"\\*?[]{}^@'):
        raise SystemExit('Move the download to a folder without special filename characters first.')
    parser = shutil.which('apparmor_parser') or '/sbin/apparmor_parser'
    if not Path(parser).is_file():
        raise SystemExit('AppArmor is not installed; this setup is not required.')
    if os.geteuid() != 0:
        raise SystemExit('Run with sudo to install the AppArmor profile for this launcher only.')
    name = 'chorusdraft-' + hashlib.sha256(str(executable).encode()).hexdigest()[:16]
    profile = Path('/etc/apparmor.d') / name
    if sys.argv[1:] == ['--remove']:
        if profile.exists():
            subprocess.run([parser, '-R', str(profile)], check=True)
            profile.unlink()
        return
    if sys.argv[1:]:
        raise SystemExit('Usage: linux_sandbox.py [--remove]')
    content = f'abi <abi/4.0>,\ninclude <tunables/global>\nprofile {name} "{executable}" flags=(unconfined) {{\n  userns,\n}}\n'
    profile.write_text(content)
    profile.chmod(0o644)
    subprocess.run([parser, '-r', str(profile)], check=True)
    print('Sandbox configured for this ChorusDraft download. Start ./bot as your normal user.')


if __name__ == '__main__':
    main()
