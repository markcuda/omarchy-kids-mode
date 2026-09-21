# GCompris first run, and its own settings/quit controls (proposal)

Status: proposal, owner decision needed before any code. Source: the 2026-09-21 live Level 1 review
(`docs/dogfood-2026-09-21.md`, findings 5-6) and a read-only look at the running VM afterwards.

## What the live pass saw

- The first time a kid launches GCompris it shows a **welcome dialog** (a paragraph about
  application settings and the language, dismissed by a small red X) before any activity.
- GCompris's own bottom bar exposes a **wrench** (its configuration) and a **power/quit** control
  to the kid. Quit exits the app (back to the launcher); the config screen is the app's own.
- Both are the app's affordances. Nothing in Kids Mode fences them: a tile launch is a plain
  `argv` (R-APPS-4, R-DESK-5), and the launcher only controls what starts, not what the app draws.

## What the app actually writes (observed, same VM)

`~/.config/gcompris/gcompris-qt.conf` (Qt `QSettings` INI), created on first run. Keys seen:

```
[Admin]    cachePath, downloadServerUrl, renderer, userDataPath
[%General] audioEffectsVolume, backgroundMusicVolume, baseFontSize, defaultCursor,
           enableAudioVoices, enableAutomaticDownloads, enableBackgroundMusic,
           exitConfirmation=false, filterLevelMin/Max, font, fullscreen=true,
           homeButtonVisible=true, kiosk=false, locale=system, noCursor=false,
           previousHeight/Width, sectionVisible, virtualKeyboard=false
[Internal] exeCount=4, lastGCVersionRan=260100
[Teacher]  teacherId, teacherPort
```

- `fullscreen=true` is already the default; `kiosk=false` is the interesting one: GCompris
  documents a kiosk mode that hides its own exit/settings affordances.
- No explicit "first run shown" key is visible; the welcome dialog appears tied to the first
  launch (the `[Internal]` section above only materialised after our runs). **Unconfirmed** which
  exact condition suppresses it.

## Options

1. **Pre-seed the config at provisioning (recommended).** `omarchy-kids-provision` (root) writes a
   minimal `~/.config/gcompris/gcompris-qt.conf` into the kid's home before their first login:
   `fullscreen=true`, `exitConfirmation=false`, a fixed `locale`, and `kiosk=true` if a live test
   confirms kiosk mode hides the wrench/quit. For the welcome dialog, seed the confirmed
   first-run key once we have run the one live test below.
   - Honest framing: this is convenience configuration in the kid's home, **not a lock** (I-3).
     The kid's account can still edit it; the tile and the session are what the product enforces.
   - It fits the provisioning step we already own and adds no daemon.
2. **Accept and label.** Leave the app as-is; state in the kid-app docs that GCompris's own
   settings/quit are app-owned, and that quitting returns to the launcher (observed live).
3. **Wrapper.** A small launcher-side wrapper that writes the config before exec. More moving
   parts than a provisioning seed for the same result; only worth it if the seed cannot work.

## What to verify before implementing (one VM run)

1. Seed `kiosk=true` in a copy of the config, launch GCompris, and confirm the wrench/quit are
   gone (and that the kid can still leave via Super+Q / the exit modal, both of which are ours).
2. Find what suppresses the welcome dialog: try a config that includes `[Internal]` (e.g.
   `exeCount=1`, `lastGCVersionRan=<current>`) versus no config at all, and record which state is
   enough. If nothing in the config suppresses it, option 2 is the honest answer for the dialog.
3. Confirm the English (`locale` / band-appropriate) values for our bands before seeding.

## Owner decision

- Do we add a **provisioning step that writes per-kid app configs** (GCompris first) into the new
  kid's home? It is convenience, never enforcement, and it is per-app work each time.
- If yes: `kiosk=true` is a fence in the app, not ours, and must be labelled that way anywhere we
  describe it (I-6).
