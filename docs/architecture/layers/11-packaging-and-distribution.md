# L11 · Packaging & Distribution

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/01-omarchy-platform.md`_

## Purpose

How Kids Mode reaches a parent's machine, how it is turned on and off, and how it keeps working after
`omarchy update`. This layer defines the *shape* of every satellite repo.

## What we know (verified, report 01)

- **Omarchy 4.0.2 (2026-08-31)**, repo `omacom/omarchy`, MIT, default branch `quattro`. Internals ship as Arch
  packages (`omarchy`, `omarchy-settings`) under `/usr/share/omarchy`; user intent lives in
  `~/.config/omarchy/`; generated state in `~/.local/state/omarchy/`. [R01-S4][R01-S26]
- **Official extension points, in order of leverage for us:**
  1. **Shell plugins** — `manifest.json` (`schemaVersion: 1`) + QML; kinds `bar-widget`, `panel`, `overlay`,
     `menu`, `service`, `bar`; installed with `omarchy plugin add <git-url>` into `~/.config/omarchy/plugins/<id>/`;
     hot-reload on save; ids reverse-domain, **`omarchy.*` reserved**; listed on plugins.omarchy.org via PR to
     `omacom/omarchy-plugin-marketplace`. Plugins run **unsandboxed inside the user's shell process**. [R01-S14][R01-S21][R01-S20]
  2. **Menu extensions** — `~/.config/omarchy/extensions/omarchy-menu.jsonc` overlays the Omarchy menu: hide/retitle
     `Setup`/`Update`/`Remove`/`Install`, add `Play / Learn / Create`. Zero code, live-reloaded. [R01-S42]
  3. **Hyprland Lua overlays** — `~/.config/hypr/bindings.lua`, `looknfeel.lua`, … (Omarchy 4 converted all Hyprland
     config to Lua for 0.56). [R01-S6]
  4. **Hooks** — `~/.config/omarchy/hooks/{post-boot,post-update,theme-set,…}.d/`; `omarchy hook install`. [R01-S29]
  5. **Themes** — `colors.toml` (24-colour palette) + backgrounds + `unlock.png` etc.; git-installed themes are
     **colors-only** (any `.lua`, terminal config, `vscode.json` is stripped since 4.0.1). Naming
     `omarchy-<name>-theme`; catalog at omarchy.org/themes via PR to `omarchy-site`. [R01-S38][R01-S7][R01-S43]
  6. **Browser managed policies** — root-owned `/etc/chromium/policies/managed` (and Chrome/Edge/Brave; Firefox/Zen
     distribution dirs) with `browser_policy_*` helpers; hardened in 4.0.2. [R01-S32][R01-S39][R01-S8]
  7. **System layer** — `omarchy dns` presets on systemd-resolved, ufw (deny-in/allow-out), Snapper snapshots,
     polkit, sudoers drop-ins, `omarchy-sudo-passwordless` (15-min toggle). No AppArmor. [R01-S48][R01-S31][R01-S24][R01-S36]
- **Update pipeline:** package transaction → per-user idempotent migrations → `post-update.d` hooks → shell restart
  (unconditional). Raw `pacman -Syu` is guarded by an ALPM hook. [R01-S27]
- **Provisioning for someone else:** installer `Ctrl+C` defers username/password to first boot ("Installing for
  another owner"); unattended `cidata` drives with `defer-provisioning`; `Setup > Reset Computer` factory reset.
  [R01-S41][R01-S40][R01-S24]
- **CLI convention:** `omarchy-<group>-<verb>` scripts with `# omarchy:summary=` metadata; `omarchy <group> <verb>`
  router. [R01-S55]

## What the blueprint assumed — and what's wrong

| Blueprint | Reality |
| --- | --- |
| Plugin at `~/.config/omarchy/plugins/omarchy.kids.mode/` with root `shell.qml` | Path/manifest right; id would be **refused** (`omarchy.*` reserved); plugins declare kinds + entry points, not a root `shell.qml`; a plugin cannot lock compositor input |
| `omarchy-clarity` DNS filter with dnscrypt-proxy | Does not exist; no filtering ships |
| GRUB, ext4 `/home`, gnome-control-center | Limine + UKI, btrfs + Snapper, Quickshell menu |
| One monolithic plugin | Omarchy's ecosystem is many small repos in two catalogs |

## Design: how Kids Mode ships

