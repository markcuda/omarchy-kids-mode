#!/usr/bin/env python3
"""lib/conf.py — the one place omarchy-kids-conf needs Python.

Reads share/bands/bands.toml and share/packs/<band>.toml with the
stdlib's tomllib (3.11+) and prints plain text a bash caller can consume
directly with $(...). Also does the Appendix B.1 slug rule, since NFKD
transliteration is painful in bash. No writing: bands.toml and the pack
files are read-only data (Appendix C); only a kid's own .conf is ever
written, and that's lib/conf.sh's job.

Usage:
    conf.py slug NAME
    conf.py schema-dump SCHEMA_TOML
    conf.py band-list BANDS_TOML
    conf.py band-dump BANDS_TOML BAND
    conf.py band-get BANDS_TOML BAND KEY
    conf.py pack-ids PACK_TOML
    conf.py pack-sites PACK_TOML
    conf.py pack-app PACK_TOML ID
    conf.py desktop-argv DESKTOP_FILE

Exit 0 on success. Exit 2 with a one-line reason on stderr for a bad
band, key, or missing file — never a Python traceback.
"""
import json
import os
import re
import shlex
import shutil
import sys
import unicodedata

if sys.version_info >= (3, 11):
    import tomllib
else:  # pragma: no cover - Arch ships 3.11+; this is a courtesy for dev boxes
    try:
        import tomli as tomllib
    except ImportError:
        print(
            "conf.py: needs Python 3.11+ (tomllib) or the 'tomli' package",
            file=sys.stderr,
        )
        sys.exit(2)

BANDS_ORDER = ("3-5", "6-8", "9-12", "13+")
SCHEMA_SOURCES = {"none", "band", "pack", "global", "parent-theme"}
SCHEMA_TYPES = {"string", "enum", "integer", "csv"}
SCHEMA_EDITORS = {"text", "avatar", "enum", "number", "time", "dns", "launcher-list", "site-list", "password", "toggle", "theme"}
SCHEMA_VALIDATORS = {
    "nonempty-single-line",
    "avatar-id",
    "band",
    "level",
    "web",
    "dns",
    "minutes",
    "time",
    "wifi",
    "yes-no",
    "menu",
    "theme-id",
    "launcher-ids",
    "hostnames",
    "password-mode",
}


def die(msg):
    print(f"conf.py: {msg}", file=sys.stderr)
    sys.exit(2)


def load_toml(path):
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except FileNotFoundError:
        die(f"no such file: {path}")
    except tomllib.TOMLDecodeError as e:
        die(f"bad TOML in {path}: {e}")


