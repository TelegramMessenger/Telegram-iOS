#!/usr/bin/env python3
"""Prepare or build the genuine Telegram-iOS simulator target with local settings.

No source-controlled build file is changed. This helper only builds the isolated
offline demo: API placeholders and the dedicated bundle are fixed; user keys are not read.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time


WORKSPACE = Path(__file__).resolve().parents[1]
GIB = 1024 ** 3


def redact(text: str, api_id: int, api_hash: str) -> str:
    if api_hash:
        text = text.replace(api_hash, "<redacted-api-hash>")
    if api_id > 0:
        text = re.sub(r"(?<!\d)" + re.escape(str(api_id)) + r"(?!\d)", "<redacted-api-id>", text)
    return text


def check_disk(repo: Path, minimum: float) -> float:
    free = shutil.disk_usage(repo).free / GIB
    if free < minimum:
        raise RuntimeError(f"Only {free:.1f} GiB free; at least {minimum:.1f} GiB must remain.")
    return free


def write_private(path: Path, content: str, executable: bool = False) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o700 if executable else 0o600)


def stop_build(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGINT)
    try:
        process.wait(timeout=20)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)


def run_build(command: list[str], repo: Path, local: Path, minimum: float,
              api_id: int, api_hash: str) -> int:
    log_path = local / "build.log"
    with log_path.open("w", encoding="utf-8") as log:
        log_path.chmod(0o600)
        process = subprocess.Popen(command, cwd=repo, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, errors="replace",
                                   start_new_session=True, bufsize=1)

        def relay() -> None:
            assert process.stdout is not None
            for line in process.stdout:
                safe = redact(line, api_id, api_hash)
                log.write(safe)
                log.flush()
                sys.stdout.write(safe)
                sys.stdout.flush()

        reader = threading.Thread(target=relay, daemon=True)
        reader.start()
        try:
            while process.poll() is None:
                check_disk(repo, minimum)
                time.sleep(2)
        except (RuntimeError, KeyboardInterrupt):
            stop_build(process)
            raise
        finally:
            reader.join(timeout=5)
    return process.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--build-number", type=int, default=100001)
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=4)
    parser.add_argument("--min-free-gib", type=float, default=2.0)
    parser.add_argument("--execute", action="store_true", help="Run the full Make.py build after preparing.")
    arguments = parser.parse_args()
    arguments.bundle_id = "org.allmention.TelegramClient"
    os.umask(0o077)
    repo = arguments.repo.expanduser().resolve()
    if not (repo / "versions.json").is_file():
        raise ValueError("--repo must name a Telegram-iOS checkout containing versions.json.")
    if arguments.min_free_gib < 2 or arguments.build_number < 1:
        raise ValueError("Keep at least 2 GiB free and use a positive build number.")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+", arguments.bundle_id):
        raise ValueError("Invalid bundle identifier.")
    free = check_disk(repo, arguments.min_free_gib)
    local = repo / "build-input" / ".local-allmention"
    local.mkdir(parents=True, exist_ok=True)
    local.chmod(0o700)
    ignored = subprocess.run(["git", "-C", str(repo), "check-ignore", "-q", "--no-index",
                              "build-input/.local-allmention/configuration.json"], check=False)
    if ignored.returncode != 0:
        raise RuntimeError("The local configuration path is not gitignored; no credentials were written.")

    with (local / "build.lock").open("w") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("This checkout already has a build helper running.") from None

        api_id, api_hash = 0, ""
        configuration = {
            "bundle_id": arguments.bundle_id,
            "api_id": str(api_id), "api_hash": api_hash,
            "team_id": "LOCALDEMO0", "app_center_id": "0",
            "is_internal_build": "true", "is_appstore_build": "false",
            "appstore_id": "0", "app_specific_url_scheme": "tgallmention",
            "premium_iap_product_id": "", "enable_siri": False, "enable_icloud": False,
        }
        config_path = local / "configuration.json"
        write_private(config_path, json.dumps(configuration, indent=2) + "\n")
        versions = json.loads((repo / "versions.json").read_text(encoding="utf-8"))
        bazel_version = versions["bazel"].split(":")[0]
        architecture = "darwin-arm64" if platform.machine() == "arm64" else "darwin-x86_64"
        real_bazel = repo / "build-input" / f"bazel-{bazel_version}-{architecture}"
        rc_path = local / ".bazelrc.user"
        write_private(rc_path, "\n".join([
            "# Imported explicitly by the local wrapper; tracked .bazelrc stays unchanged.",
            f"import {shlex.quote(str(repo / '.bazelrc'))}",
            f"build --jobs={arguments.jobs}",
            "build --repo_contents_cache=",
            "build --//Telegram:disableProvisioningProfiles",
            "build --//Telegram:disableExtensions",
            "",
        ]))
        wrapper = local / "bazel-local"
        wrapper_source = (
            "#!/usr/bin/python3\nimport os, sys\n"
            f"binary = {str(real_bazel)!r}\n"
            f"rc = {str(rc_path)!r}\n"
            "if sys.argv[1:] == ['--version']:\n"
            "    os.execv(binary, [binary, '--version'])\n"
            "os.execv(binary, [binary, '--nosystem_rc', '--nohome_rc', '--noworkspace_rc', "
            "'--bazelrc=' + rc, *sys.argv[1:]])\n"
        )
        write_private(wrapper, wrapper_source, executable=True)
        command = [sys.executable, str(repo / "build-system/Make/Make.py"),
                   "--bazel", str(wrapper), "--bazelUserRoot", str(local / "bazel-user-root"),
                   "build", "--configurationPath", str(config_path), "--xcodeManagedCodesigning",
                   "--buildNumber", str(arguments.build_number), "--configuration", "debug_sim_arm64"]
        print(f"Official client: {versions['app']}; Xcode {versions['xcode']}; Bazel {bazel_version}.")
        print("API: configured locally." if api_id else "API: compile/demo-only placeholders; Telegram login is unavailable.")
        print(f"Free space: {free:.1f} GiB; jobs: {arguments.jobs}; stop threshold: {arguments.min_free_gib:.1f} GiB.")
        print("No extra disk-cache copy; Bazel output remains inside this checkout.")
        print("Command (Bazel is checksum-verified from versions.json before execution):")
        print(shlex.join(command))
        if not arguments.execute:
            print("Prepared only. Add --execute to run the full official client build.")
            return 0
        if platform.system() != "Darwin":
            raise RuntimeError("The Telegram iOS client must be built on macOS.")
        status = subprocess.run(["git", "-C", str(repo), "submodule", "status", "--recursive"],
                                capture_output=True, text=True, timeout=45, check=True)
        missing = [line for line in status.stdout.splitlines() if line.startswith(("-", "+", "U"))]
        if missing:
            raise RuntimeError("Submodules are uninitialized or not at the pinned revisions; finish the recursive update first.")
        os.chdir(repo)
        sys.path.insert(0, str(repo / "build-system/Make"))
        from BazelLocation import locate_bazel
        located_bazel = locate_bazel(base_path=str(repo), cache_host_or_path=None, cache_dir=None)
        if Path(located_bazel).resolve() != real_bazel.resolve():
            raise RuntimeError("The official Bazel locator resolved an unexpected binary.")
        check_disk(repo, arguments.min_free_gib)
        return run_build(command, repo, local, arguments.min_free_gib, api_id, api_hash)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Build interrupted.", file=sys.stderr)
        raise SystemExit(130)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        # Configuration errors never include credential values.
        print(f"Build helper: {error}", file=sys.stderr)
        raise SystemExit(1)
