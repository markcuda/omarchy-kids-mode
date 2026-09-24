# shellcheck shell=bash
# test/shell.d/tree.sh — the two things a test needs now that no shipped
# command reads its identity, its libraries or its sibling commands from
# the environment (AGENTS.md, "The trust boundary"):
#
#   kids_tree DEST ROOT            a scratch copy of bin/ with lib/ beside
#                                  it, so a stub is injected by *placing*
#                                  it next to the command under test
#                                  ("$DEST/bin/omarchy-kids-conf"), the
#                                  way the installed package would be
#                                  relocated -- never by an env override.
#   kids_stub TREE NAME            write TREE/bin/NAME from stdin, +x.
#   kids_id_stub DIR ACCOUNT [UID] an `id` on PATH that answers as
#                                  ACCOUNT, for a test that has to be a
#                                  kid. $KIDS_TEST_UID overrides what
#                                  bare `id -u` prints (0 = "as root").
#
# Not a test file (no -test.sh suffix, so test/all skips it). Source it:
#   source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"

# kids_tree DEST ROOT — every bin/omarchy-kids* copied into DEST/bin
# (real files, not symlinks: each command resolves DIR from
# `readlink -f "$0"`, and a symlink would resolve back to the checkout
# and find the checkout's siblings instead of this tree's stubs), with
# DEST/lib and DEST/share symlinked to ROOT's.
kids_tree() {
  local dest="$1" root="$2"
  mkdir -p "$dest/bin"
  cp "$root"/bin/omarchy-kids* "$dest/bin/"
  ln -sfn "$root/lib" "$dest/lib"
  ln -sfn "$root/share" "$dest/share"
}

# kids_stub TREE NAME — TREE/bin/NAME from stdin, executable.
kids_stub() {
  local path="$1/bin/$2"
  cat >"$path"
  chmod +x "$path"
}

# kids_id_stub DIR ACCOUNT [UID] — `id` for DIR (put DIR on PATH).
# `id -un` is how every command now answers "which account am I?", so a
# test drives that the same way it already drives `loginctl`.
kids_id_stub() {
  local dir="$1" account="$2" uid="${3:-1000}"
  local groups="${4:-$account}"
  cat >"$dir/id" <<EOF
#!/bin/bash
case "\${1:-}" in
  -un)
    if [[ -n "\${2:-}" ]]; then echo "\$2"; else echo "\${KIDS_TEST_ACCOUNT:-$account}"; fi
    ;;
  -u)
    if [[ -n "\${2:-}" ]]; then
      [[ "\$2" == "$account" ]] && echo "$uid" || exit 1
    else
      echo "\${KIDS_TEST_UID:-$uid}"
    fi
    ;;
  -Gn)
    echo "\${KIDS_TEST_GROUPS:-$groups}"
    ;;
  -gn)
    echo "$account"
    ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$dir/id"
}

# kids_set_const FILE NAME VALUE — rewrite a `NAME=<constant>` line in a
# *copied* command, the one relocation seam a test may use: the same
# build-time substitution PKGBUILD does at package time (KIDS_PY,
# TEST_SOCKET_ROOT, omarchy-kids-web's SYSROOT, omarchy-kids-conf's SCHEMA, and
# BOOT_MODE_MACHINE_CONF and BOOT_MODE_LOCK). Never an env override.
kids_set_const() {
  local file="$1" name="$2" value="$3" tmp line
  tmp="$(mktemp)"
  while IFS= read -r line; do
    if [[ "$line" == "$name="* ]]; then printf '%s="%s"\n' "$name" "$value"; else printf '%s\n' "$line"; fi
  done <"$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}
