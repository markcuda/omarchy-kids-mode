# Apps, Games, Learning Tools & Themes for Kids on Omarchy

_Research report · Omarchy Kids Mode · 2026-09-01 · status: draft_

## TL;DR

- **Omarchy changed under our feet.** Omarchy 4.0 "Quattro" shipped 2026-08-14 and replaced Waybar/Walker/Mako/SwayOSD/hyprlock/swaybg with one long-running **Quickshell** process that has a real plugin system (`omarchy plugin add <git-url>`, `manifest.json`, kinds `bar-widget | bar | panel | overlay | menu | service`) [S7][S15]. The canonical repo is now `omacom/omarchy` (36.7k stars); `basecamp/omarchy` redirects [S3]. A Kids Mode should be built as **Omarchy shell plugins + a theme**, not as a parallel shell.
- **Themes are small and generated.** A 4.0 theme is `colors.toml` (+ `mode = "light"`), `shell.toml` (spacing scale, base font size, control states, bar size), `icons.theme` (Yaru variants only), `backgrounds/`, `btop.theme`, `neovim.lua`, `vscode.json`, `keyboard.rgb`, `preview.png`, `unlock.png` [S8][S9][S15]. `[spacing] scale` and `[font] base-size` are exactly the knobs a kids theme needs for big hit targets and large type. Community themes are GitHub repos named `omarchy-<name>-theme`, installed via _Install > Style > Theme_, listed at omarchy.org/themes ("Extra Themes", 60+ entries incl. NES, Batman, Dracula) [S9][S10][S22].
- **Catalog reality (Arch official repo is strong):** GCompris 26.1, KTouch/KTurtle/Kanagram/KHangMan/Marble/KStars/Step/KGeography/Kolf 26.08, SuperTux 0.7, SuperTuxKart 1.5, Luanti 5.16, Prism Launcher 11, Stellarium 26.2, Godot 4.7, Kiwix 2.5, Anki, Krita 6, Inkscape, LMMS, Tenacity, RetroArch, ScummVM, Tiled, LibreSprite, cowsay/sl/fortune-mod/figlet/lolcat/asciiquarium/cmatrix/nyancat/bsd-games are all in `extra` [S19]. Tux Paint, TuxMath, TuxTyping, Frozen Bubble, Celestia, DOSBox-X, Thonny, Pixelorama, Ren'Py, Sonic Pi, TIC-80, Pyxel, Processing, bastet/nsnake/moon-buggy/cbonsai/hollywood/pipes.sh are AUR-only; TuxMath/TuxTyping/nsnake/moon-buggy are effectively unmaintained upstream [S20].
- **Scratch:** the Flathub `edu.mit.Scratch` package is dated 2020; **TurboWarp Desktop** (Flathub 1.16.0, 2026-05; AUR `turbowarp-desktop-bin`) is the maintained Scratch-compatible desktop path [S20][S21]. **ScratchJr has no official Linux build** [S54][S55]; GCompris covers ages 3-6 instead.
- **What kids expect vs. what Linux can do:** YouTube (block + curated Jellyfin/Kodi library), Minecraft (Java via Prism Launcher, paid; Omarchy's own _Install > Gaming_ menu already offers Minecraft) [S11], Roblox (Sober Flatpak — unofficial, closed-source, "use at your own risk, may be discontinued at any time") [S14], Fortnite (no; anti-cheat, confirmed in Omarchy's own gaming manual) [S11]. Minecraft Bedrock via mcpelauncher is fragile ("sitting on top a cave full of tnt" — maintainer, Feb 2026) [S28].
- **fortune is already kid-safer on Arch than the blueprint fears:** Arch's `fortune-mod` package ships without the offensive DB; offensive quotes live in the separate AUR `fortune-mod-off` [S36][S37]. Still ship a curated kid fortune file — the default cookie files are not written for 6-year-olds.
- **Blueprint corrections:** Quickshell claim is now TRUE (4.0); Voxtype IS Omarchy's dictation engine but the hotkey is **F9 (hold) / Super+Ctrl+X**, not Super+V [S16]; "Sol" voice-to-code assistant does not exist; PICO-8 is $15 commercial (free browser-only Education Edition) — TIC-80/Pyxel are the FOSS route [S57][S58]; "DOSBox mapping" is technically trivial but content-sourcing (exoDOS) is a legal gray area and DOS games have near-zero pull for ages 5-12 [S66][S67]; `github.com/omarchy/kids-mode/...` bibliography entries are fabricated (that org is an unrelated 3-star profile) [S1].
- **No Hyprland/tiling keybinding trainer game exists** (searched; none found) [S70]. "Shortcut Target Practice" is a genuinely novel, chunkable Quickshell-overlay workstream. Typing trainers do exist (KTouch, Klavaro, ttyper) — do not rebuild one in QML.
- **Mascot licensing is clean for three:** Tux (Larry Ewing permission w/ attribution; CC0 SVG by Garrett LeSage) [S18], Konqi (CC BY-SA 4.0 / LGPL 2.1+, Tyson Tan) [S17], Wilber (CC BY-SA 4.0) [S39]. Use character choice, not gender, as the onboarding fork.

## Findings

### 1. Catalog of kids software (Arch / AUR / Flathub)

Availability checked 2026-09-01 against the archlinux.org package JSON API [S19], the AUR RPC v5 API [S20], and the Flathub appstream API [S21]. "extra" = Arch official repo. Wayland notes are engineering judgement unless cited; Omarchy runs Hyprland with XWayland available, so X11-only apps still run, just without HiDPI/fractional polish.

