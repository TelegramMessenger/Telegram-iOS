#!/usr/bin/env python3
"""Cross-check semantic fixtures against preserved stock UIKit evidence."""

import argparse
import json
import pathlib
import re
import sys


FAMILIES = ("ime", "autocorrection", "inline-prediction")
PAIR_NAME = re.compile(
    r"repeat-\d+-(?:StockThenCustom|CustomThenStock)-(.+)$"
)


def fail(message):
    raise ValueError(message)


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read JSON {path}: {error}")


def utf16_units(text):
    raw = text.encode("utf-16-le")
    return [raw[index:index + 2] for index in range(0, len(raw), 2)]


def from_utf16_units(units):
    return b"".join(units).decode("utf-16-le")


def replay_terminal_canonical(scenario):
    units = utf16_units(scenario["initial"]["text"])
    selection = dict(scenario["initial"]["selection"])
    marked = None
    undo_stack = []
    group_snapshot = None

    def replace(location, length, text):
        nonlocal units, selection, marked
        inserted = utf16_units(text)
        end = location + length
        units[location:end] = inserted
        delta = len(inserted) - length

        selection_end = selection["location"] + selection["length"]
        if (
            selection["length"] == 0
            and location <= selection["location"] <= end
        ):
            selection = {"location": location + len(inserted), "length": 0}
        elif selection["location"] >= end:
            selection["location"] += delta
        elif selection_end > location:
            selection = {"location": location + len(inserted), "length": 0}

        if marked is not None:
            marked_end = marked["location"] + marked["length"]
            if marked["location"] >= end:
                marked["location"] += delta
            elif marked_end > location:
                marked = None

    for transaction in scenario["transactions"]:
        kind = transaction["kind"]
        if kind in (
            "become-first-responder",
            "resign-first-responder",
            "checkpoint",
            "set-traits",
            "unmark-text",
        ):
            if kind == "unmark-text":
                marked = None
            continue
        if kind == "set-selection":
            selection = dict(transaction["range"])
            continue
        if kind == "set-marked-text":
            target = marked if marked is not None else selection
            location = target["location"]
            replace(location, target["length"], transaction["text"])
            inserted_length = len(utf16_units(transaction["text"]))
            marked = {"location": location, "length": inserted_length}
            relative = transaction["selectedRange"]
            selection = {
                "location": location + relative["location"],
                "length": relative["length"],
            }
            continue
        if kind == "replace-range":
            target = transaction["range"]
            replace(
                target["location"], target["length"], transaction["text"]
            )
            continue
        if kind == "insert-text":
            location = selection["location"]
            replace(location, selection["length"], transaction["text"])
            selection = {
                "location": location
                + len(utf16_units(transaction["text"])),
                "length": 0,
            }
            marked = None
            continue
        if kind == "delete-backward":
            if selection["length"]:
                replace(
                    selection["location"], selection["length"], ""
                )
                selection["length"] = 0
            elif selection["location"] > 0:
                location = selection["location"] - 1
                replace(location, 1, "")
                selection = {"location": location, "length": 0}
            marked = None
            continue
        if kind == "begin-undo-group":
            if group_snapshot is not None:
                fail(f"{scenario['identifier']}: nested undo group")
            group_snapshot = (
                list(units),
                dict(selection),
                None if marked is None else dict(marked),
            )
            continue
        if kind == "end-undo-group":
            if group_snapshot is None:
                fail(f"{scenario['identifier']}: unmatched undo group")
            undo_stack.append(group_snapshot)
            group_snapshot = None
            continue
        if kind == "undo":
            if not undo_stack:
                fail(f"{scenario['identifier']}: undo without snapshot")
            units, selection, marked = undo_stack.pop()
            continue
        if kind == "redo":
            fail(f"{scenario['identifier']}: redo replay is unsupported")
        fail(f"{scenario['identifier']}: unknown transaction {kind}")

    if group_snapshot is not None:
        fail(f"{scenario['identifier']}: unterminated undo group")
    return from_utf16_units(units)


def camel_to_kebab(value):
    words = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", value)
    return words.lower()


def terminal_phase(family, identifier, phases):
    if family == "autocorrection":
        if "-undo-" in identifier:
            phase = "offered"
        elif identifier.endswith("-reject-precommit"):
            phase = "postRejectionSpace"
        else:
            phase = "quiesced"
    elif family == "inline-prediction":
        if identifier.endswith("-dismiss-then-type"):
            phase = "postDismissTyping"
        elif identifier.endswith("-accept-then-delete"):
            phase = "firstBackspace"
        else:
            phase = "quiesced"
    else:
        phase = "baseline" if identifier.endswith(
            "-return-commit-then-undo"
        ) else phases[-1]
    if phase not in phases:
        fail(f"{identifier}: missing preserved terminal phase {phase}")
    return phase


def attachment_status(pair, prefix, phase):
    directory = pair / "stock-attachments"
    manifest = read_json(directory / "manifest.json")
    if not isinstance(manifest, list):
        fail(f"{directory}: attachment manifest is not a list")
    matches = []
    expected_prefix = f"{prefix}-{phase}-status_"
    for test in manifest:
        for attachment in test.get("attachments", []):
            if attachment.get(
                "suggestedHumanReadableName", ""
            ).startswith(expected_prefix):
                matches.append(attachment)
    if len(matches) != 1:
        fail(
            f"{pair}: expected one {phase} stock status, found "
            f"{len(matches)}"
        )
    filename = matches[0].get("exportedFileName")
    status = read_json(directory / filename)
    canonical = status.get("canonical")
    if not isinstance(canonical, str):
        fail(f"{pair}: {phase} status has no canonical string")
    return canonical


