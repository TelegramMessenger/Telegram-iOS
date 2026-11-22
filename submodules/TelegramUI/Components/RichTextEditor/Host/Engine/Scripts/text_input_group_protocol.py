#!/usr/bin/env python3

import argparse
import dataclasses
import hashlib
import json
import os
import pathlib
import re
import sys


HEX_64 = re.compile(r"^[0-9a-f]{64}$")
GROUP_ID = re.compile(
    r"^(?:(?:ime|autocorrection)--group|"
    r"inline-prediction--snapshot-row-v1)--"
    r"[a-z0-9]+(?:-[a-z0-9]+)*$"
)
BATCH_ID = re.compile(
    r"^(?:ime|autocorrection|inline-prediction)--r[12]--"
    r"(?:stock-custom|custom-stock)--[a-z0-9]+(?:-[a-z0-9]+)*$"
)
ROW_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
COMMON_REQUEST_KEYS = {
    "schema", "kind", "token", "groupId", "sequenceIndex",
}
HOST_REQUEST_KEYS = COMMON_REQUEST_KEYS | {
    "batchId", "rowId", "completedHost", "nextHost",
}
ROW_REQUEST_KEYS = COMMON_REQUEST_KEYS | {
    "batchId", "completedRowId", "nextRowId",
}
PASS_REQUEST_KEYS = COMMON_REQUEST_KEYS | {
    "completedBatchId", "nextBatchId",
}


class ProtocolError(ValueError):
    pass


def group_identity(group_id):
    if not isinstance(group_id, str) or GROUP_ID.fullmatch(group_id) is None:
        raise ProtocolError("invalid group identifier")
    subsystem, scope, suffix = group_id.split("--", 2)
    if ROW_ID.fullmatch(suffix) is None:
        raise ProtocolError("invalid group row suffix")
    repetition = None
    order = None
    if subsystem == "inline-prediction":
        if scope != "snapshot-row-v1":
            raise ProtocolError("invalid group identifier")
    return subsystem, repetition, order, suffix


def boundary_plan(group):
    if not isinstance(group, dict):
        raise ProtocolError("group must be an object")
    group_id = group.get("id")
    batches = group.get("batches")
    try:
        subsystem, repetition, order, suffix = group_identity(group_id)
    except ProtocolError:
        raise ProtocolError("group identity or batch inventory is invalid")
    expected_batch_ids = [
        f"{subsystem}--r{item}--{item_order}--{suffix}"
        for item in (1, 2)
        for item_order in ("stock-custom", "custom-stock")
    ]
    if (not isinstance(batches, list) or
            [batch.get("id") if isinstance(batch, dict) else None
             for batch in batches] != expected_batch_ids):
        raise ProtocolError("group identity or batch inventory is invalid")
    result = []
    sequence_index = 1
    for batch_index, batch in enumerate(batches):
        if not isinstance(batch, dict):
            raise ProtocolError("group batch must be an object")
        batch_id = batch.get("id")
        rows = batch.get("rows")
        hosts = batch.get("hosts")
        state_sensitive = batch.get("stateSensitive")
        if (not isinstance(batch_id, str) or
                BATCH_ID.fullmatch(batch_id) is None or
                not isinstance(rows, list) or not rows or
                any(not isinstance(row, str) or not row for row in rows) or
                not isinstance(hosts, list) or
                type(state_sensitive) is not bool):
            raise ProtocolError("group batch boundary fields are invalid")
        order = batch_id.split("--", 3)[2].split("-")
        expected_hosts = [
            {"row": row, "host": host}
            for row in rows for host in order
        ]
        if hosts != expected_hosts:
            raise ProtocolError("group batch host sequence is invalid")
        if state_sensitive:
            for row_index, row in enumerate(rows):
                result.append({
                    "kind": "host",
                    "sequenceIndex": sequence_index,
                    "batchId": batch_id,
                    "rowId": row,
                    "completedHost": order[0],
                    "nextHost": order[1],
                })
                sequence_index += 1
                if row_index + 1 == len(rows):
                    continue
                result.append({
                    "kind": "row",
                    "sequenceIndex": sequence_index,
                    "batchId": batch_id,
                    "completedRowId": rows[row_index],
                    "nextRowId": rows[row_index + 1],
                })
                sequence_index += 1
        if batch_index + 1 < len(batches):
            next_batch = batches[batch_index + 1]
            next_batch_id = (
                next_batch.get("id") if isinstance(next_batch, dict) else None
            )
            if (not isinstance(next_batch_id, str) or
                    BATCH_ID.fullmatch(next_batch_id) is None):
                raise ProtocolError("next group batch identifier is invalid")
            result.append({
                "kind": "pass",
                "sequenceIndex": sequence_index,
                "completedBatchId": batch_id,
                "nextBatchId": next_batch_id,
            })
            sequence_index += 1
    return tuple(result)


