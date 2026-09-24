---
status: draft
issue: 21
intent: intent/2026-09-24-21-state-robustness.md
---

# Spec: PodmanState's failure paths

## Design

### 1. Truncation is success. `141` says so.

The intent listed four candidate fixes and said pick one. The choice was
settled by measurement rather than argument. On this machine:

| case | exit |
| --- | --- |
| `printf abc \| head -c 100`, under the limit | `0` |
| `head -c 200000 /dev/urandom \| head -c 1000`, over it | `141` |
| `podman bogus-subcommand \| head -c 1M`, genuinely failing | `125` |
| the same with `set -o pipefail` removed | `0` |

Two things follow, and together they pick the fix.

**A failing `podman` never produces 141.** It exits with its own code — 125
for an unknown subcommand — because `pipefail` reports the rightmost non-zero
status, and a producer that fails on its own terms fails before it is ever
signalled. The only way to reach 141 is `head` closing the pipe after it has
taken everything it asked for. So `141` does not mean "something went wrong";
it means "we got the megabyte we requested and stopped reading".

**The rule is load-bearing exactly as written.** The last row is the failure
AGENTS.md records: with `pipefail` removed, a failing `podman` exits 0 and the
list reads as empty. So `set -o pipefail` stays.

The fix is therefore to widen what counts as success, in one tested place:

```js
// head -c closes the pipe once it has what we asked for, and pipefail then
// reports the producer's SIGPIPE death as 141. That means truncated, not
// failed: a podman that genuinely fails exits with its own code (125 for an
// unknown subcommand), never 141. Measured, not assumed -- see #21.
function commandSucceeded(code) {
  return code === 0 || code === 141
}
```

Every `onExited` in `PodmanState.qml` — seven of them — becomes
`if (Model.commandSucceeded(code))`. Logic in `Model.js` with a Node test,
per AGENTS.md.

Truncated data is safe to parse. `parseJsonLines` wraps `JSON.parse` in
`try`/`catch` and drops what it cannot read, so a half-written final line
disappears — verified: two lines where the second is cut mid-object yields
exactly one record. `parseVolumeSizeTable` drops any row with fewer than
three columns, so a cut row goes the same way.

**How close is the cliff, honestly?** On this machine `podman images` is
10,849 bytes for nine images, about 1.2 KB each, so the 1 MB limit is roughly
830 images. `podman system df` is 432 bytes against a 64 KB limit. This is a
latent bug, not an imminent one — it will surface on a build host with
hundreds of images, not here. That is an argument about priority, not about
whether to fix it: it is three lines and a test, and the failure mode is a
silently empty list.

### 2. AGENTS.md gains one sentence

The rule is correct and stays. It is incomplete, and the incompleteness is
what bit us. Under the existing bullet:

> **Every piped `sh -c` starts with `set -o pipefail`, and the first command
> inside a `{ …; }` group ends with `|| exit 1`.** Without them, a failing
> `podman` looks like an empty list. **A pipeline that ends in `head` must
> then accept exit 141 as success: `head` closes the pipe once it has its
> limit, and `pipefail` reports the producer's SIGPIPE death. A `podman` that
> genuinely fails exits with its own code, never 141.**

This is a documentation change to the file that governs every agent working
here, so it is called out rather than folded quietly into a code commit.

### 3. `ipv6` is made to work; `scope` is deleted

The intent offered "add the fields, or delete the badge". Measurement splits
the two:

- `podman network ls --format '{{json .Scope}}'` errors: *can't evaluate field
  Scope in type network.ListPrintReports*. There is no `Scope` anywhere in the
  full JSON dump either — its keys are `created`, `dns_enabled`, `driver`,
  `id`, `internal`, `ipam_options`, `ipv6_enabled`, `name`,
  `network_interface`, `subnets`. **`scope` is not obtainable**, so
  `Model.js:570`'s `scope` field and every reader of it go.
- `.IPv6` errors the same way, which is why the badge never lit — but
  `.IPv6Enabled` works and returns `false`. **The badge is fixable**, by
  asking for the right name.

So `networksProcess` (`PodmanState.qml:332`) gains `"IPv6":{{json .IPv6Enabled}}`
to its format string, `Model.js:573` keeps reading `raw.IPv6`, and the badge
at `:934` lights for an IPv6-enabled network. `Model.js:570`'s `scope` line is
removed along with anything that reads it.

### 4. `pendingId` moves after the guard

`runAction` (`PodmanState.qml:182-186`) sets `root.pendingId` before
`runCommand` checks `actionProcess.running`, so a dropped action still moves
the busy marker. Two changes, both small:

```js
function runAction(ids, verb) {
  if (!ids || ids.length === 0 || actionProcess.running) return
  root.pendingId = ids.length === 1 ? ids[0] : ""
  runCommand(["podman", verb].concat(ids))
}
```

The `actionProcess.running` check moves into `runAction` itself, before the
assignment. `runCommand` keeps its own guard — it is called directly from
`confirmAccepted` too.

And the keyboard stops silently dropping actions. `PodmanView.qml:229-231`
gates on `root.podman.busy`, as the row buttons already do:

