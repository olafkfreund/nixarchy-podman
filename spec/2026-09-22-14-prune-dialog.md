---
status: draft
issue: 14
intent: intent/2026-09-22-14-prune-dialog.md
---

# Spec: A prune says what it will remove

## Design

A new `Model.pruneMessage(tab, list, opts)` builds the question from the same data
the tab draws. `PodmanView.askPrune` asks with it instead of `pruneSpec(tab).message`.
The commands in `PRUNE` do not change.

### What goes, per tab

`pruneTargets(tab, list)` returns the items a prune would take. It uses the tab's
unfiltered list (`podman.containers` on Containers, `podman.items` elsewhere), never
the filtered view.

| Tab | Taken by the prune | Why this matches Podman |
| --- | --- | --- |
| Containers | state in `PRUNABLE_STATES = ["exited", "created", "stopped", "configured"]` | `container prune` removes stopped containers only. A `paused` container is not running, yet the prune leaves it, so "not up" would overcount. |
| Images | `!inUse` | `image prune -a` takes every image no container uses. `inUse` comes from Podman's own per-image container count, the same source as the tab's **Unused** section. |
| Volumes | `!inUse` | `inUse` is Podman's `dangling=true` list, the same thing `volume prune` acts on. |
| Networks | `!inUse` (the built-in `podman` network is always in use) | `inUse` is Podman's `dangling=true` list. |

### The message

Three parts, in order:

1. **The count and the first three names.** For example:
   - `Remove 5 stopped containers: web, db, migrate and 2 more?`
   - `Remove 1 unused image: localhost/demo/tools:latest?`

   The noun is singular or plural (`plural`), and names are the row names already
   drawn (`name`: sanitized, and anonymous volumes already shortened).
2. **The kind's warning,** kept from today's messages. Volumes: "Whatever is stored
   in them goes with them." The other tabs have none.
3. **A filter warning, when one is active** (`opts.filter` non-empty): "The filter
   does not limit a prune."

**Stopped containers can be hidden.** With "Show stopped containers" off
(`opts.showStopped === false`), `podman.containers` does not include the stopped
ones, so the names are not known. The count then comes from `podman system df`
(`usage.Containers.count − usage.Containers.active`), and the message says:
`Remove 5 stopped containers? They are hidden because Show stopped containers is off.`
If that count is unknown (`-1`), the message says "every stopped container". It
never gives a number it doesn't have.

**Nothing listed, but the tab still says there is something to reclaim**
(`canPrune` can be true on reclaimable bytes alone, for example image layers with no
unused tag). The message falls back to today's generic `pruneSpec(tab).message`, so
the dialog never claims "0 items" and then removes something.

### Wiring

- `PodmanView.askPrune` passes the tab, its unfiltered list, and
  `{usage, showStopped, filter}`.
- **Stale data:** the message describes the last refresh (at most 3 s old while the
  surface is open). The prune itself is Podman's own, so it takes what Podman
  considers unused at that moment, which is the same stale-row behaviour as today.
  The message says "Remove", not "These will be removed", and no wording claims
  more.
- The dialog is the host's `ConfirmDialog` and already wraps its message. Three
  names plus "and N more" keeps the message to about four lines in the popup (the
  510 px view).

## Alternatives rejected

- **Every name in a scrolling list** (open question 1b): rejected at approval. It
  needs a custom dialog in place of the host's, and a long list is read less
  carefully than three names and a count.
- **The count only** (1c): rejected at approval. Names are what would have stopped
  the #10 incident.
- **Pruning only the filtered rows** (2b): rejected at approval. It needs per-item
  `rm`, which the intent's constraints rule out.
- **`paused` as prunable,** that is, "not up": it lists containers Podman keeps. See
  the table.
- **Asking Podman at prune time** (a `podman ps --filter status=exited` inside the
  question): a process launch per keypress, and the dialog would open late for a
  number the panel already has.

## Risks

- **`PRUNABLE_STATES` could miss a state Podman prunes, or include one it keeps.**
  `configured` and `stopped` are rare, and are taken from Podman's container states.
  The live check covers `exited`, `created` and `paused` with demo containers, and a
  Node test pins the list.
- **The count from `podman system df` may include containers other tools hide.** It
  is Podman's own count, so it is what the prune takes. It is only used while stopped
  containers are hidden.
- **A longer message in the menu at 1.45×:** check live that the dialog still fits
  on a 1080p screen.
- **Live testing near a prune is how #10 lost data.** The verification below confirms
  a prune only where every listed item is `demo-*`, and otherwise only opens the
  dialog, reads it and cancels.

## Verification

- Node tests, failing before the change:
  - `pruneTargets` per tab, including a `paused` container that is not taken and a
    `created` one that is;
  - `pruneMessage` for 0 (the fallback), 1 and 5 targets;
  - the hidden-stopped branch with a known and an unknown count;
  - the filter note;
  - the volume warning still present.
- `nix flake check` and `nix build`, and `omarchy plugin validate` on a fresh clone.
- Live, on razer, with `docs/capture.sh --setup` plus a `demo-paused` container
  (`podman pause`):
  - on each tab, `p` opens a dialog naming exactly the `demo-*` targets shown under
    Unused or stopped. Screenshot it, read it, then **Cancel**;
  - one confirmed prune, on Networks with only `demo-net2` unused, checking with
    `podman network ls` that only that network went;
  - "Show stopped" off: the dialog gives the count and says the containers are
    hidden. Read it and Cancel;
  - a filter typed, then the filter note appears.
- Docs: `docs/usage.md` ("Reclaim space on this tab": "It asks first, naming what
  will go") and the README's prune sentence. `confirm-prune.png` is retaken in #11.
