# Security & Safety Policy

This repository is documentation and planning — it ships no code. But the whole point of the project is
protections that children will try to get around, so we treat **bypasses as security issues** from day one,
and this policy is inherited by every satellite repo listed in `projects/README.md` unless they override it.

## Report privately first

If you have found a way that a child could **get around a protection** (content filter, time limit, allowlist,
sandbox, account separation, boot lock-down) in anything this project designs or ships:

1. Use GitHub's private reporting: **Security → Report a vulnerability** on this repo
   (`/security/advisories/new`). If that's unavailable, email the maintainers listed in `GOVERNANCE.md`.
2. Include: the layer affected, steps to reproduce, the skill level needed (any kid / curious 10-year-old /
   Linux-savvy teen / physical access), and a suggested fix if you have one.
3. We aim to acknowledge within **7 days** and agree a disclosure timeline with you. Default embargo is
   **30 days** or until a mitigation is documented, whichever is sooner.

**Kids who find bypasses are welcome to report them** — with a parent or guardian, please. You'll be credited
(first name or handle only, if you want) in the fix.

## What is *not* sensitive

Theoretical weaknesses, design critiques, and things already documented publicly (e.g. "DNS filtering can be
bypassed by DNS-over-HTTPS") can go straight to a public issue using the **Safety / bypass concern** template.
When in doubt, report privately; we'll move it public if appropriate.

## Principles

- **No working bypass recipes in public docs** until a mitigation exists. Threat models can describe the class
  of attack; they should not be a how-to.
- **Defense in depth, honestly stated.** Every layer doc lists its residual risks. We never claim "unbypassable".
- **Privacy is a safety property.** Nothing in this project may send data about a child off the machine
  by default. Any feature that does must be opt-in, documented in `docs/threat-model.md`, and reviewed.
- **No data about real children in this repo.** Stories in Discussions must be anonymised; no screenshots
  with names, faces, or usernames.

## Scope

In scope: designs, configurations, scripts, and packages produced under this project and its satellite repos.
Out of scope: vulnerabilities in upstream Omarchy, Hyprland, Arch packages, browsers, or DNS providers — report
those upstream (we'll gladly help you find the right place).
