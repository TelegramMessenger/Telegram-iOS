# Block `_internalTextLayoutController` withdrawal report

## Decision and exact receiver-specific private-surface delta

Decision: `safeFallback` on iOS 26.5 build 23F73.

Exactly one production method was removed: `-[IDBlockTextView(PrivateCallbacks) _internalTextLayoutController]`. The change does not generalize to another receiver. `-[IDTextView(PrivateCallbacks) _internalTextLayoutController]`, `-[IDBlockTextView(PrivateCallbacks) textLayoutController]`, and the clean-room `IDRichTextLayoutController` remain.

The block callback source hash changed from `3a52ebc0a24b531acef8d45e1f3b67ac8fb1d7e8` to `a85a6842aaec40eabe3c9654ee322189632c0ca5`. The permanent decision is pinned in `Tests/Fixtures/BlockInternalTextLayoutControllerAuthorization-iOS26.5.json` (hash `42a45a0e8c6e720471b7716c9560bc4270b0f177`).

## UIKitCore xrefs, pseudocode, and receiver provenance

Hopper inspection of UIKitCore iOS 26.5 found the selector message-send stub at `0x214d520` and exactly three direct UIKit xrefs:

- `0xc084fc`: concrete `_UITextLayoutCanvasView` receiver, containing method entry `0xc0825c`.
- `0x15d7924`: concrete `UITextField` receiver, containing method entry `0x15d790c`.
- `0x16215dc`: concrete `UITextView` receiver, containing method entry `0x16215c4`.

The stock `-[UITextView _internalTextLayoutController]` provider is at `0x1621580`. Refreshed pseudocode showed no direct UIKit send to an `IDBlockTextView`-like scroll host. The receiver ledger and pseudocode observations are recorded in `docs/hopper/UIKitCore-iOS26.5.md` under “Block `_internalTextLayoutController` receiver ledger.”

This is receiver-specific evidence: UIKit still owns and uses the selector on its concrete canvas, field, and stock text-view objects.

## Diagnostic rebasing and stock-only test-wrapper boundary

Custom block diagnostics now take `editor.id_richLayoutController` explicitly through `IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting`. The observer also stores that explicit controller. The legacy one-argument diagnostic remains a stock adapter and obtains the private controller only through `IDPrivateTestingInternalTextLayoutController`.

The test-only private-surface manifest therefore classifies `_internalTextLayoutController` on `UITextView`, not `IDBlockTextView`. The permanent block runtime contract performs message-free method-list inspection and constructs the selector token from fragments, preserving `testPrivateTestingOperationsStayBehindPrivateUIKitWrappers`.

## Retained/withdrawn method-list and binary proof

The temporary control was exact numeric `0/1` and guarded only the candidate method. The paired focused proof passed 6/6 in both states:

- retained: `.block-internal-controller-task3-retained-green.xcresult`, 68.926 seconds wall time;
- withdrawn: `.block-internal-controller-task3-withdrawn-green.xcresult`, 68.456 seconds wall time.

Corresponding products were not identical, proving that the experiment exercised different code:

| Product | Retained SHA-256 | Withdrawn SHA-256 |
|---|---|---|
| app debug dylib | `561ab65a7db9e57295fb8e798e28c77b1ab3f97bdb2afc93f8d1299d97cbe622` | `9ff2dcc5bd2b4a6f3f082cafdc0e299c06826cee0ce5b1b8f5148adbe0b58cca` |
| unit-test bundle | `827f45ac62a4ca882ff883cbe73016cc32f84e55ea7431752ed321772a387836` | `d57bb0125bde0563e49a062d76ecb58300f0ae03d4f4a38bb117926d7f9d1c74` |
| UI-test bundle | `5c4c942dc62a63130ba9747859ca61693d445bdf38c6578cb3130ccb3f038d93` | `a9f9fad05e43a0256b5facd6890201ce0e8a63c3ddbb3551a843fe16aadf3929` |

The broader prebuilt products also differed:

