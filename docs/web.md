# Web policy: `omarchy-kids-web` and `share/policy/` (R-WEB-1..4)

Chromium stays the browser for everyone; a kid's copy is locked by a managed policy file only
their account's group can read. `share/policy/` is the data (SPEC.md §5.1's `policy/` directory);
`bin/omarchy-kids-web` is the one thing that turns that data into the file Chromium actually
reads.

## Files

| Path | What |
| --- | --- |
| `share/policy/<band>.json` | The band's fixed policy keys (R-WEB-2), plus `URLBlocklist`/an empty `URLAllowlist` placeholder for the two walled-garden bands. One file per band: `3-5.json`, `6-8.json`, `9-12.json`, `13+.json`. |
| `share/policy/README.md` | Every key above, its type, and where it was verified (no comments in JSON, so the citations live here). |
| `share/policy/lists/<band>.txt` | The band's starter list: one host per line, `#` starts a comment (full-line or trailing). `omarchy-kids-web render` merges this into the final `URLAllowlist` for a garden band. |
| `share/policy/chromium-flags.conf` | Omarchy's own Chromium launch flags (`omacom/omarchy` `config/chromium-flags.conf`, tag `v4.0.2`), minus every `--load-extension` entry. One flag per line, same format as Omarchy's file. Read by `omarchy-kids-web launch` and copied into a kid's own `~/.config/chromium-flags.conf` by `omarchy-kids-provision` -- see "Why not just `chromium`" below. |
| `bin/omarchy-kids-web` | `render`/`install`/`launch` — see below. |
| `/etc/chromium/policies/managed/omarchy-kids-<band>.json` | The installed result: root:`omarchy-kids-<band>`, mode `0640` (R-WEB-1). |

## Precedence

For a **walled-garden** band (6-8, 9-12 — `web=garden` in `share/bands/bands.toml`), the final
`URLAllowlist` is the union of:

1. `share/policy/lists/<band>.txt` — the band's starter list, and
2. an optional `--allow FILE` passed to `render`/`install` (same one-host-per-line format) — for
   example a kid's own approved sites.

Both are deduplicated and sorted; there is no priority between them, since both are simply
allowed. For **no browser** (3-5, `web=none`) and **filtered open web** (13+, `web=filtered`),
there is no `URLAllowlist` at all — see "Why 13+ has no list" below — and `--allow` is refused
outright rather than silently accepted and ignored (I-6: don't ship a control that isn't
enforced).

`omarchy-kids-web` reads a band's `web` mode from `share/bands/bands.toml` via
`omarchy-kids-conf band <band>`, not a second hardcoded copy of that table.

### Relationship to `share/packs/<band>.toml`'s `[garden]` table

`share/packs/<band>.toml` already carries a `[garden].sites` list (Appendix C) that
`omarchy-kids-conf get <kid> sites` falls back to for Appendix B's `sites` key — a *kid's own*
approved-sites override, resolved per kid, not rendered into a Chromium policy directly. The two
lists cover different jobs and are edited separately:

- `share/policy/lists/<band>.txt` — what this issue's tool renders into the live policy's
  `URLAllowlist` for every kid in that band. **This is the file a parent edits to grow the
  band's walled garden** (see below).
- `share/packs/<band>.toml`'s `[garden].sites` — a new kid's starting point for their own `sites`
  override, a separate mechanism (not wired to `omarchy-kids-web` by this issue).

They're kept in rough sync by hand for the well-known sites both lists already agree on
(PBS Kids, National Geographic Kids, Scratch, ...); nothing enforces that they stay identical, and
they don't need to be — a kid's own `sites` override can diverge from the band's shared starter
list.

### Why 13+ has no list

SPEC.md R-WEB-3 is explicit: "Filtered open web adds neither" `URLBlocklist` nor `URLAllowlist`.
That band's filtering is R-WEB-2's baseline (SafeSearch, YouTube Restricted Mode, and the family
DNS-over-HTTPS resolver) plus whatever the resolver's own categories cover — not a Chromium-side
site list. `share/policy/lists/13+.txt` still exists, but only as parked reference data for a
future Advanced option that isn't built yet; it is never read by `render` or `install` today.

## `omarchy-kids-web render <band> [--allow FILE] [--out FILE]`

Prints the final managed-policy JSON to stdout (or `--out FILE`). Pure — never touches
`/etc`. Used by `install` internally, and useful on its own to preview what a band's policy would
look like, or to check a kid's own approved-sites file before installing it.

```console
$ omarchy-kids-web render 6-8
{
  "DnsOverHttpsMode": "secure",
  ...
  "URLAllowlist": ["highlightskids.org", "kids.nationalgeographic.com", "pbskids.org", ...]
}
```text

