---
status: approved
issue: 30
spec: spec/2026-09-24-30-menu-text-rungs.md
---

# Plan: The menu magnifies instead of choosing larger text

## The approved decisions, carried over

**Named roles, never a factor.** `PodmanView.qml` gains `property bool large`
and six readonly text roles. `Menu.qml` passes `large: true`; `Panel.qml`
leaves it false. The ladder is `caption 10 · bodySmall 11 · body 12 ·
subtitle 13 · title 14 · heading 16 · display 24 · displayLarge 28`, with
`iconSmall = bodySmall` and `icon = title`:

| role | small | large | sites |
| --- | --- | --- | --- |
| `fontRow` | `caption` | `title` | 14 |
| `fontGlyph` | `iconSmall` | `title` | 4 |
| `fontLabel` | `body` | `heading` | 2 |
| `fontTab` | `bodySmall` | `title` | 1 |
| `fontIcon` | `icon` | `heading` | 1 |
| `fontHero` | `display` | `displayLarge` | 1 |

`fontTab` is podman's addition — distrobox has no `bodySmall` text. It is not
folded into `fontGlyph` despite resolving identically by default, because a
theme pinning `icon-small` must not resize text.

**`ConfirmDialog` and `PanelHero` are inlined**, adapted from
`DistroboxView.qml:754+` and `:374+`. Their sizes are internal and cannot be
reached from outside. Each copy carries why it exists and when to delete it.
**`TextField` is not inlined** — a focus-handling control copied for one font
size costs more than it buys.

**`viewWidth` keeps #22's screen fraction, minus the `/ uiScale`.** Without
the transform the card is `viewWidth` directly, so distrobox's plain
`Style.space(680)` would make it *smaller* than today. Scaling the bounds by
1.45 reproduces #22's measured numbers: 883px at 1920, 1178px at 2560 against
the 1208px measured live.

**No `Flickable`.** Remove the magnification that causes clipping and derive
the height ceiling from the panel, rather than adding scrolling to make
truncation survivable.

## Steps

One commit per step, citing the step number and `#30`.

1. **`PodmanView.qml`: the roles.** Add after `property string fontFamily`:

   ```qml
   // A full-screen surface is read from further away than a bar popup, so it
   // is drawn larger -- but by picking LARGER TOKENS, never by a factor. Each
   // rung derives from [font] base-size, so the menu moves in step with the
   // desktop instead of sitting a fixed percentage above it, and a theme that
   // pins a token is honoured. Do not reintroduce a scale: transform (it
   // magnifies after layout, so wrap and elide are computed at the wrong
   // size) or a flat multiplier (#30).
   property bool large: false

   readonly property int fontRow:   large ? Style.font.title        : Style.font.caption
   readonly property int fontGlyph: large ? Style.font.title        : Style.font.iconSmall
   readonly property int fontLabel: large ? Style.font.heading      : Style.font.body
   readonly property int fontTab:   large ? Style.font.title        : Style.font.bodySmall
   readonly property int fontIcon:  large ? Style.font.heading      : Style.font.icon
   readonly property int fontHero:  large ? Style.font.displayLarge : Style.font.display
   ```

   → verify by `nix flake check` still green (nothing uses them yet).

2. **Thread `large` and the roles through the drawing pieces.**
   `ResourceList.qml`, `TabStrip.qml` and `ShortcutSheet.qml` each gain the
   role properties they use, defaulted to the small rung, set from
   `PodmanView.qml` where `fontFamily` is already passed. `Menu.qml:172` adds
   `large: true`.

   → verify by `grep -c "fontFamily:" ` matching the new role pass-downs.

3. **Convert all 23 sites.** Each `font.pixelSize: Style.font.X` becomes the
   role from the table. The per-file counts must come out at:
   `PodmanView.qml` 7, `ResourceList.qml` 8, `TabStrip.qml` 3,
   `ShortcutSheet.qml` 5.

   → verify by, per file, `grep -c 'pixelSize:'` equalling the count of
   `font(Row|Glyph|Label|Tab|Icon|Hero)` references. A missed site keeps base
   size silently, so this counts rather than samples.

4. **Inline `PanelHero`**, adapted from `DistroboxView.qml:374-381` onward:
   same layout, same tokens, icon at `fontHero`, title at `fontLabel`, meta at
   `fontRow`. Comment names the reason and the revert condition.

   → verify by the popup and menu both rendering a header (live, step 9).

