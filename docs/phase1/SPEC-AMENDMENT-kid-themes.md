# SPEC amendment: kid-chosen themes (T44/T45)

Status: **partly built.** The pick-from-the-set half (T44: `theme_apply_for` is kid-owned; the `theme:<account>` lock is verify-only) is built on `fix/kid-session-polish`. The T45 chord and the "make a theme" question (T48) are still open. Requested by the owner's
dogfooding notes, 2026-09-24: "We need a way for kids to easily change and make inside the system,
their own themes, and bundle some desktop themes for kids for them out of the box. It should be the
same keybinding as the main, so they are actually learning."

Amends: R-DESK-3/4, Appendix E, docs/theming.md issue #53's lock. Does not touch the child's
account, screen time, web policy, or any enforcement lock.

## Why

Today a kid's theme is applied by root (`theme_apply_for`) and re-applied on drift by the
`theme:<account>` assert lock (`lib/assert-locks.sh`). The kid cannot change it, and the same chord
a parent uses to switch themes (`Super+Ctrl+Shift+Space`, Omarchy's own) does nothing in a kid's
session. The owner wants the kid to learn the real chord. A theme is presentation, not
enforcement: a kid-writable theme dir in their own home, read by their own session, is not a
privilege escalation and not a lock this project should own.

## The model

- **The theme is a preference inside a parent-approved set.** The offered set is
  `theme_list_installed` — Omarchy's own `$OMARCHY_PATH/themes` plus the package's
  `$KIDS_THEMES_DIR` (`share/themes-kids/`, R-DESK). The kid picks from that set only; a name
  outside it is refused.
- **The parent's `theme` override sets the default.** It is what provisioning applies and what
  "Reset to band defaults" restores. A kid changing their theme does not change the profile's
  `theme` value (the override stays the default the parent chose); it changes the kid's current
  theme, which lives in their own `~/.local/state/omarchy/current/theme`.
- **The themes are visible to Omarchy's own switcher.** Provisioning links each collection theme into the kid's `~/.config/omarchy/themes/<name>` (a kid-owned symlink to the root-owned package copy), which Omarchy reads for user themes. Built on `fix/kid-session-polish`.
- **The kid switches on Omarchy's own chord.** Built: the level configs bind `Super+Ctrl+Shift+Space` to `bin/omarchy-kids-theme` at Grid, Desktop and the retired level 2, and the command applies through Omarchy's own `omarchy-theme-set`. (What the chord does not yet do is a pre-reader grid tile.) `Super+Ctrl+Shift+Space` runs the same kind of
  picker a parent's does, over the offered set. Every level gets it: at the Grid, a grid tile for
  pre-readers as well. This is a presentation bind, so it does not touch the Appendix E "nothing
  else bound" claim for the Grid's *window* controls; the amendment adds exactly this one bind and
  restates Appendix E.
- **The `theme` assert lock becomes verify-only.** It no longer re-applies the profile's theme on
  every run. It accepts an absent `theme.name` (nothing to enforce) or a name inside the offered
  set (a kid's free choice); it refuses a name outside the set, or any planted non-regular file (a
  FIFO/symlink/directory), reading `theme.name` with `O_NOFOLLOW` + `O_NONBLOCK` + a regular-file
  check so a planted FIFO cannot hang the assert. `fix` applies the profile's `theme`, or the
  parent's current theme when the profile has no `theme` override (the same default
  `omarchy-kids-conf unset theme` uses). This is the one fence: the set is closed at the package's
  two roots.

## The one owner question

**May a kid make their own theme** (write a `colors.toml` of their own under a kid-owned directory),
or only pick from the offered set? The owner's note says "change and make". Making one is a kid app
(T48, L): it needs a constrained editor and a kid-owned theme root the session reads. Picking is
this amendment (M). The amendment as written ships **picking**; a kid-made theme is a separate,
larger ticket. The owner decides whether making is in scope now.

## Acceptance

- A kid at any level can change their theme among the offered set on the real chord, and the
  choice survives a logout and is not reverted by `omarchy-kids-assert`.
- A kid cannot point their theme at a directory outside the two offered roots; assert reports and
  fixes that.
- The parent's `theme` override and "Reset to band defaults" still work as the default.
- Live on the VM: switch a theme as a kid at Level 1 and Level 3, log out and back, run
  `omarchy-kids-assert`, and check the theme is unchanged and the lock passes.
