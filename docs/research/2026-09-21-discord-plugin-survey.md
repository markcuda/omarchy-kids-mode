# Discord kids-mode repo survey and the add-on model (2026-09-21)

Status: research only. No code, config, or package changed. Owner asked for a survey of the
repos listed in the Omarchy community thread plus a first design for parent-controlled add-ons.

## Method and coverage

- The owner's Discord thread was read in his logged-in browser via AppleScript JavaScript
  (read-only): every `github.com` link in the rendered messages was harvested and deduplicated.
- 18 links came out. Five are noise for this purpose: `omacom/omarchy` (core), `omacom/omarchy-site`
  and `omacom-io/omarchy-site` (the website), `you/omarchy-your-theme` (a template), and
  `omacom/omarchy-plugin-marketplace` (read directly, see below).
- The remaining 13 repos were read by workers over the GitHub web UI (README, license, manifests,
  and the most relevant source). Six further projects from
  `docs/research/2026-09-18-kids-mode-landscape.md` were surveyed the same way.
- Discord virtualizes its message list; the scroller did not yield older messages to scripted
  `scrollTop` changes, so the thread may hold repos above the first screenful. This document covers
  the 18 harvested links; a manual pass can extend it.

## Per-repo digests (thread repos)

All claims come from the repos' READMEs/licenses/manifests; the licenses were taken from the repo
metadata and license files.

### Adopt as parent-approved apps (separate packages, own tile)

- **tcballard/omarchy-retro-arcade** — GPL-3.0-or-later. Rust/egui native app, 14 offline games,
  keyboard-first, per-game atomic saves, shipped as an Arch package. Its optional leaderboard is
  the only network path and must be fenced (I-2). Copyleft: package separately, never vendor.
- **neshath/omasprite** — GPL-3.0-or-later. Rust/egui sprite and game editor; "creator levels"
  unlock discoverability, not file compatibility; local-first versioned project folders. Same
  separate-package treatment.
- **virajshoor/touchtype-for-kids** — MIT. Static typing game served by a Python stdlib server and
  opened in `Chromium --app`; no root, no telemetry, no account. `launch.sh` hardening (mode-0700
  mktemp, owner checks, traps) is worth copying into our own launchers.
- **mikeg0/omarchy-kids-math** — MIT. Quickshell overlay, offline, adaptive practice; hardened
  state-path validation (no-follow, ownership, atomic writes) and a tutor IPC result shape
  (`schemaVersion`, `skillScores`, `recommendedLevel`). State must be re-keyed per Unix account.
- **elynch303/omarchy-math** — MIT. Gentler practice loop: a miss shows the answer and moves on,
  press-and-hold grown-ups area, `FloatingWindow` panel isolation. Also per-install state today.
- **peterholko/omarchy-math-time** — MIT. Full-screen practice overlay whose socket presence lease
  counts time only while it is visible on an unlocked desktop; root-owned progress; parent override
  through PAM. Explicitly "not an OS security boundary" (honest label, I-6).

### Adopt the data

- **peterholko/omarchy-bubblegum-theme** — MIT, data only (`colors.toml`, wallpapers, icons,
  keyboard RGB, unlock/screensaver art). Its own attribution says it was originally developed in
  an Omarchy Kids project. A ready kid theme for `lib/theme.sh` / `share/sddm-theme`.
- The design thread's links (`omarchy-kids-logos`, `omascot`, `omarchy-omaski`, plus kid-friendly
  fonts such as `maple-font`, `recursive`, `baloo2`, `dynapuff`, `victor-mono`) are assets for a
  bundled kid theme pack, license permitting per repo.

### Borrow the design, not the code

