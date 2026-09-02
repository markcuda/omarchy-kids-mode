# The installer path

Kids Mode chosen **at install**. The installer's first question becomes *Who is this computer
for? Me / Child / Another owner*; "Child" installs a child profile: one account, the kid's, with a
kid password and a parent password. This is DHH's direction, and it is being built upstream by
Pete (@peterholko). Updated 2026-09-02.

The other path is the [sandbox path](PATH-SANDBOX.md), for the shared family machine.

## Where it lives

| Piece | Where | Status |
| --- | --- | --- |
| Runtime side | [omacom/omarchy#9750](https://github.com/omacom/omarchy/pull/9750) — child profile, `sudo omarchy-parent`, parent password as root's, kid out of `wheel`, lock-screen parent unlock, masked consoles, Wi-Fi parent-by-default | Open, draft, smoke-tested by a community reviewer on 2026-09-02 |
| Installer side | [omacom/omarchy-iso#146](https://github.com/omacom/omarchy-iso/pull/146) — the first question, both passwords, parent LUKS slot, child package list | Open, depends on the runtime PR |
| Plan | `plans/kids-passwords.md` in the runtime PR: model, rejected alternatives, threat model, naming | Rev 2 |
| Kid home isolation | [markcuda/omarchy-kids-sandbox#1](https://github.com/markcuda/omarchy-kids-sandbox/pull/1) (HxHippy) — namespaced kid home on one uid, filtered system bus, safe Wi-Fi helper | Open on the sandbox spoke, not merged there; belongs to this path |

## The model, in one paragraph

Two passwords, one account. The kid password is the account password: login, lock screen, disk.
The parent password is root's password: `sudo` asks for it through `Defaults rootpw`, polkit
through an admin rule naming root, and it also unlocks the disk as a second key slot. The kid
account is outside `wheel` with an explicit grant that still asks for the parent password. A
`sudo omarchy-parent <feature>` command dispatches to `omarchy-parent-<feature>` files, so later
features plug in without editing it. Rejected there, deliberately: a separate parent login account,
and converting a Me install afterward. Both are exactly what the sandbox path is.

## Known gaps from the 2026-09-02 smoke test

- SDDM rejects the parent password; after a logout on an unencrypted install the parent has no way
  to a desktop (consoles are masked too).
- The lock-screen helper runs under `pam_exec` without `seteuid`; copied onto SDDM's root-run
  stack it would accept any password.
- The kid's failed-login counter sits ahead of the parent unlock: ten wrong kid tries lock the
  parent out for two minutes.
- Unencrypted first boot tries a LUKS mapping; the parent-password header goes stale on later
  screens; installer copy overclaims "a parent can always get in".
- The "hand Wi-Fi to the kid" grant lets a kid set per-connection DNS. The sandbox spoke's helper
  fixes this by forcing the joined network to ignore its DNS.

## What this hub sends there

- The ignore-DNS Wi-Fi helper (above).
- The child package list: our per-band starter packs from report 05 are the natural fill for
  `install/omarchy-child.packages`.
- Kid-test reports from parents in the channel, once ISO builds are shareable.

## How to help

Build the two branches into an ISO and run the smoke list above. Pick a gap and send a PR to
Pete's branch. Post results in the Discord channel and as a 🧒 kid-test report here.
