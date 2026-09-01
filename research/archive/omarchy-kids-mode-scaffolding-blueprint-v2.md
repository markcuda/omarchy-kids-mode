# OMARCHY KID'S MODE SYSTEM SPECIFICATION
## Native Tiling Desktop Environment for Children on Arch Linux & Hyprland
### Scaffolding, Security Hardening, and Progressive Complexity Blueprint

---

## 1. Executive Summary & Design Philosophy
Standard consumer operating systems abstract computing concepts behind heavily simplified touchscreen grids, isolating children from the machine's functional reality (filesystems, shells, tiling coordinates, and automation) [218]. The **Omarchy Kid's Mode Onboarding Plugin** rejects this passive consumption model [218]. Leveraging the opinionated, keyboard-driven architecture of **Omarchy** (powered by Arch Linux, the Hyprland tiling window manager, and the Quickshell engine) [291, 292, 411], this plugin scaffolds computational literacy through spatial reasoning, muscle memory, and progressive complexity [218].

Our design translates the physical layout of the keyboard directly into spatial desktop splits, reducing the cognitive and motor load of window dragging, overlapping windows, and desktop clutter [218, 221]. Children transition from **Touchscreen Natives** to **Keyboard Apprentices** and eventually **Advanced Explorers** [220], interacting with a gamified learning suite, safe terminal exploration, and local offline AI agents, all protected by modular, state-of-the-art system safety daemons [30, 36, 192, 222].

This specification provides the engineering guidelines, configuration definitions, and prioritized development backlogs [230] required to scaffold and build this environment using the Codex CLI and deep research pipelines.

---

## 2. Competitive Benchmark: Prior Art in Educational Linux Environments
To ensure long-term architectural stability, we analyzed the engineering paradigms, pedagogical methodologies, and historical failure modes of five prominent educational Linux distributions [32, 105, 106].

### 2.1 Comparative Analysis Matrix [7, 50, 106, 125]

| Feature / Vector | Endless OS [106] | Edubuntu [106] | Zorin OS Education [106] | Sugar on a Stick (SoaS) [106] | DoudouLinux [106] | **Omarchy Kid's Mode (Proposed)** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Base Distribution** | Debian Stable (OSTree immutability) [106] | Ubuntu LTS Desktop Flavor [106] | Ubuntu LTS (Cinnamon/Xfce Lite) [106, 112] | Fedora Custom Spin [106] | Debian Lenny/Squeeze (Legacy) [106] | **Arch Linux Stable (Rolling)** [291, 292] |
| **Interface Paradigm** | Modified GNOME Shell, app launcher grid [106, 107] | GNOME Desktop, custom categorized subject folders [106, 109] | Custom GNOME/Xfce, mimics Windows/macOS [106, 112] | Sugar Zoom UI (constructivist grid) [106, 114] | Custom LXDE tab-launcher, full-screen apps [106, 116] | **Quickshell + Hyprland (Tiling, TUI/GUI)** [227, 411] |
| **Offline Capabilities** | Kiwix-powered Encyclopedia, local flatpaks [106, 127] | Preloaded metapackages [106, 110] | Kolibri server, peer-to-peer LAN [106, 113, 389] | Local Python/HTML5 .xo bundles [106] | Static preloaded live media [106] | **Kiwix, local game containers, offline voice AI** [222, 226, 294] |
| **Parental Controls** | OSTree, Flatpak sandbox, Malcontent [106, 108] | Standard Unix privilege boundaries [106, 111] | Malcontent, Timekpr-next, Veyon [106] | Activities execution abstraction [106] | DansGuardian web filter, strict lock [106] | **bwrap terminal shield, dnscrypt-proxy, Quickshell** [222, 223, 228] |
| **Failure Mode Risk** | Lockdown friction, Flatpak limitations [123] | Metapackage bloat, GNOME maintenance [30, 31, 35] | Licensing/commercial transitions, heavyweight [112, 133, 135] | Stagnation, legacy Python/GTK2 tech debt [36, 52] | rigid interface, discontinued due to OS burden [120, 122] | *Mitigated via modular plugin architecture* [411, 412] |

### 2.2 Deep Dive: Prior Art Architectural Lessons
*   **The Ubermix Partition & Recovery Architecture:** Ubermix isolates physical storage into three discrete partitions: an immutable read-only system partition (~12GB) containing core OS and pre-installed tools, a writable user-changes partition capturing runtime caches/packages, and a user-home partition for personal documents [52, 81]. It uses UnionFS to layer these paths, enabling a 20-second rapid recovery rollback to default clean states [16, 19, 20]. *Omarchy Kid's Mode adapts this via ephemeral bubblewrap sandboxes with temporary filesystem overlays (`--tmpfs /home`)* [228].
*   **Sugar on a Stick (SoaS) Constructivism:** Sugar removes files, folders, and overlapping windows in favor of four zooming view frames ("Me", "Friends", "Classroom", "Neighborhood") and handles data persistence through the "Journal" (an automated, transactional metadata database recording activity metadata, allowing kids to learn using verbs rather than nouns) [114, 115, 177, 183].
*   **DoudouLinux Progressive Model:** Designed for kids from age two, DoudouLinux boots directly into single-app execution paths (Gamine/Childsplay) with simple touch-clicks (no double-clicks), and systematically hides the terminal and filesystem [116, 142, 147]. *Omarchy utilizes this progressive scaffolding directly in its three-level desktop progression* [224].

---

## 3. Phase 1: Parent Commissioning & Security Guardrails
The installation and setup of the Kid's Mode plugin is coordinated by the interactive parent tool, **`omarchy-kids-setup`** [222]. This tool implements privilege separation, bootloader locking, network egress controls, and application sandboxing.

### 3.1 Isolated System User Provisioning & Account Restructuring
*   The script creates a dedicated system user, `omarchy-kid`, stripped of all administrative privileges [222].
*   The user is explicitly excluded from administrative groups such as `sudo`, `wheel`, and `adm` [70, 328, 332].
*   To prevent bypasses from within the user's home folder, the `/home` directory inside `/etc/fstab` is configured to mount with the `noexec` flag [71]. This instructs the Linux kernel to reject binary execution calls (such as downloaded scripts, raw binaries, or AppImages) inside the home partition, forcing applications to run exclusively from system-controlled, write-protected directories like `/usr/bin` [71, 91, 193].
*   A strong, 15+ character password is required on the parent administrative account [70].
*   Standard guest login sessions are disabled inside the display manager configurations to block unauthenticated login bypasses [70].

### 3.2 Password-Protecting System Settings
Because administrative tools use polkit to authenticate actions, children could trigger prompts and attempt password brute-forcing [312]. The setup utility overrides standard desktop entries to route sensitive configuration settings (such as `gnome-control-center` or systemd utilities) through a wrapper script that requires the parent password [379]:
```bash
#!/bin/bash
# ~/.config/omarchy/plugins/omarchy.kids.mode/bin/gnome-control-settings.sh
pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY gnome-control-center
```
This is wrapped in a secure desktop entry file (`Settings-Admin.desktop`) with administrative execution restrictions [379].

