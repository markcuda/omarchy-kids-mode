-- Level 2 Hyprland config (SPEC.md R-DESK-3, Appendix E; I-3, I-5, I-6).
--
-- Root-owned, installed and provisioned the same way as L1.lua (see its
-- header). Appendix E: "Level 2: Level 1 plus Super+arrows focus ·
-- Super+Shift+arrows swap · Super+K cheat sheet · Super+Space launcher."
--
-- This file intentionally duplicates L1.lua's binding lines rather than
-- requiring a shared sibling module: Lua's `require` search path isn't
-- guaranteed to include this file's own directory when Hyprland loads it
-- via `--config`, and `dofile` with a guessed relative path is worse
-- than plain duplication for something this small and this security-
-- relevant (Appendix E's "exactly this set" framing wants each level's
-- binding table readable as one flat list anyway). Like L1, this file
-- never requires default.hypr.bindings.*.

-- --- Look, input, animations ---------------------------------------------
-- Same reasoning as L1.lua: looknfeel and input are self-contained (no
-- nested requires, no home paths); envs is reimplemented directly to
-- avoid default.hypr.envs's default.hypr.paths (home) dependency.
-- Root-owned config (I-3): a fixed module path -- not $OMARCHY_PATH, and
-- not the inherited package.path (Omarchy's user bootstrap.lua puts
-- ~/.config and ~/.local/state first). Both are set by the session this
-- file exists to fence, so neither may choose what require() loads
-- (review §3.5).
package.path = "/usr/share/omarchy/?.lua;/usr/share/lua/5.4/?.lua;/usr/share/lua/5.4/?/init.lua"
require("default.hypr.helpers")

require("default.hypr.looknfeel")
require("default.hypr.input")

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Same idle-pointer rule as L1 (verified option, see L1.lua's note): a pointer
-- parked on a screen a kid drives by keyboard reads as clutter, and the live
-- review flagged it. It returns the moment the mouse moves.
hl.config({ cursor = { inactive_timeout = 1 } })

-- Hide the idle pointer after a second of stillness (verified option on
-- the running compositor; movement brings it back). Same live-review
-- finding as L1: a parked cursor on a keyboard-first surface.
hl.config({ cursor = { inactive_timeout = 1 } })

-- Unlike L1, Level 2 actually tiles (50/50 dwindle split, below), so
-- keep default.hypr.looknfeel's normal gaps/border/animation instead of
-- L1's flattened kiosk look. The "50/50 dwindle split" Appendix E asks
-- for comes from default.hypr.looknfeel itself once required above:
-- it sets `general.layout = "dwindle"` and `dwindle.preserve_split =
-- true` / `dwindle.force_split = 2`, which is dwindle's normal
-- side-by-side 50/50 behaviour for two windows. No extra config here:
-- there's no dwindle "ratio" key in the reference material to justify
-- inventing one.

-- Apps tile normally; only the owned app picker floats over the desktop.
o.window({ title = "^Omarchy Kids Launcher$" }, { float = true, center = true })

-- --- Bindings: the Level 1 set plus Appendix E's Level 2 additions -----
o.bind("SUPER + Home", "Kids Mode: launcher", "omarchy-kids-launcher-ctl show")
o.bind("SUPER + RETURN", "Kids Mode: open selected", "omarchy-kids-launcher-ctl activate")
o.bind("SUPER + Q", "Kids Mode: close", hl.dsp.window.close())
o.bind("SUPER + SHIFT + K", "Kids Mode: parent", "omarchy-kids-exit")

-- Wi-Fi picker (SPEC.md R-WIFI-1..2, issue #26). See L1.lua's comment on
-- this same bind for why it is unconditional here (the level configs
-- are static; the refusal lives in omarchy-kids-wifi picker, not here).
o.bind("SUPER + SHIFT + W", "Kids Mode: Wi-Fi", "omarchy-kids-wifi picker")

-- The triple-tap gesture (SPEC.md R-EXIT-1: "Super pressed three times
-- within 1.5s" as an alternative to Super+Shift+K). The release-bind
-- form is real: /usr/share/omarchy/default/hypr/bindings/voxtype.lua
-- ships `o.bind("F9", ..., "voxtype record stop", { release = true })`,
-- and Hyprland 0.56.2's Lua engine documents `release` (plus
-- ignore_mods/long_press/non_consuming/repeating/separate/transparent)
-- as bind options -- confirmed, not guessed (docs/exit.md used to flag
-- this as unconfirmed; that's resolved now). SUPER_L is the left Super
-- keysym: binding "SUPER + SUPER_L" release is Hyprland's documented way
-- to catch a bare Super tap (Super is both the modifier and the key).
-- bin/omarchy-kids-super-tap does the counting/timing; this bind just
-- calls it once per bare Super release.
o.bind("SUPER + SUPER_L", "Kids Mode: exit (tap Super three times)", "omarchy-kids-super-tap", { release = true })

o.bind("XF86AudioRaiseVolume", "Volume up", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
o.bind("XF86AudioLowerVolume", "Volume down", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
o.bind("XF86AudioMute", "Mute toggle", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
o.bind("XF86MonBrightnessUp", "Brightness up", "brightnessctl set +5%")
o.bind("XF86MonBrightnessDown", "Brightness down", "brightnessctl set 5%-")

-- Focus/swap dispatchers copied verbatim (same calls Omarchy's own
-- default.hypr.bindings.tiling uses) rather than requiring that module,
-- so Level 2 gets only these eight binds and not the rest of tiling.lua.
o.bind("SUPER + LEFT", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + RIGHT", "Focus on right window", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + SHIFT + LEFT", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + RIGHT", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.bind("SUPER + SHIFT + UP", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + DOWN", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

-- Cheat sheet: the same command default.hypr.bindings.utilities binds
-- SUPER + K to, kept for Appendix E -- but it is inert at Level 2 (live,
-- 2026-09-22). Its menu is summoned with `omarchy-shell shell summon`, which
-- needs a running Omarchy shell; a Level 2 session runs the kids launcher
-- instead (only Level 3's start hook runs omarchy-launch-shell), and the
-- command also fails first on the unset $OMARCHY_PATH. `omarchy-menu-keybindings
-- --print` still prints the live binds as text, with no kid surface to show it;
-- a kid-side viewer is the open item (docs/levels.md).
o.bind("SUPER + K", "Kids Mode: keybindings", "omarchy-menu-keybindings")

-- Launcher, aliased onto Super+Space too (Appendix E). Also doubles as
-- R-DESK-4's enforcement: Super+Space is never bound to "omarchy-menu
-- toggle" at this level, so the untrimmed menu has no keyboard path in
-- (see share/menu/omarchy-kids-trimmed.jsonc for the rest of that story).
o.bind("SUPER + SPACE", "Kids Mode: launcher", "omarchy-kids-launcher-ctl show")

-- --- Start the session ---------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("omarchy-kids-session-start")
end)

-- --- Band overlay ---------------------------------------------------------
-- Fixed, not $OMARCHY_KIDS_HYPRLAND_DIR: dofile runs whatever it is
-- handed, so the kid's environment must not choose the file (review §3.5).
local HYPRLAND_DIR = "/etc/omarchy-kids/hyprland"
local band = os.getenv("OMARCHY_KIDS_BAND")
if band == "3-5" then
  dofile(HYPRLAND_DIR .. "/band-3-5.lua")
elseif band == "6-8" then
  dofile(HYPRLAND_DIR .. "/band-6-8.lua")
end
