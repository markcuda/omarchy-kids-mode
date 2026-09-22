# Decisions the loop could not make alone

| Date | Topic | Where | Options |
| --- | --- | --- | --- |
| 2026-09-02 | Pause (fast user switch) cannot use SDDM on Omarchy 4.0.2: a second greeter fails with `HELPER_TTY_ERROR` on both the VM and the laptop | `docs/phase1/V1.md`, issue #2 | (1) start the parent's session on a spare VT through PAM without SDDM, as a new ticket with its own check; (2) ship Pause as lock-and-logout for v1; (3) wait for upstream multi-user. Note: the failed SDDM call also revoked the laptop's input devices until a udev re-trigger, so it is not a safe thing to ship even as a fallback |

## 3. Limine snapshot entries bypass every lock (V6) — decided 2026-09-04

Decided under Mark's standing order ("i trust you fully"): default hide while any kid profile
exists (`MAX_SNAPSHOT_ENTRIES=0`) with a conf toggle to show them, in disk boot mode only;
portal mode (docs/specs/07-boot-mode.md) never touches Limine, so nothing to hide there.
The wizard's summary names it in disk mode. Tracked in spec 07 ticket 2 (#93) and the
assert gate (#93/#95).

A pre-Kids-Mode Snapper snapshot boots its own frozen UKI (no unlock hook) and its own system
files (no locks, stock owner autologin) on the live home. Anyone with a disk password can pick
it from the boot menu. Recommendation: hide snapshot entries while any kid profile exists
(`MAX_SNAPSHOT_ENTRIES=0`), with a conf toggle to show them again. This touches the parent's
boot menu, not the parent's account: rollback stays available with `snapper rollback` and the
toggle. Your call: default hide, default show with a warning in the wizard, or something else.
Evidence: docs/phase1/V6.md.

## 4. Publish to the AUR, and the package name — closed 2026-09-04

Mark, 2026-09-04: "no need to upload the package or hub PR". Out of the definition of done
(docs/GOAL.md). The tree stays AUR-ready.

Everything for a first AUR upload is in the tree (`PKGBUILD`, `.SRCINFO` to regenerate with
`makepkg --printsrcinfo`, `CHANGELOG.md`, `docs/install.md`, `PRIVACY.md`). Publishing is
outward-facing and yours: the package name (`omarchy-kids` today), the maintainer line, and
whether to wait for the laptop round (Wi-Fi on real hardware, the lock screen's parent unlock)
before the first upload.

## 5. Upstream notes for Pete's PR (#33)

The findings worth sending upstream are written up (the `ignore-auto-dns` Wi-Fi helper,
`success=done` parent-unlock PAM line placement, SDDM's no-greeter-after-hard-terminate
behaviour, the Limine snapshot-entry bypass). Posting on omacom/omarchy#9750 is yours.

## 6. Decisions taken under the owner's standing order (2026-09-19)

Mark, 2026-09-19: "1-5 choose sensical defaults. we will dogfood it later." The five items below
are decided; the VM evidence still waits for a dogfooding session.

| # | Question | Decision | Why |
| --- | --- | --- | --- |
| 1 | R-ASK-2 "approve/decline on one keystroke" | Keep the safe flow: Enter opens the request's card with **Approve** preselected, one more Enter approves. SPEC.md's R-ASK-2 wording is amended to match. | Approving performs a real action (a grant, an install) and cannot be undone from the panel; a stray Enter on the list must not do it. |
| 2 | Pause (R-EXIT-3/4) | Not offered for v1. It waits for the PAM-on-a-spare-VT helper and its own Phase 1 check (option 1 in the 2026-09-02 entry), or upstream multi-user, whichever comes first. | The SDDM route failed on hardware and left the laptop's input devices dead until a udev re-trigger (V1). I-6: no control that is not enforced. |
| 3 | #98 / #109 boot transitions | Do not merge #98 before #109's template fix lands; portal mode is the recommended v1 configuration. #97 stays blocked behind #98; #99's VM proof moves into the dogfooding session. | A power cut during a single-UKI rebuild can leave the machine unbootable; no rush while the portal path is the supported one. |
| 4 | Level 3 | Hidden from the wizard and panel pickers for v1; existing `level = 3` profiles still start. Queued as the loop's next code item. | Its binds and the `omarchy-provision-first-run` passwordless-sudo question are unverified on a real box. |
| 5 | Per-app limits / weekly caps proposal | The seven open questions in `docs/research/2026-09-19-per-app-limits-and-weekly-caps-proposal.md` take the proposal's recommended answers, now recorded there as decisions. | Sensible defaults; no code until a ticket is opened. |

The R-ASK-2 amendment and the Level 3 hiding are tracked in commits on
`docs/decisions-2026-09-19` and the follow-up branch named in the loop prompt.

**Update, 2026-09-21 (supersedes item 4's hiding):** the owner asked for Level 3 to be made to
work properly and offered ("just make it work properly now"; "available, just with things hidden
per the parental permissions"). The autostart and menu-trim work is on
`fix/level3-no-parent-autostart` and `fix/level3-menu-trim`, verified live in
`docs/dogfood-2026-09-21.md`, and the three pickers now offer Level 3.

## 7. Open decisions at the end of the 2026-09-22 loop

By 2026-09-22 the loop had fixed and pushed everything it could reach on the try-omarchy VM, and
four consecutive rounds found nothing left to change. Each item below is already drafted or
proposed and waits only on the owner; none blocks merging the pushed branches, but each holds up
the work that follows it.

| # | Decision | Where the proposal and evidence are | What is needed |
| --- | --- | --- | --- |
| 1 | Collapse R-DESK-3/Appendix E to two kid modes (`grid`, `desktop`; band defaults 3-8 grid, 9+ desktop) | `docs/phase1/SPEC-AMENDMENT-two-kid-modes.md`, branch `docs/spec-amendment-two-kid-modes` (`64c73c5`) | Review the amendment; its five closing questions are yours. No code until then. |
| 2 | GCompris's first-run dialog and its config/quit controls — **decided 2026-09-21** (pre-seed the config), live-checked 2026-09-22, implemented on `feat/gcompris-preseed` | `docs/research/2026-09-21-gcompris-first-run-and-config-proposal.md` (its results section has the check: what `kiosk=true` hides and what suppresses each dialog) | Nothing further; it only needs the merge gate. |
| 3 | The add-on (plugins) model | `docs/research/2026-09-21-discord-plugin-survey.md` | Its five questions are yours. |
| 4 | Favorites/recents from the launch log (root-owned manifest stays authoritative) | `docs/favorites-recents-proposal` (`1c9a1a3`) | Three decisions: recents-first manifest ordering vs a Recent row; parent-pinned favorites; where recents appear. |
| 5 | W2: the time tick fails open when a budget or lights-out value cannot be read (the last state stays in force; `time:timer` only proves the timer is active) | `docs/time.md`; ticket W2 in `docs/research/2026-09-19-per-app-limits-and-weekly-caps-proposal.md` | Whether W2 (a `grace` state with reason `policy-invalid`) ships before the next dogfood round. |
| 6 | Does Level 3 keep the file-manager bind (`Super+Shift+F`) under `menu=trimmed`? | `share/hyprland/L3.lua`; `docs/levels.md` | Keep it, or unbind it with the rest of the trimmed rows. |
| 7 | The `dns` **and `sites`** keys are stored and never applied: the wizard offers Cloudflare / CleanBrowsing / "type my own", and the rendered Chromium policy always uses Cloudflare's family resolver (`omarchy-kids-web render` reads only the band's `web` mode) | `share/policy/README.md` ("not wired into `omarchy-kids-web` yet"), `docs/conf.md`'s `dns` row and `lib/wizard-advanced.sh`'s two descriptions, corrected 2026-09-22 to say so; `fix/dns-control-honesty`. `sites` is the same shape: the wizard offers an "Allowed sites" editor whose value nothing reads -- the live allowlist is `allow.txt` (approved requests) plus `share/policy/lists/<band>.txt`, and the pack's `[garden]` had drifted from that list until 2026-09-22 (`fix/garden-sources-agree`, pinned by `test/shell.d/garden-lists-test.sh`) | Wire them (the policy file is per band while the keys are per kid, so a per-kid override needs a re-think -- band-level only, with the docs saying so) or drop the choices. The same sweep found `apps.show_missing` has no reader on the union (`fix/show-missing-regression` restores it) and that `password`/`onboarded` are system-managed records nothing keys off. |
| 8 | The bar widget's open-request badge and its "Open requests" row run the root-only `omarchy-kids-ask list` from the parent's unprivileged session, so neither can ever work (`share/bar/KidsModule.qml:112` polls it; `:185` runs `omarchy-kids --requests`) | `docs/loop-bar-requests-finding` (live: `omarchy-kids --requests` exits 1 "list: root only"; the queue is 0644 by `lib/ask.py:135`, and the panel reads it unprivileged via `lib/panel-requests.sh:44`). The contradiction is explicit in the docs: `docs/ask.md:78-82` documents `list` as root-only while `docs/bar.md:114` assumes the badge runs it unprivileged, so one of them is wrong whatever the fix | Pick one: publish the count in root-written `status.json` (0640 `omarchy-parents`); have `omarchy-kids --requests` read the queue the way the panel does; or tighten the queue to 0640 `omarchy-parents` (the only option that makes the guard real). |

**Live evidence only an owner-run session can produce** (the loop drives the VM, never the laptop):
the Level 3 menu trim on a real Omarchy box (`share/menu/omarchy-kids-trimmed.jsonc` is an admitted
guess), a Wi-Fi join through the helper plus a captive portal, a band-3-5 kid's level, and the
portal's wrong-password path.

**The gate:** 60 branches sit ahead of `integration/dogfood-2026-09-19`;
`docs/branch-conflict-map-2026-09-22.md` (branch `docs/branch-conflict-map-2026-09-22`) maps the
file overlaps, the real pairwise conflicts and how each resolves (all supersets or stale branches),
the eight branches that are safe to skip, and the two stale ones. Read it before opening the gate.

