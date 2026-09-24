---
status: draft
issue: 19
spec: spec/2026-09-24-19-stop-all-confirm.md
---

# Plan: Stopping every container should ask first

## The approved decisions, carried over

Implementable without opening the intent or the spec.

**The defect.** `PodmanView.qml:324-332` wires the header's "Stop every
running container" button straight to `root.podman.stopEverything()` with no
`ask()`. Every other destructive path goes through the confirmation dialog.
`space` also starts and stops containers, through Omarchy's shared
`PanelKeyCatcher.qml:75-77`, and is documented nowhere.

**The line, approved:** breadth, not reversibility. Acting on the row under
the cursor stays immediate; acting on every row at once asks. This is where
`p` already sits, so the button becomes consistent with an existing rule
rather than a new one.

**`space` keeps its behaviour and gets documented.** It comes from the shared
key catcher that every Omarchy surface uses, and it toggles one row exactly as
`enter` does, so it is on the immediate side of the line. Only the silence was
the defect.

**The button stays** where it is, with its `visible` condition unchanged.

**The confirmation lives in the view, never in `PodmanState`.**
`Panel.qml:59`'s `stopAll` IPC verb must keep working without a dialog, so
`stopEverything()` is not touched. It ends up with no in-plugin caller, which
is correct — it becomes the IPC entry point and nothing else — and gets a
comment saying so, or a future reader will delete it as dead.

