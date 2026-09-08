const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("chorus", {
  info: () => ipcRenderer.invoke("bot:info"),
  run: (request) => ipcRenderer.invoke("bot:run", request),
  respond: (text) => ipcRenderer.invoke("bot:input", text),
  stop: () => ipcRenderer.invoke("bot:stop"),
  settings: (selection) => ipcRenderer.invoke("bot:settings", selection),
  saveSettings: (selection, input, persist) =>
    ipcRenderer.invoke("bot:save-settings", selection, input, persist),
  forgetSettings: (selection) =>
    ipcRenderer.invoke("bot:forget-settings", selection),
  history: (selection, filter) =>
    ipcRenderer.invoke("bot:history", selection, filter),
  queue: (selection) => ipcRenderer.invoke("bot:queue", selection),
  copy: (text) => ipcRenderer.invoke("bot:copy", text),
  onEvent: (callback) => {
    const listener = (_event, message) => callback(message);
    ipcRenderer.on("bot:event", listener);
    return () => ipcRenderer.removeListener("bot:event", listener);
  },
});
