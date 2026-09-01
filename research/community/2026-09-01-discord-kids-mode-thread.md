# Community signal: Omarchy Discord kids-mode thread (2026-09-01, ~11:40–11:56)

_Synthesised from a chat excerpt shared by @markcuda ("MC"). Handles as they appeared; no children's details recorded. Quotes lightly trimmed. This is **signal**, not decisions — decisions go through `rfcs/`._

## Who was in the room

Omarchy team/mod tags in brackets as displayed: Harris Kenny [OMA], Viraj [OMA], Pete [FIRE], Rob Snow, Ashish, DubOh, anthonyrussano [GROK], JΛHΞBΛ [REAP], qyro [тєѕѕ], Baniel__, MC (Mark Cuda).

Harris Kenny [OMA] defined the effort: **"Omarchy upstream and independent features, themes, plugins, etc. for children with a focus around child safety, fun, learning, etc. Kids deserve awesome computers too!"** — and noted Cloudflare sponsors Omarchy (blog.cloudflare.com, "Supporting the future of the open web"). Also: "we have the busiest channel — and our participants have the least free time with kids/work" → process must be **low-ceremony and async**.

## Themes (ranked by how many people converged on them)

| # | Theme | Voices | Signal for us |
| --- | --- | --- | --- |
| 1 | **Web safety is the #1 parent fear** — "that moment when a pr0n site pops up… getting a handle on that ASAP would be a quick win" | Rob Snow, Ashish, DubOh, anthonyrussano | First shippable slice = network/content layer (L3) with a *fast, boring, robust* default |
| 2 | **DNS is the easy first layer, not the whole answer** — 1.1.1.3 (Cloudflare family), Quad9, Pi-hole with per-device profiles; "porn is simpler to handle with DNS blocks" but "safety is going to be more than DNS" | Ashish, Rob Snow, anthonyrussano, DubOh | L3 = DNS + browser policy + app-level; document limits honestly |
| 3 | **Default to kids versions of services and prevent override; push the burden onto providers** (YouTube Kids as the simple example) | DubOh, Rob Snow | Allowlist of kid-safe web apps as the L8 default; research which services have real kid modes |
| 4 | **Parent onboarding must be adaptive and dev-free** — "different preferences & parenting styles… more control (6 yr old) → more freedom (13 yr old)… Boot, choose KID MODE, quick setup, off to the races" | Rob Snow, Pete | L6 parent flow = age presets + sliders, ≤5 minutes; no terminal |
| 5 | **Mascot-guided kid onboarding**; a "boy/girl flow" was floated with a neutral default suggested as optional | Rob Snow | Adopt **character choice, not gender choice**; neutral is the default (see `docs/vision.md` principles) |
| 6 | **People want to build: onboarding, games, themes** — "I want to work on onboarding, I'm not creative enough for themes"; "make a game!" | Pete, Harris | Backlog needs clearly chunked, claimable workstreams per skill type (design / shell / systems / content) |
| 7 | **Where does code go?** — "Where do we add the code once we make it?" | Viraj | Exactly what this repo answers: ADR-0002 (plan here, code in satellite repos) + `projects/README.md` |
| 8 | **Curated offline video instead of YouTube** — block YouTube, let parents build a hand-picked local library with yt-dlp | anthonyrussano | Option in L8 (local media library); note ToS/legal caveat; not default |
| 9 | **Skepticism about AI for kids** — "Imagine you had an AI friend in your youth… where is the point where it begins to get scary. My kids should rather share thoughts to me than a machine" | JΛHΞBΛ | L10 stance: optional, offline, tool-not-friend, parent-visible; not in v1 default |
| 10 | **Mass-market intent vs. hacker-parent reality** — "isn't this supposed to target the masses?" vs. Pi-hole/yt-dlp suggestions; "What is Omarchy kids?" asked twice | DubOh, qyro | README must explain the project in one screen; defaults must work with zero infra (no Pi-hole required) |
| 11 | **Gatekeeping worry** — "Every Linux community are the same… gatekeeping" | Baniel__ | CONTRIBUTING explicitly welcomes non-devs, parents, kids-with-a-grown-up |

## Open question raised, unanswered

> "What do we think the top 3 apps that kids 5-12 are going to want/assume on a device after a fresh install?" — DubOh

Tracked in `docs/open-questions.md` (OQ-1). Research report 05 offers a first answer.

## Direct asks to carry into the backlog

- Quick-win web filter with sane defaults (L3) — *Rob Snow*
- Adaptive parent setup by age/parenting style (L6) — *Rob Snow*
- Kid-version defaults, no override (L8/L4) — *DubOh, Rob Snow*
- Onboarding workstream owner candidate — *Pete*
- Games workstream — *Harris ("make a game!")*
- Themes workstream — needs a creative owner
- A clear "where the code goes" answer — *Viraj* → this repo
