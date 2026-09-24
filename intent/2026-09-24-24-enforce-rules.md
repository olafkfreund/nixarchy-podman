---
status: draft
issue: 24
author: olafkfreund
---

# Intent: The rules are written down but not enforced

## Problem

AGENTS.md opens its Rules section with "Each rule records a real failure or a
hard constraint", and `nix flake check` is advertised as the thing that holds
them: "tests + manifest, entry points, no symlinks, no pacman/yay, no hex
colours". Four of those five checks cannot do what the rule says, because
every one of them runs against the *packaged output* — the nine files
`flake.nix` copies — rather than against the repository.

**The no-symlink check is structurally unable to fail.** `flake.nix:73-75`
runs `find ${plugin} -mindepth 1 -type l`. The check is written correctly and
walks what it is pointed at, but `runCommand` builds that output by copying
each file, so the output can never contain a symlink no matter what the
repository holds. The rule it is supposed to enforce is about the repository,
and it matters because `omarchy plugin add` clones this repo *as* the plugin
folder and `omarchy-plugin-validate` refuses any symlink inside one. AGENTS.md
even explains the consequence — it is why `CLAUDE.md` imports `AGENTS.md`
rather than linking to it — and then checks the one place the problem cannot
appear.

**There is no `.gitignore`.** Verified: `result` is ignored only by the
owner's machine-local `~/.config/git/ignore`. The repository's own no-symlink
rule currently depends on one developer's personal configuration. On any
other clone, a `result` link from `nix build` is simply untracked and
visible, and the first person to `git add -A` commits a symlink into a
repository whose central rule forbids them.

**Two greps are scoped to a fraction of what their rules claim.** The
hardcoded-colour check (`flake.nix:68`) scans `*.qml` and never `Model.js` —
the one file AGENTS.md says carries all the logic. It also matches only
quoted hex, so `"transparent"` passes; that appears at `Menu.qml:102` and
`ResourceList.qml:252`, and whether it counts as a hardcoded colour is a
judgement the project has not made. The `pacman|yay` check (`flake.nix:66`)
scans `*.qml` and `*.js` in the output, so it cannot see AGENTS.md, README.md,
`docs/` or manifest.json's own strings — where the rule says "not even in
comments", and where prose is exactly where such a word would appear.

**The rule that has already bitten us is not checked at all.** Nothing greps
for `set -o pipefail` or the `|| exit 1` guard. That rule exists because a
failing `podman` once looked like an empty list, and #21 shows it is subtly
broken again today. It is the rule most worth a check and the only one
without one.

**The manifest check never asserts `keepLoaded: true`**, though AGENTS.md
treats keep-loading as load-bearing for how `open()` must reset state.

**CI has loose edges.** `ci.yml` has no `permissions:` block on the check job,
where `pages.yml` correctly scopes its own, and both pin actions to floating
major tags rather than SHAs. Low risk today — no step uses the token — but
it is free to fix.

What works and should be left alone: the `files` list in `flake.nix` matches
the runtime files exactly; aarch64 evaluates green in about a second; the
`flake.lock` pin is current; and `ci.yml` does correctly enforce the
`docs/img` budget, which stands at 5,761,828 bytes, 69% of 8 MB.

## Proposed outcome

- A symlink committed to the repository fails a check, on any clone, without
  depending on a developer's personal git config.
- The `pacman`/`yay` and colour rules are checked everywhere they claim to
  apply, or their wording in AGENTS.md is narrowed to what is actually
  checked. One of the two, not neither.
- The `pipefail` / `|| exit 1` rule is enforced mechanically, so #21 cannot
  silently recur.
- Every rule in AGENTS.md is either enforced by a check or explicitly marked
  as convention that reviewers uphold. No rule sits in between, appearing
  enforced while it is not.
- CI grants itself only the permissions it uses.

## Affected users and systems

- `flake.nix` (`checks.default`), `.github/workflows/ci.yml`, a new
  `.gitignore`, and AGENTS.md if any rule is reworded.
- Every future contributor and every agent working in this repository, who
  currently get a green check that means less than they think.
- Anyone installing via `omarchy plugin add`, which is where a committed
  symlink would actually break.

## Constraints

- Checks must run against the repository source, not only the built output,
  while continuing to validate the built output where that is the right
  target.
- `nix flake check` must stay fast — it is currently about a second for
  `--all-systems --no-build`, and a check nobody waits for is a check nobody
  runs.
- No new dependency for something `grep` and `find` already do.
- A check that cannot fail is worse than no check, because it is trusted.
  Every check added or changed here must be demonstrated failing against a
  deliberately broken tree before it is believed.
- `.gitignore` must not exclude anything the plugin needs; the `files` list
  in `flake.nix` is the authority on what ships.

## Open questions

1. **Is `"transparent"` a hardcoded colour?** It is not a theme token and
   survives a theme switch, but it is also not a colour in the sense the rule
   means. Decide, then make the check and the two call sites agree.
2. **How should the `pipefail` rule be checked** without becoming brittle? A
   grep for `sh", "-c"` requiring `set -o pipefail` in the same string is
   cheap and catches the real case; it will also produce false positives on
   any unpiped `sh -c`. Note that #21 may change what the correct pattern
   even is, so this check may need to wait on that decision.
3. **Should the repo-wide greps cover `docs/` and the artifacts?** Widening
   `pacman|yay` to the whole tree will hit AGENTS.md's own explanatory line
   about the rule. Either the check needs an exclusion or the rule needs to
   admit that naming the forbidden thing in order to forbid it is allowed.
4. **Do the CI hardening items belong here at all,** or are they a separate
   small PR? They are unrelated to the AGENTS.md rules and only grouped
   because they surfaced in the same review.
