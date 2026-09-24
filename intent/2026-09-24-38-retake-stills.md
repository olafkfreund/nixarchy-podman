---
status: approved
issue: 38
author: olafkfreund
---

# Intent: The shipped captures show a theme nobody is running

## Problem

`docs/img` holds 14 stills, every one of them used on `docs/index.md`, and
they no longer show this plugin.

**The theme moved.** Both razer and p620 currently run `osaka-jade`, whose
background is `1-glowing-city.jpg` — a green cityscape, mean colour `#0E3E2D`.
The shipped captures were taken on 2026-09-22 (`c56d21c`, #11) against a warm
painterly background: `popup-containers.png` means `#2F302D`,
`confirm-prune.png` `#2E2E2D`, `filter.png` `#31322F`, `glyph-states.png`
`#2C2B2A`, `menu.png` `#302F2D`. A capture taken today means `#13251E`. So the
site shows a theme that is not running on either machine.

**Three merged changes moved the menu underneath that.** #22 replaced a fixed
986px card with a 46% screen fraction; #30 replaced the `scale: 1.45`
transform with larger token rungs and drew `PanelHero` and `ConfirmDialog`
locally; #17 changed the `?` sheet's key column, wrapping and height. So
`menu.png` and `shortcuts.png` are wrong twice over — wrong theme *and* wrong
layout.

AGENTS.md requires a user-visible change to retake the captures it makes
wrong, in the same PR. Those three PRs did not, because the session that made
them could not drive the capture procedure. This is that debt.

**Retaking only the menu stills would not fix it.** The other eleven are
equally out of date on theme, and the site puts them next to each other.

## Proposed outcome

- Every still in `docs/img` shows the plugin as it is on `master`, in the
  theme both machines actually run, at the text size a new user gets.
- The set is internally consistent: one sitting, one theme, one text size.
- `docs/img` stays inside its 8 MB budget, which CI enforces and which the
  showcase spends because it ships inside every `omarchy plugin add` clone.
- Nothing but the plugin and `demo-*` objects appears in any frame — no
  desktop content, no notifications, no tooltips.

## Affected users and systems

- `docs/img/*.png` — 14 files, currently 5,761,828 bytes across the whole
  directory including the videos.
- `docs/index.md`, which displays all 14 and whose captions must still
  describe what the new images show.
- Anyone reading the GitHub Pages site, which is the plugin's shop window.
- p620's podman state and desktop during the run; both must be restored.

## Constraints

- **Real captures only**, of nothing but the plugin and `demo-*` objects
  (AGENTS.md). No compositing, no staging with the owner's own containers.
- `docs/capture.sh --setup` refuses if any `demo-*` name exists, records what
  it creates, and `--teardown` removes only that record. Use it; do not
  hand-roll the objects.
- **`[font] base-size` stays at its default 12.** #39 established the menu now
  follows that setting, so the captures must show what a new user sees rather
  than whatever the machine is set to.
- Each image keeps its current dimensions, so `index.md`'s layout does not
  shift.
- The 8 MB budget is shared with six videos totalling about 3.5 MB. The stills
  currently total about 1.6 MB and must not grow much.
- Look at every image before committing (AGENTS.md). A capture with a
  notification or a tooltip in frame is worse than a stale one.
- The desktop must be returned to its workspace and the podman state diffed
  against a baseline afterwards.

## Open questions

1. **Do the videos go in this pass?** Six recordings, about 3.5 MB, and they
   need sustained key input — which is where a stray keypress removed a
   container earlier today. Doing stills first is safer, but it leaves the
   site mixing new stills with old-theme video. The approver should say
   whether a half-updated gallery for a while is acceptable.
2. **Do `glyph-states.png` and `omarchy-menu-row.png` need retaking at all?**
   The first is 1,482 bytes and may be a composite of bar-glyph colours; the
   second shows Omarchy's own menu row rather than this plugin's UI. Both may
   be theme-independent enough to leave.
3. **Should `logs.png` and `shell.png` be retaken?** They show a terminal
   running `podman logs` and a shell inside a container — the terminal's
   appearance is the terminal's theme, not the plugin's, so they may already
   be fine.
