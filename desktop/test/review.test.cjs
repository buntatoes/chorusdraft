const { test } = require("node:test");
const assert = require("node:assert/strict");

const prompt = "Publish this exact draft? [y/N/e=edit/d=reject/q=quit]: ";
const header = "\n11111111-2222-4333-8444-555555555555 | manual | public\n";

test("only a prompt at the start of a line arms the publish button", async () => {
  const { REVIEW_PROMPT, tail } = await import("../src/review.mjs");
  assert.ok(REVIEW_PROMPT.test(header + "  Hello\n" + prompt));
  assert.ok(REVIEW_PROMPT.test(tail("", header + "  Hello\n" + prompt)));
  assert.ok(!REVIEW_PROMPT.test(header + "  " + prompt.trim() + "\n"));
  assert.ok(!REVIEW_PROMPT.test(header + "  " + prompt));
  assert.ok(!REVIEW_PROMPT.test("Something else: "));
});

test("the draft id comes from a header line, not from draft text", async () => {
  const { reviewDraftIdFrom } = await import("../src/review.mjs");
  const fake = "  99999999-8888-4777-8666-555555555555 | manual | public\n";
  assert.equal(
    reviewDraftIdFrom(header + fake + "  more text\n" + prompt),
    "11111111-2222-4333-8444-555555555555",
  );
  assert.equal(reviewDraftIdFrom(fake + prompt), "");
});

test("the prompt buffer is trimmed at a line boundary", async () => {
  const { REVIEW_PROMPT, tail } = await import("../src/review.mjs");
  const long = "  " + "x".repeat(5000) + "\n";
  const buffer = tail("", header + long + prompt);
  assert.ok(buffer.length <= 4096);
  assert.ok(buffer.startsWith("\n"));
  assert.ok(REVIEW_PROMPT.test(buffer));
  const spoof = tail("", "x".repeat(4090) + "\n  " + prompt);
  assert.ok(!REVIEW_PROMPT.test(spoof));
});
