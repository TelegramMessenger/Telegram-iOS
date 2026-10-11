import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "Scripts" / "compare-ime-composition-results.py"
SPEC = importlib.util.spec_from_file_location(
    "compare_ime_composition_results", MODULE_PATH)
compare = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compare)


def status(host="stock", canonical="Alpha n\nSecond", geometry_x=81.0):
    block_prefix = "stock" if host == "stock" else "custom"
    return {
        "schema": 1,
        "scenario": "ime-japanese-romaji-interior-candidate-commit",
        "language": "japanese-romaji",
        "location": "interior",
        "decision": "candidate-commit",
        "canonical": canonical,
        "blocks": canonical.split("\n"),
        "blockIdentifiers": [f"{block_prefix}-0", f"{block_prefix}-1"],
        "anchorIdentities": [f"{block_prefix}-0"],
        "selection": {"location": 7, "length": 0},
        "affinity": "forward",
        "markedRange": {"location": 6, "length": 1},
        "markedText": "n",
        "markedSelection": {"location": 1, "length": 0},
        "markedAttributeKeys": ["NSColor", "NSFont"],
        "structuralNewlineLocations": [7],
        "checkingRanges": [],
        "temporaryRenderingDescriptors": [{
            "range": {"location": 6, "length": 1},
            "attributeKeys": ["NSColor", "NSFont"],
            "valueDescriptions": [
                f"color-{host}", f"<font: 0x{'1' if host == 'stock' else '2'}>",
            ],
        }],
        "candidateDescriptor": {
            "visible": True,
            "actionable": True,
            "labels": ["かな, ヒラガナノカナ"],
            "selectedLabel": "かな, ヒラガナノカナ",
            "geometry": {"x": 10.0, "y": 500.0, "width": 60.0, "height": 44.0},
        },
        "keyboardState": {
            "visible": True,
            "primaryLanguage": "ja-JP",
            "enabledInputModeIdentifiers": [
                "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
                "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
            ],
        },
        "compositionGeometry": {
            "x": geometry_x, "y": 205.0, "width": 11.0, "height": 25.667,
        },
        "mutationTrace": ["selectionDidChange", "textDidChange"],
        "eventTrace": ["selectionDidChange", "textDidChange"],
        "coordinateSpaceIdentity": "screen",
        "documentRevision": 1,
        "textEpoch": 1,
        "selectionEpoch": 1,
        "checkingEpoch": 1,
        "layoutEpoch": 2,
        "firstResponder": True,
    }


def lifecycle(host="stock", **status_changes):
    return {
        "schema": 1,
        "testMethod": f"test-{host}",
        "decision": "candidate-commit",
        "phases": [
            {"phase": "firstComposition",
             "status": status(host=host, **status_changes)},
        ],
    }


