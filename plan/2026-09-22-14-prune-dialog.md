---
status: draft
issue: 14
spec: spec/2026-09-22-14-prune-dialog.md
---

# Plan: A prune says what it will remove

## Approved decisions (self-contained summary)

- **The prune commands do not change** (`PRUNE` in `Model.js`):
  `container prune -f`, `image prune -a -f`, `volume prune -f`, `network prune -f`.
  Only the question changes.
- **`pruneTargets(tab, list)`** returns what a prune takes, from the tab's
  **unfiltered** list:
  - Containers: `state` in `PRUNABLE_STATES = ["exited", "created", "stopped", "configured"]`.
    A `paused` container is not taken.
  - Images, Volumes, Networks: `!inUse`. The built-in `podman` network is always in
    use.
- **`pruneMessage(tab, list, opts)`**, where `opts = {usage, showStopped, filter}`,
  builds the message in three parts:
  1. the count and the first three row `name`s, then "and N more". Singular or
     plural through `plural`. For example
     `Remove 5 stopped containers: web, db, migrate and 2 more?`;
  2. the volume warning, "Whatever is stored in them goes with them.";
  3. when `opts.filter` is non-empty, "The filter does not limit a prune."
- **Stopped containers hidden** (`showStopped === false`, Containers tab): the
  count is `usage.Containers.count − usage.Containers.active`, and the message is
  `Remove N stopped containers? They are hidden because Show stopped containers is off.`
  If either number is `-1`: `Remove every stopped container? …hidden…`. It never
  invents a number.
- **Nothing listed, though the tab is still prunable** (reclaimable bytes only): fall
  back to `pruneSpec(tab).message`.
- **`PodmanView.askPrune`** asks with `pruneMessage(...)`. Cancel stays the default.
- **Rejected** (don't reintroduce): a scrolling list of every name; count only;
  pruning the filtered rows; treating `paused` as prunable; querying Podman when
  asked.

**Live-test safety:** only `demo-*` objects. Screenshot and read every dialog
before any confirm, and send the confirm in a separate call. Never confirm a prune
on Containers or Images while the owner has stopped containers or unused images.
Confirm only a Networks prune whose unused list, checked with the CLI first, is
`demo-*` alone. Snapshot Podman, `shell.json` and the clipboard, restore them, and
diff the snapshot afterwards.

## Steps

One commit per step on `feat/14-prune-dialog`, each citing `plan step N` and
`(#14)`. Step 1 is test-first, with the failing output in the commit body.

1. **Model.**
   - Tests: `tests/model/prune.test.js` (new) covers:
     - `pruneTargets` per tab, with `paused` not taken and `created` taken;
     - `pruneMessage` with 0 targets (fallback), 1 and 5;
     - hidden-stopped with a known and an unknown count;
     - the filter note;
     - the volume warning.
   - Code, `Model.js`: `PRUNABLE_STATES`, `pruneTargets`, `pruneMessage`.
   - Verify: the new tests fail first, then `node tests/run.js` is green.
2. **Wiring.**
   - `PodmanView.askPrune` passes `root.podman.tab`, the unfiltered list
     (`podman.containers` on Containers, `podman.items` elsewhere), and
     `{usage: podman.usage, showStopped: podman.showStopped, filter: root.filterText}`.
   - Verify: `nix flake check` and `nix build` pass.
3. **Docs.**
   - `docs/usage.md`: "Reclaim space on this tab … It asks first, naming what will
     go".
   - `README.md`: the prune sentence mentions that the question names what goes.
   - Verify: `nix flake check`.
4. **Live check on razer.** No commit unless it forces a fix, which then goes in the
   step it belongs to, with a plan deviation note.
   - Install: record razer's `nixarchy.podman` link, replace it with this branch's
     `nix build` output, and restart the shell. Use the session's `OMARCHY_PATH`
     (from `systemctl --user show-environment`) for any `omarchy-shell` command.
   - Stage: take the snapshot and backups. Run `docs/capture.sh --setup`, plus
     `podman run -d --name demo-paused <demo image> sleep infinity && podman pause demo-paused`
     and `podman network create demo-net2`, each recorded in the capture state file.
     Announce on the agent bus, then ask for ai-mirror control.
   - Checks:
     - on each tab, `p` opens a dialog naming exactly the `demo-*` targets
       (`demo-paused` absent). Screenshot, read, **Cancel**;
     - Networks, with only `demo-net2` unused (checked with the CLI):
       confirm, then `podman network ls` shows only that network gone;
     - `omarchy bar set nixarchy.podman showStopped false --json` and a shell
       restart: the Containers dialog gives the count and says the containers are
       hidden. Read it, Cancel, and restore `shell.json`;
     - a filter typed: the filter note appears. Cancel;
     - `qs log` shows no plugin errors.
   - Teardown: `docs/capture.sh --teardown` and a clean diff; restore the link and
     restart the shell; hand back control; post on the bus.
5. **PR.** Push and open a PR that links the intent, spec and plan and closes #14,
   noting that `confirm-prune.png` is retaken in #11.
   - Verify: CI is green, and `git show origin/master:Model.js` after merge contains
     `pruneMessage`.

## Tests

```bash
node tests/run.js                              # green; the prune tests failed before step 1's fix
nix flake check
nix flake check --all-systems --no-build
nix build
d=$(mktemp -d) && git clone -q . "$d/p" && rm -rf "$d/p/.git" && omarchy plugin validate "$d/p"
```

## Rollback

- Each step is one commit: `git revert <sha>`. Before merge, delete the branch.
- razer: put back the recorded plugin link and restart the shell. `shell.json` comes
  back from the backup. `docs/capture.sh --teardown` removes only the recorded demo
  objects.
- After merge: revert the merge commit.
