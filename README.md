# Omarchy Kids Mode

Kids Mode for Omarchy: the parent keeps their own account and full desktop, never restricted.
Each kid gets a profile that is a real account underneath, with root-owned screen time, a
parent-owned browser policy, a login portal, and a parent panel. A Super triple-tap and the
parent password get the parent back out. Core is untouched.

This is the one repository for the project. The design records live here: `CORE.md`, `SPOKES.md`
and `research/`; `PATH-SANDBOX.md` and `PATH-INSTALLER.md`, which describe the two paths this
app came out of, are on the **`two-paths`** branch
([PATH-INSTALLER.md](https://github.com/markcuda/omarchy-kids-mode/blob/two-paths/PATH-INSTALLER.md)).
The two paths share the parent command and its feature commands. The old hub history is kept on
the `hub-archive-2026-09-19` branch.

## Status: v1 build in progress

**Paused 2026-09-11** at the owner's request; the current state, what is verified, and the resume
path are in [`docs/handoffs/PAUSED-2026-09-11.md`](docs/handoffs/PAUSED-2026-09-11.md).

The spec is **[SPEC.md](SPEC.md)**; the work is
[issues in six milestones](https://github.com/markcuda/omarchy-kids-mode/milestones), in build
order. Results of the Phase 1 checks live in [`docs/phase1/`](docs/phase1/) (real hardware and the
QEMU test VM described in [`docs/vm.md`](docs/vm.md)): **V2, V4, V5 and V7 pass**; **V1 is
finished and failed** — that's the reason Pause isn't built yet, see
[`docs/phase1/V1.md`](docs/phase1/V1.md); V3 and the rest of V6 are still in progress.

### What works today

Only what has actually run against a real Hyprland, Quickshell, and SDDM in the QEMU test VM —
each command's own doc under [`docs/`](docs/) has the full "Verified live" section this list is
drawn from; nothing here is drawn from the spec alone.

- The parent wizard runs start to finish over SSH with an answers file, provisions a real kid
  account (Unix account, LUKS slot, band, avatar), and a cold boot with that kid's own disk
  password lands straight on their Level 1 launcher — no manual step in between
  (`docs/wizard.md`, `docs/session.md`).
- The login portal shows one face tile per account and logs a kid straight into their own
  Hyprland session by keyboard alone (`docs/portal.md`).
- Super×3 and Super+Shift+K both open the exit modal; the parent password on **Finish** ends the
  kid's session cleanly and SDDM returns to the portal (`docs/exit.md`). The password gate there
  is a courtesy, not a lock: a kid can end their own session anyway (`loginctl terminate-session`,
  or closing every window). **Pause** is not offered because it is not implemented.
- Screen time counts real minutes while a kid's session is active, in a root-owned ledger, and
  warns before it runs out (`docs/time.md`). At the budget or lights-out boundary root asks logind
  to lock the session, records the result of that request, and ends the session after a 60-second
  grace period unless a parent grants more; the lock's live behavior is an open finding
  (`docs/handoffs/PAUSED-2026-09-11.md`). The in-session "Time's Up" card is display only —
  killing it does not stop the root deadline.
- "Ask a parent" for more time opens over the launcher, and the parent password grants it on the
  spot — the grant shows up in the ledger within the minute (`docs/ask.md`).
- The parent panel's Home screen shows live per-kid minutes and grants more time for real, run
  over SSH with an answers file (`docs/panel.md`).
- A kid's Wi-Fi request is correctly refused by default, worded for a kid, and routed through the
  root helper when a kid is allowed to join on their own — confirmed without a wireless device, so
  a real join is still unverified (`docs/wifi.md`). The captive-portal helper is **not** shipped:
  it needed privileges a kid is denied outright, so it could never have worked for the one account
  that could reach it.

Everything else in this repository — including anything in "What will be here" below — is either
unfinished or unverified. If a control is not on this list, do not rely on it as a fence.

**Try it:** [`docs/install.md`](docs/install.md) — prerequisites, the one-command build, and the
honest list of what isn't ready yet.

The night the code landed is summarised in [`docs/loop-report.md`](docs/loop-report.md): what is
verified live, what is open, and which decisions are still waiting.

## What will be here

| Piece | What it does |
| --- | --- |
| Kids Mode app | Opens from the drawer. First run is the parent wizard; after that, a home screen with a settings gear into the panel |
| Parent wizard | Easy path (A-or-B chunks, preselected by age band) or Advanced (a table of toggles). Bash + gum in Omarchy's floating terminal, looks like the installer, Omy where the logo sits |
| Per-kid provisioning | Real account, no sudo, locked home, polkit denies, the installer path's privilege posture, a LUKS slot for the kid's password, a root-owned Hyprland config for the chosen level |
| Login portal | Face tiles then password, as an SDDM theme. Parent tile last |
| Exit modal | Super ×3: parent password, then **Finish** (closes the kid's apps and returns to the portal). **Pause** is not offered; its mechanism is undecided (`docs/phase1/DECISIONS-NEEDED.md`) |
| `omarchy-kids-*` | Feature commands: web policy, screen time, apps, Wi-Fi helper, ask-a-parent queue |
| Safety check | Green/red, at the end of setup and at every kid login, failing closed |

## What is here now

Thirty-three `bin/omarchy-kids*` commands, each with a `--help`; most have their own
`docs/<command>.md`, the rest documented alongside a related command's page instead. The shared
shell under `lib/`; the data, policies, Hyprland levels, and Quickshell surfaces under `share/`;
and `test/all`. [`AGENTS.md`](AGENTS.md)'s Layout table is the map.

## Rules

MIT, same as Omarchy. Never collects anything about a child; nothing leaves the machine except to a
device the parent paired or a server the parent named, and only while notifications are on (I-2).
A way for a kid to get around this is a bug: report privately per
[SECURITY.md](SECURITY.md). Everything
here must work from the keyboard alone. Not affiliated with DHH, 37signals, or the Omarchy project.
