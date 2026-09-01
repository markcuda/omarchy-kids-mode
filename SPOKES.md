# Hub and spokes

**The hub (this repo):** research, planning, deliberation, and the core feature set.
**A spoke:** any repo that ships something — a theme, plugin, game, app pack, or tool — and links
back here for context. Spokes are owned by whoever builds them.

## Active and forming

| Spoke | What | Status | Who |
| --- | --- | --- | --- |
| Onboarding flow & parent/child setup | The install-time "Child" path and the parent's five-minute setup | forming — people coalescing (Discord) | open — join in |
| Onboarding mascot | The character(s) that teach kids the machine; boy/girl/neutral paths proposed | forming | needs artists |
| Kid themes | `omarchy-<name>-theme` repos: big type, high contrast, fun, mascot unlock art | open — perfect lone-wolf project | you? |
| Kid plugins & games | Shell plugins (bar, launcher, widgets) and mini-games — "so when they log in, they have something to do" | open — lone-wolf friendly | you? |
| App packs | Curated per-age install manifests + web-app sets | open | you? |
| [`jfuerwentsches/omarchy-kids`](https://github.com/jfuerwentsches/omarchy-kids) | Independent project, started 2026-08-27: age-tiered config + Rust parental agent + Qt parent control over SSH. Early concept | related — coordinating is open question #5 | jfuerwentsches |

## Add a spoke

Open an issue (🧩 Spoke) or PR a row into the table. A spoke should:

1. Say in its README what it is, who owns it, and link back here.
2. Carry an open license (MIT recommended — same as Omarchy).
3. Never collect anything about a child.
4. Follow upstream naming: themes `omarchy-<name>-theme`; plugin ids reverse-domain, never `omarchy.*`.

## Distribution

Themes get listed at [omarchy.org/themes](https://omarchy.org/themes/) (PR to `omarchy-site`);
plugins at [plugins.omarchy.org](https://plugins.omarchy.org/) (PR to the marketplace registry).
Core-worthy ideas go to Omarchy's Discussions → Suggestions — upstream's call.

## Two more ways to start

Put Omarchy on an old laptop and build something for the kid in your life — or yourself.
And [run or join an Omarchy meetup](https://omarchy.org/meetups/); invite other parents and caregivers.
