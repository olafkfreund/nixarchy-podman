---
status: approved
issue: 5
author: olafkfreund
---

# Intent: GitHub Pages showcase with real captures and a user story

## Problem

nixarchy.podman is documented only in text: the README, `docs/usage.md` and
`AGENTS.md`. Someone deciding whether to use it cannot see it, and nothing shows:

- what the bar glyph, the popup and the full-screen menu look like;
- how the four tabs differ;
- what the keyboard flow feels like;
- what happens when Podman refuses something or is not reachable.

The text also never makes the case for the plugin. It never says who it is
for, what it replaces (a terminal full of `podman ps`, `podman system df`,
`podman volume prune`), or why the choices were made:

- Podman decides what counts as unused;
- every destructive step asks first;
- there are two ways in.

The sibling projects already have a public face: `nixarchy` has a Jekyll site
on GitHub Pages, and `nixarchy-pkg` has a captioned screenshot tour. This
plugin has neither. Pages is already switched on for this repository, set to
deploy through GitHub Actions from `master`, but no site has been built.

## Proposed outcome

- **A public site.** `https://olafkfreund.github.io/nixarchy-podman/` looks
  like the nixarchy/omarchy site (same typography, layout and colour
  language) and presents the plugin to a newcomer.
- **A user story up front.** The home page opens with who this is for, the
  problem it solves, and how and why it works, before any install
  instructions.
- **Real captures.** Screenshots and short screen recordings, taken from a
  live desktop, show every surface and every menu:
  - the bar glyph states;
  - the popup and the full-screen menu;
  - all four tabs, with the filter, the shortcut sheet and both kinds of
    confirmation;
  - the terminal launches (logs, shell, podman-tui);
  - the Omarchy menu row, the key binding and the settings.
- **The guide is part of the site.** `docs/usage.md` becomes a page there
  rather than a second copy, and the README links to the site.
- **Repeatable captures.** A capture script sits in the repo, as nixarchy
  has, so the images can be retaken when the UI changes.

## Affected users and systems

- This repository: `docs/` (site layout, styles, home page, images,
  recordings, capture script), a Pages deploy workflow in `.github/`, and
  links in `README.md`. The plugin code and the flake package do not change;
  the package's explicit file list keeps all of this out of it.
- p620's desktop, used to take the captures. It is driven through ai-mirror,
  with throwaway demo containers, images and volumes.
- The Pages setting on the repo is already `workflow`; nothing new has to be
  switched on.

## Constraints

- **Real captures only.** No mock-ups or hand-drawn UI, and every image comes
  from the running plugin. As in nixarchy-pkg, say so on the page.
- **No private data in any image.** The desktop shows other agents'
  sessions, chat and browser tabs. Captures must be cropped to the plugin, or
  taken on an empty workspace with a neutral wallpaper, and every image is
  reviewed before it is committed.
- **Nothing of the user's is changed or deleted while capturing.** Demo
  objects are created for the shoot, clearly named, and removed afterwards.
  Confirmation dialogs are cancelled unless the demo object is the target.
  The user's `shell.json` and menu file are backed up and restored.
- **No symlinks in the repository** (see `AGENTS.md`).
- **A small repository.** Recordings are short and compressed, and images are
  sized for the web. The repo is cloned whole by `omarchy plugin add`, so
  every megabyte lands in users' plugin folders.
- **The same look as nixarchy, without a copy that drifts.** Reuse its
  approach (plain Jekyll, no theme gem, one stylesheet, JetBrains Mono)
  rather than inventing a new design.

## Open questions

1. **Which recording format?** Pick one:
   - (a) short GIFs, as nixarchy uses: they autoplay everywhere, but are
     large;
   - (b) MP4/WebM, which is about ten times smaller with better colour,
     played in a `<video>` on the site;
   - (c) both: video on the site, one small GIF for the README.

   I recommend (c).
2. **Where do captures live?** In this repo under `docs/img/`, so they are
   versioned with the UI they show but also reach `plugin add` clones. Or on
   a separate `gh-pages`-only branch or in release assets, which keeps them
   out of clones but lets them drift from the code. I recommend `docs/img/`
   with a hard size budget: total under about 8 MB.
3. **Site shape.** Pick one:
   - (a) a single long landing page: story, tour, install, links;
   - (b) a landing page plus a "manual" section built from `docs/usage.md`,
     with the sidebar layout nixarchy uses.

   I recommend (b), since it reuses the guide.
4. **Capture session.** The shoot takes over the desktop for about 20–30
   minutes: it opens and closes surfaces, launches terminals, and restarts
   the shell. Should it run at a time you choose, and on which monitor or
   workspace? DP-2 on an empty workspace would be the default.

## Decisions at approval

The owner approved this intent with "use the recommendations":

1. Video (MP4/WebM) on the site, plus one small GIF for the README.
2. Captures live in `docs/img/`, with a total budget of about 8 MB.
3. The site is a landing page plus a manual section built from
   `docs/usage.md`, with the sidebar layout nixarchy uses.
4. The capture session runs on an empty workspace on DP-2.
