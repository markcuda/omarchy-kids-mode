# Apps: `omarchy-kids-apps`, the launcher allowlist, and the background install unit (SPEC.md R-APPS-2..6, Appendix C; I-1, I-6)

`bin/omarchy-kids-apps` is the one command that knows: what a band's starter pack contains and
whether it's installed, how to install the missing pieces without blocking the parent, a kid's
effective launcher allowlist (pack plus their own additions, minus their own hidden apps), and the
parent's opt-in switch for keeping kids' apps out of their own launcher.

## Commands

```text
omarchy-kids-apps list <band|kid> [--json]
omarchy-kids-apps install <band> [--now] [--apply]
omarchy-kids-apps install-queued
omarchy-kids-apps allowlist <kid>
omarchy-kids-apps hide <kid> <app>
omarchy-kids-apps show <kid> <app>
omarchy-kids-apps hide-from-mine [--apply]
omarchy-kids-apps show-in-mine [--apply]
```text

### `list <band|kid> [--json]`

Prints every app in a band's pack (`share/packs/<band>.toml`) with an `installed`/`missing` state
from `pacman -Q`. Given a kid account instead of a band, resolves that kid's band first
(`omarchy-kids-conf get <kid> band`) and lists the same thing — `list` is always about a *pack*,
never a kid's own allowlist (that's `allowlist`, below). An `aur:`-prefixed `pkg` is checked with
the prefix stripped (`pacman -Q` doesn't know about it), same as `install`.

`--json` prints a JSON array of `{id, label, pkg, state}` objects instead of the human table —
for a caller that needs to read the fields back (`lib/panel-kid.sh`'s Apps screen; review 2.6),
never for a column-offset `cut`. The human table is unchanged.

### `install <band> [--now]`

Finds the band's pack packages that `pacman -Q` says aren't installed yet, then resolves each one
against the sync db with `pacman -Si` before it goes anywhere near a real transaction (issue #52:
this is exactly what caught "target not found: tuxpaint" on a VM with fully synced mirrors — one
bad target used to sink the whole `pacman -S` transaction, so *nothing* in the pack installed).
Only targets `pacman -Si` confirms go on to be queued or installed; either way:

- **Default** — enqueues the resolvable ones (deduplicated, one per line) to
  `/var/lib/omarchy-kids/apps-queue`, then `systemctl start --no-block
  omarchy-kids-apps-install.service` (R-APPS-3: "the parent keeps going"). The unit's own
  `install-queued` is what actually runs pacman, in the background, whenever systemd gets to it.
- **`--now`** — runs `pacman -S --needed --noconfirm` for the resolvable ones directly, in the
  foreground, right away, as one transaction.

Either way, an `aur:`-prefixed package is named on stderr and skipped (not queued, not installed:
building AUR packages is R-APPS-1's own job, `omarchy-pkg-*`, not yet built), and any other package
`pacman -Si` can't find is also named on stderr and skipped — a mismarked pack entry or a mirror
that's missing a target no longer stops the rest of the band from installing. Nothing here ever
removes a package or reboots. Exits 0 as long as nothing that was actually attempted failed.

`DRY_RUN=1` by default (AGENTS.md rule 8): both modes only print what they would do (the `pacman
-Q`/`pacman -Si` resolution itself is a read, so it always runs, dry-run or not — same as `list`).
`--apply`, or `DRY_RUN=0`, makes either mode real.

### `install-queued`

The queue's own worker: reads `/var/lib/omarchy-kids/apps-queue`, resolves each entry against the
sync db the same way `install` does (`pacman -Si`, issue #52), installs whatever resolves and isn't
already installed in one `pacman -S --needed --noconfirm` transaction, names anything that doesn't
resolve on stderr, then empties the file. Meant to be run by
`systemd/omarchy-kids-apps-install.service`, never by a parent directly — see "Judgment calls"
below for why this one command always runs for real, unlike the rest of this file.

Idempotent: an empty queue, a queue where everything is already installed, or a queue where nothing
left resolves, is a no-op that still empties the file — an entry `pacman -Si` can't find would never
succeed on a later run either, so it is reported once and dropped rather than retried forever. If
`pacman -S` itself fails on the resolvable set (a real transaction failure, not a missing target),
the queue file is left untouched so the next run — another `install`, or a manual `install-queued`
— tries again; this is the "retry from the panel" R-APPS-3 mentions, not a timer (no timer is built
by this issue).

No launcher surface reads this queue yet (issue #42, docs/levels.md's "The launcher's tile list"):
with `apps.show_missing=yes` a missing app's kept tile always reads `"not installed yet"`, so
`"installing..."` versus `"not installed yet"` is not implemented. The queue remains this command
and `install-queued`'s alone.

### `allowlist <kid>`

Prints the kid's *effective* launcher allowlist, comma-separated, same format as the raw
`allowlist` profile key: the band's pack (or the kid's `allowlist` override, if they have one),
plus every id in their `apps.extra`, minus every id in their `apps.hidden` (docs/conf.md's two
extension keys). Order: pack/override ids first in their own order, then any `apps.extra` ids not
already present, in their own order; anything in `apps.hidden` is dropped from either list.

`lib/session-manifest.sh` calls this (through `omarchy-kids-apps allowlist`) to build the manifest's
`.allowlist` array, and `lib/launcher-map.sh` calls it too, to derive the root-owned map. A
`hide`/`show` therefore takes effect in the launcher after the next `omarchy-kids-assert` (which
rebuilds the map and manifest) and a session restart.

### `hide <kid> <app>` / `show <kid> <app>`

Add/remove one launcher id from the kid's `apps.hidden`, through `omarchy-kids-conf set`
(docs/conf.md: nothing else is supposed to touch a kid's `.conf` file directly). Both are
idempotent — hiding an already-hidden app, or showing an app that was never hidden, changes
nothing. `<app>` doesn't have to be a pack id: hiding an `apps.extra` id works the same way.

### `hide-from-mine` / `show-in-mine`

**Opt-in only (I-1: the parent's account is never restricted or altered except when they ask).**
Nothing else in this repo calls these two.

`hide-from-mine` collects the effective allowlist (see `allowlist` above) of every provisioned
kid, finds each id's `.desktop` file in the system application directories, and writes an override copy of it into
`$HOME/.local/share/applications/<name>.desktop` with `NoDisplay=true` set and a
`X-OmarchyKidsHideFromMine=true` marker line added — so those apps stop appearing in the *current
user's own* launcher/menu, without touching the system-wide `.desktop` file, the kid's own account,
or anything under `omarchy`/`omarchy-settings` (I-7). An id with no matching `.desktop` file found
is skipped with a note, never silently claimed as hidden (I-6).

`show-in-mine` removes exactly the override files carrying that marker — never a file the parent
created themselves some other way, even one that also happens to set `NoDisplay=true`.

Both are `DRY_RUN=1` by default; `--apply` or `DRY_RUN=0` makes them real.

## Package audit (issue #52)

Every `pkg` in `share/packs/*.toml` was checked against
`https://archlinux.org/packages/search/json/?name=<pkg>` (the same official-repo data `pacman -Si`
resolves against) on 2026-09-03. Each pack entry now carries a `source` field (`extra` or `aur`)
recording that result, so this table is a live cross-check, not just a point-in-time note. `extra`
is Arch's post-2023 merged repo (what used to be `community` is folded into it); nothing here needs
`core` or `multilib`.

| pkg | id | band | `source` |
| --- | --- | --- | --- |
| `gcompris-qt` | gcompris | 3-5 | extra |
| `aur:tuxpaint` | tuxpaint | 3-5 | aur — not in any official repo; a genuine gap, not a mirror issue (this is the pack entry issue #52 was filed over) |
| `ktuberling` | ktuberling | 3-5 | extra |
| `blinken` | blinken | 3-5 | extra |
| `supertux` | supertux | 6-8 | extra |
| `supertuxkart` | supertuxkart | 6-8 | extra |
| `klettres` | klettres | 6-8 | extra |
| `kanagram` | kanagram | 6-8 | extra |
| `aur:turbowarp-desktop-bin` | turbowarp | 9-12 | aur (already marked before this issue) |
| `luanti` | luanti | 9-12 | extra |
| `ktouch` | ktouch | 9-12 | extra |
| `aur:pixelorama` | pixelorama | 9-12 | aur (already marked before this issue) |
| `kiwix-desktop` | kiwix | 9-12 | extra |
| `aur:sonic-pi` | sonic-pi | 13+ | aur — no repo package plays the same "live-coding music synth for kids" role, so it stays `aur:` rather than being swapped |
| `pyzo` | pyzo | 13+ | extra — replaces `thonny` (AUR-only); `pyzo` is `extra`'s own interactive, beginner-oriented Python IDE, the same kind of app for this band's "coding" category |
| `kstars` | kstars | 13+ | extra |

Two calls worth spelling out:

- **`tuxpaint` and `sonic-pi` were left as their real apps, just `aur:`-prefixed**, rather than
  swapped for a repo alternative. Neither has a same-kind repo equivalent worth the trade — Tux
  Paint's whole value for band 3-5 is the toddler-specific UI (giant buttons, sound, stamps), which
  `kolourpaint`/`mtpaint`/`pinta` (general-purpose paint tools) don't replicate; Sonic Pi's role is
  "teach coding through live-coded music," which `lmms`/`musescore`/`rosegarden` (production/
  notation tools) don't replicate either. `aur:` is the honest label (R-APPS-1 already skips and
  names these on `install`'s stderr).
- **`thonny` was swapped for `pyzo`**, unlike the two above, because `extra/pyzo` genuinely is the
  same kind of thing `thonny` was standing in for — an interactive, beginner-friendly Python IDE —
  and is in the official repos today, so a band-13+ kid gets a working starter pack instead of one
  more `aur:` skip.

## Root-owned launcher map (finding 2)

Provisioning and `omarchy-kids-assert` write `/etc/omarchy-kids/launchers/<account>.json` as
root-owned, mode 0644. It is derived from the band pack and the effective allowlist after hidden
and extra entries are applied. Each tile has display metadata plus an `argv` array. Desktop-entry
`Exec=` lines are parsed during this root-side write, field codes are removed, and the executable
is resolved to an absolute path. Pack fallbacks are also resolved to absolute paths at that time.

The launcher does not read a runtime launcher JSON: the manifest refactor (`38f878e`) made the
validated session manifest the single session input. `share/launcher/shell.qml` runs
`omarchy-kids-session --manifest` and executes each tile's fixed `argv`; `lib/session-manifest.sh`
renders that manifest from the same launcher-map rendering (it re-runs `launcher_map_render`, not
reading the on-disk map file). The Web and More apps tiles are fixed absolute argv entries, so no
tile invokes a shell string. Re-run `omarchy-kids-assert` after changing installed apps or the
effective allowlist.

## No runtime `$RUN/allowlist.json` any more (R-DESK-4, issue #24)

`bin/omarchy-kids-session-start` writes neither a runtime
`$XDG_RUNTIME_DIR/omarchy-kids/allowlist.json` nor a `launcher-<uid>.json`: the manifest refactor
made the validated session manifest the single session input, and `session-start-test.sh` and
`levels-test.sh` assert that neither file is created. The kid's effective allowlist lives in the
manifest's `.allowlist` array — the same value `omarchy-kids-apps allowlist <kid>` prints. Feeding
that list into Omarchy's own app grid/menu, as a future trimmed-menu extension at Levels 2/3, is
still unbuilt: `share/menu/omarchy-kids-trimmed.jsonc` is a different mechanism (it hides the
Install/Update/Setup rows, R-DESK-4's other half), and this repo has no confirmed way to feed an app
allowlist into Omarchy's menu yet.

## Env (every path overridable — nothing here ever runs as root in dev, per AGENTS.md rule 8)

| Var | Default | Affects |
| --- | --- | --- |
| `OMARCHY_KIDS_ETC` | `/etc/omarchy-kids` | kid profiles (via `omarchy-kids-conf`) |
| `OMARCHY_KIDS_SHARE` | `/usr/share/omarchy-kids` | `packs/<band>.toml` |
| `OMARCHY_KIDS_ROOT` | (empty — the real paths) | scratch prefix for `/var/lib/omarchy-kids` (the install queue) — same convention `bin/omarchy-kids-assert` and `lib/posture.sh` use for system paths this package doesn't own |
| `OMARCHY_KIDS_HOME` | `$HOME` | `hide-from-mine`/`show-in-mine`'s target home — always the account running the command, never a kid's |
| `OMARCHY_KIDS_APPLICATIONS_DIRS` | `/usr/share/applications:/usr/local/share/applications` | `hide-from-mine`'s `.desktop` search |
| `DRY_RUN` | `1` | `install` and `hide-from-mine`/`show-in-mine`; see "Judgment calls" |

`test/shell.d/apps-test.sh` runs entirely against a scratch `OMARCHY_KIDS_ETC`/`OMARCHY_KIDS_SHARE`/
`OMARCHY_KIDS_ROOT`/`OMARCHY_KIDS_HOME`, with stub `pacman` and `systemctl` on a stub `PATH` — see
that file's header comment for exactly how.

## Judgment calls made in this implementation

- **Resolution uses `pacman -Si` per package, not one `pacman -Sp` dry-run.** The issue names both
  as options. A per-package `-Si` call is O(n) processes instead of one O(1) call, but it means one
  unresolved target never has to be diffed back out of a combined `-Sp` transaction's output/exit
  code, and the per-package result is exactly what already drives the `aur:`/missing branches right
  next to it — same shape, one clear reason each package was skipped.
- **An unresolved (non-`aur:`) package is reported and dropped, not retried forever.** Same
  reasoning as an `aur:` package: something `pacman -Si` can't find today won't resolve on the next
  run either without a data or mirror change, so `install-queued` empties it out of the queue along
  with everything it did install, rather than leaving a permanently-stuck entry that reruns forever
  with the same stderr line. A real transaction failure (`pacman -S` itself failing on the
  resolvable set) is the one case still left for a retry — see the next bullet.
- **`install-queued` always runs for real, no `DRY_RUN` gate**, unlike every other write in this
  file. Same reasoning `docs/assert.md` gives for `omarchy-kids-assert`: it exists precisely so its
  one caller (`systemd/omarchy-kids-apps-install.service`, started with no other flags) never needs
  `--apply` to do its job. `install` (the command a parent actually runs) still defaults to
  `DRY_RUN=1` — the preview happens there, before anything is queued.
- **`hide`/`show` have no `DRY_RUN` gate**, unlike `install`. Same reasoning
  `bin/omarchy-kids-session-start`'s own `docs/session.md` gives for `--install-configs`, and the
  same one `omarchy-kids-conf set`/`reset` already live by: these are small, reversible,
  already-idempotent edits to one profile key, the same risk class as any other `omarchy-kids-conf
  set` — adding a dry-run flag here would be inconsistent with the tool they're a thin wrapper
  around, which has never had one.
- **`NoDisplay=true`, not `Hidden=true`.** SPEC.md's R-APPS-5 text says `Hidden=true`; this uses
  `NoDisplay=true` instead. In the freedesktop Desktop Entry / menu specs these mean different
  things: `Hidden=true` says "this id no longer exists, ignore it even for file-type/URL-scheme
  association", while `NoDisplay=true` says "don't list this in a menu, everything else about it is
  still valid" — which is what "keep it out of my launcher" actually means here (the app still
  needs to work if the parent runs it some other way, and still needs to resolve correctly for a
  kid's own, separate account). `NoDisplay=true` is also what desktop environments' own
  "remove from menu" features conventionally write. Worth a one-line comment on the issue per
  AGENTS.md's "if a ticket/spec disagree, the spec wins and the ticket gets a comment" rule, since
  this is the spec's own wording, not a ticket's.
- **`hide-from-mine` always covers every provisioned kid, no kid filter.** The issue's own wording
  ("writes those overrides for the current user") doesn't ask for one, and a filtered `show-in-mine`
  would need to re-resolve an allowlist that may have changed since the matching `hide-from-mine`
  ran, right when a parent is trying to clean up — matching everything the marker identifies is
  simpler and can't miss a stale override.
- **`list`/`allowlist` never touch `apps.extra`/`apps.hidden` for a band-only `list`.** `list
  <band>` is deliberately about the pack alone; a kid's own hides/extras only show up through
  `allowlist <kid>` or `list <kid>` (which resolves to the same band-level pack view — a kid's
  `apps.hidden` doesn't change what `list` reports as installed/missing, only what
  `allowlist`/the launcher shows).
- **AUR packages are named on `install`'s stderr, not silently dropped.** A parent running `--now`
  or watching the journal from the queue should be able to tell "this pack has N apps I can't
  install yet" from "everything installed cleanly" (I-6).

## Verify in the VM

Live status (2026-09-21, try-omarchy VM): the install path has now run against a real `pacman` —
`omarchy-kids-apps install 6-8 --now --apply` installed the band's packages (GCompris among them)
and skipped the AUR one with the documented R-APPS-1 notice. Still open below: the
`.local/share/applications` menu checks and the list/queue assertions:

1. `omarchy-kids-apps list 6-8` on a fresh box: confirm every pack app shows `missing`.
2. `omarchy-kids-apps install 6-8` (default, no `--apply`): confirm it only prints the plan and
   queues nothing. Then `--apply`: confirm `/var/lib/omarchy-kids/apps-queue` has the missing
   package names and `systemctl status omarchy-kids-apps-install.service` shows it ran (or is
   running) `install-queued`; `journalctl -u omarchy-kids-apps-install.service` shows the pacman
   output.
3. `omarchy-kids-apps list 6-8` again: confirm the newly-installed apps now show `installed`.
4. The issue #52 regression: on a box with a deliberately stale/partial mirror (or with one pack
   `pkg` temporarily renamed to something bogus), run `omarchy-kids-apps install <band> --apply
   --now`; confirm every *other* resolvable app in that band still installs, the bogus one is named
   on stderr, and the command exits 0.
5. Provision a kid, `omarchy-kids-apps hide kid-ada supertux`, then start (or restart) that kid's
   session and confirm the Level 1 launcher no longer has a SuperTux tile; `show` and confirm it
   reappears.
6. `omarchy-kids-apps hide-from-mine --apply` as the parent: confirm the parent's own app
   grid/menu no longer lists the kids' apps, and that a kid can still open them from their own
   session. `show-in-mine --apply`: confirm they're back in the parent's menu, unchanged from
   before.

## Verified live (2026-09-03, QEMU test VM)

With synced mirrors, `omarchy-kids-apps install 6-8 --now --apply` resolved the pack, skipped
the AUR-only Tux Paint with a line, and installed the other seven in one transaction in about
ninety seconds; `list` showed them installed and the launcher drew nine real tiles at the next
login.

## Source header (moved from `bin/omarchy-kids-apps`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-apps — starter-pack installs, the per-kid launcher
allowlist, and the parent's own opt-in "hide kids' apps from my
launcher" switch (SPEC.md R-APPS-2..6, Appendix C; I-1, I-6).

  list <band|kid>          Every app in a band's pack (or, given a kid
                            account, that kid's band) with its
                            installed/missing state (`pacman -Q`).
  install <band> [--now]   Missing packages for a band's pack, resolved
                            against the sync db first (`pacman -Si`,
                            issue #52) so one bad/missing target never
                            sinks the whole transaction. By default,
                            enqueues the resolvable ones to
                            /var/lib/omarchy-kids/apps-queue and starts
                            omarchy-kids-apps-install.service in the
                            background (`systemctl start --no-block`),
                            so the parent keeps going (R-APPS-3).
                            --now runs `pacman -S --needed --noconfirm`
                            for them directly, right away. AUR packages
                            (pkg = "aur:...") and any target `pacman -Si`
                            can't find are named on stderr and skipped
                            either way -- building AUR is R-APPS-1's own
                            job, not built here. Exits 0 as long as
                            nothing that *was* attempted failed.
                            DRY_RUN=1 by default (AGENTS.md rule 8);
                            --apply or DRY_RUN=0 makes either mode real.
  install-queued           The queue's worker: resolves everything still
                            in the queue file against the sync db
                            (`pacman -Si`, issue #52), installs whatever
                            resolves and isn't already installed in one
                            transaction, reports anything that doesn't
                            resolve, then empties the file. Always runs
                            for real -- see "Judgment calls" in
                            docs/apps.md. Meant to be called by
                            systemd/omarchy-kids-apps-install.service,
                            not by a parent directly.
  allowlist <kid>          The kid's effective launcher allowlist:
                            their band's pack (`allowlist`, Appendix B),
                            plus `apps.extra`, minus `apps.hidden` (two
                            profile keys this adds beyond Appendix B --
                            docs/conf.md). Comma-separated ids, same
                            format as the `allowlist` key itself.
  hide <kid> <app>         Adds <app> to the kid's `apps.hidden`.
  show <kid> <app>         Removes <app> from the kid's `apps.hidden`.
  hide-from-mine [--apply] Opt-in only (I-1): writes NoDisplay=true
                            overrides for every provisioned kid's
                            allowlisted apps into the *current user's
                            own* ~/.local/share/applications/, so those
                            apps stop showing in the parent's own
                            launcher. Never touches a kid's account or
                            any file owned by `omarchy`/`omarchy-settings`
                            (I-7). DRY_RUN=1 by default.
  show-in-mine [--apply]   Removes exactly the override files
                            hide-from-mine wrote (marked internally with
                            X-OmarchyKidsHideFromMine=true), never a
                            file the parent created some other way.

Every path is overridable for tests, same convention as
omarchy-kids-conf and bin/omarchy-kids-assert:
  OMARCHY_KIDS_ETC     kid overrides root (default /etc/omarchy-kids)
  OMARCHY_KIDS_SHARE   bands.toml, packs/ (default /usr/share/omarchy-kids)
  OMARCHY_KIDS_ROOT    scratch prefix for /var/lib/omarchy-kids (the
                       install queue), same convention
                       bin/omarchy-kids-assert and lib/posture.sh use
                       for system paths this package doesn't own
  OMARCHY_KIDS_HOME    hide-from-mine/show-in-mine's target home
                       (default: $HOME) -- always the account running
                       this command, never a kid's home
  OMARCHY_KIDS_APPLICATIONS_DIRS  colon-separated .desktop search dirs
                       for hide-from-mine (default
                       /usr/share/applications:/usr/local/share/applications)
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
