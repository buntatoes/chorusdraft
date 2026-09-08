// The bot indents draft text, so header and prompt lines are the only ones
// that start at column 0. Both patterns are anchored there to keep draft
// content from posing as either.
export const REVIEW_PROMPT = /(?:^|\n)Publish this exact draft\? \[[^\]]+\]:\s*$/;
const REVIEW_HEADER =
  /(?:^|\n)([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) \| (?:manual|ai_generated) \|/g;

export function reviewDraftIdFrom(buffer) {
  const matches = [...String(buffer).matchAll(REVIEW_HEADER)];
  return matches.length ? matches[matches.length - 1][1] : "";
}

// Keep the tail of the output for prompt detection, trimmed at a line
// boundary so the start of the buffer is always the start of a line.
export function tail(buffer, output) {
  let next = buffer + output;
  if (next.length > 4096) {
    next = next.slice(-4096);
    const cut = next.indexOf("\n");
    if (cut !== -1) next = next.slice(cut);
  }
  return next;
}