5. **Inline `ConfirmDialog`**, adapted from `DistroboxView.qml:754+`. Podman
   keeps `selectedIndex` on the dialog where distrobox uses a root
   `confirmIndex`; move it to `root.confirmIndex` to match, updating `ask()`
   (`PodmanView.qml:154`) and `keyRoot`'s `handleKey` call (`:252`).
   Message at `fontIcon`, buttons at `fontRow`. **Cancel stays index 0 and the
   default** — this is the #19 safety surface.

   → verify by `grep -n "ConfirmDialog" *.qml` returning nothing, and by the
   live confirmation in step 9.

   **Deviation, found live by the owner.** distrobox's buttons are a fixed
   `Style.space(88)` wide, which suits its short labels. Podman's are longer
   ("Remove stopped", "Prune unused", "Stop all") and at the menu's rung the
   text is 1.4x wider, so it overflowed the border on both sides. The button
   now sizes to its label — `Math.max(Style.space(88), label.implicitWidth +
   Style.space(22))`, same for height — and the card widens at the large rung
   (`Style.space(520)` against the popup's 370), or a 1.4x message wraps into
   a column. Copying a sibling's fixed dimension was the mistake; the floor is
   kept so the small rung is unchanged.

6. **`Menu.qml`: remove the transform.** Delete `uiScale`, the `scale:` and
   `transformOrigin`, and the `/ root.uiScale` divisions in `view.width`,
   `view.height`, `card.width`, `card.height` and `listMaxHeight`. Pass
   `large: true`.

   `viewWidth` becomes:

   ```qml
   readonly property int viewWidth: {
     if (!root.targetScreen) return Style.space(986)
     var target = Math.round(root.targetScreen.width * 0.46)
     return Math.max(Style.space(800), Math.min(target, Style.space(1200)))
   }
   ```

   and `listMaxHeight` loses its `/ root.uiScale` and its `Style.space(560)`
   ceiling, deriving from `panel.height * 0.85` less the chrome.

   → verify by `grep -nwE 'uiScale|textScale' *.qml` returning nothing.

7. **`flake.nix`: the guard**, so neither form can return:

   ```bash
   if grep -nwE 'textScale|uiScale' ${plugin}/*.qml; then
     echo "a text multiplier is back; use the large roles instead (#30)" >&2
     exit 1
   fi
   ```

   → verify by reintroducing `uiScale` in a scratch clone and seeing it fail,
   as #24's checks were demonstrated.

   **Deviation.** Catching a multiplier by *name* is not enough: a bare
   `scale: 1.45` with no named property passes that grep. Tested here in a
   scratch clone, and independently reported by the `nixarchy.devenv` review
   that filed #30, which found the same hole in distrobox's version. A fourth
   guard, `grep -nE '^[[:space:]]*scale:'`, is added and demonstrated
   failing.

8. **AGENTS.md**: note that the menu sizes by rungs, not a factor, so the next
   reader does not reintroduce one.

   → verify by reading it back.

9. **HELD — live verification.** Cannot be done from a build. Listed in Tests.

## Tests

```bash
node tests/run.js    # expect green, 170 -- no Model.js change
nix flake check      # expect: all checks passed
```

Live, on p620, **clipping first because that is the bug**:

1. Set `[font] base-size = 16`. Open the menu on DP-2 and confirm the footer,
   reclaimable total and prune button are all reachable. Repeat on HDMI-A-1
   (1080 tall), which is the short case.
2. Menu and bar popup side by side at the same theme setting: the menu's text
   visibly larger, both growing together when `base-size` changes.
3. Trigger a confirmation in the menu: the question sized with the list around
   it, Cancel selected. **Screenshot before answering.**
4. A long container name elides at the displayed size.
5. The card is ~46% of DP-2 (2560), matching the 1208px measured for #22.
6. `?` sheet still fits — with an eye on #17, which this does not claim to fix.

Captures: `menu.png` and the menu recordings need retaking, frame by frame,
within the 8 MB budget (currently 69%).

## Rollback

Steps 1-3 are additive then mechanical; reverting them restores the tokens.
Steps 4 and 5 are the ones with weight — reverting restores the shell
components and the transform must come back with them, or the header and
dialog render at base size against a larger list. Revert 4, 5 and 6 together.
Step 7 alone would then fail, so revert it too.
