"""Set the Windows terminal encoding before starting a bot without a shell."""
import ctypes
import os
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
    # OTP 25 cannot always report columns on ConPTY. Verify both console
    # handles here before declaring this inherited session interactive.
    kernel.GetStdHandle.restype = ctypes.c_void_p
    mode = ctypes.c_ulong()
    interactive = all(kernel.GetConsoleMode(kernel.GetStdHandle(handle), ctypes.byref(mode))
                      for handle in (-10, -11))
    environment = os.environ.copy()
    environment.pop('CHORUSDRAFT_WINDOWS_CONSOLE', None)
    if interactive:
        environment['CHORUSDRAFT_WINDOWS_CONSOLE'] = '1'
    child = subprocess.Popen(command, env=environment)
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
