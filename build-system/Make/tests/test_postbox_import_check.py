"""Tests for PostboxImportCheck.

Run: python3 -m unittest discover -s build-system/Make/tests -v
"""

import io
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import PostboxImportCheck  # noqa: E402

ALLOWLIST = PostboxImportCheck.ALLOWLIST_PATH
ACCESS = PostboxImportCheck.ACCESS_ALLOWLIST_PATH


class TreeTestCase(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.allow()
        self.allow_access()

    def tearDown(self):
        shutil.rmtree(self.root)

    def write(self, path, text):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8', newline='') as f:
            f.write(text)

    def allow(self, *paths):
        # Line 1 is a comment and line 2 is blank, so the first entry is on line 3.
        self.write(ALLOWLIST, '# Files that may still import Postbox.\n\n' + ''.join(path + '\n' for path in paths))

    def allow_access(self, *paths):
        # Same layout as allow(): the first entry is on line 3.
        self.write(ACCESS, '# Files that may still use .postbox.\n\n' + ''.join(path + '\n' for path in paths))

    def errors(self):
        return PostboxImportCheck.check(self.root)


class ImportDetectionTests(unittest.TestCase):
    def test_import_forms_are_detected(self):
        for source in [
            'import Postbox\n',
            'import Foundation\nimport Postbox\n',
            '@testable import Postbox\n',
            '@_implementationOnly import Postbox\n',
            '@preconcurrency import Postbox\n',
            '@_spi(Internal) import Postbox\n',
            'internal import Postbox\n',
            'public import Postbox\n',
            'import struct Postbox.MessageId\n',
            'import Postbox.Submodule\n',
            '    import Postbox\n',
            '#if DEBUG\nimport Postbox\n#endif\n',
            'import Postbox // still needed\n',
            'import Postbox\r\n',
            'import Postbox',
        ]:
            with self.subTest(source=source):
                self.assertIsNotNone(PostboxImportCheck.find_import_line(source))

    def test_reported_line_is_the_import_line(self):
        self.assertEqual(PostboxImportCheck.find_import_line('import Foundation\n\nimport Postbox\n'), 3)

    def test_non_imports_are_ignored(self):
        for source in [
            '// import Postbox\n',
            '/* import Postbox */\n',
            'import PostboxExtras\n',
            'import TelegramCore\nlet postbox: Postbox\n',
            'let text = "import Postbox"\n',
            'importPostbox\n',
        ]:
            with self.subTest(source=source):
                self.assertIsNone(PostboxImportCheck.find_import_line(source))


class ScopeTests(TreeTestCase):
    def test_unlisted_importer_fails_naming_file_and_line(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Foundation\nimport Postbox\n')
        errors = self.errors()
        self.assertEqual(len(errors), 1, errors)
        self.assertTrue(errors[0].startswith('submodules/Foo/Sources/A.swift:2: imports Postbox'), errors[0])
        self.assertIn(ALLOWLIST, errors[0])

    def test_listed_importer_passes(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Postbox\n')
        self.allow('submodules/Foo/Sources/A.swift')
        self.assertEqual(self.errors(), [])

    def test_app_and_extension_sources_are_checked(self):
        self.write('Telegram/SiriIntents/A.swift', 'import Postbox\n')
        self.write('Telegram/NotificationService/Sources/B.swift', 'import Postbox\n')
        self.assertEqual(len(self.errors()), 2)

    def test_test_paths_are_exempt(self):
        for path in [
            'submodules/Foo/Tests/T.swift',
            'submodules/Foo/Tests/Nested/T.swift',
            'Telegram/SiriIntentsTests/T.swift',
            'Tests/ComposerHarness/AppContext/H.swift',
        ]:
            self.write(path, '@testable import Postbox\n')
        self.assertEqual(self.errors(), [])

    def test_postbox_and_telegramcore_are_exempt(self):
        self.write('submodules/Postbox/Sources/P.swift', 'import Postbox\n')
        self.write('submodules/TelegramCore/Sources/C.swift', 'import Postbox\n')
        self.assertEqual(self.errors(), [])

    def test_paths_with_spaces(self):
        path = 'submodules/SettingsUI/Sources/Data and Storage/S.swift'
        self.write(path, 'import Postbox\n')
        errors = self.errors()
        self.assertEqual(len(errors), 1, errors)
        self.assertTrue(errors[0].startswith(path + ':1: imports Postbox'), errors[0])
        self.allow(path)
        self.assertEqual(self.errors(), [])


class AllowlistTests(TreeTestCase):
    def test_listed_file_without_import_is_stale(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Foundation\n')
        self.allow('submodules/Foo/Sources/A.swift')
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Sources/A.swift no longer imports Postbox; delete this line.'.format(ALLOWLIST),
        ])

    def test_listed_missing_file_is_stale(self):
        self.allow('submodules/Foo/Sources/Gone.swift')
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Sources/Gone.swift no longer exists; delete this line.'.format(ALLOWLIST),
        ])

    def test_unsorted_entries_fail(self):
        self.write('submodules/A/Sources/A.swift', 'import Postbox\n')
        self.write('submodules/B/Sources/B.swift', 'import Postbox\n')
        self.allow('submodules/B/Sources/B.swift', 'submodules/A/Sources/A.swift')
        self.assertEqual(self.errors(), [
            '{}:4: submodules/A/Sources/A.swift is out of order; keep the entries sorted.'.format(ALLOWLIST),
        ])

    def test_duplicate_entries_fail(self):
        self.write('submodules/A/Sources/A.swift', 'import Postbox\n')
        self.allow('submodules/A/Sources/A.swift', 'submodules/A/Sources/A.swift')
        self.assertEqual(self.errors(), [
            '{}:4: submodules/A/Sources/A.swift is listed twice; delete this line.'.format(ALLOWLIST),
        ])

    def test_out_of_scope_entry_fails(self):
        self.write('submodules/Foo/Tests/T.swift', 'import Postbox\n')
        self.allow('submodules/Foo/Tests/T.swift')
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Tests/T.swift is not checked (a test path, or Postbox/TelegramCore); delete this line.'.format(ALLOWLIST),
        ])

    def test_missing_allowlist_is_reported(self):
        os.remove(os.path.join(self.root, ALLOWLIST))
        self.assertEqual(self.errors(), ['{} is missing.'.format(ALLOWLIST)])


