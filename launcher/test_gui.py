"""Native desktop smoke tests and terminal-session regression checks."""
import os
from pathlib import Path
import queue
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from bridge import arguments
from process import Session, bot_command


class DesktopTests(unittest.TestCase):
    def test_terminal_input_remains_interactive_and_literal(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'prompt.py'
            program.write_text("import sys,os\nassert os.environ['ERL_CRASH_DUMP'] == os.devnull\nassert os.environ['ERL_CRASH_DUMP_SECONDS'] == '0'\nprint('TTY=' + str(sys.stdin.isatty()), flush=True)\nprint('Approve this exact draft? ', end='', flush=True)\nprint('REPLY=' + input(), flush=True)\n")
            session = Session([sys.executable, str(program)], folder)
            output = ''
            sent = False
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                try:
                    kind, value = session.events.get(timeout=0.2)
                except queue.Empty:
                    continue
                if kind == 'output':
                    output += value
                    if 'Approve this exact draft?' in output and not sent:
                        session.send('yes & $HOME | café')
                        sent = True
                elif kind == 'exit':
                    break
                else:
                    self.fail(value)
            else:
                session.stop()
                self.fail('Interactive session timed out')
            self.assertTrue(sent)
            self.assertIn('TTY=True', output)
            self.assertIn('REPLY=yes & $HOME | café', output)

    def test_stop_ends_a_running_session(self):
        session = Session([sys.executable, '-c', 'import time; print("READY", flush=True); time.sleep(90)'], tempfile.gettempdir())
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            kind, value = session.events.get(timeout=10)
            if kind == 'output' and 'READY' in value:
                break
        session.stop()
        while not session.finished and time.monotonic() < deadline:
            time.sleep(0.1)
        self.assertTrue(session.finished)

    def test_desktop_commands_cannot_inject_flags_or_skip_approval(self):
        text = 'quotes "hello" & pipes | $HOME; café'
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'post', 'text': text}),
                         ('elixir', 'bluesky', ['post', text]))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'edit', 'target': 'draft-id', 'text': text}),
                         ('elixir', 'bluesky', ['edit', 'draft-id', text]))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reject', 'text': 'draft-id'}),
                         ('elixir', 'mastodon', ['reject', 'draft-id']))
        for request in ({'runtime': 'elixir', 'platform': 'bluesky', 'action': '--publish'},
                        {'runtime': 'python', 'platform': 'mastodon', 'action': 'review'},
                        {'runtime': 'elixir', 'platform': '../bluesky', 'action': 'review'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'edit', 'text': text}):
            with self.assertRaises(ValueError):
                arguments(request)

    def test_missing_executable_has_a_clear_error(self):
        with tempfile.TemporaryDirectory() as folder, patch('process.shutil.which', return_value='/fake/escript'):
            with self.assertRaisesRegex(ValueError, 'Elixir executable is missing'):
                bot_command(folder, 'elixir', 'bluesky', ['review'])


if __name__ == '__main__':
    unittest.main()
