#!/usr/bin/env python3

import argparse
import json
import math
import pathlib


class ComparisonError(ValueError):
    pass


IDENTITY_FIELDS = ("blockIdentifiers", "anchorIdentities")
GEOMETRY_FIELDS = ("x", "y", "width", "height")
REQUIRED_INPUT_MODES = (
    "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
    "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
)
EXACT_FIELDS = (
    "schema", "scenario", "language", "location", "decision",
    "canonical", "blocks", "selection", "affinity", "markedRange",
    "markedText", "markedSelection", "markedAttributeKeys",
    "structuralNewlineLocations", "checkingRanges",
    "mutationTrace", "eventTrace", "coordinateSpaceIdentity",
    "textEpoch", "selectionEpoch", "checkingEpoch",
    "layoutEpoch", "firstResponder",
)


def fail(phase, field, stock, custom):
    raise ComparisonError(
        f"{phase}.{field} differs: stock={stock!r} custom={custom!r}")


def compare_geometry(phase, field, stock, custom, tolerance,
                     components=GEOMETRY_FIELDS):
    if not isinstance(stock, dict) or not isinstance(custom, dict):
        fail(phase, field, stock, custom)
    if set(stock) != set(GEOMETRY_FIELDS) or set(custom) != set(
            GEOMETRY_FIELDS):
        fail(phase, field, stock, custom)
    for component in components:
        stock_value = stock[component]
        custom_value = custom[component]
        if (isinstance(stock_value, bool) or
                isinstance(custom_value, bool) or
                not isinstance(stock_value, (int, float)) or
                not isinstance(custom_value, (int, float)) or
                not math.isfinite(stock_value) or
                not math.isfinite(custom_value) or
                abs(stock_value - custom_value) > tolerance):
            fail(
                phase, f"{field}.{component}", stock_value, custom_value)


def normalized_descriptors(value):
    if not isinstance(value, list):
        return value
    normalized = []
    for descriptor in value:
        if not isinstance(descriptor, dict):
            return value
        normalized.append({
            "range": descriptor.get("range"),
            "attributeKeys": descriptor.get("attributeKeys"),
        })
    return normalized


def compare_candidate(phase, stock, custom, tolerance,
                      compare_labels=True):
    exact = ["visible", "actionable"]
    if compare_labels:
        exact.extend(("labels", "selectedLabel"))
    if not isinstance(stock, dict) or not isinstance(custom, dict):
        fail(phase, "candidateDescriptor", stock, custom)
    for field in exact:
        if stock.get(field) != custom.get(field):
            fail(
                phase, f"candidateDescriptor.{field}",
                stock.get(field), custom.get(field))
    compare_geometry(
        phase, "candidateDescriptor.geometry",
        stock.get("geometry"), custom.get("geometry"), tolerance,
        components=("y", "width", "height"))


def compare_keyboard_state(phase, stock, custom):
    expected_keys = {
        "visible", "primaryLanguage", "enabledInputModeIdentifiers",
    }
    if (not isinstance(stock, dict) or not isinstance(custom, dict) or
            set(stock) != expected_keys or set(custom) != expected_keys):
        fail(phase, "keyboardState", stock, custom)
    for field in ("visible", "primaryLanguage"):
        if stock[field] != custom[field]:
            fail(
                phase, f"keyboardState.{field}",
                stock[field], custom[field])
    # iOS may append an unrelated fallback after the pre-launch provisioning
    # gate. Keep that raw evidence, but require both target IMEs on every phase.
    for host, state in (("stock", stock), ("custom", custom)):
        modes = state["enabledInputModeIdentifiers"]
        if (not isinstance(modes, list) or
                any(not isinstance(mode, str) for mode in modes)):
            raise ComparisonError(
                f"{phase}.{host}.enabledInputModeIdentifiers is invalid")
        missing = sorted(set(REQUIRED_INPUT_MODES) - set(modes))
        if missing:
            raise ComparisonError(
                f"{phase}.{host}.enabledInputModeIdentifiers is missing "
                f"required modes: {missing!r}")


