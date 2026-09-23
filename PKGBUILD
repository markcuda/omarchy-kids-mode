# Maintainer: Mark Cuda <mc@markcuda.com>
#
# makepkg sources this file itself (setting pkgdir/srcdir/startdir and
# reading pkgname/pkgver/... back out), so the usual "unused"/"not
# assigned" shellcheck warnings for those don't apply here.
# shellcheck shell=bash disable=SC2034,SC2154
#
# This PKGBUILD lives in the repo root and builds from the local checkout,
# not a downloaded tarball: source=() is intentionally empty, so package()
# reads straight from $startdir (the checkout root) instead of $srcdir.
# Build on the test laptop (never as root, never with sudo makepkg):
#   makepkg -sf
# See docs/packaging.md for what gets installed where and how to remove it.

pkgname=omarchy-kids
pkgver=0.1.0
pkgrel=1
pkgdesc="Kids Mode as an app on a normal Omarchy install"
arch=('x86_64')
url="https://github.com/markcuda/omarchy-kids-mode"
license=('MIT')
# qt6-svg: SDDM renders share/avatars/*.svg (#39). networkmanager: wifid drives nmcli (#26).
# quickshell: the modals and the Level 1 launcher exec it (#32). hyprland, sddm: the kid session
# and the portal. python-cryptography: omarchy-kids-authd verifies a paired device's signed
# decision (R-NOTIFY-4) and fails closed without it. Omarchy itself comes from its own installer,
# so it cannot be listed; omarchy-kids-check reports when its files are missing. docs/packaging.md
# has the reasoning.
depends=('bash' 'gum' 'jq' 'python' 'cryptsetup' 'polkit' 'sudo' 'systemd' 'qt6-svg' 'qt6-5compat' 'networkmanager' 'quickshell' 'hyprland' 'sddm' 'python-cryptography')
# snapper and limine-snapper-sync are guarded with command -v: skipped, never failed (#38).
optdepends=(
	'socat: faster transport between omarchy-kids-parent-auth and omarchy-kids-authd'
	'snapper: pre-apply "before Kids Mode" snapshot and Remove Kids Mode snapshot (R-TRUST-1)'
	'limine-snapper-sync: refresh the boot menu right after hiding/showing snapshot entries (issue #38)'
)
install=omarchy-kids.install
source=()

