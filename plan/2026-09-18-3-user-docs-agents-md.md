---
status: draft
issue: 3
spec: spec/2026-09-18-3-user-docs-agents-md.md
---

# Plan: User documentation and an AGENTS.md for all AI agents

## Approved decisions (self-contained summary)

- **No behaviour change.** This is documentation only: the plugin, the flake
  package (ten files) and CI behaviour stay as they are. Every command, key,
  path and UI string in the docs is checked against the code on `master`
  (`94602b6`).
- **`docs/usage.md`.** A task-oriented guide, in this order:
  1. what it is (the two ways in);
  2. install on NixOS: the flake input,
     `programs.nixarchy.plugins."nixarchy.podman".src`,
     `virtualisation.podman.enable`, `podman-tui`, rebuild, then
     `omarchy plugin enable nixarchy.podman`, which also places the widget;
     check with the glyph and `omarchy plugin list`;
  3. install without Nix: `omarchy plugin add`, then `enable`;
  4. the bar popup: the glyph's states, what each tab shows, the
     Unused / In use split and the footer;
  5. the full-screen menu: the row from `share/omarchy-menu.jsonc`,
     Super+Alt+Space → "podman", the Super+Alt+O bind, the `{"tab":…}`
     payload, and how it differs from the popup;
  6. everyday recipes: start and stop, logs, shell, copy, remove one item,
     prune, filter;
  7. settings, which the menu picks up the next time it opens;
  8. troubleshooting, each entry as symptom → cause → fix:
     - "Podman unreachable" or "No access to the Podman storage";
     - blank volume sizes;
     - the menu row is missing;
     - the old id is still in the bar;
     - a rebuild does not replace the plugin (a real directory shadows the
       managed link);
     - the `d` key does nothing;
  9. removal.
- **`README.md`.** It becomes a landing page. It keeps:
  - the pitch and the two ways in;
  - the key tables;
  - the short NixOS snippet;
  - Settings;
  - IPC;
  - the port notes;
  - Development;
  - the License.

  The walkthroughs for migration, the menu row, the bind, removal and
  requirements move to the guide. It links to `docs/usage.md` near the top
  and to `AGENTS.md` under Development.
- **`AGENTS.md`.** Plain Markdown, and the single source for agents. It has
  seven sections:
  1. what the repo is;
  2. layout and ownership;
  3. commands (`node tests/run.js`, `nix flake check`, `--all-systems
     --no-build`, `nix build`, `omarchy plugin validate`);
  4. live verification (link or copy into the plugins folder,
     `omarchy-restart-shell`, `qs log -i`, `omarchy-shell shell toggle`,
     `omarchy shell nixarchy.podman.bar open`, `hyprctl layers -j`), with
     two caveats: a restart drops ai-mirror control, and the bar's IPC target
     reaches only one monitor;
  5. rules, each with its reason (the list is under step 2 below);
  6. workflow (the gates, one commit per step, deviations recorded in
     `plan/`, the commit style);
  7. known follow-ups.
- **`CLAUDE.md`.** A regular file containing `@AGENTS.md`, plus one line on
  why it is not a symlink.
- **`.github/copilot-instructions.md`.** One paragraph pointing to
  `AGENTS.md`, and a restatement of three rules: no symlinks, pipefail with
  `|| exit 1`, and no polling while closed. The restatement is marked as a
  deliberate copy, with `AGENTS.md` winning on drift.
- **No symlinks anywhere in the repo.** Nothing here is a symlink, because
  `omarchy plugin add` makes the repo itself the plugin folder.

## Steps

Each step is one commit on `docs/3-user-docs-agents-md`, citing
`plan step N`.

1. **`docs/usage.md`.** Write the guide. Take each UI string from the
   source: `Model.emptyText`, `Model.summaryText` and the hint texts in
   `PodmanView.qml`.
   → Verify:
   - the strings the guide quotes are found in the code:
     `grep -F "Podman unreachable" Model.js`,
     `grep -F "No access to the Podman storage" Model.js`, and the subuid
     hint in `PodmanView.qml`;
   - every key it names appears in `Model.js` shortcut data or
     `PodmanView.qml` `handleTextKey`;
   - its read-only commands run: `omarchy plugin list | grep nixarchy.podman`,
     `podman info`, `podman system df -v`.
2. **`AGENTS.md`.** Write it. Its rules section holds:
   - no symlinks anywhere in the repo, because `omarchy plugin add` makes the
     repo the plugin folder;
   - no hardcoded colours: use `Color.*` tokens;
   - no `pacman` or `yay`;
   - a new runtime file goes in the `files` list in `flake.nix`;
   - external commands run by name from `PATH`, never wrapped;
   - every piped `sh -c` gets `set -o pipefail`, and each command inside a
     `{ …; }` group gets `|| exit 1`;
   - QObject-property lists are not JS arrays;
   - `open()` on the keep-loaded menu resets its state and focus;
   - `PodmanState` does not poll while its surface is closed, except for the
     bar's slow poll;
   - Model logic gets a Node test;
   - user-visible changes update `docs/usage.md` in the same PR.

   → Verify:
   - every command in its "Commands" and "Live verification" sections has
     been run, or exercised in #1;
   - every file path it names exists (`test -e` on each);
   - the rules match the code: `grep -c 'set -o pipefail' PodmanState.qml`
     is at least 7, and `grep -c '|| exit 1' PodmanState.qml` is 2.
3. **`CLAUDE.md` and `.github/copilot-instructions.md`.**
   → Verify:
   - `test ! -L CLAUDE.md`;
   - `grep -qx '@AGENTS.md' CLAUDE.md`;
   - the three restated rules match `AGENTS.md` word for word, checked with
     `grep -F` on each rule line;
   - `claude -p "What must you never add to this repository, and why?"` from
     the repo root answers that symlinks must not be added, because of
     `omarchy plugin add` or the validator. The prompt carries no hints.
4. **`README.md`.** Trim it and add the links.
   → Verify:
   - every relative Markdown link in `README.md`, `docs/usage.md`,
     `AGENTS.md` and `.github/copilot-instructions.md` resolves, via a small
     link-extract loop with `test -e`;
   - nothing that was cut is lost: each moved walkthrough heading exists in
     `docs/usage.md`.
5. **Close-out.**
   - Run the whole-repo checks (Tests below).
   - Add an implementation record to this plan.
   - Push, then open a PR that links the intent, spec and plan and says
     `Closes #3`.
   - Once CI passes, answer the Copilot review. Its findings are verified
     one by one before anything changes.
   - Merge only when you say so.

## Tests

- `git ls-files -s | awk '$1 == "120000"'` prints nothing.
- `omarchy plugin validate .` exits 0. This is the checkout that
  `plugin add` would use.
- `nix flake check` passes, and `ls "$(readlink -f result)" | wc -l` is 10
  after `nix build`.
- `node tests/run.js` passes 125.
- The link check from step 4 passes.
- The `claude -p` check from step 3 passes.
- CI passes on the PR.

## Rollback

Everything is additive Markdown except the README trim. Revert the PR's
merge commit, or `git revert` a single step's commit. The plugin, the
package and the hosts are untouched in every case.
