"""Run bot commands in a terminal session while keeping approval interactive."""
import codecs
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import threading


def application_root():
    if getattr(sys, 'frozen', False):
        executable = Path(sys.executable).resolve()
        if sys.platform == 'darwin' and '.app' in str(executable):
            return executable.parents[3]
        return executable.parent.parent
    return Path(__file__).resolve().parent.parent


def bot_command(root, runtime, platform, arguments):
    root = Path(root)
    if runtime != 'elixir' or platform not in ('bluesky', 'mastodon'):
        raise ValueError('Choose Bluesky or Mastodon.')
    for component in (root / 'elixir', root / 'elixir' / platform):
        if component.is_symlink():
            raise ValueError('Bot folders must not be symbolic links.')
    escript = shutil.which('escript')
    if not escript:
        raise ValueError('Install Erlang/OTP 25 or later and add escript to PATH, then reopen ChorusDraft.')
    executable = root / 'elixir' / 'chorusdraft'
    if not executable.is_file():
        raise ValueError('The Elixir executable is missing. Build it from the elixir folder or use a combined download.')
    return [escript, str(executable), platform, *arguments, '--base', str(root / 'elixir' / platform)]


class Session:
    def __init__(self, command, cwd, settings=None):
        self.events = queue.Queue(maxsize=1000)
        self.finished = False
        self.process = None
        self.master = None
        self._stopping = False
        environment = os.environ.copy()
        environment.update(ERL_CRASH_DUMP=os.devnull, ERL_CRASH_DUMP_SECONDS='0')
        if settings:
            environment.update(settings)
        if 'LD_LIBRARY_PATH_ORIG' in environment:
            environment['LD_LIBRARY_PATH'] = environment.pop('LD_LIBRARY_PATH_ORIG')
        elif getattr(sys, 'frozen', False):
            environment.pop('LD_LIBRARY_PATH', None)
        if os.name == 'nt':
            from winpty import PtyProcess
            wrapper = [sys.executable, '--terminal-child'] if getattr(sys, 'frozen', False) else [
                sys.executable, str(Path(__file__).with_name('terminal_child.py'))]
            self.process = PtyProcess.spawn([*wrapper, *command], cwd=str(cwd), env=environment, dimensions=(40, 160))
        else:
            import fcntl
            import pty
            import struct
            import termios
            self.master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 160, 0, 0))
            # Canonical mode caps a line at 4095 bytes on Linux and 1024 on macOS and
            # silently drops the rest, which truncates long edits. The bridge always
            # sends complete lines, so hand them over unedited; signals still work.
            attributes = termios.tcgetattr(slave)
            attributes[3] &= ~termios.ICANON
            attributes[6][termios.VMIN] = 1
            attributes[6][termios.VTIME] = 0
            termios.tcsetattr(slave, termios.TCSANOW, attributes)
            try:
                self.process = subprocess.Popen(command, cwd=cwd, stdin=slave, stdout=slave,
                                                stderr=slave, start_new_session=True, env=environment)
            except Exception:
                os.close(self.master)
                self.master = None
                raise
            finally:
                os.close(slave)
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()

    def _read(self):
        decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')
        try:
            while True:
                if os.name == 'nt':
                    try:
                        text = self.process.read(8192)
                    except EOFError:
                        break
                else:
                    try:
                        data = os.read(self.master, 8192)
                    except OSError:
                        break
                    if not data:
                        break
                    text = decoder.decode(data)
                if text:
                    self.events.put(('output', text))
            if os.name != 'nt':
                tail = decoder.decode(b'', final=True)
                if tail:
                    self.events.put(('output', tail))
                code = self.process.wait()
            else:
                code = self.process.exitstatus
            self.events.put(('exit', code))
        except Exception:
            self.events.put(('error', 'The bot session ended unexpectedly. Check the account before retrying a publication.'))
        finally:
            self.finished = True
            if self.master is not None:
                os.close(self.master)
                self.master = None

    def send(self, text):
        if self.finished:
            return
        if os.name == 'nt':
            self.process.write(text + '\r\n')
        else:
            os.write(self.master, (text + '\n').encode('utf-8'))

    def stop(self):
        if self.finished or self._stopping:
            return
        self._stopping = True
        if os.name == 'nt':
            self.process.write('\x03')
        else:
            try:
                os.killpg(self.process.pid, signal.SIGINT)
            except ProcessLookupError:
                return
        threading.Thread(target=self._force_stop, daemon=True).start()

    def _force_stop(self):
        import time
        time.sleep(3)
        if self.finished:
            return
        if os.name == 'nt':
            self.process.terminate(force=True)
        else:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
