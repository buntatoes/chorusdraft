const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { Vault, History, Redactor, DAYS } = require("../electron/privacy.cjs");
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "chorusdraft privacy "));
  for (const site of ["bluesky", "mastodon"])
    fs.mkdirSync(path.join(root, "elixir", site), { recursive: true });
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}
function protectedStorage(backend = "gnome_libsecret") {
  const key = crypto.randomBytes(32);
  return {
    isEncryptionAvailable: () => true,
    getSelectedStorageBackend: () => backend,
    encryptString(value) {
      const iv = crypto.randomBytes(12);
      const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
      const ciphertext = Buffer.concat([
        cipher.update(value, "utf8"),
        cipher.final(),
      ]);
      return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
    },
    decryptString(value) {
      const cipher = crypto.createDecipheriv(
        "aes-256-gcm",
        key,
        value.subarray(0, 12),
      );
      cipher.setAuthTag(value.subarray(12, 28));
      return Buffer.concat([
        cipher.update(value.subarray(28)),
        cipher.final(),
      ]).toString("utf8");
    },
  };
}
const input = (values) => ({ values, clear: [] });
test("OpenAI credentials use protected storage and remain masked", (t) => {
  const root = fixture(t);
  const vault = new Vault(root, path.join(root, "credentials"), protectedStorage(), "linux");
  vault.save("bluesky", input({
    AI_PROVIDER: "chatgpt", OPENAI_MODEL: "fixture-model",
    OPENAI_API_KEY: "synthetic-openai-secret"
  }), true);
  assert.equal(vault.values("bluesky").OPENAI_API_KEY, "synthetic-openai-secret");
  const info = vault.view("bluesky");
  assert.equal(info.values.OPENAI_API_KEY, undefined);
  assert.equal(info.saved.OPENAI_API_KEY, true);
});
test("secure persistence migrates all supported plaintext assignments and never returns credentials", (t) => {
  const root = fixture(t),
    dir = path.join(root, "credentials"),
    storage = protectedStorage();
  const file = path.join(root, "elixir", "bluesky", ".env");
  fs.writeFileSync(
    file,
    '# Keep operating preferences\nBLUESKY_HANDLE=account.example\nBLUESKY_APP_PASSWORD="synthetic app secret"\nBLUESKY_APP_PASSWORD=ignored-duplicate\nMAX_DRAFTS=5\n',
  );
  const vault = new Vault(root, dir, storage, "linux");
  assert.equal(
    vault.values("bluesky").BLUESKY_APP_PASSWORD,
    "synthetic app secret",
  );
  assert.equal(vault.view("bluesky").values.BLUESKY_APP_PASSWORD, undefined);
  const view = vault.save("bluesky", input({}), true);
  assert.equal(view.mode, "saved");
  assert.equal(view.saved.BLUESKY_APP_PASSWORD, true);
  assert.equal(view.legacy, false);
  assert.ok(!JSON.stringify(view).includes("synthetic app secret"));
  const onDisk = fs.readFileSync(path.join(dir, "bluesky.enc"));
  assert.ok(!onDisk.includes(Buffer.from("synthetic app secret")));
  assert.equal(
    fs.readFileSync(file, "utf8"),
    "# Keep operating preferences\nMAX_DRAFTS=5\n",
  );
  assert.equal(
    new Vault(root, dir, storage, "linux").values("bluesky")
      .BLUESKY_APP_PASSWORD,
    "synthetic app secret",
  );
  if (process.platform !== "win32")
    assert.equal(
      fs.statSync(path.join(dir, "bluesky.enc")).mode & 0o777,
      0o600,
    );
});
test("Linux plaintext and unknown storage backends fail closed while session-only credentials stay in memory", (t) => {
  const root = fixture(t),
    dir = path.join(root, "credentials");
  for (const backend of ["basic_text", "unknown"]) {
    const vault = new Vault(root, dir, protectedStorage(backend), "linux");
    assert.throws(
      () =>
        vault.save(
          "mastodon",
          input({ MASTODON_ACCESS_TOKEN: "synthetic-token" }),
          true,
        ),
      /Secure storage is unavailable/,
    );
    assert.deepEqual(fs.readdirSync(dir), []);
    assert.equal(
      vault.save(
        "mastodon",
        input({ MASTODON_ACCESS_TOKEN: "synthetic-token" }),
        false,
      ).mode,
      "session",
    );
    assert.equal(
      vault.values("mastodon").MASTODON_ACCESS_TOKEN,
      "synthetic-token",
    );
    assert.deepEqual(fs.readdirSync(dir), []);
    assert.equal(
      new Vault(root, dir, protectedStorage(backend), "linux").values(
        "mastodon",
      ).MASTODON_ACCESS_TOKEN,
      "",
    );
  }
});
test("locked or malformed encrypted settings are never silently replaced", (t) => {
  const root = fixture(t),
    dir = path.join(root, "credentials"),
    storage = protectedStorage();
  const vault = new Vault(root, dir, storage, "linux");
  vault.save(
    "mastodon",
    input({ MASTODON_ACCESS_TOKEN: "synthetic-token" }),
    true,
  );
  const file = path.join(dir, "mastodon.enc"),
    original = fs.readFileSync(file);
  const locked = new Vault(root, dir, protectedStorage("basic_text"), "linux");
  assert.equal(locked.view("mastodon").locked, true);
  assert.throws(
    () =>
      locked.save(
        "mastodon",
        input({ MASTODON_ACCESS_TOKEN: "replacement" }),
        true,
      ),
    /keyring/,
  );
  assert.deepEqual(fs.readFileSync(file), original);
  fs.writeFileSync(
    file,
    storage.encryptString('{"unexpected_secret":"synthetic-token"}'),
  );
  const malformed = fs.readFileSync(file);
  assert.equal(vault.view("mastodon").locked, true);
  assert.throws(
    () => vault.save("mastodon", input({}), true),
    /could not be unlocked/,
  );
  assert.deepEqual(fs.readFileSync(file), malformed);
  assert.ok(
    !JSON.stringify(vault.view("mastodon")).includes("synthetic-token"),
  );
});
test("malformed legacy assignments prevent a misleading successful migration", (t) => {
  const root = fixture(t),
    file = path.join(root, "elixir", "bluesky", ".env");
  const original = "export BLUESKY_APP_PASSWORD=synthetic-secret\n";
  fs.writeFileSync(file, original);
  const vault = new Vault(
    root,
    path.join(root, "credentials"),
    protectedStorage(),
    "linux",
  );
  assert.throws(
    () => vault.save("bluesky", input({}), true),
    /Invalid .env assignment at line 1/,
  );
  assert.equal(fs.readFileSync(file, "utf8"), original);
  assert.deepEqual(fs.readdirSync(path.join(root, "credentials")), []);
});
test("secret omission preserves credentials, explicit clearing removes them, and unsafe settings are rejected", (t) => {
  const root = fixture(t),
    vault = new Vault(
      root,
      path.join(root, "credentials"),
      protectedStorage(),
      "linux",
    );
  vault.save(
    "mastodon",
    input({ MASTODON_ACCESS_TOKEN: "synthetic-token" }),
    true,
  );
  vault.save("mastodon", input({ MASTODON_ACCESS_TOKEN: "" }), true);
  assert.equal(
    vault.values("mastodon").MASTODON_ACCESS_TOKEN,
    "synthetic-token",
  );
  for (const values of [
    { MASTODON_API_BASE_URL: "http://social.example" },
    { MASTODON_API_BASE_URL: "https://user:password@social.example" },
    { MASTODON_API_BASE_URL: "https://social.example/?token=x" },
    { MASTODON_API_BASE_URL: "https://social.example/api" },
    { LOCAL_LLM_URL: "http://ai.example" },
    { MASTODON_ACCESS_TOKEN: "token\nOTHER=value" },
    { PATH: "/tmp/custom" },
  ])
    assert.throws(() => vault.save("mastodon", input(values), true));
  vault.save(
    "mastodon",
    { values: {}, clear: ["MASTODON_ACCESS_TOKEN"] },
    true,
  );
  assert.equal(vault.values("mastodon").MASTODON_ACCESS_TOKEN, "");
});
test("redaction handles every chunk boundary, encoded forms, and overlapping secrets", () => {
  const secret = 'synthetic secret/"value';
  const text = `before ${secret} between ${encodeURIComponent(secret)} then ${JSON.stringify(secret).slice(1, -1)} after`;
  for (let index = 0; index <= text.length; index++) {
    const redactor = new Redactor([secret]);
    assert.equal(
      redactor.push(text.slice(0, index)) +
        redactor.push(text.slice(index)) +
        redactor.push("", true),
      "before [redacted] between [redacted] then [redacted] after",
    );
  }
  const redactor = new Redactor(["short", "short-with-private-suffix"]);
  assert.equal(redactor.push("start short"), "start ");
  assert.equal(
    redactor.push("-with-private-suffix end", true),
    "[redacted] end",
  );
  const partial = new Redactor(["synthetic-secret"]);
  assert.equal(
    partial.push("start synthe") + partial.push("", true),
    "start [redacted]",
  );
});
test("activity retention uses event timestamps at the exact ten-day boundary, including shared hourly files", (t) => {
  const root = fixture(t),
    dir = path.join(root, "activity");
  const now = Date.UTC(2026, 8, 6, 12, 30),
    cutoff = now - DAYS;
  const history = new History(root, dir, () => now);
  const file = path.join(
    dir,
    `${Math.floor(cutoff / 3600000) * 3600000}-bluesky.jsonl`,
  );
  fs.writeFileSync(
    file,
    [
      { time: cutoff - 1, text: "expired" },
      { time: cutoff, text: "at cutoff" },
      { time: cutoff + 1, text: "still retained" },
    ]
      .map((row) => JSON.stringify(row))
      .join("\n") + "\n",
  );
  assert.deepEqual(
    history.list("bluesky", { kind: "activity" }).items.map((row) => row.text),
    ["still retained"],
  );
  assert.ok(!fs.readFileSync(file, "utf8").includes("expired"));
  assert.ok(!fs.readFileSync(file, "utf8").includes("at cutoff"));
  history.append("mastodon", "other platform");
  assert.equal(history.list("bluesky", { kind: "activity" }).total, 1);
  assert.equal(history.list("mastodon", { kind: "activity" }).total, 1);
});
test("history exposes only recent published drafts and never edits pending, uncertain, or corrupt posting state", (t) => {
  const root = fixture(t),
    now = Date.UTC(2026, 8, 6),
    dir = path.join(root, "elixir", "bluesky", "data", "a".repeat(24));
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, "state.json");
  const drafts = [
    "pending",
    "publishing",
    "uncertain",
    "rejected",
    "published",
  ].map((status) => ({
    id: status,
    status,
    text: status,
    finished_at: new Date(now - 1000).toISOString(),
  }));
  drafts.push({
    id: "expired",
    status: "published",
    text: "expired",
    finished_at: new Date(now - DAYS).toISOString(),
  });
  const original = JSON.stringify({
    drafts,
    seen: ["keep"],
    blocked: ["keep"],
  });
  fs.writeFileSync(file, original);
  const history = new History(root, path.join(root, "activity"), () => now);
  assert.deepEqual(
    history.list("bluesky").items.map((row) => row.text),
    ["published"],
  );
  assert.equal(fs.readFileSync(file, "utf8"), original);
  fs.writeFileSync(file, "{broken state");
  assert.throws(() => history.list("bluesky"));
  assert.equal(fs.readFileSync(file, "utf8"), "{broken state");
  const activity = path.join(
    root,
    "activity",
    `${now - DAYS - 1}-bluesky.jsonl`,
  );
  fs.writeFileSync(activity, "{broken activity\n");
  assert.throws(() => history.prune(), /preserved for recovery/);
  assert.equal(fs.readFileSync(activity, "utf8"), "{broken activity\n");
});
test("queue lists unresolved drafts and automatic budget without writing state", (t) => {
  const root = fixture(t),
    now = Date.UTC(2026, 8, 8, 12),
    dir = path.join(root, "elixir", "bluesky", "data", "b".repeat(24));
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, "state.json");
  const original = JSON.stringify({
    drafts: [
      {
        id: "pending-id",
        status: "pending",
        text: "hold for review",
        action: "manual",
        created_at: new Date(now - 1000).toISOString(),
      },
      {
        id: "uncertain-id",
        status: "uncertain",
        text: "check the account",
        created_at: new Date(now - 2000).toISOString(),
      },
      {
        id: "published-id",
        status: "published",
        text: "already live",
        finished_at: new Date(now - 1000).toISOString(),
      },
    ],
    automatic: [Math.floor(now / 1000) - 60, Math.floor(now / 1000) - 90000],
  });
  fs.writeFileSync(file, original);
  const history = new History(root, path.join(root, "activity"), () => now);
  const queue = history.queue("bluesky");
  assert.deepEqual(
    queue.items.map((row) => row.id),
    ["uncertain-id", "pending-id"],
  );
  assert.equal(queue.automatic.limit, 5);
  assert.equal(queue.automatic.used, 1);
  assert.equal(queue.automatic.remaining, 4);
  assert.equal(queue.automatic.frozen, true);
  assert.equal(fs.readFileSync(file, "utf8"), original);
});
test(
  "filesystem links cannot redirect credentials, activity, or legacy cleanup outside their boundaries",
  {
    skip:
      process.platform === "win32"
        ? "Creating symlinks requires privileges on Windows."
        : false,
  },
  (t) => {
    const root = fixture(t),
      outside = fs.mkdtempSync(path.join(os.tmpdir(), "chorusdraft outside "));
    t.after(() => fs.rmSync(outside, { recursive: true, force: true }));
    const untouched = path.join(outside, "keep.log");
    fs.writeFileSync(untouched, "must survive");
    fs.utimesSync(untouched, new Date(0), new Date(0));
    const vault = new Vault(
      root,
      path.join(root, "credentials"),
      protectedStorage(),
      "linux",
    );
    fs.symlinkSync(
      path.join(outside, "not-created"),
      path.join(root, "credentials", "bluesky.enc"),
    );
    assert.throws(
      () =>
        vault.save("bluesky", input({ BLUESKY_APP_PASSWORD: "secret" }), true),
      /links/,
    );
    assert.ok(!fs.existsSync(path.join(outside, "not-created")));
    const history = new History(root, path.join(root, "activity"));
    fs.mkdirSync(path.join(root, "logs"));
    fs.symlinkSync(outside, path.join(root, "logs", "external"));
    history.prune();
    assert.equal(fs.readFileSync(untouched, "utf8"), "must survive");
    fs.renameSync(
      path.join(root, "elixir"),
      path.join(root, "elixir-original"),
    );
    fs.symlinkSync(outside, path.join(root, "elixir"));
    assert.throws(() => history.prune(), /links/);
    assert.throws(() => vault.legacy("mastodon"), /links/);
    assert.equal(fs.readFileSync(untouched, "utf8"), "must survive");
  },
);
