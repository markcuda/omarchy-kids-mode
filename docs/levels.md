# Levels: the root-owned Hyprland configs and the Level 1 launcher (R-DESK, Appendix E)

## Desktop defaults (Mark's direction, #200)

The two kid modes are **App grid** (Level 1) and **Desktop** (Level 3 — the real Omarchy
desktop, menu-trimmed). Ages 3–5 and 6–8 default to App grid; 9–12 and 13+ default to Desktop.
This changes presentation and window controls, not the band's web, Wi-Fi, app, screen-time or
terminal policy values. The Desktop row in the parent's Advanced permissions checklist and
Desktop settings writes the same `level` override (Grid stores `level = 1`, Desktop stores
`level = 3`). It survives a band change and applies at next login.

The old **Simplified desktop** (Level 2 — a themed background layer over the owned Kids
launcher's searchable picker) is retired: no band defaults to it and no picker offers it, but
`L2.lua` and its launcher stay in the tree so a profile that already names `level = 2` still
starts. The Desktop mode is the stock Omarchy desktop with its menu trimmed of
Install/Update/Setup (R-DESK-4), so a kid learns the same Super keys a parent uses.

**What each mode does not do.** The app allow-list, the hide/extra-app rows and a `web = none` band
are the Kids launcher's (Grid): a Desktop kid starts apps from Omarchy's own menu search and can open
Chromium, so those rows neither restrict nor reach them -- keep a child on the Grid if you need the
allow-list enforced or the browser hidden. The "What my grown-ups can see" screen (R-DATA-3) is the
reverse: a Desktop kid gets it as a provisioning-installed `.desktop` entry, and the Grid has no tile
for it (the tile opens a terminal, which R-DESK-3 forbids on the Grid). The child's account, screen
time, the rendered web *policy* (safe search, safe DNS) and every lock are the same in both modes;
the per-kid `web = none` **is not**.

Every level also turns off Hyprland's own update-news and donation popups
(`ecosystem.no_update_news` and `ecosystem.no_donation_nag`): the news dialog carries an outbound
link, and `xdg-open` would open it in the browser outside the kids launcher (R-DESK-1, I-6). A
kid's session never shows either.

Every level imports the environment into `systemd --user` and the D-Bus activation environment
(`systemctl --user import-environment` and `dbus-update-activation-environment --systemd --all`)
before `omarchy-kids-session-start`. Without it the kid's user services and portals come up with an
empty environment, which is what killed a D-Bus-activated app at Level 1; Level 3 always did this,
Levels 1 and 2 now do too.

The desktop layer and picker are sibling windows under the existing launcher's ShellRoot;
the background takes no keyboard focus. `launcher-ctl show` writes the existing control
file as well as focusing the grid, so a hidden picker can become visible again. Runtime
rendering, focus and window tiling require the named installed scenario; unit tests alone
do not verify those compositor behaviors.


What each level binds, how the Level 1/2 big-tile launcher gets its tiles, and how to check any
of this on the test laptop's VM.

Live status (2026-09-21, try-omarchy aarch64 VM, real SDDM logins; see
`docs/dogfood-2026-09-21.md`): **Levels 1, 2 and 3 have all run against a real Hyprland and
Quickshell.** Level 1 verified the fullscreen grid, keyboard navigation, launch, the exit modal,
and the portal after logout; Level 2 the desktop hint layer and the windowed searchable picker;
Level 3 the stock Omarchy desktop with the menu extension's `when: "false"` rows hiding
Install/Remove/Update/Setup (only Apps/Learn/Trigger/Style/About — the `l3-menu.png` capture is
kept on the Mac, not in the repo), no first-run provisioning, and two apps tiled side by side. Still open from the checklist below:
every `share/wifi/shell.qml` claim (unchanged), the owner question whether Level 3 keeps the
file-manager bind under `menu=trimmed`, and Level 2's own two-app tiling and `Super+K` cheat sheet
(the 2026-09-21 two-app and cheat-sheet checks were at Level 3, under stock bindings).

## The files

| File | What it is |
| --- | --- |
| `share/hyprland/L1.lua`, `L2.lua`, `L3.lua` | Root-owned Hyprland configs, one per level (R-DESK-1, R-DESK-3) |
| `share/hyprland/band-3-5.lua`, `band-6-8.lua` | Cursor/gap/scale overlays, loaded by whichever level file is active when `OMARCHY_KIDS_BAND` matches |
| `share/launcher/shell.qml` | The Level 1/2 big-tile launcher (Quickshell/QtQuick), R-DESK-5 |
| `share/launcher/gridnav.js` | Pure column/index math shared by `shell.qml`'s key navigation and its GridView layout (issue #43) |
| `bin/omarchy-kids-session-start` | Runs once per session from each level file's `exec-once`; reads the validated manifest and starts the right surface for the level |
| `bin/omarchy-kids-launcher-ctl` | What the Hyprland binds call to show/activate the launcher, so the Lua files don't need Quickshell IPC details |
| `bin/omarchy-kids-exit`, `bin/omarchy-kids-super-tap`, `share/exit-modal/shell.qml` | The exit modal for Super+Shift+K and the triple-tap (R-EXIT-1); see `docs/exit.md` |
| `share/menu/omarchy-kids-trimmed.jsonc` | The omarchy-menu user extension (verified merge shape) that hides Install/Remove/Update/Setup on a `menu=trimmed` kid's Level 3 stock desktop (R-DESK-4) |

Deployment (R-DESK-1): the package installs these under `/usr/share/omarchy-kids/hyprland/` and
`/usr/share/omarchy-kids/launcher/`; provisioning copies or links them to
`/etc/omarchy-kids/hyprland/`. `omarchy-kids-session` reads the caller-bound manifest, exports the
level and band before Hyprland parses its config, and execs:

```text
Hyprland --config /etc/omarchy-kids/hyprland/L<level>.lua
```text

`bin/omarchy-kids-session-start` reads the same validated manifest through
`omarchy-kids-session --manifest`. It derives the level surface, theme, web mode, tile list,
budget, and lights-out values from that one document; it does not re-read the profile or scan
desktop files. This keeps the level overlay and the launcher on the same root-owned snapshot.

## What each level binds (Appendix E)

**Grid (Level 1).** `Super+Home` show the launcher · `Super+Return` open the highlighted tile ·
`Super+Q` close the focused window · `Super+Shift+K` the exit overlay, and a bare `Super` tap
three times within 1.5s does the same (`omarchy-kids-exit`, `omarchy-kids-super-tap`,
`docs/exit.md`) · `Super+Shift+W` the Wi-Fi picker (R-WIFI-1..2; the command refuses unless the
band is `helper`) · the five standard volume/brightness media keys. Nothing else — no defaults, no
`require("default.hypr.bindings.*")`. No theme picker: it needs a terminal, and the Grid has none
(R-DESK-3). Every window is forced fullscreen
(`o.window(".*", { fullscreen = true })`). `test/shell.d/levels-test.sh` greps for exactly this
set; nothing more, nothing less.

**Retired (Level 2).** The Simplified desktop. Everything Level 1 binds, plus `Super+arrows` to focus a window,
`Super+Shift+arrows` to swap it, `Super+K` for Omarchy's own keybindings cheat sheet
(`omarchy-menu-keybindings`; verified live 2026-09-21 that this does nothing for a kid -- the
command fails without `$OMARCHY_PATH` -- so the bind is inert), and `Super+Space` aliased onto the same launcher as
`Super+Home`. The "50/50 dwindle split" Appendix E asks for isn't extra config here — it's
`default.hypr.looknfeel`'s own `general.layout = "dwindle"` / `dwindle.preserve_split = true`,
which Level 2 requires (see below) and which already gives that behavior for two tiled windows.

**Desktop (Level 3).** `Super+Ctrl+Shift+Space` is the theme picker (`omarchy-launch-floating-terminal-with-presentation omarchy-kids-theme`, bound over Omarchy's own). The stock Omarchy modules required individually — bindings (media, clipboard, tiling,
utilities, voxtype, optional applications), envs, looknfeel, input, windows — but **not** the
`default.hypr.omarchy` umbrella, which also pulls in `default.hypr.autostart` and its per-session
`omarchy-provision-first-run` (`fix/level3-no-parent-autostart`; the session's own start hook runs
the shell instead). Then `hl.unbind("SUPER + RETURN")` — under this config `hyprctl binds` lists
no such bind (L3.lua's header); that does not separate "stock never binds it" from "stock binds it
and the unbind worked" — and `o.bind("SUPER + SHIFT + K", ...)` for the exit overlay. The old worry about `omarchy-sudo-passwordless` was the autostart's provisioning,
which this file no longer requires; whether a keybind of that name exists at all is still open
(item 2).

## What Level 1/2 do and don't require from Omarchy's defaults (I-3)

Level 1 must not depend on anything in the kid's home. Reading Omarchy's own
`default.hypr.looknfeel` and `default.hypr.input` end to end (the two files this repo had a copy
of to check against), neither one reaches into a home directory or requires anything else — they
only call `hl.config`/`hl.curve`/`hl.animation` (looknfeel) or read `/etc/vconsole.conf`, a
system file (input). Both are required directly by L1.lua and L2.lua.

`default.hypr.envs`, by contrast, requires `default.hypr.paths` and sets `XCOMPOSEFILE` to
`paths.home .. "/.XCompose"` — a path inside the logged-in account's home. That's not
enforcement, but I-3 is written broadly enough ("nothing in `~` enforces anything") that this
repo treats "nothing in `~` should matter at all" as the safer reading. L1.lua and L2.lua set the
handful of Wayland/toolkit envs a session actually needs directly instead (copied from
`default.hypr.envs`'s own list, minus the home-dependent lines).

`default.hypr.windows` and `hypr.monitors` are not required either: `windows.lua` requires
`default.hypr.apps` (not available to inspect while writing this, and not relevant to a
fullscreen-only kiosk), and `hypr.monitors` is the *user's own* `~/.config/hypr/monitors.lua` —
exactly the home file I-3 rules out. Levels 1 and 2 set no explicit monitor configuration; they
rely on Hyprland's own auto-detection.

## The launcher's tile list

At provision and assert time, `lib/launcher-map.sh` resolves the kid's effective `allowlist`
against `share/packs/<band>.toml` and writes the execution authority to
`/etc/omarchy-kids/launchers/<account>.json` (root:root, mode 0644). Desktop entries are read
only from the system application directories; their `Exec=` line is parsed then, field codes are
removed, and the executable is resolved to an absolute path. A pack id with no desktop entry may
use the same root-time resolution for an absolute executable. The map contains:

```json
{
  "account": "kid-ada",
  "band": "6-8",
  "level": "1",
  "tiles": [
    { "id": "tuxpaint", "label": "Tux Paint", "icon": "tuxpaint", "pkg": "tuxpaint",
      "installed": true, "argv": ["/usr/bin/tuxpaint", "--file"] }
  ]
}
```text

The root-owned session manifest at `/etc/omarchy-kids/sessions/<account>.json` is the launcher's
only tile document. Each tile carries its `id`, `label`, `icon`, `installed` state, and fixed
absolute `argv`; unavailable tiles carry `installed: false` and an empty argv. The launcher reads
the validated document through `omarchy-kids-session --manifest`, so a kid-writable runtime file
cannot add, remove, relabel, or activate a tile.

If the kid's `web` key isn't `none` **and** `/etc/chromium/policies/managed/omarchy-kids-<band>.json`
is readable, manifest construction appends a `chromium` tile with the fixed argv
`["/usr/bin/omarchy-kids-web", "launch"]` (R-WEB-4). The Level 1 `more-apps` tile likewise uses
fixed argv for `/usr/bin/quickshell` and the packaged plugins shelf, with the band supplied as an
environment argument. No tile is evaluated by a shell.

**Installed/missing tiles (issue #42, I-6).** Every pack/`apps.extra` tile in the manifest also
carries `installed: true|false` — a matched `.desktop` file, or (the bare-command fallback)
`command -v` on the resolved executable, **never `pacman -Q`**, so this works the same for a pack app,
an `apps.extra` id with no package at all, or any future non-pacman app source. By default
(`apps.show_missing=no`, docs/conf.md) a missing app's tile is left out of the JSON entirely, with
one log line naming why (`$RUN/session-<uid>.log`) — the live bug this issue fixes was a tile that
rendered but did nothing on Enter. With `apps.show_missing=yes` the tile is kept instead, with
`caption` set to `"installing..."` if the app's package is sitting in
`bin/omarchy-kids-apps`' pending install queue (`OMARCHY_KIDS_ROOT/var/lib/omarchy-kids/apps-queue`,
read here, never written) or `"not installed yet"` otherwise; `share/launcher/shell.qml` renders
that tile greyed and the caption underneath the label, and refuses to launch it on Enter
(`installed === false`, checked before `launchCurrent()` runs anything). An installed tile always
carries `installed: true` and an empty `caption`. The synthetic `chromium`/`more-apps`/`kids-data`
tiles are built into the manifest with fixed argv.

`share/launcher/shell.qml` reads the manifest through the fixed `omarchy-kids-session --manifest`
command and polls only the small control file (`/run/user/<uid>/omarchy-kids/launcher-control`)
that `bin/omarchy-kids-launcher-ctl` writes to on `Super+Return`. It renders the tiles as a grid
with keyboard-only navigation (arrows move the highlight, Return/Enter launches, Escape is
swallowed and does nothing).

**The grid's layout (issue #54).** Live at 1280x800 the grid used to be anchored top-left,
full-width, with a hardcoded 160px cell: two tiles sat in a loose row with the rest of the screen
empty, and ten tiles only filled the top third, with names but no icons. Now:

- The grid is centred horizontally and anchored to the top with a shared `margin` (56px) —
  exactly as many columns wide as it has cells to show (never wider than there are tiles), so two
  tiles sit in a small centred block instead of hugging the left edge of a full-width row.
- Tile (cell) size is derived from the screen width, not hardcoded: whatever width fits
  `targetColumns` (5) tiles in the space left after `margin` on each side, floored at
  `minTileWidth` (160px) — five per row at 1280 wide, bigger tiles (not more columns) on a wider
  screen, and fewer than five per row if the screen is narrower than that floor allows.
- Each tile shows the app's real icon above its label: `Icon=` from the matched `.desktop` file
  (written into the tile JSON's `icon` field by this script, verbatim, no resolution done here)
  is resolved through the active icon theme by `share/launcher/shell.qml`'s `iconSource()`, using
  `Quickshell.iconPath(name, true)` — the same call the real Omarchy shell's own launcher makes
  (`shell/services/AppLibrary.qml`'s `iconSource()`, `omacom/omarchy@v4.0.2`, commit
  `346e69e1cec6c4e8924531874af6ba010a1bc99e`). When nothing resolves (no `Icon=`, a name the icon
  theme doesn't have, `apps.extra`/`more-apps`/`kids-data` tiles that carry no icon at all), the
  tile shows a rounded initial in the theme accent colour instead of a broken-image glyph or
  empty space (I-6: still an honest, intentional-looking tile).
- Labels are set in the theme font (`theme.fontFamily`, `docs/theming.md`) rather than the Qt
  platform default; the highlight ring on the current tile is the theme accent colour
  (`theme.accent`); the greyed, captioned look for an `installed: false` tile (issue #42) is
  unchanged.
- The clock stays top-right (`root.margin` top/right inset), in its own band above the grid: the
  grid's top margin is `root.margin + clockText.height + root.margin` (clock bottom + one more
  margin), not the same flat `root.margin` the clock uses. **Live review fix**: a shared flat
  `root.margin` for both put the clock and the grid in the same horizontal band, and a live
  1280x800/nine-tile screenshot showed the clock overlapping the fifth tile of row one — a
  centred five-wide grid reaches close enough to the right edge to pass under a top-right clock
  at any width past some threshold. Giving the clock its own band removes that threshold
  entirely, regardless of tile count or screen width.

`test/shell.d/launcher-grid-test.sh` statically checks all of the above against `shell.qml`'s
source, including that activation passes the root-map argv list directly to Quickshell rather than
evaluating a runtime string — see that file's own header for exactly what it can and can't check
without a real Quickshell.

**Issue #43: key navigation must use the layout's own column count.** Seen live in the VM with
ten tiles rendered five per row: Down from row1/col4 highlighted row2/col3 instead of row2/col4,
and Right from row2/col3 didn't move at all — the key navigation had its own hardcoded
`columns: 4` instead of reading whatever GridView actually laid out. Fixed by moving the index
math into `share/launcher/gridnav.js`, a small pure-JS module `shell.qml` imports
(`import "gridnav.js" as GridNav`), and binding `columns` to
`GridNav.columnsFor(grid.width, grid.cellWidth)` — the same `width`/`cellWidth` GridView itself
lays tiles out from, so the two can't drift apart again. Left/Right move the highlight by ±1 and
wrap to the previous/next row on their own (tiles are laid out row-major, so index±1 already
crosses a row boundary correctly), clamping only at the very first/last tile rather than wrapping
all the way around the grid. Up/Down move by the column count and clamp at the top/bottom edge,
including a ragged last row. `test/shell.d/launcher-grid-test.sh` checks `gridnav.js`'s index math
directly with `node` (skipped if `node` isn't available) and greps `shell.qml` for the wiring
(the import, the `columns` binding, and each `Keys.on*Pressed` calling into `GridNav`) — see that
file's own header for exactly what it can and can't check without a real Quickshell/QtQuick to
run the file against.

## Open questions / what could not be verified without Hyprland or Quickshell

Live status (2026-09-21, `docs/dogfood-2026-09-21.md`): **item 5 is answered for Levels 1 and 2,
and item 8's column model holds on a real surface.** Both configs loaded on a real Hyprland with no
parse errors; the launcher read its manifest and control file, launched apps, moved the highlight
with the arrows and rendered real icons through `Quickshell.iconPath()`; the Level 2 picker and
desktop layer rendered as sibling Quickshell windows (the `PanelWindow`/desktop-mode shapes are
real API). The live output there is 876x491 and the grid drew exactly the four columns `gridnav.js`
computes for that width. The Level 3 pass then ran the stock desktop itself (live status above).
Still open: item 2 (whether an `omarchy-sudo-passwordless` keybind exists at all), item 4
(`hl.unbind`'s signature, Level 3 only), and item 8's exact per-row layout on unusual geometries.
Item 1 is checked and item 6 is verified; item 5 was confirmed on 2026-09-03. Items 3 and 7 were
settled on 2026-09-26 by reading Omarchy's own shipped configs on the VM (`fullscreen = true` is
what `default/hypr/apps/system.lua` writes; the volume/brightness wrappers are
`default/hypr/bindings/media.lua`'s) — confirmed against the real install, though still not
*exercised* live in a kid session.

This repo had two of Omarchy's real `default.hypr.bindings.*` files to check syntax against
(`bindings-tiling.lua`, `bindings-utilities.lua`) and a handful of other `default.hypr.*` files,
but no live Hyprland, no Quickshell, and no `default.hypr.bindings.applications` while it was
written. The 2026-09-21 VM pass then answered several items below; what remains needs a real box or
another look:

1. **The exact Level 3 terminal-launching bind(s) -- checked 2026-09-21.** `omarchy-menu-keybindings`
   on the VM lists the stock L3 binds, including `SUPER + SHIFT + RETURN` (Browser) and
   `SUPER + SHIFT + F` (File manager); only terminal-launching binds are trimmed under
   `menu=trimmed` (Appendix E). L3.lua still unbinds `SUPER + RETURN`: its header records that
   under L3.lua `hyprctl binds` lists no such bind, which does not separate "stock never binds it"
   from "stock binds it and the unbind worked". Try `Super+Return` and confirm nothing launches.
   Whether the file-manager bind should also go under `menu=trimmed` is an owner question
   (`docs/dogfood-2026-09-21.md`).
2. **`omarchy-sudo-passwordless`.** Deliberately not touched. The worry that a Level 3 session
   re-runs Omarchy's first-run provisioning -- a likely home for such a convenience -- is answered:
   L3.lua no longer requires `default.hypr.omarchy` (`fix/level3-no-parent-autostart`), and the
   2026-09-21 Level 3 pass saw no `omarchy-provision-first-run`, `udiskie` or migration line in
   the kid's journal. Whether an `omarchy-sudo-passwordless` keybind exists at all remains
   unconfirmed on a real box.
When this checklist was first written the repo had two of Omarchy's real
`default.hypr.bindings.*` files to check syntax against (`bindings-tiling.lua`,
`bindings-utilities.lua`) and a handful of other `default.hypr.*` files, but no live Hyprland and
no `default.hypr.bindings.applications` (where terminal launching and, per Appendix E,
"omarchy-sudo-passwordless" are presumably bound). Levels 1 and 2 have since run live (see the
live-status note above); what is left here is the Level 3 set, which needs the VM or a real
Omarchy 4.0.2 box to close out:

1. **The exact Level 3 terminal-launching bind(s).** L3.lua unbinds `SUPER + RETURN` on the
   near-universal Hyprland/tiling-WM convention that Super+Return opens a terminal — not
   confirmed against Omarchy's actual bindings. Run `omarchy-menu-keybindings` or `hyprctl binds`
   on a real box and correct the list in `share/hyprland/L3.lua` (there may be more than one
   terminal-launching bind, e.g. a second terminal or a file manager, also gated by
   `menu=trimmed`).
2. **`omarchy-sudo-passwordless` -- answered 2026-09-21.** It is a menu row, not a keybind
   (`omarchy-menu`'s `setup.security.passwordless-sudo`), hidden under the trimmed menu and refused
   for a kid; it was never a bind to strip. L3.lua does not load `default.hypr.omarchy`, so
   `omarchy-provision-first-run` is not re-run for a kid either
   (`docs/phase1/SPEC-AMENDMENT-two-kid-modes.md`).
3. **`fullscreen = true` as a windowrule -- resolved 2026-09-26, from Omarchy's own files.**
   It is the right shape: `default/hypr/windows.lua` writes `fullscreen = false` as the default
   boolean and `default/hypr/apps/system.lua:35` uses
   `o.window("org.omarchy.screensaver", { fullscreen = true })` for the screensaver, both read off
   the try-omarchy VM's real 4.0.2 install. `{ fullscreen = "1" }` is not what Omarchy itself
   writes. Still true that no live pass has *seen* a non-self-fullscreening client under our rule
   (the launcher fullscreens itself via `share/launcher/shell.qml`'s `Window.FullScreen`, and
   GCompris asks for `fullscreen: 2` of its own accord) — `hyprctl clients` would settle that.
4. **`hl.unbind`'s signature.** Assumed to take the same key-combo string `o.bind`'s first
   argument does. `bindings-utilities.lua`'s comment on its selection-layer binds describes
   unbinding by key as risky only because it can strip a *user's own* rebinding from their
   personal `~/.config/hypr` files — L3.lua has no such layer (R-DESK-6), so that risk doesn't
   apply here, but the call signature itself is still unverified. The L3 config loaded live on
   2026-09-21 without an error from it; whether the unbind actually removes a bind remains
   unshown.
5. **Historical launcher API questions (predating #200).** #200 uses the documented
   `Process.startDetached()` lifecycle, a sibling background `PanelWindow`, and Hyprland
   0.56 `hyprctl dispatch 'hl.dsp.focus({window=...})'` for the picker. The old fullscreen/focuswindow
   assumptions below apply only to the original implementation. No Quickshell documentation or source was
   available while writing it, so every Quickshell-specific type/property (as opposed to plain
   QtQuick ones) was a best-effort guess:
   - **`Window` over `PanelWindow`/`WlrLayershell`.** The issue that asked for this file suggested
     a layer-shell panel; this uses a plain QtQuick `Window` instead, fullscreened by the same
     windowrule as every other Level 1/2 app (`share/hyprland/L1.lua`'s
     `o.window(".*", { fullscreen = true })`) and reachable by `hyprctl dispatch focuswindow`
     (`bin/omarchy-kids-launcher-ctl`) — sidesteps needing Quickshell's IPC system at the cost of
     not being a "real" always-on-top overlay. The "fullscreened by the same windowrule" sentence
     above was never accurate: the launcher has set `visibility: Window.FullScreen` since it was
     written (`7d5ddeb`), so the windowrule is not needed to fullscreen it (item 3). If Quickshell
     requires `PanelWindow` for anything it loads, or an always-on-top overlay is wanted after
     all, this is the piece to redo.
   - **`Quickshell.Io.FileView`** — whether `reload()`/`text()` exist with those names, and how a
     missing file is reported (assumed to throw or return empty, not crash the shell).
   - **`Quickshell.Io.Process`** — whether `command`/`running` are real properties and
     start-on-`running=true` is the right lifecycle.
   - **`Quickshell.iconPath()`** (issue #54) is confirmed real — `shell/services/AppLibrary.qml`'s
     `iconSource()` at omacom/omarchy@v4.0.2 calls it the same way — but the rendered size/DPI of
     the returned source still needs a real Quickshell to confirm.
   Confirmed live 2026-09-03 (see "Verified live" below): the launcher renders, arrow/Enter
   navigation and launching work. Still open: whether the plain-`Window` choice above is worth
   revisiting for a true always-on-top guarantee.
6. **`omarchy-kids-trimmed.jsonc`'s schema -- VERIFIED 2026-09-21.** omarchy-menu is a Quickshell
   plugin that merges the user extension at `$HOME/.config/omarchy/extensions/omarchy-menu.jsonc`
   into the stock entries by id, field by field (`MenuModel.mergeMenuSources`), and hides an entry
   whose `when:` expression is false; the file now uses that shape (the same id with
   `when: "false"`), not the old guessed "hide" list. `fix/level3-menu-trim` rewrote it and the
   live Level 3 pass saw only Apps/Learn/Trigger/Style/About. R-DESK-4 also holds at the
   keybinding level independently: Level 1 runs no bar/shell at all, and Level 2 never binds
   anything to `"omarchy-menu toggle"` (`Super+Space` is rebound to the kids' own launcher), so
   there is no keyboard path to the untrimmed menu at either level. The trim is presentation, not
   a lock: the kid's own account still refuses every action behind a hidden row (I-3).
7. **Volume/brightness keys use Omarchy's own wrappers -- swapped in 2026-09-26.** The reference
   material was simply missing `default/hypr/bindings/media.lua`, which exists on the real 4.0.2
   install and binds exactly these five keys to `omarchy-audio-output-volume raise|lower|mute-toggle`
   and `omarchy-brightness-display +5%|5%-`, with `{ locked = true, repeating = true }`. L1 and L2
   now mirror it, so a kid gets the same on-screen feedback, volume ceiling and brightness
   rounding as the parent instead of raw `wpctl`/`brightnessctl` (and `brightnessctl set +5%`
   rounds to nothing on a display with few steps). `levels-test.sh` holds both files to the
   wrapper names.
8. **GridView's real column layout (issue #43) -- holds at the tested sizes.**
   `share/launcher/gridnav.js`'s `columnsFor()` assumes GridView lays tiles out at exactly
   `Math.floor(grid.width / grid.cellWidth)` per row. The 2026-09-21 pass drew exactly its four
   columns at the VM's 876x491, and 2026-09-03 saw ten tiles at five per row at 1280x800, so the
   model matches the real surface at those sizes; unusual geometries are still unchecked. If the
   real layout disagrees, `columnsFor()` is the one place to correct — both the GridView and the
   key navigation read that same value, so a fix there fixes both at once instead of two places
   drifting apart again.

## Verify in the VM

With the package installed (or `share/hyprland/`, `share/launcher/`, and the `bin/omarchy-kids-*`
scripts copied to their spec-required paths and made root-owned):

1. From a spare tty (or the omarchy-kids session entry, once `omarchy-kids-session` is built):
   `Hyprland --config /etc/omarchy-kids/hyprland/L1.lua`.
2. Confirm the launcher appears fullscreen with tiles from the validated
   `/etc/omarchy-kids/sessions/<account>.json` manifest, that arrows move the highlight, Return
   launches, and Escape does nothing. Confirm that `/run/user/<uid>/omarchy-kids` contains no
   launcher JSON. With a full row of tiles,
   confirm Right/Left/Up/Down move to the visually adjacent tile (issue #43) — in particular,
   Right/Left at a row's end wrap to the next/previous row rather than holding still, except at
   the very first/last tile, which clamp; Up/Down clamp at the top/bottom edge. Confirm Enter
   launches whatever tile is highlighted after each of those moves, checkable via
   `$XDG_RUNTIME_DIR/omarchy-kids/launches.log`.
3. `Super+Home` and `Super+Space` (Level 2) bring the launcher back after opening an app;
   `Super+Enter` opens whatever tile is highlighted without needing the launcher already focused.
4. `Super+Q` closes the focused app; `Super+Shift+K` opens the exit modal (`docs/exit.md`).
5. Repeat for `L2.lua` (focus/swap/cheat sheet) and `L3.lua` (real Omarchy desktop minus the
   terminal bind — try `Super+Return` and confirm nothing launches; `hyprctl binds` under L3.lua
   lists no such bind, which is the expected outcome either way).
6. Confirm the manifest-selected band overlay makes the cursor visibly larger and GTK/Qt apps
   render bigger.
7. Issue #42: on a box where pack apps are missing, confirm the manifest marks them
   `installed: false`; the launcher shows them greyed with a "not installed yet" caption and Enter
   does nothing. After installation and a manifest rebuild, confirm the tile has fixed argv and
   launches directly.

Everything above is run from `bash test/shell.d/levels-test.sh` first where it can be
(grep-based binding checks, `luac -p` if available, `bin/omarchy-kids-session-start`'s manifest
startup against a scratch profile), plus `bash test/shell.d/launcher-grid-test.sh` for
`gridnav.js`'s index math (`node`, if available) and its wiring into `shell.qml` — the VM is only
for what a test file on a laptop with no Hyprland or Quickshell cannot check, chiefly step 2's
actual on-screen tile adjacency and issue #43's GridView column-count assumption (open question 8
above).

## Verified live (2026-09-03, QEMU test VM)

With ten tiles drawn five per row, eight Right presses from the first tile highlighted Web and
Enter launched Chromium (issue #43's column-count fix, `share/launcher/gridnav.js`).
Same night, with the 6-8 pack installed: Enter on the GCompris tile launched it fullscreen in
the kid's session (Hyprland reported the client fullscreen; the launch was logged), the first
real app run through Kids Mode.
