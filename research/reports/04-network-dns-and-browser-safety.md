# Network, DNS & Browser Safety

_Research report · Omarchy Kids Mode · 2026-09-01 · status: draft_

> **Erratum (added 2026-09-01 by the repo maintainer after cross-checking report 01):** this report's claim that Omarchy ships `iwd` + `systemd-networkd` and *not* NetworkManager was derived from the `master` branch of `omacom/omarchy`, which is the **3.x** line. The **4.x `quattro` branch (default; 4.0.2 is current)** lists `networkmanager` in `install/omarchy-base.packages` and ships `etc/NetworkManager/conf.d/`; `iwd`/`impala` are absent there (verified 2026-09-01 by fetching both package lists). Likewise the script is now `bin/omarchy-dns` (not `omarchy-setup-dns`). systemd-resolved, ufw (allow-out) and Chromium managed policies are unchanged, so the DNS/browser-policy recommendations stand; the **DNS-pinning mechanism** (`UseDNS=no` in networkd `.network` files) must be re-verified against NetworkManager (`ipv4.ignore-auto-dns` / `ipv4.dns-priority`, polkit `org.freedesktop.NetworkManager.settings.modify.system`). Tracked in `docs/architecture/layers/03-network-and-content-filtering.md`.

Scope: what actually stands between a kid on an Omarchy laptop and "that moment when a porn site pops up" — filtering DNS, local resolvers, bypass enforcement, SafeSearch/Restricted-Mode enforcement, browser policy, kid-versions of services, content-aware filtering, and parent UX. Every claim below is tagged with a source; sources are graded VERIFIED (fetched and read), SEARCH-ONLY (seen in search-result snippets, not fetched), or DEAD-UNVERIFIABLE. Nothing in the prior blueprint was trusted without re-checking.

## TL;DR

- **Omarchy's network stack is NOT NetworkManager.** It ships `iwd` + `systemd-networkd` + `systemd-resolved` (stub `/etc/resolv.conf`), a `ufw` firewall that allows all outbound, and a first-party `omarchy-setup-dns` script that already writes `/etc/systemd/resolved.conf` with DoT and locks DHCP DNS off via `UseDNS=no` [S30–S34]. The blueprint's "omarchy-clarity + dnscrypt-proxy" integration does not exist in the repo.
- **Fastest credible v1 quick win (hours, not weeks):** add a `Family` option to `omarchy-setup-dns` pointing resolved at Cloudflare `1.1.1.3#family.cloudflare-dns.com` with `DNSOverTLS=yes` [S1, S2, S26], plus a Chromium managed-policy JSON in `/etc/chromium/policies/managed/` that sets `DnsOverHttpsMode: "off"`, `ForceGoogleSafeSearch`, `ForceYouTubeRestrict`, kills Incognito/DevTools/extension installs [S47, S48]. Kid is unprivileged and cannot undo either.
- **Cloudflare for Families is a fine default but is a blunt instrument:** two fixed tiers, no allow/deny customization, no SafeSearch enforcement, no per-child profiles [S1, S2]. Quad9 does **no** adult filtering at all [S3] — drop it from the kids shortlist. CleanBrowsing Family and AdGuard Family both enforce SafeSearch/YouTube Restricted at the DNS layer for free [S7, S9]; NextDNS adds per-profile parental controls, Recreation Time, and configurable logging, capped at 300k queries/month on the free tier (after which it silently stops filtering) [S4, S5, S6].
- **A local `dnscrypt-proxy` (Arch `extra`, 2.1.18) is the right v1.5 spine:** it can forward to `cloudflare-family` / `adguard-dns-family-doh` / `cleanbrowsing-family-doh` (all in its built-in resolver list), ships example cloaking rules that force Google/Bing/DDG/YouTube SafeSearch via CNAME, and supports time-scheduled block rules (`*.youtube.* @time-to-sleep`) [S17–S21]. Filtering then travels with the laptop to any Wi-Fi/hotspot — a Pi-hole does not.
- **DoH bypass is solved by browser policy, not by IP blocking.** Chrome's automatic DoH only "upgrades" when the system resolver is a known DoH provider (a local 127.0.0.x resolver never qualifies) and explicitly refuses to honor Firefox's canary domain [S50]; the `DnsOverHttpsMode=off` policy closes the manual-override hole. Firefox needs `DNSOverHTTPS: {Enabled:false, Locked:true}` [S52]. Blocking DoH by IP is whack-a-mole with collateral damage: `cloudflare-dns.com` resolves to 104.16.x CDN space (observed today) while `family.cloudflare-dns.com` resolves to 1.1.1.3 [S84].
- **SafeSearch via DNS CNAME is officially supported by Google (with HTTPS intact — Google calls it "SafeSearch VIP"), YouTube (five specific hostnames → `restrict.youtube.com` / `restrictmoderate.youtube.com`), and DuckDuckGo (`safe.duckduckgo.com`)** [S12, S13, S14]; Bing's `strict.bing.com` is documented by Microsoft and third parties but was not fetched (SEARCH-ONLY) [S15, S16].
- **DNS-rewriting `youtube.com` → `youtubekids.com` cannot work** — and today both hostnames resolve to the *same* Google front-end (`youtube-ui.l.google.com`); routing is by Host header/certificate, not IP [S84]. Use `URLBlocklist` + a YouTube Kids web app instead. YouTube Kids works on the web without sign-in, with a parent age gate and content-level picker; sign-in unlocks the rest [S67].
- **Family Link is a real, underused lever:** a supervised child account signed into Chrome on Linux gets site block/allow lists, "try to block explicit sites", and an *approve/deny request* flow — the "ask parent" UX for free — but only inside Chrome while signed in; the child can sign out or use another browser unless policy forbids it [S69]. Whether Arch's Chromium (which needs Omarchy's OAuth-key script to sign in at all) supports supervised profiles is untested [S85].
- **Content-aware filtering (e2guardian/Squid+ICAP) requires a local MITM CA** — out of scope for v1. A realistic v2 "second net" is the open-source **NSFW Filter** Chrome extension (local TensorFlow.js ViT model, v3.0.0, 1.8k stars) force-installed by policy [S75].
- **Parent-UX precedents exist and are API-shaped:** AdGuard Home `POST /control/protection {enabled:false, duration:ms}`, per-client `parental_enabled`/`safe_search`/`blocked_services_schedule` [S63]; Pi-hole v6 `POST /api/dns/blocking {blocking:false, timer:s}` [S64–S66]. Our local resolver needs an equivalent polkit-gated helper.
- **Omarchy's own web-app mechanism is the right container for "kids versions" but shares one Chromium profile and had a `javascript:`/`file:` URL injection bug fixed 2026-08-27** [S35, S36, S41, S42]. Per-app profile isolation was requested and closed (#1384) [S43].

## Findings

### 1. Filtering DNS providers