def observation_plan(group):
    try:
        subsystem, _, _, _ = group_identity(group.get("id"))
    except (AttributeError, ProtocolError):
        raise ProtocolError("group identity or batch inventory is invalid")
    if subsystem != "inline-prediction":
        raise ProtocolError("observation plan requires snapshot inline group")
    boundaries = boundary_plan(group)
    observations = []
    for batch in group["batches"]:
        for observation in batch["hosts"]:
            observations.append({
                "observationIndex": len(observations) + 1,
                "batchId": batch["id"],
                "rowId": observation["row"],
                "host": observation["host"],
                "precedingBoundary": (
                    None if not observations
                    else dict(boundaries[len(observations) - 1])
                ),
            })
    if len(observations) != 8 or len(boundaries) != 7:
        raise ProtocolError("snapshot observation inventory is invalid")
    return tuple(observations)


@dataclasses.dataclass(frozen=True)
class ObservationEvent:
    token: str
    group_id: str
    event_index: int
    observation_index: int
    attempt: int
    kind: str
    batch_id: str
    row_id: str
    host: str
    preceding_boundary: dict = None

    def __post_init__(self):
        _require_hex(self.token, "token")
        subsystem, _, _, _ = group_identity(self.group_id)
        if subsystem != "inline-prediction":
            raise ProtocolError("observation event requires snapshot inline group")
        for value, label in [
            (self.event_index, "event index"),
            (self.observation_index, "observation index"),
            (self.attempt, "attempt"),
        ]:
            if (isinstance(value, bool) or not isinstance(value, int) or
                    value <= 0):
                raise ProtocolError(f"{label} must be a positive integer")
        if self.observation_index > 8:
            raise ProtocolError("observation index must not exceed 8")
        if self.attempt > 20:
            raise ProtocolError("observation attempt must not exceed 20")
        if self.kind not in {
                "observation-started", "retry-required", "offer-ready",
                "observation-complete"}:
            raise ProtocolError("observation event kind is invalid")
        if self.kind == "observation-started" and self.attempt != 1:
            raise ProtocolError("observation-started attempt must equal 1")
        if self.kind == "retry-required" and self.attempt <= 1:
            raise ProtocolError("retry-required attempt must exceed 1")
        if (not isinstance(self.batch_id, str) or
                BATCH_ID.fullmatch(self.batch_id) is None or
                not isinstance(self.row_id, str) or
                ROW_ID.fullmatch(self.row_id) is None or
                self.host not in {"stock", "custom"}):
            raise ProtocolError("observation event identity is invalid")
        if (self.kind != "observation-started" and
                self.preceding_boundary is not None):
            raise ProtocolError(
                "only observation-started may carry preceding boundary")
        if (self.preceding_boundary is not None and
                not isinstance(self.preceding_boundary, dict)):
            raise ProtocolError("preceding boundary must be an object or null")


