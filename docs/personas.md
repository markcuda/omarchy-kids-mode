# Personas

_status: draft · updated 2026-09-01 — grounded in report 07 (age bands) and the Discord signal; refine with parent stories._

## Parents / guardians

| Persona | Who | Wants | Fears | Will tolerate |
| --- | --- | --- | --- | --- |
| **The Omarchy parent** (most of Discord) | Already runs Omarchy; comfortable with a terminal; has 1–3 kids aged 4–12 | To share the thing they love, safely; to chunk off a piece and build it | The pop-up; wasting weekends on a fragile hack | A TUI, a PKGBUILD, reading a threat model |
| **The gift-giver** | Techie relative preparing a laptop for a niece/nephew or for a school | "Install for another owner" and walk away; it must keep working | Being the support desk forever | Deferred provisioning, a printed key poster |
| **The mainstream parent** ("isn't this for the masses?") | Not technical; heard Omarchy is fast and safe | Boot → Kid Mode → five minutes → done; a green/red "is it safe?" screen | Anything that looks like a config file; alert fatigue | A menu and two sliders; nothing else |
| **The teacher** | Runs a classroom or club; needs 10–30 identical machines | Imaging, per-machine presets, no accounts required, offline content | Surveillance tools masquerading as safety; licensing traps | `cidata` unattended installs; a documented school profile (later) |

## Kids (by band — capability rank is earned, preset is parent-set)

| Band | Rank on day one → | Preset | What delights | What frustrates |
| --- | --- | --- | --- | --- |
| **3–5** | Explorer | Guided | Sound, colour, the mascot, `nyancat`; one thing at a time | Text, small targets, dragging, anything hierarchical |
| **5–7** | Explorer → Tinkerer | Guided | Making two windows; keys with pictures; SuperTuxKart with a sibling | Chords >2 keys; losing a window; being told "wrong" |
| **8–10** | Tinkerer → Navigator | Supported | Building (Scratch/TurboWarp, Luanti), typing games, `hollywood`, the first `ls` | Limits without warning; being spied on; "no Roblox" without a reason |
| **11–13** | Navigator → Wizard | Independent | The real terminal, dotfiles, Godot, a machine that's actually theirs | Kid-branded anything; reports that read like surveillance |
| **13+** | Wizard | Trusted | Plain Omarchy | Training wheels |

Rules: no persona is gendered; no kid is ever identified in this repo; kid feedback arrives only via a parent
using the **kid-test report** issue form, with age bands, no names or photos.

## Contributors

| Persona | Brings | Best first task |
| --- | --- | --- |
| **Designer / artist** | Characters, palettes, posters, sound | THEME-01 Tux theme; THEME-07 original CC0 character |
| **Shell / QML dev** | Quickshell plugins, Hyprland Lua | SHELL-02 kids bar; SHELL-05 Shortcut Target Practice |
| **Systems dev** | polkit, systemd, nftables, PKGBUILDs | NET-02 policy pack; WS-11.2 setup tool skeleton |
| **Content curator / teacher** | App and content judgement | APPS-03 pack manifests; APPS-02 kid fortune file |
| **Researcher / writer** | Verifying sources, writing notes | any `needs-verification` issue; RES-01 literature pack |
| **Parent tester** | A real kid, an evening, honesty | kid-test reports on anything `alpha` |
