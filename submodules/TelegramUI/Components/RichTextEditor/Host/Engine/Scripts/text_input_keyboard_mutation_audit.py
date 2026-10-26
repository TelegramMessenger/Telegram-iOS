#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import pathlib
import re
import stat
import sys


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
RUNTIME = {"osVersion": "26.5", "osBuild": "23F73"}
TREE_CANDIDATES = (
    "Library/Keyboard",
    "Library/Caches/com.apple.keyboards",
)
PREFERENCE_PREFIXES = (
    "com.apple.keyboard",
    "com.apple.TextInput",
)
HEX_64 = re.compile(r"^[0-9a-f]{64}$")


class MutationAuditError(RuntimeError):
    pass


def _sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _description(path):
    information = path.lstat()
    if stat.S_ISLNK(information.st_mode):
        raise MutationAuditError(f"candidate is a symlink: {path}")
    if not stat.S_ISREG(information.st_mode):
        raise MutationAuditError(f"candidate is not a regular file: {path}")
    return {
        "type": "file",
        "mode": stat.S_IMODE(information.st_mode),
        "size": information.st_size,
        "sha256": _sha256(path),
        "mtimeNS": information.st_mtime_ns,
    }


def _tree_files(root):
    if not root.exists() and not root.is_symlink():
        return []
    if root.is_symlink():
        raise MutationAuditError(f"candidate root is a symlink: {root}")
    if not root.is_dir():
        raise MutationAuditError(f"candidate root is not a directory: {root}")
    result = []
    for current, directories, files in os.walk(root, followlinks=False):
        current_path = pathlib.Path(current)
        for name in directories:
            path = current_path / name
            if path.is_symlink():
                raise MutationAuditError(
                    f"candidate directory is a symlink: {path}")
        for name in files:
            result.append(current_path / name)
    return result


def scan_candidates(device_root):
    device_root = pathlib.Path(device_root)
    if device_root.is_symlink() or not device_root.is_dir():
        raise MutationAuditError("device root is missing or invalid")
    candidates = []
    for relative in TREE_CANDIDATES:
        candidates.extend(_tree_files(device_root / relative))

    preferences = device_root / "Library" / "Preferences"
    if preferences.exists() or preferences.is_symlink():
        if preferences.is_symlink() or not preferences.is_dir():
            raise MutationAuditError("preferences candidate root is invalid")
        for path in preferences.iterdir():
            if any(path.name.startswith(prefix)
                   for prefix in PREFERENCE_PREFIXES):
                candidates.append(path)

    files = {}
    for path in sorted(candidates, key=lambda item: item.as_posix()):
        relative = path.relative_to(device_root).as_posix()
        if relative in files:
            raise MutationAuditError(f"duplicate candidate path: {relative}")
        files[relative] = _description(path)
    return {
        "schema": 1,
        "udid": PINNED_UDID,
        "runtime": RUNTIME,
        "files": files,
    }


def _validate_scan(scan):
    if (not isinstance(scan, dict) or
            set(scan) != {"schema", "udid", "runtime", "files"} or
            scan.get("schema") != 1 or
            scan.get("udid") != PINNED_UDID or
            scan.get("runtime") != RUNTIME or
            not isinstance(scan.get("files"), dict)):
        raise MutationAuditError("mutation scan contract or identity is invalid")
    for relative, description in scan["files"].items():
        path = pathlib.PurePosixPath(relative) if isinstance(relative, str) else None
        if (path is None or path.is_absolute() or ".." in path.parts or
                str(path) != relative or not isinstance(description, dict) or
                set(description) != {
                    "type", "mode", "size", "sha256", "mtimeNS"} or
                description.get("type") != "file" or
                isinstance(description.get("mode"), bool) or
                not isinstance(description.get("mode"), int) or
                isinstance(description.get("size"), bool) or
                not isinstance(description.get("size"), int) or
                description["size"] < 0 or
                not isinstance(description.get("sha256"), str) or
                HEX_64.fullmatch(description["sha256"]) is None or
                isinstance(description.get("mtimeNS"), bool) or
                not isinstance(description.get("mtimeNS"), int)):
            raise MutationAuditError(
                f"mutation scan file entry is invalid: {relative!r}")


