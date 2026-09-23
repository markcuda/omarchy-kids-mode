# shellcheck shell=bash
# test/shell.d/lib.sh — the two things every test needs to give the same
# answer on a bare dev box and on a real Omarchy box with the package
# installed and Omarchy's own tools on PATH (AGENTS.md, testing rules):
#
#   kids_file_mode FILE        a file's permission bits, GNU stat first.
#   kids_base_path DIR [TOOL…] a private bin directory holding only the
#                              base tools (plus each TOOL named), so a
#                              test that needs a command *absent* is not
#                              at the mercy of what this box installed.
#
# Not a test file (no -test.sh suffix, so test/all skips it). Source it:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# kids_file_mode FILE — FILE's permission bits ("644"). GNU first, always:
# on GNU coreutils `stat -f` means *filesystem* status, so it succeeds and
# prints something that is not a mode at all (issue #49; lib/kids.sh's
# file_stat has the same ordering for the same reason).
kids_file_mode() {
  if stat --version >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}

# kids_file_mtime FILE — FILE's mtime in seconds, same GNU-first rule.
kids_file_mtime() {
  if stat --version >/dev/null 2>&1; then stat -c '%Y' "$1"; else stat -f '%m' "$1"; fi
}

# kids_file_gid FILE — FILE's numeric group id, same GNU-first rule.
kids_file_gid() {
  if stat --version >/dev/null 2>&1; then stat -c '%g' "$1"; else stat -f '%g' "$1"; fi
}

# KIDS_BASE_TOOLS — bash plus the coreutils/text tools bin/ and lib/ use.
# Deliberately absent: everything a test may need to *not* find — getent,
# lsblk, socat, limine, every omarchy-* and omarchy-kids-* command. Name
# those explicitly when a test wants them.
KIDS_BASE_TOOLS=(
  awk base64 basename bash cat chgrp chmod chown cmp comm cp cut date
  diff dirname du env expr find grep gzip head id install jq ln ls mkdir
  mktemp mv od ps python3 readlink realpath rm rmdir sed seq sh sleep
  sort stat tail tar tee timeout touch tr uname uniq wc xargs
)

# kids_base_path DIR [TOOL...] — fill DIR with symlinks to KIDS_BASE_TOOLS
# and each TOOL, and print DIR. Run a command under "PATH=$STUBS:$(…)" so
# an installed package can never turn "not installed yet" into "installed".
# Resolve it before a test puts its own stubs on PATH.
kids_base_path() {
  local dir="$1" tool src
  shift
  mkdir -p "$dir"
  for tool in "${KIDS_BASE_TOOLS[@]}" "$@"; do
    src="$(type -P "$tool")" || continue
    [[ -n "$src" ]] && ln -sf "$src" "$dir/$tool"
  done
  printf '%s\n' "$dir"
}
