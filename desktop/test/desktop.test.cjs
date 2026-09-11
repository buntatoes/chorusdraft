const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { _electron } = require("playwright");
test(
  "Elixir desktop protects credentials, gates each publication, and recalls local history",
  { timeout: 240000 },
  async () => {
    const source = path.resolve(__dirname, "../..");
    const root = await fs.realpath(
      await fs.mkdtemp(path.join(os.tmpdir(), "ChorusDraft desktop test ")),
    );
    let app, page;
    try {
      await fs.copyFile(
        path.join(source, "VERSION"),
        path.join(root, "VERSION"),
      );
      await fs.mkdir(path.join(root, "elixir"));
      for (const folder of ["bluesky", "mastodon"])
        await fs.cp(
          path.join(source, "elixir", folder),
          path.join(root, "elixir", folder),
          { recursive: true },
        );
      const fixture = path.join(root, "elixir", "chorusdraft");
      const args = [
        "run",
        path.join(source, "desktop/test/build_fixture.exs"),
        fixture,
      ];
      if (process.platform === "win32")
        execFileSync(
          "cmd.exe",
          [
            "/d",
            "/s",
            "/c",
            '"mix ' + args.map((x) => '"' + x + '"').join(" ") + '"',
          ],
          {
            cwd: path.join(source, "elixir"),
            windowsVerbatimArguments: true,
            env: { ...process.env, MIX_ENV: "prod" },
            stdio: "pipe",
          },
        );
      else
        execFileSync("mix", args, {
          cwd: path.join(source, "elixir"),
          env: { ...process.env, MIX_ENV: "prod" },
          stdio: "pipe",
        });
      const userData = path.join(root, "private-settings");
      app = await _electron.launch({
        args: [
          "--force-device-scale-factor=1",
          ...(process.platform === "linux"
            ? ["--no-sandbox", "--ozone-platform=x11"]
            : []),
          ...(process.env.CHORUSDRAFT_TEST_KEYRING
            ? ["--password-store=gnome-libsecret"]
            : []),
          path.join(source, "desktop/test/entry.cjs"),
        ],
        env: {
          ...process.env,
          CHORUSDRAFT_ROOT: root,
          CHORUSDRAFT_USER_DATA: userData,
          ...(process.platform === "linux"
            ? { WAYLAND_DISPLAY: "", ELECTRON_OZONE_PLATFORM_HINT: "x11" }
            : {}),
        },
        timeout: 30000,
      });
      page = await app.firstWindow();
      page.setDefaultTimeout(30000);
      await page.getByRole("heading", { name: "Your bot workspace" }).waitFor();
      await page.evaluate(() => {
        window.sessionEvents = [];
        window.chorus.onEvent((event) => {
          if (["started", "exit", "error"].includes(event.type))
            window.sessionEvents.push({
              type: event.type,
              action: event.action,
              value: event.type === "exit" ? event.value : undefined,
            });
        });
      });
      assert.equal(
        await page.getByRole("button", { name: "Ruby", exact: true }).count(),
        0,
      );
      for (const site of ["bluesky", "mastodon"]) {
        await page.getByLabel("Social platform").selectOption(site);
        await page.getByRole("button", { name: "Set up", exact: true }).click();
        await page.getByText("Session complete", { exact: true }).waitFor();
        assert.ok(
          (await fs.stat(path.join(root, "elixir", site, ".env"))).isFile(),
        );
      }
      await page.getByLabel("Social platform").selectOption("bluesky");
      await page
        .getByRole("button", { name: "Open configuration", exact: true })
        .click();
      await page
        .getByLabel("Bluesky handle", { exact: true })
        .fill("desktop.example");
      await page
        .getByLabel("Bluesky app password", { exact: true })
        .fill("desktop-fixture-password");
      assert.equal(
        await page
          .getByLabel("Bluesky app password", { exact: true })
          .getAttribute("type"),
        "password",
      );
      const save = page.getByRole("button", {
        name: "Save securely",
        exact: true,
      });
      await page.getByLabel("Provider", { exact: true }).selectOption("chatgpt");
      await page.getByLabel("OpenAI model", { exact: true }).fill("fixture-model");
      await page.getByLabel("OpenAI API key", { exact: true }).fill("synthetic-openai-secret");
      assert.equal(await page.getByLabel("OpenAI API key", { exact: true }).getAttribute("type"), "password");
      await page.getByLabel("Provider", { exact: true }).selectOption("local");
      const secure = await save.isEnabled();
      if (!secure)
        console.log(
          "Secure storage:",
          await app.evaluate(({ safeStorage }) => ({
            available: safeStorage.isEncryptionAvailable(),
            backend:
              process.platform === "linux"
                ? safeStorage.getSelectedStorageBackend()
                : process.platform,
          })),
        );
      if (process.env.CHORUSDRAFT_TEST_KEYRING || process.platform === "win32")
        assert.ok(
          secure,
          "OS secure storage must be available on this test runner",
        );
      await (
        secure
          ? save
          : page.getByRole("button", { name: "Use for this session" })
      ).click();
      await page.getByRole("dialog").waitFor({ state: "hidden" });
      if (secure) {
        const disk = await fs.readFile(
          path.join(userData, "credentials", "bluesky.enc"),
        );
        assert.ok(!disk.includes(Buffer.from("desktop-fixture-password")));
        assert.ok(
          !(
            await fs.readFile(
              path.join(root, "elixir", "bluesky", ".env"),
              "utf8",
            )
          ).includes("BLUESKY_APP_PASSWORD="),
        );
      }
      const info = await page.evaluate(() =>
        window.chorus.settings({ runtime: "elixir", platform: "bluesky" }),
      );
      assert.equal(info.saved.BLUESKY_APP_PASSWORD, true);
      assert.equal(info.values.BLUESKY_APP_PASSWORD, undefined);
      assert.equal(
        await page.getByRole("button", { name: "Write a quote", exact: true }).count(),
        1,
      );
      await page
        .getByRole("button", { name: "Write a post", exact: true })
        .click();
      await page.getByRole("textbox", { name: "Post text" }).waitFor();
      assert.equal(await page.getByLabel("Character count").innerText(), "0/300");
      assert.match(
        await page.getByLabel("Draft visibility").innerText(),
        /^Visibility: public$/,
      );
      assert.equal(await page.getByLabel("Content warning").count(), 0);
      await page.getByLabel("Reply id").waitFor();
      await page.getByLabel("Quote id").waitFor();
      await page.getByRole("textbox", { name: "Post text" }).fill("Hi");
      assert.equal(await page.getByLabel("Character count").innerText(), "2/300");
      await page.getByRole("textbox", { name: "Post text" }).fill("x".repeat(301));
      assert.equal(
        await page.getByLabel("Character count").innerText(),
        "301/300",
      );
      assert.equal(
        await page.getByRole("button", { name: "Add to review queue" }).isDisabled(),
        true,
      );
      await page.getByRole("button", { name: "Cancel", exact: true }).click();
      await page.getByLabel("Social platform").selectOption("mastodon");
      await page
        .getByRole("button", { name: "Write a post", exact: true })
        .click();
      await page.getByRole("textbox", { name: "Post text" }).waitFor();
      assert.equal(await page.getByLabel("Character count").innerText(), "0/500");
      await page.getByLabel("Content warning").waitFor();
      assert.match(
        await page.getByLabel("Draft visibility").innerText(),
        /^Visibility: public/,
      );
      await page.getByLabel("Reply id").fill("123");
      await page.waitForFunction(() => {
        const field = document.querySelector(
          '[aria-label="Draft visibility"]',
        );
        return field && /^Visibility: unlisted/.test(field.textContent);
      });
      assert.match(
        await page.getByLabel("Draft visibility").innerText(),
        /^Visibility: unlisted/,
      );
      await page.getByRole("button", { name: "Cancel", exact: true }).click();
      await page.getByLabel("Social platform").selectOption("bluesky");
      const texts = [
        'A literal "draft" & pipes | $HOME; café',
        "This second draft requires separate approval.",
      ];
      for (const text of texts) {
        await page
          .getByRole("button", { name: "Write a post", exact: true })
          .click();
        await page.getByRole("textbox", { name: "Post text" }).fill(text);
        await page.getByRole("button", { name: "Add to review queue" }).click();
        await page.getByText("Session complete", { exact: true }).waitFor();
        assert.match(
          await page.getByRole("log").innerText(),
          /Staged manual draft /,
        );
      }
      await page.getByRole("button", { name: "Queue", exact: true }).click();
      await page.getByRole("heading", { name: "Queue", exact: true }).waitFor();
      await page.getByText(texts[0], { exact: true }).waitFor();
      await page.getByText(texts[1], { exact: true }).waitFor();
      await page
        .getByText(/Automatic attempts remaining: 5\/5/)
        .waitFor();
      const edited = "Edited from the queue for later review.";
      await page
        .locator("article")
        .filter({ hasText: texts[0] })
        .getByRole("button", { name: "Edit text", exact: true })
        .click();
      await page.getByLabel("Edited draft text").fill(edited);
      const queueSave = page.getByRole("button", {
        name: "Save edit",
        exact: true,
      });
      await queueSave.evaluate((b) => {
        b.click();
        b.click();
      });
      await page.getByText(edited, { exact: true }).waitFor();
      assert.equal(await page.getByText(texts[0], { exact: true }).count(), 0);
      await page
        .locator("article")
        .filter({ hasText: texts[1] })
        .getByRole("button", { name: "Reject", exact: true })
        .click();
      await page.getByText(texts[1], { exact: true }).waitFor({ state: "hidden" });
      await page.getByRole("button", { name: "Overview", exact: true }).click();
      await assert.rejects(fs.access(path.join(root, "published.txt")));
      await page
        .getByRole("button", { name: "Open review", exact: true })
        .click();
      await page
        .getByRole("button", { name: "Publish this draft", exact: true })
        .waitFor();
      const log = await page.getByRole("log").innerText();
      assert.ok(log.includes(edited));
      assert.ok(!log.includes(texts[0]));
      assert.ok(!log.includes("desktop-fixture-password"));
      assert.ok(log.includes("[redacted]"));
      await page.getByRole("button", { name: "Edit text", exact: true }).click();
      const editor = page.getByLabel("Replacement draft text");
      await editor.waitFor();
      await page.waitForFunction(
        (expected) => {
          const field = document.querySelector(
            '[aria-label="Replacement draft text"]',
          );
          return field && field.value === expected;
        },
        edited,
      );
      assert.equal(
        await page.getByLabel("Review response").isDisabled(),
        true,
      );
      assert.equal(
        await page
          .getByRole("button", { name: "Publish this draft", exact: true })
          .count(),
        0,
      );
      assert.equal(await editor.inputValue(), edited);
      const reviewed = "Edited during review.\nSecond line.";
      await editor.fill(reviewed);
      const saveEdit = page.getByRole("button", {
        name: "Save edit",
        exact: true,
      });
      await saveEdit.evaluate((b) => {
        b.click();
        b.click();
      });
      await page
        .getByRole("button", { name: "Publish this draft", exact: true })
        .waitFor();
      // Draft text is indented by the bot so it never starts a line.
      assert.ok(
        (await page.getByRole("log").innerText()).includes(
          "\n  Edited during review.\n  Second line.\n",
        ),
      );
      await page
        .getByRole("button", { name: "Publish this draft", exact: true })
        .evaluate((b) => {
          b.click();
          b.click();
        });
      await page.getByText("Session complete", { exact: true }).waitFor();
      assert.equal(
        await fs.readFile(path.join(root, "published.txt"), "utf8"),
        reviewed,
      );
      await page
        .getByRole("button", { name: "Write a reply", exact: true })
        .click();
      await page
        .getByLabel("Reply id")
        .fill("at://did:plc:alice/app.bsky.feed.post/fixture");
      const replyText = "A staged reply from compose.";
      await page.getByRole("textbox", { name: "Reply text" }).fill(replyText);
      assert.equal(
        await page.getByLabel("Character count").innerText(),
        `${replyText.length}/300`,
      );
      await page.getByRole("button", { name: "Add to review queue" }).click();
      await page.getByText("Session complete", { exact: true }).waitFor();
      assert.match(
        await page.getByRole("log").innerText(),
        /Staged manual draft /,
      );
      await page.getByRole("button", { name: "History", exact: true }).click();
      await page
        .getByRole("heading", { name: "History", exact: true })
        .waitFor();
      await page.getByText(reviewed, { exact: true }).waitFor();
      assert.equal(await page.getByText(texts[0], { exact: true }).count(), 0);
      assert.equal(await page.getByText(texts[1], { exact: true }).count(), 0);
      await page
        .getByRole("button", { name: "Bot activity", exact: true })
        .click();
      await page.getByLabel("Search history").fill("Credential check");
      await page
        .getByText(/Credential check: \[redacted\]/)
        .first()
        .waitFor();
      for (const name of await fs.readdir(path.join(userData, "activity")))
        assert.ok(
          !(
            await fs.readFile(path.join(userData, "activity", name), "utf8")
          ).includes("desktop-fixture-password"),
        );
    } catch (error) {
      console.error(error);
      if (page && !page.isClosed()) {
        await page.screenshot({ path: path.join(root, "failure.png") });
        console.error(await page.locator("body").innerText());
        console.error(
          "Session lifecycle:",
          await page.evaluate(() => window.sessionEvents),
        );
      }
      throw error;
    } finally {
      if (app && app.process().exitCode === null) {
        await app.evaluate(({ dialog }) => {
          dialog.showMessageBox = async () => ({ response: 1 });
        });
        await app.close();
      }
      await fs.rm(root, {
        recursive: true,
        force: true,
        maxRetries: 10,
        retryDelay: 200,
      });
    }
  },
);