class WalkTests(TreeTestCase):
    def test_walk_prunes_build_directories_and_symlinked_directories(self):
        self.write('submodules/Foo/.build/checkouts/A.swift', 'import Postbox\n')
        self.write('submodules/Foo/.swiftpm/B.swift', 'import Postbox\n')
        self.write('elsewhere/C.swift', 'import Postbox\n')
        os.symlink(os.path.join(self.root, 'elsewhere'), os.path.join(self.root, 'submodules', 'Linked'))
        self.assertEqual(self.errors(), [])

    def test_files_outside_the_scan_roots_are_ignored(self):
        self.write('third-party/X/A.swift', 'import Postbox\n')
        self.write('.claude/worktrees/w/submodules/Foo/A.swift', 'import Postbox\n')
        self.assertEqual(self.errors(), [])


class OutputTests(TreeTestCase):
    def test_run_returns_zero_when_clean(self):
        self.assertEqual(PostboxImportCheck.run(self.root), 0)

    def test_run_survives_ascii_stderr(self):
        self.write('submodules/Foo/Sources/é.swift', 'import Postbox\n')
        stream = io.TextIOWrapper(io.BytesIO(), encoding='ascii')
        original = sys.stderr
        sys.stderr = stream
        try:
            status = PostboxImportCheck.run(self.root)
        finally:
            sys.stderr = original
        self.assertEqual(status, 1)
        stream.flush()
        self.assertIn(b'imports Postbox', stream.buffer.getvalue())


