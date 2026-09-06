const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { _electron } = require("playwright");

test(
  "desktop routes all four bots and requires review before a publication",
  { timeout: 120000 },
  async () => {
    const source = path.resolve(__dirname, "../..");
    const root = await fs.mkdtemp(
      path.join(os.tmpdir(), "ChorusDraft desktop test "),
    );
    let application, page;
    try {
      for (const entry of ["bluesky", "mastodon", "lib", "VERSION"])
        await fs.cp(path.join(source, entry), path.join(root, entry), {
          recursive: true,
        });
      await fs.mkdir(path.join(root, "elixir"), { recursive: true });
      for (const entry of ["bluesky", "mastodon", "chorusdraft"])
        await fs.cp(
          path.join(source, "elixir", entry),
          path.join(root, "elixir", entry),
          { recursive: true },
        );
      const probe = path.join(root, "desktop_client.rb");
      await fs.writeFile(
        probe,
        `require File.join(ENV.fetch('CHORUSDRAFT_ROOT'), 'lib/chorus_draft/cli')
class DesktopClient
  def login = nil
  def identity = 'desktop-test'
  def account_key = 'https://example.org:desktop-test'
  def actor_aliases(actor) = [actor]
  def mentioned_actors(text) = []
  def limit = 500
  def publish(draft) = File.write(File.join(ENV.fetch('CHORUSDRAFT_ROOT'), 'published.txt'), draft.fetch('text'))
end
ChorusDraft::Bluesky.define_singleton_method(:new) { |*_| DesktopClient.new }
ChorusDraft::Mastodon.define_singleton_method(:new) { |*_| DesktopClient.new }
`,
      );
      application = await _electron.launch({
        args: [
          ...(process.platform === "linux" ? ["--no-sandbox"] : []),
          path.resolve(__dirname, ".."),
        ],
        env: {
          ...process.env,
          CHORUSDRAFT_ROOT: root,
          RUBYLIB: root,
          RUBYOPT: "-rdesktop_client",
        },
        timeout: 30000,
      });
      page = await application.firstWindow();
      page.setDefaultTimeout(10000);
      await page.getByRole("heading", { name: "Your bot workspace" }).waitFor();
      const setUp = page.getByRole("button", { name: "Set up", exact: true });
      for (const runtime of ["Ruby", "Elixir"]) {
        await page.getByRole("button", { name: runtime, exact: true }).click();
        for (const platform of ["bluesky", "mastodon"]) {
          await page.getByLabel("Social platform").selectOption(platform);
          await setUp.click();
          await page.getByText("Session complete", { exact: true }).waitFor();
          const base =
            runtime === "Ruby"
              ? path.join(root, platform)
              : path.join(root, "elixir", platform);
          assert.equal((await fs.stat(path.join(base, ".env"))).isFile(), true);
        }
      }
      await page.getByRole("button", { name: "Ruby", exact: true }).click();
      await page.getByLabel("Social platform").selectOption("bluesky");
      await page
        .getByRole("button", { name: "Write a post", exact: true })
        .click();
      const text = 'A literal "draft" & pipes | $HOME; café';
      await page.getByRole("textbox", { name: "Post text" }).fill(text);
      await page.getByRole("button", { name: "Add to review queue" }).click();
      await page.getByText("Session complete", { exact: true }).waitFor();
      await assert.rejects(fs.access(path.join(root, "published.txt")));
      await page
        .getByRole("button", { name: "Open review", exact: true })
        .click();
      await page
        .getByRole("button", { name: "Publish this draft", exact: true })
        .waitFor();
      assert.ok((await page.getByRole("log").innerText()).includes(text));
      await assert.rejects(fs.access(path.join(root, "published.txt")));
      await page
        .getByRole("button", { name: "Publish this draft", exact: true })
        .click();
      await page.getByText("Session complete", { exact: true }).waitFor();
      assert.equal(
        await fs.readFile(path.join(root, "published.txt"), "utf8"),
        text,
      );
    } catch (error) {
      if (page) console.error(await page.locator("body").innerText());
      throw error;
    } finally {
      if (application) {
        await application.evaluate(({ app }) => app.exit(0)).catch(() => {});
      }
      await fs.rm(root, { recursive: true, force: true });
    }
  },
);
