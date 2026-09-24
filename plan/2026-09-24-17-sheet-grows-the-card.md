---
status: approved
issue: 17
spec: spec/2026-09-24-17-sheet-grows-the-card.md
---

# Plan: The card should make room for the shortcut sheet

## The approved decisions, carried over

**The view asks for the height the sheet needs while it is open.** The sheet
stays an overlay at `z: 5`; reporting a height is not joining the layout, and
the rows behind it do not move.

**Both hosts already clamp**, so asking is safe and no per-surface flag is
needed: `Menu.qml:136` caps at `panel.height * 0.85`, and `Panel.qml:94`'s
`fittedContentHeight` is `min(desired, availableCardHeight)`
(`KeyboardPanel.qml:168-171`).

**This sits on top of PR #35, not instead of it.** The `Flickable` stays; a
screen that genuinely cannot fit the sheet still gets bounded, top-aligned,
scrollable. This removes the common case of scrolling, not the case.

**The card shrinks again on close.** A card that no longer matches its content
is worse in a panel whose job is to show what Podman holds, and the card
already changes height on tab switches.

**The loop analysis:** `implicitHeight` reads `wantedHeight` →
`sheetColumn.implicitHeight` → children → widths. Nothing there reads a height
of the view. `ShortcutSheet.qml:81`'s `y` does read `parent.height`, but `y`
is a consumer of that chain, never a producer.

## Steps

One commit per step, citing the step number and `#17`.

1. **`ShortcutSheet.qml`: expose `wantedHeight`.** Beside the other readonly
   properties:

   ```qml
   // What the sheet needs to show every row, so the host can make room (#17).
   // Matches the Flickable's margins below; change them together.
   readonly property int wantedHeight: sheetColumn.implicitHeight + Style.spacing.md * 2
   ```

   → verify by `nix flake check` green and the property resolving at load
   (step 3).

2. **`PodmanView.qml:53`: ask for it while open.**

   ```qml
   implicitHeight: helpOpen ? Math.max(column.implicitHeight, helpSheet.wantedHeight)
                            : column.implicitHeight
   ```

   `helpSheet` is the existing id at `PodmanView.qml:628`.

   → verify by `grep -n "implicitHeight:" PodmanView.qml` showing the new
   form, and `git diff master -- Panel.qml Menu.qml` being empty.

3. **Load it.** `nix build`, install to
   `~/.config/omarchy/plugins/nixarchy.podman`, `omarchy-restart-shell`, read
   the log.

   → verify by **0 errors and 0 binding loops** in `qs log -i <instance>`.
   This is the step that matters: the loop is the real risk and no build check
   sees it.

4. **HELD — live verification.** In Tests.

## Tests

```bash
node tests/run.js    # expect green, 170 -- no Model.js change
nix flake check      # expect: all checks passed
```

Live, on p620, the failing cases first:

1. **Full-screen menu, no containers** — the case that showed seven rows of
   nineteen. Press `?`: every group visible, down to
   "press ? or esc to go back".
2. **Bar popup, Networks tab** (two rows) — the original report. Same.
3. **Containers tab with a full list**: the sheet already fitted; the card
   must not jump more than the sheet needs.
4. `esc`: the card returns to the list's size.
5. A case the screen cannot fit — raise `[font] base-size`, or the 1080-tall
   HDMI-A-1 — and confirm PR #35's behaviour still applies underneath.
6. `git diff master -- Panel.qml Menu.qml` empty.

Captures: no shipped still shows the sheet; the menu recordings may. Check
before concluding no retake. `docs/img` is at 69% of 8 MB.

## Rollback

Two lines in two files. Reverting step 2 restores the card to sizing from the
list, which is today's behaviour including today's squeeze; step 1's property
then has no reader and can stay or go. PR #35's bounded, top-aligned,
scrollable sheet is untouched by either.