@dataclasses.dataclass(frozen=True)
class ObservationRestoreResponse:
    request: ObservationEvent
    reset_summary_sha256: str
    result: str

    def __post_init__(self):
        if (not isinstance(self.request, ObservationEvent) or
                self.request.kind not in {
                    "observation-started", "retry-required"}):
            raise ProtocolError("restore response request is invalid")
        _require_hex(self.reset_summary_sha256, "reset summary SHA-256")
        if self.result != "ready":
            raise ProtocolError("restore response result must equal ready")


class ObservationProtocolState:
    def __init__(self, group, token):
        _require_hex(token, "token")
        self._group_id = group.get("id") if isinstance(group, dict) else None
        self._plan = observation_plan(group)
        self._token = token
        self._next_observation_index = 1
        self._next_event_index = 1
        self._attempt = 1
        self._phase = "need-preparation"
        self._preparation = None
        self._completed = []

    @property
    def completed_observation_indexes(self):
        return tuple(self._completed)

    @property
    def next_observation_index(self):
        return self._next_observation_index

    @property
    def next_event_index(self):
        return self._next_event_index

    def _validate_common(self, event):
        if not isinstance(event, ObservationEvent):
            raise ProtocolError("observation state requires an event")
        if (event.token != self._token or event.group_id != self._group_id or
                event.event_index != self._next_event_index or
                event.observation_index != self._next_observation_index or
                self._next_observation_index > len(self._plan)):
            raise ProtocolError("observation event sequence differs")
        identity = self._plan[self._next_observation_index - 1]
        if (event.batch_id != identity["batchId"] or
                event.row_id != identity["rowId"] or
                event.host != identity["host"]):
            raise ProtocolError("observation event identity differs")
        return identity

    def advance(self, event):
        identity = self._validate_common(event)
        if self._phase == "need-preparation":
            if (event.kind != "observation-started" or event.attempt != 1 or
                    event.preceding_boundary != identity["precedingBoundary"]):
                raise ProtocolError("observation preparation sequence differs")
            self._attempt = 1
            self._preparation = event
            self._phase = "awaiting-restore"
        elif self._phase == "awaiting-restore":
            raise ProtocolError("restore-complete response is required")
        elif self._phase == "restored":
            if event.kind == "retry-required":
                if event.attempt != self._attempt + 1:
                    raise ProtocolError("readiness retry attempt differs")
                if event.attempt > 20:
                    raise ProtocolError("readiness retry exceeds 20 attempts")
                self._attempt = event.attempt
                self._preparation = event
                self._phase = "awaiting-restore"
            elif event.kind == "offer-ready":
                if event.attempt != self._attempt:
                    raise ProtocolError("offer-ready attempt differs")
                self._phase = "offer-ready"
            else:
                raise ProtocolError(
                    "restored observation requires offer-ready or retry")
        elif self._phase == "offer-ready":
            if event.kind == "retry-required":
                raise ProtocolError(
                    "retry after offer-ready would hide a semantic failure")
            if (event.kind != "observation-complete" or
                    event.attempt != self._attempt):
                raise ProtocolError("observation completion sequence differs")
            self._completed.append(self._next_observation_index)
            self._next_observation_index += 1
            self._attempt = 1
            self._preparation = None
            self._phase = (
                "complete" if self._next_observation_index > len(self._plan)
                else "need-preparation"
            )
        else:
            raise ProtocolError("observation protocol is already complete")
        self._next_event_index += 1

    def accept_restore(self, response):
        if self._phase != "awaiting-restore":
            raise ProtocolError("restore response is not currently expected")
        if (not isinstance(response, ObservationRestoreResponse) or
                response.request != self._preparation):
            raise ProtocolError("restore response differs from preparation")
        self._phase = "restored"

    def to_dict(self):
        return {
            "schema": 1,
            "token": self._token,
            "groupId": self._group_id,
            "nextObservationIndex": self._next_observation_index,
            "nextEventIndex": self._next_event_index,
            "attempt": self._attempt,
            "phase": self._phase,
            "preparation": (
                None if self._preparation is None
                else observation_event_dict(self._preparation)
            ),
            "completedObservationIndexes": list(self._completed),
        }

    @classmethod
    def from_dict(cls, group, token, value):
        expected_keys = {
            "schema", "token", "groupId", "nextObservationIndex",
            "nextEventIndex", "attempt", "phase", "preparation",
            "completedObservationIndexes",
        }
        if (not isinstance(value, dict) or set(value) != expected_keys or
                value.get("schema") != 1 or value.get("token") != token or
                value.get("groupId") != group.get("id")):
            raise ProtocolError("observation state identity is invalid")
        state = cls(group, token)
        next_observation = value["nextObservationIndex"]
        next_event = value["nextEventIndex"]
        attempt = value["attempt"]
        completed = value["completedObservationIndexes"]
        phase = value["phase"]
        if (isinstance(next_observation, bool) or
                not isinstance(next_observation, int) or
                next_observation < 1 or next_observation > 9 or
                isinstance(next_event, bool) or
                not isinstance(next_event, int) or next_event < 1 or
                isinstance(attempt, bool) or not isinstance(attempt, int) or
                attempt < 1 or attempt > 20 or
                not isinstance(completed, list) or
                completed != list(range(1, next_observation)) or
                phase not in {
                    "need-preparation", "awaiting-restore", "restored",
                    "offer-ready", "complete"}):
            raise ProtocolError("observation state fields are invalid")
        preparation_value = value["preparation"]
        preparation = (
            None if preparation_value is None
            else observation_event_from_dict(preparation_value)
        )
        if phase in {"awaiting-restore", "restored", "offer-ready"}:
            if (preparation is None or
                    preparation.observation_index != next_observation or
                    preparation.attempt != attempt or
                    preparation.token != token or
                    preparation.group_id != group["id"]):
                raise ProtocolError("observation state preparation differs")
        elif preparation is not None:
            raise ProtocolError("observation state has unexpected preparation")
        if ((phase == "complete") != (next_observation == 9) or
                (phase == "need-preparation" and attempt != 1)):
            raise ProtocolError("observation state phase differs")
        state._next_observation_index = next_observation
        state._next_event_index = next_event
        state._attempt = attempt
        state._phase = phase
        state._preparation = preparation
        state._completed = list(completed)
        return state