- **This-Is-NPC/omahouse** — MIT. App identity is the cgroup `app.scope`, not `/proc/exe`; budgets
  per app/site/session with warn→grace→act; presence measured by root from `/sys/class/drm/*/dpms`
  plus `logind` (never the kid's own socket or an idle hint); a new profile starts observing
  (`enforce:false`); the read of the kid-writable runtime file is hardened (O_NOFOLLOW, owner +
  regular-file check, bounded tail). Rejects: it composes one machine-wide Chromium policy
  (breaks I-1), installs via `curl|bash` and its own PAM line (rule 8), and its docs say a session
  logout can leave SDDM black (a fail-safe defect we must not inherit).
- **mandrigin/ok-extras** — **no license**. Claims `/etc/omarchy-kids/policy.json` and
  `/var/lib/omarchy-kids/`, a namespace collision with us, and is built on a different Omarchy Kids
  host. Design only: `policy.json` vs `allowlist.json` split, cgroup accounting where overlapping
  processes bill once, idempotent 1–60 minute grants with explicit after-bedtime vs schedule-only.
- **peterholko/omarchy-school-mode** — MIT. Take the PAM **expiry gate** pattern (policy checked
  before *and* after auth, originals run as a substack so an internal `success` cannot skip it),
  stdin-only passwords, SO_PEERCRED peer checks, and the "approved desktop" allowlist idea.
  Rejects: it patches core `LockView.qml` (I-7) and owns `/usr/bin/omarchy-kids-controls` +
  `/etc/omarchy-kids-controls/`, a second namespace collision; its helper is runnable by the kid,
  so it is UI, never enforcement.
- **TrissyGE/cozy-kids-launcher** — MIT (from the earlier landscape pass). Per-tile weekly
  availability windows, an owned-process launch lifecycle with a defined end, and a CSP-fenced
  embedded web view with a return path. Its enforcement is user-writable; borrow the shapes.
- **Drmedkit/quiet-youtube** — MIT. Channel-ID allowlists, a UID-bound 900-second parent session,
  per-device CRX3 signing. Rejects: it fetches YouTube metadata over the network (I-2), writes a
  global Chromium policy file, and self-admits its page guard needs hardening (so it cannot ship
  as an enforced control).
- **relloyd/tubetimeout** — GPL-3.0 (earlier pass). Expiring override records (`Mode` +
  `ModeEndTime`) and temp+fsync+rename validated writes for our ledger. Its unauthenticated `:80`
  control plane and DHCP/nftables posture are not adoptable.
- **polesapart/timekpr-next** — GPLv3 (earlier pass). Per-weekday hour windows, weekly/monthly
  caps, free "∞" lesson windows, read-open/admin-denied D-Bus ACL, gift/penalty on spent balance.
  A competing root daemon; patterns only.
- **GHJJ123/brainrotguard** — MIT (earlier pass). Kid request queue → parent approve/deny →
  allowlist entry, trusted-source auto-approval, per-day overrides and bonus minutes; its own docs
  confirm DNS is "a layer, not a wall" (DoH/VPN/hotspot bypass). The approval shape matches our
  Ask-a-parent flow; the Telegram dependency cannot come.
- **bitoceango/civideo** — MIT (earlier pass). Single parent-authored manifest as the only catalog,
  heartbeat accounting with reason codes, aggregate parent reports. Client-trusted time and cloud
  state are rejects.

### Skip

- **JohnnyPitchfork/scratch-launcher** — no license, Windows/WPF, unmaintained. Negative evidence
  only (a topmost window is not a fence).
- **This-Is-NPC/backstage** — Apache-2.0, developer recording tool (Hyprland, libvirt, display
  takeover). Not a kid add-on; its "rehearse before take" discipline is already our dry-run habit.
- **This-Is-NPC/omapixel** — MIT, pixel studio. It is a fine app, but ship it only with its plugin
  runner disabled: `plugin run` executes a local executable the kid could supply, against rule 9.

## Marketplace facts that shape the design

`omacom/omarchy-plugin-marketplace` lists community plugins that are installed with
`omarchy plugin add <repo>`. Its own README states: plugins execute as **unsandboxed** code, the
checks are "not a security audit", and "current marketplace install and update commands clone
mutable upstream HEAD and are not verification-bound". A parent's own shell can accept that; a
kid's account cannot. We reuse the *pattern* (a manifest, a listing, a submission review), not the
trust model.

## Fold-in shortlist (ranked, what to do first)

1. **Launcher/ledger mechanics (core, no third-party code):** expiring Ask-a-parent grants;
   presence-crossed accounting (DRM dpms + logind, never a kid-reported idle); temp+fsync+rename
   validated writes for the ledger; observe-first profiles; per-tile availability windows.
2. **Per-app identity and accounting:** cgroup `app.scope` as the app identity (omahouse) instead
   of matching executables, with overlapping scopes billed once (ok-extras).
3. **PAM gate hardening:** policy checked before and after auth in a substack (school-mode).
4. **Content apps as packages:** retro-arcade, omasprite, touchtype, both maths, math-time —
   separate packages, tiles from the root-owned manifest, network fenced where it exists.
5. **Kid theme pack:** bubblegum-theme data plus the design thread's logos/fonts.
6. **Approve/allow flow:** trusted-source auto-approval (brainrotguard) applied to domains and to
   our request queue.

## Add-on model (proposed)

Seam: an extension is **content the parent approves**, never control.

- **Closed forever:** locks, verifier/PAM, session entry, preflight, Chromium policy and DoH,
  boot hook, time ledger. Anything that selects code or skips a root check is out of scope.
- **Open surfaces:** launcher tiles (id + fixed argv from our root-validated manifest), allowed
  sites, themes, band pack entries (v2; needs a SPEC amendment to R-BAND-1), kid screens and
  read-only parent-panel rows (v3, keyboard-complete and reviewed).
- **Manifest:** an extension repo ships `omarchy-kids-extension.toml` (data, never sourced):
  `id`, `name`, `version`, `source` (`aur:<pkg>` or git URL), `commit` (pinned SHA), `sha256`,
  `surfaces`, `min_spec`, optional age floor.
- **Registry:** the parent approves in Advanced setup or the panel with their password; root writes
  `/etc/omarchy-kids/extensions/<id>.toml` (0644, same convention as `kids/<account>.conf`). The
  approval *is* the entry; nothing kid-writable or environment-selected participates.
- **Apply:** provisioning/conf applies only Appendix B keys and adds the tile to the root-owned
  manifest. Kid login never reads extension state (an absent extension is a hidden tile).
- **Updates:** pinned commits; surface or exec changes re-open for approval (show the diff, I-6);
  patch-only auto-apply is an owner question below. Discovery happens at the parent's own time,
  never at kid login; no new daemon.
- **Threat model:** a hostile extension can at worst write the kid's home and launch already
  allowed apps/sites; it cannot reach the parent, the policy file, the locks, or the network beyond
  the browser policy.
- **Staging:** v1 = registry + tiles/sites/themes with a small shipped catalog; v2 = pack entries
  (with the amendment); v3 = kid screens/panel rows.

## Collisions and constraints to resolve first

- Namespace: `school-mode` and `ok-extras` both claim `/etc/omarchy-kids/…`; `school-mode` also
  claims `/usr/bin/omarchy-kids-controls`. Third parties must use `/etc/<vendor>/…`; our registry is
  the only shared surface.
- Licensing: GPL-3.0/GPLv3 repos stay external packages (never vendored); repos with no license
  (`ok-extras`, `scratch-launcher`) are design-only, never copied.
- I-1: anything composing one machine-wide Chromium policy (omahouse, quiet-youtube) cannot be
  adopted as-is.

## Open questions for the owner

1. Catalog source: ship a small add-on catalog inside our package, or let root fetch a listing at
   its own time (I-2 permits only the package manager and the browser DoH)?
2. Re-approval scope: every release, or only when the surface set / exec argv changes?
3. Band pack entries: v1 or wait for a SPEC amendment to R-BAND-1 / Appendix C?
4. Distribution: AUR packages the parent installs, or vendor MIT apps as optional dependencies?
   (GPL apps stay separate either way.)
5. Surfaces for v1: tiles + sites + themes only, or also the kid-screen and panel-row surfaces?
