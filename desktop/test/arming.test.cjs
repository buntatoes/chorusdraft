const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createPrompts } = require("../electron/arming.cjs");

const draft = { id: "11111111-2222-4333-8444-555555555555", text: "Hello" };

test("approve is armed only by a review event with draft text", () => {
  const prompts = createPrompts();
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "output", value: "Publish this exact draft?" });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review" });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft: { id: "1" } });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft });
  assert.equal(prompts.allow("quit"), true);
  assert.equal(prompts.allow("approve"), true);
  assert.equal(prompts.allow("approve"), false);
});

test("edit, reject, and skip consume the review prompt", () => {
  const prompts = createPrompts();
  prompts.onEvent({ type: "review", draft });
  assert.equal(prompts.allow("edit"), true);
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft });
  assert.equal(prompts.allow("reject"), true);
  assert.equal(prompts.allow("skip"), false);
  prompts.onEvent({ type: "review", draft });
  assert.equal(prompts.allow("skip"), true);
});

test("delete approve is armed only by a confirm event with an id", () => {
  const prompts = createPrompts();
  prompts.onEvent({ type: "confirm", action: "delete" });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({
    type: "confirm",
    action: "delete",
    id: "at://did:plc:alice/app.bsky.feed.post/abc",
  });
  assert.equal(prompts.allow("edit"), false);
  assert.equal(prompts.allow("approve"), true);
  assert.equal(prompts.allow("approve"), false);
});

test("session start, exit, stop, and inactive errors clear arming", () => {
  const prompts = createPrompts();
  prompts.onEvent({ type: "review", draft });
  prompts.onEvent({ type: "started", action: "review" });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft });
  prompts.onEvent({ type: "exit", value: 0 });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft });
  prompts.onEvent({ type: "error", value: "failed", active: false });
  assert.equal(prompts.allow("approve"), false);
  prompts.onEvent({ type: "review", draft });
  prompts.reset();
  assert.equal(prompts.allow("approve"), false);
  assert.equal(prompts.allow("quit"), true);
});
