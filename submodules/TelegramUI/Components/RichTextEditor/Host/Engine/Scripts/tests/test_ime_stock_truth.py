import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "Scripts" / "ime_stock_truth.py"
SPEC = importlib.util.spec_from_file_location("ime_stock_truth", MODULE_PATH)
ime_stock_truth = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ime_stock_truth)


def action(kind, value, identity):
    return {
        "kind": kind,
        "value": value,
        "accessibilityIdentity": identity,
    }


def fixture():
    return {
        "schema": 1,
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "language": "japanese-romaji",
        "inputModeIdentifier":
            "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
        "primaryLanguage": "ja-JP",
        "canonicalDocument":
            "Alpha middle omega\nSecond block remains unchanged.",
        "interiorOffset": 6,
        "beforeBoundaryOffset": 18,
        "afterBoundaryOffset": 19,
        "physicalKeySequence": ["k", "a", "n", "a"],
        "firstComposition": "k",
        "updatedComposition": "か",
        "markedSelections": [
            {"location": 1, "length": 0},
            {"location": 1, "length": 0},
        ],
        "candidateAction":
            action("candidate-cell-tap", "かな", "かな, ヒラガナノカナ"),
        "candidateLabel": "かな",
        "candidateAccessibilityIdentity": "かな, ヒラガナノカナ",
        "committedText": "かな",
        "ordinaryCommitAction":
            action("software-keyboard-button", "Return", "Return"),
        "ordinaryCommitResult":
            "Alpha かなmiddle omega\nSecond block remains unchanged.",
        "cancelAction":
            action("software-keyboard-key-sequence",
                   "delete,delete", "delete"),
        "cancelResult":
            "Alpha middle omega\nSecond block remains unchanged.",
        "returnAction":
            action("software-keyboard-button", "Return", "Return"),
        "returnCommitResult":
            "Alpha middle omegaかな\nSecond block remains unchanged.",
        "undoAction": action("uikit-undo-manager", "undo", "ime-undo"),
        "undoResult":
            "Alpha middle omega\nSecond block remains unchanged.",
        "responderLossResult":
            "Alpha middle omegaかな\nSecond block remains unchanged.",
        "geometryTolerance": 1.0,
    }


def observation(candidate_y=538.0):
    return {
        "schema": 1,
        "fixture": fixture(),
        "candidateGeometry":
            {"x": 1.0, "y": candidate_y, "width": 58.0, "height": 45.0},
        "compositionGeometry":
            {"x": 81.0, "y": 205.0, "width": 37.333, "height": 25.667},
    }


class IMEStockTruthTests(unittest.TestCase):
    def write_attachment_directory(self, root, payload, count=1):
        root.mkdir()
        attachments = []
        for index in range(count):
            filename = f"observation-{index}.json"
            (root / filename).write_text(
                json.dumps(payload), encoding="utf-8")
            attachments.append({
                "suggestedHumanReadableName":
                    f"ime-stock-contract-observation_{index}.json",
                "exportedFileName": filename,
            })
        (root / "manifest.json").write_text(json.dumps([{
            "testIdentifier":
                "IDIMECompositionLifecycleUITests/"
                "testStockJapaneseRomajiDiscoveryTruth",
            "attachments": attachments,
        }]), encoding="utf-8")

    def test_three_exact_semantic_observations_agree(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            paths = []
            for index, y in enumerate((538.0, 539.0, 538.5)):
                path = root / str(index)
                self.write_attachment_directory(path, observation(y))
                paths.append(path)
            agreement = ime_stock_truth.compare_observations(
                paths, "japanese-romaji")
            self.assertEqual(agreement["observationCount"], 3)
            self.assertEqual(agreement["fixture"], fixture())

    def test_semantic_difference_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            first = root / "first"
            second = root / "second"
            self.write_attachment_directory(first, observation())
            changed = observation()
            changed["fixture"]["committedText"] = "仮名"
            self.write_attachment_directory(second, changed)
            with self.assertRaisesRegex(
                    ime_stock_truth.TruthError, "semantic disagreement"):
                ime_stock_truth.compare_observations(
                    [first, second], "japanese-romaji")

    def test_geometry_beyond_frozen_tolerance_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            first = root / "first"
            second = root / "second"
            self.write_attachment_directory(first, observation(538.0))
            self.write_attachment_directory(second, observation(540.0))
            with self.assertRaisesRegex(
                    ime_stock_truth.TruthError, "geometry disagreement"):
                ime_stock_truth.compare_observations(
                    [first, second], "japanese-romaji")

    def test_missing_or_duplicate_observation_attachment_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            missing = root / "missing"
            duplicate = root / "duplicate"
            self.write_attachment_directory(missing, observation(), count=0)
            self.write_attachment_directory(duplicate, observation(), count=2)
            for path in (missing, duplicate):
                with self.assertRaisesRegex(
                        ime_stock_truth.TruthError,
                        "exactly one observation attachment"):
                    ime_stock_truth.load_observation(path)

    def test_extra_fixture_and_nonfinite_geometry_are_rejected(self):
        extra = observation()
        extra["fixture"]["unexpected"] = True
        with self.assertRaisesRegex(
                ime_stock_truth.TruthError, "fixture keys"):
            ime_stock_truth.validate_observation(extra)

        invalid = observation()
        invalid["candidateGeometry"]["x"] = float("nan")
        with self.assertRaisesRegex(
                ime_stock_truth.TruthError, "finite"):
            ime_stock_truth.validate_observation(invalid)


if __name__ == "__main__":
    unittest.main()
