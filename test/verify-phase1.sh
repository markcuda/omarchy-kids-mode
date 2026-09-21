#!/bin/bash
# Phase-1 fact collector: answers the project's five unknowns as far as read-only checks can,
# and prints the manual steps for the rest. Output: a report you can paste into an issue.
set -uo pipefail
echo "# Phase 1 verification — $(hostname) — $(date -u +%F)"
echo
echo "## Platform"
echo "- omarchy: $(cat /usr/share/omarchy/version 2>/dev/null || pacman -Q omarchy 2>/dev/null || echo 'not found')"
echo "- kernel: $(uname -r) · model: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo '?')"
echo
echo "## U3 · tmpfs exec flags (kid escape route if exec)"
for m in /tmp /var/tmp /dev/shm /run/user/$(id -u); do
  echo "- $m: $(findmnt -no OPTIONS "$m" 2>/dev/null || echo 'not a mount')"
done
echo
echo "## U2 · Limine editor state"
grep -E 'editor_enabled|hash_mismatch' /boot/limine.conf 2>/dev/null | sed 's/^/- /' || echo "- limine.conf not readable"
echo "- MANUAL: reboot → in the Limine menu press E on the Omarchy entry → try appending init=/bin/bash → report whether it boots to a root shell (it should hit the LUKS prompt on encrypted installs; this box is unencrypted — that's the interesting case)"
echo
echo "## U5 · Snapshots in the boot menu"
sudo snapper list 2>/dev/null | tail -5 | sed 's/^/- /' || echo "- snapper not readable without sudo"
echo "- MANUAL: reboot → Limine → Snapshots submenu → boot the oldest → check whether kid restrictions exist there → report"
echo
echo "## U1 · Second-user SDDM session"
echo "- sddm.conf.d: $(ls /etc/sddm.conf.d/ 2>/dev/null | tr '\n' ' ')"
echo "- sessions: $(ls /usr/share/wayland-sessions/ 2>/dev/null | tr '\n' ' ')"
echo "- MANUAL: create a second user, log out → does the greeter list both? does omarchy update still work after? → report"
echo
echo "## U4 · Flatpak override precedence"
command -v flatpak >/dev/null && echo "- flatpak IS installed: $(flatpak --version)" || echo "- flatpak not installed (good — matches report 03)"
echo "- MANUAL (only if installed): as kid, flatpak override --user to re-grant a system-removed permission → does it win? → report"
echo
echo "## Extra facts"
echo "- getty@tty1: $(systemctl is-enabled getty@tty1.service 2>/dev/null)"
echo "- root status: $(passwd -S root 2>/dev/null | awk '{print $2}')"
echo "- autologin: $(grep -rhs 'User=' /etc/sddm.conf.d/ | tr '\n' ' ')"
