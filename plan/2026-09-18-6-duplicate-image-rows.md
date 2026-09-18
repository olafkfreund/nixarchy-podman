---
status: draft
issue: 6
spec: spec/2026-09-18-6-duplicate-image-rows.md
---

# Plan: Images with several tags leave stale duplicate rows

## Approved decisions (self-contained summary)

- **One row per tag**, the intent's decision. Upstream work stays a separate
  follow-up.
- **`rowId`.** `normalizeImage` adds `rowId`: the reference for a tagged
  image, the short image id for an untagged one.
  - `imageRow` builds its row with `blankRow(image.rowId, image.rowId,
    "images")`.
  - `itemById` matches `item.rowId` when present, else `item.id`, so
    containers, volumes and networks are unchanged.
  - `copyValue` is unchanged, and `c` still copies the image id.
- **Remove by reference**, approved explicitly at the spec gate. Podman
  refuses `rmi <id>` on a multi-tag image; the probe on p620 is quoted in the
  spec. `removeCommand("images", rowId)` returns:
  - `["podman","rmi",rowId]` when `rowId` passes `isContainerId` (an untagged
    image) or the new `isImageReference`;
  - `null` for anything else.

  `isImageReference` allows `^[A-Za-z0-9][A-Za-z0-9._/:@-]{0,255}$`. There is
  never a `-f`.
- **`reconcilePlan`.** After its insert and move pass, it removes every
  remaining index at or past `next.length`, from the end back. Plans that
  start from unique keys are unchanged.
- **No changes outside `Model.js` and the tests.** QML, the flake and the
  package's ten files stay as they are.

## Steps

Each step is one commit on `fix/6-duplicate-image-rows`, citing
`plan step N`.

1. **Failing tests first.** Add `tests/model/image-rows.test.js` with the
   spec's five tests (distinct keys, recovery from duplicates, lookup, remove
   command, remove question). The recovery test uses an `apply` helper like
   the one in `reconcile.test.js`.
   → Verify: `node tests/run.js` shows the new tests failing and the 125
   existing tests passing; record the failure output in the commit message.
2. **The fix in `Model.js`**: `rowId`, `imageRow`, `itemById`,
   `isImageReference`, `removeCommand`, and the trailing removal in
   `reconcilePlan`.
   → Verify: all tests pass (125 plus the new ones), and the reproduction
   from the intent now prints `want 2 rows, got 2`.
3. **Live check on p620.** No commit, unless it forces a fix.
   - **Prepare.** Snapshot Podman. Install `nix build` output over
     `~/.config/omarchy/plugins/nixarchy.podman` as a real copy, then run
     `omarchy-restart-shell`.
   - **Stage.** Run `docs/capture.sh --setup`, then
     `podman tag localhost/demo/tools:latest localhost/demo/tools:second`.
     Work on a new empty workspace.
   - **Checks.** Filter the Images tab to `demo`, in both the popup and the
     menu:
     - `tools` shows exactly two rows, and they survive a refresh, a tab
       switch and a re-filter;
     - `x` on `:second` names `localhost/demo/tools:second`;
     - confirming untags only `:second`, which `podman images` confirms;
     - `x` on the in-use `demo/shop` shows Podman's refusal.
   - **Clean up.** Remove any leftover `:second` tag by hand, run
     `--teardown`, and diff the snapshot, which must be identical. Return to
     workspace 11 and release control.
4. **Close-out.** Run `nix flake check`, confirm the package is ten files,
   and add an implementation record to this plan. Push, and open a PR that
   says `Closes #6`. Once CI passes, answer the Copilot review, verifying
   each finding. **Merge only when the owner says so.**

## Tests

- `node tests/run.js`: every test passes, and the new ones were seen failing
  on the old code.
- `nix flake check` passes, and the package is ten files.
- The live checks in step 3 all pass, and the owner's Podman snapshot is
  identical before and after.

## Rollback

Revert the merge commit. The change is confined to `Model.js` and one test
file.
