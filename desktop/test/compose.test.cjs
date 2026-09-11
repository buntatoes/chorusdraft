const { test } = require("node:test");
const assert = require("node:assert/strict");

test("compose counts graphemes the way the bot counts characters", async () => {
  const { characterCount, TEXT_LIMIT } = await import("../src/compose.mjs");
  assert.equal(TEXT_LIMIT.bluesky, 300);
  assert.equal(TEXT_LIMIT.mastodon, 500);
  assert.equal(characterCount(""), 0);
  assert.equal(characterCount("Hi"), 2);
  assert.equal(characterCount("café"), 4);
  assert.equal(characterCount("e\u0301"), 1);
  assert.equal(characterCount("👨‍👩‍👧‍👦"), 1);
  assert.equal(characterCount("x".repeat(301)), 301);
});

test("compose action follows filled reply or quote ids, not the modal title", async () => {
  const { composeAction } = await import("../src/compose.mjs");
  assert.equal(composeAction("", ""), "post");
  assert.equal(composeAction("123", ""), "reply");
  assert.equal(composeAction("", "123"), "quote");
  assert.equal(composeAction("123", "456"), null);
});

test("visibility preview matches Runner.draft/5", async () => {
  const { composeAction, draftVisibility } = await import("../src/compose.mjs");
  assert.equal(draftVisibility("bluesky", "post", "unlisted"), "public");
  assert.equal(draftVisibility("bluesky", "reply", "unlisted"), "public");
  assert.equal(
    draftVisibility("mastodon", composeAction("", ""), "public"),
    "public",
  );
  assert.equal(
    draftVisibility("mastodon", composeAction("", ""), "unlisted"),
    "unlisted",
  );
  assert.equal(
    draftVisibility("mastodon", composeAction("123", ""), "public"),
    "unlisted",
  );
  assert.equal(
    draftVisibility("mastodon", composeAction("", "123"), "unlisted"),
    "unlisted",
  );
  assert.equal(draftVisibility("mastodon", "post", "private"), "public");
});

test("reply and quote ids use the bot's Bluesky URI and Mastodon status formats", async () => {
  const { validPostId } = await import("../src/compose.mjs");
  const uri = "at://did:plc:alice/app.bsky.feed.post/fixture";
  const longUri =
    "at://did:web:bsky.much-longer.subdomain.example.social/app.bsky.feed.post/3jzfciyerx22f";
  assert.equal(validPostId("bluesky", uri), true);
  assert.equal(validPostId("bluesky", longUri), true);
  assert.ok(longUri.length > 80);
  assert.equal(validPostId("mastodon", "123"), true);
  assert.equal(validPostId("bluesky", "123"), false);
  assert.equal(validPostId("mastodon", uri), false);
  assert.equal(validPostId("bluesky", "at://did:plc:alice/app.bsky.feed.like/x"), false);
  assert.equal(validPostId("bluesky", "not-a-uri"), false);
  assert.equal(validPostId("mastodon", "12 3"), false);
  assert.equal(validPostId("mastodon", "12a"), false);
  assert.equal(validPostId("mastodon", "abc"), false);
  assert.equal(validPostId("bluesky", "--publish"), false);
  assert.equal(validPostId("bluesky", ""), false);
  assert.equal(validPostId("other", uri), false);
});

test("submit stays off until body, CW, and target match the bot", async () => {
  const { composeCanSubmit, TEXT_LIMIT } = await import("../src/compose.mjs");
  const uri = "at://did:plc:alice/app.bsky.feed.post/fixture";
  assert.equal(
    composeCanSubmit({ compose: "search", platform: "bluesky", text: "topic" }),
    true,
  );
  assert.equal(
    composeCanSubmit({ compose: "post", platform: "bluesky", text: "Hi" }),
    true,
  );
  assert.equal(
    composeCanSubmit({
      compose: "post",
      platform: "bluesky",
      text: "x".repeat(TEXT_LIMIT.bluesky + 1),
    }),
    false,
  );
  assert.equal(
    composeCanSubmit({
      compose: "reply",
      platform: "bluesky",
      text: "Hi",
      replyId: "",
    }),
    false,
  );
  assert.equal(
    composeCanSubmit({
      compose: "reply",
      platform: "bluesky",
      text: "Hi",
      replyId: "not-a-uri",
    }),
    false,
  );
  assert.equal(
    composeCanSubmit({
      compose: "reply",
      platform: "bluesky",
      text: "Hi",
      replyId: uri,
    }),
    true,
  );
  assert.equal(
    composeCanSubmit({
      compose: "quote",
      platform: "mastodon",
      text: "Hi",
      quoteId: "99",
    }),
    true,
  );
  assert.equal(
    composeCanSubmit({
      compose: "post",
      platform: "mastodon",
      text: "Hi",
      replyId: "1",
      quoteId: "2",
    }),
    false,
  );
  assert.equal(
    composeCanSubmit({
      compose: "post",
      platform: "mastodon",
      text: "Hi",
      cw: "n".repeat(TEXT_LIMIT.mastodon + 1),
    }),
    false,
  );
  assert.equal(
    composeCanSubmit({
      compose: "post",
      platform: "mastodon",
      text: "Hi",
      cw: "note",
    }),
    true,
  );
});