**Kids Mode = a policy layer (root-owned) + an experience layer (user-owned), installed by one parent-run command,
removable by one command, and re-asserted after every update.**

| Piece | Mechanism | Owner | Kid can edit? |
| --- | --- | --- | --- |
| Web-safety policy | Chromium/Firefox managed policies in `/etc/…/policies/managed` | root | no |
| DNS + egress | `omarchy dns` custom resolver + ufw egress rules + resolved DoT | root | no |
| Account policy | groups, polkit rules in `/etc/polkit-1/rules.d`, sudoers | root | no |
| Enforcement daemon (time, allowlist) | systemd system service (Rust/Python), talks to logind | root | no |
| Kid bar / launcher / widgets | shell plugins in `~/.config/omarchy/plugins/` | kid's user | **yes** — UX only, never enforcement |
| Menu hiding, `Play/Learn/Create` | `omarchy-menu.jsonc` extension | kid's user | yes — UX only |
| Level 1/2/3 behaviour | Hyprland Lua overlays | kid's user | yes — UX only (see OQ-16) |
| Theme | `omarchy-<name>-theme` repos | kid's user | yes — colours only |
| Re-assertion | `post-update.d` / `post-boot.d` hooks + the daemon checking policy on start | root-installed hook | no |

Consequence: **anything that must hold against a curious kid lives above the line (root-owned); anything below is
delight, not defence.** OQ-16 asks whether the line can move.

### Install / uninstall contract (proposal for `omarchy-kids-setup`)

- `omarchy-kids-setup enable --preset <name>` → Snapper snapshot ("before kids mode") → install root policy →
  seed kid user config (or, single-user today, the current user's config) → install plugins/theme → hooks →
  verification run (prints the residual-risk checklist).
- `omarchy-kids-setup disable` → reverse in order; keep documents; print what was removed.
- `omarchy-kids-setup status` → what's enforced, what's UX-only, last re-assert time.
- Idempotent; safe to re-run; logs to `~/.local/state/omarchy-kids/`.

### Distribution channels

| What | Where | How |
| --- | --- | --- |
| Themes | omarchy.org/themes | PR to `omarchy-site` |
| Plugins | plugins.omarchy.org | PR to `omarchy-plugin-marketplace` registry |
| Setup tool + policy packs | GitHub repo, later AUR package (`omarchy-kids-setup`) | `curl \| bash` is **not** acceptable for a kids-safety tool; ship a PKGBUILD |
| "Gift a kid computer" | Guide using deferred provisioning / `cidata` with `defer-provisioning` + a `post-boot.d` hook applying Kids Mode on first boot | Doc + sample `cidata` |

### Upstream asks (small, realistic)

An `Install > Kids` (or `Setup > Kids Mode`) menu entry; a manual chapter; a family-DNS preset in `omarchy dns`;
multi-user (already on their radar, #532). Proposed via Discussions > Suggestions, per upstream norms. [R01-S28]

## Interfaces

- Consumes presets from **L6**, policies from **L1/L3/L4/L9**, UI from **L5/L7**.
- Must survive: `omarchy update` (shell restart, migrations), theme switches (`theme-set.d`), factory reset
  (Kids Mode should be re-applicable from a one-liner after reset).

## Residual risks

- Plugins are unsandboxed code in the kid's session → never carry enforcement there.
- A kid who can restore a pre-Kids-Mode Snapper snapshot from the Limine menu undoes everything → L2.
- Upstream moves fast (4.0 → 4.0.2 in 17 days); pin to manifest `schemaVersion` and test on each release (WS: platform watch).

## Workstreams & backlog seeds

- WS-11.1 **Platform watch** — weekly note on 4.1/multi-user/`agent-accounts`; a 4.0.2 VM image built unattended for contributors.
- WS-11.2 **Setup tool skeleton** — `omarchy-kids-setup {enable,disable,status}` with snapshot + verification; PKGBUILD.
- WS-11.3 **Re-assertion hooks** — `post-update.d`/`post-boot.d` scripts + daemon self-check.
- WS-11.4 **Gift-a-kid-computer guide** — deferred provisioning + `cidata` sample.
- WS-11.5 **Catalog presence** — marketplace + themes PRs; naming guide; Suggestions post for `Install > Kids`.

## Open questions

OQ-3 (mostly answered), OQ-9, OQ-12, OQ-15, OQ-16.
