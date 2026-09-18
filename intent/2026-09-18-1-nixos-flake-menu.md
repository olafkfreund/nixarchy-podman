---
status: draft
issue: 1
author: olafkfreund
---

# Intent: NixOS-native install and a keyboard-driven Omarchy menu surface

## Problem

OmaPodman (forked from `i228808/omapodman`, id `abdullahmansoor.omapodman`) is a
bar-widget-only Omarchy plugin that installs with `omarchy plugin add` from the
upstream URL. On nixarchy that leaves three gaps:

- **No declarative install.** Our other plugins (nixarchy-ghtui, nixarchy-gltui,
  nixarchy-pkg) ship a flake whose package is linked in through
  `programs.nixarchy.plugins."<id>".src` and validated at build time. This one
  cannot be declared in the host flake, pinned, or checked in CI.
- **Only reachable from the bar.** There is no entry in the Omarchy menu
  (Super+Alt+Space) and no full-screen keyboard surface. If the widget is not
  placed in the bar, the plugin cannot be opened at all.
- **Podman failures are hidden.** Every list command is `podman … | head -c …`
  under `sh -c`, which returns `head`'s exit status. A failing Podman therefore
  shows "No containers" instead of the panel's error state. Checked:
  `sh -c 'false | head -c 1M'` exits 0.

The code itself has no FHS assumptions. It finds every command on `PATH`, has no
pacman/yay references, no internal symlinks and no hardcoded colours. The main
gap is packaging and integration, not portability.

## Proposed outcome

- The plugin is `nixarchy.podman`. A host installs it by adding the flake as an
  input and setting `programs.nixarchy.plugins."nixarchy.podman".src`, then
  running `nixos-rebuild switch` and `omarchy plugin enable nixarchy.podman`.
- `nix flake check` runs the Model tests and plugin-shape checks: manifest,
  entry points, no symlinks, no pacman/yay, no hex colours. CI runs the same.
- A "Podman" row in the Omarchy menu, plus an optional Hyprland bind, opens a
  full-screen overlay. It holds the keyboard and offers the same four tabs and
  the same keys as the bar popup.
- The bar widget and its popup keep working exactly as they do now.
- When Podman fails, the error state appears instead of an empty list.
- The README gives the NixOS host prerequisites: `virtualisation.podman.enable`,
  `podman-tui`, and removing an old upstream install.

## Affected users and systems

- This repository: `Panel.qml` (split into shared state and view), a new
  `Menu.qml`, `manifest.json`, `Model.js` and its tests, a new `flake.nix`,
  `flake.lock`, CI and `README.md`.
- nixarchy hosts that consume it: p620 and razer, through `/etc/nixos/flake.nix`
  and `hosts/*/nixos/nixarchy.nix` (a separate change, after this one merges).
- Users of the upstream id `abdullahmansoor.omapodman` must remove that install;
  the widget has to be re-added under the new id.

## Constraints

- Follow nixarchy-pkg and ghtui for packaging: `runCommand` with real copies,
  only the `nixpkgs` input, and no HM or NixOS module of its own.
- The plugin must pass `omarchy-plugin-validate` and nixarchy's
  `validatedPlugins`.
- Nothing may be wrapped or bundled. Runtime tools come from `PATH`, as with our
  other plugins.
- The menu surface must not poll Podman while it is closed. Closing it must not
  kill a stop or prune that is still running.
- No change in bar popup behaviour or keys.
- No credentials and no host-specific values in the flake.
- Keep upstream credit (MIT licence, author attribution).

## Open questions

- Decided during plan-mode review, with Fable and Codex as reviewers:
  - both surfaces, sharing one state and view split;
  - id `nixarchy.podman`;
  - the menu row is pasted by the user (the nixarchy-pkg convention), not
    auto-registered.

  Confirm or overturn these when approving.
- Should the pipefail fix also go upstream to `i228808/omapodman` as a separate
  PR? It is independent of the rename.
- Wiring it into p620/razer host config belongs to a follow-up in the nixos
  config repo, not this one. Agree?
