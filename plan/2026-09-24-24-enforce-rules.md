---
status: approved
issue: 24
spec: spec/2026-09-24-24-enforce-rules.md
---

# Plan: The rules are not actually enforced

## The approved decisions, carried over

**Nix preserves symlinks in an imported source path** — demonstrated with a
throwaway flake containing `src/link.txt -> real.txt`, which the check saw and
`find -type l` found. So the rule is enforceable; the check just has to look
at the source, not `${plugin}`.

**A flake's source view excludes gitignored files** — reading this repo's
`outPath` lists every tracked file and not `result`. That is the right
semantics: the check sees what `omarchy plugin add` clones. It does include
`.git`, so checks are scoped to named paths, never the whole tree.

**`.gitignore` is the primary fix**, not the check. The rule currently depends
on one developer's `~/.config/git/ignore`.

**`"transparent"` stays allowed** — it is the absence of a colour, not one a
theme could supply differently.

**`pacman`/`yay` means code, not prose.** Widening to the source flags
`AGENTS.md:109` and `README.md:182`, the rule stating itself. The grep covers
code and configuration; the rule's wording narrows to match.

**`pipefail` is checked by two greppable invariants**, not by parsing shell
out of concatenated QML strings: `set -o pipefail` count equals `head -c`
count (8 and 8 today; the two extra `sh -c` are `viewLogs` and `openShell`,
correctly unpiped), and `code === 0` stays at zero.

**CI hardening is out of scope** and gets its own issue.

## Steps

One commit per step, citing the step number and `#24`.

1. **`.gitignore`**, containing `result` and `result-*` and nothing else.
   `flake.nix`'s `files` list stays the authority on what ships.
   → verify by `git check-ignore -v result` naming the repo file rather than
   `~/.config/git/ignore`.

2. **`flake.nix`: the source-scoped checks.** Add, keeping every existing
   package check:

   ```bash
   # omarchy plugin add clones this repo AS the plugin folder, and
   # omarchy-plugin-validate refuses a symlink inside one. The package cannot
   # contain one -- runCommand copies -- so the source is what must be checked.
   if [ -n "$(find ${./docs} ${./share} ${./tests} -type l)" ] \
      || [ -n "$(find ${./.} -maxdepth 1 -type l)" ]; then
     echo "symlink in the repository" >&2; exit 1
   fi

   # In code, configuration and scripts -- comments included. Naming the rule
   # in AGENTS.md or the README is not a violation.
   if grep -nwE 'pacman|yay' ${./Model.js} ${./manifest.json} \
        ${./docs}/capture.sh ${./share}/*.jsonc ${plugin}/*.qml; then
     echo "Arch package manager reference above" >&2; exit 1
   fi

   # Model.js is the one file AGENTS.md says carries all the logic, and the
   # colour grep never scanned it.
   if grep -nE '"#[0-9a-fA-F]{3,8}"' ${plugin}/*.qml ${./Model.js}; then
     echo "hardcoded colour above; use a Color.* token" >&2; exit 1
   fi

   # The pipefail rule, by its two greppable invariants (#21).
   pf=$(grep -c 'set -o pipefail' ${./PodmanState.qml})
   hd=$(grep -c 'head -c' ${./PodmanState.qml})
   test "$pf" -eq "$hd" || {
     echo "a head-bounded pipeline without pipefail, or the reverse" >&2; exit 1; }
   if grep -n 'code === 0' ${./PodmanState.qml}; then
     echo "use Model.commandSucceeded: a truncating head exits 141 (#21)" >&2; exit 1
   fi
   ```

   And one clause on the existing `jq -e`: `and .keepLoaded == true`.

   **Deviation, found by step 4f.** Breaking `keepLoaded` did fail the check,
   but with no message at all — `jq -e` exits non-zero silently, so the reader
   saw only `170 passed, 0 failed` and a store path. Pre-existing, and made
   more likely to fire by the new clause. The `jq` gains an `|| { echo …;
   exit 1; }` naming what is wrong, so a manifest failure is legible.

   → verify by `nix flake check` green, then by step 4's breakages.

3. **`AGENTS.md`: narrow the `pacman` rule to what it means** and record what
   the checks now cover:

   - the rule becomes "**No `pacman` or `yay` in code, configuration or
     scripts — comments included.**"
   - the `nix flake check` line in Commands gains the new assertions.

   → verify by reading both back.

4. **Prove every check fails.** In a scratch clone under the scratchpad
   directory, never the working tree — a staged symlink or a stray hex literal
   left behind would be worse than the bug. For each: break, run
   `nix flake check`, confirm it fails with the intended message, restore,
   confirm green.

   a. `ln -s Model.js decoy.qml` at the root, `git add -f` → symlink check.
   b. `# pacman -S foo` in `docs/capture.sh` → grep. Confirm `AGENTS.md` and
      `README.md` do **not** trip it.
   c. `color: "#ff0000"` in `Model.js` → colour grep.
   d. remove one `set -o pipefail` → count invariant.
   e. one `Model.commandSucceeded(code)` back to `code === 0` → second grep.
   f. `keepLoaded: false` → manifest check.

   → verify by six failures and six recoveries, recorded in the commit.

5. **Open the CI issue** for the `permissions:` block and SHA pins, referenced
   from #24 and not implemented here.
   → verify by the issue URL.

## Tests

```bash
node tests/run.js                          # expect green, 170
nix flake check                            # expect: all checks passed
nix flake check --all-systems --no-build   # expect green, about a second
```

No live desktop verification: this issue changes no runtime behaviour. No
capture is affected.

## Rollback

`.gitignore` is additive. The flake checks revert as a block; reverting them
restores today's weaker checks rather than breaking anything. The AGENTS.md
wording reverts alone, though leaving it while reverting step 2 would document
checks that no longer exist — revert the pair.
