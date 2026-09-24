---
status: approved
issue: 38
spec: spec/2026-09-24-38-retake-stills.md
---

# Plan: Retake the stills in the theme both machines run

## The approved decisions, carried over

**All fourteen stills are retaken**, including the four I expected to exempt:
`alacritty.toml` lives in the theme directory, so `logs.png` and `shell.png`
are themed; `glyph-states.png` shows the bar background and accent;
`omarchy-menu-row.png` is shell-drawn.

**Stills only this pass.** The videos need sustained key input, which is how a
container was lost today. If the stills go cleanly they can be attempted after;
otherwise they are a stated follow-up.

**Three techniques, each learned by failing without it:**
`hl.dsp.focus({ workspace = "31" })` to clear the background (the plain form
silently does nothing); `hl.dsp.focus({ monitor = "DP-2" })` to park the
cursor below the card (plain `movecursor` silently does nothing); and IPC over
keys wherever possible — `Panel.qml:58`'s `tab(name)` removes key input from
three popup captures, and `menu.png` takes its tab from the payload.

**Every dialog is screenshotted and escaped, never confirmed.**

**`[font] base-size` stays at 12**, and `~/.config/omarchy/shell.toml` must be
absent during the run.

## Steps

1. **Baseline and stage.** Snapshot `podman ps -a`, `images`, `volume ls`,
   `network ls`; record the current workspace of each monitor; confirm
   `~/.config/omarchy/shell.toml` is absent and the theme is `osaka-jade`.
   Then `docs/capture.sh --setup` and `--unhealthy`.
   → verify by the state file listing eleven objects and `demo-unhealthy`
   reporting unhealthy.

2. **Clear and park.** `hl.dsp.focus({ workspace = "31" })` on DP-2, confirm
   no clients on it, then `hl.dsp.focus({ monitor = "DP-2" })` to put the
   cursor at 1280,720.
   → verify by `hyprctl clients` returning nothing for workspace 31 and
   `hyprctl cursorpos` reading 1280,720.

3. **The four that need no keys**, each geometry resolved from
   `hyprctl layers` at capture time:
   `menu.png` (1320x780) via `toggle '{"tab":"containers"}'`;
   `popup-containers.png` (510x565) via `bar open`;
   `popup-images.png` (510x396), `popup-volumes.png` (510x388) and
   `popup-networks.png` (510x362) via `bar tab <name>`.
   → verify by `identify` matching each previous size, and by viewing each.

4. **The keyed popup captures**, confirming the layer is up before every
   keypress: `shortcuts.png` (`?`), `filter.png` (`/` then type),
   `confirm-remove.png` (`x`, **then Esc**), `confirm-prune.png` (`p`,
   **then Esc**), `podman-refuses.png` (remove an in-use demo volume).
   → verify after each dialog that the demo object still exists.

5. **The terminal captures**: `logs.png` (`o` on `demo-shop-migrate`),
   `shell.png` (`s` on a running demo container). Both open a terminal window,
   so the workspace is no longer empty — capture the terminal, then close it.
   → verify by the terminal being gone before the next capture.

6. **`glyph-states.png` and `omarchy-menu-row.png`.** The glyph needs three
   states, which means changing what podman holds between shots — stop the
   demo containers for dim, start for accent, `--unhealthy` for red.
   → verify by the three glyph colours differing.

7. **Inspect every image at full size** before anything is staged. Any frame
   with a notification, a tooltip or desktop content through the scrim is
   retaken, not kept.
   → verify by viewing all fourteen.

8. **Restore.** `--teardown`, return each monitor to its recorded workspace,
   diff the podman snapshot.
   → verify by four identical diffs.

9. **Commit** only after `du -sb docs/img` is under 8,388,608 and
   `node tests/run.js` and `nix flake check` are green.

## Tests

```bash
identify docs/img/*.png     # each matches its previous dimensions
du -sb docs/img             # < 8388608
node tests/run.js           # 170
nix flake check             # all checks passed
```

Then `docs/index.md` read through with the new images in place, each caption
checked against what its image now shows.

## Rollback

`git checkout -- docs/img` restores every image; nothing else is touched. The
desktop and podman state are restored in step 8 regardless of whether the
captures are kept.
