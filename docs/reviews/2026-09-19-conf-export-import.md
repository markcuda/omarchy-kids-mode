**Verdict: request changes.** The import path fails closed and parses correctly, but three claims are not true of the code: "all-or-nothing", the per-line error messages, and a round trip that restores the profile. Review was by reading only. No tests were run, so the claim that the new tests pass on the parent commit comes from reading.

## Findings

1. **High. Export then import turns every inherited value into an override.** `cmd_export` at `bin/omarchy-kids-conf:372` prints effective values, and `cmd_import` writes each one through `cmd_set`.
   - After a round trip, `level`, `web`, `dns`, budgets, `allowlist` and `sites` are overrides. A later `band` change or pack update no longer reaches the kid.
   - `theme` gets pinned to the parent's current theme, and `theme_apply_for` runs.
   - Importing one kid's export into another kid also overwrites `name`, `avatar` and `band`.
   - Minimal fix: export only overrides as live lines and print inherited values as `# key=value` comments. Otherwise document that import pins everything.

2. **High. "All-or-nothing" covers validation only.** Apply is one `cmd_set` per key at `bin/omarchy-kids-conf:362`. Each call rewrites the profile and rebuilds the session manifest.
   - A failure on a later key exits under `set -e` with the earlier keys already written. No message says which keys were applied. Examples are a full disk or a `mktemp` error.
   - Intermediate manifests are built for half-applied profiles. With `level=3` then `web=none`, a manifest briefly pairs the new level with the old web setting.
   - A `theme_apply_for` failure is non-fatal, yet import still prints "imported N setting(s)".
   - Minimal fix: copy the profile to a temp file beside it, `conf_set` every pair into the copy, and `mv` once. Then run the theme side effect and `manifest_follow_profile` once. CHANGELOG, `--help` and `docs/conf.md` must describe what a late failure leaves behind.

3. **Medium. The line-number error for bad values is dead code.** `validate_value` calls `die` itself, so the `|| die "import: line $lineno: invalid value..."` at `bin/omarchy-kids-conf:357` never runs. The parent sees an error with no line number. Minimal fix: run the validator in a subshell, as in `( validate_value "$key" "$value" ) 2>/dev/null || die ...`, or print the line number before calling it.

4. **Medium. Three of the four import tests, plus the "changes nothing" check, pass on the parent commit.** On `main`, `import` is an unknown command and exits nonzero. The "refused" tests at `test/shell.d/conf-test.sh:752`, `:762` and `:771` only check for a nonzero exit, so they pass there too, as does the `level` stays `2` check.
   - They also pass if the refusal happens for the wrong reason.
   - Minimal fix: capture stderr and assert the reason text, such as "system-managed", "unknown key 'nonsense'" and "line 2".
   - The first import case and the export cases do fail on the parent commit.

5. **Medium. There is no round-trip test.** The brief mentions one, but the diff has none. Nothing feeds export output into import, and nothing restores a cleared override. Such a test would have exposed finding 1. Also missing are tests for CRLF, a value containing `=`, an empty `apps.extra=`, `onboarded=`, a comment-only file, and duplicate keys.

6. **Medium. A failed export leaves a truncated file that import accepts.** Export prints line by line at `bin/omarchy-kids-conf:374`.
   - If `resolve` dies midway, a file written by `export kid > f` holds the header and some keys, and a later import applies it.
   - This happens when `theme` has no override and `theme_current_name` is empty, which is likely when root runs the command.
   - `show` has the same theme failure, but it does not produce a reusable file.
   - Minimal fix: collect the output in a variable and print it only after the loop.

7. **Low. CRLF files.** Every validator rejects the trailing carriage return except `nonempty-single-line`, so `name=Ada\r` is written to the profile with the control character. The other keys fail with a confusing message. Minimal fix: strip one trailing `\r` per line at `bin/omarchy-kids-conf:349`, and reject control characters in `name`.

8. **Low. The file argument has no regular-file check.** `[[ -r "$file" ]]` at `bin/omarchy-kids-conf:343` accepts a FIFO, which hangs, and follows symlinks inside a kid-writable directory. Values are still validated, so this is not code selection, but rule 9 asks for more than a shell redirect on kid-owned paths. Minimal fix: require `-f` and not `-L`, and state in the docs that the parent vouches for the file.

9. **Low. Duplicate keys.** A key listed twice is applied twice, and the reported count is inflated. Refuse duplicates or count unique keys.

10. **Low. Docs.** `docs/conf.md:196-197` adds only two usage lines.
    - It says nothing about the file format or the comment rule.
    - It does not say that `password` and `onboarded` are omitted and refused.
    - Findings 1 and 2 also need to be documented there.

## Verified as correct

- **Parsing.**
  - The split on the first `=` matches `conf_get` and `conf_set`, so a value containing `=` survives, for example a custom DNS URL.
  - Keys with spaces and indented comments are refused.
  - A newline cannot enter a value.
  - Empty `apps.extra=` exports, validates and sets cleanly.
  - No schema value can contain a pipe character.
- **Omission list.** The `reset = "keep"` keys are `name`, `avatar`, `band`, `theme`, `password` and `onboarded`. Only the last two are system markers, so the list is right. `name`, `band` and `theme` matter through finding 1 instead.
- **Bash 3.2 and strict mode.**
  - `local -a x=()`, `+=` and `${#keys[@]}` on an empty array are safe under `set -u`.
  - The `&& continue` list inside the loop is safe under `set -e`.
  - The arithmetic guard cannot trip `set -e`.
- **Trust boundary.** No new environment variable or path override was added, and only `stdout` from `cmd_set` is discarded.
