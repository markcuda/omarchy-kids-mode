# Wi-Fi: `omarchy-kids-wifi`, `omarchy-kids-wifid`, and the picker (SPEC.md R-WIFI-1..4; issue #26)

Kids can join new Wi-Fi (the school's network, a café) without ever touching NetworkManager
directly, and without the network they join being able to weaken the DoH filtering already forced
into their Chromium policy (R-WEB-6/I-1).

## Why a daemon at all

Kid accounts are polkit-denied, no prompt, from `org.freedesktop.NetworkManager.settings.modify`
(`lib/posture.sh`'s `41-omarchy-kids-deny.rules`, R-FND-4) — the action every plain `nmcli
device wifi connect` needs to save a connection profile. `bin/omarchy-kids-wifid` is the one
root, socket-activated process that may call `nmcli` on a kid's behalf, the same shape as
`bin/omarchy-kids-authd` (docs/authd.md): one request per connection, stdlib-only Python,
socket-activated via `systemd/omarchy-kids-wifid.{socket,service}`.

Unlike authd, this daemon isn't a password oracle — it identifies its caller by the kernel's own
idea of who is on the other end of the socket (`SO_PEERCRED`, never anything the client claims),
maps that uid to an account, and refuses outright unless that account's `wifi` profile key
(`bin/omarchy-kids-conf`, Appendix B) resolves to `helper`. `parent`-mode kids get nothing from
this daemon at all — R-WIFI-1's other value.

## Pieces

- `bin/omarchy-kids-wifid` — the root daemon. Reads the caller's uid via `SO_PEERCRED`, shells out
  to `omarchy-kids-conf get <account> wifi` to resolve the profile, and only then runs `nmcli` —
  always with a fixed, hardcoded argument list (`subprocess.run([...])`, never `shell=True`, never
  string interpolation into a command line), so nothing a client sends over the socket can smuggle
  in an extra flag.
- `bin/omarchy-kids-wifi` — the kid-side command: `list`, `join`, `status`, `forget`, `picker`. Talks to the daemon over the socket; never calls `nmcli`
  itself.
- `share/wifi/shell.qml` — the kid-facing Quickshell picker (`omarchy-kids-wifi picker`).
- `share/hyprland/L1.lua` / `L2.lua` / `L3.lua` — bind `Super+Shift+W` to `omarchy-kids-wifi
  picker` at every level (Appendix E). The bind itself is unconditional (these files are static
  and provisioned once, R-DESK-1); `picker` is what actually refuses for a `parent`-mode kid.
- `systemd/omarchy-kids-wifid.socket` / `.service` — same shape as `omarchy-kids-authd`'s units.

## Wire protocol

A client connects to `/run/omarchy-kids/wifi.sock`, writes its request, shuts down its write side
(or just closes), and reads the reply:

```text
LIST\n                          -> "OK\n" + nmcli's own terse output, or "REFUSED ...\n"/"ERROR ...\n"
STATUS\n                        -> "OK\n" + nmcli's own terse output
JOIN <ssid>\n<password>\n       -> "OK\njoined kids-<ssid>\n", or an ERROR line
FORGET <ssid>\n                 -> "OK\nforgot kids-<ssid>\n", or an ERROR line
```text

`<password>` may be empty (an open network); the header line is required, the password line is
not. The daemon serves one request per connection — same reasoning as authd: there's no need for
more, and it keeps every request's authorization decision (the `SO_PEERCRED` check) tied 1:1 to
one accepted connection.

Every reply starts with one of three words:

- `OK` — the payload (if any) follows on subsequent lines.
- `REFUSED <reason>` — the peer's account isn't `wifi=helper` (or has no resolvable profile at
  all). `bin/omarchy-kids-wifi` turns this into exit code 3.
- `ERROR <reason>` — the request was allowed, but `nmcli` (or the request itself) failed — a bad
  SSID, a wrong password, a network that's out of range by the time `join` runs, etc. Exit code 1.

## What `join` actually does

1. `nmcli device wifi connect <ssid> [password <password>] name kids-<ssid>` — always targets
   (creates, if needed) a connection named `kids-<ssid>`, **never** a bare-named `<ssid>`
   connection, even if one already exists for that network. That existing connection wasn't
   created by this daemon, so it's never touched (R-WIFI-2's "never touch connections it did not
   create") — the cost is that a network can end up with two connection profiles (the parent's own
   bare-named one, and the kid's `kids-`-prefixed one), which is the trade-off, not a bug.
2. `nmcli connection modify kids-<ssid> ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
   ipv4.dns "" ipv6.dns "" connection.zone kids` — forces the network's own DNS to be ignored and
   clears any DNS servers already recorded on the connection (R-WIFI-2). This is the whole point:
   without it, a captive network or a school's resolver could quietly hand out its own DNS and
   short-circuit the DoH filtering forced into the kid's Chromium policy (R-WEB-2, R-WEB-6).
   `connection.zone kids` additionally tags the connection so a future pass can recognize every
   connection this daemon owns without relying on the name prefix alone.
3. `nmcli connection up kids-<ssid>` — reactivates so the DNS change takes on a connection that
   `device wifi connect` may have already brought up with the network's own DNS still attached.

`forget <ssid>` only ever runs `nmcli connection delete kids-<ssid>` — by construction, it can
never reach a connection this daemon didn't create.

## The per-kid `wifi` key (Appendix B)

| Value | Meaning |
| --- | --- |
| `parent` | Default for 3-5, 6-8. The kid cannot use `omarchy-kids-wifi` at all; every subcommand (and the picker) refuses. R-WIFI-4 says the kid-side join should instead open the ask modal — **not built here**, see "Known gap" below. |
| `helper` | Default for 9-12, 13+. `omarchy-kids-wifid` will act on this account's requests. |

Read/write it the normal way: `omarchy-kids-conf get <kid> wifi` / `omarchy-kids-conf set <kid>
wifi helper`.

## The picker (`omarchy-kids-wifi picker`, `share/wifi/shell.qml`)

Bound to `Super+Shift+W` at every level. `picker` checks the profile itself before ever launching
Quickshell: a `parent`-mode (or profile-less) kid gets a small toast (`share/time/toast.qml`,
reused from the screen-time warnings, but with `OMARCHY_KIDS_TOAST_ICON` set to the Wi-Fi bars so
the glyph matches the words rather than the time toast's clock) saying Wi-Fi needs a grown-up, and
the command exits without
opening anything (I-6: the bind existing is not the same claim as the bind doing anything). A
`helper`-mode kid gets the real picker: arrow keys through nearby networks (from `omarchy-kids-wifi
list`), Enter to join (a password field appears first if the network needs one), Esc to back out
of the password field or close the picker entirely. An empty scan says “No networks found” and
shows **Try again**, available by click or Enter. A failed scan keeps its error visible with the
same retry action. While loading or joining, the footer offers only Escape; other steps show the
available selection, retry, or join keys.

A successful join keeps “Joined <network>.” visible through the automatic list refresh.
The message names the submitted network even if selection changes while the join is running.
A failed refresh replaces it with the scan error; a new join or manual retry clears stale
feedback. Success reports the join client’s result, not a separate internet-access check.

Every action the picker takes still goes through `omarchy-kids-wifi` → `omarchy-kids-wifid`, which
re-checks `SO_PEERCRED` on every single connection — the picker's own check is a UX nicety, not the
real gate.

## The captive-portal window (R-WIFI-3): removed, not shipped

Some networks (a school's guest Wi-Fi, most cafés) intercept all traffic until you complete a
captive-portal page, which usually needs to load over plain `http://`. R-WIFI-3 asks for a helper
window that opens one and briefly relaxes just enough filtering to let it load.

`omarchy-kids-wifi portal` used to be that helper. **It is gone** (issue #58, the round-two
review's §3.9). It could not work for the only account that would ever reach it:

- Its temporary-allow step ran `omarchy-kids-web install <band> --allow … --apply`, which writes
  root-owned files under `/etc/chromium/policies/managed/`.
- Its restore step ran `systemd-run --on-active=10min`, which needs
  `org.freedesktop.systemd1.manage-units` — an action `lib/posture.sh`'s
  `41-omarchy-kids-deny.rules` denies every kid account outright (R-FND-4).

So for a kid it failed at both halves, and in the one context where it *would* have worked (root)
a failed `systemd-run` left `neverssl.com` allowed for that whole band, for every sibling in it,
until some unrelated `omarchy-kids-web install` happened to re-render the policy. It also ran a
bare `chromium --new-window`, with none of the R-WEB-4 fail-closed check `omarchy-kids-web launch`
and `omarchy-kids-session-start` both enforce.

A narrow polkit rule would not have fixed it: the NetworkManager actions a kid could plausibly be
granted (`org.freedesktop.NetworkManager.network-control`, and
`org.freedesktop.NetworkManager.settings.modify.system` for a `kids-`-prefixed connection id) are
about *connections*, not about writing a Chromium policy or starting a transient unit. Rule 6
(honest UI) says do not ship a control that is not enforced, so the command and its docs are out
until there is a root-side helper that can do both halves and confirm its own restore.

Until then: a parent completes the captive portal from their own session.

## Known gap: R-WIFI-4 (`parent` mode → ask modal)

R-WIFI-4 says a `parent`-mode kid's join attempt should open the ask modal
(`bin/omarchy-kids-ask`, docs/ask.md). That modal's queue record (Appendix D) has a fixed `kind`
enum — `time | app | plugin | site` — that does not include `wifi`; adding a fifth kind (and
deciding what "approve" even means for a Wi-Fi request — join it *for* the kid? just flip their
`wifi` key to `helper`?) is a real design decision, not a plumbing one, and is out of scope for
this issue. Every `omarchy-kids-wifi` subcommand instead refuses a `parent`-mode kid honestly, with
a one-line reason (the picker: a toast; everything else: stderr and exit 3) — no control here
claims to open anything it doesn't (I-6).

## Testing

`test/shell.d/wifi-test.sh` covers, all offline and without a real NetworkManager or root:

- `bin/omarchy-kids-wifid`'s request parsing and `nmcli` argument-vector construction, tested by
  importing the file as a Python module (`importlib`) and calling its functions directly — the
  same reasoning `test/shell.d/authd-test.sh` gives for driving `omarchy-kids-authd` as a real
  process instead doesn't carry over cleanly here, since faking `SO_PEERCRED` across a real Unix
  socket from a test harness is far more machinery than importing the module and calling
  `cmd_join`/`cmd_forget`/`parse_request` with a fake `nmcli` stub on `$PATH`.
- `bin/omarchy-kids-wifi`'s `require_helper` refusal for `wifi=parent` (and for no profile at
  all), against a scratch `OMARCHY_KIDS_ETC`/`OMARCHY_KIDS_SHARE` tree, the same convention
  `test/shell.d/conf-test.sh` and `test/shell.d/web-test.sh` use.
- `omarchy-kids-wifi forget` only ever building a `kids-<ssid>` argument, never a bare SSID.
- `omarchy-kids-wifi portal` exiting 2 as an unknown command: the captive-portal helper is gone,
  and the test says so, so it cannot come back unnoticed.
- `cmd_join`'s exact five-call `nmcli` sequence, in order, with the R-WIFI-2 DNS lockdown applied
  *before* activation, a `--` before every client-supplied value, and a failed activation deleting
  the half-built profile (review §3.10, §3.11).

```text
bash test/shell.d/wifi-test.sh
```text

## What needs the VM (never run here — AGENTS.md rule 8)

- `bin/omarchy-kids-wifid` actually accepting a connection from a real kid uid and reading its
  `SO_PEERCRED` — this only runs on Linux at all (guarded in `main()`), and this repo was written
  without a Linux box with NetworkManager, systemd socket activation, or a kid account to test
  against.
- `share/wifi/shell.qml`'s network-dependent parts: the overlay, its `omarchy-kids-wifi list`
  Process and stdout read-back, the empty state, `Try again` and Esc were verified live 2026-09-22
  (see the Verified-live note below), so they are no longer open; everything that needs a real
  network -- the populated list's signal/security/`inUse` fields, the password step, and the join
  outcome messages -- still has not run. Two pieces carry over from `share/exit-modal/shell.qml`,
  verified live there 2026-09-02 (`PanelWindow` + `WlrLayershell.layer: WlrLayer.Overlay` +
  `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`; `Quickshell.Io.Process` with
  `stdinEnabled`/`write()`, flipping `stdinEnabled = false` rather than a `closeStdin()` call to
  signal EOF). Also flagged, not fixed: `nmcli`'s terse (`-t`) output is `:`-delimited and escapes
  a literal `:` inside a field with a backslash; the picker's naive `split(":")` does not unescape
  that, so an SSID containing a colon parses wrong (rare in practice).
- `nmcli connection add type wifi con-name kids-<ssid> autoconnect no …` actually creating a *new*
  connection (not silently reusing/renaming an existing bare-named one) on a real NetworkManager,
  `wifi-sec.psk` actually authenticating, and `ipv4.ignore-auto-dns`/`ipv6.ignore-auto-dns` being
  in force from the first packet — the profile is only brought up after they are set, so there is
  no window on the network's own DNS at all (review §3.11).

## Verified live (2026-09-02, QEMU test VM, no wireless device)

`omarchy-kids-wifid.socket` is active after `omarchy-kids-assert` (units lock). As Cy with the
default `wifi = parent`, `status` and `list` are refused with the kid-worded message (exit 3).
With `wifi = helper`, `status` lists the connections through the root helper, `list` returns an
empty OK, and `join TestNet` fails with NetworkManager's "No Wi-Fi device found", which is the
VM telling the truth. The picker overlay, a real join with `ignore-auto-dns`, `forget`, and the
captive-portal window need the laptop's wireless card.

### The picker overlay, live (2026-09-22, same VM, still no wireless device)

With `wifi = helper`, `Super+Shift+W` reached Hyprland and `omarchy-kids-wifi picker` opened
`share/wifi/shell.qml` under a real Quickshell over the Level 2 tiled windows: the overlay drew
with its dim background, the `omarchy-kids-wifi list` Process ran and its stdout was read back
(empty), the "No networks found" empty state rendered with "Try again" focused and the footer
"Enter try again · Esc close", Enter re-ran the list (still empty, no error), and Esc closed the
process. So the layer/keyboard shape, the Process stdout read-back, and the empty/retry/close
paths are confirmed; the populated network list, the password step and the join outcomes still
need the laptop's wireless card. The profile was set back to `parent` afterwards.
## The daemon no longer echoes the Wi-Fi password (2026-09-03)

`run_nmcli` raised `Failed(f"nmcli {' '.join(args)}: {exc}")` on an `OSError` or a timeout, and
that text goes straight back to the client. On the JOIN path `args` contains
`password <secret>`, so a parent who typed a network password into the kid's picker got it back
over the socket and into whatever the client logged (review S8). The message now names only the
nmcli subcommand, which is all a caller needs to diagnose it. `test/shell.d/wifi-test.sh` calls
`run_nmcli` directly with a nonexistent binary and a password in the argv and asserts the
password is absent from the raised text and the subcommand present -- a unit-level check, so it
runs on every platform, unlike section B, which needs `SO_PEERCRED`. `bin/omarchy-kids-wifi`'s
socket client is now `lib/sock.sh`'s shared `kids_sock_request`, and the wifi picker's QML names
`/usr/bin/omarchy-kids-wifi` absolutely.

## Source header (moved from `bin/omarchy-kids-wifi`, issue #49)

Kept for reference; the file itself now carries a 3-line pointer instead.

```text
omarchy-kids-wifi — the kid-side Wi-Fi commands (SPEC.md R-WIFI-1..4).

Kid accounts are polkit-denied from
`org.freedesktop.NetworkManager.settings.modify` (lib/posture.sh's
41-omarchy-kids-deny.rules, R-FND-4), so none of the subcommands below
ever call `nmcli` themselves. Instead they talk to
bin/omarchy-kids-wifid, a root, socket-activated daemon that identifies
the caller by Unix peer credentials (SO_PEERCRED — never anything the
client claims), looks up that account's `wifi` profile key
(bin/omarchy-kids-conf, Appendix B), and refuses outright unless it is
`helper`. See docs/wifi.md for the wire protocol and docs/conf.md for
the profile key.

  list                       Nearby networks: SSID, signal, security.
  join <ssid> [--password-stdin]
                              Joins (creating it if needed). With
                              --password-stdin, reads one line of
                              password from stdin (never argv, never
                              logged — AGENTS.md's rule); omit it for
                              an open network. The daemon always
                              creates/targets a `kids-<ssid>`
                              connection (never a bare-named one it
                              didn't create) with ipv4/ipv6
                              ignore-auto-dns forced on and connection
                              DNS cleared (R-WIFI-2), so a captive
                              network or a school's DNS can never
                              weaken the DoH filtering already forced
                              in the kid's Chromium policy (R-WEB-6/I-1).
  status                      The active connection(s), if any.
  forget <ssid>               Deletes `kids-<ssid>` — never a
                              bare-named connection this daemon didn't
                              create, even one for the same SSID.
  picker                      Launches the kid-facing Quickshell
                              picker (share/wifi/shell.qml). Bound to
                              Super+Shift+W at every level
                              (share/hyprland/L1.lua, L2.lua, L3.lua);
                              the bind is unconditional (the level
                              configs are static, R-DESK-1), so this
                              command itself is what refuses — with a
                              small toast, I-6 — when the profile says
                              `parent` instead of `helper`.

Every subcommand above (list/join/status/forget/picker) does
the same `wifi=helper` check twice: once here, fast and friendly,
before ever touching the socket, and once again — authoritatively,
server-side, from the kernel's own idea of who's connecting — inside
omarchy-kids-wifid. Only the second one is real security; this
script's own check exists purely so a `parent`-mode kid gets a plain
sentence instead of a raw daemon refusal (I-6).

`parent` mode (R-WIFI-4: "the kid-side join opens the ask modal") is
NOT wired to bin/omarchy-kids-ask in this issue: Appendix D's queue
record `kind` enum is `time|app|plugin|site` and does not include
`wifi`, so there is no existing modal/record shape to reuse without
extending that contract, which is out of scope here (see docs/wifi.md
"Known gap"). Every subcommand instead refuses honestly with a
one-line reason (I-6: never fake a control that isn't there) — the
same shape bin/omarchy-kids-exit's `--pause` uses for its own
not-yet-built path.

The daemon socket and every sibling command are constants, not
environment overrides (AGENTS.md rule 9). What is left:
  OMARCHY_KIDS_SHARE       default /usr/share/omarchy-kids (wifi/shell.qml, time/toast.qml)
  OMARCHY_KIDS_WIFID_TIMEOUT  seconds, default 10 (nmcli's own wifi rescan can be slow)
```

## The trust boundary (issue #58)

This command resolves `lib/` and every sibling `omarchy-kids-*` from its own resolved location
(`readlink -f "$0"`), else the installed prefix — never from the environment. `$OMARCHY_KIDS_LIB`,
the `*_BIN` / `*_PY` overrides, the socket paths and the `*_REQUIRE_ROOT` escapes are gone:
`AGENTS.md` rule 9 states the rule and `test/shell.d/trust-boundary-test.sh` enforces it, with the
allowlist of the data settings that stay. A test that needs a stub places it beside a copy of the
command in a scratch tree (`test/shell.d/tree.sh`), or substitutes a build-time constant, the way
`PKGBUILD` substitutes `KIDS_PY` at package time.
