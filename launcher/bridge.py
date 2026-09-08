"""Restricted JSON protocol between the desktop window and bot terminal sessions."""
import json
import os
from pathlib import Path
import queue
import sys
import threading
import subprocess
import time
from process import Session, bot_command

ENV_KEYS = {'AI_PROVIDER', 'LOCAL_LLM_URL', 'LOCAL_LLM_MODEL', 'GEMINI_API_KEY', 'GEMINI_MODEL', 'STATUS_LANGUAGE', 'BLUESKY_PDS_URL', 'BLUESKY_HANDLE', 'BLUESKY_APP_PASSWORD', 'MASTODON_API_BASE_URL', 'MASTODON_ACCESS_TOKEN', 'STATUS_VISIBILITY'}
ENV_KEYS.update({'OPENAI_API_KEY', 'OPENAI_MODEL'})


def settings(request):
    values = request.pop('environment', {})
    if not isinstance(values, dict) or any(key not in ENV_KEYS or not isinstance(value, str) or len(value) > 4096 or any(c in value for c in '\r\n\x00') for key, value in values.items()):
        raise ValueError('Invalid bot settings.')
    return values


ACTIONS = {'setup', 'draft', 'review', 'start', 'listen', 'replies', 'search', 'post', 'help', 'version'}
ACTIONS.update({'automatic', 'reject', 'edit', 'status'})
LINE_LIMIT = 65536


def has_control(text, newline=False):
    """True for control characters the bot must not receive as a terminal line."""
    for character in text:
        code = ord(character)
        if character == '\t' or (newline and character == '\n'):
            continue
        if code < 0x20 or code == 0x7f:
            return True
    return False


def valid_id(value):
    return isinstance(value, str) and value.strip() and len(value) <= 80 and not has_control(value)


def arguments(request):
    runtime, platform, action = (request.get(key) for key in ('runtime', 'platform', 'action'))
    if runtime != 'elixir' or platform not in ('bluesky', 'mastodon') or action not in ACTIONS:
        raise ValueError('Choose a valid bot and action.')
    args = [action]
    if action in ('search', 'post'):
        text = request.get('text')
        if not isinstance(text, str) or not text.strip() or len(text) > 10000 or '\x00' in text:
            raise ValueError('Enter text for this action (maximum 10,000 characters).')
        args.append(text)
    if action == 'reject':
        text = request.get('text')
        if not valid_id(text):
            raise ValueError('Choose a pending or uncertain draft to reject.')
        args.append(text)
    if action == 'edit':
        target = request.get('target')
        text = request.get('text')
        if not valid_id(target):
            raise ValueError('Choose a pending draft to edit.')
        if not isinstance(text, str) or not text.strip() or len(text) > 10000 or '\x00' in text:
            raise ValueError('Enter replacement text (maximum 10,000 characters).')
        args.extend([target, text])
    return runtime, platform, args


def serve(root):
    requests = queue.Queue(maxsize=100)
    session = None
    quitting = False
    cleanup_results = queue.Queue()
    cleaning = False
    last_cleanup = 0

    def cleanup():
        failures = []
        for platform in ('bluesky', 'mastodon'):
            if not (root / 'elixir' / platform / 'data').is_dir():
                continue
            try:
                environment = os.environ.copy()
                environment.update(ERL_CRASH_DUMP=os.devnull, ERL_CRASH_DUMP_SECONDS='0')
                if getattr(sys, 'frozen', False):
                    if os.name == 'nt':
                        import ctypes
                        ctypes.windll.kernel32.SetDllDirectoryW(None)
                    else:
                        environment['LD_LIBRARY_PATH'] = environment.get('LD_LIBRARY_PATH_ORIG', '')
                result = subprocess.run(bot_command(root, 'elixir', platform, ['history']), cwd=root,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                        timeout=20, env=environment)
                if result.returncode:
                    failures.append(platform)
            except (ValueError, OSError, subprocess.TimeoutExpired):
                failures.append(platform)
        cleanup_results.put(failures)

    def emit(kind, **values):
        print(json.dumps({'type': kind, **values}, ensure_ascii=True), flush=True)

    def reader():
        while True:
            line = sys.stdin.readline(LINE_LIMIT + 1)
            if not line:
                requests.put({'type': 'quit'})
                return
            if len(line) > LINE_LIMIT:
                # Drain the rest of the oversized line so it is one bad request, not several.
                while line and not line.endswith('\n'):
                    line = sys.stdin.readline(LINE_LIMIT + 1)
                requests.put({'type': 'invalid'})
                continue
            try:
                request = json.loads(line)
                requests.put(request if isinstance(request, dict) else {'type': 'invalid'})
            except ValueError:
                requests.put({'type': 'invalid'})

    threading.Thread(target=reader, daemon=True).start()
    emit('ready')
    while True:
        if not cleaning and time.monotonic() - last_cleanup >= 60:
            cleaning = True
            last_cleanup = time.monotonic()
            threading.Thread(target=cleanup, daemon=True).start()
        try:
            failures = cleanup_results.get_nowait()
            cleaning = False
            emit('maintenance', failures=failures)
        except queue.Empty:
            pass
        if session:
            for _ in range(100):
                try:
                    kind, value = session.events.get_nowait()
                except queue.Empty:
                    break
                if kind == 'review':
                    emit('review', draft=value)
                else:
                    emit(kind, value=value)
            if quitting and session.finished:
                return
        try:
            request = requests.get(timeout=0.03)
        except queue.Empty:
            continue
        try:
            kind = request.get('type')
            if kind == 'run':
                if session and not session.finished:
                    raise ValueError('Stop the running bot before starting another action.')
                runtime, platform, args = arguments(request)
                environment = settings(request)
                environment['CHORUSDRAFT_CONTROL'] = '1'
                try:
                    session = Session(bot_command(root, runtime, platform, args), root, environment)
                finally:
                    environment.clear()
                emit('started', action=args[0], runtime=runtime, platform=platform)
            elif kind == 'input':
                action = request.get('action')
                text = request.get('text')
                if action is not None:
                    if action not in {'approve', 'reject', 'quit', 'skip', 'edit'}:
                        raise ValueError('Enter one response at a time.')
                    command = {'action': action}
                    if action == 'edit':
                        if (not isinstance(text, str) or not text.strip() or len(text) > 20000 or
                                has_control(text, newline=True)):
                            raise ValueError('Enter replacement text (maximum 10,000 characters).')
                        command['text'] = text
                    if session and not session.finished:
                        session.send(json.dumps(command, ensure_ascii=True))
                else:
                    if not isinstance(text, str) or len(text) > 20000 or has_control(text):
                        raise ValueError('Enter one response at a time.')
                    if session and not session.finished:
                        session.send(text)
            elif kind == 'stop':
                if session:
                    session.stop()
            elif kind == 'quit':
                if session and not session.finished:
                    session.stop()
                    quitting = True
                else:
                    return
            else:
                raise ValueError('Unsupported desktop action.')
        except (ValueError, OSError) as error:
            emit('error', value=str(error), active=bool(session and not session.finished))
        except Exception:
            emit('error', value='Unable to start the session. Check the selected runtime installation.')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--terminal-child']:
        from terminal_child import main
        main(sys.argv[2:])
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_dir():
        raise SystemExit('Expected the ChorusDraft package directory.')
    sys.stdin.reconfigure(encoding='utf-8')
    sys.stdout.reconfigure(encoding='utf-8')
    serve(Path(sys.argv[1]).resolve())