| Tool | Age | Category | Arch | AUR | Flathub | Wayland | Maint. (evidence) | Offline | Why |
|---|---|---|---|---|---|---|---|---|---|
| GCompris | 3-5, 5-7, 8-10 | Edu suite (190+ activities) | extra `gcompris-qt` 26.1 (2026-03) | — | `org.kde.gcompris` 26.1 | Qt6, native | Active (2026) | Yes | The single best ages-3-9 app on Linux; covers reading, math, logic, keyboard, mouse. Anchor of the 3-7 pack. |
| Tux Paint | 3-5, 5-7 | Drawing | — | `tuxpaint` 0.9.35 (2026-07) | `org.tuxpaint.Tuxpaint` 0.9.35 | SDL2; native or XWayland | Active (0.9.35, 2025-26) | Yes | Stamps, magic tools, sounds; kids adore it. Flatpak preferred. |
| TuxMath | 5-7, 8-10 | Math arcade | — | `tuxmath` 2.0.3 (pkg 2024; upstream ~2011) | — | SDL1.2 via sdl12-compat, XWayland | Dormant | Yes | Still fun; treat as legacy. GCompris covers similar ground. |
| TuxTyping | 5-7, 8-10 | Typing game | — | `tuxtype` 1.8.3 (pkg 2021; upstream ~2011) | — | SDL1.2, XWayland | Dormant | Yes | Fish-catching typing game. Legacy; KTouch for 8+. |
| Klavaro | 8-10, 11-13 | Typing tutor | extra `klavaro` 3.14 (2024) | — | not found | GTK3 native | Slow but alive | Yes | Simple, language-agnostic, adaptive. |
| KTouch | 8-10, 11-13, 13+ | Typing tutor | extra `ktouch` 26.08.0 | — | `org.kde.ktouch` 26.04.3 | Qt6 native | Active (KDE Gear) | Yes | Structured courses with per-key stats; the "serious" trainer. |
| KTurtle | 5-7, 8-10 | Logo programming | extra `kturtle` 26.08.0 | — | `org.kde.kturtle` | native | Active | Yes | Turtle graphics in plain words; ideal first "code" experience. |
| Kanagram / KHangMan | 5-7, 8-10 | Word games | extra 26.08.0 | — | on Flathub | native | Active | Yes | Vocabulary/spelling. |
| KLettres, Blinken, KTuberling, KBruch, KWordQuiz, Parley, KmPlot, Kalzium, KolourPaint | 3-5 → 13+ | KDE Edu extras | extra (KDE Gear) | — | all on Flathub (26.04/26.08) | native | Active | Yes | KTuberling ("potato guy") and Blinken (Simon) suit 3-6; KBruch/KmPlot/Kalzium for 10+. |
| Marble | 8-10, 11-13 | Virtual globe | extra `marble` 26.08.0 | — | `org.kde.marble` | native | Active | Partial (offline maps downloadable) | Kid-safe alternative to Google Earth. |
| KStars | 8-10, 11-13, 13+ | Planetarium | extra `kstars` 3.8.4.1 | — | `org.kde.kstars` 3.8.5 | native | Active | Yes | Deep astronomy; Stellarium is prettier for younger kids. |
| Step | 11-13, 13+ | Physics sandbox | extra `step` 26.08.0 | — | not on Flathub | native | Active | Yes | Interactive mechanics simulator. |
| KGeography | 8-10, 11-13 | Geography quiz | extra 26.08.0 | — | on Flathub | native | Active | Yes | Map quizzes. |
| Stellarium | 5-7 → 13+ | Planetarium | extra `stellarium` 26.2 (2026-07) | — | `org.stellarium.Stellarium` 26.2 | Qt6 native | Active | Yes | Wow-factor sky at night; works with a projector/TV. |
| Celestia | 8-10 → 13+ | Space sim | — | `celestia` 1.6.4 (2025-11) | not found under guessed id | GL, XWayland likely | Slow | Yes | Fly between planets. Lower priority than Stellarium. |
| Scratch 3 (official) | 8-10, 11-13 | Block coding | extra `scratch` is the **1.4** legacy Squeak app (2023) | — | `edu.mit.Scratch` 3.10.1, release dated **2020-03** | Electron; needs ozone/Wayland flags or XWayland | Stale packaging | Yes | Use the web editor (needs net) or TurboWarp desktop instead. |
| TurboWarp Desktop | 8-10, 11-13 | Scratch-compatible | — | `turbowarp-desktop-bin` 1.16.0 (2026-05) | `org.turbowarp.TurboWarp` 1.16.0 (2026-05) | Electron | Active | Yes | Opens/saves .sb3, faster, offline. **Recommended Scratch path.** |
| ScratchJr | 5-7 | Block coding (pre-readers) | — | `scratchjr-desktop-git` (2021, 0 votes) | none | Electron port | Community port, Mac/Win focus [S54] | Yes | No official Linux build. Use GCompris "programming maze"/Tux Paint instead, or tablet. |
| Turtle Blocks JS / Music Blocks (Sugar Labs) | 8-10, 11-13 | Block coding + music | — | — | `org.sugarlabs.TurtleBlocks` not found; `org.sugarlabs.Physics`/`Speak` present but dated 2020 | web | Sugar Flatpaks largely dormant | Web needs net | Prefer as a pinned web app. Not verified this session beyond Flathub API. |
| Blockly Games | 8-10 | Puzzle coding | — | — | — | web | — | No (web) | Google's maze/bird/turtle puzzles. Pin as web app (Omarchy has a Web Apps feature [S4]). Not fetched this session. |
| Sugar (desktop) | 5-7, 8-10 | Learning OS | — | `sugar-toolkit-gtk3-git` (2021) | `org.sugarlabs.Sugar` not found | — | Dormant on Arch/Flathub | — | Do not build on Sugar; cherry-pick ideas (journal, "activities" grid). |
| Luanti (ex-Minetest) | 5-7 → 13+ | Voxel sandbox | extra `luanti` 5.16.1 (2026-07) | — | `org.luanti.luanti` 5.17.0 (2026-08) | native | Very active | Yes (LAN too) | Free Minecraft-alike; ContentDB has an `education` tag, a Classroom mod, EDUtest, modpack4Edu [S61-S65]. **Strong candidate for "make a game" and multiplayer siblings.** |
| Minecraft Java | 8-10 → 13+ | Sandbox (paid) | extra `prismlauncher` 11.0.3 | — | `org.prismlauncher.PrismLauncher` | LWJGL, native/XWayland | Active | Mostly | Needs paid Microsoft account. Omarchy's _Install > Gaming_ already offers "Minecraft — official client" [S11]. |
| Minecraft Bedrock (mcpelauncher) | 8-10 → 13+ | Sandbox (paid) | — | `mcpelauncher-ui-git` 0.15 (2025-10) | not on Flathub under guessed id | — | Fragile; DRM risk, latest Play version unsupported at times [S28][S29] | Mostly | Requires Google Play purchase. Not recommended as a default. |
| SuperTux | 5-7, 8-10 | Platformer | extra `supertux` 0.7.0 (2026-03) | — | `org.supertuxproject.SuperTux` 0.7.0 | SDL2 native | Active | Yes | Mario-like with Tux; gamepad friendly. |
| SuperTuxKart | 5-7 → 13+ | Kart racing | extra `supertuxkart` 1.5 | — | `net.supertuxkart.SuperTuxKart` 1.5 | native | Active | Yes (+LAN/online) | Split-screen multiplayer; **top pick for "a game kids will actually play."** Disable online chat for young kids. |
| Pingus | 8-10 | Lemmings-like | extra `pingus` 0.7.6 (2024 pkg) | — | not on Flathub | SDL, XWayland | Dormant upstream | Yes | Fine puzzle game; legacy. |
| Frozen Bubble | 5-7, 8-10 | Puzzle | — | `frozen-bubble` 2.212 (2025-12) | not on Flathub | Perl/SDL1.2, XWayland | Dormant upstream | Yes | Charming; legacy. |
| Kolf | 5-7, 8-10 | Mini-golf | extra `kolf` 26.08.0 | — | `org.kde.kolf` | native | Active | Yes | Simple mouse game. |
| Inkscape | 11-13, 13+ | Vector art | extra 1.4.4 | — | yes | GTK, native | Active | Yes | Teens; too complex under 10. |
| Krita | 8-10 → 13+ | Painting | extra `krita` 6.0.3 | — | yes | Qt6 native, tablet support | Active | Yes | Kiki mascot; great with a drawing tablet. |
| Audacity / Tenacity | 11-13, 13+ | Audio editor | extra 3.7.8 / 1.3.5 | — | Tenacity on Flathub | wx, XWayland/native | Active | Yes | Podcasts/voice memos. |
| LMMS | 11-13, 13+ | Music production | extra `lmms` 1.2.2 | — | Flathub release dated 2020 | Qt5 | Slow | Yes | Beats and loops. |
| Sonic Pi | 8-10 → 13+ | Live-coding music | — | `sonic-pi` 5.0.0 (2026-08) | `net.sonic_pi.SonicPi` 5.0.0 (2026-08) | Qt6 | Active | Yes | Music = code; huge hit in classrooms. Flatpak preferred. |
| Godot | 11-13, 13+ | Game engine | extra `godot` 4.7.2 | — | `org.godotengine.Godot` 4.7.2 | native | Very active | Yes | Teen "make a real game." Pixelorama and Tiled pair with it. |
| Processing / p5.js | 11-13, 13+ | Creative coding | — | `processing` 4.5.6 (2026-07) | not found | JVM | Active | Processing yes; p5 web | Sketch-based coding. |
| MakeCode Arcade | 8-10, 11-13 | Block/JS retro games | — | — | — | web (PWA) | — | Web | Microsoft, free; pin as web app. Not fetched this session. |
| TIC-80 | 8-10 → 13+ | Fantasy console (FOSS) | — | `tic-80-git` (2026-06) | not found under guessed id | SDL2 | Active | Yes | The FOSS PICO-8. Free version is enough for kids. |
| PICO-8 | 8-10 → 13+ | Fantasy console (commercial) | — | — | — | SDL2 | Active | Yes | **$15** DRM-free Linux build; free **Education Edition runs only in a browser**; educator seats $3 in blocks of 10 [S57][S58]. |
| Pyxel | 11-13, 13+ | Python retro engine | — | `python-pyxel` 2.9.5 (2026-05) | not found | SDL2 | Active | Yes | Python path to game-making. |
| Pixel Vision 8 | — | Fantasy console | — | none | none | — | Dormant (nothing packaged) | — | Skip. |
| Kiwix | 5-7 → 13+ | Offline Wikipedia/ZIM reader | extra `kiwix-desktop` 2.5.1 (2026-08) | — | `org.kiwix.desktop` 2.4.1 | Qt native | Active | **Yes — the point** | Serves Wikipedia, Khan Academy, TED, PhET, Gutenberg ZIMs offline [S42][S43]. |
| Anki | 8-10 → 13+ | Flashcards | extra `anki` 26.08.1 | — | `net.ankiweb.Anki` 26.08.1 | Qt6 | Active | Yes | Spaced repetition; parent-built decks. |
| LibreOffice | 8-10 → 13+ | Office | extra `libreoffice-fresh` 26.8.0 | — | yes | native | Active | Yes | School work. |
| Typst / Markdown | 13+ | Writing | extra `typst` 0.15.1 | — | — | CLI | Active | Yes | Teens who like the terminal. |
| JupyterLab | 13+ | Notebooks | extra `jupyterlab` 4.6.3 | — | — | web | Active | Yes | Teen science/data. |
| Thonny | 8-10 → 13+ | Beginner Python IDE | — | `thonny` 5.0.0 (2026-05) | `org.thonny.Thonny` 4.1.7 (2024-12) | Tk, XWayland | Active | Yes | Best first Python IDE; step debugger. |
| mu-editor | 8-10, 11-13 | Beginner Python IDE | — | `mu-editor` 1.2.0 (2023) | — | Qt5 | Dormant | Yes | Thonny is the maintained choice. |
| Hedy | 8-10, 11-13 | Gradual programming language | — | none | none | web | Active upstream; "Offline Hedy" zip is Windows-only per wiki [S56] | Web (or self-host) | Self-host the Python server on the box for offline; good Kids Mode backlog item. |
| Kojo | 8-10, 11-13 | Scala turtle/coding | — | none | none | JVM | Unverified | — | Not packaged; low priority. |
| Pixelorama | 8-10 → 13+ | Pixel art | — | `pixelorama` 1.2.1 (2026-08) | `com.orama_interactive.Pixelorama` 1.2.1 (2026-08) | Godot, native | Active | Yes | Kid-friendly sprite editor. Flatpak preferred. |
| Piskel | 8-10, 11-13 | Pixel art | — | — | — | web | — | Web | Browser fallback for Pixelorama. Not fetched. |
| LibreSprite | 8-10 → 13+ | Pixel art (Aseprite fork) | extra `libresprite` 1.2 (2025-09) | — | Flathub 1.1-dev (2021) | SDL/XWayland | Alive | Yes | Prefer Pixelorama for kids. |
| Tiled | 11-13, 13+ | Map editor | extra `tiled` 1.12.2 | — | `org.mapeditor.Tiled` | Qt native | Active | Yes | Pairs with Godot/Pyxel. |
| PuzzleScript, Bitsy, Twine | 8-10 → 13+ | Tiny game/story makers | — | — | — | web | — | Web | Zero-install creativity; pin as web apps. Not fetched this session. |
| Ren'Py | 11-13, 13+ | Visual novels | — | `renpy` 8.5.3 (2026-05) | not found under guessed id | SDL2 | Active | Yes | Teen storytelling. |
| RetroArch | 8-10 → 13+ | Emulation | extra `retroarch` 1.22.2 | — | `org.libretro.RetroArch` | native | Active | Yes | **Ship with homebrew/freeware cores only**; ROM dumps of owned cartridges are the user's legal call [S67][S68]. |
| DOSBox-X | 11-13, 13+ | DOS emulation | — | `dosbox-x` 2026.08.31 | `com.dosbox_x.DOSBox-X` 2026.08.02 | SDL2 | Very active | Yes | Only with freeware/shareware DOS titles; **exoDOS is abandonware (copyright infringement in most jurisdictions)** [S67][S68][S69]. |
| ScummVM | 8-10 → 13+ | Adventure games | extra `scummvm` 2026.3.0 | — | `org.scummvm.ScummVM` 2026.3.0 | SDL2 | Active | Yes | scummvm.org hosts 11 legally free games (Beneath a Steel Sky, Flight of the Amazon Queen, Drascula, Lure of the Temptress…) [S66]. Check content ratings per title. |
| Steam | 8-10 → 13+ | Store/launcher | multilib `steam` 1.0.0.87 | — | `com.valvesoftware.Steam` | native/XWayland | Active | Partially | Family View PIN + Steam Families child accounts with playtime limits and store/community locks work on the Linux client [S31][S32]. |
| Heroic / Lutris | 11-13, 13+ | Launchers | Lutris extra 0.5.22; Heroic Flathub 2.22.1 | — | both on Flathub | native | Active | No | Omarchy manual warns installs "feel slow and janky" and Fortnite/Rocket League cannot run (anti-cheat) [S11]. |
| Sober (Roblox) | 8-10 → 13+ | Roblox runtime | — | none | `org.vinegarhq.Sober` 1.7.1 (2026-06) | native | Active but "experimental", closed-source, unofficial [S14] | No | Wraps the Android Roblox build; x86 only; no Roblox Studio [S26]. |
| Jellyfin / Kodi | all | Media server/player | Jellyfin: Flathub server 10.11.11; Kodi Flathub 21.3 | — | yes | native | Active | Yes (LAN) | Curated local video library with per-user max parental rating, "block unrated", and tag-based blocking [S51][S52]. |

