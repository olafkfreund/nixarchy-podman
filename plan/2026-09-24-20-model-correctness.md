---
status: approved
issue: 20
spec: spec/2026-09-24-20-model-correctness.md
---

# Plan: Three wrong answers in Model.js

## The approved decisions, carried over

Implementable without opening the intent or the spec.

**1. `canPrune` reuses `pruneTargets`, and stops trusting df about
containers.** The two functions were one idea written twice: `pruneTargets`
tests `inUse === false`, `canPrune` tests `!inUse`, and since `Model.js:462`,
`:501` and `:577` all assign booleans those agree everywhere `inUse` exists.
It is absent only on containers, which is the bug. The `podman system df`
short-circuit must not apply to containers, because #14 recorded that df
counts paused containers as reclaimable where `container prune` leaves them
alone — so df stays the fast path for the disk-backed tabs, and the list is
the only authority for containers. The `networks` special case is deleted:
`usageFor` already returns `null` for networks, since `USAGE_TYPE` has no
entry for them.

**2. `compareContainers` drops the `!a.up` guard,** so a failing container
sorts above a healthy one whether it is running or stopped. It is called once
(`Model.js:758`), sorting within a Compose project section; there is no
"needs attention" section for a failure to float into. #13 made the cursor
follow its row by key, so a re-sort cannot move the cursor onto a different
container.

**3. `shortImage` handles `@` before it looks for a tag colon,** reusing
`shortId` so the 12-character convention lives in one place. A digest
attached to a repository drops the `sha256:` prefix (`alpine@e7d88de73db3`)
because the `@` already says what follows; a bare digest keeps it, as
`parsing.test.js:104` asserts.

Scope is `Model.js` and its tests. No QML, no new file, so `flake.nix`'s
`files` list is untouched.

## Steps

One commit per step, each citing the step number and `#20`.

1. **`tests/model/resources.test.js`: add the containers cases first, and
   watch them fail.** The spec requires the assertion whose absence hid the
   bug to fail against unfixed code — a test written after the fix proves
   only that the code does what it does.

   ```js
   test("prune is dark on a containers tab with nothing stopped", () => {
     const running = [make("web", "", "running"), make("db", "", "running")]
     eq(Model.canPrune("containers", {}, running), false)

     // df counts a paused container as reclaimable; container prune does
     // not take it (#14), so the list is the only authority here.
     const dirty = Model.indexUsage([
       { Type: "Containers", Size: "1GB", Reclaimable: "500MB (50%)" }
     ])
     eq(Model.canPrune("containers", dirty, running), false)
     eq(Model.canPrune("containers", dirty, [make("held", "", "paused")]), false)

     eq(Model.canPrune("containers", {}, [make("old", "", "exited")]), true)
   })

   test("canPrune and the question that names what goes never disagree", () => {
     const mixed = [make("web", "", "running"), make("old", "", "exited")]
     eq(Model.canPrune("containers", {}, mixed),
        Model.pruneTargets("containers", mixed).length > 0)
   })
   ```

   → verify by `node tests/run.js` **failing**, on the first three
   assertions of the first test. Record the failure text in the step-1 commit
   message. If it passes, stop: the diagnosis is wrong.

2. **`Model.js`: replace `canPrune`.** Lines 1135-1150 (the comment and the
   function) become:

   ```js
   // One definition of "prunable", shared with the question that names what
   // goes: pruneTargets. df is a fast path for the disk-backed tabs only --
   // on containers it counts paused ones as reclaimable where prune leaves
   // them alone (#14), so that tab trusts the list and nothing else.
   function canPrune(tabKey, usage, items) {
     if (tabKey !== "containers") {
       var entry = usageFor(usage, tabKey)
       if (entry && entry.reclaimableBytes > 0) return true
     }
     return pruneTargets(tabKey, items || []).length > 0
   }
   ```

   → verify by `node tests/run.js` green, step 1's tests now passing **and**
   the five pre-existing assertions at `resources.test.js:391-402` still
   passing untouched.

3. **`Model.js`: drop the `!a.up` guard in `compareContainers`** (line 723).
   `if (!a.up && a.failing !== b.failing)` becomes
   `if (a.failing !== b.failing)`.

   → verify by step 4's tests.

4. **`tests/model/grouping.test.js`: the sort cases.** A running unhealthy
   container sorts above a running healthy one within its project; a running
   healthy container still sorts above a stopped failing one, so the `up`
   comparison keeps precedence over the failing one.

   `make(name, project, state, extra)` takes an `extra` object merged into
   the raw container, so an unhealthy container is
   `make("api", "shop", "running", { Status: "Up 2 hours (unhealthy)" })` —
   confirm against `normalizeContainer` that this is what sets `failing`
   before relying on it.

   → verify by `node tests/run.js` green.

5. **`Model.js`: `shortImage` handles the digest.** Insert after the
   registry-stripping block and before the `lastIndexOf(":")` line:

   ```js
     // A digest pins the image; the colon inside it is not a tag delimiter.
     var at = value.indexOf("@")
     if (at > 0) return value.substring(0, at) + "@" + shortId(value.substring(at + 1))
   ```

   → verify by step 6's tests.

6. **`tests/model/parsing.test.js`: the digest cases**, added to the existing
   `shortImage` test at line 98 so the assertions stay together:

   ```js
   eq(Model.shortImage("alpine@sha256:e7d88de73db3c0f1"), "alpine@e7d88de73db3")
   eq(Model.shortImage("ghcr.io/acme/api@sha256:abc123def4567890"), "acme/api@abc123def456")
   ```

   The seven assertions already at `parsing.test.js:98-105` must be unchanged
   and still passing — particularly `:104`'s bare-digest case, which keeps its
   `sha256:` prefix.

   → verify by `node tests/run.js` green.

## Tests

```bash
node tests/run.js    # expect green; 164 + 4 new test() blocks = 168
nix flake check      # expect: all checks passed
```

Live, on the nixarchy desktop (AGENTS.md "Verifying live"):

1. Containers tab with everything running → the Prune button is dark, and `p`
   does nothing.
2. Stop one container → the button lights; `p` asks, naming that container.
3. `docs/capture.sh --unhealthy` → `demo-unhealthy` sorts to the top of its
   project while still running.
4. Run a digest-pinned container
   (`podman run -d --name demo-digest docker.io/library/alpine@sha256:<digest> sleep infinity`)
   and read its subtitle: `alpine@` plus twelve hex characters.
5. Diff `podman ps -a`, `images`, `volume ls`, `network ls` against a snapshot
   taken first; only `demo-*` may differ.

No capture is affected: no shipped image in `docs/img/` shows a digest-pinned
container, an unhealthy running container inside a project, or a prune button
on a clean Containers tab. Confirm by eye before concluding no retake.

## Rollback

Three independent one-function changes on a branch, no state and no
migration. `git revert` any step alone — step 2 restores the old `canPrune`
verbatim, step 3 restores one word, step 5 removes two lines. Reverting a fix
without its test leaves a failing suite, which is the correct signal; revert
the pair.
