const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("chorus", {
  info: () => ipcRenderer.invoke("bot:info"),
  run: (request) => ipcRenderer.invoke("bot:run", request),
  respond: (text) => ipcRenderer.invoke("bot:input", text),
  stop: () => ipcRenderer.invoke("bot:stop"),
  configure: (selection) => ipcRenderer.invoke("bot:configure", selection),
  onEvent: (callback) => {
    const listener = (_event, message) => callback(message);
    ipcRenderer.on("bot:event", listener);
    return () => ipcRenderer.removeListener("bot:event", listener);
  },
});
