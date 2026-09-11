import { Settings, History, Queue } from "./Privacy.jsx";
import { TerminalText } from "./terminal.mjs";
import { reviewDraftFrom } from "./review.mjs";
import {
  TEXT_LIMIT,
  characterCount,
  composeAction,
  composeCanSubmit,
  draftVisibility,
} from "./compose.mjs";
import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

function Icon({ name, size = 20 }) {
  const paths = {
    grid: (
      <>
        <rect x="3" y="3" width="7" height="7" rx="2" />
        <rect x="14" y="3" width="7" height="7" rx="2" />
        <rect x="3" y="14" width="7" height="7" rx="2" />
        <rect x="14" y="14" width="7" height="7" rx="2" />
      </>
    ),
    draft: (
      <>
        <path d="m14 4 6 6M4 20l4-1L21 6a2 2 0 0 0-4-4L4 15v5Z" />
        <path d="M13 20h8" />
      </>
    ),
    review: (
      <>
        <rect x="4" y="4" width="16" height="17" rx="3" />
        <path d="M9 3h6M8 12l3 3 5-6" />
      </>
    ),
    monitor: (
      <>
        <path d="M3 12h4l3-8 4 16 3-8h4" />
      </>
    ),
    settings: (
      <>
        <path d="M4 7h16M4 17h16" />
        <circle cx="9" cy="7" r="3" />
        <circle cx="16" cy="17" r="3" />
      </>
    ),
    arrow: <path d="M4 12h16m-6-6 6 6-6 6" />,
    search: (
      <>
        <circle cx="10.5" cy="10.5" r="6.5" />
        <path d="m16 16 5 5" />
      </>
    ),
    terminal: (
      <>
        <path d="m4 6 6 6-6 6M13 18h7" />
      </>
    ),
    stop: <rect x="5" y="5" width="14" height="14" rx="3" />,
    send: (
      <>
        <path d="m3 3 18 9-18 9 4-9-4-9Zm4 9h14" />
      </>
    ),
    check: <path d="m5 12 4 4 10-10" />,
    close: <path d="m6 6 12 12M6 18 18 6" />,
    help: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M9 9a3 3 0 0 1 6 0c0 2-3 2-3 4M12 17h.01" />
      </>
    ),
    spark: (
      <path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3Z" />
    ),
  };
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name] || paths.grid}
    </svg>
  );
}
function Logo() {
  return (
    <span className="logo">
      <svg viewBox="0 0 32 32" fill="none">
        <path
          d="M7 12c0-4 4-7 9-7s9 3 9 7v6c0 4-4 7-9 7h-3l-6 3V12Z"
          stroke="currentColor"
          strokeWidth="2.4"
        />
        <path
          d="M12 13v5m4-8v11m4-8v5"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    </span>
  );
}
const titles = {
  setup: "Set up",
  draft: "Draft a post",
  review: "Review drafts",
  start: "Monitor",
  automatic: "Automatic",
  listen: "Listen for mentions",
  replies: "Draft replies",
  search: "Search posts",
  post: "Write a post",
  reply: "Write a reply",
  quote: "Write a quote",
  edit: "Edit draft",
  reject: "Reject draft",
  status: "Queue status",
  help: "Command help",
  version: "Version",
};
const api = window.chorus;

