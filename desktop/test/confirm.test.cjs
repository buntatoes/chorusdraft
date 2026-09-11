const { test } = require("node:test");
const assert = require("node:assert/strict");

const printed =
  '{"event":"confirm","action":"delete","id":"at://did:plc:alice/app.bsky.feed.post/abc"}';

test("delete confirm is armed only by the structured confirm event", async () => {
  const { confirmDeleteFrom } = await import("../src/confirm.mjs");
  assert.equal(
    confirmDeleteFrom({
      type: "confirm",
      action: "delete",
      id: "at://did:plc:alice/app.bsky.feed.post/abc",
    }),
    "at://did:plc:alice/app.bsky.feed.post/abc",
  );
  assert.equal(confirmDeleteFrom({ type: "output", value: printed }), null);
  assert.equal(confirmDeleteFrom({ type: "review", action: "delete" }), null);
  assert.equal(
    confirmDeleteFrom({ type: "confirm", action: "reject", id: "1" }),
    null,
  );
  assert.equal(confirmDeleteFrom({ type: "confirm", action: "delete" }), null);
  assert.equal(confirmDeleteFrom({ type: "confirm", action: "delete", id: "" }), null);
  assert.equal(confirmDeleteFrom(null), null);
});
