const { test } = require("node:test");
const assert = require("node:assert/strict");

test("inspect_posts print becomes author, id, and text cards", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  const printed =
    "\n@alice.bsky.social | at://did:plc:alice/app.bsky.feed.post/abc\nA café draft\n\n@bob@example.org | 10987654321\nLine one\nLine two\n";
  assert.deepEqual(searchHitsFrom(printed), [
    {
      author: "alice.bsky.social",
      id: "at://did:plc:alice/app.bsky.feed.post/abc",
      text: "A café draft",
    },
    {
      author: "bob@example.org",
      id: "10987654321",
      text: "Line one\nLine two",
    },
  ]);
});

test("empty or non-print output yields no search hits", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  assert.deepEqual(searchHitsFrom(""), []);
  assert.deepEqual(searchHitsFrom(null), []);
  assert.deepEqual(searchHitsFrom("Session complete"), []);
  assert.deepEqual(searchHitsFrom("not a hit | because it lacks an @"), []);
});
