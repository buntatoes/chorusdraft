const {
  app,
  BrowserWindow,
  ipcMain,
  dialog,
  safeStorage,
  clipboard,
  powerMonitor,
} = require("electron");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");
const os = require("node:os");
const { Vault, History, Redactor, SECRET } = require("./privacy.cjs");
const localData =
  !app.isPackaged && process.env.CHORUSDRAFT_USER_DATA
    ? process.env.CHORUSDRAFT_USER_DATA
    : process.platform === "win32"
      ? path.join(
          process.env.LOCALAPPDATA ||
            path.join(os.homedir(), "AppData", "Local"),
          "ChorusDraft",
        )
      : process.platform === "darwin"
        ? path.join(
            os.homedir(),
            "Library",
            "Application Support",
            "ChorusDraft",
          )
        : path.join(
            process.env.XDG_STATE_HOME ||
              path.join(os.homedir(), ".local", "state"),
            "chorusdraft",
          );
app.setPath("userData", localData);
app.commandLine.appendSwitch("disable-logging");
let vault,
  history,
  currentSite,
  redactor = new Redactor(),
  maintenanceFailures = [];
function output(text) {
  if (!text) return;
  if (currentSite)
    try {
      history.append(currentSite, text);
    } catch {
      emit({
        type: "notice",
        value: "Local activity could not be saved. Check storage permissions.",
      });
    }
  emit({ type: "output", value: text });
}

let window,
  bridge,
  running = false,
  closing = false,
  root;
