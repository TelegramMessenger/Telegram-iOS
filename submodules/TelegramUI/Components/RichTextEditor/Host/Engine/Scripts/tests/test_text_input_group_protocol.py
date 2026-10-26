import dataclasses
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest


from Scripts import text_input_group_protocol as MODULE


TOKEN = "0123456789abcdef" * 4
OTHER_TOKEN = "fedcba9876543210" * 4
RESET_HASH = "a1" * 32
GROUP_ID = "autocorrection--group--interior-reject-undo"
BATCH_ID = "autocorrection--r1--stock-custom--interior-reject-undo"
NEXT_BATCH_ID = "autocorrection--r1--custom-stock--interior-reject-undo"
COMPLETED_ROW_ID = "interior-reject-precommit"
NEXT_ROW_ID = "interior-undo-space"
ROW_ID = COMPLETED_ROW_ID


def selected_group(state_sensitive=True, rows=None):
    rows = rows or [
        "interior-reject-precommit", "interior-undo-space",
    ]
    batches = []
    for repetition, order in (
            (1, "stock-custom"), (1, "custom-stock"),
            (2, "stock-custom"), (2, "custom-stock")):
        batch_id = (
            f"autocorrection--r{repetition}--{order}--"
            "interior-reject-undo"
        )
        hosts = [
            {"row": row, "host": host}
            for row in rows
            for host in order.split("-")
        ]
        batches.append({
            "id": batch_id,
            "subsystem": "autocorrection",
            "language": "en-US",
            "rows": list(rows),
            "hosts": hosts,
            "repetition": repetition,
            "order": order,
            "stateSensitive": state_sensitive,
            "resetPolicy": "erase-reset-learning-provision",
            "expectedHostObservations": len(hosts),
        })
    return {
        "id": "autocorrection--group--interior-reject-undo",
        "subsystem": "autocorrection",
        "language": "en-US",
        "rows": list(rows),
        "stateSensitive": state_sensitive,
        "resetPolicy": "erase-reset-learning-provision",
        "batches": batches,
    }


def inline_snapshot_group():
    row = "interior-accept"
    batches = []
    for repetition, order in (
            (1, "stock-custom"), (1, "custom-stock"),
            (2, "stock-custom"), (2, "custom-stock")):
        batch_id = f"inline-prediction--r{repetition}--{order}--{row}"
        batches.append({
            "id": batch_id,
            "subsystem": "inline-prediction",
            "language": "en-US",
            "rows": [row],
            "hosts": [
                {"row": row, "host": host}
                for host in order.split("-")
            ],
            "repetition": repetition,
            "order": order,
            "stateSensitive": True,
            "resetPolicy": "erase-reset-learning-provision",
            "expectedHostObservations": 2,
        })
    return {
        "id": f"inline-prediction--snapshot-row-v1--{row}",
        "subsystem": "inline-prediction",
        "language": "en-US",
        "rows": [row],
        "stateSensitive": True,
        "resetPolicy": "erase-reset-learning-provision",
        "batches": batches,
    }


def row_payload(**changes):
    value = {
        "schema": 2,
        "kind": "row",
        "token": TOKEN,
        "groupId": GROUP_ID,
        "sequenceIndex": 1,
        "batchId": BATCH_ID,
        "completedRowId": COMPLETED_ROW_ID,
        "nextRowId": NEXT_ROW_ID,
    }
    value.update(changes)
    return value


def host_payload(**changes):
    value = {
        "schema": 2,
        "kind": "host",
        "token": TOKEN,
        "groupId": GROUP_ID,
        "sequenceIndex": 1,
        "batchId": BATCH_ID,
        "rowId": ROW_ID,
        "completedHost": "stock",
        "nextHost": "custom",
    }
    value.update(changes)
    return value


def pass_payload(**changes):
    value = {
        "schema": 2,
        "kind": "pass",
        "token": TOKEN,
        "groupId": GROUP_ID,
        "sequenceIndex": 2,
        "completedBatchId": BATCH_ID,
        "nextBatchId": NEXT_BATCH_ID,
    }
    value.update(changes)
    return value


