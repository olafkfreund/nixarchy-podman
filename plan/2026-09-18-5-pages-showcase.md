---
status: approved
issue: 5
spec: spec/2026-09-18-5-pages-showcase.md
---

# Plan: GitHub Pages showcase with real captures and a user story

## Approved decisions (self-contained summary)

- **Site.** Plain Jekyll in `docs/`, with no theme gem. nixarchy's
  `_layouts/home.html`, `_layouts/manual.html`, `assets/style.css` and
  `assets/manual.js` are copied, each with a header naming the nixarchy
  commit it came from. The CSS gains a figure/caption/`<video>` block, and
  the wordmark width is retuned from 92 to 76 columns.
  - **Wordmark.** `_includes/logo.html` holds **PODMAN** in figlet Delta
    Corps Priest 1, from `xero/figlet-fonts` (sha256 prefix
    `5065f00aa615c5e2`). Only the output is committed, not the font.
  - **Config.** `_config.yml` sets `baseurl: /nixarchy-podman`, excludes
    `capture.sh`, and has a `nav:` of anchors into `/usage/`.
- **Pages.**
  - `docs/index.md` (`layout: home`) holds, in order: the user story (who
    it is for, the problem, what it does, how, why), the captioned tour,
    the install, and the "every image is real, nothing of the owner's was
    changed" line.
  - `docs/usage.md` gains front matter (`layout: manual`) and becomes
    `/usage/`.
- **Captures.**
  - **Where.** A **new, empty workspace (31) on DP-2**, opened for the
    shoot.
  - **Demo objects**, all named `demo-*`:
    - `demo-shop-web` and `demo-shop-db` (alpine, label
      `com.docker.compose.project=demo-shop`);
    - `demo-unhealthy` (a failing health check, which gives the red glyph);
    - volumes `demo-cache` (with data) and `demo-empty`;
    - network `demo-net`.
  - **Output.** 15 stills, cropped with `grim -g` to the surface, at most
    1600 px wide, optimised; three recordings (`rec-popup`, `rec-menu`,
    `rec-omarchy-menu`) as WebM (VP9) plus MP4 (H.264), 1280 px wide, no
    audio; and `demo.gif` at 800 px, 6 s, under 1.5 MB.
  - **Limits.** `docs/img/` is at most 8 MB, enforced by CI.
  - **Script.** `docs/capture.sh` makes the stills repeatable.
- **Deploy.** `.github/workflows/pages.yml` runs `configure-pages`, then
  `jekyll-build-pages` on `./docs`, then `upload-pages-artifact`, then
  `deploy-pages`, on pushes to `master` touching `docs/**` and on manual
  dispatch.
- **Other files.** `README.md` gets `demo.gif` and a link to the site.
  `AGENTS.md` gets a `docs/` row, a retake-captures rule and the capture
  procedure. The plugin, the flake and the ten-file package do not change.
- **Safety.**
  - Only `demo-*` objects are ever confirmed or removed.
  - The owner's Podman state is snapshotted before and after, and the two
    must be identical excluding `demo-*`.
  - `shell.json` and `omarchy-menu.jsonc` are backed up and restored.
  - Every image is reviewed for private data before it is committed.

## Steps

Each step is one commit on `docs/5-pages-showcase`, citing `plan step N`.
The site is built before the shoot, so the captures drop into a working
page.

1. **Site skeleton.**
   - Copy the four nixarchy files at a pinned commit, each with its source
     header.
   - Write `_config.yml`, and `logo.html` with the generated wordmark.
   - Add the front matter to `usage.md`.
   - Write `index.md` with the user story and install, with image slots
     marked but empty.

   → Verify: `nix shell nixpkgs#jekyll -c jekyll build -s docs -d
   $SCRATCH/_site` succeeds with no warnings; `/index.html` and
   `/usage/index.html` exist; the wordmark renders in the built HTML.
2. **`pages.yml`, plus the budget step in `ci.yml`.**
   → Verify: `actionlint` is clean; the budget step fails on a temporary
   9 MB dummy file and passes without it.
3. **Staging (desktop, announced first).**
   - Snapshot Podman to `$SCRATCH/before.txt` (`ps -a`, `images`,
     `volume ls`, `network ls`, names only).
   - Back up `shell.json` and the menu file.
   - Create the demo objects.
   - Switch DP-2 to **new workspace 31**.
   - Take ai-mirror control.

   → Verify: workspace 31 is active on DP-2 and has 0 windows
   (`hyprctl workspaces -j`); `podman ps -a` shows the three `demo-*`
   containers, and `demo-unhealthy` reports unhealthy.
4. **Stills, with `docs/capture.sh`.** The script does the IPC-driven
   shots. The key-driven ones use ai-mirror plus a `grim -g` crop; the
   settings panel is opened through the UI. Each still is checked right
   after it is taken.
   → Verify: all 15 files exist, and each is viewed. None shows another
   window, chat, browser tab or non-demo name.
5. **Recordings.** `wl-screenrec -g <surface region>` runs while ai-mirror
   sends the keys. Transcode to VP9/H.264 at 1280 px, and cut `demo.gif`
   with ffmpeg palettegen.
   → Verify: each video plays (`ffprobe` shows its duration and codec) and
   is watched in full; `demo.gif` is under 1.5 MB; `du -sb docs/img` is at
   most 8 MB.
