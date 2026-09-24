---
status: draft
issue: 19
intent: intent/2026-09-24-19-stop-all-confirm.md
---

# Spec: Stopping every container should ask first

## Design

### The line this draws

The intent asked where confirmation should start. The answer this spec
proposes: **breadth, not reversibility.**

Stopping one container is not irreversible — `enter` starts it again. Nor is
stopping forty, strictly. But stopping forty takes down everything the person
is running in one keystroke, and recovering means remembering which of them
were up. The cost of being wrong scales with how many rows the action touches,
and that is what the question should track.

So: acting on the row under the cursor stays immediate. Acting on every row at
once asks. That is the same line `p` already sits on — prune touches the whole
tab and asks — so this makes the header button consistent with a rule the
plugin already follows rather than inventing a new one.

### `Model.stopAllSpec(containers)`

The logic goes in `Model.js` with a Node test, per AGENTS.md. It sits beside
`pruneSpec`/`pruneMessage` and mirrors their shape:

```js
// Every running container at once, named like a prune (#14): the question
// says what it takes, because "Are you sure?" teaches people to say yes.
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

It returns `null` when nothing is running, which is also the button's
visibility condition, so the two cannot disagree.

`plural` and the three-then-"and N more" shape are lifted from
`pruneMessage` deliberately: the user has already learnt to read that
sentence, and a second phrasing for the same kind of question is a second
thing to learn.

### `PodmanView.qml`

Add the asking function next to `askRemove` and `askPrune`:

```js
function askStopAll() {
  var spec = Model.stopAllSpec(root.podman.containers)
  if (!spec) return
  ask(spec.args, spec.message, spec.label)
}
```

`root.podman.containers`, not `root.podman.items` — the unfiltered list. A
filter narrows what is shown; it has never narrowed what prune takes (#14),
and it must not narrow this either, or the question would name three
containers while `podman stop` took thirty.

The button at `PodmanView.qml:324-332` changes one line:

```qml
onClicked: root.askStopAll()
```

Its `visible` condition is unchanged. `ask()` already routes the answer
through `pendingCommand` and `confirmAccepted()` → `runCommand`, and
`confirmDialog.selectedIndex = 0` already makes Cancel the default answer, so
a stray `enter` cancels rather than confirms.

Note what this deliberately does *not* touch: `PodmanState.stopEverything()`
keeps building its own command from its own list. The dialog belongs to the
view. `Panel.qml:59`'s `stopAll()` IPC verb therefore keeps working exactly as
it does today, which it must — a scripted caller cannot answer a dialog.
`stopEverything()` ends up with no in-plugin caller, which is correct: it is
now the IPC entry point and nothing else.

### `space`

**Leave the behaviour alone. Document it.**

`space` reaches `activateRow()` through Omarchy's *shared*
`PanelKeyCatcher.qml:75-77`, which every Omarchy surface uses. Making it inert
here would make this one plugin inconsistent with the rest of the shell, and
the next person to read `PanelKeyCatcher` would find a key that works
everywhere except Podman, with nothing local explaining why.

It also lands on the right side of the line drawn above: `space` toggles the
single row under the cursor, exactly as `enter` does, and single-row actions
stay immediate. The defect was never that `space` acts — it is that nothing
told the user it does.

So `Model.SHORTCUTS` gains one row, next to `enter`:

```js
{ group: "Containers", keys: "enter  space", text: "Start or stop the container" },
```

replacing the existing `enter` row rather than adding a second line, so the
`?` sheet stays the length it is.

### Documentation

`Model.js:83-84` claims the README quotes `SHORTCUTS`, so the README's
Containers row must change with it, character for character.

- `README.md` — the `enter` row becomes `enter  space`; the header-buttons
  sentence at `:91-92` gains that the stop-everything button asks first.
- `docs/usage.md` — same two changes, in its own table and prose.
- `docs/index.md:103` — "Nothing irreversible happens by accident" is left
  standing but is no longer doing work it cannot support. It is accurate about
  removal, which always asks; it was never a claim about stopping, which is
  reversible. This spec does not rewrite it, and `#23` owns the site's
  wording.

