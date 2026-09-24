---
status: draft
issue: 19
author: olafkfreund
---

# Intent: Stopping every container should ask first

## Problem

The header carries a button whose tooltip reads "Stop every running
container". `PodmanView.qml:324-332` wires it straight to
`root.podman.stopEverything()` — no `ask()`, no dialog, no undo. One click on
a button the user may have been aiming past stops every running container on
the machine.

Every other destructive path in this plugin asks first. Removing a single
container, removing an image, removing a volume, pruning a tab: all of them
go through `ask()`, and #14 went further and made the prune question name
what it is about to take. The one action that touches *everything at once* is
the only one that asks nothing.

The same reach exists from the keyboard without anyone having documented it.
Omarchy's shared `PanelKeyCatcher.qml:75-77` emits `activateRequested` on
`Qt.Key_Space`, `PodmanView.qml:265` routes that to `activateRow()`, and on
the Containers tab that calls `toggleContainer`. So `space` starts and stops
containers. It is absent from `Model.SHORTCUTS`, and therefore from the `?`
sheet, from the README tables and from `docs/usage.md`. A user pressing space
to scroll — the reflex from every list they have ever used — stops whatever
the cursor is on.

Two of our own documents currently promise otherwise. `docs/index.md:103`
says "Nothing irreversible happens by accident." `README.md:91-92` says only
that the header buttons "do what their tooltips say", which is true and tells
the reader nothing about whether they will be asked.

This is the failure recorded in this repository's own memory: on razer, a
confirmation was answered blind and real containers went away. That incident
produced the rule that a dialog must be seen before it is answered. This
button skips the dialog altogether.

## Proposed outcome

- Stopping every running container asks first, and the question names what it
  is about to stop, in the same voice #14 established for prune.
- Whatever `space` does on a row is either asked for, or changed, or
  documented — the intent should not prejudge which. It must not remain an
  undocumented one-key stop.
- `docs/index.md:103` is true again: no destructive action in the plugin
  proceeds without the user seeing a question.
- The README and `docs/usage.md` describe the header buttons and every key
  that can stop a container.

## Affected users and systems

- Both surfaces: the header lives in `PodmanView.qml`, shared by `Panel.qml`
  and `Menu.qml`.
- Anyone driving the plugin from the keyboard, who is the primary audience —
  the bar popup and the full-screen menu are both keyboard-first.
- `docs/usage.md`, `README.md` and `docs/index.md`.
- `Model.SHORTCUTS`, and so the `?` sheet, which `Model.js:83-84` asserts the
  README quotes verbatim.

## Constraints

- Must not add a confirmation to the non-destructive paths. Starting a
  container, filtering, copying and refreshing stay immediate; a plugin that
  asks about everything trains people to dismiss questions unread, which is
  how the razer incident happened.
- The question must name what it takes, as `Model.pruneMessage` does (#14).
  "Are you sure?" is not acceptable here.
- Logic goes in `Model.js` with a Node test (AGENTS.md). The message belongs
  next to `removeMessage` and `pruneMessage`, not inlined in QML.
- `stopEverything()` is also reachable over IPC as `stopAll` (`Panel.qml:59`).
  A scripted caller must keep working without a dialog it cannot answer —
  the confirmation belongs to the UI path, not to `PodmanState`.
- A user-visible change updates `docs/usage.md` and the README tables in the
  same PR, and retakes any capture it makes wrong (AGENTS.md). `docs/img` is
  at 69% of its 8 MB budget.

## Open questions

1. **What should `space` do?** Three options, and the approver picks:
   (a) leave it toggling but document it and let the new confirmation cover
   the stop half; (b) make it do nothing on the Containers tab, so `enter` is
   the only toggle; (c) leave it entirely alone as an Omarchy-wide convention
   we should not break locally. Option (c) has a real argument: the key comes
   from the shared `PanelKeyCatcher`, so changing it here makes this plugin
   inconsistent with every other Omarchy surface.
2. **Does stopping need a confirmation for a single container too?** Today
   `enter` stops one container immediately. This intent proposes asking only
   for the all-at-once button, on the grounds that stopping one container is
   cheap to undo and stopping forty is not. Confirm that line is in the right
   place.
3. **Should the button keep its place in the header at all?** It is visible
   whenever the Containers tab has a running container. An alternative is to
   move it behind the prune-style keyboard path and drop the always-present
   button.
