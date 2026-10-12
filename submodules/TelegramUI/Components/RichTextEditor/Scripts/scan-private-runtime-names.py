#!/usr/bin/env python3
"""Reports every private UIKit name from Scripts/private-runtime-names.txt that a binary still
carries as text.

Usage: Scripts/scan-private-runtime-names.py <Mach-O, static archive or .o> ...

Reads the sections a name can reach in a build: the Objective-C method and class names (selectors,
method and property names, ivar names), C strings, Swift reflection strings, and the constant data
the embedded contract tables live in. A name is reported when it appears as a WHOLE string in a
string section, or anywhere in constant data (the tables are one long JSON blob, not separate
strings). Exits 1 when anything is found.

Run it on the release framework after a Make.py release build:
    unzip -o bazel-bin/Telegram/Telegram.ipa 'Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/*' -d <dir>
    Scripts/scan-private-runtime-names.py <dir>/Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework
and on the engine's static archives, which attribute a hit to a module.

A hit is not by itself a private API reference. The table holds names the engine crosses with
UIKit, and some are ordinary words (`selectionChanged`, `textInputTraits`): another module's own
Swift field or enum case of that name lands in `__swift5_reflstr`, and an Objective-C ivar or
method of ours in `__objc_methname`. Attribute every hit to an archive and a section before
calling it a leak. The release result on 2026-10-12, and what each hit is, is in the package
CLAUDE.md, "Private UIKit names are not in the binary".
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, 'Scripts', 'private-runtime-names.txt')
STRING_SECTIONS = [('__TEXT', '__objc_methname'), ('__TEXT', '__objc_classname'),
                   ('__TEXT', '__cstring'), ('__TEXT', '__swift5_reflstr')]
DATA_SECTIONS = [('__TEXT', '__const'), ('__DATA', '__const'), ('__DATA_CONST', '__const')]
# A name shorter than this is not searched for inside constant data, where any short run of bytes
# can occur by accident.
MIN_DATA_MATCH = 8


def names():
    return [l.strip() for l in open(LIST, encoding='utf-8') if l.strip() and not l.startswith('#')]


def otool(args, path):
    return subprocess.run(['otool'] + args + [path], capture_output=True, text=True, errors='replace').stdout


def strings_in(path, segment, section):
    # Read the section's raw bytes and split them on NUL, rather than asking `otool -v` to print
    # it as strings: `-v` prints only the sections otool knows to be C strings that way, and dumps
    # `__swift5_reflstr` as hex, so reading its lines checked no reflection string at all (found
    # 2026-10-12 when a Swift enum case named like a private selector was in an archive's bytes and
    # the scan said nothing).
    return {chunk.decode('utf-8', 'replace') for chunk in data_in(path, segment, section).split(b'\x00') if chunk}


def data_in(path, segment, section):
    # `otool -s` prints an arm64 section as little-endian 32-bit WORDS ("696e612f" is the bytes
    # "/ani"), not as bytes, so each 8-digit token is reversed back into byte order. Read as plain
    # hex, every word came out byte-swapped and no name in constant data could ever match.
    chunks = []
    for line in otool(['-X', '-s', segment, section], path).splitlines():
        line = re.sub(r'^[0-9a-f]{8,16}\s+', '', line.strip())
        for token in line.split():
            try:
                raw = bytes.fromhex(token)
            except ValueError:
                continue
            chunks.append(raw[::-1] if len(token) == 8 else raw)
    return b''.join(chunks)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    table = names()
    total = 0
    for path in sys.argv[1:]:
        strings = set()
        for segment, section in STRING_SECTIONS:
            strings |= strings_in(path, segment, section)
        data = b''.join(data_in(path, segment, section) for segment, section in DATA_SECTIONS)
        hits = []
        for name in table:
            pattern = re.compile(r'(?<![A-Za-z0-9_])' + re.escape(name) + r'(?![A-Za-z0-9_:])')
            if name in strings:
                hits.append((name, 'string'))
            elif len(name) >= MIN_DATA_MATCH and any(pattern.search(s) for s in strings):
                hits.append((name, 'inside a string'))
            elif len(name) >= MIN_DATA_MATCH and name.encode() in data:
                hits.append((name, 'data'))
        total += len(hits)
        print(f'{path}: {len(hits)} private name(s)')
        for name, where in hits:
            print(f'    {name}  ({where})')
    sys.exit(1 if total else 0)


if __name__ == '__main__':
    main()
