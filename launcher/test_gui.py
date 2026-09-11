"""Native desktop smoke tests and terminal-session regression checks."""
import json
import os
from pathlib import Path
import queue
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from bridge import arguments, has_control, require_live_session, settings
from process import Session, bot_command


def run_prompt_session(program, reply, prompt='Approve this exact draft?'):
    """Start PROGRAM in a session, answer PROMPT with REPLY, and return everything it printed."""
    session = Session([sys.executable, str(program)], str(program.parent))
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
            if prompt in output and not sent:
                session.send(reply)
                sent = True
        elif kind == 'exit':
            break
        else:
            raise AssertionError(value)
    else:
        session.stop()
        raise AssertionError('Interactive session timed out')
    if not sent:
        raise AssertionError('The prompt never appeared')
    return output


class DesktopTests(unittest.TestCase):
    def test_terminal_input_remains_interactive_and_literal(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'prompt.py'
            program.write_text("import sys,os\nassert os.environ['ERL_CRASH_DUMP'] == os.devnull\nassert os.environ['ERL_CRASH_DUMP_SECONDS'] == '0'\nprint('TTY=' + str(sys.stdin.isatty()), flush=True)\nprint('Approve this exact draft? ', end='', flush=True)\nprint('REPLY=' + input(), flush=True)\n")
            output = run_prompt_session(program, 'yes & $HOME | café')
            self.assertIn('TTY=True', output)
            self.assertIn('REPLY=yes & $HOME | café', output)

    @unittest.skipIf(os.name == 'nt', 'POSIX terminal line discipline only')
    def test_long_replies_reach_the_bot_intact(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'prompt.py'
            program.write_text("import sys\nprint('Approve this exact draft? ', end='', flush=True)\nreply = sys.stdin.readline()\nprint('LEN=' + str(len(reply.rstrip('\\n'))), flush=True)\n")
            long_reply = '<<JSON>>"' + 'é' * 6000 + '"'
            output = run_prompt_session(program, long_reply)
            self.assertIn('LEN=' + str(len(long_reply)), output)

    def test_control_characters_are_rejected_before_the_terminal(self):
        for text in ('\x03', 'y\x1a', 'stop\x04', 'del\x7f', 'line\n', 'ret\r', 'nul\x00'):
            self.assertTrue(has_control(text), repr(text))
        self.assertFalse(has_control('tabs\tare fine, so is café'))
        self.assertFalse(has_control('line\nbreaks', newline=True))
        self.assertTrue(has_control('line\nbreaks'))
        for request in ({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reject', 'text': 'draft\x03id'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'edit', 'target': 'draft\x1bid', 'text': 'ok'}):
            with self.assertRaises(ValueError):
                arguments(request)

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

    def test_control_sessions_speak_json_instead_of_a_tty(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'control.py'
            program.write_text(
                "import json,sys\n"
                "print(json.dumps({'event':'log','value':'hello\\n'}), flush=True)\n"
                "print(json.dumps({'event':'review','draft':{'id':'1','text':'hi'}}), flush=True)\n"
                "command = json.loads(sys.stdin.readline())\n"
                "print(json.dumps({'event':'log','value':'got '+command['action']+'\\n'}), flush=True)\n"
            )
            session = Session([sys.executable, str(program)], folder, {'CHORUSDRAFT_CONTROL': '1'})
            output = ''
            review = None
            deadline = time.monotonic() + 20
            sent = False
            while time.monotonic() < deadline:
                try:
                    kind, value = session.events.get(timeout=0.2)
                except queue.Empty:
                    continue
                if kind == 'output':
                    output += value
                elif kind == 'review':
                    review = value
                    if not sent:
                        session.send(json.dumps({'action': 'approve'}))
                        sent = True
                elif kind == 'exit':
                    break
                else:
                    raise AssertionError(value)
            else:
                session.stop()
                raise AssertionError('Control session timed out')
            self.assertEqual(review, {'id': '1', 'text': 'hi'})
            self.assertIn('hello', output)
            self.assertIn('got approve', output)
            self.assertTrue(session.control)

    def test_control_sessions_forward_delete_confirm(self):
        with tempfile.TemporaryDirectory(prefix='ChorusDraft GUI test ') as folder:
            program = Path(folder) / 'control.py'
            program.write_text(
                "import json,sys\n"
                "print(json.dumps({'event':'confirm','action':'delete','id':'post-1'}), flush=True)\n"
                "command = json.loads(sys.stdin.readline())\n"
                "print(json.dumps({'event':'log','value':'got '+command['action']+'\\n'}), flush=True)\n"
            )
            session = Session([sys.executable, str(program)], folder, {'CHORUSDRAFT_CONTROL': '1'})
            output = ''
            confirm = None
            deadline = time.monotonic() + 20
            sent = False
            while time.monotonic() < deadline:
                try:
                    kind, value = session.events.get(timeout=0.2)
                except queue.Empty:
                    continue
                if kind == 'output':
                    output += value
                elif kind == 'confirm':
                    confirm = value
                    if not sent:
                        session.send(json.dumps({'action': 'approve'}))
                        sent = True
                elif kind == 'exit':
                    break
                else:
                    raise AssertionError((kind, value))
            else:
                session.stop()
                raise AssertionError('Control session timed out')
            self.assertEqual(confirm, {'action': 'delete', 'id': 'post-1'})
            self.assertIn('got approve', output)
            self.assertNotIn('confirm', output)

    def test_desktop_commands_cannot_inject_flags_or_skip_approval(self):
        text = 'quotes "hello" & pipes | $HOME; café'
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'post', 'text': text}),
                         ('elixir', 'bluesky', ['post', text]))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'edit', 'target': 'draft-id', 'text': text}),
                         ('elixir', 'bluesky', ['edit', 'draft-id', text]))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reject', 'text': 'draft-id'}),
                         ('elixir', 'mastodon', ['reject', 'draft-id']))
        uri = 'at://did:web:bsky.much-longer.subdomain.example.social/app.bsky.feed.post/3jzfciyerx22f'
        self.assertGreater(len(uri), 80)
        self.assertEqual(
            arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'reply', 'text': text, 'target': uri}),
            ('elixir', 'bluesky', ['reply', uri, text]))
        self.assertEqual(
            arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'quote', 'text': text, 'target': uri}),
            ('elixir', 'bluesky', ['quote', uri, text]))
        self.assertEqual(
            arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'post', 'text': text, 'cw': 'note'}),
            ('elixir', 'mastodon', ['post', text, '--cw', 'note']))
        self.assertEqual(
            arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reply',
                       'text': text, 'target': '123', 'cw': 'note'}),
            ('elixir', 'mastodon', ['reply', '123', text, '--cw', 'note']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'review', 'target': 'draft-id'}),
                         ('elixir', 'bluesky', ['review', 'draft-id']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'review'}),
                         ('elixir', 'bluesky', ['review']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'discover'}),
                         ('elixir', 'bluesky', ['discover']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'discover', 'text': '  '}),
                         ('elixir', 'bluesky', ['discover']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'discover', 'text': 'opensource'}),
                         ('elixir', 'mastodon', ['discover', 'opensource']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'targets'}),
                         ('elixir', 'bluesky', ['targets']))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'targets', 'text': 'someone'}),
                         ('elixir', 'mastodon', ['targets', 'someone']))
        post_id = 'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/3k2yqh3k2yq2q'
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'bluesky', 'action': 'delete', 'text': post_id}),
                         ('elixir', 'bluesky', ['delete', post_id]))
        self.assertEqual(arguments({'runtime': 'elixir', 'platform': 'mastodon', 'action': 'delete', 'text': '123'}),
                         ('elixir', 'mastodon', ['delete', '123']))
        for request in ({'runtime': 'elixir', 'platform': 'bluesky', 'action': '--publish'},
                        {'runtime': 'python', 'platform': 'mastodon', 'action': 'review'},
                        {'runtime': 'elixir', 'platform': '../bluesky', 'action': 'review'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'edit', 'text': text},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reject', 'text': 'draft\nid'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'publish', 'text': text},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'reply', 'text': text},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'quote', 'text': text, 'target': '--publish'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'post', 'text': text, 'cw': 'note'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reply', 'text': text, 'target': '12 3'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'reply', 'text': text, 'target': 'abc'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'quote', 'text': text, 'target': uri},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'reply', 'text': text, 'target': 'not-a-uri'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'quote', 'text': text,
                         'target': 'at://did:plc:alice/app.bsky.feed.like/fixture'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'post', 'text': text, 'cw': 'n' * 501},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'review', 'target': 'draft\nid'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'import'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'service'},
                        {'runtime': 'elixir', 'platform': 'bluesky', 'action': 'delete'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'delete', 'text': 'post\nid'},
                        {'runtime': 'elixir', 'platform': 'mastodon', 'action': 'delete', 'text': post_id}):
            with self.assertRaises(ValueError):
                arguments(request)

    def test_review_input_requires_a_live_session(self):
        class Finished:
            finished = True

        with self.assertRaisesRegex(ValueError, 'already ended'):
            require_live_session(None)
        with self.assertRaisesRegex(ValueError, 'already ended'):
            require_live_session(Finished())

    def test_gui_settings_allow_hours_and_discovery_keywords(self):
        self.assertEqual(
            settings({'environment': {'ACTIVE_HOURS': '08:30-22:00', 'DISCOVERY_KEYWORDS': 'elixir,linux'}}),
            {'ACTIVE_HOURS': '08:30-22:00', 'DISCOVERY_KEYWORDS': 'elixir,linux'},
        )
        with self.assertRaises(ValueError):
            settings({'environment': {'DISCOVERY_TAGS': 'opensource'}})
        with self.assertRaises(ValueError):
            settings({'environment': {'ACTIVE_HOURS': '08:30-22:00\nOTHER=1'}})

    def test_missing_executable_has_a_clear_error(self):
        with tempfile.TemporaryDirectory() as folder, patch('process.shutil.which', return_value='/fake/escript'):
            with self.assertRaisesRegex(ValueError, 'Elixir executable is missing'):
                bot_command(folder, 'elixir', 'bluesky', ['review'])


if __name__ == '__main__':
    unittest.main()