| Product | Retained SHA-256 | Withdrawn SHA-256 |
|---|---|---|
| app debug dylib | `d516528591ca29f341e2ba26e7487df106bb03eec8887a1d47460579dc8a8b0d` | `24017367f8d291c6ae08973bddcfdc631eb67cb50a79571f45c20ae471d9e79f` |
| unit-test bundle | `cbe2ccadd48186085c537a50a64f6fdc7ecfa29ae7c5b51a569b9891828732f6` | `baa8939c6031871928e289d62e85bd5fa6e73f79eeaee88f4d0b848787ee8a2e` |
| UI-test bundle | `6e7e93160345b78c3907ec0b1f63f57ff24d5a886b8262ea61f045a7810b8b45` | `f37b3cf371452f098b873d8f3c4018613a825cd8528e2a4675da18a1be03c898` |

## Controller/range authority matrix

| Concern | Permanent authority | Result |
|---|---|---|
| block layout-controller lookup | `IDBlockTextView.textLayoutController` | retained, one local provider |
| block range, affinity, geometry, and layout | `IDRichTextLayoutController` | retained, one clean-room authority |
| flat editor private compatibility | `IDTextView._internalTextLayoutController` | retained, one provider |
| stock test oracle lookup | `IDPrivateTestingInternalTextLayoutController(UITextView *)` | retained, stock-only |
| custom floating lifecycle diagnostics | explicit `editor.id_richLayoutController` | no private lookup |
| forwarding or dynamic-resolution substitute | none | zero implementations |

The retained/withdrawn authority suites each passed 136/136 with no failures or skips: `.block-internal-controller-task4-retained-authority.xcresult` (5.121 seconds) and `.block-internal-controller-task4-withdrawn-authority.xcresult` (4.922 seconds).

## Lifecycle reconstruction matrix

Each variant passed all five selected lifecycle tests, including three live-HID reconstruction epochs, editable/selectable transitions, hosted graph reconstruction, window-detach interruption, quiescence, and old-owner deallocation:

- retained: `.block-internal-controller-task4-retained-lifecycle.xcresult`, 5/5, 115.956 seconds;
- withdrawn: `.block-internal-controller-task4-withdrawn-lifecycle.xcresult`, 5/5, 110.756 seconds.

No crash, skip, stale graph owner, or lifecycle leak was observed.

## Touch/loupe/handles/autoscroll/floating/bidi/large-document matrix

The paired 14-test physical matrices covered horizontal BiDi/emoji/consecutive-empty-block navigation, large-document select-all while visible geometry changes, native loupe tracking, logical endpoint roles, cross-structural-boundary handle dragging, top/bottom edge autoscroll, multi-block floating cursor, BiDi reversal, anchor crossing, selection autoscroll, batched floating/touch chrome, and selectable noneditable copy-menu cancellation/reentry.

- retained: 14/14, zero failures/skips, 448.702 seconds XCTest duration (`.block-internal-controller-task4-retained-ui.xcresult`);
- withdrawn: 14/14, zero failures/skips, 447.161 seconds XCTest duration (`.block-internal-controller-task4-withdrawn-ui.xcresult`).

The retained Xcode command later spent 600 seconds in a timed-out `simctl diagnose`; the withdrawn command entered the same post-test collector and it was stopped after XCTest had passed. Those diagnostic tails explain the 1050.997- and 540.449-second result wall times and are not behavioral differences.

The final unconditional ordinary-build matrix passed 14/14 with zero failures/skips in 447.953 seconds XCTest time and 453.111 seconds result wall time: `.block-internal-controller-task6-final-ui.xcresult`. `-collect-test-diagnostics never` eliminated the 600-second tail.

## Permanent source/runtime/Release contracts

The post-decision focused suite passed 43/43 with zero failures/skips: `.block-internal-controller-task5-permanent-focused.xcresult`.

The first complete-unit attempt exposed one source-boundary violation: the new integration test embedded the private selector literally. No behavior test failed. After constructing the observation token from fragments, the exact wrapper-boundary and permanent-state tests passed 2/2 in `.block-internal-controller-task6-wrapper-repair.xcresult`, and the repeated complete unit suite passed 1007/1007 with zero failures/skips in 21.524 seconds XCTest time (`.block-internal-controller-task6-all-units.xcresult`). The failed evidence is preserved as `.block-internal-controller-task6-all-units-first-failure.xcresult`.

The bounded semantic gate passed 287/287 with zero failures/skips in 14.064 seconds (`.block-internal-controller-task6-fast/summary.json`).

