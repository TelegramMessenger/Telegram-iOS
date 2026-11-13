#!/usr/bin/env python3
"""Checks the watch app's strings against its code and the iOS strings file.

The watch app takes its translations from the iOS app's language packs on
translations.telegram.org, so:

  1. every key the Swift code passes to L(...) / LPlural(...) must be in the
     watch's bundled English table (Localization/Localizable.strings);
  2. every key in that table must exist in
     Telegram/Telegram-iOS/en.lproj/Localizable.strings with the same English
     value, which is how new keys reach the translation platform;
  3. keys in the table that no code uses are reported, so it doesn't grow
     stale.

Usage: check_watch_strings.py [--ios-strings PATH]
Exits non-zero on any error.
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WATCH_ROOT = os.path.dirname(HERE)
APP_DIR = os.path.join(WATCH_ROOT, "tgwatch Watch App")
WATCH_STRINGS = os.path.join(APP_DIR, "Localization", "Localizable.strings")
DEFAULT_IOS_STRINGS = os.path.join(
    WATCH_ROOT, "..", "Telegram-iOS", "en.lproj", "Localizable.strings"
)

PLURAL_SUFFIXES = ["_0", "_1", "_2", "_3_10", "_many", "_any"]

ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)
CALL = re.compile(r'\b(L|LPlural)\(\s*"((?:[^"\\]|\\.)*)"')
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?l?[@dius]")


def strip_comments(text):
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def parse_strings(path):
    with open(path, encoding="utf-8") as f:
        text = strip_comments(f.read())
    entries = {}
    duplicates = []
    for key, value in ENTRY.findall(text):
        if key in entries:
            duplicates.append(key)
        entries[key] = value
    return entries, duplicates


def used_keys():
    """Keys passed to L/LPlural as literals, and every other string literal
    (helpers take keys as arguments)."""
    keys = {}
    literals = set()
    for root, _, files in os.walk(APP_DIR):
        for name in files:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8") as f:
                for lineno, line in enumerate(f, 1):
                    literals.update(LITERAL.findall(line))
                    for function, key in CALL.findall(line):
                        rel = os.path.relpath(path, APP_DIR)
                        keys.setdefault((function, key), []).append(f"{rel}:{lineno}")
    return keys, literals


def placeholder_count(value):
    positions = set()
    sequential = 0
    for match in PLACEHOLDER.finditer(value.replace("%%", "")):
        if match.group(1):
            positions.add(int(match.group(1)))
        else:
            sequential += 1
    return max(positions | {sequential})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ios-strings", default=DEFAULT_IOS_STRINGS)
    args = parser.parse_args()

    errors = []
    warnings = []

    watch, watch_duplicates = parse_strings(WATCH_STRINGS)
    for key in watch_duplicates:
        errors.append(f"duplicate key in watch strings: {key}")

    if os.path.exists(args.ios_strings):
        ios, _ = parse_strings(args.ios_strings)
        for key, value in sorted(watch.items()):
            if key not in ios:
                errors.append(f"{key}: missing from the iOS strings file")
            elif ios[key] != value:
                errors.append(f'{key}: value differs from iOS ("{value}" vs "{ios[key]}")')
    else:
        warnings.append(f"iOS strings file not found at {args.ios_strings}; skipped the iOS check")

    plural_bases = {k[: -len("_any")] for k in watch if k.endswith("_any")}
    referenced = set()
    calls, literals = used_keys()
    for literal in literals:
        if literal in plural_bases:
            referenced.update(literal + suffix for suffix in PLURAL_SUFFIXES)
        elif literal in watch:
            referenced.add(literal)
        elif literal.startswith("Watch.") and " " not in literal:
            errors.append(f"{literal}: looks like a key but is not in the watch strings")
    for (function, key), sites in sorted(calls.items()):
        where = ", ".join(sites)
        if function == "LPlural":
            if key not in plural_bases:
                errors.append(f"{key}: used with LPlural but {key}_any is not in the watch strings ({where})")
            referenced.update(key + suffix for suffix in PLURAL_SUFFIXES)
        else:
            if key not in watch:
                errors.append(f"{key}: used but not in the watch strings ({where})")
            referenced.add(key)

    for key in sorted(watch):
        if key not in referenced:
            warnings.append(f"{key}: in the watch strings but not used")

    # Existing iOS keys are as the iOS app ships them; only lint new ones.
    for base in sorted(b for b in plural_bases if b.startswith("Watch.")):
        for suffix in PLURAL_SUFFIXES:
            if base + suffix not in watch:
                warnings.append(f"{base}: plural form {suffix} missing")

    for key, value in sorted(watch.items()):
        if key.startswith("Watch.") and placeholder_count(value) > 1 and "$" not in value:
            warnings.append(f"{key}: several sequential placeholders; use %1$@ %2$@ so translators can reorder")

    for message in warnings:
        print(f"warning: {message}")
    for message in errors:
        print(f"error: {message}")
    print(f"{len(watch)} strings, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
