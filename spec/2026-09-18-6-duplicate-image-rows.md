---
status: draft
issue: 6
intent: intent/2026-09-18-6-duplicate-image-rows.md
---

# Spec: Images with several tags leave stale duplicate rows

## Design

One row per tag (the intent's decision 1). All the changes are in `Model.js`;
`ResourceList.qml` and the QML hosts are untouched.

### 1. Every image row gets a unique identity: `rowId`

`normalizeImage` adds `rowId`:

- a **tagged** image uses its reference, e.g. `localhost/demo/shop:latest`;
- an **untagged** (dangling) image uses its short image id.

References are unique per tag. An untagged image has no reference, so its id
is the only name it has.

- **Rows.** `imageRow` builds its row with `blankRow(image.rowId, image.rowId,
  "images")`, so both the row's `key` (reconcile identity) and its `id` (what
  actions are keyed on) are unique.
- **Lookup.** `itemById` matches `item.rowId` when present and `item.id`
  otherwise. Containers, volumes and networks carry no `rowId` and behave
  exactly as before. For images, the item a row resolves to is now the tag
  under the cursor, not whichever tag was listed first. The remove question
  therefore names the right tag, which today it does not.
- **Copy** stays `item.id`, the image id (`copyValue` is unchanged). `c` on a
  tag copies the same image id as before.

### 2. Removing a tagged row removes that tag: a change the intent did not foresee

The intent's constraint was "the remove command does not change: `podman rmi
<id>`". Checked on p620 with a throwaway two-tag demo image:

```
$ podman rmi f6185618a70a
Error: unable to delete image "f6185618…" by ID with more than one tag
       ([localhost/demo/probe:b localhost/demo/probe:a]): please force removal
$ podman rmi localhost/demo/probe:b
Untagged: localhost/demo/probe:b
```

So with one row per tag, removing by id is **refused for every tag of a
multi-tag image**. Today's code has the same failure, hidden behind the
duplicate rows. Removing by reference does what the row says: it untags that
tag, and once no tag is left, the image goes.

`removeCommand("images", rowId)` becomes:

- `rowId` is an image id (`isContainerId`): `podman rmi <id>`, as today, for
  untagged images;
- `rowId` is a reference (`isImageReference`): `podman rmi <reference>`;
- anything else: `null`, as today.

**Never `-f`**, and the existing "a container still references it, so Podman
will refuse" question is unchanged. The new validator `isImageReference`
allows `[A-Za-z0-9][A-Za-z0-9._/:@-]{0,255}`. The first character can't be
`-`, so a reference can never be read as a flag. The command is an argv array
and never goes through a shell.

This spec asks for approval of the change explicitly. It departs from the
intent's constraint because the constraint rested on an assumption the probe
disproved.

### 3. `reconcilePlan` always lands on exactly the target rows

After its insert and move pass, the plan removes every row left past
`next.length`. It removes them from the end back, so earlier indices stay
valid, the same rule as the existing removal pass.

- **Starting from duplicates.** If the current list holds duplicate keys,
  from this bug or any future one, the list ends identical to `next`.
- **Starting from unique keys** nothing is ever left past the end, so today's
  plans are unchanged and the existing tests hold.

## Tests (`tests/model/`)

New tests, each shown failing on today's `Model.js` before the fix:

1. **Distinct keys.** Two tags of one image give two rows with distinct `key`
   and `id`, each the tag's reference. An untagged image's row id is its short
   id.
2. **Recovery from duplicates.** Take a current key list with duplicates
   (`b,a,a`) and a target (`b,a`): applying the plan gives exactly `b,a`. More
   shapes: duplicates at the front, in the middle, and an empty target.
3. **Lookup.** `itemById(images, rowId)` returns the item for that tag;
   container lookup is unchanged.
4. **Remove.** `removeCommand("images", "localhost/demo/shop:latest")` gives
   `["podman","rmi","localhost/demo/shop:latest"]`. An image id still gives
   `rmi <id>`. `-rf`, `--all` and `a b` give `null`.
5. **Remove question.** `removeMessage` for the second tag names the second
   tag.

All existing tests still pass, reconcile's included.

## Alternatives rejected

- **One row per image listing all its tags.** The owner kept one row per tag
  (the intent's decision 1). It would also need a new "remove every tag"
  action.
- **Keeping `podman rmi <id>` and adding `-f` for multi-tag images.** That
  is the destructive shortcut `Model.js` explicitly rules out: "a stale row
  must never be able to destroy something".
- **Fixing only `imageRow`, not `reconcilePlan`.** It fixes this bug, but
  leaves the reconcile unable to recover from the next key collision on any
  tab. Hardening it takes one small loop.
- **De-duplicating in `ResourceList.qml`.** That would hide the symptom in
  QML, which has no tests. The cause is in `Model.js`, which does.

## Risks

- **Remove now untags.** On a multi-tag image, removing one row takes away
  only that tag, as its row says, not the whole image. The image goes once
  its last tag is removed. This change is the point of the fix. The question
  text says "Remove image <tag>", which stays accurate.
- **Reconcile changes for everyone.** The added trailing-removal loop runs on
  every tab. Existing reconcile tests cover order, moves, inserts and
  clearing, and all must pass unchanged.
- **Behaviour inside QML.** The last Model bug passed Node and failed in QML
  (Qt sequence wrappers). This change adds no list-type checks, but the live
  check below is required anyway.

## Verification

1. `node tests/run.js`: all pass. The new tests are shown failing first
   against `master`'s `Model.js`, with their output recorded.
2. `nix flake check` passes, and the package is still ten files.
3. **Live on p620**, using `docs/capture.sh --setup` plus a second tag added to
   the demo image:
   - the Images tab shows one row per tag, with no stale extras, after
     filtering, refreshing and switching tabs, in both the popup and the menu;
   - `x` on the second tag names that tag;
   - removing it (confirmed; a demo object) untags only that tag;
   - removing an in-use tag is refused by Podman, with its reason shown;
   - `--teardown` then leaves the owner's Podman state identical to a
     snapshot taken before.