Wayland compatibility summary: everything Qt6/GTK4/SDL2 above runs natively on Hyprland. SDL1.2 titles (TuxMath, TuxTyping, Frozen Bubble) run through sdl12-compat/XWayland. Electron apps (Scratch/TurboWarp) should be launched with Wayland ozone flags in the `.desktop` override or accepted as XWayland. Flatpaks isolate the mess and are the right default for Kids Mode installs where both exist.

### 2. What kids 5-12 expect on a fresh device, and Linux feasibility

| Expectation | Linux status | Kids Mode stance |
|---|---|---|
| YouTube / YouTube Kids | Works in any browser; that is the problem | Block at DNS/browser policy; replace with a **curated local library** (Jellyfin or Kodi kid profile) [S51][S52] plus Kiwix TED-Ed/Khan ZIMs [S42]. Community member's proposal is the right default. |
| Minecraft | Java: yes, paid, via Prism Launcher; Omarchy already lists Minecraft under _Install > Gaming_ [S11]. Bedrock: mcpelauncher, fragile [S28] | Offer **Luanti** free by default; one-click Prism install if the family owns Java edition. |
| Roblox | Sober Flatpak: unofficial, closed-source, "use at your own risk… may be discontinued at any time" [S14]; active bug flow into Aug 2026 [S27] | Opt-in only, parent-installed, paired with Roblox's own account parental controls. Do not preinstall. |
| Fortnite | No (Easy Anti-Cheat); Omarchy's manual says so [S11] | Say no clearly; suggest SuperTuxKart split-screen for the "play with a friend" itch. |
| Scratch | TurboWarp desktop offline; web Scratch needs net | Preinstall TurboWarp; pin web Scratch for sharing (8+). |
| Khan Academy / Duolingo / Prodigy | Web apps, need accounts and net | Kiwix Khan ZIM offline; the rest as parent-approved web apps. |
| Spotify Kids / music | Spotify web works; kids tier is an app | Local music folder + a simple player; Sonic Pi for making music. |
| Steam games | Steam Family View + Steam Families child accounts [S31][S32] | Document the PIN + playtime-limit setup; do not preinstall. |

