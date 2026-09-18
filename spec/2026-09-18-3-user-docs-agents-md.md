---
status: draft
issue: 3
intent: intent/2026-09-18-3-user-docs-agents-md.md
---

# Spec: User documentation and an AGENTS.md for all AI agents

## Decisions taken from the intent's open questions

The intent was approved without answers to its three questions. This spec
takes the recommendations it gave. Overturn any of them at this gate.

1. **The usage guide is `docs/usage.md`**, a Markdown file that GitHub
   renders. It is written so a Pages site could later be built on the same
   file without a rewrite.
2. **Pointer files:** `CLAUDE.md` and `.github/copilot-instructions.md`.
   There is no `GEMINI.md`.
3. **`AGENTS.md` carries the intent → spec → plan workflow in short form**,
   so that agents without the global managed policy follow the gates too.

## Design

### `docs/usage.md`: task-oriented guide

For someone who has never seen the plugin. It is ordered by what they do,
not by feature:

1. **What it is.** Two ways in (bar popup, full-screen menu), with one line
   on each.
2. **Install on NixOS (nixarchy):**
   - the flake input;
   - `programs.nixarchy.plugins."nixarchy.podman".src`;
   - `virtualisation.podman.enable` and `podman-tui`;
   - rebuild, then `omarchy plugin enable nixarchy.podman`, which also
     places the widget in the bar;
   - how to check it worked: the glyph appears, and `omarchy plugin list`
     shows it enabled.
3. **Install without Nix:** `omarchy plugin add` plus `enable`.
4. **First look: the bar popup.** What the glyph's states mean
   (dim, bright, red), what each tab shows, and the Unused / In use split
   with its footer.
5. **The full-screen menu:**
   - adding the menu row (`share/omarchy-menu.jsonc` into the extension
     file);
   - finding it with Super+Alt+Space → "podman";
   - binding Super+Alt+O;
   - opening it on a given tab;
   - how it differs from the popup (larger, holds the keyboard, Tab walks
     tabs, works without the bar).
6. **Everyday tasks.** Each is a short recipe with its keys:
   - start and stop;
   - follow logs;
   - open a shell;
   - copy a name or id;
   - remove one item;
   - reclaim space with prune;
   - filter.
7. **Settings.** What each changes, and that the menu picks them up the next
   time it opens.
8. **Troubleshooting.** Each entry is a symptom, then the cause, then the fix:
   - "Podman unreachable" or "No access to the Podman storage": check
     `podman info`, the subuid/subgid ranges, and whether
     `virtualisation.podman` is on;
   - volume sizes blank: check `podman system df -v`, and whether
     "Measure what each volume costs" is off;
   - the menu row is missing: check the extension file, the JSON syntax,
     and whether the plugin is enabled;
   - the old `abdullahmansoor.omapodman` is still in the bar: the migration
     steps;
   - a nixarchy rebuild does not replace the plugin: remove the real
     directory that shadows the managed link;
   - the `d` key does nothing: install `podman-tui`.
9. **Removal.**

Every command, key, path and message in it is checked against the merged code
(`94602b6`). The empty-state and error texts come from `Model.emptyText`
(`Model.js`) and `PodmanView.qml`, not from memory.

### `README.md`: trimmed to a landing page

It keeps:

- the pitch and the two ways in;
- the key tables (they double as reference);
- the short NixOS install snippet;
- the Settings table;
- IPC;
- the Docker → Podman port notes;
- Development;
- the License.

It moves to `docs/usage.md`: the migration, menu-row, bind, removal and
requirements walkthroughs. The README links to the guide near the top, and
links to `AGENTS.md` under Development.

### `AGENTS.md`: the single source for agents

Plain Markdown, with no agent-specific syntax:

1. **What this repo is.**
   - An Omarchy Quickshell plugin, `nixarchy.podman`, packaged by a flake for
     nixarchy.
   - A fork of OmaPodman.
2. **Layout and ownership:**
   - `Model.js` holds all logic and is pure, tested under Node;
   - `PodmanState.qml` holds data, polling and commands;
   - `PodmanView.qml` holds interaction;
   - `Panel.qml` and `Menu.qml` are the hosts;
   - `flake.nix` holds the package file list and the checks;
   - `share/`, `intent/`, `spec/`, `plan/` and `tests/` complete the tree.
3. **Commands:**
   - `node tests/run.js`;
   - `nix flake check`;
   - `nix flake check --all-systems --no-build`;
   - `nix build`;
   - `omarchy plugin validate "$(readlink -f result)"`.
