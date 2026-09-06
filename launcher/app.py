"""ChorusDraft desktop launcher."""
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
from tkinter.scrolledtext import ScrolledText

from process import Session, application_root, bot_command


class Launcher:
    def __init__(self, window, root=None):
        self.window = window
        self.root = Path(root) if root else application_root()
        self.session = None
        self.pending_output = ''
        self.runtime = tk.StringVar(value='Ruby')
        self.platform = tk.StringVar(value='Bluesky')
        self.status = tk.StringVar(value='Ready')
        window.title('ChorusDraft')
        window.geometry('1000x760')
        window.minsize(820, 700)
        window.configure(background='#f3f5f8')
        style = ttk.Style()
        if 'clam' in style.theme_names():
            style.theme_use('clam')
        style.configure('TFrame', background='#f3f5f8')
        style.configure('TLabel', background='#f3f5f8', foreground='#202c3f', font=('TkDefaultFont', 11))
        style.configure('Title.TLabel', font=('TkDefaultFont', 25, 'bold'))
        style.configure('TButton', padding=(12, 6), font=('TkDefaultFont', 10))
        style.configure('Accent.TButton', background='#275caa', foreground='white')
        frame = ttk.Frame(window, padding=24)
        frame.pack(fill='both', expand=True)
        ttk.Label(frame, text='ChorusDraft', style='Title.TLabel').pack(anchor='w')
        ttk.Label(frame, text='Draft, review, and publish from one place.').pack(anchor='w', pady=(4, 18))
        settings = ttk.Frame(frame)
        settings.pack(fill='x')
        self.selectors = []
        for label, variable, values in [('Implementation', self.runtime, ('Ruby', 'Elixir')),
                                         ('Platform', self.platform, ('Bluesky', 'Mastodon'))]:
            group = ttk.Frame(settings)
            group.pack(side='left', padx=(0, 20))
            ttk.Label(group, text=label).pack(anchor='w', pady=(0, 5))
            selector = ttk.Combobox(group, textvariable=variable, values=values, state='readonly', width=22)
            selector.pack()
            self.selectors.append(selector)
        body = ttk.Frame(frame)
        body.pack(fill='both', expand=True, pady=(22, 12))
        actions = ttk.Frame(body)
        actions.pack(side='left', fill='y', padx=(0, 20))
        self.buttons = []
        for label, command in [('Set up', 'setup'), ('Open configuration', 'config'),
                               ('Draft a post', 'draft'), ('Review drafts', 'review'),
                               ('Start monitoring', 'start'), ('Listen for mentions', 'listen'),
                               ('Draft replies', 'replies'), ('Search posts', 'search'),
                               ('Write a post', 'post'), ('Command help', 'help')]:
            button = ttk.Button(actions, text=label, command=lambda c=command: self.launch(c),
                                style='Accent.TButton' if command == 'review' else 'TButton')
            button.pack(fill='x', pady=(0, 5))
            self.buttons.append(button)
        console = ttk.Frame(body)
        console.pack(side='left', fill='both', expand=True)
        ttk.Label(console, text='Activity').pack(anchor='w', pady=(0, 7))
        self.output = ScrolledText(console, height=16, width=60, wrap='word', state='disabled', background='#142033',
                                  foreground='#e7edf7', insertbackground='white', font=('TkFixedFont', 11),
                                  borderwidth=0, padx=15, pady=15)
        self.output.pack(fill='both', expand=True)
        self.append('Choose a bot, then select Set up. Add your account and AI settings before drafting.\n\n'
                    'AI drafts stay in the queue until you approve them in Review drafts.\n')
        reply = ttk.Frame(console)
        reply.pack(fill='x', pady=(9, 0))
        ttk.Label(reply, text='Response').pack(side='left', padx=(0, 8))
        self.input = ttk.Entry(reply, state='disabled')
        self.input.pack(side='left', fill='x', expand=True)
        self.input.bind('<Return>', self.send)
        self.send_button = ttk.Button(reply, text='Send', command=self.send, state='disabled')
        self.send_button.pack(side='left', padx=(8, 0))
        ttk.Label(console, text='During review: y = publish, d = reject, q = finish.').pack(anchor='w', pady=(7, 0))
        footer = ttk.Frame(frame)
        footer.pack(fill='x')
        ttk.Label(footer, textvariable=self.status).pack(side='left')
        self.stop_button = ttk.Button(footer, text='Stop', command=self.stop, state='disabled')
        self.stop_button.pack(side='right')
        window.protocol('WM_DELETE_WINDOW', self.close)
        window.after(50, self.poll)

    def append(self, text):
        # ConPTY emits presentation sequences; they are not part of draft text.
        self.pending_output += text
        # Retain an incomplete escape sequence until the next read.
        match = re.search(r'\x1b(?:\[[0-?]*[ -/]*|\][^\x07]*)?$', self.pending_output)
        if match:
            text, self.pending_output = self.pending_output[:match.start()], self.pending_output[match.start():]
        else:
            text, self.pending_output = self.pending_output, ''
        text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\)', '', text)
        text = text.replace('\r\n', '\n').replace('\r', '')
        self.output.configure(state='normal')
        self.output.insert('end', text)
        # Bound long monitoring sessions while retaining recent activity.
        if int(self.output.index('end-1c').split('.')[0]) > 6000:
            self.output.delete('1.0', '1000.0')
        self.output.see('end')
        self.output.configure(state='disabled')

    def set_busy(self, busy):
        for button in self.buttons:
            button.configure(state='disabled' if busy else 'normal')
        for selector in self.selectors:
            selector.configure(state='disabled' if busy else 'readonly')
        self.stop_button.configure(state='normal' if busy else 'disabled')
        self.input.configure(state='normal' if busy else 'disabled')
        self.send_button.configure(state='normal' if busy else 'disabled')

    def launch(self, action):
        if self.session and not self.session.finished:
            return
        runtime, platform = self.runtime.get().lower(), self.platform.get().lower()
        if action == 'config':
            self.open_config(runtime, platform)
            return
        arguments = [action]
        if action in ('search', 'post'):
            text = simpledialog.askstring('Search posts' if action == 'search' else 'Write a post',
                                          'Search query:' if action == 'search' else 'Post text (queued for review):',
                                          parent=self.window)
            if not text:
                return
            arguments.append(text)
        try:
            command = bot_command(self.root, runtime, platform, arguments)
            self.session = Session(command, self.root)
        except Exception as error:
            messagebox.showerror('Unable to start bot', str(error), parent=self.window)
            return
        self.current_action = action
        self.current_base = self.root / platform if runtime == 'ruby' else self.root / 'elixir' / platform
        self.append(f'\n── {self.runtime.get()} / {self.platform.get()} · {action} ──\n')
        self.status.set(f'{self.runtime.get()} / {self.platform.get()} — {action}')
        self.set_busy(True)
        self.input.focus_set()

    def send(self, _event=None):
        text = self.input.get()
        self.input.delete(0, 'end')
        if self.session:
            try:
                self.session.send(text)
            except OSError:
                self.append('\nThe session has ended.\n')

    def stop(self):
        if self.session:
            self.session.stop()
            self.status.set('Stopping…')

    def poll(self):
        if self.session:
            for _ in range(100):
                try:
                    kind, value = self.session.events.get_nowait()
                except queue.Empty:
                    break
                if kind == 'output':
                    self.append(value)
                else:
                    self.set_busy(False)
                    self.status.set('Ready' if kind == 'exit' and value == 0 else 'Session ended')
                    if kind == 'error':
                        self.append('\n' + value + '\n')
                    elif value == 0 and self.current_action == 'setup':
                        self.append(f'\nConfiguration: {self.current_base / ".env"}\nUse Open configuration to add your settings.\n')
                    else:
                        self.append(f'\nSession finished (exit {value}).\n')
        self.window.after(50, self.poll)

    def open_config(self, runtime, platform):
        base = self.root / platform if runtime == 'ruby' else self.root / 'elixir' / platform
        path = base / '.env'
        if not path.is_file():
            messagebox.showinfo('Set up first', 'Choose Set up to create this bot’s configuration.', parent=self.window)
            return
        if os.name == 'nt':
            subprocess.Popen(['notepad.exe', str(path)])
        elif sys.platform == 'darwin':
            subprocess.Popen(['open', '-t', str(path)])
        else:
            subprocess.Popen(['xdg-open', str(path)])

    def close(self):
        if self.session and not self.session.finished:
            if not messagebox.askyesno('Stop bot?', 'Stop the running bot and close ChorusDraft?', parent=self.window):
                return
            self.stop()
            self.wait_to_close()
        else:
            self.window.destroy()

    def wait_to_close(self):
        if self.session.finished:
            self.window.destroy()
        else:
            self.window.after(100, self.wait_to_close)


def main():
    window = tk.Tk()
    Launcher(window)
    if '--smoke-test' in sys.argv:
        window.after(250, window.destroy)
    window.mainloop()


if __name__ == '__main__':
    main()
