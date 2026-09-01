# Prior Art: Kids/Educational Linux & Parental Control Tooling

_Research report · Omarchy Kids Mode · 2026-09-01 · status: draft_

Scope: kids/educational Linux distributions, mainstream parental-control benchmarks, Linux parental-control tooling (with Arch + Hyprland/Wayland applicability), and reusable design patterns. Every claim is tagged with a source `[S#]`; sources are graded VERIFIED / SEARCH-ONLY / DEAD-UNVERIFIABLE in the final section. Statements marked **(inference)** are the author's reasoning, not sourced facts.

## TL;DR

- **No Linux desktop ships end-to-end parental controls that work on Hyprland.** The only upstream framework, GNOME's `malcontent`, stores policy in accounts-service but enforces it inside gnome-shell / flatpak / gnome-software; on Hyprland nothing enforces it. Its author calls it "not real security" [S6][S8].
- **malcontent is packaged in Arch `extra` (0.14.0-4, 2026-04-11)** [S1], and **CVE-2026-44931 is real**: any local user can fill `/var` via the `malcontent-timerd` `RecordUsage` D-Bus method; upstream told SUSE it lacks developer capacity to fix it [S7]. Session/screen-time in malcontent is young and thinly maintained.
- **timekpr-next is the most Arch/Hyprland-ready screen-time tool**: AUR 0.5.10 (upstream release 2026-08-03; the upstream author co-maintains the AUR package), enforces via systemd-logind and tracks Wayland sessions, and has a process-based "PlayTime" limiter [S3][S4][S5]. Tray icon and screen-lock hooks are the open compatibility questions on Hyprland **(inference)**.
- **Kids distros mostly died of maintainer attrition, not bad ideas.** DoudouLinux: last release Dec 2013 [S21][S31]. ubermix: last public release 6.06, July 2022 [S15]. Sugar: 0.121 (Feb 2024), GTK3, GTK4 port only now planned via GSoC 2026 [S20][S34]. Edubuntu is the counter-example: revived 2023 and now on 26.04 LTS with age-group profiles [S11].
- **Parents' baseline expectation (from Family Link, Apple Screen Time, Microsoft Family Safety, Nintendo, Amazon Kids)** is: per-child profile, app allowlist, daily limit + bedtime window, content ratings, a remote "ask parent / approve" flow, and a weekly activity report [S45]–[S51]. No Linux tool delivers the "ask parent" flow.
- **Physical/boot-layer bypasses are documented and generic**: GRUB recovery → root shell → `adduser` on elementary OS [S30]; ArchWiki itself warns a child can boot any live USB [S2]; even GNOME's own screen-time can be bypassed via the user switcher [S9]. Design must assume the threat model is "deterrent for a curious child", and layer FDE/boot-password/firmware locks for anything stronger.
- **Best reusable patterns**: ubermix's "recover in seconds instead of lock down" [S14], Sugar's Journal (verbs, not files) and zoom views [S20], PrimTux/DoudouLinux/Edubuntu age-banded sessions [S18][S21][S11][S41], Endless's offline-first + OARS-rated app store [S8][S22], Amazon's "educational goal before entertainment" [S50], Family Link's remote approval [S51].
- **Blueprint corrections**: Zorin Education is GNOME-based (not Cinnamon/Xfce) and its page lists Veyon + Kolibri, not malcontent/timekpr [S12][S36]; Sugar's views are Home/Group/Neighborhood (not "Me/Friends/Classroom") [S20]; Edubuntu is not stagnant [S11]; several bibliography URLs are fabricated (`/12345`, `/123456`, `github.com/omarchy/kids-mode/...`).

## Findings

### 1. Kids / educational distributions and environments

#### Comparison matrix

