#!/usr/bin/env python3
import json
import pathlib
import sys


def fail(message):
    raise SystemExit(f"invalid autocorrection test summary: {message}")


def require_equal(actual, expected, label):
    if actual != expected:
        fail(f"{label}: expected {expected!r}, found {actual!r}")


def require_integer_equal(actual, expected, label):
    if type(actual) is not int or actual != expected:
        fail(f"{label}: expected integer {expected!r}, found {actual!r}")


def validate_counts(summary, prefix=""):
    expected = {
        "expectedFailures": 0,
        "failedTests": 0,
        "skippedTests": 0,
        "passedTests": 1,
    }
    for key, value in expected.items():
        require_integer_equal(summary.get(key), value, f"{prefix}{key}")


def main():
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: validate-autocorrection-summary.py "
            "SUMMARY EXPECTED_UDID EXPECTED_OS_VERSION EXPECTED_OS_BUILD"
        )
    summary_path = pathlib.Path(sys.argv[1])
    try:
        summary = json.loads(summary_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read {summary_path}: {error}")

    require_equal(summary.get("result"), "Passed", "result")
    require_integer_equal(summary.get("totalTestCount"), 1, "totalTestCount")
    validate_counts(summary)

    configurations = summary.get("devicesAndConfigurations")
    if not isinstance(configurations, list):
        fail("devicesAndConfigurations is not an array")
    require_equal(len(configurations), 1, "devicesAndConfigurations count")
    configuration = configurations[0]
    if not isinstance(configuration, dict):
        fail("devicesAndConfigurations[0] is not an object")
    validate_counts(configuration, "devicesAndConfigurations[0].")

    device = configuration.get("device")
    if not isinstance(device, dict):
        fail("devicesAndConfigurations[0].device is not an object")
    for key, expected in (
        ("deviceId", sys.argv[2]),
        ("osVersion", sys.argv[3]),
        ("osBuildNumber", sys.argv[4]),
    ):
        require_equal(device.get(key), expected, key)


if __name__ == "__main__":
    main()
