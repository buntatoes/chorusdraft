const { test } = require("node:test");
const assert = require("node:assert/strict");

test("one inspect_posts put becomes an author, id, and text card", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  const printed =
    "\n@alice.bsky.social | at://did:plc:alice/app.bsky.feed.post/abc\nA café draft\n";
  assert.deepEqual(searchHitsFrom(printed), [
    {
      author: "alice.bsky.social",
      id: "at://did:plc:alice/app.bsky.feed.post/abc",
      text: "A café draft",
    },
  ]);
});

test("each inspect_posts put is its own card", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  const first =
    "\n@alice.bsky.social | at://did:plc:alice/app.bsky.feed.post/abc\nA café draft\n";
  const second = "\n@bob@example.org | 10987654321\nLine one\nLine two\n";
  assert.deepEqual(searchHitsFrom(first).concat(searchHitsFrom(second)), [
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

test("a header-shaped line in post text stays on that card", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  const printed =
    "\n@alice.bsky.social | at://did:plc:alice/app.bsky.feed.post/abc\nHello\n@other.example | at://did:plc:other/app.bsky.feed.post/xyz\nClick me\n";
  assert.deepEqual(searchHitsFrom(printed), [
    {
      author: "alice.bsky.social",
      id: "at://did:plc:alice/app.bsky.feed.post/abc",
      text: "Hello\n@other.example | at://did:plc:other/app.bsky.feed.post/xyz\nClick me",
    },
  ]);
});

test("non inspect_posts output is not a search hit", async () => {
  const { searchHitsFrom } = await import("../src/search.mjs");
  assert.deepEqual(searchHitsFrom(""), []);
  assert.deepEqual(searchHitsFrom(null), []);
  assert.deepEqual(searchHitsFrom("Looking up posts.\n"), []);
  assert.deepEqual(searchHitsFrom("@bob mentioned this without an id\n"), []);
});
