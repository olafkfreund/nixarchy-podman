---
status: draft
issue: 30
intent: intent/2026-09-24-30-menu-text-rungs.md
---

# Spec: The menu magnifies instead of choosing larger text

## Design

Follow `nixarchy.distrobox`, which has shipped this, adapted where podman's
content differs. Every claim below was read from its source or computed.

### The mechanism: named roles, not a factor

`PodmanView.qml` gains `property bool large: false` and a set of readonly
text roles, each resolving to a different rung of the shell's ladder. Nothing
multiplies. `Menu.qml` passes `large: true`; `Panel.qml` leaves it false, so
the popup is untouched.

Podman's 23 `pixelSize:` sites use six distinct tokens, where distrobox uses
five. The ladder is `caption 10 · bodySmall 11 · body 12 · subtitle 13 ·
title 14 · heading 16 · display 24 · displayLarge 28`, with
`iconSmall = bodySmall` and `icon = title` by default:

| role | small | large | ratio | sites | what it is |
| --- | --- | --- | --- | --- | --- |
| `fontRow` | `caption` | `title` | 1.40 | 14 | subtitles, meters, footer, sheet rows |
| `fontGlyph` | `iconSmall` | `title` | 1.27 | 4 | row action glyphs |
| `fontLabel` | `body` | `heading` | 1.33 | 2 | container and resource names |
| `fontTab` | `bodySmall` | `title` | 1.27 | 1 | the tab labels (`TabStrip.qml:83`) |
| `fontIcon` | `icon` | `heading` | 1.14 | 1 | the sheet's header glyph (`ShortcutSheet.qml:50`) |
| `fontHero` | `display` | `displayLarge` | 1.17 | 1 | the Podman glyph (`PodmanView.qml:293`) |

The first five match distrobox's `fontRow`/`fontGlyph`/`fontLabel`/`fontIcon`/
`fontHero` exactly. `fontTab` is new: podman's tab strip uses `bodySmall`,
which distrobox has no equivalent of. It is given `bodySmall → title`, the
same pair as `fontGlyph`, rather than folded into it — a theme that pins
`icon-small` must not resize text.

**The ratios are deliberately uneven** (1.14 to 1.40). That is the point: a
typographic ladder, not a constant. Today's flat 1.45 sits above the largest
of them, which is why the menu currently outgrows everything else.

`Menu.qml:36` `uiScale`, `:154-156`'s `scale:`/`transformOrigin` and the
`/ uiScale` divisions all go. The view fills its frame like any other item.

### The two components that cannot be sized from outside

This is the objection #22 stopped on, and distrobox's answer is to draw them
locally:

- **`ConfirmDialog`** hardcodes `Style.font.title` and `caption` with no
  property to override (`DistroboxView.qml:754-756` records the same finding).
- **`PanelHero`** hardcodes title, body and caption; only `iconSize` is
  exposed (`DistroboxView.qml:374-381`).

Both are inlined into `PodmanView.qml`: the same layout, the same `Color.*`
and `Style.*` tokens, sized through the roles. Each carries a comment naming
why the copy exists and the condition for deleting it — AGENTS.md's
"Known follow-ups" already tracks offering `fontSize` upstream, added by #22.

`TextField` (the filter) is **not** inlined. It has no size property either,
but it is a single input whose text is transient, and copying a focus-handling
control to change one font size buys less than it costs. It keeps base size;
if that reads wrong live, it becomes its own issue.

`PanelActionButton` and `PanelSectionHeader` both expose `fontSize` and are
passed a role. No copy needed.

### `viewWidth`: #22's screen fraction survives, minus the division

The intent asked whether #22's merged derivation stays or reverts to
distrobox's plain `Style.space(680)`. **It stays**, because without the
transform the card is `viewWidth` directly rather than `viewWidth * 1.45` —
so a plain 680 would render the card *smaller than it is today*, about 27% of
a 2560 screen.

Removing the `/ uiScale` and scaling the bounds by the same 1.45 reproduces
#22's measured behaviour exactly:

```qml
readonly property int viewWidth: {
  if (!root.targetScreen) return Style.space(986)
  var target = Math.round(root.targetScreen.width * 0.46)
  return Math.max(Style.space(800), Math.min(target, Style.space(1200)))
}
```