6. **Teardown.**
   - Remove the `demo-*` objects.
   - Restore `shell.json` and the menu file from backup.
   - Leave workspace 31, returning DP-2 to workspace 11.
   - Release ai-mirror control.

   → Verify: a fresh snapshot equals `before.txt`; both config files
   `cmp` equal to their backups; workspace 11 is active on DP-2.
7. **Wire the captures in.** Fill the tour in `index.md` with `<figure>`s
   and `<video autoplay muted loop playsinline>` (WebM first, then MP4),
   each with a caption. Update `README.md` (GIF and site link) and
   `AGENTS.md` (`docs/` row, retake rule, capture procedure).
   → Verify: the local Jekyll build passes; every `src`/`href` in the
   built site resolves to a file; the README GIF path resolves.
8. **Close-out.**
   - Run the whole-repo checks (Tests below).
   - Add an implementation record to this plan.
   - Push and open a PR that says `Closes #5`.
   - Once CI passes, answer the Copilot review, verifying each finding.
   - **Merge only on the owner's word.** After the merge, confirm the
     Pages deploy.

## Tests

- The local Jekyll build is clean, and every internal link and asset in
  the built site resolves.
- `du -sb docs/img` is at most 8 MB, and the CI budget step passes.
- Privacy: all 15 stills and 3 videos are viewed, and nothing but the
  plugin and `demo-*` objects appears.
- The owner is untouched: the Podman snapshot before equals the snapshot
  after, excluding `demo-*`, and the config files `cmp` equal to their
  backups.
- A fresh clone has no symlinks and passes `omarchy plugin validate`;
  `nix flake check` passes, and the package is still ten files.
- After the merge: the Pages deploy succeeds; the site and `/usage/`
  return 200; the videos play.

## Rollback

- Before the merge, close the PR and delete the branch.
- After it, revert the merge commit. The Pages workflow then redeploys the
  previous `docs/`; to take the site down entirely, disable Pages in the
  repo settings.
- The shoot itself is undone by step 6. If it is interrupted,
  `docs/capture.sh --teardown` removes every `demo-*` object, and the
  config backups sit in the scratch directory.

## Implementation record

- **Step 1: wordmark width.** With trailing spaces stripped, the generated
  wordmark is 73 columns, not the 76 the spec assumed. `style.css` scales
  nixarchy's clamp by 92/73, to `clamp(0.38rem, 1.32vw, 1.11rem)`.
- **Step 1: layout headers.** The source headers in the copied layouts are
  Liquid comments, not HTML comments, so nothing is emitted before
  `<!DOCTYPE>`.
- **Step 1: links in `usage.md`.** Its two `../` links (README, menu
  snippet) became absolute GitHub URLs. The site publishes only `docs/`, so
  relative links out of it would 404 there. The absolute URLs work on both
  github.com and the site.
- **Step 4: widget placement for the shoot.** On DP-2 the widget sat in the
  right section's overflow, where the visible red icon was Herdr's. It was
  moved to the left section with `omarchy bar move` so that it could be
  clicked; `shell.json` is restored from backup at teardown.
- **Step 4: one tag per demo image.** An image with two tags (`alpine:3` and
  `localhost/demo/shop`) shows duplicate rows in the list. That is a real
  bug in `Model.js` (`imageRow` keys rows by image id, and `reconcilePlan`
  never drops the trailing duplicates), filed as **#6** for its own gated
  fix. It is not patched here. `capture.sh` untags the base images it pulled
  itself, so the captures show the plugin's correct behaviour without hiding
  the bug. The first attempt used `podman untag IMAGE`, which removes
  *every* name. Only the demo images were affected; they were re-tagged by
  id, and the script uses `podman untag IMAGE NAME`.
- **Step 4: the shortcut sheet overflows short tabs.** On Networks (two
  rows) the `?` sheet is taller than the popup and draws outside it. It was
  shot on Containers, where it fits. The overflow is filed as a follow-up
  (see Results).
- **Step 4: no settings panel.** This Omarchy build (4.0.3) registers each
  widget's settings schema but has no UI that renders it, so
  `settings.png` was dropped (14 stills, not 15). The only working route is
  `omarchy bar set <id> <key> <value> --json`. Without `--json`, booleans
  are stored as the strings `"true"`/`"false"`, and the menu's
  `settingsFor` ignores them. The docs claimed an "Omarchy settings panel"
  (text inherited from upstream); step 7 corrects that.
- **Step 4: prune wording.** The prune question names the category ("every
  volume that no container is using"), not the individual items. The docs'
  "naming what will go" is corrected in step 7.
- **Step 5: two takes discarded for privacy.** The first popup take and the
  first menu take walked the Images and Volumes tabs unfiltered, which
  showed the owner's own images (postgres, keycloak) and anonymous volumes.
  Both were deleted unencoded. The kept takes stay on Containers (demo
  containers only) and Networks (`demo-net` plus Podman's predefined
  `podman`) and use the filter. The pointer is parked off-screen, because
  a hover tooltip stayed in frame in the first menu take.
- **Step 5: Omarchy menu recording.** Recording starts after "podman" is
  typed: the menu's unfiltered first screen lists the owner's installed
  apps. So `rec-omarchy-menu` shows the filtered results and the click that
  opens the Podman menu, not the Super+Alt+Space press. (Keyboard selection
  inside Omarchy's own menu did not move with ↓ in #1 either.)
- **Step 5: sizes.** `rec-popup` 520 px at native width (the popup is
  narrower than 1280), `rec-menu` and `rec-omarchy-menu` 1280 px.
  `demo.gif` is 800 px, 7.5 s, 0.64 MB. The whole of `docs/img` is 5.5 MB.
