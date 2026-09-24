---
status: approved
issue: 24
intent: intent/2026-09-24-24-enforce-rules.md
---

# Spec: The rules are not actually enforced

## Design

The intent's constraint — *"a check that cannot fail is worse than no check"* —
was applied to the spec itself. Every claim below was tested before it was
written.

### Two facts that decide the shape

**Nix preserves symlinks in an imported source path.** Tested with a throwaway
flake containing `src/link.txt -> real.txt`: the check printed
`lrwxrwxrwx … link.txt -> real.txt` and found it with `find -type l`. So a
flake check *can* enforce the no-symlink rule — it simply has to look at the
source instead of the package. The intent's claim that the check is
"structurally unable to fail" was right about `${plugin}` and wrong about the
limits of Nix.

**A flake's source view already excludes gitignored files.** Reading the
flake's `outPath` on this repository lists every tracked file and **not**
`result`, which exists in the working tree and is ignored by the owner's
global config. That is the correct semantics: the check sees what
`omarchy plugin add` clones.

It also lists `.git` and `.claude`, so a naive `find ${./.} -type l` would walk
the git directory. The checks are therefore scoped to named paths, never the
whole tree.

### 1. `.gitignore` is the primary fix, not the check

The no-symlink rule currently depends on one developer's
`~/.config/git/ignore`. A repository `.gitignore` containing `result` and
`result-*` is what actually prevents a build artefact being staged, on every
clone. The check is the backstop; this is the fix.

### 2. The symlink check moves to the source

```nix
if [ -n "$(find ${./.}/docs ${./.}/share ${./.}/tests -type l)" ] \
   || [ -n "$(find ${./.} -maxdepth 1 -type l)" ]; then
  echo "symlink in the repository; omarchy-plugin-validate refuses them" >&2
  exit 1
fi
```

The package check stays as well — it is cheap and asserts a different thing.

### 3. `pacman`/`yay`: code and configuration, not prose

Widening this grep to the source flags `AGENTS.md:109` (the rule stating
itself) and `README.md:182` (describing the check). The intent anticipated
this and asked for a decision. **Naming the forbidden thing in order to forbid
it is not a violation.** The rule means code.

So the grep covers `*.qml`, `Model.js`, `manifest.json`, `share/*.jsonc` and
`docs/capture.sh` — every file that becomes part of the plugin or runs — and
AGENTS.md's wording changes from "not even in comments" to **"not in code,
configuration or scripts — including comments"**, which is what it always
meant and is now checkable without an exclusion list.

### 4. Colours: add `Model.js`

`Model.js` is the one file AGENTS.md says carries all the logic, and the grep
never scanned it. Adding it passes today (verified: no literals anywhere), so
it is a live check against a future addition rather than a fix for a current
violation.

`"transparent"` at `Menu.qml:102` and `ResourceList.qml:252` stays allowed.
It is not a colour that a theme could supply differently — it is the absence
of one — and forbidding it would mean inventing a token for "no fill".
The intent asked; this is the answer.

### 5. The `pipefail` rule, checked by its two greppable invariants

Shell lives inside concatenated QML strings, so no grep can parse a pipeline
out of it. Two invariants can be asserted exactly, and both encode real
bugs rather than style:

```nix
pf=$(grep -c 'set -o pipefail' ${./PodmanState.qml})
hd=$(grep -c 'head -c' ${./PodmanState.qml})
test "$pf" -eq "$hd" || { echo "a head-bounded pipeline without pipefail, or the reverse" >&2; exit 1; }

grep -q 'code === 0' ${./PodmanState.qml} \
  && { echo "use Model.commandSucceeded, not code === 0 -- a truncating head exits 141 (#21)" >&2; exit 1; }
true
```

Measured on current `master`: `set -o pipefail` 8, `head -c` 8, `sh -c` 10 —
the two extra `sh -c` are `viewLogs` and `openShell`, which have no pipe and
correctly no `pipefail`. `code === 0` is 0.

The second grep is the one that matters: it guards the #21 regression
directly, and #21's amendment to AGENTS.md already tells readers to use
`Model.commandSucceeded`.

### 6. The manifest check asserts `keepLoaded`

One clause added to the existing `jq -e`. AGENTS.md treats keep-loading as
load-bearing for how `open()` must reset state; nothing checked it.

### 7. CI hardening is split out

The intent asked whether the `permissions:` block and SHA pins belong here.
**They do not.** They are unrelated to the AGENTS.md rules and were grouped
only because they surfaced in the same review. Mixing a supply-chain change
into a rules-enforcement PR makes both harder to review and to revert. A
separate issue, referenced from this one.

## Alternatives rejected

**Scan the whole tree with `find ${./.} -type l`.** Rejected: the source view
includes `.git`, so it would walk the object store on every check.

**Exclude the rule's own lines from the `pacman` grep.** Rejected as fragile —
an exclusion list that must be updated whenever prose moves. Narrowing the
rule to what it always meant is the honest fix.

**Parse the `sh -c` strings to check `pipefail` properly.** Rejected: the
strings are QML concatenations across lines, and a checker that must
understand them would be more likely to be wrong than the thing it checks.

**Forbid `"transparent"`.** Rejected above.

**Drop the package-level checks now that the source is scanned.** Rejected:
they assert that what actually ships is clean, which is a different claim.

## Risks

- **A source-scoped check makes `nix flake check` depend on more of the tree**,
  so it re-runs after a docs edit. Acceptable: the check takes about a second.
- **The `pipefail` count invariant is a proxy.** It cannot tell a pipeline
  with `pipefail` in the wrong place from one with it in the right place. It
  catches the case that actually happens — a new query added without it — and
  the spec claims nothing more.
- **`.gitignore` could hide a file someone meant to commit.** Scoped to
  `result` and `result-*` only; `flake.nix`'s `files` list remains the
  authority on what ships.
- **Widening `pacman|yay` could still false-positive** on a future doc that
  quotes the rule inside `docs/capture.sh`. Unlikely, and the failure is loud.

## Verification

Each check must be demonstrated failing before it is believed. In a scratch
copy of the tree, not the working one:

1. `ln -s Model.js decoy.qml` at the repo root, `git add -f` it → the symlink
   check fails. Remove it → passes.
2. Add `# pacman -S foo` to `docs/capture.sh` → the grep fails. Remove →
   passes. Confirm `AGENTS.md:109` and `README.md:182` do **not** trip it.
3. Add `color: "#ff0000"` to `Model.js` → the colour check fails.
4. Delete one `set -o pipefail` from `PodmanState.qml` → the count invariant
   fails. Restore, then change one `Model.commandSucceeded(code)` back to
   `code === 0` → the second grep fails.
5. Set `keepLoaded: false` in `manifest.json` → the manifest check fails.
6. With nothing broken: `nix flake check` green, `node tests/run.js` green,
   and `nix flake check --all-systems --no-build` still evaluates in about a
   second.
