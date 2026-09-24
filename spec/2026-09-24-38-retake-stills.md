---
status: draft
issue: 38
intent: intent/2026-09-24-38-retake-stills.md
---

# Spec: Retake the stills in the theme both machines run

## Design

### The three open questions, answered by looking

**All fourteen need retaking, including the three I expected to exempt.**

- `glyph-states.png` shows the bar glyph dim, accent and red. Both the bar
  background and the accent come from the theme, so it is not
  theme-independent. Retake.
- `logs.png` and `shell.png` show a terminal. I assumed the terminal's
  appearance was outside the theme — it is not: `alacritty.toml` lives in
  `~/.local/state/omarchy/current/theme/`, so the terminal is themed with
  everything else. `logs.png` is currently warm beige on brown. Retake.
- `omarchy-menu-row.png` shows Omarchy's own menu row, drawn by the shell
  with theme colours. Retake.

**Videos: this pass takes the stills only.** Six recordings plus `demo.gif`,
about 3.5 MB, and they need sustained key input — which is how a stray
keypress removed a container during the investigation that led here. The
stills carry most of the page's visual weight and all fourteen appear on
`index.md`. A gallery that is briefly mixed is better than a gallery that is
uniformly wrong, and much better than a destroyed container. If the stills go
cleanly the videos can be attempted in the same sitting; otherwise they are a
follow-up, stated as such rather than quietly dropped.

### The three techniques that make this safe

Each was established by failing without it earlier today:

1. **Clear the background** with `hyprctl dispatch 'hl.dsp.focus({ workspace
   = "31" })'`. The plain `hyprctl dispatch workspace 31` form silently does
   nothing on this host, which is why an earlier attempt captured the owner's
   terminal through the menu's semi-transparent scrim.
2. **Park the pointer** with `hyprctl dispatch 'hl.dsp.focus({ monitor =
   "DP-2" })'`, which moves focus *and* takes the cursor to the monitor's
   centre (1280,720 on a 1440 panel). The card occupies roughly y 108-690, so
   the cursor lands just below it and no tooltip enters the frame. Plain
   `hyprctl dispatch movecursor` silently does nothing.
3. **Prefer IPC over keys.** `Panel.qml:58` exposes
   `tab(name: string)`, so `popup-images`, `popup-volumes` and
   `popup-networks` need no key input at all, and `menu.png` takes its tab
   from the `toggle` payload. That removes key input from four of the
   fourteen outright.

### Per-image recipe

Geometry is resolved from `hyprctl layers` at capture time, never hardcoded —
the popup's monitor has moved between shell restarts all day. Each image keeps
its current dimensions so `index.md`'s layout does not shift.

| image | size | surface | how |
| --- | --- | --- | --- |
| `menu.png` | 1320x780 | menu | `toggle '{"tab":"containers"}'` |
| `popup-containers.png` | 510x565 | popup | `bar open` (default tab) |
| `popup-images.png` | 510x396 | popup | `bar tab images` |
| `popup-volumes.png` | 510x388 | popup | `bar tab volumes` |
| `popup-networks.png` | 510x362 | popup | `bar tab networks` |
| `shortcuts.png` | 510x565 | popup | key `?` |
| `filter.png` | 510x342 | popup | key `/` then type |
| `confirm-remove.png` | 510x306 | popup | key `x` on a demo row, **then Esc** |
| `confirm-prune.png` | 510x565 | popup | key `p`, **then Esc** |
| `podman-refuses.png` | 510x364 | popup | attempt to remove an in-use demo volume |
| `logs.png` | 760x110 | terminal | key `o` on `demo-shop-migrate` |
| `shell.png` | 760x140 | terminal | key `s` on a running demo container |
| `glyph-states.png` | 540x132 | bar | three shots of the glyph, composited |
| `omarchy-menu-row.png` | 324x330 | Omarchy menu | the row users paste in |

**Every dialog is screenshotted and then escaped, never confirmed.** This
repository's memory records a confirmation answered blind on razer that pruned
real containers; `confirm-remove` and `confirm-prune` exist to show the
question, not the outcome.

### Composition and staging

`docs/capture.sh --setup` creates the objects and `--unhealthy` makes
`demo-unhealthy` report unhealthy, which `glyph-states` and
`popup-containers` both need. Nothing is staged by hand.

`[font] base-size` stays at its default 12 — #39 established the menu now
follows it, so the captures must show what a new user gets rather than
whatever the machine is set to. `~/.config/omarchy/shell.toml` must be absent
during the run; it is absent by default and was confirmed so after #39.

### Budget

The stills total about 1.6 MB of a 5.76 MB directory against an 8 MB CI
limit. The one `menu.png` already produced came out at 325 KB against the
current 670 KB, so the set is more likely to shrink than grow — but
`du -sb docs/img` is checked before committing, not assumed.

## Alternatives rejected

**Retake only the menu stills.** The other eleven are equally stale on theme,
and `index.md` shows them together.

**Take them on razer to match the existing set.** The premise was wrong:
razer runs `osaka-jade` too, so the existing set matches neither machine.
Razer's shell is also not running and its plugin is the Sep 23 build.

**Switch p620 to whatever theme the old captures used.** It would reproduce a
theme nobody runs, to preserve consistency with images that are themselves
the problem.

**Composite or edit the images.** AGENTS.md: real captures only.

## Risks

- **Key input is how a container was lost today.** Mitigated by IPC wherever
  possible, by confirming the layer is up before typing, and by escaping every
  dialog rather than answering it. The objects at risk are `demo-*` only, and
  `--teardown` removes them regardless.
- **Other sessions drive this desktop.** Workspace 31 was switched back
  underneath an earlier attempt, and notifications from other agents land
  top-right where the popup is. Each capture must be inspected for a
  notification before it is kept.
- **A capture that looks fine at thumbnail size may carry a tooltip or a
  stray pixel of desktop.** Every image is viewed full size before committing,
  as AGENTS.md requires.
- **`index.md`'s captions may no longer match.** They describe behaviour, not
  theme, so most should survive — but each is read against its new image.
- **The gallery is mixed until the videos follow.** Stated in the intent as
  the approver's call; recorded here as accepted.

## Verification

1. Every image matches its previous dimensions exactly (`identify`).
2. `du -sb docs/img` is under 8,388,608 before committing, and CI's own check
   passes.
3. Each image viewed full size: nothing in frame but the plugin, `demo-*`
   objects and wallpaper. No notification, no tooltip, no desktop content
   through the scrim.
4. `docs/index.md` renders with all fourteen and each caption still describes
   its image.
5. `docs/capture.sh --teardown`, then `podman ps -a` / `images` /
   `volume ls` / `network ls` diffed against a baseline taken first: identical
   apart from nothing. The desktop is returned to its workspace.
6. `node tests/run.js` and `nix flake check` green — neither is affected, but
   a broken commit must not be the thing that discovers otherwise.
