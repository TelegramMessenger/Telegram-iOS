import json
import pathlib
import tempfile
import unittest

import Scripts.verification_stabilization as stabilization


PREFLIGHT = (
    "InputDecTests/IDSpellingReadinessProbeTests/"
    "testStockTextViewSpellingEnvironmentIsReady"
)


def observation(status="ready"):
    annotation = status in ("ready", "markerRenderingUnavailable")
    return {
        "schema": 2,
        "status": status,
        "currentPrimaryLanguage": (
            "zh-Hans" if status == "inputModeMismatch" else "en-US"
        ),
        "inputPrimaryLanguage": "en-US",
        "continuousCheckingEnabled": status != "continuousCheckingDisabled",
        "temporaryAnnotationObserved": annotation,
        "markerPixelCount": 4 if status == "ready" else 0,
        "elapsedSeconds": 0.5,
        "word": "wrng",
        "wordRange": {"location": 10, "length": 4},
        "firstRect": {
            "x": 82.33333333333333,
            "y": 7,
            "width": 38.333333333333336,
            "height": 22,
        },
        "markerROI": {
            "x": 79.33333333333333,
            "y": 2,
            "width": 44.33333333333333,
            "height": 32,
        },
    }


def metadata(passed=True, failures=None, crashed=False, skipped=0):
    return {
        "schema": 1,
        "identifier": PREFLIGHT,
        "executed": 1,
        "passed": 1 if passed else 0,
        "failed": 0 if passed else 1,
        "skipped": skipped,
        "crashed": crashed,
        "failures": failures or [],
    }


