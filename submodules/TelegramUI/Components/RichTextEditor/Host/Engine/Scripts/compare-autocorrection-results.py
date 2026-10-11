#!/usr/bin/env python3
import json
import math
import pathlib
import re
import subprocess
import sys


SEMANTIC_KEYS = (
    "canonical",
    "blocks",
    "selection",
    "affinity",
    "markedRange",
    "structuralNewlineLocations",
    "checkingRanges",
    "candidateDescriptor",
    "firstResponder",
)
PHASE_ORDER = (
    "baseline",
    "offered",
    "decision",
    "immediate",
    "quiesced",
    "postRejectionSpace",
    "firstBackspace",
    "secondBackspace",
)


def statuses_from_export(destination: pathlib.Path):
    manifest = json.loads((destination / "manifest.json").read_text())
    if not isinstance(manifest, list) or len(manifest) != 1:
        count = len(manifest) if isinstance(manifest, list) else "non-list"
        raise AssertionError(
            f"expected one test in {destination}, found {count}"
        )
    attachments = manifest[0].get("attachments")
    if not isinstance(attachments, list):
        raise AssertionError(f"missing attachment list in {destination}")
    statuses = {}
    for attachment in attachments:
        if not isinstance(attachment, dict):
            raise AssertionError(f"malformed attachment in {destination}")
        name = attachment.get("suggestedHumanReadableName", "")
        match = re.match(r"autocorrection-(.+)-status_", name)
        if match is None:
            continue
        phase = match.group(1)
        if phase in statuses:
            raise AssertionError(f"duplicate {phase} status in {destination}")
        filename = attachment.get("exportedFileName")
        if not isinstance(filename, str) or not filename:
            raise AssertionError(f"missing exported filename for {phase}")
        statuses[phase] = json.loads(
            (destination / filename).read_text()
        )
    if not statuses:
        raise AssertionError(
            f"no autocorrection status attachments in {destination}"
        )
    return statuses


def export_statuses(bundle: pathlib.Path, destination: pathlib.Path):
    if destination.exists():
        raise AssertionError(f"refusing to replace {destination}")
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
         "--output-path", str(destination)],
        check=True,
    )


def assert_equal(stock, custom, label):
    if stock != custom:
        raise AssertionError(f"{label}: stock={stock!r} custom={custom!r}")


def compare_geometry(stock, custom, phase):
    assert_equal(set(stock), set(custom), f"{phase}.correctionGeometry keys")
    for component in stock:
        stock_value = float(stock[component])
        custom_value = float(custom[component])
        if not math.isfinite(stock_value) or not math.isfinite(custom_value):
            raise AssertionError(f"{phase}.correctionGeometry.{component} is not finite")
        if abs(stock_value - custom_value) > 1.0:
            raise AssertionError(
                f"{phase}.correctionGeometry.{component}: "
                f"stock={stock_value} custom={custom_value}"
            )


def compare_exported_directories(
    stock_directory,
    custom_directory,
    output,
    stock_bundle,
    custom_bundle,
):
    stock = statuses_from_export(stock_directory)
    custom = statuses_from_export(custom_directory)
    assert_equal(set(stock), set(custom), "phase set")
    phases = [phase for phase in PHASE_ORDER if phase in stock]
    assert_equal(set(phases), set(stock), "known phase set")
    for phase in phases:
        for key in SEMANTIC_KEYS:
            assert_equal(stock[phase][key], custom[phase][key], f"{phase}.{key}")
        for key in ("visible", "locale", "learnedOriginal"):
            assert_equal(
                stock[phase]["keyboardState"][key],
                custom[phase]["keyboardState"][key],
                f"{phase}.keyboardState.{key}",
            )
        compare_geometry(
            stock[phase]["correctionGeometry"],
            custom[phase]["correctionGeometry"],
            phase,
        )
    summary = {
        "schema": 1,
        "stockBundle": str(stock_bundle),
        "customBundle": str(custom_bundle),
        "phases": phases,
        "semanticKeys": list(SEMANTIC_KEYS),
        "geometryTolerance": 1.0,
        "result": "passed",
    }
    output.mkdir(parents=True, exist_ok=True)
    parity = output / "parity.json"
    if parity.exists():
        raise AssertionError(f"refusing to replace {parity}")
    parity.write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: compare-autocorrection-results.py STOCK CUSTOM OUTPUT")
    stock_bundle = pathlib.Path(sys.argv[1])
    custom_bundle = pathlib.Path(sys.argv[2])
    output = pathlib.Path(sys.argv[3])
    stock_export = output / "stock-attachments"
    custom_export = output / "custom-attachments"
    export_statuses(stock_bundle, stock_export)
    export_statuses(custom_bundle, custom_export)
    compare_exported_directories(
        stock_export, custom_export, output, stock_bundle, custom_bundle
    )


if __name__ == "__main__":
    main()
