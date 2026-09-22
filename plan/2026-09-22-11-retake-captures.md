---
status: draft
issue: 11
spec: spec/2026-09-22-11-retake-captures.md
---

# Plan: Retake the captures that #10, #13 and #14 made wrong

## Approved decisions (self-contained summary)

- **One session, on p620,** on HDMI-A-1 (1920×1080 at +1849+1440), where the
  originals were taken, using `master` `bc0b77a` (#10, #13 and #14 merged).
- **Retake, keeping each name and pixel size:**

  | File | Size |
  | --- | --- |
  | `popup-containers.png` | 510×512 |
  | `menu.png` | 1320×780 |
  | `filter.png` | 510×306 |
  | `confirm-prune.png` | 510×306 |
  | `podman-refuses.png` | 510×376 |
  | `shortcuts.png` | 510×510 |
  | `rec-menu.webm/.mp4` | 1280×848, 30 fps, about 14.5 s |
  | `rec-popup.webm/.mp4` | 520×560, 30 fps, about 9 s |
  | `rec-omarchy-menu.webm/.mp4` | 1280×848, 30 fps, about 4.2 s |
  | `demo.gif` | 800×529, 10 fps, about 76 frames |

  Correction to the spec, from those sizes: `demo.gif` is re-cut from `rec-menu`
  (the same aspect ratio), not from `rec-popup`.
- **Leave alone:** `confirm-remove.png`, the Images, Volumes and Networks popup
  stills, `glyph-states.png`, `logs.png`, `shell.png` and `omarchy-menu-row.png`.
- **Privacy:**
  - `confirm-prune.png` is taken on the **Containers** tab. p620 has no containers of
    its own, so the question names only `demo-shop-migrate`. Read it on screen
    before the shot; stop if it names anything that is not `demo-*`.
  - No frame of any recording may show anything outside `demo-*`. Show Images and
    Volumes only filtered to `demo`.
- **Storyboards, the same as the originals:**
  - `rec-menu`: the menu opens on Containers, the cursor walks, one container is
    stopped and started;
  - `rec-popup`: the popup opens, a filter is typed and cleared, then the tabs, then
    `?`;
  - `rec-omarchy-menu`: the Omarchy menu search for "podman", the row, the menu opens.
- **p620 is restored exactly:**
  - the plugin folder, a real directory, is backed up and restored (`diff -r` clean);
  - `shell.json`, `omarchy-menu.jsonc` and the clipboard are restored;
  - the Podman snapshot diff is clean;
  - the session is announced on the bus, with "done" posted at the end.
- **Rejected:** taking the captures on razer; `confirm-prune` on Volumes;
  pixelating names; linking the folder to `master`'s store path (the p620 wiring
  follow-up).

**Safety** (from #10 and #14): screenshot and read every dialog before any confirm,
and send the confirm in a separate call. This retake confirms nothing: every dialog
is shot, then cancelled. Never confirm a prune. Ask for ai-mirror control before
opening any surface, because the request dialog closes layer-shell panels.

## Steps

One commit on `docs/11-retake-captures` for the captures, and one for this plan's
status notes.

1. **Prepare.**
   - Check the bus for p620 claims, then post the announcement.
   - Record `du -sb docs/img` and each target file's size.
   - Back up: `cp -a ~/.config/omarchy/plugins/nixarchy.podman <scratch>/p620-plugin.bak`,
     plus `shell.json`, `extensions/omarchy-menu.jsonc` and `wl-paste` into the
     scratchpad.
   - Snapshot Podman: `ps -a`, `images`, `volume ls` and `network ls`.
   - Verify: the backups exist, and `diff -r` of the plugin backup against its
     source is empty.
2. **Install `master`.**
   - Run `nix build` on `master` (`bc0b77a`), then replace the plugin folder's
     contents with `cp -rL result/.` (`chmod -R u+w`).
   - Run `omarchy-restart-shell`, with the session `OMARCHY_PATH` for every
     `omarchy-shell` call.
   - Verify: `grep -c pruneMessage` in the installed `Model.js`, `ping` answers, and
     `qs log` shows no plugin errors.
3. **Stage.**
   - Run `docs/capture.sh --setup`, then `--unhealthy`.
   - Switch to a new empty workspace on HDMI-A-1, and park the pointer off-screen.
   - Ask ai-mirror (the local MCP) for control.
   - Verify: the demo objects are listed, the workspace is empty, and control is
     `agent`.
4. **Stills.** For each one:
   - open the surface by IPC or keys;
   - read the layer geometry;
   - screenshot and read it: `demo-*` only, and the expected look;
   - then run `docs/capture.sh --shot NAME X,Y WxH` at the recorded size.

   The six stills:
   - `popup-containers`: popup on Containers (header, dim stopped rows);
   - `menu`: menu on Containers;
   - `filter`: Containers filtered to `web`;
   - `confirm-prune`: `p` on Containers (named question), then Cancel;
   - `podman-refuses`: Images filtered to `demo/shop`, `x` on the in-use image,
     screenshot the dialog, confirm (Podman refuses), then shoot the full refusal;
   - `shortcuts`: `?` in the popup.

   Verify: each file's size matches the table.
5. **Recordings.** For each storyboard:
   - record with `wl-screenrec --low-power=off -m 30 -g "X,Y WxH"`;
   - encode to WebM (`-c:v libvpx-vp9 -crf 40 -b:v 0`) and MP4
     (`-c:v libx264 -crf 28 -pix_fmt yuv420p`), with no audio;
   - re-cut `demo.gif` from `rec-menu` at 10 fps and 800 px wide, with a palette
     pass.

   Verify:
   - `ffprobe`: sizes and frame rates match;
   - frame sheets are viewed, with nothing outside `demo-*` and the new look
     present;
   - `du -sb docs/img` is under 8,388,608.
6. **Tear down and restore.**
   - Run `docs/capture.sh --teardown`.
   - Restore the plugin folder from the backup (`diff -r` empty), both config files
     (`cmp`), and the clipboard.
   - Run `omarchy-restart-shell`, release control, and post "done".
   - Verify: the Podman snapshot diff is clean.
7. **Commit and PR.**
   - Commit the retaken files, citing `plan step 4–5` and `(#11)`.
   - Push, and open a PR that links the intent, spec and plan and closes #11.
   - Verify: CI and the pages workflow are green after merge.

## Tests

```bash
magick identify -format '%f %wx%h\n' docs/img/*.png docs/img/demo.gif'[0]'
for v in rec-menu rec-popup rec-omarchy-menu; do ffprobe -v error -show_entries stream=width,height,r_frame_rate -of csv=p=0 docs/img/$v.webm; done
du -sb docs/img                                # < 8388608
nix flake check
```

## Rollback

- Before merge: `git checkout master -- docs/img`, or delete the branch.
- After merge: revert the merge commit. The old captures come back.
- p620: restore the plugin folder from `p620-plugin.bak`, and the config files from
  their backups. `docs/capture.sh --teardown` removes only the recorded demo
  objects.
