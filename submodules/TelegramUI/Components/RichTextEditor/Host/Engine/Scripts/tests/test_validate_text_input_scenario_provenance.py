import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "Scripts" / "validate-text-input-scenario-provenance.py"


class TextInputScenarioProvenanceTests(unittest.TestCase):
    def _scenario(self, identifier):
        return {
            "identifier": identifier,
            "initial": {
                "text": "abc",
                "selection": {"location": 3, "length": 0},
                "traits": {},
            },
            "transactions": [
                {
                    "kind": "insert-text",
                    "text": "X",
                    "range": None,
                    "selectedRange": None,
                    "traits": {},
                    "phase": None,
                },
                {
                    "kind": "checkpoint",
                    "text": None,
                    "range": None,
                    "selectedRange": None,
                    "traits": {},
                    "phase": "terminal",
                },
            ],
            "comparisonFields": ["canonical"],
            "geometryTolerance": 1,
            "provenance": {
                "sourceFixture": "controlled",
                "stockEvidence": "controlled",
                "targetRuntime": "iOS 26.5 (23F73)",
            },
        }

    def _write_fixture(self, root, family, scenario):
        payload = {
            "schema": 1,
            "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
            "family": family,
            "scenarios": [scenario],
        }
        (root / f"{family}-ios26.5-v1.json").write_text(
            json.dumps(payload), encoding="utf-8"
        )

    def _write_attachment_evidence(
        self, root, pair_name, prefix, canonical
    ):
        pair = root / pair_name
        attachments = pair / "stock-attachments"
        attachments.mkdir(parents=True)
        (pair / "parity.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "phases": ["baseline", "quiesced"],
                    "result": "passed",
                }
            ),
            encoding="utf-8",
        )
        (attachments / "quiesced.txt").write_text(
            json.dumps({"canonical": canonical}), encoding="utf-8"
        )
        (attachments / "manifest.json").write_text(
            json.dumps(
                [
                    {
                        "attachments": [
                            {
                                "exportedFileName": "quiesced.txt",
                                "suggestedHumanReadableName": (
                                    f"{prefix}-quiesced-status_0_test.txt"
                                ),
                            }
                        ]
                    }
                ]
            ),
            encoding="utf-8",
        )

    def _make_tree(self, temporary, autocorrection_canonical="abcX"):
        base = pathlib.Path(temporary)
        fixtures = base / "fixtures"
        ime = base / "ime"
        autocorrection = base / "autocorrection"
        inline = base / "inline"
        fixtures.mkdir()

        self._write_fixture(
            fixtures,
            "ime",
            self._scenario("japanese-romaji-interior-candidate-commit"),
        )
        self._write_fixture(
            fixtures,
            "autocorrection",
            self._scenario("interior-accept-space"),
        )
        self._write_fixture(
            fixtures,
            "inline-prediction",
            self._scenario("interior-accept"),
        )

        lifecycle = ime / "row" / "stock"
        lifecycle.mkdir(parents=True)
        (lifecycle / "lifecycle.json").write_text(
            json.dumps(
                {
                    "phases": [
                        {
                            "phase": "terminal",
                            "status": {
                                "scenario": (
                                    "ime-japanese-romaji-interior-"
                                    "candidate-commit"
                                ),
                                "canonical": "abcX",
                            },
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        self._write_attachment_evidence(
            autocorrection,
            "repeat-1-StockThenCustom-InteriorAcceptSpace",
            "autocorrection",
            autocorrection_canonical,
        )
        self._write_attachment_evidence(
            inline,
            "repeat-1-StockThenCustom-InteriorAccept",
            "inline-prediction",
            "abcX",
        )
        return fixtures, ime, autocorrection, inline

    def _run(self, paths):
        fixtures, ime, autocorrection, inline = paths
        return subprocess.run(
            [
                str(VALIDATOR),
                "--fixture-root",
                str(fixtures),
                "--ime-evidence",
                str(ime),
                "--autocorrection-evidence",
                str(autocorrection),
                "--inline-prediction-evidence",
                str(inline),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_rejects_missing_scenario_identifier(self):
        with tempfile.TemporaryDirectory() as temporary:
            paths = self._make_tree(temporary)
            fixture = paths[0] / "autocorrection-ios26.5-v1.json"
            payload = json.loads(fixture.read_text())
            payload["scenarios"][0]["identifier"] = "missing-scenario"
            fixture.write_text(json.dumps(payload), encoding="utf-8")
            result = self._run(paths)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing-scenario", result.stderr)
            self.assertIn("missing from autocorrection evidence", result.stderr)

    def test_rejects_terminal_canonical_mismatch(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self._run(
                self._make_tree(
                    temporary, autocorrection_canonical="different"
                )
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("interior-accept-space", result.stderr)
            self.assertIn("terminal canonical mismatch", result.stderr)

    def test_accepts_matching_controlled_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self._run(self._make_tree(temporary))
            self.assertEqual(result.returncode, 0, result.stderr)
            summary = json.loads(result.stdout)
            self.assertEqual(summary["scenarioCount"], 3)
            self.assertEqual(summary["result"], "passed")


if __name__ == "__main__":
    unittest.main()
