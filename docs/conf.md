# Settings: profiles, bands, and `omarchy-kids-conf` (R-BAND-1, R-BAND-2, R-BUILD-5)

One way to read and write every kid setting: the schema declares the keys and their metadata, band
defaults live as data in `bands.toml`, a kid's own choices live as overrides in their profile file,
and `omarchy-kids-conf` is the only thing that knows how to combine the sources. No other command
should read or write a kid's `.conf` file directly.

## Pieces

- `share/bands/bands.toml` — the R-BAND table as data (Appendix C): one `[band."<band>"]` table
  per band, with every value in it treated as a default.
- `share/packs/<band>.toml` — each band's starter apps (`[[app]]`) and, for a walled-garden band,
  its starter site list (`[garden]`).
- `/etc/omarchy-kids/kids/<account>.conf` — one kid's overrides, `key=value`, only the keys that
  differ from the band ever appear here (R-BAND-2).
- `bin/omarchy-kids-conf` — the CLI below.
- `lib/conf.sh` — the `key=value` file helpers (`conf_get`/`conf_set`/`conf_del`) other commands
  can also source.
- `lib/conf.py` — the one place this uses Python: reading TOML (stdlib `tomllib`) and the
  Appendix B.1 slug rule (NFKD transliteration). Never runs on its own; `omarchy-kids-conf` shells
  out to it.
- `share/config/schema.toml` — the package-owned version-1 declaration for every profile and
  `apps.*` key: type, required/default source, validator, group, label, editor, and reset policy.

## Precedence

For every key in the table below, `omarchy-kids-conf get <kid> <key>` resolves in this order and
stops at the first hit:

1. **override** — the key is set in the kid's `.conf` file.
2. **band** — the kid's band supplies it, from `bands.toml` (most keys) or from
   `share/packs/<band>.toml` (`allowlist`, `sites`).
3. **default** — a global default that isn't band-specific (`password`, `onboarded`).

## Schema

`share/config/schema.toml` is installed at `/usr/share/omarchy-kids/config/schema.toml`. It has
one `[[key]]` table per supported profile key, in the same order used by `show` and `reset`. A
row's `default_source` names the existing source; it does not duplicate a band, pack, or global
value. `required = true` with `default_source = "none"` or `"parent-theme"` preserves the current
missing-value failures; the latter records the parent theme used when provisioning supplies the
required override.

The command validates the schema at startup through the fixed `lib/conf.py` helper. It then uses
the resulting rows for key recognition, `show`/`reset` iteration, precedence, and value validation.
Validator and editor names are fixed IDs selected by `case` statements; no schema value is
executed as shell code. Wizard and panel maps remain in place until tickets 2–3.

