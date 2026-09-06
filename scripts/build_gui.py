#!/usr/bin/env python3
"""Build a native desktop executable with its Python/Tk runtime."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
command = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onedir', '--windowed',
           '--name', 'ChorusDraft', '--distpath', str(root / 'dist' / 'gui'),
           '--workpath', str(root / 'dist' / 'gui-build'), '--specpath', str(root / 'dist'),
           '--paths', str(root / 'launcher')]
if os.environ.get('TK_LIBRARY'):
    command += ['--add-data', os.environ['TK_LIBRARY'] + os.pathsep + '_tk_data']
if sys.platform == 'win32':
    command += ['--collect-all', 'winpty']
command += [str(root / 'launcher' / 'app.py')]
subprocess.run(command, check=True)
