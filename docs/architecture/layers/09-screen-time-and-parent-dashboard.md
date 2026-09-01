# L9 · Screen Time, Reports & Parent Dashboard

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/02-prior-art-kids-linux-and-parental-controls.md`, `01-omarchy-platform.md`_

## Purpose

Daily budgets, bedtime windows, per-app/per-activity limits, and a **local, kid-visible** summary of how the
computer was used — without spyware. Plus the parent's side: seeing status, granting time, approving requests.

## What parents measure us against (verified, report 02 §2)

Per-child profile · app allowlist · daily budget · bedtime/downtime · content ratings · **remote "ask parent /
approve"** · weekly summary · single-app mode for the youngest. Distinctive extras worth copying: Nintendo's
"suspend software" hard stop with warnings; Amazon's *education gates entertainment* ("no games until 30 min
reading"); Apple's in-place approval with the parent's password. **No Linux tool has an "ask parent" flow** —
it's our differentiator. [R02-S45]–[R02-S51]

## What exists on Linux (verified, report 02 §3)

| Option | Fit on Omarchy/Hyprland | Verdict |
| --- | --- | --- |
| **timekpr-next** (AUR 0.5.10, 2026-08-17; upstream co-maintains) | Enforces via **systemd-logind** (compositor-agnostic), tracks Wayland sessions, PlayTime per-process limits, restriction types terminate/lock/suspend/shutdown, freedesktop notifications. Unknowns on Hyprland + omarchy-shell: tray (SNI) icon, lock-screen hook, polkit agent. [R02-S3][R02-S5] | **Spike first** (OQ-18). Integrate if tray/lock work; otherwise borrow its semantics |
| **malcontent-timerd** | GNOME-shell enforced → enforces nothing here; unfixed local DoS CVE-2026-44931; user-switcher bypass filed upstream. [R02-S7][R02-S9] | **Avoid** for enforcement; maybe reuse policy schema (OQ-17) |
| **little_brother** | Process-kill limits, multi-host pooling, web UI; last release Dec 2024; not in AUR. [R02-S23] | Design reference for pooled time across devices; don't depend on it |
| **LiFE Parental Control** | Root daemon + unprivileged UI + JSON policy; the right shape; Electron UI, .deb only. [R02-S24] | Copy the architecture, not the code |
| **ActivityWatch** + `aw-watcher-window-hyprland` | Local usage tracking via Hyprland IPC (window titles, workspace, AFK). [R02-S43][R02-S44] | **Candidate** for the activity summary |
| **`jfuerwentsches/omarchy-kids` agentd** | Rust daemon with budget / pre-warning / ticker modules, polkit policy, parent control over SSH. [R01-S44] | Coordinate (OQ-15) — this may *be* the daemon |

## Principles

1. **Enforce in logind/a root daemon, never in the shell.** Shell-only limits get bypassed by a user switcher
   (GNOME's own bug). [R02-S9]
2. **Warn before stopping.** Notifications at 15/5/1 minutes; a soft-lock overlay, then session termination or
   lock. Save work where possible.
3. **The kid can see everything the parent can see.** No covert monitoring, no screenshots, no keyloggers. A
   summary of *what* and *how long*, at most window titles — never content.
4. **Local only.** Summaries live on the machine. Remote notification (ntfy to a parent's phone) is opt-in.
5. **Activity-type awareness.** Creating (Tux Paint, Scratch, terminal) can be unlimited while consuming (video)
   is budgeted — the Amazon pattern, with the kid told the rule up front.
6. **Ask-parent, two ways.** In place (parent types their password) or remote (ntfy push → approve link over the
   LAN/SSH). Grants: +N minutes, one-off app launch, "until bedtime".

## Proposed design

- **Policy:** one root-owned JSON/TOML per kid (budget per day-of-week, bedtime window, per-app class limits,
  education gate). Written by `omarchy-kids-setup`/the parent UI; readable by the kid's bar widget.
- **Daemon:** system service; polls logind sessions (timekpr-next model) or subscribes to Hyprland IPC via a
  per-user helper for foreground app class; ticks budget; emits warnings over D-Bus/notifications; terminates or
  locks via logind.
- **Kid-side UI (L5 plugin):** `bar-widget` countdown; `overlay` soft-lock with the mascot ("Time's up — ask a
  grown-up for more?"); `panel` "My day" summary.
- **Parent-side:** single-user Omarchy today → parent unlocks with password in place; shared machine (after 4.1)
  → a `panel` in the parent's session; remote → the omarchy-kids Qt control centre or a tiny web/TUI over SSH.
- **Reports:** ActivityWatch's Hyprland watcher feeding a weekly local summary; same data shown to the kid.

## Interfaces

Consumes presets (L6), app classes/allowlist (L4/L8), account identity (L1). Provides budget state to L5 widgets.
Depends on L2/L1 for tamper-resistance (a kid in `wheel` defeats everything).

## Residual risks

- A kid who can switch VT or log in as another user escapes limits → L1/L2.
- Killing sessions loses unsaved work → warnings + autosave-friendly app choices.
- Any monitoring is a trust cost; keep it minimal and symmetric.

## Workstreams & backlog seeds

- WS-9.1 **timekpr-next on Omarchy 4 spike** (tray, lock, polkit agent, notifications under omarchy-shell).
- WS-9.2 **Policy schema** for budgets/bedtime/app-classes (align with omarchy-kids agentd; consider malcontent schema for app filters).
- WS-9.3 **Ask-parent flow** design study + ntfy prototype.
- WS-9.4 **Activity summary** via ActivityWatch Hyprland watcher; a "My day" panel mock.
- WS-9.5 **Education-gates-entertainment** rule design (kid-visible).

## Open questions

OQ-11, OQ-15, OQ-17, OQ-18; plus: is *any* activity summary acceptable to the community (report 02 asks)? Where
does the "parent side" live on a single-user machine?