@unittest.skipIf(shutil.which('git') is None, 'git is not installed')
class GitModeTests(TreeTestCase):
    def setUp(self):
        super().setUp()
        self.git('init', '-q')

    def git(self, *arguments):
        subprocess.run(['git'] + list(arguments), cwd=self.root, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def test_untracked_unignored_importer_is_reported(self):
        self.write('submodules/Foo/Sources/New.swift', 'import Postbox\n')
        self.assertEqual(len(self.errors()), 1)

    def test_ignored_importer_is_not_reported(self):
        self.write('.gitignore', 'submodules/Foo/Generated/\n')
        self.write('submodules/Foo/Generated/G.swift', 'import Postbox\n')
        self.assertEqual(self.errors(), [])

    def test_staged_file_deleted_from_disk_is_stale(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Postbox\n')
        self.allow('submodules/Foo/Sources/A.swift')
        self.git('add', '-A')
        os.remove(os.path.join(self.root, 'submodules/Foo/Sources/A.swift'))
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Sources/A.swift no longer exists; delete this line.'.format(ALLOWLIST),
        ])

    def test_git_and_walk_agree_on_a_clean_tree(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Postbox\n')
        self.write('submodules/Foo/Sources/Data and Storage/B.swift', '@testable import Postbox\n')
        self.git('add', '-A')
        self.assertEqual(
            PostboxImportCheck.postbox_importers(self.root, use_git=True),
            PostboxImportCheck.postbox_importers(self.root, use_git=False),
        )


class AccessDetectionTests(unittest.TestCase):
    def test_access_forms_are_detected(self):
        for source in [
            'let a = context.account.postbox.mediaBox\n',
            'let a = self.postbox\n',
            'f(postbox: account.postbox)\n',
            'let a = x!.postbox.transaction { _ in }\n',
            'let p = "\\(context.account.postbox.mediaBox.basePath)/cache"\n',
            'let p = """\n  \\(account.postbox.mediaBox.basePath)\n  """\n',
            'let p = "a\\("b\\(account.postbox)")"\n',
        ]:
            with self.subTest(source=source):
                self.assertIsNotNone(PostboxImportCheck.find_access_line(source))

    def test_reported_line_is_the_access_line(self):
        self.assertEqual(PostboxImportCheck.find_access_line('import Foundation\n// account.postbox\nlet a = account.postbox\n'), 3)

    def test_non_access_is_ignored(self):
        for source in [
            '// let a = account.postbox\n',
            '/* account.postbox */\n',
            '/* outer /* inner */ account.postbox, still comment */\n',
            'let s = "account.postbox"\n',
            'let s = """\naccount.postbox\n"""\n',
            'let s = "escaped \\" account.postbox"\n',
            'let postbox = makePostbox()\n',
            'let a = x.postboxes\n',
            'let a = x.postboxValue\n',
        ]:
            with self.subTest(source=source):
                self.assertIsNone(PostboxImportCheck.find_access_line(source))

    def test_stripping_keeps_line_count(self):
        source = 'a\n/* b\n c */ "d\\(e)"\n"""\nf\n"""\n'
        self.assertEqual(PostboxImportCheck.strip_comments_and_strings(source).count('\n'), source.count('\n'))

    def test_stripping_is_fast_on_large_sources(self):
        # The check runs before every Make.py build over ~230 files; a per-character Python loop
        # made it cost ~6 s (17 MB at ~4 MB/s). Strip ~10 MB of typical Swift in under a second.
        line = 'let value = context.account.postbox.mediaBox.resourceData(file.resource) // note "x"\n'
        source = ('/* header */\n' + line + 'let s = "text \\(a.b) more"\n') * 80000
        start = time.perf_counter()
        stripped = PostboxImportCheck.strip_comments_and_strings(source)
        elapsed = time.perf_counter() - start
        self.assertEqual(len(stripped), len(source))
        self.assertLess(elapsed, 1.0)


class AccessScopeTests(TreeTestCase):
    def test_unlisted_accessor_fails_naming_file_and_line(self):
        self.write('submodules/Foo/Sources/A.swift', 'import TelegramCore\nlet a = context.account.postbox\n')
        errors = self.errors()
        self.assertEqual(len(errors), 1, errors)
        self.assertTrue(errors[0].startswith('submodules/Foo/Sources/A.swift:2: uses .postbox'), errors[0])
        self.assertIn(ACCESS, errors[0])

    def test_listed_accessor_passes(self):
        self.write('submodules/Foo/Sources/A.swift', 'let a = context.account.postbox\n')
        self.allow_access('submodules/Foo/Sources/A.swift')
        self.assertEqual(self.errors(), [])

    def test_test_paths_and_core_are_exempt(self):
        for path in ['submodules/Foo/Tests/T.swift', 'Tests/ComposerHarness/AppContext/H.swift',
                     'submodules/TelegramCore/Sources/C.swift', 'submodules/Postbox/Sources/P.swift']:
            self.write(path, 'let a = account.postbox\n')
        self.assertEqual(self.errors(), [])

    def test_both_lists_are_checked_in_one_pass(self):
        self.write('submodules/Foo/Sources/A.swift', 'import Postbox\nlet a = account.postbox\n')
        errors = self.errors()
        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any(': imports Postbox' in e for e in errors), errors)
        self.assertTrue(any(': uses .postbox' in e for e in errors), errors)


