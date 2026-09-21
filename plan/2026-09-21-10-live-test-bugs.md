---
status: approved
issue: 10
spec: spec/2026-09-21-10-live-test-bugs.md
---

# Plan: Fix the bugs found in the live test pass

## Approved decisions (self-contained summary)

Bugs are numbered as in the intent.

1. **Volume prune.** `PRUNE.volumes.args` becomes
   `["podman", "volume", "prune", "-f"]`. Podman's `volume prune` has no `-a`,
   and already takes named volumes.
   - A test pins all four tabs' prune arguments: `container prune -f`,
     `image prune -a -f`, `volume prune -f`, `network prune -f`.
   - The comment above `PRUNE` (at `Model.js:1032`) is corrected: the point is
     that `rm`/`rmi` never get `--force`. The prunes do get `-f`, which only stops
     Podman's own prompt.
2. **Labels in both shapes.** A new `labelMap(labels)` returns a plain
   `{key: value}` object:
   - A non-null, non-array object (the shape `podman ps` and `podman volume ls`
     give on Podman 5) is copied, with values through `String`.
   - Anything else is parsed as `k=v,k=v` text, the shape network labels, older
     Podman and Docker give. A part with no `=` is a key with value `""`.
   - The array guard is `typeof labels === "object" && labels.length === undefined`,
     not `Array.isArray`.
   - `labelValue` returns `trim(map[key] || "")`, and `hasLabel` returns
     whether `map` has `key` as its own property. Their callers don't change.
     (Deviation in step 2: own property, not `key in map`, so a label named like
     an `Object.prototype` member such as `constructor` cannot match.)
3. **The menu's list height.**
   - `PodmanView.qml` gets `property int listMaxHeight: Style.space(560)`, which
     feeds `ResourceList.maxHeight`, and
     `readonly property int chromeHeight: column.implicitHeight - list.height`.
   - `Menu.qml` sets `listMaxHeight` to
     `Math.max(Style.space(120), Math.min(Style.space(560), Math.floor((panel.height * 0.85 - card.contentTopInset - card.contentBottomInset) / root.uiScale) - view.chromeHeight))`.
   - The popup is unchanged.
   - If the log shows `Binding loop detected`, compute `chromeHeight` from the
     non-list children instead, and record that as a deviation.
   - Deviation in step 5 (the fallback above, taken): on razer the first version
     logged `Binding loop detected for property "chromeHeight"` and for the
     ListView's `height`. `chromeHeight` is now the sum of `hero`, `tabStrip`,
     `filterField`, `separator` and `footer`, plus `emptyState` and `errorLine`
     when visible, plus `Style.spacing.panelGap` times the gaps. Re-checked live:
     footer visible on Volumes (9) and Images (12), and the log is clean.
4. **Stopped on purpose.**
   - `var STOP_EXIT_CODES = [137, 143]` sits next to `UP_STATES`. `isFailing`
     treats those codes like 0. The comment says an OOM kill now looks like a
     clean stop, and that this was accepted at intent approval.
   - The status text keeps `Exited (137)`.
   - `containerRow.unhealthy = container.up && container.health === "unhealthy"`.
5. **The first move.** A new `nextCursor(active, index, delta, count)` returns
   `{index}`:
   - hidden cursor: `clampCursor(index, count)`, whatever `delta` is;
   - visible cursor: `clampCursor(index + delta, count)`.

   `PodmanView.moveCursor` uses it. Both filter hand-offs stay as they are.
6. **Menu settings.** First diagnose, with temporary instrumentation that is
   never committed. Then:
   - if the stale copy is the host's, reword the `docs/usage.md` sentence, file
     an upstream omarchy report, and make no plugin change;
   - if the plugin holds the stale copy, fix `Menu.qml`.

   No reading `shell.json` from the plugin.
7. **List sync.** Reproduce live with the **unfiltered** log, then fix at the
   cause:
   - re-entrancy: a `syncing`/`resync` guard in `ResourceList.sync()`;
   - a refused ListModel operation: fix its source, with a Node test if the
     source is in `Model.js`.

   No speculative guards, and no rebuild-on-mismatch. If it doesn't reproduce
   within the time box, record what was tried on #10 and leave it open.

   Deviation in step 8: the cause was neither (a) nor (b). A depth counter showed
   no nested `sync()`, and the log had no ListModel warning. Logging the short
   case gave `count=0 next=4 nextKeys=[null,null,null,null]`: on Containers →
   Images, the view saw the new tab with the old tab's containers for one
   binding pass. `imageRow` keyed them by `rowId`, which containers lack, so
   `reconcilePlan` matched `undefined === undefined` and inserted nothing. Fixed
   at the source: `rowsForSections` builds each item with its own `kind`'s
   builder. A Node test covers it. No guard in `ResourceList.qml`.

