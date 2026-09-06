const { app, BrowserWindow, ipcMain, dialog, shell } = require("electron");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

let window,
  bridge,
  running = false,
  closing = false,
  root;
const smoke = process.argv.includes("--smoke-test");
function selection(request) {
  if (
    !request ||
    !["ruby", "elixir"].includes(request.runtime) ||
    !["bluesky", "mastodon"].includes(request.platform)
  ) {
    throw new Error("Choose a valid bot.");
  }
  return request;
}
function send(request) {
  if (!bridge || bridge.killed || !bridge.stdin.writable)
    throw new Error("The bot service is unavailable. Reopen ChorusDraft.");
  bridge.stdin.write(JSON.stringify(request) + "\n");
}
function emit(message) {
  if (window && !window.isDestroyed())
    window.webContents.send("bot:event", message);
}
function trusted(event) {
  if (
    !window ||
    event.sender !== window.webContents ||
    event.senderFrame !== window.webContents.mainFrame
  ) {
    throw new Error("Unsupported sender.");
  }
}
function handle(channel, callback) {
  ipcMain.handle(channel, (event, ...args) => {
    trusted(event);
    return callback(...args);
  });
}
function startBridge() {
  const frozen = path.join(
    process.resourcesPath,
    "backend",
    process.platform === "win32" ? "chorus-bridge.exe" : "chorus-bridge",
  );
  const command = app.isPackaged
    ? frozen
    : process.env.CHORUSDRAFT_PYTHON ||
      (process.platform === "win32" ? "python" : "python3");
  const args = app.isPackaged
    ? [root]
    : [path.resolve(__dirname, "../../launcher/bridge.py"), root];
  bridge = spawn(command, args, {
    cwd: root,
    windowsHide: true,
    stdio: ["pipe", "pipe", "pipe"],
  });
  readline.createInterface({ input: bridge.stdout }).on("line", (line) => {
    try {
      const message = JSON.parse(line);
      if (message.type === "started") running = true;
      if (message.type === "exit") running = false;
      if (message.type === "error") running = Boolean(message.active);
      emit(message);
    } catch {
      emit({
        type: "error",
        value: "The bot service returned an invalid response.",
      });
    }
  });
  bridge.stderr.on("data", () => {}); // Bot output travels through the structured terminal channel.
  bridge.on("error", () =>
    emit({
      type: "error",
      value: "The bot service could not start. Check the desktop installation.",
    }),
  );
  bridge.on("exit", () => {
    running = false;
    if (closing) app.exit(0);
    else
      emit({
        type: "error",
        value: "The bot service stopped. Reopen ChorusDraft to continue.",
      });
  });
}
app
  .whenReady()
  .then(async () => {
    root = app.isPackaged
      ? process.platform === "darwin"
        ? path.resolve(process.resourcesPath, "../../..")
        : path.resolve(process.resourcesPath, "../..")
      : path.resolve(
          process.env.CHORUSDRAFT_ROOT || path.resolve(__dirname, "../.."),
        );
    window = new BrowserWindow({
      width: 1220,
      height: 900,
      minWidth: 1000,
      minHeight: 740,
      backgroundColor: "#f7f8fb",
      title: "ChorusDraft",
      autoHideMenuBar: true,
      webPreferences: {
        preload: path.join(__dirname, "preload.cjs"),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
      },
    });
    window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
    window.webContents.on("will-navigate", (event) => event.preventDefault());
    handle("bot:info", () => ({
      version: fs.readFileSync(path.join(root, "VERSION"), "utf8").trim(),
    }));
    handle("bot:run", (request) => {
      selection(request);
      const actions = [
        "setup",
        "draft",
        "review",
        "start",
        "listen",
        "replies",
        "search",
        "post",
        "help",
        "version",
      ];
      if (!actions.includes(request.action) || running)
        throw new Error("Choose an action after the current session ends.");
      send({
        type: "run",
        runtime: request.runtime,
        platform: request.platform,
        action: request.action,
        text: request.text,
      });
    });
    handle("bot:input", (text) => {
      if (
        typeof text !== "string" ||
        text.length > 10000 ||
        /[\r\n\0]/.test(text)
      )
        throw new Error("Enter one response at a time.");
      send({ type: "input", text });
    });
    handle("bot:stop", () => send({ type: "stop" }));
    handle("bot:configure", async (request) => {
      selection(request);
      if (running)
        throw new Error(
          "Stop the active session before editing configuration.",
        );
      const file = path.join(
        root,
        ...(request.runtime === "elixir" ? ["elixir"] : []),
        request.platform,
        ".env",
      );
      if (!fs.existsSync(file))
        throw new Error(
          "Choose Set up first to create this bot’s configuration.",
        );
      if (process.platform === "win32") {
        spawn("notepad.exe", [file], { windowsHide: false }).on("error", () =>
          emit({
            type: "error",
            value: "Could not open the configuration editor.",
          }),
        );
      } else if (process.platform === "darwin") {
        spawn("open", ["-t", file]).on("error", () =>
          emit({
            type: "error",
            value: "Could not open the configuration editor.",
          }),
        );
      } else {
        const error = await shell.openPath(file);
        if (error)
          throw new Error(
            "Could not open the configuration editor. Open the bot’s .env in a text editor.",
          );
      }
    });
    startBridge();
    window.on("close", async (event) => {
      if (closing) return;
      event.preventDefault();
      if (running) {
        const result = await dialog.showMessageBox(window, {
          type: "question",
          buttons: ["Keep open", "Stop and close"],
          defaultId: 0,
          cancelId: 0,
          message: "Stop the running bot?",
          detail: "The active session will stop before ChorusDraft closes.",
        });
        if (result.response !== 1) return;
      }
      closing = true;
      if (bridge && !bridge.killed && bridge.stdin.writable)
        send({ type: "quit" });
      else app.quit();
    });
    await window.loadFile(path.join(__dirname, "../dist/index.html"));
    if (smoke) {
      const rendered = await window.webContents.executeJavaScript(
        'new Promise(resolve => requestAnimationFrame(() => resolve(document.body.textContent.includes("Your bot workspace"))))',
      );
      if (!rendered) app.exit(1);
      else {
        await window.webContents.executeJavaScript(`(async () => {
          const info = await window.chorus.info();
          for (const runtime of ['ruby', 'elixir']) {
            for (const platform of ['bluesky', 'mastodon']) {
              await new Promise((resolve, reject) => {
                let output = '';
                const timer = setTimeout(() => { unsubscribe(); reject(new Error('Bot version check timed out')); }, 20000);
                const finish = error => { clearTimeout(timer); unsubscribe(); error ? reject(error) : resolve(); };
                const unsubscribe = window.chorus.onEvent(event => {
                  if (event.type === 'output') output += event.value;
                  if (event.type === 'error') finish(new Error(event.value));
                  if (event.type === 'exit') finish(event.value === 0 && output.includes(info.version) ? null : new Error(runtime + '/' + platform + ': ' + output));
                });
                window.chorus.run({runtime, platform, action: 'version'}).catch(finish);
              });
            }
          }
        })()`);
        window.close();
      }
    }
  })
  .catch((error) => {
    console.error(error);
    app.exit(1);
  });
app.on("window-all-closed", () => app.quit());
