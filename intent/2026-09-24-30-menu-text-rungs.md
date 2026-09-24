---
status: draft
issue: 30
author: olafkfreund
---

# Intent: The menu magnifies instead of choosing larger text

## Problem

`Menu.qml:36` declares `uiScale: 1.45` and `Menu.qml:154-156` applies it as a
QML `scale:` transform over the whole view. Everything it multiplies has
already been scaled: `Style.space()` carries the theme's spacing scale, which
carries its font scale; `Style.font.*` derives from `[font] base-size`; and
the compositor has already applied the monitor's scale to those logical
pixels. So raising the desktop's text size raises a figure that is then
magnified again.

Three consequences, in the order they hurt:

**Content is clipped, not just mis-sized.** `Menu.qml:156` sets `clip: true`
on the frame, and `listMaxHeight` (`:175-177`) is clamped to
`Style.space(560)`. Once `view.implicitHeight * 1.45` exceeds what the clamp
leaves, whatever sits below the list — the footer, the reclaimable total, the
prune button — is truncated with no way to reach it. A short screen or a
raised theme font is enough. This is the part #22 did not see at all.

**Nothing reflows.** The transform magnifies after layout, so wrap and elide
are computed at the small size and stretched. #22 identified this and
knowingly left it.

**The menu does not move with the desktop.** It sits a fixed 45% above every
other surface at every text size, and overrides a theme that deliberately
pins a font token.

### Why this reopens a decision #22 already made

#22 considered replacing the transform and **rejected it**, on the grounds
that `ConfirmDialog`, `PanelHero` and `TextField` expose no font size, so a
layout-time approach would leave the confirmation question at base size while
the list around it grew — shrinking the safety surface that #19 had just made
carry more weight. That reasoning was correct about the constraint and wrong
about the conclusion, because it only considered multiplying.

`nixarchy.distrobox` has since shipped the complete fix and answers it
directly. Read from its source, not its description:

- It does not multiply anything. `DistroboxView.qml:26-31` declares named
  text *roles* — `fontRow`, `fontLabel`, `fontIcon`, `fontGlyph`, `fontHero` —
  each resolving to a different `Style.font.*` token depending on a
  `property bool large`. `Menu.qml:154` passes `large: true`; the bar popup
  leaves it false. Every rung derives from `[font] base-size`, so the menu
  moves in step with the desktop.
- The card is wider because `viewWidth` is 680 where the popup's is 470 —
  both theme-scaled — not because of a factor.
- **It hit exactly the objection #22 raised, and solved it.** Both
  `PanelHero` (`DistroboxView.qml:374-381`) and `ConfirmDialog` (`:754-756`)
  are drawn locally instead of used, because their sizes are internal and
  "cannot be multiplied from outside". Same layout, same tokens, sized through
  the roles — each with a comment saying to delete the copy and go back if
  omarchy ever exposes the sizes.
- `flake.nix:118` fails the build on `textScale` or `uiScale` appearing in any
  `*.qml`, so neither the transform nor a flat multiplier can return.

So the choice #22 framed as "transform, or shrink the dialog" had a third
option that neither shrinks nor multiplies.

## Proposed outcome

- Raising `[font] base-size` makes the menu larger *in step with the rest of
  the desktop*, rather than larger than an already-larger figure.
- Nothing below the list is ever unreachable, on any screen height or text
  size.
- Wrap and elide are computed at the size actually displayed.
- The confirmation question stays the same size relative to the list it
  covers — the property #22 protected, kept.
- A theme that pins a font token is honoured rather than overridden.
- `nix flake check` fails if a transform or a flat multiplier returns.

## Affected users and systems

- `Menu.qml`, `PodmanView.qml`, and the drawing pieces `ResourceList.qml`,
  `TabStrip.qml`, `ShortcutSheet.qml` — 23 `pixelSize:` sites route through
  the roles.
- `Panel.qml`'s popup must be unchanged: it keeps the base rungs.
- `flake.nix`, for the check.
- Anyone on a short screen or with a raised theme font — the clipped case,
  which is silent today.
- `docs/img`: the menu's proportions and type change, so `menu.png` and the
  menu recordings need retaking. At 69% of the 8 MB budget.

## Constraints

- **Do not simply delete the multiplier.** It exists for a real reason — a
  full-screen surface is read from further away — and deleting it alone leaves
  the menu at popup text size. `nixarchy.devenv` did that and needed a
  follow-up.
- **Do not replace it with a different flat multiplier**, for the reasons
  above.
- The confirmation dialog must not end up smaller relative to its list than it
  is today. This is the #19 safety surface and the reason #22 stopped.
- Inlining a shell component is a copy that will drift. Each one must carry
  the reason and the condition for deleting it again.
- The menu is `keepLoaded`: anything screen-derived is re-derived on `open()`.
- #22's screen-fraction `viewWidth` is already merged and verified live at 47%
  of 2560. This intent must say whether that survives the rework or is
  replaced by distrobox's simpler `Style.space(680)`.

## Open questions

1. **Does #22's screen-derived `viewWidth` stay?** distrobox uses a plain
   `Style.space(680)` and lets the panel clamp it. #22 shipped a 46% screen
   fraction, measured live. Keeping both is possible; the approver should say
   whether following distrobox exactly matters more than the adaptation #22
   added.
2. **Inline `ConfirmDialog` and `PanelHero`, or upstream the `fontSize`
   properties first?** AGENTS.md already carries the upstream follow-up from
   #22. Inlining unblocks this now at the cost of two copies that must track
   the shell; waiting blocks it on someone else's release.
3. **Is a `Flickable` wanted** so the surviving clamp degrades to scrolling
   rather than truncation, as #30 suggests? It is the difference between
   "never clipped" and "clipped but reachable", and it is extra machinery.
4. **Does this supersede or extend #17?** The `?` sheet overflows a short card
   and, since #23, elides two rows. If the roles fix the sheet's sizing, #17
   may close with this; if not, it stays separate.
