# Release media

`scripts/media-driver.sh` takes the release screenshots from the test VM at 1280x800. It defaults
to tokyo-night and catppuccin-latte, one dark and one light Omarchy theme. Each successful capture
replaces one `<surface>-<theme>.png`; a failed capture leaves the previous file intact.

| File pair | What it shows |
| --- | --- |
| `portal-<theme>.png` | The restarted SDDM portal; the test kid's configured name must be visible. |
| `launcher-<theme>.png` | The test kid's Level 1 launcher and clock; GCompris must be visible. |
| `exit-modal-<theme>.png` | The parent-password exit card; its `Finish for <name>` action must be visible. |
| `ask-<theme>.png` | The Ask a grown-up card; its title and fifteen-minute request must be visible. |
| `times-up-<theme>.png` | The root-triggered Time's Up card; QML readiness, title, and countdown must all pass. |
| `wifi-picker-<theme>.png` | The keyboard-driven Wi-Fi picker; its title and keyboard footer must be visible. |
| `plugins-shelf-<theme>.png` | The read-only More apps shelf; its title and instruction must be visible. |
| `wizard-<theme>.png` | The parent wizard; Welcome and Begin must be visible in the floating terminal. |
| `panel-<theme>.png` | The parent panel; Kids Mode and Add a kid must be visible in the floating terminal. |
| `bar-module-<theme>.png` | The enabled parent widget's open menu; live state and Open Kids Mode must be visible. |

The existing `exit-modal-over-app-<theme>.png` files are extra composition checks, not another
required surface. The three walkthrough videos in docs/GOAL.md item 3 are recorded separately;
this driver only takes stills.

**On disk today (2026-09-18):** only `launcher-<theme>.png` and `exit-modal-<theme>.png`, plus the
two `exit-modal-over-app-<theme>.png` composition shots. The rest of the table is the driver's
target list, not a claim that the files exist; the release set is filled in by the gate runner on
the VM.

For every surface, the driver polls disposable screenshots until macOS Vision finds the required
text. It then takes a separate release screenshot and checks the same text again before replacing
the committed image. A process alone is never treated as proof that its UI has rendered.

The bar capture requires the parent to have enabled the widget already; the driver never edits the
parent's bar. It opens a genuine owner desktop, starts a temporary PAM-backed login session for the
test kid, and leaves the real screen-time timer running. After a fresh ledger tick reports that kid
as live and unpaused, the driver opens the real widget menu through the owner's shell and applies
the same two-stage text check. Cleanup ends only the temporary login and ticks the ledger again.
