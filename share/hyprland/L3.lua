-- Level 3 Hyprland config (SPEC.md R-DESK-3, Appendix E; I-3, I-5, I-6).
--
-- Root-owned, installed and provisioned the same way as L1.lua (see its
-- header). Appendix E: "Level 3: Omarchy defaults minus: terminal-
-- launching binds under menu=trimmed (kept under full), omarchy-sudo-
-- passwordless, screenshot-to-clipboard of other users' windows (n/a),
-- plus Super+Shift+K." Level 3 gets the *real* Omarchy desktop, but by
-- requiring the stock modules individually rather than the
-- default.hypr.omarchy umbrella: the umbrella also requires
-- default.hypr.autostart, which execs `omarchy-provision-first-run` and the
-- rest of Omarchy's per-session parent setup on every start (read live on the
-- VM, 2026-09-21). Our own start hook below runs the shell, so the autostart
-- module is replaced, not lost.
-- Root-owned config (I-3): a fixed module path -- not $OMARCHY_PATH, and
-- not the inherited package.path (Omarchy's user bootstrap.lua puts
-- ~/.config and ~/.local/state first). Both are set by the session this
-- file exists to fence, so neither may choose what require() loads
-- (review §3.5).
package.path = "/usr/share/omarchy/?.lua;/usr/share/lua/5.4/?.lua;/usr/share/lua/5.4/?/init.lua"
require("default.hypr.helpers")
local require_optional = require("default.hypr.require_optional")

-- The stock modules a grown-up's session gets, minus default.hypr.autostart
-- (see the header). Bound modules are required the same way the umbrella does,
-- so a box that sets _G.omarchy_default_bindings = false still gets its
-- choice.
if _G.omarchy_default_bindings ~= false then
  require("default.hypr.bindings.media")
  require("default.hypr.bindings.clipboard")
  require("default.hypr.bindings.tiling")
  require("default.hypr.bindings.utilities")
  require("default.hypr.bindings.voxtype")
  require_optional.module("default.hypr.bindings.applications")
end
require("default.hypr.envs")
require("default.hypr.looknfeel")
require("default.hypr.input")
require("default.hypr.windows")
require_optional.module("omarchy.current.theme.hyprland")

-- Hyprland's own update-news and donation popups are upstream notices about
-- Omarchy, not a kid's; the news dialog carries an outbound link that xdg-open
-- would open in the browser outside the kids launcher (R-DESK-1, I-6).
hl.config({
  ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- --- Unbind: terminal-launching binds (menu=trimmed) --------------------
--
-- Verified on the VM (2026-09-21) with a `menu = trimmed` kid at Level 3:
-- `hyprctl binds` shows no SUPER + RETURN bind at all, and the session's sudo
-- and polkit checks still deny (docs/dogfood-2026-09-21.md). The unbind below
-- is kept so the rule holds on a build that does bind a terminal launcher; it
-- is not what keeps the kid out of a shell on today's box.
--
-- The "omarchy-sudo-passwordless" question this header used to flag is now
-- answered: it is not a keybind, it was Omarchy's autostart running
-- `omarchy-provision-first-run` for whoever logs in, and this file no longer
-- requires that module (see the requires above). A kid's sudo refusal is the
-- account's own permissions, checked live, not this file.
hl.unbind("SUPER + RETURN")

-- --- Add: the exit modal bind (Appendix E) -------------------------------
o.bind("SUPER + SHIFT + K", "Kids Mode: parent", "omarchy-kids-exit")

-- Wi-Fi picker (SPEC.md R-WIFI-1..2, issue #26). See L1.lua's comment on
-- this same bind for why it is unconditional here (the level configs
-- are static; the refusal lives in omarchy-kids-wifi picker, not here).
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

-- --- Start the session (starts Omarchy's shell, not the L1 launcher) ----
-- The first two commands are the systemd/dbus environment imports Omarchy's
-- autostart made before launching the shell; without them the session's user
-- services and portals come up with an empty environment. The parent-only
-- parts of that module (omarchy-provision-first-run, power-profiles, udiskie,
-- the post-boot hook) are deliberately not run for a kid.
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("omarchy-kids-session-start")
end)

-- --- Band overlay (in practice 13+ has its own look; kept for any kid
-- whose level was manually raised while still in a younger band) -------
-- Fixed, not $OMARCHY_KIDS_HYPRLAND_DIR: dofile runs whatever it is
-- handed, so the kid's environment must not choose the file (review §3.5).
local HYPRLAND_DIR = "/etc/omarchy-kids/hyprland"
local band = os.getenv("OMARCHY_KIDS_BAND")
if band == "3-5" then
  dofile(HYPRLAND_DIR .. "/band-3-5.lua")
elseif band == "6-8" then
  dofile(HYPRLAND_DIR .. "/band-6-8.lua")
end
