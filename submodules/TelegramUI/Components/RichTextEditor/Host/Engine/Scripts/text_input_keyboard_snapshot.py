#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import sqlite3
import stat
import sys


PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
RUNTIME = {"osVersion": "26.5", "osBuild": "23F73"}
DEFAULT_ROOTS = (
    "Library/Keyboard",
    "Library/Preferences/com.apple.keyboard.preferences.plist",
)


class KeyboardSnapshotError(RuntimeError):
    pass


def _sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _relative_path(value):
    path = pathlib.PurePosixPath(value)
    if (not isinstance(value, str) or not value or path.is_absolute() or
            ".." in path.parts or str(path) != value):
        raise KeyboardSnapshotError(
            f"snapshot root is not a safe relative path: {value!r}")
    return path


def _validate_identity(identity):
    expected_keys = {
        "schema", "udid", "runtime", "locale", "inputModes",
        "manifestFormat",
    }
    if (not isinstance(identity, dict) or set(identity) != expected_keys or
            identity.get("schema") != 1 or
            identity.get("udid") != PINNED_UDID or
            identity.get("runtime") != RUNTIME or
            identity.get("locale") != "en_US" or
            identity.get("manifestFormat") != 1 or
            not isinstance(identity.get("inputModes"), list) or
            not identity["inputModes"] or
            any(not isinstance(item, str) or not item
                for item in identity["inputModes"])):
        raise KeyboardSnapshotError("snapshot identity is invalid")


def _sqlite_description(path):
    try:
        with path.open("rb") as stream:
            header = stream.read(16)
    except OSError as error:
        raise KeyboardSnapshotError(f"cannot inspect SQLite file {path}: {error}")
    if header != b"SQLite format 3\x00":
        return None
    try:
        connection = sqlite3.connect(
            f"file:{path}?mode=ro&immutable=1", uri=True)
        try:
            journal_mode = connection.execute(
                "PRAGMA journal_mode").fetchone()[0]
            rows = connection.execute(
                "SELECT type, name, tbl_name, sql FROM sqlite_master "
                "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name"
            ).fetchall()
            schema = [{
                "type": item[0],
                "name": item[1],
                "tableName": item[2],
                "sql": item[3],
            } for item in rows]
            counts = {}
            for item in schema:
                if item["type"] != "table":
                    continue
                quoted = item["name"].replace('"', '""')
                counts[item["name"]] = connection.execute(
                    f'SELECT COUNT(*) FROM "{quoted}"').fetchone()[0]
            return {
                "journalMode": journal_mode,
                "schema": schema,
                "tableRowCounts": counts,
            }
        finally:
            connection.close()
    except sqlite3.Error as error:
        raise KeyboardSnapshotError(f"cannot inspect SQLite file {path}: {error}")


def _scan_roots(base, relative_roots):
    files = {}
    databases = {}
    roots = []
    for raw_root in relative_roots:
        relative_root = _relative_path(raw_root)
        root = base.joinpath(*relative_root.parts)
        if root.is_symlink():
            raise KeyboardSnapshotError(f"snapshot root is a symlink: {raw_root}")
        if not root.is_dir() and not root.is_file():
            raise KeyboardSnapshotError(
                f"snapshot root is not a directory or regular file: {raw_root}")
        roots.append(str(relative_root))
        paths = [root]
        if root.is_dir():
            paths.extend(sorted(root.rglob("*"), key=lambda item: item.as_posix()))
        for path in paths:
            relative = path.relative_to(base).as_posix()
            information = path.lstat()
            mode = stat.S_IMODE(information.st_mode)
            if stat.S_ISLNK(information.st_mode):
                raise KeyboardSnapshotError(
                    f"snapshot entry is a symlink: {relative}")
            if stat.S_ISDIR(information.st_mode):
                files[relative] = {"type": "directory", "mode": mode}
                continue
            if not stat.S_ISREG(information.st_mode):
                raise KeyboardSnapshotError(
                    f"snapshot entry has unsupported type: {relative}")
            files[relative] = {
                "type": "file",
                "mode": mode,
                "size": information.st_size,
                "sha256": _sha256(path),
            }
            sqlite_description = _sqlite_description(path)
            if sqlite_description is not None:
                databases[relative] = sqlite_description
    if len(roots) != len(set(roots)):
        raise KeyboardSnapshotError("snapshot roots must be unique")
    return roots, files, databases