Two consecutive `xcodegen generate` runs produced the identical project hash `1b3aa0f3f9c553766b49be233545e201d6d8840306142eb644bfe606b13d9677`.

The optimized Release simulator product built successfully as universal `x86_64 arm64`. For each architecture, unique `nm` implementation-address counts were:

| Contract | arm64 | x86_64 |
|---|---:|---:|
| block `_internalTextLayoutController` | 0 | 0 |
| block `textLayoutController` | 1 | 1 |
| flat `_internalTextLayoutController` | 1 | 1 |
| representative rich-controller authority method | 1 | 1 |
| block forwarding/dynamic-resolution substitute | 0 | 0 |

`otool -ov` confirmed the Objective-C method metadata/string tables, while `strings` found zero experiment-control/header tokens.

## Manifest counts and before/after protected hashes

Inventory counts remain exactly 127 production capability members, 53 reference-only members, and 24 test-only capability members. The production manifest remains byte-for-byte unchanged.

| File | Before | After | Interpretation |
|---|---|---|---|
| block callbacks | `3a52ebc0a24b531acef8d45e1f3b67ac8fb1d7e8` | `a85a6842aaec40eabe3c9654ee322189632c0ca5` | candidate deleted |
| flat callbacks | `11161058090d3efe7f021b62bb2be34929efbd6c` | same | protected |
| `IDPrivateUIKit.h` | `1e8932f8df33ac5c8cf4f001be51524553f37686` | `6aecd73543a035ba1c11d20e34f42bd02234133a` | explicit diagnostic API |
| `IDPrivateUIKit.m` | `37c371abfcf5e7758594c5ffb42e6aa81bd2d180` | `a400fdde5592a2cbaffc267dcf33bc7266d19495` | stock/custom diagnostic split |
| rich private callbacks | `c8325530e00330c3895778bc90c9849692a561f0` | same | protected |
| rich controller | `dc1adeee6eae9cd0cf012ee035ef30a73714812a` | same | protected |
| rich internal header | `821a31ec61d9351e8ce146c2a6d8cbbb3d87adc0` | same | protected |
| production manifest | `d2143fb0a8d056793885a4a1ea117d93a83fff59` | same | protected |
| test-only manifest | `bca0b9181fb9bc79aa71d6617a821375b0ee44ff` | `8861741fbdfbb2f915753dadd47beca5ac0b13b4` | stock-only provenance |

## Real-keyboard reachability decision

The long real-keyboard sentinel matrix was not rerun. This pass did not change the input-controller, checking, autocorrection, prediction, marked-text, keyboard database, or IME authority. Its production changes are limited to the block receiver and floating-lifecycle diagnostic plumbing. Hopper’s relevant selector xrefs remain concrete canvas, text-field, and stock text-view receivers. Existing real-keyboard certification therefore remains applicable to the unchanged reachable code.

## Experiment-token and substitute-provider audit

The temporary header was deleted and the control token is absent from `App`, `TextView`, `PrivateUIKit`, `Tests`, `UITests`, `Scripts`, `project.yml`, and the generated project. Runtime and source contracts require block method absence, preserved flat/block authorities, explicit rich-controller custom diagnostics, stock-only wrapper provenance, and no forwarding or `resolveInstanceMethod:` substitute. Release `strings` found zero experiment tokens; unique symbol counts found zero substitutes on both architectures.

## Dirty-tree/index/process/nonparallel-testing hygiene

All simulator XCTest commands used `Scripts/with-inputdec-simulator-test-lock.sh` and `-parallel-testing-enabled NO`; no XCTest processes overlapped. Final process inspection found no live `xcodebuild test`, `xctest`, or `XCTRunner` process. `git diff --check` passed and `git diff --cached --quiet` confirmed an empty index.

The exploration worktree was already extensively dirty and remains so (2,176 status entries, largely generated evidence/derived products). No unrelated source was reset, staged, or deleted. The pass touched only its scoped implementation, diagnostics, probe, tests, generated project, Hopper notes, plans/specification, fixture, and this report.

## iOS 26.5 build 23F73 limitation

The `safeFallback` authorization is pinned specifically to UIKitCore and simulator behavior on iOS 26.5 build 23F73. It does not assert that another OS release has identical private receiver topology. Broader deployment must retain runtime/version gating and repeat this receiver-specific authorization when UIKit changes.