package() {
	cd "$startdir" || exit 1

	# Commands (R-BUILD-4): every bin/omarchy-kids-* file, whatever exists
	# today plus whatever lands later -- this glob needs no updating.
	# The tui-demo dev tool lives in scripts/, not bin/, so this glob
	# never sees it (docs/tui.md).
	install -dm755 "$pkgdir/usr/bin"
	install -m755 bin/omarchy-kids bin/omarchy-kids-* "$pkgdir/usr/bin/"
	# Keep the schema package-owned: source copies use the checkout-relative path,
	# while the installed command uses the fixed data path below.
	# shellcheck disable=SC2016 # $DIR is a literal build-time source constant.
	sed -i 's|^SCHEMA="$DIR/share/config/schema.toml"$|SCHEMA="/usr/share/omarchy-kids/config/schema.toml"|' \
		"$pkgdir/usr/bin/omarchy-kids-conf"
	grep -q '^SCHEMA="/usr/share/omarchy-kids/config/schema.toml"$' "$pkgdir/usr/bin/omarchy-kids-conf" \
		|| { echo "PKGBUILD: schema substitution failed" >&2; return 1; }

	# Early-boot LUKS-unlock hook (R-BOOT).
	install -dm755 "$pkgdir/usr/lib/omarchy-kids"
	install -m644 lib/*.sh lib/*.py "$pkgdir/usr/lib/omarchy-kids/"

	# The one build-time constant (AGENTS.md, "The trust boundary"): no
	# shipped command reads a program, a library or a socket path from its
	# environment, so the packaged copy has the interpreter's absolute path
	# baked in here rather than resolving "python3" through $PATH.
	sed -i 's|^KIDS_PY=python3$|KIDS_PY=/usr/bin/python3|' \
		"$pkgdir/usr/lib/omarchy-kids/kids.sh"
	grep -q '^KIDS_PY=/usr/bin/python3$' "$pkgdir/usr/lib/omarchy-kids/kids.sh" \
		|| { echo "PKGBUILD: KIDS_PY substitution failed" >&2; return 1; }
	install -dm755 "$pkgdir/usr/lib/initcpio/hooks" "$pkgdir/usr/lib/initcpio/install"
	install -m755 initcpio/hooks/* "$pkgdir/usr/lib/initcpio/hooks/"
	install -m755 initcpio/install/* "$pkgdir/usr/lib/initcpio/install/"
	install -Dm755 initcpio/omarchy-kids-open "$pkgdir/usr/lib/initcpio/omarchy-kids-open"

	# systemd units (authd socket/service, wifid socket/service (R-WIFI-2,
	# issue #26), boot-login + its cleanup unit, the screen-time ledger's
	# timer/service, R-TIME-1, and the ask-collect timer, R-ASK-1..3,
	# issue #25).
	install -dm755 "$pkgdir/usr/lib/systemd/system"
	install -m644 systemd/*.service systemd/*.socket systemd/*.timer "$pkgdir/usr/lib/systemd/system/"
	# The relay's system account (R-NOTIFY-1): authd accepts a DECIDE only from it.
	install -dm755 "$pkgdir/usr/lib/sysusers.d"
	install -m644 systemd/omarchy-kids-relay.sysusers "$pkgdir/usr/lib/sysusers.d/omarchy-kids-relay.conf"

	# Data: bands, packs, hyprland, tui, policy, avatars, menu, sddm-theme,
	# wifi (share/wifi/shell.qml, the kid-facing picker, R-WIFI-1..2).
	# cp -a preserves the share/ subtree; .gitkeep placeholders are pruned
	# afterward so empty data dirs still exist without shipping git litter.
	install -dm755 "$pkgdir/usr/share/omarchy-kids"
	cp -a share/. "$pkgdir/usr/share/omarchy-kids/"
	# Quickshell only resolves types inside a shell's own directory, so the one theme file is
	# installed next to every standalone surface (seen live: "KidsTheme is not a type").
	for d in "$pkgdir"/usr/share/omarchy-kids/{launcher,exit-modal,ask,time,plugins,wifi}; do
		[ -d "$d" ] && cp share/qml/KidsTheme.qml "$d/"
	done
	find "$pkgdir/usr/share/omarchy-kids" -name '.gitkeep' -delete

	# The portal (R-LOGIN, issue #14): SDDM only looks for greeter themes
	# under /usr/share/sddm/themes/<name>/, not under our own share dir --
	# so share/sddm-theme/ is installed there too, selected at runtime by
	# lib/posture.sh's posture_write_sddm_theme_dropin
	# (/etc/sddm.conf.d/zz-omarchy-kids-theme.conf).
	install -dm755 "$pkgdir/usr/share/sddm/themes/omarchy-kids"
	cp -a share/sddm-theme/. "$pkgdir/usr/share/sddm/themes/omarchy-kids/"
	find "$pkgdir/usr/share/sddm/themes/omarchy-kids" -name '.gitkeep' -delete

	# pacman hook: re-assert every lock after any transaction (R-TRUST-5).
	install -Dm644 pacman/omarchy-kids.hook \
		"$pkgdir/usr/share/libalpm/hooks/omarchy-kids.hook"

	# Desktop entries: the app, and the kid Wayland session.
	install -Dm644 desktop/omarchy-kids.desktop \
		"$pkgdir/usr/share/applications/omarchy-kids.desktop"
	install -Dm644 desktop/omarchy-kids-session.desktop \
		"$pkgdir/usr/share/wayland-sessions/omarchy-kids.desktop"

	# License.
	install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
