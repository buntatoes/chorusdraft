// Publication is armed only by the bridge's structured review event, never by
// scanning terminal output: post text and content warnings are
// attacker-influenced and could otherwise spoof the old TTY approval prompt.
export function reviewDraftFrom(event) {
  if (!event || event.type !== "review") return null;
  const draft = event.draft;
  return draft && typeof draft === "object" && !Array.isArray(draft)
    ? draft
    : {};
}
