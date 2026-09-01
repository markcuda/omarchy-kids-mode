# L8 · Apps, Games & Learning Content

_status: draft · updated 2026-09-01 · lead: open · primary evidence: report 05 (catalog + availability checked against Arch/AUR/Flathub APIs on 2026-09-01), report 04 §6, report 07 §6_

## Purpose

What's installed on day one, what isn't, and why — per age band; plus the honest answer to "what will kids expect?"

## What we know (verified)

- **Arch `extra` covers most of the catalog**: GCompris 26.1, the KDE Edu suite (KTouch, KTurtle, Kanagram,
  KHangMan, Marble, KStars, Step, KGeography, KTuberling, Blinken…), SuperTux 0.7, SuperTuxKart 1.5, Luanti 5.16,
  Prism Launcher, Stellarium, Godot 4.7, Kiwix 2.5, Anki, Krita, Inkscape, LMMS, Tenacity, RetroArch, ScummVM,
  Tiled, LibreSprite, Klavaro, and the terminal toys (cowsay, sl, fortune-mod, figlet, lolcat, asciiquarium,
  cmatrix, nyancat, bsd-games). **AUR/Flathub only:** Tux Paint, TuxMath/TuxTyping (dormant), Thonny, Pixelorama,
  Sonic Pi, TIC-80, Pyxel, DOSBox-X, Frozen Bubble, Celestia, ttyper. [R05-S19][R05-S20][R05-S21]
- **Scratch:** the official Flathub package is from 2020; **TurboWarp Desktop** (Flathub 1.16, 2026-05) is the
  maintained path. **ScratchJr has no official Linux build** — GCompris covers 3–6. [R05-S20][R05-S21][R05-S54]
- **fortune is already kid-safer on Arch**: `fortune-mod` excludes the offensive DB (separate AUR
  `fortune-mod-off`). Still ship a curated kid fortune file — stock cookies aren't written for six-year-olds. [R05-S36]–[R05-S38]
- **Kids expect YouTube, Minecraft, Roblox** (Scratch for 8–12 as the "school" expectation). Minecraft Java runs
  via Prism (paid; already in Omarchy's _Install > Gaming_); Bedrock via mcpelauncher is fragile; Roblox via
  **Sober** is unofficial, closed-source, "may be discontinued at any time"; Fortnite: no (anti-cheat; Omarchy's
  own manual says so). Steam has Family View + Steam Families child accounts with playtime limits on Linux. [R05-S11][R05-S14][R05-S26]–[R05-S32]
- **YouTube Kids works on the web** (youtubekids.com) without sign-in, with a parent age gate; enforce by
  `URLBlocklist` + web app, not DNS rewrite (L3). [R04-S67]
- **OARS** ratings in AppStream (Flathub ships them) are the machine-readable source for allowlists; map to
  PEGI/ESRB for parents; missing metadata = treat as "intense" until a parent overrides. [R07-S60]–[R07-S64]
- Jellyfin per-user parental rating + block-unrated + tag blocking; Kodi profiles with master lock. [R05-S51]–[R05-S53]

## The "top 3 apps" answer (OQ-1)

> Kids will expect **YouTube, Minecraft and Roblox**. We give them: (1) a **curated video library** (Jellyfin/Kodi
> kid profile + Kiwix TED-Ed/Khan ZIMs) and YouTube Kids as a web app instead of YouTube; (2) **Luanti** preinstalled
> plus one-click **Minecraft Java** if the family owns it; (3) **TurboWarp (Scratch) + SuperTuxKart** as the
> creative/social pair. Roblox stays a **parent-gated opt-in** via Sober with Roblox's own account controls.
> Fortnite: no, and we say so clearly.

## Starter packs (proposal; Flatpak where both exist; all offline-capable)

| Band / preset | Pack |
| --- | --- |
| **3–5 Guided** | GCompris, Tux Paint, KTuberling, Blinken, Kolf, Stellarium (parent-driven); `nyancat`/`sl`/`cowsay` as rewards |
| **5–7 Guided** | + SuperTux, SuperTuxKart (local split-screen), KTurtle, KLettres, Kanagram, Jellyfin/Kodi kid profile, Kiwix Simple-English Wikipedia; Bashcrawl-lite (3 rooms) |
| **8–10 Supported** | + TurboWarp, Luanti (+ Classroom mod, LAN only, chat off), KTouch, KHangMan/KGeography, Pixelorama, Sonic Pi, Kiwix Khan/TED-Ed, Thonny (optional), full Bashcrawl, `hollywood`, `cbonsai`; Shortcut Target Practice unlocks Level 2 |
| **11–13 Independent** | + Godot, Tiled, TIC-80, Pyxel, Krita, LMMS/Tenacity, Marble, KStars, Anki, LibreOffice, ScummVM freeware pack, Steam with Family View; Minecraft Java if owned; Roblox via Sober only by parent opt-in |
| **13+ Trusted** | any stock theme; Jupyter, Typst, Processing, Ren'Py, Inkscape, Heroic/Lutris (parent-installed) |

Web apps (parent-approved, `https://`-only): Blockly Games, MakeCode Arcade, Piskel, PuzzleScript, Bitsy, Turtle
Blocks, Hedy (or self-hosted for offline), YouTube Kids, PBS Kids. **Remove** stock YouTube/ChatGPT/X/Discord/WhatsApp
web apps for the kid.

## Terminal fun (for the L4 sandboxed kid shell)

`cowsay sl figlet toilet lolcat asciiquarium cmatrix nyancat bsd-games tldr` from `extra`; `vitetris cbonsai
pipes.sh hollywood ttyper` from AUR; a **kid fortune file** (300+ jokes/riddles/facts, CC0, `strfile`) as the only
fortune DB; **Bashcrawl** (a dungeon made of directories) themed with the mascot as the "quest". Review `bsd-games`
text adventures for tone.

## Legal/ethical notes

exoDOS/abandonware = copyright infringement in most jurisdictions → DOSBox only with freeware/shareware; RetroArch
with homebrew cores only; ScummVM's 11 legally free games; YouTube ToS forbids automated downloading → Library mode
documents the pattern, never automates it (L3).

## Interfaces

Allowlist → L4 (launcher/sandbox), web apps → L3 policy, OARS → L6 parent flow badges, budgets by app class → L9.
Packaged by L11 as `omarchy-kids-packs` (manifests + install script).

## Workstreams & backlog seeds

APPS-01 package-availability audit script (CI, monthly; good first issue) · APPS-02 kid fortune file (GFI) ·
APPS-03 pack manifests per preset · APPS-04 curated web-app list (GFI) · APPS-05 Hedy self-host recipe ·
APPS-06 Luanti kids world · APPS-07 Jellyfin/Kodi kid-profile playbook · APPS-08 Kiwix starter ZIM set ·
APPS-09 TIC-80 cartridge shelf · APPS-10 Bashcrawl-Omarchy fork · APPS-11 docs: Roblox (Sober) and Steam Family
View parent guides (GFI) · APPS-12 OARS ingestion for allowlist badges.

## Open questions

Flatpak-first for kid apps on a pacman/AUR-first distro? Roblox in or out of "supported"? Multilingual content from
day one (GCompris is)? Who owns the Kiwix ZIM sizes/"Wikipedia for Schools" question?
