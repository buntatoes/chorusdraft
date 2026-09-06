#!/usr/bin/env python3
"""Bundle the terminal bridge, then package the React/Electron desktop."""
from pathlib import Path
import shutil
import importlib.metadata
import sysconfig
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
command = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onedir', '--console',
           '--name', 'chorus-bridge', '--distpath', str(root / 'dist' / 'gui-backend'),
           '--workpath', str(root / 'dist' / 'gui-build'), '--specpath', str(root / 'dist'),
           '--paths', str(root / 'launcher')]
if sys.platform == 'win32':
    command += ['--collect-all', 'winpty']
command += [str(root / 'launcher' / 'bridge.py')]
subprocess.run(command, check=True)
licenses = root / 'dist' / 'gui-backend' / 'chorus-bridge' / 'licenses'
licenses.mkdir(exist_ok=True)
for name in ['pyinstaller'] + (['pywinpty'] if sys.platform == 'win32' else []):
    distribution = importlib.metadata.distribution(name)
    for file in distribution.files or []:
        if Path(file).name.lower().startswith(('license', 'copying')):
            source = distribution.locate_file(file)
            if source.is_file():
                shutil.copy2(source, licenses / (name + '-' + source.name))
for candidate in [Path(sys.base_prefix) / 'LICENSE.txt', Path(sysconfig.get_path('stdlib')) / 'LICENSE.txt',
                  Path('/usr/share/doc/python3.12/copyright')]:
    if candidate.is_file():
        shutil.copy2(candidate, licenses / 'PYTHON-LICENSE.txt')
        break
node = shutil.which('node')
if not node:
    raise SystemExit('Install Node.js 24 to build the desktop application.')
subprocess.run([node, str(root / 'desktop/node_modules/vite/bin/vite.js'), 'build'], cwd=root / 'desktop', check=True)
subprocess.run([node, str(root / 'desktop/package.cjs')], cwd=root / 'desktop', check=True)