**Rejected** (don't reintroduce):

- sniffing the Podman version for `-a`;
- `{{range}}` label templates;
- a scrolling card;
- lowering `maxHeight` for everyone;
- `podman inspect` for OOMKilled;
- the plugin reading `shell.json`;
- self-healing rebuilds.

**Constraints:**

- `AGENTS.md` rules: logic in `Model.js` with Node tests; no hardcoded colours,
  symlinks or banned package-manager names; a user-visible change updates
  `docs/usage.md`, the README and wrong captures in the same PR; `docs/img/`
  under 8 MB.

**Live-test safety** (applies to every live step):

- Only `demo-*` objects staged by `docs/capture.sh`.
- Screenshot and read every dialog before sending the keys that confirm it, and
  send the confirm in a separate call.
- Never confirm a prune on Containers or Images while the owner has stopped
  containers or unused images.
- Before any prune on Volumes or Networks, list with the CLI what it would take,
  and proceed only if that is `demo-*` alone.
- Snapshot Podman state first and diff it after.
- Back up and restore `shell.json` and the clipboard.

## Steps

One commit per step on `fix/10-live-test-bugs`, each subject citing
`plan step N` and `(#10)`. Steps 1–4 are written test-first: add the tests, run
them to see them fail, then fix. Put the failing output in the commit body.

1. **Bug 1: volume prune.**
   - Change: in `tests/model/resources.test.js`, a test asserting all four
     `Model.pruneSpec(tab).args`. In `Model.js`, drop `-a` from volumes and fix
     the comment at line 1032.
   - Verify: the test fails first on volumes only, then `node tests/run.js` is
     all green.
2. **Bug 2: labels.**
   - Change, `tests/model/parsing.test.js`:
     - a `podman ps` line with object labels (razer's shape:
       `{"com.docker.compose.project":"demo-shop",…}`) gives `project === "demo-shop"`;
     - the text form `a=1,com.docker.compose.project=x` still gives `x`;
     - a volume with object labels `{"com.docker.volume.anonymous":""}` is
       `anonymous`.
   - Change, `tests/model/grouping.test.js`: `sectionsFor` of such containers
     has a section titled `demo-shop`.
   - Change, `Model.js`: add `labelMap`, and rewrite `labelValue` and `hasLabel`
     on top of it.
   - Verify: the new tests fail first, then everything is green.
3. **Bug 4 and the unhealthy mark.**
   - Change, `tests/model/presentation.test.js`: `isFailing` for exited 137 and
     143 is false, for 1 and 139 it is true; a stopped container with
     `(unhealthy)` in its status gives a row with `unhealthy === false`, while a
     running one stays true.
   - Change, `Model.js`: `STOP_EXIT_CODES`, `isFailing`, `containerRow`.
   - Verify: fail first, then green.
   - Deviation in step 3: the inherited test "health is only read while the
     container is actually up" used `Exited (137)` as its crash. It now uses
     `Exited (1)`, which keeps what it tests under the approved decision.
4. **Bug 5: first move.**
   - Change: `tests/model/cursor.test.js` (new) covers
     `nextCursor(false,0,1,5).index === 0`, `nextCursor(true,0,1,5).index === 1`,
     `nextCursor(false,0,-1,5).index === 0`,
     `nextCursor(true,4,1,5).index === 4`, and `nextCursor(false,7,1,3).index === 2`.
     `Model.js` gets `nextCursor`, and `PodmanView.moveCursor` uses it.
   - Verify: fail first, then green. `nix flake check` passes (QML changed).
5. **Bug 3: menu list height.**
   - Change: `PodmanView.qml` (`listMaxHeight`, `chromeHeight`, pass it to
     `ResourceList.maxHeight`) and `Menu.qml` (the binding).
   - Verify:
     - `nix flake check` and `nix build` pass;
     - live, in step 6's session: the footer is fully visible with 9 or more rows
       on Volumes and Images, and the list scrolls;
     - `Binding loop` doesn't appear in the log.
   - Commit after that live check passes.
6. **Live session on razer: install, verify 1–5, diagnose 6 and 7.** No commit
   unless it forces a fix; a fix goes into the step it belongs to, with a plan
   deviation note.
   - **Install.** razer's `~/.config/omarchy/plugins/nixarchy.podman` is a
     nixarchy-managed symlink. Record its target first:
     `readlink ~/.config/omarchy/plugins/nixarchy.podman`. Then replace it with a
     real copy of this branch's `nix build` output (`cp -rL`, then `chmod -R u+w`),
     run `omarchy-restart-shell`, and wait for `omarchy-shell shell ping`.
   - **Stage.** Take the snapshot and backups. Run `docs/capture.sh --setup`, and
     create `demo-u` and `demo-net2` so there are enough rows (record them in the
     capture state file). Ask for ai-mirror control.
   - **Verify bugs 1–5**, as in the spec:
     - (1) Volumes → Prune removes only `demo-*` unused volumes. Check the
       dangling list first; if anything that isn't `demo-*` is unused, skip the
       confirm and verify the command in the Node test only.
     - (2) Containers shows a `demo-shop` header.
     - (3) The footer is visible on Volumes and Images.
     - (4) After stop-all, the demo rows are dim and `demo-shop-migrate` is red.
     - (5) Fresh open, `j`, Enter starts the first row; confirm with `podman events`.
   - **Diagnose bug 6.**
     - Locally, not committed: add to `Menu.open()`
       `console.info("podman-menu", JSON.stringify(root.settings), root.shell === root._lastShell); root._lastShell = root.shell`,
       with `property var _lastShell: null`.
     - Install, restart, open the menu, then `omarchy bar set nixarchy.podman showStats false --json`,
       then open again.
     - Read `qs log`. Record whether `shell` stayed the same object and whether
       `settings` changed.
     - Remove the instrumentation (`git diff` must be empty for `Menu.qml`).
   - **Reproduce bug 7.** Time box: 20 minutes. Run tab switches (`1`–`4`, `h`/`l`,
     `Tab`), typing and clearing the filter, `u`, and a stop/start while on
     Containers. Capture the **unfiltered** `qs log` around each
     `ResourceList.qml:75` hit, including `ListModel` and `<Unknown File>` lines.
   - **Tear down.** Run `docs/capture.sh --teardown` and diff the snapshot. Restore
     `shell.json` and the clipboard. Leave the copied plugin in place for steps
     7–8, and hand back control.
7. **Bug 6: fix or document.** Following step 6's evidence:
   - **host:** reword `docs/usage.md` line ~193 to say the popup applies a change
     at once and the menu picks it up after `omarchy-restart-shell`. Draft the
     upstream report for the owner to file. Don't file it yourself: it's outward
     facing.
   - **plugin:** fix `Menu.qml` and re-verify live.

   Verify: the docs match what the desktop does. Record the evidence in the
   commit body.
   - Outcome (step 6 evidence): host. After `omarchy bar set`, the menu's next
     open logged `sameShell=true barCfg=null`. omarchy 4.0.4's `prunePluginApis`
     revokes and destroys the scoped API, and keep-loaded instances are
     re-injected only on reload. Took the docs path; the upstream report is
     drafted for the owner.
8. **Bug 7: fix at the cause.**
   - Following step 6's log: the re-entrancy guard in `ResourceList.sync()`, or a
     fix to the refused operation (with a Node test if it is in `Model.js`).
   - Verify live: repeat the step 6 sequence twice, and `qs log` shows no
     `ResourceList` errors and no `ListModel` warnings.
   - If it didn't reproduce: no code. Comment on #10 with what was tried, and
     note it in the PR.
9. **Docs.**
   - `docs/usage.md` and `README.md`:
     - stopped containers show dim, and exit 137/143 is a normal stop;
     - the settings sentence, if step 7 changed it;
     - anything else the steps changed.
   - Verify: `grep -n "grouped by Compose" docs/usage.md README.md` is still true
     now that it works. `nix flake check` passes.
10. **Captures.**
    - Find which captures show the Containers tab: open every file in `docs/img/`.
      Expected: `popup-containers.png`, `menu.png`, `demo.gif`, `rec-menu.*`,
      `rec-popup.*`. Retake those per `AGENTS.md` "Retaking the captures".
    - Use the same host as the originals: check their pixel size against each
      monitor. Only `demo-*` objects, filtered where the section says.
    - Verify: look at every new image and a frame sheet of every video.
      `du -sb docs/img` must be under 8 MB, compared before and after. The
      teardown diff is clean.
    - Deviation in step 10: deferred at the owner's request ("push and merge all
      that is done"). The captures were taken on p620 and need that desktop.
      Tracked in #11, which lists the affected stills and recordings.
11. **Restore razer and open the PR.**
    - Put the nixarchy link back:
      `rm -rf ~/.config/omarchy/plugins/nixarchy.podman && ln -s <recorded target> ~/.config/omarchy/plugins/nixarchy.podman`,
      then `omarchy-restart-shell`.
    - Push the branch and open a PR that links `intent/`, `spec/` and `plan/`,
      closes #10, and lists step 6's evidence.
    - Verify: CI is green, and razer's plugin link points at the recorded store
      path again.

## Tests

```bash
node tests/run.js                              # all green; new tests failed before their fix
nix flake check                                # tests + manifest, entry points, no symlinks, colour/word checks
nix flake check --all-systems --no-build       # aarch64 evaluates
nix build                                      # the plugin folder
d=$(mktemp -d) && git clone -q . "$d/p" && rm -rf "$d/p/.git" && omarchy plugin validate "$d/p"
du -sb docs/img                                # < 8388608
```

Live checks (razer, step 6 and re-checks in steps 5, 7 and 8) are listed in the
steps. Each one ends with an unfiltered `qs log` read.

## Rollback

- **Code:** each step is its own commit, so undo one with
  `git revert <sha>`. The branch is unmerged until the PR, and deleting it
  undoes everything.
- **razer:** put the plugin link back to the recorded store path (step 11), then
  run `omarchy-restart-shell`. Restore `shell.json` from the backup.
  `docs/capture.sh --teardown` removes only the recorded demo objects.
- **After merge:** revert the merge commit. nixarchy hosts pick up the old
  version on their next rebuild.