class VerificationStabilizationClassifierTests(unittest.TestCase):
    def fixture(self, status="ready", passed=True, failures=None):
        temporary = tempfile.TemporaryDirectory()
        root = pathlib.Path(temporary.name)
        metadata_path = root / "result.json"
        attachments = root / "attachments"
        attachments.mkdir()
        metadata_path.write_text(json.dumps(metadata(
            passed=passed,
            failures=failures,
        )))
        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps(observation(status))
        )
        self.addCleanup(temporary.cleanup)
        return metadata_path, attachments

    def test_ready_requires_one_passed_preflight_and_ready_evidence(self):
        result, attachments = self.fixture()
        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "ready")
        self.assertEqual(classified["status"], "ready")

    def test_retired_one_shot_word_and_range_are_rejected(self):
        result, attachments = self.fixture()
        retired = observation()
        retired["word"] = "mispelled"
        retired["wordRange"] = {"location": 0, "length": 9}
        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps(retired)
        )

        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

    def test_stock_unavailable_requires_prefix_and_valid_nonready_evidence(self):
        failure = (
            "IDSpellingReadiness:stockUnavailable:"
            "temporaryAnnotationUnavailable evidence={}"
        )
        result, attachments = self.fixture(
            status="temporaryAnnotationUnavailable",
            passed=False,
            failures=[failure],
        )
        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "stockUnavailable")

    def test_input_mode_mismatch_is_a_classified_environment_failure(self):
        failure = (
            "IDSpellingReadiness:stockUnavailable:"
            "inputModeMismatch evidence={}"
        )
        result, attachments = self.fixture(
            status="inputModeMismatch",
            passed=False,
            failures=[failure],
        )
        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "stockUnavailable")
        self.assertEqual(classified["status"], "inputModeMismatch")

        contradictory = observation("inputModeMismatch")
        contradictory["currentPrimaryLanguage"] = "en-US"
        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps(contradictory)
        )
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

    def test_input_mode_mismatch_takes_precedence_over_downstream_evidence(self):
        failure = (
            "IDSpellingReadiness:stockUnavailable:"
            "inputModeMismatch evidence={}"
        )
        result, attachments = self.fixture(
            status="inputModeMismatch",
            passed=False,
            failures=[failure],
        )
        mismatch = observation("inputModeMismatch")
        mismatch["continuousCheckingEnabled"] = True
        mismatch["temporaryAnnotationObserved"] = True
        mismatch["markerPixelCount"] = 4
        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps(mismatch)
        )

        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "stockUnavailable")
        self.assertEqual(classified["status"], "inputModeMismatch")

    def test_stock_unavailable_accepts_xctassert_expression_wrapper(self):
        wrapped = (
            '((observation.status) equal to (Ready)) failed - '
            "IDSpellingReadiness:stockUnavailable:"
            "temporaryAnnotationUnavailable evidence={}"
        )
        result, attachments = self.fixture(
            status="temporaryAnnotationUnavailable",
            passed=False,
            failures=[wrapped],
        )
        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "stockUnavailable")

    def test_real_xcresult_attachment_manifest_resolves_hashed_export(self):
        result, attachments = self.fixture()
        exact = attachments / "stock-spelling-readiness.json"
        exported = attachments / "A1B2C3.json"
        exact.rename(exported)
        (attachments / "manifest.json").write_text(json.dumps([{
            "testIdentifier": (
                "IDSpellingReadinessProbeTests/"
                "testStockTextViewSpellingEnvironmentIsReady"
            ),
            "attachments": [{
                "exportedFileName": exported.name,
                "suggestedHumanReadableName": (
                    "stock-spelling-readiness_0_"
                    "B0B883F5-479F-43AF-9203-45993FFB6B60.json"
                ),
            }],
        }]))
        classified = stabilization.classify_preflight(result, attachments)
        self.assertEqual(classified["classification"], "ready")

    def test_crash_missing_or_malformed_evidence_is_fatal(self):
        result, attachments = self.fixture()
        data = metadata(crashed=True)
        result.write_text(json.dumps(data))
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

        result.write_text(json.dumps(metadata()))
        (attachments / "stock-spelling-readiness.json").unlink()
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps({**observation(), "extra": 1})
        )
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

    def test_unknown_status_unrelated_assertion_and_skip_are_fatal(self):
        result, attachments = self.fixture(
            status="temporaryAnnotationUnavailable",
            passed=False,
            failures=["unrelated semantic assertion"],
        )
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

        (attachments / "stock-spelling-readiness.json").write_text(
            json.dumps({**observation(), "status": "futureStatus"})
        )
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

        result.write_text(json.dumps(metadata(skipped=1)))
        with self.assertRaises(stabilization.EvidenceError):
            stabilization.classify_preflight(result, attachments)

    def test_summary_classifies_only_ready_then_failed_family_as_divergence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            attempt = root / "attempt.json"
            family = root / "family.json"
            output = root / "summary.json"
            attempt.write_text(json.dumps({"classification": "ready"}))
            family.write_text(json.dumps({
                "schema": 1, "executed": 5, "passed": 4,
                "failed": 1, "skipped": 0, "crashed": False,
            }))
            summary = stabilization.write_summary(
                output, attempt, None, family, service_restarts=0
            )
            self.assertEqual(summary["classification"], "customDivergence")
            self.assertEqual(summary["semanticRetries"], 0)
            self.assertEqual(summary["preflightAttempts"], 1)

    def test_incomplete_or_crashed_family_is_a_test_state_leak(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            attempt = root / "attempt.json"
            family = root / "family.json"
            attempt.write_text(json.dumps({"classification": "ready"}))
            family.write_text(json.dumps({
                "schema": 1, "executed": 4, "passed": 4,
                "failed": 0, "skipped": 0, "crashed": True,
            }))
            summary = stabilization.write_summary(
                root / "summary.json", attempt, None, family,
                service_restarts=0
            )
            self.assertEqual(summary["classification"], "testStateLeak")
            self.assertEqual(summary["semanticRetries"], 0)

    def test_summary_rejects_extra_attempt_restart_or_semantic_retry(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            ready = root / "ready.json"
            unavailable = root / "unavailable.json"
            family = root / "family.json"
            ready.write_text(json.dumps({"classification": "ready"}))
            unavailable.write_text(json.dumps({
                "classification": "stockUnavailable"
            }))
            family.write_text(json.dumps({
                "schema": 1, "executed": 5, "passed": 5,
                "failed": 0, "skipped": 0, "crashed": False,
            }))
            with self.assertRaises(stabilization.EvidenceError):
                stabilization.write_summary(
                    root / "one.json", ready, unavailable, family,
                    service_restarts=2
                )
            with self.assertRaises(stabilization.EvidenceError):
                stabilization.write_summary(
                    root / "two.json", ready, None, family,
                    service_restarts=0, semantic_retries=1
                )

    def test_summary_writes_create_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            attempt = root / "attempt.json"
            family = root / "family.json"
            output = root / "summary.json"
            attempt.write_text(json.dumps({"classification": "ready"}))
            family.write_text(json.dumps({
                "schema": 1, "executed": 5, "passed": 5,
                "failed": 0, "skipped": 0, "crashed": False,
            }))
            stabilization.write_summary(output, attempt, None, family, 0)
            with self.assertRaises(FileExistsError):
                stabilization.write_summary(output, attempt, None, family, 0)


if __name__ == "__main__":
    unittest.main()