## `omarchy-kids-web install <band> [--allow FILE] [--apply]`

Renders, then writes `/etc/chromium/policies/managed/omarchy-kids-<band>.json` at `0640
root:omarchy-kids-<band>` (R-WEB-1), through a same-directory temp file and rename so a browser
reading the managed-policy directory never sees a half-written file. `DRY_RUN=1` is the default
(AGENTS.md rule 8); pass `--apply`, or set `DRY_RUN=0`, to write for real. `OMARCHY_KIDS_ROOT`
prefixes the system path, the same convention `bin/omarchy-kids-session` and `lib/posture.sh`
already use, for pointing a test run at a scratch tree instead of the real `/etc`.

Ownership (`chown root:omarchy-kids-<band>`) is attempted best-effort and never fails the call:
a real run is always root (the pacman hook, the boot unit, or a parent's polkit-elevated action),
at which point it always succeeds; a non-root dev or test run cannot chown to `root:<group>`, and
`bin/omarchy-kids-assert`'s own `chromium-policy:<band>` lock already fixes the mode (and
attempts ownership again) on the real target — same reasoning `docs/assert.md` gives for that
lock, which this issue's writer fills in (that doc's own note: "a separate issue's deliverable").

## `omarchy-kids-web launch [URL]` — why not just `chromium` (issue #44)

The Web tile's exec used to be the bare command `chromium`. Live on the test laptop, that ran
Arch's `/usr/bin/chromium` wrapper script, which reads `~/.config/chromium-flags.conf` and
appends whatever it finds to the real binary's argv. Omarchy's own copy of that file
(`omacom/omarchy` `config/chromium-flags.conf`, tag `v4.0.2` — landed in a fresh kid's home by
`omarchy-provision-user`, the per-user setup `omarchy-kids-provision add` runs, R-FND-2) is:

```console
--ozone-platform=wayland
--ozone-platform-hint=wayland
--password-store=basic
--enable-features=TouchpadOverscrollHistoryNavigation
--load-extension=/usr/share/omarchy/default/chromium/extensions/copy-url,/usr/share/omarchy/default/chromium/extensions/yt-dlp,/usr/share/omarchy/default/chromium/extensions/whatsapp-slim
```

That last flag tries to load Omarchy's three bundled extensions unpacked. The kids policy always
sets `ExtensionInstallBlocklist: ["*"]` and `DeveloperToolsAvailability: 2` (R-WEB-2), so Chromium
refused every one of them and showed "Failed to load extension … Loading of unpacked extensions
is disabled by the administrator" on every single launch — a modal that also stole keyboard focus
(I-5). The policy was working exactly as intended; the flag it was refusing should never have
been offered to begin with.

`omarchy-kids-web launch` fixes this by never going through the wrapper at all: it execs
`/usr/lib/chromium/chromium` — the real binary Arch's `/usr/bin/chromium` wrapper itself execs
after reading that flags file — directly. Its argv is Omarchy's four Wayland/password-
store/feature flags from `share/policy/chromium-flags.conf` (the same four lines above, minus the
`--load-extension` line — this repo's own copy of that file), then `--no-first-run
--no-default-browser-check --hide-crash-restore-bubble --disable-session-crashed-bubble`, then
`URL` if one was given on the command line, else the band's rendered policy's
`RestoreOnStartupURLs[0]`, which the garden bands (6-8, 9-12) now define — `render_policy_json`
derives it from the first host of that band's own starter list, so the tile opens in the garden
instead of on Chromium's Google-branded new-tab page (issue #6; `none` and `filtered` bands define
none, so their launch opens Chromium's own default — see `share/policy/README.md`). The last two
flags exist because Finish (`bin/omarchy-kids-exit`,
R-EXIT-1) ends the Hyprland compositor while Chromium is still running mid-session, so without
them the *next* launch shows Chromium's own "Restore pages? Chromium didn't shut down correctly"
crash bubble instead of a clean start.

Before exec'ing anything, `launch` re-checks that this band's managed-policy file is actually
readable (R-WEB-4) — the same fail-closed rule the tile-omission logic below already gives the
Web tile itself, repeated here as defense in depth for whatever else might call `launch` directly.
The band comes from the caller's own root-owned profile — `id -un`, then `omarchy-kids-conf get
<account> band` — never from the environment (review §3.8; see the section below).

**A kid running `chromium` directly from a terminal** (bands 9-12/13+ have one, R-BAND's table)
still goes through Arch's wrapper and still reads `~/.config/chromium-flags.conf` — a path
`omarchy-kids-web launch` never touches. So `omarchy-kids-provision add` overwrites that file with
`share/policy/chromium-flags.conf` too, at `root:root 0644`: readable (Chromium's wrapper still
picks it up) but not writable, so a kid can't quietly restore the `--load-extension` flag by
editing it. It isn't undeletable — the kid still owns `~/.config` itself, and deleting the file
just leaves Chromium with no user flags file at all, never Omarchy's extension-loading one back.

## How a parent edits the walled garden

Open `share/policy/lists/<band>.txt` (installed at
`/usr/share/omarchy-kids/policy/lists/<band>.txt`) in a text editor, add a line — plain hostname,
optionally followed by `# a reason` — and re-run `omarchy-kids-web install <band> --apply` (as
root) to push the change live. Chromium's managed-policy directory is watched for changes, so a
kid's already-open browser picks it up without a restart (confirmed in `docs/phase1/V2.md`'s
notes on the same directory). There is no wizard screen for this yet (Phase 2 / a future R-WIZ
issue); editing the file directly is the only way in v1.