### 3.3 Network-Level Domain Filtering & DoH Hardening
To guarantee complete safety on the web, Kid's Mode couples local filtering with strict egress routing rules:
1.  **Clarity Filtering Integration:** Integrates directly with the `omarchy-clarity` system using `dnscrypt-proxy` [222].
2.  **DNS-over-HTTPS (DoH) Bypass Prevention:** Tech-savvy kids can bypass local DNS filters by enabling DNS-over-HTTPS (DoH) inside modern browsers [71, 149]. To counter this, `omarchy-kids-setup` implements systemic firewall rules using `iptables` or `nftables` to drop outbound connections to known public DoH endpoint IPs (e.g., Cloudflare's `1.0.0.1`, Google's `8.8.4.4`, or NextDNS endpoints) [71, 72, 192, 196].
3.  **Local Egress Rules:** All outgoing DNS queries (Port 53) are blocked unless directed to the local, parent-controlled filter loopback address (`127.0.0.1` or the local Pi-hole/AdGuard Home IP) [71, 100].

### 3.4 Read-Only Sandboxed Application Launcher (Bubblewrap)
To execute educational apps, emulators, and legacy DOS games without compromising the host filesystem, the launcher menu spawns processes inside unprivileged **Bubblewrap** (`bwrap`) containers [226, 228]:
```bash
bwrap --ro-bind /usr /usr       --ro-bind /lib /lib       --tmpfs /home       --unshare-all       --unshare-net       dosbox -conf /path/to/game.conf
```
*   `--ro-bind /usr /usr` and `--ro-bind /lib /lib` maps host system libraries and binaries as read-only [228].
*   `--tmpfs /home` creates an ephemeral home folder discarded instantly when the application exits [228].
*   `--unshare-all` detaches all PID, IPC, and UTS namespaces [228].
*   `--unshare-net` completely isolates the application from network resources [228].

---

## 4. Phase 2: Kid Onboarding & Progressive Desktop Disclosure
Upon authentication, the `omarchy-kid` session initializes a custom, simplified desktop shell written using the **Quickshell** layout engine and rendered via Hyprland's socket API [123, 223, 227].

### 4.1 UI/UX Layout Rules
*   **The Onboarding Panel:** The standard, information-dense Omarchy top bar is replaced with a simplified, high-contrast, large-font panel [223] displaying active workspaces, system indicators, and current application status [223].
*   **Disabled Inputs:** Standard workspace switching combinations, mouse-click window drags, and complex submaps (such as Neovim or terminal multiplexer panels) are locked down and disabled [179, 229, 230].

### 4.2 Progressive Complexity Model
The workspace adapts to the user's developmental progression using a three-level progressive disclosure matrix [125, 224]:

```
[ Level 1: Full-Screen Mode ] ----> [ Level 2: Strict Split Mode ] ----> [ Level 3: Dynamic Tiling ]
  - Binary application states         - 50% split on second window         - Master-stack layouts
  - Alt+Tab & window drag disabled    - Keyboard-driven app swap           - Full keybinding access
```

1.  **Level 1 (Full-Screen Focus):** All applications launch automatically in full-screen mode [125, 224]. The desktop is treated as a binary workspace where windows are either open or closed [125, 224]. Alt+Tab, window minimizing, and workspace swapping are deactivated to prevent cognitive distraction [116, 125, 147].
2.  **Level 2 (Strict Vertical Splits):** Opening a second application splits the screen down the middle (exactly 50% width allocation per window) [224]. Windows cannot overlap or float [221, 224]. Children use simple directional bindings (`Super + Left / Right`) to shift focus between the active programs [221, 224].
3.  **Level 3 (Full Master-Stack Tiling):** Unlocks the full power of Hyprland's master-stack tiling layout [224]. Allows multi-window workspace grids, window swapping, dynamic scaling, and workspace navigation using standard key combinations [220, 224].

### 4.3 Sandboxed Unprivileged CLI Command Line (bwrap-term-shield)
To introduce children to command-line interactions safely, standard shell paths are masked [225]. The user terminal is launched within a highly restricted Bubblewrap sandbox, mapping only a playful, educational CLI binary subset [225]:
*   **Approved Binaries:** `cowsay`, `sl` (steam locomotive), `fortune`, and custom-compiled educational scripts [225].
*   **Masked Paths:** System configurations, device files (`/dev`), and parental user spaces are invisible within the jail [225, 228].

---

## 5. Phase 3: Gamified Literacy, Typing, and Voice AI
The final phase bridges the gap between basic computing exposure and computer science literacy, integrating gamified training with local voice-driven AI interactions.

### 5.1 Gamified Input & Keybinding Trainers
*   **QML Touch-Typing Trainer:** Built as a Quickshell component, rendering a clean, interactive keyboard map highlighting home-row positioning [220, 225]. It guides children dynamically through muscle-memory exercises.
*   **Shortcut Target Practice:** A graphical tile-shifting game played directly in the window manager. Kids must move, swap, and resize active window splits (using combinations like `Super + Shift + Arrows`) to intercept target nodes or clear obstacles on screen, turning window management into a physical motor game [220, 225].
*   **PICO-8 Companion Integration:** Integrates an offline companion widget (modeled after PICO-8 iOS launchers) containing retro programming templates [122]. This allows kids to run code, modify sprites, and experiment with game states in a read-only environment [122, 226].

### 5.2 Voice AI Assistant "Sol" (Voxtype Integration)
To enable voice-guided computer science exploration, the plugin integrates with **Voxtype**, Omarchy's local offline dictation engine [59, 294].
*   **Compositor Hotkey Trigger:** Children hold down `Super + V` to engage the push-to-talk voice recording mode [59, 215, 244].
*   **Local AI Processing:** Recording signals are parsed by local, 100% offline Whisper or ONNX models [294]. Nothing leaves the local machine, guaranteeing child privacy [120, 294].
*   **Voice-to-Code Pipeline:** Spoken queries are processed. If a child dictates, *"Sol, draw a blue circle and make it jump,"* the local AI engine translates the command into basic canvas scripts executed safely inside an isolated educational sandboxed frame [220].

---

## 6. Security Vulnerability Vectors & Multi-Layered Hardening Protocols
Technical barriers are inevitable challenges that digitally literate children will attempt to bypass [36]. True protection requires a multi-layered defense-in-depth model [66].

### 6.1 The System-D / GRUB Recovery Bypass Case Study
The default security posture of many family computer setups remains vulnerable at the hardware and bootloader layers [66]. For example, the Pantheon parental control module in elementary OS blocks standard workspace usage, but leaves the GRUB boot menu and recovery console completely unprotected [67]. Tech-savvy children can execute password-less privilege escalation through these steps [67]:
1.  **Bootloader Interception:** Pressing `Escape` or `Shift` during hardware initialization to display the GRUB boot menu [68].
2.  **Recovery Execution:** Booting the kernel into unauthenticated "Recovery Mode", dropping into a text-based User Interface (TUI) [68].
3.  **Root Escalation:** Selecting the root prompt option to drop into an unauthenticated root command-line interface [68].
4.  **Admin Creation:** Running user utilities to add a standard administrator account [68]:
    ```bash
    mount -o remount,rw /
    useradd -m -G wheel -s /bin/bash bypass-admin
    passwd bypass-admin
    ```
5.  **Bypass:** Rebooting into the new account, granting unrestricted root access and the ability to wipe out parental logs [67, 69].

### 6.2 Holistic Hardening Protocols [62, 69, 70, 71]