| Provider / tier | IPv4 | Encrypted endpoint | Adult coverage | SafeSearch / YT Restricted enforced by DNS | Customization | Logging / privacy | Cost | Kid-bypass resistance | Src |
|---|---|---|---|---|---|---|---|---|---|
| **Cloudflare 1.1.1.1 for Families – Malware** | 1.1.1.2 / 1.0.0.2 | DoH `https://security.cloudflare-dns.com/dns-query`, DoT `security.cloudflare-dns.com` | none | no | none (two fixed tiers; "contact us" / Zero Trust for more) | not documented on the pages fetched | free | same as any public resolver: only as strong as the OS lock | S1, S2 |
| **Cloudflare 1.1.1.1 for Families – Malware + Adult** | 1.1.1.3 / 1.0.0.3 (v6 `2606:4700:4700::1113/::1003`) | DoH `https://family.cloudflare-dns.com/dns-query`, DoT `family.cloudflare-dns.com` | "adult content" (single category, definition not published) | **no** | none | not documented on pages fetched | free | — | S1, S2 |
| **Quad9** (9.9.9.9 / dns.quad9.net) | 9.9.9.9, 149.112.112.112 | DoH `https://dns.quad9.net/dns-query`, DoT `dns.quad9.net` | **none — malware/phishing only** | no | none | (not assessed) | free | — | S3 |
| **OpenDNS FamilyShield** | 208.67.222.123 / 208.67.220.123 | not confirmed (official router page now redirects to Cisco community) | Pornography, Nudity, Sexuality, Proxy/Anonymizer (per OpenDNS community answers) | not stated | none at those IPs; dashboard cannot un-block FamilyShield categories | Cisco account for stats | free | blocks anonymizers (helps vs bypass) | S10, S11 (SEARCH-ONLY / DEAD) |
| **AdGuard DNS – Family Protection** | 94.140.14.15 / 94.140.15.16 (v6 `2a10:50c0::bad1:ff/::bad2:ff`) | DoH `https://family.adguard-dns.com/dns-query`, DoT `tls://family.adguard-dns.com`, DoQ, DNSCrypt stamp published | "adult content" + ads/trackers/malware | **yes** — "enable Safe Search and Safe Mode, where possible" | none on public tier (private AdGuard DNS tier exists; limits not verified) | not assessed | free | — | S7, S8 |
| **CleanBrowsing – Family** | 185.228.168.168 / 185.228.169.168 | DoH `https://doh.cleanbrowsing.org/doh/family-filter/`, DoT `family-filter-dns.cleanbrowsing.org` | "all adult, pornographic and explicit sites" + **proxies/VPNs** + mixed-content platforms | **yes** — Google, Bing, YouTube Restricted | none free; paid unlocks 21+ filters and customization | free tier "throttled", no support | free / paid | blocks proxies/VPNs at DNS (good) | S9 |
| **CleanBrowsing – Adult** | 185.228.168.10 / 185.228.169.11 | DoH `…/adult-filter/` | adult only; allows VPN/proxies/Reddit | Google, Bing | none | — | free | weaker | S9 |
| **NextDNS** | per-profile (config ID) | DoH/DoT per profile | Parental Control: porn, violence, piracy… + block specific sites/apps/games | **yes** — SafeSearch "on all search engines", YouTube Restricted Mode | **per-profile**, Recreation Time (time-of-day allow windows), unlimited configurations | retention 1 h – 2 y or off; US/EU/UK/CH residency | free to **300k queries/month, then becomes a plain non-filtering resolver** (email at 250k/300k); Pro $1.99/mo unlimited | per-profile IDs make per-child profiles easy; also markets a "block bypass methods" option (not verified this pass) | S4, S5, S6 |

Observations:
- **Only CleanBrowsing Family, AdGuard Family and NextDNS enforce SafeSearch at the DNS layer.** With Cloudflare Family you must enforce SafeSearch yourself (browser policy or local cloaking).
- **The free-tier quota cliff at NextDNS is a safety bug for a kids product**: filtering silently disappears at 300k queries [S5]. A laptop with a modern browser can plausibly hit that in a busy month. Either pay $1.99/mo or don't make NextDNS the sole layer.
- Category definitions ("adult") are not published by Cloudflare; treat its coverage as "mainstream porn domains", not "everything a parent would object to".
- All of these are only as strong as the local lock: on Omarchy the kid user has no sudo, so `resolved.conf` and `.network` files are already out of reach [S30]. The threat is *application-level* DNS (DoH in the browser, VPN clients, Tor), addressed in §3.

### 2. Local resolvers and what Omarchy actually ships

**Omarchy ground truth (repo `omacom/omarchy`, formerly `basecamp/omarchy`; latest release v4.0.2, 2026-08-31 [S45]):**
- Wi-Fi: `iwd` (enabled in `install/config/hardware/network.sh`), with `systemd-networkd`; `systemd-networkd-wait-online` masked [S31, S34]. `impala` is the TUI Wi-Fi picker [S34]. **No NetworkManager** in `omarchy-base.packages` [S34], so the NetworkManager/polkit pinning question is moot for stock installs.
- Resolver: `systemd-resolved`, with `/etc/resolv.conf → /run/systemd/resolve/stub-resolv.conf` (i.e. apps query `127.0.0.53`) [S32].
- `bin/omarchy-setup-dns [Cloudflare|Google|DHCP|Custom]` (requires sudo) overwrites `/etc/systemd/resolved.conf` with e.g. `DNS=1.1.1.1#cloudflare-dns.com … FallbackDNS=9.9.9.9#dns.quad9.net … DNSOverTLS=opportunistic`, and its `lock_dns_to_resolved` function inserts `UseDNS=no` under `[DHCPv4]` and `[IPv6AcceptRA]` in every `/etc/systemd/network/*.network` so DHCP-supplied DNS is ignored [S30]. This is exactly the "pin DNS so the network can't override it" mechanism we need — it already exists; Kids Mode should add a `Family` (and later `Kids`) option rather than build a parallel system.
- Firewall: `ufw` + `ufw-docker`, `default deny incoming`, **`default allow outgoing`**, LocalSend and Docker-DNS exceptions [S33]. Egress restrictions are additive work.
- Browser: `chromium` (Arch `extra`, 152.0.7977.64 today) is in base packages and is "the default browser… what every web app runs inside" [S34, S40, S23]. Flags in `~/.config/chromium-flags.conf`: Wayland ozone + `--load-extension=` of Omarchy's `copy-url` extension [S38]. Firefox/Zen are installable alternatives but "a different family" without Omarchy extensions/theming [S40].
- Google sign-in in Chromium is off until the parent runs `omarchy-install-chromium-google-account`, which appends OAuth client id/secret flags [S85].

**resolved.conf facts we rely on** (systemd `resolved.conf(5)`) [S26]:
- `DNS=` accepts `ip[:port][%ifname][#sni]`, so `1.1.1.3#family.cloudflare-dns.com` is a valid DoT target; `DNSOverTLS=yes|opportunistic|no`; `DNSSEC=`; `FallbackDNS=` only used when nothing else is configured; drop-ins in `/etc/systemd/resolved.conf.d/`.
- Precedence rule: per-link DNS from networkd/NM wins over global `DNS=` unless `Domains=~.` is set on the global config — which is why `omarchy-setup-dns` neuters per-link DNS at the source with `UseDNS=no`. A Kids Mode drop-in should do both (`UseDNS=no` and `Domains=~.`) for belt-and-braces.

