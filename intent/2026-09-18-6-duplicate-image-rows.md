---
status: approved
issue: 6
author: olafkfreund
---

# Intent: Images with several tags leave stale duplicate rows

## Problem

When one image carries more than one tag, the Images tab shows rows that are not
there. This is common, for example after `podman tag alpine:3 localhost/myapp`.

Found while capturing the showcase (#5), and reproduced in Node against `Model.js`
on `master`. Take one image with two tags and one other image: the model builds
three rows, and after filtering to two, the on-screen list still holds three.

```
unfiltered keys: bbbbbbbbbbbb,aaaaaaaaaaaa,aaaaaaaaaaaa
filtered keys:   bbbbbbbbbbbb,aaaaaaaaaaaa
list after reconcile: bbbbbbbbbbbb,aaaaaaaaaaaa,aaaaaaaaaaaa  (want 2 rows, got 3)
```

Live on p620 this showed as:

- a tag listed twice;
- a row sitting under the wrong section;
- "In use: 1" with three rows under it.

It did not go away on refresh.

There are two defects, and either one alone is a bug:

1. **Row keys are not unique.** `imageRow` keys an image row by its image id
   alone (`blankRow(image.id, image.id, "images")`), so every tag of one image
   gets the same key.
2. **The reconcile cannot recover from duplicates.** `reconcilePlan`'s removal
   pass keeps every key that is still wanted, so both copies survive. Its insert
   and move pass then walks only `next.length` positions and never removes what
   is left past the end. A duplicate key from anywhere therefore leaves stale
   rows on screen.

## Proposed outcome

- **Each tag is its own row, and the list shows exactly the rows the model
  built.** This holds for any mix of tags, filters and refreshes.
- **Actions keep their target.** The row's `id` stays the image id, so copy,
  remove and the commands behind them are unchanged.
- **The reconcile ends with exactly the target rows** whatever list it starts
  from, duplicates included, so a future key collision on any tab cannot
  strand rows.
- **Tests fail on today's code and pass after the fix.**

## Affected users and systems

- `Model.js` (`imageRow`, `reconcilePlan`) and `tests/model/`. `ResourceList.qml`
  applies the plan and should not need to change.
- Anyone with multi-tagged images, in both the bar popup and the full-screen
  menu.
- No change to the package file list, the flake or the docs. The showcase
  captures already show the correct behaviour.

## Constraints

- Logic stays in `Model.js` and gets Node tests (`AGENTS.md`).
- Keep the row `id` as the image id. The remove command must not change: it is
  `podman rmi <id>`, never `-f`.
- No change to how untagged (dangling) images are shown.
- Model-only fixes still need a live check. The last Model bug that passed its
  Node tests failed inside QML, because of Qt sequence wrappers. So verify on
  the desktop with a real multi-tagged image, using only `demo-*` objects
  staged by `docs/capture.sh`.

## Open questions

1. **What should a multi-tag image look like?** Pick one:
   - (a) **one row per tag**: what `podman images` prints, and what the list
     does today apart from the stale extras;
   - (b) **one row per image, listing all its tags**: shorter, but a different
     look, and removing it removes every tag.

   I recommend (a): it is the smallest change, and matches Podman's own output.
2. **Should the pipefail fix go upstream to `i228808/omapodman` together with
   this?** It is still open from #1, and this bug likely exists upstream too.
   I recommend keeping upstream work separate, as its own follow-up.

## Decisions at approval

Approved without answers to the open questions; the recommendations stand:
1. One row per tag.
2. Upstream contribution stays a separate follow-up.
