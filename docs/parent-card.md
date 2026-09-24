# The parent card

One page. Print it (or save the PDF) and keep it somewhere you'll actually find it — a junk
drawer, taped inside a cabinet, wherever the house's other manuals live. The setup wizard is meant
to remind you to print this card whenever the firmware-password step is still outstanding; that
reminder isn't wired into the wizard yet (see the firmware section below), so for now this is on
you to remember, not something the app will nag about.

---

## The three things to know

**1. Getting the parent controls up.** Tap **Super three times, fast** (within about a second
and a half), or press **Super+Shift+K**. Either one opens the same box: your password, then
**Finish**, which closes the kid's apps and takes you back to the login screen. (**Pause** —
leaving their apps open — is not built yet: the box offers Finish only, so no Pause button is
shown at all, rather than one that does nothing. See "Not yet" below.)

**2. The login screen (the portal).** One tile per person in the house, yours last. Arrow keys
move the highlight, Enter picks a tile, then type that person's password (a kid with no password
gets in on Enter). If the machine is set to go straight in from the disk password — the default —
whoever's password unlocked the *disk* at power-on lands on their own desktop with no login screen
at all, once, right after the machine turns on; if it is set to show the portal every time, this
screen is what you see at every power-on. Every other time — after **Finish** ends someone's turn,
or if the disk password you typed didn't match anyone's — it's this one.

**3. Time's Up.** When a kid's screen time runs out, their screen shows an owl (or their own
avatar), their name and why they are out of time, a countdown, and one button: **Ask a grown-up for
more time**. Left alone for
60 seconds, it finishes on its own (no button needed for that). "Ask a grown-up" is the same
request queue as everything else a kid asks for — see "Four things you'll do most" below.

## The one password rule

Kids Mode never asks you for anything but **your own login password** — the one you already use
to unlock your account. It is never stored anywhere, never written to a file, never a second
password to remember. Every prompt checks what you type against your own account, live, every
time. If anything ever asks you for something else — a PIN, an email, a "Kids Mode account" — it
isn't Kids Mode.

## If the screen goes black

This is rare, and only follows a **Finish** that failed to close cleanly — a fallback inside
Kids Mode ends the session hard, which can crash the login screen instead of restarting it.
There's no console for a kid to reach on this machine (their consoles are switched off on
purpose), and there usually isn't one for you either, mid-crash. The honest fix, no keyboard
tricks required: **hold the power button until the machine turns off, then turn it back on.**
It's a hard shutdown, not a graceful one, but nothing is lost that a normal reboot wouldn't also
risk. If you happen to have another way onto the machine — SSH from your phone or another
computer, if you've set that up — `systemctl restart sddm` there is the gentler fix.

## Four things you'll do most, from the panel (`omarchy-kids`)

1. **Give a kid more time today.** Their row → Screen time → "Give more minutes today". Doesn't
   touch tomorrow's budget, just today's.
2. **Answer a request.** Home screen → Requests (shows the count). Enter on one shows what they
   asked for; Enter approves (Approve is preselected), arrow to Decline and Enter declines.
3. **Change what they can see or use.** Their row → Web (the allow list, if they're on one) or
   Apps (turn something on or off from their starter pack).
4. **Add another kid.** Home screen → "Add a kid" — the same wizard as the first one, one kid at
   a time.

**Desktop notifications.** With the Kids Mode bar widget on, `omarchy-kids-bar notify-enable` shows
each request on your own desktop with **Approve** and **Decline** (`docs/notify.md`). The panel's
**Notifications** screen turns the device side on or off, pairs a device, and lists or revokes the
paired ones. The phone app is in this repository (`clients/parent`) and does the same from the other
side: pair, approve or decline a request, approve or deny a changed add-on, give more time or end a
session, and read what was decided in the last day. **There is no installable build yet** — the
platform scaffolding and the store builds are not committed — so a pairing window is what you pair
*to* rather than *from* until that lands.

## What's not built yet

See `docs/install.md`'s "What isn't ready yet" for the full, current list — the short version:
**Pause** (switching back without closing a kid's apps), an **installable build of the phone app**
(the source is here; nothing to put on a phone yet), and the firmware/BIOS password (see below),
which Kids Mode can't set for you.

## The firmware password (this part is on you)

Kids Mode locks the operating system down; it can't touch what happens *before* the operating
system starts. A kid who knows your disk password and can get to the firmware/BIOS boot menu can
boot something else entirely and skip everything on this card. Set a firmware password the same
way you would on any computer (reboot, enter setup — usually a key held right at power-on, check
your machine's manual for which one — and look for "Set Supervisor/Admin/Firmware Password"). This
is the actual wall; everything else on this card is a fence for a curious kid, not a lock against
someone who's decided to get around it. Kids Mode tracks whether you've done this: once a kid
exists, the box's own check reports it as a FAILing row and the panel's Machine screen shows
**Safety: NOT READY — n check(s) failing** with the firmware step named, until it is marked done
(before the first kid, the check skips rather than fails). What is not built is the check-off
itself — nothing writes that mark yet — so for now, do it, and remember that you did, the same as
any other thing on this card outside Kids Mode's reach.

---

*Omarchy Kids Mode. Not affiliated with DHH, 37signals, or the Omarchy project. Something on this
card wrong, or a kid found a way around one of these? See `SECURITY.md` in this repository for how
to report it privately.*
