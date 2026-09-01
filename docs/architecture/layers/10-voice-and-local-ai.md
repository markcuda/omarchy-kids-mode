# L10 · Voice & Local AI (optional, off by default)

_status: draft · updated 2026-09-01 · lead: none (parked pending RFC) · primary evidence: report 07 §5, report 01 §6_

## Purpose

Decide whether any voice/AI capability belongs in Kids Mode, and if so, how small it must be.

## What we know (verified)

- **Voxtype is real**: third-party (peteonrails), Rust, MIT, whisper.cpp, local; Omarchy installs it via
  _Install > AI > Dictation_ (150 MB base English model); hotkeys **hold `F9` / toggle `Super+Ctrl+X`** (not
  `Super+V`, which is paste). It is **speech-to-text only** — not an assistant. [R01-S15][R07-S25]
- The blueprint's "Sol" voice-to-code persona does not exist and would need a local LLM.
- The 2025–26 climate is hostile to "AI friend" designs for children: Common Sense Media — no social AI companions
  under 18 (Apr 2025), AI toys unacceptable ≤5 (Jan 2026); FTC 6(b) orders to seven companies (Sep 2025);
  Character.AI ended open-ended chat for under-18s (Nov 2025) and settled family suits (Jan 2026); California
  SB 243 in force 1 Jan 2026 (disclosure, break reminders, crisis protocols for companion chatbots). [R07-S1]–[R07-S6][R07-S19]–[R07-S24]
- Discord signal: "My kids should rather share thoughts with me than a machine."

## Stance (proposal; must go through an RFC before anything is built)

1. **No persona.** No name, no face, no first-person feelings. Call it *Voice Command* / *Talk to type*.
2. **Tool, not friend.** Three functions only: dictation into any app; a whitelisted intent set ("open paint",
   "how do I split the screen?" → shows the key overlay); answers *about the computer* from a local curated FAQ.
   Anything else → "That's a great thing to ask a grown-up" + one-tap "leave a note for a parent" (lands in L9).
3. **Off by default; opt-in per child; 8+ default gate.**
4. **Offline only.** Voxtype/whisper.cpp; network denied in its sandbox (L4). If a local LLM is ever added: no
   memory, session-scoped, child-mode system prompt, same deflection — and its own RFC.
5. **Mutual transparency.** Transcripts visible to parent *and* child; auto-delete after N days by default.
6. **No engagement mechanics.** No proactive speech, notifications, or "miss you".
7. **Publish "Why there's no AI friend"** — one page for parents; meets the "target the masses" objection with an
   explanation, not a chatbot.

Accessibility upside: dictation is genuinely useful for pre-readers and dyslexic kids — the strongest argument for
keeping the *STT* piece.

## Interfaces

Sandbox from L4; transcript panel in L9; preset gate from L6; Voxtype's own `omarchy-plugin` dir (report 07)
suggests a shell integration path.

## Workstreams & backlog seeds

AI-00 **RFC: should L10 exist in v1 at all?** · AI-01 Voice Command spec (intent whitelist, deflection copy,
transcript viewer, retention, network-deny) · AI-02 parent explainer · AI-03 Voxtype-in-sandbox spike.

## Open questions

OQ-8; community appetite; separate opt-in package vs bundled.