def validate_stable_identities(host, phases):
    if not phases:
        raise ComparisonError(f"{host} lifecycle has no phases")
    baseline = phases[0].get("status", {})
    for field in IDENTITY_FIELDS:
        expected = baseline.get(field)
        if not isinstance(expected, list) or not expected:
            raise ComparisonError(f"{host} {field} is empty or invalid")
        for phase in phases[1:]:
            observed = phase.get("status", {}).get(field)
            if observed != expected:
                raise ComparisonError(
                    f"{host} {field} changed at {phase.get('phase')}: "
                    f"{expected!r} -> {observed!r}")
    previous_revision = -1
    for phase in phases:
        revision = phase.get("status", {}).get("documentRevision")
        if (isinstance(revision, bool) or not isinstance(revision, int) or
                revision < 0):
            raise ComparisonError(
                f"{host} documentRevision is invalid at "
                f"{phase.get('phase')}: {revision!r}")
        if revision < previous_revision:
            raise ComparisonError(
                f"{host} documentRevision regressed at "
                f"{phase.get('phase')}: {previous_revision} -> {revision}")
        previous_revision = revision


def compare_lifecycles(stock, custom, tolerance):
    if (isinstance(tolerance, bool) or
            not isinstance(tolerance, (int, float)) or
            not math.isfinite(tolerance) or tolerance < 0):
        raise ComparisonError("geometry tolerance must be finite and nonnegative")
    if stock.get("schema") != 1 or custom.get("schema") != 1:
        raise ComparisonError("both lifecycle schemas must equal 1")
    if stock.get("decision") != custom.get("decision"):
        fail(
            "lifecycle", "decision",
            stock.get("decision"), custom.get("decision"))
    stock_phases = stock.get("phases")
    custom_phases = custom.get("phases")
    if not isinstance(stock_phases, list) or not isinstance(custom_phases, list):
        raise ComparisonError("both lifecycles must contain phase arrays")
    stock_names = [phase.get("phase") for phase in stock_phases]
    custom_names = [phase.get("phase") for phase in custom_phases]
    if stock_names != custom_names:
        fail("lifecycle", "phases", stock_names, custom_names)
    validate_stable_identities("stock", stock_phases)
    validate_stable_identities("custom", custom_phases)

    for stock_phase, custom_phase in zip(stock_phases, custom_phases):
        phase = stock_phase["phase"]
        stock_status = stock_phase.get("status")
        custom_status = custom_phase.get("status")
        if not isinstance(stock_status, dict) or not isinstance(
                custom_status, dict):
            fail(phase, "status", stock_status, custom_status)
        for field in EXACT_FIELDS:
            if stock_status.get(field) != custom_status.get(field):
                fail(
                    phase, field,
                    stock_status.get(field), custom_status.get(field))
        for field in IDENTITY_FIELDS:
            stock_ids = stock_status.get(field)
            custom_ids = custom_status.get(field)
            if len(stock_ids) != len(custom_ids):
                fail(phase, f"{field}.count", len(stock_ids), len(custom_ids))
        stock_descriptors = normalized_descriptors(
            stock_status.get("temporaryRenderingDescriptors"))
        custom_descriptors = normalized_descriptors(
            custom_status.get("temporaryRenderingDescriptors"))
        if stock_descriptors != custom_descriptors:
            fail(
                phase, "temporaryRenderingDescriptors",
                stock_descriptors, custom_descriptors)
        compare_candidate(
            phase,
            stock_status.get("candidateDescriptor"),
            custom_status.get("candidateDescriptor"),
            tolerance,
            compare_labels=(phase != "firstComposition"))
        compare_keyboard_state(
            phase,
            stock_status.get("keyboardState"),
            custom_status.get("keyboardState"))
        compare_geometry(
            phase, "compositionGeometry",
            stock_status.get("compositionGeometry"),
            custom_status.get("compositionGeometry"),
            tolerance)

    return {
        "schema": 1,
        "stockTestMethod": stock.get("testMethod", ""),
        "customTestMethod": custom.get("testMethod", ""),
        "decision": stock.get("decision"),
        "phaseCount": len(stock_phases),
        "geometryTolerance": tolerance,
    }


def load_json(path):
    try:
        return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ComparisonError(f"cannot read {path}: {error}") from error


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stock", required=True)
    parser.add_argument("--custom", required=True)
    parser.add_argument("--tolerance", required=True, type=float)
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()
    output = pathlib.Path(arguments.output)
    if output.exists():
        raise SystemExit(f"refusing existing comparison output: {output}")
    try:
        comparison = compare_lifecycles(
            load_json(arguments.stock),
            load_json(arguments.custom),
            arguments.tolerance)
    except ComparisonError as error:
        raise SystemExit(f"IME composition mismatch: {error}") from error
    output.write_text(
        json.dumps(comparison, indent=2, ensure_ascii=False, sort_keys=True)
        + "\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
