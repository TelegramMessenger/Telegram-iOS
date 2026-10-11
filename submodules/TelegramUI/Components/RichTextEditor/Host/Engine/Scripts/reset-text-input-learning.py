#!/usr/bin/env python3

import argparse
import json
import pathlib
import sqlite3


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
DATABASE_RELATIVE_PATH = pathlib.Path(
    "Library/Keyboard/AutocorrectionRejections.db"
)
EXPECTED_COLUMNS = {
    "rejections": [
        "ROWID",
        "typed",
        "correction",
        "performed_count",
        "soft_rejections",
        "hard_rejections",
        "last_soft_rejection",
        "last_hard_rejection",
        "journaled",
    ],
    "inline_completion_rejections": [
        "ROWID",
        "typed",
        "correction",
        "performed_count",
        "soft_rejections",
        "hard_rejections",
        "last_soft_rejection",
        "last_hard_rejection",
        "journaled",
    ],
    "properties": ["ROWID", "key", "value"],
}


class ResetError(RuntimeError):
    pass


def _dynamic_lexicon_files(device_root):
    bundle = (
        device_root
        / "Library"
        / "Keyboard"
        / "mul-dynamic.lm"
    )
    if not bundle.exists():
        return []
    if bundle.is_symlink() or not bundle.is_dir():
        raise ResetError("refusing invalid multilingual learning bundle")
    lexicons = sorted(bundle.glob("dynamic-lexicon-*.dat"))
    for lexicon in lexicons:
        if lexicon.is_symlink() or not lexicon.is_file():
            raise ResetError(
                "refusing invalid dynamic lexicon file: "
                f"{lexicon.name}"
            )
    return lexicons


def _database_counts(database):
    if database.is_symlink():
        raise ResetError("refusing a symbolic-link rejection database")
    connection = sqlite3.connect(
        f"file:{database}?mode=ro", uri=True
    )
    try:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        expected_tables = set(EXPECTED_COLUMNS) | {"sqlite_sequence"}
        if tables != expected_tables:
            raise ResetError(
                "rejection database tables differ from iOS 26.5: "
                f"expected={sorted(expected_tables)!r} "
                f"actual={sorted(tables)!r}"
            )
        for table, expected in EXPECTED_COLUMNS.items():
            actual = [
                row[1]
                for row in connection.execute(f"PRAGMA table_info({table})")
            ]
            if actual != expected:
                raise ResetError(
                    f"{table} columns differ from iOS 26.5: "
                    f"expected={expected!r} actual={actual!r}"
                )
        return {
            "priorAutocorrectionRejections": connection.execute(
                "SELECT COUNT(*) FROM rejections"
            ).fetchone()[0],
            "priorInlineCompletionRejections": connection.execute(
                "SELECT COUNT(*) FROM inline_completion_rejections"
            ).fetchone()[0],
        }
    finally:
        connection.close()


def reset(udid, device_root, output):
    if udid != PINNED_UDID:
        raise ResetError(f"refusing non-K3 simulator: {udid}")
    device_root = pathlib.Path(device_root).expanduser().resolve()
    output = pathlib.Path(output)
    if output.exists():
        raise ResetError(f"refusing existing evidence path: {output}")
    database = device_root / DATABASE_RELATIVE_PATH
    dynamic_lexicons = _dynamic_lexicon_files(device_root)
    if database.exists():
        counts = _database_counts(database)
    else:
        counts = {
            "priorAutocorrectionRejections": 0,
            "priorInlineCompletionRejections": 0,
        }
    result = (
        "reset"
        if database.exists() or dynamic_lexicons
        else "already-clean"
    )

    output.mkdir(parents=True)
    if database.exists():
        for path in [
            database,
            pathlib.Path(str(database) + "-shm"),
            pathlib.Path(str(database) + "-wal"),
        ]:
            path.unlink(missing_ok=True)
    for lexicon in dynamic_lexicons:
        lexicon.unlink()

    summary = {
        "schema": 1,
        "udid": udid,
        "database": str(DATABASE_RELATIVE_PATH),
        **counts,
        "priorDynamicLexiconFiles": [
            str(lexicon.relative_to(device_root))
            for lexicon in dynamic_lexicons
        ],
        "result": result,
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--device-root", required=True)
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()
    try:
        summary = reset(
            arguments.udid, arguments.device_root, arguments.output
        )
    except (OSError, sqlite3.Error, ResetError) as error:
        raise SystemExit(f"text-input learning reset failed: {error}")
    print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
