---
status: approved
issue: 21
spec: spec/2026-09-24-21-state-robustness.md
---

# Plan: PodmanState's failure paths

## The approved decisions, carried over

Implementable without opening the intent or the spec.

**1. Exit 141 means truncated, not failed.** Measured: output under a `head`
limit exits 0, over it 141, and a genuinely failing `podman` exits with its
own code (125 for an unknown subcommand) — never 141. With `set -o pipefail`
removed, a failing `podman` exits 0 and the list silently empties, which is
the recorded failure the rule prevents, so the rule stays. `Model.js` gains
`commandSucceeded(code)`, returning true for 0 and 141, and all seven
`onExited` handlers use it. Truncated data is safe to parse: `parseJsonLines`
drops a fragment mid-object, verified.

**2. AGENTS.md gains one sentence** on the existing pipefail bullet, saying a
pipeline ending in `head` must accept 141. Its own commit, because it changes
the rules every agent here follows.

**3. `ipv6` is fixed; `scope` is deleted.** Measured against real podman:
`.Scope` errors and appears nowhere in the JSON dump, so `scope` is not
obtainable. `.IPv6` errors too — which is why the badge never lit — but
`.IPv6Enabled` works. The amended `networksProcess` query was run end to end
and returned `"IPv6":false`, exit 0. `normalizeNetwork` needs no change:
`trim` stringifies booleans, so `trim(true) === "true"` already holds,
confirmed by running it.

**4. `pendingId` moves after the busy guard,** and `handleTextKey` gates on
`root.podman.busy` so a key cannot silently drop an action while the row
buttons are greyed.

**5. `refreshStats` gates on the tab**, and `setTab` triggers it so switching
to Containers does not wait up to five seconds for numbers.

**6. A failed `podman ps` clears only `containers` and `stats`**, not the
four lists owned by other processes. `daemonReachable` still drives the error
line.

## Steps

One commit per step, each citing the step number and `#21`.

1. **`Model.js`: add `commandSucceeded`**, beside the other parsing helpers,
   above `parseJsonLines`:

   ```js
   // head -c closes the pipe once it has what we asked for, and pipefail then
   // reports the producer's SIGPIPE death as 141. That means truncated, not
   // failed: a podman that genuinely fails exits with its own code (125 for
   // an unknown subcommand), never 141. Measured, not assumed (#21). This
   // holds only while head is the single consumer of each pipeline.
   function commandSucceeded(code) {
     return code === 0 || code === 141
   }
   ```

   Plus tests in `tests/model/parsing.test.js`: true for 0 and 141; false for
   1, 125, 126, 137. And an assertion that `parseJsonLines` drops a fragment
   cut mid-object while keeping the whole records before it — the property
   this whole design rests on.

   → verify by `node tests/run.js` green.

2. **`PodmanState.qml`: use it in all seven handlers.** Replace
   `if (code === 0)` with `if (Model.commandSucceeded(code))` in
   `statsProcess`, `imagesProcess`, `volumesProcess`, `networksProcess`,
   `usageProcess` and `volumeSizeProcess`, and change `listProcess`'s
   `if (code !== 0)` to `if (!Model.commandSucceeded(code))`.

   → verify by `grep -c "code === 0" PodmanState.qml` returning 0, and
   `grep -c "commandSucceeded" PodmanState.qml` returning 7.

3. **`AGENTS.md`: extend the pipefail rule.** Append to the existing bullet:

   > A pipeline that ends in `head` must then accept exit 141 as success:
   > `head` closes the pipe once it has its limit, and `pipefail` reports the
   > producer's SIGPIPE death. A `podman` that genuinely fails exits with its
   > own code, never 141.

   Its own commit, touching no code.

   → verify by reading it back.

4. **`PodmanState.qml`: ask for IPv6, and `Model.js`: drop `scope`.**
   In `networksProcess` (line ~332) add `"IPv6":{{json .IPv6Enabled}},` before
   `"Labels"`. In `Model.js`, delete the `scope:` line from `normalizeNetwork`
   (~line 570) and any reader of it.

   The exact amended command was run end to end before planning and returned
   `{"ID":"2f259bab93aa","Name":"podman",…,"IPv6":false,"Labels":""}` with
   exit 0.

   → verify by `grep -rn "scope" Model.js *.qml` finding no network `scope`,
   and by running the amended shell command directly.

5. **`PodmanView.qml`: the busy guard.**

   **Deviation: half of this step was based on a defect that does not exist.**
   The intent and spec both state that `runAction` sets `root.pendingId`
   before checking `actionProcess.running`, so a dropped action moves the busy
   marker to the wrong row. It does not. On untouched `master`, `runAction`
   reads:

   ```js
   function runAction(ids, verb) {
     if (!ids || ids.length === 0 || actionProcess.running) return
     root.pendingId = ids.length === 1 ? ids[0] : ""
     runCommand(["podman", verb].concat(ids))
   }
   ```

   The guard precedes the assignment, so a second action returns before
   `pendingId` is touched and no marker moves. The claim came from a review
   agent and was carried into the artifacts without that line ordering being
   checked. `PodmanState.qml` needs no change here.

   What is real is the missing feedback: `handleTextKey` does not gate on
   `root.podman.busy` where the row buttons do, so a second keypress is
   swallowed with no sign it happened. Add, before the container-verb block:

   ```js
   if (root.podman.busy) return
   ```

   placed after the `tab !== "containers" || !cursorItem` check, so `c` (copy)
   is unaffected — copying is not an action and has its own process.

   Place it after the `cursorActive`/`cursorRow` check so `c` (copy) is
   unaffected — copying is not an action and has its own process.

   → verify by reading the two functions back.

6. **`PodmanState.qml`: the stats tab gate and the failure narrowing.**
   `refreshStats` gains `if (tab !== "containers") return`. `setTab` calls
   `refreshStats()` so switching back does not wait for the timer.
   `listProcess.onExited`'s failure branch clears only `containers` and
   `stats`.

   → verify by reading them back, then the full suite and flake check.

## Tests

```bash
node tests/run.js    # expect green; 157 + 2 new test() blocks = 159
nix flake check      # expect: all checks passed
```

The measurement this rests on, re-run on the target host:

```bash
sh -c 'set -o pipefail; head -c 200000 /dev/urandom | head -c 1000 >/dev/null'; echo $?   # 141
sh -c 'set -o pipefail; podman bogus 2>/dev/null | head -c 1M >/dev/null'; echo $?        # 125, not 141
```

Live on the desktop:

1. Make `podman ps` fail (rename the binary on `PATH`, or stop the socket).
   The Containers tab empties and says the daemon is unreachable; Images still
   lists what it last read.
2. `podman network create --ipv6 --subnet fd00::/64 demo-v6` → the badge
   appears on that row. `podman network rm demo-v6` afterwards.
3. Hold `r` on a container: no other row shows busy.
4. Open the Images tab and confirm `podman stats` stops being called
   (`qs log -i <instance>`, or `podman events`). Switch back to Containers and
   confirm numbers appear at once rather than after five seconds.
5. Diff `podman ps -a`, `images`, `volume ls`, `network ls` against a snapshot;
   only `demo-*` may differ.

No capture is affected: no shipped image shows an IPv6 network or a failure
state. Confirm by eye before concluding no retake.

## Rollback

Six independent changes on a branch. Step 2 is mechanical and reverts with
step 1. Step 3 touches only AGENTS.md and can be reverted alone, though
leaving it while reverting step 1 would document a behaviour the code no
longer has — revert the pair. Steps 4, 5 and 6 are independent of each other
and of 1-3.