**Option A — resolved-only (v1):** `DNS=1.1.1.3#family.cloudflare-dns.com 1.0.0.3#family.cloudflare-dns.com …`, `DNSOverTLS=yes` (strict, not opportunistic, so a hostile network can't downgrade), `FallbackDNS=` pointed at another *family* resolver (e.g. AdGuard Family 94.140.14.15#family.adguard-dns.com) — never at an unfiltered one. Pros: ~10-line change to an existing script; no new daemon. Cons: no SafeSearch enforcement, no local block/allow lists, no schedules, no logs.

**Option B — local `dnscrypt-proxy` (v1.5/v2):** package `extra/dnscrypt-proxy` 2.1.18 [S21]. Relevant config from the upstream example TOML [S17]:
- `server_names = ['cloudflare-family', 'adguard-dns-family-doh', 'cleanbrowsing-family-doh']` — all present in the built-in `public-resolvers.md` list (as are `nextdns`, `quad9-*`, `cloudflare-security`) [S20].
- `[blocked_names] blocked_names_file` with patterns `*sex*`, `ads.*`, `=example.com` (exact), `*.example.com`, plus **time schedules** via suffix: `*.youtube.* @time-to-sleep`, with `[schedules] time-to-sleep = {after='21:00', before='7:00'}` [S17, S19]. `[allowed_names]` overrides; `[blocked_ips]`; `block_ipv6`.
- `cloaking_rules` file: upstream's example already contains `www.google.* forcesafesearch.google.com`, `www.bing.com strict.bing.com`, `=duckduckgo.com safe.duckduckgo.com`, and `www.youtube.com`/`m.youtube.com` → `restrictmoderate.youtube.com` [S18]. This is SafeSearch enforcement in five lines.
- `forwarding_rules` to send specific domains to specific servers (e.g. LAN names to the router).
- Wiring: run dnscrypt-proxy on `127.0.0.1:53` (or 5353) and set `resolved.conf` `DNS=127.0.0.1` `DNSOverTLS=no` `Domains=~.`; or bypass the stub entirely. ArchWiki's page on socket-activation vs service and the systemd-resolved interop notes could not be fetched (Anubis anti-bot wall) [S24, S25] — **needs a hands-on test**; the blueprint's `dnscrypt-proxy.service.d/override.conf` target is plausible but unverified.

**Option C — Pi-hole / AdGuard Home on the LAN:** best per-device/per-client profiles (AdGuard Home: `clients` with `parental_enabled`, `safe_search{google,youtube,bing,duckduckgo…}`, `blocked_services` + `blocked_services_schedule`, per-client `upstreams`) [S63]; Pi-hole v6 has groups and a REST API [S64]. But it does not travel: the kid's laptop at grandma's house or on a phone hotspot is unfiltered. For a laptop product, LAN appliances are a *parent-optional* upgrade, not the base.

**NetworkManager (only if a parent installs it):** `ipv4.dns`, `ipv4.ignore-auto-dns`, `ipv6.*` equivalents, `ipv4.dns-priority` (negative = exclusive), and `connection.permissions` (`user:<name>`) exist to pin DNS per connection [S28]. Modifying system connections is gated by polkit action `org.freedesktop.NetworkManager.settings.modify.system` (default `auth_admin_keep`), so an unprivileged kid already cannot change DNS; do not loosen it [S29, SEARCH-ONLY].

### 3. Enforcement against bypass

Threat model: the kid is an unprivileged local user (cannot write `/etc/hosts`, `resolved.conf`, policy dirs, or `/etc/systemd/network/*`), may be technically curious, may have a phone hotspot, may download portable binaries into `$HOME`.

| Bypass | Works against DNS-only setup? | Mitigation | Status |
|---|---|---|---|
| Change system DNS | No — needs sudo (`omarchy-setup-dns` requires it; networkd files root-owned) [S30] | Keep as is; add `Domains=~.` | VERIFIED |
| Join another Wi-Fi / phone hotspot with its own DNS | **Yes** if filtering lives on the router/Pi-hole; **No** if resolver is local (`UseDNS=no` + local dnscrypt-proxy/resolved config travels with the machine) [S30, S26] | Local resolver; `DNSOverTLS=yes` strict so a hostile network can't intercept | VERIFIED (mechanism) |
| Plain DNS to 8.8.8.8 on port 53 from a script/app | Yes | nftables egress: drop `udp/tcp dport 53` and `853` unless `ip daddr 127.0.0.0/8` (and the resolver's own upstream if it uses 53/853 — allow by `meta skuid dnscrypt` / `systemd-resolve`) [S60, S61] | syntax VERIFIED; rules untested |
| Browser DoH (Chrome/Chromium/Brave) | Automatic mode won't upgrade a local/unknown resolver [S50, S77]; but user can pick a custom DoH provider in settings | Policy `DnsOverHttpsMode: "off"` (values `off`/`automatic`/`secure`; "if unset, for managed devices DoH queries will not be sent") [S47]; Brave reads `/etc/brave/policies/managed/` and supports Chromium policies [S51] | VERIFIED |
| Browser DoH (Firefox/Zen) | Firefox may enable DoH by default in some regions [S78]; honors canary only in default mode, ignores it when user opts in [S57, S82] | Policy `DNSOverHTTPS: {"Enabled": false, "Locked": true}` [S52]; additionally answer `use-application-dns.net` with NXDOMAIN at the local resolver (dnscrypt-proxy `blocked_names`) as defense-in-depth; note Chrome "has no plans to support" the canary [S50] | VERIFIED |
| Blocking DoH by destination IP | Poor: `cloudflare-dns.com` → 104.16.248/249.249 (Cloudflare CDN space); NextDNS/others are anycast; collateral damage to unrelated sites [S62, S84]. Exception: dedicated resolver IPs (1.1.1.1, 8.8.8.8, 9.9.9.9) are safe to block. | Prefer resolver-level blocking of DoH **hostnames** (dnscrypt-proxy `blocked_names` from a community DoH/VPN-bypass list) + browser policy; use IP blocks only for the well-known dedicated resolver IPs | VERIFIED (observation) |
| Portable browser / AppImage with its own DoH | Yes | Per-uid nftables (kid uid may only talk tcp 80/443, udp 443/QUIC, and 127.0.0.0/8:53) + hostname blocking of DoH endpoints; `noexec` home is a sandboxing-report topic | design only |
| VPN / proxy / Tor | Yes (WireGuard/OpenVPN UDP, Tor bridges over 443) | Per-uid egress allowlist kills most VPN transports; choose a DNS provider that blocks proxy/VPN/anonymizer categories (CleanBrowsing Family, OpenDNS FamilyShield) [S9, S10]; Tor-over-443 remains the residual risk; no root = no TUN device | partial |
| Browser extension that is a VPN/proxy | Yes | `ExtensionInstallBlocklist: ["*"]` ("all extensions blocked by default… all unpacked extensions are blocked") + `ExtensionInstallForcelist` for approved ones [S47]; Firefox `ExtensionSettings {"*": {"installation_mode": "blocked"}}` [S54]. **Caveat:** Omarchy loads its own unpacked `copy-url` extension via `--load-extension` [S38]; a `*` blocklist will disable it — either allowlist by ID or drop it in Kids Mode | VERIFIED (policy text) |
| Edit `/etc/hosts` | No (root-owned) | — | trivially true |
| Incognito / guest / new profile to dodge sign-in-bound controls | Yes for Family Link–style controls [S69] | `IncognitoModeAvailability: 1`, `BrowserSignin: 2` (force) or `0` (disable) [S47]; profile-switch policies to be verified | VERIFIED (values) |
| Kid boots another OS / recovery | out of scope here (see boot/security report) | — | — |

**nftables sketch (untested; syntax per [S60])**, intended to coexist with ufw by living in its own table:

```text
table inet kids {
  chain output {
    type filter hook output priority 0; policy accept;
    meta skuid kid udp dport 53 ip daddr != 127.0.0.0/8 drop
    meta skuid kid tcp dport 53 ip daddr != 127.0.0.0/8 drop
    meta skuid kid tcp dport 853 drop
    meta skuid kid udp dport 853 drop
  }
}
```

A stricter variant flips the kid's policy to an allowlist (80/443 tcp, 443 udp, loopback) — this is the single most effective anti-VPN measure available without a MITM proxy. Both need testing against ufw's iptables-nft tables on Arch (`nftables` 1.1.6 in `extra` [S22]).

### 4. SafeSearch and Restricted-Mode enforcement via DNS CNAME

| Service | Official hostname(s) | Official instruction | HTTPS/HSTS | Src |
|---|---|---|---|---|
| Google Search | `forcesafesearch.google.com` | "Set the DNS entry for www.google.com (and any other Google country or region domains…) to be a CNAME for forcesafesearch.google.com." Covers Search, Image and Video search. | Google: "leverages SafeSearch VIP to force all users… to use SafeSearch on Google Search **while still allowing a secure connection via HTTPS**" — the VIP serves valid `www.google.com` certs, so HSTS is unaffected | S12 (VERIFIED) |
| YouTube | `restrict.youtube.com` (Strict), `restrictmoderate.youtube.com` (Moderate) | CNAME **exactly** `www.youtube.com`, `m.youtube.com`, `youtubei.googleapis.com`, `youtube.googleapis.com`, `www.youtube-nocookie.com`; "Don't give a CNAME to other YouTube hostnames, such as youtube.com, s.ytimg.com, youtu.be, googleapis.com, youtubeeducation.com". Alternative: inject header `YouTube-Restrict: Strict\|Moderate` (needs MITM). | Same VIP model | S13 (VERIFIED) |
| DuckDuckGo | `safe.duckduckgo.com` | "Set the DNS entry for duckduckgo.com to the safe.duckduckgo.com CNAME" (also `&kp=1` URL param; `!safeoff` bang exists and is disabled by the CNAME) | works per DDG | S14 (VERIFIED) |
| Bing | `strict.bing.com` | Map `www.bing.com` (and `edgeservices.bing.com` for the Edge sidebar) to a CNAME for `strict.bing.com` | claimed to work; Microsoft page not fetched | S15, S16 (SEARCH-ONLY) |

Local resolution today (from this machine, 2026-09-01): `forcesafesearch.google.com` and `restrict.youtube.com` both → `216.239.38.120`; `restrictmoderate.youtube.com` → `216.239.38.119`; `strict.bing.com` → CNAME chain into `ax-msedge.net`; `safe.duckduckgo.com` → `40.89.244.237` [S84]. dnscrypt-proxy's cloaking file implements exactly these mappings [S18]. Note that cloaking with an **IP** (as dnscrypt-proxy does when it flattens the CNAME) breaks if Google renumbers the VIP — Google's own advice is "use a CNAME rather than the IP"; dnscrypt-proxy can cloak to a name and resolve it, so prefer the name form.

Browser-side equivalents (Chromium family, machine-wide): `ForceGoogleSafeSearch: true`; `ForceYouTubeRestrict: 2` (Strict) or `1` (Moderate — "user may only pick Moderate… but can't turn off Restricted mode") [S47]. Use **both** DNS and policy: DNS catches every app on the box (including web apps, Electron apps, other browsers); policy catches the case where DNS is somehow bypassed.

### 5. Browser policy management on Linux

**Chromium/Chrome/Brave:** policies are JSON files in `/etc/chromium/policies/managed/` (Chromium), `/etc/opt/chrome/policies/managed/` (Chrome), `/etc/brave/policies/managed/` (Brave); "files under /managed are not writable by non-admin users"; split across files freely but don't define the same key twice [S48, S51]. Verified policy semantics (from Chromium's own `policy_definitions` YAML) [S47]:

| Policy | Kid-safe value | Notes |
|---|---|---|
| `URLBlocklist` / `URLAllowlist` | Blocklist `["youtube.com", "m.youtube.com", …]` or, for young kids, blocklist `["*"]` + allowlist of approved sites | `URLAllowlist` "takes precedence", "most specific filter" wins, **1,000 entries max**; does not stop XHR to blocked paths; from v147 `*` alone no longer covers `chrome://*` (use explicit `chrome://*`) |
| `DnsOverHttpsMode` | `"off"` | see §3 |
| `ForceGoogleSafeSearch` | `true` | |
| `ForceYouTubeRestrict` | `2` (or `1`) | |
| `IncognitoModeAvailability` | `1` (Disabled) | |
| `DeveloperToolsAvailability` | `2` (Disallowed) | policy doc says prefer this over blocking `devtools://*` |
| `ExtensionInstallBlocklist` | `["*"]` | blocks unpacked too — conflicts with Omarchy's `--load-extension` `copy-url` [S38] |
| `ExtensionInstallForcelist` | approved IDs (ad blocker; NSFW Filter in v2) | uBlock Origin (MV2) availability in current Chromium is not verified here — check MV3 alternatives before committing |
| `BrowserSignin` | `0` (no Google sign-in) or `2` (force sign-in, for Family Link supervision) | product decision, see §6 |
| `DownloadRestrictions` | `3` (block all) for young kids, `1`/`4` otherwise | |
| `SafeBrowsingProtectionLevel` | `1` (Standard) — `2` sends more data to Google | |
| `HomepageLocation` / `NewTabPageLocation` | kids launcher page | names taken from the task brief; not individually re-verified |

**Crucial constraint: Linux Chromium policy is machine-wide, not per-user.** Parent and kid share `/etc/chromium/policies/managed/`. Options: (a) Kids Mode toggles the policy file in/out (parent runs a polkit-gated command); (b) parent uses a different browser family (Firefox/Brave/Chrome read different policy dirs — Omarchy already supports switching default browser [S37, S40]); (c) per-user wrapper — unverified whether Chromium honors any env/flag to relocate the policy dir. Flag as an open question.

**Firefox/Zen:** `policies.json` at `/etc/firefox/policies/policies.json` (system-wide, distro-independent) or `/usr/lib/firefox/distribution/policies.json` on Arch [S58, S59 SEARCH-ONLY]. Verified policies [S52–S55]: `WebsiteFilter {"Block": ["<all_urls>"], "Exceptions": ["https://example.org/*"]}` (match-pattern syntax, **1,000 entries per array**, "a single wildcard `*` as a value is not sufficient"); `DisablePrivateBrowsing`; `DNSOverHTTPS {Enabled, ProviderURL, Locked, ExcludedDomains, Fallback}`; `ExtensionSettings {"*": {"installation_mode": "blocked"}, "uBlock0@raymondhill.net": {"installation_mode": "force_installed", "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"}}`; `SearchEngines`; `Homepage`; `DisableDeveloperTools`. Mozilla's old `policy-templates` README now points to `firefox-admin-docs.mozilla.org` [S56]. Firefox has no `ForceGoogleSafeSearch` equivalent → DNS cloaking is the enforcement path there. Zen is a Firefox fork; policy support assumed, unverified.

**Omarchy web apps** [S35, S36, S39, S41]: `omarchy-webapp-install NAME URL ICON` writes `~/.local/share/applications/NAME.desktop` whose `Exec` is `omarchy-launch-webapp URL`; that script resolves the default browser (falls back to `chromium.desktop` unless it's chrome/brave/edge/opera/vivaldi/helium) and execs it with `--app="$URL"` under `uwsm-app`. Icons are fetched from Google's favicon service. Stock web apps include YouTube, ChatGPT, Discord, X, WhatsApp — most of which a Kids Mode must **remove** (`omarchy-webapp-remove-all` exists). Web apps share the main Chromium profile (the manual says to log into accounts in the regular browser first), so managed policies apply inside them — good. Security note: until 2026-08-27 the installer accepted `javascript:`, `file:` and `data:` URLs into `--app=` (issue #8495, closed) [S42]; a Kids Mode installer should whitelist `https://` only. Per-app `--user-data-dir` isolation was proposed (#1384, closed) [S43]; a Firefox-based web-app wrapper with a dedicated profile is documented by a community member (discussion #2468) [S44].

### 6. "Kids versions" of services

- **YouTube Kids on the web** (`www.youtubekids.com`): "You can watch videos on YouTube Kids on the web"; sign-in optional ("choose whether or not to sign in to get greater access to features and parental controls"); parent enters birth year; pick a content level; Search can be turned off; web lacks offline mode, voice search and **timer** [S67, S68]. Best delivered as an Omarchy web app plus `URLBlocklist` of `youtube.com`/`m.youtube.com` (and `youtu.be`). **Do not attempt a DNS rewrite** `youtube.com → youtubekids.com`: HTTPS certificates bind to the requested hostname, and today `www.youtubekids.com` resolves to the same `youtube-ui.l.google.com` front-end as YouTube — the server distinguishes them by Host/SNI, so a DNS rewrite is a no-op at best and a certificate error at worst [S84].
- **Google supervised accounts / Family Link on Linux Chrome** [S69]: the child can sign in; parent can "select a content filter to block or allow certain sites", "try to block explicit sites", "allow or block specific sites", and "approve or deny requests from your child to visit blocked sites"; but "your child can sign out of Chrome and switch to other profiles… They may also have access to other browsers where Family Link settings for Chrome won't apply." Combined with `BrowserSignin: 2` and blocking other browsers, this yields a first-party "ask parent" flow. Unknown: whether Arch Chromium with Omarchy's OAuth flags [S85] supports supervised-user features (Chrome-only code paths are common). **Needs a test.**
- **PBS Kids, Khan Academy Kids, Scratch**: not researched in this pass (owned by the education/apps report); note only that Khan Academy Kids is primarily an app, so web availability must be checked before promising it.
- **The yt-dlp curated-library idea** (block YouTube entirely; parent curates local videos):
  - Feasibility: high. Pinchflat (5.3k stars, AGPL-3.0, single Docker container, yt-dlp under the hood, "perfect for… Plex, Jellyfin, or Kodi", channel/playlist rules on a schedule, README warns it's "in active development and anything can break at any time") [S71]; Tube Archivist (three containers, heavier, full-text search; users report using it "to download videos for their kids") [S72, SEARCH-ONLY]. A non-Docker path is plain `yt-dlp` + a playlist file + a Jellyfin/Kodi kids library; Jellyfin has per-user parental ratings/libraries (not verified this pass).
  - Legal/ToS: YouTube's Terms forbid users to "access, reproduce, download, distribute… any part of the Service or any Content except: (a) as expressly authorized by the Service; or (b) with prior written permission from YouTube" and to "access the Service using any automated means (such as robots, botnets or scrapers)" [S70]. The community project must therefore not ship or automate YouTube downloading as an official feature; it can document the pattern as a parent-side option with the ToS caveat stated, and should prefer legally clean sources (PBS, Creative Commons, purchased media, the family's own videos).
  - UX: this is the only option that fully removes autoplay/recommendation risk, and it works offline. It costs the parent curation time. Reasonable as a v2 "Library" workstream with a Kodi/Jellyfin kid profile.

### 7. Content-aware filtering beyond DNS

- **The HTTPS elephant:** DNS and browser policy see hostnames and URLs, not page content. Anything that inspects content on the wire (e2guardian, Squid + ICAP, DansGuardian's descendants) must terminate TLS with a locally trusted CA. That means generating a CA, installing it into the system and browser trust stores, breaking certificate pinning on some apps, and taking on a privacy/complexity burden no volunteer community should ship by default. **Out of scope for v1.**
- **e2guardian** is alive: v5.5.9r released 2025-08-22, repo updated Nov 2025, in the AUR; supports explicit/transparent proxy and ICAP; filters by URL, phrases, MIME, with generated certs for HTTPS [S73, S74, SEARCH-ONLY]. Candidate for a v3 "school-grade" profile, not for parents.
- **On-device image classifiers** are the realistic middle path: **NSFW Filter** (Chrome extension, "images are classified on your device with TensorFlow.js. Nothing is uploaded", ships a ViT-384 model and the original NSFWJS MobileNet, hides images until classified as safe, v3.0.0, 1.8k stars, Chrome-only per README) [S75]; underlying `nsfwjs` (~90–93% accuracy claims, five classes) and `NudeNet` for detection [S76, SEARCH-ONLY]. Force-install via `ExtensionInstallForcelist` gives a second net *inside the page* — the only layer that can act on an explicit image that arrives from an otherwise-allowed domain (Reddit, Discord CDN, image search). Expect false positives (artwork, swimwear) and CPU cost on old laptops.
- **ML URL classification** as a community deliverable: not recommended; the existing category feeds (NextDNS/CleanBrowsing/AdGuard/hagezi-style lists) already do this with far more data.

### 8. Parent UX precedents

| Need | Precedent | Mechanism | Src |
|---|---|---|---|
| "Pause filtering for N minutes" | AdGuard Home | `POST /control/protection {"enabled": false, "duration": <ms>}` | S63 |
| | Pi-hole v6 | `POST /api/dns/blocking {"blocking": false, "timer": <seconds>}` with session `sid`; a 2025 FTL issue reported the timer being ignored in one build | S64, S65, S66 (SEARCH-ONLY for timer) |
| | NextDNS | no official pause; recurring feature request | S5 (help center, SEARCH-ONLY) |
| | Local dnscrypt-proxy | none built in → we build a polkit-gated `omarchy-kids-pause <minutes>` that swaps the blocklist/cloaking symlink and reloads, with a systemd timer to restore | design |
| Per-child profiles | NextDNS "as many configurations as you want"; AdGuard Home per-client `parental_enabled`, `safe_search`, `blocked_services_schedule`, `upstreams` | profile = resolver config; locally: one dnscrypt-proxy instance per child on `127.0.0.N`, selected per uid via nftables DNAT (untested) | S4, S63 |
| Time windows | NextDNS Recreation Time; AdGuard Home blocked-services schedule; dnscrypt-proxy `@schedule` suffix | | S4, S63, S17 |
| "Ask parent" for a blocked site | Family Link on Chrome (approve/deny requests) | first-party; needs signed-in child | S69 |
| Activity/report visibility | NextDNS analytics/logs (1 h–2 y retention or off); AdGuard Home `/control/querylog`; dnscrypt-proxy `blocked_names` `log_file` | local log → nightly digest | S4, S63, S17 |
| Notification | push via a self-hosted/hosted notifier such as ntfy (not researched here) | hook on blocked-query log | — |

## Blueprint claims checked

| Claim (blueprint §3.3 / BACK-07 / §8) | Verdict | Evidence |
|---|---|---|
| "Integrates directly with the `omarchy-clarity` system using dnscrypt-proxy" | **Unfounded.** No `clarity` anything in the Omarchy tree (1,389 paths); DNS is handled by `omarchy-setup-dns` writing `systemd-resolved` config with DoT | S30, S32, S34 |
| Omarchy uses NetworkManager (implicit in "polkit for NetworkManager" framing) | **False for stock Omarchy.** `iwd` + `systemd-networkd` + `systemd-resolved`; no NetworkManager in base packages | S31, S34 |
| Kids can bypass local DNS filters by enabling DoH in browsers | **True**, but the fix is policy (`DnsOverHttpsMode=off`, Firefox `DNSOverHTTPS.Locked`), not firewalling | S47, S50, S52 |
| Drop outbound connections to "known public DoH endpoint IPs (1.0.0.1, 8.8.4.4, NextDNS)" | **Partly wrong.** Dedicated resolver IPs can be blocked, but DoH hostnames commonly resolve to shared CDN/anycast space (`cloudflare-dns.com` → 104.16.x today); blocking by IP is incomplete and causes collateral damage | S62, S84 |
| Block all outbound port 53 except to `127.0.0.1` | **True with corrections:** Omarchy apps use the resolved stub at `127.0.0.53`; also block 853; do it per-uid so the resolver itself can reach upstream; ufw is already installed with allow-all egress | S32, S33, S60 |
| Use "iptables or nftables" | **OK.** `nftables` 1.1.6 is in `extra`; ufw (iptables-nft backend) already owns some tables — coexistence needs testing | S22, S33 |
| BACK-07: force dnscrypt-proxy via `/etc/systemd/system/dnscrypt-proxy.service.d/override.conf` | **Unverified.** Package exists (2.1.18, `extra`); socket-vs-service activation and the resolved handoff could not be verified (ArchWiki blocked); plausible but must be tested | S21, S24 |
| Bibliography entries `…/chrome/a/answer/123456`, `lwn.net/Articles/123456`, `reddit.com/…/12345`, `forum.qubes-os.org/…/12345`, `community.home-assistant.io/…/123456` | **Fabricated placeholders** (sequential digits). Not cited here | blueprint §8 |
| Bibliography: Chromium "Configuring Apps and Extensions by Policy", "Linux Quick Start", Mozilla policy-templates, AdGuardHome issue #1333, NextDNS "can be bypassed easily" thread | **Plausible but unverified** — only the Linux quick-start path and policy-templates README were fetched | S48, S56 |
| SafeSearch/YouTube Restricted CNAME approach works over HTTPS | **True** — Google documents it explicitly ("while still allowing a secure connection via HTTPS") | S12, S13 |
| Cloudflare sponsors Omarchy | **True** — blog post dated 2025-09-22 names Omarchy and Ladybird, "no strings attached" | S46 |

## Implications & recommendations

**Design principles that fall out of the evidence**
1. Filtering must live **on the laptop**, not on the router — kids roam. Omarchy's `UseDNS=no` lock is the anchor.
2. Layer, don't pick: DNS (broad, every app) + browser policy (precise, closes DoH/incognito/extension holes) + egress firewall (closes app-level bypass). Each layer is a small, testable artifact.
3. Prefer editing what Omarchy already has (`omarchy-setup-dns`, `omarchy-webapp-install`, `chromium-flags.conf`, ufw) over parallel infrastructure; upstream-friendly PRs beat a fork.
4. Never let a "safe" layer fail open silently (NextDNS free quota; `DNSOverTLS=opportunistic`; `FallbackDNS` to an unfiltered resolver).

**v1 — the quick win ("no porn pop-ups", one afternoon for a parent, one week for the community)**
- `omarchy-setup-dns Family`: `DNS=1.1.1.3#family.cloudflare-dns.com 1.0.0.3#family.cloudflare-dns.com 2606:4700:4700::1113#family.cloudflare-dns.com …`, `FallbackDNS=94.140.14.15#family.adguard-dns.com …`, `DNSOverTLS=yes`, `Domains=~.`; keep `lock_dns_to_resolved`. (Alternative default for stronger coverage + DNS-level SafeSearch: CleanBrowsing Family or AdGuard Family; make it a menu choice with a one-line explanation of each.)
- `/etc/chromium/policies/managed/omarchy-kids.json` (and `/etc/brave/…`, `/etc/opt/chrome/…` copies): `DnsOverHttpsMode:"off"`, `ForceGoogleSafeSearch:true`, `ForceYouTubeRestrict:2`, `IncognitoModeAvailability:1`, `DeveloperToolsAvailability:2`, `ExtensionInstallBlocklist:["*"]` (+ allowlist Omarchy's copy-url ID or drop it), `BrowserSignin:0`, `DownloadRestrictions:1`, `SafeBrowsingProtectionLevel:1`, `URLBlocklist` for YouTube/known social; `/etc/firefox/policies/policies.json` twin with `DNSOverHTTPS.Locked`, `DisablePrivateBrowsing`, `ExtensionSettings "*" blocked`, `WebsiteFilter`.
- Kids web apps: remove stock YouTube/ChatGPT/X/Discord/WhatsApp web apps for the kid user; install YouTube Kids (and vetted education sites) via `omarchy-webapp-install` with an `https://`-only guard.
- Ship a **verification script** (`omarchy-kids-check`): resolves a known-bad test domain, `forcesafesearch` CNAME presence, `chrome://policy` values via the policy JSON, DoH status — so a parent gets a green/red screen.

**v2 — the real product**
- Local `dnscrypt-proxy` profile: family upstreams, upstream's cloaking rules for SafeSearch, `blocked_names` with bedtime schedules, DoH/VPN-bypass hostname list, canary-domain NXDOMAIN, blocked-query log.
- nftables `kids` table: per-uid DNS pinning (DNAT kid → filtered instance), 53/853 egress lock, optional strict allowlist (80/443) for young kids.
- Parent CLI/TUI (`omarchy-kids pause 15m | allow example.org | report today`), polkit-gated, with a systemd timer that restores filtering; optional ntfy push.
- Per-child profiles (one resolver instance + one Chromium `--user-data-dir` per child) or NextDNS Pro profile per child for parents who prefer a hosted dashboard.
- Family Link supervised sign-in path (if Chromium supports it) for the "ask parent" flow; force-install NSFW Filter as the in-page second net.
- Optional "Library" mode: YouTube blocked entirely; Jellyfin/Kodi kid profile fed by parent-curated media, with the yt-dlp pattern documented (ToS caveat stated), not automated.

## Candidate workstreams / backlog items

1. **NET-01 `omarchy-setup-dns Family` option** — PR to omacom/omarchy adding Cloudflare Family / AdGuard Family / CleanBrowsing Family choices with strict DoT and `Domains=~.`; 1 file; testable with `resolvectl status` and a known-blocked domain. [S30, S26]
2. **NET-02 Chromium-family kids policy pack** — JSON for `/etc/chromium`, `/etc/brave`, `/etc/opt/chrome`; document each key with Chromium YAML source; resolve the `copy-url` unpacked-extension conflict. [S47, S48, S51, S38]
3. **NET-03 Firefox/Zen policy pack** — `policies.json` twin; verify Zen honors it. [S52–S55, S58]
4. **NET-04 dnscrypt-proxy kids profile** — TOML + cloaking + blocked-names with schedules + resolved handoff; prove socket/service activation on Arch; document `override.conf` if actually needed. [S17–S21]
5. **NET-05 nftables `kids` egress table** — per-uid 53/853 lock + DNAT to per-child resolver; verify coexistence with ufw/iptables-nft; systemd unit. [S60, S22, S33]
6. **NET-06 DoH/VPN-bypass hostname list** — curate from community lists into `blocked_names`; add `use-application-dns.net` NXDOMAIN; measure false positives. [S57, S82, S50]
7. **NET-07 `omarchy-kids-check` verification script** — green/red self-test a parent can run; doubles as CI for the other workstreams.
8. **NET-08 Kids web-app set** — remove-list + install-list (YouTube Kids, PBS Kids…), `https://`-only guard, optional per-app profile dir. [S36, S41, S42, S43, S67]
9. **NET-09 Parent pause/allow/report CLI** — polkit rule + helper + timer; spec the API against AdGuard Home/Pi-hole precedents. [S63, S64]
10. **NET-10 Family Link feasibility spike** — does Arch Chromium + Omarchy OAuth flags expose supervised-user controls and the request flow? [S69, S85]
11. **NET-11 NSFW Filter force-install spike** — CPU cost on a 2015 laptop, false-positive rate on kid sites, MV3 status. [S75]
12. **NET-12 "Library" mode design note** — Jellyfin/Kodi kid profile; document (not automate) yt-dlp/Pinchflat with the YouTube ToS caveat. [S70, S71]
13. **NET-13 Threat-model doc** — the bypass table above turned into a living checklist with a test per row.

## Open questions for the community

1. Per-user browser policy on Linux: is there any supported way to scope Chromium policies to one Unix user, or do we accept machine-wide policies and a parent "toggle"/different-browser convention?
2. Default DNS provider for v1: Cloudflare Family (sponsor, simplest, no SafeSearch) vs CleanBrowsing/AdGuard Family (SafeSearch at DNS, proxy/VPN blocking)? Should the picker explain trade-offs or just choose?
3. Does Arch's Chromium (with Omarchy's OAuth flags) support Family Link supervised profiles? If yes, is a Google account for a child acceptable to this community's parents at all?
4. How strict should the kid-uid egress policy be by default — DNS-only lock (compatible with everything) or 80/443 allowlist (breaks games, Steam, some video)?
5. Should Kids Mode disable Omarchy's `--load-extension copy-url` for the kid, or allowlist it by ID?
6. Is a local `dnscrypt-proxy` acceptable as a hard dependency, or should v1 stay resolved-only and defer local filtering to v2?
7. Is shipping (or even documenting) the yt-dlp library pattern acceptable given YouTube's ToS, or do we restrict "Library" mode to legally clean sources?
8. Who owns list curation (blocked/allowed domains, DoH endpoints, kid-site allowlist) and where does it live so parents can pull updates without a full Omarchy update?
9. What is the reporting/privacy stance — local logs only by default? retention? does the kid get to see what's logged (age-appropriate transparency)?

## Sources

| # | Title | URL | Status | Accessed | Note |
|---|---|---|---|---|---|
| S1 | Set up 1.1.1.1 · Cloudflare 1.1.1.1 docs | https://developers.cloudflare.com/1.1.1.1/setup/ | VERIFIED | 2026-09-01 | Families IPs, DoH/DoT endpoints; returns 0.0.0.0 for blocked |
| S2 | Network operators · Cloudflare 1.1.1.1 docs | https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/ | VERIFIED | 2026-09-01 | Two tiers; "contact us"/Zero Trust for customization |
| S3 | Quad9 service addresses & features | https://quad9.net/service/service-addresses-and-features/ | VERIFIED | 2026-09-01 | Malware blocking only; no adult filtering |
| S4 | NextDNS homepage (features) | https://nextdns.io/ | VERIFIED | 2026-09-01 | Parental control, SafeSearch, YouTube Restricted, Recreation Time, log retention |
| S5 | NextDNS Help: What happens after 300k queries? | https://help.nextdns.io/t/p8hmvaw/what-happens-after-300k-queries | SEARCH-ONLY | 2026-09-01 | Becomes non-filtering resolver after quota |
| S6 | NextDNS Pricing | https://nextdns.io/pricing | SEARCH-ONLY | 2026-09-01 | Pro $1.99/mo unlimited |
| S7 | AdGuard DNS public servers | https://adguard-dns.io/en/public-dns.html | VERIFIED | 2026-09-01 | Family Protection IPs/DoH/DoT/DoQ/DNSCrypt; "enable Safe Search and Safe Mode, where possible" |
| S8 | AdGuard DNS KB overview | https://adguard-dns.io/kb/public-dns/overview/ | VERIFIED | 2026-09-01 | Family blocks adult + enforces safe search |
| S9 | CleanBrowsing filters | https://cleanbrowsing.org/filters/ | VERIFIED | 2026-09-01 | Family/Adult/Security IPs, DoH/DoT; SafeSearch + YT restricted; VPN/proxy blocking |
| S10 | OpenDNS community: What is the default filtering? | https://support.opendns.com/hc/en-us/community/posts/220039227-What-is-the-default-filtering | SEARCH-ONLY | 2026-09-01 | FamilyShield categories |
| S11 | OpenDNS FamilyShield router instructions | https://support.opendns.com/hc/en-us/articles/228006487-FamilyShield-Router-Configuration-Instructions | DEAD-UNVERIFIABLE | 2026-09-01 | 301 → Cisco community landing page |
| S12 | Google: Keep SafeSearch on for your network (forcesafesearch) | https://support.google.com/websearch/answer/186669?hl=en | VERIFIED | 2026-09-01 | CNAME www.google.com → forcesafesearch.google.com; HTTPS preserved (SafeSearch VIP) |
| S13 | Google Workspace: Control YouTube content available to users | https://knowledge.workspace.google.com/admin/youtube/control-youtube-content-available-to-users?hl=en | VERIFIED | 2026-09-01 | Redirect target of support.google.com/a/answer/6214622; five CNAME hosts; header alternative |
| S14 | DuckDuckGo Safe Search help | https://duckduckgo.com/duckduckgo-help-pages/features/safe-search/ | VERIFIED | 2026-09-01 | safe.duckduckgo.com CNAME; kp param |
| S15 | Microsoft: Blocking explicit content with SafeSearch | https://support.microsoft.com/en-us/bing/blocking-explicit-content-with-safesearch | SEARCH-ONLY | 2026-09-01 | strict.bing.com mapping |
| S16 | CleanBrowsing: How to enforce SafeSearch with DNS filtering | https://cleanbrowsing.org/articles/how-to-enforce-safesearch-with-dns-filtering | SEARCH-ONLY | 2026-09-01 | Bing/edgeservices mapping |
| S17 | dnscrypt-proxy example-dnscrypt-proxy.toml | https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-dnscrypt-proxy.toml | VERIFIED | 2026-09-01 | blocked_names, allowed_names, schedules, cloaking, forwarding |
| S18 | dnscrypt-proxy example-cloaking-rules.txt | https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-cloaking-rules.txt | VERIFIED | 2026-09-01 | SafeSearch cloaking examples |
| S19 | dnscrypt-proxy example-blocked-names.txt | https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-blocked-names.txt | VERIFIED | 2026-09-01 | Pattern syntax; `@time-to-sleep` |
| S20 | dnscrypt-resolvers public-resolvers.md | https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md | VERIFIED | 2026-09-01 | cloudflare-family, adguard-dns-family-doh, cleanbrowsing-family-doh, nextdns, quad9-* present |
| S21 | Arch package dnscrypt-proxy | https://archlinux.org/packages/extra/x86_64/dnscrypt-proxy/ | VERIFIED | 2026-09-01 | 2.1.18, extra, updated 2026-07-21 |
| S22 | Arch package nftables | https://archlinux.org/packages/extra/x86_64/nftables/ | VERIFIED | 2026-09-01 | 1.1.6, extra |
| S23 | Arch package chromium | https://archlinux.org/packages/extra/x86_64/chromium/ | VERIFIED | 2026-09-01 | 152.0.7977.64, extra |
| S24 | ArchWiki: dnscrypt-proxy | https://wiki.archlinux.org/title/Dnscrypt-proxy | DEAD-UNVERIFIABLE | 2026-09-01 | Anubis anti-bot wall blocked fetch |
| S25 | ArchWiki: systemd-resolved | https://wiki.archlinux.org/title/Systemd-resolved | DEAD-UNVERIFIABLE | 2026-09-01 | Anubis wall |
| S26 | resolved.conf(5) (Debian manpages mirror) | https://manpages.debian.org/unstable/systemd/resolved.conf.5.en.html | VERIFIED | 2026-09-01 | DNS= `#sni` syntax, DNSOverTLS, Domains=~., precedence |
| S27 | resolved.conf(5) freedesktop | https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html | DEAD-UNVERIFIABLE | 2026-09-01 | HTTP 403 to fetcher |
| S28 | NetworkManager nm-settings-nmcli | https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html | VERIFIED | 2026-09-01 | ipv4.dns, ignore-auto-dns, dns-priority, connection.permissions |
| S29 | slatecave: NetworkManager group permissions via polkit | https://slatecave.net/blog/networkmanager-group-using-polkit/ | SEARCH-ONLY | 2026-09-01 | settings.modify.system default auth_admin_keep |
| S30 | Omarchy bin/omarchy-setup-dns | https://github.com/omacom/omarchy/blob/master/bin/omarchy-setup-dns | VERIFIED (raw) | 2026-09-01 | Writes resolved.conf; UseDNS=no lock |
| S31 | Omarchy install/config/hardware/network.sh | https://github.com/omacom/omarchy/blob/master/install/config/hardware/network.sh | VERIFIED (raw) | 2026-09-01 | Enables iwd; masks networkd-wait-online |
| S32 | Omarchy install/first-run/dns-resolver.sh | https://github.com/omacom/omarchy/blob/master/install/first-run/dns-resolver.sh | VERIFIED (raw) | 2026-09-01 | stub-resolv.conf symlink |
| S33 | Omarchy install/first-run/firewall.sh | https://github.com/omacom/omarchy/blob/master/install/first-run/firewall.sh | VERIFIED (raw) | 2026-09-01 | ufw deny in / allow out |
| S34 | Omarchy install/omarchy-base.packages | https://github.com/omacom/omarchy/blob/master/install/omarchy-base.packages | VERIFIED (raw) | 2026-09-01 | chromium, iwd, impala, ufw, polkit-gnome; no NetworkManager |
| S35 | Omarchy bin/omarchy-launch-webapp | https://github.com/omacom/omarchy/blob/master/bin/omarchy-launch-webapp | VERIFIED (raw) | 2026-09-01 | `--app=` launch, browser fallback |
| S36 | Omarchy bin/omarchy-webapp-install | https://github.com/basecamp/omarchy/blob/master/bin/omarchy-webapp-install | VERIFIED | 2026-09-01 | .desktop writer, favicon fetch |
| S37 | Omarchy bin/omarchy-default-browser | https://github.com/omacom/omarchy/blob/master/bin/omarchy-default-browser | VERIFIED (raw) | 2026-09-01 | supported browsers list |
| S38 | Omarchy config/chromium-flags.conf | https://github.com/omacom/omarchy/blob/master/config/chromium-flags.conf | VERIFIED (raw) | 2026-09-01 | `--load-extension` copy-url |
| S39 | Omarchy install/packaging/webapps.sh | https://github.com/omacom/omarchy/blob/master/install/packaging/webapps.sh | VERIFIED (raw) | 2026-09-01 | Stock web apps incl. YouTube, X, Discord |
| S40 | The Omarchy Manual: Browsers | https://omarchy.org/manual/browsers/ | VERIFIED | 2026-09-01 | Chromium default; web apps run in it |
| S41 | The Omarchy Manual: Web Apps | https://omarchy.org/manual/web-apps/ | VERIFIED | 2026-09-01 | Install > Web App; shared logins |
| S42 | Omarchy issue #8495 (javascript:/file: URLs in --app) | https://github.com/omacom/omarchy/issues/8495 | VERIFIED (gh api) | 2026-09-01 | Closed 2026-08-27 |
| S43 | Omarchy issue #1384 (separate Chromium profile per web app) | https://github.com/omacom/omarchy/issues/1384 | VERIFIED (gh api) | 2026-09-01 | Closed 2025-09-01 |
| S44 | Omarchy discussion #2468 (Firefox as web-app browser) | https://github.com/omacom/omarchy/discussions/2468 | VERIFIED (gh api) | 2026-09-01 | Dedicated Firefox profile approach |
| S45 | Omarchy releases | https://github.com/omacom/omarchy/releases | VERIFIED (gh api) | 2026-09-01 | v4.0.2, 2026-08-31 |
| S46 | Cloudflare blog: Supporting the future of the open web | https://blog.cloudflare.com/supporting-the-future-of-the-open-web/ | VERIFIED | 2026-09-01 | 2025-09-22; Omarchy + Ladybird sponsorship |
| S47 | Chromium policy_definitions (YAML source) | https://github.com/chromium/chromium/tree/main/components/policy/resources/templates/policy_definitions | VERIFIED (raw) | 2026-09-01 | DnsOverHttpsMode, ForceYouTubeRestrict, ForceGoogleSafeSearch, URLBlocklist/Allowlist, Incognito, DevTools, ExtensionInstall*, DownloadRestrictions, BrowserSignin, SafeBrowsingProtectionLevel |
| S48 | Chromium: Linux Quick Start (policies) | https://www.chromium.org/administrators/linux-quick-start/ | VERIFIED | 2026-09-01 | /etc/chromium/policies/managed; /etc/opt/chrome |
| S49 | Chrome Enterprise policy list | https://chromeenterprise.google/policies/ | DEAD-UNVERIFIABLE | 2026-09-01 | JS-only render; used S47 instead |
| S50 | Chromium: DNS over HTTPS (design/FAQ) | https://www.chromium.org/developers/dns-over-https/ | VERIFIED | 2026-09-01 | Same-provider auto-upgrade; managed opt-out; no canary support |
| S51 | Brave: Group Policy | https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy | SEARCH-ONLY | 2026-09-01 | /etc/brave/policies/managed; Chromium policies supported |
| S52 | Firefox admin docs: DNSOverHTTPS | https://firefox-admin-docs.mozilla.org/reference/policies/dnsoverhttps/ | VERIFIED | 2026-09-01 | Enabled/ProviderURL/Locked/ExcludedDomains/Fallback |
| S53 | Firefox admin docs: WebsiteFilter | https://firefox-admin-docs.mozilla.org/reference/policies/websitefilter/ | VERIFIED | 2026-09-01 | 1000-entry limit; match patterns |
| S54 | Firefox admin docs: ExtensionSettings | https://firefox-admin-docs.mozilla.org/reference/policies/extensionsettings/ | VERIFIED | 2026-09-01 | `*` blocked; force_installed uBO example |
| S55 | Firefox admin docs: policies index | https://firefox-admin-docs.mozilla.org/reference/policies/ | VERIFIED | 2026-09-01 | Policy list |
| S56 | mozilla/policy-templates README | https://github.com/mozilla/policy-templates | VERIFIED | 2026-09-01 | Deprecated → admin docs |
| S57 | Mozilla: Canary domain use-application-dns.net | https://support.mozilla.org/en-US/kb/canary-domain-use-application-dnsnet | DEAD-UNVERIFIABLE (content via search) | 2026-09-01 | Page did not render for fetcher; behavior from snippets |
| S58 | Mozilla: Managing policies on Linux desktops | https://support.mozilla.org/en-US/kb/managing-policies-linux-desktops | SEARCH-ONLY | 2026-09-01 | /etc/firefox/policies |
| S59 | Firefox admin docs: Configuring policies | https://firefox-admin-docs.mozilla.org/guides/policies-configuration/ | SEARCH-ONLY | 2026-09-01 | policies.json locations |
| S60 | nftables wiki: Quick reference (10 minutes) | https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes | VERIFIED | 2026-09-01 | output hook, meta skuid, dport 53, verdicts |
| S61 | nftables wiki: Simple ruleset for a workstation | https://wiki.nftables.org/wiki-nftables/index.php/Simple_ruleset_for_a_workstation | VERIFIED (partial) | 2026-09-01 | table inet filter example |
| S62 | Netgate forum: Blocking DNS over HTTPS ("shotgun") | https://forum.netgate.com/topic/157500/blocking-dns-over-https-seems-the-only-way-is-to-fire-a-shotgun-at-it | SEARCH-ONLY | 2026-09-01 | Anycast/shared-IP problem |
| S63 | AdGuard Home openapi.yaml | https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/openapi/openapi.yaml | VERIFIED | 2026-09-01 | /control/protection duration; clients; safesearch; blocked_services schedule; querylog |
| S64 | Pi-hole API docs | https://docs.pi-hole.net/api/ | VERIFIED | 2026-09-01 | Auth; /api/dns/blocking; self-hosted OpenAPI |
| S65 | pi-hole/FTL issue #1845 (timer ignored) | https://github.com/pi-hole/FTL/issues/1845 | SEARCH-ONLY | 2026-09-01 | Timer bug report |
| S66 | HA community: Pi-hole v6 REST API temporarily disable | https://community.home-assistant.io/t/use-pi-hole-v6-rest-api-to-temporarily-disable-blocking/811609 | SEARCH-ONLY | 2026-09-01 | timer in seconds |
| S67 | Google: Watch YouTube Kids on the web | https://support.google.com/youtubekids/answer/9406390?hl=en | VERIFIED | 2026-09-01 | Sign-in optional; content level; web limitations |
| S68 | Google: YouTube Kids system requirements (computers) | https://support.google.com/youtubekids/answer/9597907 | SEARCH-ONLY | 2026-09-01 | Browser versions |
| S69 | Google: Chrome & your child's Google Account | https://support.google.com/families/answer/7087030?hl=en | VERIFIED | 2026-09-01 | Linux Chrome controls; sign-out caveat; request flow |
| S70 | YouTube Terms of Service | https://www.youtube.com/t/terms | VERIFIED | 2026-09-01 | No download/automated access without permission |
| S71 | Pinchflat README | https://github.com/kieraneglin/pinchflat | VERIFIED | 2026-09-01 | yt-dlp; single container; Plex/Jellyfin/Kodi; stability caveat |
| S72 | Tube Archivist | https://git.tubearchivist.com/tubearchivist/tubearchivist | SEARCH-ONLY | 2026-09-01 | Three containers; kids-use anecdotes |
| S73 | e2guardian GitHub (repo + releases) | https://github.com/e2guardian/e2guardian | SEARCH-ONLY | 2026-09-01 | v5.5.9r 2025-08-22 |
| S74 | AUR: e2guardian | https://aur.archlinux.org/packages/e2guardian | SEARCH-ONLY | 2026-09-01 | Packaged in AUR |
| S75 | NSFW Filter extension | https://github.com/nsfw-filter/nsfw-filter | VERIFIED | 2026-09-01 | Local TF.js; ViT-384; v3.0.0; Chrome |
| S76 | nsfwjs | https://github.com/infinitered/nsfwjs | SEARCH-ONLY | 2026-09-01 | Client-side classifier |
| S77 | chromium net-dev: DoH same-provider auto-upgrade | https://groups.google.com/a/chromium.org/g/net-dev/c/lIm9esAFjQ0/m/vJ93oMbAAgAJ | SEARCH-ONLY | 2026-09-01 | Auto-upgrade semantics |
| S78 | Mozilla: DNS over HTTPS FAQs | https://support.mozilla.org/en-US/kb/dns-over-https-doh-faqs | SEARCH-ONLY | 2026-09-01 | Default-on regions; manual DoH ignores canary |
| S79 | NextDNS Help: parental-control (guessed URL) | https://help.nextdns.io/t/g9hdkhh/parental-control | DEAD-UNVERIFIABLE | 2026-09-01 | 404 |
| S80 | Bing help (SafeSearch) | https://help.bing.microsoft.com/#apex/18/en-US/10003/0 | DEAD-UNVERIFIABLE | 2026-09-01 | Rendered only nav |
| S81 | Cloudflare One: DNS policies | https://developers.cloudflare.com/cloudflare-one/traffic-policies/dns-policies/ | SEARCH-ONLY | 2026-09-01 | Customizable alternative to public Families |
| S82 | Pi-hole discourse: NXDOMAIN for use-application-dns.net | https://discourse.pi-hole.net/t/support-for-returning-nxdomain-for-use-application-dns-net-to-disable-firefox-doh/23243 | SEARCH-ONLY | 2026-09-01 | Canary handling |
| S83 | The Omarchy 3 Manual: Web Apps (learn.omacom.io) | https://learn.omacom.io/2/the-omarchy-manual/63/web-apps | SEARCH-ONLY | 2026-09-01 | Mirror of S41 |
| S84 | Local DNS observations (`dig`, this machine) | — | VERIFIED (local) | 2026-09-01 | forcesafesearch→216.239.38.120; family.cloudflare-dns.com→1.1.1.3; cloudflare-dns.com→104.16.24x.249; youtubekids.com→youtube-ui.l.google.com |
| S85 | Omarchy bin/omarchy-install-chromium-google-account | https://github.com/omacom/omarchy/blob/master/bin/omarchy-install-chromium-google-account | VERIFIED (raw) | 2026-09-01 | Adds OAuth client flags to chromium-flags.conf |

Source counts: VERIFIED 55 · SEARCH-ONLY 22 · DEAD-UNVERIFIABLE 8 (total 85).
