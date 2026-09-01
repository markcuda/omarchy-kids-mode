# Omarchy Platform: Current State & Extension Points

_Research report · Omarchy Kids Mode · 2026-09-01 · status: draft_

## TL;DR

- **Current release: Omarchy 4.0.2 (2026-08-31).** Omarchy 4 "Quattro" shipped 2026-08-14; 4.0.1 (08-25) and 4.0.2 (08-31) were security fast-follows. The `quattro` branch is now the **default branch** of the canonical repo **github.com/omacom/omarchy** (36.7k stars, MIT). `basecamp/omarchy` URLs redirect; `github.com/omarchy/omarchy` is an unrelated 3-star profile repo. [S1][S4][S6][S7][S8]
- **Quattro rewrote the whole desktop shell in Quickshell** (`omarchy-shell`): bar, launcher, menus, notifications, OSDs, control panels, lock screen and polkit agent are all plugins in one process. Waybar, Walker, Mako, SwayOSD, hyprlock, hypridle, swaybg and polkit-gnome are gone. [S6][S9]
- **An official plugin system exists and is the primary extension point.** `manifest.json` (schemaVersion 1) + QML; six kinds (`bar-widget`, `panel`, `overlay`, `menu`, `service`, `bar`); installed to `~/.config/omarchy/plugins/<id>/` via `omarchy plugin add <git-url>`; the `omarchy.` id namespace is **reserved** for first-party. Community directory: plugins.omarchy.org (22 registered sources) backed by `omacom/omarchy-plugin-marketplace`. [S14][S20][S21][S22]
- **Omarchy is single-user by design** (LUKS full-disk encryption is the gate; SDDM ships with ISO-managed autologin). A community comment in the official "Support Multiple Users" discussion says multi-user is "coming in 4.1", citing a DHH post — second-hand, not yet confirmed by DHH text I could fetch. An `agent-accounts` branch exists (separate accounts for coding agents), which shows account infrastructure is being built. [S23][S35][S47][S52]
- **Verified stack (4.x):** Hyprland (config now in **Lua**, targeting 0.56), Quickshell shell, Foot terminal (default), Chromium (default browser, plain build, machine-level managed policies), **Limine** bootloader + UKI, **btrfs** + **Snapper** + `limine-snapper-sync`, mandatory **LUKS**, **NetworkManager**, **systemd-resolved**, **ufw** (deny-in/allow-out, ufw-docker), **uwsm** present, **SDDM** present, Plymouth, Voxtype dictation, Tesseract OCR. **No AppArmor** in the package lists. [S6][S31][S33][S34][S35][S36][S39]
- **Config layout:** Omarchy internals moved from a git checkout to Arch packages (`omarchy`, `omarchy-settings`) at `/usr/share/omarchy` (`$OMARCHY_PATH`); user-owned intent lives in `~/.config/omarchy/` (themes, hooks, plugins, `shell.json`, `shell.toml`, `extensions/omarchy-menu.jsonc`, `themed/*.tpl`); generated state in `~/.local/state/omarchy/`. Migrations are per-user, timestamp-named shell scripts under `migrations/`. [S26][S27]
- **Themes are colors-only when installed from git**: since 4.0.1 any `.lua`, terminal config or `vscode.json` in a third-party theme is stripped ("Installing someone's theme should change what your desktop looks like, never what it runs"). Naming convention `omarchy-<name>-theme`; ~300+ community themes cataloged at omarchy.org/themes. [S7][S38][S43]
- **"omarchy-clarity" does not exist.** No content filter or DNS filtering feature ships; built-in DNS control is `omarchy dns` / Setup > Network > DNS (Cloudflare, Google, DHCP, custom) on systemd-resolved. Voxtype is real but the hotkeys are hold-`F9` / toggle `Super+Ctrl+X`, not `Super+V`. [S15][S48]
- **A parallel effort already exists: `jfuerwentsches/omarchy-kids`** (created 2026-08-27, pushed 2026-08-30): age-tiered config layer + Rust agent/daemon on the child machine + Qt control center and Quickshell plugin on the parent machine, over SSH; "early concept, not usable yet". Coordinate, don't duplicate. [S44]
- **Contribution policy:** GitHub issues are for verified bugs only; feature ideas go to Discussions > Suggestions; support goes to Discord. `AGENTS.md` is "the authority on contributions"; run `./test/all`. Cloudflare sponsorship (CDN/R2/DDoS) is real: blog post 2025-09-22. The Omacom Foundation launched Aug 2026 with $12.6M pledged. [S11][S13][S28][S30]

## Findings

### 1. Release state, canonical locations, community

**Version & cadence.** Releases via gh API: v3.8.0 (2026-05-09), 3.8.1 (05-14), 3.8.2 (05-24), 3.8.3 (07-13), 3.8.4 (07-21), **v4.0.0 (2026-08-14)**, v4.0.1 (08-25), **v4.0.2 (08-31)**. The `version` file on the `quattro` branch HEAD reads `4.0.0.alpha` (dev tree; not the release number). Repo `pushed_at` was 2026-09-01T16:11Z, i.e., very active. [S4]

