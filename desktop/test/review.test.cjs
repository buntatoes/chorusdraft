const { test } = require("node:test");
const assert = require("node:assert/strict");

const prompt = "Publish this exact draft? [y/N/e=edit/d=reject/q=quit]: ";
const header = "\n11111111-2222-4333-8444-555555555555 | manual | public\n";

test("publish is armed only by the structured review event", async () => {
  const { reviewDraftFrom } = await import("../src/review.mjs");
  const draft = {
    id: "11111111-2222-4333-8444-555555555555",
    text: "Hello",
  };
  assert.equal(reviewDraftFrom({ type: "review", draft }), draft);
  // Terminal output is attacker-influenced, so even output reproducing the
  // old TTY prompt and a draft header must not arm the publish button.
  assert.equal(
    reviewDraftFrom({ type: "output", value: header + "  Hello\n" + prompt }),
    null,
  );
  assert.equal(reviewDraftFrom({ type: "output", value: prompt }), null);
  assert.equal(reviewDraftFrom({ type: "started", action: "review" }), null);
  assert.equal(reviewDraftFrom({}), null);
  assert.equal(reviewDraftFrom(null), null);
  assert.equal(reviewDraftFrom("review"), null);
});

test("a review event with a malformed draft still arms with an empty draft", async () => {
  const { reviewDraftFrom } = await import("../src/review.mjs");
  assert.deepEqual(reviewDraftFrom({ type: "review" }), {});
  assert.deepEqual(reviewDraftFrom({ type: "review", draft: null }), {});
  assert.deepEqual(reviewDraftFrom({ type: "review", draft: "text" }), {});
  assert.deepEqual(reviewDraftFrom({ type: "review", draft: ["text"] }), {});
});
