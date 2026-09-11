// Parse one inspect_posts put. Each control log event is one put:
// "\n@author | id\ntext\n". Pass that event, not the activity panel.
// The body is not scanned for extra headers; post text is attacker-influenced.
const HEADER = /^\n@(\S+) \| (\S+)\n/;

export function searchHitsFrom(output) {
  if (typeof output !== "string" || !output) return [];
  const match = HEADER.exec(output);
  if (!match) return [];
  return [
    {
      author: match[1],
      id: match[2],
      text: output.slice(match[0].length).replace(/\n$/, ""),
    },
  ];
}
