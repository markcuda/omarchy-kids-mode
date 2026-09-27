# OmaKid

A shared, safe, & curated Omarchy experience for Kids.

How to use this file: every block below is one post, in order. Copy them one at a time. Each block
is under 280 characters (checked). Post as a reply chain.

---

1/27

I run Arch with Omarchy. My kids wanted to use my computer.

I didn't want a guest account bolted onto mine. My machine stays mine.

So I'm building OmaKid. A shared, safe, and curated Omarchy experience for kids. Here's what it will do.

---

2/27

One rule shapes all of it: the parent's account is never restricted.

Not by policy. Not by DNS. Not while a kid is paused. Your session, your home, your browser and your files stay yours.

---

3/27

One password. Yours.

Your kid never creates an account, never signs in to anything, never learns a second password. There is no cloud, no family plan, no dashboard on someone else's server. One machine.

---

4/27

Under the hood, each kid is a real Unix account.

kid-<name>, bash, no sudo, a home mounted noexec, its own private noexec /tmp. Not a profile inside your session. An account that Hyprland, SDDM and the kernel all understand.

---

5/27

Kids have no sudoers entry at all.

When something needs root, polkit asks, and the admin identity for kid accounts is you. It asks for your password. There is no prompt a kid can satisfy.

---

6/27

Each kid's password is also a disk key.

Every kid gets their own LUKS key slot, so their password opens the machine at boot. That makes "your password opens your computer" true for a seven year old. Remove the kid, remove the slot.

---

7/27

The youngest kids can have no password at all.

You unlock the disk that morning. They press Enter at their tile. Nothing to forget, nothing to lose.

---

8/27

Login is face tiles, then a password.

An SDDM theme, twelve animals, one per kid, picked during setup. Arrow keys move, Enter picks. Your tile sits last and smaller. It works with no mouse.

---

9/27

To hand the machine back, a kid presses Super three times.

An overlay opens with their name and a password field. Your password unlocks it, then Finish closes their apps and returns to the login screen.

---

10/27

On your desktop, Super+Shift+K opens the app.

That binding is one line, appended to your own config, shown to you word for word, and written only if you say yes.

---

11/27

Two kid desktops.

Grid is big tiles, fullscreen only, no terminal and no file manager. For the little ones.

Desktop is the real Omarchy desktop, menu trimmed. For the older ones.

Kids move up when they are ready.

---

12/27

Bands set the defaults: 3-5, 6-8, 9-12, 13+.

Each band carries a time budget, a bedtime, a web mode, a starter app pack, a Wi-Fi rule and a terminal rule. Every cell is overridable per kid.

---

13/27

Web stays Chromium, for everyone.

Kids policy files are root owned, mode 0640, readable only by that kid's group. Your browser loads none of it. Family DNS lives inside the kid's policy as a locked DNS-over-HTTPS template. Your machine DNS is never touched.

---

14/27

Three web modes: none, a walled garden, or filtered open web.

SafeSearch is forced, YouTube is restricted, incognito is off, dev tools are off, extensions are blocked. The kid's launcher refuses to open the browser if the policy file is unreadable.

---

15/27

Screen time is a root owned ledger.

It counts real active minutes. Locked and paused time does not count. Warnings at 10, 5 and 1 minute. At the limit it locks the session, then ends it 60 seconds later unless a parent grants more.

---

16/27

The countdown card is display only.

Closing it changes nothing, because the deadline lives outside the kid's reach in a root process. That is the whole point.

---

17/27

More time is asked for, not demanded.

One "Ask a parent" modal covers time, an app, a plugin and a site. Your password grants it on the spot. Otherwise it queues, and you approve it later from the panel.

---

18/27

Apps come as starter packs per band, installed natively from the repos and the AUR.

Setup prefetches them in the background so Apply does not sit there waiting. Tiles appear as installs land. A per kid allowlist decides what is there.

---

19/27

Two fences for you.

"Parents only" marks a binary unexecutable for the kids group, and re-asserts it after every update.

"Hide kids' apps from my launcher" writes overrides into your own menu entries, only when you ask.

---

20/27

Setup is a wizard with two speeds.

Easy shows one choice per screen, two options, one reason each, preselected by age. Advanced is a table of everything.

It looks like the Omarchy installer, runs on the keyboard, Esc goes back, and Ctrl+C leaves with nothing changed.

---

21/27

The panel manages each kid: time today and this week, top apps, browsing history, open requests, every setting, reset password, remove.

The machine page has safety status and Remove Kids Mode.

---

22/27

An optional bar widget sits in your bar and shows who is live and how many minutes are left.

Give more time, end a session, open the app. Every action behind it goes through your password.

---

23/27

Your kid can see what you can see.

A "What my grown-ups can see" screen lists exactly what is recorded for them: active minutes, app launches, requests, browsing history if you turned it on.

Never keystrokes, screenshots, file contents or messages.

---

24/27

Nothing about your child leaves the machine.

No telemetry, no accounts, no cloud. The one network listener is a relay, fenced to your home network and off unless you turn notifications on. Pair your phone and you can approve requests from it. Optional, and yours.

---

25/27

The locks stay on.

A snapshot runs before the first apply. Safety checks run at every kid login and fail closed. A pacman hook re-asserts every lock after updates. Remove Kids Mode keeps every kid's files. Omarchy's own files are never edited.

---

26/27

It is being built in the open, MIT, one repo. The honest list of what works and what does not is in the README, not in the marketing.

---

27/27

If you want your machine to say yes to your kid without giving up your own, follow along. I will post progress here.

---

## A few alt hooks, if you want a different opener

- My kids share my Arch machine now. Nobody is locked out except me, and I built it.
- There are two ways to give a kid a computer. One is to hand them yours. The other is OmaKid.
- I wanted my kids to have their own computer. I wanted mine back. OmaKid is both.

## Posting notes

- Put the repo link in post 27, or in a reply straight under post 1 so the first post stays clean.
- Any alt hook above drops into post 1 as is. Nothing else in the thread changes.
- Each numbered block is one post. The blank line inside a block is a line break, not a new post.
