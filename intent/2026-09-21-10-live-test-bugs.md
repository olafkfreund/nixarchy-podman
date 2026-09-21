---
status: approved
issue: 10
author: olafkfreund
---

# Intent: Fix the bugs found in the live test pass

## Problem

A full live test of both surfaces on razer (1920×1080, Podman 5.8.6, omarchy
4.0.4) found seven defects. Each was seen on the desktop or reproduced against
real `podman` output, not inferred from reading code.

1. **Prune on Volumes never works.** `Model.js` sends `podman volume prune -a -f`.
   Podman 5.8 has no `-a` for `volume prune`, exits 125 with
   `unknown shorthand flag: 'a' in -a`, and removes nothing. No test pins the
   prune arguments, so the suite stayed green.
2. **Containers are never grouped by Compose project.** `podman ps` with
   `{{json .Labels}}` emits a JSON object, but `labelValue` and `hasLabel` split
   a `k=v,k=v` string. The object stringifies to `[object Object]`, so `project`
   and `service` are always empty and every container lands in one unnamed
   section. Network labels arrive as text and parse fine. Volume labels are
   unverified.
3. **The menu's footer is cut off on a 1080p screen.** The card is capped at
   85% of the screen and clips whatever overflows. The list's own height limit
   (`Style.space(560)`) is not scaled by the menu's 1.45×. With roughly six or
   more rows, the usage line and the Prune button are off the card, on the
   Containers, Images and Volumes tabs.
4. **Containers you stop look like crashes.** A container stopped from the
   panel exits 137, or 143 after a graceful SIGTERM. It is then drawn red,
   "Exited (137)", exactly like a container that failed. After stop-all, every
   row is red.
5. **The first `j` skips the top row.** From a fresh open, with the cursor
   hidden, `moveCursor(+1)` moves from index 0 to 1. Pressing Enter then acts on
   the second container: in the test it started `demo-shop-migrate` instead of
   the first row.
6. **The menu ignores settings changed while the shell runs.** After
   `omarchy bar set nixarchy.podman …`, the popup applies the change at once.
   The menu keeps the old values (tab, stopped containers, stats) until the
   shell restarts. `docs/usage.md` says a change applies "the next time you
   open it, with no restart".
7. **The list model falls out of step with its rows.** The shell log repeats
   `ResourceList.qml:75: TypeError: Cannot read property 'kind' of undefined`.
   After the reconcile operations, the model holds fewer rows than the target.
   `reconcilePlan` itself always ends with the right length, so the cause is in
   how the plan is applied: likely `sync()` being re-entered, or a clear
   arriving mid-sync.

## Proposed outcome

- Pruning on Volumes removes the unused volumes, on the Podman versions the
  plugin supports.
- Containers carrying Compose labels are grouped under their project, as the
  user guide describes. Volumes and networks read their labels correctly
  whichever shape Podman sends.
- In the full-screen menu, the footer (usage line and Prune button) is always
  visible on a 1080p screen, whatever the list's length. The list scrolls
  instead.
- A container stopped on purpose does not look like a failure. A real failure
  still stands out.
- The first `j` (or `↓`) after opening lands on the top row.
- A setting changed with `omarchy bar set` applies to the menu the next time it
  opens, as the docs say. If that cannot be done from the plugin, the docs say
  what is actually true instead.
- The shell log stays free of `ResourceList.qml` errors through tab switches,
  filtering and refreshes.
- Each fix has a Node test that fails on today's `Model.js`, wherever the fix is
  in `Model.js`.

## Affected users and systems

- `Model.js` and `tests/`: prune arguments, label parsing, failure
  classification, cursor start.
- `Menu.qml`, `ResourceList.qml`, and possibly `PodmanView.qml`: menu height,
  list sync.
- `docs/usage.md` and the README tables, if any visible behaviour or the
  settings wording changes.
- Screenshots in `docs/img/` that show the ungrouped container list or red
  stopped containers will be wrong afterwards and need retaking.
- Every user of either surface, on any host. It was found on razer; p620 is the
  other nixarchy desktop.

## Constraints

- Logic in `Model.js`, with Node tests; QML stays drawing and wiring (`AGENTS.md`).
- The `AGENTS.md` rules hold: no hardcoded colours, no symlinks, no banned
  package-manager names. `nix flake check` must pass.
- Prune and remove commands keep refusing to force: no new `-f` on `rm`/`rmi`,
  and no `--all` added anywhere to reclaim more.
- Must work on Podman 5.x. Label parsing must keep accepting the `k=v` text
  form, since older Podman and Docker-compatible output use it.
- Verify live on a nixarchy desktop using only `demo-*` objects staged by
  `docs/capture.sh`. During live tests:
  - screenshot every dialog before sending the keys that confirm it;
  - never confirm a prune on Containers or Images while the owner has stopped
    containers or unused images;
  - restore `shell.json` afterwards.
- `docs/img/` stays under 8 MB.

## Open questions

1. **What counts as "stopped on purpose" (bug 4)?** Pick one:
   - (a) treat exit codes 137 and 143 (SIGKILL after stop, SIGTERM) as not
     failing, and keep them dim like exit 0;
   - (b) ask `podman inspect` whether the container was OOM-killed, and only
     then call 137 a failure. This is more accurate, but adds an inspect call
     per stopped container.

   I recommend (a). A real OOM kill will then look like a clean stop.
2. **Bug 6 may be in the host, not the plugin.** The popup reads settings
   through its bar entry and sees changes. The menu reads `shell.barConfig`
   from its scoped shell API, which seems to be refreshed only on some host
   events. If the spec finds that the plugin cannot fix it, should I:
   - (a) change the docs to "restart the shell to apply" and report it to
     omarchy; or
   - (b) have the menu read `shell.json` itself?

   I recommend (a): (b) duplicates the host's config handling.
3. **Should the minor items join this task?** They are: the see-through help
   sheet, the card jumping between tabs, rows re-sorting under the pointer, a
   stale unhealthy mark on stopped containers, an error line that is truncated
   and can only be dismissed with the mouse, and the stale comment at
   `Model.js:1032`. I recommend only the stale comment and the unhealthy mark,
   which are one-liners next to code this task already touches. The rest would
   be a separate issue.
4. **Should prune on Containers and Images say what it will remove?** In this
   test, one keypress plus one confirm removed five real stopped containers.
   Listing the names, or the count, in the dialog would make that much harder to
   do by accident. This is a new feature rather than a fix, so I recommend a
   separate issue.

## Decisions at approval

Approved without separate answers; the recommendations stand:
1. Exit codes 137 and 143 count as a clean stop, not a failure.
2. If the menu's stale settings are a host defect, correct the docs and report it
   to omarchy rather than reading `shell.json` from the plugin.
3. Of the minor items, only the stale `Model.js:1032` comment and the unhealthy mark
   on stopped containers join this task; the rest go to a separate issue.
4. A prune dialog that names what it removes is a separate issue.
