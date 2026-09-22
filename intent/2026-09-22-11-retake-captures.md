---
status: approved
issue: 11
author: olafkfreund
---

# Intent: Retake the captures that #10 made wrong

## Problem

The site (`docs/index.md`, `docs/usage.md`) and the README show real captures from
`docs/img/`, taken on p620 before #10. #10 changed what the Containers tab looks
like:

- containers now group under their Compose project header (`DEMO-SHOP`), with the
  rest under `UNGROUPED`;
- a container you stopped is drawn dim, where the old captures show it red;
- a stopped container no longer carries the unhealthy mark.

These captures therefore now show a panel nobody will see:

- stills: `popup-containers.png` and `menu.png`, and probably `filter.png`,
  `confirm-remove.png` and `confirm-prune.png` (Containers behind a dialog);
- recordings: `rec-menu.webm`/`.mp4` (a stop that turns red) and
  `rec-popup.webm`/`.mp4` (the ungrouped list), plus `demo.gif` if it is cut from
  them.

`AGENTS.md` asks for wrong captures to be retaken in the same PR. #10 deferred this
at the owner's request, because the originals were taken on p620 and need that
desktop.

## Proposed outcome

- Every capture in `docs/img/` matches what the current plugin shows, taken on the
  same host and at the same framing as the originals, so the page layout does not
  shift.
- The captures show only the plugin and `demo-*` objects. The owner's desktop,
  containers, images and volumes stay out of frame, and their state is unchanged
  afterwards.
- `docs/img/` stays under 8 MB. It is 5.0 MB today.

## Affected users and systems

- `docs/img/` and nothing else, unless a caption in `docs/index.md` or
  `docs/usage.md` describes the old look.
- p620: the branch build of the plugin is installed there for the session, demo
  objects are created in p620's Podman, and ai-mirror takes control of p620's
  desktop. p620 is also the machine this agent runs on, and other agents use it,
  so the session is announced on the agent bus first.
- Readers of the site and the README.

## Constraints

- `AGENTS.md` "Retaking the captures":
  - snapshot Podman, `shell.json` and `omarchy-menu.jsonc` first;
  - use `docs/capture.sh --setup` / `--unhealthy` / `--teardown`;
  - work on a new, empty workspace, with the pointer parked;
  - look at every image, and at a frame sheet of every video;
  - the snapshot diff must be clean apart from `demo-*`;
  - videos get `controls`.
- The live-test safety rules from #10: screenshot every dialog before any confirm,
  and never confirm a prune on Containers or Images while the owner has stopped
  containers or unused images. Only a `demo-*`-only Volumes or Networks prune may be
  confirmed.
- p620's plugin install: AGENTS.md lists wiring p620 to this flake as a known
  follow-up. Whatever is in `~/.config/omarchy/plugins/nixarchy.podman` on p620 is
  recorded first and restored afterwards.

## Open questions

1. **When should this run?** #13 (help sheet, error line) and #14 (prune dialog)
   change what `shortcuts.png`, `podman-refuses.png` and `confirm-prune.png` show.
   Pick one:
   - (a) retake once, after #13 and #14 merge;
   - (b) retake now, and again for the stills #13 and #14 change.

   I recommend (a): one p620 session, one set of captures, and nothing on the site
   is wrong for longer than it already is.
2. **Which host?** The originals came from p620: its bar, and 1920×1080 crops. I
   recommend p620 for consistency. razer would change the crop sizes and the bar,
   so every image on the site would visibly change.

## Decisions at approval

Approved without separate answers; the recommendations stand:
1. Retake once, after #13 and #14 merge.
2. On p620, the host the originals came from.
