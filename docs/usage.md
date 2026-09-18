---
layout: manual
title: The manual
permalink: /usage/
---

# Using nixarchy.podman

A walkthrough, from installing it to fixing the usual problems. For the reference
tables (every key, every setting, IPC), see the [README](https://github.com/olafkfreund/nixarchy-podman#readme).

## What it is

Podman for the Omarchy shell: containers, images, volumes and networks on four tabs.
There are two ways in, with the same tabs and the same keys:

- **The bar popup.** Click the Podman glyph in the bar.
- **The full-screen menu.** Pick **Podman** in the Omarchy menu, or press a key. It is
  larger, holds the keyboard while it is up, and works even if the widget is not in the
  bar.

## Requirements

- **Podman, running rootless.** It needs no daemon and no group membership: if
  `podman ps` works in a terminal without `sudo`, the plugin works too. On NixOS,
  `virtualisation.podman.enable = true` covers it, and normal users get subuid/subgid
  ranges by default.
- **`wl-copy`**, for the copy keys. It ships with Omarchy.
- **A terminal** for logs and shells. The plugin uses whatever `omarchy-launch-tui`
  picks.
- **[podman-tui](https://github.com/containers/podman-tui)**, optional, for the `d` key.

Every command is run by name from `PATH`; nothing is wrapped or bundled.

## Install on NixOS (nixarchy)

1. Add the flake to your system flake's inputs:

   ```nix
   inputs.nixarchy-podman = {
     url = "github:olafkfreund/nixarchy-podman";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```

2. Where you configure nixarchy (next to `programs.nixarchy.enable`), install the plugin,
   and make sure Podman is on:

   ```nix
   programs.nixarchy.plugins."nixarchy.podman".src =
     inputs.nixarchy-podman.packages.${pkgs.stdenv.hostPlatform.system}.default;

   virtualisation.podman.enable = true;              # not on by default in nixarchy
   environment.systemPackages = [ pkgs.podman-tui ]; # optional, for the `d` key
   ```

3. Rebuild with `nixos-rebuild switch`. nixarchy validates the plugin during the build
   and links it into `~/.config/omarchy/plugins/nixarchy.podman`.

4. Enable it, once per machine. Enabling is runtime state that nixarchy leaves to you:

   ```bash
   omarchy plugin enable nixarchy.podman
   ```

   This also places the widget in the right section of the bar. To put it elsewhere:

   ```bash
   omarchy bar move nixarchy.podman --section left
   ```

**Check it worked.** A Podman glyph is in the bar, and the plugin shows as enabled:

```bash
omarchy plugin list | grep nixarchy.podman
```

## Install without Nix

```bash
omarchy plugin add https://github.com/olafkfreund/nixarchy-podman
omarchy plugin enable nixarchy.podman
```

You still need Podman itself, running rootless: if `podman ps` works in a terminal
without `sudo`, it is ready.

## The bar popup

The glyph tells you the state at a glance:

| Glyph | Means |
| --- | --- |
| Dim | Nothing is running |
| Bright (accent colour) | At least one container is running |
| Red | A running container needs attention: its health check reports unhealthy, or it is restarting |

Hover it for a one-line summary, such as `1 of 2 running`. Click to open the popup, and
middle-click to refresh.

The popup has four tabs:

- **Containers**, grouped by Compose project, running first, with live CPU and memory.
- **Images, Volumes, Networks**, each split into **Unused** and **In use**, biggest
  first. Podman itself decides what counts as unused, so the list matches what a prune
  would take.

The footer says what the tab holds and, for images and volumes, how much of it is
reclaimable. On Networks it gives the count and how many are unused; Podman reports
no size for them.

## The full-screen menu

### Add it to the Omarchy menu

Open `~/.config/omarchy/extensions/omarchy-menu.jsonc` and paste the `"apps.podman"`
row from [`share/omarchy-menu.jsonc`](https://github.com/olafkfreund/nixarchy-podman/blob/master/share/omarchy-menu.jsonc) inside its top-level
`{ }`. Mind the comma between rows. Omarchy reloads the file when you save.

Now press **Super+Alt+Space** and type `podman`. The **Podman** row is under Apps;
`containers` and `docker` find it too.

### Give it a key

Add this line to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + O", "Podman", "omarchy-shell shell toggle nixarchy.podman '{}'")
```

The same key closes it again. To open it on a particular tab, pass the tab's name:

```bash
omarchy-shell shell toggle nixarchy.podman '{"tab":"volumes"}'
```

### How it differs from the popup

- It is drawn larger, centred on the monitor you are working on.
- It holds the keyboard until you close it. Esc closes it, and so does a click outside.
- **Tab** moves to the next tab. In the popup, Tab hands over to the next bar panel.
- It does not need the widget to be in the bar.
- It does nothing in the background while closed.

## Everyday tasks

Both surfaces use the same keys. Press `?` inside either to see them all.

| To | Do |
| --- | --- |
| Pick a tab | `1`–`4`, or `h` / `l` |
| Move the cursor | `j` / `k` |
| Start or stop a container | Put the cursor on it, press `enter` |
| Restart a container | `r` |
| Follow its logs | `o` opens them in a terminal |
| Get a shell inside it | `s` (running containers only) |
| Copy its name | `n` |
| Copy an id, or a volume's mount path | `c`; on Images, Volumes and Networks, `enter` does the same |
| Remove one thing | `x`. It asks first, and **Cancel** is the default |
| Reclaim space on this tab | `p`, or the footer button. It asks first, saying what kind of thing will go |
| Filter the list | `/`, then type. `↓` returns to the list; if nothing matches, it stays in the filter. The first `esc` clears the text, the second leaves the filter |
| Refresh now | `u` |
| Open podman-tui | `d` |

When Podman refuses something (a volume still in use, an image still referenced), its own
reason appears under the list until you dismiss it.

## Settings

Change these with `omarchy bar set`, which edits the widget's entry in
`~/.config/omarchy/shell.json`. Pass `--json` so a value keeps its type; without it,
`false` is stored as the text `"false"` and ignored:

```bash
omarchy bar set nixarchy.podman showStats false --json
omarchy bar set nixarchy.podman refreshIntervalSec 30 --json
omarchy bar set nixarchy.podman defaultTab '"Volumes"' --json
```

The settings are:

| Setting | Default | What it changes |
| --- | --- | --- |
| Refresh interval | 15s | How often the bar glyph re-reads Podman. An open surface refreshes every 3 seconds regardless. |
| Tab the panel opens on | Containers | Where both surfaces land when they open. |
| Show stopped containers | on | Off lists only running containers. |
| Show CPU and memory | on | Off skips `podman stats` entirely. Worth it on a laptop. |
| Measure what each volume costs | on | Off keeps the Volumes tab instant; per-volume sizes stay blank. |
| Hide the bar icon when empty | off | On hides the glyph until the Containers tab lists at least one container. |

The full-screen menu reads these each time it opens. A change applies the next time you
open it, with no restart.

## Troubleshooting

**The list says "Podman unreachable" or "No access to the Podman storage".**
The plugin could not run `podman ps`.

- Run `podman info` in a terminal; it says what is wrong.
- On NixOS, check that `virtualisation.podman.enable = true` is in your config.
- For the storage message, rootless Podman needs a subuid/subgid range for your user.
  NixOS gives normal users one by default.

**The Volumes tab shows no sizes.**

- Check that "Measure what each volume costs" is on.
- Then run `podman system df -v`. If that fails, Podman cannot measure the volumes
  either; fix the error it prints, and the sizes appear on the next refresh.

**Podman is not in the Omarchy menu.**

- Check that the row is inside the top-level `{ }` of
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`, with commas between rows.
- Check that the plugin is enabled: `omarchy plugin list | grep nixarchy.podman`.

**The old OmaPodman is still in the bar.**
An earlier install under the id `abdullahmansoor.omapodman` stays until you remove it:

```bash
omarchy plugin disable abdullahmansoor.omapodman
rm -rf ~/.config/omarchy/plugins/abdullahmansoor.omapodman
```

Its settings belong to the old id and do not carry over.

**A rebuild does not update the plugin.**
nixarchy will not replace a real directory at `~/.config/omarchy/plugins/nixarchy.podman`
with its managed link. Such a directory comes from `omarchy plugin add`, a manual copy or
a checkout. Remove that directory and rebuild.

**`d` does nothing.**
podman-tui is not installed, or not on `PATH`. Install it with your package manager;
on NixOS, add `pkgs.podman-tui` to `environment.systemPackages`.

## Removal

```bash
omarchy plugin disable nixarchy.podman
```

Then either remove the `programs.nixarchy.plugins."nixarchy.podman"` line and rebuild, or,
if you installed without Nix, run `omarchy plugin remove nixarchy.podman`. Take the
`apps.podman` row out of `omarchy-menu.jsonc`, and the bind out of `bindings.lua`.

Your containers, images, volumes and networks are not touched.