function App() {
  const runtime = "elixir";
  const [page, setPage] = useState("overview");
  const [settingsTarget, setSettingsTarget] = useState(null);
  const [notice, setNotice] = useState("");
  const activityParts = useRef([]);
  const [platform, setPlatform] = useState("bluesky");
  const [version, setVersion] = useState("0.52");
  const [running, setRunning] = useState(false);
  const [action, setAction] = useState(null);
  const [activity, setActivity] = useState("");
  const [response, setResponse] = useState("");
  const [error, setError] = useState("");
  const [compose, setCompose] = useState(null);
  const [text, setText] = useState("");
  const [cw, setCw] = useState("");
  const [replyTo, setReplyTo] = useState("");
  const [quoteTo, setQuoteTo] = useState("");
  const [mastodonVisibility, setMastodonVisibility] = useState("public");
  const [result, setResult] = useState("");
  const logRef = useRef(null);
  const terminalText = useRef(new TerminalText());
  const approvalAvailable = useRef(false);
  const [reviewPrompt, setReviewPrompt] = useState(false);
  const [editingReview, setEditingReview] = useState(false);
  const [reviewEdit, setReviewEdit] = useState("");
  const [savingReview, setSavingReview] = useState(false);
  const [reviewDraft, setReviewDraft] = useState(null);
  const savingReviewLock = useRef(false);
  const runningLock = useRef(false);
  useEffect(() => {
    if (!api) {
      setError("Open ChorusDraft in the desktop app to use the bot controls.");
      return;
    }
    api
      .info()
      .then((info) => setVersion(info.version))
      .catch((e) => setError(e.message));
    return api.onEvent((event) => {
      if (event.type === "output") {
        const output = terminalText.current.push(event.value);
        if (output) {
          const now = Date.now();
          activityParts.current = activityParts.current.filter(
            (p) => p.time > now - 10 * 86400000,
          );
          activityParts.current.push({ time: now, text: output });
          while (
            activityParts.current.length > 1 &&
            activityParts.current.reduce((n, p) => n + p.text.length, 0) >
              160000
          )
            activityParts.current.shift();
          setActivity(
            activityParts.current
              .map((p) => p.text)
              .join("")
              .slice(-160000),
          );
        }
      }
      const draft = reviewDraftFrom(event);
      if (draft) {
        setReviewDraft(draft);
        approvalAvailable.current = true;
        setReviewPrompt(true);
        setEditingReview(false);
        setReviewEdit(typeof draft.text === "string" ? draft.text : "");
        setSavingReview(false);
        savingReviewLock.current = false;
      }
      if (event.type === "started") {
        setRunning(true);
        setAction(event.action);
      }
      if (event.type === "exit") {
        setRunning(false);
        setResult(event.value === 0 ? "Session complete" : "Session ended");
      }
      if (event.type === "notice") setNotice(event.value);
      if (event.type === "error") {
        setError(event.value);
        // An error without an active field says nothing about the session.
        if (typeof event.active === "boolean") setRunning(event.active);
      }
    });
  }, []);
  useEffect(() => {
    const timer = setInterval(() => {
      const fresh = activityParts.current.filter(
        (p) => p.time > Date.now() - 10 * 86400000,
      );
      if (fresh.length !== activityParts.current.length) {
        activityParts.current = fresh;
        setActivity(fresh.map((p) => p.text).join(""));
        if (!fresh.length) {
          approvalAvailable.current = false;
          setReviewPrompt(false);
        }
      }
    }, 60000);
    return () => clearInterval(timer);
  }, []);
  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [activity]);
  useEffect(() => {
    const close = (e) => {
      if (e.key === "Escape") setCompose(null);
    };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, []);
  useEffect(() => {
    if (!running) runningLock.current = false;
  }, [running]);
  useEffect(() => {
    if (platform !== "mastodon" || !api) return;
    let active = true;
    api
      .settings({ runtime, platform })
      .then((info) => {
        if (active)
          setMastodonVisibility(info.values.STATUS_VISIBILITY || "public");
      })
      .catch(() => {
        if (active) setMastodonVisibility("public");
      });
    return () => {
      active = false;
    };
  }, [platform]);
  const invoke = async (operation, opts = {}) => {
    try {
      setError("");
      await operation();
      return true;
    } catch (e) {
      const message = e.message.replace(
        /^Error invoking remote method '[^']+': Error: /,
        "",
      );
      setError(message);
      if (message === "The bot session has already ended.") {
        setRunning(false);
        return false;
      }
      if (
        !opts.keepRunning &&
        message !== "Choose an action after the current session ends."
      )
        setRunning(false);
      return false;
    }
  };
  const run = async (nextAction, suppliedText, target, opts = {}) => {
    if (!api || running || runningLock.current) return;
    if (
      ["search", "post", "reply", "quote"].includes(nextAction) &&
      suppliedText === undefined
    ) {
      setText("");
      setCw("");
      setReplyTo("");
      setQuoteTo("");
      setCompose(nextAction);
      return;
    }
    runningLock.current = true;
    setCompose(null);
    if (!opts.stay) setPage("overview");
    activityParts.current = [];
    setAction(nextAction);
    setRunning(true);
    setActivity("");
    setResult("");
    setResponse("");
    terminalText.current.reset();
    approvalAvailable.current = false;
    setReviewPrompt(false);
    setEditingReview(false);
    setReviewEdit("");
    setSavingReview(false);
    savingReviewLock.current = false;
    setReviewDraft(null);
    await invoke(() =>
      api.run({
        runtime,
        platform,
        action: nextAction,
        text: suppliedText,
        target,
        cw: opts.cw,
      }),
    );
  };
  const send = async (value, opts = {}) => {
    if (!api || !running) return false;
    if ((editingReview || savingReview || savingReviewLock.current) && !opts.force)
      return false;
    if (action === "review" && !opts.force && !approvalAvailable.current)
      return false;
    let payload = value;
    if (typeof value === "string") {
      const trimmed = value.trim().toLowerCase();
      if (trimmed === "e") {
        setReviewEdit(reviewDraft?.text || "");
        setEditingReview(true);
        return true;
      }
      payload =
        trimmed === "y" || trimmed === "yes"
          ? { action: "approve" }
          : trimmed === "d"
            ? { action: "reject" }
            : trimmed === "q"
              ? { action: "quit" }
              : { action: "skip" };
    }
    approvalAvailable.current = false;
    const ok = await invoke(() => api.respond(payload), { keepRunning: true });
    if (ok) {
      setReviewPrompt(false);
      setResponse("");
      // Prevent repeated approval clicks before the next prompt arrives.
      setActivity((previous) => previous + "\n");
    } else if (action === "review") {
      approvalAvailable.current = true;
    }
    return ok;
  };
  const reviewReady = running && action === "review" && reviewPrompt;
  const canRespond =
    running &&
    !editingReview &&
    !savingReview &&
    (action !== "review" || reviewReady);
  const selected = `${platform === "bluesky" ? "Bluesky" : "Mastodon"}`;
  const configure = () => api && setSettingsTarget({ runtime, platform });
  const writeLimit = TEXT_LIMIT[platform];
  const replyId = replyTo.trim();
  const quoteId = quoteTo.trim();
  const stagingAction = composeAction(replyId, quoteId);
  const composeVisibility = draftVisibility(
    platform,
    stagingAction,
    mastodonVisibility,
  );
  const bodyCount = characterCount(text);
  const composeOver =
    compose && compose !== "search" && bodyCount > writeLimit;
  const composeReady = composeCanSubmit({
    compose,
    platform,
    text,
    cw,
    replyId,
    quoteId,
  });
  const submitCompose = () => {
    if (compose === "search") {
      run("search", text);
      return;
    }
    if (!composeReady) return;
    const action = composeAction(replyId, quoteId);
    if (!action) return;
    run(action, text, replyId || quoteId || undefined, {
      cw: platform === "mastodon" && cw.trim() ? cw : undefined,
    });
  };
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <Logo />
          <div>
            ChorusDraft<span>YOUR SOCIAL WORKSPACE</span>
          </div>
        </div>
        <div className="nav-label">WORKSPACE</div>
        <nav aria-label="Workspace">
          <button
            className={`nav-button ${page === "overview" ? "selected" : ""}`}
            onClick={() => setPage("overview")}
          >
            <Icon name="grid" />
            Overview
            <span className="nav-dot" />
          </button>
          <button
            className="nav-button"
            disabled={running || !api}
            onClick={() => run("review")}
          >
            <Icon name="review" />
            Review drafts
          </button>
          <button
            className="nav-button"
            disabled={running || !api}
            onClick={configure}
          >
            <Icon name="settings" />
            Configuration
          </button>
          <button
            className={`nav-button ${page === "queue" ? "selected" : ""}`}
            disabled={!api}
            onClick={() => setPage("queue")}
          >
            <Icon name="review" />
            Queue
          </button>
          <button
            className={`nav-button ${page === "history" ? "selected" : ""}`}
            disabled={!api}
            onClick={() => setPage("history")}
          >
            <Icon name="review" />
            History
          </button>
        </nav>
        <div className="sidebar-note">
          <span className="note-icon">
            <Icon name="check" size={16} />
          </span>
          <h4>You have the final say.</h4>
          <p>Review drafts, or start automatic mode when you mean to.</p>
        </div>
        <button
          className="nav-button help-link"
          disabled={running || !api}
          onClick={() => run("help")}
        >
          <Icon name="help" />
          Command guide
        </button>
        <div className="sidebar-footer">
          <span className="version-mark">C</span>
          <div>
            ChorusDraft<span>{version}</span>
          </div>
        </div>
      </aside>
      <main>
        <header className="topbar">
          <div>
            Workspace <span>/</span>{" "}
            {page === "history"
              ? "History"
              : page === "queue"
                ? "Queue"
                : "Overview"}
          </div>
          <span className="version-tag">{version}</span>
        </header>
        <div className="workspace">
          {notice && (
            <div role="status" className="settings-notice">
              {notice}
              <button
                aria-label="Dismiss message"
                onClick={() => setNotice("")}
              >
                ×
              </button>
            </div>
          )}
          {error && page !== "overview" && (
            <div className="error-banner" role="alert">
              <span>{error}</span>
              <button
                aria-label="Dismiss error"
                onClick={() => setError("")}
              >
                <Icon name="close" size={16} />
              </button>
            </div>
          )}
          {page === "history" ? (
            <>
              <label className="history-selection">
                Platform
                <select
                  aria-label="History platform"
                  disabled={running}
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value)}
                >
                  <option value="bluesky">Bluesky</option>
                  <option value="mastodon">Mastodon</option>
                </select>
              </label>
              <History selection={{ runtime, platform }} />
            </>
          ) : page === "queue" ? (
            <Queue
              selection={{ runtime, platform }}
              running={running}
              onPlatform={setPlatform}
              onReview={(id) => run("review", undefined, id)}
              onRun={(action, text, target) =>
                run(action, text, target, { stay: true })
              }
            />
          ) : (
            <>
              <div className="page-heading">
                <div className="eyebrow">CREATE WITH INTENTION</div>
                <div className="heading-row">
                  <div>
                    <h1>Your bot workspace</h1>
                    <p>
                      Choose a social platform and start shaping your next post.
                    </p>
                  </div>
                  <span className={`status-pill ${running ? "busy" : ""}`}>
                    <i />
                    {running ? "Session running" : "Ready to start"}
                  </span>
                </div>
              </div>
              {error && (
                <div className="error-banner" role="alert">
                  <span>{error}</span>
                  <button
                    aria-label="Dismiss error"
                    onClick={() => setError("")}
                  >
                    <Icon name="close" size={16} />
                  </button>
                </div>
              )}
              <section className="selection-panel" aria-label="Bot selection">
                <div className="selection-group">
                  <label>Social platform</label>
                  <select
                    aria-label="Social platform"
                    disabled={running}
                    value={platform}
                    onChange={(e) => setPlatform(e.target.value)}
                  >
                    <option value="bluesky">Bluesky</option>
                    <option value="mastodon">Mastodon</option>
                  </select>
                </div>
                <div className="setup-actions">
                  <button
                    className="button secondary"
                    disabled={running || !api}
                    onClick={() => run("setup")}
                  >
                    <Icon name="settings" size={17} />
                    Set up
                  </button>
                  <button
                    className="text-button"
                    disabled={running || !api}
                    onClick={configure}
                  >
                    Open configuration
                    <Icon name="arrow" size={15} />
                  </button>
                </div>
              </section>
              <div className="section-title">
                <h2>What would you like to do?</h2>
                <span>{selected}</span>
              </div>
              <section className="action-grid" aria-label="Bot actions">
                {[
                  [
                    "draft",
                    "draft",
                    "Draft a post",
                    "Let your bot turn a fresh idea into a draft.",
                    "Create a draft",
                  ],
                  [
                    "review",
                    "review",
                    "Review your drafts",
                    "Read what’s queued and choose what goes live.",
                    "Open review",
                  ],
                  [
                    "start",
                    "monitor",
                    "Keep things moving",
                    "Monitor mentions and prepare new drafts.",
                    "Start monitoring",
                  ],
                  [
                    "automatic",
                    "monitor",
                    "Automatic mode",
                    "May publish new originals and eligible mention replies. Five attempts per day.",
                    "Start automatic mode",
                  ],
                ].map(([key, icon, title, description, label]) => (
                  <article
                    className={`action-card ${key === "draft" ? "featured" : ""}`}
                    key={key}
                  >
                    <span className={`action-icon ${key}`}>
                      <Icon name={icon} size={23} />
                    </span>
                    <h3>{title}</h3>
                    <p>{description}</p>
                    <button
                      className={`button ${key === "draft" ? "primary" : "secondary"}`}
                      disabled={running || !api}
                      onClick={() => run(key)}
                    >
                      {label}
                      <Icon name="arrow" size={17} />
                    </button>
                  </article>
                ))}
              </section>
              <div className="quick-actions">
                <span>MORE ACTIONS</span>
                <button disabled={running || !api} onClick={() => run("post")}>
                  <Icon name="draft" size={15} />
                  Write a post
                </button>
                <button disabled={running || !api} onClick={() => run("reply")}>
                  <Icon name="draft" size={15} />
                  Write a reply
                </button>
                <button disabled={running || !api} onClick={() => run("quote")}>
                  <Icon name="draft" size={15} />
                  Write a quote
                </button>
                <button
                  disabled={running || !api}
                  onClick={() => run("search")}
                >
                  <Icon name="search" size={15} />
                  Search posts
                </button>
                <button
                  disabled={running || !api}
                  onClick={() => run("replies")}
                >
                  Draft replies
                </button>
                <button
                  disabled={running || !api}
                  onClick={() => run("listen")}
                >
                  Listen for mentions
                </button>
              </div>
              <section
                className="activity-panel"
                aria-label="Activity and review"
              >
                <div className="activity-header">
                  <div>
                    <Icon name="terminal" size={18} />
                    <h2>Activity</h2>
                    <span>{action ? titles[action] : "No active session"}</span>
                  </div>
                  <button
                    className="stop-button"
                    disabled={!running}
                    onClick={() => invoke(() => api.stop())}
                  >
                    <Icon name="stop" size={13} />
                    Stop session
                  </button>
                </div>
                <div
                  className={`activity-body ${activity ? "has-output" : ""}`}
                  ref={logRef}
                  role="log"
                  aria-label="Bot output"
                  aria-live="polite"
                >
                  {activity ? (
                    <pre>{activity}</pre>
                  ) : (
                    <div className="empty-state">
                      <span>
                        <Icon name="terminal" size={25} />
                      </span>
                      <h3>A quiet moment before you begin.</h3>
                      <p>
                        Your bot’s activity and review prompts will appear here.
                      </p>
                    </div>
                  )}
                </div>
                {reviewReady && (
                  <div className="review-actions">
                    {editingReview ? (
                      <>
                        <label className="settings-field">
                          Replacement text
                          <textarea
                            aria-label="Replacement draft text"
                            maxLength={10000}
                            value={reviewEdit}
                            onChange={(e) => setReviewEdit(e.target.value)}
                          />
                        </label>
                        <button
                          className="button secondary"
                          disabled={savingReview}
                          onClick={() => {
                            setEditingReview(false);
                            setReviewEdit("");
                            setSavingReview(false);
                          }}
                        >
                          Cancel
                        </button>
                        <button
                          className="button primary"
                          disabled={savingReview || !reviewEdit.trim()}
                          onClick={async () => {
                            const next = reviewEdit.trim();
                            if (!next || savingReviewLock.current) return;
                            savingReviewLock.current = true;
                            setSavingReview(true);
                            try {
                              if (
                                !(await send(
                                  { action: "edit", text: reviewEdit },
                                  { force: true },
                                ))
                              )
                                return;
                              setEditingReview(false);
                              setReviewEdit("");
                            } finally {
                              savingReviewLock.current = false;
                              setSavingReview(false);
                              setEditingReview(false);
                            }
                          }}
                        >
                          Save edit
                        </button>
                      </>
                    ) : (
                      <>
                        <span>Publish the exact draft displayed above?</span>
                        <button
                          className="button secondary"
                          disabled={savingReview}
                          onClick={() => send("d")}
                        >
                          Reject draft
                        </button>
                        <button
                          className="button secondary"
                          disabled={savingReview}
                          onClick={() => {
                            if (savingReviewLock.current) return;
                            setResponse("");
                            setReviewEdit(
                              reviewDraft && typeof reviewDraft.text === "string"
                                ? reviewDraft.text
                                : "",
                            );
                            setEditingReview(true);
                          }}
                        >
                          Edit text
                        </button>
                        <button
                          className="button primary"
                          disabled={savingReview}
                          onClick={() => send("y")}
                        >
                          Publish this draft
                        </button>
                      </>
                    )}
                  </div>
                )}
                <form
                  className="response-bar"
                  onSubmit={(e) => {
                    e.preventDefault();
                    send(response);
                  }}
                >
                  <input
                    aria-label="Review response"
                    value={response}
                    onChange={(e) => setResponse(e.target.value)}
                    disabled={!canRespond}
                    placeholder="Respond to a prompt…"
                  />
                  <button
                    className="send-button"
                    type="submit"
                    disabled={!canRespond}
                    aria-label="Send response"
                  >
                    <Icon name="send" size={17} />
                  </button>
                  <span>
                    {running
                      ? "Responses go to this session only"
                      : result || "No posts are published automatically"}
                  </span>
                </form>
              </section>
              <footer className="workspace-footer">
                <span>
                  <i />
                  {selected}
                </span>
                <span>Your accounts. Your words. Your approval.</span>
              </footer>
            </>
          )}
        </div>
      </main>
      {settingsTarget && (
        <Settings
          selection={settingsTarget}
          onClose={() => setSettingsTarget(null)}
          onSaved={setNotice}
        />
      )}
      {compose && (
        <div className="modal-backdrop">
          <section
            className="compose-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="compose-title"
          >
            <div className="modal-title">
              <h2 id="compose-title">
                {compose === "search"
                  ? "Search public posts"
                  : compose === "reply"
                    ? "Write a reply"
                    : compose === "quote"
                      ? "Write a quote"
                      : "Write a post"}
              </h2>
              <button
                aria-label="Close dialog"
                onClick={() => setCompose(null)}
              >
                <Icon name="close" />
              </button>
            </div>
            <p>
              {compose === "search"
                ? "Enter a topic or phrase to search on the selected platform."
                : "Queued for review before publication. Bluesky is 300 characters; Mastodon is 500."}
            </p>
            <form
              onSubmit={(e) => {
                e.preventDefault();
                submitCompose();
              }}
            >
              <textarea
                autoFocus={compose !== "reply" && compose !== "quote"}
                maxLength={10000}
                aria-label={
                  compose === "search"
                    ? "Search query"
                    : compose === "reply"
                      ? "Reply text"
                      : compose === "quote"
                        ? "Quote text"
                        : "Post text"
                }
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder={
                  compose === "search"
                    ? "Search for a topic…"
                    : "What would you like to say?"
                }
              />
              {compose !== "search" && (
                <>
                  <p
                    className="compose-count"
                    data-over={composeOver ? "true" : "false"}
                    aria-label="Character count"
                  >
                    {bodyCount}/{writeLimit}
                  </p>
                  {platform === "mastodon" && (
                    <label className="settings-field">
                      Content warning
                      <input
                        aria-label="Content warning"
                        maxLength={500}
                        value={cw}
                        onChange={(e) => setCw(e.target.value)}
                        placeholder="Optional Mastodon content warning"
                      />
                    </label>
                  )}
                  {compose !== "quote" && (
                    <label className="settings-field">
                      Reply id
                      <input
                        autoFocus={compose === "reply"}
                        aria-label="Reply id"
                        maxLength={512}
                        value={replyTo}
                        onChange={(e) => setReplyTo(e.target.value)}
                        placeholder={
                          platform === "bluesky"
                            ? "at:// URI of the post to reply to"
                            : "Numeric Mastodon status id"
                        }
                      />
                    </label>
                  )}
                  {compose !== "reply" && (
                    <label className="settings-field">
                      Quote id
                      <input
                        autoFocus={compose === "quote"}
                        aria-label="Quote id"
                        maxLength={512}
                        value={quoteTo}
                        onChange={(e) => setQuoteTo(e.target.value)}
                        placeholder={
                          platform === "bluesky"
                            ? "at:// URI of the post to quote"
                            : "Numeric Mastodon status id"
                        }
                      />
                    </label>
                  )}
                  <p
                    className="compose-visibility"
                    aria-label="Draft visibility"
                  >
                    Visibility: {composeVisibility}
                    {platform === "mastodon"
                      ? ". Replies to others stage as unlisted. Originals and quotes use Default visibility from Settings."
                      : ""}
                  </p>
                  {replyId && quoteId && (
                    <p className="settings-error" role="alert">
                      Choose either a reply or quote.
                    </p>
                  )}
                </>
              )}
              <div className="modal-footer">
                <button
                  type="button"
                  className="button secondary"
                  onClick={() => setCompose(null)}
                >
                  Cancel
                </button>
                <button
                  className="button primary"
                  type="submit"
                  disabled={!composeReady}
                >
                  {compose === "search" ? "Search posts" : "Add to review queue"}
                  <Icon name="arrow" size={16} />
                </button>
              </div>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
