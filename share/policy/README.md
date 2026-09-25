# Chromium policy templates (SPEC.md R-WEB-2, R-WEB-3)

JSON has no comments, so this file carries the citations the JSON templates can't. See
`docs/web.md` for how these templates, `lists/*.txt`, and `omarchy-kids-web` fit together.

Every key below was verified against Chromium's own generated policy list -- the JSON data
[chromeenterprise.google/policies](https://chromeenterprise.google/policies/) itself renders
client-side from (`https://chromeenterprise.google/static/json/policy_templates_en-US.json`,
fetched and checked directly against `policy_definitions` on 2026-09-02) -- not guessed from
memory. This is the same source Chromium's own `policy_templates.json` in the Chromium source
tree is built from.

| Key | Type | Meaning here |
| --- | --- | --- |
| `DnsOverHttpsMode` | string-enum (`off`\|`automatic`\|`secure`) | `secure`: DoH only, no plaintext-DNS fallback (R-WEB-2). |
| `DnsOverHttpsTemplates` | string | The family resolver's DoH URI template. Default here: Cloudflare's "1.1.1.1 for Families" malware+adult-content resolver, `https://family.cloudflare-dns.com/dns-query` (confirmed against Cloudflare's own docs, developers.cloudflare.com/1.1.1.1/setup/, 2026-09-02). CleanBrowsing Family's equivalent (`https://doh.cleanbrowsing.org/doh/family-filter/`, confirmed against cleanbrowsing.org/filters) or a custom URL is Appendix B's `dns` key (`cleanbrowsing-family`, `custom:<url>`) -- not wired into `omarchy-kids-web` yet; see docs/web.md. |
| `ForceGoogleSafeSearch` | boolean | `true`: SafeSearch on in Google Search, not user-changeable. |
| `ForceYouTubeRestrict` | int-enum (`0` Off, `1` Moderate, `2` Strict) | `2`: Strict Restricted Mode enforced on YouTube (R-WEB-2's literal value). |
| `IncognitoModeAvailability` | int-enum (`0` Enabled, `1` Disabled, `2` Forced) | `1`: Incognito windows disabled. |
| `DeveloperToolsAvailability` | int-enum (`0` disallowed only for force-installed extensions, `1` Allowed, `2` Disallowed) | `2`: DevTools and the JS console disallowed everywhere. |
| `ExtensionInstallBlocklist` | list of strings | `["*"]`: every extension ID is blocked; a value of `*` is documented as meaning "block all extensions". |
| `BrowserSignin` | int-enum (`0` Disable, `1` Enable, `2` Force) | `0`: the kid can't sign the browser into a Google account (no Sync). |
| `PromotionalTabsEnabled` | boolean | `false`: no promotional tabs (the "What's new"/promo pages a first run or a version bump would open). |
| `DefaultBrowserSettingEnabled` | boolean | `false`: no "make Chromium your default browser" prompt. |
| `MetricsReportingEnabled` | boolean | `false`: no usage/crash metrics leave the machine (I-2 -- nothing about a child leaves it). |
| `SearchSuggestEnabled` | boolean | `false`: the address bar makes no search-suggestion requests (I-2). |
| `DownloadRestrictions` | int-enum (`0`..`4`) | `1`: `BlockDangerousDownloads` -- blocks malicious downloads and dangerous file types (R-WEB-2's literal value). |
| `SavingBrowserHistoryDisabled` | boolean | `false`: history *is* saved (R-DATA-1 needs it; `true` would turn saving off). |
| `AllowDeletingBrowserHistory` | boolean | `false`: the kid cannot clear their own history (matches R-WEB-2 and I-6 -- a parent's visibility into history isn't a control the kid can quietly defeat). |
| `URLBlocklist` | list of strings | `["*"]`: blocks every URL; `URLAllowlist` carves out exceptions (walled-garden and no-browser modes). Not set at all for the filtered (13+) band -- see below. |
| `URLAllowlist` | list of strings | The band's starter list (`lists/<band>.txt`) merged with an optional `--allow FILE` (e.g. a kid's own approved sites), via `omarchy-kids-web render`. Only present for walled-garden bands (6-8, 9-12). |
| `PasswordManagerEnabled` | boolean | `false` for the two youngest bands (3-5, 6-8) only: a pre-reader or early reader gains nothing from Chromium's saved-password autofill and it's one less thing to explain. Left unset (enabled) for 9-12 and 13+. Not in R-WEB-2's list; added here as a small extra hardening step for young bands, consistent with I-6 since it *is* enforced. |

## Per-band shape (R-WEB-3)

- **3-5** (`web=none`): the launcher hides Chromium entirely (`bin/omarchy-kids-session-start`);
  the policy still sets `URLBlocklist: ["*"]` as defense in depth if it's ever opened anyway. No
  `URLAllowlist` key -- there is nothing to allow through a browser that isn't offered.
- **6-8, 9-12** (`web=garden`, "walled garden" in the R-BAND table): `URLBlocklist: ["*"]` plus a
  merged `URLAllowlist` from that band's `lists/<band>.txt` and the kid's own approved sites.
- **13+** (`web=filtered`, "filtered open web"): neither key. R-WEB-3 says so explicitly --
  filtering here is the table above plus the DoH resolver's own category blocking, not a
  Chromium-side site list. `lists/13+.txt` exists as parked reference data for a future Advanced
  option; `omarchy-kids-web render 13+ --allow ...` refuses on purpose rather than silently doing
  nothing (I-6).

## What this doesn't cover

`omarchy-kids-web` writes exactly the keys above (plus the merged allowlist). It does not touch
machine DNS (R-WEB-6: never changed by this path) and it never runs against the parent's own
account -- the parent is in no `omarchy-kids-<band>` group, so `/etc/chromium/policies/managed/`
holds nothing that applies to them (R-WEB-1).