The duplicate `tab` row at `README.md:55`/`:60` is *not* fixed here. It
belongs to `#23`, and fixing it in two places invites a conflict.

## Alternatives rejected

**Confirm every stop, including single containers.** Rejected: it is the
mechanism that produced the incident this repository already recorded. A
dialog the user sees forty times a day is a dialog answered without reading,
and then the one that mattered is answered the same way. Confirmation is a
scarce resource and spending it on cheap, reversible actions devalues it.

**Make `space` inert on the Containers tab.** Rejected above: it breaks a
shell-wide convention locally, for a key that is on the correct side of the
line anyway.

**Remove the stop-everything button and make it keyboard-only.** Rejected: it
removes a working affordance to fix a missing question, which is a larger
change than the defect warrants, and a keyboard-only destructive action is
*less* discoverable, not safer.

**Put the confirmation inside `PodmanState.stopEverything()`.** Rejected: it
would break the `stopAll` IPC verb, which has no way to answer a dialog, and
it puts view concerns in the state object.

**A generic "Are you sure?" dialog.** Rejected by #14, which established that
the question names what it takes. Regressing to a generic prompt in a new
place would undo that.

## Risks

- **The command can get long.** `["podman", "stop", ...ids]` with forty
  containers is a forty-two element argv. It is an argv array, not a shell
  string, so there is no quoting exposure; `runCommand` passes it straight to
  `Process`. `ARG_MAX` is not a practical concern at container-count scale.
- **`stopEverything()` loses its only in-plugin caller**, so a future reader
  may delete it as dead and silently break the `stopAll` IPC verb. Mitigated
  by a comment at its definition naming `Panel.qml:59` as its caller.
- **The message names containers from `root.podman.containers`**, which on a
  bar popup with `showStopped: false` still holds every container — the
  setting filters the *view*, not the state. Verify in testing that the
  count in the question matches what `podman stop` actually takes.
- **Captures.** `docs/img/` has `confirm-prune.png` and `confirm-remove.png`
  but no shortcut-sheet still, so the `SHORTCUTS` row change invalidates no
  PNG. It may appear in `rec-menu.webm`/`rec-menu.mp4`/`demo.gif` — those
  must be checked frame by frame before concluding no retake is needed. No
  new capture is proposed: the dialog is visually identical to the two
  already shipped, and `docs/img` is at 69% of its 8 MB budget.
- **Host risk is nil.** No NixOS, flake or packaging change; no new file, so
  `flake.nix`'s `files` list is untouched.

## Verification

1. `node tests/run.js` — green, with new cases for `stopAllSpec`:
   - `null` when the list is empty
   - `null` when every container is stopped
   - one running container: message names it, `args` is `["podman","stop",id]`
   - three running: all three named, no "and N more"
   - five running: three named plus "and 2 more", `args` carries all five ids
   - stopped containers appear in neither `args` nor the message
   - a container with no `name` falls back to its `id`
2. `nix flake check` — green (runs the same tests, plus manifest and greps).
3. Live on the desktop, per AGENTS.md's procedure:
   - Start three demo containers. Press the header's stop button. **Screenshot
     the dialog before answering it** — the memory note on this repository
     says a confirmation was once answered blind on razer, and that is not
     repeated here. Confirm the dialog names all three.
   - Cancel. Verify all three are still running.
   - Press it again, confirm, verify all three stopped and no fourth object
     was touched.
   - With a filter active that shows one container, press it: the question
     must still name every running container, not the filtered one.
   - Press `space` on a running row: it stops, immediately, no dialog.
   - Press `?`: the Containers group reads `enter  space`.
   - `omarchy shell nixarchy.podman.bar stopAll` over IPC: stops everything
     with no dialog, as before.
4. `git diff` the README's Containers row against `Model.SHORTCUTS` and
   confirm they are identical.