```js
if (root.podman.busy) return
```

placed with the other early returns in `handleTextKey`, before the
container-verb block. A key that would start a second action now does nothing
visible rather than moving the marker — the same as pressing a greyed button.

### 5. `statsProcess` gates on the tab

`refreshStats` (`PodmanState.qml:98-102`) already refuses when the surface is
closed, when stats are off and when nothing is running. It gains the tab:

```js
if (!showStats || statsProcess.running || !active) return
if (tab !== "containers") return
if (counts.running === 0) return
```

`podman stats` samples every running container and the settings text tells
users it costs "about a second of work each time the panel is open". Spending
that while the Images tab is open buys nothing. The 5s timer stays as it is;
the guard is enough.

### 6. A failed `podman ps` stops blanking the other tabs

`listProcess.onExited` (`PodmanState.qml:265-277`) clears containers, images,
volumes, networks, volumeSizes, usage and stats. The intent asked whether that
is deliberate. It reads as deliberate — it also sets `daemonReachable = false`,
and if the daemon is gone then everything is stale — but it is wrong in the
case that actually happens: `podman ps` failing on one tick while the other
four processes, on their own independent timers, are still succeeding. The
whole UI flashes empty and refills a second later.

The narrow fix keeps the daemon signal and stops the collateral:

```js
root.daemonReachable = false
root.permissionDenied = /permission denied/i.test(message)
root.containers = []
root.stats = ({})
return
```

`containers` and `stats` are what `listProcess` owns — `stats` because
`refreshStats` is driven from the container list and a stat with no container
is an orphan. Images, volumes, networks, volumeSizes and usage keep whatever
their own processes last successfully read, and each will clear itself on its
own next failure. `daemonReachable` still drives the error line, so the user
is still told the daemon is unreachable.

## Alternatives rejected

**Drop `set -o pipefail` from the piped commands.** Rejected, and the
measurement is the reason: without it a failing `podman` exits 0 and the list
silently empties. That is the recorded failure the rule exists to prevent.

**Raise the `head` limits.** Rejected: it moves the cliff without removing it,
and the limits exist to bound what a runaway `podman` can push into the shell.

**Drop `head` and bound the output in QML.** Rejected as the largest change
for the same result. `StdioCollector` would hold the whole stream in memory
first, which is what the bound exists to prevent.

**Accept any non-zero exit when there is parseable output.** Rejected: it
would swallow the 125 case, which is exactly the failure that must stay
visible.

**Add `scope` by calling `podman network inspect` per network.** Rejected: one
process per network on every poll, for a field nothing displays.

**Leave `listProcess` blanking everything.** Rejected above, but if the
approver prefers it, the fallback is a comment saying the blanking is
deliberate and why — not silence.

## Risks

- **Accepting 141 could mask a producer killed by SIGPIPE for another
  reason.** In these seven pipelines `head` is the only consumer, so there is
  no other source of SIGPIPE. If a future command gains a second consumer this
  reasoning must be revisited; the comment on `commandSucceeded` says so.
- **Truncated data will now be displayed rather than discarded.** That is the
  intent — a partial list beats an empty one — but the user is not told the
  list is partial. No indicator is proposed here; if one is wanted it is a
  separate issue, because it needs a design.
- **`IPv6Enabled` is a podman template name and could change between
  versions.** If it does, the template errors and the whole `networksProcess`
  query fails rather than degrading — which, with `pipefail`, now correctly
  shows as a failure. Worth confirming against the minimum podman version the
  README claims.
- **Gating stats on the tab means switching to Containers shows stale numbers
  until the next tick.** `setTab` should trigger `refreshStats()` so the wait
  is not up to five seconds.
- **No packaging or host risk.** `Model.js` gains one function; no new file.

## Verification

1. `node tests/run.js` green, with new cases:
   - `commandSucceeded(0)` and `(141)` true; `(1)`, `(125)`, `(126)`, `(137)`
     false.
   - `normalizeNetwork` sets `ipv6` from `IPv6` and no longer carries `scope`.
   - `parseJsonLines` on input cut mid-object yields the whole records and
     drops the fragment (asserting the truncation safety this design rests on).
2. `nix flake check` green.
3. A shell check that the measurement still holds on the target host:
   `sh -c 'set -o pipefail; head -c 200000 /dev/urandom | head -c 1000 >/dev/null'; echo $?`
   must print 141, and
   `sh -c 'set -o pipefail; podman bogus 2>/dev/null | head -c 1M >/dev/null'; echo $?`
   must print a podman code, not 141.
4. Live on the desktop:
   - Stop the podman socket or rename the binary so `podman ps` fails; confirm
     the Containers tab empties and says so, while Images still lists what it
     last read.
   - Create an IPv6 network (`podman network create --ipv6 demo-v6`) and
     confirm the badge appears; remove it afterwards.
   - Hold `r` on a container and confirm no other row shows busy.
   - Open the Images tab and confirm `podman stats` stops being called
     (`qs log -i <instance>`, or watch with `podman events`).
