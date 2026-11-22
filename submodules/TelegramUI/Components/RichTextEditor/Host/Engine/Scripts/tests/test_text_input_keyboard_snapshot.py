import hashlib
import json
import os
import pathlib
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
import unittest


from Scripts import text_input_keyboard_snapshot as MODULE


IDENTITY = {
    "schema": 1,
    "udid": "FA6F7462-AA97-42FE-9E57-8DA0593CE756",
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "locale": "en_US",
    "inputModes": ["en_US@sw=QWERTY;hw=Automatic"],
    "manifestFormat": 1,
}


def make_device_root(root):
    device_root = root / "device"
    keyboard = device_root / "Library" / "Keyboard"
    nested = keyboard / "mul-dynamic.lm"
    nested.mkdir(parents=True)
    state = keyboard / "state.dat"
    state.write_bytes(b"state")
    state.chmod(0o640)
    (nested / "dynamic-lexicon-en_US.dat").write_bytes(b"lexicon")

    database = keyboard / "user_model_database.sqlite"
    connection = sqlite3.connect(database)
    try:
        connection.execute(
            "CREATE TABLE usermodeldurablerecords (value TEXT NOT NULL)"
        )
        connection.execute(
            "CREATE TABLE usermodeltransientrecords (value TEXT NOT NULL)"
        )
        connection.executemany(
            "INSERT INTO usermodeltransientrecords VALUES (?)",
            [("first",), ("second",)],
        )
        connection.execute(
            "INSERT INTO usermodeldurablerecords VALUES ('durable')"
        )
        connection.commit()
    finally:
        connection.close()
    preference = (
        device_root / "Library" / "Preferences" /
        "com.apple.keyboard.preferences.plist"
    )
    preference.parent.mkdir(parents=True)
    preference.write_bytes(b"keyboard-preferences")
    return device_root


def make_writable(path):
    if not path.exists():
        return
    for current, directories, files in os.walk(path):
        pathlib.Path(current).chmod(0o700)
        for name in directories:
            (pathlib.Path(current) / name).chmod(0o700)
        for name in files:
            (pathlib.Path(current) / name).chmod(0o600)


class KeyboardSnapshotCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.device_root = make_device_root(self.root)
        self.snapshot = self.root / "snapshot"

    def tearDown(self):
        make_writable(self.snapshot)
        self.temporary.cleanup()

    def test_capture_records_bytes_modes_and_sqlite_state(self):
        manifest = MODULE.capture_snapshot(
            self.device_root,
            self.snapshot,
            IDENTITY,
            ("Library/Keyboard",),
        )

        self.assertEqual(manifest["schema"], 1)
        self.assertEqual(manifest["identity"], IDENTITY)
        self.assertEqual(manifest["roots"], ["Library/Keyboard"])
        state = manifest["files"]["Library/Keyboard/state.dat"]
        self.assertEqual(state["type"], "file")
        self.assertEqual(state["mode"], 0o640)
        self.assertEqual(state["size"], 5)
        self.assertEqual(
            state["sha256"], hashlib.sha256(b"state").hexdigest()
        )
        sqlite = manifest["sqlite"][
            "Library/Keyboard/user_model_database.sqlite"
        ]
        self.assertEqual(sqlite["journalMode"], "delete")
        self.assertEqual(sqlite["tableRowCounts"], {
            "usermodeldurablerecords": 1,
            "usermodeltransientrecords": 2,
        })
        self.assertEqual(
            [item["name"] for item in sqlite["schema"]],
            ["usermodeldurablerecords", "usermodeltransientrecords"],
        )
        stored = self.snapshot / "tree" / "Library" / "Keyboard"
        self.assertTrue((stored / "state.dat").is_file())
        for path in [stored, stored / "state.dat", stored / "mul-dynamic.lm"]:
            self.assertEqual(stat.S_IMODE(path.stat().st_mode) & 0o222, 0)
        self.assertEqual(MODULE.verify_snapshot(self.snapshot, IDENTITY), manifest)
        self.assertEqual(
            json.loads((self.snapshot / "manifest.json").read_text()),
            manifest,
        )

    def test_capture_and_restore_support_exact_keyboard_preference_file(self):
        preference = (
            self.device_root / "Library" / "Preferences" /
            "com.apple.keyboard.preferences.plist"
        )
        preference.parent.mkdir(parents=True, exist_ok=True)
        preference.write_bytes(b"baseline-preferences")
        roots = (
            "Library/Keyboard",
            "Library/Preferences/com.apple.keyboard.preferences.plist",
        )
        manifest = MODULE.capture_snapshot(
            self.device_root, self.snapshot, IDENTITY, roots
        )

        preference.write_bytes(b"learned-preferences")
        (self.device_root / "Library" / "Keyboard" /
         "state.dat").write_bytes(b"learned-keyboard")
        summary = MODULE.restore_snapshot(
            self.device_root, self.snapshot, self.root / "restore-evidence",
            IDENTITY,
        )

        self.assertEqual(manifest["roots"], list(roots))
        self.assertEqual(preference.read_bytes(), b"baseline-preferences")
        self.assertEqual(
            (self.device_root / "Library" / "Keyboard" /
             "state.dat").read_bytes(), b"state"
        )
        self.assertEqual(summary["roots"], list(roots))

    def test_capture_rejects_symlinked_root_without_publishing_output(self):
        shutil.rmtree(self.device_root / "Library" / "Keyboard")
        external = self.root / "external-keyboard"
        external.mkdir()
        (self.device_root / "Library" / "Keyboard").symlink_to(
            external, target_is_directory=True
        )

        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "symlink"):
            MODULE.capture_snapshot(
                self.device_root,
                self.snapshot,
                IDENTITY,
                ("Library/Keyboard",),
            )

        self.assertFalse(self.snapshot.exists())
        self.assertEqual(list(self.root.glob(".snapshot.partial-*")), [])

    def test_capture_refuses_existing_output(self):
        self.snapshot.mkdir()
        marker = self.snapshot / "owned.txt"
        marker.write_text("preserve")

        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "already exists"):
            MODULE.capture_snapshot(
                self.device_root,
                self.snapshot,
                IDENTITY,
                ("Library/Keyboard",),
            )

        self.assertEqual(marker.read_text(), "preserve")

    def test_verify_rejects_identity_or_stored_byte_change(self):
        MODULE.capture_snapshot(
            self.device_root,
            self.snapshot,
            IDENTITY,
            ("Library/Keyboard",),
        )
        wrong_identity = {
            **IDENTITY,
            "runtime": {"osVersion": "26.5", "osBuild": "changed"},
        }
        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "identity"):
            MODULE.verify_snapshot(self.snapshot, wrong_identity)

        stored = self.snapshot / "tree" / "Library" / "Keyboard" / "state.dat"
        stored.chmod(0o600)
        stored.write_bytes(b"changed")
        stored.chmod(0o400)
        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "manifest"):
            MODULE.verify_snapshot(self.snapshot, IDENTITY)


class KeyboardSnapshotRestoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.device_root = make_device_root(self.root)
        self.snapshot = self.root / "snapshot"
        self.evidence = self.root / "restore-evidence"
        MODULE.capture_snapshot(
            self.device_root,
            self.snapshot,
            IDENTITY,
            ("Library/Keyboard",),
        )

    def tearDown(self):
        make_writable(self.snapshot)
        self.temporary.cleanup()

    def test_restore_replaces_mutated_tree_and_reapplies_live_modes(self):
        keyboard = self.device_root / "Library" / "Keyboard"
        (keyboard / "state.dat").write_bytes(b"contaminated")
        (keyboard / "extra.dat").write_bytes(b"extra")
        connection = sqlite3.connect(keyboard / "user_model_database.sqlite")
        try:
            connection.execute(
                "INSERT INTO usermodeltransientrecords VALUES ('third')"
            )
            connection.commit()
        finally:
            connection.close()

        summary = MODULE.restore_snapshot(
            self.device_root,
            self.snapshot,
            self.evidence,
            IDENTITY,
        )

        self.assertEqual((keyboard / "state.dat").read_bytes(), b"state")
        self.assertFalse((keyboard / "extra.dat").exists())
        self.assertEqual(
            stat.S_IMODE((keyboard / "state.dat").stat().st_mode), 0o640
        )
        connection = sqlite3.connect(
            f"file:{keyboard / 'user_model_database.sqlite'}?mode=ro", uri=True
        )
        try:
            count = connection.execute(
                "SELECT COUNT(*) FROM usermodeltransientrecords"
            ).fetchone()[0]
        finally:
            connection.close()
        self.assertEqual(count, 2)
        manifest_hash = hashlib.sha256(
            (self.snapshot / "manifest.json").read_bytes()
        ).hexdigest()
        self.assertEqual(summary, {
            "schema": 1,
            "result": "restored",
            "identity": IDENTITY,
            "roots": ["Library/Keyboard"],
            "baselineManifestSHA256": manifest_hash,
            "restoredManifestSHA256": manifest_hash,
        })
        self.assertEqual(
            json.loads((self.evidence / "summary.json").read_text()), summary
        )
        self.assertEqual(list(self.root.glob(".restore-evidence.partial-*")), [])
        self.assertEqual(
            list((self.device_root / "Library").glob(".Keyboard.restore-*")),
            [],
        )

    def test_restore_rejects_identity_change_without_mutating_live_tree(self):
        state = self.device_root / "Library" / "Keyboard" / "state.dat"
        state.write_bytes(b"keep-live")
        wrong_identity = {
            **IDENTITY,
            "runtime": {"osVersion": "26.5", "osBuild": "23F74"},
        }

        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "identity"):
            MODULE.restore_snapshot(
                self.device_root,
                self.snapshot,
                self.evidence,
                wrong_identity,
            )

        self.assertEqual(state.read_bytes(), b"keep-live")
        self.assertFalse(self.evidence.exists())

    def test_restore_rejects_live_staging_collision_without_mutation(self):
        state = self.device_root / "Library" / "Keyboard" / "state.dat"
        state.write_bytes(b"keep-live")
        collision = (
            self.device_root / "Library" / f".Keyboard.restore-{os.getpid()}"
        )
        collision.mkdir()
        (collision / "owned.txt").write_text("preserve")

        with self.assertRaisesRegex(
                MODULE.KeyboardSnapshotError, "staging"):
            MODULE.restore_snapshot(
                self.device_root,
                self.snapshot,
                self.evidence,
                IDENTITY,
            )

        self.assertEqual(state.read_bytes(), b"keep-live")
        self.assertEqual((collision / "owned.txt").read_text(), "preserve")

    def test_cli_capture_verify_restore_and_identity_failure(self):
        cli_snapshot = self.root / "cli-snapshot"
        identity_path = self.root / "identity.json"
        identity_path.write_text(json.dumps(IDENTITY))
        script = pathlib.Path(MODULE.__file__)
        captured = subprocess.run([
            sys.executable, str(script), "capture",
            "--device-root", str(self.device_root),
            "--identity", str(identity_path),
            "--output", str(cli_snapshot),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(captured.returncode, 0, captured.stderr)
        self.assertEqual(json.loads(captured.stdout)["result"], "captured")

        verified = subprocess.run([
            sys.executable, str(script), "verify",
            "--snapshot", str(cli_snapshot),
            "--identity", str(identity_path),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        self.assertEqual(json.loads(verified.stdout)["result"], "verified")

        cli_evidence = self.root / "cli-restore"
        restored = subprocess.run([
            sys.executable, str(script), "restore",
            "--device-root", str(self.device_root),
            "--snapshot", str(cli_snapshot),
            "--identity", str(identity_path),
            "--output", str(cli_evidence),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(restored.returncode, 0, restored.stderr)
        self.assertEqual(json.loads(restored.stdout)["result"], "restored")

        wrong_identity = {**IDENTITY, "locale": "en_AU"}
        identity_path.write_text(json.dumps(wrong_identity))
        failed = subprocess.run([
            sys.executable, str(script), "verify",
            "--snapshot", str(cli_snapshot),
            "--identity", str(identity_path),
        ], text=True, capture_output=True, check=False)
        self.assertEqual(failed.returncode, 65)
        self.assertIn("snapshot identity", failed.stderr)
        make_writable(cli_snapshot)


if __name__ == "__main__":
    unittest.main()
