#!/usr/bin/env python3
import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "Scripts" / "validate-autocorrection-summary.py"


def valid_summary():
    counts = {
        "expectedFailures": 0,
        "failedTests": 0,
        "passedTests": 1,
        "skippedTests": 0,
    }
    return {
        **counts,
        "result": "Passed",
        "totalTestCount": 1,
        "devicesAndConfigurations": [{
            **counts,
            "device": {
                "deviceId": "SIMULATOR-UDID",
                "osBuildNumber": "23F73",
                "osVersion": "26.5",
            },
        }],
    }


class ValidateAutocorrectionSummaryTests(unittest.TestCase):
    def run_validator(self, summary):
        self.assertTrue(VALIDATOR.is_file(), f"missing validator: {VALIDATOR}")
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "summary.json"
            path.write_text(json.dumps(summary))
            return subprocess.run(
                [
                    str(VALIDATOR), str(path), "SIMULATOR-UDID", "26.5",
                    "23F73",
                ],
                text=True,
                capture_output=True,
            )

    def test_accepts_exactly_one_pass_on_pinned_runtime(self):
        result = self.run_validator(valid_summary())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_skip_even_when_xcode_result_is_passed(self):
        summary = valid_summary()
        summary.update(passedTests=0, skippedTests=1)
        summary["devicesAndConfigurations"][0].update(
            passedTests=0, skippedTests=1
        )
        result = self.run_validator(summary)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("skippedTests", result.stderr)

    def test_rejects_wrong_device_or_os_build(self):
        for key, value in [
            ("deviceId", "OTHER-UDID"),
            ("osVersion", "26.4"),
            ("osBuildNumber", "23E99"),
        ]:
            with self.subTest(key=key):
                summary = valid_summary()
                summary["devicesAndConfigurations"][0]["device"][key] = value
                result = self.run_validator(summary)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(key, result.stderr)

    def test_rejects_multiple_or_zero_tests(self):
        for passed, total in [(2, 2), (0, 0)]:
            with self.subTest(passed=passed, total=total):
                summary = valid_summary()
                summary.update(passedTests=passed, totalTestCount=total)
                summary["devicesAndConfigurations"][0]["passedTests"] = passed
                result = self.run_validator(summary)
                self.assertNotEqual(result.returncode, 0)

    def test_rejects_boolean_count_values(self):
        for container in ("summary", "configuration"):
            with self.subTest(container=container):
                summary = valid_summary()
                target = summary if container == "summary" else (
                    summary["devicesAndConfigurations"][0]
                )
                target["passedTests"] = True
                result = self.run_validator(summary)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("passedTests", result.stderr)


if __name__ == "__main__":
    unittest.main()