**What changed in the last ~6 months (3.7/3.8 → 4.0.x).** From the v4.0.0 notes [S6]: entire shell reimagined in Quickshell; Omarchy internals moved from git to system packages "for safely separating user modifications"; dual-boot install; **"Setup a machine for a new owner during install, so OEMs and gift givers can prepare a machine for others"**; **factory reset (`Setup > Reset Computer`)**; ISO shrunk under 6 GB, installs 30% faster; all Hyprland configs converted to Lua for 0.56 compatibility; theme palette expanded from 8 to 24 colors so btop/nvim/vscode themes are autogenerated; NetworkManager for the new network panel; launcher merged into the Omarchy menu (`Super+Space`); text scaling across shell/GTK/terminals; plugin system + ecosystem; Omawrite/Omacut/Omacalc default apps; configurable default coding agent; new themes Solitude, Last Horizon, Lupine; window position saving; Foot as default terminal; Tensaku replaces Satty; Moonlight client; udiskie automount. The 4.0.1 and 4.0.2 notes are dominated by **security hardening** reviewed by a new Omarchy Security team (theme code-stripping, plugin-add URL guards, docker group opt-in, signed packages required from the Omarchy repo, sudoers tightening, SSH hardening, shell-injection fixes). [S7][S8] The Quattro PR (#6231, opened 2026-07-17, 1,998 commits) documents the upgrade path `Update > Omarchy` → `Update > Omarchy to Quattro`. [S9] Phoronix confirms the 08-14 date and the Quickshell consolidation. [S10]

**Canonical URLs.** Website omarchy.org [S1]; repo github.com/omacom/omarchy (branches include `quattro` (default), `dev`, `agent-accounts`, many `fix/*`) [S4]; **manual at omarchy.org/manual/** (51 chapters; authoritative source is `manual/` in the repo, mirrored to learn.omacom.io) [S5][S14]; legacy "The Omarchy 3 Manual" remains at learn.omacom.io/2/the-omarchy-manual/ and explicitly notes that v4 has its own manual [S2]; Discord invite `https://discord.gg/tXFUdasqhY` (also `omarchy.org/discord`) [S1][S28]; ISO `https://iso.omarchy.org/omarchy-4.0.2.iso` [S1]; plugins directory `omarchyplugins.com` → `plugins.omarchy.org` [S20]; extra themes `omarchy.org/themes/` [S43]; security reporting `security@omarchy.org` [S12]. The omacom org also hosts `omarchy-iso`, `omarchy-pkgs`, `omarchy-mirror`, `omarchy-chromium`, `omarchy-configurator`, `aether` (theme GUI, 671 stars), `omarchy-plugin-marketplace`, `omarchy-plugin-registry`, `omarchy-site`, `quickshell` (fork), `omawrite`, `omacut`, `omacalc`, plus retired omakub/omamac/omaterm. [S46]

**Foundation & sponsorship.** The Omacom Foundation (announced 2026-08-21) will "hold the trademarks, fund the infrastructure, promote the work, and support the open-source projects and developers Omarchy depends on"; 12 Founding Patrons at $1M each plus two corporate patrons at $100k/yr for three years ($12.6M total; the URL slug says "8 million", the page text says 12.6). No grant program is described. [S11] Cloudflare's post "Supporting the future of the open web: Cloudflare is sponsoring Ladybird and Omarchy" (2025-09-22, Sam Rhea) confirms CDN, R2 storage and DDoS protection; no dollar figure. [S13]

**Community norms.** Issue template header: "Remember: Omarchy is an open source gift, not a product you bought from a vendor"; blank issues disabled; bug template "NOT FOR SUPPORT REQUESTS". [S30] (See §7.)

### 2. Core stack (verified against `install/omarchy-base.packages`, `etc/`, `install/`, release notes)

| Component | Verified state (4.0.x) | Evidence |
|---|---|---|
| Compositor | Hyprland; configs converted to **Lua** "for full 0.56 compatibility" (`~/.config/hypr/{hyprland,bindings,input,looknfeel,monitors,autostart}.lua`; `o.bind("SUPER + SHIFT + W", ...)` DSL) | [S6][S4 tree] |
| Bar / launcher / menu / notifications / OSD / lock / polkit | All Quickshell plugins inside `omarchy-shell` (`shell/plugins/{bar,menu,notifications,osd,lock,polkit,panels,clipboard,emojis,...}`). Waybar, Walker, Mako, SwayOSD, hyprlock, hypridle, swaybg, polkit-gnome removed. | [S6][S9][S4 tree] |
| Terminal | **Foot** default ("for better resource utilization"); Alacritty/Ghostty/Kitty configs still shipped and themed | [S6][S38] |
| Browser | **Chromium** (plain build) default; Chrome/Edge/Brave/Brave Origin/Firefox/Zen installable; Chromium-family get machine-level managed policies at `/etc/chromium/policies/managed` (root-owned 0755, hardened in 4.0.2) and two Omarchy extensions (Copy URL, Download Video) | [S32][S39] |
| Screensaver | Terminal text-effects screensaver via `omarchy-launch-screensaver` + `default/alacritty/screensaver.toml`; idle handled by shell (manual ch. 13) | [S4 tree][S5] |
| Bootloader | **Limine** + UKI (`limine`, `limine-mkinitcpio-hook`, `etc/limine-entry-tool.d/omarchy-uki.conf`); `omarchy-setup-direct-boot` adds an EFI entry (not GRUB) | [S36][S56] |
| Filesystem / snapshots | **btrfs** (`btrfs-progs`, `btrfs-overlayfs` initcpio hook) + **Snapper** (`root` config from `default/snapper/root`, `snapper-cleanup.timer`, timeline timer disabled) + `limine-snapper-sync.service`; installer takes a baseline snapshot used by factory reset | [S33][S34][S24] |
| Encryption | **LUKS mandatory** (`encrypt` initcpio hook; Plymouth unlock screen themed per theme "unlock" images) | [S24][S34][S37] |
| Login flow | **SDDM** is installed (`etc/sddm.conf.d/10-wayland.conf` runs `start-hyprland -- --config /usr/share/sddm/hyprland.lua`; themed SDDM at `/usr/share/sddm/themes/omarchy`). `install/login/sddm.sh`: "The ISO owns autologin/session state because it knows whether the target is encrypted." Users in #532 disable autologin by removing `/etc/sddm.conf.d/autologin.conf`. Earlier (v3) HN discussion described "no display manager, Hyprland autostarts, LUKS is the password." **Inference:** on encrypted installs the ISO configures SDDM autologin; LUKS passphrase is the effective login. | [S35][S23][S49][S26] |
| uwsm | Present (`uwsm` package; `default/uwsm/env.d/10-omarchy`, `/usr/share/uwsm/env.d/`) | [S36][S26] |
| Network | **NetworkManager** (`etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf`; "Use networkmanager for new network panel") — iwd not in package lists | [S6][S36] |
| DNS | **systemd-resolved** (`etc/systemd/resolved.conf.d/{10-disable-multicast,20-docker-dns}.conf`); `omarchy dns` / Setup > Network > DNS: Cloudflare, Google, DHCP, custom; privileged helper via `etc/sudoers.d/omarchy-dns` (PATH pinned in 4.0.1) | [S36][S48][S7] |
| Firewall | **ufw**: `default deny incoming`, `allow outgoing`, 53317 open for LocalSend, ufw-docker rules, `systemctl enable ufw` | [S31][S24] |
| AppArmor / MAC | **Not present** in base/other package lists (grep for apparmor: none) | [S36] |
| ISO / installer | `omacom/omarchy-iso`: Omarchy Configurator front-end to archinstall; supports `--dev`/`--quattro` builds; **unattended installs** via a `cidata`-labelled drive (cloud-init NoCloud style) with `user_configuration.json`, `user_credentials.json`, optional `authorized_keys`, `tailscale_authkey`, or an empty `defer-provisioning` file | [S54][S40] |
| Dictation / OCR | Voxtype (`Install > AI > Dictation`, 150 MB base English model, `~/.config/voxtype/config.toml`, hold `F9` or toggle `Super+Ctrl+X`); Tesseract OCR on `Super+Ctrl+PrtScr` | [S15][S16] |
| Other | Plymouth, `faillock.conf`, sudoers drop-ins (dns, passwd-tries, theme-browser, tzupdate), zram, oomd, `omarchy-sudo-passwordless` (15-min passwordless sudo toggle) | [S4 tree][S24] |

### 3. Config layout, CLI conventions, updates, per-user model

**Layout (from `docs/file-layout.md`).** Two Arch packages built from the repo: `omarchy` (bin, install, migrations, themes, shell → `/usr/share/omarchy/...`, bins → `/usr/bin/omarchy-*`) and `omarchy-settings` (everything needed before `useradd`: `/etc/skel/**`, `/etc/` drop-ins, fonts, plymouth/sddm themes, limine/snapper configs). Three layers populate `$HOME`: (1) **seed** from `/etc/skel` at user creation, (2) **finalize** via `omarchy-provision-user` once per user, (3) **resync** via `omarchy-reinstall-configs` (destructive). "Keep `~/.config/omarchy/` for files a user may intentionally version in a dotfile manager, such as user themes, hooks, shell layout, plugins, and themed template overrides." Generated theme state lives in `~/.local/state/omarchy/current/` (moved from `~/.config/omarchy/current`). `~/.local/share/omarchy` is no longer the install path — that was the v3 git-checkout era. [S26][S9]

**Key user-side files:** `~/.config/omarchy/shell.json` (plugin enable state, bar layout, `bar.id`, `disabledPlugins[]`), `~/.config/omarchy/shell.toml` (machine-level override merged over the theme: font, spacing, bar tweaks; live-watched), `~/.config/omarchy/plugins/<id>/`, `~/.config/omarchy/themes/<name>/`, `~/.config/omarchy/themed/*.tpl` (theme templates for any app), `~/.config/omarchy/hooks/<event>.d/`, `~/.config/omarchy/extensions/omarchy-menu.jsonc`, `~/.config/hypr/*.lua`. [S14][S6][S38][S29][S42]

**CLI.** 444 scripts in `bin/`, all `omarchy-<group>-<verb>` (largest groups: install 35, theme 32, remove 27, hw 27, hyprland 24, launch 23, update 21, restart 16, menu 14, toggle 13, refresh 12, system 11, plugin 9, pkg 9, webapp 5, provision 3, setup 5). A `bin/omarchy` router exposes them as `omarchy <group> <verb>` (e.g., `omarchy plugin add`, `omarchy theme install`, `omarchy dns`). Scripts carry metadata comments (`# omarchy:summary=`, `# omarchy:group=`, `# omarchy:requires-sudo=true`, `# omarchy:hidden=true`). [S4 tree][S55][S56]

**Updates & migrations.** `omarchy update` owns the pipeline: package transaction → per-user migrations (`migrations/<unix-timestamp>.sh`, markers in `~/.local/state/omarchy/migrations/`, must be idempotent, "every user gets a chance to run every migration") → `post-update.d` hooks → restart checks (shell restarted unconditionally). A pacman ALPM pre-transaction hook (`00-omarchy-update-guard.hook`) blocks raw `pacman -Syu` unless bypassed. Update channels: stable / RC / edge / dev (v3 manual; 4.0.2 pointed RC at a dedicated repo). [S27][S2][S8]

**Per-user / multi-user.** The packaging deliberately supports N users at the filesystem level (skel seed, per-user finalize, per-user migration markers, `useradd -m`) [S26], but **the product is single-user by design**: in discussion #532 (opened 2025-08-07 asking for family multi-user) a maintainer replied "This is not part of the design ... and uses LUKS to gate only you to use it"; workarounds (SDDM/ly) broke against "seamless login" on later updates; on 2026-08-18 a community member posted "Multi user support coming in 4.1!" citing a DHH tweet (not fetched). [S23][S52] The `agent-accounts` branch adds `omarchy-agent-account-{list,login,logout,switch}` and touches `omarchy-provision-user` — account-switching plumbing for coding-agent accounts, plausibly reusable for human users (inference). [S47] Also relevant: "Installing for another owner" (Ctrl+C on the installer's first screen defers keyboard/username/password to first boot; the new owner's password becomes the LUKS password) and `Setup > Reset Computer` (wipes `/home`, restores baseline snapshot) — a supported *hand-over* flow, not concurrent users. [S41][S24]

### 4. Theme system

**Anatomy (verified from `themes/tokyo-night/`):** `colors.toml` (the master; 24-color semantic palette; `mode = "light"` for light themes), `backgrounds/*.webp|jpg`, `icons.theme` (Yaru variant name), `keyboard.rgb`, `neovim.lua`, `vscode.json`, `shell.lock.toml`, `preview.png`, `unlock.png` + `preview-unlock.png` (Plymouth LUKS unlock artwork). Optional per manual: `btop.theme`, `chromium.theme`, `helix.toml`, `shell.toml`, `hyprland.lua`, terminal configs (`alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`). From `colors.toml` Omarchy generates configs for Foot/Alacritty/Ghostty/Kitty, btop, Chromium, Hyprland, Neovim, Helix, VSCode, Obsidian and the entire shell (bar, menu, notifications, OSD, lock). 22 built-in themes. [S4 tree][S37][S38]

**Install & distribution.** User themes go in `~/.config/omarchy/themes/` (copy one from `/usr/share/omarchy/themes`). Third-party: put it in a public git repo, users install via _Install > Style > Theme_ or `omarchy theme install <url>`; remove via _Remove > Theme_. **Security rule (4.0.1+):** a git-installed theme keeps everything that is colour and **loses any `.lua`, terminal config, and `vscode.json`**; Omarchy tells the two apart by the presence of a `.git` dir. Naming: `omarchy-[themename]-theme` (slug rules: starts with letter/digit/underscore; letters, digits, `. _ + -` only; lowercased). Aether (GUI theme builder) is bundled. Catalog: omarchy.org/themes (~300+ themes), added by PR to the omarchy-site repo. `bin/omarchy-theme-*` has 32 commands incl. `omarchy-theme-install`, `-set`, `-set-browser-policy`, `-set-templates`, `-extras`, `-update`. [S38][S43][S4 tree][S7]

### 5. Plugin system (official)

**Exists, first-party, documented** in `manual/32-shell-plugins.md` (v4 manual ch. 32 "Shell Plugins"), `docs/omarchy-shell.md`, `shell/README.md`, `shell/plugins/README.md`, and `default/agents/skills/omarchy/plugins.md`. The blueprint's cited path is real, but under `omacom/omarchy`, not `omarchy/omarchy`. [S14][S18][S4 tree]

- **Model:** the desktop is one long-lived Quickshell process `omarchy-shell`; "almost everything you see on screen is a plugin inside it" — bar, panels, overlays (emoji picker, clipboard), the Omarchy menu, lock screen, polkit dialog, headless services (battery, night light). First-party plugins live in `$OMARCHY_PATH/shell/plugins/` (`agents, background, bar, clipboard, dev-gallery, emojis, image-picker, lock, menu, notifications, osd, panels, polkit, reminders, services`); user plugins in `~/.config/omarchy/plugins/<id>/`; both discovered identically. [S14][S4 tree]
- **Manifest:** `manifest.json` with `schemaVersion: 1`, `id` (namespaced; **`omarchy.*` reserved**; marketplace guide recommends reverse-domain like `io.github.<you>.<plugin>`), `name`, `version`, `author`, `license`, `description`, `kinds[]`, `entryPoints{}` (QML file per kind). Bar widgets add a `barWidget` block (display name, category, `defaultSection`, `allowMultiple`). [S14][S21]
- **Kinds:** `bar-widget` (component in a bar section), `panel` (floating persistent/summoned window), `overlay` (fullscreen), `menu` (summoned menu surface), `service` (headless singleton), `bar` (full replacement bar; "there's always exactly one bar"). A plugin may declare several kinds. [S14]
- **Runtime contract:** panel/overlay/menu entry points expose `open(payloadJson)`/`close()`; the host injects `omarchyPath`, `shell`, `manifest`, `pluginRegistry`, `barWidgetRegistry`; theming via `root.barForeground`, `root.bar.fontFamily`, `Style` imports; IPC: `omarchy-shell shell summon <id> '{}'`, `omarchy-shell shell hide <id>`, `omarchy-shell shell rescanPlugins`. Saving a file under `~/.config/omarchy/plugins/` hot-reloads. [S21][S14]
- **Commands:** `omarchy plugin list [--json] | enable | disable | add <git-url> [--enable] | update [id] | remove <id> | clone <builtin-id> [--edit] | validate <dir>`; menu: _Setup > Plugins_. `add` warns that "plugins run as arbitrary, unsandboxed code inside your long-lived shell process", never runs install hooks or sudo, refuses id collisions, rejects unsafe git transports (4.0.1). `clone` copies a built-in to `~/.config/omarchy/plugins/<username>.<name>` and routes calls from the original id to the clone. Enable state in `shell.json` (third-party enabled iff referenced; first-party non-widgets on by default unless in `disabledPlugins[]`). [S14][S7]
- **Ecosystem:** plugins.omarchy.org (MIT, maintained by HANCORE; sort by starred/copied/hearts; "verified" filter; submission by PR to `omacom/omarchy-plugin-marketplace`, whose `registry.json` lists 22 sources). Example community plugins found on GitHub: `omacom/omarchy-notification-center-plugin`, `huacnlee/omarchy-mihoro`, `brianblakely/omarchy-everything`, `jonashan/omarchy-workspace-mover`, `bruce-forte/omarchy-mcp-server`, `felixzsh/omarchy-key-visualizer`, `28allday/omarchy-plugin-manager`, `Qurupeco01/omarchy-plugin-bridge` (runs Omarchy plugins on plain Arch+Hyprland). [S20][S21][S22][S45]

**Adjacent extension mechanisms (also official):**
- **Menu extensions** — `~/.config/omarchy/extensions/omarchy-menu.jsonc` overlays `default/omarchy/omarchy-menu.jsonc`; dotted ids form the tree; reusing a shipped id replaces only declared fields (retitle/re-icon/hide via `when` guards); `action`, `target`, `provider`, `checked`, `disabled` fields; live-reloaded. [S42]
- **Hooks** — `~/.config/omarchy/hooks/{battery-low,font-set,post-boot,post-update,pre-refresh-pacman,theme-set}.d/`; `omarchy hook install <name> <script>`. [S29]
- **Hyprland Lua** — user-editable `~/.config/hypr/bindings.lua` etc.; Hyprland's native `hyprpm` plugins were not mentioned anywhere in the manual (unverified whether supported/encouraged).
- **Theme templates** — `~/.config/omarchy/themed/<file>.tpl` regenerated on every theme switch. [S38]
- **Web apps** — `omarchy-webapp-install` creates themed Chromium app windows (URL validation added 4.0.2). [S4 tree][S8]
- **Browser policy** — root-owned managed policy dirs for Chromium/Chrome/Edge/Brave and Firefox/Zen distribution policies, with `browser_policy_*` helper functions. [S32]

### 6. "omarchy-clarity", content filtering, Voxtype

- **omarchy-clarity: no evidence anywhere.** Not in the 2,015-path repo tree (grep `clarity|parental|kiosk`: zero hits), not in the manual, not in web search. Treat as fabricated. [S4 tree][S48]
- **Built-in filtering: none.** DNS is switchable (Cloudflare/Google/DHCP/custom) via `omarchy dns` on systemd-resolved; no blocklists, no dnscrypt-proxy, no DoH pinning. Firewall is ufw deny-in/allow-out (no egress control). [S48][S31]
- **Voxtype: confirmed** ("Omarchy offers AI dictation via Voxtype"), installed via _Install > AI > Dictation_ (also a first-run hook `install-voxtype.hook`), local 150 MB base English model, `voxtype setup model`, config `~/.config/voxtype/config.toml`, **hold `F9` or toggle `Super + Ctrl + X`**. The blueprint's `Super + V` is the paste key. The blueprint's URL `.../58/dictation` is wrong (page 58 is "Shell Functions"; the v3 page is `/116/text-extraction-dictation`; v4 chapter is `manual/11-text-extraction-dictation.md`). [S15][S16][S17][S4 tree]

### 7. Contribution policy & naming

- **Routing (from `default/agents/skills/omarchy/contributing.md` and `.github/ISSUE_TEMPLATE/config.yml`):** verified bugs → GitHub issues ("Issues are for validated bugs only, not support requests"); feature ideas → `github.com/basecamp/omarchy/discussions/categories/suggestions`; support/"is this a bug?" → Discord (`omarchy.org/discord`). Blank issues disabled. Bug template requires system details + `omarchy debug` log (uploadable to logs.omarchy.org, 24 h expiry) + captures. [S28][S30]
- **PRs:** fork, never develop against `/usr/share/omarchy`; "Follow the repository's own `AGENTS.md` for style, testing, and commit conventions — it is the authority on contributions"; atomic commits; `./test/all` before pushing; before/after captures for visual changes. `CODEOWNERS` and `SECURITY.md` exist. Contributor task guides live in `agents/skills/` (`install-scripts.md`, `migrations.md`, `shell-dev.md`, `acceptance-tests.md`, `command-metadata.md`). [S28][S4 tree]
- **How community work is referenced:** external repos, discovered through two curated catalogs — omarchy.org/themes (PR to omarchy-site) and plugins.omarchy.org (PR to omarchy-plugin-marketplace). No "awesome list" is official; `deepakness/omarchy-hub` is an unofficial resource library. [S43][S20][S60]
- **Naming conventions (observed):** themes `omarchy-<name>-theme` (manual-recommended; e.g., `omacom/omarchy-synthwave84-theme`); plugins commonly `omarchy-<thing>` or `omarchy-plugin-<thing>` / `omarchy-<thing>-plugin` (e.g., `omacom/omarchy-notification-center-plugin`); tools `omarchy-<thing>` (`omarchy-zsh`, `omarchy-fish`, `omarchy-lazyvim`); plugin ids reverse-domain, never `omarchy.*`. [S38][S45][S46][S21]

### 8. Prior / parallel efforts

- **`jfuerwentsches/omarchy-kids`** (GitHub, created 2026-08-27, last push 2026-08-30, 4 stars, MIT). "A configuration layer on top of Omarchy that grows with a child — age-tiered desktop profiles plus tooling for parental controls and screen time. Not a fork." Architecture: child computer runs Omarchy + config layer + local Rust agent (`omarchy-kids-agent` CLI, `omarchy-kids-agentd` daemon with budget/prewarning/security/ticker modules, app wrapper, override-helper, repair-helper, pairing over mDNS/QR, PKGBUILD, polkit policy `net.omarchykids.agent.policy`, systemd unit); parent computer runs a C++/Qt control center (GUI + TUI) and a Quickshell headerbar plugin, talking to the agent over SSH; `tiers/` holds per-age Hyprland config, Quickshell modules, wallpaper/branding and `omarchy-kids-set-tier`; `setup-wizard/` for first boot; `website/` for omarchy-kids.com (EN+DE). Status: "early concept / development environment setup. Not usable yet." Has `CONTRIBUTING.md` and CI. [S44]
- GitHub searches for "omarchy parental / school / kiosk / child / education" returned nothing else. [S45]
- **Reddit "Installing Omarchy on school computers" (r/omarchy, id `1vnklrc`)**: could not be verified — reddit.com is unreachable from this tool and three web searches surfaced nothing. Treat as unverified until someone opens it in a browser. [S51]
- Relevant upstream threads: Discussion #532 "Support Multiple Users" (family shared PC — the exact kids use case; 11 participants; "coming in 4.1" claim) [S23]; Discussion #3540 "Auto-login potential security issue?" and Issue #2880 "Add a matching SDDM login screen theme" (both search-only) [S58][S59]; blog post "Omarchy: Any User Process Can Escalate to Root" (0xcc.io; 403 on fetch — title only) [S50].
- Cloudflare sponsorship blog: **confirmed**, see §1. [S13]

## Blueprint claims checked

| Blueprint claim | Verdict | Evidence |
|---|---|---|
| Omarchy = Arch + Hyprland + "Quickshell engine" | **Confirmed** (true since 4.0, 2026-08-14) | [S6][S9] |
| Official plugin doc at `github.com/omarchy/omarchy/blob/quattro/manual/32-shell-plugins.md` and `shell/plugins/bar/README.md` | **Partly** — files exist, but under `omacom/omarchy`; the `omarchy/omarchy` URLs 404 | [S14][S18][S19] |
| Plugin lives at `~/.config/omarchy/plugins/omarchy.kids.mode/` with `manifest.json` | **Partly** — directory and manifest right; **id `omarchy.*` is reserved** and will be refused by `omarchy plugin validate` | [S14][S21] |
| Plugin root is `shell.qml` that "locks standard Wayland compositor inputs" | **Wrong** — plugins declare kinds + `entryPoints` (e.g., `Bar.qml`, `Panel.qml`); `shell.qml` is the host's root; a plugin cannot lock compositor input (that is Hyprland config/`hyprctl`) | [S14][S21] |
| Replacement `components/Bar.qml` | **Partly** — a `bar`-kind plugin can replace the bar; entry point name is free (guide uses `Bar.qml`) | [S14][S21] |
| `omarchy-clarity` DNS filter with dnscrypt-proxy | **Wrong** — no such component; DNS is systemd-resolved + `omarchy dns` | [S4 tree][S48] |
| Voxtype is Omarchy's dictation engine | **Confirmed** | [S15][S16] |
| Voxtype push-to-talk on `Super + V`; config `~/.config/voxtype/config.toml` | **Partly** — config path right; hotkeys are hold `F9` / toggle `Super+Ctrl+X`; `Super+V` is paste | [S15] |
| Manual dictation page `learn.omacom.io/2/the-omarchy-manual/58/dictation` | **Wrong** — 58 is "Shell Functions"; dictation is /116 (v3) and manual ch. 11 (v4) | [S17][S16] |
| "The Omarchy 3 Manual" as the current manual | **Outdated** — v4 manual at omarchy.org/manual; learn.omacom.io v3 page labels itself legacy | [S2][S5] |
| GRUB bootloader; harden with `grub-mkpasswd-pbkdf2` | **Wrong** — Limine + UKI, `omarchy-setup-direct-boot` EFI entry | [S36][S56] |
| `/home` on ext4 with `noexec` in fstab | **Partly/unverified** — root is btrfs with Snapper; partition/subvolume layout not verified; ext4 assumption wrong | [S33][S34] |
| Wrap `gnome-control-center` behind pkexec | **Wrong** — no gnome-control-center; settings are the Quickshell Omarchy menu (`Setup > ...`) and `omarchy-*` commands | [S42][S4 tree] |
| Firewall via raw iptables/nftables rules | **Partly** — ufw is the managed layer (deny-in/allow-out); egress rules would need to be ufw-compatible | [S31] |
| Dedicated `omarchy-kid` Unix user with display-manager guest disabled | **Blocked/partly** — single-user by design today; SDDM present with ISO-managed autologin; multi-user "coming in 4.1" (second-hand) | [S23][S35][S52] |
| Cloudflare sponsorship blog post exists | **Confirmed** (2025-09-22, Sam Rhea) | [S13] |
| r/omarchy "Installing Omarchy on school computers" thread | **Unverifiable** (reddit blocked; not in search) | [S51] |
| `omarchy.org/guide/` "complete guide by Ulrich Rozier" | **Unverifiable** — not linked from omarchy.org; not fetched | [S1] |
| `github.com/omarchy/kids-mode/...` docs (bib #29-32, #113) | **Wrong** — `omarchy` org is an unrelated profile repo; no such repo | [S3] |
| Hyprland "socket API" usable for custom shell | **Confirmed** in principle; note Hyprland config is now Lua, target 0.56 | [S6] |

## Implications & recommendations for Omarchy Kids Mode

**1. Single-user vs multi-user decides the architecture. Plan two tracks.**
- **Track A — "The kid's own machine" (works on 4.0.2 today).** Omarchy explicitly supports preparing a machine for someone else (installer Ctrl+C → deferred provisioning; unattended `cidata` installs with `defer-provisioning`; factory reset) [S40][S41][S24]. Kids Mode v1 should be a *profile applied to a whole Omarchy install* whose sole user is the child, with parental enforcement living **outside the child's control** (root-owned files, system services, polkit rules) — the child's own `~/.config/omarchy/*` must be treated as editable by the child.
- **Track B — "Shared family machine" (after 4.1).** Do not build against SDDM/ly hacks now; #532 shows those break on updates [S23]. Track the 4.1 roadmap and the `agent-accounts` branch (`omarchy-agent-account-switch`, `omarchy-provision-user` changes) as the likely template for per-account provisioning [S47]. Design the kid profile so it can later be applied to a second Unix user via the seed/finalize layers (`/etc/skel`, `omarchy-provision-user`, per-user migrations) [S26].

**2. Which extension mechanisms to use (ranked).**
1. **Shell plugins** for anything visible: a `bar`-kind "Kids Bar" (big, high-contrast, few widgets), `bar-widget`s (screen-time countdown, "ask a parent" button), an `overlay`/`menu` kid launcher, and a `service` for timers. Id namespace e.g. `org.omarchykids.*` (never `omarchy.*`). Distribute as git repos; list on plugins.omarchy.org. [S14][S21]
2. **Menu extension JSONC** to hide/retitle `Setup`, `Update`, `Remove`, `Install` entries with `when` guards and add `Play / Learn / Create` submenus — zero code, live-reloaded. [S42]
3. **Hyprland Lua overlays** (`bindings.lua`, `looknfeel.lua`) for the blueprint's "Level 1 fullscreen / Level 2 split / Level 3 tiling" progression and for disabling dangerous binds. [S6]
4. **Hooks** (`post-update.d`, `post-boot.d`, `theme-set.d`) to re-assert kid policy after updates/theme changes — Omarchy restarts the shell after every update, so re-application must be idempotent. [S29][S27]
5. **Themes** for fun/branding only — they are colors-only when installed from git, which is exactly right for kids: safe to share, impossible to weaponize. Follow `omarchy-<name>-theme`, ship `unlock.png` for a kid-friendly LUKS screen. [S38]
6. **Chromium managed policies** (`/etc/chromium/policies/managed`, root-owned, already hardened) for URL allow/block lists, SafeSearch, YouTube restricted mode, extension allowlists, DoH control — the single highest-leverage safety control and it composes with Omarchy's existing `browser_policy_*` helpers and `omarchy-theme-set-browser-policy`. [S32][S39]
7. **System layer** (sudo-required installer, keep it small): `omarchy dns` custom family resolver, ufw egress rules (ufw-compatible), Snapper snapshot before enabling kid mode, polkit rules. Note Omarchy has no AppArmor and offers 15-minute passwordless sudo — the kid account must not be in `wheel`, and Kids Mode should disable `omarchy-sudo-passwordless` for that account. [S24][S36]

**3. Do not fork; do not upstream first.** Omarchy's posture ("an open source gift", suggestions via Discussions, AGENTS.md as authority) plus DHH's opinionated scope make an upstream "kids mode" unlikely as core. The realistic upstream asks are small: an `Install > Kids` menu entry, a manual chapter, and multi-user. Everything else ships as external repos in the two catalogs. [S28][S30]

**4. Coordinate with `jfuerwentsches/omarchy-kids` immediately.** It already owns the obvious name and domain, has the right split (unprivileged child config layer + privileged agent + parent-side control), and is four days old — the ideal moment to merge efforts or agree on boundaries (e.g., this community repo = research, themes, launcher/bar plugins, browser-policy packs; omarchy-kids = agent/control plane). [S44]

**5. Security realism.** Plugins are unsandboxed code in the child's session; anything a kid can edit, a kid can defeat. Enforcement = root-owned policy + system daemon (as omarchy-kids does). Also handle: TTY switching, SDDM autologin semantics, Snapper rollback (a kid restoring a pre-kids-mode snapshot from the Limine menu), factory reset, and the LUKS passphrase being the effective login. [S24][S33][S35]

## Candidate workstreams / backlog items

| ID | Workstream | Concrete first deliverable | Depends on |
|---|---|---|---|
| WS-01 | **Platform watch** | Weekly note on 4.1 roadmap, multi-user, `agent-accounts`; a 4.0.2 VM test image (unattended `cidata` build) for contributors | — |
| WS-02 | **Kid theme pack** | 3 themes (`omarchy-<name>-theme`): `colors.toml`, 5 backgrounds, `icons.theme`, `unlock.png`; PR to omarchy-site catalog | — |
| WS-03 | **Kids Bar plugin** (`bar` kind) | Replacement bar: workspaces as big colored dots, clock, battery, "Parent" button; manifest id `org.omarchykids.bar` | WS-01 |
| WS-04 | **Kid launcher** (`overlay`/`menu` kind) | Fullscreen icon grid reading a curated app list; summoned on `Super+Space` via Hyprland Lua override | WS-03 |
| WS-05 | **Menu extension pack** | `omarchy-menu.jsonc` overlay hiding Setup/Update/Remove/Install; adds Play/Learn/Create submenus | — |
| WS-06 | **Tiered Hyprland Lua profiles** | `tier-1.lua` (fullscreen only, minimal binds), `tier-2.lua` (50/50 splits), `tier-3.lua` (full tiling); `omarchy-kids-set-tier` (align with omarchy-kids `tiers/`) | WS-01 |
| WS-07 | **Browser policy pack** | Root-owned Chromium managed-policy JSON: URLAllowlist/Blocklist, SafeSearch, YouTube restricted, extension allowlist, DoH mode; installer script using Omarchy's `browser_policy_*` helpers | — |
| WS-08 | **Network safety** | `omarchy dns` family-resolver preset; ufw egress rules blocking third-party DNS/DoH; doc on systemd-resolved DoT | WS-07 |
| WS-09 | **Parental agent / control plane** | ADR: adopt or contribute to `omarchy-kids` agentd (Rust, polkit, SSH); define the JSON protocol boundary with plugins | WS-01 |
| WS-10 | **Screen-time service** (`service` + `bar-widget`) | Countdown widget + soft-lock overlay driven by the agent's budget | WS-03, WS-09 |
| WS-11 | **Provisioning & school imaging** | "Gift a kid computer" guide using deferred provisioning; `cidata` unattended profile with `defer-provisioning`; `post-boot.d` hook that applies Kids Mode on first boot | WS-05..08 |
| WS-12 | **Education app catalog** | `Install > Kids` entries (GCompris, Tux Paint, Scratch, KDE Edu, Minetest, Kiwix) via `omarchy-pkg`/`omarchy-webapp-install`; a curated web-app list | WS-05 |
| WS-13 | **Security threat model & test plan** | Bypass matrix (sudo, passwordless sudo, plugin dir edits, snapshot rollback, TTY, SDDM, LUKS); acceptance tests in Omarchy's `test/` style | WS-06..09 |
| WS-14 | **Docs & catalog presence** | Manual-style chapter; marketplace listings; naming/security guidelines; Discussions > Suggestions post for `Install > Kids` | all |

## Open questions for the community

1. What exactly will 4.1 "multi-user" be — separate Unix users with SDDM login, fast user switching, or agent-style account switching? Can we get DHH/Ryan's design intent early (Discussion #532)? [S23][S52]
2. Will Omarchy accept an `Install > Kids` (or `Setup > Kids Mode`) menu entry upstream, or should it live entirely in a menu extension? [S42][S28]
3. Is the `omarchy.` id namespace ever opened to blessed community plugins, and what does "verified" mean on plugins.omarchy.org? [S14][S20]
4. Can `~/.config/omarchy/shell.json` / `plugins/` be made root-owned or overlaid from `/etc` so a child cannot disable a kids plugin, or must enforcement always be an external daemon? [S14][S26]
5. Does the Security team have an opinion on a supported "restricted account" mode (no `wheel`, no passwordless sudo, no snapshot restore from the boot menu)? [S7][S24]
6. Should this effort merge into `jfuerwentsches/omarchy-kids`, or split by layer (agent vs. UI/themes)? Who owns the `omarchy-kids` name and domain going forward? [S44]
7. Is the r/omarchy "school computers" thread real, and what did schools ask for (fleet imaging via `cidata`? shared logins?) — someone with a browser should verify. [S51]
8. Any interest from Omarchy in a built-in DNS/content-filter preset (e.g., Cloudflare 1.1.1.3 family) in `omarchy dns`? [S48]

## Sources

Status key: VERIFIED = fetched and content matches; SEARCH-ONLY = seen in results, not fetched; DEAD/UNVERIFIABLE = 404/blocked/not found. All accessed 2026-09-01.

| # | Title | URL | Status | Note |
|---|---|---|---|---|
| S1 | Omarchy homepage | https://omarchy.org/ | VERIFIED | Version 4.0.2, links to omacom repo, Discord, manual, plugins site, foundation news |
| S2 | The Omarchy 3 Manual (legacy index) | https://learn.omacom.io/2/the-omarchy-manual/ | VERIFIED | Labels itself legacy v3; v4 has separate manual; Waybar-era content |
| S3 | github.com/omarchy/omarchy | https://github.com/omarchy/omarchy | VERIFIED | Unrelated 3-star personal profile repo — not Omarchy |
| S4 | omacom/omarchy repo (gh API: metadata, branches, tree, releases) | https://github.com/omacom/omarchy | VERIFIED | Default branch `quattro`; 36,693 stars; MIT; 2,015 paths; 444 bin scripts |
| S5 | The Omarchy 4 Manual index | https://omarchy.org/manual/ | VERIFIED | 51 chapters incl. Shell Plugins, Security, Unattended Installs |
| S6 | Release v4.0.0 "The Quattro Release" | https://github.com/omacom/omarchy/releases/tag/v4.0.0 | VERIFIED | 2026-08-14; full feature list; Quickshell; Foot; Lua; plugin system |
| S7 | Release v4.0.1 "Fast-Follow Fixes" | https://github.com/omacom/omarchy/releases/tag/v4.0.1 | VERIFIED | 2026-08-25; security fixes incl. theme code stripping, plugin-add guards |
| S8 | Release v4.0.2 | https://github.com/omacom/omarchy/releases/tag/v4.0.2 | VERIFIED | 2026-08-31; signed packages required; browser policy dir hardening |
| S9 | PR #6231 "Omarchy Quattro" | https://github.com/omacom/omarchy/pull/6231 | VERIFIED | Opened 2026-07-17; 1,998 commits; layout migration notes |
| S10 | Phoronix: Omarchy 4.0 Released | https://www.phoronix.com/news/Omarchy-4.0-Released | VERIFIED | Confirms date and Quickshell consolidation |
| S11 | Omacom Foundation launches | https://omarchy.org/news/2026/08/omacom-foundation-launches-with-8-million | VERIFIED | $12.6M pledged; trademarks/infrastructure; no grant program described |
| S12 | omarchy.org/security | https://omarchy.org/security/ | VERIFIED | Vulnerability reporting only (security@omarchy.org) |
| S13 | Cloudflare: Supporting the future of the open web | https://blog.cloudflare.com/supporting-the-future-of-the-open-web/ | VERIFIED | 2025-09-22, Sam Rhea; CDN/R2/DDoS for Omarchy |
| S14 | manual/32-shell-plugins.md (quattro, raw) | https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md | VERIFIED | Plugin model, kinds, commands, reserved namespace, security warning |
| S15 | manual/11-text-extraction-dictation.md (quattro, raw) | https://github.com/omacom/omarchy/blob/quattro/manual/11-text-extraction-dictation.md | VERIFIED | Voxtype; F9 / Super+Ctrl+X; Tesseract |
| S16 | v3 manual: Text Extraction & Dictation | https://learn.omacom.io/2/the-omarchy-manual/116/text-extraction-dictation | VERIFIED | Same content as S15 |
| S17 | Blueprint URL ".../58/dictation" | https://learn.omacom.io/2/the-omarchy-manual/58/dictation | DEAD/WRONG | Page 58 is "Shell Functions" |
| S18 | Blueprint URL omarchy/omarchy .../32-shell-plugins.md | https://github.com/omarchy/omarchy/blob/quattro/manual/32-shell-plugins.md | DEAD | 404 — wrong org |
| S19 | shell/plugins/bar/README.md (omacom) | https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md | SEARCH-ONLY | Appeared in search; blueprint's omarchy/omarchy variant 404s |
| S20 | Omarchy Plugin Marketplace | https://plugins.omarchy.org/ | VERIFIED | omarchyplugins.com 301s here; MIT; HANCORE; submit via GitHub |
| S21 | Develop a Plugin guide | https://plugins.omarchy.org/develop.html | VERIFIED | Manifest fields, kinds table, IPC commands, theming access |
| S22 | omacom/omarchy-plugin-marketplace registry.json | https://github.com/omacom/omarchy-plugin-marketplace | VERIFIED | 22 `sources`; keys retiredPluginIds/repositoryMigrations/sources |
| S23 | Discussion #532 "Support Multiple Users" | https://github.com/omacom/omarchy/discussions/532 | VERIFIED | Single-user by design; LUKS gate; "coming in 4.1" comment 2026-08-18 |
| S24 | Omarchy 4 manual: Security | https://omarchy.org/manual/security/ | VERIFIED | LUKS mandatory; ufw; reset computer; passwordless sudo; signing key |
| S25 | manual/48-security.md (raw) | https://github.com/omacom/omarchy/blob/quattro/manual/48-security.md | VERIFIED | Source of S24 |
| S26 | docs/file-layout.md (raw) | https://github.com/omacom/omarchy/blob/quattro/docs/file-layout.md | VERIFIED | Package split; seed/finalize/resync; installed paths; deferred provisioning |
| S27 | docs/update-process.md (raw) | https://github.com/omacom/omarchy/blob/quattro/docs/update-process.md | VERIFIED | Update pipeline; per-user migrations; pacman guard |
| S28 | default/agents/skills/omarchy/contributing.md (raw) | https://github.com/omacom/omarchy/blob/quattro/default/agents/skills/omarchy/contributing.md | VERIFIED | Issue/suggestion/support routing; AGENTS.md authority; ./test/all |
| S29 | default/agents/skills/omarchy/hooks.md (raw) | https://github.com/omacom/omarchy/blob/quattro/default/agents/skills/omarchy/hooks.md | VERIFIED | Six hook events; `omarchy hook install` |
| S30 | .github/ISSUE_TEMPLATE/{bug.yml,config.yml} (raw) | https://github.com/omacom/omarchy/tree/quattro/.github/ISSUE_TEMPLATE | VERIFIED | "open source gift"; blank issues disabled; support → Discord |
| S31 | install/config/firewall.sh (raw) | https://github.com/omacom/omarchy/blob/quattro/install/config/firewall.sh | VERIFIED | ufw deny-in/allow-out; 53317; ufw-docker |
| S32 | install/helpers/browser-policy.sh (raw) | https://github.com/omacom/omarchy/blob/quattro/install/helpers/browser-policy.sh | VERIFIED | Managed policy dirs for Chromium/Chrome/Edge/Brave; Firefox/Zen distribution dirs |
| S33 | install/config/snapper.sh (raw) | https://github.com/omacom/omarchy/blob/quattro/install/config/snapper.sh | VERIFIED | Snapper root config; limine-snapper-sync |
| S34 | etc/mkinitcpio.conf.d/omarchy_hooks.conf (raw) | https://github.com/omacom/omarchy/blob/quattro/etc/mkinitcpio.conf.d/omarchy_hooks.conf | VERIFIED | plymouth, encrypt, btrfs-overlayfs hooks |
| S35 | install/login/sddm.sh + etc/sddm.conf.d/10-wayland.conf (raw) | https://github.com/omacom/omarchy/tree/quattro/install/login | VERIFIED | SDDM present; ISO owns autologin state |
| S36 | install/omarchy-base.packages + omarchy-other.packages (raw) | https://github.com/omacom/omarchy/tree/quattro/install | VERIFIED | hyprland, quickshell, foot, chromium, limine, btrfs-progs, snapper, networkmanager, ufw, uwsm, sddm, plymouth; no apparmor/iwd/grub |
| S37 | manual/06-themes.md (raw) | https://github.com/omacom/omarchy/blob/quattro/manual/06-themes.md | VERIFIED | 22 themes; what a theme styles; unlock images |
| S38 | manual/43-making-your-own-theme.md (raw) | https://github.com/omacom/omarchy/blob/quattro/manual/43-making-your-own-theme.md | VERIFIED | colors.toml; code-stripping rule; naming; templates; catalog PR |
| S39 | manual/23-browsers.md (raw) | https://github.com/omacom/omarchy/blob/quattro/manual/23-browsers.md | VERIFIED | Chromium default; policy dirs; extensions; alternatives |
| S40 | manual/51-unattended-installs.md (raw) | https://github.com/omacom/omarchy/blob/quattro/manual/51-unattended-installs.md | VERIFIED | cidata NoCloud; defer-provisioning; SSH/Tailscale keys |
| S41 | manual/02-getting-started.md (raw, grep) | https://github.com/omacom/omarchy/blob/quattro/manual/02-getting-started.md | VERIFIED | "Installing for another owner" |
| S42 | docs/menu.md (raw) | https://github.com/omacom/omarchy/blob/quattro/docs/menu.md | VERIFIED | Menu JSONC schema; user extension overlay; guards |
| S43 | Omarchy extra themes catalog | https://omarchy.org/themes/ | VERIFIED | ~300+ themes; Install > Style > Theme; PR to omarchy-site |
| S44 | jfuerwentsches/omarchy-kids (README + tree via gh API) | https://github.com/jfuerwentsches/omarchy-kids | VERIFIED | Created 2026-08-27; Rust agent + Qt control + tiers; "not usable yet" |
| S45 | GitHub repo search results (omarchy kids/parental/school/kiosk; omarchy-theme; omarchy plugin) | https://github.com/search?q=omarchy+kids&type=repositories | VERIFIED (API) | Only omarchy-kids matched; 50+ theme repos; ~15 plugin repos sampled |
| S46 | omacom org repository list (gh API) | https://github.com/omacom | VERIFIED | omarchy-iso, omarchy-pkgs, aether, marketplace, registry, retired omakub/omamac |
| S47 | Branch compare quattro...agent-accounts (gh API) | https://github.com/omacom/omarchy/compare/quattro...agent-accounts | VERIFIED | Adds omarchy-agent-account-{list,login,logout,switch}; touches provision-user |
| S48 | Omarchy 4 manual: Networking | https://omarchy.org/manual/networking/ | SEARCH-ONLY | `omarchy dns`; Setup > Network > DNS; Cloudflare/Google/custom |
| S49 | HN comment on Omarchy login (no display manager, LUKS as password) | https://news.ycombinator.com/item?id=45247299 | SEARCH-ONLY | v3-era description of "seamless login" |
| S50 | "Omarchy: Any User Process Can Escalate to Root" | https://0xcc.io/posts/omarchy-root-creds/ | DEAD/UNVERIFIABLE | HTTP 403; title only |
| S51 | r/omarchy "Installing Omarchy on school computers" (blueprint URL) | https://www.reddit.com/r/omarchy/comments/1vnklrc/installing_omarchy_on_school_computers/ | UNVERIFIABLE | reddit blocked from tool; not surfaced by 3 searches |
| S52 | DHH on X: "The road map for Omarchy 4.1 is already several man years..." | https://x.com/dhh/status/2089630095010889953 | SEARCH-ONLY | 4.1 roadmap; multi-user claim relies on #532 comment |
| S53 | DHH on X: "Omarchy Quattro is out!!" | https://x.com/dhh/status/2088304854603047019 | SEARCH-ONLY | Launch announcement |
| S54 | omacom/omarchy-iso README (raw) | https://github.com/omacom/omarchy-iso | VERIFIED | Configurator → archinstall; `--quattro` builds; edge mirror |
| S55 | bin/omarchy-plugin-catalog (raw) | https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-plugin-catalog | VERIFIED | Manifest discovery in $OMARCHY_PATH/shell/plugins and ~/.config/omarchy/plugins |
| S56 | bin/omarchy-setup-direct-boot (raw) | https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-setup-direct-boot | VERIFIED | EFI boot entry for the UKI (efibootmgr) |
| S57 | codetocloud.io: Omarchy 4 Quattro what's new | https://codetocloud.io/blog/omarchy-4-quattro-whats-new/ | SEARCH-ONLY | Secondary coverage |
| S58 | Discussion #3540 "Auto-login potential security issue?" | https://github.com/basecamp/omarchy/discussions/3540 | SEARCH-ONLY | Autologin threat discussion |
| S59 | Issue #2880 "Add a matching SDDM login screen theme" | https://github.com/basecamp/omarchy/issues/2880 | SEARCH-ONLY | SDDM theme (now shipped) |
| S60 | deepakness/omarchy-hub | https://github.com/deepakness/omarchy-hub | SEARCH-ONLY | Unofficial resource library |
| S61 | omarchy-site repo (theme catalog PR target) | https://github.com/omacom-io/omarchy-site | SEARCH-ONLY | Linked from manual; omacom org also lists `omarchy-site` |
| S62 | Voxtype | https://voxtype.io/ | SEARCH-ONLY | Linked from manual |
| S63 | Lunduke: Omarchy 2.0 | https://lunduke.substack.com/p/omarchy-20-the-arch-based-hyprland | SEARCH-ONLY | Old (Discord >6,000 members at 2 months) |

**Source counts:** VERIFIED 47 · SEARCH-ONLY 12 · DEAD/UNVERIFIABLE 4 (S17, S18, S50, S51; the blueprint's omarchy/omarchy variant of S19 also 404s) · total 63.
