# Kids Mode Core

The current picture of core Kids Mode: what upstream has fixed, what the research says, what's
open. Updated 2026-09-02. Numbers like "report 03" refer to [research/](research/).

## Fixed points (from upstream — [quotes](research/discord-signal.md))

1. **Triggered at install.** First question: *Who is this computer for? Me / Child / Another owner.*
2. **Under 13 first.**
3. **sudo is the boundary.** Parent holds sudo; the child's account doesn't.
4. **DHH decides core.** This hub prepares suggestions, not decrees.

## The picture so far

| Area | Direction | Grounding |
| --- | --- | --- |
| **Install & accounts** | Two builds. [Installer path](PATH-INSTALLER.md): one account, kid password + parent password (root's), chosen at install. [Sandbox path](PATH-SANDBOX.md): Kids Mode app on a normal install, one real account per kid, parent never restricted. Both run the kid desktop from a root-owned Hyprland config via `--config`, how Omarchy's own greeter runs | reports 01, 03; the path pages |
| **Parent setup** | Five minutes, no terminal: age band → preset → daily budget + bedtime → parent PIN. Bands under 13: 3–5, 5–7, 8–10, 11–12 | report 07 |
| **Child onboarding** | A mascot teaches the machine one key at a time. Paths: **boy/girl/neutral proposed** (Harris); research leans character-choice with a neutral default — open design question for the mascot spoke | report 07 |
| **Web safety day one** | Family DNS via `omarchy dns` (strict DoT) + locked Chromium policy: SafeSearch, YouTube Restricted, DoH off, no incognito/devtools/extensions. Small change — the hooks already exist | report 04 |
| **A desktop that grows** | Level 1: one app, fullscreen → Level 2: 50/50 split, `Super+arrows` → Level 3: real tiling. Parent preset controls how fast levels unlock | reports 05, 07 |
| **Day-one apps** | Starter pack per band (GCompris, Tux Paint, SuperTuxKart, Luanti, TurboWarp…). Kids expect YouTube/Minecraft/Roblox — we answer with a curated library + YouTube Kids, Luanti + Minecraft Java one-click, Scratch + SuperTuxKart; Roblox is parent opt-in | report 05 |
| **Screen time** | Budgets and bedtime enforced via systemd-logind (not the shell); warnings before stops; local only; the kid sees what the parent sees; "ask a parent" for more time | report 02 |
| **Themes & fun** | Kid theme packs on Omarchy's theme system (git themes are colors-only — safe by design); big type, high contrast, mascot on the unlock screen | reports 01, 05 |

## Safety model, honestly

A deterrent for a curious child, not a wall against a determined teen. sudo is the wall; everything
else is depth. Nothing about a child ever leaves the machine — no spying, no cloud, no keylogging.

Sharp edges the research found on Omarchy 4.0.2 (report 03): Limine has no password and its editor
is on by default; `omarchy-refresh-limine` overwrites local hardening; root's password is set equal
to the owner's; `getty@tty1` is enabled; Ctrl+Alt+Fn VT switching is hardcoded in Hyprland; a child
who boots the machine alone knows the LUKS passphrase — so the **firmware password is the parent's
single most important step**. Full anti-bypass matrix: report 03 §6.

## Open questions

| # | Question | Where |
| --- | --- | --- |
| 1 | What exactly will the installer's "Child" path create? Being answered by Pete's PRs; see the [installer path](PATH-INSTALLER.md) | upstream |
| 2 | Mascot paths: boy/girl/neutral vs character-choice-with-neutral-default — or both? | mascot spoke |
| 3 | Default family DNS: Cloudflare Family (sponsor, simplest) vs CleanBrowsing/AdGuard (SafeSearch at DNS)? | report 04 |
| 4 | Levels: parent-set, earned through play, or both? | report 07 |
| 5 | How do we relate to [`jfuerwentsches/omarchy-kids`](https://github.com/jfuerwentsches/omarchy-kids) (same idea, started 2026-08-27)? | Discord outreach |
| 6 | Multiple kids on one machine — what does upstream multi-user look like? | upstream |
| 7 | Any voice/AI at all? Community is wary; if ever, a nameless offline tool, off by default | report 07 |

## Two paths, one hub

The old build plan ("prototype the Child path") is superseded. Upstream started building the
Child path itself on 2026-09-02, and the hub's spoke turned to the shared-machine case. Each path
has its own page with status, decisions, gaps, and how to help:

| Path | One line | Page |
| --- | --- | --- |
| **Installer** | The machine is the kid's. One account, two passwords, chosen at install. Built upstream by Pete | [PATH-INSTALLER.md](PATH-INSTALLER.md) |
| **Sandbox** | The family machine. Kids Mode is an app; each kid a real account; parent never restricted. Built in `omarchy-kids-sandbox` | [PATH-SANDBOX.md](PATH-SANDBOX.md) |

They share the parent command and its feature commands, and each hands the other pieces: the
sandbox spoke's Wi-Fi helper and starter packs go up; the installer path's privilege posture and
parent command come down. The Phase 1 verification checks live on the sandbox page and apply to
both.

## Omarchy 4.0.2 facts to build against (report 01)

Repo `omacom/omarchy` (default branch `quattro`; `master` is 3.x — don't read stale branches).
Quickshell shell with an official plugin system (`omarchy plugin add`, kinds: bar-widget / panel /
overlay / menu / service / bar; `omarchy.*` ids reserved). Hyprland config is Lua. Limine + UKI,
btrfs + Snapper, mandatory LUKS, NetworkManager + systemd-resolved, ufw, Chromium with root-owned
managed policies, SDDM autologin. Themes installed from git are colors-only. Extension points that
survive updates: plugins, menu-extension JSONC, hooks, root-owned `/etc` policy.
