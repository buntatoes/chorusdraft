const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const DAYS = 10 * 86400000;
const SECRET = [
  "BLUESKY_APP_PASSWORD",
  "MASTODON_ACCESS_TOKEN",
  "GEMINI_API_KEY",
  "OPENAI_API_KEY",
];
const common = {
  AI_PROVIDER: "local",
  LOCAL_LLM_URL: "http://localhost:11434/v1/chat/completions",
  LOCAL_LLM_MODEL: "llama3.2:3b",
  GEMINI_API_KEY: "",
  GEMINI_MODEL: "",
  OPENAI_API_KEY: "",
  OPENAI_MODEL: "",
  STATUS_LANGUAGE: "en",
};
const sites = {
  bluesky: {
    BLUESKY_PDS_URL: "https://bsky.social",
    BLUESKY_HANDLE: "",
    BLUESKY_APP_PASSWORD: "",
  },
  mastodon: {
    MASTODON_API_BASE_URL: "https://mastodon.social",
    MASTODON_ACCESS_TOKEN: "",
    STATUS_VISIBILITY: "public",
  },
};
function platform(value) {
  if (!Object.hasOwn(sites, value)) throw Error("Choose Bluesky or Mastodon.");
  return value;
}
function stat(file) {
  try {
    return fs.lstatSync(file);
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}
function regular(file) {
  const value = stat(file);
  if (value && !value.isFile()) throw Error("Storage must be a regular file.");
}
function directory(dir) {
  const value = stat(dir);
  if (value && !value.isDirectory())
    throw Error("Storage directory must not be a link.");
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  fs.chmodSync(dir, 0o700);
  return fs.realpathSync(dir);
}
// Resolve system aliases once, then reject links beneath each storage boundary.
function within(anchor, file) {
  const relative = path.relative(anchor, file);
  if (
    relative === ".." ||
    relative.startsWith(".." + path.sep) ||
    path.isAbsolute(relative)
  )
    throw Error("Invalid storage path.");
  if (!stat(anchor)?.isDirectory() || fs.realpathSync(anchor) !== anchor)
    throw Error("Storage directory must not be a link.");
  let current = anchor;
  const parts = relative.split(path.sep).filter(Boolean);
  for (let index = 0; index < parts.length; index++) {
    current = path.join(current, parts[index]);
    const value = stat(current);
    if (!value) break;
    if (
      value.isSymbolicLink() ||
      (index < parts.length - 1 && !value.isDirectory())
    )
      throw Error("Storage paths must not contain links.");
  }
  return file;
}
function write(file, data) {
  regular(file);
  const temp = file + "." + crypto.randomUUID() + ".tmp";
  try {
    fs.writeFileSync(temp, data, { mode: 0o600, flag: "wx" });
    fs.renameSync(temp, file);
  } finally {
    if (stat(temp)) fs.unlinkSync(temp);
  }
}
function validValues(site, values) {
  if (!values || Array.isArray(values) || typeof values !== "object")
    throw Error("Invalid settings.");
  const allowed = { ...common, ...sites[site] };
  for (const [key, value] of Object.entries(values)) {
    if (
      !Object.hasOwn(allowed, key) ||
      typeof value !== "string" ||
      value.length > 4096 ||
      /[\r\n\0]/.test(value)
    )
      throw Error("Invalid settings value.");
  }
  return values;
}
class Vault {
  constructor(root, dir, storage, os = process.platform) {
    this.root = fs.realpathSync(root);
    this.dir = directory(dir);
    this.storage = storage;
    this.os = os;
    this.sessions = new Map();
  }
  available() {
    try {
      return (
        this.storage.isEncryptionAvailable() &&
        (this.os !== "linux" ||
          ["gnome_libsecret", "kwallet", "kwallet5", "kwallet6"].includes(
            this.storage.getSelectedStorageBackend(),
          ))
      );
    } catch {
      return false;
    }
  }
  file(site) {
    return within(this.dir, path.join(this.dir, platform(site) + ".enc"));
  }
  envFile(site) {
    return within(
      this.root,
      path.join(this.root, "elixir", platform(site), ".env"),
    );
  }
  legacy(site) {
    const file = this.envFile(site),
      values = {};
    regular(file);
    if (!stat(file)) return values;
    const allowed = { ...common, ...sites[site] };
    for (const [index, original] of fs
      .readFileSync(file, "utf8")
      .split(/\r?\n/)
      .entries()) {
      const line = original.trim();
      if (!line || line.startsWith("#")) continue;
      const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
      if (!match)
        throw Error(
          `Invalid .env assignment at line ${index + 1}. Correct it before migrating credentials.`,
        );
      if (!Object.hasOwn(allowed, match[1]) || Object.hasOwn(values, match[1]))
        continue;
      let value = match[2].trim();
      if (
        value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))
      )
        value = value.slice(1, -1);
      values[match[1]] = value;
    }
    return validValues(site, values);
  }
  read(site) {
    platform(site);
    if (this.sessions.has(site)) return { ...this.sessions.get(site) };
    const file = this.file(site);
    regular(file);
    if (!stat(file)) return {};
    if (!this.available())
      throw Error("Unlock your system keyring to use saved credentials.");
    try {
      return validValues(
        site,
        JSON.parse(this.storage.decryptString(fs.readFileSync(file))),
      );
    } catch {
      throw Error(
        "Saved credentials could not be unlocked. Unlock the keyring or forget these settings before replacing them.",
      );
    }
  }
  values(site) {
    platform(site);
    return {
      ...common,
      ...sites[site],
      ...this.legacy(site),
      ...this.read(site),
    };
  }
  view(site) {
    platform(site);
    const legacy = this.legacy(site);
    let values,
      locked = false;
    try {
      values = this.values(site);
    } catch {
      values = { ...common, ...sites[site], ...legacy };
      locked = true;
    }
    const saved = Object.fromEntries(SECRET.map((key) => [key, !!values[key]]));
    for (const key of SECRET) delete values[key];
    return {
      values,
      saved,
      locked,
      available: this.available(),
      legacy: Object.keys(legacy).length > 0,
      mode: this.sessions.has(site)
        ? "session"
        : stat(this.file(site))
          ? "saved"
          : "unset",
    };
  }
  save(site, input, persist) {
    platform(site);
    if (!input || !Array.isArray(input.clear) || typeof persist !== "boolean")
      throw Error("Invalid settings.");
    validValues(site, input.values);
    const values = this.values(site);
    for (const [key, value] of Object.entries(input.values))
      if (!SECRET.includes(key) || value !== "") values[key] = value.trim();
    for (const key of input.clear) {
      if (!SECRET.includes(key) || !Object.hasOwn(values, key))
        throw Error("Invalid credential field.");
      values[key] = "";
    }
    if (!["local", "ollama", "gemini", "chatgpt", "openai"].includes(values.AI_PROVIDER))
      throw Error("Choose a supported AI provider.");
    if (
      site === "mastodon" &&
      !["public", "unlisted"].includes(values.STATUS_VISIBILITY)
    )
      throw Error("Choose public or unlisted visibility.");
    for (const key of [
      "BLUESKY_PDS_URL",
      "MASTODON_API_BASE_URL",
      "LOCAL_LLM_URL",
    ]) {
      if (!Object.hasOwn(values, key)) continue;
      let uri;
      try {
        uri = new URL(values[key]);
      } catch {
        throw Error("Enter a valid server URL.");
      }
      const local = ["localhost", "127.0.0.1", "[::1]"].includes(uri.hostname);
      if (
        uri.username ||
        uri.password ||
        uri.search ||
        uri.hash ||
        (uri.protocol !== "https:" &&
          !(key === "LOCAL_LLM_URL" && local && uri.protocol === "http:"))
      )
        throw Error(
          "Use HTTPS for servers. HTTP is allowed only for AI on this computer. Keep credentials out of URLs.",
        );
      if (key !== "LOCAL_LLM_URL" && uri.pathname !== "/")
        throw Error("Site server must be an HTTPS origin.");
    }
    if (persist) {
      if (!this.available())
        throw Error(
          "Secure storage is unavailable. Unlock your keyring or use session-only settings.",
        );
      try {
        write(
          this.file(site),
          this.storage.encryptString(JSON.stringify(values)),
        );
      } catch {
        throw Error(
          "Could not save credentials securely. No plaintext fallback was used.",
        );
      }
      this.sessions.delete(site);
      const file = this.envFile(site);
      try {
        regular(file);
        if (stat(file))
          write(
            file,
            fs
              .readFileSync(file, "utf8")
              .split(/\r?\n/)
              .filter(
                (line) =>
                  !Object.hasOwn(
                    values,
                    line.trim().match(/^([A-Z][A-Z0-9_]*)=/)?.[1],
                  ),
              )
              .join("\n"),
          );
      } catch {
        throw Error(
          "Settings were encrypted, but old .env credentials could not be removed. Remove those plaintext assignments before continuing.",
        );
      }
    } else this.sessions.set(site, values);
    return this.view(site);
  }
  forget(site) {
    this.sessions.delete(platform(site));
    const file = this.file(site);
    regular(file);
    if (stat(file)) fs.unlinkSync(file);
    return this.view(site);
  }
}
class Redactor {
  constructor(secrets = []) {
    this.secrets = [
      ...new Set(
        secrets
          .filter((value) => typeof value === "string" && value.length)
          .flatMap((s) => [
            s,
            encodeURIComponent(s),
            JSON.stringify(s).slice(1, -1),
          ]),
      ),
    ].sort((a, b) => b.length - a.length);
    this.tail = "";
  }
  push(chunk, final = false) {
    this.tail += chunk;
    let out = "";
    while (this.tail) {
      // Hold an ambiguous prefix until the longest overlapping secret is known.
      if (
        !final &&
        this.secrets.some(
          (s) => s.length > this.tail.length && s.startsWith(this.tail),
        )
      )
        break;
      const match = this.secrets.find((s) => this.tail.startsWith(s));
      if (match) {
        out += "[redacted]";
        this.tail = this.tail.slice(match.length);
      } else if (this.secrets.some((s) => s.startsWith(this.tail))) {
        if (final) {
          out += "[redacted]";
          this.tail = "";
        }
        break;
      } else {
        out += this.tail[0];
        this.tail = this.tail.slice(1);
      }
    }
    return out;
  }
}
class History {
  constructor(root, dir, now = Date.now) {
    this.root = fs.realpathSync(root);
    this.dir = directory(dir);
    this.now = now;
  }
  files() {
    within(this.dir, this.dir);
    return fs
      .readdirSync(this.dir)
      .filter((n) => /^\d+-(bluesky|mastodon)\.jsonl$/.test(n))
      .map((n) => ({
        name: n,
        file: within(this.dir, path.join(this.dir, n)),
        time: Number(n.split("-")[0]),
      }));
  }
  activity(file) {
    regular(file);
    return fs
      .readFileSync(file, "utf8")
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        let row;
        try {
          row = JSON.parse(line);
        } catch {
          throw Error(
            "Local activity is invalid; it has been preserved for recovery.",
          );
        }
        if (
          !row ||
          !Number.isSafeInteger(row.time) ||
          row.time < 0 ||
          typeof row.text !== "string"
        )
          throw Error(
            "Local activity is invalid; it has been preserved for recovery.",
          );
        return { time: row.time, text: row.text };
      });
  }
  prune() {
    const cutoff = this.now() - DAYS;
    let bytes = 0;
    for (const item of this.files().sort((a, b) => b.time - a.time)) {
      const rows = this.activity(item.file);
      const retained = rows.filter((row) => row.time > cutoff);
      if (!retained.length) fs.unlinkSync(item.file);
      else {
        if (retained.length !== rows.length)
          write(
            item.file,
            retained.map((row) => JSON.stringify(row) + "\n").join(""),
          );
        bytes += fs.statSync(item.file).size;
        if (bytes > 50 * 1024 * 1024) fs.unlinkSync(item.file);
      }
    }
    for (const base of [
      this.root,
      path.join(this.root, "elixir"),
      ...Object.keys(sites).map((s) => path.join(this.root, "elixir", s)),
    ]) {
      const folder = within(this.root, path.join(base, "logs"));
      if (stat(folder)?.isDirectory()) this.pruneLegacy(folder);
    }
  }
  pruneLegacy(folder) {
    within(this.root, folder);
    for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
      const file = path.join(folder, entry.name);
      if (entry.isSymbolicLink()) continue;
      within(this.root, file);
      if (entry.isDirectory()) this.pruneLegacy(file);
      else if (entry.isFile()) {
        const value = fs.lstatSync(file);
        if (
          value.isFile() &&
          Math.min(value.mtimeMs, value.birthtimeMs || value.mtimeMs) <=
            this.now() - DAYS
        )
          fs.unlinkSync(file);
      }
    }
  }
  append(site, text) {
    platform(site);
    if (!text) return;
    if (typeof text !== "string") throw Error("Invalid activity.");
    this.prune();
    const time = this.now(),
      bucket = Math.floor(time / 3600000) * 3600000;
    const file = within(
      this.dir,
      path.join(this.dir, `${bucket}-${site}.jsonl`),
    );
    regular(file);
    const fd = fs.openSync(
      file,
      fs.constants.O_WRONLY |
        fs.constants.O_APPEND |
        fs.constants.O_CREAT |
        (fs.constants.O_NOFOLLOW || 0),
      0o600,
    );
    try {
      if (!fs.fstatSync(fd).isFile())
        throw Error("Storage must be a regular file.");
      fs.fchmodSync(fd, 0o600);
      fs.writeSync(fd, JSON.stringify({ time, text }) + "\n");
    } finally {
      fs.closeSync(fd);
    }
  }
  list(site, { kind = "posts", query = "", offset = 0 } = {}) {
    platform(site);
    if (
      !["posts", "activity"].includes(kind) ||
      typeof query !== "string" ||
      query.length > 300 ||
      !Number.isInteger(offset) ||
      offset < 0
    )
      throw Error("Invalid history filter.");
    this.prune();
    const now = this.now();
    let items = [];
    if (kind === "activity") {
      for (const item of this.files()) {
        if (!item.name.endsWith(`-${site}.jsonl`)) continue;
        for (const [index, row] of this.activity(item.file).entries())
          if (row.time > now - DAYS && row.time <= now)
            items.push({ ...row, id: item.name + index });
      }
    } else {
      const data = within(
        this.root,
        path.join(this.root, "elixir", site, "data"),
      );
      if (stat(data)) {
        if (!fs.lstatSync(data).isDirectory())
          throw Error("Invalid history directory.");
        for (const entry of fs.readdirSync(data, { withFileTypes: true })) {
          if (!entry.isDirectory() || !/^[a-f0-9]{24}$/.test(entry.name))
            continue;
          const file = within(
            this.root,
            path.join(data, entry.name, "state.json"),
          );
          regular(file);
          if (!stat(file)) continue;
          const state = JSON.parse(fs.readFileSync(file, "utf8"));
          if (!state || !Array.isArray(state.drafts))
            throw Error("Invalid history file.");
          for (const draft of state.drafts) {
            if (!draft || typeof draft !== "object")
              throw Error("Invalid history file.");
            const time = Date.parse(draft.finished_at || draft.created_at);
            if (
              draft.status === "published" &&
              time > now - DAYS &&
              time <= now &&
              typeof draft.text === "string"
            )
              items.push({
                id: draft.id,
                time,
                text: draft.text,
                account: typeof draft.account === "string" ? draft.account : "",
                action:
                  typeof draft.action === "string" ? draft.action : "post",
                cw: typeof draft.cw === "string" ? draft.cw : "",
              });
          }
        }
      }
    }
    items = items
      .filter((item) =>
        (item.text + " " + (item.account || ""))
          .toLowerCase()
          .includes(query.toLowerCase()),
      )
      .sort(
        (a, b) => b.time - a.time || String(a.id).localeCompare(String(b.id)),
      );
    return { items: items.slice(offset, offset + 50), total: items.length };
  }
}
module.exports = { Vault, History, Redactor, SECRET, DAYS };
