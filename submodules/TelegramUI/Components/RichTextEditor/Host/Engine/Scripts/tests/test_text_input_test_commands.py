import os
import json
import pathlib
import plistlib
import subprocess
import tempfile
import time
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "Scripts"
FAST_RUNNER = SCRIPTS / "run-text-input-fast.sh"
KEYBOARD_SENTINEL_RUNNER = (
    SCRIPTS / "run-text-input-keyboard-sentinels.sh"
)
CERTIFICATION_RUNNER = SCRIPTS / "run-text-input-ios26-certification.sh"
LOCK_RUNNER = SCRIPTS / "with-inputdec-simulator-test-lock.sh"
BATCH_RUNNER = SCRIPTS / "run-text-input-batch.sh"
GROUP_RUNNER = SCRIPTS / "run-text-input-group.sh"
BATCHED_CERTIFICATION_RUNNER = (
    SCRIPTS / "run-text-input-batched-certification.sh"
)
SNAPSHOT_PROOF_RUNNER = (
    SCRIPTS / "run-inline-prediction-snapshot-proof.sh"
)
VERIFICATION_STABILIZATION_RUNNER = (
    SCRIPTS / "run-verification-stabilization.sh"
)
AUTOCORRECTION_BATCHES = (
    ROOT
    / "UITests"
    / "Fixtures"
    / "text-input-autocorrection-batches-ios26.5-v1.json"
)
INLINE_PREDICTION_BATCHES = (
    ROOT
    / "UITests"
    / "Fixtures"
    / "text-input-inline-prediction-batches-ios26.5-v1.json"
)
PINNED_UDID = "FA6F7462-AA97-42FE-9E57-8DA0593CE756"


