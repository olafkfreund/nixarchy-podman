---
status: draft
issue: 1
intent: intent/2026-09-18-1-nixos-flake-menu.md
---

# Spec: NixOS-native install and a keyboard-driven Omarchy menu surface

## Design

### 1. Split `Panel.qml` into state and view, with two thin hosts

Today `Panel.qml` holds everything: settings (16-25), data and derivations
(28-102), tabs, cursor, filter and confirm logic (104-400), timers (164-194),
`onOpenedChanged` (196), eight `Process` blocks (409-542), `IpcHandler` (544),
the bar button (562) and the `KeyboardPanel` popup UI (582-908).

The split separates **data** from **interaction**, not lines 15-560 from
582-908. Cursor, filter, confirm and help code refers to view items
(`list.clear()` 107/206, `filterField` 113/201/347/352/369,
`confirmDialog` 279), so all of it belongs with the view.

- **`PodmanState.qml`** (new): non-visual `Item`, one instance per surface.
  - Inputs: `settings` (object: `refreshIntervalSec`, `showStopped`,
    `showStats`, `showVolumeSizes`), `active` (the surface is open) and
    `background` (keep the slow poll running while closed).
  - Owns: `tab`, the raw lists (`containers`, `images`, `volumes`, `networks`,
    `volumeSizes`, `usage`, `stats`), status flags (`daemonReachable`,
    `permissionDenied`, `loading`, `everLoaded`, `lastError`), the data
    derivations (`sizedVolumes`, `counts`, `tabCounts`, `usageLine`,
    `prunable`), all `refresh*()` functions, every `Process` and the four
    timers.
  - The slow timer (164) runs only when `background || active`. The fast,
    stats and resource timers (172/179/189) run when `active`. Setting
    `active` to true calls `refreshAll()`, which replaces the data half of
    `onOpenedChanged`.
  - Action entry points: `runCommand`, `runOnIds`, `stopEverything`,
    `toggleContainer`, `toggleSection`, `copy`, `viewLogs`, `openShell`,
    `launchTui`. The last three emit `closeRequested()` instead of calling
    `root.close()` (317/328/336).
  - `setTab(key)` changes only `tab` plus the refresh. It emits
    `tabReset()`, and the view answers by clearing its list and filter.
  - Every piped `sh -c` gets a `set -o pipefail;` prefix. The error branch
    in `listProcess.onExited` (416) then fires when Podman fails.
- **`PodmanView.qml`** (new): a `FocusScope` holding all interaction.
  - Property `podman: PodmanState`.
  - Owns: `filterText`, the cursor properties, `visibleItems`, `sections`,
    `rows`, `cursorRow`/`cursorItem`, the confirm and help state, the move,
    activate and remove handlers, `handleTextKey`, and the UI from
    `Panel.qml:589-908`: `keyRoot`, `PanelKeyCatcher`, filter field,
    `TabStrip`, `ResourceList`, footer, confirm dialog and `ShortcutSheet`.
  - Input `defaultTab`.
  - Signals: `closeRequested()` (Esc with nothing left to dismiss) and
    `switchPanelRequested(direction)` (Tab).
  - `reset()` holds the UI half of today's `onOpenedChanged` (197-211): it
    clears cursor, filter, help and confirm, sets `defaultTab`, clears the
    text field's focus, and then runs
    `Qt.callLater(keyCatcher.forceActiveFocus)`. This last step is the
    FocusScope gotcha from nixarchy-pkg `Menu.qml:47-56`.
  - `implicitHeight` exposes the column height, so each host can size it.
- **`Panel.qml`** (bar widget): extends `Panel` as before.
  - Reads its settings through `setting()` and passes them to one
    `PodmanState` with `background: true` and `active: opened`.
  - Keeps `BarIconButton`, driven by `podman.counts`.
  - Its `KeyboardPanel` holds a `PodmanView`, with `focusTarget` set to the
    view. `onOpenedChanged` calls `view.reset()`.
  - `switchPanelRequested` → `root.switchPanel`.
  - `closeRequested` → `root.close()`.
  - `moduleName: "nixarchy.podman"`. The `IpcHandler` target becomes
    `nixarchy.podman.bar`, so it can never shadow the host's `shell` route.
    It keeps the same functions: open, close, show, hide, toggle, refresh,
    stopAll, tab.