def expected_row_request():
    return MODULE.GroupBoundaryRequest(
        token=TOKEN,
        group_id=GROUP_ID,
        sequence_index=1,
        kind="row",
        batch_id=BATCH_ID,
        completed_row_id=COMPLETED_ROW_ID,
        next_row_id=NEXT_ROW_ID,
    )


def expected_host_request():
    return MODULE.GroupBoundaryRequest(
        token=TOKEN,
        group_id=GROUP_ID,
        sequence_index=1,
        kind="host",
        batch_id=BATCH_ID,
        row_id=ROW_ID,
        completed_host="stock",
        next_host="custom",
    )


def expected_pass_request():
    return MODULE.GroupBoundaryRequest(
        token=TOKEN,
        group_id=GROUP_ID,
        sequence_index=2,
        kind="pass",
        completed_batch_id=BATCH_ID,
        next_batch_id=NEXT_BATCH_ID,
    )


def observation_event(kind, event_index, observation_index=1, attempt=1,
                      **changes):
    identity = MODULE.observation_plan(inline_snapshot_group())[
        observation_index - 1]
    value = {
        "token": TOKEN,
        "group_id": "inline-prediction--snapshot-row-v1--interior-accept",
        "event_index": event_index,
        "observation_index": observation_index,
        "attempt": attempt,
        "kind": kind,
        "batch_id": identity["batchId"],
        "row_id": identity["rowId"],
        "host": identity["host"],
        "preceding_boundary": (
            identity["precedingBoundary"]
            if kind == "observation-started" else None
        ),
    }
    value.update(changes)
    return MODULE.ObservationEvent(**value)