| Distro / env | Base | UI paradigm | Parental controls | Offline strategy | Pedagogy | Status (2026-09) | Failure mode / lesson |
|---|---|---|---|---|---|---|---|
| **Endless OS** | Debian 12 + OSTree immutable root; Flatpak apps [S22][S37] | Modified GNOME (phone-like app grid) [S22] | malcontent (app allowlist, OARS install filter, browser switch), created here and upstreamed to GNOME [S6][S8][S56] | Ships "packed with content" for zero-bandwidth use; creative + learning apps preinstalled [S22] | Digital-inclusion / first computer; learning games for logic, math, coding [S22] | 6.0.x series (6.0.0 May 2024; 6.0.7 by Nov 2025); org now Endless Global / Endless Access [S37][S38][S22] | Parental controls uptake ~2% of new installs [S8]; time limits were a community *idea* thread, not a feature [S39]. Lesson: controls nobody turns on at setup are dead weight; make them the default kid-profile path. |
| **Sugar / Sugar on a Stick** | Fedora spin (SoaS 43, Oct 2025) [S32]; Sugar 0.121 (Feb 2024), Python + GTK3 [S20][S33] | No files/folders/overlapping windows; **Journal** + zoom views **Home / Group / Neighborhood**; "activities" (.xo bundles) not apps [S20][S19] | None in the parental sense; activity model limits what a child can reach **(inference)** | Activities are local bundles; Sugarizer (HTML5) for other devices [S20] | Constructionist (OLPC lineage); collaboration built in [S20] | Alive but slow: wiki page stale (still says 0.118/F35, last edited 2022) [S19]; GTK4 port a GSoC 2026 project [S34] | Tied to OLPC hardware era; small volunteer base; toolkit churn (GTK2→3→4). Lesson: paradigm ideas outlive the codebase; steal the Journal, not the code. |
| **DoudouLinux** | Debian + heavily customised LXDE [S21] | Age-tiered activity menus, full-screen apps, single-click, terminal/filesystem hidden [S21] | DansGuardian web filter in Epiphany; usage monitoring (2.1) [S21] | Static live media, preloaded [S21] | Ages 2–12; GCompris, Childsplay [S21] | **Dead**: last release 2.1, Dec 2013; no site activity after 2015 [S21][S31] | One-person-scale project on a frozen Debian base; each Debian cycle meant a rebuild. Lesson: build on the host distro's package flow (Omarchy/Arch), never fork the base. |
| **PrimTux** (FR) | Debian-based family of releases; PrimTux 9 current [S18][S41] | Four sessions: **mini** (3–5), **super** (6–7), **maxi** (8–10), **prof** (teacher/parent) [S41] | CTparental (e2guardian + privoxy, transparent, per-user, HTTPS filtering, schedules); QwantJunior search; "protection against bad manipulations" [S42][S18] | Curriculum apps preinstalled; dynamic app catalogue filterable by age/subject [S18] | French primary curriculum; listed on France's SILL, Education Nationale partner [S18] | Active [S18] | Survives because of institutional anchoring (schools, ministry listing). Lesson: age bands as *sessions/users*, not just themes; a real institution as customer. |
| **Edubuntu** | Ubuntu 26.04 LTS flavour, GNOME 50 [S11] | Standard GNOME + Edubuntu Menu Administration [S11] | No malcontent mention; admin tool can disable terminal for non-admins; per-user menu customisation [S11] | Subject metapackages (`ubuntu-edu-preschool` … `-tertiary`) [S11] | Four age-group learning profiles: Preschool, Primary, Secondary, Tertiary [S11] | Active; revived 2023, 26.04 LTS supported to Apr 2029, lead Amy Eickmeyer [S11][S35] | Died once (post-14.04) from lack of maintainers, then revived by a single committed lead. Lesson: bus-factor is the real risk; document so anyone can pick it up. |
| **Zorin OS Education** | Ubuntu 24.04 LTS; Zorin 18.1 (Apr 2026); GNOME-based Zorin Desktop (Lite = Xfce) [S36][S12] | Windows/macOS-like layouts [S12] | None listed; Veyon classroom monitoring; Zorin Grid fleet tool "coming soon" [S12] | Kolibri offline learning library with LAN peer sharing [S12] | Broad subject bundle (GCompris, Stellarium, Minetest, TurboWarp, GDevelop…) [S12] | Active, commercial company [S12][S36] | Classroom-first, not home-first: monitoring (Veyon) rather than parental limits. Lesson: don't confuse teacher surveillance with parent controls. |
| **ubermix** | Ubuntu 22.04 (6.06) [S15] | Standard desktop; philosophy: give students full access, recover fast [S14] | None (deliberately) [S14] | 60+ apps preinstalled [S13] | K-12 device program [S13] | Last public release 6.06, July 2022; a district-specific 7.0lv3 exists [S15][S40] | Single-author, district-funded. Lesson: **the recovery pattern is gold** — UnionFS of read-only "Default System" + rw "User Changes" + separate "User Home"; "Restore Factory Settings" from a boot key, seconds long [S14]. |
| **Debian Junior** | Debian Pure Blend (metapackages) [S17] | None (package lists only) | None | n/a | Ages up to 8, then 7–12, graduate to plain Debian [S17] | Exists as a blend page; no dated activity visible [S17] | A "blend" without a UI never became a product. Lesson: curation lists are necessary, not sufficient. |
| **Debian Edu / Skolelinux** | Debian; wiki says Bullseye current, Bookworm skipped, Trixie upcoming [S16] | Standard desktops + LTSP server/thin-client profiles [S16] | Network-level (school) rather than per-child **(inference)** | Central server model [S16] | School IT infrastructure, not pedagogy per se [S16] | Active but skipped a whole Debian release [S16] | Heavy infra; skipping Bookworm signals thin maintainer capacity. Lesson: the more infra, the fewer maintainers. |
| **Newer entrants 2024–26** | — | — | — | — | — | Searches surfaced no new kids-focused distro; lists still recycle Edubuntu, SoaS, DoudouLinux, Qimo, Endless [S60] | The field is empty. An Omarchy Kids Mode would be the first *tiling/Wayland* kids environment and the first new entrant in years **(inference)**. |

#### Notes on the individual environments

**Endless OS / malcontent origin.** Withnall's GUADEC 2020 notes are the clearest primary source on why malcontent exists and how it works [S8]: Endless users and integrators asked to limit what non-admin users could do "particularly relating to access to and installation of content"; the first version shipped in Endless, then was upstreamed after a March 2019 hackfest. Integration points: gnome-shell (hide/prevent launch), flatpak (refuse install/launch of disallowed or over-rated apps), gnome-software, gnome-control-center, gnome-initial-setup (parent + child account creation at first boot). Install-time filtering uses **OARS** metadata compared against per-user limits in accounts-service; missing OARS = assumed `intense`. Already-installed apps are governed by a **blocklist** also stored in accounts-service. Withnall explicitly: "It's not real security: a determined user will always be able to find a way around it… It should prevent the average child from doing things they're not supposed to do, though." Uptake was ~2% of new Endless installs. "Screen time" was listed as future work in 2020 — that became `malcontent-timerd` (now CVE-affected) [S7].

**Sugar.** The Journal replaces the file system: everything a child does is recorded as an entry with metadata, resumed rather than "opened"; the zoom views (Home / Group / Neighborhood, plus the Activity view) replace desktops and windows; activities are collaborative by default [S20]. Still maintained by Sugar Labs (a Software Freedom Conservancy project) [S20]; Arch packages `sugar-toolkit-gtk3` 0.121 [S33]; Fedora still ships a SoaS spin (43, Oct 2025) [S32]. The Sugar Labs homepage fetch returned empty [S63]; the SoaS wiki page has not been edited since Feb 2022 [S19].

**DoudouLinux.** Beyond the matrix: 44 languages, DuckDuckGo default, KDE edu apps [S21]. The age-tiered "activity" menus and single-click, full-screen behaviour are the durable idea [S21].

**ubermix recovery design (verified detail).** "UnionFS technology with three physical storage slices": a read-only *Default System* partition and a read/write *User Changes* partition logically combined, with user documents in a separate *User Home* area; restore by "pressing a key at startup and selecting 'Restore Factory Settings'", which erases User Changes and preserves documents, "literally in seconds" [S14]. The stated philosophy: rather than locking devices down, "prioritize rapid recovery and give students full access to their computer for experimentation and discovery" [S14]. The blueprint's "~12 GB" and "20-second" figures: the 20-second claim is on the ubermix homepage [S13]; the 12 GB figure was not found.

### 2. Mainstream benchmarks parents compare against

| Platform | Per-child profile | App allow/approve | Daily limit | Bedtime / downtime | Content ratings | Remote approval ("ask parent") | Activity report | Other |
|---|---|---|---|---|---|---|---|---|
| **ChromeOS + Family Link** [S51] | Yes (Google child account) | Play Store installs need parent approval | Yes, per device (not pooled) | Yes; device locks | Chrome filter: block-list / auto-block explicit / allow-list only | Yes (push to parent phone) | Yes | Web filter "best effort"; school-managed devices answer to the school |
| **iPadOS Screen Time** [S45][S46] | Yes (Family Sharing) | Ask to Buy | App Limits (per app / category) | Downtime (only allowed apps + calls) | Content & privacy restrictions | Child sends exception request; parent approves on their own device or in place | Yes | Communication Limits; Guided Access = single-app kiosk with screen regions disabled |
| **Microsoft Family Safety** (Windows/Xbox) [S47][S48] | Yes | Purchase approvals; app/game blocking | Device and app caps across Windows, Xbox, Android | Yes | Age-appropriate web/app filtering (Edge) | Yes | Weekly summaries of device/app/web use | Spending limits |
| **Nintendo Switch** [S49] | Per console (PIN) | Age-based game restriction levels | Daily play-time limit; "Suspend Software" auto-stops game | Bedtime alarm | Age ratings; per-game communication/UGC restrictions | Parent adds time via PIN | What was played, for how long | eShop spending restrictions |
| **Amazon Kids / Fire** [S50] | Yes | Curated Kids+ catalogue | Limits by activity type (e.g. unlimited books, limited games) | "Turn off by" bedtime | Age filters | Web dashboard from any browser | Yes | **Educational goals gate entertainment** ("no games until 30 min reading") |