OBSERVATION_EVENT_KEYS = {
    "schema", "kind", "token", "groupId", "eventIndex",
    "observationIndex", "attempt", "batchId", "rowId", "host",
    "precedingBoundary",
}


def observation_event_dict(event):
    if not isinstance(event, ObservationEvent):
        raise ProtocolError("observation event has the wrong type")
    return {
        "schema": 3,
        "kind": event.kind,
        "token": event.token,
        "groupId": event.group_id,
        "eventIndex": event.event_index,
        "observationIndex": event.observation_index,
        "attempt": event.attempt,
        "batchId": event.batch_id,
        "rowId": event.row_id,
        "host": event.host,
        "precedingBoundary": event.preceding_boundary,
    }


def observation_event_from_dict(value):
    if (not isinstance(value, dict) or set(value) != OBSERVATION_EVENT_KEYS or
            value.get("schema") != 3):
        raise ProtocolError("observation event keys or schema differ")
    return ObservationEvent(
        token=value["token"],
        group_id=value["groupId"],
        event_index=value["eventIndex"],
        observation_index=value["observationIndex"],
        attempt=value["attempt"],
        kind=value["kind"],
        batch_id=value["batchId"],
        row_id=value["rowId"],
        host=value["host"],
        preceding_boundary=value["precedingBoundary"],
    )


def observation_restore_response_dict(response):
    if not isinstance(response, ObservationRestoreResponse):
        raise ProtocolError("observation restore response has the wrong type")
    return {
        **observation_event_dict(response.request),
        "kind": "restore-complete",
        "preparationKind": response.request.kind,
        "resetSummarySHA256": response.reset_summary_sha256,
        "result": response.result,
    }


