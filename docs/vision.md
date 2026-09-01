# Vision

_status: draft · updated 2026-09-01_

> **Kids deserve awesome computers too.**

## Mission

A child's first real computer should be **safe by default, fun on day one, and grow with them** until one
day it is simply Omarchy — and they never noticed the training wheels come off.

## The thesis: progressive complexity

Consumer devices hide the machine behind a grid of icons; the child learns to consume, not to drive.
Omarchy is the opposite — keyboard-driven, tiled, opinionated, fast. Kids Mode bets that this is *better*
for children, not worse, if complexity arrives in steps:

| Level | The desktop is… | The kid learns… |
| --- | --- | --- |
| **1 · One thing at a time** | Every app full-screen; open or closed; nothing to drag or lose | Launch, quit, the mascot, a few keys |
| **2 · Two things side by side** | Second app splits 50/50; `Super+←/→` moves focus; no floating, no overlap | Spatial thinking, focus, keyboard as the instrument |
| **3 · The real thing** | Omarchy's tiling, workspaces and keybindings, with guard-rails still on | Everything the parent knows — and soon, more |

Levels are dialled by the parent, unlocked by age presets, and (maybe) earned through play. See
`docs/architecture/layers/05-desktop-shell-and-progressive-ui.md` and research report 07 for the
age-band mapping.

## Principles

1. **Safe by default, honest about limits.** Every protection documents how it can be bypassed and what
   residual risk a parent accepts. We never say "unbypassable".
2. **Grows with the child; never a dead-end kiosk.** A 13-year-old on Kids Mode should be running an
   almost-normal Omarchy. Restrictions are dials, not walls.
3. **Parent setup in five minutes, no terminal.** Boot, choose *Kid Mode*, pick a preset, adjust two sliders,
   hand over the laptop. Everything else is optional.
4. **Local-first and private.** Nothing about the child leaves the machine unless a parent explicitly turns it
   on, and then only to a destination the parent controls. No cloud dashboards by default.
5. **Fun is a feature.** Mascots, sound, games, surprise. If a seven-year-old doesn't giggle in the first
   minute, we shipped a parental-control product, not a kid's computer.
6. **Neutral by default.** No boy/girl fork. Characters, colours and names are choices the child makes.
7. **Zero infrastructure required.** Works on one laptop with no Pi-hole, no server, no account. Integrations
   (Pi-hole, NextDNS, ntfy, a parent's phone) are welcome extras.
8. **Built alongside Omarchy, not on top of a fork.** Ships as themes, tools and config that survive
   `omarchy-update`; respects upstream's opinions; proposes upstream only what upstream would want.
9. **Verified, kid-tested, open.** Claims cite verified sources (ADR-0003). Features get tried by actual
   children before they're called done. All of it is MIT/CC-licensed and forkable.

## Non-goals (for now)

- **Not a new distro.** No ISO, no fork of Omarchy.
- **Not surveillance.** No keyloggers, screenshots, or covert monitoring. Activity summaries, if any, are
  visible to the child too.
- **Not HTTPS interception.** No MITM proxies or local CAs in v1; content filtering is DNS + browser policy +
  app allowlists.
- **Not a classroom MDM.** Teachers are welcome and a school mode may come later; v1 is one family, one machine.
- **Not an AI friend.** If a local voice helper ships at all, it is a tool with no persona, no memory, and
  parent-visible transcripts — and it is off by default.
- **Not a replacement for parenting.** Co-use beats controls. The tool should make it easier for a parent
  to sit beside the child, not to walk away.

## What success looks like

A parent installs Omarchy, runs the kids setup, picks *Early reader (5–7)*, and hands over the laptop. Ten
minutes later the child asks: *"How do I make two windows?"*
