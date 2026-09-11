"""Run bot commands in a terminal session while keeping approval interactive."""
import codecs
import json
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import threading


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
        self.control = environment.get('CHORUSDRAFT_CONTROL') == '1'
        if 'LD_LIBRARY_PATH_ORIG' in environment:
            environment['LD_LIBRARY_PATH'] = environment.pop('LD_LIBRARY_PATH_ORIG')
        elif getattr(sys, 'frozen', False):
            environment.pop('LD_LIBRARY_PATH', None)
        if os.name == 'nt' and not self.control:
            from winpty import PtyProcess
            wrapper = [sys.executable, '--terminal-child'] if getattr(sys, 'frozen', False) else [
                sys.executable, str(Path(__file__).with_name('terminal_child.py'))]
            self.process = PtyProcess.spawn([*wrapper, *command], cwd=str(cwd), env=environment, dimensions=(40, 160))
        elif self.control:
            popen = {'cwd': cwd, 'stdin': subprocess.PIPE, 'stdout': subprocess.PIPE,
                     'stderr': subprocess.PIPE, 'env': environment, 'bufsize': 0}
            if os.name == 'nt':
                popen['creationflags'] = subprocess.CREATE_NEW_PROCESS_GROUP
            else:
                popen['start_new_session'] = True
            self.process = subprocess.Popen(command, **popen)
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
        if self.control:
            threading.Thread(target=self._drain_stderr, daemon=True).start()

    def _drain_stderr(self):
        try:
            while True:
                line = self.process.stderr.readline()
                if not line:
                    return
        except Exception:
            return

    def _read(self):
        if self.control:
            self._read_control()
            return
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
            self.events.put(('exit', 1))
        finally:
            self.finished = True
            if self.master is not None:
                os.close(self.master)
                self.master = None

    def _read_control(self):
        try:
            while True:
                line = self.process.stdout.readline()
                if not line:
                    break
                if isinstance(line, bytes):
                    line = line.decode('utf-8', errors='replace')
                if len(line) > 65536:
                    self.events.put(('error', 'The bot sent a line that was too large.'))
                    continue
                line = line.rstrip('\r\n')
                if not line:
                    continue
                try:
                    message = json.loads(line)
                except ValueError:
                    self.events.put(('output', line + '\n'))
                    continue
                if not isinstance(message, dict):
                    self.events.put(('output', line + '\n'))
                    continue
                event = message.get('event')
                if event == 'log':
                    self.events.put(('output', message.get('value') or ''))
                elif event == 'review':
                    draft = message.get('draft')
                    self.events.put(('review', draft if isinstance(draft, dict) else {}))
                elif event == 'confirm':
                    action = message.get('action')
                    ident = message.get('id')
                    if action == 'delete' and isinstance(ident, str):
                        self.events.put(('confirm', {'action': 'delete', 'id': ident}))
                    else:
                        self.events.put(('output', line + '\n'))
                else:
                    self.events.put(('output', line + '\n'))
            code = self.process.wait()
            self.events.put(('exit', code))
        except Exception:
            self.events.put(('error', 'The bot session ended unexpectedly. Check the account before retrying a publication.'))
            self.events.put(('exit', 1))
        finally:
            self.finished = True

    def send(self, text):
        if self.finished:
            return
        payload = text if text.endswith('\n') else text + '\n'
        if self.control:
            self.process.stdin.write(payload.encode('utf-8'))
            self.process.stdin.flush()
            return
        if os.name == 'nt':
            self.process.write(text + '\r\n')
        else:
            os.write(self.master, payload.encode('utf-8'))

    def stop(self):
        if self.finished or self._stopping:
            return
        self._stopping = True
        try:
            if self.control:
                if os.name == 'nt':
                    self.process.terminate()
                else:
                    os.killpg(self.process.pid, signal.SIGINT)
            elif os.name == 'nt':
                self.process.write('\x03')
            else:
                os.killpg(self.process.pid, signal.SIGINT)
        except (ProcessLookupError, OSError):
            return
        threading.Thread(target=self._force_stop, daemon=True).start()

    def _force_stop(self):
        import time
        time.sleep(3)
        if self.finished:
            return
        try:
            if self.control:
                self.process.kill()
            elif os.name == 'nt':
                self.process.terminate(force=True)
            else:
                os.killpg(self.process.pid, signal.SIGTERM)
        except (ProcessLookupError, OSError, AttributeError):
            pass
