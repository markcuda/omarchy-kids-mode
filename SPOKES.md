# Hub and spokes

**The hub (this repo):** research, planning, deliberation, and the core feature set.
**A spoke:** any repo that ships something — a theme, plugin, game, app pack, or tool — and links
back here for context. Spokes are owned by whoever builds them.

## Active and forming

| Spoke | What | Status | Who |
| --- | --- | --- | --- |
| [Kids Mode sandbox](https://github.com/markcuda/omarchy-kids-sandbox) | The [sandbox path](PATH-SANDBOX.md): the Kids Mode app, parent wizard and panel, per-kid provisioning, login portal, exit modal, safety check. Renamed from `omarchy-kids-setup` on 2026-09-02 | **design settled** — spec next; current scripts predate the decisions | @markcuda + open |
| Onboarding mascot | The character(s) that teach kids the machine; boy/girl/neutral paths proposed | forming | needs artists |
| Kid themes | `omarchy-<name>-theme` repos: big type, high contrast, fun, mascot unlock art | open — perfect lone-wolf project | you? |
| Kid plugins & games | Shell plugins (bar, launcher, widgets) and mini-games — "so when they log in, they have something to do" | open — lone-wolf friendly | you? |
| App packs | Curated per-age install manifests + web-app sets | open | you? |
| [Learn with Omy](LEARN.md) | Guided, gamified learning where the *subject* is a plug-in: an engine that plays any **learning pack**; packs are data-only repos (`omarchy-kids-<subject>-pack`) domain experts write. Pack 0: *Your Omarchy* | forming — research + design in the hub first | @markcuda + open |

## Seen in the wild, not yet registered

Public repos with Kids Mode in their name, found on GitHub on 2026-09-02. Descriptions are the
owners' own; nobody here has reviewed the code. Owners: open a 🧩 Spoke issue and claim your row.

| Repo | Owner's description |
| --- | --- |
| [Dmcchesney/omarchy-kids-game-turbo-tables](https://github.com/Dmcchesney/omarchy-kids-game-turbo-tables) | Solo offline times-table kart sprint for Omarchy Kids Mode |
| [TyRichards/omarchy-kids-logos](https://github.com/TyRichards/omarchy-kids-logos) | Logos |
| [Deoxizn/omarchy-kids-edition-plymouth](https://github.com/Deoxizn/omarchy-kids-edition-plymouth) | Omarchy logo done for kids under 13, Plymouth preview |
| [jfuerwentsches/omarchy-kids](https://github.com/jfuerwentsches/omarchy-kids) | A configuration layer on top of Omarchy for children of different age groups (CORE.md open question 5) |

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
