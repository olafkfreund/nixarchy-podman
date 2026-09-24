---
status: approved
issue: 17
intent: intent/2026-09-24-17-shortcut-sheet-fits.md
---

# Spec: The shortcut sheet does not fit its card

## Design

The intent asked two questions and this spec answers both, because they turn
out to be the same answer: **make the sheet fit first, and scroll only as the
thing that catches what still cannot.**

That ordering matters. The intent's own objection to scrolling — *a reference
that silently has more below is worse than one that fits* — is right, and it
argues against reaching for a `Flickable` as the primary fix. So the primary
fix is to stop wasting the width, which removes most of the height at the
same time.

### 1. Rows wrap instead of eliding, and the key column earns its width

`entryText` carries `elide: Text.ElideRight` with no `wrapMode`, so a long
description loses its end. `entryKeys` is a fixed `Style.space(90)`, sized for
the popup's base rung; at the menu's `title` rung the widest key string
(`tab  shift+tab`) needs more, and every row pays the same fixed 90 whether it
holds `?` or `j  k  ↑ ↓`.

Both change:

```qml
// Wide enough for the widest key string at the current rung, so no row is
// charged for the longest one and none of them is clipped (#17).
readonly property int keyColumnWidth: {
  var w = 0
  for (var i = 0; i < Model.SHORTCUTS.length; i++)
    w = Math.max(w, keyMetrics.widthOf(Model.SHORTCUTS[i].keys))
  return Math.ceil(w)
}
```

measured with a `TextMetrics` bound to the same family and `fontRow`, and:

```qml
  wrapMode: Text.WordWrap
  elide: Text.ElideNone
```

on `entryText`, whose delegate already sizes from `entryText.implicitHeight`,
so a wrapped row simply becomes two lines high.

**This alone may close the issue.** Wrapping costs height where it wraps, but
reclaiming the over-wide key column gives the text more room and so wraps
less; and the reported case is a *short card*, where the sheet's own content
was never the problem — the card was.

### 2. The sheet is bounded by the card, top-aligned, and scrolls when it must

Today the content is `anchors.verticalCenter: parent.verticalCenter` with
nothing bounding it, so overflow escapes equally above and below. Centring is
right when the content fits and wrong when it does not.

```qml
Flickable {
  anchors.fill: parent
  anchors.margins: Style.spacing.md
  contentHeight: sheetColumn.implicitHeight
  interactive: contentHeight > height
  flickableDirection: Flickable.VerticalFlick
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: sheetColumn
    width: parent.width
    // Centred while it fits, top-aligned once it does not: overflow must go
    // downward where scrolling can reach it, never upward off the top edge.
    y: Math.max(0, (parent.height - implicitHeight) / 2)
  }
}
```

`interactive` is false while everything fits, so nothing that fits acquires a
scroll gesture. The `y` expression keeps today's centred appearance in the
common case and switches to top-aligned exactly when the sheet would
otherwise lose its first lines — which is the half of the bug that is worst,
because the reader cannot tell anything is missing above.

Keyboard scrolling is not added. `?` and `esc` already close the sheet, and
the arrow keys belong to the list behind it; a sheet that needs paging is a
sheet that should have been made to fit.

### 3. No scroll indicator

The intent asked. Rejected: with §1 in place the `Flickable` should engage
rarely, and an indicator is machinery in proportion to a case that should not
arise. If it turns out to engage often on a real card, that is evidence the
sheet is too long — a content problem, not a chrome problem — and it earns
its own issue.

### What this does not do

It does not grow the card while `?` is open. The sheet is an overlay at
`z: 5` precisely so that opening it does not resize the card and shuffle the
rows behind it, and the intent lists keeping that as a constraint.

`Panel.qml` is untouched, as it was through #30.

## Alternatives rejected

**A `Flickable` alone**, as `nixarchy.devenv` did. It turns truncation into
scrolling without addressing why the sheet is taller than it needs to be, and
leaves every row still eliding horizontally. It is half of this.

**Grow the card while the sheet is open.** Couples the overlay to the host's
layout and moves the rows behind it; the `z: 5` design exists to avoid that.

**Shorten the wording of the two long rows.** Explicitly ruled out by the
intent: #23 added them because the keys were real and undocumented.

**Shrink the sheet's text below the view's rung.** It would fit by making the
reference harder to read, and it would reintroduce a per-surface size
knob two days after #30 removed one.

## Risks

- **Wrapping makes rows different heights**, so the sheet's total height now
  depends on the card's width. On a very narrow popup several rows could wrap
  and the sheet could get *taller* than today — which the `Flickable` then
  catches, but it means §1 and §2 must land together, not separately.
- **`TextMetrics` measures at the rung it is bound to**, so the key column
  resizes when the theme's `base-size` changes. That is correct, and it means
  the column width is no longer a constant anyone can reason about from the
  source alone.
- **The `y` expression is a binding on `parent.height`**, and the column's
  `implicitHeight` depends on its children — the same shape that #30 had to
  check for a loop. `implicitHeight` must not read `y` or `height`.
- **No capture shows the sheet as a still**, but the menu recordings may.
  Check before concluding no retake.

## Verification

1. `node tests/run.js` and `nix flake check` green. Neither sees QML layout.
2. `git diff master -- Panel.qml` is empty.
3. The shell log has no binding-loop warning after opening `?` on both
   surfaces — the specific risk above.
4. Live, on p620, and the reported case first:
   - Bar popup, **Networks tab** (two rows, the short card from the report):
     press `?`. Every line readable, including "press ? or esc to go back",
     with nothing cut off above.
   - Same on **Images filtered to one row**.
   - Containers tab, where it already fitted: unchanged, still centred.
   - Full-screen menu, at the larger rung: the two rows #23 lengthened read
     in full, wrapped rather than elided.
   - Narrow the popup if possible, or raise `[font] base-size`, until the
     sheet genuinely overflows: it scrolls, and does so from the top.
