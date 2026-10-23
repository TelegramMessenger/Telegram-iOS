#!/usr/bin/env python3
"""Keeps the app from importing a non-public function of the system ICU.

libicucore ships with iOS, but only the functions the SDK's own headers declare
($SDK/usr/include/unicode/*.h: character properties, case mapping, UTF, IDNA, regex) are public API.
App Store review rejects a build that imports any other of its symbols ("Non-public API usage",
90338), and nothing fails before then: the SDK's libicucore.tbd exports all of them, so a function
declared by hand links. This check reads every Mach-O binary of the built .ipa (the app, its
frameworks and its extensions) with `xcrun dyld_info -imports`, and fails on any symbol bound to
libicucore that no SDK header declares.

Make.py runs it after `build`, on bazel-bin/Telegram/Telegram.ipa. To run it alone:
    python3 build-system/Make/ICUImportCheck.py <.ipa, .app or Mach-O binary> ...
"""

import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# The prefix of a Mach-O binary of the bundle: the app's, a framework's, an extension's.
BINARY_PATTERNS = (
    re.compile(r'^Payload/[^/]+\.app/([^/.]+)$'),
    re.compile(r'^Payload/[^/]+\.app/Frameworks/([^/]+)\.framework/\1$'),
    re.compile(r'^Payload/[^/]+\.app/PlugIns/([^/]+)\.appex/\1$'),
)

IMPORT_LINE = re.compile(r'^\s*0x[0-9A-Fa-f]+\s+_?(\S+?)(?:\s+\[[^\]]*\])*\s+\(from libicucore\)\s*$')


def declared_functions(header_texts):
    """The names of the functions `header_texts` declare: ICU's `U_CAPI <type> U_EXPORT2 name(`."""
    names = set()
    for text in header_texts:
        text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
        text = re.sub(r'//[^\n]*', '', text)
        names.update(match.group(1) for match in re.finditer(r'\bU_EXPORT2\s+(\w+)\s*\(', text))
    return names


def sdk_public_functions():
    sdk = subprocess.run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], capture_output=True, text=True, check=True).stdout.strip()
    texts = []
    for path in sorted(glob.glob(os.path.join(sdk, 'usr', 'include', 'unicode', '*.h'))):
        with open(path, encoding='utf-8', errors='replace') as file:
            texts.append(file.read())
    return declared_functions(texts)


def icu_imports(dyld_info_output):
    """The symbols `dyld_info -imports` lists as bound to libicucore, without their leading underscore."""
    names = set()
    for line in dyld_info_output.splitlines():
        match = IMPORT_LINE.match(line)
        if match:
            names.add(match.group(1))
    return names


def binary_imports(path):
    output = subprocess.run(['xcrun', 'dyld_info', '-imports', path], capture_output=True, text=True, check=True).stdout
    return icu_imports(output)


def bundle_binaries(ipa_path, directory):
    """Extracts the bundle's Mach-O binaries into `directory`: (name in the bundle, extracted path)."""
    out = []
    with zipfile.ZipFile(ipa_path) as archive:
        for name in archive.namelist():
            if any(pattern.match(name) for pattern in BINARY_PATTERNS):
                out.append((name, archive.extract(name, directory)))
    return out


def private_imports(paths):
    """{binary: sorted libicucore imports no SDK header declares} for every binary of `paths` that has any."""
    public = sdk_public_functions()
    found = {}
    work = tempfile.mkdtemp(prefix='icu-import-check-')
    try:
        binaries = []
        for path in paths:
            if path.endswith('.ipa'):
                binaries.extend(bundle_binaries(path, work))
            elif os.path.isdir(path):
                for root, _, files in os.walk(path):
                    binaries.extend((os.path.join(root, f), os.path.join(root, f)) for f in files if not os.path.splitext(f)[1])
            else:
                binaries.append((path, path))
        for name, binary in binaries:
            with open(binary, 'rb') as file:
                magic = file.read(4)
            if magic not in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
                continue
            private = sorted(binary_imports(binary) - public)
            if private:
                found[name] = private
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return found


def run(paths):
    found = private_imports(paths)
    for name, symbols in found.items():
        print('ICUImportCheck: {} imports libicucore functions that are not public API (App Store review rejects them; '
              'only what $SDK/usr/include/unicode/*.h declares may be called):'.format(name))
        for symbol in symbols:
            print('  ' + symbol)
    return 1 if found else 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(run(sys.argv[1:]))
