# Persistent English-US Spelling Profile Report

## Outcome

The persistent-profile infrastructure is complete and behaves as designed.
The pinned K3 simulator was explicitly provisioned once, and the subsequent
spelling runner validated and reused that boot without rebooting, restarting
the keyboard service, mutating an input mode, or retrying the stock result.

The live run also disproved the input-mode hypothesis. A stock `UITextView`
reported both public UIKit primary-language readings as `en-US`, but native
TextKit 2 still produced no temporary spelling annotation or red marker pixels
for `mispelled`. The focused custom spelling family therefore did not run.
This is a shared stock spelling-service prerequisite failure, not evidence of a
custom-editor regression.

## Implementation

- `Scripts/english_us_keyboard_profile.py` executes six read-only `simctl`
  commands and requires exact iOS 26.5/23F73, `en_US`, one `en-US` language,
  one `en_US@hw=Automatic` keyboard, and expanded input modes.
- `Scripts/provision-english-us-keyboard.sh` now writes the complete locale,
  language, and keyboard profile before and after its single reboot. Its
  explicit `--verify` mode runs the shared exact validator; existing
  two-argument keyboard-test callers remain compatible.
- `IDSpellingReadinessObservation` schema 2 records
  `UITextInputMode.currentInputMode.primaryLanguage` and the hosted
  `UITextView.textInputMode.primaryLanguage`. `inputModeMismatch` outranks the
  annotation and rendering statuses.
- `Scripts/run-verification-stabilization.sh` validates persistent state before
  building, performs one stock preflight, and contains no daemon-restart or
  second-attempt branch.

No production editor source or production private-API surface changed.

## Test Evidence

Focused test-driven gates:

- English profile Python module: 8 passed.
- Verification classifier Python module: 11 passed.
- Stabilization runner fake-toolchain methods: 4 passed.
- Complete retained readiness class excluding the separately preserved live
  stock prerequisite: 18 passed, zero failures and zero skips in
  `.persistent-english-readiness-unit-final.xcresult`.

The broader `test_text_input_test_commands` run reached 61 methods. The four
new stabilization methods passed. Its remaining failures are in pre-existing
dirty IME/group-runner work and sandboxed `ps`/`nice` behavior; the focused
current-pass tests were rerun independently and are green.

## Live Evidence

Provisioning evidence:

- `.persistent-english-us-provision-1/verification/summary.json`
- Result: `verified`
- Runtime: iOS 26.5 build 23F73
- Profile: locale `en_US`, languages `[en-US]`, input modes
  `[en_US@hw=Automatic]`, expanded `true`
- Simulator lifecycle: one explicit shutdown/boot during provisioning

No-reboot spelling evidence:

- `.persistent-english-us-spelling-live-1/summary.json`
- Result: `Blocked`, classification `stockUnavailable`
- Preflight attempts: 1
- Service restarts: 0
- Semantic retries: 0
- Public current primary language: `en-US`
- Hosted input primary language: `en-US`
- Continuous checking: enabled
- Temporary annotation: absent after 5.003 seconds
- Marker pixels: 0
- Focused custom family: not executed

The simulator preference read after provisioning also showed
`KeyboardLastUsed = en_US@sw=QWERTY;hw=Automatic`. The stale multilingual
`KeyboardsCurrentAndNext` preference no longer controls the actual public
UIKit mode observed by the stock editor, so it does not explain the missing
annotation.

## Conclusion

Steady-state spelling runs are now faster and fail closed: once K3 is in its
English profile, they avoid every reboot and automatic recovery attempt. The
next spelling investigation should focus below input-mode selection—on the
keyboard/checking-controller request path that schedules
`checkSpellingForWordInRange:`—while retaining this profile gate as an
environmental prerequisite.

