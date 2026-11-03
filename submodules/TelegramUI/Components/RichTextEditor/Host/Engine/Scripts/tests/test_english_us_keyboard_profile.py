import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "Scripts" / "english_us_keyboard_profile.py"
PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"


def load_module():
    specification = importlib.util.spec_from_file_location(
        "english_us_keyboard_profile", MODULE_PATH
    )
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


class EnglishUSKeyboardProfileTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.outputs = {
            "SIMULATOR_RUNTIME_VERSION": "26.5\n",
            "SIMULATOR_RUNTIME_BUILD_VERSION": "23F73\n",
            "AppleLocale": "en_US\n",
            "AppleLanguages": '(\n    "en-US"\n)\n',
            "AppleKeyboards": '(\n    "en_US@hw=Automatic"\n)\n',
            "AppleKeyboardsExpanded": "1\n",
        }

    def runner(self, overrides=None, calls=None):
        overrides = overrides or {}
        calls = calls if calls is not None else []

        def run(command, **arguments):
            self.assertTrue(arguments.get("text"))
            self.assertTrue(arguments.get("capture_output"))
            self.assertFalse(arguments.get("check"))
            calls.append(command)
            key = command[-1]
            return overrides.get(
                key,
                subprocess.CompletedProcess(
                    command, 0, self.outputs.get(key, ""), ""
                ),
            )

        return run

    def test_exact_profile_publishes_verified_summary_and_commands(self):
        calls = []
        with tempfile.TemporaryDirectory() as temporary:
            output = pathlib.Path(temporary) / "evidence"
            summary = self.module.verify_profile(
                PINNED_UDID, output, runner=self.runner(calls=calls)
            )

            self.assertEqual(summary, {
                "schema": 1,
                "result": "verified",
                "udid": PINNED_UDID,
                "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
                "profile": {
                    "locale": "en_US",
                    "languages": ["en-US"],
                    "inputModes": ["en_US@hw=Automatic"],
                    "inputModesExpanded": True,
                },
            })
            self.assertEqual(calls, self.module.verification_plan(PINNED_UDID))
            self.assertEqual(
                json.loads((output / "summary.json").read_text()), summary
            )
            records = json.loads((output / "commands.json").read_text())
            self.assertEqual([record["argv"] for record in records], calls)
            self.assertTrue(all(record["exitCode"] == 0 for record in records))

    def test_plan_is_read_only_and_pinned(self):
        plan = self.module.verification_plan(PINNED_UDID)
        self.assertEqual(len(plan), 6)
        self.assertEqual(plan[:2], [
            ["xcrun", "simctl", "getenv", PINNED_UDID,
             "SIMULATOR_RUNTIME_VERSION"],
            ["xcrun", "simctl", "getenv", PINNED_UDID,
             "SIMULATOR_RUNTIME_BUILD_VERSION"],
        ])
        self.assertEqual(
            [command[-1] for command in plan[2:]],
            ["AppleLocale", "AppleLanguages", "AppleKeyboards",
             "AppleKeyboardsExpanded"],
        )
        flattened = [token for command in plan for token in command]
        for forbidden in (
            "write", "delete", "import", "notifyutil", "launchctl",
            "shutdown", "boot", "erase", "clone", "create",
        ):
            self.assertNotIn(forbidden, flattened)
        with self.assertRaises(self.module.ProfileError):
            self.module.verification_plan("00000000-0000-0000-0000-000000000000")

    def test_every_wrong_profile_field_fails_with_retained_evidence(self):
        cases = {
            "SIMULATOR_RUNTIME_VERSION": "26.4\n",
            "SIMULATOR_RUNTIME_BUILD_VERSION": "23F72\n",
            "AppleLocale": "en_AU\n",
            "AppleLanguages": '(\n    "en-US",\n    "zh-Hans"\n)\n',
            "AppleKeyboards": '(\n    "en_AU@sw=QWERTY;hw=Automatic"\n)\n',
            "AppleKeyboardsExpanded": "0\n",
        }
        for key, value in cases.items():
            with self.subTest(key=key), tempfile.TemporaryDirectory() as temporary:
                output = pathlib.Path(temporary) / "evidence"
                override = subprocess.CompletedProcess([], 0, value, "")
                with self.assertRaises(self.module.ProfileError) as raised:
                    self.module.verify_profile(
                        PINNED_UDID,
                        output,
                        runner=self.runner({key: override}),
                    )
                self.assertIn(key, str(raised.exception))
                summary = json.loads((output / "summary.json").read_text())
                self.assertEqual(summary["result"], "mismatch")
                self.assertEqual(summary["mismatches"][0]["field"], key)

    def test_malformed_defaults_values_fail_closed(self):
        cases = {
            "AppleLanguages": "en-US\n",
            "AppleKeyboards": '(\n    "en_US@hw=Automatic", garbage\n)\n',
            "AppleKeyboardsExpanded": "perhaps\n",
        }
        for key, value in cases.items():
            with self.subTest(key=key), tempfile.TemporaryDirectory() as temporary:
                output = pathlib.Path(temporary) / "evidence"
                override = subprocess.CompletedProcess([], 0, value, "")
                with self.assertRaises(self.module.ProfileError):
                    self.module.verify_profile(
                        PINNED_UDID,
                        output,
                        runner=self.runner({key: override}),
                    )
                summary = json.loads((output / "summary.json").read_text())
                self.assertEqual(summary["result"], "invalid")

    def test_nonzero_command_fails_and_records_only_executed_prefix(self):
        failure = subprocess.CompletedProcess([], 7, "", "denied")
        with tempfile.TemporaryDirectory() as temporary:
            output = pathlib.Path(temporary) / "evidence"
            with self.assertRaises(self.module.ProfileError):
                self.module.verify_profile(
                    PINNED_UDID,
                    output,
                    runner=self.runner({"AppleLanguages": failure}),
                )
            records = json.loads((output / "commands.json").read_text())
            self.assertEqual(len(records), 4)
            self.assertEqual(records[-1]["exitCode"], 7)
            self.assertEqual(records[-1]["stderr"], "denied")

    def test_existing_or_symlink_output_is_refused_without_commands(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for output in (root / "existing", root / "link"):
                calls = []
                if output.name == "existing":
                    output.mkdir()
                else:
                    output.symlink_to(root / "missing")
                with self.subTest(output=output), self.assertRaises(
                    self.module.ProfileError
                ):
                    self.module.verify_profile(
                        PINNED_UDID, output, runner=self.runner(calls=calls)
                    )
                self.assertEqual(calls, [])


class EnglishUSKeyboardProvisionerTests(unittest.TestCase):
    def make_fake_xcrun(self, root):
        binary = root / "xcrun"
        binary.write_text("""#!/bin/zsh
set -eu
print -r -- "$*" >>"$FAKE_XCRUN_LOG"
case "$*" in
  *SIMULATOR_RUNTIME_VERSION) print -r -- "26.5" ;;
  *SIMULATOR_RUNTIME_BUILD_VERSION) print -r -- "23F73" ;;
  *"defaults read NSGlobalDomain AppleLocale") print -r -- "en_US" ;;
  *"defaults read NSGlobalDomain AppleLanguages")
    print -r -- '('
    print -r -- '    "en-US"'
    print -r -- ')'
    ;;
  *"defaults read NSGlobalDomain AppleKeyboards")
    print -r -- '('
    print -r -- '    "en_US@hw=Automatic"'
    print -r -- ')'
    ;;
  *"defaults read NSGlobalDomain AppleKeyboardsExpanded") print -r -- "1" ;;
esac
""", encoding="utf-8")
        binary.chmod(0o755)

    def run_provisioner(self, root, udid=PINNED_UDID, existing=False):
        root.mkdir(parents=True, exist_ok=True)
        fake_bin = root / "bin"
        fake_bin.mkdir()
        self.make_fake_xcrun(fake_bin)
        log = root / "xcrun.log"
        output = root / "evidence"
        if existing:
            output.mkdir()
        environment = dict(os.environ)
        environment["PATH"] = f"{fake_bin}:{environment['PATH']}"
        environment["FAKE_XCRUN_LOG"] = str(log)
        result = subprocess.run(
            [str(ROOT / "Scripts" / "provision-english-us-keyboard.sh"),
             udid, str(output), "--verify"],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )
        calls = log.read_text().splitlines() if log.exists() else []
        return result, output, calls

    def test_complete_profile_is_written_once_before_and_after_one_reboot(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, output, calls = self.run_provisioner(
                pathlib.Path(temporary)
            )
            summary = json.loads(
                (output / "verification" / "summary.json").read_text()
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        writes = [call for call in calls if " defaults write " in f" {call} "]
        expected_writes = [
            "defaults write NSGlobalDomain AppleLocale en_US",
            "defaults write NSGlobalDomain AppleLanguages -array en-US",
            "defaults write NSGlobalDomain AppleKeyboards -array en_US@hw=Automatic",
            "defaults write NSGlobalDomain AppleKeyboardsExpanded -bool YES",
        ]
        for expected in expected_writes:
            matches = [call for call in writes if expected in call]
            self.assertEqual(len(matches), 2, (expected, calls))
        self.assertEqual(sum("simctl shutdown" in call for call in calls), 1)
        self.assertEqual(sum("simctl boot " in f"{call} " for call in calls), 1)
        self.assertEqual(sum("simctl bootstatus" in call for call in calls), 1)
        notification = next(
            index for index, call in enumerate(calls)
            if "notifyutil -p AppleKeyboardsPreferencesChangedNotification" in call
        )
        restart = next(
            index for index, call in enumerate(calls)
            if "launchctl kickstart -k user/501/com.apple.TextInput.kbd" in call
        )
        last_write = max(
            index for index, call in enumerate(calls)
            if " defaults write " in f" {call} "
        )
        self.assertLess(last_write, notification)
        self.assertLess(notification, restart)
        self.assertEqual(summary["result"], "verified")

    def test_invalid_arguments_do_not_invoke_xcrun(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            wrong, _, wrong_calls = self.run_provisioner(
                root / "wrong",
                udid="00000000-0000-0000-0000-000000000000",
            )
            existing, _, existing_calls = self.run_provisioner(
                root / "existing", existing=True
            )
        self.assertEqual(wrong.returncode, 64)
        self.assertEqual(wrong_calls, [])
        self.assertEqual(existing.returncode, 73)
        self.assertEqual(existing_calls, [])


if __name__ == "__main__":
    unittest.main()
