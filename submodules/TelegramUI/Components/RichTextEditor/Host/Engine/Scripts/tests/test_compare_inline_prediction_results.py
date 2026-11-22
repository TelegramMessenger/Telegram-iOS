import copy
import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "compare_inline_prediction_results",
    ROOT / "Scripts" / "compare-inline-prediction-results.py",
)
COMPARATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPARATOR)


def status():
    return {
        "canonical": "I look forward to ",
        "blocks": ["I look forward to ", "Later block stays."],
        "selection": {"location": 18, "length": 0},
        "affinity": "forward",
        "markedRange": {"location": 15, "length": 3},
        "structuralNewlineLocations": [18],
        "checkingRanges": [],
        "predictionDescriptor": {
            "present": True,
            "displayText": " to",
            "accessibilityIdentity": "marked-text",
            "range": {"location": 15, "length": 3},
            "renderingAttributeKeys": [],
        },
        "temporaryRenderingDescriptors": [],
        "firstResponder": True,
        "keyboardState": {
            "visible": True,
            "locale": "en-US",
            "inlinePredictionEnabled": True,
        },
        "predictionGeometry": {
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
        attachments.append(
            {
                "exportedFileName": filename,
                "suggestedHumanReadableName":
                    f"inline-prediction-{phase}-status_0_fixture.txt",
            }
        )
    (directory / "manifest.json").write_text(
        json.dumps([{"attachments": attachments}])
    )


class CompareInlinePredictionResultsTests(unittest.TestCase):
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

    def test_rejects_missing_phase(self):
        with self.assertRaisesRegex(AssertionError, "phase set"):
            self.compare(
                [("baseline", status()), ("offered", status())],
                [("baseline", status())],
            )

    def test_rejects_duplicate_phase(self):
        with self.assertRaisesRegex(AssertionError, "duplicate offered"):
            self.compare(
                [("offered", status()), ("offered", status())],
                [("offered", status())],
            )

    def test_rejects_unknown_phase(self):
        with self.assertRaisesRegex(AssertionError, "known phase set"):
            self.compare(
                [("surprise", status())],
                [("surprise", status())],
            )

    def test_rejects_semantic_mismatch(self):
        custom = status()
        custom["selection"] = {"location": 17, "length": 0}
        with self.assertRaisesRegex(AssertionError, "offered.selection"):
            self.compare([("offered", status())], [("offered", custom)])

    def test_rejects_nonfinite_geometry(self):
        custom = status()
        custom["predictionGeometry"]["x"] = float("nan")
        with self.assertRaisesRegex(AssertionError, "is not finite"):
            self.compare([("offered", status())], [("offered", custom)])

    def test_rejects_geometry_over_one_point(self):
        custom = status()
        custom["predictionGeometry"]["width"] += 1.01
        with self.assertRaisesRegex(
            AssertionError, "offered.predictionGeometry.width"
        ):
            self.compare([("offered", status())], [("offered", custom)])

    def test_accepts_exact_semantics_with_subpixel_geometry(self):
        custom = copy.deepcopy(status())
        custom["predictionGeometry"]["x"] += 0.75
        custom["predictionGeometry"]["height"] -= 0.5
        summary = self.compare(
            [("baseline", status()), ("offered", status())],
            [("baseline", custom), ("offered", custom)],
        )
        self.assertEqual(summary["result"], "passed")
        self.assertEqual(summary["phases"], ["baseline", "offered"])
        self.assertEqual(summary["geometryTolerance"], 1.0)


if __name__ == "__main__":
    unittest.main()
