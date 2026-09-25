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
- **The kid themselves**, on their own "What my grown-ups can see" screen (R-DATA-3) — a launcher
  tile for bands 9-12 and 13+, run with a grown-up for younger kids (`docs/data.md`). Those two bands
  also get it on the Desktop mode, as a kid-owned app entry provisioning installs, so a 9-12 or 13+
  kid reaches it in either mode (`bin/omarchy-kids-provision`'s `install_kids_data_entry`). See "In
  kid words" below.
- **Nobody else, unless the parent turns notifications on.** Nothing here is uploaded, synced, or
  reachable over the network by default. I-2: nothing about a child leaves the machine except to a
  device the parent paired or a server the parent named, and only while notifications are on (see
  "Parental notifications" below) — no telemetry, no cloud account. With notifications off there is
  no network listener at all.

## History, specifically

A parent can turn a kid's browsing-history visibility off per kid (`docs/conf.md`'s per-kid
settings). Off means the panel shows nothing for that kid, and that kid's own "What my grown-ups
can see" screen says so plainly — it is a real off switch, not a hidden one (R-DATA-4). Chromium's
own "clear browsing data" is locked out of the kid's policy (`AllowDeletingBrowserHistory: false`,
`docs/web.md`) either way, so a kid can't erase what's there before it's looked at, and a parent
can't be shown a history that's been quietly wiped.

## Parental notifications

If a parent turns notifications on (`docs/notify.md`), Kids Mode may tell **the parent's own paired
devices** about a kid's requests and decisions (I-2 as amended). That is the only thing that leaves
the machine, and only then.

- The listener, `omarchy-kids-relayd`, is local and fenced to the home network (and to the CGNAT
  range only if the parent turns on away-from-home, `docs/notify.md`); it holds no decision power. A
  device may answer a request only if the parent
  paired it and root verifies its signature (`docs/devices.md`).
- What is sent is a kid's live state (whether they are logged in and paused, minutes left), their
  requests ("Ada asked for 15 more minutes"), and the outcomes — nothing else, and never a
  transcript, a keystroke or a screenshot.
- Nothing reaches the project, any vendor, or any third party. There is no telemetry and no account.
- **Not built on this branch:** the parent app (a phone or another computer). When it ships it will
  show a request when open (no background push on iOS in the first version). The desktop notifier on
  the parent's own computer **is** built and works today, and so is the box-side away courier
  (`docs/courier.md`): it talks only to the server the parent typed, and only while they turned it on.

Turning notifications off revokes every paired device and removes the certificate
(`omarchy-kids-notify disable`).

## In kid words

This is the screen behind the "What grown-ups see" tile (bands 9-12 and 13+; a grown-up can run it
with a younger kid), quoted from `bin/omarchy-kids-data`'s `mine` (K5, SPEC.md Appendix A):

> **What my grown-ups can see**
>
> Hi! Here's what this computer remembers about how you use it:
>
>   - How many minutes you use it each day. Kept for 1 year.
>   - Which apps you open from your launcher. Kept for 90 days.
>   - What you asked for ("Ask a parent") and what happened. Kept for 90 days.
>   - The websites you visit. Kept as long as the web browser itself keeps it. — *or, when it is
>     off for that kid:* Your grown-ups have turned OFF website history for you — they cannot see
>     which sites you visit.
>
> Nothing you type, no pictures of your screen, and nothing you write in a message is ever
> recorded. Only your grown-ups can see any of this. It stays on this computer — unless your
> grown-ups turn notifications on, and then only their own phone or computer, and only things like
> your minutes and your asks.

## If you think this is wrong

A way for Kids Mode to record more than this list, or to send anything off the machine, is a
security bug, not a feature request — report it privately per this repository's `SECURITY.md`
(<https://github.com/markcuda/omarchy-kids-mode/blob/main/SECURITY.md>), not in a public issue.
