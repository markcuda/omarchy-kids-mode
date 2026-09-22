# Kids-plugins shelf: `omarchy-kids-plugins`, the panel screen, and the "More apps" tile (SPEC.md R-APPS-7, I-3, I-6; issue #28)

`bin/omarchy-kids-plugins` reads a marketplace index filtered to category **Kids**, **verified**
listings only, and can install one into a kid's own account (through Omarchy's own plugin
installer) or remove one again. Nothing here is a lock: "no plugin may enforce anything" is
R-APPS-7's own wording, and Appendix G already covers the reverse ("Kid deletes a launcher
plugin -> Cosmetic — plugins are never locks").

## What "the marketplace catalog" actually is (facts checked against Omarchy 4.0.2 and its

## community marketplace — read this before changing the index schema below)

Omarchy 4.0.2's own shell-plugin commands (`bin/omarchy-plugin-list`, `-add`, `-remove`,
`-enable`, `-disable`, `-clone`, `-validate`, `-catalog`; confirmed by reading
[omacom/omarchy](https://github.com/omacom/omarchy)'s `bin/` directory at the `quattro` tag) only
know about plugins already **installed** on this machine, under `$OMARCHY_PATH/shell/plugins` and
`~/.config/omarchy/plugins`. `omarchy-plugin-list --json`'s own fields are `id`, `enabled`,
`firstParty`, `kinds`, `name` — no `category`, no verification status of any kind.
**There is no Omarchy-shipped command that browses the online marketplace.** That data lives in a
separate community project, [omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace)
(the site behind `omarchyplugins.com`), whose `site/catalog.json` is what actually has the fields
this issue needs: `id`, `name`, `description`, `category` (one of `Appearance`, `Desktop`,
`Developer Tools`, `Hardware`, `Kids`, `Productivity`, `System`, `Widgets`, `Other` —
`SUBMISSION.md`'s own exact spelling, case-sensitive), `verificationStatus` (`"verified"` or
`"unverified"`, confirmed by inspecting live entries), `installAvailable`, `installCommand`
(shaped like `omarchy plugin add https://github.com/<owner>/<repo>.git --enable`), and `repo`.
**UNVERIFIED:** at the time this was written, `category == "Kids"` had zero live listings in that
catalog — the category exists (it's a real choice on the submission form) but nothing has been
published under it yet, so no real Kids-category entry's exact field shape was checked; the fixture
in `test/shell.d/plugins-test.sh` is built from the *general* schema other categories' entries
really have, not a real Kids one.

`bin/omarchy-kids-plugins` therefore reads a **local, already-fetched copy** of that catalog
(`shelf`'s own `$OMARCHY_KIDS_PLUGIN_INDEX`, shaped like `site/catalog.json`: `{"plugins": [...]}`),
never the network itself. **Nothing in this issue fetches or refreshes that file** — see "Judgment
calls" below for exactly what that leaves undone.

"Omarchy's own plugin installer" (the phrase this issue's brief used) is `bin/omarchy-plugin-add`
(confirmed, same repo/tag): `omarchy-plugin-add <git-url> --enable --yes` clones the repo into
`$HOME/.config/omarchy/plugins/<manifest-id>` and enables it — `$HOME`, not a system-wide
location, which is exactly why `install` below runs it as the kid, not as root directly.
`omarchy-plugin-remove <id> --yes` is the reverse, same `$HOME`.

## Commands

```text
omarchy-kids-plugins shelf [--band BAND] [--all] [--json]
omarchy-kids-plugins install <plugin> --kid <kid> [--apply]
omarchy-kids-plugins remove <plugin> --kid <kid> [--apply]
```text

### `shelf [--band BAND] [--all] [--json]`

Lists index entries where `category == "Kids"` and `installAvailable == true`, and — by
default — `verificationStatus == "verified"`. Prints a table: `ID`, `NAME`, `AGE`, `VERIFIED`,
`DESCRIPTION`.

- **`--band BAND`** keeps only entries whose `age` field (reusing Appendix C's own "band floor"
  concept — see "Judgment calls") is at or below `BAND`. An entry with **no** `age` field is never
  filtered out by this flag: an unknown floor isn't the same claim as "too old for this band"
  (I-6).
- **`--all`** also lists unverified Kids-category listings, with a warning line first. This is
  parent-only **by convention**, not by any runtime identity check — see "Judgment calls" for why
  that's the right call here. Neither `--band` nor `--all` changes what `install` will accept:
  `install` always refuses anything not verified, regardless of how it was listed.
- **`--json`** prints the same, band-filtered set as a JSON array of `{id, name, description, age,
  verified}` instead of a table (and suppresses the `--all` warning line, which has no place in a
  machine-readable stream). This is what `share/plugins/shell.qml` — the kid-side "More apps"
  overlay — reads.

A missing or unreadable index prints a one-line "nothing on the shelf yet" message and exits 0,
never an error (R-APPS-8's own "offline" framing: not-synced-yet is not a failure).

### `install <plugin> --kid <kid> --apply`

Root. Refuses unless `<plugin>` is on the index as `category == "Kids"`, `installAvailable ==
true`, and `verificationStatus == "verified"` — the same rule `shelf` applies by default, checked
again here so nothing can install by a shelf-bypassing say-so (R-APPS-7 cuts both ways). Then:

1. `runuser -l <kid> -c "omarchy-plugin-add <repo>.git --enable --yes"` — installs into the kid's
   *own* `$HOME/.config/omarchy/plugins`, never root's.
2. Adds `<plugin>`'s id to that kid's `apps.extra` (`omarchy-kids-conf set <kid> apps.extra ...`,
   the exact profile key `omarchy-kids-apps allowlist` already composes over — R-APPS-4), so it
   shows up the same way any other allowed app does.

Refuses (before either step) if `<kid>` isn't a provisioned kid (`$OMARCHY_KIDS_ETC/kids/<kid>.conf`
doesn't exist). `DRY_RUN=1` by default (AGENTS.md rule 8); `--apply` or `DRY_RUN=0` makes it real.

### `remove <plugin> --kid <kid> --apply`

Root. The reverse: `runuser -l <kid> -c "omarchy-plugin-remove <plugin> --yes"`, then drops the id
from that kid's `apps.extra` — never `apps.hidden`: a removed plugin isn't hidden, it's gone.

## The panel: Apps → Plugins shelf

`bin/omarchy-kids-panel`'s existing "Apps" screen (`screen_kid_apps`) gained one more row,
**"Plugins shelf"**, above "Back". Choosing it opens `screen_kid_plugins`, which lists that kid's
band-filtered shelf (`omarchy-kids-plugins shelf --band <kid's band>`) the same way the Apps screen
already parses `omarchy-kids-apps list`'s table (fixed columns; the first line is the header).
Enter installs the selected plugin for that kid through the panel's own `run_priv` (the same
warm-once-`sudo` path every other panel write uses) — `omarchy-kids-plugins install <id> --kid
<account> --apply`. The panel never passes `--all`: nothing a parent can press Enter on in this
screen should be anything but installable (I-6).

## The kid side: the "More apps" tile

`bin/omarchy-kids-session-start` adds one more Level 1 launcher tile, `more-apps` / "More apps",
for every band **except 3-5** (bands 6-8, 9-12, 13+ get it) — 3-5 gets no tile at all, not a shelf
that would always come up empty. Its `exec` runs
`OMARCHY_KIDS_BAND=<band> quickshell -p $OMARCHY_KIDS_SHARE/plugins/shell.qml` — the only thing the
overlay needs from its caller, since the overlay is read-only and needs no password step (unlike
`share/ask/shell.qml`).

`share/plugins/shell.qml` runs `omarchy-kids-plugins shelf --json --band <band>` once at startup,
shows the result as a keyboard-navigable list (Up/Down/Enter, Esc closes with no side effect —
I-5), and Enter on an item runs `omarchy-kids-ask app <plugin-id>` (`Quickshell.execDetached`,
the existing "Ask a grown-up" flow) then closes itself, handing off to that modal rather than
layering two overlays. Verified live on the try-omarchy VM 2026-09-21, from the repo's own file: the
overlay loads under a real Quickshell (`Configuration Loaded`, no error) and, with an empty catalog,
renders the honest empty state ("Nothing here yet — check back later!") and closes on Esc with no
side effect. That run also confirms the stdout capture: the empty state only renders once
`handleShelf` has run, so `Quickshell.Io.Process`'s `stdout: StdioCollector { onStreamFinished }` /
`.text` did deliver and parse the command's output (nothing else in this repo captures a Process's
whole stdout). Still unconfirmed in the overlay: a **non-empty** shelf (rendering the list and
Up/Down/Enter) and the Enter→`omarchy-kids-ask app` handoff. `omarchy-kids-plugins shelf`'s own
non-empty output was
exercised on the VM with a hand-written fixture index (the marketplace index was empty), and that
exposed a field-shift bug when an entry had no `age` — `bin/omarchy-kids-plugins` parsed its rows
with a tab `IFS`, which bash `read` collapses, so `age` picked up the status and `verified` went
false; fixed there by using a non-whitespace field separator. The overlay was not then run against
that non-empty shelf. The layer-shell/keyboard-focus shape it reuses line for line is
`share/exit-modal/shell.qml`'s live-verified one (`docs/exit.md`'s "Verified live" section,
2026-09-02): `PanelWindow` + `WlrLayershell.layer: WlrLayer.Overlay` +
`WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`, every action via
`Quickshell.execDetached` before quitting.

## Env

| Var | Default | Affects |
| --- | --- | --- |
| `OMARCHY_KIDS_ETC` | `/etc/omarchy-kids` | kid profiles (`install`/`remove`'s provisioned-kid check, `apps.extra`) |
| `OMARCHY_KIDS_ROOT` | (empty — the real paths) | scratch prefix for `/var/lib/omarchy-kids`, same convention as `omarchy-kids-ask`/`-apps` |
| `OMARCHY_KIDS_PLUGIN_INDEX` | `$OMARCHY_KIDS_ROOT/var/lib/omarchy-kids/plugin-marketplace/index.json` | the marketplace index `shelf`/`install`/`remove` read |
| `DRY_RUN` | `1` | `install`/`remove` only — `shelf` never writes, so it's never gated |

`test/shell.d/plugins-test.sh` runs entirely against a scratch `OMARCHY_KIDS_ETC`/
`OMARCHY_KIDS_PLUGIN_INDEX`, with a fixture index JSON and stub `runuser`/`omarchy-plugin-add`/
`omarchy-plugin-remove` on a stub `PATH` — same shape `test/shell.d/apps-test.sh`'s `stub()` helper
uses.

## Judgment calls made in this implementation

- **The index is read from a local file, never fetched by this command.** This issue's brief
  ("Deliver") only asks for the shelf, the panel screen, the kid tile, and tests — not a sync
  mechanism, and Omarchy itself ships no local command that already has this data (see "What 'the
  marketplace catalog' actually is" above). Keeping the fetch out of `bin/omarchy-kids-plugins`
  also keeps `shelf` fast, offline-safe (R-APPS-8's own framing), and trivially testable with a
  fixture. **Left undone, on purpose:** nothing populates `$OMARCHY_KIDS_PLUGIN_INDEX` yet. A real
  install needs a separate mechanism (almost certainly a timer, mirroring
  `omarchy-kids-apps-install.service`'s own shape) to periodically fetch and cache
  `omarchy-plugin-marketplace`'s `site/catalog.json` there — that's a follow-up issue, not this
  one.
- **Reusing Appendix C's `age` field name for the shelf's own band floor**, rather than inventing
  a new key. The real marketplace catalog has no age-appropriateness data of any kind (it's not a
  concept the marketplace itself has); `age` on a shelf entry is entirely a Kids Mode convention,
  by design shaped exactly like a pack app's own `age` in `share/packs/<band>.toml` (Appendix C:
  "`age` (band floor)"), so `--band`'s filter and the table's "age hint" column are the same one
  field, and a future real per-plugin age floor (however it eventually gets set) slots in with no
  schema change.
- **`--all` is parent-only by *convention*, not by a runtime check.** No command in this repo
  checks "is the caller really the parent" by Unix identity from inside a shell script; that
  boundary is drawn structurally instead — only the panel (which only the parent runs, already
  behind their own login) would ever pass `--all`, and the kid-side overlay
  (`share/plugins/shell.qml`) simply never does. This matches every other "root-side" vs
  "kid-side" split already documented in `bin/omarchy-kids-ask`'s own header. It's also lower
  stakes than most such splits: `--all` only changes what's *listed*, and `install` re-checks
  `verificationStatus` itself regardless of how something was found — the actual gate is there, not
  on `shelf`.
- **`apps.extra` is edited directly (`omarchy-kids-conf set`), not through a new
  `omarchy-kids-apps` verb.** This issue's brief says the id is added "via omarchy-kids-apps", but
  `bin/omarchy-kids-apps` has no command that writes `apps.extra` (only `hide`/`show`, which write
  `apps.hidden`) — `bin/omarchy-kids-ask`'s own `apply_apps_extra` already does this exact edit the
  same way, for the same reason (a parent granting an "ask for this app/plugin" request). This file
  keeps its own small copy of that idempotent append/remove (same shape as `is_in`/`run` being
  duplicated per-file across this codebase already), rather than either adding a new verb to
  `omarchy-kids-apps` (out of scope for this issue) or reaching across into `omarchy-kids-ask`'s
  internals (which are not a public interface). `apps.extra` is the field that matters here — it's
  what `omarchy-kids-apps allowlist` composes over — so this is "via omarchy-kids-apps" in the
  sense that counts.
- **The plugin's marketplace `id` remains an allowlist id, not executable input.** Quickshell shell
  plugins generally have no `.desktop` launcher entry because they are bar widgets or panels, not
  standalone apps. The root-owned launcher map may add a desktop-backed `apps.extra` id, but a
  plugin id with no desktop entry is not turned into a shell command. The Level 1 More apps tile
  opens this file's packaged plugins shelf through its own fixed argv entry.

## Verify in the VM

The shelf overlay's load and its empty state have now run under a real Quickshell (2026-09-21, see
above); everything else here is open until it has run against a real `jq`, `runuser`,
`omarchy-plugin-add`/`-remove`, and Quickshell:

1. Hand-write a small index JSON at `/var/lib/omarchy-kids/plugin-marketplace/index.json` with one
   real, installable, verified Kids-category-shaped entry (once one exists on the real
   marketplace — see the UNVERIFIED note above) and confirm `omarchy-kids-plugins shelf` lists it,
   `shelf --band 3-5` includes/excludes it correctly by its `age`, and `shelf --all` also shows an
   unverified one with the warning line.
2. `omarchy-kids-plugins install <id> --kid kid-ada --apply` as root on a provisioned kid: confirm
   `omarchy-plugin-add` really runs as `kid-ada` (the plugin lands under
   `/home/kid-ada/.config/omarchy/plugins/`, not `/root/...`), and `omarchy-kids-conf get kid-ada
   apps.extra` includes the id afterward.
3. From the panel, Apps → Plugins shelf → Enter on an entry: confirm the same install happens
   through the warmed-sudo path, with the exact command shown first under `--dry-run`.
4. As `kid-ada` at Level 1 (band 6-8+), Super+Home, navigate to "More apps": the overlay load, the
   honest empty state and Esc are done (2026-09-21, see above); still confirm Up/Down/Enter work with
   no pointer on a **non-empty** shelf, and that Enter on an item opens the "Ask a grown-up" modal
   for that plugin (`share/ask/shell.qml`) rather than doing anything itself.
5. Confirm a band-3-5 kid's Level 1 launcher has no "More apps" tile at all.

## Source header (moved from `bin/omarchy-kids-plugins`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-plugins — the kids-plugins shelf (SPEC.md R-APPS-7, I-3,
I-6; issue #28): marketplace listings filtered to category "Kids",
verified only, install/remove into one kid's own account.

  shelf [--band BAND] [--all] [--json]
      Lists shelf entries: id, name, one-line description, and an age
      hint (SPEC.md Appendix C's own `age` = band floor, reused here —
      see "Judgment calls" in docs/plugins.md) when the index carries
      one. Default: category "Kids" AND verified only. --band keeps
      only entries whose age floor is at or below BAND (an entry with
      no age floor recorded is never filtered out — an unknown floor
      is not the same claim as "too old", I-6). --all also lists
      unverified Kids-category listings, with a warning line first
      (I-6: never blur "on the shelf" into "verified"); this flag is
      parent-only by convention — only the panel passes it, never the
      kid-side share/plugins/shell.qml overlay (docs/plugins.md).
      --json prints the same, band-filtered set as a JSON array
      instead of a table (id/name/description/age/verified) — what
      share/plugins/shell.qml reads. Neither flag changes what
      `install` will accept: install always refuses anything not
      verified, --all or not.

  install <plugin> --kid <kid> --apply
      Root. Refuses unless <plugin> is on the verified Kids shelf (the
      same rule `shelf` applies by default, enforced here again, not
      just left to the listing — R-APPS-7: "no plugin may enforce
      anything" cuts the other way too: nothing here may be installed
      on a shelf-bypassing say-so). Installs it into <kid>'s own
      account through Omarchy's own plugin installer
      (`omarchy-plugin-add <repo> --enable --yes`, run as that kid via
      `runuser -l`, so $HOME/.config/omarchy/plugins is the kid's
      own — never root's), then adds the plugin's id to that kid's
      `apps.extra` (the same profile key `omarchy-kids-apps allowlist`
      already composes over, R-APPS-4) so it shows up the same way any
      other allowed app does. DRY_RUN=1 by default (AGENTS.md rule 8);
      --apply or DRY_RUN=0 makes it real.

  remove <plugin> --kid <kid> --apply
      Root. The reverse: `omarchy-plugin-remove <plugin> --yes` as the
      kid, then drops the id from `apps.extra` (never touches
      `apps.hidden` — a removed plugin isn't hidden, it's gone).

No plugin may enforce anything (R-APPS-7's own words; Appendix G's
"Kid deletes a launcher plugin -> cosmetic" already covers the
reverse). This command never marks anything a lock, never writes
under /etc, and never runs as anyone but the parent invoking it (root,
by way of the panel's own sudo, same as every other write command
here) or the kid it installs into (by way of `runuser -l`).

Every path is overridable for tests, same convention as the rest of
bin/:
  OMARCHY_KIDS_ETC            default /etc/omarchy-kids (kid profiles)
  OMARCHY_KIDS_ROOT           scratch prefix for /var/lib/omarchy-kids
                               (the cached marketplace index), same
                               convention as omarchy-kids-ask/-apps
  OMARCHY_KIDS_PLUGIN_INDEX   full path to the marketplace index JSON
                               (default $OMARCHY_KIDS_ROOT/var/lib/
                               omarchy-kids/plugin-marketplace/
                               index.json). Nothing in this issue
                               fetches or refreshes this file — see
                               "Judgment calls" in docs/plugins.md for
                               what that means and what's left undone.
                               PATH lookup, i.e. Omarchy's own)
  DRY_RUN                     default 1; install/remove only. shelf
                               never writes, so it is never gated.
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