class AccessAllowlistTests(TreeTestCase):
    def test_listed_file_without_access_is_stale(self):
        self.write('submodules/Foo/Sources/A.swift', 'let a = 1 // account.postbox\n')
        self.allow_access('submodules/Foo/Sources/A.swift')
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Sources/A.swift no longer uses .postbox; delete this line.'.format(ACCESS),
        ])

    def test_listed_missing_file_is_stale(self):
        self.allow_access('submodules/Foo/Sources/Gone.swift')
        self.assertEqual(self.errors(), [
            '{}:3: submodules/Foo/Sources/Gone.swift no longer exists; delete this line.'.format(ACCESS),
        ])

    def test_unsorted_and_duplicate_entries_fail(self):
        self.write('submodules/A/Sources/A.swift', 'let a = account.postbox\n')
        self.write('submodules/B/Sources/B.swift', 'let a = account.postbox\n')
        self.allow_access('submodules/B/Sources/B.swift', 'submodules/A/Sources/A.swift', 'submodules/A/Sources/A.swift')
        self.assertEqual(self.errors(), [
            '{}:4: submodules/A/Sources/A.swift is out of order; keep the entries sorted.'.format(ACCESS),
            '{}:5: submodules/A/Sources/A.swift is listed twice; delete this line.'.format(ACCESS),
        ])

    def test_missing_access_list_is_reported(self):
        os.remove(os.path.join(self.root, ACCESS))
        self.assertEqual(self.errors(), ['{} is missing.'.format(ACCESS)])


class MediaConformanceDetectionTests(unittest.TestCase):
    def test_raw_media_conformances_are_found(self):
        for source, name in [
            ('public final class A: Media {\n}\n', 'A'),
            ('final class A: Equatable, Media {\n}\n', 'A'),
            ('class A: EngineRawMedia {\n}\n', 'A'),
            ('class A: Postbox.Media {\n}\n', 'A'),
            ('public final class A: NSObject,\n    EngineRawMedia {\n}\n', 'A'),
            ('protocol P: Media {\n}\n', 'P'),
            ('extension A: Media {\n}\n', 'A'),
        ]:
            with self.subTest(source=source):
                self.assertEqual(PostboxImportCheck.find_unwrappable_media(source), [(1, name)])

    def test_reported_line_is_the_declaration_line(self):
        self.assertEqual(PostboxImportCheck.find_unwrappable_media('import TelegramCore\n\nfinal class A: Media {\n}\n'), [(3, 'A')])

    def test_wrappable_and_unrelated_declarations_are_ignored(self):
        for source in [
            'final class A: EngineCustomMedia {\n}\n',
            'final class A: Equatable, EngineCustomMedia {\n}\n',
            'class A: MediaPlayer {\n}\n',
            'class A: EngineMediaResourceRepresentation {\n}\n',
            'class A<T: Media>: Base {\n}\n',
            'class A: Base where T: Media {\n}\n',
            'func f(media: Media) {\n}\n',
            'struct S {\n    let media: Media\n}\n',
            '// final class A: Media {\n',
            'let s = "final class A: Media {"\n',
        ]:
            with self.subTest(source=source):
                self.assertEqual(PostboxImportCheck.find_unwrappable_media(source), [])