def toml_scalar(value):
    """Render a TOML scalar the way bash key=value files expect it."""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def load_schema(path):
    data = load_toml(path)
    top_level_allowed = {"schema_version", "key"}
    unknown_top_level = set(data) - top_level_allowed
    if unknown_top_level:
        die(f"schema {path} has unknown top-level fields: {', '.join(sorted(unknown_top_level))}")
    if type(data.get("schema_version")) is not int or data["schema_version"] != 1:
        die(f"schema {path} must declare schema_version = 1")
    entries = data.get("key")
    if not isinstance(entries, list) or not entries:
        die(f"schema {path} has no [[key]] entries")

    allowed = {
        "key",
        "type",
        "required",
        "default_source",
        "enum",
        "min",
        "max",
        "pattern",
        "validator",
        "group",
        "label",
        "editor",
        "reset",
    }
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            die(f"schema {path} has a non-table [[key]] entry")
        unknown = set(entry) - allowed
        if unknown:
            die(f"schema {path} has unknown fields: {', '.join(sorted(unknown))}")
        required_fields = {
            "key",
            "type",
            "required",
            "default_source",
            "validator",
            "group",
            "label",
            "editor",
            "reset",
        }
        missing = required_fields - set(entry)
        if missing:
            die(f"schema {path} entry is missing: {', '.join(sorted(missing))}")
        key = entry["key"]
        if not isinstance(key, str) or not key or any(char in key for char in "\t\n|"):
            die(f"schema {path} has an invalid key")
        if key in seen:
            die(f"schema {path} repeats key '{key}'")
        seen.add(key)
        if not isinstance(entry["type"], str) or entry["type"] not in SCHEMA_TYPES:
            die(f"schema {path} key '{key}' has an unknown type")
        if not isinstance(entry["required"], bool):
            die(f"schema {path} key '{key}' has a non-boolean required flag")
        if not isinstance(entry["default_source"], str) or entry["default_source"] not in SCHEMA_SOURCES:
            die(f"schema {path} key '{key}' has an unknown default source")
        if not isinstance(entry["validator"], str) or entry["validator"] not in SCHEMA_VALIDATORS:
            die(f"schema {path} key '{key}' has an unknown validator")
        for field in ("group", "label", "editor", "reset"):
            if not isinstance(entry[field], str) or not entry[field] or any(char in entry[field] for char in "\t\n|"):
                die(f"schema {path} key '{key}' has an invalid {field}")
        if entry["editor"] not in SCHEMA_EDITORS:
            die(f"schema {path} key '{key}' has an unknown editor")
        if entry["reset"] not in {"keep", "clear"}:
            die(f"schema {path} key '{key}' has an unknown reset mode")
        if "enum" in entry:
            if not isinstance(entry["enum"], list) or not entry["enum"] or not all(
                isinstance(value, str) and value and not any(char in value for char in "\t\n|") for value in entry["enum"]
            ):
                die(f"schema {path} key '{key}' has an invalid enum")
            if len(set(entry["enum"])) != len(entry["enum"]):
                die(f"schema {path} key '{key}' has a duplicate enum value")
        if entry["type"] == "enum" and "enum" not in entry:
            die(f"schema {path} key '{key}' has no enum")
        if "pattern" in entry and (not isinstance(entry["pattern"], str) or not entry["pattern"]):
            die(f"schema {path} key '{key}' has an invalid pattern")
        for field in ("min", "max"):
            if field in entry and type(entry[field]) is not int:
                die(f"schema {path} key '{key}' has a non-integer {field}")
        if entry["type"] == "integer":
            if type(entry.get("min")) is not int or type(entry.get("max")) is not int:
                die(f"schema {path} key '{key}' has no integer bounds")
            if entry["min"] > entry["max"]:
                die(f"schema {path} key '{key}' has reversed integer bounds")
        elif "min" in entry or "max" in entry:
            die(f"schema {path} key '{key}' has bounds for a non-integer type")
        if "min" in entry and "max" not in entry or "max" in entry and "min" not in entry:
            die(f"schema {path} key '{key}' has incomplete integer bounds")
        if entry["required"] and entry["default_source"] not in {"none", "parent-theme"}:
            die(f"schema {path} required key '{key}' has a default source")
    return entries


def cmd_schema_dump(argv):
    if len(argv) != 1:
        die("schema-dump: needs SCHEMA_TOML")
    for entry in load_schema(argv[0]):
        enum = ",".join(entry.get("enum", []))
        minimum = str(entry["min"]) if "min" in entry else ""
        maximum = str(entry["max"]) if "max" in entry else ""
        fields = (
            entry["key"],
            entry["type"],
            "yes" if entry["required"] else "no",
            entry["default_source"],
            entry["group"],
            entry["label"],
            entry["editor"],
            entry["validator"],
            enum,
            minimum,
            maximum,
            entry["reset"],
        )
        print("|".join(fields))


def cmd_slug(argv):
    if not argv:
        die("slug: needs a display name")
    name = " ".join(argv)
    # NFKD splits an accented letter into base + combining mark(s); we
    # then drop every combining mark and any remaining non-ASCII, so
    # e.g. "Zoë" -> "Zoe" (Appendix B.1: transliterate common accents).
    decomposed = unicodedata.normalize("NFKD", name)
    ascii_only = decomposed.encode("ascii", "ignore").decode("ascii")
    slug = "".join(ch for ch in ascii_only.lower() if ch.isalnum())
    slug = slug[:24]
    if not slug:
        die(f"slug: '{name}' has no alphanumeric characters to slug")
    print(f"kid-{slug}")


def cmd_band_list(argv):
    if len(argv) != 1:
        die("band-list: needs BANDS_TOML")
    data = load_toml(argv[0])
    bands = data.get("band", {})
    for band in BANDS_ORDER:
        if band not in bands:
            continue
        b = bands[band]
        print(f"{band}\t{b.get('label', '')}\t{b.get('blurb', '')}")


def _band_table(data, band):
    bands = data.get("band", {})
    if band not in bands:
        die(f"unknown band: {band}")
    return bands[band]


def cmd_band_dump(argv):
    if len(argv) != 2:
        die("band-dump: needs BANDS_TOML BAND")
    data = load_toml(argv[0])
    table = _band_table(data, argv[1])
    for key, value in table.items():
        print(f"{key}={toml_scalar(value)}")