## Fail-closed: the launcher's web tile

`bin/omarchy-kids-session`'s own R-DESK-2 `check_policy` already refuses the **entire** kid
session if the band's policy file is missing or unreadable, for any band whose `web` isn't `none`
(see `docs/session.md`). `bin/omarchy-kids-session-start` — which builds the Level 1/2 launcher's
tile list — carries the same check as defense in depth: it only adds the `chromium` tile when
`/etc/chromium/policies/managed/omarchy-kids-<band>.json` exists and is readable by the kid's own
account, and logs a line naming why the tile was left out otherwise
(`$XDG_RUNTIME_DIR/omarchy-kids/session-<uid>.log`, the same file `omarchy-kids-session` itself
writes to). A kid never sees a Web tile that would silently fail to open (I-6). `omarchy-kids-web
launch` itself repeats this same check (see above) before it ever execs Chromium, so the rule
holds even if something other than this tile ever calls `launch` directly.

## Verifying policy keys

Every key in `share/policy/<band>.json` was checked against Chromium's own generated policy
list, not written from memory — see `share/policy/README.md` for the exact source and the
per-key citations.

## Verified live (2026-09-03, QEMU test VM)

As a 6-8 kid, the Web tile started Chromium (the launch was logged) and `https://example.com`
rendered Chromium's own "This page is blocked. Your organization doesn't allow you to view this
site", so the managed policy at `/etc/chromium/policies/managed/omarchy-kids-6-8.json` (0640
root:omarchy-kids-6-8) is loaded and the walled garden holds. Two warts found and tracked in
issue #44: Omarchy's wrapper adds `--load-extension` for its bundled extensions, which the policy
rightly refuses with a modal error every launch, and a "Chromium didn't shut down correctly"
bubble appears after a Finish. DoH and the 9-12/13+ filtered mode are not yet checked live.
Same night, after #44: the Web tile launched `/usr/lib/chromium/chromium` with the kids flags
(basic password store, no extension flags, crash bubble hidden) and opened a clean new-tab page
with no dialog of any kind; the launcher listed only the installed tiles (#42).

Re-checked 2026-09-22 (same try-omarchy VM, chromium 153.0.8010.36), which closes one of the two
gaps above: **DoH is live.** Chromium's own loader log says it found the managed file
(`config_dir_policy_loader.cc: Found mandatory policy file: /etc/chromium/policies/managed/
omarchy-kids-6-8.json`), logs no unknown- or invalid-policy warning for any of the fourteen keys,
and then makes its DNS-over-HTTPS requests to our template (`NotifyBeforeURLRequest:
https://family.cloudflare-dns.com/dns-query`), which only happens if `DnsOverHttpsMode` and
`DnsOverHttpsTemplates` were accepted. Driving the Web tile again in the kid's own session: the
new-tab page is still clean, and `example.com` still renders Chromium's "This page is blocked.
Your organization doesn't allow you to view this site" -- the same result as 2026-09-03, with the
same six-entry 6-8 allowlist. Two honest limits: `chrome://policy` cannot be dumped on this guest
to read the per-key status table (headless `--dump-dom` hangs, and chrome:// URLs need
`--allow-chrome-scheme-url`), so per-key runtime acceptance rests on the published-schema citation
in `share/policy/README.md` plus the absence of loader warnings; and the 9-12/13+ filtered mode is
still unchecked, since this box has only a 6-8 kid.

## Source header (moved from `bin/omarchy-kids-web`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-web — renders and installs the per-band managed Chromium
policy (SPEC.md R-WEB-1..4). Templates and starter lists are data:
share/policy/<band>.json (the fixed keys, R-WEB-2) and
share/policy/lists/<band>.txt (the walled-garden starter allowlist,
R-WEB-3); see share/policy/README.md for every key's citation and
docs/web.md for how a parent edits the lists.

  render <band> [--allow FILE] [--out FILE]
      Merges the band's policy template with its starter list (plus an
      optional extra --allow FILE, same one-host-per-line format --
      e.g. a kid's own approved sites) into the final managed-policy
      JSON. Prints to stdout, or writes --out FILE. Only garden bands
      (6-8, 9-12; share/bands/bands.toml's `web` field) take an
      allowlist at all -- "none" (3-5) and "filtered" (13+) bands die
      on --allow rather than silently ignore it (I-6, R-WEB-3: "filtered
      open web adds neither" list).

  install <band> [--allow FILE] [--apply]
      Same render, then writes
      /etc/chromium/policies/managed/omarchy-kids-<band>.json at 0640
      root:omarchy-kids-<band> (R-WEB-1), under $OMARCHY_KIDS_ROOT if
      set. DRY_RUN=1 by default (AGENTS.md rule 8); --apply or
      DRY_RUN=0 writes for real.

  launch [URL]
      Execs /usr/lib/chromium/chromium directly -- not /usr/bin/chromium,
      Arch's wrapper script, which reads ~/.config/chromium-flags.conf
      and appends Omarchy's own flags, including
      --load-extension=/usr/share/omarchy/default/chromium/extensions/...
      for its three bundled extensions (omacom/omarchy config/chromium-
      flags.conf, tag v4.0.2, landed in a fresh account's home by
      omarchy-provision-user). The kids policy always refuses unpacked
      extensions (ExtensionInstallBlocklist: ["*"],
      DeveloperToolsAvailability: 2), so that flag only produced a
      "Failed to load extension ... disabled by the administrator" modal
      that steals keyboard focus on every launch (issue #44). This
      command instead passes share/policy/chromium-flags.conf --
      Omarchy's own Wayland/password-store/feature flags, same file,
      minus every --load-extension entry -- plus --no-first-run
      --no-default-browser-check --hide-crash-restore-bubble
      --disable-session-crashed-bubble (the last two: Finish ends the
      compositor mid-session, so the next launch otherwise shows
      Chromium's "Restore pages?" crash bubble), then URL if given, else
      the band's `RestoreOnStartupURLs[0]` — the garden bands' own first
      starter host (issue #6). Refuses to start (exit 1) if the band's installed
      managed-policy file isn't readable (R-WEB-4: never launch
      Chromium unmanaged). The band comes from the caller's own
      root-owned profile (`id -un`), never the environment.

Every path is overridable for tests, same convention as
omarchy-kids-provision and omarchy-kids-session:
  OMARCHY_KIDS_SHARE    package data root (default /usr/share/omarchy-kids;
                        this reads $OMARCHY_KIDS_SHARE/policy/<band>.json,
                        $OMARCHY_KIDS_SHARE/policy/lists/<band>.txt, and
                        $OMARCHY_KIDS_SHARE/policy/chromium-flags.conf)
  OMARCHY_KIDS_ROOT     scratch prefix for /etc/chromium/policies/managed
                        (default empty, the real path -- same var
                        bin/omarchy-kids-session and lib/posture.sh use
                        for the system paths this package doesn't own)
  OMARCHY_KIDS_WEB_NO_EXEC=1  `launch`: print the argv that would be
                        exec'd, one argument per line, and return 0
                        instead of exec'ing it (test hook, same
                        convention as bin/omarchy-kids-session-start's
                        OMARCHY_KIDS_SESSION_START_NO_EXEC)
```

## `launch`'s fail-closed check reads the real `/etc` (issue #58)

`cmd_launch` refuses to start Chromium unless `/etc/chromium/policies/managed/omarchy-kids-<band>.json`
is readable (R-WEB-4), and it resolves `<band>` from the caller's own profile (`id -un`, then
`omarchy-kids-conf get <account> band`). Neither is an environment read any more: `$OMARCHY_KIDS_ROOT`
used to prefix that path and `$OMARCHY_KIDS_BAND` used to supply the band, so a kid could point a
fence check at a tree they owned, or name a band whose policy happened to exist (review §3.8). The
managed policy itself still applied — this was a broken *check*, not a broken fence — but the check
is what the session and the Web tile rely on.

The prefix is now `SYSROOT`, a build-time constant that is empty in every shipped copy
(`test/shell.d/pkgbuild-test.sh` asserts it). `test/shell.d/web-test.sh` substitutes its scratch
root into a copy, the same seam `bin/omarchy-kids-parent-auth`'s `TEST_SOCKET_ROOT` uses.

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