- **`Menu.qml`** (new): the menu entry point, shaped like
  nixarchy-pkg `Menu.qml`.
  - An `Item` with the injected `shell` and `manifest` properties, plus
    `opened`, `open(payloadJson)`, `close()` and `toggle()`.
  - A `PanelWindow` on the screen that has Hyprland focus, resolved when it
    opens. It is anchored full-screen with `exclusionMode: Ignore`,
    `WlrLayershell.layer: Overlay` and
    `WlrLayershell.keyboardFocus: Exclusive`.
  - The scrim is a `MouseArea` that closes the menu. On it sits a centred
    card built from `Color.popups.*` and `Style.*` tokens, holding a
    `PodmanView`.
  - It owns its own `PodmanState` with `background: false` and
    `active: opened`.
  - `open()` does four things in order:
    1. Re-reads settings through
       `Model.settingsFor(shell.barConfig, manifest.id, manifest.barWidget.defaults)`.
    2. Parses the payload. `{"tab":"volumes"}` picks a tab; `{}` or
       invalid JSON falls back to the configured default tab.
    3. Calls `view.reset()`.
    4. Sets `opened = true`.
  - Closing by Esc or scrim clears `opened` and runs
    `omarchy-shell shell hide nixarchy.podman`. That keeps
    `shell.openPanelIds` in sync, so the next `toggle` opens the menu instead
    of closing it.
  - `switchPanelRequested(d)` → `podman.setTab(Model.shiftTab(tab, d))`.
  - `closeRequested` → close.
- **Shared by both hosts:** `ResourceList.qml`, `TabStrip.qml`,
  `ShortcutSheet.qml` and `Model.js` stay unchanged except for the addition
  below.

### 2. `Model.js`: `settingsFor(barConfig, id, defaults)`

This is a pure function. It scans `barConfig.left`, `.center` and `.right` for
the first entry whose `id` matches, and copies the known keys over `defaults`.
Values of the wrong type are ignored. If `barConfig` is missing, it returns
`defaults`. New tests go in `tests/model/settings.test.js`.

### 3. `manifest.json`

- `id`: `nixarchy.podman`, `name`: `Podman`, `version`: `0.2.0`.
- `kinds`: `["menu", "bar-widget"]`.
- `entryPoints`: `{ "menu": "Menu.qml", "barWidget": "Panel.qml" }`.
- `keepLoaded`: `true`. Once hidden, the menu instance stays alive with no
  polling (`active` is false). A stop or prune still running when it closes
  is not killed; see `shell.qml:1192`.
- `author` credits the upstream author, and `homepage` points at the fork.
- The `barWidget` block (defaults and schema) is unchanged.

### 4. Menu row: `share/omarchy-menu.jsonc`

```jsonc
"apps.podman": {
  "icon": "<podman glyph>", "label": "Podman",
  "description": "Containers, images, volumes and networks",
  "aliases": ["podman", "containers", "docker", "images", "volumes", "networks"],
  "action": "omarchy-shell shell toggle nixarchy.podman '{}'"
}
```

The user pastes the row into
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, as with nixarchy-pkg. The
README also gives a Hyprland bind for `~/.config/hypr/bindings.lua`:
`o.bind("SUPER + ALT + P", "Podman", "omarchy-shell shell toggle nixarchy.podman '{}'")`.

### 5. `flake.nix` and `flake.lock`

- The only input is `nixpkgs` (nixos-unstable). Consumers set
  `inputs.nixpkgs.follows`.
- `packages.{x86_64-linux,aarch64-linux}.default` is a `runCommand` named
  `nixarchy-podman-<version>`, with the version read from `manifest.json`. It
  `cp`s exactly these files, as real copies:
  `manifest.json Panel.qml Menu.qml PodmanState.qml PodmanView.qml
  ResourceList.qml TabStrip.qml ShortcutSheet.qml Model.js LICENSE`.
- `checks.${system}.default` uses `nodejs` and `jq` against the built package
  and the source. It must:
  - pass `node tests/run.js`;
  - pass the jq manifest checks: `id == "nixarchy.podman"`, both kinds
    present, and every `entryPoints` value present as a file in the package;
  - find no symlinks in the package;
  - find no `pacman` or `yay` in any `.qml` or `.js` file;
  - find no `"#rrggbb"` literals in any `.qml` file.
- No HM or NixOS module. Consumers use:

```nix
inputs.nixarchy-podman = { url = "github:olafkfreund/nixarchy-podman"; inputs.nixpkgs.follows = "nixpkgs"; };
# Home Manager scope (nixarchy's user module):
programs.nixarchy.plugins."nixarchy.podman".src =
  inputs.nixarchy-podman.packages.${pkgs.stdenv.hostPlatform.system}.default;
```

### 6. CI: `.github/workflows/ci.yml`

The workflow runs on ubuntu with `install-nix-action`. It runs
`nix flake check`, then `nix build .#default`, then
`test -z "$(find "$(readlink -f result)" -type l)"`.

### 7. `README.md`

Rewrite the Installation section in this order:

1. NixOS/nixarchy install first: flake input, the plugins option,
   `nixos-rebuild switch`, and `omarchy plugin enable nixarchy.podman`.
2. Host prerequisites: `virtualisation.podman.enable = true` and
   `pkgs.podman-tui`.
3. Migrating from `abdullahmansoor.omapodman`: remove that directory, because
   HM will not replace a real directory.
