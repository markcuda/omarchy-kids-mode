# L3 · Network & Content Filtering

_status: draft · updated 2026-09-01 · lead: open · primary evidence: `research/reports/04-network-dns-and-browser-safety.md` (see its erratum), `01-omarchy-platform.md`_

## Purpose

Stop "the moment when a porn site pops up" — with a boring, robust default that works on one laptop anywhere
(home, grandma's, a phone hotspot), needs no server, and is honest about what it cannot do.

## What we know (verified)

- **Omarchy 4.x stack:** NetworkManager + **systemd-resolved** (stub at `127.0.0.53`) + **ufw** (deny-in, **allow-out**)
  plus **Chromium** default with root-owned managed policies at `/etc/chromium/policies/managed` (hardened 4.0.2).
  `omarchy dns` (Setup > Network > DNS) switches resolved between Cloudflare / Google / DHCP / custom via a sudoers
  helper. **No content filtering ships.** [R01-S36][R01-S48][R01-S31][R01-S32][R01-S8]
- Report 04 analysed the 3.x branch for the network layer (iwd + networkd) — corrected in its erratum. Its
  provider, policy and bypass findings are branch-independent.
- **Filtering DNS providers** (report 04 §1): Cloudflare for Families `1.1.1.3` / `family.cloudflare-dns.com`
  (adult + malware; **no SafeSearch enforcement, no customisation**); **Quad9 does no adult filtering** — drop it;
  AdGuard Family and CleanBrowsing Family enforce SafeSearch/YouTube-restricted at DNS for free (CleanBrowsing also
  blocks proxies/VPNs); NextDNS is best-featured (per-child profiles, Recreation Time) but **silently stops filtering
  after 300k free queries/month** — a fail-open trap. [R04-S1][R04-S2][R04-S3][R04-S7][R04-S9][R04-S4][R04-S5]
- **SafeSearch via DNS CNAME is officially supported over HTTPS** by Google (`forcesafesearch.google.com`), YouTube
  (`restrict.youtube.com` / `restrictmoderate.youtube.com` on five exact hostnames) and DuckDuckGo
  (`safe.duckduckgo.com`); Bing `strict.bing.com` is documented but was not fetched. [R04-S12][R04-S13][R04-S14]
- **DoH bypass is closed by browser policy, not IP blocking**: Chromium `DnsOverHttpsMode: "off"`, Firefox
  `DNSOverHTTPS: {Enabled:false, Locked:true}`; Chrome ignores the Firefox canary domain; `cloudflare-dns.com`
  lives in CDN IP space so IP blocks cause collateral damage. [R04-S47][R04-S50][R04-S52][R04-S84]
- **DNS rewriting `youtube.com → youtubekids.com` cannot work** (same front-end, certificate-bound). Use
  `URLBlocklist` + a YouTube Kids web app. [R04-S84][R04-S67]
- **Linux Chromium policy is machine-wide**, not per-user — parent and kid share it. [R04-S48]
- `dnscrypt-proxy` (Arch `extra`) already ships SafeSearch cloaking rules, time-scheduled blocks and family
  upstreams — the right local spine for v2; filtering then travels with the laptop. [R04-S17]–[R04-S21]
- Omarchy's stock web apps include YouTube, ChatGPT, X, Discord, WhatsApp; `omarchy-webapp-install` accepted
  `javascript:`/`file:` URLs until 2026-08-27. [R04-S41][R04-S42]

## What the blueprint assumed — and what's wrong

| Blueprint | Reality |
| --- | --- |
| `omarchy-clarity` + dnscrypt-proxy integration | Doesn't exist |
| Block DoH by IP (1.0.0.1, 8.8.4.4…) | Incomplete and collateral-prone; use policy + resolver-level hostname blocks |
| Block port 53 except to 127.0.0.1 | Right idea; must also cover 853, the `127.0.0.53` stub, and be per-uid so the resolver itself can reach upstream |
| Raw iptables/nftables | ufw already owns tables; a separate nftables table must coexist |

## Design: layered, fail-closed, travels with the laptop

```text
DNS (every app on the box)  →  browser policy (closes DoH/incognito/extension/devtools holes)  →  egress firewall (closes app-level bypass)
```

### v1 — the quick win (Phase 2)

| Piece | Concrete | Owner |
| --- | --- | --- |
| Family DNS | `omarchy dns` custom → `DNS=1.1.1.3#family.cloudflare-dns.com 1.0.0.3#family.cloudflare-dns.com …`, `DNSOverTLS=yes` (**strict**, never opportunistic), `Domains=~.`, `FallbackDNS=` to *another family resolver* (AdGuard Family) — never an unfiltered one. **Verified 2026-09-01 from `bin/omarchy-dns` on `quattro`:** the script (sudoers/pkexec-gated) writes NetworkManager global DNS in `/etc/NetworkManager/conf.d/20-omarchy-dns.conf` (`[global-dns-domain-*] servers=…`) and reads/writes `/etc/systemd/resolved.conf` — so the pinning point on 4.x is NM's global-dns (which overrides per-connection DNS) plus resolved. A `Family` preset is a small, upstream-shaped PR to that script (NET-01). | root |
| Chromium policy pack | `/etc/chromium/policies/managed/omarchy-kids.json` (+ Brave/Chrome copies): `DnsOverHttpsMode:"off"`, `ForceGoogleSafeSearch:true`, `ForceYouTubeRestrict:2`, `IncognitoModeAvailability:1`, `DeveloperToolsAvailability:2`, `ExtensionInstallBlocklist:["*"]` (+ allowlist Omarchy's `copy-url` by ID or drop it for kids), `BrowserSignin:0`, `DownloadRestrictions`, `SafeBrowsingProtectionLevel:1`, `URLBlocklist` (YouTube, known social) — or **allowlist-only** for Guided presets (`URLBlocklist:["*"]` + `URLAllowlist`, 1,000-entry cap) | root |
| Firefox/Zen twin | `/etc/firefox/policies/policies.json`: `DNSOverHTTPS.Locked`, `DisablePrivateBrowsing`, `ExtensionSettings "*" blocked`, `WebsiteFilter` | root |
| Kid web apps | Remove stock YouTube/ChatGPT/X/Discord/WhatsApp for the kid; install YouTube Kids + vetted sites via `omarchy-webapp-install` with an `https://`-only guard | kid config, root-applied |
| Verification | `omarchy-kids-check`: resolves a known-blocked test domain, checks the SafeSearch CNAME, reads policy JSON, confirms DoH off → **green/red screen for the parent** | tool |

Default provider is **OQ-6** (Cloudflare Family: sponsor, simplest, no SafeSearch → we enforce SafeSearch via
policy; vs CleanBrowsing/AdGuard Family: SafeSearch + proxy blocking at DNS). Recommendation: pick one default,
show a one-line trade-off in the parent flow.

### v2 — the real product

- **Local `dnscrypt-proxy` profile**: family upstreams, upstream's cloaking rules for SafeSearch, `blocked_names`
  with bedtime schedules (`*.youtube.* @time-to-sleep`), DoH/VPN-bypass hostname list, `use-application-dns.net`
  NXDOMAIN, blocked-query log (local).
- **nftables `kids` table** (coexisting with ufw): per-uid 53/853 egress lock; optional strict 80/443 allowlist for
  Guided presets (the single most effective anti-VPN measure without MITM); DNAT kid uid → per-child resolver.
- **Parent CLI**: `omarchy-kids pause 15m | allow example.org | report today` — polkit-gated, systemd timer
  restores filtering; optional ntfy push. Precedents: AdGuard Home / Pi-hole v6 pause APIs.
- **Second net inside the page**: force-install the open-source NSFW Filter extension (local TensorFlow.js
  classifier) — spike CPU cost and false positives first.
- **Family Link spike**: supervised child account in Chromium gives an "ask parent" flow for free — if Arch
  Chromium + Omarchy's OAuth flags support it, and if parents accept a Google account for a child.
- **Per-child profiles**: one resolver instance + one Chromium `--user-data-dir` per child, or NextDNS Pro.
- **"Library" mode** (Discord ask): YouTube blocked entirely; Jellyfin/Kodi kid profile fed by parent-curated media.
  YouTube's ToS forbids automated downloading — document the yt-dlp/Pinchflat pattern with the caveat, never
  automate it as a feature; prefer legally clean sources (PBS, CC, purchased, family videos).

### Explicitly out of scope (v1/v2)

HTTPS interception (e2guardian/Squid+ICAP need a local CA) — OQ-14. Maybe a v3 "school-grade" profile.

## Bypass → mitigation (condensed; full table in report 04 §3)

| Kid does… | Stops it? |
| --- | --- |
| Changes system DNS / edits `/etc/hosts` | Already impossible without sudo |
| Joins a hotspot with its own DNS | Local resolver config + `Domains=~.` + strict DoT travel with the machine |
| Enables DoH in the browser | Policy `DnsOverHttpsMode=off` / Firefox `Locked` |
| Runs a portable browser/AppImage with its own DoH | Per-uid egress lock + `noexec` home (L4) |
| Installs a VPN/proxy extension | `ExtensionInstallBlocklist:["*"]` |
| VPN/Tor client | Per-uid allowlist kills most transports; no root = no TUN; **Tor-over-443 is the residual risk** |
| Incognito / new profile | `IncognitoModeAvailability:1`, `BrowserSignin` policy |
| Boots another OS | L2 |

## Interfaces

Consumes preset (L6) → allowlist/blocklist strength, web-app set (L8), uid (L1). Provides "pause" to L9's parent
actions. Packaged by L11 as `omarchy-kids-web-safety`.

## Residual risks

Category coverage of any provider is "mainstream porn domains", not "everything a parent objects to"; explicit
images on allowed domains (Reddit, Discord CDN, image search) pass DNS — hence SafeSearch + NSFW Filter; any
provider outage or quota cliff must fail **closed** (block) not open.

## Workstreams & backlog seeds (from report 04, renumbered)

NET-01 `omarchy dns` Family preset (PR upstream) · NET-02 Chromium-family policy pack · NET-03 Firefox/Zen pack ·
NET-04 dnscrypt-proxy kids profile · NET-05 nftables `kids` table · NET-06 DoH/VPN hostname list ·
NET-07 `omarchy-kids-check` · NET-08 kids web-app set · NET-09 parent pause/allow/report CLI ·
NET-10 Family Link spike · NET-11 NSFW Filter spike · NET-12 Library-mode design note · NET-13 bypass checklist with a test per row · **NET-14 re-verify DNS pinning under NetworkManager (4.x)**.

## Open questions

OQ-5, OQ-6, OQ-14; plus (report 04): per-user browser policy on Linux — toggle, different browser family per user, or accept machine-wide? Default egress strictness (DNS-only vs 80/443 allowlist)? Who curates lists and how do parents pull updates?
