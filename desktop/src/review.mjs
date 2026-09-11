// Publication is armed only by the bridge's structured review event, never by
// scanning terminal output: post text and content warnings are
// attacker-influenced and could otherwise spoof the old TTY approval prompt.
export function reviewDraftFrom(event) {
  if (!event || event.type !== "review") return null;
  const draft = event.draft;
  if (!draft || typeof draft !== "object" || Array.isArray(draft)) return null;
  return typeof draft.text === "string" ? draft : null;
}

function field(draft, key) {
  const value = draft[key];
  return typeof value === "string" ? value : "";
}

export function reviewCardFrom(draft) {
  const source =
    draft && typeof draft === "object" && !Array.isArray(draft) ? draft : {};
  return {
    id: field(source, "id"),
    action: field(source, "action"),
    visibility: field(source, "visibility"),
    text: field(source, "text"),
    cw: field(source, "cw"),
    reply_to: field(source, "reply_to"),
    quote_to: field(source, "quote_to"),
    status: field(source, "status"),
  };
}
