#!/usr/bin/env python3
"""Keeps new code from importing or reaching into Postbox.

The Postbox -> TelegramEngine refactor (CLAUDE.md, "Postbox -> TelegramEngine refactor") moves
every module except TelegramCore off Postbox. This check stops it from going backwards, with two
lists that only shrink:

- an in-scope Swift file may import Postbox only while it is listed in
  submodules/Postbox/AllowedImporters.txt, and every listed file must still import it;
- an in-scope Swift file may use `.postbox` (Account.postbox member access, or passing the
  Postbox handle on) only while it is listed in submodules/Postbox/AllowedPostboxAccess.txt, and
  every listed file must still use it. Comments and string literals do not count; code inside
  string interpolation does.

It also fails on any in-scope declaration that conforms to Postbox's `Media` (or `EngineRawMedia`)
without `EngineCustomMedia`: `EngineMedia.init(_:)` has no case for such a type and traps on it.

In scope: Swift files under submodules/ and Telegram/, except Postbox and TelegramCore
themselves and test sources (any directory named `Tests` or ending in `Tests`).

Make.py runs this before `build` and `test`. To run it alone:
    python3 build-system/Make/PostboxImportCheck.py [repository root]
To print the access measures the refactor log records for each wave:
    python3 build-system/Make/PostboxImportCheck.py --report [repository root]
"""

import os
import re
import subprocess
import sys

ALLOWLIST_PATH = 'submodules/Postbox/AllowedImporters.txt'

ACCESS_ALLOWLIST_PATH = 'submodules/Postbox/AllowedPostboxAccess.txt'

SCAN_ROOTS = ('submodules', 'Telegram')

EXEMPT_PREFIXES = ('submodules/Postbox/', 'submodules/TelegramCore/')

# Directory names the filesystem walk never enters. The walk is used when the tree has no git
# metadata: the CI VM receives the source by rsync without .git (TartBuild.py).
PRUNED_DIRECTORY_NAMES = frozenset(['.git', '.build', '.swiftpm', '.claude', 'build-input', 'DerivedData'])

IMPORT_RE = re.compile(
    r'^[ \t]*'
    r'(?:@[A-Za-z_]\w*(?:\([^)\n]*\))?[ \t]+)*'
    r'(?:(?:public|package|internal|fileprivate|private)[ \t]+)?'
    r'import[ \t]+'
    r'(?:(?:class|struct|enum|protocol|typealias|func|var|let)[ \t]+)?'
    r'Postbox(?=[.\s/]|$)',
    re.MULTILINE,
)


ACCESS_RE = re.compile(r'\.postbox\b')
MEDIABOX_RE = re.compile(r'\.postbox\.mediaBox\b(?:\.([A-Za-z_]\w*))?')
MEMBER_RE = re.compile(r'\.postbox\b(?:\.([A-Za-z_]\w*))?')


# Where the scanner may stop next, per state. Everything between two stops is copied (code) or
# blanked (strings, comments) in one slice, so the scan runs at regex speed rather than one
# Python step per character.
_CODE_STOPS = re.compile(r'//|/\*|"')
_INTERPOLATION_STOPS = re.compile(r'//|/\*|"|[()]')
_BLOCK_COMMENT_STOPS = re.compile(r'/\*|\*/')
_STRING_STOPS = re.compile(r'\\|"|\n')
_MULTILINE_STRING_STOPS = re.compile(r'\\|"""')
_NOT_NEWLINE = re.compile(r'[^\n]')


def _blank(text):
    return _NOT_NEWLINE.sub(' ', text)