**The message is built from the unfiltered list.** A filter narrows the view,
never what the command takes (#14).

**Out of scope, owned by #23:** the duplicate `tab` row at `README.md:55`/`:60`,
and the wording of `docs/index.md:103`.

## Steps

One commit per step, each citing the step number and `#19`.

1. **`Model.js`: add `stopAllSpec(containers)`**, immediately after
   `pruneMessage` (which ends at line 1132, before `canPrune`), so it sits
   with the other question-builders.

   ```js
   // Every running container at once, named like a prune (#14): the question
   // says what it takes, because "Are you sure?" teaches people to say yes.
   // Returns null when nothing is running, which is also the button's
   // visibility condition, so the two cannot disagree.
   function stopAllSpec(containers) {
     var running = []
     for (var i = 0; i < (containers || []).length; i++) {
       if (containers[i].up) running.push(containers[i])
     }
     if (running.length === 0) return null

     var ids = []
     for (var j = 0; j < running.length; j++) ids.push(running[j].id)

     var names = []
     for (var k = 0; k < running.length && k < 3; k++) {
       names.push(running[k].name || running[k].id)
     }
     var rest = running.length - names.length
     var named = rest > 0 ? names.join(", ") + " and " + rest + " more" : names.join(", ")

     return {
       args: ["podman", "stop"].concat(ids),
       message: "Stop " + plural(running.length, "running container") + ": " + named + "?",
       label: "Stop all"
     }
   }
   ```

   No export step: `Model.js` is a `.pragma library`, and `tests/harness.js`
   picks up every new global automatically.

   → verify by `node -e` loading the file and calling it, before any test
   exists.

2. **`tests/model/prune.test.js`: add the `stopAllSpec` cases.** It is the
   closest subject and already imports `make`. `make(name, project, state)`
   yields a normalized container, so `make("web", "", "running").up` is
   `true`, `.id` and `.name` are the name.

   - empty list → `null`
   - `[make("a","", "exited")]` → `null`
   - one running → message names it, `args` is `["podman","stop","a"]`
   - exactly three running → all three named, message contains no "more"
   - five running → three named plus "and 2 more", `args` has all five ids
   - a mix → stopped containers appear in neither `args` nor the message
   - a container with `Names: ""` → falls back to its id in the message

   → verify by `node tests/run.js`: 157 + 7 = 164 passing, 0 failing.

3. **`PodmanView.qml`: add `askStopAll()`** directly after `askPrune`
   (which ends at line 174), and point the button at it.

   ```js
   function askStopAll() {
     var spec = Model.stopAllSpec(root.podman.containers)
     if (!spec) return
     ask(spec.args, spec.message, spec.label)
   }
   ```

   `root.podman.containers`, not `root.podman.items` — the unfiltered list.

   Then at `PodmanView.qml:331`, change
   `onClicked: root.podman.stopEverything()` to
   `onClicked: root.askStopAll()`. Leave the `visible` condition alone.

   → verify by `grep -n "stopEverything" *.qml` returning only
   `PodmanState.qml` (the definition) and `Panel.qml:59` (the IPC verb).

4. **`PodmanState.qml`: comment `stopEverything()`** at its definition
   (line 197) naming `Panel.qml:59` as its only caller, so it is not deleted
   as dead:

   ```qml
   // The stopAll IPC verb's entry point, and only that — Panel.qml:59. The
   // button asks first and builds its own command (#19); a scripted caller
   // cannot answer a dialog, so this path stays direct.
   ```

   → verify by reading it back.

5. **`Model.js`: fold `space` into the `SHORTCUTS` `enter` row.** Replace

   `{ group: "Containers", keys: "enter", text: "Start or stop the container" },`

   with

   `{ group: "Containers", keys: "enter  space", text: "Start or stop the container" },`

   Replace, not add, so the `?` sheet stays its current length.

   → verify by `node -e` printing the Containers group.

6. **`README.md`: match `SHORTCUTS` exactly.** Line 66,
   `| `enter` | Start or stop the container |`, becomes
   `| `enter`  `space` | Start or stop the container |`. `Model.js:83-84`
   claims the README quotes `SHORTCUTS`, so this must be character-for-character.

   Also extend the header-buttons sentence at `README.md:91-92` to say the
   stop-everything button asks first and names what it will stop.

   → verify by diffing the README's Containers rows against the `SHORTCUTS`
   Containers entries by eye, and by `grep -c` that only one `tab` row was
   touched (the duplicate at `:55`/`:60` belongs to #23 and must be left alone).

7. **`docs/usage.md`: the same two changes** — `space` beside `enter` at
   line 157's table row, and the stop-everything button's new question in the
   prose that covers the header buttons.

   → verify by `grep -n "space" docs/usage.md` showing the new mention.

## Tests

```bash
node tests/run.js        # expect: 164 passed, 0 failed
nix flake check          # expect: green (same tests, manifest, greps)
```

Live, on the nixarchy desktop, following AGENTS.md's "Verifying live":

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/nixarchy.podman   # if not already linked
omarchy plugin enable nixarchy.podman
omarchy-restart-shell && omarchy-shell shell ping
qs list --all && qs log -i <instance>                    # read for errors
```

Then, with three `demo-*` containers running:

1. Press the header's stop button. **Screenshot the dialog before answering
   it.** This repository's memory records a confirmation answered blind on
   razer that pruned real containers; that is not repeated here.
2. Confirm the dialog names all three.
3. Cancel → all three still running.
4. Press again, confirm → all three stopped, nothing else touched. Diff
   `podman ps -a`, `images`, `volume ls`, `network ls` against a snapshot
   taken first.
5. With a filter showing one container, press it → the question still names
   every running container, not the filtered one.
6. `space` on a running row → stops immediately, no dialog.
7. `?` → the Containers group reads `enter  space`.
8. `omarchy shell nixarchy.podman.bar stopAll` → stops everything, no dialog.

Captures: `docs/img/` has no shortcut-sheet still, so step 5 invalidates no
PNG. Check `rec-menu.webm`, `rec-menu.mp4` and `demo.gif` frame by frame for
the `?` sheet before concluding no retake is needed. No new capture is
proposed — the dialog is visually identical to the shipped
`confirm-prune.png` and `confirm-remove.png`, and `docs/img` is at 69% of its
8 MB budget.

## Rollback

Every step is additive or a one-line substitution, on a branch, with no
migration and no state. `git revert` the range, or reset the branch — nothing
outside the repository changes. If only the live test fails, step 3's single
line reverts to `onClicked: root.podman.stopEverything()` and restores
today's behaviour exactly, leaving the tested `stopAllSpec` in place and
unused.
