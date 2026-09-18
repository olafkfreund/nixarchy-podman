---
status: approved
issue: 1
spec: spec/2026-09-18-1-nixos-flake-menu.md
---

# Plan: NixOS-native install and a keyboard-driven Omarchy menu surface

## Approved decisions (self-contained summary)

The intent and spec are approved.

- **Id and packaging.** The plugin id becomes `nixarchy.podman`, `name` becomes
  `Podman`, `version` 0.2.0. The manifest declares
  `kinds: ["menu","bar-widget"]`, the entry points
  `{menu: Menu.qml, barWidget: Panel.qml}`, and `keepLoaded: true`. The
  `barWidget` defaults and schema do not change. `author` credits Abdullah
  Mansoor (upstream), and `homepage` points to
  `github.com/olafkfreund/nixarchy-podman`.
- **The split.** `Panel.qml` splits by responsibility:
  - **`PodmanState.qml`** holds the data. It is a non-visual `Item`; each
    surface creates one. It owns:
    - `tab` and the raw lists;
    - the status flags and the data derivations;
    - every `refresh*`, `Process` and timer;
    - the actions.

    Its inputs are `settings`, `active` and `background`. The slow timer runs
    when `background || active`; the fast, stats and resource timers run when
    `active`. When `active` becomes true it calls `refreshAll()`. It emits two
    signals:
    - `closeRequested()`, from `viewLogs`, `openShell` and `launchTui`;
    - `tabReset()`, from `setTab`.
  - **`PodmanView.qml`** holds the interaction. It is a `FocusScope` with a
    `podman` property and an input `defaultTab`. It owns:
    - the filter and cursor state;
    - `rows`, `sections`, `visibleItems`, `cursorRow` and `cursorItem`;
    - the confirm and help state, and all key handling;
    - the UI from `Panel.qml:589-908`.

    It emits `closeRequested()` and `switchPanelRequested(dir)`. Its
    `reset()` clears the interaction state, sets the default tab, drops focus
    from the text field, and then calls
    `Qt.callLater(keyCatcher.forceActiveFocus)`.
- **The two hosts.**
  - **`Panel.qml`** reads settings through `setting()` and creates a
    `PodmanState` with `background: true` and `active: opened`. It keeps
    `BarIconButton` driven by `podman.counts`, and puts a `PodmanView` inside
    `KeyboardPanel`. Tab calls `switchPanel`. `moduleName` is
    `nixarchy.podman`, and the `IpcHandler` target is `nixarchy.podman.bar`
    with the same functions as before.
  - **`Menu.qml`** follows the nixarchy-pkg shape. It is a full-screen
    `PanelWindow` on the screen Hyprland has focused, on the Overlay layer
    with `keyboardFocus: Exclusive`. A scrim closes it, and a centred card
    built from `Color.popups.*` / `Style.*` tokens holds its own
    `PodmanState` (`background: false`, `active: opened`) and a
    `PodmanView`. `open(payload)` does, in order:
    1. Re-read settings with
       `Model.settingsFor(shell.barConfig, manifest.id, manifest.barWidget.defaults)`.
    2. Take the tab from the payload (`{"tab":"…"}`). Missing or invalid
       JSON falls back to the default tab.
    3. Call `view.reset()`.
    4. Set `opened = true`.

    Every close path goes through one function, which clears `opened` and
    runs `omarchy-shell shell hide nixarchy.podman`. Tab cycles tabs.
- **Model and fixes.**
  - **`Model.settingsFor`** is a pure function. It scans `left`, `center` and
    `right` for the first entry with a matching id, and copies the known keys
    over the defaults when their types match. If `barConfig` is missing, it
    returns the defaults.
  - **pipefail.** Every piped `sh -c` starts with `set -o pipefail;`.
- **Menu row and bind.**
  - **Menu row.** `share/omarchy-menu.jsonc` adds the row `"apps.podman"`
    with the action `omarchy-shell shell toggle nixarchy.podman '{}'`. The
    user pastes it in.
  - **Hyprland bind.** The bind is `SUPER + ALT + O`. This is a change from
    the spec, which named `SUPER + ALT + P`. That key is already GitLab
    Pipelines in `~/.config/hypr/bindings.lua:328`. `O` is free in both the
    user's binds and Omarchy's defaults.