def _require_hex(value, label):
    if not isinstance(value, str) or HEX_64.fullmatch(value) is None:
        raise ProtocolError(f"{label} must be 64 lowercase hexadecimal digits")


def _validate_group_and_sequence(token, group_id, sequence_index):
    _require_hex(token, "token")
    group_identity(group_id)
    if (isinstance(sequence_index, bool) or
            not isinstance(sequence_index, int) or sequence_index <= 0):
        raise ProtocolError("sequence index must be a positive integer")


def _validate_batch_for_group(batch_id, group_id, label):
    if not isinstance(batch_id, str) or BATCH_ID.fullmatch(batch_id) is None:
        raise ProtocolError(f"invalid {label} identifier")
    group_subsystem, repetition, order, group_suffix = group_identity(
        group_id)
    batch_parts = batch_id.split("--", 3)
    if (batch_parts[0] != group_subsystem or
            batch_parts[3] != group_suffix or
            (repetition is not None and
             (batch_parts[1] != f"r{repetition}" or
              batch_parts[2] != order))):
        raise ProtocolError(f"{label} identifier differs from group")


def _validate_row_fields(group_id, batch_id, completed_row_id, next_row_id):
    _validate_batch_for_group(batch_id, group_id, "batch")
    for value, label in [
        (completed_row_id, "completed row"),
        (next_row_id, "next row"),
    ]:
        if not isinstance(value, str) or ROW_ID.fullmatch(value) is None:
            raise ProtocolError(f"invalid {label} identifier")
    if completed_row_id == next_row_id:
        raise ProtocolError("completed and next row identifiers must differ")


def _validate_host_fields(
        group_id, batch_id, row_id, completed_host, next_host):
    _validate_batch_for_group(batch_id, group_id, "batch")
    if not isinstance(row_id, str) or ROW_ID.fullmatch(row_id) is None:
        raise ProtocolError("invalid row identifier")
    expected_hosts = batch_id.split("--", 3)[2].split("-")
    if [completed_host, next_host] != expected_hosts:
        raise ProtocolError("host transition differs from batch order")


def _validate_pass_fields(group_id, completed_batch_id, next_batch_id):
    for value, label in [
        (completed_batch_id, "completed batch"),
        (next_batch_id, "next batch"),
    ]:
        if not isinstance(value, str) or BATCH_ID.fullmatch(value) is None:
            raise ProtocolError(f"invalid {label} identifier")
        _validate_batch_for_group(value, group_id, label)
    if completed_batch_id == next_batch_id:
        raise ProtocolError("completed and next batch identifiers must differ")


@dataclasses.dataclass(frozen=True)
class GroupBoundaryRequest:
    token: str
    group_id: str
    sequence_index: int
    kind: str
    batch_id: str = None
    row_id: str = None
    completed_host: str = None
    next_host: str = None
    completed_row_id: str = None
    next_row_id: str = None
    completed_batch_id: str = None
    next_batch_id: str = None

    def __post_init__(self):
        _validate_group_and_sequence(
            self.token, self.group_id, self.sequence_index)
        host_fields = (
            self.batch_id, self.row_id, self.completed_host, self.next_host)
        row_fields = (self.batch_id, self.completed_row_id, self.next_row_id)
        pass_fields = (self.completed_batch_id, self.next_batch_id)
        if self.kind == "host":
            if any(value is not None for value in (
                    self.completed_row_id, self.next_row_id,
                    *pass_fields)):
                raise ProtocolError("host request contains row or pass fields")
            _validate_host_fields(self.group_id, *host_fields)
        elif self.kind == "row":
            if any(value is not None for value in (
                    self.row_id, self.completed_host, self.next_host,
                    *pass_fields)):
                raise ProtocolError("row request contains pass fields")
            _validate_row_fields(self.group_id, *row_fields)
        elif self.kind == "pass":
            if any(value is not None for value in (
                    *host_fields, self.completed_row_id, self.next_row_id)):
                raise ProtocolError("pass request contains row fields")
            _validate_pass_fields(self.group_id, *pass_fields)
        else:
            raise ProtocolError("request kind must equal host, row, or pass")