**Honest answer to the Discord "top 3 apps" question:** kids will assume (1) **YouTube**, (2) **Minecraft**, (3) **Roblox** — with Scratch as the top "school" expectation for 8-12. Omarchy Kids Mode should answer with: (1) a **curated video library** (Jellyfin/Kodi + Kiwix) instead of YouTube, (2) **Luanti preinstalled + one-click Minecraft Java** if owned, (3) **TurboWarp/Scratch + SuperTuxKart** as the creative/social pair, with Roblox via Sober as a documented, parent-gated opt-in.

### 3. Terminal fun for a sandboxed kids shell

All in Arch `extra` unless noted [S19][S20]:

| Package | Repo | Use | Kid-safety note |
|---|---|---|---|
| `cowsay` 3.8.4, `sl` 5.05, `figlet` 2.2.5, `toilet`, `lolcat` 100.0.1 | extra | Silly output, banners, rainbows | Safe. Combine: `figlet \| lolcat`. |
| `fortune-mod` 3.26.1 | extra | Random quotes | Arch's package **excludes** the offensive DB; offensive quotes are only in AUR `fortune-mod-off` [S36][S37]; `-o`/`-a` flags reach nothing unless that is installed [S38]. Still: the standard cookie files are adult-oriented in tone. **Ship a kid fortune file** (jokes, riddles, science facts) compiled with `strfile`, and point `fortune` only at it. |
| `asciiquarium` 1.1, `cmatrix` 2.0, `nyancat` 1.5.2 | extra | Screensavers/eye candy | Safe. `nyancat` is a great "first command" reward. |
| `bsd-games` 3.3 | extra | hangman, worm, snake, tetris-bsd, adventure, wump, arithmetic, quiz | `arithmetic` and `quiz` are secretly educational; review `fortune`-adjacent text games (`adventure`, `battlestar`) for tone; `bsd-games` does not include the fortune DB. |
| `bastet`, `vitetris` (69 votes), `tetris` (OpenBSD port) | AUR | Tetris | vitetris is the maintained pick. |
| `nsnake` (pkg 2015), `moon-buggy` (flagged out-of-date) | AUR | Snake, buggy | Legacy; `bsd-games` worm/snake cover it. |
| `cbonsai` 1.4.2 (2025), `pipes.sh`, `hollywood` 1.25 (2026) | AUR | Bonsai, pipes, "hacker movie" | Safe; `hollywood` is a hit with 8-12. |
| `tldr` 3.4.4 / `tealdeer` 1.9.0, `bat`, `fzf` | extra | Learning commands | `tldr` pages are the kid-readable man pages. |
| `ttyper-git`, `typioca`, `tt` | AUR | Terminal typing tests | Good for the typing workstream; ttyper is cleanest. |

**Shell-as-a-game precedents** [S33][S34][S35]: **Bashcrawl** (a dungeon made of directories; `cd`/`ls`/`cat` to explore; not packaged in AUR, clone from GitHub mirror) is the best fit for 8-12 and trivially themeable; **Terminus** (web game; note the AUR `terminus` package is an unrelated Pantheon CLI); **The Command Line Murders** (10+, needs reading stamina); **Command Challenge** and **OverTheWire Bandit** for teens. Vim Adventures, KeyCombiner, ShortcutFoo and Typing.io are commercial/web and were not verified this session.

A bwrap-sandboxed "kid shell" (blueprint §4.3) is sound: bind a curated `/usr/bin` subset, the kid fortune file, and a Bashcrawl dungeon under `$HOME/quest`.

### 4. Omarchy theme system (verified against 4.0)

**Structure.** Built-in themes live in `themes/<name>/` in the repo (20 directories on master: catppuccin, catppuccin-latte, ethereal, everforest, flexoki-light, gruvbox, hackerman, kanagawa, lumon, matte-black, miasma, nord, osaka-jade, retro-82, ristretto, rose-pine, tokyo-night, vantablack, white…) [S3]. `tokyo-night/` contains exactly: `btop.theme`, `colors.toml`, `icons.theme`, `keyboard.rgb`, `neovim.lua`, `preview-unlock.png`, `preview.png`, `unlock.png`, `vscode.json`, `backgrounds/` [S8]. The shell doc additionally describes `themes/<name>/shell.toml` (surface roles, `[spacing] scale`, `[font] base-size`, `[controls]` states normal/hover-cursor/focus/selected, `[bar] size-*`) with a machine-level override at `~/.config/omarchy/shell.toml` that survives theme switches [S15]. The older 3.x files (`hyprland.conf`, `walker.css`, `waybar.css`, `mako.ini`, `hyprlock.conf`, `alacritty.toml`) are **gone**; terminal/btop/Chromium/Hyprland/Neovim/Helix/VSCode/Obsidian configs are generated from `colors.toml` [S9]. Light themes set `mode = "light"` in `colors.toml` [S9]. Icons: `icons.theme` picks one of the Yaru variants [S9]. Custom app templates go in `~/.config/omarchy/themed/<config>.toml.tpl` [S9].

