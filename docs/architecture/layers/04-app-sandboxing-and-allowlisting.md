# L4 · App Sandboxing & Allowlisting

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/03-system-hardening-and-sandboxing.md` §3–5, 02, 04, 05_

## Purpose

What the child can run and how it's contained: the launcher shows only allowed apps; downloads can't execute;
apps that don't need the network don't get it; the terminal is a playground with a curated toolbox.

## What we know (verified)

- Omarchy ships **no** `flatpak`, `bubblewrap`, `firejail`, `apparmor`, `malcontent` (all are in Arch `extra`;
  bwrap 0.12 runs unprivileged on Arch kernels). **`fapolicyd` does not exist for Arch** (AUR: 0 results) — drop it.
  [R03-S23][R03-S35][R03-S53]
- **`noexec` on the kid's home** is a bind-remount (`/home/kid /home/kid none bind,nosuid,nodev,noexec 0 0`) or a
  dedicated subvolume mount line — VFS flags are per-mount even on btrfs. Also audit `/tmp`, `/var/tmp`,
  `/dev/shm`, `/run/user/<uid>` (`findmnt -o TARGET,OPTIONS`). `noexec` blocks `execve` of files there (incl.
  AppImages) but **not** interpreters (`bash file`, `python file`) or `ld.so ./bin` — it is not an allowlist.
  Removable media mounted by udisks are executable unless denied (polkit, L1). [R03-S46][R03-S41][R03-S59]
- **The blueprint's bwrap command cannot launch any GUI app**: no `/lib64` loader symlink, no `/proc`, `/dev`,
  `/etc`, Wayland/PipeWire sockets, GPU, or `$HOME`. **Working shape** (ArchWiki patterns): `--ro-bind /usr /usr
  --symlink usr/lib /lib64 --symlink usr/lib /lib --symlink usr/bin /bin --ro-bind /etc /etc --proc /proc --dev /dev
  --dev-bind /dev/dri /dev/dri --tmpfs /home --dir "$HOME" --ro-bind <content> <content> --dir "$XDG_RUNTIME_DIR"
  --ro-bind "$XDG_RUNTIME_DIR/wayland-1" … --ro-bind "$XDG_RUNTIME_DIR/pipewire-0" … --setenv WAYLAND_DISPLAY
  wayland-1 --unshare-all --new-session --die-with-parent <app>`. **Bind only the two sockets, never the whole
  `$XDG_RUNTIME_DIR`** (it holds Hyprland's `hypr/` IPC socket → `hyprctl keyword` undoes any config lockdown).
  Prefer `dosbox-staging` (SDL2/Wayland) over classic DOSBox. [R03-S35][R03-S36][R03-S54]
- **Firejail** is setuid-root (an escalation surface on a system whose adversary is the local user); user overrides
  in `~/.config/firejail` may be honoured unless pinned — bwrap-only unless verified. [R03-S37][R03-S41]
- **Flatpak:** `flatpak override` at system level (root) vs `--user` (kid can write their own) — precedence must be
  confirmed on the host (report 03 OQ 4); many Flathub apps are "not effectively sandboxed"; `--socket=session-bus`
  stops filtering. Flatpak consults libmalcontent for install (OARS) and run (blocklist); nothing else on Hyprland
  does. [R03-S45][R03-S49][R03-S70][R02-S2]
- **rbash is not a boundary** (any editor/pager/interpreter in `PATH` escapes; scripts drop restrictions). Use it
  only for friendliness inside a real sandbox. [R03-S57]
- Arch `fortune-mod` ships no offensive DB; stock fortunes are still adult-flavoured — curate. [R03-S52][R05-S36]
- Hyprland **permissions** (`ecosystem:enforce_permissions=true`, needs `hyprland-guiutils` — Omarchy has it):
  deny `plugin` (blocks `hyprctl plugin load`), `screencopy`, last-rule `keyboard` deny `.*` (rubber duckies);
  not reloadable at runtime. [R03-S54][R03-S60]

## Design

| Control | Mechanism | Owner |
| --- | --- | --- |
| **Allowlist** | Root-owned per-preset list (app ids + OARS ceiling) consumed by the kid launcher (L5) and by `kids-run`; nothing else is on the kid's `PATH`/desktop dirs | root |
| **No downloads execute** | `noexec,nosuid,nodev` bind-remount of the kid home + tmp-dir audit; interpreters only inside sandboxes; no `flatpak` CLI for the kid (or system-level installs only, `--user` overrides verified inert) | root |
| **Sandboxed apps (`kids-run`)** | bwrap base profile (Wayland + PipeWire + DRI sockets only; `--unshare-all --new-session --die-with-parent`; tmpfs home; read-only content dir) + per-app overlays (GCompris, Tux Paint, dosbox-staging, a portal-using browser); Flatpak system installs with system-level overrides for the Flathub-only apps | root wrapper |
| **Compositor side** | `enforce_permissions` with `plugin`/`screencopy` deny; sandboxes omit `hypr/`; kid session config root-owned (L1/L5) | root |
| **Kid shell (`bwrap-term-shield`)** | Root-owned wrapper: `--ro-bind /usr/lib`, `--symlink usr/lib /lib64`, **individual** `--ro-bind /usr/bin/{bash,ls,cat,echo,touch,cowsay,sl,fortune,figlet,lolcat,nyancat,tldr,…}` + `/usr/share/{cowsay,fortune,…}`, `--proc --dev --tmpfs /home --dir $HOME --unshare-all --new-session --die-with-parent --clearenv`, then `bash --norc -r`; kid fortune DB via `strfile`; Bashcrawl quest under `~/quest`; `rm` → trash; no `hyprctl`/`python`/editors/`sudo`/`flatpak` inside. Growth = adding binaries per level. For 5–8 a **toy REPL** on a virtual filesystem is safer still; rootless podman "real Arch" for 11+ later | root wrapper |
| **Voice tool** | Voxtype in a network-denied bwrap (L10) | root wrapper |
| **Web apps** | `https://`-only guard; machine-wide browser policy applies inside (L3) | root |

## Interfaces

Consumes preset (L6), packs (L8), uid/group (L1); provides allowlist to L5's launcher; complements L3's egress
rules; packaged by L11 as `omarchy-kids-sandbox`.

## Residual risks

Interpreters/shells as execution vectors; Wayland/GPU/PipeWire attack surface inside sandboxes; Flatpak portal
leaks; anything the kid can `git clone` and run under an allowed interpreter; sandboxes are not a substitute for
the allowlist.

## Workstreams & backlog seeds

SBX-01 `kids-run` base profile + smoke-test matrix on Hyprland 0.56 · SBX-02 kid home bind-remount + tmpfs audit ·
SBX-03 Flatpak system-override policy + `--user` precedence test · SBX-04 malcontent/`flatpak run` enforcement spike
(OQ-17) · SBX-05 allowlist format + launcher wrapper · SBX-06 `bwrap-term-shield` + Bashcrawl-Omarchy quest ·
SBX-07 toy REPL prototype for 5–8 · SBX-08 kid fortune file (GFI) · SBX-09 Hyprland permissions rule set.

## Open questions

OQ-16, OQ-17; Flatpak-first on a pacman-first distro; real shell vs playground at Supported (8–10); Firejail's
user-override behaviour.