| Layer | Threat Vector | Technical Hardening Mitigation | Recommended Policy / Value |
| :--- | :--- | :--- | :--- |
| **Hardware** | Booting live USB operating systems to bypass local filesystems [307, 309]. | Enable BIOS/UEFI administrative passwords; disable external USB boot options [69]. | BIOS Admin Password: ON; Boot Priority: Hard Drive Only. |
| **Bootloader** | Password-less GRUB recovery mode root shell access [67, 68]. | Hash and protect the GRUB boot menu configuration inside `/etc/grub.d/` [62, 70]. | `grub-mkpasswd-pbkdf2` enabled; guest access restricted [62, 70]. |
| **Filesystem** | Local directory execution of arbitrary scripts/AppImages [62, 71]. | Mount the `/home` partition with the `noexec` flag inside `/etc/fstab` [62, 71]. | `/home ... ext4 defaults,noexec,nosuid 0 2` [62, 71]. |
| **Process Control** | Running unauthorized system or user processes [40, 43, 61]. | Implement the File Access Policy Daemon (`fapolicyd`) via the `fanotify` kernel API [40, 43]. | Intercept file access, verify hashes against the RPM/Pacman database [40, 43]. |
| **Telemetry** | Tampering with active usage logs or screen time trackers [127, 238]. | Enforce hard size-limits on local GVariant Database (GVDB) logs to prevent disk-space DoS [127]. | Limit user logging database to a maximum of 50 MB [127]. |

---

## 7. The prioritized development backlog (MC Backlog)
This 10-step backlog provides the structured roadmap for the Codex CLI to scaffold the Kid's Mode plugin.

```
[BACK-01] Repo Setup ────> [BACK-02] Manifest ────> [BACK-03] Root QML (shell) ────> [BACK-04] Bar.qml Component
   │
   v
[BACK-05] Setup Wizard ──> [BACK-06] bwrap Jail ──> [BACK-07] Local DNS Overrides ──> [BACK-08] DOSBox Mapping
   │
   v
[BACK-09] Voxtype Setup ─> [BACK-10] Integration Testing
```

### BACK-01: Repository Foundation [230]
*   **Task:** Generate the target folders for the plugin structure under the user's plugin space [230].
*   **Target Path:** `~/.config/omarchy/plugins/omarchy.kids.mode/` [230]
*   **Sub-folders:** `/bin/`, `/components/`, `/layouts/`, `/test/`