Common denominator = the minimum viable feature list parents will measure Omarchy Kids Mode against **(inference)**: (1) per-child profile with a parent PIN/password, (2) app allowlist, (3) daily time budget, (4) bedtime window, (5) age rating on apps/content, (6) an "ask parent" request that a parent can grant remotely (phone) or in place (password), (7) a readable weekly usage summary, (8) a kiosk/single-app mode for the youngest. Distinctive extras worth copying: Amazon's education-before-entertainment gate; Nintendo's "suspend software" hard stop with warning; Apple's Guided Access.

### 3. Linux parental-control tooling — Arch + Hyprland applicability

#### Tool matrix

| Tool | What it does | Enforcement mechanism | Dependencies | Arch packaging | Arch + Hyprland applicability | Sources |
|---|---|---|---|---|---|---|
| **malcontent** (libmalcontent, malcontent-control, malcontent-client, malcontent-timerd) | Per-user app allow/block list, OARS install ceiling, browser switch, session/screen-time limits | Policy in **accounts-service** via D-Bus, edited under polkit; enforcement lives in gnome-shell, flatpak, gnome-software, gnome-control-center, gnome-initial-setup | accounts-service, polkit, flatpak, GLib/GTK, dbus | `extra/malcontent` 0.14.0-4 (2026-04-11) [S1] | **Policy store: reusable. Enforcement: absent.** On Hyprland no launcher (walker/wofi/etc.) consults libmalcontent; screen-time limits are enforced by gnome-shell, so nothing enforces them. `flatpak run` filtering depends on the flatpak build linking libmalcontent — unverified for Arch **(open question)**. CVE-2026-44931 (disk DoS via `RecordUsage`) unfixed upstream as of May 2026 [S7]. ArchWiki's only usage example is `malcontent-client set-app-filter <user> x-scheme-handler/http` to block Flatpak browsers [S2]. | [S1][S2][S6][S7][S8] |
| **timekpr-next** | Daily/weekly/monthly limits, allowed hour intervals, "unaccounted" intervals, PlayTime per-process limits, per-user, admin GUI + client tray | Daemon polls **systemd-logind** every 3 s; tracks X11/Wayland/Mir sessions (not TTY); restriction types: terminate session (default), soft kill, shutdown, suspend (with wake), lock screen; warns via freedesktop notifications | python, GTK3, D-Bus, polkit + a polkit agent, libappindicator (tray), logind | **AUR `timekpr-next` 0.5.10-1**, maint SanskritFritz, co-maint Mjasnik (upstream), updated 2026-08-17, 9 votes [S3]; upstream 0.5.10 released 2026-08-03 [S4] | **Best fit today.** Session termination via logind works on any compositor. Caveats **(inference)**: the client tray icon needs an SNI host (waybar tray module); "lock screen" restriction relies on freedesktop screensaver/GNOME screensaver interfaces that Hyprland/hyprlock do not implement natively; a polkit agent must be running (Omarchy ships one — verify). Upstream states testing is now "mostly on demand". | [S2][S3][S4][S5] |
| **little_brother** | Process ("games") time limits, rules per user (windows, daily max, breaks), multi-host pooling via master/client, web UI, device ping detection | Monitors and **kills processes**; spoken warnings before logout | Python 3, SQLite/MariaDB, web frontend | Not in AUR per this research; upstream lists Arch among tested distros (Debian pkg, Snap, Docker) | Compositor-agnostic (process-level). Good model for "pooled time across kid's devices" and parent web dashboard. Last release 0.5.6, Dec 2024 — maintenance risk. | [S23] |
| **LiFE Parental Control** (valueerrorx, Austria) | Lockdown wizard (creates parent admin, de-privileges child, **optionally secures GRUB**), web filter via `/etc/hosts` + dnsmasq with HaGeZi lists and DoH hardening, screen time with allowed hours, school-time schedules, app blocking (process kill) + per-app quotas, KDE Kiosk restrictions, activity dashboard | **Root systemd daemon** enforces; Electron/Vue frontend as user; pre-seedable JSON config for fleet rollout | Electron, systemd, dnsmasq | .deb only; beta, tested by Austrian school IT | Architecture (root daemon + unprivileged UI + JSON policy) is exactly the shape a Hyprland-native tool needs; Electron UI and KDE kiosk bits are not. Its GRUB-hardening step is the only tool that addresses the boot bypass. | [S24] |
| **Veyon** | Classroom monitoring: screen view, remote control, demo, lock, file transfer, LDAP | VNC-style screen capture and input injection | Qt | Available (extra/AUR — not checked) | **Poor fit**: GitHub issue reports no image under Wayland; docs have no Wayland section [S28][S29]. Also it's teacher surveillance, not parental control. | [S27][S28][S29] |
| **ActivityWatch** | Local, private usage tracking (window titles, AFK) | Watchers push events to local server; dashboard | Rust/Python | AUR (`aw-watcher-window-wayland-git` etc.) | `aw-watcher-window-wayland` needs `wlr-foreign-toplevel-management` + `ext-idle-notify` (works on sway/niri/phosh; not GNOME/KWin) [S43]; a **Hyprland-specific watcher exists** (`aw-watcher-window-hyprland`, IPC-based, also tracks workspace) [S44]. Strong candidate for the "activity report" feature without cloud. | [S43][S44] |
| **cage** | Single-app Wayland kiosk compositor (wlroots 0.20), runs at TTY or nested | The compositor *is* the sandbox: one maximized app | wlroots, xkbcommon | Available | Not Hyprland — but a perfect "toddler mode": a dedicated session that launches `cage -- gcompris`. Active, MIT [S26]. | [S26] |
| **Hyprland-native kiosk** | No built-in kiosk; achievable with autologin + `exec-once`, unbinding keys, window rules, hyprlock/hypridle | Config-level | — | — | HyprTile v0.16 (2026-07-29, GPL-3) ships a password "Child Lock / Kiosk Mode" for its launcher [S25] — a UX precedent, not a security boundary **(inference)**. | [S25][S58][S59] |
| **DNS / proxy filtering** (ArchWiki) | tinyproxy + firehol transparent per-user allowlist; OpenDNS + ddclient; `/etc/hosts` block or allow-only; BIND `denied.zone` (with DoT/DoH); Squid + nftables | Network layer, per-uid via firewall marks | — | `tinyproxy`, `firehol` (AUR), `bind`, `squid` | Compositor-independent; per-user transparent proxy via firehol is the ArchWiki's recommended allowlist pattern [S2]. | [S2] |
| **timeoutd**, **logkeys** (ArchWiki) | utmp-based login-time limits; keylogger | — | — | AUR | timeoutd is X11-era; logkeys is surveillance and ethically out of scope **(inference)**. | [S2] |

