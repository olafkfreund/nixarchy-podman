---
status: draft
issue: 11
intent: intent/2026-09-22-11-retake-captures.md
---

# Spec: Retake the captures that #10, #13 and #14 made wrong

Per the approved intent: one session, on p620, after #13 and #14 merged (they have,
as `master` `bc0b77a`).

## Design

### What gets retaken

Every file in `docs/img/` was checked against the current plugin: stills opened,
recordings read as frame sheets.

| File | Why it is wrong now | Retake |
| --- | --- | --- |
| `popup-containers.png` | no `DEMO-SHOP` header; a stopped container drawn red | yes |
| `menu.png` | same, in the full-screen menu | yes |
| `filter.png` | Containers filtered to `web` shows no project header | yes |
| `confirm-prune.png` | the old question, which named nothing (#14) | yes, see privacy below |
| `podman-refuses.png` | the refusal cut off at "force-…", with a 64-character id (#13) | yes |
| `shortcuts.png` | see-through, and no `tab` line (#13) | yes |
| `rec-menu.webm/.mp4` | ungrouped list, red stopped rows | yes |
| `rec-popup.webm/.mp4` | ungrouped list, old sheet | yes |
| `rec-omarchy-menu.webm/.mp4` | ends in the ungrouped list | yes |
| `demo.gif` | cut from the recordings | yes, re-cut |
| `confirm-remove.png` | its remove question is unchanged | no |
| `popup-images.png`, `popup-volumes.png`, `popup-networks.png` | unchanged views | no |
| `glyph-states.png`, `logs.png`, `shell.png`, `omarchy-menu-row.png` | unchanged | no |

Each file keeps its **name and pixel size**, so no page or README reference
changes. The recordings keep their storyboard, as read from the old frame sheets:

- `rec-menu`: the menu opens on Containers, the cursor walks, a container is stopped
  and started;
- `rec-popup`: the popup opens, a filter is typed and cleared, then the tabs, then
  the `?` sheet;
- `rec-omarchy-menu`: the Omarchy menu search, the Podman row, the menu opens.

### Privacy: which tab `confirm-prune.png` shows

Since #14, a prune question names **every** unused item on its tab, and the filter
does not limit it. On p620, the owner's own images and volumes are unused, so a
Volumes or Images prune dialog would put their names into a public image. So
`confirm-prune.png` is taken on **Containers**. p620 has no containers of its own,
so that question names only the demo container (`demo-shop-migrate`). It is read on
screen before the shot. If it names anything that is not `demo-*`, stop.

The same rule applies to every frame of every recording: nothing that is not
`demo-*` may be visible. Images and Volumes are only ever shown filtered to `demo`,
as `AGENTS.md` already says.

### The p620 session

1. **Announce** on the agent bus: p620, desktop control, plugin folder swapped,
   several shell restarts, about an hour.
2. **Record and back up.** Copy `~/.config/omarchy/plugins/nixarchy.podman` (a real
   directory from 19 September, not a link) to the scratchpad. Snapshot
   `podman ps -a`/`images`/`volume ls`/`network ls`, `~/.config/omarchy/shell.json`,
   `~/.config/omarchy/extensions/omarchy-menu.jsonc` and the clipboard.
3. **Install `master`.** Copy the `nix build` output of `bc0b77a` over that folder,
   then `omarchy-restart-shell`. Use the session's `OMARCHY_PATH` (from
   `systemctl --user show-environment`) for every `omarchy-shell` call, the #10
   trap.
4. **Stage.** Run `docs/capture.sh --setup`, then `--unhealthy`. Take a new empty
   workspace on HDMI-A-1 (1920×1080, where the originals were taken), park the
   pointer off-screen, and ask ai-mirror for control.
5. **Shoot.** Drive by keys. Take each still with `docs/capture.sh --shot NAME X,Y WxH`
   at the original size, with its position taken from the surface's layer
   geometry (`hyprctl layers`). Record with
   `wl-screenrec --low-power=off -m 30 -g "X,Y WxH"`, then encode to WebM (VP9,
   `-crf 40`) and MP4 (H.264, `-crf 28`). Re-cut `demo.gif` from `rec-popup` with the
   same palette settings as #5.
6. **Look.** Open every new still and a frame sheet of every recording before
   committing. Check nothing outside `demo-*` is visible, and that sizes match the
   originals.
7. **Tear down.** Run `docs/capture.sh --teardown`, restore the plugin folder from
   the backup, restore both config files and the clipboard, restart the shell, and
   release control. The Podman snapshot diff must be clean. Post "done" on the bus.

## Alternatives rejected

- **Taking the captures on razer:** rejected at approval. Its bar and crop sizes
  differ, so every image on the site would change.
- **`confirm-prune.png` on Volumes, as before:** leaks the owner's volume names
  (see above).
- **Pixelating the owner's names out afterwards:** a doctored capture, and one miss
  publishes them. Choosing a tab where only demo objects exist avoids the problem.
- **Linking the plugin folder to `master`'s store path:** that is the known
  follow-up of wiring p620 to this flake, which `AGENTS.md` handles separately.
  This session restores exactly what was there.

## Risks

- **p620 is shared:** other agents work on it, and the desktop is the owner's. The
  session is announced, keeps to one empty workspace, and restores the folder,
  configs and clipboard.
- **Control requests close layer-shell panels** (seen on razer by another agent), so
  ask for control before opening any surface, never mid-shot.
- **Size:** `docs/img/` is 5.0 MB today, and the recordings are about the same length
  as before. Check it is under 8 MB after re-encoding.
- **A prune dialog showing a real name:** the privacy rule above, checked on screen
  before every dialog shot.

## Verification

- Every retaken file keeps its name and pixel size (`magick identify`, `ffprobe`
  before and after).
- Every still and a frame sheet of every recording is viewed, and each shows
  `DEMO-SHOP` grouping, dim stopped rows, the opaque sheet with `tab`, the full
  refusal, or the named prune question, as its row in the table says. Nothing
  outside `demo-*` is in frame.
- `du -sb docs/img` is under 8,388,608. `nix flake check` passes (it checks
  captures for nothing, but guards the repo rules).
- The p620 Podman snapshot diff is clean, `shell.json` and `omarchy-menu.jsonc` are
  byte-identical, and the plugin folder matches its backup (`diff -r`).
- The site builds in CI (the pages workflow) after merge.