def _validate_restore_roots(restore_roots):
    if not isinstance(restore_roots, tuple) or not restore_roots:
        raise MutationAuditError("restore roots must be a nonempty tuple")
    normalized = []
    for raw in restore_roots:
        if not isinstance(raw, str):
            raise MutationAuditError("restore root is not a string")
        path = pathlib.PurePosixPath(raw)
        if (not raw or path.is_absolute() or ".." in path.parts or
                str(path) != raw):
            raise MutationAuditError(f"restore root is invalid: {raw!r}")
        normalized.append(raw)
    if len(normalized) != len(set(normalized)):
        raise MutationAuditError("restore roots must be unique")
    return tuple(normalized)


def compare_scans(before, after, restore_roots):
    _validate_scan(before)
    _validate_scan(after)
    roots = _validate_restore_roots(restore_roots)
    before_files = before["files"]
    after_files = after["files"]
    added = sorted(set(after_files) - set(before_files))
    removed = sorted(set(before_files) - set(after_files))
    changed = sorted(
        relative for relative in set(before_files) & set(after_files)
        if before_files[relative] != after_files[relative]
    )
    mutations = sorted({*added, *removed, *changed})

    def covered(relative):
        return any(relative == root or relative.startswith(f"{root}/")
                   for root in roots)

    restored = [relative for relative in mutations if covered(relative)]
    unclassified = [relative for relative in mutations if not covered(relative)]
    return {
        "schema": 1,
        "udid": PINNED_UDID,
        "runtime": RUNTIME,
        "result": "clean" if not unclassified else "unclassified-mutations",
        "restoreRoots": list(roots),
        "added": added,
        "removed": removed,
        "changed": changed,
        "restored": restored,
        "unclassified": unclassified,
    }


def _write_json_atomic(path, value):
    path = pathlib.Path(path)
    if path.exists() or path.is_symlink():
        raise MutationAuditError(f"audit output already exists: {path}")
    if path.parent.is_symlink() or not path.parent.is_dir():
        raise MutationAuditError("audit output parent is invalid")
    staging = path.with_name(f".{path.name}.partial-{os.getpid()}")
    if staging.exists() or staging.is_symlink():
        raise MutationAuditError(f"audit staging path already exists: {staging}")
    try:
        with staging.open("x", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
        staging.replace(path)
    except Exception:
        staging.unlink(missing_ok=True)
        raise


def _load_scan(path):
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file():
        raise MutationAuditError(f"audit scan input is invalid: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise MutationAuditError(f"cannot load audit scan: {error}")
    _validate_scan(value)
    return value


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    scan = commands.add_parser("scan")
    scan.add_argument("--device-root", required=True, type=pathlib.Path)
    scan.add_argument("--output", required=True, type=pathlib.Path)
    compare = commands.add_parser("compare")
    compare.add_argument("--before", required=True, type=pathlib.Path)
    compare.add_argument("--after", required=True, type=pathlib.Path)
    compare.add_argument(
        "--restore-root", action="append", required=True, dest="restore_roots")
    compare.add_argument("--output", required=True, type=pathlib.Path)
    arguments = parser.parse_args()
    try:
        if arguments.command == "scan":
            value = scan_candidates(arguments.device_root)
            _write_json_atomic(arguments.output, value)
            printed = {"schema": 1, "result": "scanned",
                       "files": len(value["files"])}
            status = 0
        else:
            value = compare_scans(
                _load_scan(arguments.before),
                _load_scan(arguments.after),
                tuple(arguments.restore_roots),
            )
            _write_json_atomic(arguments.output, value)
            printed = value
            status = 0 if value["result"] == "clean" else 65
    except MutationAuditError as error:
        print(f"keyboard mutation audit error: {error}", file=sys.stderr)
        raise SystemExit(65)
    print(json.dumps(printed, sort_keys=True, separators=(",", ":")))
    raise SystemExit(status)


if __name__ == "__main__":
    main()
