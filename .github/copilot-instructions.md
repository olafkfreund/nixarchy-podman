# Copilot instructions

Follow [`AGENTS.md`](../AGENTS.md) at the repository root. It is the single source of
instructions for every AI agent working here: layout, commands, rules and workflow.

Copilot code review may read only this file, so three rules from `AGENTS.md` are
repeated below. This is the one deliberate copy; if it ever disagrees with
`AGENTS.md`, `AGENTS.md` wins.

- **No symlinks anywhere in the repository.** `omarchy plugin add` clones this repo
  *as* the plugin folder, and `omarchy-plugin-validate` refuses any symlink inside
  one. That is why `CLAUDE.md` imports `AGENTS.md` instead of linking to it.
- **Every piped `sh -c` starts with `set -o pipefail`, and the first command inside a
  `{ …; }` group ends with `|| exit 1`.** Without them, a failing `podman` looks
  like an empty list.
- **`PodmanState` does not poll while its surface is closed.** The bar's slow
  background poll for the glyph is the only exception.
