---
status: approved
issue: 10
intent: intent/2026-09-21-10-live-test-bugs.md
---

# Spec: Fix the bugs found in the live test pass

Seven fixes, plus two one-liners the intent approval pulled in. Each fix is
independent and lands as its own plan step and commit. Bugs are numbered as in
the intent.

## Design

### 1. Volume prune drops `-a`

`Model.js` `PRUNE.volumes.args` becomes `["podman", "volume", "prune", "-f"]`.

In Podman, `volume prune` already removes every volume no container uses, named
or anonymous. `-a` exists only in Docker, where it widens a prune that otherwise
takes only anonymous volumes. Nothing else about the command changes: the message
and label stay the same, and it keeps its `-f`, which stops Podman's own prompt.

A new test pins every tab's prune arguments against the flags Podman 5 accepts:

- containers: `container prune -f`
- images: `image prune -a -f`
- volumes: `volume prune -f`
- networks: `network prune -f`

A future stray flag then fails in Node, not on someone's desktop. The same commit
fixes the stale comment above `PRUNE`: it says "without -f", but what it means is
no `--force` on `rm`/`rmi`.

### 2. Labels are read in both shapes

This goes in one place, the shared helper both label readers call.

A new `labelMap(labels)` in `Model.js` returns a plain `{key: value}` object:

- A non-null object that isn't an array (`podman ps` and `podman volume ls` in
  Podman 5) is copied key by key, with values through `String`.
- Anything else is treated as the existing `k=v,k=v` text (network labels, older
  Podman, Docker). A part with no `=` is a key with an empty value, which
  `hasLabel` relies on for `com.docker.volume.anonymous`.

`labelValue(labels, key)` returns `trim(labelMap(labels)[key] || "")`.
`hasLabel(labels, key)` returns `key in labelMap(labels)`. Their callers
(`composeProject`, `normalizeContainer`, `normalizeVolume`, `normalizeNetwork`)
don't change.

Tests feed `normalizeContainers` a line in the shape razer's `podman ps` produced,
and expect `project: "demo-shop"` and `sectionsFor` titled `demo-shop`. They also
check the text form still parses, and that an object-shaped volume label marks a
volume anonymous.

`labelMap` guards with `typeof labels === "object"` and `length === undefined`,
not `Array.isArray`. These values come through `parseJsonLines`, as plain JS, but
the `AGENTS.md` sequence-wrapper rule is cheap to respect.

### 3. The menu's list gets the height that is left

Today, `Menu.qml` caps the card at 85% of the screen and clips the rest. The view
inside is laid out at its natural height, and the list's cap
(`ResourceList.maxHeight = Style.space(560)`) doesn't know about the menu.

The fix is to let the view say how tall the list may be:

- `PodmanView.qml` gains `property int listMaxHeight: Style.space(560)`, bound to
  `ResourceList.maxHeight`. It also gains a read-only
  `chromeHeight: column.implicitHeight - list.height`: everything but the list.
- `Menu.qml` binds
  `view.listMaxHeight: Math.max(Style.space(120), Math.min(Style.space(560), Math.floor((panel.height * 0.85 - card.contentTopInset - card.contentBottomInset) / root.uiScale) - view.chromeHeight))`.
  The card then fits within 85% without clipping, and the list scrolls. The
  `Style.space(120)` floor keeps a couple of rows on absurdly short screens,
  where clipping is back, but only there.
- The bar popup doesn't set it, so the popup keeps today's 560.

A binding loop is possible in principle: `chromeHeight` reads `list.height`,
which follows `listMaxHeight`. It settles, because `chromeHeight`'s value doesn't
change when the list height does. The plan checks the log for
`Binding loop detected`. If one appears, the fallback is to compute the chrome
height from the non-list children explicitly.

This is layout wiring, not logic, so it has no Node test. It is verified live.

### 4. Stopped on purpose is not a failure

`isFailing` treats exit codes 137 (SIGKILL after the stop timeout) and 143
(SIGTERM) like 0. A new `var STOP_EXIT_CODES = [137, 143]` sits beside
`UP_STATES`. A comment says so, and names the cost the approver accepted: an
OOM-killed container now looks like a clean stop.

The status text still says `Exited (137)`, so the code stays visible. Only the
red goes.

`containerRow.unhealthy` becomes `container.up && container.health === "unhealthy"`.
A stopped container's last health result is history, and the header already
stops counting it. This is the second minor item the approval took in.

Tests: 137 and 143 are not failing, 1 and 139 still are, and a stopped container
that was unhealthy has `unhealthy: false`.

### 5. The first `j` lands on the top row

A new `nextCursor(active, index, delta, count)` in `Model.js` returns `{index}`.

When the cursor is hidden (`!active`), the first move only reveals it: at
`clampCursor(index, count)` for `j`/`↓`, and the same for `k`/`↑`. Once it is
visible, it moves by `delta` as today.

`PodmanView.moveCursor` calls it in place of
`clampCursor(cursorIndex + delta, …)`. It keeps its two filter hand-offs (up from
the first row, and an empty list) exactly as they are.

Tests: hidden cursor with `j` → index 0; visible with `j` → +1; hidden with `k`
→ index 0.

`↓` out of the filter already calls `moveCursor(0)` and lands on row 0, so it is
unchanged.

### 6. Menu settings: diagnose, then fix or document

The host refreshes each plugin's scoped shell API when `shell.json` changes
(`syncPluginApis`, called from `onShellConfigChanged`). The menu still read stale
values on razer until the shell restarted.

The leading theory: `createScopedPluginShell` revokes and rebuilds the cached API
when a plugin's capability profile changes. The keep-loaded menu keeps the
**revoked** object, whose `barConfig` nobody updates any more.

