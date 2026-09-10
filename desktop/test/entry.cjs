// Playwright's loader forces Chromium's basic password store. Override it before
// app readiness so Linux integration tests exercise the isolated real keyring.
const { app } = require("electron");
if (process.env.CHORUSDRAFT_TEST_KEYRING) {
  app.commandLine.appendSwitch("password-store", "gnome-libsecret");
}
if (process.platform === "darwin") app.commandLine.removeSwitch("use-mock-keychain");
require("../electron/main.cjs");