def index_ime(root):
    values = {}
    lifecycles = sorted(root.rglob("stock/lifecycle.json"))
    if not lifecycles:
        fail(f"missing IME lifecycle evidence under {root}")
    for path in lifecycles:
        lifecycle = read_json(path)
        phases = lifecycle.get("phases")
        if not isinstance(phases, list) or not phases:
            fail(f"{path}: missing lifecycle phases")
        statuses = {
            item.get("phase"): item.get("status")
            for item in phases
            if isinstance(item, dict)
        }
        terminal_status = phases[-1].get("status", {})
        identifier = terminal_status.get("scenario")
        if not isinstance(identifier, str):
            fail(f"{path}: missing scenario identifier")
        if identifier.startswith("ime-"):
            identifier = identifier[4:]
        phase = terminal_phase("ime", identifier, list(statuses))
        status = statuses.get(phase)
        canonical = status.get("canonical") if isinstance(status, dict) else None
        if not isinstance(canonical, str):
            fail(f"{path}: {phase} has no canonical string")
        add_evidence(values, identifier, canonical, path)
    return values


def add_evidence(values, identifier, canonical, path):
    prior = values.get(identifier)
    if prior is not None and prior != canonical:
        fail(
            f"{identifier}: inconsistent preserved canonical values "
            f"{prior!r} and {canonical!r} at {path}"
        )
    values[identifier] = canonical


def normalized_evidence_canonical(family, identifier, canonical):
    # Accepting a correction from the candidate bar immediately before a
    # structural newline makes UIKit insert a candidate-boundary spacer. The
    # semantic fixture freezes the equivalent UITextInput replacement itself;
    # that transaction deliberately excludes the keyboard UI's spacer.
    if (
        family == "autocorrection"
        and identifier == "before-boundary-accept-candidate"
    ):
        return canonical.replace("address \n", "address\n", 1)
    # Dismissing a native inline offer by typing consumes UIKit's whitespace
    # immediately before the offer. The replay starts from the already-typed
    # fixture and expresses only marked-text removal plus insertion, so retain
    # that fixture-owned whitespace when comparing the terminal document.
    if family == "inline-prediction" and identifier.endswith(
        "-dismiss-then-type"
    ):
        return canonical.replace("forwardx", "forward x", 1)
    return canonical


def index_attachment_family(root, family, prefix):
    values = {}
    parities = sorted(root.glob("*/parity.json"))
    if not parities:
        fail(f"missing {family} parity evidence under {root}")
    for path in parities:
        match = PAIR_NAME.fullmatch(path.parent.name)
        if match is None:
            fail(f"{path.parent}: unrecognized pair directory")
        identifier = camel_to_kebab(match.group(1))
        parity = read_json(path)
        if parity.get("result") != "passed":
            fail(f"{path}: parity result is not passed")
        phases = parity.get("phases")
        if not isinstance(phases, list) or not phases:
            fail(f"{path}: missing parity phases")
        phase = terminal_phase(family, identifier, phases)
        canonical = attachment_status(path.parent, prefix, phase)
        add_evidence(values, identifier, canonical, path)
    return values


def load_fixtures(root):
    fixtures = {}
    for family in FAMILIES:
        path = root / f"{family}-ios26.5-v1.json"
        payload = read_json(path)
        if payload.get("family") != family:
            fail(f"{path}: family mismatch")
        scenarios = payload.get("scenarios")
        if not isinstance(scenarios, list) or not scenarios:
            fail(f"{path}: missing scenarios")
        fixtures[family] = scenarios
    return fixtures


def validate(args):
    fixtures = load_fixtures(args.fixture_root)
    evidence = {
        "ime": index_ime(args.ime_evidence),
        "autocorrection": index_attachment_family(
            args.autocorrection_evidence,
            "autocorrection",
            "autocorrection",
        ),
        "inline-prediction": index_attachment_family(
            args.inline_prediction_evidence,
            "inline-prediction",
            "inline-prediction",
        ),
    }
    counts = {}
    for family in FAMILIES:
        seen = set()
        for scenario in fixtures[family]:
            identifier = scenario.get("identifier")
            if not isinstance(identifier, str) or not identifier:
                fail(f"{family}: fixture scenario has no identifier")
            if identifier in seen:
                fail(f"{family}: duplicate fixture identifier {identifier}")
            seen.add(identifier)
            if identifier not in evidence[family]:
                fail(f"{identifier}: missing from {family} evidence")
            expected = replay_terminal_canonical(scenario)
            observed = normalized_evidence_canonical(
                family, identifier, evidence[family][identifier]
            )
            if expected != observed:
                fail(
                    f"{identifier}: terminal canonical mismatch: "
                    f"fixture={expected!r} evidence={observed!r}"
                )
        counts[family] = len(seen)
    return {
        "schema": 1,
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "scenarioCount": sum(counts.values()),
        "families": counts,
        "result": "passed",
    }


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture-root", type=pathlib.Path, required=True)
    parser.add_argument("--ime-evidence", type=pathlib.Path, required=True)
    parser.add_argument(
        "--autocorrection-evidence", type=pathlib.Path, required=True
    )
    parser.add_argument(
        "--inline-prediction-evidence", type=pathlib.Path, required=True
    )
    return parser.parse_args()


def main():
    try:
        summary = validate(parse_args())
    except (KeyError, TypeError, ValueError) as error:
        print(f"provenance validation failed: {error}", file=sys.stderr)
        return 65
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
