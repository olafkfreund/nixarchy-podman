---
status: draft
issue: 17
author: olafkfreund
---

# Intent: The shortcut sheet does not fit its card

## Problem

`?` opens `ShortcutSheet.qml`, which is `anchors.fill: parent` over the view
at `z: 5` and centres its content with
`anchors.verticalCenter: parent.verticalCenter`. Nothing bounds that content
to the space available, so when the sheet is taller than the card the top
lines are cut off above it and the rest spills below — including
"press ? or esc to go back", the one line telling the reader how to leave.

Reported from the #11 captures on razer (1920x1080, bar popup) on a short
card: the Networks tab with two rows, or Images filtered to one. On the
Containers tab the card is tall enough, which is why it went unseen.

**Two things have changed since it was filed, and they pull in opposite
directions.**

#23 lengthened two rows to document behaviour that existed but was written
down nowhere — `tab  shift+tab` and the three-step `esc` chain. Observed live
on p620 after that merge, those are the only two rows that now elide:

| row | rendered |
| --- | --- |
| `tab  shift+tab` | "Next or previous tab in the full-screen menu; the ne**…**" |
| `esc` | "Close the shortcut sheet, dismiss Podman's message, **…**" |

So the sheet has a *second*, horizontal problem that the filed issue does not
mention: `entryKeys` is a fixed `Style.space(90)` wide and `entryText` carries
`elide: Text.ElideRight` with no wrapping, so a long row is truncated rather
than wrapped. I introduced that in #23 and recorded it on the issue.

#30 removed the `scale:` transform, so the sheet is no longer magnified past
its frame, and `listMaxHeight` lost its fixed ceiling. That narrows the
vertical path but does not close it: the sheet still centres unbounded
content in a card whose height comes from elsewhere. A sibling review
(`nixarchy.devenv`) reports that removing the magnification alone was not
enough in its own plugin and that a `Flickable` was what turned "truncated"
into "scrolls".

## Proposed outcome

- The sheet is fully readable on any card, on either surface, at any theme
  text size — including the line that says how to close it.
- No row is truncated horizontally. A long description wraps or the column
  gives it room; the reader never loses the end of a sentence.
- The fix lives where the sheet lives, so the bar popup and the full-screen
  menu behave the same without either host knowing about it.

## Affected users and systems

- `ShortcutSheet.qml`, and possibly `PodmanView.qml` if the sheet has to
  report a height.
- Both surfaces. The popup is where it was reported; the menu shows it too.
- Anyone pressing `?` on a tab with few rows — which is the Networks tab
  almost always, and any filtered tab.
- `docs/img` only if a capture shows the sheet; none currently does as a
  still, though the menu recordings may.

## Constraints

- `Panel.qml` must stay byte-identical, as it did through #30. The popup is
  not the thing being changed.
- The sheet is an overlay at `z: 5` and must remain one: it must not become
  part of the column's layout, or opening it would resize the card underneath
  and move the rows behind it.
- Whatever is added must work at the menu's larger rungs as well as the
  popup's base ones — that is the case that currently fails.
- No text multiplier and no `scale:` transform; `nix flake check` fails on
  both since #30.
- Do not solve it by shortening the wording. #23 added those rows because the
  keys were real and undocumented; the sheet should fit them.

## Open questions

1. **Scroll, or grow the card?** The issue offers both. A `Flickable` inside
   the sheet is self-contained and works on both surfaces, but a scrollable
   reference that silently has more below is worse than one that fits.
   Growing the card while `?` is open couples the overlay to the host's
   layout, which the `z: 5` design deliberately avoids. The approver should
   pick, knowing `nixarchy.devenv` chose the `Flickable`.
2. **Wrap, or widen the key column?** `entryKeys` is a fixed
   `Style.space(90)`. Sizing it to the widest key would give the text more
   room and might be enough on its own; letting `entryText` wrap is the
   more certain fix but makes rows different heights.
3. **Is a scroll indicator needed** if scrolling is chosen? Without one the
   reader cannot tell there is more. That is extra machinery for a sheet that
   should mostly fit.