`name`, `avatar`, `band`, and `theme` have no default at all: they must already be an override, or
`get` (and anything that resolves through them) exits 2. `theme` (issue #53, `docs/theming.md`)
joins this list for a different reason than the other three — it isn't asked for interactively;
`omarchy-kids-provision add` always writes it, to the parent's own current Omarchy theme at that
moment, unless the parent has never picked one at all (a warning, not a failure — see that
command's own comment).

"Reset to band defaults" (`omarchy-kids-conf reset <kid>`) deletes every override except
`band`, `name`, `avatar`, `theme`, `password`, and `onboarded` — a kid's identity, theme, and
password survive a reset; everything else falls back to their band.

## Appendix B keys

| Key | Values | Default source | Default |
| --- | --- | --- | --- |
| `name` | text | none — required | — |
| `avatar` | id from `share/avatars/` | none — required | — |
| `band` | `3-5` `6-8` `9-12` `13+` | none — required | — |
| `level` | `1` `2` `3` | band | per band |
| `web` | `garden` `filtered` `none` | band | per band |
| `dns` | `cloudflare-family` `cleanbrowsing-family` `custom:<url>` | band | per band |
| `budget_min`, `budget_min_weekend` | integer minutes | band | per band |
| `lights_out`, `lights_out_weekend` | `HH:MM` | band | per band |
| `wifi` | `parent` `helper` | band | per band |
| `history_visible` | `yes` `no` | band | per band |
| `menu` | `trimmed` `full` | band | per band (trimmed for bands 3-5, 6-8 and 9-12; full for 13+), but no level reads it yet and the wizard no longer offers a row for it (`docs/wizard.md`) |
| `theme` | id from the system themes dir (`$OMARCHY_PATH/themes`) | parent-theme — required | — (`omarchy-kids-provision add` sets it to the parent's current theme; `docs/theming.md`) |
| `allowlist` | comma-separated launcher ids | band's pack | the full starter pack |
| `sites` | comma-separated hosts | band's pack | the band's `[garden]` list |
| `password` | `set` `none` | global | `set` |
| `onboarded` | `yes` `no` | global | `no` |

`dns` and `history_visible` are carried in `bands.toml` for every band and therefore resolve from
the band table like the other band-derived profile keys.

### Band-only fields (not profile keys)

`bands.toml` additionally carries `label`, `blurb`, `terminal` (`none` `playground` `sandboxed`),
`password_min`, and `password_optional` for each band. These describe the band itself — shown in
the wizard, used by the desktop session — and are never read through `get`/`set`/`show`, never
written to a kid's `.conf` file, and aren't part of Appendix B.

### App override keys (issue #24, not Appendix B)

Three more keys live in the same per-kid `.conf` file and go through the same `get`/`set`/`show`/
`reset` as the table above, but aren't part of Appendix B, so they're kept out of that table and
out of the schema's Appendix B rows: `bin/omarchy-kids-apps` is `apps.extra`/
`apps.hidden`'s only real caller (docs/apps.md), through `hide`/`show`, never by writing the
profile file directly; `bin/omarchy-kids-session-start` is `apps.show_missing`'s only reader
(issue #42).

| Key | Values | Default source | Default |
| --- | --- | --- | --- |
| `apps.extra` | comma-separated launcher ids | global | (empty) |
| `apps.hidden` | comma-separated launcher ids | global | (empty) |
| `apps.show_missing` | `yes` `no` | global | `no` |

`apps.extra` adds launcher ids on top of the kid's band pack; `apps.hidden` removes ids (from the
pack or from `apps.extra` alike). `omarchy-kids-apps allowlist <kid>` is what actually combines
these with `allowlist` (docs/apps.md) — `get`/`show` here only read and write the raw override,
same as any other key. `reset` clears both, same as every other override.

`apps.show_missing` controls what `bin/omarchy-kids-session-start` does with a tile whose app
isn't installed (docs/levels.md's "The launcher's tile list"): `no` (the default) omits it
entirely; `yes` keeps it, greyed, with a caption. Not read anywhere else.

### `theme`: the one key with a real side effect (issue #53)

Every other key above is a plain profile write — whatever reads it later (session-start, the bar,
a lock) is what actually acts on it. `theme` is the exception: `omarchy-kids-conf set <kid> theme
<name>` writes the override *and* applies it to `<kid>`'s own `$HOME` as root right away
(`lib/theme.sh`'s `theme_apply_for`, the same shape `omarchy theme set` uses for a live session —
see `docs/theming.md` for the full mechanics, the ownership rationale, and what "applies" actually
means non-interactively). A live session gets a best-effort reload the same way; no session means
the kid simply sees it at their next login — no restart needed either way. A failed apply (not
root, no `$OMARCHY_PATH/themes` on this box) still leaves the override written; `omarchy-kids-assert`'s
`theme:<account>` lock re-applies it on its own the next time it runs.

### Machine-level keys (`machine.conf`, not profile keys)

`/etc/omarchy-kids/machine.conf` (SPEC.md §5.1) holds settings with no kid to scope them to —
`parent` (docs/provision.md) and `boot` — as plain `key=value` lines. `parent` is read directly
with `lib/conf.sh`'s `conf_get` by commands that need the account name. `boot` is different:
`lib/boot-mode.sh` is the sole validator and reads the fixed
`/etc/omarchy-kids/machine.conf` path; it is never selected by an environment variable or a
second parser. The public reader is `omarchy-kids-conf machine get boot`, not a direct `conf_get`.
`parent` has the one exception on the write side: `omarchy-kids-conf machine set parent <name>` (issue #46),
a tiny, one-key wrapper around `conf_set` — added because `bin/omarchy-kids-wizard`'s Apply
step needs a command it can name on a plain `sudo <command>` argv (`run_priv`'s own contract), not
an inline shell that could call `conf_set` directly. `boot.snapshot_entries` still has no writer of
its own in this repo; nothing else needs one yet.

`machine set parent` has a real side effect, the same way `set <kid> theme` does (above):
right after `machine.conf` is written, it calls `lib/kids.sh`'s `luks_slots_record_parent`
against `/etc/omarchy-kids/luks-slots`, so a `0=<parent>` line exists once a parent is recorded
(docs/boot.md step 5 — without it, a boot unlocked with the parent's own disk password maps to
nothing and lands on the portal). Every existing kid entry in the file is kept untouched. An
already-present `0=` line is left exactly as it is — even one naming someone else — noted on
stderr; `machine set parent` still succeeds. The one case it refuses outright, exiting non-zero:
the existing `0=` line names a currently-provisioned kid, meaning slot 0 is already how that kid's
own account unlocks, and writing the parent there too would be a real LUKS slot clash rather than
a naming question — that needs a human to resolve the slot mapping by hand.

| Key | Values | Default | What it does |
| --- | --- | --- | --- |
| `parent` | a login name | *(none — see below)* | The parent's own account name. Read by `omarchy-kids-authd` (`docs/authd.md`) to know whose shadow hash to check, and by `omarchy-kids-provision`, which refuses to add a kid without it. Written by `omarchy-kids-conf machine set parent <name>` — `bin/omarchy-kids-wizard`'s Apply step does this first, before anything else, to `id -un` (the account running the wizard) — since nothing else in this repo writes it (issue #46: seen live, missing entirely right after a real `omarchy-kids-remove`, which deletes the whole `$ETC` tree). |
| `boot` | `disk` `portal` | *(migration or explicit choice)* | The machine startup path. Read and validated only by `omarchy-kids-conf machine get boot` through `lib/boot-mode.sh` from the fixed `/etc/omarchy-kids/machine.conf` path (R-BOOTMODE-1). |
| `boot.snapshot_entries` | `hide` `show` | `hide` | `omarchy-kids-assert`'s `limine-snapshots` lock (docs/assert.md, issue #38): while `hide` and any kid exists, `/etc/default/limine`'s `MAX_SNAPSHOT_ENTRIES=0` hides Snapper's boot-menu entries, so a kid with a disk password can't pick a pre-Kids-Mode snapshot from Limine's menu and land on the parent's desktop. `show` restores the value `MAX_SNAPSHOT_ENTRIES` held before we touched it. The parent's own rollback path stays `snapper rollback` from the running system. |

`machine migrate boot` is package-internal. During an upgrade it holds the shared boot-mode lock
while it selects or reads the mode, reads back any new value, and converges the captured legacy
mkinitcpio drop-in. `machine set boot` changes only the setting; a full mode transition owns its
boot artifacts separately.

## Band defaults

| Band | Level | Web | Budget / lights-out | Weekend lights-out | Wi-Fi | Terminal | Password |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3-5 | 1 | none | 45 min / 19:00 | 19:30 | parent | none | min 4, optional |
| 6-8 | 1 | garden | 60 min / 19:30 | 20:00 | parent | none | min 4 |
| 9-12 | 2 | garden | 90 min / 20:30 | 21:00 | helper | playground | min 6 |
| 13+ | 3 | filtered | 120 min / 21:30 | 22:00 | helper | sandboxed | min 6 |

`omarchy-kids-conf bands` prints each band's `label` and `blurb`; `omarchy-kids-conf band <band>`
prints its full default table, including the band-only fields above.

## File locations (profile/data roots are overridable for tests)

| What | Default path | Env override |
| --- | --- | --- |
| Kid overrides directory | `/etc/omarchy-kids/kids/` | `OMARCHY_KIDS_ETC` (the `/etc/omarchy-kids` root) |
| `bands.toml` and `packs/` | `/usr/share/omarchy-kids/` | `OMARCHY_KIDS_SHARE` |

Profile and package-data paths in the table are built from these two roots, so
`OMARCHY_KIDS_ETC=$scratch/etc OMARCHY_KIDS_SHARE=$scratch/share omarchy-kids-conf ...` runs
entirely against a throwaway tree — see `test/shell.d/conf-test.sh`. The boot-mode reader is the
exception: its installed machine path is fixed at `/etc/omarchy-kids/machine.conf` and tests
rewrite its build-time constant in a copied command tree.

## Commands

```text
omarchy-kids-conf get <kid> <key>          effective value: override, else band, else default
omarchy-kids-conf source <kid> <key>       print override, band, or default
omarchy-kids-conf set <kid> <key> <value>  write an override (validated against the table above)
omarchy-kids-conf unset <kid> <key>        clear one override and inherit its default
omarchy-kids-conf show <kid>                every key, its value, and where it came from
omarchy-kids-conf export <kid>              every effective setting as key=value (read-only)
omarchy-kids-conf reset <kid>                clear overrides except band/name/avatar/theme/password/onboarded
omarchy-kids-conf bands                      list bands with their label and blurb
omarchy-kids-conf band <band>                print one band's defaults
omarchy-kids-conf slug <display name>        the kid- account-name slug for a display name (Appendix B.1)
omarchy-kids-conf machine get boot           print the trusted machine boot mode
omarchy-kids-conf machine set boot <mode>    set disk or portal, after validation
omarchy-kids-conf machine set parent <name>  write machine.conf's parent= (issue #46),
                                              then record the parent's LUKS slot 0
```text

`set` refuses a key that isn't in Appendix B, and a value that doesn't match the key's format, with
exit 2 and a one-line reason on stderr. `source` exposes the same source labels as `show`. `unset`
refuses identity keys with no inherited value. Clearing `theme` first applies the parent's current
theme to the kid's home, then removes the override. `get` on an unknown key also exits 2. `get` on `name`,
`avatar`, `band`, or `theme` with no override set exits 2, naming the missing key.

## Examples

```text
$ omarchy-kids-conf set kid-ada name Ada
kid-ada: name=Ada
$ omarchy-kids-conf set kid-ada avatar fox
kid-ada: avatar=fox
$ omarchy-kids-conf set kid-ada band 6-8
kid-ada: band=6-8

$ omarchy-kids-conf get kid-ada level        # no override -> band 6-8's default
1
$ omarchy-kids-conf set kid-ada level 2      # override wins from here on
kid-ada: level=2
$ omarchy-kids-conf get kid-ada level
2

$ omarchy-kids-conf show kid-ada
KEY                  VALUE                          SOURCE
name                 Ada                            override
avatar               fox                            override
band                 6-8                            override
level                2                              override
web                  garden                         band
...
onboarded            no                             default

$ omarchy-kids-conf reset kid-ada            # level's override is gone; identity stays
kid-ada: reset to band defaults
$ omarchy-kids-conf get kid-ada level
1

$ omarchy-kids-conf slug "Zoë  O'Brien"
kid-zoeobrien
```text

## Appendix B.1: the account-name slug

`kid-` plus a slug of the display name: lowercase ASCII, common accents transliterated (NFKD
decomposition, then combining marks and anything non-ASCII dropped), non-alphanumeric characters
dropped, the result truncated to 24 characters. Collisions (`kid-ada` already taken) are the
caller's job — `omarchy-kids-conf slug` always returns the same answer for the same name and never
appends a `-2` itself.

## Source header (moved from `bin/omarchy-kids-conf`, issue #49)

Kept for reference; the file itself now carries a short pointer instead.

```text
omarchy-kids-conf — one way to read and write every kid setting
(SPEC.md R-BAND-1, R-BAND-2, R-BUILD-5, Appendix B, Appendix C).

Precedence for every Appendix B key: the kid's override
(/etc/omarchy-kids/kids/<account>.conf), else the kid's band default
(share/bands/bands.toml, plus share/packs/<band>.toml for allowlist and
sites), else the global default (password, onboarded). `band`, `name` and `avatar` have no default at all — they
must already be in the profile.

Every path is overridable for tests, so test/shell.d/conf-test.sh runs
entirely against scratch trees:
  OMARCHY_KIDS_ETC    default /etc/omarchy-kids        (kid overrides live here)
  OMARCHY_KIDS_SHARE  default /usr/share/omarchy-kids  (bands.toml, packs/)
```

## Extension keys (moved from `bin/omarchy-kids-conf`, issue #49)

```text
Extension keys (issue #24, docs/apps.md): not in Appendix B, so kept out
of the schema key rows, `cmd_show`'s main table, and `reset`'s identity-key
exemption -- but still one KEY=VALUE line in the same profile file,
read and written through this same tool (docs/conf.md's "no other
command touches a kid's .conf file directly" rule applies to these
too). omarchy-kids-apps is the only caller that needs them:
  apps.extra   comma-separated launcher ids added on top of the band's
               pack for this kid ("hide"/"show" edit this and
               apps.hidden through `omarchy-kids-conf set`, never the
               raw file)
  apps.hidden  comma-separated launcher ids removed from this kid's
               allowlist, pack or apps.extra alike
  apps.show_missing  yes/no (issue #42, docs/apps.md): whether
               bin/omarchy-kids-session-start keeps a tile for a
               pack/apps.extra app whose package isn't installed yet,
               greyed with a "not installed yet"/"installing..."
               caption, instead of the default of omitting it
               entirely (I-6: no tile that Enter silently does
               nothing on)
```

`set` and `reset` also rebuild the kid's session manifest when the box is provisioned (the
`/etc/omarchy-kids/sessions/` directory exists): a manifest older than the profile is refused at
login, so the change must land there too. `omarchy-kids-assert` repairs it if that fails.
