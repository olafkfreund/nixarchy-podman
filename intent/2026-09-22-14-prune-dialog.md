---
status: approved
issue: 14
author: olafkfreund
---

# Intent: A prune says what it will remove

## Problem

Every tab's Prune asks a one-line question that names a kind of thing, not the
things themselves:

- Containers: "Remove every stopped container?"
- Images: "Remove every image that no container is using?"
- Volumes: "Remove every volume that no container is using? Whatever is stored in
  them goes with them."
- Networks: "Remove every network that no container is using?"

In the #10 live test on razer, one keypress (`p`, on a tab reached by a wrapping
`l`/`→`) plus one confirm ran `podman container prune -f`. It removed five of the
owner's stopped containers, including two toolbox containers they still used. The
dialog was accurate, but it gave no hint that it covered anything beyond the test
objects in view. Nothing on screen named them.

The same shape applies on every tab. After those containers went, their base
images and six anonymous volumes became "unused", so a
prune on Images or Volumes would have taken them too, again without naming them.

The panel already knows the answer. The Containers tab lists the stopped
containers, and the other tabs split their items into **Unused** and **In use**
using Podman's own verdict.

## Proposed outcome

- Before anything is removed, the prune question states how many things will go and
  names them, or enough of them to recognise, on all four tabs.
- The names come from the same data the tab shows, so the dialog cannot disagree
  with the list above it.
- Cancel stays the default answer.
- If what is on screen is stale, the prune still takes only what Podman considers
  unused. The dialog must not claim more certainty than the refresh it was built
  from.

## Affected users and systems

- `Model.js` (`pruneSpec` and the messages) with Node tests, `PodmanView.qml`
  (`askPrune`), and possibly the dialog's layout for a longer message.
- `docs/usage.md` ("Reclaim space on this tab") and the README.
- Capture: `confirm-prune.png` changes. The retake is tracked in #11.
- Everyone who prunes, on either surface.

## Constraints

- Logic in `Model.js`, with Node tests (`AGENTS.md`).
- No change to the prune commands themselves. They stay exactly as #10 pinned them
  (`container prune -f`, `image prune -a -f`, `volume prune -f`,
  `network prune -f`), and nothing moves to per-item `rm`.
- Names are sanitised, like every other string the panel draws from Podman output.
- The popup is small (about 510 px wide), so a long list must stay readable there.
- Verify live with `demo-*` objects only. On this change in particular, the dialog
  is read and screenshotted before any confirm, and a confirm happens only where
  every listed item is `demo-*`.

## Open questions

1. **How much to list?** Pick one:
   - (a) the count plus the first few names, for example "5 containers: toolbox-a,
     toolbox-b, web and 2 more";
   - (b) every name, in a scrolling list inside the dialog;
   - (c) the count only.

   I recommend (a). It fits the popup, and the names are what would have stopped
   the #10 incident.
2. **Should a prune take a filter into account?** Today Prune ignores the filter box
   and takes everything unused. Pick one:
   - (a) keep that, and have the dialog say so when a filter is active;
   - (b) prune only what the filter shows. That would mean per-item removal, which
     the constraints above rule out.

   I recommend (a).
3. **Should the wrapping `l`/`→` from Networks to Containers change?** It set up the
   #10 incident. I recommend no: the listing fixes the danger at the point of
   decision, and the wrap is consistent everywhere.

## Decisions at approval

Approved without separate answers; the recommendations stand:
1. The dialog states the count and the first few names ("5 containers: a, b, c and 2 more").
2. Prune keeps taking everything unused; with a filter active, the dialog says so.
3. The wrapping `l`/`→` stays as it is.