**Install/list.** User themes: `~/.config/omarchy/themes/`. Community themes are GitHub repos named `omarchy-<name>-theme`, installed with _Install > Style > Theme_ (paste URL), removed with _Remove > Theme_; switch with `Super+Ctrl+Shift+Space`, backgrounds with `Super+Ctrl+Space` [S9][S10][S12]. The official "Extra Themes" page is omarchy.org/themes (60+ entries, e.g. Ayaka, Batman, Dracula, Event Horizon, NES, Omacarchy, Pink Blood, Sakura Mochi) [S22]; awesome-omarchy lists [S23][S24] and the `omarchy-themes` GitHub topic [S25] are the community indexes. Popularity is not ranked anywhere official; Dracula/Catppuccin/Batman/NES recur across lists. There is also an "Aether" GUI theme creator referenced in the manual [S9] (not verified further).

**Kids theme guidelines (proposal).**
- Contrast: WCAG AA 4.5:1 minimum body text, 7:1 for the 3-7 preset; verify `colors.toml` pairs with a contrast checker in CI.
- Size: `shell.toml` `[spacing] scale = 1.4` (3-7) / `1.2` (8-12) and `[font] base-size` bumped; bar `size-*` ≥ 44px-equivalent hit targets [S15].
- Fonts: **Atkinson Hyperlegible** is in `extra` (`ttf-/otf-atkinson-hyperlegible` 1.006; AUR `otf-atkinson-hyperlegible-next`) [S19][S20]; **Lexend** (SIL OFL) via AUR `lexend-fonts-git` [S20][S59]; **OpenDyslexic** (SIL OFL per [S59]) is not in AUR under that name — vendor it. Offer the font as a per-child toggle, not a theme fork.
- Color-blind safety: keep the eight `color0-15` roles distinguishable in deuteranopia; prefer an Okabe-Ito-style accent set (not verified this session; standard practice).
- Two moods: **Low-stimulation** (base on `flexoki-light` / `catppuccin-latte`, muted accents, no animated backgrounds) and **Playful** (base on community `NES` / `retro-82`, saturated primaries). Ship both per mascot.
- Per-age presets: `kids-3-7` (light, huge, few colors), `kids-8-12` (either mood), `teen` (any stock theme + Hyperlegible).
- Backgrounds: license-safe sources are Wikimedia Commons (CC/PD) and NASA imagery (PD) — both are well-known; not fetched this session. Every `backgrounds/` file gets a `CREDITS.md` line.
- Sound: Omarchy 4.0 notifications are in-shell; a sound theme would need a small `service` plugin. Source CC0 audio (Kenney, freesound CC0 filter — not verified this session).

**Mascot / character packs (instead of boy/girl).** Present 3-5 characters at onboarding; each maps to a theme, a fortune voice, and an avatar.

| Mascot | Project | License (evidence) | OK for packs? |
|---|---|---|---|
| Tux | Linux | Larry Ewing: "anyone may use for any purpose, provided proper attribution (Larry Ewing and The GIMP)"; Garrett LeSage SVG contributions CC0 [S18] | Yes, attribute. |
| Konqi | KDE | CC BY-SA 4.0 or LGPL 2.1+, Tyson Tan [S17] | Yes (share-alike). Katie/Konqi variants exist. |
| Wilber | GIMP | CC BY-SA 4.0 (Aryeom Han SVG) [S39] | Yes. |
| Kiki | Krita | Tyson Tan; license not verified this session | Likely CC BY-SA; verify before use. |
| Freedo | Linux-libre | not verified this session [S13] | Verify. |
| GNU head | FSF | not verified this session | FSF has specific terms; verify. |
| Beastie | BSD | Copyright held by an individual; historically requires permission | Avoid. |
| Suzanne | Blender | not verified this session | Verify; monkey head is 3D-only anyway. |
| Xue (Xfce mouse), Puffy (OpenBSD) | — | not verified | Optional. |

Default = neutral "explorer" (Tux). Avatars: generate from the same SVGs (hats/colors) to avoid third-party licensing.

### 5. Gamified learning of the Omarchy way

- **Cheat sheet:** `Super+K` shows all main bindings; Tmux/Herdr bindings on modifier variants; bindings live in `~/.config/hypr/bindings.lua` in 4.0 (Lua DSL, e.g. `o.bind("SUPER + SHIFT + W", ...)`) [S7][S12]. The popup is generated from the user's own config [S49], so a kids binding set will produce its own kid-sized cheat sheet for free.
- **Existing trainers:** typing — KTouch, Klavaro, TuxTyping (legacy), ttyper. Shortcut trainers — none for Hyprland/tiling WMs found [S70]; commercial web ones (Vim Adventures, ShortcutFoo, KeyCombiner) exist but were not verified.
- **Toolkit:** Omarchy 4.0 **is** Quickshell (QtQuick/QML) with plugin kinds `overlay` and `panel`, IPC `summon/hide/toggle/call`, and `Color`/`Style`/`Border` singletons for theme-aware widgets [S15]. Small games and trainers therefore belong in QML overlays — they inherit the kid theme automatically. Larger games: Godot (extra), TIC-80, Pyxel; web/PWA via Omarchy's Web Apps feature [S4].
- **Blueprint ideas assessed:**
  - *QML touch-typing trainer* — feasible in a day as an overlay, but KTouch already exists. Recommend a thin **"home-row hint" overlay** that can be summoned over any app, plus KTouch for real lessons.
  - *Shortcut Target Practice* — novel; feasible: an `overlay` plugin draws targets, `hyprctl` reports window geometry, the kid moves/resizes windows with `Super+Arrow`/`Super+Shift+Arrow` to cover targets. Chunkable, theme-aware, no prior art. **Recommended flagship mini-game.**
  - *PICO-8 companion* — PICO-8 is commercial; a "read-only cartridge browser" is possible with **TIC-80** (FOSS) instead. Downgrade to "TIC-80 cartridge shelf" backlog item.
  - *Voxtype "Sol"* — Voxtype is real and local (F9 hold / Super+Ctrl+X, 150MB base model, `~/.config/voxtype/config.toml`) [S16]; it is speech-to-text only. Voice-to-code needs an LLM and is out of scope for v1; keep dictation as an accessibility feature for pre-readers.

### 6. Offline / local content

