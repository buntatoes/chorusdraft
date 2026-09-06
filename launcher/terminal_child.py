"""Set the Windows terminal encoding before starting a bot without a shell."""
import ctypes
import subprocess
import sys


def main(command):
    if sys.platform != 'win32' or not command:
        raise SystemExit('Expected a Windows bot command.')
    kernel = ctypes.windll.kernel32
    if not kernel.SetConsoleCP(65001) or not kernel.SetConsoleOutputCP(65001):
        raise SystemExit('Unable to configure the bot terminal for UTF-8.')
    # Frozen Python must not redirect a bot's DLL lookup into its own runtime.
    kernel.SetDllDirectoryW(None)
    child = subprocess.Popen(command)
    try:
        code = child.wait()
    except KeyboardInterrupt:
        try:
            code = child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.terminate()
            code = child.wait()
    raise SystemExit(code)


if __name__ == '__main__':
    main(sys.argv[1:])
