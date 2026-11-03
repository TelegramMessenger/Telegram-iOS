import copy
import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "compare_autocorrection_results",
    ROOT / "Scripts" / "compare-autocorrection-results.py",
)
COMPARATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPARATOR)


def status():
    return {
        "canonical": "A quiet address ",
        "blocks": ["A quiet address ", "Later block stays."],
        "selection": {"location": 16, "length": 0},
        "affinity": "forward",
        "markedRange": {"location": 9223372036854775807, "length": 0},
        "structuralNewlineLocations": [16],
        "checkingRanges": [],
        "candidateDescriptor": {
            "candidate": "",
            "original": "",
            "actionable": False,
        },
        "firstResponder": True,
        "keyboardState": {
            "visible": True,
            "locale": "en-US",
            "learnedOriginal": False,
        },
        "correctionGeometry": {
            "x": 120.25,
            "y": 31.0,
            "width": 22.5,
            "height": 25.5,
        },
    }


def write_export(directory, phases):
    attachments = []
    for index, (phase, payload) in enumerate(phases):
        filename = f"status-{index}.json"
        (directory / filename).write_text(json.dumps(payload))
        attachments.append({
            "exportedFileName": filename,
            "suggestedHumanReadableName": (
                f"autocorrection-{phase}-status_0_fixture.txt"
            ),
        })
    (directory / "manifest.json").write_text(json.dumps([{
        "attachments": attachments,
    }]))


class CompareAutocorrectionResultsTests(unittest.TestCase):
    def compare(self, stock_phases, custom_phases):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            stock = root / "stock"
            custom = root / "custom"
            output = root / "output"
            stock.mkdir()
            custom.mkdir()
            write_export(stock, stock_phases)
            write_export(custom, custom_phases)
            return COMPARATOR.compare_exported_directories(
                stock, custom, output, pathlib.Path("stock.xcresult"),
                pathlib.Path("custom.xcresult")
            )

    def test_rejects_missing_and_duplicate_phases(self):
        with self.assertRaisesRegex(AssertionError, "phase set"):
            self.compare(
                [("baseline", status()), ("offered", status())],
                [("baseline", status())],
            )
        with self.assertRaisesRegex(AssertionError, "duplicate offered"):
            self.compare(
                [("offered", status()), ("offered", status())],
                [("offered", status())],
            )

    def test_rejects_semantic_and_geometry_mismatches(self):
        custom = copy.deepcopy(status())
        custom["selection"] = {"location": 15, "length": 0}
        with self.assertRaisesRegex(AssertionError, "baseline.selection"):
            self.compare([("baseline", status())], [("baseline", custom)])
        custom = copy.deepcopy(status())
        custom["correctionGeometry"]["x"] += 1.01
        with self.assertRaisesRegex(
            AssertionError, "baseline.correctionGeometry.x"
        ):
            self.compare([("baseline", status())], [("baseline", custom)])

    def test_accepts_exact_semantics_with_subpixel_geometry(self):
        custom = copy.deepcopy(status())
        custom["correctionGeometry"]["x"] += 0.75
        summary = self.compare(
            [("baseline", status()), ("offered", status())],
            [("baseline", custom), ("offered", custom)],
        )
        self.assertEqual(summary["result"], "passed")
        self.assertEqual(summary["phases"], ["baseline", "offered"])
        self.assertEqual(summary["geometryTolerance"], 1.0)


if __name__ == "__main__":
    unittest.main()