def cmd_band_get(argv):
    if len(argv) != 3:
        die("band-get: needs BANDS_TOML BAND KEY")
    data = load_toml(argv[0])
    table = _band_table(data, argv[1])
    key = argv[2]
    if key not in table:
        die(f"band '{argv[1]}' has no '{key}'")
    print(toml_scalar(table[key]))


def cmd_pack_ids(argv):
    if len(argv) != 1:
        die("pack-ids: needs PACK_TOML")
    data = load_toml(argv[0])
    ids = [app["id"] for app in data.get("app", []) if "id" in app]
    print(",".join(ids))


def cmd_pack_sites(argv):
    if len(argv) != 1:
        die("pack-sites: needs PACK_TOML")
    data = load_toml(argv[0])
    sites = data.get("garden", {}).get("sites", [])
    print(",".join(sites))


def cmd_pack_app(argv):
    # Used by bin/omarchy-kids-session-start to resolve one allowlisted
    # launcher id to its pack metadata (label, pkg, and the optional
    # `web` URL for a web app -- see AGENTS.md's packs/<band>.toml row)
    # without hand-parsing TOML in bash. Tab-separated so a bash caller
    # can `IFS=$'\t' read -r label pkg web`.
    if len(argv) != 2:
        die("pack-app: needs PACK_TOML ID")
    data = load_toml(argv[0])
    want = argv[1]
    for app in data.get("app", []):
        if app.get("id") == want:
            label = app.get("label", "")
            pkg = app.get("pkg", "")
            web = app.get("web", "")
            print(f"{label}\t{pkg}\t{web}")
            return
    die(f"no such app id in pack: {want}")


def cmd_desktop_argv(argv):
    """Read one trusted desktop entry and print its fixed launch argv."""
    if len(argv) != 1:
        die("desktop-argv: needs DESKTOP_FILE")
    path = argv[0]
    exec_line = None
    in_entry = False
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if line.startswith("["):
                    in_entry = line == "[Desktop Entry]"
                    continue
                if in_entry and line.startswith("Exec="):
                    exec_line = line[5:]
                    break
    except OSError as e:
        die(f"desktop-argv: cannot read {path}: {e.strerror}")
    if exec_line is None:
        die(f"desktop-argv: {path} has no Exec=")
    try:
        tokens = shlex.split(exec_line, posix=True)
    except ValueError as e:
        die(f"desktop-argv: bad Exec= in {path}: {e}")

    field_codes = re.compile(r"%(?:%|[fFuUdDnNickvm])")
    cleaned = []
    for token in tokens:
        token = field_codes.sub("", token)
        if "%" in token:
            die(f"desktop-argv: unsupported field code in {path}")
        if token:
            cleaned.append(token)
    if not cleaned:
        die(f"desktop-argv: empty Exec= in {path}")

    def resolve_program(program):
        # Resolved on the session's PATH; the caller (lib/launcher-map.sh) is the
        # fence: it refuses anything not root-owned and group/other-writable, so a
        # PATH a kid can set can make a program absent, never point the map at the
        # kid's own binary (AGENTS.md rule 9 -- see the trust-boundary test's why).
        resolved = shutil.which(program, path=os.environ.get("PATH"))
        if not resolved or not os.path.isabs(resolved):
            die(f"desktop-argv: executable not found for {path}: {program}")
        return resolved

    command_index = 0
    if cleaned[0] == "env":
        cleaned[0] = resolve_program(cleaned[0])
        command_index = 1
        while command_index < len(cleaned) and "=" in cleaned[command_index]:
            command_index += 1
    if command_index >= len(cleaned):
        die(f"desktop-argv: no executable in {path}")
    if os.path.basename(cleaned[command_index]) in {"sh", "bash", "dash", "fish", "zsh"} and "-c" in cleaned:
        die(f"desktop-argv: shell evaluation is not allowed in {path}")
    cleaned[command_index] = resolve_program(cleaned[command_index])
    print(json.dumps(cleaned, separators=(",", ":")))


COMMANDS = {
    "slug": cmd_slug,
    "schema-dump": cmd_schema_dump,
    "band-list": cmd_band_list,
    "band-dump": cmd_band_dump,
    "band-get": cmd_band_get,
    "pack-ids": cmd_pack_ids,
    "pack-sites": cmd_pack_sites,
    "pack-app": cmd_pack_app,
    "desktop-argv": cmd_desktop_argv,
}


def main(argv):
    if not argv or argv[0] not in COMMANDS:
        die(f"usage: conf.py {{{'|'.join(COMMANDS)}}} ...")
    COMMANDS[argv[0]](argv[1:])


if __name__ == "__main__":
    main(sys.argv[1:])
