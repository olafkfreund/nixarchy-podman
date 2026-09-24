---
status: approved
issue: 17
spec: spec/2026-09-24-17-shortcut-sheet-fits.md
---

# Plan: The shortcut sheet does not fit its card

## The approved decisions, carried over

**Make it fit first; scroll only as what catches the rest.** A reference that
silently has more below is worse than one that fits, so the primary fix is to
stop wasting width — not to reach for a `Flickable`.

**Rows wrap and the key column earns its width.** `entryKeys` is a fixed
`Style.space(90)` sized for the popup's base rung; every row pays it whether
it holds `?` or `j  k  ↑ ↓`, and at the menu's `title` rung the widest string
(`tab  shift+tab`) does not fit. It becomes the measured width of the widest
key string at the current rung. `entryText` gains `wrapMode: Text.WordWrap`
and drops `elide`, and the delegate already sizes from
`entryText.implicitHeight`, so a wrapped row becomes two lines.

**The sheet is bounded, top-aligned on overflow, and scrolls when it must.**
`interactive: contentHeight > height`, so nothing that fits acquires a scroll
gesture. The column stays centred while it fits and goes top-aligned once it
does not: overflow must go downward where scrolling reaches it, never off the
top edge, because lines lost above give the reader no sign they are missing.

**No scroll indicator**, no keyboard scrolling, and the sheet stays an overlay
at `z: 5` — it must not join the column's layout or opening it would resize
the card and shuffle the rows behind it.

**`Panel.qml` stays byte-identical**, as through #30 and #31.

## Steps

One commit per step, citing the step number and `#17`.

1. **`ShortcutSheet.qml`: the key column measures the widest key.** Add a
   `TextMetrics` bound to `root.fontFamily` and `root.fontRow`, walk
   `Model.SHORTCUTS` once, and use the result as `entryKeys.width`.

   The sheet already imports `Model.js`; confirm before relying on it.

   → verify by reading the rendered sheet at both rungs (step 5): no key
   string clipped, and the text column visibly wider than the old fixed 90.

2. **`ShortcutSheet.qml`: rows wrap instead of eliding.** On `entryText`, add
   `wrapMode: Text.WordWrap` and `elide: Text.ElideNone`.

   → verify by the two rows #23 lengthened reading in full at the menu's rung.

3. **`ShortcutSheet.qml`: bound the content in a `Flickable`.** Replace the
   `anchors.verticalCenter` placement with:

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
       y: Math.max(0, (parent.height - implicitHeight) / 2)
     }
   }
   ```

   The column's `implicitHeight` must not read `y` or `height`, or the binding
   loops — the shape #30 had to check for.

   → verify by no binding-loop warning in `qs log` after opening `?` on both
   surfaces.

4. **Load it.** `nix build`, install to
   `~/.config/omarchy/plugins/nixarchy.podman`, `omarchy-restart-shell`, and
   read the log. A QML error here is invisible to `nix flake check`.

   → verify by `qs log -i <instance>` showing 0 errors and 0 binding loops.

5. **HELD — live verification.** In Tests below; cannot be done from a build.

   **Deviation, found by running it.** The spec rejected a scroll indicator on
   the grounds that "with §1 in place the `Flickable` should engage rarely".
   Observed live on p620, it engages in the *common* case, not rarely: the card
   sizes to the list's content, so on an empty or short list — the menu with no
   containers, the Networks tab with two rows — the sheet shows about seven of
   its nineteen rows. Wrapping the two long rows adds height rather than
   removing it, so §1 does not shrink the sheet the way the spec assumed.

   What this change does deliver is real and worth merging: the content no
   longer spills over the desktop, no line is lost above the card's top edge
   where the reader cannot tell it is missing, and every row is reachable. But
   the issue's stated expectation — "the sheet is always fully readable" — is
   **not met**, so #17 should not close on this alone.

   The remedy is the issue's other option, which the spec rejected for coupling
   the overlay to the host's layout: **grow the card to the sheet's height
   while `?` is open**. On a full-screen menu there is ample room; the card is
   small only because the list is. That is a larger change to `Menu.qml` and
   `PodmanView.qml` than this one, and it deserves its own pass rather than
   being bolted on here.

## Tests

```bash
node tests/run.js    # expect green, 170 -- no Model.js change
nix flake check      # expect: all checks passed
```

Live, on p620, **the reported case first**:

1. Bar popup, **Networks tab** — the short card from the report. Press `?`.
   Every line readable including "press ? or esc to go back", nothing cut off
   above the card's top edge.
2. Same on **Images filtered to one row**.
3. **Containers tab**, where it already fitted: unchanged, still centred.
4. **Full-screen menu**, at the larger rung: the two rows #23 lengthened
   (`tab  shift+tab` and the `esc` chain) read in full, wrapped not elided.
5. Force genuine overflow — raise `[font] base-size`, or use the 1080-tall
   HDMI-A-1 — and confirm it scrolls, and scrolls **from the top**.
6. `git diff master -- Panel.qml` is empty.

Captures: no shipped still shows the sheet, but the menu recordings may.
Check before concluding no retake. `docs/img` is at 69% of 8 MB.

## Rollback

One file. Steps 1 and 2 revert together — reverting the wrap without the key
column would leave rows eliding at a narrower column than today. Step 3
reverts alone, restoring the unbounded centred column, which is today's
behaviour including today's bug.
