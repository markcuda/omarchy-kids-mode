# Accessibility Statement

_status: draft · updated 2026-09-01_

Omarchy Kids Mode is built for children who can't read yet, children who read differently, and children who use
a keyboard before they use a mouse. Accessibility is therefore not a compliance box — it's the product.

## Commitments

- Any UI we ship targets **WCAG 2.2 AA**; the 3–7 preset targets 7:1 contrast.
- **Keyboard-operable end to end** (this is Omarchy); every shortcut has an on-screen anchor.
- **Pre-reader mode**: icon + audio, no essential text; targets ≥ 64 px for 4-year-olds, ≥ 32 px for 5-year-olds.
- **Fonts as a per-child toggle**: Atkinson Hyperlegible (default for kids), Lexend, OpenDyslexic.
- **Colour-blind-safe** palettes; nothing conveyed by colour alone.
- **Dictation** (local, offline) available as an input method where a parent enables it.
- Left-handed and non-QWERTY layouts considered in key posters and stickers.
- Docs in this repo: plain language, headings, alt text on images, tables with headers.

## Known limitations (today)

This repo is documentation only; no UI exists yet. Screen-reader support inside Quickshell/Hyprland surfaces is
an open research question (add it to `docs/open-questions.md` when a UI workstream starts).

## Feedback

Open an issue with the 💡 Idea form and mention accessibility, or use the kid-test report form to tell us what a
child could not do.
