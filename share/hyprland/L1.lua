-- Level 1 Hyprland config (SPEC.md R-DESK-3, Appendix E; I-3, I-5, I-6).
--
-- Root-owned. Installed to /usr/share/omarchy-kids/hyprland/L1.lua and
-- provisioned to /etc/omarchy-kids/hyprland/L1.lua (R-DESK-1), where
-- omarchy-kids-session execs:
--   Hyprland --config /etc/omarchy-kids/hyprland/L1.lua
-- The kid's own ~/.config/hypr is never read (R-DESK-6): everything a
-- Level 1 session needs is either in this file, in one of Omarchy's
-- default.hypr.* modules pulled in below, or under /usr/share and /etc
-- (never under the kid's home) -- see the "what we do and don't require"
-- note below for I-3.
--
-- Appendix E, Level 1: "Super+Home launcher · Super+Enter open selected
-- · Super+Q close · Super+Shift+K exit modal · volume/brightness keys.
-- Nothing else bound; every window rule forces fullscreen." This file
-- binds exactly that set -- test/shell.d/levels-test.sh greps for it --
-- and never requires default.hypr.bindings.* (Omarchy's own binding
-- modules), unlike Level 3.

-- --- Look, input, animations -------------------------------------------
--
-- What we require and why (judgment call, since Level 1 must not depend
-- on the kid's home -- I-3):
--
--   default.hypr.looknfeel -- required. Read start to finish: it only
--   calls hl.config/hl.curve/hl.animation and requires nothing else. No
--   file access, no home path.
--
--   default.hypr.input -- required. Reads /etc/vconsole.conf (a system
--   file, not the kid's home) for keyboard layout and calls hl.config
--   and o.window. Requires nothing else.
--
--   default.hypr.envs -- NOT required. It requires default.hypr.paths
--   (not available to inspect while writing this) and sets
--   XCOMPOSEFILE to paths.home .. "/.XCompose" -- a path inside the
--   logged-in account's home. That's a soft coupling, not enforcement,
--   but I-3 says nothing in home should matter here, so this file sets
--   the handful of envs a Wayland session actually needs (below)
--   directly instead of pulling in a module that reaches into $HOME.
--
--   default.hypr.windows / default.hypr.monitors / default.hypr.bindings.*
--   -- NOT required. windows.lua requires default.hypr.apps (unseen,
--   app-specific tweaks not relevant to a fullscreen-only kiosk);
--   monitors is the *user's own* ~/.config/hypr/monitors.lua, which is
--   exactly the kind of home file I-3 says must never matter; bindings
--   are built by hand below, per Appendix E, per R-DESK-1's "no
--   defaults" framing for this level.
-- Root-owned config (I-3): a fixed module path -- not $OMARCHY_PATH, and
-- not the inherited package.path (Omarchy's user bootstrap.lua puts
-- ~/.config and ~/.local/state first). Both are set by the session this
-- file exists to fence, so neither may choose what require() loads
-- (review §3.5).
package.path = "/usr/share/omarchy/?.lua;/usr/share/lua/5.4/?.lua;/usr/share/lua/5.4/?/init.lua"
require("default.hypr.helpers")

require("default.hypr.looknfeel")
require("default.hypr.input")

-- Wayland/toolkit envs, copied from default.hypr.envs without the
-- default.hypr.paths dependency (see note above).
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Hyprland's own update-news and donation popups are upstream notices about
-- Omarchy, not a kid's; the news dialog carries an outbound link that xdg-open
-- would open in the browser outside the kids launcher (R-DESK-1, I-6).
hl.config({
  ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- Kiosk look: no gaps/border/animation chrome since every window is
-- forced fullscreen below anyway (hl.config after a require overrides
-- the keys it sets, same as hyprctl reload semantics).
hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 0 },
  decoration = { rounding = 0 },
  animations = { enabled = false },
  -- Hide the idle pointer: the live review found a mouse cursor parked
  -- mid-grid on a keyboard-only first paint. The option name is verified
  -- on the running compositor (`hyprctl getoption cursor:inactive_timeout`
  -- reports a float, default 0, unset); movement brings it straight back.
  cursor = { inactive_timeout = 1 },
})

-- UNVERIFIED: this file does not set up monitors at all (see the note
-- above on why hypr.monitors -- the user's own file -- is out of
-- bounds). Hyprland's own auto-detection defaults apply. If a real
-- machine needs an explicit monitor layout, that has to be a Kids Mode
-- concern (an env var or a generated snippet), not something read from
-- a home directory; out of scope for this issue.

-- --- Every window fullscreen (Appendix E) --------------------------------
-- `no_focus = true` in Omarchy's own default.hypr.windows shows a
-- boolean windowrule flag is written this way in this DSL, so the
-- fullscreen flag rule (windowrulev2 = fullscreen, ...) is assumed to
-- follow the same shape. UNVERIFIED against a live Hyprland: confirm
-- `fullscreen = true` actually renders as the `fullscreen` windowrule
-- and not, say, `fullscreen = "1"` or a dispatcher-shaped table.
o.window(".*", { fullscreen = true })

-- --- Bindings: exactly the Appendix E Level 1 set, nothing else ---------
--
-- The launcher itself (share/launcher/shell.qml) is a plain top-level
-- window titled "Omarchy Kids Launcher" and gets the same fullscreen
-- rule as every other window above; bin/omarchy-kids-launcher-ctl is the
-- one place that knows how to reach it (by window title, or by writing
-- its control file), so these binds don't have to guess Quickshell's
-- IPC details themselves. See that script's header for what's verified
-- and what isn't.
o.bind("SUPER + Home", "Kids Mode: launcher", "omarchy-kids-launcher-ctl show")
o.bind("SUPER + RETURN", "Kids Mode: open selected", "omarchy-kids-launcher-ctl activate")
o.bind("SUPER + Q", "Kids Mode: close", hl.dsp.window.close())
o.bind("SUPER + SHIFT + K", "Kids Mode: parent", "omarchy-kids-exit")

-- Wi-Fi picker (SPEC.md R-WIFI-1..2, issue #26). Unconditional here on
-- purpose: this file is static and provisioned once (R-DESK-1), so it
-- cannot itself branch on a kid's `wifi` profile key. omarchy-kids-wifi
-- picker does that check instead -- it refuses, with a small toast,
-- unless the profile says wifi=helper (I-6: the bind existing is not
-- the same claim as the bind doing anything).
o.bind("SUPER + SHIFT + W", "Kids Mode: Wi-Fi", "omarchy-kids-wifi picker")

-- Theme picker (T45): the same chord a grown-up uses (Super+Ctrl+Shift+Space),
-- so the kid learns the real one. omarchy-kids-theme offers only installed
-- themes and applies the choice through Omarchy's own omarchy-theme-set.
o.bind("SUPER + CTRL + SHIFT + SPACE", "Kids Mode: theme", "omarchy-kids-theme")

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

-- Volume/brightness media keys. UNVERIFIED: no default.hypr.bindings.media
-- was in the reference material used to write this file, so this uses
-- wpctl (PipeWire, ships with every current Omarchy) and brightnessctl
-- directly rather than guessing an Omarchy-specific wrapper name. If
-- Omarchy ships its own volume/brightness helper (for on-screen-display
-- feedback, say), swap these for it.
o.bind("XF86AudioRaiseVolume", "Volume up", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
o.bind("XF86AudioLowerVolume", "Volume down", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
o.bind("XF86AudioMute", "Mute toggle", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
o.bind("XF86MonBrightnessUp", "Brightness up", "brightnessctl set +5%")
o.bind("XF86MonBrightnessDown", "Brightness down", "brightnessctl set 5%-")

-- --- Start the session (launcher, exit overlay, notifications) ---------
-- The same systemd/dbus environment imports L3's start hook makes (and that
-- Omarchy's own autostart makes before the shell). Without them the kid's
-- user services and portals come up with an empty environment, which is the
-- live finding behind a D-Bus-activated app dying at this level. The
-- parent-only parts of Omarchy's autostart stay out (R-DESK-1, I-3).
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("omarchy-kids-session-start")
end)

-- --- Band overlay (larger cursor/gaps/scale for younger bands) ---------
-- Loaded by fixed, deployed path (R-DESK-1: this file always lives at
-- /etc/omarchy-kids/hyprland/L1.lua) rather than a `require` search
-- path, exactly like the real hyprland.lua entry file uses
-- `dofile(... .. "/...")` for its own bootstrap -- `dofile` with a fixed
-- path is Omarchy's own idiom for reaching a sibling file outside
-- `require`.
-- Fixed, not $OMARCHY_KIDS_HYPRLAND_DIR: dofile runs whatever it is
-- handed, so the kid's environment must not choose the file (review §3.5).
local HYPRLAND_DIR = "/etc/omarchy-kids/hyprland"
local band = os.getenv("OMARCHY_KIDS_BAND")
if band == "3-5" then
  dofile(HYPRLAND_DIR .. "/band-3-5.lua")
elseif band == "6-8" then
  dofile(HYPRLAND_DIR .. "/band-6-8.lua")
end

-- Band overlays may loosen gaps; Level 1 stays edge to edge after apps close.
hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 0 },
})