This is settled by evidence, not by guessing:

- The first plan step for this bug adds a temporary `console.info` in
  `Menu.open()`, logging a hash of `shell.barConfig` and whether `shell` is the
  same object as on the previous open. It runs live on razer with an
  `omarchy bar set` in between.
- The instrumentation is removed before the fix is committed. It is never
  committed.

Then, per the approved decision:

- **If the stale value is the host's** (revoked or stale API): change
  `docs/usage.md`'s "no restart" sentence to say the menu picks settings up after
  `omarchy-restart-shell`, while the popup applies them at once. Then file an
  upstream omarchy report with the evidence. No plugin workaround.
- **If the plugin is holding the value itself** (for example a copy taken in
  `readSettings`): fix it in `Menu.qml`, and keep the docs sentence.

### 7. List sync: reproduce with the full log, then fix at the cause

In Node, `reconcilePlan` produces the right list: a 20,000-case fuzz, duplicate
keys included, always ends at exactly the target keys. So the fault is in how
`ResourceList.sync()` applies the plan in QML.

The candidates are:

- (a) re-entrancy: a model operation triggers bindings that change `rows` and
  call `sync()` again mid-loop;
- (b) Qt refusing an operation, with a `ListModel` warning. The earlier log search
  filtered on "podman" and would have hidden such a warning.

The plan's first step for this bug reproduces it live (tab switches, filtering,
refreshes) and captures the **unfiltered** log around the TypeError. The fix
follows the evidence:

- **If it is (a):** `sync()` gets a `syncing` guard. A nested call sets `resync`
  and returns, and the outer call loops until `resync` is clear. That is five
  lines, all in `ResourceList.qml`.
- **If it is (b):** fix the operation Qt refuses, at its source. If that is in
  `Model.js`, it gets a Node test.

Either way, the loop that updates each row's fields gets a
`if (!current) break` guard only if the evidence shows an unavoidable transient.
It is not added pre-emptively.

## Alternatives rejected

- **Bug 1, keeping `-a` on Podman versions that support it.** No supported Podman
  has it on `volume prune`, and the version sniffing isn't worth it.
- **Bug 2, switching the Go template to `{{range}}` text.** It would work, but
  `{{json .Labels}}` is already the more robust transport, and the reader should
  simply accept what Podman sends. It would also still need the text path for
  networks.
- **Bug 3, a scrolling card instead of a scrolling list.** It would scroll the
  tabs and filter away from the rows, and break keeping the cursor visible.
- **Bug 3, lowering `maxHeight` for everyone.** The popup has room it would lose,
  and higher-resolution screens would still clip in theory.
- **Bug 4, `podman inspect` for `OOMKilled`.** Rejected at intent approval: an
  extra call per stopped container on every poll.
- **Bug 6, the menu reading `shell.json` itself.** Rejected at intent approval: it
  duplicates host config handling.
- **Bug 7, self-healing by rebuilding the model when counts differ.** It hides the
  cause, and drops hover state on every rebuild. Only if the evidence leaves no
  other fix.

## Risks

- **Bug 2 shows section headers on the Containers tab** where there were none. The
  captures that show that tab become wrong: `popup-containers.png`, `menu.png`,
  and any recordings that show Containers (`rec-menu`, `rec-popup`, `demo.gif`).
  Retaking them must keep `docs/img/` under 8 MB. Measure it before and after.
- **Bug 3's binding loop.** It is detected in the log, and has a fallback (see
  above).
- **Bug 4 hides a real SIGKILL/OOM failure** behind a dim row. It was accepted at
  approval, and the status text keeps the exit code.
- **Bug 6 may end as a docs change plus an upstream report,** not a code fix.
- **Bug 7 may not reproduce quickly.** The plan time-boxes the reproduction. If
  it doesn't reproduce, the step records what was tried and the bug stays open on
  the issue, rather than shipping a speculative guard.
- **Live testing can destroy data.** The rules from the intent apply to every
  live step: `demo-*` objects only; screenshot every dialog before confirming;
  no prune on Containers or Images while the owner has stopped containers or
  unused images; restore `shell.json`.

## Verification

- `node tests/run.js`: the new tests fail on `master`'s `Model.js` and pass after.
  Check that by running them against `git stash`'d code once.
- `nix flake check`, `nix flake check --all-systems --no-build` and `nix build`
  pass, and `omarchy plugin validate` passes on a fresh clone (`AGENTS.md`).
- Live on razer, with the build copied into place, a shell restart and
  `docs/capture.sh --setup`:
  - (1) Prune on Volumes removes only `demo-empty`, with the other unused volumes
    checked first, and shows no error.
  - (2) The Containers tab shows a `demo-shop` header with its three containers,
    and `demo-unhealthy` below it.
  - (3) With 9 or more rows on Volumes and on Images, the menu footer is fully
    visible and the list scrolls. No `Binding loop` in the log.
  - (4) After stop-all, the demo rows are dim, not red. The "Exited (137)" text
    remains. `demo-shop-migrate`'s exit 1 stays red.
  - (5) Fresh open, `j`, Enter acts on the first row. Verify with `podman events`.
  - (6) The diagnosis output is recorded in the plan's deviation note, and the
    docs or code are changed as decided.
  - (7) After a scripted session of tab switches, filter typing and refreshes,
    `qs log` holds no `ResourceList.qml` errors and no `ListModel` warnings.
- `docs/usage.md` and the README are updated where behaviour or wording changed.
  The captures are retaken per `AGENTS.md`, and `docs/img/` is under 8 MB.
