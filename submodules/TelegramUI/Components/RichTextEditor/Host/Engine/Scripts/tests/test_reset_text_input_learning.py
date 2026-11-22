import json
import pathlib
import sqlite3
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
RESET = ROOT / "Scripts" / "reset-text-input-learning.py"
PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"


def create_rejections_database(root):
    database = root / "Library" / "Keyboard" / "AutocorrectionRejections.db"
    database.parent.mkdir(parents=True)
    connection = sqlite3.connect(database)
    connection.executescript(
        """
        CREATE TABLE rejections (
            ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
            typed TEXT,
            correction TEXT,
            performed_count INTEGER DEFAULT 0,
            soft_rejections INTEGER DEFAULT 0,
            hard_rejections INTEGER DEFAULT 0,
            last_soft_rejection REAL DEFAULT -1e10,
            last_hard_rejection REAL DEFAULT -1e10,
            journaled
        );
        CREATE TABLE inline_completion_rejections (
            ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
            typed TEXT,
            correction TEXT,
            performed_count INTEGER DEFAULT 0,
            soft_rejections INTEGER DEFAULT 0,
            hard_rejections INTEGER DEFAULT 0,
            last_soft_rejection REAL DEFAULT -1e10,
            last_hard_rejection REAL DEFAULT -1e10,
            journaled
        );
        CREATE TABLE properties (
            ROWID INTEGER PRIMARY KEY,
            key,
            value,
            UNIQUE (key)
        );
        INSERT INTO rejections (typed, correction, hard_rejections)
            VALUES ('adress', 'address', 1);
        INSERT INTO inline_completion_rejections
            (typed, correction, soft_rejections)
            VALUES ('forward', 'to', 1);
        """
    )
    connection.commit()
    connection.close()
    return database


class ResetTextInputLearningTests(unittest.TestCase):
    def run_reset(self, device_root, output, udid=PINNED_UDID):
        if not RESET.is_file():
            self.fail("missing targeted text-input learning reset helper")
        return subprocess.run(
            [
                "python3",
                str(RESET),
                "--udid",
                udid,
                "--device-root",
                str(device_root),
                "--output",
                str(output),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_removes_rejections_and_multilingual_dynamic_lexicons(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary) / "device-data"
            database = create_rejections_database(root)
            sibling = database.parent / "VulgarWordUsage.db"
            sibling.write_bytes(b"preserve")
            multilingual_bundle = database.parent / "mul-dynamic.lm"
            multilingual_bundle.mkdir()
            dynamic_lexicons = [
                multilingual_bundle / "dynamic-lexicon-en_AU.dat",
                multilingual_bundle / "dynamic-lexicon-ja_JP.dat",
            ]
            for lexicon in dynamic_lexicons:
                lexicon.write_bytes(b"learned")
            dynamic_model = multilingual_bundle / "dynamic.dat"
            dynamic_model.write_bytes(b"preserve")
            english_bundle = database.parent / "en-dynamic.lm"
            english_bundle.mkdir()
            english_model = english_bundle / "dynamic.dat"
            english_model.write_bytes(b"preserve")
            for suffix in ("-shm", "-wal"):
                pathlib.Path(str(database) + suffix).write_bytes(b"sidecar")
            output = pathlib.Path(temporary) / "evidence"

            result = self.run_reset(root, output)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(database.exists())
            self.assertFalse(pathlib.Path(str(database) + "-shm").exists())
            self.assertFalse(pathlib.Path(str(database) + "-wal").exists())
            self.assertEqual(sibling.read_bytes(), b"preserve")
            self.assertTrue(
                all(not lexicon.exists() for lexicon in dynamic_lexicons)
            )
            self.assertTrue(dynamic_model.is_file())
            self.assertTrue(english_model.is_file())
            self.assertEqual(dynamic_model.read_bytes(), b"preserve")
            self.assertEqual(english_model.read_bytes(), b"preserve")
            self.assertEqual(
                json.loads((output / "summary.json").read_text()),
                {
                    "database": "Library/Keyboard/"
                    "AutocorrectionRejections.db",
                    "priorAutocorrectionRejections": 1,
                    "priorDynamicLexiconFiles": [
                        "Library/Keyboard/mul-dynamic.lm/"
                        "dynamic-lexicon-en_AU.dat",
                        "Library/Keyboard/mul-dynamic.lm/"
                        "dynamic-lexicon-ja_JP.dat",
                    ],
                    "priorInlineCompletionRejections": 1,
                    "result": "reset",
                    "schema": 1,
                    "udid": PINNED_UDID,
                },
            )

    def test_wrong_udid_or_schema_fails_without_removing_database(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary = pathlib.Path(temporary)
            root = temporary / "device-data"
            database = create_rejections_database(root)

            wrong_udid = self.run_reset(
                root, temporary / "wrong-udid", udid="not-k3"
            )
            self.assertNotEqual(wrong_udid.returncode, 0)
            self.assertTrue(database.exists())

            connection = sqlite3.connect(database)
            connection.execute("DROP TABLE properties")
            connection.commit()
            connection.close()
            wrong_schema = self.run_reset(root, temporary / "wrong-schema")
            self.assertNotEqual(wrong_schema.returncode, 0)
            self.assertTrue(database.exists())

    def test_existing_output_fails_without_removing_database(self):
        with tempfile.TemporaryDirectory() as temporary:
            temporary = pathlib.Path(temporary)
            root = temporary / "device-data"
            database = create_rejections_database(root)
            output = temporary / "evidence"
            output.mkdir()

            result = self.run_reset(root, output)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(database.exists())


if __name__ == "__main__":
    unittest.main()