@dataclasses.dataclass(frozen=True)
class GroupBoundaryResponse:
    request: GroupBoundaryRequest
    reset_summary_sha256: str
    result: str

    def __post_init__(self):
        if not isinstance(self.request, GroupBoundaryRequest):
            raise ProtocolError("response request has the wrong type")
        _require_hex(self.reset_summary_sha256, "reset summary SHA-256")
        if self.result != "ready":
            raise ProtocolError("response result must equal ready")


def request_dict(request):
    if not isinstance(request, GroupBoundaryRequest):
        raise ProtocolError("request has the wrong type")
    value = {
        "schema": 2,
        "kind": request.kind,
        "token": request.token,
        "groupId": request.group_id,
        "sequenceIndex": request.sequence_index,
    }
    if request.kind == "host":
        value.update({
            "batchId": request.batch_id,
            "rowId": request.row_id,
            "completedHost": request.completed_host,
            "nextHost": request.next_host,
        })
    elif request.kind == "row":
        value.update({
            "batchId": request.batch_id,
            "completedRowId": request.completed_row_id,
            "nextRowId": request.next_row_id,
        })
    else:
        value.update({
            "completedBatchId": request.completed_batch_id,
            "nextBatchId": request.next_batch_id,
        })
    return value


def response_dict(response):
    if not isinstance(response, GroupBoundaryResponse):
        raise ProtocolError("response has the wrong type")
    return {
        **request_dict(response.request),
        "resetSummarySHA256": response.reset_summary_sha256,
        "result": response.result,
    }


def _request_from_dict(value):
    if not isinstance(value, dict):
        raise ProtocolError("request must be an object")
    if isinstance(value.get("schema"), bool) or value.get("schema") != 2:
        raise ProtocolError("request schema must be integer 2")
    kind = value.get("kind")
    expected_keys = {
        "host": HOST_REQUEST_KEYS,
        "row": ROW_REQUEST_KEYS,
        "pass": PASS_REQUEST_KEYS,
    }.get(kind)
    if expected_keys is None or set(value) != expected_keys:
        raise ProtocolError("request keys differ from schema 2 kind")
    common = {
        "token": value["token"],
        "group_id": value["groupId"],
        "sequence_index": value["sequenceIndex"],
        "kind": kind,
    }
    if kind == "host":
        return GroupBoundaryRequest(
            **common,
            batch_id=value["batchId"],
            row_id=value["rowId"],
            completed_host=value["completedHost"],
            next_host=value["nextHost"],
        )
    if kind == "row":
        return GroupBoundaryRequest(
            **common,
            batch_id=value["batchId"],
            completed_row_id=value["completedRowId"],
            next_row_id=value["nextRowId"],
        )
    return GroupBoundaryRequest(
        **common,
        completed_batch_id=value["completedBatchId"],
        next_batch_id=value["nextBatchId"],
    )


def request_for_identity(token, group_id, identity):
    if not isinstance(identity, dict):
        raise ProtocolError("boundary identity must be an object")
    kind = identity.get("kind")
    common = {
        "token": token,
        "group_id": group_id,
        "sequence_index": identity.get("sequenceIndex"),
        "kind": kind,
    }
    if kind == "host" and set(identity) == {
            "kind", "sequenceIndex", "batchId", "rowId",
            "completedHost", "nextHost"}:
        return GroupBoundaryRequest(
            **common,
            batch_id=identity["batchId"],
            row_id=identity["rowId"],
            completed_host=identity["completedHost"],
            next_host=identity["nextHost"],
        )
    if kind == "row" and set(identity) == {
            "kind", "sequenceIndex", "batchId",
            "completedRowId", "nextRowId"}:
        return GroupBoundaryRequest(
            **common,
            batch_id=identity["batchId"],
            completed_row_id=identity["completedRowId"],
            next_row_id=identity["nextRowId"],
        )
    if kind == "pass" and set(identity) == {
            "kind", "sequenceIndex", "completedBatchId", "nextBatchId"}:
        return GroupBoundaryRequest(
            **common,
            completed_batch_id=identity["completedBatchId"],
            next_batch_id=identity["nextBatchId"],
        )
    raise ProtocolError("boundary identity keys differ from kind")


