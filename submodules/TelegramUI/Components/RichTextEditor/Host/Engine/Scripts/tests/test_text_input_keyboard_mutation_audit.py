import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest


from Scripts import text_input_keyboard_mutation_audit as MODULE


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value)


class KeyboardMutationScanTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name) / "device"
        write(self.root / "Library/Keyboard/state.dat", b"keyboard")
        write(
            self.root / "Library/Caches/com.apple.keyboards/cache.dat",
            b"cache",
        )
        write(
            self.root / "Library/Preferences/com.apple.keyboard.plist",
            b"keyboard-pref",
        )
        write(
            self.root /
            "Library/Preferences/com.apple.keyboard.preferences.plist",
            b"keyboard-learning-pref",
        )
        write(
            self.root / "Library/Preferences/com.apple.TextInput.plist",
            b"text-input-pref",
        )
        write(
            self.root / "Library/Preferences/com.apple.unrelated.plist",
            b"ignore",
        )
        write(self.root / "Library/Caches/unrelated/cache.dat", b"ignore")

    def tearDown(self):
        self.temporary.cleanup()

    def test_scan_includes_only_keyboard_and_textinput_candidates(self):
        scan = MODULE.scan_candidates(self.root)

        self.assertEqual(scan["schema"], 1)
        self.assertEqual(scan["udid"], MODULE.PINNED_UDID)
        self.assertEqual(scan["runtime"], MODULE.RUNTIME)
        self.assertEqual(set(scan["files"]), {
            "Library/Keyboard/state.dat",
            "Library/Caches/com.apple.keyboards/cache.dat",
            "Library/Preferences/com.apple.keyboard.plist",
            "Library/Preferences/com.apple.keyboard.preferences.plist",
            "Library/Preferences/com.apple.TextInput.plist",
        })
        state = scan["files"]["Library/Keyboard/state.dat"]
        self.assertEqual(state["type"], "file")
        self.assertEqual(state["size"], 8)
        self.assertEqual(
            state["sha256"], hashlib.sha256(b"keyboard").hexdigest()
        )
        self.assertIsInstance(state["mode"], int)
        self.assertIsInstance(state["mtimeNS"], int)
        self.assertEqual(scan, MODULE.scan_candidates(self.root))

    def test_scan_rejects_candidate_symlink(self):
        candidate = self.root / "Library/Keyboard/state.dat"
        candidate.unlink()
        candidate.symlink_to(
            self.root / "Library/Preferences/com.apple.unrelated.plist"
        )

        with self.assertRaisesRegex(MODULE.MutationAuditError, "symlink"):
            MODULE.scan_candidates(self.root)

    def test_scan_does_not_mutate_candidate_metadata(self):
        candidate = self.root / "Library/Keyboard/state.dat"
        before = candidate.stat()

        MODULE.scan_candidates(self.root)

        after = candidate.stat()
        self.assertEqual(after.st_mode, before.st_mode)
        self.assertEqual(after.st_size, before.st_size)
        self.assertEqual(after.st_mtime_ns, before.st_mtime_ns)


class KeyboardMutationComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.base = pathlib.Path(self.temporary.name)
        self.root = self.base / "device"
        write(self.root / "Library/Keyboard/state.dat", b"keyboard")
        write(
            self.root / "Library/Caches/com.apple.keyboards/cache.dat",
            b"cache",
        )
        write(
            self.root / "Library/Preferences/com.apple.keyboard.plist",
            b"keyboard-pref",
        )
        write(
            self.root / "Library/Preferences/com.apple.TextInput.plist",
            b"text-input-pref",
        )

    def tearDown(self):
        self.temporary.cleanup()

    def test_compare_classifies_only_restore_root_mutations_as_covered(self):
        before = MODULE.scan_candidates(self.root)
        write(self.root / "Library/Keyboard/state.dat", b"learned")
        write(
            self.root / "Library/Caches/com.apple.keyboards/cache.dat",
            b"changed-cache",
        )
        (self.root / "Library/Preferences/com.apple.keyboard.plist").unlink()
        write(
            self.root / "Library/Preferences/com.apple.TextInput.extra.plist",
            b"new-pref",
        )
        after = MODULE.scan_candidates(self.root)

        report = MODULE.compare_scans(
            before, after, ("Library/Keyboard",)
        )

        self.assertEqual(report["result"], "unclassified-mutations")
        self.assertEqual(report["added"], [
            "Library/Preferences/com.apple.TextInput.extra.plist",
        ])
        self.assertEqual(report["removed"], [
            "Library/Preferences/com.apple.keyboard.plist",
        ])
        self.assertEqual(report["changed"], [
            "Library/Caches/com.apple.keyboards/cache.dat",
            "Library/Keyboard/state.dat",
        ])
        self.assertEqual(report["restored"], [
            "Library/Keyboard/state.dat",
        ])
        self.assertEqual(report["unclassified"], [
            "Library/Caches/com.apple.keyboards/cache.dat",
            "Library/Preferences/com.apple.TextInput.extra.plist",
            "Library/Preferences/com.apple.keyboard.plist",
        ])

    def test_compare_is_clean_when_identical_or_all_changes_are_restored(self):
        before = MODULE.scan_candidates(self.root)
        identical = MODULE.compare_scans(
            before, before, ("Library/Keyboard",)
        )
        self.assertEqual(identical["result"], "clean")
        self.assertEqual(identical["restored"], [])
        self.assertEqual(identical["unclassified"], [])

        write(self.root / "Library/Keyboard/state.dat", b"learned")
        after = MODULE.scan_candidates(self.root)
        covered = MODULE.compare_scans(
            before, after, ("Library/Keyboard",)
        )
        self.assertEqual(covered["result"], "clean")
        self.assertEqual(covered["restored"], [
            "Library/Keyboard/state.dat",
        ])
        self.assertEqual(covered["unclassified"], [])

    def test_exact_keyboard_preference_restore_root_is_classified(self):
        preference = (
            self.root / "Library" / "Preferences" /
            "com.apple.keyboard.preferences.plist"
        )
        before = MODULE.scan_candidates(self.root)
        preference.write_bytes(b"changed-keyboard-learning-pref")
        after = MODULE.scan_candidates(self.root)

        covered = MODULE.compare_scans(before, after, (
            "Library/Keyboard",
            "Library/Preferences/com.apple.keyboard.preferences.plist",
        ))

        self.assertEqual(covered["result"], "clean")
        self.assertEqual(covered["restored"], [
            "Library/Preferences/com.apple.keyboard.preferences.plist",
        ])
        self.assertEqual(covered["unclassified"], [])

    def test_compare_rejects_schema_identity_and_restore_root_errors(self):
        scan = MODULE.scan_candidates(self.root)
        mutations = [
            {**scan, "schema": 2},
            {**scan, "udid": "another-device"},
            {**scan, "runtime": {"osVersion": "26.5", "osBuild": "bad"}},
            {**scan, "files": []},
        ]
        for invalid in mutations:
            with self.subTest(invalid=invalid):
                with self.assertRaises(MODULE.MutationAuditError):
                    MODULE.compare_scans(
                        scan, invalid, ("Library/Keyboard",)
                    )
        for roots in [(), ("/Library/Keyboard",), ("../Keyboard",),
                      ("Library/Keyboard", "Library/Keyboard")]:
            with self.subTest(roots=roots):
                with self.assertRaises(MODULE.MutationAuditError):
                    MODULE.compare_scans(scan, scan, roots)

    def test_cli_preserves_unclassified_report_and_returns_65(self):
        script = pathlib.Path(MODULE.__file__)
        before_path = self.base / "before.json"
        after_path = self.base / "after.json"
        clean_output = self.base / "clean.json"
        failed_output = self.base / "failed.json"

        scanned = subprocess.run([
            sys.executable, str(script), "scan",
            "--device-root", str(self.root),
            "--output", str(before_path),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(scanned.returncode, 0, scanned.stderr)
        self.assertEqual(json.loads(scanned.stdout)["result"], "scanned")

        clean = subprocess.run([
            sys.executable, str(script), "compare",
            "--before", str(before_path),
            "--after", str(before_path),
            "--restore-root", "Library/Keyboard",
            "--output", str(clean_output),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(clean.returncode, 0, clean.stderr)
        self.assertEqual(json.loads(clean_output.read_text())["result"], "clean")

        write(
            self.root / "Library/Caches/com.apple.keyboards/cache.dat",
            b"changed-cache",
        )
        scanned_after = subprocess.run([
            sys.executable, str(script), "scan",
            "--device-root", str(self.root),
            "--output", str(after_path),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(scanned_after.returncode, 0, scanned_after.stderr)
        failed = subprocess.run([
            sys.executable, str(script), "compare",
            "--before", str(before_path),
            "--after", str(after_path),
            "--restore-root", "Library/Keyboard",
            "--output", str(failed_output),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(failed.returncode, 65)
        self.assertEqual(
            json.loads(failed_output.read_text())["unclassified"],
            ["Library/Caches/com.apple.keyboards/cache.dat"],
        )


if __name__ == "__main__":
    unittest.main()
