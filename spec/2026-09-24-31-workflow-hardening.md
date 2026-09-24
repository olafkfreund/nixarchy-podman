---
status: draft
issue: 31
intent: intent/2026-09-24-31-workflow-hardening.md
---

# Spec: CI grants itself more than it uses, and trusts moving tags

## Design

The intent asked three questions and explicitly declined to accept the
checklist answer. This spec takes a position on each, with the reason, so the
approver is rejecting an argument rather than a default.

### 1. `permissions:` on `ci.yml` — do it

The clearest of the three and the one that does most of the work.

```yaml
permissions:
  contents: read
```

`ci.yml`'s steps are `nix flake check`, `nix build`, a `find` and a `du`.
None reads the token; `actions/checkout` needs `contents: read` and nothing
else. `pages.yml` already scopes itself and stays exactly as it is.

This matters more than it first appears, and it changes the weight of §2: a
job holding only `contents: read` is a much smaller prize than one holding the
repository default, so locking the permission down removes most of what a
compromised action could do with it.

### 2. SHA pins — do it, on both workflows

The intent was right to question this rather than accept it, and right that
the cost is real: a pinned action stops receiving fixes until someone repins
it, and there is no Dependabot here to do it.

It is still worth doing, for a reason specific to this repository rather than
from a checklist. There are **three** action references in total —
`actions/checkout` twice and `cachix/install-nix-action` once, plus whatever
`pages.yml` uses. Repinning three references a couple of times a year is not a
maintenance burden that needs automation to be tolerable. The usual argument
against pinning assumes dozens of actions across many workflows; it does not
apply at this size.

`pages.yml` is pinned too, and arguably first: it holds `pages: write` and
`id-token: write`, so a moved tag there can publish, where in `ci.yml` — once
§1 lands — it can only read.

Each pin carries the tag in a trailing comment, or the next reader cannot tell
what they are looking at and will never update it:

```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
```

**The honest caveat, which the approver should weigh:** pinned actions go
stale silently. If the answer is "we will not remember to repin", floating
tags from two well-known publishers is a defensible position and this section
should be dropped rather than done badly. Half-done pinning — pinned and then
forgotten for two years — is worse than not pinning, because it looks
deliberate.

### 3. A scheduled `flake.lock` bump — do not

Rejected. The usual shape is a weekly job opening a pull request, which means
a pull request most weeks that nobody asked for, on a repository whose lock
is currently fresh because a human bumped it when it mattered.

The failure this would prevent — silent drift between bumps — is not a failure
this repository has had. `nix flake check --all-systems --no-build` runs on
every pull request and takes about a second, so a lock that has drifted into
breakage is caught the next time anyone touches anything.

If drift does start to bite, the evidence will be a build that broke because
the lock was old, and *that* is when to add the job. Adding it now is
automation ahead of a problem.

### Scope

Two workflow files. No runtime change, no package change, no documentation
change beyond the pins' own comments.

## Alternatives rejected

**Add `permissions: {}` and grant per-step.** Over-precise for a job whose
only need is `contents: read`, and it breaks `actions/checkout` in a way the
next reader has to diagnose.

**Pin `ci.yml` but not `pages.yml`.** Backwards: `pages.yml` is the one
holding write scopes.

**Use `@v5.0.0` exact tags instead of SHAs.** A tag remains mutable however
specific it looks. If tags are acceptable, floating majors are honest about
being tags; exact tags only look like pins.

**Add Dependabot to keep the pins fresh.** A third thing to configure and a
stream of pull requests, to maintain three references. If the maintenance
burden is the concern, the answer is to skip §2, not to automate around it.

## Risks

- **Pinned actions go stale**, as above. This is the main reason to reject §2
  rather than a reason to do it carelessly.
- **A wrong SHA fails at checkout with an unhelpful message.** Each pin must
  be resolved from the upstream tag at the time of writing, not typed from
  memory, and CI must be seen green before merge.
- **`permissions: contents: read` could break a future step** that needs more
  — a step that comments on a pull request, say. It will fail loudly and
  obviously, and the fix is to grant exactly what that step needs.
- **No runtime risk.** Nothing here touches the plugin, the package, the
  tests or the docs. If CI is green, this is done.

## Verification

1. CI green on the pull request that makes the change — which is the whole
   verification, since the change is to CI.
2. `gh run view` on that run shows the job's permissions as `contents: read`
   and nothing else.
3. Each pinned SHA resolves to the tag its comment claims, checked with
   `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` at the time of pinning and
   recorded in the pull request body.
4. `nix flake check`, `nix flake check --all-systems --no-build` and
   `nix build` all still run and pass in the workflow — the change must not
   quietly drop a step.
5. `docs/img` budget step still runs and still reports its size.
