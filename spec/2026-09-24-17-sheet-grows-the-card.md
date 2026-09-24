---
status: draft
issue: 17
intent: intent/2026-09-24-17-sheet-grows-the-card.md
---

# Spec: The card should make room for the shortcut sheet

## Design

The view asks for the height the sheet needs while the sheet is open. Each
host already clamps, so asking is safe.

### The one change

`PodmanView.qml:53` is `implicitHeight: column.implicitHeight`. It becomes:

```qml
// The sheet is an overlay, so it contributes nothing to the column and the
// card ends up sized for the list behind it -- on an empty list that left the
// sheet showing seven rows of nineteen (#17). Reporting the height it wants
// is not joining the layout: it stays at z: 5, absolutely positioned, and the
// rows behind it do not move. Both hosts clamp what they give.
implicitHeight: helpOpen ? Math.max(column.implicitHeight, helpSheet.wantedHeight)
                         : column.implicitHeight
```

and `ShortcutSheet.qml` exposes what it wants:

```qml
readonly property int wantedHeight: sheetColumn.implicitHeight + Style.spacing.md * 2
```

That is the whole mechanism. Neither `Menu.qml` nor `Panel.qml` changes, and
neither needs to know the sheet exists.

### Why asking is safe on both surfaces — open question 2, answered

The intent asked whether the popup wants this, since it is anchored under its
glyph and growing pushes it down. It does, because **both hosts already
clamp**:

- `Menu.qml:136` — `min(view.implicitHeight + insets, panel.height * 0.85)`
- `Panel.qml:94` — `fittedContentHeight`, which is
  `min(desired, availableCardHeight)` (`KeyboardPanel.qml:168-171`)

So the view asks and each host gives what it can. No per-surface flag, and
the view does not learn which surface it is on — which it currently has no way
to know except `large`, and that is about type size, not behaviour.

### It sits on top of PR #35, not instead of it — open question 3, answered

The `Flickable` stays. On a screen that genuinely cannot fit the sheet — a
1080-tall panel at a raised `base-size`, say — the card grows to its cap and
the remainder still scrolls, bounded and top-aligned, exactly as #35 shipped.
This change removes the *common* case of scrolling; it does not claim to
remove the case.

That also means the two are independent: reverting this leaves #35's
behaviour intact.

### The card shrinks again on close — open question 1, answered

The simple binding does, and that is the right answer. The alternative —
holding the larger height until the surface closes — leaves a card that no
longer matches its content, which is worse in a panel whose whole job is to
show what Podman holds. The card already changes height when switching tabs
and when the list refreshes, so a change on `?` is not a new kind of
movement.

### The binding loop, checked rather than assumed

`implicitHeight` will read `helpSheet.wantedHeight` → `sheetColumn.implicitHeight`
→ its children's heights → their widths. Nothing in that chain reads a height
of the view.

`ShortcutSheet.qml:81`'s `y: Math.max(0, (parent.height - implicitHeight) / 2)`
*does* read `parent.height`, which resolves through the card back to
`view.implicitHeight` — but `y` is a consumer of that chain, never a producer:
`sheetColumn.implicitHeight` does not depend on `y`. So the graph terminates.

This is the shape #30 had to check, and it is stated here so the verification
looks for it rather than trusting the analysis.

## Alternatives rejected

**Put the sheet in the column.** This is what "coupling the overlay to the
host's layout" actually means, and it is what PR #35's spec was right to
reject: the card would change whenever the sheet *exists*, and the rows behind
would move.

**Give the view a `surface` property so the popup behaves differently.**
Unnecessary once both hosts are seen to clamp, and it would be the first time
the view knew which host it was in — a coupling worth avoiding for a problem
that turns out not to exist.

**Make the sheet smaller instead** — fewer rows, or a smaller rung. #23 added
those rows because the keys were real and undocumented, and #30 set the rungs
deliberately two days ago.

**Add a scroll indicator instead of growing the card.** It would tell the
reader there is more without giving them a way to read it in one view. That is
a worse answer to "the sheet is always fully readable", though it remains a
reasonable addition if scrolling is still common after this.

## Risks

- **A binding loop is the real risk**, analysed above and checked in
  verification. If it appears, it will be loud in `qs log` and the change
  reverts cleanly.
- **The card will visibly grow when `?` is pressed on a short list.** That is
  the intended behaviour and it will look like a change to anyone used to the
  old squeeze.
- **On the bar popup, a taller card extends further down the screen**, up to
  whatever `availableCardHeight` allows. It cannot exceed it, but the popup
  will be noticeably larger than it is today when `?` is open on a short list.
- **`wantedHeight` adds `Style.spacing.md * 2`** to match the `Flickable`'s
  margins. If those margins change, this must change with them; they are
  adjacent in the same file.
- **No capture shows the sheet as a still**, but the menu recordings may.

## Verification

1. `node tests/run.js` and `nix flake check` green — neither sees QML layout.
2. `git diff master -- Panel.qml` is empty, and `Menu.qml` is untouched.
3. Build, install, restart, and read `qs log`: **0 errors and 0 binding
   loops**. This is the check that matters most.
4. Live, on p620:
   - **Full-screen menu with no containers** — the case that showed seven of
     nineteen rows. Press `?`: the whole sheet, every group, down to
     "press ? or esc to go back".
   - **Bar popup, Networks tab** (two rows) — the case from the original
     report. Same expectation.
   - **Containers tab with a full list**: the sheet still fits and the card
     does not jump more than the sheet needs.
   - Press `esc`: the card returns to the list's size.
   - Force a case the screen cannot fit — raise `[font] base-size`, or use the
     1080-tall HDMI-A-1 — and confirm #35's behaviour still applies: bounded,
     top-aligned, scrollable, nothing lost above.
