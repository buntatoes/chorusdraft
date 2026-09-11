// Deletion is armed only by the bridge's structured confirm event, never by
// scanning terminal output. Approve still means confirm; there is no delete
// control action.
export function confirmDeleteFrom(event) {
  if (!event || event.type !== "confirm" || event.action !== "delete")
    return null;
  return typeof event.id === "string" && event.id !== "" ? event.id : null;
}
