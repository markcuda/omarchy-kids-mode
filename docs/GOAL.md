# The goal

Ship the Kids Mode that makes parents and kids in the Omarchy community say "that's it" — the
one DHH, Jason Fried, Ryan Hughes and NetworkChuck are waiting for. Fast, smooth, secure,
expandable, easy to configure, easy to contribute to. This file is the standing order the
autonomous loop works from; `docs/loop-report.md` is the running account.

## Definition of done (release)

1. **Every spec in `docs/specs/` is landed** (six specs, tickets #64–#87), each ticket gated the
   same way: Mac suite green, VM suite green (scenario 05, with the style gate), the live scenario
   the spec names green, and a screenshot for anything visible.
2. **The live harness is green in one run** (`test/live/all -k`, all scenarios) on the release
   candidate, twice in a row, with the kid's budget headroom rules the harness already carries.
3. **Dogfooded with pictures and video.** For every surface (portal, launcher, exit modal, Ask,
   Time's Up, Wi-Fi picker, plugins shelf, wizard, panel, bar module) a screenshot under a dark
   and a light Omarchy theme lives in `docs/media/`, and a short video of each of the three
   walkthroughs (parent sets up a kid; kid logs in, plays, asks for time, gets Time's Up; parent
   approves and removes) is recorded from the VM (QMP frames stitched with ffmpeg) and delivered
   to Mark. Anything that looks wrong in a picture is a ticket before it is a release.
4. **Security reviewed three times and every finding closed or documented**: the two
   antagonistic rounds, the maintainer's eye, and Codex's review. The trust-boundary test stays
   the gate for new code.
5. **A parent can install it in ten minutes from `docs/install.md`** on a stock Omarchy 4.0.2
   box, never restricted themselves, with one password (their own), and remove it cleanly.
6. **It is installed on the Air itself and dogfooded on real hardware**: the portal path (greeter
   tile, password, launcher, exit modal, Finish, Pause, screen time) under the owner's theme, with
   the owner never restricted and a clean removal proven. The AUR upload and the upstream PR are not
   part of done (Mark, 2026-09-04); the cold-boot-kid path stays VM-proven.
7. **The community findings are folded in or decided**: #88 (signed ask requests), #89
   (hardened root helpers), #90 (the ADR on per-kid accounts), #91 (show_missing).
8. **The docs tell the truth**: README, parent card, install, every `docs/<command>.md` checked
   against the code ("label claims" rule), CHANGELOG current, the loop report up to date.

## How the loop works from here

- gpt-5.6-sol writes specs; tickets are filed from them; gpt-5.6-luna drafts every ticket in its
  own clone; Claude briefs, gates, merges, and does the dogfooding. Claude writes code only for
  hotfixes that keep main working.
- Never merge a consumer before its producer is wired on a provisioned box. A live scenario
  asserts behaviour (a running launcher), not that a session exists.
- Root-side builders never replace state on failure; root paths are exercised with an empty
  environment; anything root-only is verified on the VM, not the Mac.
- The VM is the truth for boot paths; the Air host is the truth for real hardware. The Air is
  never rebooted and never left without a way in. Test users only. Only the public repo goes to
  Codex; Discord text stays on the Mac.

## Order of work

Spec 02 (root screen time) → spec 03 (config schema) → spec 04 (one kid shell) → #88/#89 →
spec 05 (locks table) → spec 06 (screen spec) → #90/#91 → release candidate, harness twice,
pictures and videos, docs pass, tag.
