import importlib.util
import json
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    ROOT / "UITests" / "Fixtures" / "ime-keyboard-modes-ios26.5-v1.json"
)
SPEC = importlib.util.spec_from_file_location(
    "ime_keyboard_contract",
    ROOT / "Scripts" / "ime_keyboard_contract.py",
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def contract_payload():
    return json.loads(CONTRACT_PATH.read_text())


class IMEKeyboardContractTests(unittest.TestCase):
    def test_shell_wrapper_is_fail_closed_and_cannot_manage_device_sets(self):
        wrapper = (ROOT / "Scripts" / "provision-ime-keyboards.sh").read_text()
        self.assertIn("set -euo pipefail", wrapper)
        self.assertIn("Refusing overlapping XCTest run", wrapper)
        self.assertIn('rg "$pinned_udid"', wrapper)
        self.assertIn("ime_keyboard_contract.py provision", wrapper)
        self.assertIn('[[ ! -e "$output" ]]', wrapper)
        self.assertNotIn("simctl erase", wrapper)
        self.assertNotIn("simctl create", wrapper)
        self.assertNotIn("simctl clone", wrapper)

    def test_ime_runner_retries_only_exact_keyboard_readiness_failure(self):
        runner = (ROOT / "Scripts" / "run-ime-stock-truth.sh").read_text()
        self.assertIn(
            'Failed to determine hittability of "(k|n)" Key: '
            'Activation point invalid and no suggested hit points based on '
            'element frame',
            runner,
        )
        self.assertIn('rg -q -- "$keyboard_readiness_diagnostic"', runner)
        self.assertNotIn(
            'Failed to determine hittability of ".*" Key:', runner
        )
        self.assertIn("readiness-attempts", runner)
        self.assertIn("retained_attempts", runner)
        self.assertIn("! -name readiness-attempts", runner)
        self.assertIn("attempt < 3", runner)
        self.assertIn("RETRY keyboard-service-not-ready", runner)
        self.assertNotIn("RETRY semantic", runner)
        matrix = (
            ROOT / "Scripts" / "run-ime-complete-matrix.sh"
        ).read_text()
        self.assertNotIn('root.rglob("*.xcresult")', matrix)
        self.assertIn(
            'path.parent / f"{path.parent.name}.xcresult"', matrix
        )

    def test_accepts_exact_ios_26_5_contract(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        self.assertEqual(contract["schema"], 1)
        self.assertEqual(
            [mode["language"] for mode in contract["inputModes"]],
            ["japanese-romaji", "simplified-chinese-pinyin"],
        )
        self.assertEqual(
            [mode["primaryLanguage"] for mode in contract["inputModes"]],
            ["ja-JP", "zh-Hans"],
        )
        self.assertEqual(
            contract["preferenceContract"]["postRebootAllowedIdentifiers"],
            [
                "ru_RU@sw=Russian;hw=Automatic",
                "en_AU@sw=QWERTY;hw=Automatic",
            ],
        )
        self.assertEqual(
            contract["preferenceContract"].get("fixedHostFallbackIdentifier"),
            "en_AU@sw=QWERTY;hw=Automatic",
        )
        self.assertEqual(
            contract["preferenceContract"]["serviceRefresh"],
            "simulator-reboot-then-live-preference-notification-and-"
            "keyboard-service-restart",
        )

    def test_rejects_missing_extra_and_wrong_scalar_types(self):
        fixtures = []
        missing = contract_payload()
        missing.pop("preferenceContract")
        fixtures.append(missing)
        extra = contract_payload()
        extra["unexpected"] = True
        fixtures.append(extra)
        boolean_schema = contract_payload()
        boolean_schema["schema"] = True
        fixtures.append(boolean_schema)
        wrong_modes = contract_payload()
        wrong_modes["inputModes"] = "not-an-array"
        fixtures.append(wrong_modes)
        for payload in fixtures:
            with self.subTest(payload=payload):
                with self.assertRaises(MODULE.ContractError):
                    MODULE.validate_contract(payload)

    def test_rejects_missing_duplicate_or_unknown_modes(self):
        missing = contract_payload()
        missing["inputModes"].pop()
        duplicate = contract_payload()
        duplicate["inputModes"][1] = dict(duplicate["inputModes"][0])
        unknown = contract_payload()
        unknown["inputModes"][1]["language"] = "traditional-chinese"
        for payload in [missing, duplicate, unknown]:
            with self.subTest(payload=payload):
                with self.assertRaises(MODULE.ContractError):
                    MODULE.validate_contract(payload)

    def test_rejects_wrong_udid_runtime_and_build(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        valid = {
            "udid": MODULE.PINNED_UDID,
            "osVersion": "26.5",
            "osBuild": "23F73",
        }
        MODULE.validate_simulator_metadata(contract, valid)
        for key, value in [
            ("udid", "00000000-0000-0000-0000-000000000000"),
            ("osVersion", "26.4"),
            ("osBuild", "23F72"),
        ]:
            metadata = dict(valid)
            metadata[key] = value
            with self.subTest(key=key):
                with self.assertRaises(MODULE.ContractError):
                    MODULE.validate_simulator_metadata(contract, metadata)

    def test_plan_uses_only_pinned_simulator_and_never_creates_or_clones(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        plan = MODULE.provisioning_plan(contract, MODULE.PINNED_UDID)
        self.assertGreater(len(plan), 0)
        flattened = "\n".join(" ".join(command) for command in plan)
        self.assertNotIn(" simctl create ", f" {flattened} ")
        self.assertNotIn(" simctl clone ", f" {flattened} ")
        for command in plan:
            if command[:2] == ["xcrun", "simctl"]:
                self.assertIn(MODULE.PINNED_UDID, command)
        self.assertIn("NSGlobalDomain", flattened)
        self.assertIn("AppleKeyboards", flattened)
        self.assertIn(
            "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic", flattened
        )
        self.assertIn(
            "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic", flattened
        )

    def test_plan_writes_one_fixed_english_fallback_for_host_equivalence(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        plan = MODULE.provisioning_plan(contract, MODULE.PINNED_UDID)
        writes = [
            command for command in plan
            if command[5:8] ==
            ["write", "NSGlobalDomain", "AppleKeyboards"]
        ]
        self.assertEqual(len(writes), 2)
        expected = [
            "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
            "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
            "en_AU@sw=QWERTY;hw=Automatic",
        ]
        self.assertEqual(writes[0][9:], expected)
        self.assertEqual(writes[1][9:], expected)
        shutdown = plan.index([
            "xcrun", "simctl", "shutdown", MODULE.PINNED_UDID,
        ])
        write_indices = [
            index for index, command in enumerate(plan)
            if command[5:8] ==
            ["write", "NSGlobalDomain", "AppleKeyboards"]
        ]
        second_write = write_indices[1]
        notification = [
            "xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
            "notifyutil", "-p",
            "AppleKeyboardsPreferencesChangedNotification",
        ]
        restart = [
            "xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
            "launchctl", "kickstart", "-k",
            "user/501/com.apple.TextInput.kbd",
        ]
        self.assertLess(shutdown, second_write)
        self.assertLess(second_write, plan.index(notification))
        self.assertLess(plan.index(notification), plan.index(restart))

    def test_inventory_requires_each_expected_identifier_exactly_once(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        expected = [
            mode["inputModeIdentifier"] for mode in contract["inputModes"]
        ]
        fallback = ["en_AU@sw=QWERTY;hw=Automatic"]
        MODULE.verify_inventory(contract, expected + fallback)
        for inventory in [
            expected[:1],
            expected + ["ru_RU@sw=Russian;hw=Automatic"],
            expected + fallback +
            ["ru_RU@sw=Russian;hw=Automatic"],
            expected + fallback + fallback,
            expected + expected[:1] + fallback,
            expected + ["emoji@sw=Emoji"],
        ]:
            with self.subTest(inventory=inventory):
                with self.assertRaises(MODULE.ContractError):
                    MODULE.verify_inventory(contract, inventory)

    def test_defaults_inventory_parser_rejects_malformed_output(self):
        valid = """(
    "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
    "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic"
)
"""
        self.assertEqual(
            MODULE.parse_defaults_array(valid),
            [
                "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
                "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
            ],
        )
        for malformed in ["", "{}", "(\\n  1\\n)", "(\\n  unquoted\\n)"]:
            with self.subTest(malformed=malformed):
                with self.assertRaises(MODULE.ContractError):
                    MODULE.parse_defaults_array(malformed)

    def test_execution_is_injected_and_preserves_command_log(self):
        contract = MODULE.load_contract(CONTRACT_PATH)
        expected = [
            mode["inputModeIdentifier"] for mode in contract["inputModes"]
        ] + ["en_AU@sw=QWERTY;hw=Automatic"]
        calls = []

        def runner(command):
            calls.append(command)
            if command[-1] == "SIMULATOR_RUNTIME_VERSION":
                return MODULE.CommandResult(0, "26.5\n", "")
            if command[-1] == "SIMULATOR_RUNTIME_BUILD_VERSION":
                return MODULE.CommandResult(0, "23F73\n", "")
            if command[-3:] == [
                "read", "NSGlobalDomain", "AppleKeyboards",
            ]:
                output = "(\n" + ",\n".join(
                    f'    "{identifier}"' for identifier in expected
                ) + "\n)\n"
                return MODULE.CommandResult(0, output, "")
            return MODULE.CommandResult(0, "", "")

        with tempfile.TemporaryDirectory() as temporary:
            output = pathlib.Path(temporary) / "evidence"
            summary = MODULE.provision(
                contract, MODULE.PINNED_UDID, output, runner=runner
            )
            self.assertEqual(summary["inventory"], expected)
            self.assertEqual(summary["runtime"]["osVersion"], "26.5")
            self.assertTrue((output / "commands.json").is_file())
            self.assertTrue((output / "summary.json").is_file())
            self.assertEqual(calls, MODULE.provisioning_plan(
                contract, MODULE.PINNED_UDID
            ))


class LiveProvisioningTests(unittest.TestCase):
    def setUp(self):
        self.contract = MODULE.load_contract(CONTRACT_PATH)
        self.expected_inventory = [
            "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
            "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
            "en_AU@sw=QWERTY;hw=Automatic",
        ]

    def successful_runner(self, overrides=None):
        overrides = overrides or {}

        def runner(command):
            command_key = tuple(command)
            if command_key in overrides:
                return overrides[command_key]
            if command[-1] == "SIMULATOR_RUNTIME_VERSION":
                return MODULE.CommandResult(0, "26.5\n", "")
            if command[-1] == "SIMULATOR_RUNTIME_BUILD_VERSION":
                return MODULE.CommandResult(0, "23F73\n", "")
            if command[-3:] == [
                "read", "NSGlobalDomain", "AppleKeyboards",
            ]:
                output = "(\n" + ",\n".join(
                    f'    "{identifier}"'
                    for identifier in self.expected_inventory
                ) + "\n)\n"
                return MODULE.CommandResult(0, output, "")
            return MODULE.CommandResult(0, "", "")

        return runner

    def test_live_plan_rewrites_notifies_and_verifies_without_lifecycle_commands(self):
        plan = MODULE.live_provisioning_plan(
            self.contract, MODULE.PINNED_UDID
        )
        flattened = [token for command in plan for token in command]
        self.assertNotIn("shutdown", flattened)
        self.assertNotIn("boot", flattened)
        self.assertNotIn("bootstatus", flattened)
        self.assertEqual(plan, [
            ["xcrun", "simctl", "getenv", MODULE.PINNED_UDID,
             "SIMULATOR_RUNTIME_VERSION"],
            ["xcrun", "simctl", "getenv", MODULE.PINNED_UDID,
             "SIMULATOR_RUNTIME_BUILD_VERSION"],
            ["xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
             "defaults", "write", "NSGlobalDomain", "AppleKeyboards",
             "-array", *self.expected_inventory],
            ["xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
             "defaults", "write", "NSGlobalDomain",
             "AppleKeyboardsExpanded", "-bool", "YES"],
            ["xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
             "notifyutil", "-p",
             "AppleKeyboardsPreferencesChangedNotification"],
            ["xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
             "defaults", "read", "NSGlobalDomain", "AppleKeyboards"],
        ])

    def test_live_provision_publishes_exact_verified_summary_and_commands(self):
        calls = []
        successful = self.successful_runner()

        def runner(command):
            calls.append(command)
            return successful(command)

        with tempfile.TemporaryDirectory() as temporary:
            output = pathlib.Path(temporary) / "live"
            summary = MODULE.live_provision(
                self.contract, MODULE.PINNED_UDID, output, runner=runner
            )
            self.assertEqual(summary, {
                "schema": 1,
                "udid": MODULE.PINNED_UDID,
                "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
                "inventory": self.expected_inventory,
                "primaryLanguages": ["ja-JP", "zh-Hans"],
                "mode": "live-no-reboot",
                "commandCount": 6,
            })
            self.assertEqual(
                calls,
                MODULE.live_provisioning_plan(
                    self.contract, MODULE.PINNED_UDID
                ),
            )
            self.assertEqual(
                json.loads((output / "summary.json").read_text()), summary
            )
            command_records = json.loads(
                (output / "commands.json").read_text()
            )
            self.assertEqual(len(command_records), 6)
            self.assertEqual(
                [record["argv"] for record in command_records], calls
            )

    def test_live_provision_rejects_wrong_runtime_or_build(self):
        plan = [
            ["xcrun", "simctl", "getenv", MODULE.PINNED_UDID,
             "SIMULATOR_RUNTIME_VERSION"],
            ["xcrun", "simctl", "getenv", MODULE.PINNED_UDID,
             "SIMULATOR_RUNTIME_BUILD_VERSION"],
        ]
        for command, value in [(plan[0], "26.4\n"), (plan[1], "23F72\n")]:
            with self.subTest(command=command):
                overrides = {
                    tuple(command): MODULE.CommandResult(0, value, ""),
                }
                with tempfile.TemporaryDirectory() as temporary:
                    with self.assertRaises(MODULE.ContractError):
                        MODULE.live_provision(
                            self.contract,
                            MODULE.PINNED_UDID,
                            pathlib.Path(temporary) / "live",
                            runner=self.successful_runner(overrides),
                        )

    def test_live_provision_rejects_wrong_inventory_order(self):
        read_command = [
            "xcrun", "simctl", "spawn", MODULE.PINNED_UDID,
            "defaults", "read", "NSGlobalDomain", "AppleKeyboards",
        ]
        reordered = list(reversed(self.expected_inventory))
        readback = "(\n" + ",\n".join(
            f'    "{identifier}"' for identifier in reordered
        ) + "\n)\n"
        overrides = {
            tuple(read_command): MODULE.CommandResult(0, readback, ""),
        }
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(MODULE.ContractError):
                MODULE.live_provision(
                    self.contract,
                    MODULE.PINNED_UDID,
                    pathlib.Path(temporary) / "live",
                    runner=self.successful_runner(overrides),
                )

    def test_live_provision_rejects_any_nonzero_command(self):
        plan = MODULE.live_provisioning_plan(
            self.contract, MODULE.PINNED_UDID
        )
        for failed_index in range(len(plan)):
            with self.subTest(failed_index=failed_index):
                overrides = {
                    tuple(plan[failed_index]):
                        MODULE.CommandResult(7, "", "failed"),
                }
                with tempfile.TemporaryDirectory() as temporary:
                    with self.assertRaises(MODULE.ContractError):
                        MODULE.live_provision(
                            self.contract,
                            MODULE.PINNED_UDID,
                            pathlib.Path(temporary) / "live",
                            runner=self.successful_runner(overrides),
                        )

    def test_live_provision_refuses_existing_output_and_wrong_udid(self):
        with tempfile.TemporaryDirectory() as temporary:
            existing = pathlib.Path(temporary) / "existing"
            existing.mkdir()
            with self.assertRaises(MODULE.ContractError):
                MODULE.live_provision(
                    self.contract,
                    MODULE.PINNED_UDID,
                    existing,
                    runner=self.successful_runner(),
                )
            absent = pathlib.Path(temporary) / "absent"
            with self.assertRaises(MODULE.ContractError):
                MODULE.live_provision(
                    self.contract,
                    "00000000-0000-0000-0000-000000000000",
                    absent,
                    runner=self.successful_runner(),
                )
            self.assertFalse(absent.exists())


if __name__ == "__main__":
    unittest.main()
