"""Native desktop smoke tests and terminal-session regression checks."""
import os
from pathlib import Path
import queue
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import tkinter as tk
from app import Launcher
from process import Session, bot_command


class DesktopTests(unittest.TestCase):
    def test_terminal_input_remains_interactive_and_literal(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'prompt.py'
            program.write_text("import sys\nprint('TTY=' + str(sys.stdin.isatty()), flush=True)\nprint('Approve this exact draft? ', end='', flush=True)\nprint('REPLY=' + input(), flush=True)\n")
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

    def test_window_selection_launch_output_and_review_response(self):
        window = tk.Tk()
        try:
            with tempfile.TemporaryDirectory() as folder:
                app = Launcher(window, folder)
                window.update()
                self.assertEqual(window.title(), 'ChorusDraft')
                app.runtime.set('Elixir')
                app.platform.set('Mastodon')
                with patch('app.bot_command', return_value=['escript', 'bot']), patch('app.Session') as mock:
                    instance = mock.return_value
                    instance.finished = False
                    instance.events = queue.Queue()
                    app.launch('review')
                    self.assertEqual(str(app.selectors[0].cget('state')), 'disabled')
                    instance.events.put(('output', 'Exact draft text.\nPublish this exact draft? [y/N/d/q]: '))
                    app.poll()
                    self.assertIn('Exact draft text.', app.output.get('1.0', 'end'))
                    app.input.insert(0, 'y')
                    app.send()
                    instance.send.assert_called_once_with('y')
                    instance.events.put(('exit', 0))
                    instance.finished = True
                    app.poll()
                    self.assertEqual(app.status.get(), 'Ready')
                    self.assertEqual(str(app.selectors[0].cget('state')), 'readonly')
        finally:
            window.destroy()

    def test_missing_elixir_never_falls_back_to_ruby(self):
        with tempfile.TemporaryDirectory() as folder, patch('process.shutil.which', return_value='/fake/escript'):
            with self.assertRaisesRegex(ValueError, 'Elixir executable is missing'):
                bot_command(folder, 'elixir', 'bluesky', ['review'])


if __name__ == '__main__':
    unittest.main()
