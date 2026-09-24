---
status: approved
issue: 31
spec: spec/2026-09-24-31-workflow-hardening.md
---

# Plan: CI grants itself more than it uses, and trusts moving tags

## The approved decisions, carried over

**`permissions: contents: read` on `ci.yml`'s job.** Its steps are
`nix flake check`, `nix build`, a `find` and a `du`; none reads the token, and
`actions/checkout` needs nothing more. `pages.yml` already scopes itself
correctly and its permissions are not touched.

**SHA pins on both workflows**, each with the tag in a trailing comment.
`pages.yml` first in importance: it holds `pages: write` and
`id-token: write`, so a moved tag there can publish, where in `ci.yml` — once
the permission lands — it can only read.

**Deviation: the spec justified pinning by there being "three action
references in total".** There are **seven references across six unique
actions** — the spec hand-waved `pages.yml` rather than counting it. Six is
still not the "dozens across many workflows" that the usual argument against
pinning assumes, so the recommendation stands, but it stands on a number
twice the one given. Repinning six references occasionally is the burden being
accepted.

**No scheduled `flake.lock` bump.** Automation ahead of a problem this
repository has not had; `nix flake check --all-systems --no-build` already
catches a lock that drifted into breakage, in about a second.

**The caveat the approver accepted:** pinned actions go stale silently, and
half-done pinning — pinned then forgotten — is worse than not pinning, because
it looks deliberate.

## Steps

One commit per step, citing the step number and `#31`.

1. **`ci.yml`: the permission.** Add, above `jobs:`:

   ```yaml
   permissions:
     contents: read
   ```

   → verify by CI running green on the pull request, and by `gh run view`
   reporting the job's permissions.

2. **Pin every action to its SHA.** Resolved from upstream with
   `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha` at the time of
   writing, not typed from memory:

   | action | tag | sha |
   | --- | --- | --- |
   | `actions/checkout` | v5 | `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09` |
   | `cachix/install-nix-action` | v31 | `13d8dd58da0234aa297dedd986986ccb8e7f3e24` |
   | `actions/configure-pages` | v5 | `983d7736d9b0ae728b81ab479565c72886d7745b` |
   | `actions/jekyll-build-pages` | v1 | `44a6e6beabd48582f863aeeb6cb2151cc1716697` |
   | `actions/upload-pages-artifact` | v3 | `56afc609e74202658d3ffba0e8f6dda462b719fa` |
   | `actions/deploy-pages` | v4 | `d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e` |

   Each written as `uses: owner/repo@<sha> # <tag>`.

   → verify by re-resolving each tag after editing and diffing against what
   was written, then by CI green.

3. **`AGENTS.md`: record the convention**, under Known follow-ups or beside
   the other rules, so the next person to add an action pins it and the next
   person to see a stale pin knows it was deliberate:

   > Actions are pinned to a commit SHA with the tag in a comment. Repin by
   > hand when an action needs a newer version; there is no Dependabot.

   → verify by reading it back.

## Tests

The change is to CI, so CI is the test:

```bash
gh pr checks <n> --watch     # expect green
gh run view <id> --json jobs # expect contents: read and nothing else
```

Plus, before merge:

- every pinned SHA re-resolves to the tag its comment claims;
- the workflow still runs `nix flake check`, `nix flake check --all-systems
  --no-build`, `nix build`, the symlink test and the `docs/img` budget — none
  quietly dropped;
- `pages.yml`'s existing `permissions:` block is unchanged.

No live desktop verification: nothing in the plugin, the package or the docs
moves. No capture is affected.

## Rollback

Two workflow files, no runtime effect. Step 1 reverts alone. Step 2 reverts
alone — restoring floating tags is a valid state, not a broken one, which is
the point of the caveat: if the pins are not going to be maintained, reverting
this step is the honest outcome rather than leaving them to rot.
