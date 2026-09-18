---
status: draft
issue: 3
author: olafkfreund
---

# Intent: User documentation and an AGENTS.md for all AI agents

## Problem

- **Usage lives only in the README.** The README is a reference: install
  snippets, key tables, settings, IPC. It does not walk a new user through
  first use: installing, enabling, finding Podman in the bar and in the menu,
  adding the bind, and what to do when a tab is empty or shows an error.
  Nothing on GitHub presents the plugin to someone who has not cloned it.
  `nixarchy` has a `docs/` site on GitHub Pages; this repo has nothing like it.
- **Agents lose the repo's rules.** The rules for working in this repo were
  learned the hard way during #1, and none of them is written down for an
  agent to read:
  - the intent → spec → plan gates;
  - the flake file list and its checks;
  - no symlinks inside the plugin;
  - no hardcoded colours;
  - Qt sequence wrappers are not JS arrays;
  - `pipefail` inside brace groups;
  - the stale-focus trap on a keep-loaded menu;
  - live testing through `omarchy-restart-shell` and ai-mirror.

  Claude Code, Codex, Copilot and Gemini each look for different files, so
  whatever gets written down reaches only some of them.

## Proposed outcome

- **A usage guide on GitHub.** A user landing on the repo can follow a
  task-oriented guide: install on NixOS, or without Nix; use the bar popup;
  open the full-screen menu from the Omarchy menu or a key; the keys; the
  settings; troubleshooting; removal. The README stays short and links to it.
- **An `AGENTS.md` at the repo root.** It is the single source of
  instructions for any AI agent: what the repo is, the file layout and who
  owns what, how to build, test and verify live, the rules above, and the
  artifact workflow.
- **One set of instructions for every agent.** `CLAUDE.md` and
  `.github/copilot-instructions.md` point at `AGENTS.md` rather than holding
  copies. Every agent then reads the same instructions, and a change is made
  in one place.

## Affected users and systems

- Repository docs only: a new `AGENTS.md`, `CLAUDE.md`, the guide, a trimmed
  `README.md`, and possibly `.github/` and `docs/`.
- The plugin package and its behaviour do not change. The flake copies an
  explicit file list, so new docs never reach the plugin folder.
- Users who install with `omarchy plugin add` get the whole repo as their
  plugin folder, docs included (see Constraints).

## Constraints

- **No symlinks anywhere in the repo.** `nixarchy` makes `CLAUDE.md` a
  symlink to `AGENTS.md`, but here that would break the non-Nix install:
  `omarchy plugin add` clones the repo as the plugin folder, and
  `omarchy-plugin-validate` refuses any symlink inside it. So `CLAUDE.md` must
  be a real file that imports `AGENTS.md` (`@AGENTS.md`), not a link.
- **Docs describe what exists.** Every command, key and path in them must be
  checked against the merged code (`94602b6`), not recalled.
- **No behaviour change.** `nix flake check` and CI stay green, and the
  package's ten-file list does not change.
- **One source of truth.** `AGENTS.md` holds the content; the other agent
  files only point at it.

## Open questions

1. **Where should the user docs live?** Pick one:
   - (a) `docs/usage.md` in the repo, rendered by GitHub. This is the
     simplest.
   - (b) a GitHub Pages site under `docs/`, like `nixarchy`'s. This is the
     nicest to read, but needs Pages turned on in the repo settings and a CI
     deploy.
   - (c) the GitHub wiki. Wikis are already enabled, but a wiki is not
     versioned with the code or reviewable in PRs.

   I recommend (a) now; (b) can later be layered on the same file.
2. **Which agents should get a pointer?** `CLAUDE.md` (required), plus
   `.github/copilot-instructions.md`, since Copilot already reviews PRs here.
   Also `GEMINI.md`? It would matter only if Gemini CLI or Antigravity is used
   on this repo.
3. **Should `AGENTS.md` repeat the managed artifact workflow**, so that agents
   without your global policy (Codex, Copilot) follow the gates too? I
   recommend yes, in short form.
