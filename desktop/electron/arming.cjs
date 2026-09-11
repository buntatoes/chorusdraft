// Approve, reject, skip, and edit are armed only by structured bot events.
// The renderer also gates buttons; this module is the main-process check.
function createPrompts() {
  let review = false;
  let confirm = false;
  function reset() {
    review = false;
    confirm = false;
  }
  return {
    reset,
    onEvent(message) {
      if (!message || typeof message !== "object") return;
      if (message.type === "review") {
        const draft = message.draft;
        review =
          !!draft &&
          typeof draft === "object" &&
          !Array.isArray(draft) &&
          typeof draft.text === "string";
        confirm = false;
        return;
      }
      if (message.type === "confirm") {
        confirm =
          message.action === "delete" &&
          typeof message.id === "string" &&
          message.id !== "";
        review = false;
        return;
      }
      if (
        message.type === "started" ||
        message.type === "exit" ||
        (message.type === "error" && message.active === false)
      )
        reset();
    },
    allow(action) {
      if (action === "quit") return true;
      const ok =
        action === "approve"
          ? review || confirm
          : ["reject", "skip", "edit"].includes(action)
            ? review
            : false;
      if (ok) reset();
      return ok;
    },
  };
}
module.exports = { createPrompts };