def _manifest_for(base, identity, relative_roots):
    roots, files, databases = _scan_roots(base, relative_roots)
    return {
        "schema": 1,
        "identity": identity,
        "roots": roots,
        "files": files,
        "sqlite": databases,
    }


def _write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def _make_tree_read_only(tree):
    paths = sorted(
        [tree, *tree.rglob("*")],
        key=lambda item: len(item.parts),
        reverse=True,
    )
    for path in paths:
        mode = stat.S_IMODE(path.lstat().st_mode)
        path.chmod(mode & ~0o222)


def capture_snapshot(device_root, output, identity, relative_roots=DEFAULT_ROOTS):
    device_root = pathlib.Path(device_root)
    output = pathlib.Path(output)
    _validate_identity(identity)
    if output.exists() or output.is_symlink():
        raise KeyboardSnapshotError(f"snapshot output already exists: {output}")
    if output.parent.is_symlink() or not output.parent.is_dir():
        raise KeyboardSnapshotError("snapshot output parent is invalid")
    staging = output.with_name(f".{output.name}.partial-{os.getpid()}")
    if staging.exists() or staging.is_symlink():
        raise KeyboardSnapshotError(
            f"snapshot staging path already exists: {staging}")

    manifest = _manifest_for(device_root, identity, relative_roots)
    try:
        tree = staging / "tree"
        tree.mkdir(parents=True)
        for raw_root in manifest["roots"]:
            relative_root = pathlib.PurePosixPath(raw_root)
            source = device_root.joinpath(*relative_root.parts)
            destination = tree.joinpath(*relative_root.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                shutil.copytree(source, destination, symlinks=True)
            else:
                shutil.copy2(source, destination, follow_symlinks=False)
        _write_json(staging / "manifest.json", manifest)
        _make_tree_read_only(tree)
        _verify_snapshot_contents(staging, identity)
        staging.replace(output)
        return manifest
    except Exception as error:
        if staging.exists():
            _force_remove(staging)
        if isinstance(error, KeyboardSnapshotError):
            raise
        raise KeyboardSnapshotError(f"cannot capture keyboard snapshot: {error}")


def _force_remove(path):
    for current, directories, files in os.walk(path):
        pathlib.Path(current).chmod(0o700)
        for name in directories:
            (pathlib.Path(current) / name).chmod(0o700)
        for name in files:
            (pathlib.Path(current) / name).chmod(0o600)
    shutil.rmtree(path, ignore_errors=True)


def _load_manifest(snapshot):
    manifest_path = snapshot / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise KeyboardSnapshotError("snapshot manifest is missing or invalid")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise KeyboardSnapshotError(f"cannot load snapshot manifest: {error}")
    if (not isinstance(manifest, dict) or set(manifest) != {
            "schema", "identity", "roots", "files", "sqlite"} or
            manifest.get("schema") != 1 or
            not isinstance(manifest.get("roots"), list) or
            not isinstance(manifest.get("files"), dict) or
            not isinstance(manifest.get("sqlite"), dict)):
        raise KeyboardSnapshotError("snapshot manifest contract is invalid")
    return manifest


def _verify_snapshot_contents(snapshot, expected_identity):
    manifest = _load_manifest(snapshot)
    if manifest["identity"] != expected_identity:
        raise KeyboardSnapshotError("snapshot identity differs")
    tree = snapshot / "tree"
    if tree.is_symlink() or not tree.is_dir():
        raise KeyboardSnapshotError("snapshot tree is missing or invalid")
    actual = _manifest_for(tree, expected_identity, tuple(manifest["roots"]))
    expected_files = manifest["files"]
    if set(actual["files"]) != set(expected_files):
        raise KeyboardSnapshotError("snapshot tree differs from manifest")
    for relative, expected in expected_files.items():
        observed = actual["files"][relative]
        comparable = {key: value for key, value in observed.items()
                      if key != "mode"}
        expected_comparable = {key: value for key, value in expected.items()
                               if key != "mode"}
        if comparable != expected_comparable:
            raise KeyboardSnapshotError("snapshot tree differs from manifest")
        stored = tree.joinpath(*pathlib.PurePosixPath(relative).parts)
        if stat.S_IMODE(stored.lstat().st_mode) & 0o222:
            raise KeyboardSnapshotError("snapshot tree is writable")
    if actual["sqlite"] != manifest["sqlite"]:
        raise KeyboardSnapshotError("snapshot SQLite state differs from manifest")
    return manifest


def verify_snapshot(snapshot, expected_identity):
    _validate_identity(expected_identity)
    snapshot = pathlib.Path(snapshot)
    if snapshot.is_symlink() or not snapshot.is_dir():
        raise KeyboardSnapshotError("snapshot path is missing or invalid")
    return _verify_snapshot_contents(snapshot, expected_identity)


def _apply_live_modes(root, tree, manifest):
    entries = sorted(
        manifest["files"].items(),
        key=lambda item: len(pathlib.PurePosixPath(item[0]).parts),
        reverse=True,
    )
    for relative, description in entries:
        relative_path = pathlib.PurePosixPath(relative)
        root_path = pathlib.PurePosixPath(root)
        try:
            suffix = relative_path.relative_to(root_path)
        except ValueError:
            continue
        path = tree.joinpath(*suffix.parts)
        path.chmod(description["mode"])


def _verify_live_root(device_root, root, manifest):
    _, actual_files, actual_sqlite = _scan_roots(device_root, (root,))
    expected_files = {
        relative: description
        for relative, description in manifest["files"].items()
        if (relative == root or relative.startswith(f"{root}/"))
    }
    expected_sqlite = {
        relative: description
        for relative, description in manifest["sqlite"].items()
        if relative == root or relative.startswith(f"{root}/")
    }
    if actual_files != expected_files or actual_sqlite != expected_sqlite:
        raise KeyboardSnapshotError(
            f"restored live root differs from snapshot manifest: {root}")


def restore_snapshot(
        device_root, snapshot, evidence_output, expected_identity):
    device_root = pathlib.Path(device_root)
    snapshot = pathlib.Path(snapshot)
    evidence_output = pathlib.Path(evidence_output)
    manifest = verify_snapshot(snapshot, expected_identity)
    if evidence_output.exists() or evidence_output.is_symlink():
        raise KeyboardSnapshotError(
            f"restore evidence output already exists: {evidence_output}")
    if (evidence_output.parent.is_symlink() or
            not evidence_output.parent.is_dir()):
        raise KeyboardSnapshotError("restore evidence output parent is invalid")

    prepared = []
    for root in manifest["roots"]:
        relative = pathlib.PurePosixPath(root)
        live = device_root.joinpath(*relative.parts)
        staging = live.with_name(f".{live.name}.restore-{os.getpid()}")
        if staging.exists() or staging.is_symlink():
            raise KeyboardSnapshotError(
                f"live restore staging path already exists: {staging}")
        prepared.append((root, live, staging))

    evidence_staging = evidence_output.with_name(
        f".{evidence_output.name}.partial-{os.getpid()}")
    if evidence_staging.exists() or evidence_staging.is_symlink():
        raise KeyboardSnapshotError(
            f"restore evidence staging path already exists: {evidence_staging}")

    try:
        for root, _, staging in prepared:
            source = snapshot / "tree"
            source = source.joinpath(*pathlib.PurePosixPath(root).parts)
            if source.is_dir():
                shutil.copytree(source, staging, symlinks=True)
            else:
                shutil.copy2(source, staging, follow_symlinks=False)
            _apply_live_modes(root, staging, manifest)

        for root, live, staging in prepared:
            if live.is_symlink():
                raise KeyboardSnapshotError(
                    f"live restore root is a symlink: {root}")
            if live.exists():
                if staging.is_dir():
                    if not live.is_dir():
                        raise KeyboardSnapshotError(
                            f"live restore root is not a directory: {root}")
                    shutil.rmtree(live)
                else:
                    if not live.is_file():
                        raise KeyboardSnapshotError(
                            f"live restore root is not a regular file: {root}")
                    live.unlink()
            staging.replace(live)
            _verify_live_root(device_root, root, manifest)

        manifest_hash = _sha256(snapshot / "manifest.json")
        summary = {
            "schema": 1,
            "result": "restored",
            "identity": expected_identity,
            "roots": list(manifest["roots"]),
            "baselineManifestSHA256": manifest_hash,
            "restoredManifestSHA256": manifest_hash,
        }
        evidence_staging.mkdir()
        _write_json(evidence_staging / "summary.json", summary)
        evidence_staging.replace(evidence_output)
        return summary
    except Exception as error:
        for _, _, staging in prepared:
            if staging.exists():
                _force_remove(staging)
        if evidence_staging.exists():
            _force_remove(evidence_staging)
        if isinstance(error, KeyboardSnapshotError):
            raise
        raise KeyboardSnapshotError(f"cannot restore keyboard snapshot: {error}")


def _load_identity(path):
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file():
        raise KeyboardSnapshotError("snapshot identity file is invalid")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise KeyboardSnapshotError(f"cannot load snapshot identity: {error}")
    _validate_identity(value)
    return value


def _compact_result(result, manifest=None):
    value = {"schema": 1, "result": result}
    if manifest is not None:
        encoded = json.dumps(
            manifest, indent=2, sort_keys=True).encode("utf-8") + b"\n"
        value["manifestSHA256"] = hashlib.sha256(encoded).hexdigest()
    return value


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    capture = commands.add_parser("capture")
    capture.add_argument("--device-root", required=True, type=pathlib.Path)
    capture.add_argument("--identity", required=True, type=pathlib.Path)
    capture.add_argument("--output", required=True, type=pathlib.Path)
    capture.add_argument("--root", action="append", dest="roots")

    verify = commands.add_parser("verify")
    verify.add_argument("--snapshot", required=True, type=pathlib.Path)
    verify.add_argument("--identity", required=True, type=pathlib.Path)

    restore = commands.add_parser("restore")
    restore.add_argument("--device-root", required=True, type=pathlib.Path)
    restore.add_argument("--snapshot", required=True, type=pathlib.Path)
    restore.add_argument("--identity", required=True, type=pathlib.Path)
    restore.add_argument("--output", required=True, type=pathlib.Path)

    arguments = parser.parse_args()
    try:
        identity = _load_identity(arguments.identity)
        if arguments.command == "capture":
            manifest = capture_snapshot(
                arguments.device_root,
                arguments.output,
                identity,
                tuple(arguments.roots or DEFAULT_ROOTS),
            )
            result = _compact_result("captured", manifest)
        elif arguments.command == "verify":
            manifest = verify_snapshot(arguments.snapshot, identity)
            result = _compact_result("verified", manifest)
        else:
            result = restore_snapshot(
                arguments.device_root,
                arguments.snapshot,
                arguments.output,
                identity,
            )
    except KeyboardSnapshotError as error:
        print(f"keyboard snapshot error: {error}", file=sys.stderr)
        raise SystemExit(65)
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
