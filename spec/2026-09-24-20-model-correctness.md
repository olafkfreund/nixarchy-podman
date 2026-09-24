---
status: draft
issue: 20
intent: intent/2026-09-24-20-model-correctness.md
---

# Spec: Three wrong answers in Model.js

## Design

### 1. `canPrune` reuses `pruneTargets`, and stops trusting df about containers

The intent asked whether `canPrune` should simply call `pruneTargets`. It
should, with one qualification the intent could not see.

Reading both functions together shows they were never really two ideas. For
images, volumes and networks, `pruneTargets` takes `item.inUse === false`
where `canPrune` takes `!item.inUse`. Those agree for every value `inUse`
actually holds — `Model.js:462`, `:501` and `:577` all assign a boolean — so
on those three tabs the two are already the same test written twice. The
divergence appears only where `inUse` is absent, which is containers, which
is the bug.

The qualification: **the `podman system df` short-circuit must not apply to
containers.** `USAGE_TYPE` (`Model.js:626-631`) maps `containers` to df's
`Containers` row, so today `canPrune` returns true whenever df reports
reclaimable bytes on that tab — and #14 recorded, from the razer incident,
that df's arithmetic counts paused containers as reclaimable when
`container prune` leaves them alone. Keeping that short-circuit would leave a
second, subtler version of the same lie: the button live because df
over-counts, with `pruneMessage` then naming nothing.

So df stays the fast path for the tabs where it is honest, and the list is
the only authority for containers:

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

Fifteen lines become six, the `networks` special case disappears (`usageFor`
already returns `null` for networks, since `USAGE_TYPE` has no entry), and the
function's existing comment — "never live on a tab that is already clean" —
becomes true.

**This is checked against the five assertions already in
`tests/model/resources.test.js:391-402`, and all five still hold:**
`("images", clean, [{inUse:true}])` false; `("images", clean, [{inUse:false}])`
true before df catches up; `("images", dirty, [])` true; `("networks", {},
[{inUse:true}])` false and `[{inUse:false}]` true; `("volumes", {}, [])`
false.

### 2. `compareContainers` drops the `!a.up` guard

```js
function compareContainers(a, b) {
  if (a.up !== b.up) return a.up ? -1 : 1
  if (a.failing !== b.failing) return a.failing ? -1 : 1
  return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
}
```

One deletion. Running still sorts above stopped; within each of those, a
failing container now sorts above a healthy one, where before only stopped
failures floated.

The intent asked whether the sections already carry the signal. They do not.
`compareContainers` is called exactly once (`Model.js:758`), sorting
*within* a Compose project section — there is no "needs attention" section to
float into. An unhealthy running container is marked red by `row.alerting`,
so it is visible once found; in a project with twenty running containers it
is still twenty rows to scan. The header says "1 needs attention", and the
list should put it where attention goes.

Cursor stability is not a concern: #13 made the cursor follow its row by key
rather than index, so a re-sort cannot move it onto a different container.

### 3. `shortImage` handles a digest before it looks for a tag

The bug is that `lastIndexOf(":")` finds the colon inside `@sha256:…`. The fix
is to deal with `@` first, and only then treat a colon as a tag delimiter:

```js
  // A digest pins the image; the colon inside it is not a tag delimiter.
  var at = value.indexOf("@")
  if (at > 0) return value.substring(0, at) + "@" + shortId(value.substring(at + 1))
```

placed after the registry-stripping and before the tag-stripping.

`shortId` (`Model.js:181-184`) strips a `sha256:` prefix and truncates to 12,
so `alpine@sha256:e7d88de73db3c0f…` renders as `alpine@e7d88de73db3`.

That is deliberately *not* the same shape as the existing bare-digest case,
which keeps its prefix (`shortImage("sha256:f6d0…")` is `"sha256:f6d088e608ca"`,
asserted at `tests/model/parsing.test.js:104`). A bare digest needs the
prefix because without it the string is an unlabelled hex blob; a digest
attached to a repository does not, because `alpine@` already says what
follows. Reusing `shortId` keeps the 12-character convention in one place.

### Scope

All three are `Model.js` plus tests. No QML, no new file, so `flake.nix`'s
`files` list is untouched.

## Alternatives rejected

**`canPrune` calls `pruneTargets` with no exception, df short-circuit and
all.** Rejected: it keeps df authoritative for containers, where #14 proved it
over-counts. The bug would survive in a quieter form.

**Fix `canPrune` by giving containers an `inUse` field in
`normalizeContainer`.** Rejected: it would make `canPrune`'s loose `!inUse`
work by adding a field with no other reader, inventing a second notion of
"in use" for containers — where "prunable" already means a specific set of
states. More code to produce two definitions instead of one.

**Leave `compareContainers` alone and treat it as intended.** A real option,
and the intent listed it. Rejected because nothing in the code says it was
intended — no comment, no test, and every other failure path in this plugin
surfaces failures first. If the approver disagrees, the fallback is not to
leave it silent: add a test asserting the current order and a comment saying
why, so the next reviewer does not reopen this.

**Render a digest-pinned image as just `alpine`.** Rejected: it discards the
pin, so two containers on different digests of the same repository would
render identically — the duplicate-row confusion #6 was filed about.

**Render it as `alpine@sha256:e7d88de73db3`.** Rejected only on width: 26
characters in a column beside the name. The prefix carries no information once
`@` has already said a digest follows.

## Risks

- **`canPrune`'s behaviour changes on the Containers tab**, which is the
  point, but it also means the Prune button will now be dark in situations
  where users have seen it lit. That is the fix, not a regression, and the
  button being dark on a clean tab is what its comment always promised.
- **The sort change moves rows.** Someone used to finding a container at a
  known position in a long project section will find it moved once it goes
  unhealthy. That is the intent.
- **`shortImage` is on the sanitize path** (`tests/model/sanitize.test.js:49`
  covers `shortImage` among the fields checked for hostile input). The new
  branch returns a substring of already-sanitized input and introduces no new
  source, but the sanitize test must be re-run rather than assumed.
- **No host, NixOS or packaging risk.** No capture is affected: no shipped
  image shows a digest-pinned container or a prune button on a clean
  Containers tab.

## Verification

1. `node tests/run.js` green, with new cases:
   - `canPrune("containers", …)` false when every container is running;
     false when df reports reclaimable but no container is in a prunable
     state; true when one is `exited`. **This is the assertion whose absence
     hid the bug**, and it must fail against the current code.
   - `canPrune` agrees with `pruneTargets(...).length > 0` on every tab for a
     fixture with a mix of used and unused items.
   - the five existing assertions at `resources.test.js:391-402` unchanged
     and passing.
   - `compareContainers`: two running containers, one failing, failing first;
     running-healthy still above stopped-failing.
   - `shortImage("alpine@sha256:e7d88de73db3c0f1")` is `"alpine@e7d88de73db3"`;
     `("ghcr.io/acme/api@sha256:abc123def456789")` is `"acme/api@abc123def456"`;
     the seven existing assertions at `parsing.test.js:98-105` unchanged.
2. `nix flake check` green.
3. Live on the desktop: open the Containers tab with everything running and
   confirm the Prune button is dark; stop one container and confirm it lights;
   confirm `p` on the dark button does nothing. Run a digest-pinned container
   and read its subtitle. Make a container unhealthy with
   `docs/capture.sh --unhealthy` and confirm it sorts to the top of its
   project while still running.