class MediaConformanceScopeTests(TreeTestCase):
    def test_app_side_raw_media_conformance_fails(self):
        self.write('submodules/Foo/Sources/A.swift', 'import TelegramCore\nfinal class A: EngineRawMedia {\n}\n')
        errors = self.errors()
        self.assertEqual(len(errors), 1, errors)
        self.assertTrue(errors[0].startswith('submodules/Foo/Sources/A.swift:2: A conforms to Media without EngineCustomMedia'), errors[0])

    def test_core_and_test_paths_are_exempt(self):
        for path in ['submodules/TelegramCore/Sources/M.swift', 'submodules/Postbox/Sources/M.swift', 'submodules/Foo/Tests/M.swift']:
            self.write(path, 'final class M: Media {\n}\n')
        self.assertEqual(self.errors(), [])

    def test_custom_media_passes(self):
        self.write('submodules/Foo/Sources/A.swift', 'final class A: EngineCustomMedia {\n}\n')
        self.assertEqual(self.errors(), [])


class ScanTreeTests(TreeTestCase):
    def test_one_pass_scan_matches_the_separate_scans(self):
        self.write('submodules/A/Sources/Importer.swift', 'import Postbox\n')
        self.write('submodules/A/Sources/Accessor.swift', 'let a = account.postbox\n')
        self.write('submodules/A/Sources/Both.swift', 'import Postbox\nlet a = account.postbox.mediaBox\n')
        self.write('submodules/A/Sources/Conformer.swift', 'final class C: EngineRawMedia {\n}\n')
        self.write('submodules/A/Sources/Neither.swift', 'let a = 1 // account.postbox\n')
        importers, accessors, conformance = PostboxImportCheck.scan_tree(self.root)
        self.assertEqual(importers, PostboxImportCheck.postbox_importers(self.root))
        self.assertEqual(accessors, PostboxImportCheck.postbox_accessors(self.root))
        self.assertEqual(conformance, PostboxImportCheck.media_conformance_errors(self.root))
        self.assertEqual(sorted(importers), ['submodules/A/Sources/Both.swift', 'submodules/A/Sources/Importer.swift'])
        self.assertEqual(sorted(accessors), ['submodules/A/Sources/Accessor.swift', 'submodules/A/Sources/Both.swift'])
        self.assertEqual(len(conformance), 1)


class ReportTests(TreeTestCase):
    def test_report_counts(self):
        self.write('submodules/A/Sources/A.swift', 'let a = account.postbox.mediaBox.resourceData(r)\nlet b = account.postbox.mediaBox\n')
        self.write('submodules/B/Sources/B.swift', 'import Postbox\nf(postbox: account.postbox)\nlet t = account.postbox.transaction { _ in }\n')
        result = PostboxImportCheck.report(self.root)
        self.assertEqual(result['importers'], 1)
        self.assertEqual(result['access_files'], 2)
        self.assertEqual(result['handle_sites'], 1)
        self.assertEqual(result['mediabox_sites'], 2)
        self.assertEqual(result['mediabox_by_member'], {'resourceData': 1, '(handle)': 1})
        self.assertEqual(result['mediabox_only_files'], 1)


if __name__ == '__main__':
    unittest.main()