- **Kiwix** (extra 2.5.1) with ZIMs for Wikipedia (many languages/sizes), Khan Academy, TED/TED-Ed, PhET simulations, Project Gutenberg, Wikibooks, Wiktionary [S42][S43][S44]. The historic "Wikipedia for Schools" ZIM was not confirmed in this session — check library.kiwix.org and prefer the current "Simple English Wikipedia" ZIM for 8-12.
- **Video:** Jellyfin server (Flathub 10.11.11) per-user *Maximum allowed parental rating*, *Block items with no or unrecognized rating* (fixed for NR in 10.11.0), and tag-based blocking; 10.11 had a season-visibility regression under rating limits — test [S51][S52][S53]. Kodi (Flathub 21.3) profiles with master-lock are the simpler single-box alternative.
- **Audio:** LibriVox public-domain audiobooks and local podcasts via any player; not fetched this session.
- **Luanti worlds** as offline "content" too — a family LAN server is a compelling sibling feature.

## Blueprint claims checked

| Claim (blueprint §4/§5/§7/§8) | Verdict | Evidence |
|---|---|---|
| Kid shell "written using the Quickshell layout engine" | **Now true** — Omarchy 4.0 (2026-08-14) is a single Quickshell process with plugins | [S7][S15][S45][S47] |
| Omarchy repo is basecamp/omarchy | Superseded — canonical is `omacom/omarchy` (36.7k stars); basecamp URL redirects | [S3][S7] |
| `Super+K` cheat sheet | Verified | [S12] |
| Voxtype is Omarchy's local offline dictation engine; config at `~/.config/voxtype/config.toml` | Verified | [S16] |
| Push-to-talk on `Super+V` | **Wrong** — F9 hold, or `Super+Ctrl+X` toggle | [S16] |
| "Sol" voice-to-code assistant | Does not exist; Voxtype is STT only | [S16] |
| QML touch-typing trainer as Quickshell component | Feasible but redundant with KTouch/Klavaro; reduce to hint overlay | [S15][S19] |
| "Shortcut Target Practice" window-tiling game | Feasible, novel, no prior art found | [S15][S70] |
| PICO-8 companion widget with read-only carts | PICO-8 is $15 commercial; Education Edition browser-only; use TIC-80 | [S57][S58][S20] |
| `cowsay`, `sl`, `fortune` as approved binaries | OK; Arch `fortune-mod` already excludes offensive DB; still curate a kid file | [S36][S37][S38] |
| "DOSBox mapping" inside bwrap (BACK-08) | Technically fine (DOSBox-X in AUR/Flathub) but content sourcing (exoDOS) is copyright infringement; low kid appeal → deprioritize; use ScummVM freeware list | [S20][S21][S66][S67][S68] |
| Bibliography entries `github.com/omarchy/kids-mode/docs/*.md` | **Fabricated** — `github.com/omarchy` is an unrelated 3-star profile with only a README | [S1] |
| Bibliography placeholder IDs (`/12345`, `/123456`) | Fabricated/unverifiable | [S6-style pattern; not fetched] |
| Sugar Labs "activities" as a model | Sugar is dormant on Arch/Flathub (2020-21 dates); ideas yes, code no | [S20][S21] |

## Implications & recommendations

**Starter packs (Flatpak where both exist; everything offline-capable):**
- **3-5:** GCompris, Tux Paint, KTuberling, Blinken, Kolf, Stellarium (parent-driven), `nyancat`/`sl`/`cowsay` rewards. Theme `kids-3-7` light/low-stim, spacing scale 1.4, Atkinson Hyperlegible.
- **5-7:** above + SuperTux, SuperTuxKart (local split-screen), KTurtle, KLettres, Kanagram, Jellyfin/Kodi kid profile, Kiwix Simple-English Wikipedia ZIM. Bashcrawl-lite (3 rooms).
- **8-10:** TurboWarp (Scratch), Luanti (+ Classroom mod), KTouch, KHangMan/KGeography, Pixelorama, Sonic Pi, Kiwix Khan/TED-Ed ZIMs, Thonny (optional), full Bashcrawl, `hollywood`, `cbonsai`. Shortcut Target Practice unlocks Level 2 tiling.
- **11-13:** + Godot, Tiled, TIC-80, Pyxel, Krita, LMMS/Tenacity, Marble, KStars, Anki, LibreOffice, ScummVM freeware pack, Steam with Family View; Minecraft Java if owned; Roblox via Sober only by parent opt-in.
- **13+:** any stock Omarchy theme + Hyperlegible; Jupyter, Typst, Processing, Ren'Py, Inkscape, Heroic/Lutris (parent-installed).

**Theme guidelines:** ship as `omarchy-kids-<mascot>-theme` repos following the naming convention so they install through the stock menu [S9]; each repo carries `colors.toml`, `shell.toml` with the age preset, `backgrounds/` + `CREDITS.md`, `icons.theme`, `preview.png`, `unlock.png`. Provide a `kids-theme-lint` script (contrast, font presence, license file).

**Top-3 answer for Discord:** "Kids will expect YouTube, Minecraft and Roblox. We give them a curated video library, Luanti + one-click Minecraft Java, and Scratch (TurboWarp) + SuperTuxKart — Roblox stays a parent opt-in via Sober."

## Candidate workstreams / backlog items

Good first issues marked (GFI).
1. (GFI) **Package audit script** — reproduce the Arch/AUR/Flathub availability table from the three public APIs; run in CI monthly.
2. (GFI) **Kid fortune file** — 300+ jokes/riddles/facts, CC0, `strfile`-compiled, wired as the only fortune DB in the kid sandbox.
3. (GFI) **`omarchy-kids-tux-theme`** — first mascot theme: `colors.toml` (light, AA 7:1), `shell.toml` spacing 1.4, Hyperlegible, CC0/PD backgrounds with credits.
4. **`omarchy-kids-konqi-theme`, `-wilber-theme`** — playful palettes; share-alike licensing notes.
5. **kids-theme-lint** — contrast + license + required-file checker for theme PRs.
6. **Shortcut Target Practice** — Quickshell `overlay` plugin + `hyprctl` geometry; levels map to blueprint's progressive disclosure.
7. **Home-row hint overlay** — tiny QML overlay; pairs with KTouch launcher.
8. **Bashcrawl-Omarchy fork** — themed rooms, mascot narration, safe binary allowlist; bwrap launcher script.
9. (GFI) **Curated web-app list** — Blockly Games, MakeCode Arcade, Piskel, PuzzleScript, Bitsy, Turtle Blocks, Hedy — as Omarchy Web Apps with an allowlist.
10. **Hedy self-host recipe** — run Hedy locally for offline gradual programming.
11. **Luanti kids world** — preconfigured world + Classroom/EDU mods + LAN-only server, chat off.
12. **Jellyfin/Kodi kid-profile playbook** — parental rating, block-unrated, tag blocking; test 10.11 regressions.
13. **Kiwix starter ZIM set** — sizes, links, and a download script; verify "Wikipedia for Schools" status.
14. **TIC-80 cartridge shelf** — read-only browser of CC-licensed carts (replaces PICO-8 companion).
15. **Mascot license registry** — verify Kiki, Freedo, GNU, Suzanne, Puffy, Xue; store SVG sources + attributions.
16. **Sound theme service plugin** — CC0 sounds for notifications/rewards.
17. (GFI) **Docs:** "Roblox on Omarchy (Sober) — parent guide" and "Steam Family View on Omarchy".