class TextInputGroupProtocolTests(unittest.TestCase):
    def test_snapshot_row_observation_plan_has_eight_physical_hosts(self):
        group = inline_snapshot_group()
        plan = MODULE.observation_plan(group)
        self.assertEqual(len(plan), 8)
        self.assertEqual(plan[0], {
            "observationIndex": 1,
            "batchId": (
                "inline-prediction--r1--stock-custom--interior-accept"
            ),
            "rowId": "interior-accept",
            "host": "stock",
            "precedingBoundary": None,
        })
        self.assertEqual(plan[1]["host"], "custom")
        self.assertEqual(plan[1]["precedingBoundary"]["kind"], "host")
        self.assertEqual(plan[-1]["batchId"], (
            "inline-prediction--r2--custom-stock--interior-accept"
        ))
        self.assertEqual(plan[-1]["host"], "stock")
        boundaries = MODULE.boundary_plan(group)
        self.assertEqual(len(boundaries), 7)
        self.assertEqual(
            [item["kind"] for item in boundaries],
            ["host", "pass", "host", "pass", "host", "pass", "host"],
        )
        self.assertEqual(boundaries[0], {
            "kind": "host",
            "sequenceIndex": 1,
            "batchId": (
                "inline-prediction--r1--stock-custom--interior-accept"
            ),
            "rowId": "interior-accept",
            "completedHost": "stock",
            "nextHost": "custom",
        })

    def test_snapshot_row_rejects_legacy_and_noncanonical_inventory(self):
        fixtures = []

        missing = inline_snapshot_group()
        missing["batches"] = missing["batches"][:-1]
        fixtures.append(missing)

        duplicate = inline_snapshot_group()
        duplicate["batches"].append(dict(duplicate["batches"][0]))
        fixtures.append(duplicate)

        reordered = inline_snapshot_group()
        reordered["batches"][0], reordered["batches"][1] = (
            reordered["batches"][1], reordered["batches"][0])
        fixtures.append(reordered)

        wrong_suffix = inline_snapshot_group()
        wrong_suffix["batches"][0] = {
            **wrong_suffix["batches"][0],
            "id": "inline-prediction--r1--stock-custom--unknown-row",
        }
        fixtures.append(wrong_suffix)

        wrong_hosts = inline_snapshot_group()
        wrong_hosts["batches"][0] = {
            **wrong_hosts["batches"][0],
            "hosts": list(reversed(wrong_hosts["batches"][0]["hosts"])),
        }
        fixtures.append(wrong_hosts)

        for invalid_id in (
                "inline-prediction--group--interior-accept",
                "inline-prediction--group-r1--interior-accept",
                "inline-prediction--group-r1-stock-custom--interior-accept",
                "inline-prediction--snapshot-row-v2--interior-accept"):
            invalid_scope = inline_snapshot_group()
            invalid_scope["id"] = invalid_id
            fixtures.append(invalid_scope)

        for group in fixtures:
            with self.subTest(group=group):
                with self.assertRaises(MODULE.ProtocolError):
                    MODULE.boundary_plan(group)

    def test_observation_state_completes_and_retries_only_current_host(self):
        state = MODULE.ObservationProtocolState(
            inline_snapshot_group(), TOKEN)
        started = observation_event("observation-started", 1)
        state.advance(started)
        state.accept_restore(MODULE.ObservationRestoreResponse(
            request=started,
            reset_summary_sha256=RESET_HASH,
            result="ready",
        ))
        retry = observation_event("retry-required", 2, attempt=2)
        state.advance(retry)
        state.accept_restore(MODULE.ObservationRestoreResponse(
            request=retry,
            reset_summary_sha256=RESET_HASH,
            result="ready",
        ))
        state.advance(observation_event("offer-ready", 3, attempt=2))
        state.advance(observation_event(
            "observation-complete", 4, attempt=2))

        self.assertEqual(state.completed_observation_indexes, (1,))
        self.assertEqual(state.next_observation_index, 2)
        self.assertEqual(state.next_event_index, 5)

        second = observation_event(
            "observation-started", 5, observation_index=2)
        state.advance(second)
        state.accept_restore(MODULE.ObservationRestoreResponse(
            request=second,
            reset_summary_sha256=RESET_HASH,
            result="ready",
        ))
        state.advance(observation_event(
            "offer-ready", 6, observation_index=2))
        state.advance(observation_event(
            "observation-complete", 7, observation_index=2))
        self.assertEqual(state.completed_observation_indexes, (1, 2))

    def test_observation_state_rejects_phase_attempt_and_identity_drift(self):
        state = MODULE.ObservationProtocolState(
            inline_snapshot_group(), TOKEN)
        started = observation_event("observation-started", 1)
        state.advance(started)
        with self.assertRaisesRegex(MODULE.ProtocolError, "restore"):
            state.advance(observation_event("offer-ready", 2))

        state.accept_restore(MODULE.ObservationRestoreResponse(
            request=started,
            reset_summary_sha256=RESET_HASH,
            result="ready",
        ))
        invalid_events = [
            observation_event("retry-required", 2, attempt=3),
            observation_event(
                "retry-required", 2, attempt=2, host="custom"),
        ]
        for event in invalid_events:
            with self.subTest(event=event):
                with self.assertRaises(MODULE.ProtocolError):
                    state.advance(event)

        with self.assertRaisesRegex(MODULE.ProtocolError, "preceding"):
            observation_event(
                "retry-required", 2, attempt=2,
                preceding_boundary={"kind": "host"})

        state.advance(observation_event("offer-ready", 2))
        with self.assertRaisesRegex(MODULE.ProtocolError, "semantic"):
            state.advance(observation_event(
                "retry-required", 3, attempt=2))

    def test_observation_state_rejects_attempt_twenty_one(self):
        state = MODULE.ObservationProtocolState(
            inline_snapshot_group(), TOKEN)
        event_index = 1
        for attempt in range(1, 21):
            kind = "observation-started" if attempt == 1 else "retry-required"
            event = observation_event(
                kind, event_index, attempt=attempt)
            state.advance(event)
            state.accept_restore(MODULE.ObservationRestoreResponse(
                request=event,
                reset_summary_sha256=RESET_HASH,
                result="ready",
            ))
            event_index += 1
        with self.assertRaisesRegex(MODULE.ProtocolError, "20"):
            state.advance(observation_event(
                "retry-required", event_index, attempt=21))

    def test_observation_event_and_restore_response_schema_three_round_trip(self):
        started = observation_event("observation-started", 1)
        serialized = MODULE.observation_event_dict(started)
        self.assertEqual(serialized, {
            "schema": 3,
            "kind": "observation-started",
            "token": TOKEN,
            "groupId": (
                "inline-prediction--snapshot-row-v1--interior-accept"
            ),
            "eventIndex": 1,
            "observationIndex": 1,
            "attempt": 1,
            "batchId": (
                "inline-prediction--r1--stock-custom--interior-accept"
            ),
            "rowId": "interior-accept",
            "host": "stock",
            "precedingBoundary": None,
        })
        self.assertEqual(MODULE.observation_event_from_dict(serialized), started)
        response = MODULE.ObservationRestoreResponse(
            request=started,
            reset_summary_sha256=RESET_HASH,
            result="ready",
        )
        self.assertEqual(MODULE.observation_restore_response_dict(response), {
            **serialized,
            "kind": "restore-complete",
            "preparationKind": "observation-started",
            "resetSummarySHA256": RESET_HASH,
            "result": "ready",
        })

    def test_observation_cli_persists_state_and_writes_restore_response(self):
        group = inline_snapshot_group()
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            group_path = root / "group.json"
            state_path = root / "state.json"
            event_path = root / "event.json"
            response_path = root / "response.json"
            group_path.write_text(json.dumps(group))
            event_path.write_text(json.dumps(MODULE.observation_event_dict(
                observation_event("observation-started", 1))))

            plan = subprocess.run([
                sys.executable, str(pathlib.Path(MODULE.__file__)),
                "observation-plan", "--group", str(group_path),
            ], text=True, capture_output=True, check=False)
            self.assertEqual(plan.returncode, 0, plan.stderr)
            self.assertEqual(len(json.loads(plan.stdout)), 8)

            validated = subprocess.run([
                sys.executable, str(pathlib.Path(MODULE.__file__)),
                "validate-event", "--group", str(group_path),
                "--token", TOKEN, "--state", str(state_path),
                "--path", str(event_path),
            ], text=True, capture_output=True, check=False)
            self.assertEqual(validated.returncode, 0, validated.stderr)
            self.assertEqual(
                json.loads(state_path.read_text())["phase"],
                "awaiting-restore",
            )

            restored = subprocess.run([
                sys.executable, str(pathlib.Path(MODULE.__file__)),
                "write-restore-response", "--group", str(group_path),
                "--token", TOKEN, "--state", str(state_path),
                "--request", str(event_path),
                "--path", str(response_path),
                "--reset-summary-sha256", RESET_HASH,
            ], text=True, capture_output=True, check=False)
            self.assertEqual(restored.returncode, 0, restored.stderr)
            self.assertEqual(
                json.loads(response_path.read_text())["kind"],
                "restore-complete",
            )
            self.assertEqual(
                json.loads(state_path.read_text())["phase"], "restored")

            event_path.unlink()
            event_path.write_text(json.dumps(MODULE.observation_event_dict(
                observation_event("offer-ready", 2))))
            offered = subprocess.run([
                sys.executable, str(pathlib.Path(MODULE.__file__)),
                "validate-event", "--group", str(group_path),
                "--token", TOKEN, "--state", str(state_path),
                "--path", str(event_path),
            ], text=True, capture_output=True, check=False)
            self.assertEqual(offered.returncode, 0, offered.stderr)
            self.assertEqual(json.loads(state_path.read_text())["phase"],
                             "offer-ready")

    def test_plan_interleaves_host_row_and_pass_boundaries_in_one_sequence(self):
        plan = MODULE.boundary_plan(selected_group(rows=[
            "interior-reject-precommit", "interior-undo-space",
            "interior-undo-punctuation",
        ]))

        self.assertEqual(
            [(item["sequenceIndex"], item["kind"]) for item in plan],
            [(1, "host"), (2, "row"), (3, "host"), (4, "row"),
             (5, "host"), (6, "pass"),
             (7, "host"), (8, "row"), (9, "host"), (10, "row"),
             (11, "host"), (12, "pass"),
             (13, "host"), (14, "row"), (15, "host"), (16, "row"),
             (17, "host"), (18, "pass"),
             (19, "host"), (20, "row"), (21, "host"), (22, "row"),
             (23, "host")],
        )
        self.assertEqual(plan[0], {
            "kind": "host",
            "sequenceIndex": 1,
            "batchId": (
                "autocorrection--r1--stock-custom--interior-reject-undo"
            ),
            "rowId": "interior-reject-precommit",
            "completedHost": "stock",
            "nextHost": "custom",
        })
        self.assertEqual(plan[1], {
            "kind": "row",
            "sequenceIndex": 2,
            "batchId": (
                "autocorrection--r1--stock-custom--interior-reject-undo"
            ),
            "completedRowId": "interior-reject-precommit",
            "nextRowId": "interior-undo-space",
        })
        self.assertEqual(plan[5], {
            "kind": "pass",
            "sequenceIndex": 6,
            "completedBatchId": (
                "autocorrection--r1--stock-custom--interior-reject-undo"
            ),
            "nextBatchId": (
                "autocorrection--r1--custom-stock--interior-reject-undo"
            ),
        })

    def test_plan_uses_host_boundaries_for_single_state_sensitive_rows_only(self):
        ordinary = MODULE.boundary_plan(selected_group(state_sensitive=False))
        self.assertEqual([item["kind"] for item in ordinary],
                         ["pass", "pass", "pass"])
        single = MODULE.boundary_plan(
            selected_group(rows=["interior-undo-candidate"]))
        self.assertEqual([item["kind"] for item in single],
                         ["host", "pass", "host", "pass", "host", "pass",
                          "host"])
        self.assertEqual(single[-1]["completedHost"], "custom")
        self.assertEqual(single[-1]["nextHost"], "stock")

    def test_builds_and_loads_exact_host_row_and_pass_requests(self):
        plan = MODULE.boundary_plan(selected_group())
        self.assertEqual(
            MODULE.request_for_identity(TOKEN, GROUP_ID, plan[0]),
            expected_host_request(),
        )
        self.assertEqual(
            MODULE.request_for_identity(TOKEN, GROUP_ID, plan[1]),
            MODULE.GroupBoundaryRequest(
                token=TOKEN, group_id=GROUP_ID, sequence_index=2, kind="row",
                batch_id=BATCH_ID, completed_row_id=COMPLETED_ROW_ID,
                next_row_id=NEXT_ROW_ID),
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for name, payload, expected in (
                    ("host", host_payload(), expected_host_request()),
                    ("row", row_payload(), expected_row_request()),
                    ("pass", pass_payload(), expected_pass_request())):
                with self.subTest(kind=name):
                    path = root / f"{name}.json"
                    path.write_text(json.dumps(payload))
                    request = MODULE.load_request(path, expected)
                    self.assertEqual(request, expected)
                    with self.assertRaises(dataclasses.FrozenInstanceError):
                        request.sequence_index = 3

    def test_rejects_missing_extra_wrong_types_and_invalid_scalars(self):
        fixtures = []
        missing = row_payload()
        missing.pop("nextRowId")
        fixtures.append(missing)
        fixtures.append(row_payload(extra=True))
        fixtures.append(row_payload(schema=True))
        fixtures.append(row_payload(schema=1))
        fixtures.append(row_payload(kind="reset"))
        fixtures.append(row_payload(sequenceIndex=True))
        fixtures.append(row_payload(sequenceIndex=0))
        fixtures.append(row_payload(token="A" * 64))
        fixtures.append(row_payload(token="0" * 63))
        fixtures.append(row_payload(groupId="../group"))
        fixtures.append(row_payload(batchId="autocorrection--r1--bad"))
        fixtures.append(row_payload(completedRowId="bad/row"))
        fixtures.append(row_payload(nextRowId=COMPLETED_ROW_ID))
        fixtures.append(row_payload(completedBatchId=BATCH_ID))
        fixtures.append(host_payload(completedRowId=COMPLETED_ROW_ID))
        fixtures.append(host_payload(completedHost="custom", nextHost="stock"))
        fixtures.append(host_payload(nextHost="stock"))
        fixtures.append(pass_payload(batchId=BATCH_ID))
        fixtures.append(pass_payload(nextBatchId=BATCH_ID))
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for index, payload in enumerate(fixtures):
                with self.subTest(index=index, payload=payload):
                    path = root / f"request-{index}.json"
                    path.write_text(json.dumps(payload))
                    with self.assertRaises(MODULE.ProtocolError):
                        MODULE.load_request(path, None)

    def test_rejects_wrong_or_repeated_identity_against_expected_sequence(self):
        mutations = [
            {"token": OTHER_TOKEN},
            {"groupId": "autocorrection--group--other"},
            {"sequenceIndex": 2},
            {"batchId":
             "autocorrection--r1--stock-custom--other"},
            {"completedRowId": "other-row"},
            {"nextRowId": "other-row"},
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for index, changes in enumerate(mutations):
                with self.subTest(changes=changes):
                    path = root / f"request-{index}.json"
                    path.write_text(json.dumps(row_payload(**changes)))
                    with self.assertRaises(MODULE.ProtocolError):
                        MODULE.load_request(path, expected_row_request())

        for index, changes in enumerate((
                {"rowId": "other-row"},
                {"completedHost": "custom", "nextHost": "stock"},
                {"sequenceIndex": 2})):
            with self.subTest(host_changes=changes), tempfile.TemporaryDirectory() as temporary:
                path = pathlib.Path(temporary) / f"host-{index}.json"
                path.write_text(json.dumps(host_payload(**changes)))
                with self.assertRaises(MODULE.ProtocolError):
                    MODULE.load_request(path, expected_host_request())

    def test_rejects_nonregular_symlink_and_malformed_request_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            directory = root / "directory"
            directory.mkdir()
            target = root / "target.json"
            target.write_text(json.dumps(row_payload()))
            symlink = root / "request.json"
            symlink.symlink_to(target)
            malformed = root / "malformed.json"
            malformed.write_text("{")
            missing = root / "missing.json"
            for path in [directory, symlink, malformed, missing]:
                with self.subTest(path=path):
                    with self.assertRaises(MODULE.ProtocolError):
                        MODULE.load_request(path, expected_row_request())

    def test_hash_token_is_lowercase_sha256_and_rejects_invalid_token(self):
        self.assertEqual(
            MODULE.hash_token(TOKEN),
            "a8ae6e6ee929abea3afcfc5258c8ccd6f85273e0d4626d26c7279f3250f77c8e",
        )
        for token in ["", "A" * 64, "0" * 63, 7, None]:
            with self.subTest(token=token):
                with self.assertRaises(MODULE.ProtocolError):
                    MODULE.hash_token(token)

    def test_writes_exact_response_atomically_and_refuses_existing_path(self):
        response = MODULE.GroupBoundaryResponse(
            request=expected_row_request(),
            reset_summary_sha256=RESET_HASH,
            result="ready",
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            path = root / "response.json"

            MODULE.write_response(path, response)

            self.assertEqual(json.loads(path.read_text()), {
                **row_payload(),
                "resetSummarySHA256": RESET_HASH,
                "result": "ready",
            })
            self.assertEqual(list(root.glob("*.partial-*")), [])
            with self.assertRaises(MODULE.ProtocolError):
                MODULE.write_response(path, response)

    def test_rejects_invalid_response_hash_result_path_and_symlink(self):
        request = expected_row_request()
        for reset_hash, result in [
            ("b" * 63, "ready"),
            ("B" * 64, "ready"),
            (RESET_HASH, "failed"),
        ]:
            with self.subTest(reset_hash=reset_hash, result=result):
                with self.assertRaises(MODULE.ProtocolError):
                    MODULE.GroupBoundaryResponse(
                        request=request,
                        reset_summary_sha256=reset_hash,
                        result=result,
                    )
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            target = root / "target"
            target.write_text("preserve")
            symlink = root / "response.json"
            symlink.symlink_to(target)
            valid = MODULE.GroupBoundaryResponse(
                request=request,
                reset_summary_sha256=RESET_HASH,
                result="ready",
            )
            with self.assertRaises(MODULE.ProtocolError):
                MODULE.write_response(symlink, valid)
            self.assertEqual(target.read_text(), "preserve")

    def test_cli_plans_validates_and_writes_compact_json_and_rejects_mixed_args(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            group_path = root / "group.json"
            group_path.write_text(json.dumps(selected_group()))
            planned = subprocess.run(
                ["python3", str(MODULE.__file__), "plan",
                 "--group", str(group_path)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(planned.returncode, 0, planned.stderr)
            self.assertEqual(json.loads(planned.stdout),
                             list(MODULE.boundary_plan(selected_group())))
            self.assertNotIn(TOKEN, planned.stdout)

            request_path = root / "request.json"
            request_path.write_text(json.dumps(row_payload()))
            common = [
                "--token", TOKEN,
                "--group-id", GROUP_ID,
                "--sequence-index", "1",
                "--kind", "row",
                "--batch-id", BATCH_ID,
                "--completed-row-id", COMPLETED_ROW_ID,
                "--next-row-id", NEXT_ROW_ID,
            ]
            validated = subprocess.run(
                ["python3", str(MODULE.__file__), "validate-request",
                 "--path", str(request_path), *common],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(validated.returncode, 0, validated.stderr)
            self.assertEqual(json.loads(validated.stdout), row_payload())
            self.assertNotIn("\n  ", validated.stdout)

            pass_path = root / "pass-request.json"
            pass_path.write_text(json.dumps(pass_payload()))
            pass_common = [
                "--token", TOKEN,
                "--group-id", GROUP_ID,
                "--sequence-index", "2",
                "--kind", "pass",
                "--completed-batch-id", BATCH_ID,
                "--next-batch-id", NEXT_BATCH_ID,
            ]
            pass_validated = subprocess.run(
                ["python3", str(MODULE.__file__), "validate-request",
                 "--path", str(pass_path), *pass_common],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(pass_validated.returncode, 0,
                             pass_validated.stderr)
            self.assertEqual(json.loads(pass_validated.stdout), pass_payload())

            response_path = root / "response.json"
            written = subprocess.run(
                ["python3", str(MODULE.__file__), "write-response",
                 "--path", str(response_path), *common,
                 "--reset-summary-sha256", RESET_HASH],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(written.returncode, 0, written.stderr)
            self.assertEqual(json.loads(written.stdout), {
                **row_payload(),
                "resetSummarySHA256": RESET_HASH,
                "result": "ready",
            })

            invalid_path = root / "invalid-response.json"
            invalid = subprocess.run(
                ["python3", str(MODULE.__file__), "write-response",
                 "--path", str(invalid_path), *common,
                 "--reset-summary-sha256", "bad"],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(invalid.returncode, 65)
            self.assertFalse(invalid_path.exists())

            mixed = subprocess.run(
                ["python3", str(MODULE.__file__), "validate-request",
                 "--path", str(request_path), *common,
                 "--completed-batch-id", BATCH_ID,
                 "--next-batch-id", NEXT_BATCH_ID],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(mixed.returncode, 65)
            self.assertIn("row request contains pass fields", mixed.stderr)


if __name__ == "__main__":
    unittest.main()
