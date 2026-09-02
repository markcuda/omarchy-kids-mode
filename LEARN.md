# Learn with Omy

Guided, gamified learning where the **subject is a plug-in**. One loop, any pack. Updated 2026-09-01.
Research: [report 08](research/08-gamification-and-guided-learning.md). Status: **forming**.

## The idea

Duolingo's loop works because of how it teaches, not because of what it teaches. Make the loop the
scaffold and the subject a **learning pack**: a botanist, a mechanic, an astrophysicist, a grandparent
who knows sourdough each write a pack; a parent installs it; the child gets the same hand-held,
gamified path every time. The first pack teaches the machine itself: *Learning Omarchy*.

Kids Mode is the console. The pack library is the store. Steam, but for learning packs.

## Where it lives

One hub, many spokes, same as everything else here ([SPOKES.md](SPOKES.md)). Not a second hub.
Learn with Omy is path-agnostic: the engine is a shell plugin either the [installer path](PATH-INSTALLER.md)
or the [sandbox path](PATH-SANDBOX.md) can carry.

| Piece | Where | What |
| --- | --- | --- |
| **Research + design** | this repo | [report 08](research/08-gamification-and-guided-learning.md), this page, the pack spec once agreed, and the pack catalog |
| **Engine** | spoke `omarchy-kids-learn` | The Omarchy shell plugin that plays *any* pack: lesson player, scheduler, mastery tracking, badges, parent view. Plugin id reverse-domain, never `omarchy.*`. Listed on [plugins.omarchy.org](https://plugins.omarchy.org/) when it works |
| **Packs** | spokes `omarchy-kids-<subject>-pack` | **Data only**: objectives, items, feedback text, hints, worked examples, assets, license, authoring notes. No code. Pack 0, *Your Omarchy*, lives inside the engine repo until the format settles, then splits out |
| **Catalog** | this repo, `PACKS.md` (later) | One row per pack: subject, age band, author, license, kid-tested badge. The "store" is a markdown table before it is anything else |

**Why packs are data, not code.** Omarchy's git-installed themes are colors-only, which is what makes
them safe to install by URL. Packs get the same property: a pack can't run anything, phone home, or
touch the system. That is what makes "install it like a package" safe on a child's account, and what
lets a domain expert who has never programmed write one.

**Why not a new hub.** Coordination stays in one place; spokes ship. The engine and the packs are
owned by whoever builds them and link back here, like every other spoke.

## Fixed points (inherited)

- **sudo is the boundary**; nothing about a child leaves the machine; offline first. Progress is a
  local file the parent can read and delete.
- **Rewards for mastery only. No streaks, leagues, variable rewards, or push nags.** Report 07 §4:
  the EU minors guidelines and 5Rights treat those as dark patterns for under-18s. Report 08 sorts
  Duolingo's mechanics into keep / adapt / drop against that rule.
- **Omy is the guide, not a friend.** Omy is the mascot that teaches the keys, in the same lane as the
  onboarding mascot spoke. Omy has no feelings, no memory, no "I missed you". Report 07 §5.
- **The engine must work with zero AI.** Duolingo's core loop is deterministic, expert-authored
  content, not a language model. A local model is an optional layer (hints, rephrasing a prompt,
  explaining a wrong answer), never the source of truth, and it follows the report 07 AI stance:
  nameless, offline, session-scoped, off by default, 8+.
- **Age bands, not names.** A pack declares which bands it serves (3–5, 5–7, 8–10, 11–12). The
  engine never stores a birth date.

## What the research says

Report 08, in six lines. Section numbers are its.

1. **Duolingo is two systems wearing one owl.** A learning core (bite-size lessons, immediate
   feedback, adaptive difficulty, spaced review, explicit objectives) under a retention layer
   (streaks, energy, XP, leagues, quests, bandit-tuned notifications). Duolingo's own papers tune
   the second for engagement and measure learning separately. §2
2. **The core is evidenced for 5–12-year-olds.** Spacing, retrieval practice, interleaving, and
   immediate feedback all have child studies behind them. §3
3. **The retention layer is not learning science, and children are the group it harms most.**
   Tangible rewards undermine intrinsic motivation more in children than in adults; gamification's
   motivational effect is weakest in primary school and fades with time. Report 07 §4's rules
   stand. §3
4. **Duolingo drops the hooks for young kids itself.** Its ages 3–8 literacy app has no streak
   ("a daily joke" instead), an adult-picked starting level, and a published scope and sequence.
   That is our precedent: keep the loop, drop the hooks. §2
5. **"Same loop, different subject" needs re-modelling, not re-skinning.** Duolingo Math needed
   new item types and thousands of bespoke visuals; the volunteer Incubator closed because
   templates and deadlines could not be imposed on volunteers. Packs need a strict schema, a
   validator, and a review gate. §4
6. **A deterministic tutor beats a chatbot.** Intelligent tutoring systems match human tutors in
   meta-analysis; unguarded LLM tutors hurt unaided exam performance in high school, and
   hint-only versions removed the harm. No under-13 LLM-tutor trial exists. §6

**Keep:** linear path with interleaved review · bite-size sessions · instant correctness plus a
short why · re-ask misses at session end · spaced due dates · mastery gating · a story frame the
pack supplies · delight (sound, motion, characters).
**Adapt:** adaptive difficulty as a local heuristic · badges only for mastery events, permanent ·
leaderboard becomes a family "what we learned" board with no ranks · "explain my answer" becomes
pack-authored explanations · starting level chosen by the parent · timed challenges become
untimed mastery retries.
**Drop:** streaks and freezes · hearts and energy · XP and gems · leagues · daily and friend
quests · notifications · anything that counts days or ranks kids.

## The pack, v0 sketch

A folder in a git repo. Report 08 §7(b) has the full anatomy and its precedents (Kolibri
channels, Anki decks, GCompris activities, H5P manifests).

| A pack has | Which is |
| --- | --- |
| A manifest | id (reverse-domain, never `omarchy.*`), title, version, author, license, language, age bands, subject, schema version |
| Objectives | A numbered list, mapped to a public framework where one exists, or to the pack's own published scope and sequence |
| Units → skills → items | Each item: a type (choose, type, order, drag-to-target, **press-a-key**), a prompt, answers, feedback text for the common wrong answers, one to three hints, a difficulty, prerequisites; each skill a mastery rule |
| Worked examples | One per skill, shown before the first try and again on the second miss |
| Assets | Images and audio narration for pre-readers, all local, every file licensed in the manifest |
| A story frame, optional | Characters and a mission as data. No first-person feelings |
| An authoring guide | How to write items and feedback, plus the review checklist |

A pack **never** has: executable code, reward or timing settings, network endpoints, telemetry,
anything about a specific child. A validator rejects packs outside the schema. That is the
Incubator's template problem, solved by tooling instead of deadlines.

The engine owns everything else: the scheduler, session generation, mastery tracking, the only
badges, the hint and worked-example order, the parent view, the level-up gate (kid demonstrates,
parent confirms), and a local-only progress log. The engine never nags, counts days, ranks, or
phones home.

Workstreams LRN-01 through LRN-10 are in report 08 §7(d). First three: pack schema and
validator, the headless engine core with tests, and Pack 0 built on the L1→L3 capability ladder.

## Next

| Step | Who |
| --- | --- |
| Read report 08; argue with it in an issue | anyone |
| Write the pack spec v0 in this repo (a short RFC-style doc) | @markcuda + open |
| Scaffold `omarchy-kids-learn`: Quickshell overlay that plays one hard-coded lesson | after the onboarding wizard |
| Write Pack 0 lesson 1: *Super+Enter opens a window* | pairs with the mascot spoke |
| Kid-test with 2–3 families (age bands only, per the rules) | parents in the channel |
