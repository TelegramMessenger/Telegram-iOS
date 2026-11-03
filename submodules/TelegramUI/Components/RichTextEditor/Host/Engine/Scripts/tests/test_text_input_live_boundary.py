import importlib.util
import json
import os
import pathlib
import plistlib
import sqlite3
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "Scripts" / "text_input_live_boundary.py"
SPEC = importlib.util.spec_from_file_location(
    "text_input_live_boundary", MODULE_PATH
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"
STOCK_BUNDLE = "com.inputdec.stockoracle"
CUSTOM_BUNDLE = "com.inputdec.demo"
KEYBOARD_SERVICE = "user/501/com.apple.TextInput.kbd"
EXPECTED_INVENTORY = [
    "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic",
    "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
    "en_AU@sw=QWERTY;hw=Automatic",
]
EXPECTED_CONTROL_COMMANDS = [
    ["xcrun", "simctl", "terminate", UDID, CUSTOM_BUNDLE],
    ["xcrun", "simctl", "terminate", UDID, STOCK_BUNDLE],
    ["xcrun", "simctl", "spawn", UDID, "launchctl", "disable",
     KEYBOARD_SERVICE],
    ["xcrun", "simctl", "spawn", UDID, "launchctl", "kill", "SIGKILL",
     KEYBOARD_SERVICE],
]
EXPECTED_RESTART_COMMANDS = [
    ["xcrun", "simctl", "spawn", UDID, "launchctl", "enable",
     KEYBOARD_SERVICE],
    ["xcrun", "simctl", "spawn", UDID, "launchctl", "kickstart", "-k",
     KEYBOARD_SERVICE],
]


def defaults_output(inventory=EXPECTED_INVENTORY):
    return "(\n" + ",\n".join(
        f'    "{identifier}"' for identifier in inventory
    ) + "\n)\n"


class RecordingRunner:
    def __init__(self, overrides=None, on_command=None):
        self.calls = []
        self.call_kwargs = []
        self.overrides = overrides or {}
        self.on_command = on_command

    def __call__(self, command, **kwargs):
        self.calls.append(command)
        self.call_kwargs.append(kwargs)
        if self.on_command is not None:
            self.on_command(command)
        override = self.overrides.get(tuple(command))
        if override is not None:
            return override
        if command[-1] == "SIMULATOR_RUNTIME_VERSION":
            stdout = "26.5\n"
        elif command[-1] == "SIMULATOR_RUNTIME_BUILD_VERSION":
            stdout = "23F73\n"
        elif command[-3:] == [
            "read", "NSGlobalDomain", "AppleKeyboards",
        ]:
            stdout = defaults_output()
        else:
            stdout = ""
        return subprocess.CompletedProcess(command, 0, stdout, "")


class TextInputLiveBoundaryTests(unittest.TestCase):
    def run_boundary(self, root, runner=None, udid=UDID, output_name="result"):
        root = pathlib.Path(root)
        device = root / "device"
        (device / "Library" / "Keyboard").mkdir(parents=True)
        output = root / output_name
        runner = runner or RecordingRunner()
        summary = MODULE.run_boundary_reset(
            udid, device, output, runner=runner
        )
        return summary, device, output, runner

    def snapshot_inputs(self, root):
        root = pathlib.Path(root)
        snapshot = root / "snapshot"
        snapshot.mkdir()
        preferences = (
            snapshot / "tree" / "Library" / "Preferences" /
            "com.apple.keyboard.preferences.plist"
        )
        preferences.parent.mkdir(parents=True)
        preferences.write_bytes(plistlib.dumps({
            "DictationLanguagesEnabled": {"en_US": True},
            "KeyboardLastUsed": "en_US@sw=QWERTY;hw=Automatic",
        }))
        identity = root / "identity.json"
        identity_value = {
            "schema": 1,
            "udid": UDID,
            "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
            "locale": "en_US",
            "inputModes": ["en_US@sw=QWERTY;hw=Automatic"],
            "manifestFormat": 1,
        }
        identity.write_text(json.dumps(identity_value))
        return snapshot, identity, identity_value

    def test_snapshot_restore_replaces_cached_keyboard_preferences_exactly(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, identity_value = self.snapshot_inputs(root)
            cached_domain = {
                "DictationLanguagesEnabled": {
                    "en_US": True,
                    "ru_RU": True,
                },
                "KeyboardLastUsed": "ru_RU@sw=Russian;hw=Automatic",
                "KeyboardsCurrentAndNext": [
                    "ru_RU@sw=Russian;hw=Automatic",
                ],
            }
            service_disabled = False

            def emulate_cached_preferences(command):
                nonlocal cached_domain, service_disabled
                if command == EXPECTED_CONTROL_COMMANDS[2]:
                    service_disabled = True
                elif command == EXPECTED_RESTART_COMMANDS[0]:
                    service_disabled = False
                elif command[-3:] == [
                    "defaults", "delete", "com.apple.keyboard.preferences",
                ]:
                    self.assertTrue(service_disabled)
                    cached_domain = {}
                elif command[-4:] == [
                    "defaults", "import", "com.apple.keyboard.preferences",
                    "-",
                ]:
                    self.assertTrue(service_disabled)
                if any(pathlib.Path(token).name ==
                       "text_input_keyboard_snapshot.py" for token in command):
                    output = pathlib.Path(
                        command[command.index("--output") + 1]
                    )
                    output.mkdir()
                    (output / "summary.json").write_text(json.dumps({
                        "schema": 1,
                        "result": "restored",
                        "identity": identity_value,
                        "roots": [
                            "Library/Keyboard",
                            "Library/Preferences/"
                            "com.apple.keyboard.preferences.plist",
                        ],
                        "baselineManifestSHA256": "a" * 64,
                        "restoredManifestSHA256": "a" * 64,
                    }))

            probe = [
                "xcrun", "simctl", "spawn", UDID, "defaults", "read",
                "NSGlobalDomain", "AppleKeyboards",
            ]
            runner = RecordingRunner({
                tuple(probe): subprocess.CompletedProcess(
                    probe, 0, defaults_output(identity_value["inputModes"]),
                    "",
                ),
            }, on_command=emulate_cached_preferences)

            MODULE.run_boundary_reset(
                UDID, device, root / "result", runner=runner,
                keyboard_snapshot=snapshot, identity=identity,
            )

            import_index = next(
                index for index, command in enumerate(runner.calls)
                if command[-4:] == [
                    "defaults", "import", "com.apple.keyboard.preferences",
                    "-",
                ]
            )
            imported = plistlib.loads(
                runner.call_kwargs[import_index]["input"].encode("utf-8")
            )
            self.assertEqual(imported, {
                "DictationLanguagesEnabled": {"en_US": True},
                "KeyboardLastUsed": "en_US@sw=QWERTY;hw=Automatic",
            })
            cached_domain = imported
            self.assertNotIn("ru_RU", repr(cached_domain))
            self.assertLess(
                import_index, runner.calls.index(EXPECTED_RESTART_COMMANDS[0])
            )

    def test_snapshot_restore_is_service_safe_and_hash_authoritative(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, identity_value = self.snapshot_inputs(root)
            restore_summary = {
                "schema": 1,
                "result": "restored",
                "identity": identity_value,
                "roots": ["Library/Keyboard"],
                "baselineManifestSHA256": "a" * 64,
                "restoredManifestSHA256": "a" * 64,
            }

            def publish_restore(command):
                if not any(
                    pathlib.Path(token).name ==
                    "text_input_keyboard_snapshot.py"
                    for token in command
                ):
                    return
                output = pathlib.Path(command[command.index("--output") + 1])
                output.mkdir()
                (output / "summary.json").write_text(
                    json.dumps(restore_summary)
                )

            probe = [
                "xcrun", "simctl", "spawn", UDID, "defaults", "read",
                "NSGlobalDomain", "AppleKeyboards",
            ]
            runner = RecordingRunner(
                {
                    tuple(probe): subprocess.CompletedProcess(
                        probe, 0, defaults_output(identity_value["inputModes"]),
                        "",
                    ),
                },
                on_command=publish_restore,
            )
            summary = MODULE.run_boundary_reset(
                UDID, device, root / "result", runner=runner,
                keyboard_snapshot=snapshot, identity=identity,
            )

            restore_command = [
                sys.executable,
                str(ROOT / "Scripts" / "text_input_keyboard_snapshot.py"),
                "restore", "--device-root", str(device.resolve()),
                "--snapshot", str(snapshot.resolve()),
                "--identity", str(identity.resolve()),
                "--output",
                str(root / f".result.partial-{os.getpid()}" /
                    "snapshot-restore"),
            ]
            restore_inventory_commands = [
                ["xcrun", "simctl", "spawn", UDID, "defaults", "write",
                 "NSGlobalDomain", "AppleKeyboards", "-array",
                 "en_US@sw=QWERTY;hw=Automatic"],
                ["xcrun", "simctl", "spawn", UDID, "notifyutil", "-p",
                 "AppleKeyboardsPreferencesChangedNotification"],
            ]
            restore_preferences_commands = [
                ["xcrun", "simctl", "spawn", UDID, "defaults", "delete",
                 "com.apple.keyboard.preferences"],
                ["xcrun", "simctl", "spawn", UDID, "defaults", "import",
                 "com.apple.keyboard.preferences", "-"],
            ]
            self.assertEqual(runner.calls, [
                *EXPECTED_CONTROL_COMMANDS,
                restore_command,
                *restore_preferences_commands,
                *EXPECTED_RESTART_COMMANDS,
                *restore_inventory_commands,
                probe,
            ])
            self.assertEqual(summary, restore_summary)
            self.assertEqual(
                json.loads((root / "result" / "summary.json").read_text()),
                restore_summary,
            )

    def test_snapshot_restore_repairs_inventory_changed_outside_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, identity_value = self.snapshot_inputs(root)
            expected_inventory = identity_value["inputModes"]
            live_inventory = [
                "en_US@sw=QWERTY;hw=Automatic",
                "ru_RU@sw=Russian;hw=Automatic",
            ]
            probe = [
                "xcrun", "simctl", "spawn", UDID, "defaults", "read",
                "NSGlobalDomain", "AppleKeyboards",
            ]

            def emulate_restore_and_preferences(command):
                nonlocal live_inventory
                if any(pathlib.Path(token).name ==
                       "text_input_keyboard_snapshot.py" for token in command):
                    output = pathlib.Path(
                        command[command.index("--output") + 1]
                    )
                    output.mkdir()
                    (output / "summary.json").write_text(json.dumps({
                        "schema": 1,
                        "result": "restored",
                        "identity": identity_value,
                        "roots": ["Library/Keyboard"],
                        "baselineManifestSHA256": "a" * 64,
                        "restoredManifestSHA256": "a" * 64,
                    }))
                if command[:9] == [
                    "xcrun", "simctl", "spawn", UDID, "defaults", "write",
                    "NSGlobalDomain", "AppleKeyboards", "-array",
                ]:
                    live_inventory = command[9:]

            class InventoryRunner(RecordingRunner):
                def __call__(self, command, **kwargs):
                    if command == probe:
                        self.overrides[tuple(probe)] = subprocess.CompletedProcess(
                            probe, 0, defaults_output(live_inventory), ""
                        )
                    return super().__call__(command, **kwargs)

            runner = InventoryRunner(on_command=emulate_restore_and_preferences)
            summary = MODULE.run_boundary_reset(
                UDID, device, root / "result", runner=runner,
                keyboard_snapshot=snapshot, identity=identity,
            )

            self.assertEqual(summary["result"], "restored")
            self.assertEqual(live_inventory, expected_inventory)
            write_index = next(index for index, command in enumerate(runner.calls)
                               if command[:9] == [
                                   "xcrun", "simctl", "spawn", UDID,
                                   "defaults", "write", "NSGlobalDomain",
                                   "AppleKeyboards", "-array",
                               ])
            self.assertGreater(
                write_index, runner.calls.index(EXPECTED_RESTART_COMMANDS[-1])
            )

    def test_snapshot_restore_never_runs_after_service_shutdown_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, _ = self.snapshot_inputs(root)
            kill = EXPECTED_CONTROL_COMMANDS[-1]
            runner = RecordingRunner({
                tuple(kill): subprocess.CompletedProcess(
                    kill, 7, "", "shutdown failed"
                ),
            })
            with self.assertRaises(MODULE.BoundaryResetError):
                MODULE.run_boundary_reset(
                    UDID, device, root / "result", runner=runner,
                    keyboard_snapshot=snapshot, identity=identity,
                )
            self.assertFalse(any(
                any(
                    pathlib.Path(token).name ==
                    "text_input_keyboard_snapshot.py"
                    for token in command
                )
                for command in runner.calls
            ))
            self.assertEqual(runner.calls[-2:], EXPECTED_RESTART_COMMANDS)

    def test_snapshot_restore_exception_still_restarts_keyboard_service(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, _ = self.snapshot_inputs(root)

            def fail_restore(command):
                if any(
                    pathlib.Path(token).name ==
                    "text_input_keyboard_snapshot.py"
                    for token in command
                ):
                    raise RuntimeError("restore exploded")

            runner = RecordingRunner(on_command=fail_restore)
            with self.assertRaisesRegex(RuntimeError, "restore exploded"):
                MODULE.run_boundary_reset(
                    UDID, device, root / "result", runner=runner,
                    keyboard_snapshot=snapshot, identity=identity,
                )
            self.assertEqual(runner.calls[-2:], EXPECTED_RESTART_COMMANDS)
            self.assertFalse((root / "result").exists())

    def test_snapshot_restore_rejects_manifest_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            snapshot, identity, identity_value = self.snapshot_inputs(root)

            def publish_mismatch(command):
                if not any(
                    pathlib.Path(token).name ==
                    "text_input_keyboard_snapshot.py"
                    for token in command
                ):
                    return
                output = pathlib.Path(command[command.index("--output") + 1])
                output.mkdir()
                (output / "summary.json").write_text(json.dumps({
                    "schema": 1,
                    "result": "restored",
                    "identity": identity_value,
                    "roots": ["Library/Keyboard"],
                    "baselineManifestSHA256": "a" * 64,
                    "restoredManifestSHA256": "b" * 64,
                }))

            probe = [
                "xcrun", "simctl", "spawn", UDID, "defaults", "read",
                "NSGlobalDomain", "AppleKeyboards",
            ]
            runner = RecordingRunner(
                {
                    tuple(probe): subprocess.CompletedProcess(
                        probe, 0, defaults_output(identity_value["inputModes"]),
                        "",
                    ),
                },
                on_command=publish_mismatch,
            )
            with self.assertRaises(MODULE.BoundaryResetError):
                MODULE.run_boundary_reset(
                    UDID, device, root / "result", runner=runner,
                    keyboard_snapshot=snapshot, identity=identity,
                )
            restart_index = runner.calls.index(EXPECTED_RESTART_COMMANDS[0])
            self.assertEqual(
                runner.calls[restart_index:restart_index + 2],
                EXPECTED_RESTART_COMMANDS,
            )
            self.assertFalse((root / "result").exists())

    def test_boundary_runs_exact_control_live_provision_and_restart_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            runner = RecordingRunner({
                tuple(EXPECTED_CONTROL_COMMANDS[0]):
                    subprocess.CompletedProcess(
                        EXPECTED_CONTROL_COMMANDS[0], 3, "", "not running"
                    ),
            })
            summary, _, output, runner = self.run_boundary(
                temporary, runner=runner
            )

            self.assertEqual(runner.calls[:4], EXPECTED_CONTROL_COMMANDS)
            self.assertEqual(runner.calls[-2:], EXPECTED_RESTART_COMMANDS)
            live_commands = runner.calls[4:-2]
            self.assertEqual(len(live_commands), 6)
            flattened = [token for command in live_commands for token in command]
            self.assertNotIn("shutdown", flattened)
            self.assertNotIn("boot", flattened)
            self.assertNotIn("bootstatus", flattened)
            self.assertEqual(summary["schema"], 1)
            self.assertEqual(summary["runtime"], {
                "osVersion": "26.5", "osBuild": "23F73",
            })
            self.assertEqual(summary["udid"], UDID)
            self.assertEqual(summary["result"], "Passed")
            self.assertEqual(summary["provisioning"]["mode"], "live-no-reboot")
            self.assertEqual(
                summary["postState"]["rejectionTableCounts"],
                {"rejections": 0, "inline_completion_rejections": 0},
            )
            self.assertEqual(summary["postState"]["dynamicLexicons"], [])
            self.assertEqual(
                json.loads((output / "summary.json").read_text()), summary
            )
            timing = json.loads((output / "timing.json").read_text())
            self.assertEqual(timing["schema"], 1)
            self.assertGreaterEqual(timing["totalSeconds"], 0)
            command_records = json.loads(
                (output / "commands.json").read_text()
            )
            self.assertEqual(
                [record["argv"] for record in command_records], runner.calls
            )
            self.assertEqual(len(command_records), 12)
            self.assertTrue(all(
                record["elapsedSeconds"] >= 0 for record in command_records
            ))
            self.assertTrue(
                (output / "learning-reset" / "summary.json").is_file()
            )
            self.assertTrue(
                (output / "provisioning" / "summary.json").is_file()
            )
            self.assertTrue((output / "post-state.json").is_file())

    def test_any_nonzero_control_command_other_than_absent_terminate_fails(self):
        for failed_index in range(4):
            with self.subTest(failed_index=failed_index):
                command = EXPECTED_CONTROL_COMMANDS[failed_index]
                returncode = 4 if failed_index < 2 else 3
                runner = RecordingRunner({
                    tuple(command): subprocess.CompletedProcess(
                        command, returncode, "", "failed"
                    ),
                })
                with tempfile.TemporaryDirectory() as temporary:
                    root = pathlib.Path(temporary)
                    device = root / "device"
                    device.mkdir()
                    with self.assertRaises(MODULE.BoundaryResetError):
                        MODULE.run_boundary_reset(
                            UDID, device, root / "result", runner=runner
                        )

    def test_learning_reset_failure_still_restarts_keyboard_service(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            database = (
                device / "Library" / "Keyboard" /
                "AutocorrectionRejections.db"
            )
            database.parent.mkdir(parents=True)
            connection = sqlite3.connect(database)
            connection.execute("CREATE TABLE unexpected (value TEXT)")
            connection.close()
            runner = RecordingRunner()

            with self.assertRaises(Exception):
                MODULE.run_boundary_reset(
                    UDID, device, root / "result", runner=runner
                )

            self.assertEqual(runner.calls[-2:], EXPECTED_RESTART_COMMANDS)
            self.assertFalse((root / "result").exists())

    def test_either_keyboard_restart_failure_fails_closed(self):
        for failed_command in EXPECTED_RESTART_COMMANDS:
            with self.subTest(failed_command=failed_command):
                runner = RecordingRunner({
                    tuple(failed_command): subprocess.CompletedProcess(
                        failed_command, 5, "", "restart failed"
                    ),
                })
                with tempfile.TemporaryDirectory() as temporary:
                    root = pathlib.Path(temporary)
                    device = root / "device"
                    device.mkdir()
                    with self.assertRaises(MODULE.BoundaryResetError):
                        MODULE.run_boundary_reset(
                            UDID, device, root / "result", runner=runner
                        )
                    self.assertFalse((root / "result").exists())

    def test_inventory_mismatch_and_wrong_runtime_are_rejected(self):
        read_command = [
            "xcrun", "simctl", "spawn", UDID, "defaults", "read",
            "NSGlobalDomain", "AppleKeyboards",
        ]
        runtime_command = [
            "xcrun", "simctl", "getenv", UDID,
            "SIMULATOR_RUNTIME_VERSION",
        ]
        cases = [
            (read_command, subprocess.CompletedProcess(
                read_command, 0,
                defaults_output(list(reversed(EXPECTED_INVENTORY))), ""
            )),
            (runtime_command, subprocess.CompletedProcess(
                runtime_command, 0, "26.4\n", ""
            )),
        ]
        for command, result in cases:
            with self.subTest(command=command):
                runner = RecordingRunner({tuple(command): result})
                with tempfile.TemporaryDirectory() as temporary:
                    root = pathlib.Path(temporary)
                    device = root / "device"
                    device.mkdir()
                    with self.assertRaises(Exception):
                        MODULE.run_boundary_reset(
                            UDID, device, root / "result", runner=runner
                        )
                    self.assertEqual(
                        runner.calls[-2:], EXPECTED_RESTART_COMMANDS
                    )

    def test_nonempty_post_state_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            keyboard = device / "Library" / "Keyboard"
            keyboard.mkdir(parents=True)

            def recreate_learning(command):
                if command == EXPECTED_RESTART_COMMANDS[-1]:
                    database = keyboard / "AutocorrectionRejections.db"
                    connection = sqlite3.connect(database)
                    connection.execute("CREATE TABLE rejections (value TEXT)")
                    connection.execute(
                        "CREATE TABLE inline_completion_rejections "
                        "(value TEXT)"
                    )
                    connection.execute("INSERT INTO rejections VALUES ('x')")
                    connection.commit()
                    connection.close()

            runner = RecordingRunner(on_command=recreate_learning)
            with self.assertRaises(MODULE.BoundaryResetError):
                MODULE.run_boundary_reset(
                    UDID, device, root / "result", runner=runner
                )
            self.assertFalse((root / "result").exists())

    def test_existing_output_wrong_udid_and_symlinked_device_root_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            device = root / "device"
            device.mkdir()
            existing = root / "existing"
            existing.mkdir()
            runner = RecordingRunner()
            for udid, device_root, output in [
                (UDID, device, existing),
                ("not-k3", device, root / "wrong-udid"),
            ]:
                with self.subTest(udid=udid, output=output):
                    with self.assertRaises(MODULE.BoundaryResetError):
                        MODULE.run_boundary_reset(
                            udid, device_root, output, runner=runner
                        )
            link = root / "device-link"
            link.symlink_to(device, target_is_directory=True)
            with self.assertRaises(MODULE.BoundaryResetError):
                MODULE.run_boundary_reset(
                    UDID, link, root / "symlink", runner=runner
                )
            self.assertEqual(runner.calls, [])


if __name__ == "__main__":
    unittest.main()