const smoke = process.argv.includes("--smoke-test");
function selection(request) {
  if (
    !request ||
    request.runtime !== "elixir" ||
    !["bluesky", "mastodon"].includes(request.platform)
  ) {
    throw new Error("Choose a valid bot.");
  }
  return request;
}
// One request per line; the bridge reads lines of at most 64 KiB.
const REQUEST_LIMIT = 65536;
// One response per line; never buffer more than 1 MiB of a single bridge line.
const RESPONSE_LIMIT = 1048576;
// Anything the bot reads as a line; tabs are the only control allowed.
const CONTROL = /[\x00-\x08\x0a-\x1f\x7f]/;
function send(request) {
  if (!bridge || bridge.killed || !bridge.stdin.writable)
    throw new Error("The bot service is unavailable. Reopen ChorusDraft.");
  const line = JSON.stringify(request) + "\n";
  if (Buffer.byteLength(line) > REQUEST_LIMIT)
    throw new Error("The request is too large to send.");
  bridge.stdin.write(line);
}
function validText(text, limit) {
  return (
    typeof text === "string" &&
    text.trim() !== "" &&
    text.length <= limit &&
    !/\0/.test(text)
  );
}
function validDraft(text, limit) {
  return validText(text, limit) && !/[\x00-\x08\x0b-\x1f\x7f]/.test(text);
}
function validId(id) {
  return (
    typeof id === "string" &&
    id.trim() !== "" &&
    id.length <= 80 &&
    !CONTROL.test(id)
  );
}
function validPostId(platform, id) {
  if (
    typeof id !== "string" ||
    id.trim() === "" ||
    id.length > 512 ||
    CONTROL.test(id) ||
    /\s/.test(id) ||
    id.startsWith("--")
  )
    return false;
  if (platform === "bluesky")
    return /^at:\/\/[^/\s]+\/app\.bsky\.feed\.post\/[a-zA-Z0-9._~:-]+$/.test(id);
  if (platform === "mastodon") return /^\d+$/.test(id);
  return false;
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
    env: Object.fromEntries(
      Object.entries(process.env).filter(([key]) => !SECRET.includes(key)),
    ),
    stdio: ["pipe", "pipe", "pipe"],
  });
  // readline buffers a line without bound; refuse to grow memory for a
  // bridge that stops terminating its messages.
  let buffered = 0;
  bridge.stdout.on("data", (chunk) => {
    const newline = chunk.lastIndexOf(0x0a);
    buffered =
      newline === -1 ? buffered + chunk.length : chunk.length - newline - 1;
    if (buffered > RESPONSE_LIMIT) {
      bridge.stdout.destroy();
      emit({
        type: "error",
        value: "The bot service returned an oversized response.",
        active: running,
      });
    }
  });
  readline.createInterface({ input: bridge.stdout }).on("line", (line) => {
    try {
      const message = JSON.parse(line);
      if (message.type === "started") running = true;
      if (message.type === "exit") running = false;
      if (message.type === "error") running = Boolean(message.active);
      if (message.type === "output") output(redactor.push(message.value));
      else if (["exit", "error"].includes(message.type)) {
        output(redactor.push("", true));
        if (message.type === "error")
          message.value = redactor.push(message.value, true);
        emit(message);
      } else if (message.type === "maintenance") {
        maintenanceFailures = message.failures;
        emit({ type: "history-updated" });
      } else emit(message);
    } catch {
      emit({
        type: "error",
        value: "The bot service returned an invalid response.",
        active: running,
      });
    }
  });
  bridge.stderr.on("data", () => {}); // Bot output travels through the structured terminal channel.
  bridge.on("error", () => {
    running = false;
    emit({
      type: "error",
      value: "The bot service could not start. Check the desktop installation.",
      active: false,
    });
  });
  bridge.on("exit", () => {
    running = false;
    if (closing) app.exit(0);
    else
      emit({
        type: "error",
        value: "The bot service stopped. Reopen ChorusDraft to continue.",
        active: false,
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
    vault = new Vault(root, path.join(localData, "credentials"), safeStorage);
    history = new History(root, path.join(localData, "activity"));
    const cleanup = () => {
      try {
        history.prune();
      } catch {
        emit({
          type: "notice",
          value:
            "Local log cleanup needs attention. Check storage permissions.",
        });
      }
      emit({ type: "history-updated" });
    };
    cleanup();
    setInterval(cleanup, 60000).unref();
    powerMonitor.on("resume", cleanup);
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
        partition: "chorusdraft-ui",
        spellcheck: false,
      },
    });
    window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
    window.webContents.on("will-navigate", (event) => event.preventDefault());
    // The UI requests no web permissions; deny every one by default.
    window.webContents.session.setPermissionRequestHandler(
      (_webContents, _permission, callback) => callback(false),
    );
    window.webContents.session.setPermissionCheckHandler(() => false);
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
        "automatic",
        "listen",
        "replies",
        "search",
        "post",
        "reply",
        "quote",
        "help",
        "version",
        "status",
        "reject",
        "edit",
        "discover",
        "targets",
        "delete",
      ];
      if (!actions.includes(request.action) || running)
        throw new Error("Choose an action after the current session ends.");
      if (
        ["search", "post", "reply", "quote"].includes(request.action) &&
        !validText(request.text, 10000)
      )
        throw new Error("Enter text for this action (maximum 10,000 characters).");
      if (
        ["reply", "quote"].includes(request.action) &&
        !validPostId(request.platform, request.target)
      )
        throw new Error("Enter a reply or quote target.");
      const cw =
        ["post", "reply", "quote"].includes(request.action) &&
        typeof request.cw === "string" &&
        request.cw.trim()
          ? request.cw
          : undefined;
      if (cw) {
        if (request.platform === "bluesky")
          throw new Error("Content warnings are supported only for Mastodon.");
        if (!validText(cw, 500))
          throw new Error(
            "Enter a content warning (maximum 500 characters).",
          );
      }
      if (
        ["discover", "targets"].includes(request.action) &&
        request.text != null &&
        String(request.text).trim() !== "" &&
        !validText(request.text, 10000)
      )
        throw new Error("Enter text for this action (maximum 10,000 characters).");
      if (request.action === "delete" && !validPostId(request.platform, request.text))
        throw new Error("Choose a post to delete.");
      if (request.action === "reject" && !validId(request.text))
        throw new Error("Choose a pending or uncertain draft to reject.");
      if (
        request.action === "edit" &&
        (!validId(request.target) || !validDraft(request.text, 10000))
      )
        throw new Error(
          "Enter replacement text for a pending draft (maximum 10,000 characters).",
        );
      const environment = ["setup", "help", "version"].includes(request.action)
        ? {}
        : vault.values(request.platform);
      currentSite = request.platform;
      redactor = new Redactor(SECRET.map((key) => environment[key]));
      running = true;
      try {
        send({
          environment,
          type: "run",
          runtime: request.runtime,
          platform: request.platform,
          action: request.action,
          text: request.text,
          target: request.target,
          cw,
        });
      } catch (error) {
        running = false;
        throw error;
      }
    });
    handle("bot:input", (payload) => {
      if (!running) throw new Error("The bot session has already ended.");
      if (typeof payload === "string") payload = { text: payload };
      if (!payload || typeof payload !== "object")
        throw new Error("Enter one response at a time.");
      const action = payload.action;
      const text = payload.text;
      if (action) {
        if (!["approve", "reject", "quit", "skip", "edit"].includes(action))
          throw new Error("Enter one response at a time.");
        if (action === "edit" && !validDraft(text, 10000))
          throw new Error(
            "Enter replacement text for a pending draft (maximum 10,000 characters).",
          );
        send({ type: "input", action, text });
        return;
      }
      if (typeof text !== "string" || text.length > 20000 || CONTROL.test(text))
        throw new Error("Enter one response at a time.");
      send({ type: "input", text });
    });
    handle("bot:stop", () => send({ type: "stop" }));
    handle("bot:settings", (request) =>
      vault.view(selection(request).platform),
    );
    handle("bot:save-settings", (request, input, persist) => {
      if (running) throw Error("Stop the bot before changing credentials.");
      return vault.save(selection(request).platform, input, persist);
    });
    handle("bot:forget-settings", (request) => {
      if (running) throw Error("Stop the bot before removing credentials.");
      return vault.forget(selection(request).platform);
    });
    handle("bot:history", (request, filter) => ({
      ...history.list(selection(request).platform, filter),
      failures: maintenanceFailures,
    }));
    handle("bot:queue", (request) =>
      history.queue(selection(request).platform),
    );
    handle("bot:copy", (text) => {
      if (typeof text !== "string" || text.length > 10000)
        throw Error("Invalid post text.");
      clipboard.writeText(text);
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
      if (bridge && !bridge.killed && bridge.stdin.writable) {
        send({ type: "quit" });
        // The bridge should exit on quit or stdin EOF; do not let a wedged
        // process keep the app open.
        const kill = setTimeout(() => {
          if (bridge.exitCode === null) bridge.kill("SIGTERM");
        }, 3000);
        kill.unref();
        bridge.once("exit", () => clearTimeout(kill));
      } else app.quit();
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
          for (const runtime of ['elixir']) {
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