- **Flake.** The only input is `nixpkgs` (nixos-unstable).
  `packages.{x86_64,aarch64}-linux.default` is a `runCommand` named
  `nixarchy-podman-<manifest version>`. It makes real copies of exactly:
  - `manifest.json`, `LICENSE`, `Model.js`;
  - `Panel.qml`, `Menu.qml`, `PodmanState.qml`, `PodmanView.qml`;
  - `ResourceList.qml`, `TabStrip.qml`, `ShortcutSheet.qml`.

  `checks.${system}.default` runs:
  - `node tests/run.js`;
  - jq checks on the manifest (id, both kinds, every entry point file present
    in the package);
  - no symlinks in the package;
  - no `pacman` or `yay` in any `.qml` or `.js`;
  - no `"#rrggbb"` literal in any `.qml`.

  There is no HM or NixOS module. Consumers use
  `programs.nixarchy.plugins."nixarchy.podman".src`. `flake.lock` is
  committed.
- **CI and README.**
  - **CI.** `.github/workflows/ci.yml` runs `nix flake check`, then
    `nix build .#default`, then
    `test -z "$(find "$(readlink -f result)" -type l)"`.
  - **README.** NixOS install comes first. It then covers the host
    prerequisites (`virtualisation.podman.enable`, `pkgs.podman-tui`),
    migrating from `abdullahmansoor.omapodman`, the menu row and bind, the two
    ways in, IPC, and `omarchy plugin add` as the non-Nix path. Upstream
    attribution stays.
- **Out of scope.** Sending the pipefail fix upstream as a PR, and wiring
  p620/razer to the new flake input.

## Steps

Each step is one commit on `feat/1-nixos-flake-menu`, cited as `plan step N`.
Ordering keeps the bar widget working after every commit.

1. **`Panel.qml`: pipefail.** Add `set -o pipefail; ` to the start of every
   `sh -c` string that contains `|`. These are `listProcess`, `statsProcess`,
   `imagesProcess`, `volumesProcess`, `networksProcess`, `usageProcess` and
   `volumeSizeProcess`.
   → Verify: `grep -c 'pipefail' Panel.qml` is 7 or more.
   `grep -nE '"sh", "-c"' Panel.qml` shows no piped string without it.
   `node tests/run.js` passes. `sh -c 'set -o pipefail; false | head -c 1M'`
   exits 1.
2. **`Model.js` + `tests/model/settings.test.js`: `settingsFor`.**
   Export the function. Tests cover:
   - a missing or empty `barConfig`;
   - the entry in each of `left`, `center` and `right`;
   - the first match winning;
   - a wrong-type value ignored;
   - unknown keys dropped;
   - the defaults object not mutated.

   → Verify: `node tests/run.js` passes 118 plus the new tests.
3. **Split: `PodmanState.qml` + `PodmanView.qml`, with `Panel.qml` rewired.**
   The bar popup must behave exactly as before; there is no Menu yet. Move
   code verbatim wherever possible. The only new glue:
   - the `active` / `background` inputs;
   - the `closeRequested`, `tabReset` and `switchPanelRequested` signals;
   - `reset()`.

   `Panel.qml` keeps the `abdullahmansoor.omapodman` ids in this step.
   → Verify:
   - `node tests/run.js` passes.
   - `qmllint` (from `qt6.qtdeclarative`) on the three files reports no
     syntax errors. Unresolved `qs.*` imports are expected and accepted.
   - Live check, in the current dev checkout under the old id:
     `omarchy-restart-shell`, then `journalctl --user -b | grep -i omapodman`
     shows no QML errors.
   - The bar parity checklist (Tests, section B) passes.
4. **Rename + `manifest.json` + `Menu.qml`.**
   - `manifest.json` changes are the ones listed under decisions.
   - `Panel.qml` gets `moduleName` / `ipcTarget` set to `nixarchy.podman` and
     the `IpcHandler` target set to `nixarchy.podman.bar`.
   - Add `Menu.qml`.

   → Verify:
   - `omarchy plugin validate .` exits 0.
   - Install under the new id (Tests, section A), then check the
     `journalctl` QML errors are gone.
   - Tests, sections B and C pass.
