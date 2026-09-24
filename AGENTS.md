# AGENTS.md

Instructions for any AI agent working in this repository: Claude Code, Codex, Copilot,
Gemini or others. `CLAUDE.md` and `.github/copilot-instructions.md` point here. This
file is the single source; when anything disagrees with it, this file wins.

## What this repository is

`nixarchy.podman` is an [Omarchy](https://omarchy.org/) shell plugin, written in
Quickshell QML. It manages Podman containers, images, volumes and networks through two
surfaces:

- **a bar widget**, whose popup sits under the glyph (`Panel.qml`);
- **a full-screen keyboard menu** (`Menu.qml`).

`flake.nix` packages the plugin for NixOS / nixarchy. It is a fork of
[OmaPodman](https://github.com/i228808/omapodman) by Abdullah Mansoor. The user guide
is [`docs/usage.md`](docs/usage.md).

## Layout

| Path | Owns |
| --- | --- |
| `Model.js` | All logic: parsing Podman output, what is unused, sorting, rows, commands, the menu's settings. Pure `.pragma library`, no QML, tested under Node. |
| `PodmanState.qml` | Data, polling timers and every `Process` that runs `podman`. One instance per surface. |
| `PodmanView.qml` | Interaction: tabs, cursor, filter, confirmations, keys, and the drawn list. Shared by both surfaces. |
| `Panel.qml` | The bar widget host: glyph, `KeyboardPanel` popup, IPC target `nixarchy.podman.bar`. |
| `Menu.qml` | The full-screen menu host (manifest kind `menu`), with the view scaled 1.45×. |
| `ResourceList.qml`, `TabStrip.qml`, `ShortcutSheet.qml` | Drawing pieces used by the view. |
| `manifest.json` | Plugin id `nixarchy.podman`, kinds `menu` + `bar-widget`, `keepLoaded: true`, settings schema. |
| `flake.nix` | The package (an explicit `files` list, real copies) and `checks.<system>.default`. |
| `share/omarchy-menu.jsonc` | The Omarchy menu row users paste in. |
| `tests/` | Node tests for `Model.js` (`tests/run.js`). |
| `intent/`, `spec/`, `plan/` | Per-task design artifacts. See Workflow. |
| `docs/usage.md` | The user guide; also the site's `/usage/` page (front matter on top). |
| `docs/` (rest) | The GitHub Pages site: `index.md` (user story and tour), `_layouts/`, `_includes/logo.html`, `assets/` copied from nixarchy with source headers, `img/` captures, `capture.sh`. Deployed by `.github/workflows/pages.yml`. |

## Commands

```bash
node tests/run.js                              # Model tests
nix flake check                                # tests + manifest, entry points, no symlinks, no pacman/yay, no hex colours
nix flake check --all-systems --no-build       # aarch64 evaluates
nix build                                      # the plugin folder, exactly as nixarchy links it
omarchy plugin validate "$(readlink -f result)"
```

To see the repo as `omarchy plugin add` would, validate a fresh clone rather than
the working tree. The `result` link that `nix build` leaves behind is itself a symlink,
so validating `.` fails once you have built:

```bash
d=$(mktemp -d) && git clone -q . "$d/p" && rm -rf "$d/p/.git" && omarchy plugin validate "$d/p"
```

## Verifying live (on a nixarchy desktop)

1. Put the plugin in place. Either copy the build:
   `cp -rL result ~/.config/omarchy/plugins/nixarchy.podman && chmod -R u+w ~/.config/omarchy/plugins/nixarchy.podman`.
   Or link the checkout:
   `ln -s "$PWD" ~/.config/omarchy/plugins/nixarchy.podman`.
   Then enable it once: `omarchy plugin enable nixarchy.podman`.
2. `omarchy-restart-shell`, then wait until `omarchy-shell shell ping` answers.
3. Read the log for errors. Get the instance id from `qs list --all`, then run
   `qs log -i <instance>`.
4. Open each surface:
   - the menu: `omarchy-shell shell toggle nixarchy.podman '{}'`, or
     `'{"tab":"volumes"}'` for a given tab;
   - the popup: `omarchy shell nixarchy.podman.bar open`.
5. See what is up with `hyprctl layers -j`. The menu's layer namespace is
   `nixarchy-podman-menu`; the popup's is `omarchy-keyboard-panel`.

Caveats:

- Restarting the shell drops ai-mirror desktop control, so take it again.
- With several monitors, the bar IPC target reaches one monitor's bar only.
- The menu opens on the monitor that has focus.
- Keys sent before a surface holds the keyboard land in whatever window had focus.
  Confirm the layer is up before typing.

## Retaking the captures

Real captures only, and never of anything but the plugin and `demo-*` objects:

1. Snapshot `podman ps -a` / `images` / `volume ls` / `network ls`, and back up
   `~/.config/omarchy/shell.json` and `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
2. `docs/capture.sh --setup`, then `--unhealthy`. Setup refuses if any demo name
   already exists, and records what it creates; teardown removes only that record. Open a new, empty workspace
   (`hyprctl dispatch 'hl.dsp.focus({ workspace = "31" })'`), and park the pointer
   off-screen so no tooltip lands in frame.
3. Drive the surface with keys, then `docs/capture.sh --shot NAME X,Y WxH` to crop it.
   Filter to `demo` on Images and Volumes: unfiltered, they show the owner's own images
   and volumes. Recordings: `wl-screenrec --low-power=off -m 30 -g "X,Y WxH"`, then
   encode to WebM (VP9, `-crf 40`) and MP4 (H.264, `-crf 28`).
4. Look at every image and a frame sheet of every video before committing.
5. `docs/capture.sh --teardown`, restore both config files, and diff the snapshot:
   it must be identical apart from `demo-*`. Videos get `controls` (they autoplay and
   loop, so people need a way to stop them).

## Rules

Each rule records a real failure or a hard constraint:

- **No symlinks anywhere in the repository.** `omarchy plugin add` clones this repo
  *as* the plugin folder, and `omarchy-plugin-validate` refuses any symlink inside
  one. That is why `CLAUDE.md` imports `AGENTS.md` instead of linking to it.
- **No hardcoded colours.** Use `Color.*` and `Style.*` tokens, so themes switch
  cleanly. `nix flake check` fails on `"#rrggbb"`.
- **No `pacman` or `yay`**, not even in comments. nixarchy fails the rebuild on them.
- **A new runtime file goes in the `files` list in `flake.nix`**, or it is not in the
  package.
- **Run external commands by name from `PATH`.** Never wrap or bundle them. A missing
  command fails silently inside a QML `Process`, so document it as a requirement.
- **Every piped `sh -c` starts with `set -o pipefail`, and the first command inside a
  `{ …; }` group ends with `|| exit 1`.** Without them, a failing `podman` looks
  like an empty list.
- **Lists read through a QObject `var` property are Qt sequence wrappers, not JS
  arrays.** Check `length`, not `Array.isArray` (see `Model.settingsFor`).
- **The menu is keep-loaded.** `open()` must reset the view's state, drop the filter
  field's focus and refocus the key catcher; otherwise the next keys land in a stale
  filter.
- **`PodmanState` does not poll while its surface is closed.** The bar's slow
  background poll for the glyph is the only exception.
- **Logic goes in `Model.js`, with a Node test.** Keep QML to drawing and wiring.
- **A user-visible change updates `docs/usage.md` (and the README tables) in the same
  PR, and retakes the captures in `docs/img/` it makes wrong.** `docs/img/` must stay
  under 8 MB (CI enforces it): it ships inside every `omarchy plugin add` clone.

## Workflow

Any task tracked as an issue, or touching more than one file, goes through three
artifacts with the slug `YYYY-MM-DD-<issue>-<slug>`. Typos, lock bumps and one-line
config changes are exempt.

1. `intent/<slug>.md` (why), committed as `status: draft`. Stop for the owner's
   review.
2. After approval, `spec/<slug>.md` (what). Stop.
3. After approval, `plan/<slug>.md` (how, self-contained). Stop.
4. Implement only once the plan is `status: approved`.

Rules for the gates:

- Never approve an artifact yourself.
- Record each approval as its own commit, for example
  `docs(plan): approve <slug> (#N)`.
- Make one commit per plan step, citing the step.
- A deviation updates `plan/` in the same commit as the code.
- The PR links all three artifacts and closes the issue. Review compares the diff to
  `plan/`.

Branches are `feat|fix|docs/<issue>-<slug>`. Commit subjects use Conventional
Commits (`feat:`, `fix:`, `docs:`, `build:`, `ci:`, `refactor:`), each with the issue
number.

## Known follow-ups

- Wire p620 and razer to this flake. Remove any real
  `~/.config/omarchy/plugins/nixarchy.podman` directory first, because nixarchy will
  not replace it.
- Offer the `pipefail` fix upstream to `i228808/omapodman`.
- Offer `fontSize` properties for `PanelHero`, `TextField` and `ConfirmDialog`
  upstream. Until they exist, the menu must magnify with a transform rather than
  a layout-time multiplier, and long names elide against the pre-transform width
  (#22).