4. The menu row and the bind.
5. "Two ways in": the bar popup and the full-screen menu.
6. IPC under the new ids.
7. `omarchy plugin add` as the non-Nix path.

Attribution to upstream OmaPodman and OmaDocker stays.

## Alternatives rejected

- **A menu row that summons the existing bar popup, with no QML change.** Fable
  and Codex both recommended this as the cheapest option. It fails the intent,
  because the plugin would be unreachable when the widget is not in the bar.
  The user chose both surfaces.
- **The nixarchy-pkg badge pattern: the bar icon only opens the menu.** This
  drops the bar popup, which the intent requires to keep working unchanged.
- **One `PodmanState` shared by both surfaces.** Plugin entry points are loaded
  by separate loaders with no shared object. Sharing would need a `service`
  kind, which adds a whole plugin kind to save a duplicate poll that only
  happens while both surfaces are open.
- **`keepLoaded: false`.** Host `hide()` would destroy the instance and kill an
  in-flight action.
- **Auto-registering the menu row, as ghtui `menu.py register` does.** That
  needs a Python helper and a JSONC writer. The nixarchy-pkg paste convention is
  simpler, and the row is a one-time step.
- **Wrapping dependencies or bundling Podman.** Plugins find tools on `PATH`
  under nixarchy convention, and Podman needs host-level setup
  (`virtualisation.podman`) that a plugin cannot provide.
- **An HM or NixOS module in this flake.** `programs.nixarchy.plugins` already
  validates the plugin and links it in.
- **Keeping the upstream id.** The user chose `nixarchy.podman`.

## Risks

- **Split regressions in the bar popup:** focus, filter hand-off, confirm key
  routing and Tab. The Model tests do not cover QML. Mitigation: the plan does
  the split as its own step, with a manual parity checklist over every key,
  before `Menu.qml` exists.
- **Duplicate queries while both surfaces are open.** An action in one surface
  can race the other. Accepted: Podman serialises the operations and the next
  poll reconciles. Nothing polls from a closed menu.
- **Focus on a keepLoaded menu.** A stale text-field focus could swallow keys
  on reopen. Mitigation: `reset()` clears it, then focuses the key catcher
  after `callLater`.
- **Host state getting out of sync.** If the local close fails to run
  `shell hide`, the next toggle hides an already-hidden menu. Mitigation: route
  every close through one function and test "Esc, then toggle reopens".
- **Behaviour change from `pipefail`.** A `podman stats` or `system df`
  failure now leaves stats or usage empty, where before it parsed partial
  output. That is the intended behaviour; only `listProcess` drives the error
  state.
- **Migrating from the old id.** An existing `abdullahmansoor.omapodman`
  install stays in the bar and keeps its settings under the old id.
  Mitigation: README migration steps.
- **aarch64** is evaluated but never built. Accepted, as with ghtui.
- **Hosts affected:** p620 and razer, but only once the separate host-config
  change adds the input.

## Out of scope

- Sending the pipefail fix upstream to `i228808/omapodman`. This can be a
  follow-up PR.
- Adding the flake input and plugin to p620 and razer. That is a follow-up in
  the nixos config repo.

## Verification

1. `node tests/run.js`: every test passes, including the new
   `settingsFor` tests.
2. `nix flake check` builds and runs the checks on x86_64. aarch64 is checked
   with `nix flake check --all-systems --no-build`.
3. `nix build`. Then check that
   `find "$(readlink -f result)" -type l` prints nothing, and that
   `omarchy plugin validate "$(readlink -f result)"` exits 0.
4. **pipefail:** with `PATH` pointing at a failing `podman` stub, the panel
   shows its unreachable or error state, not "No containers".
5. **Local install without touching the host config:** copy `result` to
   `~/.config/omarchy/plugins/nixarchy.podman` (a real dir), run
   `omarchy plugin enable nixarchy.podman`, then `omarchy-restart-shell`.
6. **Bar parity:** click the icon to open the popup, then check every key:
   1-4, h/l, j/k, `/`, enter, r, o, s, n, x, p, c, u, d, `?`, esc and Tab.
   Each must behave as it does before the split. The badge colour and the
   tooltip counts must update while the popup is closed.
7. **Menu, opening and keys:** paste the row. Super+Alt+Space, "podman",
   Enter must open the full-screen overlay with keyboard focus. The same keys
   must work, and Tab must cycle tabs.
8. **Menu, closing and settings:**
   - Esc closes it, and a second toggle reopens it.
   - `omarchy-shell shell toggle nixarchy.podman '{"tab":"volumes"}'` opens it
     on the Volumes tab.
   - Turn "Show CPU and memory" off in bar settings. On the next open the menu
     shows no stats, and the stats `Process` stays silent.
9. **In-flight action:** start a stop on a slow container in the menu and
   press Esc at once. The container still stops.
10. **Idle cost:** with the menu closed, `pgrep -af "podman stats"` finds
    nothing, and the only `podman ps` calls come at the bar's interval.