5. **`share/omarchy-menu.jsonc`.** Add the `apps.podman` row. The icon is the
   same glyph as `Model.Glyph.podman`, written as a `\u` escape.
   → Verify: the row parses as JSONC. Paste it into the extension file, open
   Super+Alt+Space, search "podman", press Enter, and the menu opens.
6. **`flake.nix` + `flake.lock`** as in the decisions.
   → Verify:
   - `nix flake check` passes.
   - `nix flake check --all-systems --no-build` passes.
   - `nix build` passes, and `ls "$(readlink -f result)"` lists exactly the
     10 files.
   - `find "$(readlink -f result)" -type l` prints nothing.
   - `omarchy plugin validate "$(readlink -f result)"` exits 0.
   - Negative check: temporarily add a `"#ff0000"` to a QML file and confirm
     `nix flake check` fails. Revert it; it is not committed.
7. **`.github/workflows/ci.yml`.**
   → Verify: `actionlint` is clean, if it is available. After pushing, the
   workflow is green on the branch.
8. **`README.md`** rewritten as in the decisions.
   → Verify:
   - Every command and id in it matches the manifest and flake:
     `grep -n 'omapodman' README.md` returns only the attribution and
     migration lines.
   - The HM snippet evaluates. Check it with `nix eval` against a scratch
     flake using the local path, or by reading the nixarchy option
     definition.
9. **Close-out.** Append an "Implementation record" to this plan, covering
   deviations and results. Push, then open a PR that links the intent, spec
   and plan, says `Closes #1`, and puts the Tests results in the body.

## Tests

**A. Local install (no host config change).**
Move any dev checkout out of `~/.config/omarchy/plugins` first. Then:

```bash
nix build
cp -rL result ~/.config/omarchy/plugins/nixarchy.podman
chmod -R u+w ~/.config/omarchy/plugins/nixarchy.podman
omarchy plugin enable nixarchy.podman
omarchy-restart-shell
```

To exercise the Nix path instead, copy
`~/.config/omarchy/plugins/nixarchy.podman` as the result of a nixarchy
rebuild with the plugins option. That is optional, because host wiring is out
of scope.

**B. Bar parity** (after steps 3 and 4). Click the icon, and the popup opens.
Every key must behave as on `master`: 1-4, h/l, j/k, `/` then filter, `k`
from the first row back to the filter, enter on a container (start/stop),
enter on an image (copy), r, o, s, n, x (confirm), p (confirm), c, u, d, `?`,
Esc (filter → help → close), and Tab (next bar panel). While the popup is
closed, the badge colour and tooltip counts update at the refresh interval.
Middle-click refreshes. `omarchy shell nixarchy.podman.bar toggle` still
works; from step 4 on this uses the new id.

**C. Menu surface.**
- `omarchy-shell shell toggle nixarchy.podman '{}'` opens a full-screen
  overlay on the focused monitor, and it takes keyboard input immediately.
- The same keys as in section B work. Tab cycles the tabs.
- Esc closes it, and running the same toggle again reopens it.
- Clicking the scrim closes it.
- `'{"tab":"volumes"}'` opens it on the Volumes tab. `'garbage'` opens it on
  the default tab.
- Turn "Show CPU and memory" off in the bar widget settings, then reopen: no
  stats column, and `pgrep -af "podman stats"` finds nothing.
- In-flight action: start a stop on
  `podman run -d --name slow docker.io/library/alpine sh -c 'trap "sleep 8" TERM; sleep 1000'`
  and press Esc at once. `podman ps -a` then shows it exited.
- Idle: with the menu closed, `pgrep -af "podman (stats|images|volume|network)"`
  finds nothing over 30 seconds.

**D. pipefail.** Create a stub at `$SCRATCH/podman` that runs
`echo boom >&2; exit 125`. Run the shell with that directory first on
`PATH`: `PATH=$SCRATCH:$PATH qs -p <throwaway tree>`, or temporarily prepend
it in `listProcess` in a scratch copy. The panel must show the
"unreachable" error state, not "No containers". Revert.

**E. Automated.** `node tests/run.js` and `nix flake check` are both green.

## Rollback

- Before merge: close the PR and delete `feat/1-nixos-flake-menu`. `master`
  is untouched.
