#!/usr/bin/env python3
"""Check that every L10n key used by the macOS UI exists in every language.

Run from the repository root:

    python3 scripts/check_localization.py

It scans ContentView.swift and the Views, Keyboard, Screen and Lighting
folders for L10n.text("...") and
L10n.format("...") calls, then looks for each key in every
Resources/*.lproj/Localizable.strings file. Exits with status 1 and lists
the gaps if any key is missing.
"""

import re
import sys
from pathlib import Path

APP_DIR = Path("Sources/AulaF75MaxDriver")
RESOURCES_DIR = APP_DIR / "Resources"

# A Swift string literal body: any character except a quote or backslash,
# or a backslash followed by any character (an escape like \" or \n).
STRING_BODY = r'((?:[^"\\]|\\.)*)'
USAGE_PATTERN = re.compile(r'L10n\.(?:text|format)\("' + STRING_BODY + '"')
STRINGS_KEY_PATTERN = re.compile(r'^"' + STRING_BODY + r'"\s*=')


def keys_used_in_ui() -> set[str]:
    ui_folders = ["Views", "Keyboard", "Screen", "Lighting"]
    swift_files = [APP_DIR / "ContentView.swift"]
    for folder in ui_folders:
        swift_files.extend(sorted((APP_DIR / folder).glob("*.swift")))
    keys = set()
    for path in swift_files:
        if path.exists():
            keys.update(USAGE_PATTERN.findall(path.read_text(encoding="utf-8")))
    # Keys with no letters, like "%d%%", read the same in every language,
    # and L10n falls back to the key itself, so they need no translation.
    return {key for key in keys if any(character.isalpha() for character in key)}


def keys_in_strings_file(path: Path) -> set[str]:
    keys = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = STRINGS_KEY_PATTERN.match(line)
        if match:
            keys.add(match.group(1))
    return keys


def main() -> int:
    used = keys_used_in_ui()
    strings_files = sorted(RESOURCES_DIR.glob("*.lproj/Localizable.strings"))
    if not strings_files:
        print(f"No Localizable.strings files found under {RESOURCES_DIR}")
        return 1

    missing_count = 0
    for strings_file in strings_files:
        language = strings_file.parent.stem
        available = keys_in_strings_file(strings_file)
        for key in sorted(used - available):
            print(f'{language}: missing "{key}"')
            missing_count += 1

    if missing_count:
        print(f"FAIL: {missing_count} missing translation(s)")
        return 1

    print(f"OK: {len(used)} keys in {len(strings_files)} languages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
