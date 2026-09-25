# Theme plumbing: `lib/theme.sh`, `share/qml/KidsTheme.qml`, the portal (issue #48)

Every Kids Mode surface — the parent wizard/panel TUI, the kid-facing Quickshell windows, the
SDDM portal — follows whatever Omarchy theme the parent picked, the same way Omarchy's own
tools and shell do. One bash entry point and one QML entry point, both reading the same kind of
source Omarchy's own code reads, plus one posture writer that gets the portal (which runs before
any session, kid or parent, has ever logged in) the same colors at provision/assert time.

## Ground truth this rests on

Fetched and read directly from `omacom/omarchy` at tag `v4.0.2`, 2026-09:

- `themes/<name>/` — one directory per theme. What's actually there varies theme to theme; the
  only file every theme in that release ships is `colors.toml` (a theme missing one is
  auto-generated from its `alacritty.toml` at `omarchy theme set` time, `bin/omarchy-theme-
  colors-from-alacritty`). Most themes also carry `backgrounds/`, `icons.theme`, `preview*.png`,
  `unlock.png`; some carry `neovim.lua`, `hyprland.lua`, `vscode.json`, a terminal config. None of
  that other-app-specific config is what Kids Mode reads — only `colors.toml`.
- `$HOME/.local/state/omarchy/current/theme/` — the **current** theme: a real directory (not a
  symlink), rebuilt whole by `bin/omarchy-theme-set` on every `omarchy theme set` (copy the theme,
  overlay the user's own copy if any, generate the dynamic app configs, `mv` into place). **Not**
  `$HOME/.config/omarchy/current/theme` — that path doesn't exist on this stack. The theme's own
  display name lives beside it, in `.../current/theme.name` (`bin/omarchy-theme-current`).
- `bin/omarchy-theme-color` — "Resolve semantic colors from an Omarchy theme colors.toml", the
  same tool Omarchy's own templates, OSC sequences, and previews resolve colors through
  (`docs/tui.md` already cited this before this file existed). Defaults to reading
  `$HOME/.local/state/omarchy/current/theme/colors.toml`, or `--file <path>`. Resolves a semantic
  key (`background`, `foreground`, `accent`, `muted`, `red`, `orange`, …) through a legacy
  `color0..15`/short-name alias cascade and derived shades, so a theme only defining part of the
  palette still resolves every key. **Omarchy's own palette has no `error`/`warning` key** — this
  repo maps those to `red` and `orange` (itself falling back to `yellow`), the colors Omarchy's
  own generated app configs already use for error/warning states.
- `shell/Commons/Color.qml` / `Style.qml` / `qmldir` — the real Quickshell shell's own theme
  singletons (`module qs.Commons`, `singleton Color 1.0`, `singleton Style 1.0`). `Color` reads
  `colors.toml` (foreground/background/accent/urgent/muted) with a FileView at startup and is
  pushed live updates over shell IPC on every theme change; `Style.fontFamily` is always the
  fontconfig alias `"monospace"`, resolved to a concrete family with `fc-match -f '%{family[0]}'
  monospace` (`Style.qml`'s `fcMatchProc`) — never read from `colors.toml` at all.
- There is **no system-wide (root-level) current theme** anywhere in this release — every path
  above is `$HOME`-relative, because Omarchy is a single-user desktop. That's why the portal
  section below has to resolve the *parent's* `$HOME` explicitly.

## `lib/theme.sh`: the bash entry point

```sh
theme_dir                 # the directory whose colors.toml the functions below read
theme_color NAME           # background | foreground | accent | muted | error | warning
                            # (plus three portal-only extras: surface | surface_muted | highlight)
theme_font                 # the resolved font family, same as Style.qml's fcMatchProc
```

`theme_color` shells out to `omarchy-theme-color --file "$(theme_dir)/colors.toml" <key>` (mapping
`error`→`red`, `warning`→`orange`) and falls back to this repo's own dark palette — the exact
values `share/sddm-theme/theme.conf` and every `share/**/*.qml` file already hardcoded before this
file existed — whenever that tool isn't on `PATH`, the theme has no `colors.toml` yet, or a key
comes back empty. `theme_font` runs the identical `fc-match` command `Style.qml` does, falling back
to `"JetBrainsMono Nerd Font"` (`theme.conf`'s own original default).

`THEME_KIDS_HOME` overrides `$HOME` for a caller resolving *another* account's theme — the portal
writer below is the one caller that needs it, since it runs as root but has to read the parent's
theme, not root's.

**Issue #48 live finding**: running a Kids Mode command outside a full Omarchy session (no
Hyprland login — SSH, `unshare`, CI) can leave `$OMARCHY_PATH` unset, and Omarchy's own tools
depend on it to find their own installed files. `_theme_kids_env_defaults`, called from every
`lib/theme.sh` function that reads `$OMARCHY_PATH` or is about to run an Omarchy tool (not at
source time — review 2.7: sourcing a library must never change the caller's environment):

- defaults `OMARCHY_PATH` to `/usr/share/omarchy` (where the package installs itself) if unset;
- upgrades `LANG` to `C.UTF-8` if it's unset or the plain `"C"` locale (gum's own box-drawing
  needs a UTF-8 locale, not just to look right — the bordered header in `lib/tui.sh`).

Beyond that, a theme tool that's missing or broken for any other reason never aborts a Kids Mode
command — `theme_color`/`theme_font` fall back to the palette above, with exactly **one** warning
line per process (`_theme_kids_tool_ready`'s own cache — never once per color resolved), not a
crash and not silence. `test/shell.d/theme-test.sh` proves this under `set -euo pipefail`, the mode
every `bin/omarchy-kids-*` command runs in.

`lib/tui.sh` sources `lib/theme.sh` and uses `theme_color` for every `gum style` flag it emits
(`TUI_C_ACCENT`/`TUI_C_FG`/`TUI_C_MUTED`/`TUI_C_ERROR` — the bordered header, the Omy voice line,
footers, and a failed validator's error line), so the wizard and panel look like `omarchy-menu`
under whatever theme the parent is running (`docs/tui.md`'s own "Colors" section).

## `share/qml/KidsTheme.qml`: the QML entry point

Every Quickshell surface in this repo except `share/bar/KidsModule.qml` runs as its own standalone
`quickshell -p <file>` process (`docs/levels.md`'s "Open questions" #5 explains why, for the
launcher), not inside Omarchy's long-running `omarchy-shell`. That rules out `import qs.Commons`
for those files — that module namespace only exists inside the shell process itself, and nothing
here sets `QML2_IMPORT_PATH` to extend it to a bare `quickshell -p` invocation. So
`share/qml/KidsTheme.qml` does for those files exactly what `shell/Commons/Color.qml` does for the
real shell. It also resolves the same font the real shell would: `fontFamily` is always the
fontconfig alias `"monospace"`, resolved via `fc-match -f '%{family[0]}' monospace` through the
same `Process`/`StdioCollector`/`onStreamFinished` shape `share/qml/KidsTheme.qml` and
`share/plugins/shell.qml` already use. Unconfirmed: whether a bare `running: true` property
initializer on `Process` actually starts it on component completion the way it does for a `Timer`
elsewhere here (`share/launcher/shell.qml`'s clock) — if it doesn't in the VM, trigger it from
`Component.onCompleted` instead. Reads
`$HOME/.local/state/omarchy/current/theme/colors.toml` straight off disk with a `FileView`, using
the same key/fallback chases (`background`→`color0`, `accent`→`color4`, `foreground`→`color7`,
`muted`→`color8`, plus this repo's own `error`→`red`→`color1` and `warning`→`orange`→`yellow`→
`color3`), and resolve the font with the identical `fc-match` command via a
`Process`/`StdioCollector`/`onStreamFinished` — the one `Quickshell.Io.Process` shape already
confirmed live in this repo (`share/qml/KidsTheme.qml` and `share/plugins/shell.qml`).

It's a plain `QtObject`, not a `pragma Singleton`: every file that wants it just instantiates its
own copy —

```qml
KidsTheme { id: theme }
// ...
color: theme.background
```

— no import: `KidsTheme.qml` is installed beside every standalone surface's own `shell.qml` at
package-install time (`PKGBUILD`'s own copy step — Quickshell resolves QML types only inside the
shell's own directory, "Verified live" below), not read from `share/qml` at runtime — because each
`shell.qml` here is already its own separate process; there's no cross-file singleton worth
sharing within one QML engine the way the real shell needs one.

**Derived surface colors (issue #57)**: `KidsTheme.qml` also exposes `isLight`, `inputFill`,
`cardFill`, `tileFill`, `errorFill`, and `dim` — one place each surface goes for a "raised tile"
look, a sunken input fill, or a full-screen dim scrim, rather than every `share/**/*.qml` file
calling `Qt.lighter()`/`Qt.darker()` on `theme.background` with its own magic-number factor (what
every surface did before this issue, and the live bug that came from it: a factor tuned to look
right against a dark background does the wrong thing against a light one — lightening an
already-light background blows out toward white, and darkening it by a fixed factor lands on a
flat grey that reads as a *disabled* control, not a themed one — the exit modal's password field
under catppuccin-latte). Each of the five derived colors instead picks its direction from
`isLight` (darker on a light background, lighter on a dark one) and moves the background's own HSL
lightness by a fixed amount — see `KidsTheme.qml`'s own header and each property's comment for the
exact numbers and reasoning. `test/shell.d/qml-theme-static-test.sh` enforces this: no
`share/**/*.qml` file may call `Qt.lighter()`/`Qt.darker()` with a literal factor outside
`KidsTheme.qml` itself.

**`share/bar/KidsModule.qml` is the one exception**: it really does run inside `omarchy-shell`, as
a first-party-style plugin (its own header cites `manual/32-shell-plugins.md` and the real
`shell/Ui/Panel.qml`-based examples this file's structure mirrors), so it imports `qs.Commons`
directly — `Color.background`/`Color.accent`/`Color.muted`/`Color.urgent`/`Color.foreground` and
`Style.font.family`/`Style.selectedFillFor(...)` — instead of `KidsTheme.qml`. That's the "prefer
importing Omarchy's own shell theme singleton" path the module system actually allows here.

## The portal: `theme.conf` / `theme.conf.user`

`share/sddm-theme/Main.qml` runs under SDDM's own greeter engine — plain `QtQuick` (`metadata.
desktop`'s `QtVersion=6`, `import QtQuick 2.0`, confirmed against `omacom/omarchy`'s and `sddm/
sddm`'s own upstream source, `docs/portal.md`). **There is no Quickshell there at all**, so
`Main.qml` cannot import `share/qml/KidsTheme.qml` (which needs `Quickshell.Io.FileView`) — this is
the one QML file in this repo that keeps its own hardcoded `config.x || "#hex"` fallbacks, same as
before this issue, for exactly that reason (and the one exemption in the static check below).

`Main.qml` already reads every color as `config.<key>` — SDDM's own `ThemeConfig::setTo()`
(`sddm/sddm`'s `src/common/ThemeConfig.cpp`) loads `theme.conf`'s `[General]` keys into that
`config` property, then loads a *second* file, `theme.conf.user`, right beside it, and layers any
key it sets non-empty over the first (`docs/portal.md`'s own citation for `parent=`/`kids=`). This
issue adds nine more keys to that same `theme.conf.user`, alongside `parent=`/`kids=`, so SDDM
picks all of it up in the one pass it already makes:

| `theme.conf.user` key | `lib/theme.sh` source |
| --- | --- |
| `backgroundColor` | `theme_color background` |
| `tileColor` | `theme_color surface` (→ `lighter_background`) |
| `tileHighlightColor` | `theme_color highlight` (→ `selection`) |
| `parentTileColor` | `theme_color surface_muted` (→ `dark_background`) |
| `accentColor` | `theme_color accent` |
| `textColor` | `theme_color foreground` |
| `mutedTextColor` | `theme_color muted` |
| `errorColor` | `theme_color error` |
| `fontFamily` | `theme_font` |

`lib/posture.sh` QSettings-encodes every value before it writes the file. This matters for
`fontFamily`: fontconfig may return a family containing a comma, which must stay one quoted scalar
instead of becoming a QSettings list.

`lib/posture.sh`'s `posture_theme_conf_lines PARENT` resolves the theme keys, with `THEME_KIDS_HOME` set
to the *parent's* `$HOME` (`posture_parent_home`, a real `getent passwd` lookup — the account
already exists by the time posture writes anything) — not root's, since posture code runs as root
and there is no root-level theme to read (see "Ground truth" above). `posture_portal_conf_text`
appends them to the existing `parent=`/`kids=` `[General]` block, so
`posture_write_portal_conf` writes (and `omarchy-kids-assert`'s `portal-conf` lock re-asserts) the
whole file in one write, including the geometry below.

This runs at **provision and assert time**, not at kid-login time: whatever theme the parent was
running the moment `omarchy-kids-provision add`/`omarchy-kids-assert` last ran is what the portal
shows, until the next provision/assert. `omarchy-kids-assert` runs on every pacman transaction
(the `omarchy-kids.hook`) and at boot, so a parent who changes their Omarchy theme picks it up on
the portal after the next of those — not instantly, the same way `theme.conf.user`'s `parent=`/
`kids=` data already only refreshes on assert, not live.

### Portal geometry (#201)

The same writer exports `cornerRadius` and the normal/selected/focus control colors, border
widths, border alphas and fill alphas. The tile, inset avatar mask and password input use these
values; zero means square corners or no border. The selected name remains bold when a theme
disables all control borders, and the tile uses its selected fill independently of keyboard
focus. Avatars and parent files are unchanged.

`lib/theme-geometry.py` follows the installed Omarchy `shell/Commons/Style.qml`: rounding comes
from `hyprctl -j getoption decoration:rounding`, run as the recorded parent with a validated
owned compositor instance. This invokes fixed binaries without a login shell. If the parent is
offline, it reuses the last root-owned `theme.conf.user` radius only when the parent, home,
theme name and exact `hyprland.lua`/`shell.toml` content fingerprint still match. Without that
snapshot, one numeric `rounding = N` literal in the theme's Lua is usable; comments, expressions
and ambiguous multiple assignments are ignored. Lua is never executed. Unresolved dynamic Lua
falls back to Omarchy's installed default of zero; that fallback does not claim to reproduce a
custom live compositor setting. A subsequent assert while the parent is logged in captures it.

The helper reads `[controls]` and its legacy alias `[style]` from the parent's current
`shell.toml`, in document order, with the later section winning shared keys. Scalar widths
follow Style's rounding, and focus inherits omitted values from hover-cursor. Missing or
malformed data uses Style's defaults: normal width 1/fill 0.04, selected width 0/fill 0.18,
focus width 1/fill 0.08. Only finite values from 0 to 256 (geometry) or 0 to 1 (alpha) are
accepted; colors use Style's case-insensitive palette roles (including `text` and `transparent`)
or RGB/RGBA hex. Focus's `hover`, `hover-cursor` and `inherit` aliases resolve through hover's
color, as does an invalid focus color. Fill/border alpha replaces the color's own alpha, matching
Omarchy's `Util.alpha`. Invalid data never becomes QML or a shell command.
Per-side width lists and custom gradient controls are outside this scalar bridge and use its
documented defaults. The portal remains plain SDDM QtQuick; it does not import Quickshell.

## How a theme author gets Kids Mode for free

Nothing. A theme that already works with Omarchy — a `colors.toml` with the usual
`background`/`foreground`/`accent`/`color0..15` keys — already themes every Kids Mode surface
through this plumbing, with zero Kids Mode-specific work: `theme_color`/`KidsTheme.qml` read the
exact same file Omarchy's own tools do, with the exact same alias/fallback rules. A theme that
also defines the *semantic* names — `red`, `orange` (or `yellow`), `lighter_background`,
`dark_background`, `selection` — gets more accurate `error`/`warning`/tile-surface colors than one
that only ships the plain ANSI `colorN` set; both work.

## Issue #53: a kid's own desktop theme

Everything above keys colors off whichever theme is already sitting at `.../current/theme` —
it never asked how that directory got there. Before this issue every Kids Mode surface but the
portal/wizard/bar (the ones reading through `lib/theme.sh`'s `theme_color`/`theme_font`) stayed on
Omarchy's stock theme, because a fresh kid account's own `.../current/theme` is whatever
`omarchy-provision-user` happened to leave — never the parent's. This issue makes the kid's own
`current/theme` a real, matching copy, the same way `omarchy-theme-set` builds one for a live
session, applied non-interactively for another account as root.

**`bin/omarchy-theme-set` (omacom/omarchy@v4.0.2, fetched 2026-09 — full text read directly), the
mechanics `lib/theme.sh`'s `theme_apply_for` mirrors:**

- `OMARCHY_THEMES_PATH="$OMARCHY_PATH/themes"` — the system themes dir; `USER_THEMES_PATH="$HOME/.config/omarchy/themes"` — a second, per-user overlay this repo's own `theme_apply_for` deliberately does not read (see below).
- A fresh `NEXT_THEME_PATH` (`.../current/next-theme`) is populated with `cp -r "$OMARCHY_THEMES_PATH/$THEME_NAME/"*`, then the user-themes overlay if any.
- "Generate colors.toml from alacritty.toml if theme is missing colors.toml" via `omarchy-theme-colors-from-alacritty`.
- Swap in: `rm -rf "$CURRENT_THEME_PATH"; mv "$NEXT_THEME_PATH" "$CURRENT_THEME_PATH"`.
- `echo "$THEME_NAME" >"$HOME/.local/state/omarchy/current/theme.name"`.
- Only then, and only outside `OMARCHY_THEME_HEADLESS`/`OMARCHY_THEME_OFFLINE`, does it run `set_theme_background`/`shell_ipc` (an IPC call to a *live* `omarchy-shell`) and the `post_theme_commands` restart list (terminal, btop, GNOME settings, browser, VS Code, …).

**What `lib/theme.sh` adds for issue #53 (all new functions, no existing ones changed in shape):**

- `theme_account_home ACCOUNT` — resolves any account's `$HOME` (`getent passwd`, falling back to `OMARCHY_KIDS_HOME_ROOT`-prefixed `/home/<account>` for tests); `lib/posture.sh`'s `posture_parent_home` is now a one-line call to this (AGENTS.md's "no duplicated helpers" — the two were the same lookup for the parent specifically before this issue).
- `theme_current_name` — reads `.../current/theme.name` beside `theme_dir`, respecting `THEME_KIDS_HOME` the same way `theme_dir`/`theme_color` do. Empty, not an error, for an account that has never received a theme.
- `theme_list_installed` — every name under `$OMARCHY_PATH/themes` and the package's own `$KIDS_THEMES_DIR` (`/usr/share/omarchy-kids/themes-kids`), de-duplicated by name and sorted. The wizard's Desktop group and the panel's Desktop screen offer only these. `$KIDS_THEMES_DIR` is where the kid theme collection ships (`share/themes-kids/`, R-DESK; omacom/omarchy#12488), so those themes appear with no further wiring and an upstream theme of the same name wins. Provisioning also links each collection theme into the kid's own `~/.config/omarchy/themes/<name>` (a kid-owned symlink to the root-owned package copy), which is where Omarchy's own theme switcher reads user themes (`research/05`), so the kid's own `Super+Ctrl+Shift+Space` lists them too (T45).
- `bin/omarchy-kids-theme` (T45) — the kid-side picker: lists `theme_list_installed` and applies the choice through Omarchy's own `omarchy-theme-set`, run as the kid, so it writes their own theme and live-reloads their own shell. `--list`, `--set THEME` and `--dry-run` exist for tests; the level configs bind it on `Super+Ctrl+Shift+Space`, Omarchy's own theme chord, through `omarchy-launch-floating-terminal-with-presentation` so `gum`/`read` get a tty (T45). A pre-reader grid tile for it is still open.
- `theme_apply_for ACCOUNT NAME` — the non-interactive apply. `NAME` must be one of `theme_list_installed`'s own names (never a user-installed one — `USER_THEMES_PATH` above is not read at all, since the wizard/panel never offer such a name to begin with, and `omarchy-theme-set`'s own repo-theme file-filtering logic only exists to police that overlay). Otherwise the same shape: a fresh staging dir, the alacritty-derived `colors.toml` fallback, `rm -rf` + `mv` into `.../current/theme`, `theme.name` written beside it. No background selection, no `post_theme_commands` — nothing here has a live session to restart; see the next function.
- `theme_reload_if_live ACCOUNT` — best-effort only. If `pgrep -u ACCOUNT -x Hyprland` finds nothing, this is a no-op with one line explaining why (the theme is already correct on disk; the kid sees it at their next login, no restart needed). If a session *is* live, it runs the same `omarchy-shell shell applyTheme <base64 colors.toml> <base64 shell.toml>` IPC call `omarchy-theme-set`'s own `shell_ipc` makes, via `runuser -l ACCOUNT` so it reaches that account's own socket.

**Ownership: kid-owned, inside the kid's own home (T44).** `theme_apply_for` writes the whole
`.../current/theme` tree (and `theme.name`) as `ACCOUNT:ACCOUNT`, 0644 files / 0755 dirs. The theme
is a presentation **preference**, not an enforced lock: there is no security reason to root-own it
(a theme dir in the kid's own home is read only by the kid's own session), and the owner asked for
kids to be able to change their own theme. The `theme:<account>` assert lock
(`bin/omarchy-kids-assert`'s `theme_ok`/`theme_fix`, `docs/assert.md`) is **verify-only**: it refuses
a theme *name outside the offered set* (`theme_list_installed` — Omarchy's themes plus the package's
kid collection), and a planted non-regular file (a FIFO or symlink) fails rather than reading as
"no theme"; the read itself is `O_NOFOLLOW` + `O_NONBLOCK` + a regular-file check, so a planted FIFO
cannot hang the assert. `fix` applies the profile's default, or the parent's current theme when the
profile has no `theme` override; a kid's choice inside the set is valid and is never reverted. The kid-facing picker (`bin/omarchy-kids-theme`) is bound on Omarchy's own chord (T45). See `docs/phase1/SPEC-AMENDMENT-kid-themes.md`.

**Where this gets called:**

- `bin/omarchy-kids-provision add` — after the account, posture, and per-user setup are all in
  place, reads the parent's own `theme_current_name` (via `posture_parent_home`, the same lookup
  the portal writer already uses) and writes it with `"$CONF" set "$account" theme "$parent_theme"`
  — so `omarchy-kids-conf` (`cmd_set`, `unset` and `import`, below) and, as root, `assert`'s
  `theme_fix` are the only callers of `theme_apply_for`; provisioning never touches theme files
  directly. A parent who has never picked
  an Omarchy theme at all gets a warning line and the kid keeps the desktop's stock theme, same as
  before this issue.
- `bin/omarchy-kids-conf set <kid> theme <name>` — the per-kid key (Appendix B style,
  `docs/conf.md`): validates `<name>` is a real directory under `$OMARCHY_PATH/themes` or `$KIDS_THEMES_DIR` (the
  package's kid collection), writes the
  override, then calls `theme_apply_for` and `theme_reload_if_live` itself. The wizard's Advanced
  Desktop group and the panel's Desktop screen both write through this same command, never around
  it.
- `bin/omarchy-kids-assert`'s `theme:<account>` lock — verify-only (T44): re-applies the profile's default only when the kid's theme name is outside the offered set.

## Tests

- `test/shell.d/theme-test.sh` — `theme_dir`/`theme_color`/`theme_font` against a fixture
  `colors.toml` and the fallback path (real-shaped fake `omarchy-theme-color`/`fc-match` on a
  stub `PATH`, `THEME_KIDS_HOME` pointed at a scratch home); the issue #48 `OMARCHY_PATH`/`LANG`
  defaults; a broken theme tool never aborting a caller running under `set -euo pipefail`, logging
  exactly one line; issue #53's `theme_account_home`/`theme_current_name`/`theme_list_installed`/
  `theme_apply_for`/`theme_reload_if_live` against fixture theme dirs under a scratch
  `OMARCHY_PATH`.
- `test/shell.d/qml-theme-static-test.sh` — no `share/**/*.qml` file hardcodes a literal
  `#rrggbb`/`#rrggbbaa` color outside `share/qml/KidsTheme.qml` (its own fallback palette) and
  `share/sddm-theme/Main.qml` (the SDDM-engine exemption above) — and that those two files still
  actually carry hex, so the exemption list can't silently start checking nothing.
- `test/shell.d/portal-test.sh` — `posture_theme_conf_lines`/`posture_portal_conf_text` emit all
  nine keys, falling back correctly with no parent theme on disk, and — with a fixture `colors.
  toml` under a scratch parent `$HOME` plus a stub `omarchy-theme-color` — that the real values
  actually flow through `posture_write_portal_conf` end to end.
- `test/shell.d/conf-test.sh` — `theme`'s validation (a real installed name only), that `set`
  applies it via `theme_apply_for` and that `reset` leaves it alone.
- `test/shell.d/provision-test.sh` — `add` copies the parent's current fixture theme into the new
  kid's own `.../current/theme` and writes the `theme` override; the "parent has no theme yet"
  warning path leaves both untouched.
- `test/shell.d/assert-test.sh` — `theme_ok`/`theme_fix`: ok when they match, fixed when the kid's
  `theme.name` drifts from their profile, ok (nothing to fix) with no `theme` override at all.
- `test/shell.d/wizard-test.sh` / `test/shell.d/panel-test.sh` — the Desktop group's/screen's
  `theme` row: default is the parent's own current theme, picking a different installed name
  writes the override.

## What still needs the VM

Nothing here can be visually confirmed without a real Quickshell/Hyprland session and a real SDDM
greeter (`docs/levels.md`'s "Open questions" #5, `docs/portal.md`'s own "Ground truth"
section — neither has changed). Once in the VM: set at least two different Omarchy themes (a dark
one and `white`, say) and screenshot every surface under each — the launcher, the exit modal, ask,
the time toast and time's-up overlay, the plugins shelf, the Wi-Fi picker, the parent's bar widget,
and the SDDM portal after a provision/assert — to confirm colors actually follow the theme instead
of just compiling. Also confirm `share/bar/KidsModule.qml`'s `import qs.Commons` actually resolves
inside a real `omarchy-shell` plugin load (`docs/bar.md`'s "What is not confirmed" section), and
that `Style.selectedFillFor`'s three-argument call really matches what a live `Style.qml` expects.

## Verified live (2026-09-03, QEMU test VM)

Under tokyo-night and catppuccin-latte the portal (theme.conf.user) and the wizard (gum flags
from `lib/theme.sh`) took each theme's colours. Kid surfaces resolve the kid's own per-user
theme, which provisioning leaves at Omarchy's default, so they looked the same under both:
issue #53 makes a kid inherit the parent's theme at provision time and adds a theme cell. One
packaging fact: Quickshell resolves QML types only inside the shell's own directory, so
`KidsTheme.qml` is installed beside every standalone surface rather than imported from
`share/qml`.

## Source header (moved from `lib/theme.sh`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
lib/theme.sh — resolves Omarchy's per-theme colors and font the exact
way Omarchy's own tools do, so every Kids Mode surface (the wizard/panel
TUI, the SDDM portal's theme.conf.user) looks like the rest of the
machine under whatever theme the parent picked. Not meant to be
executed directly; source it from a command or from lib/tui.sh.

============================== Ground truth ================================
Fetched and read directly from omacom/omarchy at tag v4.0.2, 2026-09:

  - bin/omarchy-theme-color: "Resolve semantic colors from an Omarchy
    theme colors.toml" — the same tool docs/tui.md already cited this
    repo's own wizard through ("the same tool Omarchy's own templates,
    OSC sequences, and previews resolve colors through"). Defaults to
    $HOME/.local/state/omarchy/current/theme/colors.toml, or --file
    <path>. Resolves a semantic key (background, foreground, accent,
    muted, red, green, yellow, blue, magenta/purple, cyan, orange,
    brown, dark_background, darker_background, lighter_background,
    dark_foreground, light_foreground, bright_foreground, selection,
    cursor, mode/theme_type, colorN, and every bright_* variant),
    falling back through legacy color0..15/short-name aliases and
    derived shades when a theme only defines part of the palette.
    Omarchy's own palette has no "error"/"warning" semantic key of its
    own — theme_color below maps those to "red" and "orange" (orange
    itself falls back to yellow when a theme doesn't define it,
    omarchy-theme-color's own alias_theme_color call), the same colors
    Omarchy's generated app configs use for error/warning states.
  - bin/omarchy-theme-set: $HOME/.local/state/omarchy/current/theme is a
    real directory (not a symlink), rebuilt whole on every
    `omarchy-theme-set` — never $HOME/.config/omarchy/current/theme,
    which does not exist on this stack.
  - bin/omarchy-theme-current: the theme's own display name lives beside
    it, in .../current/theme.name (one line, no [General] wrapper).
  - shell/Commons/Style.qml's fontFamily/resolveFontFamily: the shell's
    own font is always the fontconfig alias "monospace", resolved via
    `fc-match -f '%{family[0]}' monospace` — never read from colors.toml
    (theme Lua/toml never sets a font family; `omarchy font set` rewrites
    ~/.config/fontconfig/fonts.conf instead). theme_font below runs the
    exact same command.

There is no *system-wide* (root-level) current theme anywhere in
Omarchy 4.0.2 — every path above is $HOME-relative, because Omarchy is a
single-user desktop. THEME_KIDS_HOME (below) is this file's own way to
point that resolution at another account's $HOME — the parent's, when a
root-owned caller (lib/posture.sh, provisioning the portal before any
user has ever logged in) needs the parent's theme rather than root's.
==============================================================================

Live finding (issue #48, 2026-09): running a Kids Mode command from a
shell without Omarchy's own session environment sourced (no interactive
login through Hyprland — an SSH session, a bare `unshare`, a CI runner)
leaves $OMARCHY_PATH unset, and `omarchy-theme-color` (and Omarchy's
other bin/omarchy-* tools generally) depend on it being set to find
their own installed files, dying with "OMARCHY_PATH is not set" instead
of just failing the one color lookup. Two defenses, applied by
_theme_kids_env_defaults, called from every function below that reads
$OMARCHY_PATH or is about to run an Omarchy tool -- not the moment this
file is sourced (review 2.7: sourcing a library must never change the
caller's environment):
  - OMARCHY_PATH defaults to /usr/share/omarchy (where the omarchy
    package installs itself) when unset, so a real Omarchy tool that
    needs it to find sibling files still can, even outside a full
    session.
  - LANG defaults to C.UTF-8 when unset or the plain "C" locale: gum's
    own box-drawing characters (lib/tui.sh's bordered header) need a
    UTF-8 locale to render, not just to look right.
A theme tool that still fails after that (missing entirely, or dies for
some other reason) never aborts the caller either way — see
_theme_kids_tool_ready below — it just falls back to this file's own
palette, with one log line, not silently and not by crashing.
```

After #53, same VM: `omarchy-kids-conf set kid-cy theme catppuccin-latte` rewrote the kid's
current theme the way omarchy-theme-set does, and at the next login the launcher and the exit
modal rendered in that theme's light palette with its blue accent; setting it back to
tokyo-night restored the dark look. New kids start with the parent's theme.

## Derived colours

`share/qml/KidsTheme.qml` derives every surface shade from the theme's background so a theme this
repo has never seen still picks the readable side. `isLight` is the background's Rec. 709 relative
luminance over 0.5. `shade(c, delta)` moves HSL lightness by `delta`, clamped, leaving hue and
saturation alone, so a themed colour stays itself; `Qt.lighter()`/`Qt.darker()` scale HSV value
and move less the lighter a colour already is. `raise(c, light, dark)` is the one direction rule:
darken a little on a light background, lighten more on a dark one, because dark UIs need more
contrast headroom for a "raised" surface. From those: `inputFill` (6% darker on light, 12% lighter
on dark; the per-file `Qt.darker(background, 1.3)` read as a disabled grey block on
catppuccin-latte, issue #57's live finding), `cardFill` (4% / 8%, the old
`Qt.lighter(background, 1.6)`), `tileFill` (9% / 18%, the old `Qt.lighter(background, 2.4)`),
`errorFill` (the old `Qt.darker(error, 4)`, unchanged), and `dim` (black at 45% on dark; the
background itself at 55% on light, because black at 60% crushed a light desktop before the card
was drawn). A static test keeps literal-factor `Qt.lighter()`/`Qt.darker()` calls out of every
other QML file.