def load_request(path, expected):
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file():
        raise ProtocolError(f"request is not a regular file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProtocolError(f"cannot load boundary request: {error}") from error
    request = _request_from_dict(value)
    if expected is not None:
        if not isinstance(expected, GroupBoundaryRequest):
            raise ProtocolError("expected request has the wrong type")
        if request != expected:
            raise ProtocolError("boundary request differs from expected sequence")
    return request


def load_observation_event(path):
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file():
        raise ProtocolError(f"observation event is not a regular file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProtocolError(f"cannot load observation event: {error}")
    return observation_event_from_dict(value)


def write_response(path, response):
    path = pathlib.Path(path)
    if path.exists() or path.is_symlink():
        raise ProtocolError(f"refusing existing response: {path}")
    if path.parent.is_symlink() or not path.parent.is_dir():
        raise ProtocolError("response parent is not a regular directory")
    value = response_dict(response)
    temporary = path.with_name(f".{path.name}.partial-{os.getpid()}")
    if temporary.exists() or temporary.is_symlink():
        raise ProtocolError(f"refusing existing response staging path: {temporary}")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
        temporary.replace(path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def write_observation_restore_response(path, response):
    path = pathlib.Path(path)
    if path.exists() or path.is_symlink():
        raise ProtocolError(f"refusing existing restore response: {path}")
    if path.parent.is_symlink() or not path.parent.is_dir():
        raise ProtocolError("restore response parent is not a regular directory")
    temporary = path.with_name(f".{path.name}.partial-{os.getpid()}")
    if temporary.exists() or temporary.is_symlink():
        raise ProtocolError(
            f"refusing existing restore response staging path: {temporary}")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(
                observation_restore_response_dict(response), stream,
                indent=2, sort_keys=True)
            stream.write("\n")
        temporary.replace(path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def _load_observation_state(path, group, token):
    path = pathlib.Path(path)
    if not path.exists() and not path.is_symlink():
        return ObservationProtocolState(group, token)
    if path.is_symlink() or not path.is_file():
        raise ProtocolError("observation state path is invalid")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProtocolError(f"cannot load observation state: {error}")
    return ObservationProtocolState.from_dict(group, token, value)


def _write_observation_state(path, state):
    path = pathlib.Path(path)
    if path.is_symlink() or path.parent.is_symlink() or not path.parent.is_dir():
        raise ProtocolError("observation state path is invalid")
    temporary = path.with_name(f".{path.name}.partial-{os.getpid()}")
    if temporary.exists() or temporary.is_symlink():
        raise ProtocolError("observation state staging path already exists")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(state.to_dict(), stream, indent=2, sort_keys=True)
            stream.write("\n")
        temporary.replace(path)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def hash_token(token):
    _require_hex(token, "token")
    return hashlib.sha256(token.encode("ascii")).hexdigest()


def _add_request_arguments(parser):
    parser.add_argument("--token", required=True)
    parser.add_argument("--group-id", required=True)
    parser.add_argument("--sequence-index", required=True, type=int)
    parser.add_argument(
        "--kind", required=True, choices=("host", "row", "pass"))
    parser.add_argument("--batch-id")
    parser.add_argument("--row-id")
    parser.add_argument("--completed-host")
    parser.add_argument("--next-host")
    parser.add_argument("--completed-row-id")
    parser.add_argument("--next-row-id")
    parser.add_argument("--completed-batch-id")
    parser.add_argument("--next-batch-id")


def _request_from_arguments(arguments):
    return GroupBoundaryRequest(
        token=arguments.token,
        group_id=arguments.group_id,
        sequence_index=arguments.sequence_index,
        kind=arguments.kind,
        batch_id=arguments.batch_id,
        row_id=arguments.row_id,
        completed_host=arguments.completed_host,
        next_host=arguments.next_host,
        completed_row_id=arguments.completed_row_id,
        next_row_id=arguments.next_row_id,
        completed_batch_id=arguments.completed_batch_id,
        next_batch_id=arguments.next_batch_id,
    )


def _load_group(path):
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file():
        raise ProtocolError(f"group is not a regular file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ProtocolError(f"cannot load group: {error}") from error
    return value


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan_parser = subparsers.add_parser("plan")
    plan_parser.add_argument("--group", required=True, type=pathlib.Path)
    observation_plan_parser = subparsers.add_parser("observation-plan")
    observation_plan_parser.add_argument(
        "--group", required=True, type=pathlib.Path)
    validate_parser = subparsers.add_parser("validate-request")
    validate_parser.add_argument("--path", required=True, type=pathlib.Path)
    _add_request_arguments(validate_parser)
    response_parser = subparsers.add_parser("write-response")
    response_parser.add_argument("--path", required=True, type=pathlib.Path)
    _add_request_arguments(response_parser)
    response_parser.add_argument("--reset-summary-sha256", required=True)
    event_parser = subparsers.add_parser("validate-event")
    event_parser.add_argument("--group", required=True, type=pathlib.Path)
    event_parser.add_argument("--token", required=True)
    event_parser.add_argument("--state", required=True, type=pathlib.Path)
    event_parser.add_argument("--path", required=True, type=pathlib.Path)
    restore_parser = subparsers.add_parser("write-restore-response")
    restore_parser.add_argument("--group", required=True, type=pathlib.Path)
    restore_parser.add_argument("--token", required=True)
    restore_parser.add_argument("--state", required=True, type=pathlib.Path)
    restore_parser.add_argument("--request", required=True, type=pathlib.Path)
    restore_parser.add_argument("--path", required=True, type=pathlib.Path)
    restore_parser.add_argument("--reset-summary-sha256", required=True)
    arguments = parser.parse_args()
    try:
        if arguments.command == "plan":
            value = boundary_plan(_load_group(arguments.group))
        elif arguments.command == "observation-plan":
            value = observation_plan(_load_group(arguments.group))
        elif arguments.command in {"validate-request", "write-response"}:
            expected = _request_from_arguments(arguments)
            if arguments.command == "validate-request":
                value = request_dict(load_request(arguments.path, expected))
            else:
                response = GroupBoundaryResponse(
                    request=expected,
                    reset_summary_sha256=arguments.reset_summary_sha256,
                    result="ready",
                )
                write_response(arguments.path, response)
                value = response_dict(response)
        else:
            group = _load_group(arguments.group)
            state = _load_observation_state(
                arguments.state, group, arguments.token)
            if arguments.command == "validate-event":
                event = load_observation_event(arguments.path)
                state.advance(event)
                _write_observation_state(arguments.state, state)
                value = observation_event_dict(event)
            else:
                event = load_observation_event(arguments.request)
                response = ObservationRestoreResponse(
                    request=event,
                    reset_summary_sha256=arguments.reset_summary_sha256,
                    result="ready",
                )
                state.accept_restore(response)
                write_observation_restore_response(arguments.path, response)
                _write_observation_state(arguments.state, state)
                value = observation_restore_response_dict(response)
    except ProtocolError as error:
        print(f"text-input group protocol error: {error}", file=sys.stderr)
        raise SystemExit(65)
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
