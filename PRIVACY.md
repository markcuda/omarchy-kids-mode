# Privacy

What Kids Mode records about a kid, where it lives, who can read it, and how long it stays.
SPEC.md R-DATA-1..5, I-2. This is the whole list — if something isn't named here, Kids Mode
doesn't record it.

## What's recorded

| What | Where | Kept |
| --- | --- | --- |
| Active minutes per day | `/var/lib/omarchy-kids/<account>/usage/<day>` | One year |
| App launches and "Ask a parent" requests | `/var/lib/omarchy-kids/<account>/launches.log` and `/var/lib/omarchy-kids/queue/` | Ninety days |
| Browsing history | The kid's own Chromium profile, same as any browser | Whatever Chromium itself keeps — Kids Mode adds nothing and locks it against being cleared (see "History" below) |

"Active minutes" means the kid's session was logged in, unlocked, and not paused — a root
service (`omarchy-kids-time-ledger`, `docs/time.md`) adds a minute once a minute under exactly
those conditions. It is a count, not a log of *what* the minute was spent on, beyond "an app
launched" going into the launches log above.

## What's never recorded

**Never, by anything Kids Mode ships:** keystrokes, screenshots, the contents of any file, the
contents of any message. There is no keylogger, no screen capture, no message reader anywhere in
this package. A kid's browsing history exists only because Chromium itself keeps one, the same as
it would for anyone using a browser — Kids Mode doesn't add a second, separate history of its own.

## Where it lives, and who can read it

Everything above lives under `/var/lib/omarchy-kids/`, owned by `root`, group-readable only by
the kid's own account (mode 0750 — `SPEC.md` §5.1). Nothing is written into anyone's home
directory, so it survives a kid deleting their own files and isn't something a kid's own account
enforces or could tamper with (I-3). The only people who can read it:

- **The parent**, through the panel (`omarchy-kids-time status`, `docs/panel.md`'s Home and Kid
  screens) — the same numbers the ledger recorded, nothing added.
- **The kid themselves**, on their own "What my grown-ups can see" screen at every login
  (R-DATA-3) — see "In kid words" below.
- **Nobody else**, with one optional exception the parent controls: parental notifications (below).
  Nothing here is uploaded, synced, or reachable over the network unless the parent turns that on.
  I-2 as amended: nothing about a child leaves the machine except to a device the parent paired or a
  server the parent named, and only when notifications are on.

## Parental notifications (optional, off by default)

When a parent turns notifications on, one local process (`omarchy-kids-relayd`) may listen on the
home network so the parent's own paired devices can receive a kid's "Ask a parent" requests and
answer them. It runs only while Kids Mode is in use, is fenced to the home network by its
root-owned unit, and decides nothing itself — root verifies every answer. If the parent also names
their own server (their own VPN, or a push server they run), one outbound process
(`omarchy-kids-relay-courier`) may send end-to-end encrypted messages there, readable only by a
device the parent paired. Nothing is ever sent to this project, its authors, or any push vendor; no
usage data, browsing history, or app launches ever leave the machine — only the request fields the
spec names. A platform push service may carry at most an empty wake-up signal, and only once the
parent enables it. With notifications off, no Kids Mode process opens a network connection
(`SPEC.md` I-2, R-NOTIFY; `docs/phase1/SPEC-AMENDMENT-notifications.md`).

## History, specifically

A parent can turn a kid's browsing-history visibility off per kid (`docs/conf.md`'s per-kid
settings). Off means the panel shows nothing for that kid, and that kid's own "What my grown-ups
can see" screen says so plainly — it is a real off switch, not a hidden one (R-DATA-4). Chromium's
own "clear browsing data" is locked out of the kid's policy (`AllowDeletingBrowserHistory: false`,
`docs/web.md`) either way, so a kid can't erase what's there before it's looked at, and a parent
can't be shown a history that's been quietly wiped.

## In kid words

This is the actual text of the screen a kid sees, every time they log in (K5, SPEC.md Appendix
A) — not a paraphrase of it:

> **What my grown-ups can see**
>
> - How many minutes you were on the computer today, and other days.
> - What apps you opened.
> - What you asked for ("Ask a parent") and what happened.
> - The websites you visited — *only if that's turned on for you. If it's off, this says so and
>   nobody sees it.*
>
> Nobody outside this computer ever sees any of this, except your grown-up on their own phone or
> computer if they've turned that on. Nobody reads what you type or takes pictures of your screen.

## If you think this is wrong

A way for Kids Mode to record more than this list, or to send anything off the machine, is a
security bug, not a feature request — report it privately per this repository's `SECURITY.md`
(<https://github.com/markcuda/omarchy-kids-mode/blob/main/SECURITY.md>), not in a public issue.
