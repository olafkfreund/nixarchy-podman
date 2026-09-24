---
status: approved
issue: 17
author: olafkfreund
---

# Intent: The card should make room for the shortcut sheet

## Problem

#17 asked that "the sheet is always fully readable". The merged work
(PR #35) stopped it escaping its card — the content is bounded, top-aligned
on overflow so nothing is lost above the edge, and every row is reachable —
but it did not make the sheet readable in one view. Observed on p620 after
that merge: on the full-screen menu with no containers, and on the Networks
tab with two rows, the sheet shows about **seven of its nineteen rows**, the
rest behind a scroll with nothing indicating it is there.

PR #35's spec assumed that fixing the wasted width would shrink the sheet
enough that scrolling would be rare. It does the opposite: wrapping the long
rows adds height. That assumption is recorded as a deviation in
`plan/2026-09-24-17-shortcut-sheet-fits.md`.

**The card is small because the list is small, and the sheet has no say in
it.** Both surfaces size from `PodmanView.implicitHeight`, which is
`column.implicitHeight` — the rows, the filter, the footer. The sheet is an
overlay at `z: 5` and contributes nothing:

- `Menu.qml:136` — `card.height = min(view.implicitHeight + insets,
  panel.height * 0.85)`
- `Panel.qml:94` — `contentHeight: panel.fittedContentHeight(view.implicitHeight)`

So on a screen with room to spare, the sheet is squeezed into a card sized
for an empty list.

## Proposed outcome

- Pressing `?` shows the whole sheet, on either surface, whenever the screen
  has room for it — which on a full-screen menu is essentially always.
- Where the screen genuinely does not have room, the behaviour PR #35 shipped
  still applies: bounded, top-aligned, scrollable, nothing lost above.
- Each host keeps its own limit. The menu's 85%-of-panel cap and the popup's
  fitted height are not bypassed; the sheet asks for room and takes what the
  host can give.
- The rows behind the sheet do not visibly reflow while it is open — the
  sheet covers them, and it should not look like the list moved underneath.

## Affected users and systems

- `PodmanView.qml`, where `implicitHeight` is decided, and `ShortcutSheet.qml`,
  which must report the height it wants.
- Both surfaces, through the two lines above. Neither host should need to know
  the sheet exists — the change is in what the view reports, not in either
  `Menu.qml` or `Panel.qml`.
- Anyone pressing `?`, which is the discoverability path for a keyboard-first
  panel and so the first thing a new user does.

## Constraints

- **`Panel.qml` must stay byte-identical**, as it has through #30, #31 and
  #35.
- The sheet stays an overlay at `z: 5`. It must not join the column's layout:
  that would move the rows behind it and change the card when the sheet is
  merely *present* rather than open.
- Reporting a height is not joining the layout, and the distinction matters:
  PR #35's spec rejected "grow the card" as coupling the overlay to the host,
  which is true of putting it in the column and not true of a taller
  `implicitHeight` while `helpOpen`.
- Watch for a binding loop. `implicitHeight` would read the sheet's content
  height, which depends on the sheet's *width*; it must never read the view's
  own height. This is the shape #30 had to check.
- No text multiplier and no `scale:` transform; `nix flake check` fails on
  both.

## Open questions

1. **Should the card shrink again when the sheet closes?** The simple binding
   does, which means pressing `?` and then `esc` on a short list visibly
   grows and shrinks the card. The alternative — keep the larger height until
   the surface closes — avoids the jump at the cost of a card that no longer
   matches its content.
2. **Does the popup want this at all?** A bar popup is anchored under its
   glyph and growing it pushes it down the screen. It may be right for the
   menu only, with the popup keeping PR #35's scrolling. That would mean the
   view knowing which surface it is on, which it currently does not — it has
   `large`, but that is about type size, not behaviour.
3. **Is there a minimum worth enforcing?** If the screen cannot fit the whole
   sheet even at full height, is it better to show as much as possible, or to
   keep today's centred-then-scrolled behaviour? The answer decides whether
   this replaces PR #35's `Flickable` or sits on top of it.
