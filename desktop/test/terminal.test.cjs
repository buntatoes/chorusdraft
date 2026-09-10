const { test } = require("node:test");
const assert = require("node:assert/strict");

test("title and color controls never hide following draft text or approval prompts", async () => {
  const { TerminalText } = await import("../src/terminal.mjs");
  const prompt = "Publish this exact draft? [y/N/d=reject/q=quit]: ";
  for (const terminator of ["\x07", "\x1b\\"]) {
    const source = `Before\r\n\x1b]0;Window title${terminator}\x1b[32mA café draft\x1b[0m\r\n${prompt}`;
    const expected = `Before\nA café draft\n${prompt}`;
    for (let split = 0; split <= source.length; split++) {
      const stream = new TerminalText();
      assert.equal(
        stream.push(source.slice(0, split)) + stream.push(source.slice(split)),
        expected,
      );
    }
    const stream = new TerminalText();
    assert.equal(
      [...source].map((character) => stream.push(character)).join(""),
      expected,
    );
  }
});

test("unfinished controls do not carry into a new bot session", async () => {
  const { TerminalText } = await import("../src/terminal.mjs");
  const stream = new TerminalText();
  assert.equal(stream.push("visible\x1b]unfinished title"), "visible");
  stream.reset();
  assert.equal(stream.push("Next session\r\n"), "Next session\n");
});
