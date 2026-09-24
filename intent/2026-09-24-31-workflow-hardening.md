---
status: draft
issue: 31
author: olafkfreund
---

# Intent: CI grants itself more than it uses, and trusts moving tags

## Problem

Split out of #24, which was about enforcing the AGENTS.md rules. These three
surfaced in the same review and are unrelated to those rules; keeping them
there would have made both halves harder to review and to revert.

**`ci.yml` has no `permissions:` block.** Its `check` job therefore runs with
whatever the repository default grants, which is broader than it needs —
every step is `nix flake check`, `nix build`, a `find` and a `du`, and none
of them uses the token. `pages.yml` in the same repository gets this right,
scoping itself to `contents: read`, `pages: write`, `id-token: write`. The
risk today is small precisely because nothing uses the token; the point is
that nothing should be able to start.

**Both workflows pin actions to floating major tags** — `actions/checkout@v5`
and `cachix/install-nix-action@v31`. A major tag is mutable: whoever controls
it can move it to a different commit, and CI would run that commit against
this repository on the next push without anything in the repository changing.
This is the standard supply-chain concern for GitHub Actions, and the standard
answer is a commit SHA with the tag in a trailing comment.

**There is no automated `flake.lock` update.** The current pin is fresh
(nixos-unstable, 2026-09-18) but only because someone bumped it by hand. A
repository that ships a plugin people install from source will drift quietly
between bumps.

None of this is urgent, and none of it has caused a failure. It is recorded
because it is cheap to fix and because a green check that grants more than it
needs is a habit rather than a decision.

## Proposed outcome

- `ci.yml` grants its job only what its steps use, as `pages.yml` already
  does.
- Both workflows run the action code that was reviewed, not whatever a tag
  points at today, while staying legible about which version that is.
- Whether `flake.lock` is bumped on a schedule is decided deliberately rather
  than left to memory.

## Affected users and systems

- `.github/workflows/ci.yml` and `.github/workflows/pages.yml`.
- Anyone opening a pull request, who sees the result.
- No runtime change: nothing in the plugin, the package or the docs moves.

## Constraints

- CI must keep doing exactly what it does now. This is about what it is
  *allowed* to do and which code it runs, not about what it checks.
- It must stay fast — the check currently completes in about 20 seconds, and
  a check people wait for is a check people skip.
- Pinned SHAs must carry the human-readable tag in a comment, or the next
  reader cannot tell what version they are looking at and will not update it.
- `pages.yml`'s existing permissions are correct and must not be widened to
  match a template.

## Open questions

1. **Are SHA pins wanted at all here?** They are the standard advice, and they
   cost a small ongoing maintenance burden: a pinned action does not receive
   fixes until someone repins it, and without Dependabot or an equivalent that
   is another thing to remember. A repository this size may reasonably prefer
   floating tags from two well-known publishers. The approver should decide
   rather than accept the default answer.
2. **Should `flake.lock` be bumped on a schedule?** A weekly job opening a
   pull request is the usual shape. It also means a pull request most weeks
   that nobody asked for. The alternative is to leave it manual and accept the
   drift.
3. **Does `pages.yml` need the SHA treatment too**, or only `ci.yml`? Pages
   already holds `pages: write` and `id-token: write`, so it is the workflow
   where a moved tag would matter more — which argues for doing both, or for
   doing pages first.
