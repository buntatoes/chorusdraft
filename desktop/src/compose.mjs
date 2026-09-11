// Compose helpers match Runner.draft/5, Bluesky @uri, and Mastodon.get_post/2.
export const TEXT_LIMIT = { bluesky: 300, mastodon: 500 };

const BLUESKY_POST_URI =
  /^at:\/\/[^/\s]+\/app\.bsky\.feed\.post\/[a-zA-Z0-9._~:-]+$/;
const MASTODON_STATUS_ID = /^\d+$/;
const graphemes =
  typeof Intl !== "undefined" && typeof Intl.Segmenter === "function"
    ? new Intl.Segmenter(undefined, { granularity: "grapheme" })
    : null;

export function characterCount(text) {
  if (typeof text !== "string" || text.length === 0) return 0;
  if (graphemes) return [...graphemes.segment(text)].length;
  return [...text].length;
}

export function composeAction(replyId, quoteId) {
  const reply = typeof replyId === "string" ? replyId : "";
  const quote = typeof quoteId === "string" ? quoteId : "";
  if (reply && quote) return null;
  if (reply) return "reply";
  if (quote) return "quote";
  return "post";
}

export function draftVisibility(platform, action, mastodonVisibility) {
  if (platform === "bluesky") return "public";
  if (action === "reply") return "unlisted";
  return mastodonVisibility === "unlisted" ? "unlisted" : "public";
}

export function validPostId(platform, id) {
  if (
    typeof id !== "string" ||
    id.length === 0 ||
    id.length > 512 ||
    /\s/.test(id) ||
    id.startsWith("--")
  )
    return false;
  if (platform === "bluesky") return BLUESKY_POST_URI.test(id);
  if (platform === "mastodon") return MASTODON_STATUS_ID.test(id);
  return false;
}

export function composeCanSubmit({
  compose,
  platform,
  text,
  cw = "",
  replyId = "",
  quoteId = "",
}) {
  const body = typeof text === "string" ? text : "";
  if (compose === "search") return body.trim() !== "";
  const reply = typeof replyId === "string" ? replyId.trim() : "";
  const quote = typeof quoteId === "string" ? quoteId.trim() : "";
  const action = composeAction(reply, quote);
  const limit = TEXT_LIMIT[platform];
  if (!limit || action == null) return false;
  if (compose === "reply" && !reply) return false;
  if (compose === "quote" && !quote) return false;
  if (!body.trim() || characterCount(body) > limit) return false;
  if (
    platform === "mastodon" &&
    typeof cw === "string" &&
    cw &&
    characterCount(cw) > TEXT_LIMIT.mastodon
  )
    return false;
  if (reply && !validPostId(platform, reply)) return false;
  if (quote && !validPostId(platform, quote)) return false;
  return true;
}