class IMECompositionComparatorTests(unittest.TestCase):
    def test_semantics_match_while_host_owned_identities_and_descriptions_differ(self):
        result = compare.compare_lifecycles(
            lifecycle("stock"), lifecycle("custom"), 1.0)
        self.assertEqual(result["phaseCount"], 1)

    def test_canonical_difference_fails_closed_with_phase_and_field(self):
        with self.assertRaisesRegex(
                compare.ComparisonError,
                r"firstComposition\.canonical"):
            compare.compare_lifecycles(
                lifecycle("stock"),
                lifecycle("custom", canonical="Alpha x\nSecond"),
                1.0)

    def test_geometry_outside_tolerance_fails_closed(self):
        with self.assertRaisesRegex(
                compare.ComparisonError,
                r"compositionGeometry\.x"):
            compare.compare_lifecycles(
                lifecycle("stock"),
                lifecycle("custom", geometry_x=82.1),
                1.0)

    def test_first_composition_ignores_cold_candidate_labels_only(self):
        stock = lifecycle("stock")
        custom = lifecycle("custom")
        stock_candidate = stock["phases"][0]["status"]["candidateDescriptor"]
        stock_candidate["labels"] = ["から, ヒラガナノカラ"]
        stock_candidate["selectedLabel"] = "から, ヒラガナノカラ"
        result = compare.compare_lifecycles(stock, custom, 1.0)
        self.assertEqual(result["phaseCount"], 1)

        for value in (stock, custom):
            value["phases"].append({
                "phase": "updatedComposition",
                "status": status(
                    host="stock" if value is stock else "custom"
                ),
            })
        stock_updated = stock["phases"][1]["status"]["candidateDescriptor"]
        stock_updated["labels"] = ["から, ヒラガナノカラ"]
        stock_updated["selectedLabel"] = "から, ヒラガナノカラ"
        with self.assertRaisesRegex(
                compare.ComparisonError,
                r"updatedComposition\.candidateDescriptor\.labels"):
            compare.compare_lifecycles(stock, custom, 1.0)

    def test_first_composition_still_requires_candidate_state(self):
        custom = lifecycle("custom")
        custom["phases"][0]["status"]["candidateDescriptor"]["actionable"] = False
        with self.assertRaisesRegex(
                compare.ComparisonError,
                r"firstComposition\.candidateDescriptor\.actionable"):
            compare.compare_lifecycles(lifecycle("stock"), custom, 1.0)

    def test_keyboard_candidate_strip_x_is_os_owned_but_size_and_y_are_exact(self):
        custom = lifecycle("custom")
        geometry = custom["phases"][0]["status"][
            "candidateDescriptor"]["geometry"]
        geometry["x"] = 59.0
        result = compare.compare_lifecycles(
            lifecycle("stock"), custom, 1.0)
        self.assertEqual(result["phaseCount"], 1)

        geometry["y"] = 502.0
        with self.assertRaisesRegex(
                compare.ComparisonError,
                r"candidateDescriptor\.geometry\.y"):
            compare.compare_lifecycles(lifecycle("stock"), custom, 1.0)

    def test_host_internal_document_revisions_may_differ_but_must_not_regress(self):
        custom = lifecycle("custom")
        custom["phases"][0]["status"]["documentRevision"] = 3
        result = compare.compare_lifecycles(
            lifecycle("stock"), custom, 1.0)
        self.assertEqual(result["phaseCount"], 1)

        custom["phases"].append({
            "phase": "updatedComposition",
            "status": status(host="custom"),
        })
        stock = lifecycle("stock")
        stock["phases"].append({
            "phase": "updatedComposition",
            "status": status(host="stock"),
        })
        with self.assertRaisesRegex(
                compare.ComparisonError, "custom documentRevision regressed"):
            compare.compare_lifecycles(stock, custom, 1.0)

    def test_identity_must_remain_stable_within_each_host(self):
        custom = lifecycle("custom")
        second = status(host="custom")
        second["blockIdentifiers"][0] = "replaced-custom-0"
        custom["phases"].append(
            {"phase": "updatedComposition", "status": second})
        stock = lifecycle("stock")
        stock["phases"].append(
            {"phase": "updatedComposition", "status": status(host="stock")})
        with self.assertRaisesRegex(
                compare.ComparisonError, "custom blockIdentifiers changed"):
            compare.compare_lifecycles(stock, custom, 1.0)

    def test_os_added_fallback_input_mode_is_ignored_but_target_modes_are_required(self):
        stock = lifecycle("stock")
        custom = lifecycle("custom")
        required = [
            "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
            "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
        ]
        stock_modes = stock["phases"][0]["status"][
            "keyboardState"]["enabledInputModeIdentifiers"]
        stock_modes[:] = required + ["en_AU@sw=QWERTY;hw=Automatic"]
        custom_modes = custom["phases"][0]["status"][
            "keyboardState"]["enabledInputModeIdentifiers"]
        custom_modes[:] = stock_modes + ["ru_RU@sw=Russian;hw=Automatic"]
        result = compare.compare_lifecycles(stock, custom, 1.0)
        self.assertEqual(result["phaseCount"], 1)

        custom_modes.remove(required[1])
        with self.assertRaisesRegex(
                compare.ComparisonError,
                "enabledInputModeIdentifiers is missing required modes"):
            compare.compare_lifecycles(stock, custom, 1.0)


if __name__ == "__main__":
    unittest.main()
