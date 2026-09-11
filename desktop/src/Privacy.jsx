import React, { useEffect, useRef, useState } from "react";
export function Settings({ selection, onClose, onSaved }) {
  const dialog = useRef(null),
    [info, setInfo] = useState(null),
    [values, setValues] = useState({}),
    [lists, setLists] = useState({
      "target_accounts.txt": "",
      "do_not_contact.txt": "",
    }),
    [clear, setClear] = useState([]),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  useEffect(() => {
    dialog.current.showModal();
    window.chorus
      .settings(selection)
      .then((v) => {
        setInfo(v);
        setValues(v.values);
        if (v.lists) setLists(v.lists);
      })
      .catch(() =>
        setError("Settings could not be opened. Check storage permissions."),
      );
  }, []);
  const save = async (persist) => {
    setBusy(true);
    setError("");
    try {
      await window.chorus.saveSettings(
        selection,
        { values, clear, lists },
        persist,
      );
      setValues({});
      onSaved(
        persist
          ? "Credentials saved securely."
          : "Credentials will be cleared when ChorusDraft closes.",
      );
      onClose();
    } catch (e) {
      setError(
        e.message.replace(/^Error invoking remote method '[^']+': Error: /, ""),
      );
    } finally {
      setBusy(false);
    }
  };
  const field = (key, label, type = "text") => (
    <label className="settings-field" key={key}>
      <span>{label}</span>
      <input
        name={key}
        type={type}
        autoComplete="off"
        spellCheck={false}
        value={values[key] || ""}
        maxLength={4096}
        disabled={busy || clear.includes(key)}
        placeholder={
          type === "password" && info?.saved[key]
            ? "Saved · leave blank to keep"
            : ""
        }
        onChange={(e) => setValues({ ...values, [key]: e.target.value })}
      />
      {type === "password" && info?.saved[key] && (
        <span className="remove-secret">
          <input
            type="checkbox"
            checked={clear.includes(key)}
            onChange={(e) =>
              setClear(
                e.target.checked
                  ? [...clear, key]
                  : clear.filter((k) => k !== key),
              )
            }
          />
          Remove saved {label.toLowerCase()}
        </span>
      )}
    </label>
  );
  return (
    <dialog
      ref={dialog}
      className="settings-dialog"
      onCancel={(e) => (busy ? e.preventDefault() : onClose())}
    >
      <div className="modal-title">
        <h2>
          {selection.platform === "bluesky" ? "Bluesky" : "Mastodon"} settings
        </h2>
        <button
          className="text-button"
          aria-label="Close settings"
          disabled={busy}
          onClick={onClose}
        >
          ×
        </button>
      </div>
      <p>
        Credentials stay on this computer. Saved passwords and tokens are never
        displayed here.
      </p>
      {error && (
        <p role="alert" className="settings-error">
          {error}
        </p>
      )}
      {!info ? (
        <p>Opening settings…</p>
      ) : (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            save(true);
          }}
        >
          <fieldset disabled={busy}>
            <legend>Social account</legend>
            <div className="settings-grid">
              {selection.platform === "bluesky" ? (
                <>
                  {field("BLUESKY_PDS_URL", "Bluesky server URL", "url")}
                  {field("BLUESKY_HANDLE", "Bluesky handle")}
                  {field(
                    "BLUESKY_APP_PASSWORD",
                    "Bluesky app password",
                    "password",
                  )}
                </>
              ) : (
                <>
                  {field("MASTODON_API_BASE_URL", "Mastodon server URL", "url")}
                  {field(
                    "MASTODON_ACCESS_TOKEN",
                    "Mastodon access token",
                    "password",
                  )}
                  <label className="settings-field">
                    <span>Default visibility</span>
                    <select
                      value={values.STATUS_VISIBILITY || "public"}
                      onChange={(e) =>
                        setValues({
                          ...values,
                          STATUS_VISIBILITY: e.target.value,
                        })
                      }
                    >
                      <option>public</option>
                      <option>unlisted</option>
                    </select>
                  </label>
                </>
              )}
            </div>
          </fieldset>
          <fieldset disabled={busy}>
            <legend>AI provider</legend>
            <div className="settings-grid">
              <label className="settings-field">
                <span>Provider</span>
                <select
                  aria-label="Provider"
                  value={
                    values.AI_PROVIDER === "ollama"
                      ? "local"
                      : values.AI_PROVIDER || "local"
                  }
                  onChange={(e) =>
                    setValues({ ...values, AI_PROVIDER: e.target.value })
                  }
                >
                  <option value="local">Local / OpenAI-compatible</option>
                  <option value="gemini">Google Gemini</option>
                  <option value="chatgpt">ChatGPT / OpenAI</option>
                  <option value="openai">OpenAI API</option>
                </select>
              </label>
              {values.AI_PROVIDER === "gemini" ? (
                <>
                  {field("GEMINI_MODEL", "Gemini model")}
                  {field("GEMINI_API_KEY", "Gemini API key", "password")}
                </>
              ) : ["chatgpt", "openai"].includes(values.AI_PROVIDER) ? (
                <>
                  {field("OPENAI_MODEL", "OpenAI model")}
                  {field("OPENAI_API_KEY", "OpenAI API key", "password")}
                </>
              ) : (
                <>
                  {field("LOCAL_LLM_URL", "AI endpoint URL", "url")}
                  {field("LOCAL_LLM_MODEL", "Local AI model")}
                  <p className="settings-hint">
                    Draft and automatic mode call this URL. Ollama needs a
                    pulled model and a path such as{" "}
                    <code>/v1/chat/completions</code>.
                  </p>
                </>
              )}
              {field("STATUS_LANGUAGE", "Post language")}
            </div>
          </fieldset>
          <fieldset disabled={busy}>
            <legend>Hours and discovery</legend>
            <div className="settings-grid">
              {field("ACTIVE_HOURS", "Active hours")}
              {field("DISCOVERY_KEYWORDS", "Discovery keywords")}
              <p className="settings-hint">
                Active hours use <code>HH:MM-HH:MM</code>. Leave blank or set
                equal start and end to stay active all day. Discovery keywords
                are comma-separated.
              </p>
            </div>
          </fieldset>
          <fieldset disabled={busy}>
            <legend>Account lists</legend>
            <div className="settings-grid">
              <label className="settings-field wide">
                <span>Target accounts</span>
                <textarea
                  name="target_accounts.txt"
                  aria-label="Target accounts"
                  spellCheck={false}
                  maxLength={262144}
                  value={lists["target_accounts.txt"] || ""}
                  disabled={busy}
                  onChange={(e) =>
                    setLists({
                      ...lists,
                      "target_accounts.txt": e.target.value,
                    })
                  }
                />
              </label>
              <label className="settings-field wide">
                <span>Do not contact</span>
                <textarea
                  name="do_not_contact.txt"
                  aria-label="Do not contact"
                  spellCheck={false}
                  maxLength={262144}
                  value={lists["do_not_contact.txt"] || ""}
                  disabled={busy}
                  onChange={(e) =>
                    setLists({
                      ...lists,
                      "do_not_contact.txt": e.target.value,
                    })
                  }
                />
              </label>
              <p className="settings-hint">
                One handle per line. <code>#</code> starts a comment. Saving
                writes{" "}
                <code>
                  elixir/{selection.platform}/config/target_accounts.txt
                </code>{" "}
                and{" "}
                <code>
                  elixir/{selection.platform}/config/do_not_contact.txt
                </code>
                .
              </p>
            </div>
          </fieldset>
          <div className="storage-note">
            <p>
              {info.available
                ? "Protected storage is available. Save securely encrypts credentials with your operating system’s key store."
                : "Secure storage is unavailable. Unlock your system keyring or use these credentials for this session only."}
            </p>
            {info.locked && (
              <p>
                Unlock the keyring, or forget saved settings before replacing
                them.
              </p>
            )}
            {info.legacy && (
              <p>
                Save securely moves the fields managed here out of this bot’s
                plaintext .env. Advanced settings remain in .env.
              </p>
            )}
            <p>
              These credentials are used for GUI launches. Use a Bluesky app
              password or a Mastodon access token.
            </p>
          </div>
          <div className="settings-actions">
            <button
              type="button"
              className="text-button danger-text"
              disabled={busy || info.mode === "unset"}
              onClick={async () => {
                setBusy(true);
                try {
                  const v = await window.chorus.forgetSettings(selection);
                  setInfo(v);
                  setValues(v.values);
                  if (v.lists) setLists(v.lists);
                  setClear([]);
                } catch {
                  setError("Settings could not be removed.");
                } finally {
                  setBusy(false);
                }
              }}
            >
              Forget saved settings
            </button>
            <div>
              <button
                type="button"
                className="button secondary"
                disabled={busy || info.locked}
                onClick={() => save(false)}
              >
                Use for this session
              </button>
              <button
                type="submit"
                className="button primary"
                disabled={busy || !info.available || info.locked}
              >
                Save securely
              </button>
            </div>
          </div>
        </form>
      )}
    </dialog>
  );
}
export function History({ selection }) {
  const [kind, setKind] = useState("posts"),
    [query, setQuery] = useState(""),
    [offset, setOffset] = useState(0),
    [data, setData] = useState(null),
    [error, setError] = useState(""),
    [revision, setRevision] = useState(0),
    [copied, setCopied] = useState("");
  useEffect(() => {
    const timer = setInterval(() => setRevision((v) => v + 1), 60000);
    const remove = window.chorus.onEvent((e) => {
      if (["exit", "history-updated"].includes(e.type))
        setRevision((v) => v + 1);
    });
    return () => {
      clearInterval(timer);
      remove();
    };
  }, []);
  useEffect(() => {
    let active = true;
    const timer = setTimeout(() => {
      window.chorus
        .history(selection, { kind, query, offset })
        .then((v) => {
          if (active) {
            setData(v);
            setError("");
          }
        })
        .catch(() => {
          if (active)
            setError(
              "Local history could not be read. Check storage permissions.",
            );
        });
    }, 150);
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [selection.platform, kind, query, offset, revision]);
  return (
    <section className="history-page" aria-label="Local history">
      <div className="eyebrow">ON THIS COMPUTER</div>
      <h1>History</h1>
      <p>
        Published posts and activity from the last 10 days. Older records are
        removed while ChorusDraft is open and at the next launch.
      </p>
      <div className="history-toolbar">
        <div className="history-tabs">
          {["posts", "activity"].map((k) => (
            <button
              key={k}
              className={kind === k ? "active" : ""}
              onClick={() => {
                setKind(k);
                setOffset(0);
                setData(null);
              }}
            >
              {k === "posts" ? "Published posts" : "Bot activity"}
            </button>
          ))}
        </div>
        <input
          aria-label="Search history"
          placeholder="Search local history…"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setOffset(0);
          }}
        />
      </div>
      {error && (
        <p className="settings-error" role="alert">
          {error}
        </p>
      )}
      {data?.failures?.length > 0 && (
        <p className="settings-error" role="alert">
          Cleanup needs attention for {data.failures.join(", ")}. Check Erlang
          is installed and the bot’s state is writable.
        </p>
      )}
      {data && !data.items.length && (
        <div className="history-empty">
          <h2>Nothing here yet</h2>
          <p>
            {kind === "posts"
              ? "Posts published successfully through ChorusDraft appear here."
              : "Activity from your GUI sessions appears here."}
          </p>
        </div>
      )}
      <div className="history-list">
        {data?.items.map((i) => (
          <article className="history-card" key={i.id}>
            <div className="history-meta">
              <time dateTime={new Date(i.time).toISOString()}>
                {new Date(i.time).toLocaleString()}
              </time>
              <span>{i.action}</span>
            </div>
            {i.account && <p className="history-account">{i.account}</p>}
            {i.cw && <p>Content warning: {i.cw}</p>}
            <pre>{i.text}</pre>
            {kind === "posts" && (
              <button
                className="text-button"
                onClick={async () => {
                  try {
                    await window.chorus.copy(i.text);
                    setCopied(i.id);
                  } catch {
                    setError("This post could not be copied to the clipboard.");
                  }
                }}
              >
                {copied === i.id ? "Copied" : "Copy post"}
              </button>
            )}
          </article>
        ))}
      </div>
      {data?.total > 0 && (
        <div className="history-pagination">
          <button
            disabled={!offset}
            className="button secondary"
            onClick={() => setOffset(Math.max(0, offset - 50))}
          >
            Previous
          </button>
          <span>
            {offset + 1}–{Math.min(offset + 50, data.total)} of {data.total}
          </span>
          <button
            disabled={offset + 50 >= data.total}
            className="button secondary"
            onClick={() => setOffset(offset + 50)}
          >
            Next
          </button>
        </div>
      )}
      <p className="history-footnote">
        ChorusDraft never uploads history. Local expiry does not delete posts
        from social sites. Pending drafts, uncertain publications and account
        safety records are retained separately.
      </p>
    </section>
  );
}
function queueSummary(name, data, error) {
  if (error) return `${name}: queue could not be read`;
  if (!data) return `${name}: reading queue`;
  const pending = data.items.filter((item) => item.status === "pending").length;
  const uncertain = data.items.filter(
    (item) => item.status === "uncertain",
  ).length;
  const freeze = data.automatic.frozen ? ", frozen" : "";
  return `${name}: ${pending} pending, ${uncertain} uncertain, ${data.automatic.remaining}/${data.automatic.limit} automatic remaining${freeze}`;
}
export function Queue({ selection, running, onRun, onReview, onPlatform }) {
  const [queues, setQueues] = useState({ bluesky: null, mastodon: null }),
    [errors, setErrors] = useState({ bluesky: "", mastodon: "" }),
    [editing, setEditing] = useState(null),
    [text, setText] = useState(""),
    [revision, setRevision] = useState(0);
  const saving = useRef(false);
  const data = queues[selection.platform];
  const error = errors[selection.platform];
  useEffect(() => {
    const timer = setInterval(() => setRevision((v) => v + 1), 60000);
    const remove = window.chorus?.onEvent((e) => {
      if (["exit", "history-updated"].includes(e.type))
        setRevision((v) => v + 1);
    });
    return () => {
      clearInterval(timer);
      if (remove) remove();
    };
  }, []);
  useEffect(() => {
    setEditing(null);
    setText("");
    saving.current = false;
  }, [selection.platform]);
  useEffect(() => {
    if (!running) saving.current = false;
  }, [running]);
  useEffect(() => {
    if (!window.chorus) return;
    let active = true;
    for (const platform of ["bluesky", "mastodon"]) {
      window.chorus
        .queue({ ...selection, platform })
        .then((v) => {
          if (!active) return;
          setQueues((prev) => ({ ...prev, [platform]: v }));
          setErrors((prev) => ({ ...prev, [platform]: "" }));
        })
        .catch(() => {
          if (active)
            setErrors((prev) => ({
              ...prev,
              [platform]:
                "The local queue could not be read. Check storage permissions.",
            }));
        });
    }
    return () => {
      active = false;
    };
  }, [running, revision]);
  const save = (item) => {
    const next = text.trim();
    if (!next || running || saving.current) return;
    saving.current = true;
    setEditing(null);
    onRun("edit", next, item.id);
  };
  const reject = (item) => {
    if (running || saving.current) return;
    saving.current = true;
    setEditing(null);
    onRun("reject", item.id);
  };
  return (
    <section className="history-page" aria-label="Draft queue">
      <div className="eyebrow">WAITING ON YOU</div>
      <h1>Queue</h1>
      <p>
        Pending drafts stay here until you review, edit, or reject them.
        Uncertain drafts freeze automatic mode until you reject them after
        checking the account. Queue reads the account store last used on each
        platform. Drafts stay on the platform that created them.
      </p>
      <div
        className="queue-platforms"
        role="group"
        aria-label="Bluesky and Mastodon queues"
      >
        {[
          ["bluesky", "Bluesky"],
          ["mastodon", "Mastodon"],
        ].map(([platform, name]) => {
          const summary = queues[platform];
          const platformError = errors[platform];
          const frozen = !!summary?.automatic.frozen;
          return (
            <button
              key={platform}
              type="button"
              className={`queue-platform${frozen ? " frozen" : ""}${selection.platform === platform ? " selected" : ""}`}
              aria-pressed={selection.platform === platform}
              aria-label={queueSummary(name, summary, platformError)}
              disabled={running}
              onClick={() => onPlatform(platform)}
            >
              <strong>{name}</strong>
              {platformError ? (
                <span>Could not read this queue</span>
              ) : !summary ? (
                <span>Reading queue…</span>
              ) : (
                <>
                  <span>
                    {
                      summary.items.filter((item) => item.status === "pending")
                        .length
                    }{" "}
                    pending
                  </span>
                  <span>
                    {
                      summary.items.filter(
                        (item) => item.status === "uncertain",
                      ).length
                    }{" "}
                    uncertain
                  </span>
                  <span>
                    Automatic remaining: {summary.automatic.remaining}/
                    {summary.automatic.limit}
                    {frozen
                      ? " · frozen while a publishing or uncertain draft is open"
                      : ""}
                  </span>
                </>
              )}
            </button>
          );
        })}
      </div>
      {error && (
        <p className="settings-error" role="alert">
          {error}
        </p>
      )}
      {data && !data.items.length && (
        <div className="history-empty">
          <h2>Queue is empty</h2>
          <p>New drafts and unresolved publications appear here.</p>
        </div>
      )}
      <div className="history-list">
        {data?.items.map((item) => (
          <article className="history-card" key={item.id}>
            <div className="history-meta">
              <span className={`queue-status ${item.status}`}>{item.status}</span>
              <span>{item.action}</span>
              {item.visibility && <span>{item.visibility}</span>}
              {item.time > 0 && (
                <time dateTime={new Date(item.time).toISOString()}>
                  {new Date(item.time).toLocaleString()}
                </time>
              )}
            </div>
            {item.account && <p className="history-account">{item.account}</p>}
            {item.reply_to && editing !== item.id && (
              <p className="queue-target">Reply: {item.reply_to}</p>
            )}
            {item.quote_to && editing !== item.id && (
              <p className="queue-target">Quote: {item.quote_to}</p>
            )}
            {item.cw && editing !== item.id && (
              <p>Content warning: {item.cw}</p>
            )}
            {editing === item.id ? (
              <>
                <label className="settings-field">
                  Draft text
                  <textarea
                    aria-label="Edited draft text"
                    maxLength={10000}
                    value={text}
                    onChange={(e) => setText(e.target.value)}
                  />
                </label>
                <div className="queue-actions">
                  <button
                    className="button secondary"
                    type="button"
                    onClick={() => setEditing(null)}
                  >
                    Cancel
                  </button>
                  <button
                    className="button primary"
                    type="button"
                    disabled={running || !text.trim()}
                    onClick={() => save(item)}
                  >
                    Save edit
                  </button>
                </div>
              </>
            ) : (
              <>
                <pre>{item.text}</pre>
                <div className="queue-actions">
                  {item.status === "pending" && (
                    <button
                      className="button secondary"
                      disabled={running}
                      onClick={() => onReview(item.id)}
                    >
                      Review this draft
                    </button>
                  )}
                  {item.status === "pending" && (
                    <button
                      className="text-button"
                      disabled={running}
                      onClick={() => {
                        setEditing(item.id);
                        setText(item.text);
                      }}
                    >
                      Edit text
                    </button>
                  )}
                  {item.status !== "publishing" && (
                    <button
                      className="text-button"
                      disabled={running}
                      onClick={() => reject(item)}
                    >
                      Reject
                    </button>
                  )}
                </div>
              </>
            )}
          </article>
        ))}
      </div>
      <p className="history-footnote">
        Review this draft starts a review session for that pending item.
        Publishing still waits for a review event. Editing re-screens the new
        text, then leaves the draft pending for review. Rejecting an uncertain
        draft clears the automatic freeze after you inspect the account.
      </p>
    </section>
  );
}
