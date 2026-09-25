# The parent guide: every setting, in plain words

This is the plain-language companion to `docs/conf.md` (the exact schema) and the band table.
Every setting a parent can change is listed here with what it does, and the default each age band
gives it. `test/shell.d/parent-guide-test.sh` checks that every schema key and every band appears
here, so this guide can't quietly fall behind the code.

## The two kid desktops

There are exactly two:

- **App grid** (`level = 1`) — a full-screen grid of big tiles, one app at a time. Best for
  children who can't read yet or who lose track of windows. `Super+Home` shows the grid.
- **Desktop** (`level = 3`) — the real Omarchy desktop, with its Install / Update / Setup menu rows
  hidden. Windows tile side by side and `Super+Space` finds apps, so a child learns the same keys a
  parent uses.

Ages **3-5** and **6-8** start on the grid; **9-12** and **13+** start on the desktop. You can
switch a child either way from the panel's Desktop screen.

**The one thing to know about Desktop:** the app allow-list, the hide/extra-app rows and the
"What my grown-ups can see" screen are the App grid's. A Desktop child starts apps from Omarchy's
own menu search, so those rows do not restrict them; keep a child on the App grid if you need the
allow-list enforced, the browser hidden (`web = none`), or the "What my grown-ups can see" screen.
Screen time, safe search/safe DNS and every lock are the same in both modes.

## The defaults each band starts with

| | 3-5 | 6-8 | 9-12 | 13+ |
| --- | --- | --- | --- | --- |
| Desktop | App grid | App grid | Desktop | Desktop |
| Web | none | walled garden | walled garden | filtered open web |
| Daily minutes (school / weekend) | 45 / 45 | 60 / 60 | 90 / 90 | 120 / 120 |
| Lights out (school / weekend) | 19:00 / 19:30 | 19:30 / 20:00 | 20:30 / 21:00 | 21:30 / 22:00 |
| Wi-Fi | ask me first | ask me first | join safely | join safely |
| Terminal | none | none | playground | sandboxed |
| Password | min 4, optional | min 4 | min 6 | min 6 |

Every value above is a **default**: change any of the per-child settings and that choice sticks,
even if you later move them to another band ("Reset to band defaults" clears your changes and shows
the new band's values again). Two things are **band-only** and can't be overridden per child: a
band's **Terminal** value and its password rule.

## Every setting

### Identity

- **Name** (`name`) — what you call this child here. It becomes their account name (`kid-...`).
  Required.
- **Face** (`avatar`) — the animal face on their launcher and the login screen. Required.
- **Age band** (`band`) — sets every default below. Choose `3-5`, `6-8`, `9-12` or `13+`. Required.

### Desktop

- **Desktop** (`level`) — **App grid** or **Desktop** (see above). Switching stores your choice and
  a child keeps it across a band change. `level = 2`, the old "Simplified desktop", is retired and
  is never offered; an old profile that names it still starts.
- **Theme** (`theme`) — the Omarchy theme their desktop uses. The list is every theme Omarchy has
  installed plus the kid theme collection this package ships (`share/themes-kids/`).

### Web

- **Web** (`web`) — `none` (no browser at all), `garden` (a walled garden: only the sites on their
  list load), or `filtered` (the open web, with safe search and adult content blocked).
- **Safe-search DNS** (`dns`) — the family-safe DNS resolver (`cloudflare-family`,
  `cleanbrowsing-family`, or a `custom:<url>`). **Stored now, not applied yet:** the browser policy
  always uses the Cloudflare Family resolver regardless of this value; `docs/web.md` says so.
- **Allowed sites** (`sites`) — extra sites the walled garden allows, beyond the band's starter
  list. **Stored now, not applied yet:** the browser policy's allow-list comes from the band's
  starter list plus the sites you approve, so editing this value changes nothing today;
  `docs/conf.md` says so.

### Screen time

- **Minutes a day (weekdays)** (`budget_min`) — how long their session may run on a school day.
- **Minutes a day (weekend)** (`budget_min_weekend`) — the same on a weekend day.
- **Lights out (weekdays)** (`lights_out`) — the time their session ends on a school night.
- **Lights out (weekend)** (`lights_out_weekend`) — the same on a weekend night.

### Wi-Fi

- **Wi-Fi** (`wifi`) — `parent` means they can't join a new network themselves; the request comes
  to you. `helper` means they can join school or café Wi-Fi safely, and the network can't change
  what's blocked.

### Data

- **History you can see** (`history_visible`) — whether their browsing history appears in the
  panel's Data screen.

### Apps

- **Menu** (`menu`) — `trimmed` hides the desktop menu's Install / Update / Setup rows; `full`
  shows everything. A child's menu is `trimmed` unless you change it.
- **Extra apps** (`apps.extra`) — apps to add to their launcher, beyond their band's starter pack.
- **Hidden apps** (`apps.hidden`) — apps to hide from their launcher.
- **Show not-yet-installed apps** (`apps.show_missing`) — whether an app that hasn't finished
  installing still shows (greyed out) on their launcher.
- **Allowed apps** (`allowlist`) — the app allow-list the launcher reads.

### Login

- **Password** (`password`) — whether the child account has a password and its minimum length. A
  younger child's password can be optional (they still have their own account), an older child's
  must be set.
- **Onboarded** (`onboarded`) — whether the child has been shown the first-run wizard. The package
  sets this itself; you don't change it.