4. **Verifying live on a nixarchy desktop:**
   - link or copy the plugin into `~/.config/omarchy/plugins/nixarchy.podman`;
   - run `omarchy-restart-shell`;
   - read the shell log with `qs log -i <instance>`;
   - open the menu with `omarchy-shell shell toggle nixarchy.podman '{}'`
     and the popup with `omarchy shell nixarchy.podman.bar open`;
   - check which surfaces are up with `hyprctl layers -j`.

   Two notes go with this:
   - Restarting the shell drops ai-mirror control.
   - The bar popup's IPC target reaches only one monitor's bar.
5. **Rules (must / must not).** Each rule comes with its reason:
   - no symlinks anywhere in the repo, because `omarchy plugin add` makes the
     repo the plugin folder;
   - no hardcoded colours: use `Color.*` tokens;
   - no `pacman` or `yay`;
   - a new runtime file must be added to the `files` list in `flake.nix`;
   - external commands run by name from `PATH`, and are never wrapped;
   - every piped `sh -c` needs `set -o pipefail`, and each command inside a
     `{ …; }` group needs `|| exit 1`;
   - lists read through QObject properties are not JS arrays: check
     `length`, not `Array.isArray`;
   - reset state and focus in `open()` on the keep-loaded menu;
   - `PodmanState` must not poll while its surface is closed, except for the
     bar's slow poll;
   - Model logic gets a Node test.
6. **Workflow:**
   - the intent → spec → plan gates in five lines, never self-approved;
   - one commit per plan step, citing that step;
   - deviations are recorded in `plan/` in the same commit;
   - the commit style.
7. **Known state:** the out-of-scope follow-ups:
   - wiring the flake into the hosts;
   - sending the pipefail fix upstream.

### `CLAUDE.md` and `.github/copilot-instructions.md`: pointers

- **`CLAUDE.md`** is a regular file containing `@AGENTS.md`, which Claude
  Code resolves as an import, plus a one-line note on why it is not a
  symlink. Nothing else goes in it.
- **`.github/copilot-instructions.md`** holds one paragraph telling Copilot
  to follow `AGENTS.md`, and restates its three review-critical rules (no
  symlinks, pipefail, no polling while closed). Those rules are copied rather
  than referenced, because Copilot code review reads only this file (see
  Risks). It is the one deliberate duplication, and it is marked as such in
  both files.

## Alternatives rejected

- **`CLAUDE.md` as a symlink to `AGENTS.md`, as in `nixarchy`.** That breaks
  `omarchy plugin add`: the validator refuses symlinks inside the plugin
  folder, which for that install path is this repo.
- **Separate full instruction files per agent.** They drift apart. The
  intent requires one source.
- **A GitHub Pages site now.** It needs repository settings and a deploy
  workflow for a single-page guide. `docs/usage.md` does not block adding one
  later.
- **The wiki.** It is not versioned with the code and not reviewed in PRs,
  so the docs would drift from behaviour.
- **Leaving the README as the only doc.** The README is a reference, and the
  intent's problem is that there is no walkthrough and no troubleshooting.

## Risks

- **Copilot may not follow the pointer.** Copilot code review may not read a
  file that `copilot-instructions.md` merely points to. That is why the three
  critical rules are restated there. If they drift from `AGENTS.md`, the rules
  in `AGENTS.md` win, and a note in both files says so.
- **The docs can go stale when the code changes.** Mitigations: `AGENTS.md`
  rules require updating `docs/usage.md` in the same PR as any user-visible
  change, and the plan's verification checks every command in the docs.
- **The docs directory reaches `plugin add` users.** It becomes part of their
  plugin folder. That is harmless: Markdown only, no symlinks, and the
  validator checks only entry points.
- **No effect on the package or the hosts.** The flake's explicit `files`
  list keeps docs out of the Nix package.

## Verification

1. `git ls-files -s | awk '$1 == "120000"'` prints nothing: the repo contains
   no symlinks.
2. `omarchy plugin validate .` on the checkout exits 0. That is the
   `plugin add` path, with the new files present.
3. `nix flake check` passes, and `nix build` still yields exactly the ten
   files.
4. Every shell command in `docs/usage.md`, `README.md` and `AGENTS.md` is
   extracted and checked:
   - read-only ones are run (`omarchy plugin list`, `podman info`,
     `podman system df -v`, `node tests/run.js`, `nix flake check`,
     `qs log`, `hyprctl layers -j`);
   - state-changing ones (`enable`, `disable`, `bar move`, `toggle`) are
     confirmed against the CLI's usage output, or were already exercised in
     #1.
5. Every key and UI string in the guide is cross-checked against
   `PodmanView.qml` and `Model.js`, especially the empty-state and error
   texts.
6. Every relative link in the new and changed Markdown resolves to a file in
   the repo.
7. A fresh Claude Code session in the repo has `AGENTS.md` loaded through the
   import. The check: run `claude -p "What must you never add to this repo,
   and why?"` from the repo root, and it answers "symlinks", citing
   `omarchy plugin add`.
8. CI passes on the PR.