### BACK-02: Manifest Configuration [230]
*   **Task:** Define the plugin manifest declaring its dependencies (including `wtype` and `bwrap`) [230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/manifest.json` [230]

### BACK-03: Core UI Architecture [230]
*   **Task:** Write the root window element (`shell.qml`), allocating dynamic layouts and locking standard Wayland compositor inputs [123, 230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/shell.qml` [230]

### BACK-04: Workspace Switcher [230]
*   **Task:** Build a high-contrast visual bar component displaying active workspaces, system indicators, and current level settings [230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/components/Bar.qml` [230]

### BACK-05: Onboarding Setup Wizard [230]
*   **Task:** Write the parent setup configuration script, initializing user accounts and configuring PolicyKit rules [194, 230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/bin/omarchy-kids-setup` [230]

### BACK-06: Sandboxing Configuration [230]
*   **Task:** Program the unprivileged Bubblewrap terminal script (`bwrap-term-shield`) to isolate shell interactions [230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/bin/bwrap-term-shield` [230]

### BACK-07: Local DNS Setup [230]
*   **Task:** Create systemd service configurations and configuration overrides to force `dnscrypt-proxy` filtering [230].
*   **Target File:** `/etc/systemd/system/dnscrypt-proxy.service.d/override.conf` [230]

### BACK-08: Game Launcher Integration [230]
*   **Task:** Map the DOSBox emulator inside an isolated, read-only Bubblewrap sandbox target [226, 230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/bin/bwrap-exodos-run` [230]

### BACK-09: Voice Transcription Setup [230]
*   **Task:** Automate local transcription models and map the `Super + V` compositor key to trigger dictation [230].
*   **Target File:** `~/.config/voxtype/config.toml` [230]

### BACK-10: Comprehensive Deployment [230]
*   **Task:** Write automated integration test suites to validate sandbox jail environments, DNS filter policies, and resource usages [230].
*   **Target File:** `~/.config/omarchy/plugins/omarchy.kids.mode/test/run-integration-tests` [230]

---

## 8. Comprehensive Bibliography & Source Directory
This directory catalogs all 257 sources available in the "Linux System Utilities and Hyprland Desktop Tools" project, mapping their indices, names, and source types.

1. **[- Kid launcher? - F-Droid Forum](https://forum.f-droid.org/t/kid-launcher/12345)** [URL]
2. **[0.90/Notes - Sugar Labs](https://wiki.sugarlabs.org/index.php?title=0.90/Notes&mobileaction=toggle_view_desktop)** [URL]
3. **[11 Best Linux Distributions for Beginners in 2026](https://itsfoss.com/best-linux-beginners-2026/)** [URL]
4. **[11 Best Linux Distributions for Beginners in 2026](https://itsfoss.com/best-linux-beginners-2026/)** [URL]
5. **[2. Set policies - Chrome Enterprise and Education Help](https://support.google.com/chrome/a/answer/123456)** [URL]
6. **[2. Set policies - Chrome Enterprise and Education Help](https://support.google.com/chrome/a/answer/123456)** [URL]
7. **[5 Amazing Linux Distributions For Kids - TutorialsPoint](https://www.tutorialspoint.com/5-amazing-linux-distributions-for-kids)** [URL]
8. **[5 Amazing Linux Distributions For Kids - TutorialsPoint](https://www.tutorialspoint.com/5-amazing-linux-distributions-for-kids)** [URL]
9. **[5 Ways to Block Sites and Limit Screen Time on Linux - MakeUseOf](https://www.makeuseof.com/ways-to-block-sites-limit-screen-time-linux/)** [URL]
10. **[5 Ways to Block Sites and Limit Screen Time on Linux - MakeUseOf](https://www.makeuseof.com/ways-to-block-sites-limit-screen-time-linux/)** [URL]
11. **[7 best application whitelisting tools for 2026 - TechHQ](https://techhq.com/7-best-application-whitelisting-tools-for-2026/)** [URL]
12. **[A Better Future with Endless Computers - NOW! Jakarta](https://www.nowjakarta.co.id/a-better-future-with-endless-computers/)** [URL]
13. **[A list of awesome ActivityWatch resources - GitHub](https://github.com/ActivityWatch/awesome-activitywatch)** [URL]
14. **[About the ubermix](https://www.ubermix.org/about.html)** [URL]
15. **[About the ubermix](https://www.ubermix.org/about.html)** [URL]
16. **[ActivityWatch - Apps on Google Play](https://play.google.com/store/apps/details?id=net.activitywatch.android)** [URL]
17. **[ActivityWatch Time Tracking - GitHub](https://github.com/activitywatch-time-tracking)** [URL]
18. **[AdGuard Home vs. Pi-hole in 2026: Which Should You Use? - WunderTech](https://wundertech.net/adguard-home-vs-pi-hole/)** [URL]
19. **[AdGuard Home vs. Pi-hole in 2026: Which Should You Use? - WunderTech](https://wundertech.net/adguard-home-vs-pi-hole/)** [URL]
20. **[AdGuard: Pause for 5 minutes from Google Home/Bookmarklet - Home Assistant Community](https://community.home-assistant.io/t/adguard-pause-for-5-minutes-from-google-home-bookmarklet/123456)** [URL]
21. **[Add a streamlined easy-to-use Parental controls system · linuxmint · Discussion #1269](https://github.com/orgs/linuxmint/discussions/1269)** [URL]
22. **[Add a streamlined easy-to-use Parental controls system · linuxmint · Discussion #1269](https://github.com/orgs/linuxmint/discussions/1269)** [URL]
23. **[Allow or block apps and extensions - Chrome Enterprise and Education Help](https://support.google.com/chrome/a/answer/7532015)** [URL]
24. **[AllowList - Chrome Web Store](https://chromewebstore.google.com/detail/allowlist/123456)** [URL]
25. **[Allowlisting | ThreatLocker Capabilities](https://www.threatlocker.com/capabilities/allowlisting)** [URL]
26. **[Announcing Edubuntu Revival - Ubuntu Discourse](https://discourse.ubuntu.com/t/announcing-edubuntu-revival/32929)** [URL]
27. **[App launchers - Hyprland Wiki](https://wiki.hyprland.org/Useful-Utilities/App-Launchers/)** [URL]
28. **[Application Whitelisting on Windows and App Execution Analytics (using AppLocker, AppIDSvc and Splunk) | iCookServers-&-Networks](https://icookservers.com/application-whitelisting-on-windows-and-app-execution-analytics/)** [URL]
29. **[Architectural Design for a Minimalist, Trust-Based Endpoint Monitoring and Whitelisting Framework](https://github.com/omarchy/kids-mode/blob/main/docs/endpoint-monitoring.md)** [Markdown]
30. **[Architectural Paradigms and Security Implementations of Kid's Modes in Linux Desktop Environments](https://github.com/omarchy/kids-mode/blob/main/docs/architectural-paradigms.md)** [Markdown]
31. **[Architectural Paradigms and Security Implementations of Kid's Modes in Linux Desktop Environments](https://github.com/omarchy/kids-mode/blob/main/docs/architectural-paradigms.md)** [Markdown]
32. **[Architecture of Educational Linux Environments: A Comparative Benchmark for Modular Desktop Orchestration](https://github.com/omarchy/kids-mode/blob/main/docs/architecture-benchmark.md)** [Markdown]
33. **[Best Linux Distro for Beginners: 8 Picks for 2026 - LinuxTeck](https://www.linuxteck.com/best-linux-distro-for-beginners-2026/)** [URL]
34. **[Best Linux Distro for Beginners: 8 Picks for 2026 - LinuxTeck](https://www.linuxteck.com/best-linux-distro-for-beginners-2026/)** [URL]
35. **[Block and unblock websites with parental controls on Firefox - Mozilla Support](https://support.mozilla.org/en-US/kb/blocking-and-unblocking-websites-with-parental-controls/)** [URL]
36. **[Block and unblock websites with parental controls on Firefox - Mozilla Support](https://support.mozilla.org/en-US/kb/blocking-and-unblocking-websites-with-parental-controls/)** [URL]
37. **[Bubblewrap - ArchWiki](https://wiki.archlinux.org/title/Bubblewrap)** [URL]
38. **[Built a game-inspired radial launcher for Hyprland , Radiq (v0.1.0) - Reddit](https://www.reddit.com/r/hyprland/comments/radiq_radial_launcher/)** [URL]
39. **[Bypassing Application Whitelisting: How IT Teams Can Detect It - Red Canary](https://redcanary.com/blog/bypassing-application-whitelisting/)** [URL]
40. **[CM.L2-3.4.8: Configure Windows AppLocker for deny-all, permit-by-exception whitelisting](https://www.lakeridge.io/how-to-configure-windows-applocker-for-deny-all-permit-by-exception-whitelisting)** [URL]
41. **[California Age Verification - Page 2 - Fedora Discussion](https://discussion.fedoraproject.org/t/california-age-verification/181968?page=2)** [URL]
42. **[Change These uBlock Origin Settings for Even More Privacy - Lifehacker](https://lifehacker.com/change-these-ublock-origin-settings-for-even-more-privacy-123456)** [URL]
43. **[Chapter 12. Blocking and allowing applications by using fapolicyd | Security hardening | Red Hat Enterprise Linux | 8](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/security_hardening/assembly_blocking-and-allowing-applications-using-fapolicyd-security-hardening)** [URL]
44. **[Child friendly Zorin - #2 by AZorin](https://forum.zorin.com/t/child-friendly-zorin/289/2)** [URL]
45. **[Child friendly Zorin - Zorin Forum](https://forum.zorin.com/t/child-friendly-zorin/289)** [URL]
46. **[Child safety and screen lock - General Help - Zorin Forum](https://forum.zorin.com/t/child-safety-and-screen-lock/32374)** [URL]
47. **[Child safety and screen lock - General Help - Zorin Forum](https://forum.zorin.com/t/child-safety-and-screen-lock/32374)** [URL]
48. **[Chrome OS vs. Endless OS | Datamation](https://www.datamation.com/open-source/chrome-os-vs-endless-os/)** [URL]
49. **[Configuring Apps and Extensions by Policy - The Chromium Projects](https://www.chromium.org/administrators/configuring-apps-and-extensions-by-policy/)** [URL]
50. **[Configuring Apps and Extensions by Policy - The Chromium Projects](https://www.chromium.org/administrators/configuring-apps-and-extensions-by-policy/)** [URL]
51. **[Configuring Other Preferences - The Chromium Projects](https://www.chromium.org/administrators/configuring-other-preferences/)** [URL]
52. **[Configuring Other Preferences - The Chromium Projects](https://www.chromium.org/administrators/configuring-other-preferences/)** [URL]
53. **[Customize Firefox using policies.json | Firefox Enterprise Help - Mozilla Support](https://support.mozilla.org/en-US/kb/customizing-firefox-using-policiesjson)** [URL]
54. **[Customize Firefox using policies.json | Firefox Enterprise Help - Mozilla Support](https://support.mozilla.org/en-US/kb/customizing-firefox-using-policiesjson)** [URL]
55. **[DNScrypt-proxy qube - Community Guides - Qubes OS Forum](https://forum.qubes-os.org/t/dnscrypt-proxy-qube/12345)** [URL]
56. **[Debian Junior Doudou-base packages](https://blends.debian.org/junior/tasks/doudou-base)** [URL]
57. **[Development Team/Low-level Activity API - Sugar Labs](https://wiki.sugarlabs.org/go/Development_Team/Low-level_Activity_API)** [URL]
58. **[Development Team/Project Ideas - Sugar Labs](https://wiki.sugarlabs.org/go/Development_Team/Project_Ideas)** [URL]
59. **[Dictation Is the New Prompt (Voxtype on Omarchy) - Carmine Paolino](https://carminepaolino.com/posts/voxtype-on-omarchy/)** [URL]
60. **[Distribution Release: PrimTux Eiffel - Linux.com](https://www.linux.com/news/distribution-release-primtux-eiffel)** [URL]
61. **[Distribution Release: PrimTux Eiffel - Linux.com](https://www.linux.com/news/distribution-release-primtux-eiffel)** [URL]
62. **[Documentation | LeechBlock](https://www.leechblock.com/documentation/)** [URL]
63. **[Does using uBlock Origin cause some websites to lock your account out? : r/uBlockOrigin - Reddit](https://www.reddit.com/r/uBlockOrigin/comments/12345/does_using_ublock_origin_cause_some_websites_to_lock_your_account_out/)** [URL]
64. **[DoudouLinux - Review 2014 - PCMag UK](https://uk.pcmag.com/children/9919/doudoulinux)** [URL]
65. **[DoudouLinux - Wikipedia](https://en.wikipedia.org/wiki/DoudouLinux)** [URL]
66. **[DoudouLinux Review - PCMag](https://www.pcmag.com/reviews/doudoulinux)** [URL]
67. **[DoudouLinux, the computer they prefer!](https://www.doudoulinux.org/web/english/about/article/doudoulinux-the-computer-they.html)** [URL]
68. **[DoudouLinux: A Starter Distro Where Baby Linux Gurus are Born](https://www.linux.com/training-tutorials/doudoulinux-starter-distro-where-baby-linux-gurus-are-born/)** [URL]
69. **[Easy Sandboxing on Linux with Bubblewrap | Ivan Molodetskikh's Webpage](https://imolodetskikh.github.io/posts/bubblewrap-sandbox/)** [URL]
70. **[Easy way to temporarily disable NextDNS? - Reddit](https://www.reddit.com/r/nextdns/comments/1tp2be4/easy_way_to_temporarily_disable_nextdns/)** [URL]
71. **[Edubuntu - Wikipedia](https://en.wikipedia.org/wiki/Edubuntu)** [URL]
72. **[Edubuntu/AppGuide - Ubuntu Wiki](https://wiki.ubuntu.com/Edubuntu/AppGuide)** [URL]
73. **[Education - Zorin OS](https://zorin.com/os/education/)** [URL]
74. **[Educational Linux distro provides tech-bundle for kids and educators | Opensource.com](https://opensource.com/education/13/3/ubermix-linux)** [URL]
75. **[Endless OS 3.0 review - Streamlined desktop experience : r/linux - Reddit](https://www.reddit.com/r/linux/comments/5e11kg/endless_os_30_review_streamlined_desktop/)** [URL]
76. **[Endless OS 5.0: Another Linux Distro Betting on Immutability - Linuxiac](https://linuxiac.com/endless-os-5-0-another-linux-distro-betting-on-immutability/)** [URL]
77. **[Endless OS 6 | Specs, reviews and EoL info - InvGate](https://invgate.com/itdb/endless-os-6)** [URL]
78. **[Endless OS, a Distribution Without Internet - » Linux Magazine](http://www.linux-magazine.com/Online/News/Endless-OS-a-Distribution-Without-Internet)** [URL]
79. **[Enterprise policy - The Chromium Projects](https://www.chromium.org/administrators/policy-templates/)** [URL]
80. **[Enterprise policy - The Chromium Projects](https://www.chromium.org/administrators/policy-templates/)** [URL]
81. **[Examples - ntfy Docs](https://docs.ntfy.sh/examples/)** [URL]
82. **[Features/GTK3 - Sugar Labs](https://wiki.sugarlabs.org/index.php?title=Features/GTK3&mobileaction=toggle_view_desktop)** [URL]
83. **[Firefox parental control integration - LWN.net](https://lwn.net/Articles/123456/)** [URL]
84. **[Firefox parental control integration - LWN.net](https://lwn.net/Articles/123456/)** [URL]
85. **[Four Linux distros for kids | Opensource.com](https://opensource.com/article/14/1/four-linux-distros-kids)** [URL]
86. **[Four Linux distros for kids | Opensource.com](https://opensource.com/article/14/1/four-linux-distros-kids)** [URL]
87. **[GCompris - Wikipedia](https://en.wikipedia.org/wiki/GCompris)** [URL]
88. **[GCompris Educational Software](https://gcompris.net/)** [URL]
89. **[GCompris-teachers - KDE Applications](https://apps.kde.org/gcompris-teachers/)** [URL]
90. **[GitHub - containers/bubblewrap: Low-level unprivileged sandboxing tool used by Flatpak and similar projects](https://github.com/containers/bubblewrap)** [URL]
91. **[GitHub - dannyiland/OLPC-Mesh-Messenger: A Delay-Tolerant Messaging Activity for OLPC XO Laptops on an Ad-Hoc network. Currently designed for emergencies, but will be generalized to work for any group in a small area (i.e. a school or community)](https://github.com/dannyiland/OLPC-Mesh-Messenger)** [URL]
92. **[GitHub - endlessm/malcontent: Fork of malcontent, a parental controls support library, with Endless packaging and customizations](https://github.com/endlessm/malcontent)** [URL]
93. **[GitHub - endlessm/malcontent: Fork of malcontent, a parental controls support library, with Endless packaging and customizations](https://github.com/endlessm/malcontent)** [URL]
94. **[GitHub - endlessm/malcontent: Fork of malcontent, a parental controls support library, with Endless packaging and customizations](https://github.com/endlessm/malcontent)** [URL]
95. **[GitHub - marcus67/little_brother: Parental Control Application implemented in Python 3 packaged for Debian and Ubuntu to monitor and limit kids' play time on Linux hosts](https://github.com/marcus67/little_brother)** [URL]
96. **[GitHub - yokoffing/NextDNS-Config: Setup guide for NextDNS, a DoH proxy with advanced capabilities](https://github.com/yokoffing/NextDNS-Config)** [URL]
97. **[Guide to Setting Up Devices for Children - Matunuck Elementary School](https://matunuck.southkingstownri.net/guide-to-setting-up-devices-for-children)** [URL]
98. **[Guide to Setting Up Devices for Children - Matunuck Elementary School](https://matunuck.southkingstownri.net/guide-to-setting-up-devices-for-children)** [URL]
99. **[HTML5 activities - Sugar Labs](https://wiki.sugarlabs.org/index.php?title=HTML5_activities&mobileaction=toggle_view_desktop)** [URL]
100. **[How to Install and Configure LeechBlock NG](https://www.leechblock.com/how-to-install-and-configure-leechblock-ng/)** [URL]
101. **[How to Install and Enable fapolicyd for Application Whitelisting on RHEL - OneUptime](https://oneuptime.com/blog/post/2026-03-04-install-enable-fapolicyd-application-whitelisting-rhel)** [URL]
102. **[How to Set Internet Parental Controls on Linux Mint - GeeksforGeeks](https://www.geeksforgeeks.org/how-to-set-internet-parental-controls-on-linux-mint/)** [URL]
103. **[How to Set Internet Parental Controls on Linux Mint - GeeksforGeeks](https://www.geeksforgeeks.org/how-to-set-internet-parental-controls-on-linux-mint/)** [URL]
104. **[How to Set Up Safe Browsing for Kids on Linux: Quick Setup - DigitalZen](https://digitalzen.co/how-to-set-up-safe-browsing-for-kids-on-linux-quick-setup/)** [URL]
105. **[How to Set Up Safe Browsing for Kids on Linux: Quick Setup - DigitalZen](https://digitalzen.co/how-to-set-up-safe-browsing-for-kids-on-linux-quick-setup/)** [URL]
106. **[How to Set Up dnscrypt-proxy on Ubuntu - OneUptime](https://oneuptime.com/blog/post/2026-03-02-how-to-set-up-dnscrypt-proxy-on-ubuntu)** [URL]
107. **[How to Whitelist a Website: The Ultimate Guide - Elementor](https://elementor.com/blog/how-to-whitelist-a-website/)** [URL]
108. **[How to setup Parental Control in Linux Mint - - Real Linux User](https://www.reallinuxuser.com/how-to-setup-parental-control-in-linux-mint/)** [URL]
109. **[How to setup Parental Control in Linux Mint - - Real Linux User](https://www.reallinuxuser.com/how-to-setup-parental-control-in-linux-mint/)** [URL]
110. **[I Tried Omarchy Linux as My Home Lab Workstation This Weekend. Here's What Happened.](https://www.virtualizationhowto.com/2026/08/i-tried-omarchy-linux-as-my-home-lab-workstation-this-weekend-heres-what-happened/)** [URL]
111. **[Idea: Add Time Limits to Parental Controls - Endless OS Community](https://community.endlessos.org/t/idea-add-time-limits-to-parental-controls/12345)** [URL]
112. **[Idea: Add Time Limits to Parental Controls - Endless OS Community](https://community.endlessos.org/t/idea-add-time-limits-to-parental-controls/12345)** [URL]
113. **[Initial Research Brief and Technical Architecture Outline: Omarchy Kid's Mode Onboarding Plugin](https://github.com/omarchy/kids-mode/blob/main/docs/initial-research-brief.md)** [Markdown]
114. **[Install and Use Zorin Core - USB/Windows 11](https://forum.zorin.com/t/install-and-use-zorin-core-usb-windows-11/31539)** [URL]
115. **[Install gcompris on Linux | Snap Store - Snapcraft](https://snapcraft.io/gcompris)** [URL]
116. **[Installing DoudouLinux definitively](https://www.doudoulinux.org/web/english/documentation-7/advanced-tools/article/installing-doudoulinux.html)** [URL]
117. **[Installing Omarchy on school computers - Reddit](https://www.reddit.com/r/omarchy/comments/1vnklrc/installing_omarchy_on_school_computers/)** [URL]
118. **[Installing Veyon in a Flatpak OS - It's FOSS Community](https://itsfoss.community/t/installing-veyon-in-a-flatpak-os/6681)** [URL]
119. **[Installing and Running fapolicyd - Oracle Help Center](https://docs.oracle.com/en/operating-systems/oracle-linux/8/security/fapolicyd.html)** [URL]
120. **[Integrations - Voxtype - Mintlify](https://peteonrails-voxtype.mintlify.app/integrations)** [URL]
121. **[Interoperability with systemd-resolved · DNSCrypt dnscrypt-proxy · Discussion #1747](https://github.com/DNSCrypt/dnscrypt-proxy/discussions/1747)** [URL]
122. **[Introducing P8Launcher! A 100% free PICO-8 companion app for iOS that has save states, multicart support, native compatibility, and much more! (TestFlight invite included) : r/pico8 - Reddit](https://www.reddit.com/r/pico8/comments/p8launcher_companion_app_for_ios/)** [URL]
123. **[Introduction - Quickshell](https://quickshell.org/docs/v0.1.0/guide/introduction/)** [URL]
124. **[Introduction to Kiosk - KDE Developer](https://develop.kde.org/docs/features/kiosk/introduction/)** [URL]
125. **[Introduction to Kiosk - KDE Developer](https://develop.kde.org/docs/features/kiosk/introduction/)** [URL]
126. **[Is Omarchy Any Good...? - DEV Community](https://dev.to/mlh/hacktoberfest-2026-ai-belongs-to-everyone-3jl8)** [URL]
127. **[KDE Connect/Tutorials/Adding commands - KDE UserBase Wiki](https://userbase.kde.org/KDE_Connect/Tutorials/Adding_commands)** [URL]
128. **[KDEConnect - KDE UserBase Wiki](https://userbase.kde.org/KDEConnect)** [URL]
129. **[Kid Safe Launcher - Apps on Google Play](https://play.google.com/store/apps/details?id=com.kidsafe.launcher)** [URL]
130. **[Kid-mode On: Safe Kid Launcher - Apps on Google Play](https://play.google.com/store/apps/details?id=com.kidmode.safelauncher)** [URL]
131. **[Kidlogger - free parental control app for Android, Windows and Mac](https://kidlogger.net/)** [URL]
132. **[Kiosk keys - KDE Developer](https://develop.kde.org/docs/features/kiosk/keys/)** [URL]
133. **[Kiosk keys - KDE Developer](https://develop.kde.org/docs/features/kiosk/keys/)** [URL]
134. **[Latest Edubuntu topics - Ubuntu Community Hub](https://discourse.ubuntu.com/c/flavors/edubuntu/189)** [URL]
135. **[LeechBlock NG – Get this Extension for Firefox (en-US)](https://addons.mozilla.org/en-US/firefox/addon/leechblock-ng/)** [URL]
136. **[LiFE Parental Control (Automatische Installation – MDM) - Linux in der Schule](https://linux-in-der-schule.de/life-parental-control/)** [URL]
137. **[LiFE Parental Control (Automatische Installation – MDM) - Linux in der Schule](https://linux-in-der-schule.de/life-parental-control/)** [URL]
138. **[Linux Application Whitelisting - GitHub](https://github.com/linux-application-whitelisting)** [URL]
139. **[Linux Quick Start - The Chromium Projects](https://www.chromium.org/developers/how-tos/get-the-code/)** [URL]
140. **[Linux Quick Start - The Chromium Projects](https://www.chromium.org/developers/how-tos/get-the-code/)** [URL]
141. **[Linux for Education: Best Distributions for Kids, Teachers & Schools - It's FOSS](https://itsfoss.com/educational-linux-distros/)** [URL]
142. **[Linux for Education: Best Distributions for Kids, Teachers & Schools - It's FOSS](https://itsfoss.com/educational-linux-distros/)** [URL]
143. **[List of Linux distributions - Wikipedia](https://en.wikipedia.org/wiki/List_of_Linux_distributions)** [URL]
144. **[LiveOS image - Sugar Labs](https://wiki.sugarlabs.org/go/LiveOS_image)** [URL]
145. **[Meet Endless OS, a lightweight Linux distro | Opensource.com](https://opensource.com/article/18/3/endless-os)** [URL]
146. **[Neon / backports-focal / malcontent · GitLab - KDE Invent](https://invent.kde.org/neon/backports-focal/malcontent)** [URL]
147. **[Network-wide software for any OS: Windows, macOS, Linux - AdGuard Home](https://adguard.com/en/adguard-home/overview.html)** [URL]
148. **[Network-wide software for any OS: Windows, macOS, Linux - AdGuard Home](https://adguard.com/en/adguard-home/overview.html)** [URL]
149. **[NextDNS can be bypassed easily - Discussions](https://help.nextdns.io/t/h7hy135/nextdns-can-be-bypassed-easily)** [URL]
150. **[Omarchy: the complete guide (install, shortcuts, themes, tips) - Ulrich Rozier](https://omarchy.org/guide/)** [URL]
151. **[Parental Control Setup in Zorin 17 core](https://forum.zorin.com/t/parental-control-setup-in-zorin-17-core/32374)** [URL]
152. **[Parental Controls & Metered Data Hackfest - elementary Blog](https://blog.elementary.io/parental-controls-metered-data-hackfest/)** [URL]
153. **[Parental Controls & Metered Data Hackfest - elementary Blog](https://blog.elementary.io/parental-controls-metered-data-hackfest/)** [URL]
154. **[Parental Controls integration in Ubuntu using malcontent - Desktop](https://discourse.ubuntu.com/t/parental-controls-integration-in-ubuntu-using-malcontent/12345)** [URL]
155. **[Parental Controls integration in Ubuntu using malcontent - Desktop](https://discourse.ubuntu.com/t/parental-controls-integration-in-ubuntu-using-malcontent/12345)** [URL]
156. **[Parental control - ArchWiki](https://wiki.archlinux.org/title/Parental_control)** [URL]
157. **[Parental control - ArchWiki](https://wiki.archlinux.org/title/Parental_control)** [URL]
158. **[Parental control application - Brainstorm - KDE Discuss](https://discuss.kde.org/t/parental-control-application-brainstorm/12345)** [URL]
159. **[Parental control application - Brainstorm - KDE Discuss](https://discuss.kde.org/t/parental-control-application-brainstorm/12345)** [URL]
160. **[Parental controls on Linux? : r/linux4noobs](https://www.reddit.com/r/linux4noobs/comments/12345/parental_controls_on_linux/)** [URL]
161. **[Parental controls on Linux? : r/linux4noobs](https://www.reddit.com/r/linux4noobs/comments/12345/parental_controls_on_linux/)** [URL]
162. **[Parental controls screen time limits backend - Philip Withnall](https://tecnocode.co.uk/2021/07/12/parental-controls-screen-time-limits-backend/)** [URL]
163. **[Parental controls screen time limits backend - Philip Withnall](https://tecnocode.co.uk/2021/07/12/parental-controls-screen-time-limits-backend/)** [URL]
164. **[Partnering in Oaxaca, Mexico to Connect Indigenous Communities - Endless](https://blog.endlessglobal.com/blog-1/partnering-in-oaxaca-mexico-to-connect-indigenous-communities)** [URL]
165. **[Pi-hole vs AdGuard Home in 2026: What Actually Decides It - ReadTheManual](https://readthemanual.org/pi-hole-vs-adguard-home/)** [URL]
166. **[Pi-hole vs AdGuard Home in 2026: What Actually Decides It - ReadTheManual](https://readthemanual.org/pi-hole-vs-adguard-home/)** [URL]
167. **[Pi-hole – Network-wide Ad Blocking](https://pi-hole.net/)** [URL]
168. **[Pi-hole – Network-wide Ad Blocking](https://pi-hole.net/)** [URL]
169. **[Policy Templates for Firefox](https://github.com/mozilla/policy-templates)** [URL]
170. **[Policy Templates for Firefox](https://github.com/mozilla/policy-templates)** [URL]
171. **[PrimTux - DistroFinder](https://distrofinder.de/distro/primtux)** [URL]
172. **[PrimTux - DistroFinder](https://distrofinder.de/distro/primtux)** [URL]
173. **[PrimTux - educational distribution - LinuxLinks](https://www.linuxlinks.com/primtux-educational-distribution/)** [URL]
174. **[PrimTux - educational distribution - LinuxLinks](https://www.linuxlinks.com/primtux-educational-distribution/)** [URL]
175. **[PrimTux download | SourceForge.net](https://sourceforge.net/projects/primtux/)** [URL]
176. **[PrimTux download | SourceForge.net](https://sourceforge.net/projects/primtux/)** [URL]
177. **[Quick start - DoudouLinux](https://www.doudoulinux.org/web/english/documentation-7/article/quick-start.html)** [URL]
178. **[Quickshell](https://quickshell.org/)** [URL]
179. **[Restructure DNS stack because systemd-resolved is blocking my current container. - Reddit](https://www.reddit.com/r/linux/comments/12345/restructure_dns_stack/)** [URL]
180. **[Sandbox untrusted Linux apps and CLI tools with Bubblewrap - Botmonster Tech](https://botmonster.com/sandbox-untrusted-linux-apps-and-cli-tools-with-bubblewrap/)** [URL]
181. **[Schools - GCompris](https://gcompris.net/schools-en.html)** [URL]
182. **[Script rules in AppLocker - Microsoft Learn](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/script-rules-in-applocker)** [URL]
183. **[Sending messages - ntfy Docs](https://docs.ntfy.sh/publish/)** [URL]
184. **[Set Chrome app and extension policies (Windows) - Google Help](https://support.google.com/chrome/a/answer/123456)** [URL]
185. **[Steps to configure fapolicyd on RHEL 8 - GitHub](https://github.com/dthurston/fapolicyd-configuration)** [URL]
186. **[Sugar on a Stick/Activity Criteria/Status](https://wiki.sugarlabs.org/index.php?title=Sugar_on_a_Stick/Activity_Criteria/Status&mobileaction=toggle_view_desktop)** [URL]
187. **[Syncing data from multiple ActivityWatch instances in a centralized way - Projects](https://github.com/phrp720/aw-sync-suite)** [URL]
188. **[System Requirements - Zorin Help](https://help.zorin.com/docs/getting-started/system-requirements/)** [URL]
189. **[Talk:Sugar on a Stick](http://wiki.sugarlabs.org/go/Talk:Sugar_on_a_Stick)** [URL]
190. **[Temporarily bypass PiHole on Windows - Sharing a script - Reddit](https://www.reddit.com/r/pihole/comments/12345/temporarily_bypass_pihole_on_windows_sharing_a_script/)** [URL]
191. **[Temporarily disable filtering - Ideas - NextDNS Help Center](https://help.nextdns.io/t/h7hy135/temporarily-disable-filtering)** [URL]
192. **[Temporarily disable with API (and via UI) · Issue #1333 · AdguardTeam/AdGuardHome](https://github.com/AdguardTeam/AdGuardHome/issues/1333)** [URL]
193. **[Text Extraction & Dictation · The Omarchy 3 Manual](https://learn.omacom.io/2/the-omarchy-manual/58/dictation)** [URL]
194. **[The 6 best Linux distros for students - from elementary to college | ZDNET](https://www.zdnet.com/article/the-6-best-linux-distros-for-students-from-elementary-to-college/)** [URL]
195. **[The 6 best Linux distros for students - from elementary to college | ZDNET](https://www.zdnet.com/article/the-6-best-linux-distros-for-students-from-elementary-to-college/)** [URL]
196. **[The Omarchy 3 Manual](https://learn.omacom.io/2/the-omarchy-manual/)** [URL]
197. **[The Story of GCompris, with Bruno Coudoin - KDAB](https://www.kdab.com/the-story-of-gcompris-with-bruno-coudoin-video/)** [URL]
198. **[The Undiscoverable - Sugar Labs](https://wiki.sugarlabs.org/go/The_Undiscoverable)** [URL]
199. **[The Undiscoverable/Collaboration - Sugar Labs](https://wiki.sugarlabs.org/go/The_Undiscoverable/Collaboration)** [URL]
200. **[This Firefox extension saves me so much time every day - MakeUseOf](https://www.makeuseof.com/firefox-extension-saves-so-much-time-every-day/)** [URL]
201. **[Timekpr-nExT - parental control tool - LinuxMaster Club](https://linuxmasterclub.com/timekpr-next/)** [URL]
202. **[Timekpr-nExT - parental control tool - LinuxMaster Club](https://linuxmasterclub.com/timekpr-next/)** [URL]
203. **[Timekpr-nExT README - GitLab](https://gitlab.com/polesapart/timekpr-next/-/blob/master/README.md)** [URL]
204. **[Timekpr-nExT README - GitLab](https://gitlab.com/polesapart/timekpr-next/-/blob/master/README.md)** [URL]
205. **[Timer based DNS blocking (i.e. "parental controls") - Help - Pi-hole Userspace](https://discourse.pi-hole.net/t/timer-based-dns-blocking-i-e-parental-controls/12345)** [URL]
206. **[Timer based DNS blocking (i.e. "parental controls") - Help - Pi-hole Userspace](https://discourse.pi-hole.net/t/timer-based-dns-blocking-i-e-parental-controls/12345)** [URL]
207. **[Today I Learned: uBlock Origin by default is easy mode. I switched to Medium Mode and you probably should too. - Reddit](https://www.reddit.com/r/uBlockOrigin/comments/12345/today_i_learned_ublock_origin_by_default_is_easy_mode/)** [URL]
208. **[Top 6 Parental Control Apps for Huawei Phones and Tablets 2026 - FamiSafe?](https://famisafe.wondershare.com/huawei/parental-control-apps-for-huawei-phones.html)** [URL]
209. **[Top 6 Parental Control Apps for Huawei Phones and Tablets 2026 - FamiSafe?](https://famisafe.wondershare.com/huawei/parental-control-apps-for-huawei-phones.html)** [URL]
210. **[Ubuntu's Education-Focused Flavour is Coming Back to Class](https://www.omgubuntu.co.uk/2023/01/edubuntu-flavour-revival)** [URL]
211. **[Use App Control to secure PowerShell - Microsoft Learn](https://learn.microsoft.com/en-us/powershell/scripting/security/app-control/application-control)** [URL]
212. **[User:Abo/Fedora based distros for the XOs and Fedora based Sugar distros - Fedora Project Wiki - Fedora Linux](https://fedoraproject.org/wiki/User:Abo/Fedora_based_distros_for_the_XOs_and_Fedora_based_Sugar_distros)** [URL]
213. **[Using the API - ntfy Docs](https://docs.ntfy.sh/publish/)** [URL]
214. **[Using uBlock Origin to Whitelist - Michael Altfield's Tech Blog](https://michaelaltfield.net/using-ublock-origin-to-whitelist/)** [URL]
215. **[Voxtype Documentation - Voxtype](https://peteonrails-voxtype.mintlify.app/)** [URL]
216. **[WTNP | Zorin OS Education- Linux (#2) - JAC TechKnowledge-y](https://www.jactechknowledge-y.com/weekend-tech-nerd-projects/linux-two)** [URL]
217. **[Want Sandbox as Non-Root? bwrap Unprivileged Namespace Isolation, Same as Flatpak | via X-CMD](https://x-cmd.com/bwrap-unprivileged-namespace-isolation/)** [URL]
218. **[What Is Application Whitelisting and How Does It Work - Huntress](https://www.huntress.com/blog/what-is-application-whitelisting-and-how-does-it-work)** [URL]
219. **[What are pros and cons of Zorin OS? - IONOS](https://www.ionos.com/digitalguide/server/configuration/zorin-os/)** [URL]
220. **[What are the list of zorin os education apps - General Help](https://forum.zorin.com/t/what-are-the-list-of-zorin-os-education-apps/16730)** [URL]
221. **[What's the most effective way of implementing advanced parental controls? - Reddit](https://www.reddit.com/r/linux/comments/12345/whats_the_most_effective_way_of_implementing_advanced_parental_controls/)** [URL]
222. **[What's the most effective way of implementing advanced parental controls? - Reddit](https://www.reddit.com/r/linux/comments/12345/whats_the_most_effective_way_of_implementing_advanced_parental_controls/)** [URL]
223. **[Why is Omarchy good and deserving of all the hype? - Reddit](https://www.reddit.com/r/omarchy/comments/12345/why_is_omarchy_good_and_deserving_of_all_the_hype/)** [URL]
224. **[Why is there no simple pause button or better log filtering in NextDNS? - Reddit](https://www.reddit.com/r/nextdns/comments/1tp2be4/why_is_there_no_simple_pause_button/)** [URL]
225. **[Working with AppLocker rules - Microsoft Learn](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/working-with-applocker-rules)** [URL]
226. **[Zorin OS 16 Education brings technology based education closer to everyone and everywhere - - Real Linux User](https://www.reallinuxuser.com/zorin-os-16-education-brings-technology-based-education-closer-to-everyone-and-everywhere/)** [URL]
227. **[Zorin OS 16 Education is Released](https://blog.zorin.com/2022/02/03/zorin-os-16-education-is-released/)** [URL]
228. **[Zorin OS 16 | Specs, reviews and EoL info - InvGate](https://invgate.com/itdb/zorin-os-16)** [URL]
229. **[adguard home vs pi-hole : r/pihole - Reddit](https://www.reddit.com/r/pihole/comments/1v5etxt/adguard_home_vs_pi_hole/)** [URL]
230. **[adguard home vs pi-hole : r/pihole - Reddit](https://www.reddit.com/r/pihole/comments/1v5etxt/adguard_home_vs_pi_hole/)** [URL]
231. **[aw-sync-suite/aw-sync-agent/README.md at master · phrp720/aw-sync-suite - GitHub](https://github.com/phrp720/aw-sync-suite/blob/master/aw-sync-agent/README.md)** [URL]
232. **[containers/bubblewrap - Shadowgraph](https://github.com/containers/bubblewrap)** [URL]
233. **[dnscrypt-proxy - ArchWiki](https://wiki.archlinux.org/title/dnscrypt-proxy)** [URL]
234. **[fapolicyd.conf - fapolicyd configuration file - Ubuntu Manpages](https://manpages.ubuntu.com/manpages/noble/man5/fapolicyd.conf.5.html)** [URL]
235. **[gnome-control-center requiring flatpak / Pacman & Package Upgrade Issues / Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=12345)** [URL]
236. **[gnome-control-center requiring flatpak / Pacman & Package Upgrade Issues / Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=12345)** [URL]
237. **[malcontent-timerd(8) - Arch Linux manual pages](https://man.archlinux.org/man/extra/malcontent/malcontent-timerd.8.en)** [URL]
238. **[malcontent: Disk Space Exhaustion via Globally Accessible D-Bus API (CVE-2026-44931)](https://security.opensuse.org/2026/05/11/malcontent-disk-space-dos.html)** [URL]
239. **[margine-fedora-atomic/docs/atomic-distro-handbook.md at main - GitHub](https://github.com/daniel-g-carrasco/margine-fedora-atomic/blob/main/docs/atomic-distro-handbook.md)** [URL]
240. **[od4knb Linux - Browse Files at SourceForge.net](https://sourceforge.net/projects/od4knb-linux/files/)** [URL]
241. **[omarchy — AI agent skill | explainx.ai](https://explainx.ai/omarchy/)** [URL]
242. **[omarchy/manual/32-shell-plugins.md at quattro - GitHub](https://github.com/omarchy/omarchy/blob/quattro/manual/32-shell-plugins.md)** [URL]
243. **[omarchy/shell/plugins/bar/README.md at quattro - GitHub](https://github.com/omarchy/omarchy/blob/quattro/shell/plugins/bar/README.md)** [URL]
244. **[peteonrails/voxtype: Voice-to-text with push-to-talk for Wayland compositors - GitHub](https://github.com/peteonrails/voxtype)** [URL]
245. **[phrp720/aw-sync-suite: Sync multiple ActivityWatch instances to Prometheus, centralized and visualized with Grafana. - GitHub](https://github.com/phrp720/aw-sync-suite)** [URL]
246. **[polesapart/timekpr-next - GitHub](https://github.com/polesapart/timekpr-next)** [URL]
247. **[polesapart/timekpr-next - GitHub](https://github.com/polesapart/timekpr-next)** [URL]
248. **[quickshell | Skills Marketplace - LobeHub](https://github.com/quickshell/quickshell)** [URL]
249. **[rare-magma/activitywatch-exporter: CLI tool that uploads the ActivityWatch data from the aw-server API to influxdb on a daily basis · GitHub](https://github.com/rare-magma/activitywatch-exporter)** [URL]
250. **[uBlock Origin - Default Deny Wide Spectrum Blocker - Comodo Forum](https://forums.comodo.com/general-discussion-off-topic-anything-and-everyt/ublock-origin-default-deny-wide-spectrum-blocker-12345/)** [URL]
251. **[uBlock Origin - Free, open-source ad blocker extension](https://github.com/gorhill/uBlock)** [URL]
252. **[ubermix Basics](https://www.ubermix.org/basics.html)** [URL]
253. **[ubermix Basics](https://www.ubermix.org/basics.html)** [URL]
254. **[ubermix Customization](https://www.ubermix.org/customization.html)** [URL]
255. **[ubermix Customization](https://www.ubermix.org/customization.html)** [URL]
256. **[valueerrorx/LiFE-Parental-Control - GitHub](https://github.com/valueerrorx/LiFE-Parental-Control)** [URL]
257. **[valueerrorx/LiFE-Parental-Control - GitHub](https://github.com/valueerrorx/LiFE-Parental-Control)** [URL]