## Open questions for the community

1. Do we target Flatpak-first for kid apps (sandboxing, freshness) even though Omarchy is pacman/AUR-first?
2. Which mascots beyond Tux/Konqi/Wilber are worth the license legwork? Any artists willing to draw a Kids Mode original under CC0?
3. Is Roblox (Sober) in or out of the "supported" list? It is closed-source and could vanish.
4. Should the kid fortune/joke corpus be multilingual from day one (GCompris is)?
5. How far do we go on YouTube: DNS block only, or also a local FreeTube/Invidious-style allowlisted viewer? (not researched here)
6. Does Omarchy upstream want a `kids` plugin `kind`, or do we ship everything as third-party plugins?
7. Who owns the "Wikipedia for Schools" ZIM question and the Kiwix starter set sizes?

## Sources

Status: VERIFIED = fetched directly this session; SEARCH-ONLY = appeared in search results, not fetched; DEAD-UNVERIFIABLE = could not be confirmed. Accessed 2026-09-01.

- [S1] github.com/omarchy/omarchy — https://github.com/omarchy/omarchy — VERIFIED — Unrelated "config files for my GitHub profile" repo, 3 stars; proves blueprint's `omarchy/kids-mode` refs are fabricated.
- [S2] Hotkeys · Omarchy 3 Manual — https://learn.omacom.io/2/the-omarchy-manual/53/themes — VERIFIED — URL resolves to the hotkeys page; theme hotkeys, backgrounds dir.
- [S3] Omarchy themes directory — https://github.com/basecamp/omarchy/tree/master/themes — VERIFIED — Redirects to omacom/omarchy; 20 theme dirs; 36.7k stars.
- [S4] Omarchy Manual TOC — https://omarchy.org/manual/ — VERIFIED — 51 pages incl. Themes, Hotkeys, Gaming, Web Apps, Making your own theme, Text Extraction & Dictation.
- [S5] vinegarhq/sober — https://github.com/vinegarhq/sober — VERIFIED — Issue-tracker repo; "Not affiliated with Roblox"; 1.1k stars.
- [S6] omarchy-shell.md (master) — https://github.com/omacom/omarchy/blob/master/docs/omarchy-shell.md — DEAD-UNVERIFIABLE — 404 on master; see S15.
- [S7] Release v4.0.0 — https://github.com/omacom/omarchy/releases/tag/v4.0.0 — VERIFIED — 2026-08-14; Quickshell shell; plugin add; bindings.lua; shell.toml override.
- [S8] themes/tokyo-night — https://github.com/omacom/omarchy/tree/master/themes/tokyo-night — VERIFIED — Exact theme file list.
- [S9] Making your own theme — https://omarchy.org/manual/making-your-own-theme/ — VERIFIED — colors.toml, mode=light, icons.theme, themed/*.tpl, naming convention, install path.
- [S10] Themes — https://omarchy.org/manual/themes/ — VERIFIED — Built-ins, hotkeys, Extra themes page reference.
- [S11] Gaming — https://omarchy.org/manual/gaming/ — VERIFIED — Install > Gaming list incl. Minecraft; Fortnite/Rocket League anti-cheat caveat.
- [S12] Hotkeys — https://omarchy.org/manual/hotkeys/ — VERIFIED — Super+K; theme/background/menu keys; bindings.lua.
- [S13] Free Software Mascots — https://jxself.org/mascots.shtml — VERIFIED — Lists GNU, Freedo, Wilber, Konqi; no license detail.
- [S14] Sober site — https://sober.vinegarhq.org/ — VERIFIED — flatpak id org.vinegarhq.Sober; unofficial, closed-source, may be discontinued.
- [S15] omarchy-shell.md (quattro) — https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md — VERIFIED — Plugin manifest/kinds/dirs, shell.toml keys, IPC commands.
- [S16] Text Extraction & Dictation — https://omarchy.org/manual/text-extraction-dictation/ — VERIFIED — Voxtype; F9 hold / Super+Ctrl+X; tesseract OCR.
- [S17] Konqi by Tyson Tan — https://commons.wikimedia.org/wiki/File:KDE_Mascot_Konqi_by_Tyson_Tan.png — VERIFIED — CC BY-SA 4.0 / LGPL 2.1+.
- [S18] Tux.svg — https://commons.wikimedia.org/wiki/File:Tux.svg — VERIFIED — Ewing permission with attribution; LeSage CC0.
- [S19] Arch package JSON API — https://archlinux.org/packages/search/json/ — VERIFIED (curl, 90 names) — Official repo versions/dates in the catalog.
- [S20] AUR RPC v5 — https://aur.archlinux.org/rpc/v5/ — VERIFIED (curl, ~90 names) — AUR versions, last-modified, votes, out-of-date flags.
- [S21] Flathub appstream API — https://flathub.org/api/v2/appstream/ — VERIFIED (curl, ~70 ids) — Flathub presence/versions; 404 = not found under guessed id.
- [S22] Omarchy — The Extra Themes — https://omarchy.org/themes/ — SEARCH-ONLY — 60+ community themes incl. NES, Batman, Dracula.
- [S23] Wheel-Smith/awesome-omarchy — https://github.com/Wheel-Smith/awesome-omarchy — SEARCH-ONLY — Community index.
- [S24] aorumbayev/awesome-omarchy — https://github.com/aorumbayev/awesome-omarchy — SEARCH-ONLY — Community index.
- [S25] omarchy-themes topic — https://github.com/topics/omarchy-themes — SEARCH-ONLY — GitHub topic listing.
- [S26] Roblox on Linux 2026 guide — https://caniplayonlinux.com/guides/roblox-on-linux/ — SEARCH-ONLY — Sober wraps Android build; x86 only; no Studio.
- [S27] Sober issues — https://github.com/vinegarhq/sober/issues — SEARCH-ONLY — Active bug flow Aug 2026.
- [S28] mcpelauncher-manifest issue #1707 — https://github.com/minecraft-linux/mcpelauncher-manifest/issues/1707 — SEARCH-ONLY — "cave full of tnt" DRM warning (2026-02-22); latest Play version unsupported.
- [S29] mcpelauncher releases — https://github.com/minecraft-linux/mcpelauncher-manifest/releases — SEARCH-ONLY — v1.7.6 2026-06-25.
- [S30] Playing Minecraft on Linux — https://minecraft.wiki/w/Tutorial:Playing_Minecraft_on_Linux — SEARCH-ONLY — Bedrock requires Google Play purchase.
- [S31] Steam Families guide — https://steamdb.com/en/articles/steam-family-sharing-complete-guide — SEARCH-ONLY — Child accounts, playtime limits.
- [S32] Steam parental controls — https://www.internetmatters.org/parental-controls/gaming-consoles/steam/ — SEARCH-ONLY — Family View PIN steps.
- [S33] 3 command line games — https://opensource.com/article/19/10/learn-bash-command-line-games — SEARCH-ONLY — Bashcrawl description.
- [S34] notklaatu/bashcrawl — https://github.com/notklaatu/bashcrawl — SEARCH-ONLY — GitHub mirror.
- [S35] 5 games for learning Linux — https://devopschops.com/blog/games-for-learning-linux/ — SEARCH-ONLY — Bashcrawl → Command Challenge → Bandit → CLI Murders path.
- [S36] FS#76593 fortune-mod — https://bugs.archlinux.org/task/76593 — SEARCH-ONLY — Background on removing offensive DB from Arch package.
- [S37] AUR fortune-mod-off — https://aur.archlinux.org/packages/fortune-mod-off — SEARCH-ONLY/VERIFIED via RPC — Offensive DB lives here only.
- [S38] fortune(6) — https://man.archlinux.org/man/fortune.6.en — SEARCH-ONLY — `-o`/`-a` semantics.
- [S39] GIMP linking page — https://www.gimp.org/about/linking.html — SEARCH-ONLY — Wilber SVG CC BY-SA 4.0 (Aryeom Han).
- [S40] Category:Free software mascots — https://commons.wikimedia.org/wiki/Category:Free_software_mascots — SEARCH-ONLY — Source for further mascot license checks.
- [S41] Tyson Tan — https://en.wikipedia.org/wiki/Tyson_Tan — SEARCH-ONLY — Konqi/Kiki artist; free-licensed work.
- [S42] Kiwix catalog — https://get.kiwix.org/en/solutions/catalog/ — SEARCH-ONLY — Wikipedia, Khan, TED, PhET, Gutenberg.
- [S43] Best Kiwix ZIMs — https://ostechnix.com/best-kiwix-zim-files/ — SEARCH-ONLY — Sizes/examples.
- [S44] Kiwix Hub — https://hub.kiwix.org/ — SEARCH-ONLY — Download hub.
- [S45] Omarchy 4.0 (desdelinux) — https://blog.desdelinux.net/en/omarchy-4.0-release-new-features-quickshell-omakase/ — SEARCH-ONLY — Quickshell rewrite summary.
- [S46] PR #6231 Omarchy Quattro — https://github.com/omacom/omarchy/pull/6231 — SEARCH-ONLY.
- [S47] PR #5856 Omarchy goes Quickshell — https://github.com/omacom/omarchy/pull/5856 — SEARCH-ONLY.
- [S48] Quattro upgrade checklist — https://omarchypulse.com/articles/upgrading-to-quattro — SEARCH-ONLY.
- [S49] Omarchy has 227 shortcuts — https://www.pacyfist.dev/posts/omarchy-has-227-shortcuts-heres-how-i-remember-them/ — SEARCH-ONLY — Super+K popup generated from user config.
- [S50] Omarchy cheat sheet — https://acrogenesis.com/omarchy-cheat-sheet/ — SEARCH-ONLY — Printable reference.
- [S51] Jellyfin "max parental rating does not filter NR" — https://forum.jellyfin.org/t-solved-maximum-allowed-parental-rating-does-not-filter-nr-content — SEARCH-ONLY — Block-unrated fixed in 10.11.0.
- [S52] Jellyfin multi-user & parental controls guide 2026 — https://jellywatch.app/blog/jellyfin-multi-user-parental-controls-guide-2026 — SEARCH-ONLY — Tag blocking.
- [S53] Jellyfin issue #13338 — https://github.com/jellyfin/jellyfin/issues/13338 — SEARCH-ONLY — Custom rating vs parental rating.
- [S54] jfo8000/ScratchJr-Desktop — https://github.com/jfo8000/ScratchJr-Desktop/ — SEARCH-ONLY — Community Mac/Win port.
- [S55] AUR scratchjr-desktop-git — https://aur.archlinux.org/packages/scratchjr-desktop-git — SEARCH-ONLY/RPC — 2021, 0 votes.
- [S56] Offline Hedy wiki — https://github.com/hedyorg/hedy/wiki/Offline-Hedy — SEARCH-ONLY — Offline zip is Windows.
- [S57] PICO-8 for schools — https://www.lexaloffle.com/pico-8.php?page=schools — SEARCH-ONLY — $3/seat blocks of 10.
- [S58] PICO-8 Education Edition for Web — https://www.lexaloffle.com/bbs/?tid=47278 — SEARCH-ONLY — Free browser edition; $15 desktop.
- [S59] Best dyslexia fonts 2026 — https://focusflowapp.in/blog/best-dyslexia-fonts-for-web — SEARCH-ONLY — OFL for OpenDyslexic/Lexend; Atkinson under Braille Institute license.
- [S60] Highly legible fonts — https://chris.bur.gs/highly-legible-fonts/ — SEARCH-ONLY.
- [S61] Luanti for Education — https://www.luanti.org/en/education/ — SEARCH-ONLY.
- [S62] ContentDB education mods — https://content.luanti.org/packages/?page=1&tag=education&type=mod — SEARCH-ONLY.
- [S63] Classroom mod — https://forum.luanti.org/viewtopic.php?t=23715 — SEARCH-ONLY.
- [S64] modpack4Edu — https://github.com/minetest4edu/modpack4Edu — SEARCH-ONLY.
- [S65] minetest-edutest-ui — https://github.com/apienk/minetest-edutest-ui — SEARCH-ONLY.
- [S66] ScummVM Games — https://www.scummvm.org/games/ — SEARCH-ONLY — 11 freeware titles.
- [S67] ROMs and abandonware law — https://www.somethingawful.com/video-game-article/rom-abandonware-law/ — SEARCH-ONLY.
- [S68] Abandonware — https://en.wikipedia.org/wiki/Abandonware — SEARCH-ONLY — No legal abandonware status.
- [S69] ExOv5 on Internet Archive — https://archive.org/details/exov5_2 — SEARCH-ONLY — Gray-area distribution; do not bundle.
- [S70] Hyprland cheatz — https://cheatography.com/paulie421/cheat-sheets/hyprland-cheatz/ — SEARCH-ONLY — Search for a Hyprland keybind trainer game returned only cheat sheets; none found.
- [S71] Extra themes · Omarchy 3 Manual — https://learn.omacom.io/2/the-omarchy-manual/90/extra-themes — SEARCH-ONLY.
- [S72] Blueprint refs `github.com/omarchy/kids-mode/blob/main/docs/*.md`, `forum.f-droid.org/t/kid-launcher/12345`, `reddit.com/r/pico8/comments/p8launcher_compa…` — DEAD-UNVERIFIABLE — Placeholder IDs / nonexistent repo (see S1).

Counts: VERIFIED 21 (S1-S5, S7-S21) · SEARCH-ONLY 49 (S22-S71) · DEAD-UNVERIFIABLE 2 (S6, S72).
