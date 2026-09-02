# Omarchy Kids Mode

**Kids deserve awesome computers too.**

This is the community hub for **Kids Mode on [Omarchy](https://omarchy.org)**. Research, planning,
deliberation, and the core feature set live here. Everything that ships — themes, plugins, games,
app packs — lives in its own repo (a **spoke**) and links back. See [SPOKES.md](SPOKES.md).

An independent community effort by parents in the Omarchy Discord. Not affiliated with or endorsed
by DHH, 37signals, or the Omarchy project. Started by Mark Cuda, owned by all.

## Where this is heading

Upstream has spoken ([full quotes](research/discord-signal.md)):

- **Kids under 13 first.** — DHH
- **sudo is the boundary.** Parents hold it; changing settings requires it. — DHH
- **DHH decides what lands in core** — he signs the distro. "Not a democracy 😄. But I'll listen
  to any and all suggestions and ideas!"
- For core, **Kids Mode starts at install.** The installer's first question becomes *"Who is this
  computer for? 1) Me, 2) Child, 3) Another owner."* — DHH

That last point is where the work forks. Two builds are under way, and they diverge on one
question: **whose machine is it?**

| | Installer path | Sandbox path |
| --- | --- | --- |
| Whose machine | The kid's | The family's |
| Chosen | At install, by the first question | Any time, as an app on a normal install |
| Accounts | One, the kid's, with a kid password and a parent password | The parent's own, untouched, plus one real account per kid |
| Getting out | The parent password at `sudo` and the lock screen | Super ×3, the parent password, then *Pause* or *Finish* |
| Built by | Pete, upstream, in `omacom/omarchy` and `omarchy-iso` | This hub's spoke, [`omarchy-kids-sandbox`](https://github.com/markcuda/omarchy-kids-sandbox) |
| Page | [PATH-INSTALLER.md](PATH-INSTALLER.md) | [PATH-SANDBOX.md](PATH-SANDBOX.md) |

Both honor the fixed points above, both run the kid's desktop from a root-owned config, and they
share the parent command and its feature commands, so pieces move between them. The hub's job is
the same for either: do the homework, prototype, shape suggestions worth sending upstream, and
give spoke projects one place to coordinate. **[CORE.md](CORE.md)** is the current picture.

## Jump in

| You are… | Do this |
| --- | --- |
| Up for a team effort | Join a path: the [installer path](PATH-INSTALLER.md) upstream, or the [sandbox path](PATH-SANDBOX.md) in [`omarchy-kids-sandbox`](https://github.com/markcuda/omarchy-kids-sandbox) |
| A designer or artist | The **onboarding mascot** (boy/girl/neutral paths proposed) needs you |
| A lone wolf | Build a **theme or plugin** kids see when they log in — cool, fun, pre-packaged |
| Just curious | Put Omarchy on an old laptop and build something for the kid in your life |
| A connector | [Run or join an Omarchy meetup](https://omarchy.org/meetups/) and invite parents |
| A parent with 5 minutes | Share a [parent story](https://github.com/markcuda/omarchy-kids-mode/discussions) or open an idea issue |

Ground rules: only cite links you've opened · never post anything about a real child · AI-assisted
work is fine, say so · be kind to beginners. More: [CONTRIBUTING.md](CONTRIBUTING.md).

## Map

| | |
| --- | --- |
| [CORE.md](CORE.md) | The core feature set: fixed points, current picture, open questions |
| [PATH-INSTALLER.md](PATH-INSTALLER.md) | The installer path: DHH's direction, Pete's upstream PRs, known gaps, how to help |
| [PATH-SANDBOX.md](PATH-SANDBOX.md) | The sandbox path: sixteen settled decisions, what we borrowed, Phase 1 checks |
| [SPOKES.md](SPOKES.md) | The hub-and-spoke model and the spoke catalog |
| [LEARN.md](LEARN.md) | Learn with Omy: pack-driven guided learning — where it lives, what's fixed, what's open |
| [research/](research/) | Eight deep-dive reports + the source registry |
| [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) | How to help · how to report a bypass |

## Governance

Deliberately open. This hub belongs to the community — nobody is in charge, and we'll work out
how decisions get made together, when there's something to decide. What lands in Omarchy core is
DHH's call. `main` is protected: changes arrive by reviewed pull request.

[MIT licensed](LICENSE), same as Omarchy.