| screen | this spec | #22, measured live |
| --- | --- | --- |
| 1366 | 800px (59%) | — |
| 1920 | 883px (46%) | 883 predicted |
| 2560 | 1178px (46%) | 1177 predicted, **1208 measured** |
| 3840 | 1200px (31%) | — |

So #22's live verification carries over rather than being discarded.

### Clipping

`Menu.qml:156` sets `clip: true` and `listMaxHeight` is clamped to
`Style.space(560)`, so content below the list is currently unreachable once
the magnified view exceeds the clamp. Removing the transform removes the
magnification that causes it, and `listMaxHeight` loses its `/ root.uiScale`.

**No `Flickable` is proposed.** The intent asked. Once nothing is magnified,
the clamp is computed from real content height, and the `Style.space(560)`
ceiling is the only remaining way to truncate — so that ceiling is raised to
derive from `panel.height` like the width does, rather than adding scrolling
machinery to make truncation survivable. If a screen short enough to clip
still exists after that, a `Flickable` becomes its own issue with a real case
behind it.

### The check

`flake.nix` gains distrobox's guard (`flake.nix:118` there), so neither the
transform nor a flat multiplier can return:

```bash
if grep -nwE 'textScale|uiScale' ${plugin}/*.qml; then
  echo "a text multiplier is back; use the large roles instead (#30)" >&2; exit 1
fi
```

### #17

Out of scope. The `?` sheet's rows elide because its text column is too
narrow, which is a width problem; this changes type size. If the roles happen
to fix it, #17 closes on its own evidence, not by assertion here.

## Alternatives rejected

**Keep the transform** — what #22 decided. Rejected: it clips content
unreachably, prevents reflow, and overrides a pinned theme token. The reason
#22 kept it (the dialog shrinking) is answered by inlining.

**Delete `uiScale` and add nothing** — what `nixarchy.devenv` did, and it
needed a follow-up. Leaves the menu at popup text size.

**A different flat multiplier** — keeps the surface a fixed percentage above
every other one at every text size, and overrides a pinned token.

**Inline `TextField` too** — copying a focus-handling control for one font
size. Rejected above.

**Wait for upstream `fontSize` properties** rather than inlining. Rejected:
it blocks a clipping bug on someone else's release. The copies carry their own
deletion condition.

## Risks

- **Two inlined shell components will drift.** This is the real cost. Each
  carries the reason and the revert condition, and AGENTS.md tracks the
  upstream ask, but a shell update that restyles `ConfirmDialog` will not
  reach the copy. The confirmation dialog is the #19 safety surface, so a
  drift there matters more than elsewhere.
- **23 mechanical edits plus two inlined components** is a large diff for a
  plugin this size, and a missed site fails silently — it keeps base size
  rather than erroring. Verification enumerates.
- **Captures.** The menu's type and proportions both change. `menu.png` and
  the menu recordings need retaking; `docs/img` is at 69% of 8 MB.
- **This replaces merged work.** #22's transform-keeping decision is reversed;
  its `viewWidth` derivation is kept. The PR must say so.

## Verification

1. `node tests/run.js` and `nix flake check` green. Neither exercises QML
   layout.
2. `grep -c 'pixelSize:'` per file equals the count of role references in that
   file — every site converted.
3. `grep -nwE 'textScale|uiScale' *.qml` returns nothing, and the new flake
   check fails when `uiScale` is reintroduced (demonstrated in a scratch
   clone, as #24's checks were).
4. Live, and this is the real verification:
   - **The clipping case first**, since it is the bug: raise `[font]
     base-size` to 16, open the menu, confirm the footer and prune button are
     still reachable. Repeat on HDMI-A-1 (1080-tall).
   - Open the menu and the bar popup side by side: the menu's text should be
     visibly larger at the same theme setting, and both should grow together
     when `base-size` changes.
   - Trigger a confirmation in the menu and check the question is sized with
     the list around it — the property #22 protected.
   - Filter to a long container name and confirm it elides at the displayed
     size.
   - Check the card is ~46% of DP-2 (2560), matching the 1208px #22 measured.
5. Retake `menu.png` and the menu recordings, frame by frame, within budget.