#### ArchWiki "Parental control" — full summary [S2]

Retrieved as raw wikitext through the MediaWiki API (the HTML page is behind an Anubis anti-bot wall). Sections and content:

1. **Lead + warning note**: "Any security features will be effective only on the level you enforce them… the child may bypass it by downloading and booting any Linux distribution live image."
2. **Applications**: `timekpr-next` (AUR) — screen-time manager; `timeoutd` (AUR) — scans `/var/run/utmp` each minute against `/etc/timeouts`; `logkeys` (AUR) — keystroke logger.
3. **Restrict opening applications**: `malcontent` (official) "allows setting access restrictions for flatpak based applications"; example `malcontent-client set-app-filter timmy x-scheme-handler/http` to stop a user opening a Flatpak browser.
4. **Whitelist with Tinyproxy and Firehol**: `FilterURLs On`, `FilterDefaultDeny Yes`, whitelist file of regex domains; firehol `transparent_proxy "80 443" 8888 "nobody root bin myaccount"` so only listed accounts bypass the proxy.
5. **OpenDNS Parental Control**: filtered resolver; keep dynamic IP updated with `ddclient`; can be set at router level for all devices.
6. **Editing /etc/hosts**: block domains, or allow-only (with the warning that pacman will break unless mirrors are mapped).
7. **Blocklisting using named**: a `denied.zone` that answers 127.0.0.1/::1 for wildcard, one `zone` stanza per blocked domain; BIND supports DoT/DoH so the resolver can be used away from home.
8. **Squid**: proxy with ACLs by MAC/IP/domain/TLS SNI; with nftables "can be used to fully control which websites can be browsed by the children".
9. **Browser add-ons**: warns they are weak — safe mode, profile manager, or simply another browser defeats them.

Takeaway: the wiki's stance is honest — everything is bypassable at a lower layer; the durable techniques are per-user transparent proxies and resolver-level filtering.

#### Desktop-project status

- **GNOME**: malcontent is the integrated solution; screen-time (`malcontent-timerd`) landed by 0.14 but has an unfixed local DoS [S7] and a documented user-switcher bypass filed against gnome-shell [S9].
- **KDE Plasma 6**: no native parental-controls KCM surfaced in searches; forum history calls the area "neglected"; malcontent merely *packaged* in KDE neon [S52][S53]. LiFE uses KDE Kiosk restrictions as its Plasma lockdown [S24].
- **Linux Mint**: discussion #1269 "Add a streamlined easy-to-use Parental controls system" is real, opened 2025-12-23, in the Ideas category, **no Mint developer response**; contributors call malcontent "limited" and cite CTparental as the only real option [S10]. An older issue #720 ("No Parental Controls available") argued it is a bug for a home distro [S54].
- **elementary OS**: "Screen Time & Limits" exists in Pantheon; a Medium post documents bypass via GRUB → Advanced Options → Recovery Mode → `root` shell → `adduser me` → disable Screen Time for the target user [S30] (fetch returned 403; content taken from search excerpt). The bypass is generic to any distro whose bootloader/recovery is unprotected, not elementary-specific **(inference)**.
- **Hyprland ecosystem**: nothing kids-specific except HyprTile's Child Lock [S25]. Session lock (`ext-session-lock-v1`) is implemented (hyprlock) [S58].

### 4. Reusable design patterns and anti-patterns for a Hyprland-based kids mode

**Patterns to adopt**

1. **Recovery over lockdown (ubermix)** — a kid profile whose *system* state can be reset from a boot key in seconds while documents persist [S14]. On Omarchy this maps naturally onto Btrfs snapshots / an overlay for the kid's `$HOME` and config **(inference)**.
2. **Verbs, not files (Sugar Journal)** — young children resume "what I was doing" from a chronological journal instead of navigating directories [S20]. A Hyprland kids launcher can present recent activities/sessions rather than a file manager.
3. **Zoom views instead of workspaces (Sugar)** — Home / Group / Neighborhood as the only "places" [S20]. Hyprland workspaces + special workspaces can be renamed and limited to 2–3 named places for the youngest band.
4. **Age bands as real sessions/users (PrimTux mini/super/maxi/prof; DoudouLinux; Edubuntu Preschool→Tertiary)** — not themes but distinct users with distinct app sets and controls [S41][S21][S11]. Aligns with the blueprint's "progressive complexity" idea.
5. **Offline-first content + rated store (Endless)** — preloaded content and an OARS-rated app catalogue with an install ceiling per child [S8][S22]. Flatpak + appstream OARS data are already on Arch; Kolibri/Kiwix are the offline content precedents [S12].
6. **Policy in one place, enforcement in many (malcontent)** — keep the accounts-service/libmalcontent policy format so future GNOME/KDE/Flatpak integrations interoperate, but write Hyprland-side enforcement (launcher filter, window rules, session limits) [S6][S8].
7. **Root daemon + unprivileged UI + declarative JSON policy (LiFE)** — privilege separation and pre-seedable config for "install on the family PC in 5 minutes" [S24].
8. **logind-based session limits with graceful warnings (timekpr-next)** — compositor-agnostic, multiple restriction types [S5].
9. **Remote "ask parent" (Family Link / Apple / Nintendo PIN)** — request from the kid session, approve from the parent's phone or with a password in place [S51][S46][S49]. ntfy-style push is the obvious FOSS transport **(inference)**.
10. **Education gates entertainment (Amazon Kids)** — reading/learning goal unlocks games [S50].
11. **Kiosk for toddlers (cage / Guided Access)** — a single-app session, not a locked-down full desktop [S26][S45].
12. **Local, private activity reports (ActivityWatch + Hyprland watcher)** — weekly summary without cloud [S44].

**Anti-patterns to avoid**

