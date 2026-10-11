import copy
import hashlib
import json
import pathlib
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest

import Scripts.text_input_batch as batch_module
import Scripts.text_input_group_protocol as protocol_module


ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "UITests" / "Fixtures"
SCRIPT = ROOT / "Scripts" / "text_input_batch.py"
CATALOGS = {
    "ime": FIXTURES / "text-input-ime-batches-ios26.5-v1.json",
    "autocorrection": (
        FIXTURES / "text-input-autocorrection-batches-ios26.5-v1.json"
    ),
    "inline-prediction": (
        FIXTURES / "text-input-inline-prediction-batches-ios26.5-v1.json"
    ),
}
BATCH_RUNNER = ROOT / "Scripts" / "run-text-input-batch.sh"

from Scripts.text_input_batch import (  # noqa: E402
    BatchContractError,
    expand_batches,
    load_catalog,
    validate_catalog,
)


def autocorrection_rows():
    return [
        f"{location}-{decision}"
        for location in ("interior", "before-boundary", "after-boundary")
        for decision in (
            "accept-space",
            "accept-punctuation",
            "accept-candidate",
            "reject-precommit",
            "undo-space",
            "undo-punctuation",
            "undo-candidate",
        )
    ]


def inline_prediction_rows():
    return [
        f"{location}-{decision}"
        for location in ("interior", "before-boundary", "after-boundary")
        for decision in (
            "accept",
            "dismiss-then-type",
            "accept-then-delete",
        )
    ]


def ime_rows():
    rows = []
    for language in ("japanese-romaji", "simplified-chinese-pinyin"):
        for location in ("interior", "before-boundary", "after-boundary"):
            for decision in (
                "candidate-commit",
                "cancel",
                "ordinary-commit",
                "return-commit-then-undo",
                "responder-loss",
            ):
                if decision == "return-commit-then-undo" and location == "interior":
                    continue
                if decision == "responder-loss" and location != "before-boundary":
                    continue
                rows.append(f"{language}-{location}-{decision}")
    return rows


EXPECTED_ROWS = {
    "ime": ime_rows(),
    "autocorrection": autocorrection_rows(),
    "inline-prediction": inline_prediction_rows(),
}


def valid_catalog(subsystem="autocorrection"):
    rows = EXPECTED_ROWS[subsystem]
    language = "japanese-romaji" if subsystem == "ime" else "en-US"
    groups = []
    for index in range(0, len(rows), 3):
        group_rows = rows[index:index + 3]
        group_language = language
        if subsystem == "ime" and group_rows[0].startswith(
            "simplified-chinese-pinyin-"
        ):
            group_language = "simplified-chinese-pinyin"
        groups.append({
            "id": f"group-{index // 3 + 1}",
            "language": group_language,
            "rows": group_rows,
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        })
    return {
        "schema": 1,
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "udid": "FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        "subsystem": subsystem,
        "rows": rows,
        "groups": groups,
    }


