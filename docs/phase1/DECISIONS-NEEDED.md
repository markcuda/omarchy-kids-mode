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