def strip_comments_and_strings(text):
    """`text` with comments and string-literal contents blanked to spaces, newlines kept.

    Code inside string interpolation `\\( ... )` is kept, so `"\\(account.postbox)"` still reads as
    access. Handles `//`, nested `/* */`, `"..."` and multi-line triple-quoted literals.
    """
    out = []
    i = 0
    n = len(text)
    stack = [['code', 0]]  # [kind, paren depth]; kinds: code, str, mstr
    while i < n:
        top = stack[-1]
        kind = top[0]
        if kind == 'code':
            match = (_INTERPOLATION_STOPS if len(stack) > 1 else _CODE_STOPS).search(text, i)
            if match is None:
                out.append(text[i:])
                break
            out.append(text[i:match.start()])
            i = match.start()
            stop = match.group(0)
            if stop == '//':
                j = text.find('\n', i)
                j = n if j < 0 else j
                out.append(' ' * (j - i))
                i = j
            elif stop == '/*':
                depth = 0
                j = i
                while True:
                    inner = _BLOCK_COMMENT_STOPS.search(text, j)
                    if inner is None:
                        j = n
                        break
                    j = inner.end()
                    if inner.group(0) == '/*':
                        depth += 1
                    else:
                        depth -= 1
                        if depth == 0:
                            break
                out.append(_blank(text[i:j]))
                i = j
            elif stop == '"':
                if text.startswith('"""', i):
                    stack.append(['mstr', 0])
                    out.append('   ')
                    i += 3
                else:
                    stack.append(['str', 0])
                    out.append(' ')
                    i += 1
            elif stop == '(':
                top[1] += 1
                out.append('(')
                i += 1
            elif top[1] == 0:
                # the `)` that closes a string interpolation
                stack.pop()
                out.append(' ')
                i += 1
            else:
                top[1] -= 1
                out.append(')')
                i += 1
            continue
        match = (_MULTILINE_STRING_STOPS if kind == 'mstr' else _STRING_STOPS).search(text, i)
        if match is None:
            out.append(_blank(text[i:]))
            break
        out.append(_blank(text[i:match.start()]))
        i = match.start()
        stop = match.group(0)
        if stop == '\\':
            if i + 1 < n:
                if text[i + 1] == '(':
                    stack.append(['code', 0])
                    out.append('  ')
                else:
                    out.append(' \n' if text[i + 1] == '\n' else '  ')
                i += 2
            else:
                out.append(' ')
                i += 1
        elif stop == '"""' or stop == '"':
            stack.pop()
            out.append(' ' * len(stop))
            i += len(stop)
        else:
            # a newline ends an unterminated single-line string
            stack.pop()
            out.append('\n')
            i += 1
    return ''.join(out)


# A type that conforms to Postbox's `Media` (directly, or through the `EngineRawMedia` alias)
# outside TelegramCore has no `EngineMedia` case, so `EngineMedia.init(_:)` traps on it in release.
# App-side pseudo-media must conform to `EngineCustomMedia` instead, which wraps as `.custom`.
RAW_MEDIA_PROTOCOLS = frozenset(['Media', 'Postbox.Media', 'EngineRawMedia'])
WRAPPABLE_MEDIA_PROTOCOL = 'EngineCustomMedia'
_CONFORMANCE_RE = re.compile(r'\b(?:class|struct|enum|protocol|extension|actor)\s+([A-Za-z_][\w.]*)\s*(?:<[^>{]*>)?\s*:\s*([^{]*)\{')
# A cheap, linear byte-level prefilter: an inheritance list names a protocol followed by `,` or `{`.
# Only files that pass are stripped and parsed.
_CONFORMANCE_PREFILTER = re.compile(rb'\b(?:Media|EngineRawMedia)\s*[,{]')


def find_unwrappable_media(text):
    """[(line, type name)] for each declaration in `text` that conforms to `Media` without `EngineCustomMedia`."""
    code = strip_comments_and_strings(text)
    found = []
    for match in _CONFORMANCE_RE.finditer(code):
        inherited = re.split(r'\bwhere\b', match.group(2))[0]
        names = [part.strip().split('<')[0].strip() for part in inherited.split(',')]
        if WRAPPABLE_MEDIA_PROTOCOL in names:
            continue
        if any(name in RAW_MEDIA_PROTOCOLS for name in names):
            found.append((code.count('\n', 0, match.start()) + 1, match.group(1)))
    return found


MEDIA_CONFORMANCE_MESSAGE = ('{path}:{line}: {name} conforms to Media without EngineCustomMedia, so '
                             'EngineMedia.init(_:) would trap on it in release builds. Declare it '
                             '`: EngineCustomMedia` instead (it wraps as EngineMedia.custom); see CLAUDE.md, '
                             '"Engine wrapper cheat sheet".')


def media_conformance_errors(base_path, use_git=None):
    """One problem line per in-scope declaration that conforms to `Media` without `EngineCustomMedia`."""
    errors = []
    for path in candidate_paths(base_path, use_git=use_git):
        with open(os.path.join(base_path, path), 'rb') as f:
            data = f.read()
        if not _CONFORMANCE_PREFILTER.search(data):
            continue
        for line, name in find_unwrappable_media(data.decode('utf-8', 'replace')):
            errors.append(MEDIA_CONFORMANCE_MESSAGE.format(path=path, line=line, name=name))
    return errors


def find_access_line(text):
    """The 1-based line of the first `.postbox` access in `text` (comments and strings ignored), or None."""
    code = strip_comments_and_strings(text)
    match = ACCESS_RE.search(code)
    if match is None:
        return None
    return code.count('\n', 0, match.start()) + 1


def is_test_path(path):
    return any(component == 'Tests' or component.endswith('Tests') for component in path.split('/')[:-1])


def is_in_scope(path):
    return (
        path.endswith('.swift')
        and path.split('/', 1)[0] in SCAN_ROOTS
        and not path.startswith(EXEMPT_PREFIXES)
        and not is_test_path(path)
    )