class BatchCatalogTests(unittest.TestCase):
    def test_checked_in_catalogs_cover_the_frozen_corpus_exactly(self):
        expected_counts = {
            "ime": 24,
            "autocorrection": 21,
            "inline-prediction": 9,
        }
        for subsystem, count in expected_counts.items():
            with self.subTest(subsystem=subsystem):
                catalog = load_catalog(CATALOGS[subsystem])
                validate_catalog(catalog)
                self.assertEqual(catalog["rows"], EXPECTED_ROWS[subsystem])
                self.assertEqual(len(catalog["rows"]), count)
                grouped = [
                    row
                    for group in catalog["groups"]
                    for row in group["rows"]
                ]
                self.assertCountEqual(grouped, catalog["rows"])

    def test_expansion_preserves_repetitions_orders_and_host_adjacency(self):
        catalog = valid_catalog()
        catalog["groups"] = [{
            "id": "ordinary-accept",
            "language": "en-US",
            "rows": catalog["rows"][:2],
            "stateSensitive": False,
            "resetPolicy": "erase-reset-learning-provision",
        }]
        for index in range(2, len(catalog["rows"]), 3):
            catalog["groups"].append({
                "id": f"remaining-{index}",
                "language": "en-US",
                "rows": catalog["rows"][index:index + 3],
                "stateSensitive": True,
                "resetPolicy": "erase-reset-learning-provision",
            })
        expanded = expand_batches(catalog)
        identities = {
            (batch["repetition"], batch["order"])
            for batch in expanded
        }
        self.assertEqual(identities, {
            (1, "stock-custom"),
            (1, "custom-stock"),
            (2, "stock-custom"),
            (2, "custom-stock"),
        })
        first = expanded[0]
        self.assertEqual(first["id"],
            "autocorrection--r1--stock-custom--ordinary-accept")
        self.assertEqual(first["hosts"], [
            {"row": catalog["rows"][0], "host": "stock"},
            {"row": catalog["rows"][0], "host": "custom"},
            {"row": catalog["rows"][1], "host": "stock"},
            {"row": catalog["rows"][1], "host": "custom"},
        ])
        self.assertEqual(
            sum(batch["expectedHostObservations"] for batch in expanded),
            21 * 4 * 2,
        )

    def test_validation_rejects_unknown_top_level_key(self):
        catalog = valid_catalog()
        catalog["surprise"] = True
        with self.assertRaisesRegex(BatchContractError, "top-level keys"):
            validate_catalog(catalog)

    def test_validation_rejects_duplicate_group_identifier(self):
        catalog = valid_catalog()
        catalog["groups"][1]["id"] = catalog["groups"][0]["id"]
        with self.assertRaisesRegex(BatchContractError, "duplicate group id"):
            validate_catalog(catalog)

    def test_validation_rejects_duplicate_grouped_row(self):
        catalog = valid_catalog()
        catalog["groups"][1]["rows"][0] = catalog["groups"][0]["rows"][0]
        with self.assertRaisesRegex(BatchContractError, "grouped rows"):
            validate_catalog(catalog)

    def test_validation_rejects_missing_grouped_row(self):
        catalog = valid_catalog()
        catalog["groups"][-1]["rows"].pop()
        with self.assertRaisesRegex(BatchContractError, "grouped rows"):
            validate_catalog(catalog)

    def test_validation_rejects_unknown_frozen_row(self):
        catalog = valid_catalog()
        catalog["rows"][-1] = "unknown-row"
        catalog["groups"][-1]["rows"][-1] = "unknown-row"
        with self.assertRaisesRegex(BatchContractError, "frozen rows"):
            validate_catalog(catalog)

    def test_validation_rejects_empty_and_oversized_groups(self):
        empty = valid_catalog()
        empty["groups"][0]["rows"] = []
        with self.assertRaisesRegex(BatchContractError, "nonempty"):
            validate_catalog(empty)

        oversized = valid_catalog()
        oversized["groups"] = [{
            "id": "too-large",
            "language": "en-US",
            "rows": oversized["rows"][:13],
            "stateSensitive": False,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "rest",
            "language": "en-US",
            "rows": oversized["rows"][13:],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }]
        with self.assertRaisesRegex(BatchContractError, "at most 12"):
            validate_catalog(oversized)

    def test_validation_rejects_oversized_state_sensitive_group(self):
        catalog = valid_catalog("inline-prediction")
        catalog["groups"] = [{
            "id": "too-stateful",
            "language": "en-US",
            "rows": catalog["rows"][:4],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "rest",
            "language": "en-US",
            "rows": catalog["rows"][4:],
            "stateSensitive": False,
            "resetPolicy": "erase-reset-learning-provision",
        }]
        with self.assertRaisesRegex(BatchContractError, "at most 3"):
            validate_catalog(catalog)

    def test_validation_rejects_invalid_language_and_reset_policy(self):
        invalid_language = valid_catalog("ime")
        invalid_language["groups"][0]["language"] = "en-US"
        with self.assertRaisesRegex(BatchContractError, "language"):
            validate_catalog(invalid_language)

        invalid_reset = valid_catalog()
        invalid_reset["groups"][0]["resetPolicy"] = "app-relaunch"
        with self.assertRaisesRegex(BatchContractError, "resetPolicy"):
            validate_catalog(invalid_reset)

    def test_validation_rejects_boolean_schema_and_malformed_json(self):
        catalog = valid_catalog()
        catalog["schema"] = True
        with self.assertRaisesRegex(BatchContractError, "schema"):
            validate_catalog(catalog)

        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "broken.json"
            path.write_text("{", encoding="utf-8")
            with self.assertRaisesRegex(BatchContractError, "cannot load"):
                load_catalog(path)

    def test_cli_validate_and_show_report_stable_counts(self):
        catalog = valid_catalog("inline-prediction")
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "catalog.json"
            path.write_text(json.dumps(catalog), encoding="utf-8")
            validated = subprocess.run(
                [sys.executable, str(SCRIPT), "validate", str(path)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(validated.returncode, 0, validated.stderr)
            self.assertIn(
                "VALID subsystem=inline-prediction logicalRows=9",
                validated.stdout,
            )
            shown = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "show",
                    str(path),
                    expand_batches(catalog)[0]["id"],
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(shown.returncode, 0, shown.stderr)
            payload = json.loads(shown.stdout)
            self.assertEqual(payload["expectedHostObservations"], 2)


def inline_status():
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


def write_batch_export(directory, batch, observations=None):
    directory.mkdir()
    attachments = []
    observed = observations if observations is not None else batch["hosts"]
    metadata = {
        "schema": 1,
        "batchId": batch["id"],
        "subsystem": batch["subsystem"],
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "udid": "FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        "observations": observed,
    }
    (directory / "metadata.json").write_text(json.dumps(metadata))
    attachments.append({
        "exportedFileName": "metadata.json",
        "suggestedHumanReadableName": (
            "batch-metadata_0_7607BD27-29AC-4A69-9A5E-5A7719CFB0D5.json"
        ),
    })
    for index, observation in enumerate(batch["hosts"]):
        prefix = (
            f"batch--{observation['row']}--{observation['host']}--"
        )
        status_name = f"status-{index}.json"
        screenshot_name = f"screenshot-{index}.png"
        hierarchy_name = f"hierarchy-{index}.txt"
        (directory / status_name).write_text(json.dumps(inline_status()))
        (directory / screenshot_name).write_bytes(b"png")
        (directory / hierarchy_name).write_text("Application hierarchy")
        attachments.extend([
            {
                "exportedFileName": status_name,
                "suggestedHumanReadableName": (
                    prefix + "inline-prediction-baseline-status_0_fixture.txt"
                ),
            },
            {
                "exportedFileName": screenshot_name,
                "suggestedHumanReadableName": (
                    prefix + "inline-prediction-baseline_0_"
                    "53932C55-AF89-42BB-A103-8FCD5302EEBD.png"
                ),
            },
            {
                "exportedFileName": hierarchy_name,
                "suggestedHumanReadableName": (
                    prefix + "hierarchy_0_"
                    "B73B93E2-5681-4F15-BA18-E40DCBDE2026.txt"
                ),
            },
        ])
    manifest = [{
        "testIdentifier": (
            "IDInlinePredictionLifecycleUITests/"
            "testBatchedCertification"
        ),
        "attachments": attachments,
    }]
    (directory / "manifest.json").write_text(json.dumps(manifest))


def group_boundaries(group, token="a" * 64):
    return [{
        "schema": 2,
        "token": token,
        "groupId": group["id"],
        **identity,
        "resetSummarySHA256": "b" * 64,
        "result": "ready",
    } for identity in protocol_module.boundary_plan(group)]


def write_group_export(directory, group, token="a" * 64):
    directory.mkdir()
    attachments = []
    group_metadata = {
        "schema": 1,
        "groupId": group["id"],
        "subsystem": group["subsystem"],
        "runtime": batch_module.RUNTIME,
        "udid": batch_module.PINNED_UDID,
        "tokenSHA256": hashlib.sha256(token.encode("utf-8")).hexdigest(),
        "batches": [batch["id"] for batch in group["batches"]],
    }
    (directory / "group-metadata.json").write_text(json.dumps(group_metadata))
    attachments.append({
        "exportedFileName": "group-metadata.json",
        "suggestedHumanReadableName": (
            "group-metadata_0_7607BD27-29AC-4A69-9A5E-5A7719CFB0D5.json"
        ),
    })
    attachment_index = 0
    for batch_index, batch in enumerate(group["batches"]):
        metadata_name = f"metadata-{batch_index}.json"
        metadata = {
            "schema": 1,
            "batchId": batch["id"],
            "subsystem": batch["subsystem"],
            "runtime": batch_module.RUNTIME,
            "udid": batch_module.PINNED_UDID,
            "observations": batch["hosts"],
        }
        (directory / metadata_name).write_text(json.dumps(metadata))
        attachments.append({
            "exportedFileName": metadata_name,
            "suggestedHumanReadableName": (
                f"group--{batch['id']}--metadata_0_"
                f"7607BD27-29AC-4A69-9A5E-{batch_index:012d}.json"
            ),
        })
        for observation in batch["hosts"]:
            prefix = (
                f"group--{batch['id']}--{observation['row']}--"
                f"{observation['host']}--"
            )
            status_name = f"status-{attachment_index}.json"
            screenshot_name = f"screenshot-{attachment_index}.png"
            hierarchy_name = f"hierarchy-{attachment_index}.txt"
            (directory / status_name).write_text(json.dumps(inline_status()))
            (directory / screenshot_name).write_bytes(b"png")
            (directory / hierarchy_name).write_text("Application hierarchy")
            attachments.extend([
                {
                    "exportedFileName": status_name,
                    "suggestedHumanReadableName": (
                        prefix + "inline-prediction-baseline-status_0_fixture.txt"
                    ),
                },
                {
                    "exportedFileName": screenshot_name,
                    "suggestedHumanReadableName": (
                        prefix + "inline-prediction-baseline_0_fixture.png"
                    ),
                },
                {
                    "exportedFileName": hierarchy_name,
                    "suggestedHumanReadableName": (
                        prefix + "hierarchy_0_"
                        "B73B93E2-5681-4F15-BA18-E40DCBDE2026.txt"
                    ),
                },
            ])
            attachment_index += 1
    manifest = [{
        "testIdentifier": (
            "IDInlinePredictionLifecycleUITests/testBatchedCertification"
        ),
        # xcresulttool exports XCTest attachments newest-first. Keep the
        # synthetic manifest faithful to the real group result so extraction
        # cannot accidentally depend on addAttachment: insertion order.
        "attachments": list(reversed(attachments)),
    }]
    (directory / "manifest.json").write_text(json.dumps(manifest))


def write_snapshot_checkpoints(directory, exported, group,
                               successful_attempts=None, count=8):
    successful_attempts = successful_attempts or {}
    directory.mkdir()
    observations = [
        (batch, observation)
        for batch in group["batches"]
        for observation in batch["hosts"]
    ]
    attempt_entries = []
    for index, (batch, observation) in enumerate(observations[:count], 1):
        attempt = successful_attempts.get(index, 1)
        package = directory / f"observation-{index:03d}.checkpoint"
        attachments = package / "attachments"
        attachments.mkdir(parents=True)
        files = {
            "metadata.json": {
                "schema": 1,
                "runtime": batch_module.RUNTIME,
                "udid": batch_module.PINNED_UDID,
                "observationIndex": index,
                "batchId": batch["id"],
                "rowId": observation["row"],
                "host": observation["host"],
                "successfulAttempt": attempt,
                "result": "complete",
            },
            "attachments/inline-prediction-offered-status.json":
                inline_status(),
        }
        for relative, value in files.items():
            (package / relative).write_text(json.dumps(value))
        (attachments / "inline-prediction-offered.png").write_bytes(b"png")
        (attachments / "hierarchy.txt").write_text("Application hierarchy")
        manifest_entries = []
        for child in sorted(
                path for path in package.rglob("*") if path.is_file()):
            relative = child.relative_to(package).as_posix()
            manifest_entries.append({
                "path": relative,
                "size": child.stat().st_size,
                "sha256": hashlib.sha256(child.read_bytes()).hexdigest(),
            })
        (package / "manifest.json").write_text(json.dumps({
            "schema": 1,
            "files": manifest_entries,
        }))
        attempt_entries.append({
            "observationIndex": index,
            "batchId": batch["id"],
            "rowId": observation["row"],
            "host": observation["host"],
            "successfulAttempt": attempt,
            "readinessAttempts": attempt - 1,
        })

    attempt_map = exported / "observation-attempts.json"
    attempt_map.write_text(json.dumps({
        "schema": 1,
        "groupId": group["id"],
        "observations": attempt_entries,
    }))
    manifest_path = exported / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest[0]["attachments"].insert(0, {
        "exportedFileName": attempt_map.name,
        "suggestedHumanReadableName": (
            "observation-attempts_0_7607BD27-29AC-4A69-"
            "9A5E-5A7719CFB0D5.json"
        ),
    })
    diagnostic_duplicates = []
    for index, (batch, observation) in enumerate(observations[:count], 1):
        successful = successful_attempts.get(index, 1)
        prefix = (
            f"group--{batch['id']}--{observation['row']}--"
            f"{observation['host']}--"
        )
        for attachment in manifest[0]["attachments"]:
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith(prefix):
                continue
            attachment["suggestedHumanReadableName"] = name.replace(
                prefix, prefix + f"attempt-{successful:03d}--", 1
            )
            for attempt in range(1, successful):
                duplicate = dict(attachment)
                duplicate["suggestedHumanReadableName"] = name.replace(
                    prefix, prefix + f"attempt-{attempt:03d}--", 1
                )
                diagnostic_duplicates.append(duplicate)
    manifest[0]["attachments"][:0] = diagnostic_duplicates
    manifest_path.write_text(json.dumps(manifest))


class GroupEvidenceTests(unittest.TestCase):
    def setUp(self):
        catalog = valid_catalog("inline-prediction")
        catalog["groups"] = [{
            "id": "interior",
            "language": "en-US",
            "rows": catalog["rows"][:3],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "before-boundary",
            "language": "en-US",
            "rows": catalog["rows"][3:6],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "after-boundary",
            "language": "en-US",
            "rows": catalog["rows"][6:],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }]
        self.catalog = catalog
        self.group = batch_module.logical_groups(catalog)[0]

    def extract(self, root, boundaries=None):
        checkpoints = root / "checkpoints"
        if not checkpoints.exists():
            write_snapshot_checkpoints(
                checkpoints, root / "exported", self.group
            )
        return batch_module.extract_group(
            root / "exported", self.group, root / "output",
            pathlib.Path("group.xcresult"),
            group_boundaries(self.group) if boundaries is None else boundaries,
            checkpoints=checkpoints,
        )

    def test_extract_materializes_complete_snapshot_row(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            write_group_export(root / "exported", self.group)
            summary = self.extract(root)
            self.assertEqual(summary["batches"], 4)
            self.assertEqual(summary["comparisons"], 4)
            self.assertEqual(summary["hostObservations"], 8)
            self.assertEqual(summary["successfulBoundaries"], 7)
            self.assertEqual(summary["successfulHostBoundaries"], 4)
            self.assertEqual(summary["successfulPassBoundaries"], 3)
            self.assertEqual(summary["successfulRowBoundaries"], 0)
            self.assertEqual(len(summary["hostBoundaries"]), 4)
            self.assertEqual(len(summary["passBoundaries"]), 3)
            self.assertEqual(len(summary["rowBoundaries"]), 0)
            self.assertEqual(
                [(item["sequenceIndex"], item["kind"])
                 for item in summary["boundaries"]],
                [(item["sequenceIndex"], item["kind"])
                 for item in protocol_module.boundary_plan(self.group)],
            )
            self.assertEqual(summary["batchIds"], [
                batch["id"] for batch in self.group["batches"]
            ])
            for batch in self.group["batches"]:
                self.assertTrue((
                    root / "output" / "batches" / batch["id"] /
                    "batch-summary.json"
                ).is_file())
            summary_path = root / "output" / "group-summary.json"
            self.assertTrue(summary_path.is_file())
            self.assertNotIn("a" * 64, summary_path.read_text())
            self.assertFalse((root / "output" / "pass-exports").exists())

    def test_extract_group_cli_materializes_the_selected_group(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            output = root / "output"
            catalog = root / "catalog.json"
            boundaries = root / "boundaries.json"
            write_group_export(exported, self.group)
            write_snapshot_checkpoints(
                root / "checkpoints", exported, self.group
            )
            catalog.write_text(json.dumps(self.catalog))
            boundaries.write_text(json.dumps(group_boundaries(self.group)))
            result = subprocess.run([
                sys.executable, str(SCRIPT), "extract-group",
                "--catalog", str(catalog),
                "--group-id", self.group["id"],
                "--attachments", str(exported),
                "--output", str(output),
                "--xcresult", "group.xcresult",
                "--boundaries", str(boundaries),
                "--checkpoints", str(root / "checkpoints"),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            summary = json.loads(result.stdout)
            self.assertEqual(summary["successfulBoundaries"], 7)
            self.assertEqual(summary["successfulHostBoundaries"], 4)
            self.assertEqual(summary["successfulPassBoundaries"], 3)
            self.assertEqual(summary["successfulRowBoundaries"], 0)

    def test_boundary_validation_isolates_hosts_for_single_state_sensitive_rows(self):
        token = "a" * 64
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        ordinary = copy.deepcopy(self.group)
        ordinary["stateSensitive"] = False
        for batch in ordinary["batches"]:
            batch["stateSensitive"] = False
        single_row = copy.deepcopy(self.group)
        single_row["rows"] = single_row["rows"][:1]
        for batch in single_row["batches"]:
            batch["rows"] = batch["rows"][:1]
            batch["hosts"] = batch["hosts"][:2]
        for group, expected_kinds in (
                (ordinary, ["pass", "pass", "pass"]),
                (single_row, [
                    "host", "pass", "host", "pass",
                    "host", "pass", "host",
                ])):
            with self.subTest(group=group):
                sanitized = batch_module._validated_group_boundaries(
                    group, group_boundaries(group, token), token_hash)
                self.assertEqual([item["kind"] for item in sanitized],
                                 expected_kinds)

    def test_extract_rejects_missing_duplicate_and_reordered_metadata(self):
        def change_first_stock_custom_identity(attachments):
            attachment = next(
                item for item in attachments
                if "--stock-custom--" in item["suggestedHumanReadableName"]
            )
            attachment["suggestedHumanReadableName"] = attachment[
                "suggestedHumanReadableName"
            ].replace("--stock-custom--", "--custom-stock--", 1)

        mutations = {
            "missing": lambda attachments: attachments.pop(0),
            "duplicate": lambda attachments: attachments.insert(
                1, dict(attachments[0])
            ),
            "wrong-identity": change_first_stock_custom_identity,
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                exported = root / "exported"
                write_group_export(exported, self.group)
                manifest_path = exported / "manifest.json"
                manifest = json.loads(manifest_path.read_text())
                metadata = [
                    attachment for attachment in manifest[0]["attachments"]
                    if "--metadata_" in attachment["suggestedHumanReadableName"]
                ]
                nonmetadata = [
                    attachment for attachment in manifest[0]["attachments"]
                    if "--metadata_" not in attachment["suggestedHumanReadableName"]
                ]
                mutation(metadata)
                manifest[0]["attachments"] = [nonmetadata[0], *metadata, *nonmetadata[1:]]
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(batch_module.BatchEvidenceError):
                    self.extract(root)

    def test_extract_rejects_wrong_namespace_pass_missing_host_and_extra_pass(self):
        def pass_attachment(attachments):
            return next(
                attachment for attachment in attachments
                if attachment["suggestedHumanReadableName"].startswith(
                    "group--"
                )
            )

        def first_batch_attachment(attachments):
            return next(
                attachment for attachment in attachments
                if self.group["batches"][0]["id"] in
                attachment["suggestedHumanReadableName"] and
                "--metadata_" in attachment["suggestedHumanReadableName"]
            )

        def corrupt_namespace(attachments):
            attachment = pass_attachment(attachments)
            attachment["suggestedHumanReadableName"] = attachment[
                "suggestedHumanReadableName"
            ].replace("group--", "batch--", 1)

        def corrupt_batch_identity(attachments):
            attachment = first_batch_attachment(attachments)
            attachment["suggestedHumanReadableName"] = attachment[
                "suggestedHumanReadableName"
            ].replace(
                self.group["batches"][0]["id"],
                self.group["batches"][0]["id"].replace(
                    "--stock-custom--", "--custom-stock--", 1
                ),
            )

        mutations = {
            "namespace": corrupt_namespace,
            "wrong-batch": corrupt_batch_identity,
            "extra-pass": lambda attachments: attachments.append({
                "exportedFileName": attachments[1]["exportedFileName"],
                "suggestedHumanReadableName": (
                    "group--inline-prediction--r3--stock-custom--interior--"
                    "metadata_0_fixture.json"
                ),
            }),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                exported = root / "exported"
                write_group_export(exported, self.group)
                manifest_path = exported / "manifest.json"
                manifest = json.loads(manifest_path.read_text())
                mutation(manifest[0]["attachments"])
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(batch_module.BatchEvidenceError):
                    self.extract(root)

    def test_extract_ignores_only_reset_induced_testmanager_crash_attachments(self):
        valid_header = {
            "app_name": "testmanagerd",
            "name": "testmanagerd",
            "bug_type": "309",
        }
        valid_payload = {
            "procName": "testmanagerd",
            "codeSigningID": "com.apple.testmanagerd",
            "exception": {"type": "EXC_CRASH", "signal": "SIGKILL"},
            "termination": {
                "namespace": "LIBXPC",
                "indicator": "XPC_EXIT_REASON_SIGTERM_TIMEOUT",
            },
        }

        def add_crash_attachment(exported, header, payload,
                                 associated_with_failure=False):
            crash = exported / "reset-testmanager.ips"
            crash.write_text(
                json.dumps(header) + "\n" + json.dumps(payload) + "\n"
            )
            manifest_path = exported / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest[0]["attachments"].insert(0, {
                "exportedFileName": crash.name,
                "suggestedHumanReadableName": (
                    "Crash Log 2026-08-02 at 05.27.18 PM.ips"
                ),
                "isAssociatedWithFailure": associated_with_failure,
            })
            manifest_path.write_text(json.dumps(manifest))

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            write_group_export(exported, self.group)
            add_crash_attachment(exported, valid_header, valid_payload)
            summary = self.extract(root)
            self.assertEqual(summary["result"], "Passed")

        invalid_variants = {
            "app-crash": (
                {**valid_header, "app_name": "InputDec", "name": "InputDec"},
                {**valid_payload, "procName": "InputDec",
                 "codeSigningID": "com.inputdec.demo"},
                False,
            ),
            "unexpected-termination": (
                valid_header,
                {**valid_payload, "termination": {
                    "namespace": "SIGNAL", "indicator": "Abort trap: 6"
                }},
                False,
            ),
            "associated-failure": (
                valid_header,
                valid_payload,
                True,
            ),
        }
        for label, (header, payload, associated) in invalid_variants.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                exported = root / "exported"
                write_group_export(exported, self.group)
                add_crash_attachment(exported, header, payload, associated)
                with self.assertRaisesRegex(
                    batch_module.BatchEvidenceError,
                    "unknown group attachment",
                ):
                    self.extract(root)

    def test_extract_rejects_bad_boundaries_token_hash_and_existing_output(self):
        boundary_mutations = {
            "missing": lambda value: value.pop(),
            "extra": lambda value: value.append(dict(value[-1])),
            "wrong-sequence": lambda value: value[0].update({
                "sequenceIndex": 2}),
            "wrong-kind": lambda value: value[0].update({"kind": "pass"}),
            "wrong-batch": lambda value: value[0].update({
                "batchId": self.group["batches"][0]["id"].replace(
                    "--stock-custom--", "--custom-stock--", 1)}),
            "wrong-row": lambda value: value[0].update({
                "nextRowId": "other-row"}),
            "bad-reset-hash": lambda value: value[0].update({
                "resetSummarySHA256": "bad"}),
        }
        for label, mutation in boundary_mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                write_group_export(root / "exported", self.group)
                boundaries = group_boundaries(self.group)
                mutation(boundaries)
                with self.assertRaises(batch_module.BatchEvidenceError):
                    self.extract(root, boundaries)

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            write_group_export(root / "exported", self.group)
            boundaries = group_boundaries(self.group, token="c" * 64)
            with self.assertRaisesRegex(
                batch_module.BatchEvidenceError, "token hash"
            ):
                self.extract(root, boundaries)

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            write_group_export(root / "exported", self.group)
            (root / "output").mkdir()
            with self.assertRaisesRegex(
                batch_module.BatchEvidenceError, "existing output"
            ):
                self.extract(root)


class BatchEvidenceTests(unittest.TestCase):
    def setUp(self):
        catalog = valid_catalog("inline-prediction")
        catalog["groups"] = [{
            "id": "interior",
            "language": "en-US",
            "rows": catalog["rows"][:3],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "before-boundary",
            "language": "en-US",
            "rows": catalog["rows"][3:6],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }, {
            "id": "after-boundary",
            "language": "en-US",
            "rows": catalog["rows"][6:],
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
        }]
        self.batch = expand_batches(catalog)[0]

    def test_extract_materializes_rows_in_order_and_compares_pairs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            output = root / "output"
            write_batch_export(exported, self.batch)
            summary = batch_module.extract_batch(
                exported, self.batch, output, pathlib.Path("batch.xcresult")
            )
            self.assertEqual(summary["observedHosts"], self.batch["hosts"])
            self.assertEqual(summary["comparisons"], 1)
            self.assertEqual(summary["hostObservations"], 2)
            for row in self.batch["rows"]:
                for host in ("stock", "custom"):
                    self.assertTrue((
                        output / row / host / "attachments" / "manifest.json"
                    ).is_file())
                self.assertTrue((output / row / "parity.json").is_file())
            self.assertTrue((output / "batch-summary.json").is_file())

    def test_extract_rejects_metadata_observation_reordering(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            write_batch_export(
                exported, self.batch, list(reversed(self.batch["hosts"]))
            )
            with self.assertRaisesRegex(
                batch_module.BatchEvidenceError, "observation order"
            ):
                batch_module.extract_batch(
                    exported, self.batch, root / "output",
                    pathlib.Path("batch.xcresult")
                )

    def test_extract_rejects_missing_duplicate_and_unexpected_hosts(self):
        mutations = {
            "missing": lambda attachments: attachments.pop(1),
            "duplicate": lambda attachments: attachments.append(
                dict(attachments[1])
            ),
            "unexpected": lambda attachments: attachments[1].update({
                "suggestedHumanReadableName": attachments[1][
                    "suggestedHumanReadableName"
                ].replace("interior-accept", "unknown-row")
            }),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                exported = root / "exported"
                write_batch_export(exported, self.batch)
                manifest_path = exported / "manifest.json"
                manifest = json.loads(manifest_path.read_text())
                mutation(manifest[0]["attachments"])
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(batch_module.BatchEvidenceError):
                    batch_module.extract_batch(
                        exported, self.batch, root / "output",
                        pathlib.Path("batch.xcresult")
                    )

    def test_extract_rejects_wrong_test_runtime_device_batch_and_existing_output(self):
        mutations = {
            "test": lambda manifest, metadata: manifest[0].update({
                "testIdentifier": "wrong/test"
            }),
            "runtime": lambda manifest, metadata: metadata.update({
                "runtime": {"osVersion": "26.4", "osBuild": "wrong"}
            }),
            "udid": lambda manifest, metadata: metadata.update({"udid": "wrong"}),
            "batch": lambda manifest, metadata: metadata.update({"batchId": "wrong"}),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                exported = root / "exported"
                write_batch_export(exported, self.batch)
                manifest_path = exported / "manifest.json"
                metadata_path = exported / "metadata.json"
                manifest = json.loads(manifest_path.read_text())
                metadata = json.loads(metadata_path.read_text())
                mutation(manifest, metadata)
                manifest_path.write_text(json.dumps(manifest))
                metadata_path.write_text(json.dumps(metadata))
                with self.assertRaises(batch_module.BatchEvidenceError):
                    batch_module.extract_batch(
                        exported, self.batch, root / "output",
                        pathlib.Path("batch.xcresult")
                    )

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            output = root / "output"
            write_batch_export(exported, self.batch)
            output.mkdir()
            with self.assertRaisesRegex(
                batch_module.BatchEvidenceError, "existing output"
            ):
                batch_module.extract_batch(
                    exported, self.batch, output,
                    pathlib.Path("batch.xcresult")
                )


class BatchEntrySourceTests(unittest.TestCase):
    def test_autocorrection_batch_entry_resolves_rows_and_both_hosts(self):
        source = (
            ROOT / "UITests" / "IDAutocorrectionDecisionUITests.m"
        ).read_text(encoding="utf-8")
        for token in (
            "testBatchedCertification",
            'IDLoadSelectedTextInputGroup(self, @"autocorrection")',
            "IDRunTextInputGroup",
            "IDCrossSelectedTextInputGroupBoundary",
            "IDAutocorrectionDecisionRowsMatchingIdentifier",
            "IDLaunchStockAutocorrectionScenario",
            "IDLaunchCustomAutocorrectionScenario",
            "IDAttachTextInputBatchHierarchy(self, application)",
            "[application terminate]",
        ):
            self.assertIn(token, source)
        self.assertIn("@finally", source)
        self.assertIn("stockChronology:", source)

    def test_inline_prediction_batch_entry_resolves_rows_and_both_hosts(self):
        source = (
            ROOT / "UITests" / "IDInlinePredictionLifecycleUITests.m"
        ).read_text(encoding="utf-8")
        for token in (
            "testBatchedCertification",
            'IDLoadSelectedTextInputGroup(self, @"inline-prediction")',
            "IDRunSnapshotTextInputGroup",
            "IDAttemptInlinePredictionLifecycle",
            "IDWriteTextInputObservationEvent",
            "IDWaitForTextInputObservationRestoreResponse",
            "IDWriteInlinePredictionObservationCheckpoint",
            "IDInlinePredictionRowsMatchingIdentifier",
            "IDLaunchStockInlinePredictionScenario",
            "IDLaunchCustomInlinePredictionScenario",
            "IDAttachTextInputBatchHierarchy(self, application)",
            "[application terminate]",
        ):
            self.assertIn(token, source)
        self.assertIn("@finally", source)
        self.assertIn("assertStockResult:", source)
        self.assertIn("assertCustomResult:", source)

    def test_ime_batch_entry_serializes_rows_and_both_hosts(self):
        source = (
            ROOT / "UITests" / "IDIMECompositionLifecycleUITests.m"
        ).read_text(encoding="utf-8")
        for token in (
            "testBatchedCertification",
            'IDLoadSelectedTextInputGroup(self, @"ime")',
            "IDRunTextInputGroup",
            "IDCrossSelectedTextInputGroupBoundary",
            "IDIMECompositionRowsMatchingIdentifier",
            "IDLaunchStockIMECompositionScenario",
            "IDLaunchCustomIMECompositionScenario",
            "IDIMECompositionLifecycleDictionary",
            'IDTextInputBatchAttachmentName(@"ime-lifecycle.json")',
            "IDAttachTextInputBatchHierarchy(self, application)",
            "[application terminate]",
        ):
            self.assertIn(token, source)
        self.assertIn("@finally", source)
        self.assertIn("assertCompleteStockLifecycle:", source)


class BatchRunnerTests(unittest.TestCase):
    def test_retry_classifier_accepts_only_exact_readiness_failures(self):
        diagnostics = (
            'Failed to determine hittability of "k" Key: Activation point '
            'invalid and no suggested hit points based on element frame',
            "Expected native inline prediction was absent",
            "Expected native candidate 'address' was not actionable",
        )
        for diagnostic in diagnostics:
            self.assertTrue(batch_module.is_readiness_failure(diagnostic))
        for diagnostic in (
            "canonical mismatch",
            'Failed to determine hittability of "x" Key: Activation point '
            'invalid and no suggested hit points based on element frame',
            "Expected native candidate 'other' was not actionable",
        ):
            self.assertFalse(batch_module.is_readiness_failure(diagnostic))

    def test_fingerprint_records_counts_and_dynamic_lexicon_hashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            keyboard = device / "Library" / "Keyboard"
            keyboard.mkdir(parents=True)
            database = keyboard / "AutocorrectionRejections.db"
            connection = sqlite3.connect(database)
            try:
                connection.execute("CREATE TABLE rejections (value TEXT)")
                connection.execute(
                    "CREATE TABLE inline_completion_rejections (value TEXT)"
                )
                connection.executemany(
                    "INSERT INTO rejections VALUES (?)", [("a",), ("b",)]
                )
                connection.execute(
                    "INSERT INTO inline_completion_rejections VALUES ('c')"
                )
                connection.commit()
            finally:
                connection.close()
            lexicon = keyboard / "mul-dynamic.lm" / "dynamic-lexicon-ja.dat"
            lexicon.parent.mkdir()
            lexicon.write_bytes(b"lexicon-state")
            provisioning = root / "provisioning.json"
            provisioning.write_text(json.dumps({
                "schema": 1,
                "udid": batch_module.PINNED_UDID,
                "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
                "inventory": ["ja-mode", "zh-mode", "en-mode"],
                "primaryLanguages": ["ja-JP", "zh-Hans"],
                "commandCount": 12,
            }))
            output = root / "fingerprint.json"
            fingerprint = batch_module.fingerprint(
                batch_module.PINNED_UDID, device, provisioning, output
            )
            self.assertEqual(fingerprint["locale"], "en_US")
            self.assertEqual(
                fingerprint["enabledInputModeIdentifiers"],
                ["ja-mode", "zh-mode", "en-mode"],
            )
            self.assertEqual(fingerprint["rejectionTableCounts"], {
                "rejections": 2,
                "inline_completion_rejections": 1,
            })
            self.assertEqual(len(fingerprint["dynamicLexicons"]), 1)
            self.assertEqual(
                fingerprint["dynamicLexicons"][0]["path"],
                "Library/Keyboard/mul-dynamic.lm/dynamic-lexicon-ja.dat",
            )
            self.assertEqual(len(fingerprint["dynamicLexicons"][0]["sha256"]),
                             64)
            self.assertEqual(json.loads(output.read_text()), fingerprint)
            with self.assertRaises(batch_module.BatchEvidenceError):
                batch_module.fingerprint(
                    batch_module.PINNED_UDID, device, provisioning, output
                )

    def test_batch_runner_has_one_erase_boot_and_xcodebuild_test_site(self):
        source = BATCH_RUNNER.read_text(encoding="utf-8")
        self.assertEqual(source.count('simctl erase "$udid"'), 1)
        self.assertEqual(source.count('simctl boot "$udid"'), 1)
        self.assertEqual(source.count("xcodebuild test-without-building"), 1)
        self.assertIn("-parallel-testing-enabled NO", source)
        self.assertIn("with-inputdec-simulator-test-lock.sh", source)
        self.assertIn("INPUTDEC_TEXT_INPUT_BATCH_ID", source)
        self.assertIn("PlistBuddy", source)
        self.assertNotIn("-parallel-testing-enabled YES", source)
        self.assertNotIn("simctl create", source)
        self.assertNotIn("simctl clone", source)


class ResumeAndAggregateTests(unittest.TestCase):
    def _write_batch_output(self, root, batch):
        root.mkdir(parents=True)
        (root / "batch.xcresult").mkdir()
        (root / "batch.log").write_text("passed\n")
        (root / "selected-batch.json").write_text(json.dumps(batch))
        fingerprint = {
            "schema": 1,
            "udid": batch_module.PINNED_UDID,
            "runtime": batch_module.RUNTIME,
            "locale": "en_US",
            "languages": ["en-US"],
            "primaryLanguages": ["ja-JP", "zh-Hans"],
            "enabledInputModeIdentifiers": ["ja", "zh", "en"],
            "rejectionTableCounts": {
                "rejections": 0,
                "inline_completion_rejections": 0,
            },
            "dynamicLexicons": [],
        }
        for name in ("pre-state.json", "post-state.json"):
            (root / name).write_text(json.dumps(fingerprint))
        provisioning = root / "provisioning"
        provisioning.mkdir()
        (provisioning / "summary.json").write_text(json.dumps({
            "schema": 1,
            "udid": batch_module.PINNED_UDID,
            "runtime": batch_module.RUNTIME,
            "inventory": ["ja", "zh", "en"],
            "primaryLanguages": ["ja-JP", "zh-Hans"],
            "commandCount": 12,
        }))
        (root / "timing.json").write_text(json.dumps({
            "schema": 1,
            "attempts": 2,
            "buildSeconds": 0,
            "eraseBootSeconds": 1,
            "provisioningResetSeconds": 2,
            "xctestSeconds": 3,
            "extractionComparisonSeconds": 4,
            "totalSeconds": 10,
        }))
        (root / "batch-summary.json").write_text(json.dumps({
            "schema": 1,
            "runtime": batch_module.RUNTIME,
            "udid": batch_module.PINNED_UDID,
            "batchId": batch["id"],
            "subsystem": batch["subsystem"],
            "observedHosts": batch["hosts"],
            "comparisons": len(batch["rows"]),
            "hostObservations": len(batch["hosts"]),
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }))
        for row in batch["rows"]:
            row_root = root / row
            comparison_name = (
                "comparison.json"
                if batch["subsystem"] == "ime"
                else "parity.json"
            )
            (row_root / comparison_name).parent.mkdir(parents=True)
            (row_root / comparison_name).write_text("{}")
            for host in ("stock", "custom"):
                host_root = row_root / host
                attachments = host_root / "attachments"
                attachments.mkdir(parents=True)
                (attachments / "manifest.json").write_text("[]")
                (host_root / "host-summary.json").write_text(json.dumps({
                    "schema": 1,
                    "row": row,
                    "host": host,
                    "batchId": batch["id"],
                }))
                if batch["subsystem"] == "ime":
                    (host_root / "lifecycle.json").write_text("{}")

    def _write_single_session_group_output(self, root, group, attempts=1):
        root.mkdir(parents=True)
        (root / "group.xcresult").mkdir()
        (root / "group.xcresult" / "Info.plist").write_bytes(b"result")
        (root / "group.log").write_text("passed\n")
        (root / "selected-group.json").write_text(json.dumps(group))
        token_hash = hashlib.sha256(("a" * 64).encode()).hexdigest()
        (root / "xcresult-summary.json").write_text(json.dumps({
            "result": "Passed",
            "totalTestCount": 1,
            "expectedFailures": 0,
            "failedTests": 0,
            "skippedTests": 0,
            "passedTests": 1,
            "devicesAndConfigurations": [{
                "expectedFailures": 0,
                "failedTests": 0,
                "skippedTests": 0,
                "passedTests": 1,
                "device": {
                    "deviceId": batch_module.PINNED_UDID,
                    "osVersion": "26.5",
                    "osBuildNumber": "23F73",
                },
            }],
        }))
        exported = root / "exported-attachments"
        exported.mkdir()
        (exported / "group-metadata.json").write_text(json.dumps({
            "schema": 1,
            "groupId": group["id"],
            "subsystem": group["subsystem"],
            "runtime": batch_module.RUNTIME,
            "udid": batch_module.PINNED_UDID,
            "tokenSHA256": token_hash,
            "batches": [batch["id"] for batch in group["batches"]],
        }))
        (exported / "manifest.json").write_text(json.dumps([{
            "testIdentifier": (
                f"{batch_module.TEST_CLASSES[group['subsystem']]}/"
                "testBatchedCertification"
            ),
            "attachments": [{
                "exportedFileName": "group-metadata.json",
                "suggestedHumanReadableName": (
                    "group-metadata_0_7607BD27-29AC-4A69-"
                    "9A5E-5A7719CFB0D5.json"
                ),
            }],
        }]))
        snapshot_group = group["id"].startswith(
            "inline-prediction--snapshot-row-v1--"
        )
        if snapshot_group:
            shutil.rmtree(exported)
            write_group_export(exported, group)
            write_snapshot_checkpoints(root / "checkpoints", exported, group)
        boundaries = []
        plan = protocol_module.boundary_plan(group)
        for identity in plan:
            reset = root / "boundaries" / (
                f"boundary-{identity['sequenceIndex']:03d}-"
                f"{identity['kind']}-reset"
            )
            reset.mkdir(parents=True)
            payload = (json.dumps({
                "schema": 1,
                "runtime": batch_module.RUNTIME,
                "udid": batch_module.PINNED_UDID,
                "result": "Passed",
            }, sort_keys=True) + "\n").encode()
            (reset / "summary.json").write_bytes(payload)
            boundaries.append({
                **identity,
                "resetSummarySHA256": hashlib.sha256(payload).hexdigest(),
                "result": "ready",
            })
        for batch in group["batches"]:
            child = root / "batches" / batch["id"]
            self._write_batch_output(child, batch)
            shutil.rmtree(child / "batch.xcresult")
            shutil.rmtree(child / "provisioning")
            for name in (
                    "batch.log", "selected-batch.json", "timing.json",
                    "pre-state.json", "post-state.json"):
                (child / name).unlink()
        fingerprint = {
            "schema": 1,
            "udid": batch_module.PINNED_UDID,
            "runtime": batch_module.RUNTIME,
            "locale": "en_US",
            "languages": ["en-US"],
            "primaryLanguages": ["ja-JP", "zh-Hans"],
            "enabledInputModeIdentifiers": ["ja", "zh", "en"],
            "rejectionTableCounts": {
                "rejections": 0,
                "inline_completion_rejections": 0,
            },
            "dynamicLexicons": [],
        }
        for name in ("pre-state.json", "post-state.json"):
            (root / name).write_text(json.dumps(fingerprint))
        provisioning = root / "provisioning"
        provisioning.mkdir()
        (provisioning / "summary.json").write_text(json.dumps({
            "schema": 1,
            "udid": batch_module.PINNED_UDID,
            "runtime": batch_module.RUNTIME,
            "inventory": ["ja", "zh", "en"],
            "primaryLanguages": ["ja-JP", "zh-Hans"],
            "commandCount": 6,
        }))
        timing = {
            "schema": 1,
            "xctestInvocations": 1,
            "attempts": attempts,
            "buildSeconds": 0,
            "eraseBootSeconds": 0 if snapshot_group else attempts,
            "provisioningResetSeconds": 0 if snapshot_group else 2,
            "xctestSeconds": 3,
            "hostResetSeconds": 0 if snapshot_group else (1 if any(
                item["kind"] == "host" for item in plan) else 0
            ),
            "rowResetSeconds": 0 if snapshot_group else (1 if any(
                item["kind"] == "row" for item in plan) else 0
            ),
            "extractionComparisonSeconds": 4,
            "totalSeconds": 10,
        }
        if snapshot_group:
            timing.update({"snapshotRestores": 8, "readinessRetries": 0})
            (root / "failure-classification.json").write_text(json.dumps({
                "schema": 1,
                "result": "Passed",
                "classification": "none",
            }))
            (root / "boundaries.json").write_text(json.dumps(boundaries))
        (root / "group-timing.json").write_text(json.dumps(timing))
        (root / "group-summary.json").write_text(json.dumps({
            "schema": 1,
            "runtime": batch_module.RUNTIME,
            "udid": batch_module.PINNED_UDID,
            "groupId": group["id"],
            "subsystem": group["subsystem"],
            "tokenSHA256": token_hash,
            "batchIds": [batch["id"] for batch in group["batches"]],
            "batches": len(group["batches"]),
            "comparisons": sum(
                len(batch["rows"]) for batch in group["batches"]),
            "hostObservations": sum(
                len(batch["hosts"]) for batch in group["batches"]),
            "successfulBoundaries": len(boundaries),
            "successfulHostBoundaries": sum(
                item["kind"] == "host" for item in boundaries),
            "successfulPassBoundaries": sum(
                item["kind"] == "pass" for item in boundaries),
            "successfulRowBoundaries": sum(
                item["kind"] == "row" for item in boundaries),
            "boundaries": boundaries,
            "hostBoundaries": [
                item for item in boundaries if item["kind"] == "host"],
            "passBoundaries": [
                item for item in boundaries if item["kind"] == "pass"],
            "rowBoundaries": [
                item for item in boundaries if item["kind"] == "row"],
            "failedTests": 0,
            "skippedTests": 0,
            "result": "Passed",
        }))

    def _write_complete_single_session_corpus(self, root):
        catalog_paths = [
            CATALOGS["ime"], CATALOGS["autocorrection"],
            CATALOGS["inline-prediction"],
        ]
        group_roots = []
        for catalog_path in catalog_paths:
            catalog = load_catalog(catalog_path)
            for group in batch_module.logical_groups(catalog):
                group_root = root / catalog["subsystem"] / group["id"]
                self._write_single_session_group_output(group_root, group)
                group_roots.append(group_root)
        return catalog_paths, group_roots

    def test_resume_requires_complete_atomically_validated_batch(self):
        catalog = load_catalog(CATALOGS["autocorrection"])
        batch = expand_batches(catalog)[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary) / "batch"
            self._write_batch_output(root, batch)
            self.assertTrue(batch_module.batch_is_resumable(root, batch))

            summary = json.loads((root / "batch-summary.json").read_text())
            summary["runtime"]["osBuild"] = "wrong"
            (root / "batch-summary.json").write_text(json.dumps(summary))
            self.assertFalse(batch_module.batch_is_resumable(root, batch))
            summary["runtime"] = batch_module.RUNTIME
            (root / "batch-summary.json").write_text(json.dumps(summary))

            (root / batch["rows"][0] / "custom" /
             "host-summary.json").unlink()
            self.assertFalse(batch_module.batch_is_resumable(root, batch))

    def test_logical_groups_use_nine_inline_snapshot_rows(self):
        expected_counts = {
            "ime": 10,
            "autocorrection": 9,
            "inline-prediction": 9,
        }
        total = 0
        for subsystem, catalog_path in CATALOGS.items():
            catalog = load_catalog(catalog_path)
            groups = batch_module.logical_groups(catalog)
            self.assertEqual(len(groups), expected_counts[subsystem])
            total += len(groups)
            for group in groups:
                self.assertEqual(group["subsystem"], subsystem)
                self.assertEqual(len(group["batches"]), 4)
                self.assertTrue(all(
                    item["rows"] == group["rows"]
                    for item in group["batches"]
                ))
                if subsystem == "inline-prediction":
                    self.assertEqual(len(group["rows"]), 1)
                    self.assertEqual(
                        group["id"],
                        "inline-prediction--snapshot-row-v1--"
                        f"{group['rows'][0]}",
                    )
                    self.assertEqual(
                        [(item["repetition"], item["order"])
                         for item in group["batches"]],
                        [(1, "stock-custom"), (1, "custom-stock"),
                         (2, "stock-custom"), (2, "custom-stock")],
                    )
                    self.assertEqual(
                        sum(len(batch["hosts"])
                            for batch in group["batches"]),
                        8,
                    )
                else:
                    self.assertEqual(
                        [(item["repetition"], item["order"])
                         for item in group["batches"]],
                        [(1, "stock-custom"), (1, "custom-stock"),
                         (2, "stock-custom"), (2, "custom-stock")],
                    )
        self.assertEqual(total, 28)

    def test_snapshot_grouping_preserves_all_112_batch_ids(self):
        actual_batch_ids = []
        expected_batch_ids = []
        for subsystem in ("ime", "autocorrection", "inline-prediction"):
            catalog = load_catalog(CATALOGS[subsystem])
            suffixes = (
                catalog["rows"]
                if subsystem == "inline-prediction"
                else [group["id"] for group in catalog["groups"]]
            )
            actual_batch_ids.extend(
                batch["id"] for batch in batch_module.expand_batches(catalog)
            )
            expected_batch_ids.extend(
                f"{subsystem}--r{repetition}--{order}--{suffix}"
                for repetition in (1, 2)
                for order in ("stock-custom", "custom-stock")
                for suffix in suffixes
            )

        self.assertEqual(actual_batch_ids, expected_batch_ids)
        self.assertEqual(len(actual_batch_ids), 112)

    def test_snapshot_grouping_preserves_non_inline_groups(self):
        for subsystem in ("ime", "autocorrection"):
            catalog = load_catalog(CATALOGS[subsystem])
            groups = batch_module.logical_groups(catalog)
            self.assertEqual(
                [group["id"] for group in groups],
                [f"{subsystem}--group--{group['id']}"
                 for group in catalog["groups"]],
            )
            self.assertTrue(all(len(group["batches"]) == 4
                                for group in groups))

    def test_group_resume_requires_single_xcresult_four_passes_and_boundaries(self):
        catalog = load_catalog(CATALOGS["inline-prediction"])
        group = batch_module.logical_groups(catalog)[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary) / "group"
            self._write_single_session_group_output(root, group)
            self.assertTrue(batch_module.group_is_resumable(root, group))

            missing = root / "batches" / group["batches"][-1]["id"]
            shutil.rmtree(missing)
            self.assertFalse(batch_module.group_is_resumable(root, group))

    def test_snapshot_extraction_preserves_failed_readiness_attempts(self):
        group = batch_module.logical_groups(
            load_catalog(CATALOGS["inline-prediction"])
        )[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            checkpoints = root / "checkpoints"
            output = root / "output"
            write_group_export(exported, group)
            write_snapshot_checkpoints(
                checkpoints, exported, group, successful_attempts={1: 2}
            )

            batch_module.extract_group(
                exported, group, output, pathlib.Path("group.xcresult"),
                group_boundaries(group), checkpoints=checkpoints,
            )

            first = group["batches"][0]["hosts"][0]
            host_root = (
                output / "batches" / group["batches"][0]["id"] /
                first["row"] / first["host"]
            )
            self.assertTrue((
                host_root / "readiness-attempts" / "attempt-001"
            ).is_dir())
            self.assertTrue((
                host_root / "attachments" / "offered-status.json"
            ).is_file())
            host_summary = json.loads(
                (host_root / "host-summary.json").read_text()
            )
            self.assertEqual(host_summary["successfulAttempt"], 2)
            self.assertEqual(host_summary["readinessAttempts"], 1)

    def test_snapshot_extraction_rejects_invalid_attempt_maps(self):
        group = batch_module.logical_groups(
            load_catalog(CATALOGS["inline-prediction"])
        )[0]

        def mutate_map(root, mutation):
            path = root / "exported" / "observation-attempts.json"
            value = json.loads(path.read_text())
            mutation(value["observations"])
            path.write_text(json.dumps(value))

        mutations = {
            "duplicate-success": lambda values: values.append(dict(values[0])),
            "attempt-21": lambda values: values[0].update({
                "successfulAttempt": 21, "readinessAttempts": 20,
            }),
            "attempt-gap": lambda values: values[0].update({
                "successfulAttempt": 3, "readinessAttempts": 1,
            }),
            "unknown-observation": lambda values: values[0].update({
                "observationIndex": 9,
            }),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), \
                    tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                write_group_export(root / "exported", group)
                write_snapshot_checkpoints(
                    root / "checkpoints", root / "exported", group
                )
                mutate_map(root, mutation)
                with self.assertRaises(batch_module.BatchEvidenceError):
                    batch_module.extract_group(
                        root / "exported", group, root / "output",
                        pathlib.Path("group.xcresult"),
                        group_boundaries(group),
                        checkpoints=root / "checkpoints",
                    )

        checkpoint_mutations = {
            "missing-manifest": lambda package:
                (package / "manifest.json").unlink(),
            "changed-hash": lambda package:
                (package / "attachments" /
                 "inline-prediction-offered.png").write_bytes(b"changed"),
        }
        for label, mutation in checkpoint_mutations.items():
            with self.subTest(label=label), \
                    tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                write_group_export(root / "exported", group)
                write_snapshot_checkpoints(
                    root / "checkpoints", root / "exported", group
                )
                mutation(root / "checkpoints" / "observation-001.checkpoint")
                with self.assertRaises(batch_module.BatchEvidenceError):
                    batch_module.extract_group(
                        root / "exported", group, root / "output",
                        pathlib.Path("group.xcresult"),
                        group_boundaries(group),
                        checkpoints=root / "checkpoints",
                    )

    def test_snapshot_resume_reuses_completed_observations(self):
        group = batch_module.logical_groups(
            load_catalog(CATALOGS["inline-prediction"])
        )[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            checkpoints = root / "checkpoints"
            write_group_export(exported, group)
            write_snapshot_checkpoints(
                checkpoints, exported, group, count=3
            )
            self.assertEqual(
                batch_module.snapshot_observation_resume_indexes(
                    checkpoints, group
                ),
                [1, 2, 3],
            )
            checked = subprocess.run([
                sys.executable, str(SCRIPT), "observation-resume-check",
                "--catalog", str(CATALOGS["inline-prediction"]),
                "--group-id", group["id"],
                "--directory", str(checkpoints),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertEqual(checked.stdout.strip(), "1,2,3")

            (checkpoints / "observation-002.checkpoint").rename(
                checkpoints / "observation-004.checkpoint"
            )
            with self.assertRaises(batch_module.BatchEvidenceError):
                batch_module.snapshot_observation_resume_indexes(
                    checkpoints, group
                )

        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            exported = root / "exported"
            checkpoints = root / "checkpoints"
            write_group_export(exported, group)
            write_snapshot_checkpoints(checkpoints, exported, group)
            attempt_map_path = exported / "observation-attempts.json"
            attempt_map = json.loads(attempt_map_path.read_text())
            attempt_map["observations"] = attempt_map["observations"][3:]
            attempt_map_path.write_text(json.dumps(attempt_map))
            summary = batch_module.extract_group(
                exported, group, root / "output",
                pathlib.Path("group.xcresult"), group_boundaries(group),
                checkpoints=checkpoints,
            )
            self.assertEqual(summary["hostObservations"], 8)

    def test_group_resume_rejects_raw_token_extra_result_and_bad_boundary_hash(self):
        group = batch_module.logical_groups(
            load_catalog(CATALOGS["inline-prediction"])
        )[0]
        def mutate_summary(root, mutation):
            path = root / "group-summary.json"
            summary = json.loads(path.read_text())
            mutation(summary)
            path.write_text(json.dumps(summary))

        mutations = {
            "raw-token": lambda root: (root / "leaked-token.txt").write_text(
                "a" * 64
            ),
            "extra-result": lambda root: (root / "extra.xcresult").mkdir(),
            "boundary-hash": lambda root: mutate_summary(
                root, lambda summary: summary["boundaries"][0].update({
                    "resetSummarySHA256": "changed",
                })
            ),
            "missing-boundary": lambda root: mutate_summary(
                root, lambda summary: summary["boundaries"].pop()
            ),
            "extra-boundary": lambda root: mutate_summary(
                root, lambda summary: summary["boundaries"].append(
                    dict(summary["boundaries"][-1])
                )
            ),
            "skipped-test": lambda root: mutate_summary(
                root, lambda summary: summary.update({"skippedTests": 1})
            ),
            "failed-test": lambda root: mutate_summary(
                root, lambda summary: summary.update({"failedTests": 1})
            ),
            "changed-token-hash": lambda root: mutate_summary(
                root, lambda summary: summary.update({"tokenSHA256": "d" * 64})
            ),
            "embedded-raw-token": lambda root: (
                root / "leaked-token.json"
            ).write_text(json.dumps({"message": "prefix " + "a" * 64 + " suffix"})),
            "large-log-raw-token": lambda root: (
                root / "large.log"
            ).write_text("x" * 1024 + "a" * 64 + "y" * 1024),
            "empty-xcresult": lambda root: (
                root / "group.xcresult" / "Info.plist"
            ).unlink(),
            "failed-xcresult-summary": lambda root: (
                root / "xcresult-summary.json"
            ).write_text(json.dumps({"result": "Failed"})),
            "inconsistent-timing": lambda root: (
                root / "group-timing.json"
            ).write_text(json.dumps({
                **json.loads((root / "group-timing.json").read_text()),
                "xctestSeconds": 999,
                "totalSeconds": 0,
            })),
            "row-timing-exceeds-xctest": lambda root: (
                root / "group-timing.json"
            ).write_text(json.dumps({
                **json.loads((root / "group-timing.json").read_text()),
                "rowResetSeconds": 4,
                "xctestSeconds": 3,
            })),
            "host-timing-exceeds-xctest": lambda root: (
                root / "group-timing.json"
            ).write_text(json.dumps({
                **json.loads((root / "group-timing.json").read_text()),
                "hostResetSeconds": 4,
                "xctestSeconds": 3,
            })),
            "row-replaced-by-pass": lambda root: mutate_summary(
                root, lambda summary: summary["boundaries"].__setitem__(
                    0, {**summary["hostBoundaries"][0], "kind": "pass"}
                )
            ),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary) / "group"
                self._write_single_session_group_output(root, group)
                mutation(root)
                self.assertFalse(batch_module.group_is_resumable(root, group))

    def test_group_cli_lists_shows_summarizes_and_checks_atomically(self):
        catalog_path = CATALOGS["inline-prediction"]
        catalog = load_catalog(catalog_path)
        group = batch_module.logical_groups(catalog)[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            listed = subprocess.run([
                sys.executable, str(SCRIPT), "list-groups", str(catalog_path),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(listed.returncode, 0, listed.stderr)
            self.assertEqual(
                listed.stdout.splitlines()[0], group["id"]
            )
            shown = subprocess.run([
                sys.executable, str(SCRIPT), "show-group",
                str(catalog_path), group["id"],
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(shown.returncode, 0, shown.stderr)
            self.assertEqual(json.loads(shown.stdout), group)

            group_root = root / "group"
            self._write_single_session_group_output(group_root, group)
            checked = subprocess.run([
                sys.executable, str(SCRIPT), "group-resume-check",
                "--catalog", str(catalog_path), "--group-id", group["id"],
                "--directory", str(group_root),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertIn(f"RESUMABLE {group['id']}", checked.stdout)

    def test_aggregate_counts_28_groups_20_boots_and_112_batches(self):
        ordered_catalogs = [
            CATALOGS["ime"], CATALOGS["autocorrection"],
            CATALOGS["inline-prediction"],
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary) / "groups"
            for catalog_path in ordered_catalogs:
                catalog = load_catalog(catalog_path)
                for group in batch_module.logical_groups(catalog):
                    group_root = root / catalog["subsystem"] / group["id"]
                    self._write_single_session_group_output(group_root, group)
            summary = batch_module.aggregate_certification(
                ordered_catalogs, root
            )
            self.assertEqual(summary["groups"], 28)
            self.assertEqual(summary["erasedBoots"], 20)
            self.assertEqual(summary["successfulXCTestInvocations"], 28)
            self.assertEqual(summary["successfulBoundaries"], 344)
            self.assertEqual(summary["successfulHostBoundaries"], 180)
            self.assertEqual(summary["successfulPassBoundaries"], 84)
            self.assertEqual(summary["successfulRowBoundaries"], 80)
            self.assertEqual(summary["totalAttempts"], 28)
            self.assertEqual(summary["batches"], 112)
            self.assertEqual(summary["comparisons"], 216)
            self.assertEqual(summary["hostObservations"], 432)
            self.assertEqual(summary["durations"]["eraseBootSeconds"], 19)
            self.assertEqual(summary["durations"]["totalSeconds"], 280)

    def test_aggregate_requires_all_216_comparisons_and_432_hosts(self):
        ordered_catalogs = [
            CATALOGS["ime"], CATALOGS["autocorrection"],
            CATALOGS["inline-prediction"],
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary) / "batches"
            expected_ids = []
            for catalog_path in ordered_catalogs:
                catalog = load_catalog(catalog_path)
                for group in batch_module.logical_groups(catalog):
                    group_root = root / catalog["subsystem"] / group["id"]
                    expected_ids.extend(
                        batch["id"] for batch in group["batches"]
                    )
                    self._write_single_session_group_output(group_root, group)
            summary = batch_module.aggregate_certification(
                ordered_catalogs, root
            )
            self.assertEqual(summary["logicalRows"], 54)
            self.assertEqual(summary["batches"], 112)
            self.assertEqual(summary["comparisons"], 216)
            self.assertEqual(summary["hostObservations"], 432)
            self.assertEqual(summary["readinessRetries"], 0)
            self.assertEqual(summary["failedTests"], 0)
            self.assertEqual(summary["skippedTests"], 0)
            self.assertEqual(summary["result"], "Passed")
            self.assertEqual(
                [child["batchId"] for child in summary["children"]],
                expected_ids,
            )
            self.assertEqual(len(summary["catalogs"]), 3)
            for catalog in summary["catalogs"]:
                self.assertEqual(len(catalog["sha256"]), 64)

            inline_group = batch_module.logical_groups(
                load_catalog(CATALOGS["inline-prediction"])
            )[0]
            inline_batch = inline_group["batches"][0]
            inline_observation = inline_batch["hosts"][0]
            host_summary_path = (
                root / "inline-prediction" / inline_group["id"] /
                "batches" / inline_batch["id"] /
                inline_observation["row"] / inline_observation["host"] /
                "host-summary.json"
            )
            host_summary = json.loads(host_summary_path.read_text())
            host_summary.update({
                "successfulAttempt": 3,
                "readinessAttempts": 2,
            })
            host_summary_path.write_text(json.dumps(host_summary))
            retried = batch_module.aggregate_certification(
                ordered_catalogs, root
            )
            self.assertEqual(retried["readinessRetries"], 2)

            duplicate = ordered_catalogs + [ordered_catalogs[0]]
            with self.assertRaisesRegex(
                    batch_module.BatchEvidenceError, "duplicate aggregate"):
                batch_module.aggregate_certification(duplicate, root)

            first_group = batch_module.logical_groups(
                load_catalog(ordered_catalogs[0])
            )[0]
            missing = (root / "ime" / first_group["id"] / "batches" /
                       expected_ids[0] / "batch-summary.json")
            missing.unlink()
            with self.assertRaises(batch_module.BatchEvidenceError):
                batch_module.aggregate_certification(ordered_catalogs, root)

    def test_group_resume_uses_one_snapshot_xctest_and_legacy_attempt_limits(self):
        inline = batch_module.logical_groups(
            load_catalog(CATALOGS["inline-prediction"])
        )[0]
        autocorrection = batch_module.logical_groups(
            load_catalog(CATALOGS["autocorrection"])
        )[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            inline_root = root / "inline"
            self._write_single_session_group_output(inline_root, inline)
            timing_path = inline_root / "group-timing.json"
            timing = json.loads(timing_path.read_text())
            timing["totalSeconds"] = 29
            timing_path.write_text(json.dumps(timing))
            self.assertTrue(batch_module.group_is_resumable(
                inline_root, inline
            ))
            timing = json.loads(timing_path.read_text())
            timing["attempts"] = 2
            timing_path.write_text(json.dumps(timing))
            self.assertFalse(batch_module.group_is_resumable(
                inline_root, inline
            ))

            autocorrection_root = root / "autocorrection"
            self._write_single_session_group_output(
                autocorrection_root, autocorrection, attempts=4
            )
            self.assertFalse(batch_module.group_is_resumable(
                autocorrection_root, autocorrection
            ))

    def test_aggregate_rejects_extra_group_pass_and_inline_attempt_21(self):
        mutations = {
            "extra-group": lambda roots: shutil.copytree(
                roots[0], roots[0].parent / "unexpected-group"
            ),
            "extra-pass": lambda roots: (
                roots[0] / "batches" / "unexpected-pass"
            ).mkdir(),
            "inline-second-xctest": lambda roots: next(
                root for root in roots
                if root.parent.name == "inline-prediction"
            ).joinpath("group-timing.json").write_text(json.dumps({
                **json.loads(next(
                    root for root in roots
                    if root.parent.name == "inline-prediction"
                ).joinpath("group-timing.json").read_text()),
                "attempts": 2,
            })),
        }
        for label, mutation in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary) / "groups"
                catalogs, group_roots = self._write_complete_single_session_corpus(
                    root
                )
                mutation(group_roots)
                with self.assertRaises(batch_module.BatchEvidenceError):
                    batch_module.aggregate_certification(catalogs, root)

    def test_resume_check_and_aggregate_cli_are_create_only(self):
        catalog_path = CATALOGS["inline-prediction"]
        catalog = load_catalog(catalog_path)
        batch = expand_batches(catalog)[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            batch_root = root / "batch"
            self._write_batch_output(batch_root, batch)
            checked = subprocess.run([
                sys.executable, str(SCRIPT), "resume-check",
                "--catalog", str(catalog_path),
                "--batch-id", batch["id"],
                "--directory", str(batch_root),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertIn(f"RESUMABLE {batch['id']}", checked.stdout)

            invalid = subprocess.run([
                sys.executable, str(SCRIPT), "resume-check",
                "--catalog", str(catalog_path),
                "--batch-id", batch["id"],
                "--directory", str(root / "missing"),
            ], cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(invalid.returncode, 65)

            all_root = root / "all"
            catalog_paths = [
                CATALOGS["ime"], CATALOGS["autocorrection"],
                CATALOGS["inline-prediction"],
            ]
            for path in catalog_paths:
                loaded = load_catalog(path)
                for group in batch_module.logical_groups(loaded):
                    group_root = all_root / loaded["subsystem"] / group["id"]
                    self._write_single_session_group_output(group_root, group)
            output = root / "summary.json"
            command = [
                sys.executable, str(SCRIPT), "aggregate",
                "--batches-root", str(all_root),
                "--output", str(output),
            ]
            for path in catalog_paths:
                command.extend(["--catalog", str(path)])
            aggregated = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(aggregated.returncode, 0, aggregated.stderr)
            self.assertEqual(json.loads(output.read_text())["comparisons"], 216)
            refused = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(refused.returncode, 65)


class AuthorityComparisonTests(unittest.TestCase):
    def test_autocorrection_authority_payload_uses_comparator_contract(self):
        statuses = {
            "baseline": {
                "canonical": "adress",
                "blocks": ["adress"],
                "selection": {"location": 6, "length": 0},
                "affinity": "forward",
                "markedRange": {"location": -1, "length": 0},
                "structuralNewlineLocations": [],
                "checkingRanges": [],
                "candidateDescriptor": {
                    "actionable": True, "candidate": "address",
                    "original": "adress",
                },
                "firstResponder": True,
                "keyboardState": {
                    "visible": True, "locale": "en-US",
                    "learnedOriginal": False,
                },
                "correctionGeometry": {
                    "x": 1.0, "y": 2.0, "width": 3.0, "height": 4.0,
                },
                "ignoredEpoch": 99,
            },
        }

        semantic, geometry = batch_module.authority_payload(
            "autocorrection", statuses
        )

        self.assertEqual(semantic["phases"][0]["phase"], "baseline")
        self.assertNotIn("ignoredEpoch", semantic["phases"][0]["status"])
        self.assertNotIn(
            "correctionGeometry", semantic["phases"][0]["status"]
        )
        self.assertEqual(
            geometry,
            {"phases": [{
                "phase": "baseline",
                "correctionGeometry": {
                    "x": 1.0, "y": 2.0, "width": 3.0, "height": 4.0,
                },
            }]},
        )

    def test_authority_payload_canonicalizes_signed_ns_not_found(self):
        status = inline_status()
        status["markedRange"] = {
            "location": 9223372036854775807,
            "length": 0,
        }

        semantic, _ = batch_module.authority_payload(
            "inline-prediction", {"baseline": status}
        )

        self.assertEqual(
            semantic["phases"][0]["status"]["markedRange"],
            {"location": -1, "length": 0},
        )

    def test_ime_authority_payload_normalizes_volatile_descriptions(self):
        status = {key: f"value-{key}" for key in (
            "schema", "scenario", "language", "location", "decision",
            "canonical", "blocks", "selection", "affinity", "markedRange",
            "markedText", "markedSelection", "markedAttributeKeys",
            "structuralNewlineLocations", "checkingRanges", "mutationTrace",
            "eventTrace", "coordinateSpaceIdentity", "textEpoch",
            "selectionEpoch", "checkingEpoch", "layoutEpoch",
            "firstResponder",
        )}
        status.update({
            "blockIdentifiers": ["block"],
            "anchorIdentities": ["anchor"],
            "documentRevision": 3,
            "temporaryRenderingDescriptors": [{
                "range": {"location": 0, "length": 1},
                "attributeKeys": ["NSFont"],
                "valueDescriptions": ["<UICTFont: 0xvolatile>"],
            }],
            "candidateDescriptor": {
                "visible": True, "actionable": True,
                "labels": ["candidate"], "selectedLabel": "candidate",
                "geometry": {"x": 9.0, "y": 2.0,
                             "width": 3.0, "height": 4.0},
            },
            "keyboardState": {
                "visible": True, "primaryLanguage": "ja-JP",
                "enabledInputModeIdentifiers": [
                    "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
                    "unrelated-fallback",
                ],
            },
            "compositionGeometry": {
                "x": 1.0, "y": 2.0, "width": 3.0, "height": 4.0,
            },
        })
        lifecycle = {
            "schema": 1, "decision": "candidate-commit",
            "phases": [{"phase": "firstComposition", "status": status}],
        }

        semantic, geometry = batch_module.authority_payload("ime", lifecycle)

        normalized = semantic["phases"][0]["status"]
        self.assertEqual(
            normalized["temporaryRenderingDescriptors"],
            [{"range": {"location": 0, "length": 1},
              "attributeKeys": ["NSFont"]}],
        )
        self.assertEqual(
            normalized["keyboardState"]["requiredInputModes"],
            {"japaneseRomaji": True, "simplifiedChinesePinyin": False},
        )
        self.assertNotIn("geometry", normalized["candidateDescriptor"])
        self.assertEqual(
            normalized["candidateDescriptor"],
            {
                "visible": True,
                "actionable": True,
                "labels": [],
                "selectedLabel": "",
            },
        )
        self.assertEqual(
            geometry["phases"][0]["candidateGeometry"],
            {"y": 2.0, "width": 3.0, "height": 4.0},
        )

    def test_fresh_ime_identity_comes_from_lifecycle_status(self):
        lifecycle = {"phases": [{"phase": "baseline", "status": {
            "language": "japanese-romaji",
            "location": "before-boundary",
            "decision": "return-commit-then-undo",
        }}]}

        self.assertEqual(
            batch_module._ime_authority_row(lifecycle),
            "japanese-romaji-before-boundary-return-commit-then-undo",
        )

    def _corpus(self):
        observations = []
        for host in ("stock", "custom"):
            observations.append({
                "subsystem": "ime",
                "repetition": 1,
                "order": "stock-custom",
                "row": "japanese-romaji-before-boundary-candidate-commit",
                "host": host,
                "semantic": {
                    "canonical": "Alpha\nかな\nOmega",
                    "blocks": [
                        {"identity": "a", "text": "Alpha"},
                        {"identity": "b", "text": "かな"},
                        {"identity": "c", "text": "Omega"},
                    ],
                    "selection": {"location": 8, "length": 0},
                    "affinity": "forward",
                    "markedRange": {"location": -1, "length": 0},
                    "temporaryAnnotations": [{"kind": "spelling"}],
                    "checkingDescriptors": [{"range": [0, 5]}],
                    "candidateDescriptor": {
                        "visible": True,
                        "actionable": True,
                        "labels": ["かな", "仮名"],
                        "selectedLabel": "かな",
                    },
                    "predictionDescriptor": {"present": False},
                    "mutations": ["setMarkedText", "insertText"],
                    "events": ["selectionWillChange", "textDidChange"],
                    "epochs": {
                        "document": 4, "text": 3, "selection": 2,
                        "checking": 1, "layout": 5,
                    },
                    "keyboard": {
                        "primaryLanguage": "ja-JP",
                        "inputModeIdentifiers": ["ja-mode", "en-mode"],
                    },
                    "undoResult": {"canonical": "Alpha\nOmega"},
                    "structuralNewlineLocations": [5, 8],
                },
                "geometry": {
                    "caretRect": {"x": 10.0, "y": 20.0,
                                  "width": 2.0, "height": 18.0},
                    "selectionRects": [{"x": 10.0, "y": 20.0,
                                        "width": 2.0, "height": 18.0}],
                },
            })
        return {
            "schema": 1,
            "runtime": batch_module.RUNTIME,
            "udid": batch_module.PINNED_UDID,
            "observations": observations,
        }

    def test_authority_comparison_requires_every_semantic_field(self):
        paths = [
            ("canonical",), ("blocks",), ("selection",), ("affinity",),
            ("markedRange",), ("temporaryAnnotations",),
            ("checkingDescriptors",),
            ("candidateDescriptor", "visible"),
            ("candidateDescriptor", "actionable"),
            ("candidateDescriptor", "selectedLabel"),
            ("predictionDescriptor",), ("mutations",), ("events",),
            ("epochs", "document"), ("epochs", "text"),
            ("epochs", "selection"), ("epochs", "checking"),
            ("epochs", "layout"), ("keyboard", "primaryLanguage"),
            ("keyboard", "inputModeIdentifiers"), ("undoResult",),
            ("structuralNewlineLocations",),
        ]
        for path in paths:
            with self.subTest(path=path):
                fresh = self._corpus()
                batched = copy.deepcopy(fresh)
                target = batched["observations"][0]["semantic"]
                for component in path[:-1]:
                    target = target[component]
                target[path[-1]] = "mutated"
                with self.assertRaises(batch_module.AuthorityMismatch):
                    batch_module.compare_authority(batched, fresh)

    def test_unselected_native_candidate_inventory_is_diagnostic(self):
        fresh = self._corpus()
        batched = copy.deepcopy(fresh)
        batched["observations"][0]["semantic"]["candidateDescriptor"][
            "labels"
        ] = ["かな", "カナ", "仮名"]
        report = batch_module.compare_authority(batched, fresh)
        self.assertEqual(report["diagnosticDifferenceCount"], 1)
        self.assertEqual(
            report["diagnosticDifferences"][0]["field"],
            "semantic.candidateDescriptor.labels",
        )

        batched["observations"][0]["semantic"]["candidateDescriptor"][
            "selectedLabel"
        ] = "カナ"
        with self.assertRaises(batch_module.AuthorityMismatch):
            batch_module.compare_authority(batched, fresh)

    def test_authority_geometry_uses_only_one_point_tolerance(self):
        fresh = self._corpus()
        batched = copy.deepcopy(fresh)
        batched["observations"][0]["geometry"]["caretRect"]["x"] += 1.0
        report = batch_module.compare_authority(batched, fresh)
        self.assertEqual(report["hostObservations"], 2)
        self.assertEqual(report["comparisons"], 1)
        batched["observations"][0]["geometry"]["caretRect"]["x"] += 0.01
        with self.assertRaises(batch_module.AuthorityMismatch):
            batch_module.compare_authority(batched, fresh)

    def test_authority_rejects_identity_inventory_and_provenance_changes(self):
        for mutation in ("runtime", "udid", "missing", "duplicate", "extra"):
            with self.subTest(mutation=mutation):
                fresh = self._corpus()
                batched = copy.deepcopy(fresh)
                if mutation == "runtime":
                    batched["runtime"]["osBuild"] = "wrong"
                elif mutation == "udid":
                    batched["udid"] = "wrong"
                elif mutation == "missing":
                    batched["observations"].pop()
                elif mutation == "duplicate":
                    batched["observations"].append(copy.deepcopy(
                        batched["observations"][0]
                    ))
                else:
                    extra = copy.deepcopy(batched["observations"][0])
                    extra["row"] = "unexpected"
                    batched["observations"].append(extra)
                with self.assertRaises(batch_module.AuthorityMismatch):
                    batch_module.compare_authority(batched, fresh)

    def test_compare_authority_cli_is_strict_and_create_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            batched = root / "batched"
            fresh = root / "fresh"
            batched.mkdir()
            fresh.mkdir()
            corpus = self._corpus()
            for directory in (batched, fresh):
                (directory / "authority-observations.json").write_text(
                    json.dumps(corpus)
                )
            output = root / "equivalence.json"
            command = [
                sys.executable, str(SCRIPT), "compare-authority",
                "--batched", str(batched), "--fresh", str(fresh),
                "--output", str(output),
            ]
            compared = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(compared.returncode, 0, compared.stderr)
            self.assertEqual(json.loads(output.read_text())["result"], "Passed")
            refused = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(refused.returncode, 65)

            output.unlink()
            changed = copy.deepcopy(corpus)
            changed["observations"][0]["semantic"]["canonical"] = "wrong"
            (batched / "authority-observations.json").write_text(
                json.dumps(changed)
            )
            mismatch = subprocess.run(
                command, cwd=ROOT, text=True, capture_output=True, check=False
            )
            self.assertEqual(mismatch.returncode, 65)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
