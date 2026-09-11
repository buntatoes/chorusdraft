// Parse inspect_posts puts. Each put is one control log event:
// "\n@author | id\ntext\n". Pass that event, not the activity panel.
const HEADER = /\n@(\S+) \| (\S+)\n/g;

export function searchHitsFrom(output) {
  if (typeof output !== "string" || !output) return [];
  const matches = [];
  let match;
  HEADER.lastIndex = 0;
  while ((match = HEADER.exec(output))) {
    matches.push({
      author: match[1],
      id: match[2],
      headerEnd: match.index + match[0].length,
      headerStart: match.index,
    });
  }
  return matches.map((item, index) => {
    const end = matches[index + 1]
      ? matches[index + 1].headerStart
      : output.length;
    return {
      author: item.author,
      id: item.id,
      text: output.slice(item.headerEnd, end).replace(/\n$/, ""),
    };
  });
}
