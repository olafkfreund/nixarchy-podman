---
status: draft
issue: 5
intent: intent/2026-09-18-5-pages-showcase.md
---

# Spec: GitHub Pages showcase with real captures and a user story

## Design

### Site: plain Jekyll in `docs/`, the nixarchy way

nixarchy's site (`olafkfreund/nixarchy/docs`) uses no theme gem. Its whole
look is two layouts, one include and one stylesheet. This site reuses that
structure file for file:

| File | Content |
| --- | --- |
| `docs/_config.yml` | `title: nixarchy.podman`, `baseurl: /nixarchy-podman`, a `nav:` list for the sidebar. `exclude:` keeps the capture script and raw capture sources out of the site. |
| `docs/_layouts/home.html` | nixarchy's `home.html` with names changed: masthead wordmark, tagline, centred content. |
| `docs/_layouts/manual.html` | nixarchy's `manual.html` with names changed: sidebar with search filter, content column. Its offsite links point to this repo and to nixarchy. |
| `docs/assets/style.css` | nixarchy's `style.css`, copied with a header naming the source commit, so the palette, type and spacing match. It also gets a small appended block for figures, captions and `<video>`, plus the wordmark width retuned for 76 columns instead of 92. |
| `docs/assets/manual.js` | nixarchy's sidebar-filter script, copied likewise. |
| `docs/_includes/logo.html` | The wordmark **PODMAN**, generated with figlet in Omarchy's banner typeface, Delta Corps Priest 1. The same generator nixarchy uses, so the sites read as relatives. The font is not in nixpkgs' figlet: it comes from `xero/figlet-fonts` (sha256 `5065f00aa615c5e2…`, recorded in the include's comment). Only the generated text is committed, not the font. `role="img"` and `aria-label`, as in nixarchy. |

The copied files are copies, not a submodule or a remote theme. A shared
theme repo would be the upgrade if the two sites ever need to change
together. Until then, the header comment in each copy names its source so a
refresh is a diff away.

### Pages: the home page and the manual

- **`docs/index.md`** uses `layout: home`. It holds the user story, the
  tour and the install. Content below.
- **The manual is `docs/usage.md`.** It gets front matter
  (`layout: manual`, `title`) and becomes `/usage/`. The sidebar `nav:`
  lists its sections as anchors: Requirements, Install, The bar popup, The
  full-screen menu, Everyday tasks, Settings, Troubleshooting, Removal.
  There is one guide, not a second copy.

### The user story (`index.md`)

It is written for a newcomer, in this order:

1. **Who it is for.** You run containers with rootless Podman on
   Omarchy/nixarchy, and you would rather glance at your bar than type
   `podman ps -a`.
2. **The problem.** Answering "what is running, what is broken, what is
   eating my disk, and is it safe to delete?" takes five commands
   (`podman ps -a`, `podman images`, `podman volume ls`,
   `podman system df -v`, `podman volume prune`), and the last one is
   irreversible.
3. **What it does.** One glyph shows the state: dim, bright or red. It opens
   four tabs, each split into what is unused and what is in use, biggest
   first. Every action is a key. There are two ways in: the bar popup, and
   the full-screen menu from the Omarchy menu or Super+Alt+O.
4. **How it works.** The plugin reads Podman's own output, and Podman
   decides what counts as unused, so the list matches what a prune would
   take. Nothing runs in the background except a slow poll for the glyph.
   Every destructive key asks first, with Cancel as the default. When Podman
   refuses something, its own reason is shown.
5. **Why it is built this way.** Podman's judgment is kept rather than
   guessed at. The whole thing works from the keyboard. There is no daemon
   and no wrapper, just `podman` on `PATH`. It installs as a Nix flake, like
   the rest of nixarchy.
6. **The tour.** The captures, each with a one-line caption saying what you
   are looking at and which key got you there.
7. **Install.** The short NixOS snippet, the non-Nix line, and "enable once".
   It links to the manual for everything else.
8. **A line on how the images were made:** every image is the real plugin
   on a real machine, driven from the keyboard, and nothing of the owner's
   was changed. This is the same promise nixarchy-pkg makes.

### Captures

**Staging.**
- An empty workspace on DP-2.
- Demo objects only, all named `demo-*`:
  - a small Compose-style project of two `alpine` containers carrying the
    project label, so the grouping shows;
  - one container with a failing health check, for the red glyph;
  - `demo-cache` and `demo-empty` volumes;
  - a `demo-net` network.
- The owner's own objects appear only as counts, if at all. Any
  confirmation aimed at them is cancelled.
- `shell.json` and `omarchy-menu.jsonc` are backed up before the shoot and
  restored after.

**Stills** (PNG, cropped with `grim -g` to the surface itself, at most 1600
px wide, optimised). All go in `docs/img/`:

| # | Name | Shows |
| --- | --- | --- |
| 1 | `glyph-states.png` | The three glyph states side by side (a composite of three crops of the bar segment). |
| 2 | `popup-containers.png` | The bar popup, Containers tab, with the project group and live CPU/MEM. |
| 3 | `popup-images.png` | Images: Unused and In use, sizes, footer. |
| 4 | `popup-volumes.png` | Volumes with per-volume sizes. |
| 5 | `popup-networks.png` | Networks. |
| 6 | `filter.png` | The filter narrowing a list. |
| 7 | `shortcuts.png` | The `?` sheet. |
| 8 | `confirm-remove.png` | `x` on a demo volume, the question with Cancel focused. |
| 9 | `confirm-prune.png` | `p`, naming what would go. Cancelled. |
| 10 | `podman-refuses.png` | Podman's refusal shown verbatim: removing an image a demo container still uses. |
| 11 | `menu.png` | The full-screen menu over the scrim. |
| 12 | `omarchy-menu-row.png` | The Omarchy menu searched for "podman", showing the Podman row. |
| 13 | `settings.png` | The widget's settings in the Omarchy settings panel. |
| 14 | `logs.png` | `o`: a demo container's logs in a terminal. |
| 15 | `shell.png` | `s`: a shell inside a demo container. |

**Recordings** (WebM (VP9) plus MP4 (H.264) fallback, 1280 px wide, no
audio, 10–20 s each). They are recorded with `wl-screenrec` over the
surface's region while the keys are sent through ai-mirror:

| Name | Shows |
| --- | --- |
| `rec-popup.webm/.mp4` | Click the glyph, walk the four tabs, filter, `?`, Esc. |
| `rec-menu.webm/.mp4` | Super+Alt+O, the menu opens large; Tab through the tabs; `enter` stops a demo container and the glyph dims; Esc. |
| `rec-omarchy-menu.webm/.mp4` | Super+Alt+Space, type "podman", open it from the menu row. |

**README GIF.** `demo.gif` is made from `rec-menu`: about 6 s, 800 px wide,
under 1.5 MB, built with ffmpeg's palettegen.

**Budget.** Everything in `docs/img/` totals no more than 8 MB. A CI step
fails the build above that.

**Repeatability.** `docs/capture.sh` stages the demo objects, opens each
surface over IPC, waits for its layer (`hyprctl layers`), takes the cropped
stills and tears the demo down. Stills are fully scripted. The recordings
need key input, so the script prints their steps and records the region
while an agent or a person presses the keys; this is written down in
`AGENTS.md`.

### Deploy

`.github/workflows/pages.yml` runs on pushes to `master` that touch
`docs/**`, and on manual dispatch. It runs:

1. `actions/configure-pages`
2. `actions/jekyll-build-pages` (source `./docs`)
3. `actions/upload-pages-artifact`
4. `actions/deploy-pages`

It has the `pages: write` and `id-token: write` permissions. The repo's
Pages source is already `workflow`, so no settings change is needed. The
existing `ci.yml` gains the size-budget step.

### Other files

- **`README.md`:** the demo GIF at the top, and a link to the site next to
  the guide link.
- **`AGENTS.md`:**
  - a Layout row for `docs/` (site, captures, `capture.sh`);
  - the rule "a user-visible UI change retakes the affected captures";
  - the capture procedure under Live verification.

The plugin, `flake.nix` and the package's ten files do not change.

## Alternatives rejected

- **A theme gem or `remote_theme` shared with nixarchy.** nixarchy uses
  neither: its look is local files. Building a shared theme repo is a
  project of its own, so copying with a source header is the lazy,
  honest step.
- **GIF for all the recordings.** A 15 s GIF of a 1280 px region runs to
  several MB each, which breaks the budget. The owner chose video plus one
  GIF.
- **Captures on a `gh-pages` branch or in release assets.** They would drift
  from the UI they show. The owner chose `docs/img/`.
- **Full-desktop screenshots.** They would leak other sessions, chat and
  browser tabs. Every image is cropped to the plugin's surface.
- **A mocked UI or an HTML reconstruction.** The intent requires real
  captures.
- **Unreachable and permission-denied states staged for the tour.** Making
  them means breaking the owner's Podman. They stay as text in the
  troubleshooting section.

## Risks

- **Every `plugin add` install carries the showcase.** Up to 8 MB of
  captures lands in each user's plugin folder. The budget and the CI check
  bound it; if it becomes a complaint, the upgrade path is to move the
  captures to release assets.
- **Captures go stale** when the UI changes. The `AGENTS.md` rule and
  `capture.sh` make retaking them routine.
- **Private data could leak** through an image. Crops are to the surface,
  demo data only, and every image is looked at before it is committed. The
  scrim behind the full-screen menu shows the wallpaper, not windows,
  because it is shot on an empty workspace.
- **The owner's objects could be changed during the shoot.** Only `demo-*`
  objects are ever confirmed. The Podman state is snapshotted before and
  after (`podman ps -a`, `images`, `volume ls`, `network ls`) and the two
  are compared.
- **Front matter in `usage.md` renders as a small table on github.com.**
  This is accepted, and nixarchy's manual pages do the same.
- **The desktop is in use during the shoot.** The session restarts the
  shell and takes ai-mirror control. It is announced before it starts, and
  control is released between parts.
- **Jekyll on Pages runs in safe mode.** The site uses layouts and Liquid
  only, with no plugins, exactly as nixarchy does.

## Verification

1. The site builds locally with `nix shell nixpkgs#jekyll -c jekyll build -s
   docs -d _site` (or the same action in CI), without warnings. The built
   site's internal links and asset URLs all resolve, and `/usage/` renders
   with the sidebar.
2. `du -sb docs/img` is no more than 8 MB, and the CI step enforces it.
3. **Privacy review.** Every committed image and every recording is opened
   and checked. None shows another window, chat, browser tab, terminal text
   outside the plugin, or the owner's own container names beyond counts.
4. **The owner's Podman is unchanged.** Snapshots of `podman ps -a`,
   `images`, `volume ls` and `network ls`, taken before and after the shoot
   and excluding `demo-*`, are identical. `shell.json` and the menu file
   match their backups.
5. The Pages workflow deploys, `https://olafkfreund.github.io/nixarchy-podman/`
   and `/usage/` return 200, and the videos play in a browser.
6. A fresh clone contains no symlinks and passes `omarchy plugin validate`.
   `nix flake check` passes, and the package is still ten files.
7. The README GIF is under 1.5 MB and renders on github.com.
