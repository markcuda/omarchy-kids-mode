# Kids Mode Core

The current picture of core Kids Mode: what upstream has fixed, what the research says, what's
open. Updated 2026-09-01. Numbers like "report 03" refer to [research/](research/).

## Fixed points (from upstream — [quotes](research/discord-signal.md))

1. **Triggered at install.** First question: *Who is this computer for? Me / Child / Another owner.*
2. **Under 13 first.**
3. **sudo is the boundary.** Parent holds sudo; the child's account doesn't.
4. **DHH decides core.** This hub prepares suggestions, not decrees.

## The picture so far

| Area | Direction | Grounding |
| --- | --- | --- |
| **Install & accounts** | The "Child" path sets up a non-sudo kid account; parent holds sudo and the LUKS passphrase. Works with today's plumbing: a second user with an SDDM session and a root-owned Hyprland config via `--config` (how Omarchy's own greeter runs) | reports 01, 03 |
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
| 1 | What exactly will the installer's "Child" path create — and what should we prototype to inform it? | upstream + report 03 |
| 2 | Mascot paths: boy/girl/neutral vs character-choice-with-neutral-default — or both? | mascot spoke |
| 3 | Default family DNS: Cloudflare Family (sponsor, simplest) vs CleanBrowsing/AdGuard (SafeSearch at DNS)? | report 04 |
| 4 | Levels: parent-set, earned through play, or both? | report 07 |
| 5 | How do we relate to [`jfuerwentsches/omarchy-kids`](https://github.com/jfuerwentsches/omarchy-kids) (same idea, started 2026-08-27)? | Discord outreach |
| 6 | Multiple kids on one machine — what does upstream multi-user look like? | upstream |
| 7 | Any voice/AI at all? Community is wary; if ever, a nameless offline tool, off by default | report 07 |

## First tasks

Small, concrete, claimable. Open an issue saying "I'm on it."

| Task | Size | Grounding |
| --- | --- | --- |
| `omarchy dns` Family preset — a PR-shaped patch to the existing script | S | report 04 |
| Chromium/Firefox kids policy pack (`/etc/chromium/policies/managed/`) | S | report 04 |
| `omarchy-kids-check` — green/red "is it safe?" self-test for parents | M | report 04 |
| Kid-user script: useradd (no groups), `noexec` home, polkit deny pack | S | report 03 |
| Boot-harden kit: Limine editor off + re-apply hook, TTY/VT lockdown, checklist card | S | report 03 |
| Level 1/2/3 Hyprland Lua overlays | M | reports 01, 07 |
| Parent five-screen setup flow — prototype + test with 5 parents | M | report 07 |
| First kid theme (`omarchy-kids-tux-theme`): big type, 7:1 contrast, mascot unlock art | S | report 05 |
| Kids bar + launcher as shell plugins (big targets, allowlist-driven) | M | report 01 |
| "Shortcut Target Practice" — a window-tiling mini-game; nothing like it exists | L | report 05 |
| Verify on real 4.0.2: second-user session, Limine editor vs UKI, Flatpak override precedence | M | report 03 |
| Talk to the `omarchy-kids` author; agree how we fit together | S | — |

## Omarchy 4.0.2 facts to build against (report 01)

Repo `omacom/omarchy` (default branch `quattro`; `master` is 3.x — don't read stale branches).
Quickshell shell with an official plugin system (`omarchy plugin add`, kinds: bar-widget / panel /
overlay / menu / service / bar; `omarchy.*` ids reserved). Hyprland config is Lua. Limine + UKI,
btrfs + Snapper, mandatory LUKS, NetworkManager + systemd-resolved, ufw, Chromium with root-owned
managed policies, SDDM autologin. Themes installed from git are colors-only. Extension points that
survive updates: plugins, menu-extension JSONC, hooks, root-owned `/etc` policy.
