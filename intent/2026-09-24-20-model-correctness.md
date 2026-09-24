---
status: draft
issue: 20
author: olafkfreund
---

# Intent: Three wrong answers in Model.js

## Problem

`Model.js` carries all the logic and is the one file with real test coverage
(157 tests, all passing). Three of its answers are wrong anyway, and all
three are wrong in the same way: a check that looks right reads a field that
is not there, or reads the right field at the wrong moment.

**The Prune button lies on the Containers tab.** `canPrune`
(`Model.js:1146-1149`) falls back to `!list[j].inUse`. Images, volumes and
networks all carry `inUse`; containers never do — `normalizeContainer` does
not set it. `!undefined` is true, so `PodmanState.qml:75` reports `prunable`
as soon as a single container exists, whatever its state and whatever
`podman system df` says. The function's own comment claims the opposite:
"True only when Podman has told us there is something to reclaim, so the
button is never live on a tab that is already clean." It is also inconsistent
with `pruneTargets`, which gets it right by reading container state through
`PRUNABLE_STATES`. The tests cover images, volumes and networks and never
pass `"containers"`, which is exactly why this survived.

**Digest-pinned images render as nonsense.** `shortImage`
(`Model.js:398-399`) strips the tag with `lastIndexOf(":")`. Given
`alpine@sha256:e7d88de73db3…` the last colon is the one inside the digest, so
the user sees `alpine@sha256`. Anyone pinning images by digest — the thing
you are told to do for reproducibility, and the thing a Nix-shaped person is
most likely to do — sees a column of identical `something@sha256` rows.

**An unhealthy container hides in the alphabet.** `compareContainers`
(`Model.js:723`) guards the failing comparison with `!a.up`, so the sort only
floats failures among *stopped* containers. A running container whose health
check reports unhealthy sorts by name like any other. The header meanwhile
says it needs attention, so the plugin tells the user something is wrong and
then makes them hunt for it. This one may be deliberate — the sections may
already carry the signal — so it is listed as a question, not a defect.

## Proposed outcome

- The Prune button on Containers is live when there is something to prune and
  dark when there is not, matching what `canPrune`'s comment already promises
  and what `pruneTargets` already computes.
- `canPrune` and `pruneTargets` agree on what "prunable" means for a
  container. One definition, in one place.
- A digest-pinned image reads as the image, not as `@sha256`.
- Whatever is decided about unhealthy running containers is decided
  deliberately and recorded, rather than left as an accident of an `!a.up`.
- Each of the three has a Node test that fails without the fix.

## Affected users and systems

- `Model.js`, and `tests/model/` alongside it.
- `PodmanState.qml:75`, the only reader of `canPrune`.
- Anyone on the Containers tab, which is where the plugin opens by default.
- Anyone pinning images by digest.

## Constraints

- Logic stays in `Model.js` with a Node test (AGENTS.md). No QML changes
  unless the fix genuinely needs one.
- `node tests/run.js` must stay green, and each fix must arrive with a test
  that fails before it.
- No new dependency and no new abstraction: these are three small corrections,
  and the file is already lean. Prefer fixing `canPrune` by reusing
  `pruneTargets` over adding a fourth notion of prunability.
- `nix flake check` must pass, which runs the same tests.

## Open questions

1. **Should `canPrune` simply call `pruneTargets`?** That would give one
   definition instead of two and is the smallest honest fix, but it changes
   behaviour on the other three tabs from "is anything unused" to "is
   anything prunable", which may not be identical. Confirm that is wanted.
2. **Should a running-but-unhealthy container sort above healthy ones?** If
   the answer is no, `Model.js:723` is correct as written and only its
   absence of a test is a problem. Decide the behaviour, not just the code.
3. **What should a digest-pinned reference render as?** `alpine` loses the
   pin entirely; `alpine@sha256:e7d88de7` keeps a recognisable prefix at the
   cost of a longer column. There is a `shortId` helper already.
