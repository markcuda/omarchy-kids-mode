# Kids Mode landscape — what other implementations do (2026-09-18)

A GitHub pass over comparable projects, for feature ideas we can borrow without abandoning the
sandbox path's own rules (I-1..I-9: the parent never restricted, locks root-owned outside every
home, fail closed, keyboard-complete, honest labels). Links checked 2026-09-18.

## Closest projects

| Project | What it is | What is worth borrowing |
| --- | --- | --- |
| [polesapart/timekpr-next](https://github.com/polesapart/timekpr-next) (57★, Python, AUR) | Long-lived Linux screen-time daemon; logs out locks or suspends; per-weekday allowances, allowed-hour intervals, weekly/monthly caps, per-application "PlayTime" limits, "∞" freeride intervals, a client indicator with remaining time, DBus interfaces. | **Per-application daily limits** (PlayTime), **allowed-hours windows** distinct from a bedtime, **weekly cap**, remaining-time visibility for the kid. |
| [TrissyGE/cozy-kids-launcher](https://github.com/TrissyGE/cozy-kids-launcher) (10★, Python) | Full-screen local-first kid launcher: tiles for apps/sites/media, pinned parent settings, per-child favorites/recents, 4/9 layouts, themes, timer + per-app schedules, PIN block screens, remaining-time overlay, config export/import, sounds and speech. | **Favorites and recents** in the launcher, **config export/import** for parents, remaining-time overlay, optional gentle feedback (sound/speech) later. |
| [GHJJ123/brainrotguard](https://github.com/GHJJ123/brainrotguard) (347★) | Parent approves YouTube videos over Telegram; kid watches in a web UI. | Approval-per-item as the model for "requests" — we already have Ask; nothing to copy architecturally (cloud dependency conflicts with I-2). |
| [bitoceango/civideo](https://github.com/bitoceango/civideo) (64★) | Self-hosted, ad-free, closed-garden kids video player. | The walled-garden framing is ours already; a local media library is out of scope for v1. |
| [relloyd/tubetimeout](https://github.com/relloyd/tubetimeout) (46★) | Network-level YouTube usage tracking. | Visibility-only reporting; we do per-kid local ledgers already. |
| [JohnnyPitchfork/scratch-launcher](https://github.com/JohnnyPitchfork/scratch-launcher) (1★, C#) | Fullscreen kid launcher for Scratch. | Confirms the big-tile pattern; no new capability. |
| [markcuda/omarchy-kids-mode](https://github.com/markcuda/omarchy-kids-mode) (9★) | The hub for this project (research, installer path, this sandbox path). | Our own source of truth; keep the two paths' shared parent command in sync. |

Adjacent research already in the tree: `docs/archive/project-hub/research/` (Omarchy platform,
prior art, hardening, DNS/browser, apps/themes, pedagogy) and `docs/research/2026-09-03-community-scan.md`.

## Borrowable features, ranked for this repo

Effort assumes the existing root ledger, manifest, launcher and panel patterns.

1. **Weekly cap and allowed-hours windows** (small/medium, spec-first). timekpr-next's two most
   requested knobs. Our state machine already tracks a logical day; a week total and a per-day
   window list extend `time_remaining_minutes` and the profile schema. Needs a SPEC amendment
   before code.
2. **Per-app daily limits ("PlayTime")** (medium, spec-first). The launcher already logs launches
   (`launches.log`) and the manifest already names tiles; root could account per-app minutes and
   the launcher could refuse or warn at the limit. This is the differentiator no Omarchy-local
   project has, and it fits R-TIME's root-owned state. Security note: enforcement must live
   root-side (launcher refusal plus the exit path), never in kid-killable UI alone.
3. **Remaining-time visibility for the kid** (small). timekpr-next shows time left continuously;
   our review found kids learn it only from toasts. A small launcher indicator bound to root's
   published status closes that gap without changing enforcement.
4. **Favorites and recents** (small). Cozy sorts tiles per child; our manifest is static. Keep the
   manifest authoritative (root-owned), add parent-visible recents from the launch log — no
   kid-writable ordering.
5. **Config export/import** (small). Cozy ships it; we have `omarchy-kids-conf`. An export of a
   kid's Appendix B keys plus a validated import would help parents move setups between machines.
6. **Optional sound/speech and celebration** (small, delight). Cozy's presets show the value for
   pre-readers; our Time's Up card is silent. A generated chime or `spd-say` line behind a band
   default is honest and cheap.
7. **Local media library** (large, out of v1). Cozy's cover library and isolated player resume
   state are attractive but a new surface, new dependencies and new privacy questions; leave in
   research.

## What to avoid from the landscape

- Cloud/Telegram approvals (I-2: nothing about a child leaves the machine).
- Web UIs bound beyond localhost (attack surface without a parent need).
- Restriction types we cannot verify live (suspend/RTC wake), and anything that touches the
  parent's own session (I-1).
- Per-process blanket kill lists: our model is an allow-listed launcher plus root-side finish, not
  a process police; per-app limits should plug into that, not replace it.
