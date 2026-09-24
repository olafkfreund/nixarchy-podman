---
status: draft
issue: 21
author: olafkfreund
---

# Intent: PodmanState's failure paths do the wrong thing quietly

## Problem

`PodmanState.qml` owns every `Process` that runs `podman`. Its happy paths
are sound. Its failure paths are where the defects are, and the worst of them
is a rule turning on itself.

**`set -o pipefail` plus `head` reports failure on success.** AGENTS.md
requires every piped `sh -c` to start with `set -o pipefail`, and it is there
in all seven commands — the rule was followed. But each command also ends in
`head -c 1M` (or `head -c 64k` for `system df`). When the producer writes
more than the limit, `head` exits, the producer takes SIGPIPE, and `pipefail`
faithfully reports the pipeline as failed. Verified:
`sh -c 'set -o pipefail; yes | head -c 100'` exits 141. Every reader is
`if (code === 0)`, so past the limit the output is discarded and the list
reads as empty.

That is precisely the failure the rule exists to prevent — "without them, a
failing `podman` looks like an empty list" — arriving by the mechanism meant
to prevent it. It needs a lot of containers to trigger, which is exactly why
it will surface on someone else's machine and not on ours. Affects
`PodmanState.qml:256, 289, 301, 317, 332, 346, 359`.

**A badge that can never light.** `networksProcess` (`:332`) asks Podman for
`ID`, `Name`, `Driver`, `Internal` and `Labels`. `Model.js:570,573` read
`Scope` and `IPv6`, which were never requested, so `scope` is permanently
`""` and `ipv6` permanently `false`. The `ipv6` badge at `Model.js:934` is
unreachable code that looks live.

**The wrong row says it is busy.** `runAction` (`:184`) sets `root.pendingId`
to the new target before `runCommand` (`:175`) checks
`actionProcess.running`. The row buttons gate on `!root.busy`, but
`PodmanView.qml:229-231`'s `o`, `s` and `r` do not. So pressing `r` on a
second row while the first is still restarting moves the busy marker to a row
whose command never runs, and the user watches the wrong thing spin. No wrong
command executes; it self-corrects when the first finishes.

**One bad tick blanks everything.** `listProcess.onExited` (`:265-277`)
clears containers, images, volumes, networks, volumeSizes, usage and stats
when `podman ps` fails. The other four processes poll independently on their
own timers and may still be succeeding. This may well be deliberate — it also
sets `daemonReachable = false`, and if the daemon is gone then everything
really is unknown — so it is raised as a question.

**`podman stats` runs when nothing shows it.** `statsProcess` polls every 5s
whenever the surface is active, regardless of `root.tab`, so it samples every
running container while the user reads the Images tab. `refreshStats` already
guards on `!active` and `showStats`; it does not guard on the tab. The
settings text tells users this costs "about a second of work each time the
panel is open" and offers turning it off — we should not be spending it when
it cannot be seen.

## Proposed outcome

- A truncated list is distinguishable from a failed one. Exceeding a `head`
  limit shows data, not emptiness.
- The `pipefail` rule in AGENTS.md says something that is actually safe to
  follow, and the rule and the `head` guard do not cancel each other out.
- Either the `ipv6` badge renders, or it and `scope` go.
- The busy marker is on the row that is busy.
- `podman stats` runs when its output is on screen.
- Whatever `podman ps` failing should do to the other four tabs is decided
  and written down.

## Affected users and systems

- `PodmanState.qml`, and `PodmanView.qml:229-231` for the keyboard guard.
- `Model.js:570,573,934` if the ipv6 badge goes.
- Anyone with enough containers, images or volumes to exceed a `head` limit —
  by definition the users with the most to manage.
- Laptop users, for the stats polling.

## Constraints

- The `head` guards exist for a reason and must not simply be deleted: they
  bound what a runaway `podman` can push into the shell.
- Any replacement must still satisfy AGENTS.md's pipefail rule, or the rule
  must be amended in the same PR to say what is actually correct. It must not
  be quietly ignored.
- Run external commands by name from `PATH`; never wrap or bundle (AGENTS.md).
- `PodmanState` must not poll while its surface is closed — the bar's slow
  glyph poll stays the only exception.
- Logic goes in `Model.js` with a Node test. Exit-code handling that can be
  expressed as a pure function should be.

## Open questions

1. **How should truncation be handled?** Accepting exit 141 alongside 0 is
   the one-line fix but silently accepts other SIGPIPE deaths. Dropping
   `pipefail` from the piped commands contradicts AGENTS.md. Raising the
   limits only moves the cliff. Reading the stream without `head` and
   bounding it in QML is the largest change and the most correct. Pick one.
2. **Does AGENTS.md's pipefail rule need rewording?** It is stated absolutely
   and, combined with `head`, is unsafe as stated. If the fix changes the
   pattern, the rule should change with it.
3. **Keep the ipv6 badge or drop it?** Adding `Scope` and `IPv6` to the format
   string makes it work; deleting three lines makes it honest. The badge has
   never rendered, so nobody is relying on it.
4. **Should a failed `podman ps` blank the other tabs?** Current behaviour
   assumes the daemon is gone. Confirm, or scope the clearing to containers.