def find_import_line(text):
    """The 1-based line of the first Postbox import in `text`, or None."""
    match = IMPORT_RE.search(text)
    if match is None:
        return None
    return text.count('\n', 0, match.start()) + 1


def _git_paths(base_path):
    try:
        completed = subprocess.run(
            ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard', '--'] + list(SCAN_ROOTS),
            cwd=base_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return [path for path in completed.stdout.decode('utf-8', 'surrogateescape').split('\0') if path]


def _walked_paths(base_path):
    paths = []
    for root in SCAN_ROOTS:
        for directory, subdirectories, filenames in os.walk(os.path.join(base_path, root)):
            subdirectories[:] = sorted(
                name for name in subdirectories
                if name not in PRUNED_DIRECTORY_NAMES
                and not name.startswith('bazel-')
                and not os.path.islink(os.path.join(directory, name))
            )
            for name in filenames:
                if name.endswith('.swift'):
                    paths.append(os.path.relpath(os.path.join(directory, name), base_path).replace(os.sep, '/'))
    return paths


def candidate_paths(base_path, use_git=None):
    """Repository-relative paths of the in-scope Swift files present on disk.

    Uses `git ls-files` when `base_path` is a checkout, so ignored files are skipped and new
    untracked ones are seen; walks the tree otherwise. `use_git` forces one or the other.
    """
    if use_git is None:
        use_git = os.path.exists(os.path.join(base_path, '.git'))
    paths = _git_paths(base_path) if use_git else None
    if paths is None:
        paths = _walked_paths(base_path)
    return sorted(set(
        path for path in paths
        if is_in_scope(path) and os.path.isfile(os.path.join(base_path, path))
    ))


def postbox_importers(base_path, use_git=None):
    """{path: line of its first Postbox import} for every in-scope file that imports Postbox."""
    importers = {}
    for path in candidate_paths(base_path, use_git=use_git):
        with open(os.path.join(base_path, path), 'rb') as f:
            data = f.read()
        if b'Postbox' not in data:
            continue
        line = find_import_line(data.decode('utf-8', 'replace'))
        if line is not None:
            importers[path] = line
    return importers


def postbox_accessors(base_path, use_git=None):
    """{path: line of its first `.postbox` access} for every in-scope file that uses `.postbox`."""
    accessors = {}
    for path in candidate_paths(base_path, use_git=use_git):
        with open(os.path.join(base_path, path), 'rb') as f:
            data = f.read()
        if b'.postbox' not in data:
            continue
        line = find_access_line(data.decode('utf-8', 'replace'))
        if line is not None:
            accessors[path] = line
    return accessors


def scan_tree(base_path, use_git=None):
    """(importers, accessors, conformance problems) for the in-scope files, reading each file once.

    The same results as `postbox_importers`, `postbox_accessors` and `media_conformance_errors`.
    """
    importers = {}
    accessors = {}
    conformance_errors = []
    for path in candidate_paths(base_path, use_git=use_git):
        with open(os.path.join(base_path, path), 'rb') as f:
            data = f.read()
        if b'Postbox' not in data and b'.postbox' not in data and not _CONFORMANCE_PREFILTER.search(data):
            continue
        text = data.decode('utf-8', 'replace')
        if b'Postbox' in data:
            line = find_import_line(text)
            if line is not None:
                importers[path] = line
        if b'.postbox' in data:
            line = find_access_line(text)
            if line is not None:
                accessors[path] = line
        if _CONFORMANCE_PREFILTER.search(data):
            for line, name in find_unwrappable_media(text):
                conformance_errors.append(MEDIA_CONFORMANCE_MESSAGE.format(path=path, line=line, name=name))
    return importers, accessors, conformance_errors


def read_list(base_path, list_path):
    """[(line number, path)] for each entry of `list_path`, skipping blank lines and `#` comments."""
    entries = []
    with open(os.path.join(base_path, list_path), encoding='utf-8') as f:
        for number, line in enumerate(f, start=1):
            entry = line.strip()
            if entry and not entry.startswith('#'):
                entries.append((number, entry))
    return entries


def read_allowlist(base_path):
    """[(line number, path)] for each entry of the import allowlist."""
    return read_list(base_path, ALLOWLIST_PATH)


IMPORT_UNLISTED = ('{path}:{line}: imports Postbox, which new code must not do. Use TelegramEngine and its '
                   'wrappers (EnginePeer, EngineMessage, EngineMedia, ...) instead; see CLAUDE.md, '
                   '"Postbox -> TelegramEngine refactor". To allow it deliberately, add the path to {list}.')
IMPORT_STALE = '{where}: {path} no longer imports Postbox; delete this line.'
ACCESS_UNLISTED = ('{path}:{line}: uses .postbox, which new code must not do. Use TelegramEngine '
                   '(context.engine...) instead; see CLAUDE.md, "Postbox -> TelegramEngine refactor". '
                   'To allow it deliberately, add the path to {list}.')
ACCESS_STALE = '{where}: {path} no longer uses .postbox; delete this line.'


def _check_list(base_path, list_path, found, unlisted_message, stale_message):
    """Problems with one shrink-only list: its own shape, unlisted `found` files and stale entries."""
    try:
        entries = read_list(base_path, list_path)
    except FileNotFoundError:
        return ['{} is missing.'.format(list_path)]

    errors = []
    first_line = {}
    previous = None
    for number, path in entries:
        where = '{}:{}'.format(list_path, number)
        if path in first_line:
            errors.append('{}: {} is listed twice; delete this line.'.format(where, path))
            continue
        first_line[path] = number
        if previous is not None and path < previous:
            errors.append('{}: {} is out of order; keep the entries sorted.'.format(where, path))
        previous = path
        if not is_in_scope(path):
            errors.append('{}: {} is not checked (a test path, or Postbox/TelegramCore); delete this line.'.format(where, path))

    for path in sorted(found):
        if path not in first_line:
            errors.append(unlisted_message.format(path=path, line=found[path], list=list_path))

    for path, number in sorted(first_line.items(), key=lambda item: item[1]):
        if path in found or not is_in_scope(path):
            continue
        where = '{}:{}'.format(list_path, number)
        if os.path.isfile(os.path.join(base_path, path)):
            errors.append(stale_message.format(where=where, path=path))
        else:
            errors.append('{}: {} no longer exists; delete this line.'.format(where, path))
    return errors


def check(base_path):
    """Every problem found, one printable line each. An empty list means the check passed."""
    importers, accessors, conformance_errors = scan_tree(base_path)
    errors = _check_list(base_path, ALLOWLIST_PATH, importers, IMPORT_UNLISTED, IMPORT_STALE)
    errors += _check_list(base_path, ACCESS_ALLOWLIST_PATH, accessors, ACCESS_UNLISTED, ACCESS_STALE)
    errors += conformance_errors
    return errors


def report(base_path):
    """The refactor's access measures, computed on comment- and string-stripped code.

    importers: in-scope files importing Postbox. access_files: in-scope files using `.postbox`.
    handle_sites: `.postbox` uses that call no member (the handle is passed on or stored).
    mediabox_sites / mediabox_by_member: `.postbox.mediaBox` uses, by the member called on it
    (`(handle)` when the MediaBox itself is passed on). mediabox_only_files: files whose every
    `.postbox` use is `.postbox.mediaBox`.
    """
    importers = postbox_importers(base_path)
    access_files = 0
    handle_sites = 0
    mediabox_sites = 0
    by_member = {}
    mediabox_only = 0
    for path in candidate_paths(base_path):
        with open(os.path.join(base_path, path), 'rb') as f:
            data = f.read()
        if b'.postbox' not in data:
            continue
        code = strip_comments_and_strings(data.decode('utf-8', 'replace'))
        members = [match.group(1) for match in MEMBER_RE.finditer(code)]
        if not members:
            continue
        access_files += 1
        handle_sites += sum(1 for member in members if member is None)
        boxes = [match.group(1) or '(handle)' for match in MEDIABOX_RE.finditer(code)]
        mediabox_sites += len(boxes)
        for member in boxes:
            by_member[member] = by_member.get(member, 0) + 1
        if boxes and all(member == 'mediaBox' for member in members):
            mediabox_only += 1
    return {
        'importers': len(importers),
        'access_files': access_files,
        'handle_sites': handle_sites,
        'mediabox_sites': mediabox_sites,
        'mediabox_by_member': by_member,
        'mediabox_only_files': mediabox_only,
    }


def _emit(line):
    encoding = getattr(sys.stderr, 'encoding', None) or 'ascii'
    sys.stderr.write(line.encode(encoding, 'backslashreplace').decode(encoding) + '\n')


def run(base_path):
    """Print any problems to stderr and return the exit status (0 means the check passed)."""
    errors = check(base_path)
    if not errors:
        return 0
    _emit('PostboxImportCheck: {} problem(s):'.format(len(errors)))
    for error in errors:
        _emit('  ' + error)
    return 1


if __name__ == '__main__':
    arguments = sys.argv[1:]
    if arguments and arguments[0] == '--report':
        result = report(arguments[1] if len(arguments) > 1 else os.getcwd())
        for key in ('importers', 'access_files', 'handle_sites', 'mediabox_sites', 'mediabox_only_files'):
            print('{}: {}'.format(key, result[key]))
        for member, count in sorted(result['mediabox_by_member'].items(), key=lambda item: (-item[1], item[0])):
            print('  mediaBox.{}: {}'.format(member, count))
        sys.exit(0)
    sys.exit(run(arguments[0] if arguments else os.getcwd()))
