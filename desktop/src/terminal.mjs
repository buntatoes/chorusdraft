// Strip terminal controls without buffering or swallowing subsequent output.
export class TerminalText {
  constructor() {
    this.reset();
  }

  reset() {
    this.mode = "text";
  }

  push(chunk) {
    let output = "";
    for (const character of chunk) {
      switch (this.mode) {
        case "text":
          if (character === "\x1b") this.mode = "escape";
          else if (character !== "\r") output += character;
          break;
        case "escape":
          if (character === "[") this.mode = "csi";
          else if ("]PX^_".includes(character)) this.mode = "string";
          else if (character >= " " && character <= "/")
            this.mode = "intermediate";
          else this.mode = "text";
          break;
        case "intermediate":
          if (character >= "0" && character <= "~") this.mode = "text";
          break;
        case "csi":
          if (character >= "@" && character <= "~") this.mode = "text";
          break;
        case "string":
          if (character === "\x07") this.mode = "text";
          else if (character === "\x1b") this.mode = "string-escape";
          break;
        case "string-escape":
          if (character === "\\" || character === "\x07") this.mode = "text";
          else if (character !== "\x1b") this.mode = "string";
          break;
      }
    }
    return output;
  }
}
