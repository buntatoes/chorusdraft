const fs = require("node:fs/promises");
const path = require("node:path");
(async () => {
  const { packager } = await import("@electron/packager");
  const root = path.resolve(__dirname, "..");
  const staging = path.join(root, "dist", "desktop-stage");
  await fs.rm(staging, { recursive: true, force: true });
  await fs.mkdir(staging, { recursive: true });
  for (const item of ["dist", "electron"])
    await fs.cp(path.join(__dirname, item), path.join(staging, item), {
      recursive: true,
    });
  const metadata = { ...require("./package.json") };
  delete metadata.dependencies;
  delete metadata.devDependencies;
  delete metadata.scripts;
  await fs.writeFile(
    path.join(staging, "package.json"),
    JSON.stringify(metadata, null, 2),
  );
  await fs.copyFile(path.join(root, "LICENSE"), path.join(staging, "LICENSE"));
  // React is bundled into the renderer; preserve its original license.
  await fs.copyFile(
    path.join(__dirname, "node_modules/react/LICENSE"),
    path.join(staging, "REACT-LICENSE"),
  );
  const outputs = await packager({
    dir: staging,
    name: "ChorusDraft",
    executableName: "ChorusDraft",
    out: path.join(root, "dist", "electron"),
    overwrite: true,
    asar: true,
    electronVersion:
      metadata.devDependencies?.electron ||
      require("./package.json").devDependencies.electron,
    platform: process.platform,
    arch: process.arch,
    appBundleId: "org.chorusdraft.desktop",
    appVersion: "0.51.4",
    appCopyright: "ChorusDraft contributors",
  });
  const native =
    process.platform === "darwin"
      ? path.join(outputs[0], "ChorusDraft.app")
      : outputs[0];
  const resources =
    process.platform === "darwin"
      ? path.join(native, "Contents", "Resources")
      : path.join(native, "resources");
  await fs.cp(
    path.join(root, "dist", "gui-backend", "chorus-bridge"),
    path.join(resources, "backend"),
    { recursive: true, dereference: false, verbatimSymlinks: true },
  );
  const target = path.join(
    root,
    "dist",
    "gui",
    process.platform === "darwin" ? "ChorusDraft.app" : "ChorusDraft",
  );
  await fs.rm(target, { recursive: true, force: true });
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.cp(native, target, {
    recursive: true,
    dereference: false,
    verbatimSymlinks: true,
  });
  console.log(`Desktop package: ${path.basename(target)}`);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