- **Forking the base distro** (DoudouLinux, ubermix): every upstream cycle becomes your rebuild; both died when the one maintainer stopped [S21][S15]. Ship as Omarchy packages/config, not an ISO.
- **Controls that are opt-in at the wrong moment**: 2% uptake in Endless [S8]. Make "add a kid" the first-class path.
- **Enforcing in the shell only**: gnome-shell-only screen time was bypassed with the user switcher [S9]; make limits a logind/PAM/daemon property, not a UI property.
- **Globally callable privileged D-Bus APIs** (CVE-2026-44931): validate caller session and quota anything a child session can write to [S7].
- **Browser add-on filtering** as the primary web control — trivially evaded [S2].
- **Surveillance (keyloggers, Veyon-style screen watching) presented as parenting** — ethically and technically the wrong tool; Veyon doesn't even work on Wayland [S2][S29].
- **Ignoring the boot layer**: unprotected GRUB/Limine recovery + no FDE = root for anyone with the keyboard [S30][S2]. Decide the threat model explicitly.
- **Electron/Qt-kiosk UI baggage** (LiFE): keep the parent UI native to Omarchy's stack (TUI/GTK/Quickshell) **(inference)**.

## Blueprint claims checked

| # | Blueprint claim (§2 / §6.1 / §8) | Verdict | Evidence |
|---|---|---|---|
| 1 | Endless OS = Debian Stable + OSTree immutability | **Confirmed** | Debian + OSTree [S22]; 6.0.0 on Debian 12 [S37] |
| 2 | Endless parental controls = "OSTree, Flatpak sandbox, Malcontent" | **Partly** | malcontent yes [S6][S8]; OSTree/Flatpak are not parental controls, they are packaging **(inference)** |
| 3 | Endless offline = "Kiwix-powered Encyclopedia" | **Unverifiable** | Endless page says only "packed with content" for offline use [S22]; Kiwix not seen |
| 4 | Edubuntu = Ubuntu LTS flavour, GNOME, subject folders | **Confirmed** | 26.04 LTS, GNOME 50, subject metapackages, age-group profiles [S11] |
| 5 | Edubuntu failure risk "metapackage bloat, GNOME maintenance" | **Partly / outdated** | Edubuntu is active and just shipped an LTS with rewritten tools [S11]; the real historical failure was maintainer loss then revival [S35]. Cited refs [30][31][35] point to `github.com/omarchy/kids-mode/...` — see #16 |
| 6 | Zorin OS Education = "Ubuntu LTS (Cinnamon/Xfce Lite)" | **Wrong** | Zorin Desktop is GNOME-based; Lite is Xfce 4.20; no Cinnamon [S36]. Base Ubuntu 24.04 [S36] |
| 7 | Zorin Education parental controls = "Malcontent, Timekpr-next, Veyon" | **Partly** | Veyon and Kolibri are on Zorin's page; malcontent/timekpr are not [S12] |
| 8 | Zorin failure risk "licensing/commercial transitions, heavyweight" | **Unverifiable** | No source found |
| 9 | SoaS = Fedora custom spin | **Confirmed** | Fedora SoaS spin 43 [S32] |
| 10 | Sugar failure "stagnation, legacy Python/GTK2 tech debt" | **Partly** | Sugar is GTK3 (toolkit `sugar-toolkit-gtk3` 0.121) [S33][S20]; GTK4 port is a 2026 GSoC project [S34]; slow, not dead |
| 11 | Sugar zoom views = "Me, Friends, Classroom, Neighborhood" | **Wrong labels** | Official views: Home, Group, Neighborhood (+ Activity) [S20] |
| 12 | Sugar Journal = automated metadata record, verbs not nouns | **Confirmed** | [S20] |
| 13 | DoudouLinux = Debian Lenny/Squeeze + custom LXDE, DansGuardian, discontinued | **Confirmed** (base era plausible, exact codenames unverified) | Debian + LXDE, DansGuardian, last release 2.1 Dec 2013, inactive [S21][S31] |
| 14 | DoudouLinux "discontinued due to OS burden" | **Unverifiable** | No stated reason found [S21] |
| 15 | DoudouLinux: from age 2, single-click, no terminal/filesystem, age menus | **Confirmed** | Ages 2–12, age-tiered menus, full-screen, no double-click [S21] |
| 16 | ubermix: three partitions (ro system ~12 GB, rw user changes, user home), UnionFS, 20-second recovery | **Partly** | UnionFS, ro Default System + rw User Changes + User Home, restore key at boot, "seconds" [S14]; "20 second" on homepage [S13]; **~12 GB not found** |
| 17 | elementary OS: Pantheon parental control leaves GRUB/recovery unprotected; bypass = Esc/Shift → Recovery → root → add user | **Confirmed in substance** | Medium walkthrough: GRUB → Advanced → Recovery Mode → root → `adduser me` → turn Screen Time off [S30]. Blueprint's `useradd -m -G wheel` is Arch-flavoured; elementary uses `adduser`/`sudo` group **(inference)**. Cited refs [66]–[69] not verifiable |
| 18 | Bibliography: Endless "Idea: Add Time Limits" at `community.endlessos.org/t/.../12345` | **Wrong URL** | Real thread: `community.endlessos.com/t/idea-add-time-limits-to-parental-controls/22724` [S39] |
| 19 | Bibliography: Linux Mint discussion #1269 | **Confirmed** | [S10] |
| 20 | Bibliography: `github.com/omarchy/kids-mode/blob/main/docs/*.md` (refs 29–32, 113 etc.) | **Wrong / fabricated** | `gh repo view omarchy/kids-mode` → "Could not resolve to a Repository" (2026-09-01). The blueprint cites a non-existent repo as its own evidence base |
| 21 | Bibliography: `support.google.com/chrome/a/answer/123456`, `forum.f-droid.org/.../12345`, `lwn.net/Articles/123456`, reddit `/12345/` | **Fabricated pattern** | Placeholder IDs; not fetched |
| 22 | Bibliography: `github.com/endlessm/malcontent` | **Confirmed** | Fork/mirror README fetched [S6] |
| 23 | Bibliography: `github.com/marcus67/little_brother`, `linux-in-der-schule.de/life-parental-control/` | **Confirmed (little_brother)** / search-only (LiFE site; GitHub repo verified instead) | [S23][S24] |
| 24 | Bibliography: ArchWiki Bubblewrap, Hyprland wiki launchers, KDE Kiosk docs | **Not checked** (out of this report's scope) | — |
| 25 | (implicit) CVE-2026-44931 "malcontent disk space DoS" | **Confirmed real** | openSUSE security blog 2026-05-11 [S7]; oss-security May 2026 [S61] |

## Implications & recommendations for Omarchy Kids Mode

1. **Do not adopt malcontent as the enforcement layer; consider adopting its policy schema.** Storing per-child app filters and OARS ceilings in accounts-service keeps compatibility with Flatpak/GNOME tooling and future KDE work, while Omarchy-specific enforcement (launcher filtering, Hyprland window rules, session limits) is written natively [S6][S8]. Track the CVE and avoid `malcontent-timerd` until fixed [S7].
2. **Build session limits on systemd-logind, not on the shell.** timekpr-next already proves the model works on Wayland; either integrate it (AUR, actively maintained, Wayland-aware) or reimplement its logind polling + graceful-warning + terminate/lock/suspend semantics natively [S5]. Verify tray (SNI) and lock hooks on Hyprland first.
3. **State the threat model in the README**: "deterrent for a curious child, not a security boundary against a determined teenager" (Withnall's own framing) [S8]; then list what raises the bar: full-disk encryption, bootloader password, firmware boot-order lock, no recovery entry without password, parent-only sudo. The GRUB/recovery bypass is generic [S30][S2].
4. **Ship a recovery story before a lockdown story.** ubermix's factory-reset-in-seconds is the single most parent-friendly feature in this survey [S14]. On Omarchy: snapshot the kid profile's config/home, one command/boot-menu entry restores it.
5. **Age bands as users.** Follow PrimTux/Edubuntu: three kid bands (approx. 3–5, 6–9, 10–13) plus parent, each a real Unix user with its own Hyprland config, launcher allowlist, workspace count, and keybind set [S41][S11].
6. **Youngest band = kiosk.** Use a dedicated session (cage or a stripped Hyprland config) that boots into one activity (e.g. GCompris) — the Guided Access equivalent [S26][S45].
7. **Offline-first content**: package Kiwix/Kolibri recipes and rely on Flatpak + appstream OARS ratings for the catalogue [S12][S8].
8. **Feature parity checklist against mainstream**: per-child profile, allowlist, daily budget, bedtime, ratings, ask-parent, weekly report, kiosk. Ask-parent via ntfy/phone is the differentiator no Linux tool has [S51][S46].
9. **Local activity reports via ActivityWatch's Hyprland watcher** rather than any screen capture [S44].
10. **Avoid distro-forking and single-maintainer designs**: publish as Omarchy packages + docs; keep the bus factor > 1 from day one [S21][S15][S11].

## Candidate workstreams / backlog items

Each is intended to be independently chunkable by a community member.

- **WS-01 Threat-model & hardening doc** — write the explicit threat model; document Omarchy's bootloader/FDE defaults and how to add a boot password / disable recovery entries; test the GRUB/recovery bypass on a stock Omarchy install [S30][S2].
- **WS-02 timekpr-next on Omarchy spike** — install from AUR; verify logind session tracking, notifications, tray via waybar, lock/suspend restriction types under Hyprland; write findings + PKGBUILD tweaks [S3][S5].
- **WS-03 malcontent policy-store spike** — install `extra/malcontent`; test `malcontent-client set-app-filter`; check whether Arch's flatpak enforces the filter on `flatpak run`; document the D-Bus schema for a Hyprland launcher to consume [S1][S2][S6].
- **WS-04 Launcher allowlist prototype** — make Omarchy's launcher (walker) honour a per-user allowlist (from malcontent or a JSON policy); hide everything else; kid-friendly icons/labels.
- **WS-05 Age-band profile generator** — a script that creates kid users with band-specific Hyprland config (workspace count, keybinds, theme), modelled on PrimTux mini/super/maxi [S41].
- **WS-06 Toddler kiosk session** — a `cage`-based or minimal-Hyprland session launching one app; document login-manager integration [S26].
- **WS-07 Factory-reset for kid profiles** — Btrfs/overlay-based "restore kid profile" command and boot-menu entry, ubermix-style, preserving Documents [S14].
- **WS-08 Ask-parent flow** — kid-side request UI + parent-side approval (local password or phone push via ntfy); grants bonus time or a one-off app launch [S51][S46].
- **WS-09 Activity report** — ActivityWatch + `aw-watcher-window-hyprland` install recipe and a weekly summary for parents [S44].
- **WS-10 Network filtering recipe** — per-user transparent proxy (tinyproxy + firehol) or resolver-level allow/block with DoH pinning, per ArchWiki, packaged as an Omarchy script [S2].
- **WS-11 Offline content packs** — Kiwix (Wikipedia for Kids, etc.) and Kolibri install recipes; curated OARS-rated Flatpak list per age band [S12][S8].
- **WS-12 Upstream liaison** — file/track: malcontent CVE-2026-44931 fix status [S7]; Hyprland-side needs (e.g. foreign-toplevel for watchers); coordinate with Edubuntu's age-profile work for shared curation [S11].
- **WS-13 Sugar Journal-style "recent activities" launcher** — design study only: can a Hyprland-native "what I was doing" view replace the file manager for the youngest band [S20].

## Open questions for the community

1. What is Omarchy's current default boot stack (bootloader, FDE, snapshots)? Does a kid who can boot the machine necessarily know the disk passphrase, and what does that do to the threat model?
2. Should policy live in accounts-service (malcontent format) for ecosystem compatibility, or in a simpler Omarchy-owned JSON file (LiFE style)?
3. Integrate timekpr-next or write native? Who will own the Hyprland tray/lock integration either way?
4. Does Arch's `flatpak` link `libmalcontent` so `flatpak run` refuses filtered apps? (Determines whether Flatpak is a real enforcement point on Omarchy.)
5. Which age bands? PrimTux uses 3–5 / 6–7 / 8–10; Edubuntu uses Preschool / Primary / Secondary / Tertiary.
6. Is any monitoring acceptable? The survey suggests local ActivityWatch summaries yes, screen capture/keylogging no — does the community agree?
7. Kiosk for toddlers: `cage` (separate compositor) vs stripped Hyprland (one stack to maintain)?
8. Who is the institutional anchor? PrimTux survives via schools/ministry; Edubuntu via Ubuntu. Is there an Omarchy/37signals-adjacent home for this, or a school pilot?
9. Do we want to upstream a fix for CVE-2026-44931 as a goodwill/entry contribution to malcontent?

## Sources

Status key: **VERIFIED** = fetched and content matched; **SEARCH-ONLY** = seen in search results/snippets only; **DEAD/UNVERIFIABLE** = fetch failed or blocked. All accessed 2026-09-01.

| # | Title | URL | Status | Note |
|---|---|---|---|---|
| S1 | Arch Linux package search: malcontent | https://archlinux.org/packages/?q=malcontent | VERIFIED | libmalcontent / malcontent / malcontent-docs 0.14.0-4 in extra, updated 2026-04-11 |
| S2 | ArchWiki: Parental control | https://wiki.archlinux.org/title/Parental_control | VERIFIED (via MediaWiki API raw wikitext; HTML blocked by Anubis) | Full page summarised in §3 |
| S3 | AUR: timekpr-next (RPC v5 info) | https://aur.archlinux.org/packages/timekpr-next | VERIFIED (via AUR RPC; web page blocked by Anubis) | 0.5.10-1, maint SanskritFritz, co-maint Mjasnik, updated 2026-08-17, 9 votes; deps gtk3/polkit/libappindicator/psutil |
| S4 | Launchpad: timekpr-next | https://launchpad.net/timekpr-next | VERIFIED | 0.5.10 released 2026-08-03; 0.5.9 2025-12-22; author Eduards Bezverhijs |
| S5 | Timekpr-nExT documentation | https://mjasnik.gitlab.io/timekpr-next/ | VERIFIED | logind-based, X11/Wayland/Mir sessions, PlayTime, restriction types, Arch via AUR |
| S6 | endlessm/malcontent README (GitHub mirror) | https://github.com/endlessm/malcontent | VERIFIED | Components, deps, "not a MAC system" |
| S7 | openSUSE Security: malcontent disk-space DoS (CVE-2026-44931) | https://security.opensuse.org/2026/05/11/malcontent-disk-space-dos.html | VERIFIED | 0.14.0, RecordUsage, no upstream fix, timeline Feb–May 2026 |
| S8 | Withnall, "Parental controls in GNOME" notes (GUADEC 2020-07-23) | https://events.gnome.org/event/1/contributions/78/attachments/11/29/presentation_notes.pdf | VERIFIED (PDF read locally) | Architecture, OARS, accounts-service, 2% uptake, "not real security", screen-time future |
| S9 | GNOME gnome-shell issue #9194 "Parental control screen time limit bypass" | https://gitlab.gnome.org/GNOME/gnome-shell/-/work_items/9194 | VERIFIED (partial; header only) | User-switcher bypass of time limit |
| S10 | Linux Mint discussion #1269 | https://github.com/orgs/linuxmint/discussions/1269 | VERIFIED | Opened 2025-12-23, Ideas category, no dev response |
| S11 | Edubuntu 26.04 LTS Released | https://discourse.ubuntu.com/t/edubuntu-26-04-lts-released/80831 | VERIFIED | GNOME 50, age-group profiles, rewritten tools, RPi5, to Apr 2029 |
| S12 | Zorin OS Education | https://zorin.com/os/education/ | VERIFIED | 18.1 Education; Veyon; Kolibri; no parental controls listed |
| S13 | ubermix home | https://www.ubermix.org/ | VERIFIED | "20 second quick recovery", 60+ apps |
| S14 | About the ubermix | https://www.ubermix.org/about.html | VERIFIED | UnionFS three-slice design, Restore Factory Settings, philosophy |
| S15 | Ubermix Changelog | https://wiki.ubermix.org/index.php/Ubermix_Changelog | VERIFIED | Newest 6.06, July 2022, Ubuntu 22.04 |
| S16 | Debian Edu wiki | https://wiki.debian.org/DebianEdu | VERIFIED | Bullseye current, Bookworm skipped, Trixie upcoming, LTSP |
| S17 | Debian Junior (Pure Blend) | https://blends.debian.org/junior/ | VERIFIED | Ages up to 8 then 7–12; no dated activity |
| S18 | PrimTux | https://primtux.fr/ | VERIFIED | PrimTux 9, age sessions, parental control, QwantJunior, SILL |
| S19 | Sugar Labs wiki: Sugar on a Stick | https://wiki.sugarlabs.org/go/Sugar_on_a_Stick | VERIFIED (stale) | Says Sugar 0.118 / Fedora 35; last edited 2022-02-16 |
| S20 | Wikipedia: Sugar (desktop environment) | https://en.wikipedia.org/wiki/Sugar_(desktop_environment) | VERIFIED | 0.121 2024-02-06; Journal; Home/Group/Neighborhood; Sugarizer; SFC |
| S21 | Wikipedia: DoudouLinux | https://en.wikipedia.org/wiki/DoudouLinux | VERIFIED | Debian/LXDE, DansGuardian, 2.1 Dec 2013, inactive |
| S22 | Endless Global: Operating System | https://www.endlessglobal.com/foundation/access/operating-system | VERIFIED (redirect target of endlessos.org/os) | Debian + OSTree, offline, target users |
| S23 | marcus67/little_brother | https://github.com/marcus67/little_brother | VERIFIED | 0.5.6 Dec 2024; process kill; Arch tested |
| S24 | valueerrorx/LiFE-Parental-Control | https://github.com/valueerrorx/LiFE-Parental-Control | VERIFIED | Root daemon + Electron UI; GRUB hardening; hosts/dnsmasq; beta |
| S25 | HyprTile | https://hyprtile.org/ | VERIFIED | v0.16 2026-07-29; Child Lock / Kiosk Mode; GPL-3 |
| S26 | cage-kiosk/cage | https://github.com/cage-kiosk/cage | VERIFIED | Wayland kiosk compositor, wlroots 0.20, active |
| S27 | Veyon | https://veyon.io/ | VERIFIED | Features; no Wayland statement |
| S28 | Veyon docs: Platform specific notes | https://docs.veyon.io/en/latest/admin/platform-notes.html | VERIFIED | No Wayland section |
| S29 | Veyon issue #860 "wayland fedora 36" | https://github.com/veyon/veyon/issues/860 | SEARCH-ONLY | No image under Wayland |
| S30 | Medium: Bypassing the Elementary OS Screen time feature | https://medium.com/@jamiechamberlain01356/bypassing-the-elementary-os-screen-time-feature-f76869fa9df4 | SEARCH-ONLY (fetch 403) | GRUB → recovery → root → adduser |
| S31 | DistroWatch: DoudouLinux | https://distrowatch.com/doudou | SEARCH-ONLY | Discontinued |
| S32 | Fedora Sugar on a Stick Spin download | https://fedora.gitlab.io/websites-apps/fedora-websites/fedora-websites-3.0/spins/soas/download/ | SEARCH-ONLY | SoaS 43, 2025-10-28 |
| S33 | Arch package sugar-toolkit-gtk3 0.121-2 | https://archlinux.org/packages/extra/x86_64/sugar-toolkit-gtk3/ | SEARCH-ONLY | GTK3 toolkit packaged |
| S34 | Sugar Labs GSoC 2026 project list (PDF) | https://lists.sugarlabs.org/archives/list/sugar-devel@lists.sugarlabs.org/message/XZOFRW3ZFCCNHJHUJZK3HR47ZTKCGLTW/attachment/4/gsoc2026.pdf | SEARCH-ONLY | GTK4 transition project |
| S35 | Wikipedia: Edubuntu | https://en.wikipedia.org/wiki/Edubuntu | SEARCH-ONLY | Discontinuation and 2023 revival |
| S36 | OMG! Ubuntu: Zorin OS 18.1 released | https://www.omgubuntu.co.uk/2026/04/zorin-os-18-1-released | SEARCH-ONLY | 2026-04-15, Ubuntu 24.04, Lite = Xfce 4.20 |
| S37 | Endless community: Release Endless OS 6.0.0 and 5.1.3 | https://community.endlessos.com/t/release-endless-os-6-0-0-and-5-1-3/22661 | SEARCH-ONLY | 2024-05-14, Debian 12 |
| S38 | Endless community: Release Endless OS 6.0.7 | https://community.endlessos.com/t/release-endless-os-6-0-7/23609 | SEARCH-ONLY | Nov 2025 point release |
| S39 | Endless community: Idea — Add Time Limits to Parental Controls | https://community.endlessos.com/t/idea-add-time-limits-to-parental-controls/22724 | SEARCH-ONLY | Real thread id 22724 (blueprint used /12345) |
| S40 | LVUSD Ubermix Guides | https://docs.lvusd.org/student-laptops/ubermix/ | SEARCH-ONLY | District build 7.0lv3 |
| S41 | PrimTux wiki: présentation du système | https://wiki.primtux.fr/doku.php/presentation_du_systeme | SEARCH-ONLY | mini/super/maxi/prof sessions |
| S42 | PrimTux forum: CTParental thread | https://forum.primtux.fr/showthread.php?tid=1545&pid=17588 | SEARCH-ONLY | e2guardian + privoxy, per-user, HTTPS, schedules |
| S43 | ActivityWatch/aw-watcher-window-wayland | https://github.com/ActivityWatch/aw-watcher-window-wayland | SEARCH-ONLY | Needs wlr-foreign-toplevel + ext-idle-notify; sway/niri/phosh |
| S44 | bobvanderlinden/aw-watcher-window-hyprland | https://github.com/bobvanderlinden/aw-watcher-window-hyprland | SEARCH-ONLY | Hyprland IPC watcher incl. workspace |
| S45 | Apple Support: Use Screen Time to manage your child's iPhone or iPad | https://support.apple.com/en-us/108806 | SEARCH-ONLY | Downtime, App Limits, Communication Limits, Ask to Buy |
| S46 | Apple Support: Respond to a child's Screen Time request | https://support.apple.com/guide/ipad/respond-to-a-screen-time-request-ipadde65d7c3/ipados | SEARCH-ONLY | Exception request flow |
| S47 | Microsoft Family Safety | https://www.microsoft.com/en-us/microsoft-365/family-safety | SEARCH-ONLY | Cross-device limits, filters, spending |
| S48 | Microsoft: Family Safety activity reporting | https://support.microsoft.com/en-us/family-safety/view-device-and-app-use-with-family-safety-activity-reporting | SEARCH-ONLY | Weekly reports |
| S49 | Nintendo Support: Parental Controls Features | https://en-americas-support.nintendo.com/app/topics/detail/p/989/c/271 | SEARCH-ONLY | Play-time limit, suspend software, bedtime alarm, ratings, PIN |
| S50 | About Amazon: Set parental controls with the Parent Dashboard | https://www.aboutamazon.com/news/devices/set-parental-controls-using-amazon-parent-dashboard | SEARCH-ONLY | Educational goals gate, bedtime, remote dashboard |
| S51 | Starry Hope: Family Link on a Chromebook (2026) | https://www.starryhope.com/chromebooks/family-link-chromebook-parental-controls-2026/ | SEARCH-ONLY (secondary) | Per-device limits, app approval, three filter postures |
| S52 | Repology: malcontent-parental-controls versions | https://repology.org/project/malcontent-parental-controls/versions | SEARCH-ONLY | KDE neon packages 0.10.x |
| S53 | Kubuntu Forums: Parental Controls re-visited | https://www.kubuntuforums.net/showthread.php/53433-Parental-Controls-re-visited | SEARCH-ONLY | KDE area "neglected" |
| S54 | linuxmint/linuxmint issue #720 "No Parental Controls available" | https://github.com/linuxmint/linuxmint/issues/720 | SEARCH-ONLY | Earlier request |
| S55 | Linux Mint Forums: Parental control made easy | https://forums.linuxmint.com/viewtopic.php?t=468768 | SEARCH-ONLY | Community demand |
| S56 | endlessm/eos-parental-controls (superseded) | https://github.com/endlessm/eos-parental-controls | SEARCH-ONLY | Predecessor of malcontent |
| S57 | GNOME wiki: Parental Controls and Metered Data hackfest 2019 | https://wiki.gnome.org/Hackfests/ParentalAndMetered2019 | SEARCH-ONLY | Upstreaming event |
| S58 | Hyprland issue #799 "security: implement ext-session-lock-v1" | https://github.com/hyprwm/Hyprland/issues/799 | SEARCH-ONLY | Session lock protocol history |
| S59 | GNOME admin guide: single-application mode | https://help.gnome.org/admin/system-admin-guide/stable/lockdown-single-app-mode.html.en | SEARCH-ONLY | Kiosk reference on GNOME |
| S60 | Distroscout: Best Linux Distros for Kids (2026) | https://distroscout.com/usage/kids/ | SEARCH-ONLY (secondary) | No new entrants; recycled list |
| S61 | oss-security list, May 2026 | https://www.openwall.com/lists/oss-security/2026/05/ | SEARCH-ONLY | CVE-2026-44931 announcement venue |
| S62 | DistroWatch: Endless OS | https://distrowatch.com/endlessos | SEARCH-ONLY | Release tracking |
| S63 | Sugar Labs home | https://www.sugarlabs.org/ | DEAD/UNVERIFIABLE | Fetch returned no content |
| S64 | Debian wiki: DebianJunior | https://wiki.debian.org/DebianJunior | DEAD/UNVERIFIABLE | HTTP 404; blends page used instead |
| S65 | malcontent upstream (freedesktop GitLab) | https://gitlab.freedesktop.org/pwithnall/malcontent | DEAD/UNVERIFIABLE | Anubis anti-bot block; GitHub mirror used |

Counts: VERIFIED 28 · SEARCH-ONLY 34 · DEAD/UNVERIFIABLE 3 · total 65.
