# Open Questions Register

_status: living · updated 2026-09-01 — add a row, don't delete; resolved questions move to the bottom with a
link to the ADR/RFC that settled them._

| ID | Question | Layer | Why it matters | Where it's being worked | Status |
| --- | --- | --- | --- | --- | --- |
| OQ-1 | What are the top 3 apps kids 5–12 will expect on a fresh device — and which are feasible on Linux? (DubOh, Discord) | L8 | Decides the starter pack and the first "sorry, no Roblox" conversation | report 05 | open |
| OQ-2 | Account model: a separate unprivileged Unix user with its own Hyprland session, or a "kid mode" toggle inside the parent's session? **Evidence so far:** Omarchy is single-user by design (Discussion #532); multi-user "coming in 4.1" is second-hand; deferred provisioning supports "the kid's own machine" today | L1/L5 | Everything downstream (isolation, session switching, Omarchy's autologin design) depends on it | reports 01, 03 → RFC | open |
| OQ-3 | What extension mechanism does Omarchy actually offer today — and what survives `omarchy update`? **Largely answered by report 01:** official Quickshell plugin system (six kinds), menu extensions, hooks, Hyprland Lua overlays, colors-only themes, root-owned Chromium policies. Remaining: what can be made kid-tamper-proof (OQ-16) | L11 | Determines whether Kids Mode is "a plugin", "a theme + tools", or "a config overlay" | report 01 → L11 doc | mostly answered |
| OQ-4 | Can Omarchy's bootloader be locked down? **Answered by report 03:** Limine has no password; `editor_enabled: no` (re-applied by hook, since `omarchy-refresh-limine` overwrites it) + Direct Boot + firmware password is the realistic set; pre-Kids-Mode snapshots are bootable from the menu | L2 | The classic recovery-shell root bypass | L2 doc | mostly answered |
| OQ-5 | Which services have real kid versions we can *enforce* (not just suggest) from Linux? | L8/L3 | "Default to kids versions and prevent override" only works if enforceable | reports 04, 05 | open |
| OQ-6 | Default DNS: Cloudflare for Families (sponsor, zero-config) vs NextDNS (per-child profiles) vs local dnscrypt-proxy (offline lists)? | L3 | The quick win; also a privacy and dependency decision | report 04 → RFC | open |
| OQ-7 | Are Levels parent-set, earned through play, or both? | L5/L6 | Pedagogy vs. parent control; affects UI and motivation design | report 07 | open |
| OQ-8 | Local AI helper: in or out of v1? If in, what are the minimum guardrails? | L10 | Community is split; policy landscape is moving fast | report 07 → RFC | open |
| OQ-9 | Personal namespace vs GitHub org; may we use "Omarchy" in the name? (GOV-1) | community | Bus factor, trademark courtesy, discoverability | GOVERNANCE.md | open |
| OQ-10 | Is 3–5 (pre-readers) in scope for v1, or do we start at 5–7? | L5/L6/L7 | Pre-readers need icon+audio UI; a very different design | report 07 | open |
| OQ-11 | Multiple kids on one machine — one kid account each, or profiles inside one? | L1/L9 | Families with 2–4 kids are the norm | reports 02, 03 | open |
| OQ-12 | What, if anything, should be proposed upstream to Omarchy vs. kept independent? | community/L11 | Upstream is opinionated; guessing wrong wastes goodwill | report 01, ask upstream | open |
| OQ-13 | Which UI toolkit for kid-facing surfaces (bar, onboarding, games): whatever Omarchy's bar uses, GTK4, web/PWA, Godot? | L5/L6/L7 | Contributor skills + consistency with upstream | reports 01, 05 | open |
| OQ-14 | Do we need HTTPS-aware content filtering (beyond DNS) in any version? | L3 | Big complexity/privacy cost; parents may expect it | report 04 | open |
| OQ-15 | How do we relate to `jfuerwentsches/omarchy-kids` (started 2026-08-27: Rust agent + Qt parent control + age tiers)? Merge, split by layer, or run in parallel? Who holds the `omarchy-kids` name/domain? | community | Two four-day-old efforts with the same name is the fastest way to lose both | GOVERNANCE.md; reach out on Discord/GitHub | open — **urgent** |
| OQ-16 | Can anything under the kid's own `~/.config/omarchy/` (plugins, `shell.json`, Hyprland Lua) be made tamper-proof, or must all enforcement live in root-owned files + a system daemon? | L4/L5/L11 | Plugins run unsandboxed in the kid's shell; whatever the kid can edit, the kid can defeat | report 03; ask Omarchy security team | open |
| OQ-17 | Does Arch's `flatpak` link `libmalcontent` (so `flatpak run` refuses filtered apps)? Is the malcontent policy schema worth reusing for ecosystem compatibility? | L4 | Decides whether Flatpak is a real enforcement point | report 02 spike | open |
| OQ-18 | Is timekpr-next's tray/lock integration workable on Hyprland + omarchy-shell, or do we write a native logind-based service? | L9 | Build vs. integrate for the screen-time layer | report 02 spike | open |
| OQ-19 | Default family model: autologin stays with the parent (parent logs out → greeter → kid), or moves to `kid` (parent authenticates at the greeter)? | L1/L2 | Changes `omarchy-kids-user` defaults and the recovery story | report 03; ask parents | open |
| OQ-20 | With a UKI entry, can Limine's editor inject `init=/bin/bash`? (systemd-stub honours a bootloader cmdline only with Secure Boot off — Omarchy's required state) | L2 | Decides how urgent `editor_enabled: no` is | hands-on test on real hardware | open |
| OQ-21 | Flatpak override precedence: can a `--user` override re-grant a permission removed at system level? | L4 | Decides whether Flatpak lockdown holds if the kid can run `flatpak` | host test | open |
| OQ-22 | How should Kids Mode treat Omarchy's AI-agent tooling (agents, `omarchy-sudo-passwordless`, crash-watch AI terminal) in the kid session — hard-disable or age-gated? | L1/L10 | Omarchy is agent-forward by default | RFC | open |

## Resolved

| ID | Question | Resolution |
| --- | --- | --- |
| — | Where does the code go? (Viraj, Discord) | Plan here, code in satellite repos — ADR-0002 |