class TextInputTestCommandTests(unittest.TestCase):
    def _verification_stabilization_environment(self, temporary, scenario):
        root = pathlib.Path(temporary)
        tools = root / "bin"
        tools.mkdir()
        log = root / "commands.log"
        observation = {
            "schema": 2,
            "status": "ready",
            "currentPrimaryLanguage": "en-US",
            "inputPrimaryLanguage": "en-US",
            "continuousCheckingEnabled": True,
            "temporaryAnnotationObserved": True,
            "markerPixelCount": 4,
            "elapsedSeconds": 0.1,
            "word": "wrng",
            "wordRange": {"location": 10, "length": 4},
            "firstRect": {
                "x": 82.33333333333333,
                "y": 7,
                "width": 38.333333333333336,
                "height": 22,
            },
            "markerROI": {
                "x": 79.33333333333333,
                "y": 2,
                "width": 44.333333333333336,
                "height": 32,
            },
        }
        fake_xcodebuild = tools / "xcodebuild"
        fake_xcodebuild.write_text(
            "#!/bin/zsh\n"
            "print -r -- \"xcodebuild $*\" >>\"$FAKE_COMMAND_LOG\"\n"
            "result=\"\"\n"
            "for (( i=1; i <= $#; i++ )); do\n"
            "  [[ \"${@[i]}\" != -resultBundlePath ]] || result=\"${@[i+1]}\"\n"
            "done\n"
            "[[ -z \"$result\" ]] || mkdir -p \"$result\"\n"
            "[[ \" $* \" == *' build-for-testing '* ]] && exit 0\n"
            "if [[ \"$result\" == *spelling-preflight-attempt-1* && "
            "   \"$FAKE_SCENARIO\" == stock-then-ready ]]; then exit 65; fi\n"
            "if [[ \"$result\" == *spelling-preflight* && "
            "   \"$FAKE_SCENARIO\" == unavailable-twice ]]; then exit 65; fi\n"
            "if [[ \"$result\" == *spelling-family* && "
            "   \"$FAKE_SCENARIO\" == custom-divergence ]]; then exit 65; fi\n"
            "exit 0\n"
        )
        fake_xcrun = tools / "xcrun"
        fake_xcrun.write_text(
            "#!/bin/zsh\n"
            "print -r -- \"xcrun $*\" >>\"$FAKE_COMMAND_LOG\"\n"
            "if [[ \"${1:-}\" == simctl ]]; then\n"
            "  case \"${@: -1}\" in\n"
            "    SIMULATOR_RUNTIME_VERSION) print -r -- '26.5' ;;\n"
            "    SIMULATOR_RUNTIME_BUILD_VERSION) print -r -- '23F73' ;;\n"
            "    AppleLocale)\n"
            "      [[ \"$FAKE_SCENARIO\" == profile-mismatch ]] && "
            "print -r -- 'en_AU' || print -r -- 'en_US' ;;\n"
            "    AppleLanguages) print -r -- '(\n    \"en-US\"\n)' ;;\n"
            "    AppleKeyboards) print -r -- "
            "'(\n    \"en_US@hw=Automatic\"\n)' ;;\n"
            "    AppleKeyboardsExpanded) print -r -- '1' ;;\n"
            "  esac\n"
            "  exit 0\n"
            "fi\n"
            "xcresult_path=\"\"; output=\"\"\n"
            "for (( i=1; i <= $#; i++ )); do\n"
            "  [[ \"${@[i]}\" != --path ]] || xcresult_path=\"${@[i+1]}\"\n"
            "  [[ \"${@[i]}\" != --output-path ]] || output=\"${@[i+1]}\"\n"
            "done\n"
            "unavailable=0\n"
            "[[ \"$FAKE_SCENARIO\" != unavailable-twice ]] || unavailable=1\n"
            "if [[ \"$FAKE_SCENARIO\" == stock-then-ready && "
            "   \"$xcresult_path\" == *attempt-1* ]]; then unavailable=1; fi\n"
            "if [[ \" $* \" == *' test-results summary '* ]]; then\n"
            "  if [[ \"$xcresult_path\" == *spelling-family* ]]; then\n"
            "    if [[ \"$FAKE_SCENARIO\" == custom-divergence ]]; then\n"
            "      print -r -- '{\"totalTestCount\":5,\"passedTests\":4,"
            "\"failedTests\":1,\"skippedTests\":0,\"testFailures\":[{"
            "\"failureText\":\"custom pixel mismatch\"}]}'\n"
            "    else\n"
            "      print -r -- '{\"totalTestCount\":5,\"passedTests\":5,"
            "\"failedTests\":0,\"skippedTests\":0,\"testFailures\":[]}'\n"
            "    fi\n"
            "  elif (( unavailable )); then\n"
            "    print -r -- '{\"totalTestCount\":1,\"passedTests\":0,"
            "\"failedTests\":1,\"skippedTests\":0,\"testFailures\":[{"
            "\"testIdentifierString\":\"IDSpellingReadinessProbeTests/"
            "testStockTextViewSpellingEnvironmentIsReady\","
            "\"failureText\":\"IDSpellingReadiness:stockUnavailable:"
            "temporaryAnnotationUnavailable evidence={}\"}]}'\n"
            "  else\n"
            "    print -r -- '{\"totalTestCount\":1,\"passedTests\":1,"
            "\"failedTests\":0,\"skippedTests\":0,\"testFailures\":[]}'\n"
            "  fi\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \" $* \" == *' export attachments '* ]]; then\n"
            "  mkdir -p \"$output\"\n"
            "  if (( unavailable )); then\n"
            "    print -r -- \"$FAKE_UNAVAILABLE_OBSERVATION\" >"
            "\"$output/stock-spelling-readiness.json\"\n"
            "  else\n"
            "    print -r -- \"$FAKE_READY_OBSERVATION\" >"
            "\"$output/stock-spelling-readiness.json\"\n"
            "  fi\n"
            "  : >\"$output/stock-spelling-readiness.png\"\n"
            "  exit 0\n"
            "fi\n"
            "exit 64\n"
        )
        fake_xcodebuild.chmod(0o755)
        fake_xcrun.chmod(0o755)
        unavailable = dict(observation)
        unavailable.update({
            "status": "temporaryAnnotationUnavailable",
            "temporaryAnnotationObserved": False,
            "markerPixelCount": 0,
        })
        environment = os.environ.copy()
        environment.update({
            "PATH": f"{tools}:{environment['PATH']}",
            "INPUTDEC_XCTEST_LOCK_ROOT": str(root / "locks"),
            "FAKE_COMMAND_LOG": str(log),
            "FAKE_SCENARIO": scenario,
            "FAKE_READY_OBSERVATION": json.dumps(observation),
            "FAKE_UNAVAILABLE_OBSERVATION": json.dumps(unavailable),
        })
        return environment, log

    def test_verification_stabilization_runner_is_serial_and_non_destructive(self):
        self.assertTrue(VERIFICATION_STABILIZATION_RUNNER.is_file())
        source = VERIFICATION_STABILIZATION_RUNNER.read_text()
        for token in (
            "with-inputdec-simulator-test-lock.sh",
            "xcodebuild build-for-testing",
            "xcodebuild test-without-building",
            "-parallel-testing-enabled NO",
            "-maximum-concurrent-test-simulator-destinations 1",
            "-parallel-testing-worker-count 1",
            "-maximum-parallel-testing-workers 1",
            "english_us_keyboard_profile.py",
        ):
            self.assertIn(token, source)
        for forbidden in (
            "simctl boot", "simctl shutdown", "simctl erase",
            "simctl create", "simctl clone", "Library/Keyboard",
            "reset-text-input-learning",
        ):
            self.assertNotIn(forbidden, source)

    def test_verification_stabilization_runner_branches_once_and_preserves(self):
        expectations = {
            "ready": (0, "ready", 0, 3),
            "stock-then-ready": (65, "stockUnavailable", 0, 2),
            "unavailable-twice": (65, "stockUnavailable", 0, 2),
            "custom-divergence": (65, "customDivergence", 0, 3),
        }
        for scenario, expected in expectations.items():
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as temporary:
                environment, log = self._verification_stabilization_environment(
                    temporary, scenario
                )
                output = pathlib.Path(temporary) / "output"
                completed = subprocess.run(
                    [str(VERIFICATION_STABILIZATION_RUNNER),
                     "--udid", PINNED_UDID, "--output", str(output)],
                    cwd=ROOT, env=environment, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                )
                status, classification, restarts, build_count = expected
                self.assertEqual(completed.returncode, status, completed.stderr)
                summary = json.loads((output / "summary.json").read_text())
                self.assertEqual(summary["classification"], classification)
                self.assertEqual(summary["serviceRestarts"], restarts)
                commands = log.read_text().splitlines()
                builds = [line for line in commands if line.startswith("xcodebuild")]
                self.assertEqual(len(builds), build_count)
                self.assertEqual(sum("build-for-testing" in line for line in builds), 1)
                for line in builds:
                    for token in (
                        PINNED_UDID,
                        "-parallel-testing-enabled NO",
                        "-maximum-concurrent-test-simulator-destinations 1",
                        "-parallel-testing-worker-count 1",
                        "-maximum-parallel-testing-workers 1",
                    ):
                        self.assertIn(token, line)
                self.assertEqual(
                    sum("launchctl kickstart" in line for line in commands),
                    restarts,
                )
                self.assertTrue((output / "spelling-preflight-attempt-1").is_dir())
                self.assertFalse(
                    (output / "spelling-preflight-attempt-2").exists()
                )
                family_calls = sum("spelling-family" in line for line in builds)
                self.assertEqual(family_calls, 0 if classification == "stockUnavailable" else 1)
                if scenario == "ready":
                    first = (output / "spelling-preflight-attempt-1" /
                             "classification.json")
                    preserved = first.read_bytes()
                    command_count = len(commands)
                    repeated = subprocess.run(
                        [str(VERIFICATION_STABILIZATION_RUNNER),
                         "--udid", PINNED_UDID, "--output", str(output)],
                        cwd=ROOT, env=environment, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    )
                    self.assertEqual(repeated.returncode, 73)
                    self.assertEqual(first.read_bytes(), preserved)
                    self.assertEqual(
                        len(log.read_text().splitlines()), command_count
                    )

    def test_verification_stabilization_profile_mismatch_stops_before_xcode(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._verification_stabilization_environment(
                temporary, "profile-mismatch"
            )
            output = pathlib.Path(temporary) / "output"
            completed = subprocess.run(
                [str(VERIFICATION_STABILIZATION_RUNNER),
                 "--udid", PINNED_UDID, "--output", str(output)],
                cwd=ROOT, env=environment, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            self.assertEqual(completed.returncode, 65)
            self.assertIn(
                "Scripts/provision-english-us-keyboard.sh",
                completed.stderr,
            )
            commands = log.read_text().splitlines()
            self.assertTrue(commands)
            self.assertFalse(any(line.startswith("xcodebuild") for line in commands))
            profile = json.loads(
                (output / "english-us-profile" / "summary.json").read_text()
            )
            self.assertEqual(profile["result"], "mismatch")

    def test_verification_stabilization_without_building_reuses_products(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._verification_stabilization_environment(
                temporary, "ready"
            )
            output = pathlib.Path(temporary) / "output"
            completed = subprocess.run(
                [str(VERIFICATION_STABILIZATION_RUNNER),
                 "--udid", PINNED_UDID, "--output", str(output),
                 "--without-building"],
                cwd=ROOT, env=environment, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            builds = [line for line in log.read_text().splitlines()
                      if line.startswith("xcodebuild")]
            self.assertEqual(len(builds), 2)
            self.assertTrue(all("test-without-building" in line
                                for line in builds))

    def test_batched_coordinator_is_locked_build_once_and_complete(self):
        self.assertTrue(BATCHED_CERTIFICATION_RUNNER.is_file())
        source = BATCHED_CERTIFICATION_RUNNER.read_text()
        for token in [
            PINNED_UDID,
            "with-inputdec-simulator-test-lock.sh",
            "run-text-input-group.sh",
            "text-input-ime-batches-ios26.5-v1.json",
            "text-input-autocorrection-batches-ios26.5-v1.json",
            "text-input-inline-prediction-batches-ios26.5-v1.json",
            "xcodebuild build-for-testing",
            "-parallel-testing-enabled NO",
            "INPUTDEC_BATCH_XCTESTRUN",
            "prepare-inline-keyboard-baseline.sh",
            "inline-keyboard-snapshot-v1",
            "--prepared-device",
            "--keyboard-snapshot",
            '"comparisons": 216',
            '"hostObservations": 432',
            '"groups": 28',
            '"erasedBoots": 20',
            '"successfulXCTestInvocations": 28',
            '"successfulBoundaries": 344',
            '"successfulHostBoundaries": 180',
            '"successfulPassBoundaries": 84',
            '"successfulRowBoundaries": 80',
            "hostResetSeconds",
            "rowResetSeconds",
            '"batches": 112',
            '"repetitions": [1, 2]',
            '"orders": ["stock-custom", "custom-stock"]',
            ".summary.partial-$$",
            "wall_seconds > 3600",
            "INPUTDEC_BATCH_TESTING",
            "INPUTDEC_BATCH_TEST_GROUP_IDS",
        ]:
            self.assertIn(token, source)
        self.assertEqual(source.count("run-text-input-group.sh"), 1)
        self.assertNotIn("simctl create", source)
        self.assertNotIn("simctl clone", source)
        self.assertNotIn("-parallel-testing-enabled YES", source)
        self.assertNotIn('summary["totalAttempts"] > 24', source)
        baseline_source = (
            SCRIPTS / "prepare-inline-keyboard-baseline.sh"
        ).read_text()
        for token in (
            'simctl erase "$udid"',
            'launchctl disable "$keyboard_service"',
            'launchctl kill SIGKILL "$keyboard_service"',
            "text_input_keyboard_snapshot.py capture",
            'launchctl enable "$keyboard_service"',
            'launchctl kickstart -k "$keyboard_service"',
        ):
            self.assertIn(token, baseline_source)
        self.assertLess(
            baseline_source.index('launchctl kill SIGKILL "$keyboard_service"'),
            baseline_source.index("text_input_keyboard_snapshot.py capture"),
        )
        group_source = GROUP_RUNNER.read_text()
        self.assertEqual(group_source.count('simctl erase "$udid"'), 1)
        self.assertEqual(group_source.count("run-text-input-batch.sh"), 0)
        self.assertEqual(group_source.count("xcodebuild test-without-building"), 1)
        self.assertIn("INPUTDEC_TEXT_INPUT_GROUP_ID", group_source)
        self.assertIn("INPUTDEC_TEXT_INPUT_GROUP_TOKEN", group_source)
        self.assertIn("text_input_group_protocol.py", group_source)
        self.assertIn("text_input_live_boundary.py", group_source)
        self.assertIn("extract-group", group_source)
        self.assertEqual(group_source.count("default_request_timeout=180"), 2)
        self.assertEqual(group_source.count("default_request_timeout=90"), 1)
        self.assertIn(
            'INPUTDEC_GROUP_REQUEST_TIMEOUT_SECONDS:-$default_request_timeout',
            group_source,
        )
        self.assertIn("-parallel-testing-enabled NO", group_source)
        self.assertIn(
            "-maximum-concurrent-test-simulator-destinations 1",
            group_source,
        )
        self.assertIn("-parallel-testing-worker-count 1", group_source)
        self.assertIn("-maximum-parallel-testing-workers 1", group_source)
        self.assertNotIn("-parallel-testing-enabled YES", group_source)

    def _fake_batch_environment(self, temporary, scenario):
        root = pathlib.Path(temporary)
        tools = root / "bin"
        tools.mkdir()
        log = root / "commands.jsonl"
        count = root / "xcodebuild-count"
        real_python = pathlib.Path(os.sys.executable)
        fake_python = tools / "python3"
        fake_python.write_text(
            "#!/bin/zsh\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == resume-check ]]; then\n"
            "  directory=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --directory ]]; then directory=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  [[ -f \"$directory/batch-summary.json\" ]]\n"
            "  exit $?\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == group-resume-check ]]; then\n"
            "  directory=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --directory ]]; then directory=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  [[ -f \"$directory/group-summary.json\" ]]\n"
            "  exit $?\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == observation-resume-check ]]; then\n"
            "  directory=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --directory ]]; then directory=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  typeset -a packages\n"
            "  packages=(\"$directory\"/observation-*.checkpoint(N))\n"
            "  output=\"\"\n"
            "  for (( index=1; index <= ${#packages[@]}; index++ )); do\n"
            "    [[ -z \"$output\" ]] || output+=,\n"
            "    output+=$index\n"
            "  done\n"
            "  print -r -- \"$output\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == write-group-summary ]]; then\n"
            "  directory=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --directory ]]; then directory=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  print -r -- '{\"schema\":1,\"result\":\"Passed\","
            "\"erasedBoots\":1,\"batches\":4}' "
            ">\"$directory/group-summary.json\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == extract-group ]]; then\n"
            "  [[ \"$FAKE_BATCH_SCENARIO\" != extraction-failure ]] || exit 1\n"
            "  output=\"\"; group_id=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    [[ \"$1\" != --output ]] || output=\"$2\"\n"
            "    [[ \"$1\" != --group-id ]] || group_id=\"$2\"\n"
            "    shift\n"
            "  done\n"
            "  boundaries=7; hosts=4; passes=3; rows=0; batches=4\n"
            "  comparisons=12; host_observations=24\n"
            "  scope=${${group_id#*--}%%--*}\n"
            "  if [[ \"$scope\" == group-r1-stock-custom || "
            "\"$scope\" == group-r1-custom-stock || "
            "\"$scope\" == group-r2-stock-custom || "
            "\"$scope\" == group-r2-custom-stock ]]; then\n"
            "    boundaries=1; hosts=1; passes=0; batches=1\n"
            "    comparisons=1; host_observations=2\n"
            "  fi\n"
            "  if [[ \"$group_id\" == *--interior-reject-undo ]]; then "
            "boundaries=23; hosts=12; rows=8; fi\n"
            "  if [[ \"$group_id\" == inline-prediction--snapshot-row-v1--* ]]; then\n"
            "    boundaries=7; hosts=4; passes=3; rows=0; batches=4\n"
            "    comparisons=4; host_observations=8\n"
            "  fi\n"
            "  mkdir -p \"$output/batches\"\n"
            "  print -r -- \"{\\\"schema\\\":1,\\\"result\\\":\\\"Passed\\\","
            "\\\"groupId\\\":\\\"$group_id\\\","
            "\\\"successfulBoundaries\\\":$boundaries,"
            "\\\"successfulHostBoundaries\\\":$hosts,"
            "\\\"successfulPassBoundaries\\\":$passes,"
            "\\\"successfulRowBoundaries\\\":$rows,"
            "\\\"batches\\\":$batches,"
            "\\\"comparisons\\\":$comparisons,"
            "\\\"hostObservations\\\":$host_observations}\" "
            ">\"$output/group-summary.json\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_live_boundary.py ]]; then\n"
            "  [[ \"$FAKE_BATCH_SCENARIO\" != boundary-reset-failure ]] || exit 1\n"
            "  output=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --output ]]; then output=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  mkdir -p \"$output\"\n"
            "  if [[ \" $* \" == *' --keyboard-snapshot '* ]]; then\n"
            "    [[ \"$FAKE_BATCH_SCENARIO\" != snapshot-restore-mismatch ]] "
            "|| exit 65\n"
            "    print -r -- '{\"schema\":1,\"result\":\"restored\","
            "\"identity\":{},\"roots\":[\"Library/Keyboard\"],"
            "\"baselineManifestSHA256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\","
            "\"restoredManifestSHA256\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}' "
            "      >\"$output/summary.json\"\n"
            "    print -r -- '[\"snapshot-restore\"]' >>\"$FAKE_COMMAND_LOG\"\n"
            "    snapshot=\"\"\n"
            "    for (( index=1; index <= $#; index++ )); do\n"
            "      [[ \"${@[index]}\" != --keyboard-snapshot ]] || "
            "snapshot=\"${@[index + 1]}\"\n"
            "    done\n"
            "    print -r -- \"[\\\"snapshot-path\\\",\\\"$snapshot\\\"]\" "
            ">>\"$FAKE_COMMAND_LOG\"\n"
            "    exit 0\n"
            "  fi\n"
            "  print -r -- '{\"schema\":1,\"result\":\"Passed\"}' "
            ">\"$output/summary.json\"\n"
            "  print -r -- '[\"boundary-reset\"]' >>\"$FAKE_COMMAND_LOG\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_keyboard_snapshot.py && "
            "\"${2:-}\" == verify ]]; then\n"
            "  [[ \"$FAKE_BATCH_SCENARIO\" != snapshot-identity-mismatch ]] "
            "|| exit 65\n"
            "  print -r -- '{\"schema\":1}'\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_keyboard_mutation_audit.py ]]; then\n"
            "  audit_command=\"${2:-}\"\n"
            "  output=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    [[ \"$1\" != --output ]] || output=\"$2\"\n"
            "    shift\n"
            "  done\n"
            "  mkdir -p \"${output:h}\"\n"
            "  if [[ \"$audit_command\" == compare && "
            "\"$FAKE_BATCH_SCENARIO\" == snapshot-audit-mutation ]]; then\n"
            "    print -r -- '{\"schema\":1,\"result\":"
            "\"unclassified-mutations\"}' >\"$output\"\n"
            "    exit 65\n"
            "  fi\n"
            "  print -r -- '{\"schema\":1,\"result\":\"clean\"}' >\"$output\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \"${1:-}\" == Scripts/text_input_batch.py && "
            "\"${2:-}\" == extract ]]; then\n"
            "  output=\"\"\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --output ]]; then output=\"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "  mkdir -p \"$output/fake-row/stock\" "
            "\"$output/fake-row/custom\"\n"
            "  print -r -- '{\"schema\":1,\"result\":\"Passed\","
            "\"failedTests\":0,\"skippedTests\":0}' "
            ">\"$output/batch-summary.json\"\n"
            "  exit 0\n"
            "fi\n"
            f"exec {real_python} \"$@\"\n",
            encoding="utf-8",
        )
        fake_python.chmod(0o755)

        fake_xcrun = tools / "xcrun"
        fake_xcrun.write_text(
            "#!/bin/zsh\n"
            "python3 - \"$FAKE_COMMAND_LOG\" \"$@\" <<'PY'\n"
            "import json, pathlib, sys\n"
            "with pathlib.Path(sys.argv[1]).open('a') as stream:\n"
            "    stream.write(json.dumps(['xcrun', *sys.argv[2:]]) + '\\n')\n"
            "PY\n"
            "if [[ \"${1:-}\" == simctl && \"${2:-}\" == getenv ]]; then\n"
            "  [[ \"${4:-}\" == SIMULATOR_RUNTIME_VERSION ]] && "
            "print 26.5 || print 23F73\n"
            "elif [[ \"${1:-}\" == simctl && \"${2:-}\" == spawn && "
            "\"${4:-}\" == defaults && \"${5:-}\" == read ]]; then\n"
            "  print '('\n"
            "  print '  \"ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic\",'\n"
            "  print '  \"zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic\",'\n"
            "  print '  \"en_AU@sw=QWERTY;hw=Automatic\"'\n"
            "  print ')'\n"
            "elif [[ \"${1:-}\" == simctl && "
            "\"${2:-}\" == get_app_container ]]; then\n"
            "  if [[ \"$FAKE_BATCH_SCENARIO\" == "
            "snapshot-container-replacement ]]; then\n"
            "    query=0\n"
            "    [[ ! -f \"$FAKE_CONTAINER_QUERY_COUNT\" ]] || "
            "query=$(<\"$FAKE_CONTAINER_QUERY_COUNT\")\n"
            "    query=$((query + 1))\n"
            "    print -r -- \"$query\" >\"$FAKE_CONTAINER_QUERY_COUNT\"\n"
            "    if (( query == 1 )); then\n"
            "      print -r -- \"$FAKE_STALE_RUNNER_CONTAINER\"\n"
            "    else\n"
            "      print -r -- \"$FAKE_RUNNER_CONTAINER\"\n"
            "    fi\n"
            "  else\n"
            "    print -r -- \"$FAKE_RUNNER_CONTAINER\"\n"
            "  fi\n"
            "elif [[ \"${1:-}\" == xcresulttool && "
            "\"${2:-}\" == get ]]; then\n"
            "  print -r -- \"$FAKE_XCRESULT_SUMMARY\"\n"
            "elif [[ \"${1:-}\" == xcresulttool && "
            "\"${2:-}\" == export ]]; then\n"
            "  while (( $# > 0 )); do\n"
            "    if [[ \"$1\" == --output-path ]]; then mkdir -p \"$2\"; break; fi\n"
            "    shift\n"
            "  done\n"
            "fi\n",
            encoding="utf-8",
        )
        fake_xcrun.chmod(0o755)

        fake_xcodebuild = tools / "xcodebuild"
        fake_xcodebuild.write_text(
            "#!/bin/zsh\n"
            "attempt=0\n"
            "[[ ! -f \"$FAKE_XCODEBUILD_COUNT\" ]] || "
            "attempt=$(<\"$FAKE_XCODEBUILD_COUNT\")\n"
            "attempt=$((attempt + 1))\n"
            "print -r -- \"$attempt\" >\"$FAKE_XCODEBUILD_COUNT\"\n"
            "python3 - \"$FAKE_COMMAND_LOG\" \"$@\" <<'PY'\n"
            "import json, pathlib, sys\n"
            "with pathlib.Path(sys.argv[1]).open('a') as stream:\n"
            "    stream.write(json.dumps(['xcodebuild', *sys.argv[2:]]) + '\\n')\n"
            "PY\n"
            "xctestrun=\"\"\n"
            "while (( $# > 0 )); do\n"
            "  [[ \"$1\" != -xctestrun ]] || xctestrun=\"$2\"\n"
            "  [[ \"$1\" != -resultBundlePath ]] || mkdir -p \"$2\"\n"
            "  shift\n"
            "done\n"
            "if [[ -n \"$xctestrun\" ]]; then\n"
            "  python3 - \"$xctestrun\" \"$FAKE_RUNNER_CONTAINER\" "
            "\"$FAKE_BATCH_SCENARIO\" \"$attempt\" <<'PY'\n"
            "import json, pathlib, plistlib, sys, time\n"
            "from Scripts.text_input_group_protocol import (\n"
            "    boundary_plan, observation_plan,\n"
            ")\n"
            "xctestrun, container, scenario, attempt = sys.argv[1:]\n"
            "value = plistlib.loads(pathlib.Path(xctestrun).read_bytes())\n"
            "environment = value['InputDecUITests']['EnvironmentVariables']\n"
            "group = environment.get('INPUTDEC_TEXT_INPUT_GROUP_ID')\n"
            "token = environment.get('INPUTDEC_TEXT_INPUT_GROUP_TOKEN')\n"
            "if group:\n"
            "    if group.startswith('inline-prediction--snapshot-row-v1--'):\n"
            "        handshake = pathlib.Path(container) / 'Documents' / "
            "'InputDecTextInputGroup' / token\n"
            "        handshake.mkdir(parents=True, exist_ok=True)\n"
            "        selected_paths = pathlib.Path(container).parent.rglob(\n"
            "            'selected-group.json')\n"
            "        selected = next(\n"
            "            value for path in selected_paths\n"
            "            if (value := json.loads(path.read_text()))['id'] == group)\n"
            "        observations = observation_plan(selected)\n"
            "        completed_raw = environment.get(\n"
            "            'INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS', '')\n"
            "        completed = len(completed_raw.split(',')) if completed_raw else 0\n"
            "        event_index = 1\n"
            "        for identity in observations[completed:]:\n"
            "            observation_index = identity['observationIndex']\n"
            "            if scenario == 'snapshot-early-exit' and observation_index == 5:\n"
            "                raise SystemExit(1)\n"
            "            if scenario == 'snapshot-readiness-exhaustion' and "
            "observation_index == 5:\n"
            "                print('Inline prediction remained unavailable after 20 attempts', "
            "file=sys.stderr)\n"
            "                raise SystemExit(1)\n"
            "            attempts = (1, 2) if (\n"
            "                scenario == 'snapshot-readiness' and "
            "observation_index == 4) else (1,)\n"
            "            for observation_attempt in attempts:\n"
            "                if scenario == 'snapshot-attempt-21' and "
            "observation_index == 1:\n"
            "                    observation_attempt = 21\n"
            "                kind = ('observation-started' if "
            "observation_attempt == 1 else 'retry-required')\n"
            "                emitted_event_index = event_index\n"
            "                if scenario == 'snapshot-event-gap' and "
            "observation_index == 2:\n"
            "                    emitted_event_index += 1\n"
            "                event = {\n"
            "                    'schema': 3, 'kind': kind, 'token': token,\n"
            "                    'groupId': group, "
            "'eventIndex': emitted_event_index,\n"
            "                    'observationIndex': observation_index,\n"
            "                    'attempt': observation_attempt,\n"
            "                    'batchId': identity['batchId'],\n"
            "                    'rowId': identity['rowId'],\n"
            "                    'host': identity['host'],\n"
            "                    'precedingBoundary': (\n"
            "                        identity['precedingBoundary']\n"
            "                        if observation_attempt == 1 else None),\n"
            "                }\n"
            "                request = handshake / "
            "f'observation-{emitted_event_index:06d}-event.json'\n"
            "                response = handshake / "
            "f'observation-{emitted_event_index:06d}-restore.json'\n"
            "                request.write_text(json.dumps(event))\n"
            "                deadline = time.monotonic() + 10\n"
            "                while not response.is_file() and time.monotonic() < deadline:\n"
            "                    time.sleep(0.01)\n"
            "                if not response.is_file():\n"
            "                    raise SystemExit(1)\n"
            "                request.unlink(missing_ok=True)\n"
            "                response.unlink(missing_ok=True)\n"
            "                event_index += 1\n"
            "                if scenario == 'snapshot-semantic' and "
            "observation_index == 1:\n"
            "                    print('canonical mismatch', file=sys.stderr)\n"
            "                    raise SystemExit(1)\n"
            "                if len(attempts) == 2 and observation_attempt == 1:\n"
            "                    continue\n"
            "                event_kinds = ['offer-ready', 'observation-complete']\n"
            "                if scenario == 'snapshot-retry-after-offer' and "
            "observation_index == 1:\n"
            "                    event_kinds[1] = 'retry-required'\n"
            "                for event_kind in event_kinds:\n"
            "                    event.update(kind=event_kind, eventIndex=event_index,\n"
            "                                 precedingBoundary=None)\n"
            "                    if event_kind == 'retry-required':\n"
            "                        event['attempt'] = observation_attempt + 1\n"
            "                    event_path = handshake / "
            "f'observation-{event_index:06d}-event.json'\n"
            "                    if event_kind == 'observation-complete':\n"
            "                        checkpoint = handshake / "
            "f'observation-{observation_index:03d}.checkpoint'\n"
            "                        checkpoint.mkdir()\n"
            "                        (checkpoint / 'fake.txt').write_text('checkpoint')\n"
            "                    event_path.write_text(json.dumps(event))\n"
            "                    deadline = time.monotonic() + 10\n"
            "                    while event_path.exists() and time.monotonic() < deadline:\n"
            "                        time.sleep(0.01)\n"
            "                    if event_path.exists():\n"
            "                        raise SystemExit(1)\n"
            "                    event_index += 1\n"
            "        raise SystemExit(0)\n"
            "    if scenario == 'readiness' and attempt == '1':\n"
            "        print('Expected native inline prediction was absent', file=sys.stderr)\n"
            "        raise SystemExit(1)\n"
            "    if scenario == 'semantic':\n"
            "        print('canonical mismatch', file=sys.stderr)\n"
            "        raise SystemExit(1)\n"
            "    if scenario in ('early-exit', 'xctest-assertion-before-request'):\n"
            "        print('unexpected XCTest exit', file=sys.stderr)\n"
            "        raise SystemExit(1)\n"
            "    if scenario == 'request-timeout':\n"
            "        time.sleep(3)\n"
            "        raise SystemExit(1)\n"
            "    subsystem, scope, suffix = group.split('--', 2)\n"
            "    repetitions = ['r1', 'r2'] if scope == 'group' else [\n"
            "        scope.removeprefix('group-')]\n"
            "    batches = [\n"
            "        f'{subsystem}--{repetition}--{order}--{suffix}'\n"
            "        for repetition in repetitions\n"
            "        for order in ('stock-custom', 'custom-stock')\n"
            "    ]\n"
            "    handshake = pathlib.Path(container) / 'Documents' / "
            "'InputDecTextInputGroup' / token\n"
            "    handshake.mkdir(parents=True, exist_ok=True)\n"
            "    selected_paths = pathlib.Path(container).parent.rglob(\n"
            "        'selected-group.json')\n"
            "    selected = next(\n"
            "        value for path in selected_paths\n"
            "        if (value := json.loads(path.read_text()))['id'] == group)\n"
            "    plan = boundary_plan(selected)\n"
            "    for identity in plan:\n"
            "        index = identity['sequenceIndex']\n"
            "        if scenario == 'missing-row-request' and identity['kind'] == 'row':\n"
            "            time.sleep(3)\n"
            "            raise SystemExit(1)\n"
            "        if scenario == 'missing-host-request' and identity['kind'] == 'host':\n"
            "            time.sleep(3)\n"
            "            raise SystemExit(1)\n"
            "        request = handshake / f'boundary-{index:03d}-request.json'\n"
            "        response = handshake / f'boundary-{index:03d}-response.json'\n"
            "        request.write_text(json.dumps({\n"
            "            'schema': 2, 'token': token, 'groupId': group,\n"
            "            **identity,\n"
            "        }))\n"
            "        if scenario == 'malformed-request' and index == 1:\n"
            "            value = json.loads(request.read_text())\n"
            "            value['groupId'] = 'autocorrection--group--wrong'\n"
            "            request.write_text(json.dumps(value))\n"
            "        if scenario == 'wrong-kind' and index == 1:\n"
            "            value = json.loads(request.read_text())\n"
            "            value['kind'] = 'pass'\n"
            "            request.write_text(json.dumps(value))\n"
            "        if scenario == 'wrong-row' and identity['kind'] == 'row':\n"
            "            value = json.loads(request.read_text())\n"
            "            value['nextRowId'] = 'wrong-row'\n"
            "            request.write_text(json.dumps(value))\n"
            "        if scenario == 'wrong-host' and identity['kind'] == 'host':\n"
            "            value = json.loads(request.read_text())\n"
            "            value['nextHost'] = value['completedHost']\n"
            "            request.write_text(json.dumps(value))\n"
            "        if scenario == 'duplicate-sequence' and index == 2:\n"
            "            value = json.loads(request.read_text())\n"
            "            value['sequenceIndex'] = 1\n"
            "            request.write_text(json.dumps(value))\n"
            "        deadline = time.monotonic() + 10\n"
            "        while not response.is_file() and time.monotonic() < deadline:\n"
            "            time.sleep(0.01)\n"
            "        if not response.is_file():\n"
            "            print('boundary response timeout', file=sys.stderr)\n"
            "            raise SystemExit(1)\n"
            "        request.unlink()\n"
            "        response.unlink()\n"
            "PY\n"
            "  group_status=$?\n"
            "  (( group_status == 0 )) || exit $group_status\n"
            "fi\n"
            "if [[ \"$FAKE_BATCH_SCENARIO\" == readiness && $attempt == 1 ]]; then\n"
            "  print -u2 -- 'Expected native inline prediction was absent'\n"
            "  exit 1\n"
            "fi\n"
            "if [[ \"$FAKE_BATCH_SCENARIO\" == semantic ]]; then\n"
            "  print -u2 -- 'canonical mismatch'\n"
            "  exit 1\n"
            "fi\n",
            encoding="utf-8",
        )
        fake_xcodebuild.chmod(0o755)

        fake_baseline = tools / "fake-inline-baseline"
        fake_baseline.write_text(
            "#!/bin/zsh\n"
            "output=\"\"\n"
            "while (( $# > 0 )); do\n"
            "  [[ \"$1\" != --output ]] || output=\"$2\"\n"
            "  shift\n"
            "done\n"
            "mkdir -p \"$output/tree/Library/Keyboard\"\n"
            "print -r -- '{\"schema\":1,\"identity\":{\"schema\":1,"
            "\"udid\":\"FA6F7462-AA97-42FE-9E57-8DA0593CE756\","
            "\"runtime\":{\"osVersion\":\"26.5\",\"osBuild\":\"23F73\"},"
            "\"locale\":\"en_US\",\"inputModes\":["
            "\"en_US@sw=QWERTY;hw=Automatic\"],\"manifestFormat\":1},"
            "\"roots\":[\"Library/Keyboard\"],\"files\":{},\"sqlite\":{}}' "
            ">\"$output/manifest.json\"\n"
            "print -r -- '[\"xcrun\",\"simctl\",\"erase\"]' "
            ">>\"$FAKE_COMMAND_LOG\"\n"
            "print -r -- '[\"baseline-capture\"]' >>\"$FAKE_COMMAND_LOG\"\n",
            encoding="utf-8",
        )
        fake_baseline.chmod(0o755)

        xctestrun = root / "InputDec.xctestrun"
        with xctestrun.open("wb") as stream:
            plistlib.dump({
                "InputDecUITests": {"EnvironmentVariables": {}}
            }, stream)
        summary = {
            "result": "Passed",
            "totalTestCount": 1,
            "expectedFailures": 0,
            "failedTests": 0,
            "skippedTests": 0,
            "passedTests": 1,
            "devicesAndConfigurations": [{
                "expectedFailures": 0,
                "failedTests": 0,
                "skippedTests": 0,
                "passedTests": 1,
                "device": {
                    "deviceId": PINNED_UDID,
                    "osVersion": "26.5",
                    "osBuildNumber": "23F73",
                },
            }],
        }
        environment = dict(os.environ)
        environment.update({
            "PATH": f"{tools}:{environment['PATH']}",
            "HOME": str(root / "home"),
            "INPUTDEC_XCTEST_LOCK_ROOT": str(root / "locks"),
            "INPUTDEC_BATCH_XCTESTRUN": str(xctestrun),
            "FAKE_COMMAND_LOG": str(log),
            "FAKE_XCODEBUILD_COUNT": str(count),
            "FAKE_CONTAINER_QUERY_COUNT": str(root / "container-query-count"),
            "FAKE_BATCH_SCENARIO": scenario,
            "FAKE_XCRESULT_SUMMARY": json.dumps(summary),
            "FAKE_RUNNER_CONTAINER": str(root / "runner-container"),
            "FAKE_STALE_RUNNER_CONTAINER": str(
                root / "stale-runner-container"
            ),
            "INPUTDEC_GROUP_REQUEST_TIMEOUT_SECONDS": "2",
            "INPUTDEC_GROUP_CONTAINER_TIMEOUT_SECONDS": "2",
            "INPUTDEC_BATCH_TEST_BASELINE_RUNNER": str(fake_baseline),
        })
        pathlib.Path(environment["FAKE_RUNNER_CONTAINER"]).mkdir()
        pathlib.Path(environment["FAKE_STALE_RUNNER_CONTAINER"]).mkdir()
        return environment, log

    def _run_fake_batch(self, temporary, scenario, prepared=False):
        environment, log = self._fake_batch_environment(temporary, scenario)
        output = pathlib.Path(temporary) / "evidence"
        arguments = [
                "zsh", str(BATCH_RUNNER),
                "--udid", PINNED_UDID,
                "--catalog", str(AUTOCORRECTION_BATCHES),
                "--batch-id",
                "autocorrection--r1--stock-custom--interior-undo-candidate",
                "--output", str(output),
        ]
        if prepared:
            arguments.insert(2, "--prepared-device")
        completed = subprocess.run(
            arguments,
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )
        commands = [
            json.loads(line)
            for line in log.read_text(encoding="utf-8").splitlines()
        ]
        return completed, output, commands

    def test_prepared_batch_resets_state_without_erasing_group_boot(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, commands = self._run_fake_batch(
                temporary, "success", prepared=True
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            erases = [command for command in commands if command[1:3] == [
                "simctl", "erase",
            ]]
            tests = [command for command in commands if command[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            kickstarts = [command for command in commands
                          if "launchctl" in command and "kickstart" in command]
            self.assertEqual(erases, [])
            self.assertEqual(len(tests), 1)
            self.assertGreaterEqual(len(kickstarts), 1)
            timing = json.loads((output / "timing.json").read_text())
            self.assertEqual(timing["eraseBootSeconds"], 0)

    def test_group_runner_uses_one_xctest_and_seven_live_boundaries(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            output = pathlib.Path(temporary) / "group-evidence"
            completed = subprocess.run([
                "zsh", str(GROUP_RUNNER),
                "--udid", PINNED_UDID,
                "--catalog", str(AUTOCORRECTION_BATCHES),
                "--group-id", "autocorrection--group--interior-undo-candidate",
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            commands = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ] if log.exists() else []
            erases = [command for command in commands if command[1:3] == [
                "simctl", "erase",
            ]]
            tests = [command for command in commands if command[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            resets = [command for command in commands
                      if command == ["boundary-reset"]]
            self.assertEqual(len(erases), 1)
            self.assertEqual(len(tests), 1)
            self.assertEqual(len(resets), 7)
            summary = json.loads((output / "group-summary.json").read_text())
            self.assertEqual(summary["successfulBoundaries"], 7)
            self.assertEqual(summary["successfulHostBoundaries"], 4)
            self.assertEqual(summary["batches"], 4)

    def test_group_runner_rejects_deprecated_one_batch_inline_order_group(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            output = pathlib.Path(temporary) / "group-evidence"
            completed = subprocess.run([
                "zsh", str(GROUP_RUNNER),
                "--udid", PINNED_UDID,
                "--catalog", str(INLINE_PREDICTION_BATCHES),
                "--group-id",
                "inline-prediction--group-r1-stock-custom--interior-accept",
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False)
            self.assertNotEqual(completed.returncode, 0)
            commands = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ] if log.exists() else []
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 0)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 0)
            self.assertTrue((output / "failure.txt").is_file())

    def _snapshot_group_inputs(self, temporary):
        root = pathlib.Path(temporary)
        snapshot = root / "keyboard-snapshot"
        (snapshot / "tree" / "Library" / "Keyboard").mkdir(parents=True)
        identity = {
            "schema": 1,
            "udid": PINNED_UDID,
            "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
            "locale": "en_US",
            "inputModes": ["en_US@sw=QWERTY;hw=Automatic"],
            "manifestFormat": 1,
        }
        (snapshot / "manifest.json").write_text(json.dumps({
            "schema": 1,
            "identity": identity,
            "roots": ["Library/Keyboard"],
            "files": {},
            "sqlite": {},
        }))
        return snapshot

    def _run_fake_snapshot_group(
            self, temporary, scenario, resume_from=None, audit=False):
        environment, log = self._fake_batch_environment(temporary, scenario)
        snapshot = self._snapshot_group_inputs(temporary)
        output = pathlib.Path(temporary) / "snapshot-group-evidence"
        arguments = [
            "zsh", str(GROUP_RUNNER), "--prepared-device",
            "--udid", PINNED_UDID,
            "--catalog", str(INLINE_PREDICTION_BATCHES),
            "--group-id",
            "inline-prediction--snapshot-row-v1--interior-accept",
            "--keyboard-snapshot", str(snapshot),
            "--output", str(output),
        ]
        if resume_from is not None:
            arguments.extend(["--resume-from", str(resume_from)])
        if audit:
            arguments.append("--audit-external-mutations")
        completed = subprocess.run(arguments, cwd=ROOT, env=environment,
            text=True, capture_output=True,
            check=False, timeout=30)
        commands = [
            json.loads(line)
            for line in log.read_text(encoding="utf-8").splitlines()
        ] if log.exists() else []
        return completed, output, commands

    def test_snapshot_group_uses_one_xctest_and_restores_each_attempt(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, commands = self._run_fake_snapshot_group(
                temporary, "snapshot-readiness"
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 0)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 1)
            self.assertEqual(sum(command == ["snapshot-restore"]
                                 for command in commands), 9)
            summary = json.loads((output / "group-summary.json").read_text())
            self.assertEqual(summary["successfulBoundaries"], 7)
            self.assertEqual(summary["hostObservations"], 8)
            timing = json.loads((output / "group-timing.json").read_text())
            self.assertEqual(timing["readinessRetries"], 1)
            self.assertEqual(timing["snapshotRestores"], 9)
            self.assertTrue((output / "snapshot-preflight.json").is_file())
            self.assertTrue((output / "checkpoints" /
                             "observation-008.checkpoint").is_dir())

    def test_snapshot_group_patches_xctestrun_beside_prebuilt_products(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, _, commands = self._run_fake_snapshot_group(
                temporary, "success"
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            invocation = next(command for command in commands
                              if command[0:2] == [
                                  "xcodebuild", "test-without-building"
                              ])
            patched = pathlib.Path(
                invocation[invocation.index("-xctestrun") + 1]
            )
            self.assertEqual(patched.parent, pathlib.Path(temporary).resolve())

    def test_snapshot_group_follows_reinstalled_runner_container(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, _ = self._run_fake_snapshot_group(
                temporary, "snapshot-container-replacement"
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue((output / "group-summary.json").is_file())

    def test_snapshot_group_resumes_only_the_validated_checkpoint_prefix(self):
        with tempfile.TemporaryDirectory() as temporary:
            resume = pathlib.Path(temporary) / "resume"
            checkpoints = resume / "checkpoints"
            checkpoints.mkdir(parents=True)
            for index in range(1, 4):
                package = checkpoints / f"observation-{index:03d}.checkpoint"
                package.mkdir()
                (package / "fake.txt").write_text("checkpoint")
            (resume / "failure-classification.json").write_text(json.dumps({
                "schema": 1,
                "result": "Failed",
                "classification": "external-interruption",
                "message": "interrupted",
                "resumable": True,
            }))
            (resume / "resume-authority-boundaries.json").write_text(json.dumps([
                {
                    "kind": "host" if index == 1 else "pass",
                    "sequenceIndex": index,
                    "resetSummarySHA256": "a" * 64,
                    "result": "ready",
                }
                for index in range(1, 3)
            ]))
            completed, output, commands = self._run_fake_snapshot_group(
                temporary, "success", resume_from=resume
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(sum(command == ["snapshot-restore"]
                                 for command in commands), 5)
            self.assertTrue((output / "checkpoints" /
                             "observation-001.checkpoint").is_dir())
            self.assertTrue((output / "checkpoints" /
                             "observation-008.checkpoint").is_dir())

    def test_snapshot_group_audits_before_restore_release_and_after_complete(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, _ = self._run_fake_snapshot_group(
                temporary, "success", audit=True
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            reports = list((output / "external-mutation-audit").glob(
                "observation-*/attempt-001/report.json"
            ))
            self.assertEqual(len(reports), 8)

    def test_snapshot_readiness_exhaustion_exposes_only_valid_resume_prefix(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, _ = self._run_fake_snapshot_group(
                temporary, "snapshot-readiness-exhaustion"
            )
            self.assertNotEqual(completed.returncode, 0)
            classification = json.loads(
                (output / "failure-classification.json").read_text()
            )
            self.assertEqual(classification["classification"],
                             "readiness-exhaustion")
            self.assertTrue(classification["resumable"])
            self.assertEqual(len(list((output / "checkpoints").glob(
                "observation-*.checkpoint"
            ))), 4)
            boundaries = json.loads((
                output / "resume-authority-boundaries.json"
            ).read_text())
            self.assertEqual(len(boundaries), 3)

    def test_snapshot_proof_runs_twenty_cycles_in_each_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            snapshot = self._snapshot_group_inputs(temporary)
            output = pathlib.Path(temporary) / "proof"
            completed = subprocess.run([
                "zsh", str(SNAPSHOT_PROOF_RUNNER),
                "--udid", PINNED_UDID,
                "--xctestrun", environment["INPUTDEC_BATCH_XCTESTRUN"],
                "--snapshot", str(snapshot), "--output", str(output),
            ], cwd=ROOT, env=environment, text=True, capture_output=True,
                check=False, timeout=90)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            commands = [
                json.loads(line) for line in log.read_text().splitlines()
            ]
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 10)
            self.assertEqual(sum(command == ["snapshot-restore"]
                                 for command in commands), 80)
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 0)
            summary = json.loads((output / "proof-summary.json").read_text())
            self.assertEqual(summary, {
                "schema": 1,
                "result": "Passed",
                "iterations": 10,
                "xctestInvocations": 10,
                "physicalObservations": 80,
                "verifiedRestores": 80,
                "stockCustomTransitions": 20,
                "customStockTransitions": 20,
                "semanticFailures": 0,
                "unclassifiedMutations": 0,
                "erasedBoots": 0,
            })

    def test_snapshot_proof_stops_on_unclassified_external_mutation(self):
        for scenario in (
            "snapshot-audit-mutation",
            "snapshot-restore-mismatch",
            "snapshot-readiness-exhaustion",
            "snapshot-semantic",
        ):
            with self.subTest(scenario=scenario), \
                    tempfile.TemporaryDirectory() as temporary:
                environment, log = self._fake_batch_environment(
                    temporary, scenario
                )
                snapshot = self._snapshot_group_inputs(temporary)
                output = pathlib.Path(temporary) / "proof"
                completed = subprocess.run([
                    "zsh", str(SNAPSHOT_PROOF_RUNNER),
                    "--udid", PINNED_UDID,
                    "--xctestrun", environment["INPUTDEC_BATCH_XCTESTRUN"],
                    "--snapshot", str(snapshot), "--output", str(output),
                ], cwd=ROOT, env=environment, text=True,
                    capture_output=True, check=False, timeout=30)
                self.assertNotEqual(completed.returncode, 0)
                commands = [
                    json.loads(line) for line in log.read_text().splitlines()
                ]
                self.assertEqual(sum(command[0:2] == [
                    "xcodebuild", "test-without-building"
                ] for command in commands), 1)
                self.assertTrue((output / "failure.txt").is_file())

    def test_snapshot_group_fails_closed_for_invalid_event_sequences(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, _ = self._fake_batch_environment(
                temporary, "success"
            )
            snapshot = self._snapshot_group_inputs(temporary)
            output = pathlib.Path(temporary) / "invalid"
            completed = subprocess.run([
                "zsh", str(GROUP_RUNNER), "--prepared-device",
                "--udid", PINNED_UDID,
                "--catalog", str(INLINE_PREDICTION_BATCHES),
                "--group-id",
                "inline-prediction--snapshot-row-v1--interior-accept",
                "--keyboard-snapshot", str(snapshot / "missing"),
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True, capture_output=True,
                check=False, timeout=10)
            self.assertNotEqual(completed.returncode, 0)
            self.assertFalse(any(
                output.parent.glob(".invalid.partial-*")
            ))
        for scenario in (
            "snapshot-identity-mismatch",
            "snapshot-event-gap",
            "snapshot-attempt-21",
            "snapshot-restore-mismatch",
            "snapshot-early-exit",
            "snapshot-retry-after-offer",
            "snapshot-audit-mutation",
        ):
            with self.subTest(scenario=scenario), \
                    tempfile.TemporaryDirectory() as temporary:
                completed, output, _ = self._run_fake_snapshot_group(
                    temporary, scenario,
                    audit=(scenario == "snapshot-audit-mutation"),
                )
                self.assertNotEqual(completed.returncode, 0)
                self.assertTrue(output.is_dir())

    def test_group_runner_interleaves_host_row_and_pass_resets(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            output = pathlib.Path(temporary) / "group-evidence"
            completed = subprocess.run([
                "zsh", str(GROUP_RUNNER), "--udid", PINNED_UDID,
                "--catalog", str(AUTOCORRECTION_BATCHES),
                "--group-id", "autocorrection--group--interior-reject-undo",
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False, timeout=30)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 1)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 1)
            self.assertEqual(sum(command == ["boundary-reset"]
                                 for command in commands), 23)
            summary = json.loads((output / "group-summary.json").read_text())
            self.assertEqual(summary["successfulBoundaries"], 23)
            self.assertEqual(summary["successfulHostBoundaries"], 12)
            self.assertEqual(summary["successfulPassBoundaries"], 3)
            self.assertEqual(summary["successfulRowBoundaries"], 8)
            timing = json.loads((output / "group-timing.json").read_text())
            self.assertIn("hostResetSeconds", timing)
            self.assertIn("rowResetSeconds", timing)

    def test_group_runner_retries_the_whole_group_only_for_readiness(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "readiness"
            )
            output = pathlib.Path(temporary) / "group-evidence"
            completed = subprocess.run([
                "zsh", str(GROUP_RUNNER), "--udid", PINNED_UDID,
                "--catalog", str(AUTOCORRECTION_BATCHES),
                "--group-id", "autocorrection--group--interior-undo-candidate",
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 2)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 2)
            self.assertEqual(sum(command == ["boundary-reset"]
                                 for command in commands), 7)
            timing = json.loads((output / "group-timing.json").read_text())
            self.assertEqual(timing["attempts"], 2)
            self.assertEqual(
                [path.relative_to(output) for path in output.rglob("*.xcresult")],
                [pathlib.Path("group.xcresult")],
            )

    def test_group_runner_fails_closed_for_protocol_reset_and_extraction(self):
        for scenario in (
                "malformed-request", "wrong-kind", "wrong-row", "wrong-host",
                "duplicate-sequence", "missing-row-request", "missing-host-request",
                "boundary-reset-failure", "early-exit",
                "xctest-assertion-before-request", "request-timeout", "semantic",
                "extraction-failure"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as temporary:
                environment, log = self._fake_batch_environment(
                    temporary, scenario
                )
                environment["INPUTDEC_GROUP_REQUEST_TIMEOUT_SECONDS"] = "1"
                output = pathlib.Path(temporary) / "group-evidence"
                completed = subprocess.run([
                    "zsh", str(GROUP_RUNNER), "--udid", PINNED_UDID,
                    "--catalog", str(AUTOCORRECTION_BATCHES),
                    "--group-id",
                    ("autocorrection--group--interior-reject-undo"
                     if scenario in {"wrong-kind", "wrong-row", "wrong-host",
                                     "duplicate-sequence",
                                     "missing-row-request", "missing-host-request"}
                     else "autocorrection--group--interior-undo-candidate"),
                    "--output", str(output),
                ], cwd=ROOT, env=environment, text=True,
                    capture_output=True, check=False, timeout=15)
                self.assertEqual(completed.returncode, 65, completed.stderr)
                count_path = pathlib.Path(environment["FAKE_XCODEBUILD_COUNT"])
                invocation_count = (
                    int(count_path.read_text()) if count_path.exists() else 0
                )
                self.assertLessEqual(invocation_count, 1)
                self.assertTrue((output / "failure.txt").is_file())
                message = (output / "failure.txt").read_text()
                if scenario in {"early-exit", "xctest-assertion-before-request",
                                "semantic"}:
                    self.assertIn("Group XCTest failed", message)
                elif scenario != "extraction-failure":
                    self.assertIn("Group boundary protocol failed", message)

    def test_batch_runner_retries_whole_attempt_and_retains_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, commands = self._run_fake_batch(
                temporary, "readiness"
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            erases = [command for command in commands if command[1:3] == [
                "simctl", "erase",
            ]]
            tests = [command for command in commands if command[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            self.assertEqual(len(erases), 2)
            self.assertEqual(len(tests), 2)
            self.assertTrue(
                (output / "readiness-attempts" / "attempt-1" /
                 "batch.log").is_file()
            )
            timing = json.loads((output / "timing.json").read_text())
            self.assertEqual(timing["attempts"], 2)

    def test_batch_runner_propagates_semantic_failure_without_retry(self):
        with tempfile.TemporaryDirectory() as temporary:
            completed, output, commands = self._run_fake_batch(
                temporary, "semantic"
            )
            self.assertEqual(completed.returncode, 65, completed.stderr)
            erases = [command for command in commands if command[1:3] == [
                "simctl", "erase",
            ]]
            tests = [command for command in commands if command[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            self.assertEqual(len(erases), 1)
            self.assertEqual(len(tests), 1)
            self.assertIn(
                "canonical mismatch",
                (output / "failed-attempt" / "batch.log").read_text(),
            )

    def test_batched_coordinator_interrupts_then_resumes_without_rerun(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_LIMIT": "2",
                "INPUTDEC_BATCH_TEST_INTERRUPT_AFTER": "1",
                "INPUTDEC_BATCH_TEST_GROUP_IDS": (
                    "ime--group--japanese-after-boundary-terminal,"
                    "ime--group--chinese-after-boundary-terminal"
                ),
            })
            output = pathlib.Path(temporary) / "certification"
            command = [
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID,
                "--output", str(output),
            ]
            interrupted = subprocess.run(
                command, cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(interrupted.returncode, 75, interrupted.stderr)
            environment.pop("INPUTDEC_BATCH_TEST_INTERRUPT_AFTER")
            resumed = subprocess.run(
                command[:2] + ["--resume"] + command[2:],
                cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(resumed.returncode, 0, resumed.stderr)
            self.assertIn("RESUME group=", resumed.stdout)
            commands = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ]
            erases = [item for item in commands if item[1:3] == [
                "simctl", "erase",
            ]]
            tests = [item for item in commands if item[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            builds = [item for item in commands if item[0:2] == [
                "xcodebuild", "build-for-testing",
            ]]
            self.assertEqual(len(erases), 2)
            self.assertEqual(len(tests), 2)
            self.assertEqual(builds, [])
            testing_summary = json.loads(
                (output / "testing-summary.json").read_text()
            )
            self.assertEqual(testing_summary["completedGroups"], 2)
            progress = json.loads((output / "progress.json").read_text())
            self.assertEqual(
                progress["lastGroupId"],
                "ime--group--chinese-after-boundary-terminal",
            )

    def test_coordinator_runs_nine_rows_on_one_inline_baseline(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            group_ids = subprocess.run([
                os.sys.executable, str(SCRIPTS / "text_input_batch.py"),
                "list-groups", str(INLINE_PREDICTION_BATCHES),
            ], cwd=ROOT, text=True, capture_output=True, check=True
            ).stdout.splitlines()
            self.assertEqual(len(group_ids), 9)
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_GROUP_IDS": ",".join(group_ids),
            })
            output = pathlib.Path(temporary) / "certification"
            completed = subprocess.run([
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID, "--output", str(output),
            ], cwd=ROOT, env=environment, text=True, capture_output=True,
                check=False, timeout=90)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            commands = [
                json.loads(line) for line in log.read_text().splitlines()
            ]
            self.assertEqual(sum(command == ["baseline-capture"]
                                 for command in commands), 1)
            self.assertEqual(sum(command[1:3] == ["simctl", "erase"]
                                 for command in commands), 1)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 9)
            self.assertEqual(sum(command == ["snapshot-restore"]
                                 for command in commands), 72)
            snapshot_paths = {
                command[1] for command in commands
                if command[:1] == ["snapshot-path"]
            }
            self.assertEqual(snapshot_paths, {
                str((output / "inline-keyboard-snapshot-v1").resolve())
            })
            config = json.loads((output / "run-config.json").read_text())
            self.assertEqual(config["schema"], 2)
            self.assertEqual(
                config["inlineKeyboardSnapshot"]["path"],
                str((output / "inline-keyboard-snapshot-v1").resolve()),
            )
            testing_summary = json.loads(
                (output / "testing-summary.json").read_text()
            )
            self.assertEqual(testing_summary["completedGroups"], 9)

    def test_coordinator_resumes_verified_snapshot_and_completed_observations(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "snapshot-readiness-exhaustion"
            )
            group_id = (
                "inline-prediction--snapshot-row-v1--interior-accept"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_GROUP_IDS": group_id,
            })
            output = pathlib.Path(temporary) / "certification"
            command = [
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID, "--output", str(output),
            ]
            interrupted = subprocess.run(
                command, cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False, timeout=30,
            )
            self.assertNotEqual(interrupted.returncode, 0)
            environment["FAKE_BATCH_SCENARIO"] = "success"
            resumed = subprocess.run(
                command[:2] + ["--resume"] + command[2:],
                cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False, timeout=30,
            )
            self.assertEqual(resumed.returncode, 0, resumed.stderr)
            self.assertIn("PRESERVE invalid group=", resumed.stdout)
            commands = [
                json.loads(line) for line in log.read_text().splitlines()
            ]
            self.assertEqual(sum(command == ["baseline-capture"]
                                 for command in commands), 1)
            self.assertEqual(sum(command[0:2] == [
                "xcodebuild", "test-without-building"
            ] for command in commands), 2)
            self.assertEqual(sum(command == ["snapshot-restore"]
                                 for command in commands), 8)
            retained = list((output / "interrupted-attempts").iterdir())
            self.assertEqual(len(retained), 1)
            self.assertTrue((retained[0] / "checkpoints" /
                             "observation-004.checkpoint").is_dir())

    def test_coordinator_rejects_snapshot_identity_mismatch(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, _ = self._fake_batch_environment(
                temporary, "snapshot-readiness-exhaustion"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_GROUP_IDS": (
                    "inline-prediction--snapshot-row-v1--interior-accept"
                ),
            })
            output = pathlib.Path(temporary) / "certification"
            command = [
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID, "--output", str(output),
            ]
            first = subprocess.run(
                command, cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False, timeout=30,
            )
            self.assertNotEqual(first.returncode, 0)
            manifest_path = output / "inline-keyboard-snapshot-v1" / "manifest.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["identity"]["locale"] = "fr_FR"
            manifest_path.write_text(json.dumps(manifest))
            environment["FAKE_BATCH_SCENARIO"] = "success"
            resumed = subprocess.run(
                command[:2] + ["--resume"] + command[2:],
                cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False, timeout=30,
            )
            self.assertNotEqual(resumed.returncode, 0)
            self.assertIn("identity differs", resumed.stderr)

    def test_coordinator_migrates_one_exact_order_isolation_config(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            group_id = (
                "inline-prediction--snapshot-row-v1--interior-accept"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_GROUP_IDS": group_id,
            })
            output = pathlib.Path(temporary) / "certification"
            (output / "batches").mkdir(parents=True)
            catalogs = [
                ROOT / "UITests/Fixtures/text-input-ime-batches-ios26.5-v1.json",
                AUTOCORRECTION_BATCHES,
                INLINE_PREDICTION_BATCHES,
            ]
            old_config = {
                "schema": 1,
                "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
                "udid": PINNED_UDID,
                "catalogs": [{
                    "path": str(path.resolve()),
                    "sha256": __import__("hashlib").sha256(
                        path.read_bytes()
                    ).hexdigest(),
                } for path in catalogs],
            }
            (output / "run-config.json").write_text(json.dumps(old_config))
            completed = subprocess.run([
                "zsh", str(BATCHED_CERTIFICATION_RUNNER), "--resume",
                "--udid", PINNED_UDID, "--output", str(output),
            ], cwd=ROOT, env=environment, text=True, capture_output=True,
                check=False, timeout=30)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertEqual(json.loads((
                output / "run-config.order-isolation.json"
            ).read_text()), old_config)
            self.assertEqual(json.loads((
                output / "run-config.json"
            ).read_text())["schema"], 2)
            commands = [
                json.loads(line) for line in log.read_text().splitlines()
            ]
            self.assertEqual(sum(command == ["baseline-capture"]
                                 for command in commands), 1)

    def test_batched_coordinator_stops_after_first_child_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "semantic"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_LIMIT": "2",
            })
            output = pathlib.Path(temporary) / "certification"
            failed = subprocess.run([
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID,
                "--output", str(output),
            ], cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False)
            self.assertEqual(failed.returncode, 65, failed.stderr)
            commands = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ]
            tests = [item for item in commands if item[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            self.assertEqual(len(tests), 1)
            self.assertFalse((output / "testing-summary.json").exists())

    def test_batched_resume_preserves_invalid_partial_before_rerun(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, log = self._fake_batch_environment(
                temporary, "success"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_LIMIT": "1",
                "INPUTDEC_BATCH_TEST_INTERRUPT_AFTER": "1",
            })
            output = pathlib.Path(temporary) / "certification"
            command = [
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID,
                "--output", str(output),
            ]
            interrupted = subprocess.run(
                command, cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(interrupted.returncode, 75, interrupted.stderr)
            child_summary = next(
                (output / "batches").glob("*/*/group-summary.json")
            )
            child_summary.unlink()
            environment.pop("INPUTDEC_BATCH_TEST_INTERRUPT_AFTER")
            resumed = subprocess.run(
                command[:2] + ["--resume"] + command[2:],
                cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(resumed.returncode, 0, resumed.stderr)
            self.assertIn("PRESERVE invalid group=", resumed.stdout)
            self.assertEqual(
                len(list((output / "interrupted-attempts").iterdir())), 1
            )
            commands = [
                json.loads(line)
                for line in log.read_text(encoding="utf-8").splitlines()
            ]
            tests = [item for item in commands if item[0:2] == [
                "xcodebuild", "test-without-building",
            ]]
            self.assertEqual(len(tests), 2)

    def test_batched_resume_rejects_changed_run_contract(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment, _ = self._fake_batch_environment(
                temporary, "success"
            )
            environment.update({
                "INPUTDEC_BATCH_TESTING": "1",
                "INPUTDEC_BATCH_TEST_LIMIT": "1",
                "INPUTDEC_BATCH_TEST_INTERRUPT_AFTER": "1",
            })
            output = pathlib.Path(temporary) / "certification"
            command = [
                "zsh", str(BATCHED_CERTIFICATION_RUNNER),
                "--udid", PINNED_UDID,
                "--output", str(output),
            ]
            interrupted = subprocess.run(
                command, cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(interrupted.returncode, 75, interrupted.stderr)
            config = json.loads((output / "run-config.json").read_text())
            config["catalogs"][0]["sha256"] = "0" * 64
            (output / "run-config.json").write_text(json.dumps(config))
            environment.pop("INPUTDEC_BATCH_TEST_INTERRUPT_AFTER")
            resumed = subprocess.run(
                command[:2] + ["--resume"] + command[2:],
                cwd=ROOT, env=environment, text=True,
                capture_output=True, check=False,
            )
            self.assertEqual(resumed.returncode, 65)
            self.assertIn("catalog hashes differ", resumed.stderr)

    def test_fast_runner_is_serial_and_pinned(self):
        source = FAST_RUNNER.read_text()
        for token in [
            "-parallel-testing-enabled NO",
            PINNED_UDID,
            "with-inputdec-simulator-test-lock.sh",
            "InputDecTests/IDTextInputFastLifecycleTests",
            "InputDecTests/IDTextInputScenarioTests",
            "InputDecTests/IDTextInputStateRecorderTests",
            "InputDecTests/IDTextInputTransactionDriverTests",
            "InputDecTests/IDTextInputDifferentialRunnerTests",
            "InputDecTests/IDInlineFormattingDifferentialTests",
        ]:
            self.assertIn(token, source)
        self.assertNotIn("InputDecUITests/", source)

    def _prebuilt_runner_environment(self, temporary):
        root = pathlib.Path(temporary)
        tools = root / "bin"
        tools.mkdir()
        log = root / "xcodebuild.log"
        fake_xcodebuild = tools / "xcodebuild"
        fake_xcodebuild.write_text(
            "#!/bin/zsh\n"
            "print -r -- \"$*\" >>\"$FAKE_COMMAND_LOG\"\n"
            "result=\"\"\n"
            "for (( i=1; i <= $#; i++ )); do\n"
            "  [[ \"${@[i]}\" != -resultBundlePath ]] || "
            "result=\"${@[i+1]}\"\n"
            "done\n"
            "[[ -z \"$result\" ]] || mkdir -p \"$result\"\n"
        )
        fake_xcrun = tools / "xcrun"
        fake_xcrun.write_text(
            "#!/bin/zsh\n"
            "if [[ \" $* \" == *' xcresulttool get test-results summary '* ]]; "
            "then\n"
            f"  print -r -- '{{\"result\":\"Passed\","
            "\"totalTestCount\":1,\"passedTests\":1,"
            "\"failedTests\":0,\"skippedTests\":0,"
            "\"expectedFailures\":0,\"startTime\":1,\"finishTime\":2,"
            "\"devicesAndConfigurations\":[{\"passedTests\":1,"
            "\"failedTests\":0,\"skippedTests\":0,"
            "\"expectedFailures\":0,\"device\":{"
            f"\"deviceId\":\"{PINNED_UDID}\","
            "\"osVersion\":\"26.5\",\"osBuildNumber\":\"23F73\"}}]}'\n"
            "  exit 0\n"
            "fi\n"
            "exit 64\n"
        )
        fake_xcodebuild.chmod(0o755)
        fake_xcrun.chmod(0o755)
        environment = os.environ.copy()
        environment.update({
            "PATH": f"{tools}:{environment['PATH']}",
            "FAKE_COMMAND_LOG": str(log),
            "INPUTDEC_XCTEST_LOCK_ROOT": str(root / "locks"),
            "INPUTDEC_KEYBOARD_SENTINEL_COMMAND_TESTING": "1",
        })
        return environment, log

    def test_prebuilt_fast_and_keyboard_runners_use_exact_derived_products(self):
        for runner, expected_count in (
            (FAST_RUNNER, 1),
            (KEYBOARD_SENTINEL_RUNNER, 24),
        ):
            with self.subTest(runner=runner.name), tempfile.TemporaryDirectory() as temporary:
                environment, log = self._prebuilt_runner_environment(temporary)
                output = pathlib.Path(temporary) / "output"
                derived = pathlib.Path(temporary) / "derived"
                completed = subprocess.run(
                    [str(runner), "--udid", PINNED_UDID,
                     "--output", str(output), "--without-building",
                     "--derived-data-path", str(derived)],
                    cwd=ROOT, env=environment, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)
                commands = log.read_text().splitlines()
                self.assertEqual(len(commands), expected_count)
                for command in commands:
                    self.assertIn("test-without-building", command)
                    self.assertIn(f"-derivedDataPath {derived}", command)
                    self.assertIn("-parallel-testing-enabled NO", command)
                source = runner.read_text()
                self.assertEqual(
                    source.count("exec Scripts/with-inputdec-simulator-test-lock.sh"),
                    1,
                ) if runner == KEYBOARD_SENTINEL_RUNNER else self.assertEqual(
                    source.count("Scripts/with-inputdec-simulator-test-lock.sh"),
                    1,
                )

    def test_without_building_requires_explicit_derived_data_path(self):
        for runner in (FAST_RUNNER, KEYBOARD_SENTINEL_RUNNER):
            with self.subTest(runner=runner.name), tempfile.TemporaryDirectory() as temporary:
                completed = subprocess.run(
                    [str(runner), "--udid", PINNED_UDID,
                     "--output", str(pathlib.Path(temporary) / "output"),
                     "--without-building"],
                    cwd=ROOT, text=True, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                self.assertEqual(completed.returncode, 64)
                self.assertIn("--derived-data-path", completed.stderr)

    def test_entry_points_never_create_clone_or_parallelize_simulators(self):
        for path in [FAST_RUNNER, LOCK_RUNNER]:
            source = path.read_text()
            with self.subTest(path=path.name):
                self.assertNotIn("simctl create", source)
                self.assertNotIn("simctl clone", source)
                self.assertNotIn("-parallel-testing-enabled YES", source)
                if path == FAST_RUNNER:
                    self.assertIn(
                        f"platform=iOS Simulator,id=${{udid}}", source
                    )
                    self.assertIn(PINNED_UDID, source)

    def _lock_command(self, *command):
        return [
            str(LOCK_RUNNER),
            "--udid",
            PINNED_UDID,
            "--",
            *command,
        ]

    def test_lock_rejects_a_live_owner_and_recovers_a_dead_owner(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = dict(os.environ)
            environment["INPUTDEC_XCTEST_LOCK_ROOT"] = temporary
            holder = subprocess.Popen(
                self._lock_command(
                    "python3", "-c", "import time; time.sleep(30)"
                ),
                cwd=ROOT,
                env=environment,
            )
            lock = (
                pathlib.Path(temporary)
                / f"inputdec-xctest-{PINNED_UDID}.lock"
            )
            try:
                deadline = time.monotonic() + 5
                while not (lock / "owner-pid").is_file():
                    if holder.poll() is not None:
                        self.fail("lock holder exited before acquiring lock")
                    if time.monotonic() >= deadline:
                        self.fail("lock holder did not acquire lock")
                    time.sleep(0.02)
                rejected = subprocess.run(
                    self._lock_command("true"),
                    cwd=ROOT,
                    env=environment,
                    check=False,
                )
                self.assertEqual(rejected.returncode, 75)
            finally:
                holder.terminate()
                holder.wait(timeout=5)

            lock.mkdir(parents=True, exist_ok=True)
            (lock / "owner-pid").write_text("99999999\n")
            recovered = subprocess.run(
                self._lock_command("true"),
                cwd=ROOT,
                env=environment,
                check=False,
            )
            self.assertEqual(recovered.returncode, 0)
            self.assertFalse(lock.exists())

    def test_nested_owner_is_inherited_but_forged_owner_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = dict(os.environ)
            environment["INPUTDEC_XCTEST_LOCK_ROOT"] = temporary
            nested = subprocess.run(
                self._lock_command(*self._lock_command("true")),
                cwd=ROOT,
                env=environment,
                check=False,
            )
            self.assertEqual(nested.returncode, 0)

            environment["INPUTDEC_XCTEST_LOCK_OWNER_PID"] = "99999999"
            forged = subprocess.run(
                self._lock_command("true"),
                cwd=ROOT,
                env=environment,
                check=False,
            )
            self.assertEqual(forged.returncode, 75)

    def test_fast_runner_writes_compact_summary_from_xcresult(self):
        source = FAST_RUNNER.read_text()
        for key in [
            '"result"',
            '"passedTests"',
            '"failedTests"',
            '"skippedTests"',
            '"startTime"',
            '"finishTime"',
            '"testDurationSeconds"',
            "xcresulttool get test-results summary",
        ]:
            self.assertIn(key, source)
        self.assertIn('[[ ! -e "$output" ]]', source)
        self.assertIn("test-without-building", source)
        self.assertIn('summary["skippedTests"] != 0', source)
        self.assertIn("duration > 30.0", source)

    def test_keyboard_sentinel_runner_is_pinned_serial_and_ordered(self):
        self.assertTrue(
            KEYBOARD_SENTINEL_RUNNER.is_file(),
            "missing persistent real-keyboard sentinel runner",
        )
        source = KEYBOARD_SENTINEL_RUNNER.read_text()
        ordered_tokens = [
            "english/autocorrection-accept-space/"
            "autocorrection-accept-space.xcresult",
            "IDAutocorrectionDecisionUITests/"
            "testCustomInteriorAcceptSpaceMatchesStock",
            "english/autocorrection-reject-before-boundary/"
            "autocorrection-reject-before-boundary.xcresult",
            "IDAutocorrectionDecisionUITests/"
            "testCustomBeforeBoundaryRejectPrecommitMatchesStock",
            "english/inline-accept/inline-accept.xcresult",
            "IDInlinePredictionLifecycleUITests/"
            "testCustomInteriorAcceptMatchesStock",
            "english/inline-dismiss-before-boundary/"
            "inline-dismiss-before-boundary.xcresult",
            "IDInlinePredictionLifecycleUITests/"
            "testCustomBeforeBoundary"
            "DismissThenTypeMatchesStock",
            "english/floating-normal/floating-normal.xcresult",
            "IDFloatingCursorUITests/"
            "testFloatingCursorNormalEndMatchesStockAndQuiesces",
            "english/floating-selection-extension/"
            "floating-selection-extension.xcresult",
            "IDFloatingCursorUITests/"
            "testFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor",
            "english/inline-formatting-bold/"
            "inline-formatting-bold.xcresult",
            "IDInlineFormattingKeyboardUITests/"
            "testRealKeyboardBoldTypingMatchesStock",
            "english/inline-formatting-autocorrection/"
            "inline-formatting-autocorrection.xcresult",
            "IDInlineFormattingKeyboardUITests/"
            "testRealKeyboardAutocorrectionPreservesBoldMatchesStock",
            "english/inline-formatting-prediction/"
            "inline-formatting-prediction.xcresult",
            "IDInlineFormattingKeyboardUITests/"
            "testRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits",
            "english/inline-formatting-marked-text/"
            "inline-formatting-marked-text.xcresult",
            "IDInlineFormattingKeyboardUITests/"
            "testRealKeyboardMarkedTextCommitPreservesActiveTraits",
            "japanese/ime-return-commit-undo/"
            "ime-return-commit-undo.xcresult",
            "IDIMECompositionLifecycleUITests/"
            "testCustomJapaneseBeforeBoundaryReturnCommitThenUndoTruth",
            "chinese/ime-candidate-commit/"
            "ime-candidate-commit.xcresult",
            "IDIMECompositionLifecycleUITests/"
            "testCustomSimplifiedChinesePinyinInteriorCandidateCommitTruth",
        ]
        for token in ordered_tokens:
            self.assertIn(token, source)
        positions = [source.index(token) for token in ordered_tokens]
        self.assertEqual(positions, sorted(positions))
        minimal_selectors = [
            "IDAutocorrectionDecisionUITests/"
            "testMinimalInteriorAcceptSpaceMatchesStock",
            "IDAutocorrectionDecisionUITests/"
            "testMinimalBeforeBoundaryRejectPrecommitMatchesStock",
            "IDInlinePredictionLifecycleUITests/"
            "testMinimalInteriorAcceptMatchesStock",
            "IDInlinePredictionLifecycleUITests/"
            "testMinimalBeforeBoundaryDismissThenTypeMatchesStock",
            "IDFloatingCursorUITests/"
            "testMinimalFloatingCursorNormalEndMatchesStockAndQuiesces",
            "IDFloatingCursorUITests/"
            "testMinimalFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor",
            "IDInlineFormattingKeyboardUITests/"
            "testMinimalRealKeyboardBoldTypingMatchesStock",
            "IDInlineFormattingKeyboardUITests/"
            "testMinimalRealKeyboardAutocorrectionPreservesBoldMatchesStock",
            "IDInlineFormattingKeyboardUITests/"
            "testMinimalRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits",
            "IDInlineFormattingKeyboardUITests/"
            "testMinimalRealKeyboardMarkedTextCommitPreservesActiveTraits",
            "IDIMECompositionLifecycleUITests/"
            "testMinimalJapaneseBeforeBoundaryReturnCommitThenUndoTruth",
            "IDIMECompositionLifecycleUITests/"
            "testMinimalSimplifiedChinesePinyinInteriorCandidateCommitTruth",
        ]
        for selector in minimal_selectors:
            self.assertIn(selector, source)
        self.assertEqual(len(minimal_selectors), 12)
        for token in [
            PINNED_UDID,
            "with-inputdec-simulator-test-lock.sh",
            "Scripts/reset-text-input-learning.py",
            "Scripts/provision-ime-keyboards.sh",
            "-parallel-testing-enabled NO",
            "-collect-test-diagnostics never",
            "platform=iOS Simulator,id=${udid}",
            '"groups"',
            '"methods"',
            '"result"',
        ]:
            self.assertIn(token, source)
        for token in [
            'xcrun simctl boot "$udid"',
            'xcrun simctl bootstatus "$udid" -b',
        ]:
            self.assertIn(token, source)
        boot = source.index('xcrun simctl boot "$udid"')
        bootstatus = source.index('xcrun simctl bootstatus "$udid" -b')
        reset = source.index("Scripts/reset-text-input-learning.py")
        provisioning = source.index("Scripts/provision-ime-keyboards.sh")
        self.assertLess(boot, bootstatus)
        self.assertLess(bootstatus, reset)
        self.assertLess(reset, provisioning)
        self.assertEqual(source.count('xcrun simctl boot "$udid"'), 1)
        self.assertNotIn("simctl shutdown", source)
        self.assertEqual(
            source.count('xcodebuild "$action"'),
            1,
            "the shared method function must be the only xcodebuild site",
        )
        self.assertEqual(
            source.count("\nrun_method \\\n"),
            24,
            "each sentinel method must be a distinct XCTest invocation",
        )
        self.assertEqual(source.count(".xcresult\" \\"), 24)
        self.assertIn('readonly expected_os_version="26.5"', source)
        self.assertIn('readonly expected_os_build="23F73"', source)
        self.assertIn('"skippedTests": 0', source)
        self.assertIn('"failedTests": 0', source)
        self.assertIn(
            "wall_duration > 1200",
            source,
            "the serialized 24-method gate needs a proportional wall budget",
        )
        self.assertNotIn("wall_duration > 600", source)
        self.assertNotIn("IDZZPersistentKeyboardSentinelUITests", source)
        self.assertNotIn(
            "testZZPersistentSentinelCustomBeforeBoundary", source
        )
        self.assertNotIn("simctl erase", source)
        self.assertNotIn("simctl create", source)
        self.assertNotIn("simctl clone", source)
        self.assertNotIn("-parallel-testing-enabled YES", source)
        self.assertNotIn(
            "$EPOCHSECONDS",
            source,
            "EPOCHSECONDS is not loaded by the repository's zsh runtime",
        )
        self.assertIn("date +%s", source)

    def test_keyboard_sentinel_retries_only_known_readiness_diagnostics(self):
        self.assertTrue(
            KEYBOARD_SENTINEL_RUNNER.is_file(),
            "missing persistent real-keyboard sentinel runner",
        )
        source = KEYBOARD_SENTINEL_RUNNER.read_text()
        for diagnostic in [
            'Failed to determine hittability of "(k|n)" Key: '
            "Activation point invalid and no suggested hit points based on "
            "element frame",
            "Expected native inline prediction was absent",
            "Expected native candidate 'address' was not actionable",
        ]:
            self.assertIn(diagnostic, source)
        self.assertIn("attempt < 3", source)
        self.assertIn("RETRY keyboard-readiness", source)
        self.assertIn(
            'rg -q -- "$keyboard_readiness_diagnostic"', source
        )
        self.assertNotIn(
            'rg -Eq -- "$keyboard_readiness_diagnostic"', source
        )
        self.assertIn(
            'rg -Fq -- "$prediction_readiness_diagnostic"', source
        )
        self.assertIn(
            'rg -Fq -- "$autocorrection_readiness_diagnostic"', source
        )
        self.assertIn(
            "launchctl kickstart -k "
            "user/501/com.apple.TextInput.kbd",
            source,
        )
        readiness = source.index(
            'rg -Fq -- "$prediction_readiness_diagnostic"'
        )
        keyboard_restart = source.index(
            "launchctl kickstart -k "
            "user/501/com.apple.TextInput.kbd"
        )
        retry = source.index("RETRY keyboard-readiness")
        self.assertLess(readiness, keyboard_restart)
        self.assertLess(keyboard_restart, retry)
        self.assertNotIn("RETRY semantic", source)

    def test_certification_runner_is_locked_pinned_and_complete(self):
        self.assertTrue(
            CERTIFICATION_RUNNER.is_file(),
            "missing stable iOS 26 certification runner",
        )
        source = CERTIFICATION_RUNNER.read_text()
        ordered_runners = [
            "run-text-input-fast.sh",
            "run-text-input-keyboard-sentinels.sh",
            "run-ime-complete-matrix.sh",
            "run-autocorrection-complete-matrix.sh",
            "run-inline-prediction-complete-matrix.sh",
        ]
        positions = []
        for runner in ordered_runners:
            self.assertEqual(source.count(runner), 1)
            positions.append(source.index(runner))
        self.assertEqual(positions, sorted(positions))
        for token in [
            PINNED_UDID,
            "with-inputdec-simulator-test-lock.sh",
            "--repetitions 2",
            "--orders stock-custom,custom-stock",
            '"$udid" "$autocorrection_output" 26.5 23F73',
            '"$udid" "$inline_prediction_output" 26.5 23F73',
            "fast/summary.json",
            "keyboard-sentinels/summary.json",
            "ime/summary.json",
            "autocorrection/summary.json",
            "inline-prediction/summary.json",
            '"overallResult"',
            '"logicalRows"',
            '"comparisonCount"',
            '"hostExecutionCount"',
            'sentinels.get("passedTests") != 24',
            "materialize-authority",
            "--source fresh",
        ]:
            self.assertIn(token, source)
        self.assertNotIn("simctl create", source)
        self.assertNotIn("simctl clone", source)
        self.assertNotIn("-parallel-testing-enabled YES", source)

    def test_group_runner_provisions_english_us_outside_ime(self):
        source = (ROOT / "Scripts/run-text-input-group.sh").read_text()
        self.assertIn('if [[ "$subsystem" == "ime" ]]', source)
        self.assertIn("Scripts/provision-ime-keyboards.sh", source)
        self.assertIn("Scripts/provision-english-us-keyboard.sh", source)
        english = (ROOT / "Scripts/provision-english-us-keyboard.sh").read_text()
        self.assertIn("en_US@hw=Automatic", english)
        self.assertIn('"primaryLanguages": ["en-US"]', english)
        self.assertIn("AppleKeyboardsPreferencesChangedNotification", english)
        self.assertIn("user/501/com.apple.TextInput.kbd", english)
        self.assertIn("function write_profile()", english)
        self.assertEqual(english.count("write_profile"), 3)
        self.assertNotIn("en_US@sw=QWERTY", english)
        demo = (ROOT / "App/IDDemoViewController.m").read_text()
        stock = (ROOT / "StockOracleHost/main.m").read_text()
        autocorrection = (
            ROOT / "UITests/IDAutocorrectionDecisionTestSupport.m"
        ).read_text()
        inline = (
            ROOT / "UITests/IDInlinePredictionLifecycleTestSupport.m"
        ).read_text()
        for class_name, body in (
            ("IDDemoEnglishUSTextView", demo),
            ("IDStockEnglishUSTextView", stock),
        ):
            self.assertIn(class_name, body)
            self.assertIn("UITextInputMode.activeInputModes", body)
            self.assertIn('isEqualToString:@"en-US"', body)
            self.assertIn('NSClassFromString(@"UIKeyboardInputMode")', body)
            self.assertIn('@"keyboardInputModeWithIdentifier:"', body)
            self.assertIn('@"en_US@hw=Automatic"', body)
            self.assertIn(
                'NSClassFromString(@"UIKeyboardInputModeController")', body
            )
            self.assertIn('@"sharedInputModeController"', body)
            self.assertIn('@"_setCurrentInputMode:force:"', body)
            self.assertIn("reloadInputViews", body)
            self.assertIn("UIKeyboardTypeASCIICapable", body)
        self.assertEqual(autocorrection.count("IDForceEnglishUSInputMode"), 2)
        self.assertEqual(inline.count("IDForceEnglishUSInputMode"), 2)

    def test_group_runner_preserves_boot_for_inline_offer_readiness(self):
        source = (ROOT / "Scripts/run-text-input-group.sh").read_text()
        self.assertIn('max_attempts=20', source)
        self.assertIn('preserve_boot_retry=1', source)
        self.assertIn('RETRY_PRESERVING_BOOT', source)
        self.assertIn('cp -R "$last_retained/provisioning"', source)
        self.assertIn('cp -R "$last_retained/learning-reset"', source)
        self.assertIn("Timed out while synthesizing event.", source)
        self.assertIn('rg -Fq -- "$hid_event_readiness_diagnostic"', source)
        preserving = source.index('if (( preserve_boot_retry != 0 ))')
        erase = source.index('xcrun simctl erase "$udid"', preserving)
        self.assertLess(preserving, erase)

    def test_group_runner_removes_stale_test_runner_on_preserved_boot_retry(self):
        source = (ROOT / "Scripts/run-text-input-group.sh").read_text()
        start = source.index('if (( preserve_boot_retry != 0 ))')
        end = source.index('else', start)
        preserved_boot = source[start:end]
        self.assertIn(
            'xcrun simctl uninstall "$udid"', preserved_boot
        )
        self.assertIn(
            'com.inputdec.demo.uitests.xctrunner', preserved_boot
        )
        uninstall = source.index('xcrun simctl uninstall "$udid"', start)
        launch = source.index('xcodebuild test-without-building', start)
        self.assertLess(uninstall, launch)

    def test_keyboard_key_wait_requeries_after_keyboard_replacement(self):
        source = (ROOT / "UITests/IDHIDEventTestSupport.m").read_text()
        start = source.index("BOOL IDHIDTapSoftwareKeyboardKey")
        end = source.index("BOOL IDHIDTypeSoftwareKeyboardText", start)
        tap = source[start:end]
        self.assertIn("NSDate *hittableDeadline", tap)
        self.assertIn("matchingIdentifier:key", tap[tap.index("hittableDeadline"):])
        self.assertIn("[NSThread sleepForTimeInterval:0.05]", tap)
        self.assertIn('application.buttons[@"Continue"]', tap)
        self.assertNotIn("object:element", tap)


if __name__ == "__main__":
    unittest.main()