- After merge: `git revert` the merge commit.
- Local install:

  ```bash
  omarchy plugin disable nixarchy.podman
  rm -rf ~/.config/omarchy/plugins/nixarchy.podman
  omarchy-restart-shell
  ```

  Re-add the old checkout if you want it back.
- Every step is its own commit, so a single step, such as the split, can be
  reverted on its own. Steps 1, 2, 6 and 7 do not depend on the split.

## Implementation record

Deviations from the steps above, each made in the commit that needed it
(steps 1-3 were recorded late, in the step 4 commit):

- **Step 1.** With pipefail, listing output larger than the `head -c` cap
  now ends in SIGPIPE and counts as a failure, where before it was cut off
  mid-JSON and half-parsed. Accepted: neither result was usable.
- **Step 2.** The bar regions live under `bar.layout.{left,center,right}`,
  not directly on `bar` (checked in `~/.config/omarchy/shell.json` and
  `shell.qml:116`). `settingsFor` reads `barConfig.layout` and falls back to
  `barConfig` itself; bare-string entries are skipped.
- **Step 3.** Verified live through ai-mirror rather than by hand. An
  apparent focus regression turned out to be a second popup that a stray IPC
  toggle had opened on another monitor; the same key sequence matched
  `master` exactly.
- **Step 4, closing.** `Menu.close()` only sets `opened = false`; it does not
  run `omarchy-shell shell hide`. The host decides what `toggle` means from
  `loader.item.opened` (`shell.qml:1217`), so a local close is enough, and
  `keepLoaded: true` means the stale `openPanelIds` entry changes nothing.
  Verified: Esc, scrim click and external toggle all close, and the next
  toggle reopens.
- **Step 4, settings bug.** In QML, lists read through a QObject `var`
  property are Qt sequence wrappers: `Array.isArray` is false for them. So
  `settingsFor` silently returned the defaults inside the shell while its
  Node tests passed. It now accepts any list-like value, and a test with an
  array-like object reproduces the case (it fails without the fix).
- **Step 4, display name.** The popup title and tooltip read "Podman", to
  match the manifest `name`.
- **Step 4, menu size (user request).** The menu card and its text are
  drawn 1.45× larger: the same factor as nixarchy-pkg's full-screen menu, applied as one
  `scale` on the PodmanView inside `Menu.qml` (laid out at `Style.space(680)`,
  card sized to the scaled view). The bar popup is unchanged. Verified live:
  text stays sharp, and a click on a tab lands through the transform.

### Test results (p620, 2026-09-18)

- **A. Local install:** `nix build` copied into
  `~/.config/omarchy/plugins/nixarchy.podman` as a real directory, then the
  shell restarted. No QML errors. The menu opens, and the bar popup opens and
  closes through `omarchy shell nixarchy.podman.bar`.
- **B. Bar parity:** every key listed passes, driven through ai-mirror.
  Recorded in the step 3 commit.
- **C. Menu surface:** all passes, recorded in the step 4 commit:
  - Tab cycling, payload tab, scrim close, and toggle after Esc all work.
  - A stop survives an immediate Esc.
  - A settings change shows on the next open with no restart.
  - Idle cost, measured by inotify on the podman binary: 20 execs in 12s
    open, against only the bar's own poll while closed.
- **D. pipefail:** checked only at the shell level, not end to end in the
  UI. `sh -c 'set -o pipefail; false | head -c 1M'` exits 1, which sends
  `listProcess` down its existing error branch. The running shell's
  `PATH` cannot take a failing stub without restarting the whole desktop
  session.
- **E. Automated:** `node tests/run.js` passes 125/125. `nix flake check`
  passes: x86_64 is built and every system is evaluated. A planted colour
  fails the check.
- **Omarchy menu row:** searching the menu lists "Podman" under Apps, and
  clicking the row opens the menu. A keyboard-only pick inside Omarchy's own
  menu was not confirmed: its search field did not move the selection with
  ↓ during the test.

Found on this host, out of scope: rootless Podman's overlay storage reports
missing layer links. `podman system df -v` exits 125, and new containers
from `ubuntu:24.04` fail. Per-volume sizes stay blank here for that reason.
The plugin is not the cause.
