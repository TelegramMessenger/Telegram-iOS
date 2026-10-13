# InputDec Backend Introduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor InputDec's Objective-C UIKit behavior kernel into telegram-ios and land `IDTextEditorBackend` as a second, opt-in `RichTextInputBackend` behind the already-complete Telegram input seam, without changing any shipped behavior.

**Architecture:** A new Objective-C SwiftPM/Bazel target `RichTextInputDecObjC` holds the 16 vendored kernel files (verbatim except three mechanical edits), a compiled-in copy of the runtime contract manifest, and a set of telegram-ios-authored host classes (a document-neutral layout controller, an `NSTextStorage` façade, backend-owned position/range identity, and runtime-installed private canvas callbacks). A Swift adapter `IDTextEditorBackend` conforms to the seam's `RichTextInputBackend` and translates every incoming Objective-C callback into the six Swift client protocols through one `@objc` bridge protocol; the shared Swift contracts never become `@objc` and never see a private selector. Backend selection happens in an internal canvas factory, never inside the protocol.

**Tech Stack:** Objective-C (ARC, iOS 13 compile floor / **iOS 17.0 runtime floor** per decision 2 — the kernel is *certified* on 26.5/23F73 but selection is gated on 17.0 plus live contract evaluation), Swift 5.9, SwiftPM (`Package.swift`) + Bazel (`BUILD`, `objc_library` → `swift_library`), XCTest on iPhone 17 Pro K3 (`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, iOS 26.5 build 23F73) and K1 (`CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9`), `Make.py` Bazel app build.

**Spec:** /Users/isaac/Documents/InputDec/docs/superpowers/specs/2026-08-13-telegram-rich-text-input-backend-contract-design.md

---

## Prerequisite

This plan is the **second half** of a two-plan programme. The first half is:

~~`docs/superpowers/plans/2026-08-16-richtext-input-backend-seam.md`~~ — **that plan was REMOVED when stage 1 was squashed to master on 2026-08-24, per this repo's convention of not carrying plan/spec markdown (see master's own `b26ebebb82 chore: drop the plan and spec markdown files`). Stage 1 is COMPLETE: all 60 task sections, every automated gate green.**

**What survives, and what to read instead:**
- `docs/superpowers/richtext-seam-stage2-inheritance.md` — **gate item 23 verbatim (this plan's entry condition) and the twelve deviations that bind stage 2.** Start here.
- `docs/superpowers/phase6-gate-record-2026-08-24.md` — the gate as actually run, item by item, including the two gate commands that were themselves defective.
- `docs/superpowers/richtext-stock-divergences-followups.md` — three divergences from stock UIKit that stage 1 deliberately did not change, and what changing one would require.
- `submodules/TelegramUI/Components/RichTextEditor/docs/input-backend-differential-baseline.md` — the corpus baseline this plan's Stage D re-runs and compares against.

**No task in this document may start before every item below is green.** These were the seam plan's own "Phase 6 gate" section (now recorded in `phase6-gate-record-2026-08-24.md` and, for the one item stage 1 could not discharge, `richtext-seam-stage2-inheritance.md`, the ten numbered boxes), restated here as a hard entry checklist. Verify each by running the stated command and reading its output — not by reading the seam plan's checkboxes.

Throughout this plan, `PKG` = `/Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor`, and every relative path in a command is relative to `PKG` unless it starts with `submodules/` (in which case it is relative to the repo root, because that is where `git` runs).

- [ ] **0. Tag the baseline — do this first, before any other item.** The seam plan's gate text says `git diff <baseline>..HEAD` without ever naming a tag, so this plan creates one:
  ```sh
  cd /Users/isaac/build/telegram/telegram-ios && git tag inputdec-baseline && git rev-parse inputdec-baseline
  ```
  Every "unchanged since the baseline" check in this document diffs against `inputdec-baseline`. It is created at the seam plan's final commit, i.e. at the moment every item below is green.
- [ ] **1. All pre-existing Telegram tests pass.** `cd "$PKG" && swift test` → `0 failures` (Core, macOS, including the source-boundary suite) and `cd "$PKG" && Scripts/iostest.sh` → `Executed <N> tests, with 0 failures` (full UIKit suite, K1).
- [ ] **2. All backend contract tests pass for `.legacy`.**
  ```sh
  cd "$PKG" && for s in BackendMutationContractTests BackendRevisionContractTests \
    BackendPublicationContractTests BackendSelectionContractTests BackendMarkedTextPolicyTests \
    BackendReentrancyTests BackendAttachDetachTests BackendEditPolicyTests; do
      Scripts/iostest.sh "RichTextEditorUIKitTests/$s" || echo "FAILED $s"; done
  ```
  → no `FAILED` lines.
- [ ] **3. There is no intentional behavior or visual change.** The seam plan's characterization is **in-source XCTAssert expectations under `Tests/RichTextEditorUIKitTests/Characterization/`** — there is no JSON fixture corpus anywhere in this programme. Check the directory exists and is non-empty *first*, so a wrong path fails loudly instead of passing vacuously:
  ```sh
  cd "$PKG" && test "$(git ls-files Tests/RichTextEditorUIKitTests/Characterization/ | wc -l | tr -d ' ')" -gt 0 \
    || { echo "Characterization directory is empty or misspelled — STOP"; exit 1; }
  git log --oneline inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/
  ```
  The log must show only the Phase-0 commits that *created* the suites, with no later commit that edits an expectation. Plus the seam plan's 22-item manual checklist, run on K1 with Debug Settings ▸ "Force Text Field v2" on.
- [ ] **4. UIKit witnesses contain routing only.** `cd "$PKG" && swift test --filter RichTextEditorCoreTests.RouterWitnessBodyTests` → passes, and its `enabledWitnesses` set names every routed witness across all eleven families (the suite's own final assertion fails if an enabled name is not found).
- [ ] **5. Shared Swift contracts contain no private selector names.** `cd "$PKG" && swift test --filter RichTextEditorCoreTests.InputBackendSourceBoundaryTests` → passes, including `test_sharedContracts_containNoPrivateOrInputDecNames` (R1) and `test_privateRuntimeLookups_areConfinedToTheInventoriedFiles` (R1b, allow-list still exactly `NativeTextChecking.swift` + `DocumentCanvasView+NativeTextCheckingClient.swift`).
- [ ] **6. Backend identity is lifetime-fixed.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/BackendAttachDetachTests` → passes, including `test_attachTwice_throwsAlreadyAttached_andPreservesTheFirstAttachment` and `test_interactionContainerViewIdentity_isStableForTheBackendLifetime`.
- [ ] **7. All external changes use explicit synchronization.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/BackendRevisionContractTests` → passes, plus `swift test --filter RichTextEditorCoreTests.InputBackendSourceBoundaryTests` → `test_exactlyOneWritableSelectionAuthority` clean (R7 baseline reached zero).
- [ ] **8. Large selection presentation is bounded.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/BoundedSelectionGeometryTests` → passes, in particular `test_boundedRequestRealizesNoAdditionalBlockViews` on the 500-paragraph document.
- [ ] **9. TextKit 1 and TextKit 2 pass the same backend semantic suite.** `cd "$PKG" && MATRIX_MIN_SUITES=30 Scripts/matrix.sh; echo "exit=$?"` → `exit=0`. The floor is not decoration: `matrix.sh` derives `SUITES` from the filesystem, so without it "the matrix passed" can mean "the matrix discovered nothing" (seam Phase-6 gate item 9 runs it with the same floor for that reason). **Record the `=== matrix over <N> suites` count printed by this run** — Task B1 Step 4 and Task D5 Step 1 both compare against it.
- [ ] **10. SwiftPM and Bazel builds pass at the iOS 13 floor.** `cd "$PKG" && swift build` green, `swift test` green, and a full `python3 build-system/Make/Make.py … build --configuration=debug_sim_arm64` → `BUILD SUCCEEDED`. Also `swift test --filter RichTextEditorCoreTests.InputBackendSourceBoundaryTests` → `test_noInputDecSourcesAndNoObjectiveCUnderTheSwiftTarget` passes (R8 clean, i.e. no InputDec source has entered the package yet).
- [ ] **11. `LegacyRichTextInputBackend` is the sole backend implementation**, the backend exclusively owns input state and UIKit identity (R6 baseline reached zero), `DocumentCanvasView` is a thin router plus visual host, and the six Telegram clients exclusively own their concerns.
- [ ] **12. The eight contract suites are backend-parameterised** (decision 10 — seam gate item 11). Two checks, because this plan's Task C3 Step 7 does not compile without both:
  ```sh
  cd "$PKG" && grep -c 'BackendContractCases' Tests/RichTextEditorUIKitTests/InputBackend/Backend*ContractTests.swift
  cd "$PKG" && grep -c '^final class Backend.*ContractTests' Tests/RichTextEditorUIKitTests/InputBackend/*.swift
  ```
  → the first prints `1` for each of the eight files; the second prints `0` (none is `final`, or stage 2 cannot subclass them). Also `grep -n 'LegacyRichTextInputBackend' Tests/RichTextEditorUIKitTests/InputBackend/Backend*ContractTests.swift` → exactly eight lines, one `makeBackend()` override apiece. **If this item is red, decision 10 did not land and Stage C will lose 54 tests of coverage** — do not work around it here by restating assertions.
- [ ] **13. The differential corpus is green against the legacy backend** (decision 5 — seam gate item 12). `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/LegacyDifferentialTests` → 4 passing across all 68 scenarios, and `PKG/docs/input-backend-differential-baseline.md` exists with its per-family counts and the pinned simulator `(device, OS)` pair. **Record those numbers here** — this plan's Stage D re-runs the same corpus against `.inputDec` and compares against exactly this baseline, so a missing or stale baseline makes the Stage D comparison meaningless rather than merely inconvenient.

If any item is red, stop. The seam is the deliverable that has value on its own; this plan is optional work layered on top of it.

---

## Global Constraints

Copied from the spec. These bind every task in this document.

1. **iOS 13 deployment floor.** `Package.swift` declares `platforms: [.iOS(.v13), .macOS(.v10_13)]` and the consuming `ios_application` declares `minimum_os_version = "13.0"`. Hard invariant 12: *the seam cannot raise the iOS 13 deployment floor.* Every vendored `.m` must **compile** at the floor; the ID backend is only ever **selected** at or above **iOS 17.0** (decision 2).

   **Every `@available` in this plan is `iOS 17.0`, not 26.0.** All 21 annotations were swept when decision 2 replaced the exact-build gate with a floor, so the Swift availability boundary and the runtime gate now agree — a mismatch between them is the bug this constraint exists to prevent. If a specific site turns out to genuinely require an iOS-26 symbol, that is a finding worth reporting: the vendored kernel contains **no** `API_AVAILABLE` and no version branching at all (`rg 'API_AVAILABLE|@available|isOperatingSystemAtLeast'` over `ID/TextView`, `ID/PrivateUIKit`, `ID/App` returns zero hits), so nothing in it should need one. Raise it rather than re-pinning one annotation to 26.0 and leaving the two boundaries out of step.
2. **SwiftPM and Bazel remain authoritative builds** (hard invariant 13). Both must be updated in the same commit. `PKG/BUILD` globs `Sources/RichTextEditorUIKit/**/*.swift` only — an `.m`/`.h` under that tree compiles under `swift test` and is *silently dropped* from the app.
3. **Private API remains inside the Objective-C module** (hard invariant 11). No private selector name, no `NSSelectorFromString`/`NSClassFromString`/`objc_msgSend`/`class_addMethod` appears in any Swift file **under `Sources/`** outside the two pre-existing, inventoried offenders (`Sources/RichTextEditorUIKit/Canvas/NativeTextChecking.swift`, `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+NativeTextCheckingClient.swift`). The constraint is deliberately scoped to `Sources/`: the **test target may name private selectors in plaintext** — `CanvasCallbackInstallationTests` hard-codes all 22 of them, because its whole job is asserting that the legacy class does *not* answer them — and the test target is never shipped. This matches the enforcing rule, R1b (`test_privateRuntimeLookups_areConfinedToTheInventoriedFiles`), which scans `RepoLayout.uiKitSources` only.
4. **No behavior change until a flag is deliberately turned on.** Stages A and B ship code that is compiled and never selected. The seam plan's characterization suites under `Tests/RichTextEditorUIKitTests/Characterization/` must keep passing **unedited** through Stage D; `git diff inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/` must stay empty. (There is no JSON golden corpus in this programme — the seam plan records behavior as in-source XCTAssert expectations. See "Review notes".)
5. **Internal-only API.** No backend type becomes part of `RichTextEditorView`'s public API (spec lines 92-98). Only a kind-only preference enum may become public, and only in Stage E.
6. **Existential-friendly protocols.** No associated types, no `Self` requirements, no generic protocol methods. Stored protocol references are `any ProtocolName`. The shared Swift protocols stay Swift-only; the Objective-C backend is wrapped by a Swift adapter and the shared protocols do **not** become `@objc` merely to bridge it (spec lines 143-145).
7. **UIKit identity is backend-owned.** The two backends do not share position/range subclasses. `TGRichTextInputDecPosition`/`Range` are opaque outside `IDTextEditorBackend`.
8. **Selection policy is outside the protocol.** `RichTextInputBackend` never chooses, falls back, or hot-swaps. The canvas factory owns unsupported-runtime policy.
9. **Legacy and ID editors use different concrete canvas classes** (spec lines 1171-1173). The legacy `DocumentCanvasView` must never acquire a private selector. Categories are therefore forbidden on the shared canvas class; runtime IMP installation onto the ID subclass is the only mechanism.
10. **No InputDec source before the Phase 6 gate.** Three source-boundary rules block this plan's Swift files, not one, and **Task A4 relaxes all three in a single reviewed commit** — no other task may touch `InputBackendSourceBoundaryTests.swift`:
    - **R8** (`test_noInputDecSourcesAndNoObjectiveCUnderTheSwiftTarget`) rejects any basename matching `^ID[A-Z]` under `Sources/RichTextEditorUIKit/`, which would reject `IDDocumentCanvasView.swift`, `IDTextEditorBackend.swift` and friends.
    - **R1** (`test_sharedContracts_containNoPrivateOrInputDecNames`) rejects `\bID[A-Z]\w+` in *every* file under `Sources/RichTextEditorUIKit/InputBackend/` — the scan recurses, so an `InputDec/` subdirectory is not automatically exempt.
    - **R2** (`test_sharedContracts_referenceNoTelegramImplementationTypes`) rejects `DocumentCanvasView`, `NSTextStorage` and the identity types in every file under `InputBackend/` except `/Clients/` and `Legacy*`-prefixed ones — which would reject both the adapter and `RichTextInputCanvasFactory.swift`.
    The relaxation is exactly: exempt `InputBackend/InputDec/**` and the single file `InputBackend/RichTextInputCanvasFactory.swift` from R8's basename rule, R1's ID-name clause, and R2's implementation-type list. **R1's banned-machinery list (`NSSelectorFromString`, `objc_msgSend`, `class_addMethod`, …) and R1b stay absolute for every file, with no exemption** — that is the constraint that actually keeps private API inside the Objective-C module.
11. **Simulator testing is serialized.** `-parallel-testing-enabled NO` on every `xcodebuild test`; never overlap XCTest processes against one simulator; never interleave a K1 run with a K3 run.
12. **Do not port InputDec's demo, document, canvas, or reference backend** (spec line 1585). Stated precisely, because the manifest's own parser constrains what "never travels" can mean:
    - **No reference-backend *source* travels** — not `IDTextView*`, not `IDTextLayoutCanvasView*`, not `IDPrivateUIKit+TextLayoutCanvas.*`.
    - **No `referenceOnly` capability is ever requested or evaluated.** The codegen empties the manifest's `referenceOnly` object to `{}`, dropping all 53 rows (`legacyAutoscroll` 3 + `legacyLayout` 16 + `legacyCanvas` 34). The **key itself must stay present**: `IDUIKitRuntimeManifest.manifestWithData:error:` calls `IDUIKitDictionaryHasExactKeys` over `{schema, runtime, capabilities, referenceOnly, forbidden}` (`IDUIKitRuntimeContract.m:667-678`), so deleting the key makes the whole manifest fail to parse. An empty object parses to an empty `NSDictionary`, so `manifest.referenceOnly.count == 0`.
    - **The 8 `forbidden` symbols travel as data, deliberately.** `forbidden` is a *deny-list*, not an implementation: it is what `ContractManifestTests` and the source-boundary suite check against. Never naming them would remove the only machine-checkable statement that we do not use them.

---

## File Structure

Throughout the tables below, `…/RichTextEditor` abbreviates `$PKG`
(= `/Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor`); a
path with no prefix is relative to `$PKG`.

### Created in the InputDec repo (`/Users/isaac/Documents/InputDec`)

| Path | Single responsibility |
| --- | --- |
| `Scripts/generate-contract-data.py` | JSON manifest → `TGRichTextInputDecContractData.m` byte array: applies the 50 class renames on the `"class"` key, empties `referenceOnly`, and hard-asserts both. |
| `Scripts/test-generate-contract-data.py` | Decodes the generated byte array back to JSON and asserts the parsed manifest — the only non-vacuous check of the rename. |
| `Scripts/carve-host-preflight.sh` | Extracts `IDInteractionABISpec` + the ABI helpers + the two class methods out of `IDPrivateUIKit.m` into `TGRichTextInputDecHostPreflight.{h,m}`, by symbol name (never line numbers). |
| `Scripts/export-behavior-kernel.sh` | The only sanctioned way to produce the telegram-ios snapshot: copies 16 kernel files, applies the three mechanical edits, guards every copied `.m` **and `.h`** with `TARGET_OS_IOS`, carves the host preflight, renames the selection rect, regenerates the contract data, writes `VENDOR.md`. Refuses to run from a tree with tracked modifications. |
| `Scripts/test-export-behavior-kernel.sh` | Exports into a temp dir and asserts the snapshot shape and the guard placement. |

### Created in telegram-ios — the Objective-C module

Root: `/Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC/`

| Path (relative to that root) | Single responsibility |
| --- | --- |
| `include/TGRichTextInputDec.h` | Aggregate header the Swift adapter imports. |
| `include/Kernel/*.h` (9 files) | Vendored kernel headers, upstream content wrapped in a `TARGET_OS_IOS` guard (three of them — `IDUIKitBehaviorKernel.h`, `IDUIKitInputControllerCapability.h`, `IDUIKitInteractionCapability.h` — `#import <UIKit/UIKit.h>` on line 1, and SwiftPM's `publicHeadersPath` umbrella-directory module compiles every one of them on macOS). |
| `Kernel/*.m` (7 files) | Vendored kernel implementations; exactly three edited regions across two files, plus the `TARGET_OS_IOS` guard. |
| `include/TGRichTextInputDecContract.h` + `Generated/TGRichTextInputDecContractData.m` | The manifest compiled in as bytes; `TGRichTextInputDecContractManifest()` returns nil (never `@throw`) when it fails to parse. |
| `include/TGRichTextInputDecExceptionGuard.h` + `Host/TGRichTextInputDecExceptionGuard.m` | The `@try`/`@catch` trampoline the Swift adapter routes every kernel entry point through. The kernel still raises `NSException` on a contract mismatch (six sites), and Swift cannot catch one. |
| `include/TGRichTextInputDecHostPreflight.h` + `Host/TGRichTextInputDecHostPreflight.m` | The ~150 lines carved out of `IDPrivateUIKit.m`: interaction-host ABI specs, the ABI comparison helpers, `requireInteractionHost:stage:`, `adoptResolvedTextAutoscrollingProtocol:onClass:`. |
| `include/TGRichTextInputDecClientBridge.h` | `@objc protocol TGRichTextInputDecClientBridging` — the backend-private ObjC↔Swift seam. Not one of the six shared protocols. |
| `include/TGRichTextInputDecPosition.h`, `…Range.h` + `Host/*.m` | Backend-owned UIKit identity carrying flat `(utf16Offset, affinity, documentRevision)`. |
| `include/TGRichTextInputDecSelectionRect.h` + `Host/TGRichTextInputDecSelectionRect.m` | Vendored `UITextSelectionRect` subclass, renamed. |
| `include/TGRichTextInputDecLayoutController.h`, `Host/TGRichTextInputDecLayoutControllerInternal.h`, `Host/TGRichTextInputDecLayoutController.m` | The object handed to the kernel as `layoutController`. Implements the 47 neutral `id_…` methods against the bridge. Document-neutral by construction. |
| `Private/TGRichTextInputDecLayoutController+PrivateCallbacks.m` | The 47 private selector names, each a one-line forward to its `id_…` twin. A category is correct here: this class is backend-private. |
| `include/TGRichTextInputDecTextStorageFacade.h` + `Host/TGRichTextInputDecTextStorageFacade.m` | `NSTextStorage` subclass satisfying the mandatory `incoming.textStorage` row; converts UIKit's raw range replaces into prepared/committed semantic mutations via the intent latch. |
| `include/TGRichTextInputDecCanvasCallbacks.h` + `Private/TGRichTextInputDecCanvasCallbacks.m` | The ~22 canvas-side private callbacks as free IMPs, plus `TGRichTextInputDecInstallCanvasCallbacks` / `TGRichTextInputDecSetAttachedBridge` / `TGRichTextInputDecAttachedBridge`. |
| `include/TGRichTextInputDecCanvasABIWitness.h` + `Host/TGRichTextInputDecCanvasABIWitness.m` | A `UIView` subclass statically implementing `keyboardInputShouldDelete:`, `startAutoscroll:`, `cancelAutoscroll` with the exact ABI, so the three canvas manifest rows have a compile-time class to validate — and so the installer can install *the very IMPs the resolver validated*. |
| `Host/TGRichTextInputDecModuleAnchor.m` | One always-compiled no-op symbol so the macOS object file is never empty. |
| `Vendor/UIKitBehaviorContracts-iOS26.5.json` | Pristine upstream manifest. Excluded from both builds; input to the codegen test only. |
| `Vendor/VENDOR.md` | Provenance: upstream commit, date, certified OS band, SHA-256 of the pristine JSON and the generated `.m`, the class-rename map, the script-owned path list, the green-upstream-run evidence line. |

### Created in telegram-ios — the Swift adapter

Root: `…/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend/`

| Path | Single responsibility |
| --- | --- |
| `RichTextInputCanvasFactory.swift` | The one place backend selection policy lives. |
| `InputDec/IDDocumentCanvasView.swift` | Empty `DocumentCanvasView` subclass; the only class the private thunks are installed onto. |
| `InputDec/IDTextEditorBackend.swift` | The backend class: `attach`/`detach`, `state`, `synchronizeAfterExternalChange`, `setSelection`, `isSupported()`, the transaction-phase machine. |
| `InputDec/IDTextEditorBackend+TextBackend.swift` | `RichTextInputTextBackend` witnesses → `kernelInput`. |
| `InputDec/IDTextEditorBackend+KeyInput.swift` | `RichTextKeyInputBackend` witnesses. |
| `InputDec/IDTextEditorBackend+Responder.swift` | `RichTextInputResponderBackend` witnesses. |
| `InputDec/IDTextEditorBackend+Interaction.swift` | `RichTextInputInteractionBackend` witnesses → `kernelInteraction`. |
| `InputDec/IDTextEditorBackendClientBridge.swift` | `NSObject` conforming to `TGRichTextInputDecClientBridging`; translates every ObjC call into the six Swift clients. |
| `InputDec/IDTextEditorBackendIntent.swift` | The intent latch: maps pre-mutation delegate callbacks to `RichTextInputMutation` cases. |

### Modified in telegram-ios

| Path | Change |
| --- | --- |
| `…/RichTextEditor/Package.swift` | Adds the `RichTextInputDecObjC` target and the two dependency edges. |
| `…/RichTextEditor/BUILD` | Adds the `objc_library` and the `swift_library` dep edge. |
| `…/RichTextEditor/Scripts/iostest.sh` | Gains an **outer** `EXTRA` passthrough. `-parallel-testing-enabled NO` and the `TK1` passthrough already arrived with the seam plan's Task 9 Step 5. |
| `…/RichTextEditor/Scripts/matrix.sh` | Gains an `.inputDec` pass, by appending to the existing `SUITES` mechanism. |
| `Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift` | R8/R1/R2 gain the reviewed `InputBackend/InputDec/**` + `RichTextInputCanvasFactory.swift` exemption (Task A4, once). |
| `…/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` | `final` removed from the `final class DocumentCanvasView: UIView` declaration (line 58 at `inputdec-baseline`; match on the text, not the number). |
| `…/RichTextEditorUIKit/RichTextEditorView.swift` | `let canvas` becomes factory-assigned; a kind-only public init overload is added in Stage E. |
| `/Users/isaac/build/telegram/telegram-ios/submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift` | `inputDecTextBackend: Bool` — six edits. |
| `/Users/isaac/build/telegram/telegram-ios/submodules/DebugSettingsUI/Sources/DebugController.swift` | `case inputDecTextBackend(Bool)` — five edits. |
| `…/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` | Reads the setting, threads a preference. |
| `…/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` | `editorView` becomes init-assigned. |
| `/Users/isaac/build/telegram/telegram-ios/CLAUDE.md` | A "synced snapshot — do not hand-edit" section mirroring the WatchApp one. |

### Created — tests

| Path | Single responsibility |
| --- | --- |
| `Tests/RichTextEditorCoreTests/SourceBoundary/VendorSnapshotIntegrityTests.swift` | SHA-256 of the generated contract data matches `VENDOR.md`; the pristine JSON still names the upstream classes; no hand-edit. |
| `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecBoundaryTests.swift` | No `IDUIKit*` symbol outside `InputBackend/InputDec/`; no `.m`/`.h` under `Sources/RichTextEditorUIKit/`; the vendored tree is present and complete. |
| `Tests/RichTextEditorCoreTests/SourceBoundary/IDBackendCallGuardTests.swift` | No Swift file calls a vendored kernel entry point outside `TGRichTextInputDecPerform`. |
| `Tests/RichTextEditorUIKitTests/InputDec/ContractManifestTests.swift` | The manifest **parses** from compiled-in bytes and, on the parsed object, every `incomingCallbacks` row names `TGRichTextInputDecLayoutController`, the three canvas rows name `TGRichTextInputDecCanvasABIWitness`, both classes resolve via `NSClassFromString`, `referenceOnly` is empty and `forbidden` is intact. |
| `Tests/RichTextEditorUIKitTests/InputDec/ExceptionGuardTests.swift` | Every reachable kernel entry point, driven with a deliberately corrupted manifest, raises no exception past the guard. |
| `Tests/RichTextEditorUIKitTests/InputDec/CanvasSubclassPerformanceTests.swift` | The three `measure` baselines the `final` removal is judged against. |
| `Tests/RichTextEditorUIKitTests/InputDec/CanvasCallbackInstallationTests.swift` | Install rejects the base class and non-direct subclasses; the legacy class never gains a selector; thunks are inert with no bridge. |
| `Tests/RichTextEditorUIKitTests/InputDec/IsSupportedTests.swift` | `isSupported()` is pure, constructs nothing, and answers correctly on the running OS. |
| `Tests/RichTextEditorUIKitTests/InputDec/IDBackendAttachDetachTests.swift` | Attach atomicity and the nine-step detach order for `.inputDec`. |
| `Tests/RichTextEditorUIKitTests/InputDec/IDBackendIntentLatchTests.swift` | The intent latch maps each pre-mutation callback to the right `RichTextInputMutation`. |
| `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticContractCases.swift` | The **backend-parameterised** base class: assertions written once, run twice via the two subclasses below. |
| `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticSubclasses.swift` | `LegacyBackendSemanticTests` and `IDBackendSemanticTests` — each overrides one property and inherits every test method. |
| `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFamily<N>Tests.swift` (×11) | One per Phase-4 family: the ID-specific assertions (identity types, thunk installation, kernel routing) that have no legacy counterpart. |
| `Tests/RichTextEditorUIKitTests/InputDec/IDBackendDifferentialTraceTests.swift` | Runs each scenario against both backends **in one process** and compares the semantic projection of the shared `RichTextInputEventLog`. |
| `Tests/RichTextEditorUIKitTests/InputDec/IDFakeClientHarness.swift` | `makeIDFakeClientHarness(...)` — the seven stage-1 fakes wired to an `IDDocumentCanvasView` + `IDTextEditorBackend`, so client call counts are assertable. |

Two stage-1 test files are **modified** (both by Task C1, both purely additive):

| Path | Change |
| --- | --- |
| `Tests/RichTextEditorUIKitTests/Support/RichTextInputBackendHarness.swift` | `RichTextInputBackendKind` gains `case inputDec`; the harness gains a `backend` accessor, a `storageFacade` accessor and the `.inputDec` construction branch. |
| `Tests/RichTextEditorUIKitTests/InputBackend/Fakes/FakeInputDocumentClient.swift`, `FakeInputGeometryClient.swift` | Gain `text`, `clampCallCount`, `settableRevision`, and `receivedRequests` — counters stage 1 did not need. |

---

## Stage A — vendoring mechanics

**Deliverable:** the app builds, on both build systems, with the vendored Objective-C linked in, and zero behavior change. Nothing selects the code at runtime; `isSupported()` is hard-wired to `false` because `TG_RICHTEXT_INPUTDEC_ENABLED` is undefined.

**Stage A exit gate (Task A11):** `swift test` green on macOS; `Scripts/iostest.sh` green on K1 with the pre-existing suite unchanged; full `Make.py build --configuration=debug_sim_arm64` green; `git diff inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/` empty.

### Task A1: The contract-data codegen

The single most load-bearing transformation in the whole vendoring lives here: the manifest's class names must be rewritten, because `IDUIKitCapabilityResolver` looks each row's class up with `NSClassFromString` and fails the entire capability when it is absent. `incomingCallbacks` is **mandatory**, so a missed rename makes `isSupported()` permanently false and every later stage dead on arrival — with no build error anywhere.

**Files:**
- Create: `/Users/isaac/Documents/InputDec/Scripts/generate-contract-data.py`
- Test: `/Users/isaac/Documents/InputDec/Scripts/test-generate-contract-data.py`

**Interfaces:**
- Consumes: `PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json`.
- Produces: `generate-contract-data.py <src.json> <dst.m>` → an ObjC translation unit defining `TGRichTextInputDecContractManifest()`.

**Steps:**

1. - [ ] **Step 1: Write the failing codegen test.** It decodes the generated hex byte array **back to JSON** and asserts on the parsed object. A text `grep` over the generated `.m` cannot work — the payload is emitted as `0x49, 0x44, …`, so `grep -q IDRichTextLayoutController` is satisfied (or not) regardless of whether any rename happened. Create `/Users/isaac/Documents/InputDec/Scripts/test-generate-contract-data.py`:
   ```python
   #!/usr/bin/env python3
   """Non-vacuous check of the class renames: decode the emitted bytes and inspect the manifest."""
   import json, re, subprocess, sys, tempfile, pathlib

   SRC = "PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json"
   LAYOUT = "TGRichTextInputDecLayoutController"
   WITNESS = "TGRichTextInputDecCanvasABIWitness"

   def decoded(path):
       text = pathlib.Path(path).read_text()
       body = text.split("TGRichTextInputDecContractBytes[] = {", 1)[1].split("};", 1)[0]
       data = bytes(int(b, 16) for b in re.findall(r"0x([0-9a-f]{2})", body))
       return json.loads(data.decode("utf-8"))

   def main():
       out = pathlib.Path(tempfile.mkdtemp()) / "TGRichTextInputDecContractData.m"
       subprocess.run(["Scripts/generate-contract-data.py", SRC, str(out)], check=True)
       m = decoded(out)

       rows = [r for cap in m["capabilities"].values() for r in cap["members"]]
       assert len(rows) == 127, "capability member count changed: %d" % len(rows)
       assert [r for r in rows if r["class"] == LAYOUT].__len__() == 47, "47 incomingCallbacks rows"
       assert [r for r in rows if r["class"] == WITNESS].__len__() == 3, "3 canvas rows"
       for bad in ("IDRichTextLayoutController", "IDBlockTextView"):
           assert not [r for r in rows if r["class"] == bad], "un-renamed row: " + bad
       assert m["referenceOnly"] == {}, "referenceOnly must be emptied, not deleted"
       assert "referenceOnly" in m, "the key itself must survive (manifest parser demands it)"
       assert len(m["forbidden"]) == 8, "the forbidden deny-list must travel intact"
       assert m["runtime"] == {"osVersion": "26.5", "osBuild": "23F73"}

       # Reproducibility: two runs must be byte-identical.
       out2 = pathlib.Path(tempfile.mkdtemp()) / "again.m"
       subprocess.run(["Scripts/generate-contract-data.py", SRC, str(out2)], check=True)
       assert out.read_bytes() == out2.read_bytes(), "codegen is not deterministic"
       print("contract codegen OK")

   if __name__ == "__main__":
       main()
   ```
   `chmod +x Scripts/test-generate-contract-data.py`.

2. - [ ] **Step 2: Run it and see it fail.** `cd /Users/isaac/Documents/InputDec && Scripts/test-generate-contract-data.py`. Expected failure: `FileNotFoundError: 'Scripts/generate-contract-data.py'`.

3. - [ ] **Step 3: Write the codegen.** Create `/Users/isaac/Documents/InputDec/Scripts/generate-contract-data.py`:
   ```python
   #!/usr/bin/env python3
   """JSON runtime manifest -> TGRichTextInputDecContractData.m (compiled-in byte array).

   Two transforms, both mandatory:

   1. CLASS RENAMES, applied on the "class" key. Note the key really is spelled "class", not
      "className": IDUIKitRuntimeContract.m:327 lists it in the member's exact-key set and :344
      reads `NSString *className = dictionary[@"class"];` into the `className` PROPERTY. Renaming
      on "className" would silently rewrite nothing, IDUIKitCapabilityResolver would then get nil
      from NSClassFromString, the mandatory `incomingCallbacks` capability would be rejected, and
      isSupported() could never return true — with no build error.
   2. referenceOnly IS EMPTIED TO {} — not deleted. The 53 reference-backend rows must not travel
      (they describe the excluded reference backend), but manifestWithData:error: runs
      IDUIKitDictionaryHasExactKeys over {schema, runtime, capabilities, referenceOnly, forbidden}
      (IDUIKitRuntimeContract.m:667-678), so removing the key fails the whole parse.
      `forbidden` is KEPT: it is a deny-list the telegram-ios tests assert against.
   """
   import json, sys

   RENAMES = {
       "IDRichTextLayoutController": "TGRichTextInputDecLayoutController",
       "IDBlockTextView": "TGRichTextInputDecCanvasABIWitness",
   }
   EXPECTED_RENAMED_ROWS = 50   # 47 incomingCallbacks + 1 inputController + 2 autoscrollEntry

   HEADER = '''// GENERATED BY InputDec/Scripts/generate-contract-data.py — DO NOT HAND-EDIT.
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import "TGRichTextInputDecContract.h"
   #import "IDUIKitRuntimeContract.h"

   static const unsigned char TGRichTextInputDecContractBytes[] = {
   %s
   };

   IDUIKitRuntimeManifest * _Nullable TGRichTextInputDecContractManifest(void) {
       static IDUIKitRuntimeManifest *manifest;
       static dispatch_once_t once;
       dispatch_once(&once, ^{
           NSData *data = [NSData dataWithBytesNoCopy:(void *)TGRichTextInputDecContractBytes
                                               length:sizeof(TGRichTextInputDecContractBytes)
                                         freeWhenDone:NO];
           NSError *error = nil;
           manifest = [IDUIKitRuntimeManifest manifestWithData:data error:&error];
       });
       return manifest;
   }

   #endif
   '''

   def rename(node, counter):
       if isinstance(node, dict):
           out = {}
           for k, v in node.items():
               if k in ("class", "className") and isinstance(v, str) and v in RENAMES:
                   out[k] = RENAMES[v]
                   counter[0] += 1
               else:
                   out[k] = rename(v, counter)
           return out
       if isinstance(node, list):
           return [rename(v, counter) for v in node]
       return node

   def remaining_upstream_classes(node, found):
       if isinstance(node, dict):
           for k, v in node.items():
               if k in ("class", "className") and isinstance(v, str) and v in RENAMES:
                   found.add(v)
               else:
                   remaining_upstream_classes(v, found)
       elif isinstance(node, list):
           for v in node:
               remaining_upstream_classes(v, found)

   def main(src, dst):
       with open(src, "rb") as f:
           manifest = json.loads(f.read().decode("utf-8"))

       counter = [0]
       manifest = rename(manifest, counter)
       assert counter[0] == EXPECTED_RENAMED_ROWS, (
           "renamed %d rows, expected %d — the manifest shape changed; re-derive the count "
           "before touching this assertion" % (counter[0], EXPECTED_RENAMED_ROWS))

       leftovers = set()
       remaining_upstream_classes(manifest, leftovers)
       assert not leftovers, "un-renamed upstream class names survived: %s" % sorted(leftovers)

       dropped = sum(len(c.get("members", [])) for c in manifest["referenceOnly"].values())
       assert dropped == 53, "expected 53 referenceOnly rows, saw %d" % dropped
       manifest["referenceOnly"] = {}
       assert len(manifest["forbidden"]) == 8, "the forbidden deny-list must stay intact"

       payload = json.dumps(manifest, separators=(",", ":"),
                            sort_keys=True, ensure_ascii=True).encode("utf-8")
       rows = ["    " + " ".join("0x%02x," % b for b in payload[i:i + 16])
               for i in range(0, len(payload), 16)]
       with open(dst, "w") as f:
           f.write(HEADER % "\n".join(rows))

   if __name__ == "__main__":
       main(sys.argv[1], sys.argv[2])
   ```
   `chmod +x Scripts/generate-contract-data.py`.

4. - [ ] **Step 4: Run the test and see it pass.** `cd /Users/isaac/Documents/InputDec && Scripts/test-generate-contract-data.py` → `contract codegen OK`. The `127` is the shipped manifest's actual member count (inputController 42, typingAttributes 9, interaction 14, floatingCursor 3, autoscrollEntry 3, checking 2, prediction 1, paste 5, dictation 1, incomingCallbacks 47). If the `127` member-count or `50` rename-count assertion trips, **re-derive both numbers against the shipped JSON** rather than loosening either:
   ```sh
   python3 -c 'import json;m=json.load(open("PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json"));
   print(sum(len(c["members"]) for c in m["capabilities"].values()))'
   ```
   and update both the script and the test together — never loosen one alone.

5. - [ ] **Step 5: Commit (in the InputDec repo).**
   ```sh
   cd /Users/isaac/Documents/InputDec && \
   git add Scripts/generate-contract-data.py Scripts/test-generate-contract-data.py && \
   git commit -m "feat(export): contract-data codegen with class renames on the 'class' key"
   ```

### Task A2: The host-preflight carve

**Files:**
- Create: `/Users/isaac/Documents/InputDec/Scripts/carve-host-preflight.sh`
- Test: `/Users/isaac/Documents/InputDec/Scripts/test-carve-host-preflight.sh`

**Interfaces:**
- Consumes: `PrivateUIKit/IDPrivateUIKit.m` — the `IDInteractionABISpec` `@interface`/`@implementation` (lines 941/950), the **seven** file-static helpers of the mismatch chain (`IDInteractionTypeEncoding`, `IDInteractionABISpecMake`, `IDInteractionHostABISpecs`, `IDInteractionSkipTypeQualifiers`, `IDInteractionTypeMatches`, `IDInteractionABIMismatchForSignature`, `IDInteractionABIMismatch`, `IDInteractionABIMismatches` — eight names, of which `IDInteractionSkipTypeQualifiers`/`IDInteractionTypeMatches`/`IDInteractionABIMismatchForSignature` are reached only transitively and are easy to miss), `+requireInteractionHost:stage:`, `+adoptResolvedTextAutoscrollingProtocol:onClass:`. **Not** consumed: `IDInteractionInstanceABIMismatches` (no carved caller).
- Produces: `carve-host-preflight.sh <abs-dest>` → `<dest>/include/TGRichTextInputDecHostPreflight.h` + `<dest>/Host/TGRichTextInputDecHostPreflight.m`.

**Steps:**

1. - [ ] **Step 1: Write the failing carve test.** Create `Scripts/test-carve-host-preflight.sh`:
   ```sh
   #!/bin/bash
   set -euo pipefail
   DEST="$(mktemp -d)/snap"; mkdir -p "$DEST"/{Host,include}
   Scripts/carve-host-preflight.sh "$DEST"
   H="$DEST/include/TGRichTextInputDecHostPreflight.h"
   M="$DEST/Host/TGRichTextInputDecHostPreflight.m"
   grep -q "@interface TGRichTextInputDecHostPreflight : NSObject" "$H"
   grep -q "requireInteractionHost:(id)host stage:" "$H"
   grep -q "adoptResolvedTextAutoscrollingProtocol:" "$H"
   grep -q "^#if TARGET_OS_IOS" "$H"
   grep -q "^#if TARGET_OS_IOS" "$M"
   # Every static in the mismatch chain must be DEFINED, not merely mentioned. A bare
   # `grep -q IDInteractionABIMismatch` is satisfied by IDInteractionABIMismatches, which is why
   # each check anchors on the definition line.
   for sym in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
              IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
              IDInteractionABIMismatchForSignature IDInteractionABIMismatch \
              IDInteractionABIMismatches; do
     grep -qE "^static .*[ *]${sym}\(" "$M" || { echo "carve is missing static $sym"; exit 1; }
   done
   grep -q "interactionAssistant" "$M"
   grep -q "_textInputViewForAddingGestureRecognizers" "$M"
   grep -q "selectionContainerView" "$M"
   ! grep -q "IDPrivateUIKit" "$M"
   # The carve must NOT drag the reference backend in.
   for forbidden in objc_allocateClassPair _UITextLayoutCanvasView IDTextView IDBlockDocument; do
     ! grep -q "$forbidden" "$M" || { echo "carve dragged in $forbidden"; exit 1; }
   done
   test "$(wc -l < "$M")" -lt 250 || { echo "carve is too large — it grabbed extra regions"; exit 1; }
   echo "carve OK"
   ```
   `chmod +x Scripts/test-carve-host-preflight.sh`.

2. - [ ] **Step 2: Run it and see it fail.** `cd /Users/isaac/Documents/InputDec && Scripts/test-carve-host-preflight.sh` → `No such file or directory`.

3. - [ ] **Step 3: Write the carve.** Create `Scripts/carve-host-preflight.sh`. Extract **by symbol name, never by line number** — `IDPrivateUIKit.m` is 2998 lines and actively edited, so hard-coded ranges rot silently:
   ```sh
   #!/bin/bash
   # Carves the interaction-host preflight + autoscroll protocol adoption out of the 2998-line
   # IDPrivateUIKit.m into a standalone ~150-line vendored file. Symbol-driven, not line-driven.
   set -euo pipefail
   DEST="${1:?usage: carve-host-preflight.sh <abs-dest>}"
   SRC=PrivateUIKit/IDPrivateUIKit.m
   mkdir -p "$DEST/Host" "$DEST/include"

   cat > "$DEST/include/TGRichTextInputDecHostPreflight.h" <<'EOF'
   // CARVED from InputDec/PrivateUIKit/IDPrivateUIKit.m by Scripts/carve-host-preflight.sh.
   // DO NOT HAND-EDIT — see Vendor/VENDOR.md.
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <UIKit/UIKit.h>

   NS_ASSUME_NONNULL_BEGIN

   /// The two IDPrivateUIKit class methods the vendored behavior kernel calls, and nothing else.
   /// BOTH RAISE NSException on a mismatch — that is upstream behavior and is deliberately
   /// preserved; the Swift adapter routes every call through TGRichTextInputDecExceptionGuard.
   @interface TGRichTextInputDecHostPreflight : NSObject
   + (void)requireInteractionHost:(id)host stage:(NSString *)stage;
   + (BOOL)adoptResolvedTextAutoscrollingProtocol:(Protocol *)protocol onClass:(Class)viewClass;
   @end

   NS_ASSUME_NONNULL_END

   #endif
   EOF

   # awk extractor: print from a line matching $start until the first line that is exactly "}"
   # at column 0 (both C functions and ObjC method bodies in this file close that way).
   extract() {
     awk -v pat="$1" '
       $0 ~ pat { emit = 1 }
       emit { print }
       emit && /^\}$/ { exit }
     ' "$SRC"
   }

   {
     echo '// CARVED from InputDec/PrivateUIKit/IDPrivateUIKit.m by Scripts/carve-host-preflight.sh.'
     echo '// DO NOT HAND-EDIT — see Vendor/VENDOR.md.'
     echo '#import <TargetConditionals.h>'
     echo '#if TARGET_OS_IOS'
     echo
     echo '#import <objc/runtime.h>'
     echo '#import "TGRichTextInputDecHostPreflight.h"'
     echo
     # 1. The spec value type: @interface … @end then @implementation … @end.
     awk '/^@interface IDInteractionABISpec /,/^@end$/' "$SRC"
     echo
     awk '/^@implementation IDInteractionABISpec$/,/^@end$/' "$SRC"
     echo
     # 2. The file-static helpers, in DEPENDENCY ORDER. The chain is not the three obvious ones:
     #    IDInteractionABIMismatches -> IDInteractionABIMismatch -> IDInteractionABIMismatchForSignature
     #    -> IDInteractionTypeMatches -> IDInteractionSkipTypeQualifiers, and both the signature
     #    formatter and the mismatch text call IDInteractionTypeEncoding. Omitting any of the three
     #    inner helpers leaves the carved translation unit referencing undefined statics — it fails at
     #    Task A6/A7, and the presence loop below cannot catch it unless the name is listed there too.
     #    (IDInteractionInstanceABIMismatches is deliberately NOT carved: nothing the two class
     #    methods call reaches it.)
     for fn in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
               IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
               IDInteractionABIMismatchForSignature \
               IDInteractionABIMismatch IDInteractionABIMismatches; do
       extract "^static .*[ *]${fn}\\("
       echo
     done
     # 3. The two class methods, rehomed onto the carved class.
     echo '@implementation TGRichTextInputDecHostPreflight'
     echo
     extract '^\+ \(void\)requireInteractionHost:'
     echo
     extract '^\+ \(BOOL\)adoptResolvedTextAutoscrollingProtocol:'
     echo
     echo '@end'
     echo
     echo '#endif'
   } > "$DEST/Host/TGRichTextInputDecHostPreflight.m"

   # Every helper the carve names must actually be present; an awk miss produces an empty region
   # that would otherwise only surface as a link error inside the Telegram build.
   # NB: substring greps are not enough on their own — `grep -q IDInteractionABIMismatch` succeeds on
   # a file that only contains IDInteractionABIMismatches. Each name is therefore checked as a
   # DEFINITION (`^static ...<name>(`), which is exact.
   for sym in IDInteractionTypeEncoding IDInteractionABISpecMake IDInteractionHostABISpecs \
              IDInteractionSkipTypeQualifiers IDInteractionTypeMatches \
              IDInteractionABIMismatchForSignature IDInteractionABIMismatch \
              IDInteractionABIMismatches; do
     grep -qE "^static .*[ *]${sym}\\(" "$DEST/Host/TGRichTextInputDecHostPreflight.m" \
       || { echo "carve lost the definition of $sym — the upstream symbol was renamed or reshaped"; exit 1; }
   done
   for sym in requireInteractionHost adoptResolvedTextAutoscrollingProtocol; do
     grep -q "$sym" "$DEST/Host/TGRichTextInputDecHostPreflight.m" \
       || { echo "carve lost $sym — the upstream symbol was renamed or reshaped"; exit 1; }
   done
   echo "carved host preflight -> $DEST"
   ```
   `chmod +x Scripts/carve-host-preflight.sh`.

4. - [ ] **Step 4: Run the test and see it pass.** `Scripts/test-carve-host-preflight.sh` → `carve OK`. If a helper is missing, fix the `awk` pattern; if the file exceeds 250 lines, an `extract` pattern is too greedy — tighten it rather than raising the limit.

5. - [ ] **Step 5: Commit.**
   ```sh
   cd /Users/isaac/Documents/InputDec && \
   git add Scripts/carve-host-preflight.sh Scripts/test-carve-host-preflight.sh && \
   git commit -m "feat(export): carve the interaction-host preflight out of IDPrivateUIKit"
   ```

### Task A3: The export script

**Files:**
- Create: `/Users/isaac/Documents/InputDec/Scripts/export-behavior-kernel.sh`
- Test: `/Users/isaac/Documents/InputDec/Scripts/test-export-behavior-kernel.sh`

**Interfaces:**
- Consumes: `PrivateUIKit/BehaviorKernel/` (16 files), `PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json`, `Scripts/carve-host-preflight.sh`, `Scripts/generate-contract-data.py`, `TextView/IDRichTextSelectionRect.{h,m}`.
- Produces: `export-behavior-kernel.sh <abs-dest>` → a populated `<dest>/{Kernel,include/Kernel,Host,Generated,Vendor}` tree plus `<dest>/Vendor/VENDOR.md`.

**Steps:**

1. - [ ] **Step 1: Write the failing script test.** Create `/Users/isaac/Documents/InputDec/Scripts/test-export-behavior-kernel.sh`. Note what it does **not** do: it does not `grep` the generated contract data for a class name. That file is a hex byte array, so any such grep is vacuous in both directions; the manifest's content is checked by `test-generate-contract-data.py` (Task A1) and, on the parsed object, by `ContractManifestTests` (Task A6).
   ```sh
   #!/bin/bash
   # Exports into a temp dir and asserts the snapshot SHAPE. Run from the InputDec repo root.
   set -euo pipefail
   DEST="$(mktemp -d)/RichTextInputDecObjC"
   mkdir -p "$DEST"
   Scripts/export-behavior-kernel.sh "$DEST"
   for f in IDUIKitBehaviorKernel IDUIKitInputControllerCapability IDUIKitInteractionCapability \
            IDUIKitAutoscrollEntryCapability IDUIKitCapabilityResolver IDUIKitRuntimeContract \
            IDUIKitBehaviorReport; do
     test -f "$DEST/Kernel/$f.m" || { echo "missing Kernel/$f.m"; exit 1; }
     test -f "$DEST/include/Kernel/$f.h" || { echo "missing include/Kernel/$f.h"; exit 1; }
   done
   test -f "$DEST/include/Kernel/IDUIKitBehaviorCapabilities.h"
   test -f "$DEST/include/Kernel/IDUIKitBehaviorBackend.h"
   test -f "$DEST/Host/TGRichTextInputDecHostPreflight.m"
   test -f "$DEST/include/TGRichTextInputDecHostPreflight.h"
   test -f "$DEST/Host/TGRichTextInputDecSelectionRect.m"
   test -f "$DEST/include/TGRichTextInputDecSelectionRect.h"
   test -f "$DEST/Generated/TGRichTextInputDecContractData.m"
   test -f "$DEST/Vendor/UIKitBehaviorContracts-iOS26.5.json"
   test -f "$DEST/Vendor/VENDOR.md"

   # EVERY copied .m AND .h must be TARGET_OS_IOS-guarded. The headers matter as much as the
   # sources: SwiftPM's publicHeadersPath synthesizes an umbrella-DIRECTORY module over include/**,
   # so IDUIKitBehaviorKernel.h's line-1 `#import <UIKit/UIKit.h>` is compiled on the macOS
   # `swift build`/`swift test` loop and fails with "module 'UIKit' not found".
   for f in "$DEST"/Kernel/*.m "$DEST"/include/Kernel/*.h \
            "$DEST/include/TGRichTextInputDecSelectionRect.h" \
            "$DEST/Host/TGRichTextInputDecSelectionRect.m"; do
     head -2 "$f" | grep -q "TargetConditionals.h" || { echo "unguarded: $f"; exit 1; }
     head -3 "$f" | grep -q "^#if TARGET_OS_IOS"   || { echo "unguarded: $f"; exit 1; }
     tail -1 "$f" | grep -q "^#endif"              || { echo "unterminated guard: $f"; exit 1; }
   done

   ! grep -q "IDPrivateUIKit" "$DEST/Kernel/"*.m || { echo "IDPrivateUIKit still referenced"; exit 1; }
   ! grep -q "static #import" "$DEST/Kernel/"*.m || { echo "Edit 1 spliced into a static decl"; exit 1; }
   ! grep -q "@throw" "$DEST/Kernel/IDUIKitBehaviorKernel.m" || { echo "kernel manifest @throw survived"; exit 1; }
   grep -q "IDUIKitRuntimeManifest \*IDUIKitBehaviorRuntimeManifest" "$DEST/Kernel/IDUIKitBehaviorKernel.m"
   grep -q "static IDUIKitRuntimeManifest \*IDUIKitInteractionManifest" \
     "$DEST/Kernel/IDUIKitInteractionCapability.m" \
     || { echo "IDUIKitInteractionManifest lost its static linkage"; exit 1; }
   # No #import may appear after the first @implementation — the Edit-1 rewrite hoists them.
   python3 - "$DEST" <<'PY'
   import pathlib, sys
   for p in (pathlib.Path(sys.argv[1]) / "Kernel").glob("*.m"):
       lines = p.read_text().splitlines()
       impl = next((i for i, l in enumerate(lines) if l.startswith("@implementation")), None)
       if impl is None:
           continue
       late = [l for l in lines[impl:] if l.startswith("#import")]
       assert not late, "%s has an #import after @implementation: %s" % (p.name, late)
   PY
   echo "export snapshot OK"
   ```
   `chmod +x Scripts/test-export-behavior-kernel.sh`.

2. - [ ] **Step 2: Run it and see it fail.** `cd /Users/isaac/Documents/InputDec && Scripts/test-export-behavior-kernel.sh`. Expected failure: `Scripts/export-behavior-kernel.sh: No such file or directory`.

3. - [ ] **Step 3: Write the export script's copy + guard + rename half.** Create `/Users/isaac/Documents/InputDec/Scripts/export-behavior-kernel.sh`:
   ```sh
   #!/bin/bash
   # Exports the document-neutral UIKit behavior kernel into a telegram-ios snapshot directory.
   # The ONLY sanctioned way to produce Sources/RichTextInputDecObjC/{Kernel,include/Kernel,Host,Generated,Vendor}.
   set -euo pipefail
   DEST="${1:?usage: export-behavior-kernel.sh <abs-dest>}"
   cd "$(dirname "$0")/.."
   # `--untracked-files=no` deliberately: a snapshot must be reproducible from a COMMIT, so tracked
   # modifications are refused — but untracked files (a scratch build dir, or these very scripts
   # before they are committed) do not affect what gets exported and must not block the run.
   [ -z "$(git status --porcelain --untracked-files=no)" ] \
     || { echo "refusing to export with uncommitted tracked changes"; exit 1; }
   REV="$(git rev-parse HEAD)"

   mkdir -p "$DEST"/{Kernel,include/Kernel,Host,Generated,Vendor}

   K=PrivateUIKit/BehaviorKernel
   cp "$K"/*.h "$DEST/include/Kernel/"
   cp "$K"/*.m "$DEST/Kernel/"
   ```

4. - [ ] **Step 4: Add Edit 1 — the manifest lookups.** Append to the script. Three things the naive version got wrong and this one does not: the pattern must absorb an optional `static` (`IDUIKitInteractionManifest` is declared `static` at `IDUIKitInteractionCapability.m:106`, and matching from `IDUIKitRuntimeManifest *` leaves a dangling `static ` in front of the replacement, producing `static #import "…"` — which does not compile); the storage class must be **preserved**, or the rewrite silently promotes a file-local symbol to a global one in the app binary; and the `#import` must be hoisted to the top of the file rather than emitted at the match site.
   ```sh
   # Edit 1 — the two duplicated resource lookups become one compiled-in-bytes call that returns
   # nil instead of @throw-ing. A @throw on a missing resource is a launch-time crash inside the
   # Telegram app, where NSBundle bundleForClass: resolves to the framework bundle and the two
   # build systems locate resources differently.
   python3 - "$DEST" <<'PY'
   import re, sys, pathlib
   dest = pathlib.Path(sys.argv[1])
   IMPORT = '#import "TGRichTextInputDecContract.h"'
   BODY = ('%sIDUIKitRuntimeManifest *%s(void) {\n'
           '    return TGRichTextInputDecContractManifest();\n'
           '}\n')
   for name, fn in (("IDUIKitBehaviorKernel.m", "IDUIKitBehaviorRuntimeManifest"),
                    ("IDUIKitInteractionCapability.m", "IDUIKitInteractionManifest")):
       p = dest / "Kernel" / name
       s = p.read_text()
       pattern = re.compile(r"(?P<storage>static\s+)?IDUIKitRuntimeManifest \*"
                            + fn + r"\(void\) \{.*?\n\}\n", re.S)
       match = pattern.search(s)
       assert match, "manifest lookup not found in " + name
       storage = match.group("storage") or ""
       s = s[:match.start()] + (BODY % (storage, fn)) + s[match.end():]

       # Hoist the import: place it directly after the LAST leading #import of the file, so no
       # directive ever lands inside or after a declaration.
       lines = s.splitlines(keepends=True)
       last_import = max(i for i, l in enumerate(lines) if l.startswith("#import"))
       lines.insert(last_import + 1, IMPORT + "\n")
       s = "".join(lines)

       assert "static #import" not in s, name + ": import spliced into a storage-class decl"
       impl = s.find("@implementation")
       if impl != -1:
           assert IMPORT not in s[impl:], name + ": import landed after @implementation"
       p.write_text(s)
   PY
   ```

5. - [ ] **Step 5: Add Edits 2 and 3 — the two `IDPrivateUIKit` call sites.** Append:
   ```sh
   # Edits 2 and 3 — the only two places the kernel reaches outside BehaviorKernel/ (4 grep hits).
   python3 - "$DEST" <<'PY'
   import sys, pathlib
   dest = pathlib.Path(sys.argv[1])
   for name in ("IDUIKitInteractionCapability.m", "IDUIKitAutoscrollEntryCapability.m"):
       p = dest / "Kernel" / name
       s = p.read_text()
       s = s.replace('#import "IDPrivateUIKit.h"', '#import "TGRichTextInputDecHostPreflight.h"')
       s = s.replace("[IDPrivateUIKit", "[TGRichTextInputDecHostPreflight")
       assert "IDPrivateUIKit" not in s, name + " still references IDPrivateUIKit"
       p.write_text(s)
   PY
   ```

6. - [ ] **Step 6: Add the `TARGET_OS_IOS` guard loop — over headers AND sources.** Append. Guarding only `.m` is the trap: `IDUIKitBehaviorKernel.h:1`, `IDUIKitInputControllerCapability.h:1` and `IDUIKitInteractionCapability.h:1` each begin `#import <UIKit/UIKit.h>`, `TextView/IDRichTextSelectionRect.h:1` does too (and subclasses `UITextSelectionRect`), and SwiftPM's `publicHeadersPath: "include"` compiles every header under `include/**` into the synthesized umbrella-directory module. Since `Package.swift:6` also declares `.macOS(.v10_13)` and `RichTextEditorUIKit` will depend on this target, an unguarded header fails the mandatory macOS `swift build` in Task A6 with `module 'UIKit' not found`.
   ```sh
   # Guard EVERY vendored translation unit and EVERY vendored header. The header half is not
   # optional: see the comment in test-export-behavior-kernel.sh.
   guard_file() {
     python3 - "$1" <<'PY'
   import sys, pathlib
   p = pathlib.Path(sys.argv[1]); s = p.read_text()
   if "TARGET_OS_IOS" in s:
       sys.exit(0)
   p.write_text("#import <TargetConditionals.h>\n#if TARGET_OS_IOS\n\n" + s.rstrip("\n") + "\n\n#endif\n")
   PY
   }
   for f in "$DEST"/Kernel/*.m "$DEST"/include/Kernel/*.h; do guard_file "$f"; done
   ```

7. - [ ] **Step 7: Add the carve, the selection-rect rename and the codegen.** Append:
   ```sh
   Scripts/carve-host-preflight.sh "$DEST"     # emits Host/ + include/ TGRichTextInputDecHostPreflight

   cp TextView/IDRichTextSelectionRect.h "$DEST/include/TGRichTextInputDecSelectionRect.h"
   cp TextView/IDRichTextSelectionRect.m "$DEST/Host/TGRichTextInputDecSelectionRect.m"
   sed -i '' 's/IDRichTextSelectionRect/TGRichTextInputDecSelectionRect/g' \
     "$DEST/include/TGRichTextInputDecSelectionRect.h" "$DEST/Host/TGRichTextInputDecSelectionRect.m"
   guard_file "$DEST/include/TGRichTextInputDecSelectionRect.h"
   guard_file "$DEST/Host/TGRichTextInputDecSelectionRect.m"

   JSON=PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json
   cp "$JSON" "$DEST/Vendor/"
   Scripts/generate-contract-data.py "$JSON" "$DEST/Generated/TGRichTextInputDecContractData.m"
   ```

8. - [ ] **Step 8: Add the `VENDOR.md` writer.** Append:
   ```sh
   OSV="$(python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));print(m["runtime"]["osVersion"])' "$JSON")"
   OSB="$(python3 -c 'import json,sys;m=json.load(open(sys.argv[1]));print(m["runtime"]["osBuild"])' "$JSON")"
   cat > "$DEST/Vendor/VENDOR.md" <<EOF
   # Vendored InputDec behavior kernel — provenance

   DO NOT HAND-EDIT anything under Kernel/, include/Kernel/, Generated/, Vendor/, or
   Host/TGRichTextInputDecHostPreflight.* or Host/TGRichTextInputDecSelectionRect.*.
   Re-sync with: InputDec/Scripts/export-behavior-kernel.sh <abs path to this directory>

   - upstream repo: /Users/isaac/Documents/InputDec
   - upstream commit: $REV
   - exported: $(date -u +%Y-%m-%dT%H:%M:%SZ)
   - certified OS band: $OSV (build $OSB) — the only combination this kernel has been run on
   - pristine manifest SHA-256: $(shasum -a 256 "$JSON" | cut -d' ' -f1)
   - generated contract data SHA-256: $(shasum -a 256 "$DEST/Generated/TGRichTextInputDecContractData.m" | cut -d' ' -f1)

   ## Manifest transforms (applied by Scripts/generate-contract-data.py)
   Renames are applied on the member's \`"class"\` key — the JSON spells it \`class\`, and the
   \`className\` name appears only on the parsed Objective-C property (IDUIKitRuntimeContract.m:344).
   | manifest rows | upstream class | vendored class |
   | --- | --- | --- |
   | 47 capabilities.incomingCallbacks.members[*] | IDRichTextLayoutController | TGRichTextInputDecLayoutController |
   | 1 capabilities.inputController.members[keyboardDeletePreflight] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |
   | 2 capabilities.autoscrollEntry.members[start, cancel] | IDBlockTextView | TGRichTextInputDecCanvasABIWitness |

   \`referenceOnly\` is emptied to \`{}\` (53 rows dropped). The KEY is retained: the manifest parser
   demands the exact top-level key set {schema, runtime, capabilities, referenceOnly, forbidden}.
   \`forbidden\` (8 symbols) travels intact as a deny-list the telegram-ios tests assert against.

   Because of these transforms the shipped manifest is NOT byte-identical to the certified one.
   "Certified" here means: every ABI row (name, returnType, argumentTypes, kind) is unchanged.

   ## Behavior this snapshot does NOT change
   The kernel still raises NSException on a contract mismatch — six sites survive
   (IDUIKitInteractionCapability.m:130,144,157,262 and IDUIKitInputControllerCapability.m:131,228,531),
   plus TGRichTextInputDecHostPreflight's two methods. Only the two manifest-resource lookups were
   converted to nil-returning. The telegram-ios side must funnel every entry point through
   TGRichTextInputDecExceptionGuard; see that plan's Task A8.

   ## Paths this script owns (everything else in the module is telegram-ios-authored)
   Kernel/, include/Kernel/, Generated/, Vendor/,
   Host/TGRichTextInputDecHostPreflight.m, include/TGRichTextInputDecHostPreflight.h,
   Host/TGRichTextInputDecSelectionRect.m, include/TGRichTextInputDecSelectionRect.h

   ## Upstream green-run evidence
   xcodebuild test -project InputDec.xcodeproj -scheme InputDec \\
     -destination id=FA6F7462-AA97-42FE-9E57-8DA0593CE756 -parallel-testing-enabled NO
   EOF
   echo "exported kernel @ $REV -> $DEST"
   ```
   `chmod +x Scripts/export-behavior-kernel.sh`.

9. - [ ] **Step 9: Commit the scripts BEFORE running the export test.** This order is required, not cosmetic: `export-behavior-kernel.sh` refuses a tree with uncommitted tracked changes, and until this commit lands the four scripts are untracked — which `--untracked-files=no` tolerates, but committing them now also makes the `git rev-parse HEAD` recorded in `VENDOR.md` actually describe the script that produced the snapshot.
   ```sh
   cd /Users/isaac/Documents/InputDec && \
   git add Scripts/export-behavior-kernel.sh Scripts/test-export-behavior-kernel.sh && \
   git commit -m "feat(export): script the telegram-ios behavior-kernel snapshot"
   ```

10. - [ ] **Step 10: Stash the remaining working tree and run the test.**
    ```sh
    cd /Users/isaac/Documents/InputDec && git stash push --include-untracked --message "pre-export" && \
      Scripts/test-export-behavior-kernel.sh; \
      git stash pop
    ```
    Expect `export snapshot OK`. The stash is required because R3 recorded 20+ **tracked** modified files in this repo (`IDBlockTextView+Private*.m`, `IDPrivateUIKit.{h,m}`, the xcodeproj); `--include-untracked` additionally clears scratch files so the run is reproducible. Run `git stash pop` even if the test fails — the `;` above is deliberate.

11. - [ ] **Step 11: Amend the commit if the test forced a fix.** If Step 10 was red, fix the script, re-run Steps 9-10, and `git commit --amend` so exactly one commit lands.

### Task A4: Land the snapshot

This is the **one and only** commit that edits `InputBackendSourceBoundaryTests.swift` (Global Constraint 10). Three rules block this plan's Swift files, not one, and relaxing them piecemeal across five tasks would make the relaxation unreviewable.

**Files:**
- Create: `…/RichTextEditor/Sources/RichTextInputDecObjC/` (whole tree, produced by the script)
- Create: `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecBoundaryTests.swift`
- Modify: `Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift` (the reviewed R8 / R1 / R2 relaxation)
- Test: both of the above

**Interfaces:**
- Consumes: `RepoLayout` and `SwiftSourceScan` from the seam plan's source-boundary machinery.
- Produces: `InputDecBoundaryTests.test_objectiveCLivesOutsideTheSwiftGlob()`, `…test_noIDUIKitSymbolInSwiftOutsideTheAdapter()`, `…test_vendoredModuleIsPresentAndComplete()`; and `InputBackendSourceBoundaryTests.inputDecExemptPaths` / `.isInputDecExempt(_:)`.

**Steps:**

1. - [ ] **Step 1: Write the failing boundary test.** Create `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecBoundaryTests.swift`:
   ```swift
   import XCTest

   /// The vendored Objective-C module is allowed to exist from this commit onward, but only
   /// in one place and only reachable from one Swift directory.
   final class InputDecBoundaryTests: XCTestCase {

       /// PKG/BUILD globs `Sources/RichTextEditorUIKit/**/*.swift` ONLY. An .m or .h placed under
       /// that tree compiles under SwiftPM and is silently dropped from the Bazel app build.
       func test_objectiveCLivesOutsideTheSwiftGlob() {
           RepoLayout.assertResolved()
           let offenders = FileManager.default
               .enumerator(at: RepoLayout.uiKitSources, includingPropertiesForKeys: nil)?
               .compactMap { $0 as? URL }
               .filter { ["m", "mm", "h"].contains($0.pathExtension) } ?? []
           XCTAssertEqual(offenders.map(\.lastPathComponent), [],
                          "Objective-C under Sources/RichTextEditorUIKit is invisible to Bazel")
       }

       func test_noIDUIKitSymbolInSwiftOutsideTheAdapter() throws {
           RepoLayout.assertResolved()
           let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec").path
           var offenders: [String] = []
           for url in RepoLayout.swiftFiles(under: RepoLayout.uiKitSources) where !url.path.hasPrefix(adapter) {
               let source = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
               if source.range(of: #"\bIDUIKit\w+"#, options: .regularExpression) != nil {
                   offenders.append(url.lastPathComponent)
               }
           }
           XCTAssertEqual(offenders, [], "IDUIKit* symbols leaked out of InputBackend/InputDec")
       }

       func test_vendoredModuleIsPresentAndComplete() {
           RepoLayout.assertResolved()
           let root = RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC")
           for relative in ["Kernel/IDUIKitBehaviorKernel.m",
                            "include/Kernel/IDUIKitBehaviorKernel.h",
                            "Generated/TGRichTextInputDecContractData.m",
                            "Vendor/VENDOR.md"] {
               XCTAssertTrue(
                   FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path),
                   "missing vendored file \(relative)")
           }
       }
   }
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && swift test --filter InputDecBoundaryTests`. Expected failure: `missing vendored file Kernel/IDUIKitBehaviorKernel.m`.

3. - [ ] **Step 3: Relax R8, R1 and R2 — the reviewed exemption.** In `Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift`, add one shared predicate and apply it in exactly three places. Add at the top of the class:
   ```swift
       // ------------------------------------------------------------------------------------
       // InputDec exemption (docs/superpowers/plans/2026-08-16-inputdec-backend-introduction.md,
       // Task A4). Relaxed ONCE, in one commit, and never widened afterward.
       //
       // Exempt from: R8's `^ID[A-Z]` basename rule, R1's `\bID[A-Z]\w+` name rule, and R2's
       // Telegram-implementation-type list. NOT exempt from R1's banned-machinery list
       // (NSSelectorFromString / objc_msgSend / class_addMethod / …) or from R1b — those stay
       // absolute for every file in the package, which is what actually keeps private API inside
       // the Objective-C module.
       //
       // The set is a fixed list of TWO entries, not a pattern. A third entry is a review event.
       // ------------------------------------------------------------------------------------
       private static let inputDecExemptPaths = [
           "/InputBackend/InputDec/",                     // the adapter directory
           "/InputBackend/RichTextInputCanvasFactory.swift", // names both backends by construction
       ]

       private func isInputDecExempt(_ url: URL) -> Bool {
           Self.inputDecExemptPaths.contains { url.path.contains($0) }
       }

       /// The exemption must never grow, and must never become a pattern.
       func test_theInputDecExemptionIsExactlyTwoLiteralPaths() {
           XCTAssertEqual(Self.inputDecExemptPaths.count, 2,
                          "widening the InputDec exemption is a review event")
           for path in Self.inputDecExemptPaths {
               XCTAssertTrue(path.hasPrefix("/InputBackend/"), "exemptions are scoped to InputBackend")
               XCTAssertNil(path.range(of: #"[*?\[]"#, options: .regularExpression),
                            "the exemption is a fixed list, never a glob: \(path)")
           }
       }

       /// Non-vacuity. Added in Task B3, when BOTH exempt paths first have a file — before that,
       /// nothing is exempt and there is nothing to be vacuous about.
       func test_everyInputDecExemptPathMatchesALiveFile() throws {
           RepoLayout.assertResolved()
           let all = RepoLayout.swiftFiles(under: RepoLayout.inputBackend)
           for path in Self.inputDecExemptPaths {
               XCTAssertTrue(all.contains { $0.path.contains(path) },
                             "exempt path matches nothing — it is vacuous or misspelled: \(path)")
           }
       }
   ```
   Write `test_everyInputDecExemptPathMatchesALiveFile` **commented out** in this task, with the comment `// UNCOMMENT IN TASK B3 — both exempt paths are empty until the factory lands.` Task B3 Step 7 uncomments it. Commenting-out is deliberate rather than deleting: the reviewer of *this* commit sees the anti-vacuity guard being deferred, not omitted.
   Then, in `test_sharedContracts_containNoPrivateOrInputDecNames` (R1), leave the `banned` loop untouched and guard **only** the ID-name regex:
   ```swift
               if !isInputDecExempt(url) {
                   XCTAssertNil(text.range(of: #"\bID[A-Z]\w+"#, options: .regularExpression),
                                "\(url.lastPathComponent) references an InputDec-style ID-prefixed name")
               }
   ```
   In `test_sharedContracts_referenceNoTelegramImplementationTypes` (R2), extend the existing `where` clause:
   ```swift
           for url in inputBackendSources() where !url.path.contains("/Clients/")
               && !url.lastPathComponent.hasPrefix("Legacy")
               && !isInputDecExempt(url) {
   ```
   And in `test_noInputDecSourcesAndNoObjectiveCUnderTheSwiftTarget` (R8), keep the non-Swift-source assertion absolute and scope only the basename rule:
   ```swift
           for case let url as URL in e {
               XCTAssertFalse(["m", "mm", "h", "c"].contains(url.pathExtension),
                              "non-Swift source under the Swift target: \(url.lastPathComponent)")
               guard !isInputDecExempt(url) else { continue }
               XCTAssertNil(url.deletingPathExtension().lastPathComponent
                   .range(of: #"^ID[A-Z]"#, options: .regularExpression),
                   "InputDec-style source outside the exempt paths: \(url.lastPathComponent)")
           }
   ```

4. - [ ] **Step 4: Prove the relaxation is still tight.** `cd "$PKG" && swift test --filter RichTextEditorCoreTests.InputBackendSourceBoundaryTests` — all pre-existing rules plus `test_theInputDecExemptionIsExactlyTwoLiteralPaths` green. Nothing is exempt yet (no file matches either path), so this run must show **no change in behavior of any existing rule**: compare the passing-test count against the pre-edit run.

5. - [ ] **Step 5: Run the export.**
   ```sh
   cd /Users/isaac/Documents/InputDec && Scripts/export-behavior-kernel.sh \
     /Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC
   ```

6. - [ ] **Step 6: Add the aggregate header and the module anchor.** Create `Sources/RichTextInputDecObjC/include/TGRichTextInputDec.h`:
   ```objc
   // Every import is inside the guard: all nine kernel headers and both TG headers are
   // TARGET_OS_IOS-guarded internally, so on macOS this aggregate is empty and the module is
   // carried by TGRichTextInputDecModuleAnchor.m alone.
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS
   #import "IDUIKitBehaviorCapabilities.h"
   #import "IDUIKitBehaviorKernel.h"
   #import "IDUIKitBehaviorReport.h"
   #import "IDUIKitCapabilityResolver.h"
   #import "IDUIKitInputControllerCapability.h"
   #import "IDUIKitInteractionCapability.h"
   #import "IDUIKitRuntimeContract.h"
   #import "TGRichTextInputDecContract.h"
   #import "TGRichTextInputDecHostPreflight.h"
   #import "TGRichTextInputDecSelectionRect.h"
   #endif
   ```
   and `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecModuleAnchor.m`:
   ```objc
   // Always compiled, on every platform, so the macOS object file for this target is never
   // empty (`swift test` builds the package for arm64-apple-macosx).
   #import <Foundation/Foundation.h>

   void TGRichTextInputDecModuleAnchor(void);
   void TGRichTextInputDecModuleAnchor(void) {}
   ```
   and `Sources/RichTextInputDecObjC/include/TGRichTextInputDecContract.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <Foundation/Foundation.h>
   #import "IDUIKitRuntimeContract.h"

   NS_ASSUME_NONNULL_BEGIN

   /// The runtime contract manifest, parsed from bytes compiled into this module.
   ///
   /// THIS FUNCTION returns nil rather than @throw-ing when the compiled-in data fails to parse.
   /// That is a narrow guarantee and must not be over-read: the vendored kernel still raises
   /// NSException on a contract mismatch in six other places (IDUIKitInteractionCapability.m:130,
   /// 144, 157, 262 and IDUIKitInputControllerCapability.m:131, 228, 531), and
   /// TGRichTextInputDecHostPreflight's two class methods raise as well. Notably, with this
   /// function returning nil, IDUIKitInteractionRuntimeContract() dereferences a nil manifest and
   /// throws. Every reachable entry point is therefore funnelled through
   /// TGRichTextInputDecExceptionGuard on the Swift side; see that plan's Task A8.
   FOUNDATION_EXPORT IDUIKitRuntimeManifest * _Nullable TGRichTextInputDecContractManifest(void);

   NS_ASSUME_NONNULL_END

   #endif
   ```

7. - [ ] **Step 7: Run both boundary suites and see them pass.** `cd "$PKG" && swift test --filter SourceBoundary` — `InputDecBoundaryTests` 3 passing, `InputBackendSourceBoundaryTests` unchanged plus the new exemption test. (The target is not yet in `Package.swift`, so nothing compiles the `.m` files yet — that is Task A6; these tests are pure file I/O.)

8. - [ ] **Step 8: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorCoreTests/SourceBoundary && \
   git commit -m "vendor(inputdec): snapshot the UIKit behavior kernel + relax R8/R1/R2 once"
   ```

### Task A5: Snapshot integrity test

**Files:**
- Create: `Tests/RichTextEditorCoreTests/SourceBoundary/VendorSnapshotIntegrityTests.swift`
- Test: same file

**Interfaces:**
- Consumes: `Sources/RichTextInputDecObjC/Vendor/VENDOR.md`, `Generated/TGRichTextInputDecContractData.m`, `Vendor/UIKitBehaviorContracts-iOS26.5.json`.
- Produces: `VendorSnapshotIntegrityTests.test_generatedContractDataMatchesTheRecordedSHA()`, `…test_pristineManifestMatchesTheRecordedSHA()`, `…test_vendorMarkdownRecordsACommitAndAnOSBand()`, `…test_thePristineManifestStillNamesTheUpstreamClasses()`, `…test_vendorMarkdownRecordsTheRenameTableAndTheExceptionCaveat()` — five methods.

**Scope note:** this suite lives in `RichTextEditorCoreTests`, which builds for **macOS** and cannot import the Objective-C module. It therefore checks the snapshot as *files*: digests, provenance, and the pristine JSON. Everything that requires the manifest to be *parsed* — above all, that the renames actually landed — is asserted in `ContractManifestTests` (Task A6), on the simulator, against the parsed object.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Note the class-level `@available`: `Package.swift:6` declares `.macOS(.v10_13)` while `CryptoKit.SHA256` is `@available(macOS 10.15, iOS 13.0, *)`. This compiles today only because the Swift driver clamps the arm64-macOS deployment target to 11.0; on an x86_64 host, or with a pinned `--triple`, the unannotated version fails with *"'SHA256' is only available in macOS 10.15 or newer"*. Annotating costs nothing and makes the fast macOS loop host-architecture-independent.
   ```swift
   import CryptoKit
   import Foundation
   import XCTest

   /// A hand-edit of the synced snapshot fails the suite. This is the mechanism that makes
   /// "do not hand-edit — re-sync with the export script" enforceable rather than aspirational.
   @available(macOS 10.15, iOS 13.0, *)
   final class VendorSnapshotIntegrityTests: XCTestCase {

       private var vendorRoot: URL {
           RepoLayout.packageRoot.appendingPathComponent("Sources/RichTextInputDecObjC")
       }

       private func recordedSHA(_ label: String) throws -> String {
           let markdown = try String(contentsOf: vendorRoot.appendingPathComponent("Vendor/VENDOR.md"))
           // FAIL, never skip. A truncated or malformed VENDOR.md is exactly the corruption this
           // suite exists to catch; XCTSkip here would turn the integrity check into a green
           // no-op the moment the file it reads goes missing.
           guard let line = markdown.split(separator: "\n").first(where: { $0.contains(label) }),
                 let hex = line.split(separator: " ").last, !hex.isEmpty else {
               XCTFail("VENDOR.md has no line for \(label) — re-run "
                       + "InputDec/Scripts/export-behavior-kernel.sh")
               return ""
           }
           return String(hex)
       }

       private func sha256(of url: URL) throws -> String {
           let digest = SHA256.hash(data: try Data(contentsOf: url))
           return digest.map { String(format: "%02x", $0) }.joined()
       }

       func test_generatedContractDataMatchesTheRecordedSHA() throws {
           RepoLayout.assertResolved()
           let generated = vendorRoot.appendingPathComponent("Generated/TGRichTextInputDecContractData.m")
           XCTAssertEqual(try sha256(of: generated),
                          try recordedSHA("generated contract data SHA-256"),
                          "Generated/TGRichTextInputDecContractData.m was hand-edited — re-run "
                          + "InputDec/Scripts/export-behavior-kernel.sh instead")
       }

       func test_pristineManifestMatchesTheRecordedSHA() throws {
           RepoLayout.assertResolved()
           let json = vendorRoot.appendingPathComponent("Vendor/UIKitBehaviorContracts-iOS26.5.json")
           XCTAssertEqual(try sha256(of: json), try recordedSHA("pristine manifest SHA-256"))
       }

       func test_vendorMarkdownRecordsACommitAndAnOSBand() throws {
           RepoLayout.assertResolved()
           let markdown = try String(contentsOf: vendorRoot.appendingPathComponent("Vendor/VENDOR.md"))
           XCTAssertTrue(markdown.contains("upstream commit: "), "no upstream commit recorded")
           XCTAssertTrue(markdown.contains("certified OS band: "), "no certified OS band recorded")
           XCTAssertTrue(markdown.contains("23F73"),
                         "the certified build is the only combination this kernel has run on; "
                         + "record it explicitly")
       }

       /// The PRISTINE copy must be exactly upstream's, renames NOT applied — it is the audit
       /// input, and the codegen's own test re-derives the transform from it. Asserting on the
       /// GENERATED file's text is impossible here and would be vacuous anyway: the payload is a
       /// hex byte array (`0x49, 0x44, …`), so `contains("IDRichTextLayoutController")` is false
       /// whether or not a single rename happened. The parsed-manifest assertions are in
       /// ContractManifestTests (Task A6).
       func test_thePristineManifestStillNamesTheUpstreamClasses() throws {
           RepoLayout.assertResolved()
           let url = vendorRoot.appendingPathComponent("Vendor/UIKitBehaviorContracts-iOS26.5.json")
           let root = try XCTUnwrap(
               try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
           let capabilities = try XCTUnwrap(root["capabilities"] as? [String: Any])
           let incoming = try XCTUnwrap(capabilities["incomingCallbacks"] as? [String: Any])
           let members = try XCTUnwrap(incoming["members"] as? [[String: Any]])
           XCTAssertEqual(members.count, 47)
           // The JSON key is "class". "className" exists only as the parsed ObjC property
           // (IDUIKitRuntimeContract.m:344) — renaming on that key would rewrite nothing.
           XCTAssertTrue(members.allSatisfy { $0["class"] as? String == "IDRichTextLayoutController" },
                         "the pristine manifest must be untransformed")
           XCTAssertNil(members.first?["className"],
                        "if upstream ever renames this key, the codegen's RENAMES walker must follow")
       }

       func test_vendorMarkdownRecordsTheRenameTableAndTheExceptionCaveat() throws {
           RepoLayout.assertResolved()
           let markdown = try String(contentsOf: vendorRoot.appendingPathComponent("Vendor/VENDOR.md"))
           XCTAssertTrue(markdown.contains("TGRichTextInputDecLayoutController"))
           XCTAssertTrue(markdown.contains("TGRichTextInputDecCanvasABIWitness"))
           XCTAssertTrue(markdown.contains("referenceOnly` is emptied"),
                         "VENDOR.md must state that referenceOnly is emptied, not deleted")
           XCTAssertTrue(markdown.contains("still raises NSException"),
                         "VENDOR.md must not claim the kernel became exception-free")
       }
   }
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && swift test --filter VendorSnapshotIntegrityTests`. Expected failure on `test_generatedContractDataMatchesTheRecordedSHA` if the snapshot was touched after export, or a pass if Task A4 was clean — in which case deliberately append a space to `Generated/TGRichTextInputDecContractData.m`, re-run, and confirm the failure message names the file, then `git checkout` it.

3. - [ ] **Step 3: Re-export if red.** `cd /Users/isaac/Documents/InputDec && Scripts/export-behavior-kernel.sh /Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC`.

4. - [ ] **Step 4: Run and see it pass.** `cd "$PKG" && swift test --filter VendorSnapshotIntegrityTests` — 5 tests passing.

5. - [ ] **Step 5: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorCoreTests/SourceBoundary/VendorSnapshotIntegrityTests.swift && \
   git commit -m "test(inputdec): fail the suite on a hand-edited vendored snapshot"
   ```

### Task A6: SwiftPM target

**Files:**
- Modify: `…/RichTextEditor/Package.swift`
- Test: `swift build` (macOS) and `swift test` (Core suite)

**Interfaces:**
- Produces: SwiftPM target `RichTextInputDecObjC`, importable from Swift as `import RichTextInputDecObjC`.

**Steps:**

1. - [ ] **Step 1: Write the failing import test.** Create `Tests/RichTextEditorUIKitTests/InputDec/ContractManifestTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import XCTest

   /// This suite is the ONLY non-vacuous check that the class renames landed. Text greps over the
   /// generated `.m` cannot serve: the payload is emitted as `0x49, 0x44, …`, so a grep for an
   /// upstream class name is satisfied whether or not any rename happened. Everything here runs
   /// against the PARSED manifest.
   final class ContractManifestTests: XCTestCase {
       func test_manifestParsesFromCompiledInBytes() {
           let manifest = TGRichTextInputDecContractManifest()
           XCTAssertNotNil(manifest, "the compiled-in contract data failed to parse")
       }

       func test_manifestRecordsTheCertifiedOSBand() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           XCTAssertEqual(manifest.osVersion, "26.5")
           XCTAssertEqual(manifest.osBuild, "23F73")
       }

       /// THE load-bearing test of the vendoring. `IDUIKitCapabilityResolver.evaluateContract:`
       /// looks each member's class up with NSClassFromString and rejects the whole capability when
       /// it is nil; `incomingCallbacks` is mandatory. If the codegen renamed on the wrong key
       /// (the JSON spells it "class", not "className"), these 47 rows still say
       /// IDRichTextLayoutController, that class does not exist in this binary, and
       /// isSupported() can never return true — with no build error anywhere.
       func test_everyIncomingCallbackRowNamesTheVendoredLayoutController() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           let incoming = try XCTUnwrap(manifest.capabilities["incomingCallbacks"])
           XCTAssertEqual(incoming.members.count, 47)
           for member in incoming.members {
               XCTAssertEqual(member.className, "TGRichTextInputDecLayoutController",
                              "row \(member.identifier) was not renamed")
           }
       }

       /// The three canvas-hosted rows: inputController.keyboardDeletePreflight,
       /// autoscrollEntry.start, autoscrollEntry.cancel.
       func test_theThreeCanvasRowsNameTheABIWitness() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           var renamed: [String] = []
           for (_, capability) in manifest.capabilities {
               for member in capability.members where member.className == "TGRichTextInputDecCanvasABIWitness" {
                   renamed.append(member.identifier)
               }
           }
           XCTAssertEqual(Set(renamed), ["inputController.keyboardDeletePreflight",
                                         "autoscrollEntry.start", "autoscrollEntry.cancel"])
       }

       /// No upstream class name may survive anywhere in the shipped manifest.
       func test_noUpstreamClassNameSurvivesAnywhere() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           for (name, capability) in manifest.capabilities {
               for member in capability.members {
                   XCTAssertNotEqual(member.className, "IDRichTextLayoutController", "\(name)")
                   XCTAssertNotEqual(member.className, "IDBlockTextView", "\(name)")
               }
           }
       }

       /// `referenceOnly` is EMPTIED, not deleted: `manifestWithData:error:` runs
       /// IDUIKitDictionaryHasExactKeys over {schema, runtime, capabilities, referenceOnly,
       /// forbidden} (IDUIKitRuntimeContract.m:667-678), so deleting the key fails the parse
       /// outright — `test_manifestParsesFromCompiledInBytes` would go red first.
       /// `forbidden` DOES travel: it is a deny-list, and it is the only machine-checkable
       /// statement that the reference backend's surfaces are not used.
       func test_referenceOnlyIsEmptyAndTheForbiddenDenyListIsIntact() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           XCTAssertEqual(manifest.referenceOnly.count, 0,
                          "the 53 referenceOnly rows belong to the excluded reference backend")
           XCTAssertEqual(manifest.forbiddenSymbols.count, 8)
           for symbol in ["_UITextLayoutControllerBase", "_UITextKit2LayoutController",
                          "_UITextLayoutCanvasView", "_UITextLayoutCanvasViewController",
                          "layoutControllerWithTextView:textContainer:",
                          "initWithTextView:textContainer:", "_canvasViewForTextContainer:",
                          "_setCanvasView:forTextContainer:"] {
               XCTAssertTrue(manifest.forbiddenSymbols.contains(symbol), "missing deny-list entry \(symbol)")
           }
       }

       func test_mandatoryCapabilitiesArePresent() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
               XCTAssertNotNil(manifest.capabilities[name], "missing mandatory capability \(name)")
           }
       }
   }
   #endif
   ```
   These assertions are about the manifest's *content*, so they all go green as soon as the module compiles. The complementary half — that the two renamed class **names actually resolve in this binary**, which is what `IDUIKitCapabilityResolver` needs — is asserted where each class is created: `CanvasABIWitnessTests.test_witnessClassResolvesUnderTheRenamedManifestName` (Task B4) and `IDBackendAttachDetachTests.test_layoutControllerResolvesUnderTheRenamedManifestName` (Task C0).

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/ContractManifestTests`. Expected failure: `error: no such module 'RichTextInputDecObjC'`.

3. - [ ] **Step 3: Add the target.** In `Package.swift`, insert after the `RichTextEditorCoreTests` test target and edit the two dependency lists:
   ```swift
           // Vendored InputDec UIKit behavior kernel (Objective-C). The path is deliberately OUTSIDE
           // Sources/RichTextEditorUIKit: the Bazel glob there is `**/*.swift` and would silently drop
           // .m/.h that SwiftPM happily compiles.
           //
           // `publicHeadersPath: "include"` makes SwiftPM synthesize an umbrella-DIRECTORY module map
           // over include/**, so EVERY header there is compiled — including the three kernel headers
           // whose line 1 is `#import <UIKit/UIKit.h>`. Since this package also declares
           // `.macOS(.v10_13)` (line 6) and RichTextEditorUIKit depends on this target, the export
           // script wraps every vendored .h AND .m in `#if TARGET_OS_IOS`; without the header half,
           // `swift build` on macOS fails with "module 'UIKit' not found".
           // DO NOT HAND-EDIT — see Sources/RichTextInputDecObjC/Vendor/VENDOR.md.
           .target(
               name: "RichTextInputDecObjC",
               path: "Sources/RichTextInputDecObjC",
               exclude: ["Vendor"],
               publicHeadersPath: "include",
               cSettings: [
                   .headerSearchPath("include"),
                   .headerSearchPath("include/Kernel"),
               ]
           ),
           .target(name: "RichTextEditorUIKit", dependencies: [
               "RichTextEditorCore",
               "RichTextInputDecObjC",
               .product(name: "MosaicLayout", package: "MosaicLayout"),
           ], resources: [.process("Resources/Media.xcassets")]),
           .testTarget(name: "RichTextEditorUIKitTests",
                       dependencies: ["RichTextEditorUIKit", "RichTextInputDecObjC"]),
   ```
   `exclude: ["Vendor"]` is required — a stray `.json` inside a target directory is an unhandled resource and SwiftPM errors out.

4. - [ ] **Step 4: Prove the macOS build works — this is the header-guard gate.** `cd "$PKG" && swift build 2>&1 | tail -20`. Expect `Build complete`. Two distinct failure modes surface here, and they read almost identically:
   - `module 'UIKit' not found` while compiling a **header** — an `include/**` header lost its guard. Fix in `guard_file`'s loop in the export script (`export-behavior-kernel.sh` Step 6), re-export, never hand-patch the snapshot (`VendorSnapshotIntegrityTests` fails on a hand-edit by design).
   - `module 'UIKit' not found` while compiling a `.m` — same fix, same loop.
   Confirm the guard placement without a full rebuild with:
   ```sh
   cd "$PKG" && for f in Sources/RichTextInputDecObjC/include/Kernel/*.h Sources/RichTextInputDecObjC/Kernel/*.m; do
     head -3 "$f" | grep -q "^#if TARGET_OS_IOS" || echo "UNGUARDED: $f"; done
   ```

5. - [ ] **Step 5: Run the simulator test and see it pass.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/ContractManifestTests` — 7 tests passing.

6. - [ ] **Step 6: Run the full Core suite for regressions.** `cd "$PKG" && swift test 2>&1 | tail -5`. Expect the pre-existing Core count plus this plan's boundary/integrity tests, zero failures.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Package.swift \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/ContractManifestTests.swift && \
   git commit -m "build(swiftpm): compile the vendored InputDec kernel target"
   ```

### Task A7: Bazel objc_library

**Files:**
- Modify: `…/RichTextEditor/BUILD`
- Test: full `Make.py build`

**Interfaces:**
- Produces: Bazel target `//submodules/TelegramUI/Components/RichTextEditor:RichTextInputDecObjC`, consumed by `:RichTextEditorUIKit`.

**Steps:**

1. - [ ] **Step 1: Confirm the failure first.** Run the full build **before** editing `BUILD`, so the "no such module" error is attributable:
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && source ~/.zshrc 2>/dev/null; \
   python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build \
     --configurationPath build-system/appstore-configuration.json \
     --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
     --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
     --configuration=debug_sim_arm64 --continueOnError 2>&1 | tail -40
   ```
   At this point nothing in Swift imports the module yet, so this build should be **green** — that is the baseline. Record the wall time; the full build is the only Bazel check available.

2. - [ ] **Step 2: Add the `objc_library`.** In `BUILD`, insert immediately before the `swift_library(name = "RichTextEditorUIKit", …)` block. The shape (`module_name` + `enable_modules = True` + one public-header dir in both `hdrs` and `includes`) is the in-repo template from `submodules/MozjpegBinding/BUILD:2-24`, consumed by a `swift_library` at `submodules/ImageCompression/BUILD:3-18`:
   ```python
   # Vendored InputDec UIKit behavior kernel. These sources live OUTSIDE Sources/RichTextEditorUIKit,
   # whose glob is `**/*.swift` and would silently ignore .m/.h files.
   # DO NOT HAND-EDIT — see Sources/RichTextInputDecObjC/Vendor/VENDOR.md.
   objc_library(
       name = "RichTextInputDecObjC",
       module_name = "RichTextInputDecObjC",
       enable_modules = True,
       srcs = glob([
           "Sources/RichTextInputDecObjC/**/*.m",
           "Sources/RichTextInputDecObjC/**/*.h",
       ], exclude = [
           "Sources/RichTextInputDecObjC/include/**/*.h",
       ], allow_empty = False),
       hdrs = glob([
           "Sources/RichTextInputDecObjC/include/**/*.h",
       ]),
       includes = [
           "Sources/RichTextInputDecObjC/include",
           "Sources/RichTextInputDecObjC/include/Kernel",
       ],
       copts = [
           "-fobjc-arc",
       ],
       visibility = [
           "//visibility:public",
       ],
   )
   ```
   `Vendor/*.json` is matched by no glob, so it never enters the build graph.

3. - [ ] **Step 3: Add the dep edge.** In the `swift_library(name = "RichTextEditorUIKit", …)` `deps` list, add `":RichTextInputDecObjC",` directly after `":RichTextEditorCore",`.

4. - [ ] **Step 4: Force a real compile of the ObjC from Swift.** Create `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendModuleProbe.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC

   /// Forces both build systems to actually compile and link the vendored Objective-C module.
   /// Without a Swift import, Bazel would happily accept a broken `objc_library` that nothing
   /// depends on, and the divergence would only surface at Stage C.
   enum IDTextEditorBackendModuleProbe {
       static var isContractManifestLinkable: Bool { TGRichTextInputDecContractManifest() != nil }
   }
   #endif
   ```
   This file is the first inhabitant of `InputBackend/InputDec/`, which Task A4 exempted from R8's `^ID[A-Z]` basename rule and R1's ID-name rule. It is deliberately **not** exempt from R1's banned-machinery list — and does not need to be: it names no selector and performs no runtime lookup.

5. - [ ] **Step 5: Run the source-boundary suite.** `cd "$PKG" && swift test --filter SourceBoundary` — green. This is the moment the A4 relaxation is first exercised on a real file; if `test_noInputDecSourcesAndNoObjectiveCUnderTheSwiftTarget` now fails, the exempt-path string does not match the actual path (check for a missing leading `/`).

6. - [ ] **Step 6: Run the full build and see it pass.** Re-run the Step 1 command. Expect `BUILD SUCCESSFUL`. If it fails on a header not found, the cause is almost always a kernel `.m` importing a sibling header by bare name — fix by confirming both `includes` entries are present, never by editing a vendored import.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/BUILD \
           submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendModuleProbe.swift && \
   git commit -m "build(bazel): link the vendored InputDec kernel into RichTextEditorUIKit"
   ```

### Task A8: The exception guard

The vendored kernel is **not** exception-free, and pretending otherwise is the most dangerous inaccuracy this plan could ship. Task A3's Edit 1 converts exactly two manifest-resource lookups to nil-returning. Everything else still raises `NSException`, and **Swift cannot catch an `NSException`** — an uncaught one is an immediate app crash.

Verified raise sites reachable from this adapter:

| Site | Trigger |
| --- | --- |
| `IDUIKitInteractionCapability.m:144` (`IDUIKitInteractionRuntimeContract`) | `IDUIKitInteractionManifest()` returns nil ⇒ `nil.capabilities[@"interaction"]` is nil ⇒ throw. **This is the direct consequence of Edit 1.** |
| `IDUIKitInteractionCapability.m:157` (`IDUIKitFloatingCursorRuntimeContract`) | same, for `floatingCursor` |
| `IDUIKitInteractionCapability.m:130` | manifest data unavailable (unreachable after Edit 1, kept for symmetry) |
| `IDUIKitInteractionCapability.m:262` | private assistant initialization failed |
| `IDUIKitInputControllerCapability.m:131` | `initWithTextLayoutController:` returned nil |
| `IDUIKitInputControllerCapability.m:228` (`activeController`) | **any witness call after `detach()`** — the single most likely one in production |
| `IDUIKitInputControllerCapability.m:531` | `_rangesForBackwardsDelete` result lacks `unionRange` |
| `TGRichTextInputDecHostPreflight.requireInteractionHost:stage:` | any interaction-host ABI mismatch. **Caveat:** its one in-kernel call site is already wrapped upstream (`@try`/`@catch` at `IDUIKitInteractionCapability.m:199-206`, converting to `IDUIKitInteractionCapabilityErrorInvalidHost`), so this row is safe *today* — but it is a public class method the adapter may also call directly, and every other row above is unguarded. |

**Files:**
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecExceptionGuard.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecExceptionGuard.m`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/ExceptionGuardTests.swift`

**Interfaces:**
- Produces:
  ```objc
  FOUNDATION_EXPORT BOOL TGRichTextInputDecPerform(void (NS_NOESCAPE ^block)(void), NSError **error);
  FOUNDATION_EXPORT id _Nullable TGRichTextInputDecPerformReturningObject(id _Nullable (NS_NOESCAPE ^block)(void), NSError **error);
  FOUNDATION_EXPORT NSErrorDomain const TGRichTextInputDecExceptionGuardErrorDomain;
  ```

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/ExceptionGuardTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import XCTest

   /// Swift cannot catch an NSException; an uncaught one is an immediate crash. Every call the
   /// adapter makes into the vendored kernel therefore goes through this trampoline.
   final class ExceptionGuardTests: XCTestCase {

       func test_aRaisedExceptionBecomesAnError_notACrash() {
           var error: NSError?
           let ok = TGRichTextInputDecPerform({
               NSException(name: .internalInconsistencyException,
                           reason: "synthetic", userInfo: nil).raise()
           }, &error)
           XCTAssertFalse(ok)
           XCTAssertEqual(error?.domain, TGRichTextInputDecExceptionGuardErrorDomain)
           XCTAssertEqual(error?.localizedDescription, "synthetic")
       }

       func test_aCleanBlockReportsSuccessAndLeavesTheErrorUntouched() {
           var error: NSError? = NSError(domain: "sentinel", code: 0)
           var ran = false
           XCTAssertTrue(TGRichTextInputDecPerform({ ran = true }, &error))
           XCTAssertTrue(ran)
           XCTAssertEqual(error?.domain, "sentinel", "a successful call must not clobber the out-param")
       }

       func test_theObjectFlavorReturnsNilOnRaise_andTheValueOtherwise() {
           var error: NSError?
           XCTAssertNil(TGRichTextInputDecPerformReturningObject({
               NSException(name: .genericException, reason: "boom", userInfo: nil).raise()
               return NSString("unreachable")
           }, &error))
           XCTAssertNotNil(error)
           error = nil
           let value = TGRichTextInputDecPerformReturningObject({ NSString("ok") }, &error) as? String
           XCTAssertEqual(value, "ok")
           XCTAssertNil(error)
       }

       /// The exception name and userInfo must survive into the error, or a production report of
       /// "the kernel refused" carries no diagnostic value.
       func test_theExceptionNameAndUserInfoSurviveIntoTheError() {
           var error: NSError?
           _ = TGRichTextInputDecPerform({
               NSException(name: .internalInconsistencyException, reason: "why",
                           userInfo: ["stage": "preflight"]).raise()
           }, &error)
           XCTAssertEqual(error?.userInfo["TGRichTextInputDecExceptionName"] as? String,
                          NSExceptionName.internalInconsistencyException.rawValue)
           XCTAssertEqual((error?.userInfo["TGRichTextInputDecExceptionUserInfo"]
                           as? [String: Any])?["stage"] as? String, "preflight")
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/ExceptionGuardTests`. Expected failure: `cannot find 'TGRichTextInputDecPerform' in scope`.

3. - [ ] **Step 3: Write the header.** Create `Sources/RichTextInputDecObjC/include/TGRichTextInputDecExceptionGuard.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <Foundation/Foundation.h>

   NS_ASSUME_NONNULL_BEGIN

   FOUNDATION_EXPORT NSErrorDomain const TGRichTextInputDecExceptionGuardErrorDomain;

   /// Runs `block` inside @try/@catch and converts any NSException into an NSError.
   ///
   /// Swift has no `catch` for NSException, so an ObjC-raised exception crossing back into Swift
   /// terminates the process. The vendored kernel raises on every contract mismatch — see
   /// Vendor/VENDOR.md, "Behavior this snapshot does NOT change" — and it is certified against
   /// exactly ONE OS build, so a mismatch on a future OS is the expected case, not an edge case.
   ///
   /// Returns YES on clean completion; on NO, `*error` is set and out-params are untouched.
   FOUNDATION_EXPORT BOOL TGRichTextInputDecPerform(void (NS_NOESCAPE ^block)(void),
                                                    NSError **error);

   /// Same, for a block that returns an object. Returns nil on raise.
   FOUNDATION_EXPORT id _Nullable TGRichTextInputDecPerformReturningObject(
       id _Nullable (NS_NOESCAPE ^block)(void), NSError **error);

   NS_ASSUME_NONNULL_END

   #endif
   ```

4. - [ ] **Step 4: Write the implementation.** Create `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecExceptionGuard.m`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import "TGRichTextInputDecExceptionGuard.h"

   NSErrorDomain const TGRichTextInputDecExceptionGuardErrorDomain =
       @"TGRichTextInputDecExceptionGuardErrorDomain";

   static NSError *TGErrorFromException(NSException *exception) {
       NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
       userInfo[NSLocalizedDescriptionKey] = exception.reason ?: @"<no reason>";
       userInfo[@"TGRichTextInputDecExceptionName"] = exception.name ?: @"<unnamed>";
       if (exception.userInfo != nil) {
           userInfo[@"TGRichTextInputDecExceptionUserInfo"] = exception.userInfo;
       }
       return [NSError errorWithDomain:TGRichTextInputDecExceptionGuardErrorDomain
                                  code:1
                              userInfo:userInfo.copy];
   }

   BOOL TGRichTextInputDecPerform(void (NS_NOESCAPE ^block)(void), NSError **error) {
       @try {
           block();
           return YES;
       } @catch (NSException *exception) {
           if (error != NULL) { *error = TGErrorFromException(exception); }
           return NO;
       }
   }

   id TGRichTextInputDecPerformReturningObject(id (NS_NOESCAPE ^block)(void), NSError **error) {
       @try {
           return block();
       } @catch (NSException *exception) {
           if (error != NULL) { *error = TGErrorFromException(exception); }
           return nil;
       }
   }

   #endif
   ```
   Add `#import "TGRichTextInputDecExceptionGuard.h"` to the guarded block of `include/TGRichTextInputDec.h`.

5. - [ ] **Step 5: Run and see it pass.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/ExceptionGuardTests` — 4 tests passing.

6. - [ ] **Step 6: Write down the usage rule where it will be read.** Append to `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendModuleProbe.swift`:
   ```swift
   /// USAGE RULE for every later task in this plan:
   ///
   /// No Swift code in InputBackend/InputDec/ may call a kernel method directly. Every call —
   /// kernel construction, every `kernelInput`/`kernelInteraction` witness, every preflight —
   /// goes through `TGRichTextInputDecPerform` / `…PerformReturningObject`, and a caught
   /// exception becomes a thrown `RichTextInputBackendAttachmentError.privateRuntimeFailure`
   /// (at attach) or a logged no-op that returns the witness's documented "absent" value
   /// (afterwards). `IDUIKitInputControllerCapability.activeController` raises on ANY call after
   /// detach, so the post-detach path is the common case, not the exotic one.
   ///
   /// `IDBackendCallGuardTests` (Task C0 Step 9) greps this directory and fails on a direct call.
   enum IDTextEditorBackendKernelCallPolicy {}
   ```

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC \
           submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/ExceptionGuardTests.swift && \
   git commit -m "feat(inputdec): NSException trampoline for every kernel entry point"
   ```

### Task A9: Record the snapshot policy in CLAUDE.md

**Files:**
- Modify: `/Users/isaac/build/telegram/telegram-ios/CLAUDE.md`
- Modify: `…/RichTextEditor/CLAUDE.md`
- Test: none (documentation); verified by review

**Interfaces:** none.

**Steps:**

1. - [ ] **Step 1: Add the root section.** Append to `/Users/isaac/build/telegram/telegram-ios/CLAUDE.md`, after the "Embedded watch app" section:
   ```markdown
   ## Vendored InputDec behavior kernel

   `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC/` is a **synced
   snapshot — do not hand-edit** the paths listed in its `Vendor/VENDOR.md`. The source of truth is
   the separate `~/Documents/InputDec` repo; re-sync with
   `InputDec/Scripts/export-behavior-kernel.sh <abs path to Sources/RichTextInputDecObjC>` and commit
   the result. A hand-edit fails `VendorSnapshotIntegrityTests`.

   The directory is a **sibling** of `Sources/RichTextEditorUIKit/`, deliberately: `BUILD` globs
   `Sources/RichTextEditorUIKit/**/*.swift` only, so an `.m`/`.h` under that tree compiles under
   SwiftPM and vanishes from the app with no error.

   The kernel is **certified** against exactly one OS build (iOS 26.5 / 23F73), but **selection is
   gated on a floor of iOS 17.0**, not on that build (decision 2, 2026-08-17). The manifest's
   `runtime` block is therefore provenance, not a gate: `isSupported()` can answer yes on an OS the
   kernel was never certified against, and what keeps that safe is the live re-evaluation of the
   three mandatory contracts on every call plus the fallback to legacy on refusal. **A matching type
   encoding does not prove matching semantics** — the differential corpus
   (`docs/input-backend-differential-baseline.md`, run for both backends) is the only instrument that
   would catch a semantic drift on an uncertified OS, which is why it must be run on more than one
   OS version before any wider enablement.

   It is compiled at the iOS 13 floor (`#if TARGET_OS_IOS` on every `.m` **and** every `.h` — three
   kernel headers import UIKit on line 1 and SwiftPM compiles all of `include/**` on macOS; no
   `API_AVAILABLE` anywhere); the availability boundary is drawn once, in Swift, as
   `@available(iOS 17.0, *)` on `IDTextEditorBackend` and `IDDocumentCanvasView`.

   **Upstream has no CI.** InputDec's enforcement is a standing manual discipline — the UIKit
   equivalence tests are run on every change — and the export script's three tests are part of that
   same per-change run. So an upstream refactor that breaks the symbol-name carve is caught by a
   human running tests, reliably but not mechanically. The only *automated* guard on this side is
   `VendorSnapshotIntegrityTests`; do not weaken it on the grounds that upstream already tests, because
   upstream tests the kernel while that suite tests this repo's copy of it.

   **The kernel still raises `NSException` on a contract mismatch.** Only the two manifest-resource
   lookups were converted to nil-returning. Seven other raise sites survive, including
   `IDUIKitInputControllerCapability.activeController`, which raises on *any* call after `detach()`.
   Swift cannot catch an `NSException`, so every call from Swift into the kernel goes through
   `TGRichTextInputDecPerform` (`TGRichTextInputDecExceptionGuard.h`). Adding a direct call is a
   crash waiting for a new OS build, and `IDBackendCallGuardTests` fails the suite on one.
   ```

2. - [ ] **Step 2: Add the package-level pointer.** Append one paragraph to `…/RichTextEditor/CLAUDE.md` naming `Sources/RichTextInputDecObjC/`, this plan document, and the exception-guard rule.

3. - [ ] **Step 3: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add CLAUDE.md submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md && \
   git commit -m "docs: record the vendored-kernel snapshot policy"
   ```

### Task A10: The `EXTRA` passthrough in `iostest.sh`

**Prerequisite, verified before editing:** the seam plan's Task 9 Step 5 **already** rewrote this invocation to add `-parallel-testing-enabled NO` and the `TK1` → `TEST_RUNNER_RTE_FORCE_TK1=1` mapping. Re-applying that edit here would either duplicate the flag or clobber the earlier one (the seam plan writes `EXTRA=""` and `EXTRA="TEST_RUNNER_…"`; a naive re-write with `EXTRA="${EXTRA:-}"` and `EXTRA="$EXTRA …"` is a *different* shape, not an idempotent one). This task therefore **verifies first and adds only what is missing**: the outer `EXTRA` passthrough, which `matrix.sh` needs in Task D1.

**Files:**
- Modify: `…/RichTextEditor/Scripts/iostest.sh`
- Test: `bash -x` trace of the resulting command line

**Interfaces:**
- Produces: `iostest.sh` honouring `DEVICE`, `TK1=1`, and a caller-supplied `EXTRA`.

**Steps:**

1. - [ ] **Step 1: Verify what the seam plan already left behind.**
   ```sh
   cd "$PKG" && grep -n "parallel-testing-enabled\|TEST_RUNNER_RTE_FORCE_TK1\|EXTRA" Scripts/iostest.sh
   ```
   Expect three hits: `EXTRA=""`, `[ "${TK1:-0}" = "1" ] && EXTRA="TEST_RUNNER_RTE_FORCE_TK1=1"`, and `-parallel-testing-enabled NO … $EXTRA`. **If `-parallel-testing-enabled NO` is absent, stop** — the seam plan's Task 9 did not land, and the entry checklist was not actually green.

2. - [ ] **Step 2: Make `EXTRA` an inherited variable rather than a reset one.** Change exactly two lines:
   ```sh
   -EXTRA=""
   -[ "${TK1:-0}" = "1" ] && EXTRA="TEST_RUNNER_RTE_FORCE_TK1=1"
   +# `EXTRA` is INHERITED, not reset: matrix.sh (and any A/B run) needs to append its own
   +# xcodebuild arguments on top of the TK1 mapping. `-parallel-testing-enabled NO` above is the
   +# seam plan's, and stays: overlapping XCTest processes against one simulator is the documented
   +# cause of flakes here, and InputDec's AGENTS.md mandates it upstream. Never background a pass.
   +EXTRA="${EXTRA:-}"
   +[ "${TK1:-0}" = "1" ] && EXTRA="$EXTRA TEST_RUNNER_RTE_FORCE_TK1=1"
   ```
   Nothing else in the file changes.

3. - [ ] **Step 3: Verify both variables reach xcodebuild.**
   ```sh
   cd "$PKG" && EXTRA="-resultBundlePath /tmp/rte.xcresult" TK1=1 \
     bash -x Scripts/iostest.sh RichTextEditorUIKitTests/ContractManifestTests 2>&1 \
     | grep -m1 "xcodebuild test"
   ```
   The traced line must contain `-parallel-testing-enabled NO`, `TEST_RUNNER_RTE_FORCE_TK1=1` **and** `-resultBundlePath` — all three, in one invocation.

4. - [ ] **Step 4: Verify K3 selection works.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/ContractManifestTests` — 7 tests passing on the iOS 26.5 simulator.

5. - [ ] **Step 5: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Scripts/iostest.sh && \
   git commit -m "test(scripts): let callers append xcodebuild args via EXTRA"
   ```

### Task A11: Stage A exit gate

**Files:** none created; this task only runs and records verification.

**Interfaces:** none.

**Steps:**

1. - [ ] **Step 1: Core suite, macOS.** `cd "$PKG" && swift test 2>&1 | tail -5`. Record the executed/failed counts; they must equal the pre-Stage-A counts plus this stage's boundary + integrity tests, with zero failures.

2. - [ ] **Step 2: Full UIKit suite, K1.** `cd "$PKG" && Scripts/iostest.sh 2>&1 | tail -5`. Record the counts; they must equal the pre-Stage-A counts plus the 7 `ContractManifestTests` and the 4 `ExceptionGuardTests`.

3. - [ ] **Step 3: Characterization suites unedited.** Both halves, because a directory that does not exist diffs clean:
   ```sh
   cd "$PKG" && test "$(git ls-files Tests/RichTextEditorUIKitTests/Characterization/ | wc -l | tr -d ' ')" -gt 0 \
     || { echo "Characterization path is wrong — STOP"; exit 1; }
   git diff --stat inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/
   ```
   Expect a non-zero file count and an empty diff. A non-empty diff at this stage is a review stop: Stage A links code that nothing selects, so it cannot legitimately change a pinned behavior.

4. - [ ] **Step 4: Full app build.** Re-run the Task A7 Step 1 `Make.py build` command. Expect `BUILD SUCCESSFUL`.

5. - [ ] **Step 5: Install and smoke-test.** Copy the freshly built `.app` onto K3 following the whole-`.app` procedure in the repo `CLAUDE.md`, launch, open a chat, type one character with Debug Settings ▸ "Force Text Field v2" on. Confirm no crash and no visual change. The ID code is linked but unreachable; this proves linking alone changed nothing.

6. - [ ] **Step 6: Tag the gate.** Commit first, then tag — the reverse order tags the *previous* commit.
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git commit --allow-empty -m "chore(inputdec): Stage A gate green — kernel linked, zero behavior change" && \
   git tag inputdec-stage-a-green
   ```

---

## Stage B — the support query and the ID-specific canvas subclass

**Deliverable:** `IDTextEditorBackend.isSupported()` returns a correct answer on device and simulator; the private-callback thunks install onto `IDDocumentCanvasView` and uninstall cleanly; the legacy `DocumentCanvasView` provably never acquires a private selector. Still never selected in production — `TG_RICHTEXT_INPUTDEC_ENABLED` is defined at the end of this stage but no production call site passes anything but `.legacy`.

### Task B1: The canvas performance baseline

Task B2 removes `final` from a 1743-line class with ~44 extensions and is explicitly scoped to "land alone so any performance delta is attributable" — which requires something to attribute it *with*. The seam plan does **not** create a performance suite (its design note proposed three `XCTMetric` baselines; the plan as written does not implement them), so this task builds the minimum needed to make Task B2's numeric gate runnable.

**Files:**
- Create: `Tests/RichTextEditorUIKitTests/InputDec/CanvasSubclassPerformanceTests.swift`
- Test: same file

**Interfaces:**
- Consumes: `makeBackendHarness(backend:engine:facade:paragraphs:width:)` (seam Task 21), `DocumentCanvasView.selectionRects(for:)`, `.insertText(_:)`, `.closestPosition(to:)`, `.documentSizeValue` (`DocumentCanvasView.swift:1084` — the canvas's own length member; `utf16Length` is the *client* protocol's spelling and is not available here).
- Produces: `CanvasSubclassPerformanceTests` with three `measure`-based baselines — `test_perf_selectionRectsWholeDocument`, `test_perf_typing200Characters`, `test_perf_closestPosition200Points`.
- Modifies: `Scripts/matrix.sh` — adds `Tests/RichTextEditorUIKitTests/InputDec` to `ROOTS` (Step 4). This is the **only** matrix edit this plan makes before Task D1, and every suite added by Stages B–E depends on it.

**Steps:**

1. - [ ] **Step 1: Write the suite.** These are the three hot paths a lost devirtualization would show up in (they are also the three the risk analysis named): whole-document `selectionRects` over a 500-block document, a 200-keystroke typing loop, and a hit-test loop. Create `Tests/RichTextEditorUIKitTests/InputDec/CanvasSubclassPerformanceTests.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// The baseline Task B2's `final`-removal is judged against. Deliberately small and
   /// deterministic: three `measure` blocks over the same fixture, no window hosting, no
   /// animation. Absolute numbers are machine-dependent and are NOT asserted — the gate is the
   /// BEFORE/AFTER ratio on one machine in one sitting, recorded in the Task B2 commit message.
   @MainActor
   @available(iOS 16.0, *)
   final class CanvasSubclassPerformanceTests: XCTestCase {

       private func bigHarness() -> RichTextInputBackendHarness {
           makeBackendHarness(paragraphs: (0..<500).map { "Paragraph number \($0) with some text" },
                              width: 320)
       }

       func test_perf_selectionRectsWholeDocument() {
           let h = bigHarness()
           defer { h.tearDown() }
           h.select(0, h.canvas.documentSizeValue)
           let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                          to: h.canvas.endOfDocument)!
           measure { _ = h.canvas.selectionRects(for: whole) }
       }

       func test_perf_typing200Characters() {
           let h = makeBackendHarness(paragraphs: ["Alpha"], width: 320)
           defer { h.tearDown() }
           h.caret(5)
           measure { for _ in 0..<200 { h.canvas.insertText("a") } }
       }

       func test_perf_closestPosition200Points() {
           let h = bigHarness()
           defer { h.tearDown() }
           let points = (0..<200).map { CGPoint(x: 40, y: CGFloat($0) * 7) }
           measure { for p in points { _ = h.canvas.closestPosition(to: p) } }
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and record the numbers.** Three tests, each printing an average. **`Scripts/iostest.sh` CANNOT SHOW YOU AN AVERAGE.** Its output filter passes only seven alternatives and `Test Case '…' measured [Time, seconds] average: …` matches none of them (verified mechanically 2026-08-21 by piping a real measure line through the exact filter: 0 lines out). Piping it to `tail` prints test-case and summary lines and no numbers at all — a step that reads as "the averages were stable" having measured nothing. Use the raw runner for this suite:
  ```sh
  DEVICE="${DEVICE:-CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9}"
  cd "$PKG" && xcodebuild test -scheme RichTextEditor-Package \
    -destination "platform=iOS Simulator,id=$DEVICE" -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -only-testing:RichTextEditorUIKitTests/CanvasSubclassPerformanceTests 2>&1 \
    | grep -E "measured \[|Executed [0-9]+ test|error:"
  ```
  (Found by Task 36c's fix round in the sibling seam plan, re-sweeping the same defect class by behaviour rather than by spelling. Same class, different plan — revert if this task's owner prefers to fix it themselves.)

    (`documentSizeValue` and `insertText(_:)` are both real `DocumentCanvasView` members — `DocumentCanvasView.swift:1084` and the `+UITextInput` extension — so no spelling hedge is needed. Note `utf16Length` is **not** a canvas member: it belongs to `RichTextInputDocumentClient`, whose seam adapter implements it as `canvas.documentSizeValue`.)

3. - [ ] **Step 3: Run it twice more and confirm stability.** Repeat Step 2 two more times, serialized, on K1. Record all three runs. **If the spread between runs exceeds 10%, this baseline cannot support a 15% gate** — say so explicitly in the commit message and downgrade Task B2's gate to the qualitative check named there. A noisy baseline used as a numeric gate is worse than no gate.

4. - [ ] **Step 4: Teach the matrix script about the `InputDec` test directory.** `Scripts/matrix.sh` has **no hand-maintained `SUITES` list** — seam Task 9 Step 6 made it filesystem-derived (`SUITES="${SUITES:-$(discover)}"`, where `discover()` greps `^final class [A-Za-z0-9_]+: XCTestCase` under the directories named in `ROOTS`). There is therefore nothing to append to, and nothing to append: `final class CanvasSubclassPerformanceTests: XCTestCase` is picked up automatically **once its directory is a discovery root**, which it is not yet. Make the one-line `ROOTS` edit that every suite this plan adds depends on:
   ```sh
   # in PKG/Scripts/matrix.sh, the ROOTS assignment gains a fourth line:
   ROOTS="Tests/RichTextEditorUIKitTests/Characterization
   Tests/RichTextEditorUIKitTests/InputBackend
   Tests/RichTextEditorUIKitTests/Support
   Tests/RichTextEditorUIKitTests/InputDec"
   ```
   Verify with `cd "$PKG" && Scripts/matrix.sh 2>&1 | head -1` — the printed `=== matrix over <N> suites` must be exactly one larger than the count recorded in the prerequisite gate item 9, and the run log must contain `RichTextEditorUIKitTests/CanvasSubclassPerformanceTests`. If it does not, the class declaration is not `final class …: XCTestCase` at column 0. Do **not** replace `discover()` with a literal list.

5. - [ ] **Step 5: Commit, with the three runs in the message.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/CanvasSubclassPerformanceTests.swift \
           submodules/TelegramUI/Components/RichTextEditor/Scripts/matrix.sh && \
   git commit -m "test(inputdec): canvas performance baseline for the final-removal gate"
   ```

### Task B2: Remove `final` from `DocumentCanvasView`

This is the one unavoidable concession the spec's "different concrete canvas classes" rule forces. It costs devirtualization across a 1743-line class with ~44 extensions, so it lands **alone**, with a full suite pass, so any performance or behavior delta is attributable to it.

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/CanvasSubclassPerformanceTests.swift` (Task B1) plus the full existing UIKit suite

**Interfaces:**
- Consumes: `CanvasSubclassPerformanceTests` from Task B1.
- Produces: `class DocumentCanvasView: UIView` (was `final class`).

**Steps:**

1. - [ ] **Step 1: Re-record the baseline immediately before the edit.** Use the raw-runner command from Task B1 Step 2 (NOT `Scripts/iostest.sh`, which filters every `measured …` line away). Use *this* run, not Task B1's, as the "before" — a same-sitting pair is the only comparison the machine noise permits. Write the three averages down.

2. - [ ] **Step 2: Make the edit.** In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift`, find the declaration by text (it is line 58 at `inputdec-baseline`; do not trust the number):
   ```swift
   final class DocumentCanvasView: UIView {
   ```
   and replace it with
   ```swift
   /// NOT `final`: `IDDocumentCanvasView` (InputBackend/InputDec) subclasses it so the InputDec
   /// backend's private UIKit callbacks can be installed onto a distinct concrete class, leaving
   /// this one free of them (spec: "the legacy class must not acquire them"). Members are marked
   /// `final` individually wherever the compiler allows, to keep the devirtualization loss small.
   class DocumentCanvasView: UIView {
   ```

3. - [ ] **Step 3: Mark members final where possible.** Add `final` to every `func`/`var` declared **in the class body** (not in extensions — extension members are already statically dispatched unless `@objc`). Do not touch the five `@objc` members in `DocumentCanvasView+NativeTextCheckingClient.swift`; they must remain dynamically dispatched.

4. - [ ] **Step 4: Run the full suite and see it pass.** `cd "$PKG" && Scripts/iostest.sh 2>&1 | tail -5` — identical counts to the Stage A gate.

5. - [ ] **Step 5: Re-run the performance suite and apply the gate.** Same raw-runner command as Step 1 (again: `Scripts/iostest.sh` cannot show an average), in the same sitting as Step 1. **A >15% regression on any of the three is a stop** — report it and consider narrowing the subclass strategy (decision 3 accepted the `final` removal, but it is explicitly gated on this measurement). If Task B1 Step 3 found the baseline too noisy for a numeric gate, substitute the stated qualitative check instead: no measured average may move by more than the run-to-run spread recorded in B1, and the full suite must be green. Put both the before and after numbers in the commit message either way.

6. - [ ] **Step 6: Confirm no pinned behavior changed.** `cd "$PKG" && git diff --stat inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/` — empty, and the characterization suites are green inside the Step 4 full-suite run.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift && \
   git commit -m "refactor(canvas): drop final from DocumentCanvasView for the InputDec subclass"
   ```

### Task B3: `IDDocumentCanvasView` and the canvas factory

**Files:**
- Create: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDDocumentCanvasView.swift`
- Create: `Sources/RichTextEditorUIKit/InputBackend/RichTextInputCanvasFactory.swift`
- Modify: `Sources/RichTextEditorUIKit/RichTextEditorView.swift` (line 10, `let canvas = DocumentCanvasView()`)
- Modify: `Tests/RichTextEditorCoreTests/SourceBoundary/InputBackendSourceBoundaryTests.swift` (uncomment the anti-vacuity test from Task A4 Step 3)
- Test: `Tests/RichTextEditorUIKitTests/InputDec/CanvasFactoryTests.swift`

**Interfaces:**
- Consumes: `DocumentCanvasView`.
- Produces:
  ```swift
  enum RichTextInputBackendPreference { case legacy, inputDecIfSupported, inputDecRequired }
  enum RichTextInputCanvasFactory { static func make(_ preference: RichTextInputBackendPreference) -> DocumentCanvasView }
  @available(iOS 17.0, *) final class IDDocumentCanvasView: DocumentCanvasView {}
  @available(iOS 17.0, *) final class IDTextEditorBackend: RichTextInputBackend { static func isSupported() -> Bool }
  ```
  The conformance on `IDTextEditorBackend` is declared **here**, not in Task C0: `IDDocumentCanvasView(inputBackend:)` takes `(any RichTextInputBackend)?`, so the factory cannot compile against a non-conforming stub. Task C0 fills the bodies in.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/CanvasFactoryTests.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   final class CanvasFactoryTests: XCTestCase {
       func test_legacyPreference_makesTheLegacyClassExactly() {
           let canvas = RichTextInputCanvasFactory.make(.legacy)
           XCTAssertTrue(type(of: canvas) == DocumentCanvasView.self,
                         "the legacy preference must never produce a subclass")
       }

       /// Stage B: TG_RICHTEXT_INPUTDEC_ENABLED is not yet defined, so isSupported() is false and
       /// the factory silently falls back. The flag is turned on in Task B6; this test is written
       /// to be correct in BOTH states so it never needs rewriting.
       func test_inputDecIfSupported_fallsBackWhenUnsupported() {
           let canvas = RichTextInputCanvasFactory.make(.inputDecIfSupported)
           if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
               XCTAssertTrue(canvas is IDDocumentCanvasView)
           } else {
               XCTAssertTrue(type(of: canvas) == DocumentCanvasView.self)
           }
       }

       func test_defaultEditorViewStillUsesTheLegacyCanvas() {
           let editor = RichTextEditorView()
           XCTAssertTrue(type(of: editor.canvas) == DocumentCanvasView.self,
                         "the default facade path must be unchanged by the factory")
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `Scripts/iostest.sh RichTextEditorUIKitTests/CanvasFactoryTests`. Expected failure: `cannot find 'RichTextInputCanvasFactory' in scope`.

3. - [ ] **Step 3: Write the subclass.** Create `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDDocumentCanvasView.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit

   /// Deliberately empty.
   ///
   /// Its ONLY purpose is to be a distinct concrete class that
   /// `TGRichTextInputDecInstallCanvasCallbacks` may `class_addMethod` onto, so that the legacy
   /// `DocumentCanvasView` never acquires a private UIKit selector. `class_addMethod` adds to the
   /// class it is given and never to a superclass, so this subclass is the whole isolation
   /// mechanism (spec: "The ID-specific subclass may contain private callbacks; the legacy class
   /// must not acquire them").
   ///
   /// It is Swift, not Objective-C: ObjC source in a separate SwiftPM/Bazel module cannot see
   /// `DocumentCanvasView` (no generated `-Swift.h` crosses a target boundary) and
   /// `DocumentCanvasView` is internal to `RichTextEditorUIKit`.
   @available(iOS 17.0, *)
   final class IDDocumentCanvasView: DocumentCanvasView {
   }
   #endif
   ```

4. - [ ] **Step 4: Write the factory.** Create `Sources/RichTextEditorUIKit/InputBackend/RichTextInputCanvasFactory.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit

   /// Which input backend a canvas should be built for. This is a *preference*, not a backend type:
   /// no backend type is ever named in `RichTextEditorView`'s API (spec: "No backend type becomes
   /// part of `RichTextEditorView`'s public API").
   enum RichTextInputBackendPreference {
       case legacy
       /// Use the InputDec backend when the runtime supports it; fall back to legacy otherwise.
       case inputDecIfSupported
       /// Debug/comparison only: fail loudly instead of falling back.
       case inputDecRequired
   }

   enum RichTextInputCanvasFactory {
       /// The one place backend selection policy lives. `RichTextInputBackend` itself never
       /// chooses or falls back (spec: "Unsupported runtime policy is owned by the canvas factory
       /// or its caller").
       /// The canvas class AND the backend are chosen together, and the backend is INJECTED
       /// through the seam plan's `init(mapper:inputBackend:)`. Constructing
       /// `IDDocumentCanvasView()` bare would silently attach `LegacyRichTextInputBackend()` — the
       /// initializer's `inputBackend ?? LegacyRichTextInputBackend()` default (deviation D30) —
       /// producing an ID-shaped canvas driven by the legacy backend, which type-checks, runs, and
       /// makes every `.inputDec` test pass while testing the wrong thing.
       static func make(_ preference: RichTextInputBackendPreference) -> DocumentCanvasView {
           switch preference {
           case .legacy:
               return DocumentCanvasView()
           case .inputDecIfSupported:
               if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
                   return IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
               }
               return DocumentCanvasView()
           case .inputDecRequired:
               if #available(iOS 17.0, *), IDTextEditorBackend.isSupported() {
                   return IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
               }
               preconditionFailure(
                   "inputDecRequired: IDTextEditorBackend.isSupported() == false on this runtime")
           }
       }
   }
   #endif
   ```
   This is also where deviation D30 is discharged: the seam plan deferred `RichTextInputCanvasFactory` to "stage 2 (its Task B2)" — now **Task B3** after this plan's renumbering — and the defaulted `inputBackend` parameter stops being the selection point the moment this factory exists.

5. - [ ] **Step 5: Add the backend skeleton — conforming from the start — so the factory compiles.** The factory's two ID arms call `IDDocumentCanvasView(inputBackend: IDTextEditorBackend())`, and the seam's initializer parameter is typed `(any RichTextInputBackend)?` (seam Task 20). A bare `final class IDTextEditorBackend` with only `isSupported()` therefore **does not compile at this task**. Declare the conformance now, with every requirement stubbed to its documented "absent" value; Task C0 replaces the bodies, not the signatures. Create `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackend.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit
   import RichTextInputDecObjC

   /// The InputDec input backend. Availability is drawn ONCE here, in Swift: nothing in the
   /// Objective-C module is annotated `API_AVAILABLE`, so the whole module compiles at the iOS 13
   /// floor and only this type raises the bar.
   ///
   /// EVERY member below except `isSupported()` is a Task-C0 placeholder that fails LOUDLY rather
   /// than plausibly. This is deliberate: a conformance stubbed to plausible values (a caret at 0,
   /// a silent no-op `attach`) type-checks, runs, and makes an `.inputDec` test pass while testing
   /// nothing — the exact failure the CoreList backend hit with its `0.0`/`false` stubs.
   @available(iOS 17.0, *)
   final class IDTextEditorBackend: RichTextInputBackend {
       /// Pure and side-effect-free: constructs no object, installs no method, sends no private
       /// selector. Safe to call from the canvas factory before any canvas exists.
       static func isSupported() -> Bool {
           #if !TG_RICHTEXT_INPUTDEC_ENABLED
           return false
           #else
           guard let manifest = TGRichTextInputDecContractManifest() else { return false }
           return Self.runtimeMatches(manifest) && Self.mandatoryContractsAccepted(manifest)
           #endif
       }

       private static func runtimeMatches(_ manifest: IDUIKitRuntimeManifest) -> Bool { false }
       private static func mandatoryContractsAccepted(_ m: IDUIKitRuntimeManifest) -> Bool { false }

       init() {}

       private(set) var state = RichTextInputStateSnapshot(
           documentRevision: 0,
           selection: .caret(at: .downstream(0)),
           markedRange: nil,
           isComposing: false)
       private(set) var isAttached = false

       func attach(to host: any RichTextInputHost) throws {
           // Not "no-op" — THROW. Until Task C0 there is no bridge, no kernel and no thunks, so a
           // successful attach would be a lie the factory cannot detect.
           throw RichTextInputBackendAttachmentError.missingCapability(
               "IDTextEditorBackend has no implementation until Task C0")
       }
       func detach() {}
       func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {}
       func setSelection(_ selection: RichTextCanonicalSelection,
                         reason: RichTextSelectionChangeReason) {}
   }
   #endif
   ```
   **Consequence for Step 9:** `.inputDecIfSupported` still resolves to the legacy canvas throughout Stage B (`TG_RICHTEXT_INPUTDEC_ENABLED` is undefined until Task B6, so `isSupported()` is `false`), so the throwing `attach` is never reached by `CanvasFactoryTests`. If it ever is, the throw is the right outcome.

6. - [ ] **Step 6: Point the facade at the factory.** In `Sources/RichTextEditorUIKit/RichTextEditorView.swift`, change line 10 from `let canvas = DocumentCanvasView()` to `let canvas: DocumentCanvasView`, and add `self.canvas = RichTextInputCanvasFactory.make(.legacy)` as the first statement of `public override init(frame: CGRect)` (before `super.init(frame: frame)`).

7. - [ ] **Step 7: Uncomment the anti-vacuity boundary test.** Both InputDec exempt paths now have a file (`InputBackend/InputDec/IDDocumentCanvasView.swift` + `IDTextEditorBackend.swift`, and `InputBackend/RichTextInputCanvasFactory.swift`), so uncomment `test_everyInputDecExemptPathMatchesALiveFile` in `InputBackendSourceBoundaryTests.swift` — written and deliberately disabled in Task A4 Step 3 — and delete the `// UNCOMMENT IN TASK B3` marker.

8. - [ ] **Step 8: Run the boundary suite.** `cd "$PKG" && swift test --filter SourceBoundary` — green, including the newly live anti-vacuity test. This is the first run in which R1's ID-name rule and R2's implementation-type rule are actually being suppressed for real files; if either now fails, the exempt-path strings are wrong.

9. - [ ] **Step 9: Run the factory test and see it pass.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/CanvasFactoryTests` — 3 tests passing.

10. - [ ] **Step 10: Run the full suite.** `cd "$PKG" && Scripts/iostest.sh 2>&1 | tail -5` — counts unchanged plus the 3 new tests.

11. - [ ] **Step 11: Commit.**
    ```sh
    cd /Users/isaac/build/telegram/telegram-ios && \
    git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend \
            submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/RichTextEditorView.swift \
            submodules/TelegramUI/Components/RichTextEditor/Tests && \
    git commit -m "feat(inputdec): canvas factory and the ID-specific canvas subclass"
    ```

### Task B4: The ABI witness class and the manifest renames

The capability resolver runs **before** installation, so it cannot inspect `IDDocumentCanvasView` — a Swift class with no private methods yet. `TGRichTextInputDecCanvasABIWitness` exists so the three canvas manifest rows have a compile-time class to validate against, and the installer then installs *the very IMPs the resolver validated*.

**Files:**
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecCanvasABIWitness.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecCanvasABIWitness.m`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/CanvasABIWitnessTests.swift`

**Interfaces:**
- Consumes: `TGRichTextInputDecContractManifest()`, `IDUIKitCapabilityResolver.systemResolver()`, `IDUIKitContractResult.isAccepted`.
- Produces: `@interface TGRichTextInputDecCanvasABIWitness : UIView` implementing `keyboardInputShouldDelete:`, `startAutoscroll:`, `cancelAutoscroll`.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/CanvasABIWitnessTests.swift`:
   ```swift
   #if canImport(UIKit)
   import ObjectiveC
   import RichTextInputDecObjC
   import UIKit
   import XCTest

   final class CanvasABIWitnessTests: XCTestCase {
       func test_witnessClassResolvesUnderTheRenamedManifestName() {
           XCTAssertNotNil(NSClassFromString("TGRichTextInputDecCanvasABIWitness"))
       }

       func test_witnessImplementsTheThreeCanvasRowsDirectly() {
           let cls: AnyClass = TGRichTextInputDecCanvasABIWitness.self
           var count: UInt32 = 0
           let methods = class_copyMethodList(cls, &count)
           defer { free(methods) }
           let names = (0..<Int(count)).map { String(cString: sel_getName(method_getName(methods![$0]))) }
           for selector in ["keyboardInputShouldDelete:", "startAutoscroll:", "cancelAutoscroll"] {
               XCTAssertTrue(names.contains(selector),
                             "\(selector) must be implemented on the witness itself, not inherited")
           }
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CanvasABIWitnessTests`. Expected failure: `cannot find type 'TGRichTextInputDecCanvasABIWitness' in scope`.

3. - [ ] **Step 3: Write the header.** Create `Sources/RichTextInputDecObjC/include/TGRichTextInputDecCanvasABIWitness.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <UIKit/UIKit.h>

   NS_ASSUME_NONNULL_BEGIN

   /// A compile-time ABI witness for the three canvas-hosted manifest rows
   /// (`inputController.keyboardDeletePreflight`, `autoscrollEntry.start`, `autoscrollEntry.cancel`).
   ///
   /// The capability resolver validates a contract by looking the row's className up with
   /// NSClassFromString and comparing runtime type encodings — and it runs BEFORE any method is
   /// installed on the real canvas. So the manifest names this class, and
   /// `TGRichTextInputDecInstallCanvasCallbacks` installs
   /// `class_getMethodImplementation(TGRichTextInputDecCanvasABIWitness.class, sel)` for exactly
   /// these three selectors — i.e. the IMPs the resolver validated are the IMPs that run.
   ///
   /// Never instantiated.
   @interface TGRichTextInputDecCanvasABIWitness : UIView
   @end

   NS_ASSUME_NONNULL_END

   #endif
   ```

4. - [ ] **Step 4: Write the implementation.** Create `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecCanvasABIWitness.m`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import "TGRichTextInputDecCanvasABIWitness.h"
   #import "TGRichTextInputDecCanvasCallbacks.h"

   @implementation TGRichTextInputDecCanvasABIWitness

   - (BOOL)keyboardInputShouldDelete:(id)textInput {
       id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
       if (bridge == nil) { return YES; }
       return [bridge canvasKeyboardInputShouldDelete];
   }

   - (BOOL)startAutoscroll:(CGPoint)point {
       // The `autoscrollEntry` capability is never requested (Telegram's canvas is a UIView inside
       // a separate scroll view, not the scroll view itself), so this exists only to give the
       // manifest row a real ABI to validate. Returning NO tells UIKit autoscroll did not start.
       return NO;
   }

   - (void)cancelAutoscroll {
   }

   @end

   #endif
   ```

5. - [ ] **Step 5: Close the manifest↔class loop.** `ContractManifestTests.test_theThreeCanvasRowsNameTheABIWitness` (Task A6) already proved the *manifest* names `TGRichTextInputDecCanvasABIWitness`; `test_witnessClassResolvesUnderTheRenamedManifestName` (Step 1 here) proves the *class* answers to that name. Both halves are needed: `IDUIKitCapabilityResolver` fails the capability if either is missing. **Do not** try to `grep` the generated `.m` for the name — the payload is a hex byte array and the grep is vacuous. If a rename is genuinely missing, fix `RENAMES` in `InputDec/Scripts/generate-contract-data.py`, re-run `Scripts/test-generate-contract-data.py`, and re-export; never hand-edit the generated file (`VendorSnapshotIntegrityTests` fails on a hand-edit).

6. - [ ] **Step 6: Add the header to the aggregate.** Add `#import "TGRichTextInputDecCanvasABIWitness.h"` inside the `#if TARGET_OS_IOS` block of `include/TGRichTextInputDec.h`.

7. - [ ] **Step 7: Run and see it pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CanvasABIWitnessTests` — 2 tests passing. Then re-run `ContractManifestTests` on the same device: 7 passing, and the rename claim is now closed end to end.

8. - [ ] **Step 8: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/CanvasABIWitnessTests.swift && \
   git commit -m "feat(inputdec): ABI witness class for the three canvas manifest rows"
   ```

### Task B5: The private-callback thunks — install, validate, uninstall

**Files:**
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecClientBridge.h`
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecCanvasCallbacks.h`
- Create: `Sources/RichTextInputDecObjC/Private/TGRichTextInputDecCanvasCallbacks.m`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/CanvasCallbackInstallationTests.swift`

**Interfaces:**
- Produces:
  ```objc
  FOUNDATION_EXPORT BOOL TGRichTextInputDecInstallCanvasCallbacks(Class canvasClass, Class forbiddenBaseClass, NSError **error);
  FOUNDATION_EXPORT void TGRichTextInputDecSetAttachedBridge(UIView *canvas, id<TGRichTextInputDecClientBridging> _Nullable bridge);
  FOUNDATION_EXPORT id<TGRichTextInputDecClientBridging> _Nullable TGRichTextInputDecAttachedBridge(id canvas);
  ```

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/CanvasCallbackInstallationTests.swift`:
   ```swift
   #if canImport(UIKit)
   import ObjectiveC
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// The proof that the legacy class can never acquire a private UIKit selector.
   ///
   /// This file names all 22 private selectors in plaintext, deliberately. Global Constraint 3
   /// scopes the "no private selector name in Swift" rule to `Sources/`, and the enforcing rule
   /// (R1b, `test_privateRuntimeLookups_areConfinedToTheInventoriedFiles`) scans
   /// `RepoLayout.uiKitSources` only — the test target is never shipped, and a negative assertion
   /// about a selector cannot be written without naming it.
   @available(iOS 17.0, *)
   final class CanvasCallbackInstallationTests: XCTestCase {

       private static let installedSelectors = [
           "textStorage", "textInputView", "textContainerOrigin", "textLayoutController",
           "_inputController", "_textInputTraits", "textInputTraits",
           "_implicitPasteConfigurationClasses",
           "_attributedStringForInsertionOfAttributedString:",
           "setContinuousSpellCheckingEnabled:", "isContinuousSpellCheckingEnabled",
           "textInput:shouldChangeCharactersInRanges:replacementText:",
           "keyboardInput:shouldReplaceTextInRange:replacementText:",
           "textInputDidChange:", "textInputDidChangeSelection:", "keyboardInputChangedSelection:",
           "keyboardInput:shouldInsertText:isMarkedText:", "keyboardInputShouldDelete:",
           "_deleteBackwardAndNotify:", "interactionAssistant",
           "_textInputViewForAddingGestureRecognizers", "selectionContainerView",
       ]

       func test_installRejectsTheForbiddenBaseClassItself() {
           var error: NSError?
           let ok = TGRichTextInputDecInstallCanvasCallbacks(
               DocumentCanvasView.self, DocumentCanvasView.self, &error)
           XCTAssertFalse(ok)
           XCTAssertNotNil(error)
       }

       func test_installRejectsANonDirectSubclass() {
           var error: NSError?
           let ok = TGRichTextInputDecInstallCanvasCallbacks(
               UIView.self, DocumentCanvasView.self, &error)
           XCTAssertFalse(ok)
           XCTAssertNotNil(error)
       }

       func test_installSucceedsOnTheIDSubclass_andIsIdempotent() {
           var error: NSError?
           XCTAssertTrue(TGRichTextInputDecInstallCanvasCallbacks(
               IDDocumentCanvasView.self, DocumentCanvasView.self, &error), "\(error as Any)")
           XCTAssertTrue(TGRichTextInputDecInstallCanvasCallbacks(
               IDDocumentCanvasView.self, DocumentCanvasView.self, &error), "\(error as Any)")
       }

       /// The load-bearing assertion of the whole isolation argument.
       func test_theLegacyClassNeverGainsAnInstalledSelector() {
           var error: NSError?
           _ = TGRichTextInputDecInstallCanvasCallbacks(
               IDDocumentCanvasView.self, DocumentCanvasView.self, &error)
           var count: UInt32 = 0
           let methods = class_copyMethodList(DocumentCanvasView.self, &count)
           defer { free(methods) }
           let names = Set((0..<Int(count)).map {
               String(cString: sel_getName(method_getName(methods![$0])))
           })
           for selector in Self.installedSelectors {
               XCTAssertFalse(names.contains(selector),
                              "DocumentCanvasView acquired the private selector \(selector)")
           }
           let legacy = DocumentCanvasView()
           for selector in Self.installedSelectors {
               XCTAssertFalse(legacy.responds(to: Selector(selector)),
                              "a legacy canvas answers \(selector)")
           }
       }

       /// A thunk that reaches a canvas with no attached backend must be inert.
       func test_thunksAreInertWithoutAnAttachedBridge() {
           var error: NSError?
           _ = TGRichTextInputDecInstallCanvasCallbacks(
               IDDocumentCanvasView.self, DocumentCanvasView.self, &error)
           let canvas = IDDocumentCanvasView()
           TGRichTextInputDecSetAttachedBridge(canvas, nil)
           XCTAssertNil(canvas.perform(Selector(("textStorage")))?.takeUnretainedValue())
           XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
       }

       func test_setAttachedBridgeRoundTripsAndClears() {
           let canvas = IDDocumentCanvasView()
           let bridge = StubBridge()
           TGRichTextInputDecSetAttachedBridge(canvas, bridge)
           XCTAssertTrue(TGRichTextInputDecAttachedBridge(canvas) === bridge)
           TGRichTextInputDecSetAttachedBridge(canvas, nil)
           XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
       }
   }

   /// Minimal conformer used only to prove the associated-object channel. It implements exactly
   /// the protocol's two @required methods and is NEVER extended by Tasks C4-C7 — that is why
   /// every group they add is declared `@optional` (see the protocol's own comment).
   final class StubBridge: NSObject, TGRichTextInputDecClientBridging {
       func textStorageFacade() -> NSTextStorage { NSTextStorage() }
       func canvasKeyboardInputShouldDelete() -> Bool { true }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CanvasCallbackInstallationTests`. Expected failure: `cannot find 'TGRichTextInputDecInstallCanvasCallbacks' in scope`.

3. - [ ] **Step 3: Declare the bridge protocol's first two members.** Create `Sources/RichTextInputDecObjC/include/TGRichTextInputDecClientBridge.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <UIKit/UIKit.h>

   NS_ASSUME_NONNULL_BEGIN

   /// The backend-private Objective-C ↔ Swift seam. This is NOT one of the six shared client
   /// protocols: it is deliberately ObjC-shaped (primitives, NSRange, out-params, NS_ENUMs) so
   /// that Swift-only concepts — `AnyHashable` line ids, the mutation enum's associated values,
   /// the prepared-mutation UUID token, the presentation-invalidation OptionSet — never cross it.
   /// It grows one method group per Stage-C family.
   ///
   /// EVERY GROUP ADDED AFTER THIS ONE IS `@optional`. Objective-C protocol methods are `@required`
   /// by default, and `StubBridge` in `CanvasCallbackInstallationTests` conforms to this protocol
   /// with exactly the two methods below. Tasks C4 (six document methods), C5 (three geometry),
   /// C6 (four delegate) and C7 (one mutation) each add a group; declaring any of them `@required`
   /// would break that suite's compile — and therefore the whole UIKit test target — four separate
   /// times, in four tasks that never mention it. The real conformer,
   /// `IDTextEditorBackendClientBridge`, implements every method regardless; `@optional` costs it
   /// nothing and costs the ObjC caller only a `respondsToSelector:` it already needs for the
   /// nil-bridge case.
   @protocol TGRichTextInputDecClientBridging <NSObject>

   /// The NSTextStorage the private input controller mutates through. Never Telegram's model.
   - (NSTextStorage *)textStorageFacade;

   /// The canvas-side `keyboardInputShouldDelete:` preflight.
   - (BOOL)canvasKeyboardInputShouldDelete;

   // Tasks C4-C7 append their groups below this line, each opening with `@optional`.

   @end

   NS_ASSUME_NONNULL_END

   #endif
   ```

4. - [ ] **Step 4: Declare the installer.** Create `Sources/RichTextInputDecObjC/include/TGRichTextInputDecCanvasCallbacks.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <UIKit/UIKit.h>
   #import "TGRichTextInputDecClientBridge.h"

   NS_ASSUME_NONNULL_BEGIN

   FOUNDATION_EXPORT NSErrorDomain const TGRichTextInputDecCanvasCallbacksErrorDomain;

   /// Installs the private canvas callbacks onto `canvasClass` as free IMPs.
   ///
   /// `canvasClass` MUST be a DIRECT subclass of `forbiddenBaseClass` and MUST NOT be
   /// `forbiddenBaseClass` itself; both are checked and the call fails with an error otherwise.
   /// `class_addMethod` touches only the class it is given, so the base class can never acquire
   /// these selectors. Idempotent per class.
   ///
   /// A category is deliberately NOT used: a category is unconditional and class-global, and there
   /// is no way to give a class private methods "only for one backend".
   FOUNDATION_EXPORT BOOL TGRichTextInputDecInstallCanvasCallbacks(
       Class canvasClass, Class forbiddenBaseClass, NSError **error);

   /// The associated-object channel every installed thunk validates before doing anything.
   /// Set at attach, cleared at detach; with no bridge every thunk returns a safe default.
   FOUNDATION_EXPORT void TGRichTextInputDecSetAttachedBridge(
       UIView *canvas, id<TGRichTextInputDecClientBridging> _Nullable bridge);

   FOUNDATION_EXPORT id<TGRichTextInputDecClientBridging> _Nullable
       TGRichTextInputDecAttachedBridge(id canvas);

   NS_ASSUME_NONNULL_END

   #endif
   ```

5. - [ ] **Step 5: Implement the installer and the first thunks.** Create `Sources/RichTextInputDecObjC/Private/TGRichTextInputDecCanvasCallbacks.m`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <objc/runtime.h>

   #import "TGRichTextInputDecCanvasABIWitness.h"
   #import "TGRichTextInputDecCanvasCallbacks.h"

   NSErrorDomain const TGRichTextInputDecCanvasCallbacksErrorDomain =
       @"TGRichTextInputDecCanvasCallbacksErrorDomain";

   static const void *TGRichTextInputDecAttachedBridgeKey = &TGRichTextInputDecAttachedBridgeKey;

   void TGRichTextInputDecSetAttachedBridge(
       UIView *canvas, id<TGRichTextInputDecClientBridging> bridge) {
       objc_setAssociatedObject(canvas, TGRichTextInputDecAttachedBridgeKey, bridge,
                                OBJC_ASSOCIATION_ASSIGN);   // the backend owns the bridge strongly
   }

   id<TGRichTextInputDecClientBridging> TGRichTextInputDecAttachedBridge(id canvas) {
       return objc_getAssociatedObject(canvas, TGRichTextInputDecAttachedBridgeKey);
   }

   static NSError *TGError(NSString *reason) {
       return [NSError errorWithDomain:TGRichTextInputDecCanvasCallbacksErrorDomain
                                  code:1
                              userInfo:@{NSLocalizedDescriptionKey: reason}];
   }

   static id TGThunk_textStorage(id self, SEL _cmd) {
       id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
       if (bridge == nil) { return nil; }
       return [bridge textStorageFacade];
   }

   static id TGThunk_textInputView(id self, SEL _cmd) {
       return TGRichTextInputDecAttachedBridge(self) == nil ? nil : self;
   }

   BOOL TGRichTextInputDecInstallCanvasCallbacks(
       Class canvasClass, Class forbiddenBaseClass, NSError **error) {
       if (canvasClass == Nil || forbiddenBaseClass == Nil) {
           if (error != NULL) { *error = TGError(@"nil class"); }
           return NO;
       }
       if (canvasClass == forbiddenBaseClass) {
           if (error != NULL) {
               *error = TGError(@"refusing to install private callbacks onto the legacy canvas class");
           }
           return NO;
       }
       if (class_getSuperclass(canvasClass) != forbiddenBaseClass) {
           if (error != NULL) {
               *error = TGError(@"the canvas class must be a DIRECT subclass of the legacy class");
           }
           return NO;
       }
       // class_addMethod returns NO when the selector already exists on this class, which makes
       // the whole function naturally idempotent.
       class_addMethod(canvasClass, @selector(textStorage), (IMP)TGThunk_textStorage, "@@:");
       class_addMethod(canvasClass, NSSelectorFromString(@"textInputView"),
                       (IMP)TGThunk_textInputView, "@@:");
       // The three ABI-witnessed rows install the very IMPs the resolver validated.
       for (NSString *name in @[@"keyboardInputShouldDelete:", @"startAutoscroll:", @"cancelAutoscroll"]) {
           SEL selector = NSSelectorFromString(name);
           Method method = class_getInstanceMethod(TGRichTextInputDecCanvasABIWitness.class, selector);
           if (method == NULL) {
               if (error != NULL) { *error = TGError([@"witness lacks " stringByAppendingString:name]); }
               return NO;
           }
           class_addMethod(canvasClass, selector, method_getImplementation(method),
                           method_getTypeEncoding(method));
       }
       return YES;
   }

   #endif
   ```
   The remaining ~18 thunks are added in Stage C, each in the family that needs it.

6. - [ ] **Step 6: Add both headers to the aggregate.** Add `#import "TGRichTextInputDecClientBridge.h"` and `#import "TGRichTextInputDecCanvasCallbacks.h"` to `include/TGRichTextInputDec.h`.

7. - [ ] **Step 7: Run the tests and see them pass.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CanvasCallbackInstallationTests` — 6 tests passing. The `installedSelectors` list in the test intentionally names all 22 even though only 5 are installed yet: the negative assertion (legacy never gains them) must be complete from day one.

8. - [ ] **Step 8: Commit.**
   ```sh
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/CanvasCallbackInstallationTests.swift && \
   git commit -m "feat(inputdec): runtime-installed canvas callbacks isolated to the ID subclass"
   ```

### Task B6: `isSupported()`

**Files:**
- Modify: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackend.swift`
- Create: `Tests/RichTextEditorUIKitTests/InputDec/IsSupportedTests.swift`

**Interfaces:**
- Consumes: `IDUIKitCapabilityResolver.systemResolver()`, `IDUIKitRuntimeManifest.capabilities/osVersion/osBuild/forbiddenSymbols`, `IDUIKitContractResult.isAccepted`.
- Produces: `IDTextEditorBackend.isSupported() -> Bool` with the two private helpers.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/IsSupportedTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)   // decision 2: the floor is 17.0, not the manifest's 26.x
   final class IsSupportedTests: XCTestCase {

       /// Purity: calling it must not construct a private object or install a method. Proved by
       /// asserting the legacy class still answers nothing after 100 calls (installation would
       /// leave a trace) and that repeated calls agree.
       func test_isSupportedIsPureAndStable() {
           let first = IDTextEditorBackend.isSupported()
           for _ in 0..<100 { XCTAssertEqual(IDTextEditorBackend.isSupported(), first) }
           XCTAssertFalse(DocumentCanvasView().responds(to: Selector(("_inputController"))))
       }

       /// DECISION 2 (2026-08-17): the floor is iOS 17.0, NOT an exact manifest-build match.
       /// isSupported() may therefore say yes on an OS the manifest never certified — the
       /// contract evaluation below, not the OS band, is what keeps that safe.
       func test_isSupportedRequiresAtLeastIOS17() {
           let running = ProcessInfo.processInfo.operatingSystemVersion
           if running.majorVersion < 17 {
               XCTAssertFalse(IDTextEditorBackend.isSupported(),
                              "the iOS 17.0 floor must be enforced regardless of contract acceptance")
           }
       }

       /// The manifest's runtime block is now provenance, not a gate. Pin that it is still READ
       /// (a manifest that fails to load must make isSupported() false), while asserting it does
       /// NOT constrain the answer to one build.
       func test_theManifestIsRequired_butItsBuildDoesNotGateTheAnswer() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest(),
                                        "a missing manifest must be a hard no, not a silent yes")
           let running = ProcessInfo.processInfo.operatingSystemVersion
           let runningString = "\(running.majorVersion).\(running.minorVersion)"
           if IDTextEditorBackend.isSupported() && runningString != manifest.osVersion {
               // Expected under decision 2. Recorded, not failed — this is the whole point of
               // moving from an exact band to a floor plus live contract evaluation.
               print("isSupported() == true on \(runningString), certified on \(manifest.osVersion)")
           }
       }

       func test_mandatoryContractsAreEvaluated_notAssumed() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           let resolver = IDUIKitCapabilityResolver.systemResolver()
           for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
               let contract = try XCTUnwrap(manifest.capabilities[name])
               let result = resolver.evaluate(contract)
               if IDTextEditorBackend.isSupported() {
                   XCTAssertTrue(result.isAccepted,
                                 "\(name) rejected: \(result.mismatches)")
               }
           }
       }

       func test_forbiddenSymbolsAreAbsentFromTheRuntimeWeUse() throws {
           let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
           for symbol in manifest.forbiddenSymbols where symbol.hasPrefix("_UIText") {
               // The reference backend's classes may exist in UIKit; what must be true is that we
               // never *name* them. This asserts our own module does not resolve them.
               XCTAssertNil(Bundle(for: IDDocumentCanvasView.self).classNamed(symbol))
           }
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IsSupportedTests`. Expected failure: `test_mandatoryContractsAreEvaluated_notAssumed` passes vacuously while `isSupported()` returns false — that is the correct pre-implementation state; the real failure is that `runtimeMatches`/`mandatoryContractsAccepted` are stubs returning `false`, so nothing is exercised. Confirm by temporarily defining `TG_RICHTEXT_INPUTDEC_ENABLED` locally and observing `test_isSupportedAgreesWithTheManifestOSBand` still trivially passing.

3. - [ ] **Step 3: Implement the two helpers.** Replace the stubs in `IDTextEditorBackend.swift`:
   ```swift
       /// DECISION 2 (2026-08-17): the policy is a FLOOR of iOS 17.0, not an exact match against
       /// the manifest's `runtime` block.
       ///
       /// The consequence is deliberate and must not be "fixed" back: the kernel will run on OS
       /// builds it has never been certified against, so the manifest stops being the gate and
       /// becomes provenance. What keeps that safe is `mandatoryContractsAccepted` below — it
       /// evaluates the three mandatory contracts against the LIVE runtime on every call, so an
       /// ABI change on an uncertified OS is rejected there and the factory falls back to legacy.
       /// A matching type encoding still does not prove matching semantics; that residual risk is
       /// accepted, and Stage D's differential run against the pinned corpus is what would catch
       /// it. See "Honest constraints" section 1.
       private static let minimumMajorVersion = 17

       private static func runtimeMatches(_ manifest: IDUIKitRuntimeManifest) -> Bool {
           let running = ProcessInfo.processInfo.operatingSystemVersion
           return running.majorVersion >= minimumMajorVersion
       }

       /// Pure runtime introspection: NSClassFromString, class_getInstanceMethod,
       /// method_copyReturnType. No instance is constructed, no method is installed, and no
       /// private selector is sent.
       private static func mandatoryContractsAccepted(_ manifest: IDUIKitRuntimeManifest) -> Bool {
           let resolver = IDUIKitCapabilityResolver.systemResolver()
           for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
               guard let contract = manifest.capabilities[name],
                     resolver.evaluate(contract).isAccepted else { return false }
           }
           return true
       }
   ```
   (`evaluate(_:)` is the Swift name of `-evaluateContract:`; confirm the generated Swift name with `swift-symbolgraph` or by letting the compiler suggest it, and use whichever the compiler accepts — do not add an `NS_SWIFT_NAME` to the vendored header.)

4. - [ ] **Step 4: Define the enablement flag in both build systems.** In `Package.swift`, add `.define("TG_RICHTEXT_INPUTDEC_ENABLED")` to the `RichTextEditorUIKit` target via `swiftSettings: [.define("TG_RICHTEXT_INPUTDEC_ENABLED")]`. In `BUILD`, add `copts = ["-DTG_RICHTEXT_INPUTDEC_ENABLED"]` to the `swift_library(name = "RichTextEditorUIKit")` — Swift needs `swiftc -D`, so use `copts = ["-DTG_RICHTEXT_INPUTDEC_ENABLED"]` on the `swift_library` and verify with a build.

5. - [ ] **Step 5: Run on K3 and see it pass.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IsSupportedTests` — 5 tests passing (decision 2 replaced one test with two), and `test_theManifestIsRequired_butItsBuildDoesNotGateTheAnswer` non-vacuous.

6. - [ ] **Step 6: Run on K1 and record which way it answers.** `Scripts/iostest.sh RichTextEditorUIKitTests/IsSupportedTests` on the K1 simulator. **Under decision 2 this is no longer a guaranteed negative** — K1 is ≥ 17.0, so the answer is decided entirely by whether the three mandatory contracts still resolve on K1's runtime. Both outcomes are valid; what is required is that you *record* which one you got, because it is the first real measurement of how far the certified ABI actually travels. If K1 says **yes**, note it in `VENDOR.md` — the kernel resolves on an OS it was never certified against, and Stage D's differential run becomes the only thing standing between that and a semantic difference. If K1 says **no**, note which contract was rejected; that is the ABI boundary, and it is more useful documentation than a passing test.

   **The negative path still needs proving.** Since the floor no longer produces a negative on any modern simulator, prove the gate another way: temporarily lower `minimumMajorVersion` to a value above the running OS (e.g. `99`), re-run, and confirm every test passes with `isSupported() == false`. Restore the constant before committing. Without this, nothing in the suite exercises the false branch.

7. - [ ] **Step 7: Verify on a physical device.** Build a device configuration (`--configuration=debug_arm64`), install, and add a temporary log line at app launch printing `IDTextEditorBackend.isSupported()`. Confirm it matches the device's OS build. Remove the log line before committing.

8. - [ ] **Step 8: Commit.**
   ```sh
   git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackend.swift \
           submodules/TelegramUI/Components/RichTextEditor/Package.swift \
           submodules/TelegramUI/Components/RichTextEditor/BUILD \
           submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec/IsSupportedTests.swift && \
   git commit -m "feat(inputdec): isSupported() gates on the manifest OS band and mandatory contracts"
   ```

### Task B7: Stage B exit gate

**Files:** none created; this task only runs and records verification.

**Interfaces:** none.

**Steps:**

1. - [ ] **Step 1: Full suite on K1.** `Scripts/iostest.sh 2>&1 | tail -5` — pre-existing counts plus the new InputDec tests, zero failures.

2. - [ ] **Step 2: Full suite on K3.** `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh 2>&1 | tail -5`. Any test that fails only on K3 is an OS-drift finding, not an InputDec finding — record it and fix it separately. **Do not run this concurrently with Step 1.**

3. - [ ] **Step 3: Characterization suites unedited.** `cd "$PKG" && git diff --stat inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/` — empty, and `git ls-files` on that path is still non-zero.

4. - [ ] **Step 4: Full app build.** `Make.py build --configuration=debug_sim_arm64` — `BUILD SUCCESSFUL`.

5. - [ ] **Step 5: Confirm nothing selects the ID canvas.** `cd /Users/isaac/build/telegram/telegram-ios && grep -rn "inputDecIfSupported\|inputDecRequired" --include="*.swift" submodules/ | grep -v Tests` must return only the factory's own switch.

6. - [ ] **Step 6: Confirm no Swift file calls the kernel directly.** `cd "$PKG" && grep -rn "kernelInput?\.\|kernelInteraction?\.\|IDUIKitBehaviorKernel(" Sources/RichTextEditorUIKit` — expect no output. Nothing routes yet, so this must be empty; the same check becomes `IDBackendCallGuardTests` in Task C0.

7. - [ ] **Step 7: Tag.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git commit --allow-empty -m "chore(inputdec): Stage B gate green — support query and thunks verified" && \
   git tag inputdec-stage-b-green
   ```

---

## Stage C — the adapter, one client family at a time

**Deliverable:** `IDTextEditorBackend` conforms to `RichTextInputBackend` and every one of the six Swift clients is driven through it. The family order is the spec's Phase 4 order (spec lines 1430-1441), deliberately: the seam's tests were written in that order and each family's fixtures already exist.

### The two harnesses, and why there are two

The seam plan left behind two different test surfaces, and Stage C uses both. Confusing them is the single easiest way to write a test that cannot compile:

| Harness | Built by | Clients | Use it to assert |
| --- | --- | --- | --- |
| `makeBackendHarness(backend:engine:facade:paragraphs:width:)` — seam Task 21, **extended** by Task C1 with `case inputDec` | a real `DocumentCanvasView` / `IDDocumentCanvasView` | the six **real** Telegram clients | *canvas-visible* behavior: `h.canvas.text(in:)`, `h.canvas.beginningOfDocument`, `h.canvas.boxes`, `h.undoManager`, selection round-trips |
| `makeIDFakeClientHarness(kind:paragraphs:width:)` — **new** in Task C2, generalised over the backend kind in Task D2 | an `IDDocumentCanvasView` inside a `FakeInputHost` | the seven **fake** clients from seam Task 22, sharing one `RichTextInputEventLog` | *client-boundary* behavior: call counts, argument values, cross-client ordering, `sawDoubleCommit` |

Neither existed with these members before Tasks C1 and C2; every member they add is enumerated in those two tasks and nowhere else.

**Deliberate, test-only deviation: detach-then-reattach.** The spec (line 289) says `attach` happens *exactly once* and `detach` is idempotent and **terminal**. Both harnesses violate the terminal clause on purpose: `DocumentCanvasView.init(inputBackend:)` attaches the injected backend **to the canvas itself**, so a harness that wants the backend attached to a *fake* host has no way to get one that has never been attached — the canvas owns the construction. The harnesses therefore construct the canvas, call `backend.detach()`, then `try! backend.attach(to: host)`. This is confined to `makeIDFakeClientHarness` (Task C2 Step 4) and `makeLegacyFakeClientHarness` (Task D2 Step 1), and `IDBackendSemanticTests.test_markedTextIsNotMigratedAcrossDetachAndReattach` (Task C9) depends on it. **Both backends must therefore tolerate re-attach after detach** — that is a real requirement this plan imposes, recorded as the third entry in `DIVERGENCES.md` (Task C0 Step 6) so it is reviewed rather than discovered. No production path ever re-attaches.

**Stage C rule (restated precisely).** The seam plan's eight contract suites (`BackendMutationContractTests` … `BackendEditPolicyTests`) construct `LegacyRichTextInputBackend` **by name** — they are not backend-parameterised and this plan does not rewrite them. So "the same suite runs against `.inputDec`" is delivered by a **new** parameterised base class, `BackendSemanticContractCases` (Task C3), whose two subclasses differ only in one overridden property. A family is not done until `IDBackendSemanticTests` passes the same inherited test bodies that `LegacyBackendSemanticTests` passes for that family. Where a behavior genuinely cannot match, record it in `Sources/RichTextEditorUIKit/InputBackend/InputDec/DIVERGENCES.md` with the reason — never weaken the shared case.

### Task C0: The bridge object and the backend skeleton

**Files:**
- Modify: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackend.swift`
- Modify: `Tests/RichTextEditorUIKitTests/InputBackend/Fakes/FakeInputLifecycleClient.swift` (Step 1 — one additive `publishedStates` property + one append; a stage-1 file)
- Create: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendClientBridge.swift`
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecLayoutController.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecLayoutControllerInternal.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecLayoutController.m`
- Create: `Sources/RichTextEditorUIKit/InputBackend/InputDec/DIVERGENCES.md`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendAttachDetachTests.swift`

**Interfaces:**
- Consumes: `RichTextInputBackend`, `RichTextInputHost`, `RichTextInputStateSnapshot`, `RichTextInputBackendAttachmentError`, `RichTextInputExternalChange`, `RichTextCanonicalSelection`, `RichTextSelectionChangeReason` (all from the seam plan's Phase 1).
- Produces:
  ```swift
  @available(iOS 17.0, *)
  final class IDTextEditorBackend: RichTextInputBackend {
      private(set) var state: RichTextInputStateSnapshot
      private(set) var isAttached: Bool
      private(set) var report: IDUIKitBehaviorReport?
      func attach(to host: any RichTextInputHost) throws
      func detach()
      func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange)
      func setSelection(_ selection: RichTextCanonicalSelection, reason: RichTextSelectionChangeReason)
  }
  ```

**Steps:**

1. - [ ] **Step 1: Add the one additive fake-client member this suite needs, then write the failing attach/detach test.** The seam's `FakeInputLifecycleClient` carries `didAttachCount`, `editPolicy`, `editPolicyReadCount`, `onDidPublishState` and `onDidAttach` — but **not** a record of the published snapshots, which is what "attach publishes exactly one initial state" needs. Add one stored property to `T/InputBackend/Fakes/FakeInputLifecycleClient.swift` and one append at the top of the existing `backendDidPublishState(_:reason:)` body (before the `onDidPublishState` hook fires, so a hook that detaches still leaves the record):
   ```swift
       /// Every state the backend published, in order. `didAttachCount` cannot express "published
       /// exactly one initial snapshot"; this can. Additive — no existing assertion reads it.
       private(set) var publishedStates: [RichTextInputStateSnapshot] = []
   ```
   This is a stage-1 file: record it in the commit message as an *additive change to a stage-1 fake*, and re-run `BackendAttachDetachTests` in Step 9 to prove nothing regressed. Then create `Tests/RichTextEditorUIKitTests/InputDec/IDBackendAttachDetachTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)
   @MainActor
   final class IDBackendAttachDetachTests: XCTestCase {

       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                             "InputDec backend is not supported on this runtime")
       }

       func test_attachToALegacyCanvas_throwsIncompatibleHost() {
           let host = FakeInputHost(hostInputView: DocumentCanvasView())
           let backend = IDTextEditorBackend()
           XCTAssertThrowsError(try backend.attach(to: host)) { error in
               guard case RichTextInputBackendAttachmentError.incompatibleHost = error else {
                   return XCTFail("expected .incompatibleHost, got \(error)")
               }
           }
           XCTAssertFalse(backend.isAttached)
       }

       func test_attachSucceedsOnTheIDCanvas_andPublishesInitialState() throws {
           let host = FakeInputHost(hostInputView: IDDocumentCanvasView())
           let backend = IDTextEditorBackend()
           try backend.attach(to: host)
           XCTAssertTrue(backend.isAttached)
           XCTAssertEqual(host.lifecycle.didAttachCount, 1)
           XCTAssertEqual(host.lifecycle.publishedStates.count, 1)
       }

       func test_attachTwice_throwsAlreadyAttached_andPreservesTheFirstAttachment() throws {
           let host = FakeInputHost(hostInputView: IDDocumentCanvasView())
           let backend = IDTextEditorBackend()
           try backend.attach(to: host)
           XCTAssertThrowsError(try backend.attach(to: host))
           XCTAssertTrue(backend.isAttached)
           XCTAssertEqual(host.lifecycle.didAttachCount, 1)
       }

       /// Residue is asserted after a failure the ID attach path ACTUALLY HAS. `attach(to:)` has
       /// exactly four failure modes — wrong canvas class, nil manifest, thunk-install failure,
       /// kernel construction failure — and none of them is a host-side flag, so a
       /// `host.failingCapability = "geometry"` would simply attach successfully and the
       /// assertions below would all be false. The wrong-canvas-class throw is the one reachable
       /// without touching the vendored kernel, and it is thrown BEFORE anything is constructed,
       /// which is exactly the atomicity claim being made.
       func test_attachFailureLeavesNoResidue() {
           let idCanvas = IDDocumentCanvasView()
           let host = FakeInputHost(hostInputView: DocumentCanvasView())   // not an ID canvas
           let backend = IDTextEditorBackend()
           XCTAssertThrowsError(try backend.attach(to: host))
           XCTAssertFalse(backend.isAttached)
           XCTAssertEqual(host.lifecycle.didAttachCount, 0)
           XCTAssertEqual(host.lifecycle.publishedStates.count, 0)
           XCTAssertEqual(host.presentation.applyCount, 0)
           XCTAssertEqual(host.presentation.tearDownCount, 0)
           // No bridge was associated with ANY ID canvas — including one that exists but was
           // never the host's input view.
           XCTAssertNil(TGRichTextInputDecAttachedBridge(idCanvas))
       }

       func test_detachIsIdempotentAndClearsTheAssociatedBridge() throws {
           let canvas = IDDocumentCanvasView()
           let host = FakeInputHost(hostInputView: canvas)
           let backend = IDTextEditorBackend()
           try backend.attach(to: host)
           XCTAssertNotNil(TGRichTextInputDecAttachedBridge(canvas))
           backend.detach()
           let eventsAfterFirstDetach = host.log.events.count
           backend.detach()
           XCTAssertEqual(host.log.events.count, eventsAfterFirstDetach)
           XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
           XCTAssertFalse(backend.isAttached)
       }

       func test_detachOrder_matchesTheSpecifiedSequence() throws {
           let host = FakeInputHost(hostInputView: IDDocumentCanvasView())
           let backend = IDTextEditorBackend()
           try backend.attach(to: host)
           host.log.reset()
           backend.detach()
           let kinds = host.log.kinds
           XCTAssertEqual(kinds.last, "lifecycleWillDetach",
                          "backendWillDetach must be the last thing detach does")
           XCTAssertLessThan(try XCTUnwrap(host.log.index(of: "presentationTearDown")),
                             try XCTUnwrap(host.log.index(of: "lifecycleWillDetach")))
       }

       func test_backendRetainsHostWeakly() throws {
           var host: FakeInputHost? = FakeInputHost(hostInputView: IDDocumentCanvasView())
           weak var probe = host   // `weak let` does not compile: weak requires a mutable variable
           let backend = IDTextEditorBackend()
           try backend.attach(to: XCTUnwrap(host))
           backend.detach()
           host = nil
           XCTAssertNil(probe)
       }

       /// The other half of the rename claim. `ContractManifestTests` proved the 47
       /// `incomingCallbacks` rows NAME `TGRichTextInputDecLayoutController`; this proves the class
       /// exists under that name. `IDUIKitCapabilityResolver.evaluateContract:` looks it up with
       /// NSClassFromString and fails the whole MANDATORY capability on nil, so both halves are
       /// required for `isSupported()` ever to answer true.
       func test_layoutControllerResolvesUnderTheRenamedManifestName() {
           XCTAssertNotNil(NSClassFromString("TGRichTextInputDecLayoutController"))
       }

       /// The exception guard is not decorative: `activeController` raises on any witness call
       /// after detach (IDUIKitInputControllerCapability.m:228), and Swift cannot catch it.
       func test_aWitnessCallAfterDetachDoesNotRaise() throws {
           let host = FakeInputHost(hostInputView: IDDocumentCanvasView())
           let backend = IDTextEditorBackend()
           try backend.attach(to: host)
           backend.detach()
           // Must return the documented "absent" value, not crash the test process.
           XCTAssertNil(backend.state.markedRange)
           XCTAssertFalse(backend.isAttached)
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendAttachDetachTests`. Expected failure: `'IDTextEditorBackend' cannot be constructed because it has no accessible initializers` / `does not conform to protocol 'RichTextInputBackend'`.

3. - [ ] **Step 3: Write the layout controller shell in Objective-C.** Create `include/TGRichTextInputDecLayoutController.h`:
   ```objc
   #import <TargetConditionals.h>
   #if TARGET_OS_IOS

   #import <UIKit/UIKit.h>
   #import "TGRichTextInputDecClientBridge.h"

   NS_ASSUME_NONNULL_BEGIN

   /// The object handed to the behavior kernel as `layoutController`. It implements the 47
   /// incoming private callbacks that UIKit's private text-input controller sends, each as a
   /// one-line forward to a neutral `id_`-prefixed method that talks to `bridge`.
   ///
   /// Document-neutral by construction: it holds no Telegram type and no InputDec document type,
   /// only the bridge. This is the class InputDec's `IDRichTextLayoutController` would be if it
   /// had not been written against `IDBlockDocument` — it is a rewrite, not a port.
   @interface TGRichTextInputDecLayoutController : NSObject

   - (instancetype)initWithBridge:(id<TGRichTextInputDecClientBridging>)bridge
       NS_DESIGNATED_INITIALIZER;
   - (instancetype)init NS_UNAVAILABLE;

   /// The single synthetic NSTextContainer the callbacks vend. UIKit requires container objects to
   /// exist; `canAccessLayoutManager` answers NO and `layoutManager` answers nil, so no real
   /// TextKit graph is ever demanded (upstream does exactly this).
   @property(nonatomic, strong, readonly) NSTextContainer *syntheticContainer;

   @property(nonatomic, strong, nullable) NSTextStorage *textStorageFacade;

   @end

   NS_ASSUME_NONNULL_END

   #endif
   ```
   and `Host/TGRichTextInputDecLayoutControllerInternal.h` declaring the neutral `id_…` surface (grows one group per family), and `Host/TGRichTextInputDecLayoutController.m` with the initializer, the synthetic container, `id_canAccessLayoutManager` returning `NO` and `id_layoutManager` returning `nil`.

   **The 47 selectors, their type encodings, the `id_` naming rule and which task owns each row are in the [Appendix](#appendix-the-47-incomingcallbacks-selectors-and-the-id_-rule)** — including the one-line command that re-derives the list from the shipped manifest. This task implements only the connection/teardown rows (1, 26-29 in the appendix table): `textStorage`, `textInputController`, `adoptTextInputController:`, `detachFromTextInputController`, `canAccessLayoutManager`. Do **not** stub the other 42 here: an unimplemented row is a rejected mandatory capability (loud), while a stubbed one is a silent wrong answer.

4. - [ ] **Step 4: Write the Swift bridge object.** Create `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendClientBridge.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit

   /// Translates every Objective-C bridge call into the six Swift clients.
   ///
   /// This is the ONLY place the two worlds meet. The shared Swift protocols stay Swift-only (spec:
   /// "the shared protocols do not become `@objc` merely to bridge it"), and Swift-only concepts —
   /// `AnyHashable` line ids, the mutation enum's associated values, the prepared-mutation token,
   /// the invalidation OptionSet — are consumed here and never cross into Objective-C.
   @available(iOS 17.0, *)
   final class IDTextEditorBackendClientBridge: NSObject, TGRichTextInputDecClientBridging {
       private weak var host: (any RichTextInputHost)?
       private unowned let backend: IDTextEditorBackend
       let storage: TGRichTextInputDecTextStorageFacade

       init(host: any RichTextInputHost, backend: IDTextEditorBackend) {
           self.host = host
           self.backend = backend
           self.storage = TGRichTextInputDecTextStorageFacade()
           super.init()
           self.storage.bridge = self
       }

       func textStorageFacade() -> NSTextStorage { storage }

       func canvasKeyboardInputShouldDelete() -> Bool {
           guard let host else { return false }
           return host.lifecycleClient.editPolicy.isEditable
       }
   }
   #endif
   ```

5. - [ ] **Step 5: Write the backend's attach/detach.** Extend `IDTextEditorBackend.swift` with the stored properties and the two lifecycle methods, following the spec's fixed attach order (lines 1190-1202) and nine-step detach order (lines 1204-1216):
   ```swift
       /// Constructed MEMBERWISE. `RichTextInputStateSnapshot` (spec lines 221-226) is
       /// `{ documentRevision, selection, markedRange, isComposing }` and has **no `static let
       /// empty`** — the seam plan only ever builds it memberwise. Adding one would edit a shared
       /// stage-1 file and would have to appear in the Rollback shared-edit list; it is not worth
       /// that for one initializer. `.caret(at:)` and `.downstream(_:)` are the seam's own
       /// spellings (`RichTextInputTypesTests`, seam Task 10 Step 3).
       private(set) var state = RichTextInputStateSnapshot(
           documentRevision: 0,
           selection: .caret(at: .downstream(0)),
           markedRange: nil,
           isComposing: false)
       private(set) var isAttached = false
       private(set) var report: IDUIKitBehaviorReport?

       private weak var host: (any RichTextInputHost)?
       private var bridge: IDTextEditorBackendClientBridge?
       private var layoutController: TGRichTextInputDecLayoutController?
       private var kernel: IDUIKitBehaviorKernel?
       private var kernelInput: IDUIKitInputControllerCapability?
       private var kernelInteraction: IDUIKitInteractionCapability?
       private weak var attachedCanvas: IDDocumentCanvasView?

       /// Stage C starts with the three mandatory capabilities only. `interaction` and
       /// `floatingCursor` are added in Tasks C10/C11; autoscroll is never requested —
       /// InputDec's autoscroll assumes the first responder IS the UIScrollView, and Telegram's
       /// canvas is a UIView inside a separate GripYieldingScrollView. See DIVERGENCES.md.
       ///
       /// SPELLING. The ObjC declaration is
       /// `typedef NS_OPTIONS(NSUInteger, IDUIKitBehaviorCapabilities)` with constants named
       /// `IDUIKitBehaviorCapabilityInputController`, … (IDUIKitBehaviorCapabilities.h:21-32).
       /// Swift strips the common prefix WORD-WISE, and "Capabilities" ≠ "Capability", so the
       /// stripping stops at `IDUIKitBehavior` and the imported members keep the word:
       /// `.capabilityInputController`, `.capabilityTypingAttributes`, `.capabilityIncomingCallbacks`
       /// (and `.capabilityInteraction`, `.capabilityFloatingCursor`, `.capabilityPrediction`,
       /// `.capabilityPaste`, `.capabilityChecking`, `.capabilityDictation`, `.capabilityAutoscroll`).
       /// `.inputController` etc. do not exist.
       ///
       /// Also note `autoscrollEntry` is a MANIFEST JSON key (`capabilities.autoscrollEntry`, 3
       /// members); the OPTION constant is `IDUIKitBehaviorCapabilityAutoscroll` →
       /// `.capabilityAutoscroll`. The two names are not interchangeable.
       private static var requestedCapabilities: IDUIKitBehaviorCapabilities {
           [.capabilityInputController, .capabilityTypingAttributes, .capabilityIncomingCallbacks]
       }

       func attach(to host: any RichTextInputHost) throws {
           guard !isAttached else { throw RichTextInputBackendAttachmentError.alreadyAttached }
           guard let canvas = host.hostInputView as? IDDocumentCanvasView else {
               throw RichTextInputBackendAttachmentError.incompatibleHost(
                   "IDTextEditorBackend requires IDDocumentCanvasView, got \(type(of: host.hostInputView))")
           }
           guard let manifest = TGRichTextInputDecContractManifest() else {
               throw RichTextInputBackendAttachmentError.missingCapability("contract manifest")
           }
           var installError: NSError?
           guard TGRichTextInputDecInstallCanvasCallbacks(
                   IDDocumentCanvasView.self, DocumentCanvasView.self, &installError) else {
               throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                   installError?.localizedDescription ?? "canvas callback install")
           }
           let bridge = IDTextEditorBackendClientBridge(host: host, backend: self)
           let layoutController = TGRichTextInputDecLayoutController(bridge: bridge)
           layoutController.textStorageFacade = bridge.storage
           var kernelError: NSError?
           guard let kernel = IDUIKitBehaviorKernel(
                   manifest: manifest,
                   resolver: .systemResolver(),
                   layoutController: layoutController,
                   delegate: bridge,
                   view: canvas,
                   requestedCapabilities: Self.requestedCapabilities,
                   error: &kernelError) else {
               // Atomicity: everything above is a local; nothing has been published and the
               // associated object is not set until the last line.
               throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                   kernelError?.localizedDescription ?? "kernel construction")
           }
           self.host = host
           self.bridge = bridge
           self.layoutController = layoutController
           self.kernel = kernel
           self.kernelInput = kernel.inputController
           self.report = kernel.report
           self.attachedCanvas = canvas
           self.isAttached = true
           TGRichTextInputDecSetAttachedBridge(canvas, bridge)
           publishState(reason: .attachment)
           host.lifecycleClient.backendDidAttach()
       }

       func detach() {
           guard isAttached, let host else { return }
           kernelInteraction?.detach()                        // 1-2 gestures/loupe/floating cursor
           commitOrDiscardMarkedText()                        // 3
           kernelInput?.detach()                              // 4-5 `_detachFromLayoutManager`
           if let canvas = attachedCanvas {
               TGRichTextInputDecSetAttachedBridge(canvas, nil)   // 6 thunks go inert
           }
           host.presentationClient.tearDownPresentation()     // 7
           kernel?.detach()                                   // 8
           isAttached = false
           kernel = nil; kernelInput = nil; kernelInteraction = nil
           layoutController = nil; bridge = nil; attachedCanvas = nil
           host.lifecycleClient.backendWillDetach()           // 9 — last
           self.host = nil
       }
   ```

6. - [ ] **Step 6: Add the divergence log.** Create `Sources/RichTextEditorUIKit/InputBackend/InputDec/DIVERGENCES.md` with the first two entries: (a) `autoscrollEntry` is never requested — Telegram's canvas is not the scroll view; Telegram's own drag-autoscroll (`DocumentCanvasView.swift:1392-1449`) keeps running; (b) position identity is flat `(utf16Offset, affinity, revision)` rather than InputDec's block-anchor model, so edit-survival relies on `documentClient.rebase(_:fromRevision:)`.

7. - [ ] **Step 7: Wrap the kernel construction in the exception guard.** `IDUIKitBehaviorKernel(manifest:…)` returns nil on a mandatory contract failure, but the interaction path reached later raises, and `TGRichTextInputDecHostPreflight` raises on an ABI mismatch. Replace the `guard let kernel = IDUIKitBehaviorKernel(…)` in Step 5 with:
   ```swift
           var kernelError: NSError?
           var guardError: NSError?
           let constructed = TGRichTextInputDecPerformReturningObject({
               IDUIKitBehaviorKernel(manifest: manifest,
                                     resolver: .systemResolver(),
                                     layoutController: layoutController,
                                     delegate: bridge,
                                     view: canvas,
                                     requestedCapabilities: Self.requestedCapabilities,
                                     error: &kernelError)
           }, &guardError)
           guard let kernel = constructed as? IDUIKitBehaviorKernel else {
               // Atomicity: everything above is a local; nothing has been published and the
               // associated object is not set until the last line. Either failure mode — a nil
               // return or a raised NSException — lands here as one thrown Swift error.
               throw RichTextInputBackendAttachmentError.privateRuntimeFailure(
                   guardError?.localizedDescription
                   ?? kernelError?.localizedDescription
                   ?? "kernel construction")
           }
   ```

8. - [ ] **Step 8: Write the call-guard boundary test.** Create `Tests/RichTextEditorCoreTests/SourceBoundary/IDBackendCallGuardTests.swift` — in the **Core** target, so it runs in the fast macOS `swift test` loop:
   ```swift
   import XCTest

   /// Enforces the usage rule written down in Task A8 Step 6: no Swift file in the adapter may
   /// call the vendored kernel without the NSException trampoline. Swift cannot catch an
   /// NSException, the kernel raises on every contract mismatch, and it is certified against one
   /// OS build — so a direct call is a crash waiting for the next OS.
   final class IDBackendCallGuardTests: XCTestCase {

       /// Member ACCESSES, not declarations: `private var kernelInput: …?` and
       /// `self.kernelInput = kernel.inputController` are storage, not calls, and must not be
       /// flagged. Matching on the `?.` / `!.` / `.` suffix is what separates the two.
       private static let kernelEntryPoints = ["kernelInput?.", "kernelInput!.",
                                               "kernelInteraction?.", "kernelInteraction!.",
                                               "IDUIKitBehaviorKernel(",
                                               "TGRichTextInputDecHostPreflight."]

       func test_everyKernelCallIsInsideTheExceptionGuard() throws {
           RepoLayout.assertResolved()
           let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec")
           var offenders: [String] = []
           for url in RepoLayout.swiftFiles(under: adapter) {
               let text = SwiftSourceScan.stripCommentsAndStringLiterals(try String(contentsOf: url))
               for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                   guard Self.kernelEntryPoints.contains(where: { line.contains($0) }) else { continue }
                   // A guarded call site names the trampoline within the same statement group; the
                   // convention this enforces is that the entry point appears INSIDE the closure
                   // literal passed to TGRichTextInputDecPerform*, i.e. on a line that either
                   // names it or follows one within three lines.
                   let window = text.split(separator: "\n", omittingEmptySubsequences: false)[
                       max(0, index - 3)...index].joined(separator: "\n")
                   if !window.contains("TGRichTextInputDecPerform") {
                       offenders.append("\(url.lastPathComponent):\(index + 1)")
                   }
               }
           }
           XCTAssertEqual(offenders, [],
                          "unguarded kernel call — wrap it in TGRichTextInputDecPerform")
       }

       /// The guard must not become vacuous by the adapter simply having no kernel calls.
       func test_thereAreGuardedKernelCallsToCheck() throws {
           RepoLayout.assertResolved()
           let adapter = RepoLayout.inputBackend.appendingPathComponent("InputDec")
           let anyCall = try RepoLayout.swiftFiles(under: adapter).contains {
               try String(contentsOf: $0).contains("TGRichTextInputDecPerform")
           }
           XCTAssertTrue(anyCall, "no guarded kernel call found — the rule covers nothing")
       }
   }
   ```
   `test_thereAreGuardedKernelCallsToCheck` fails until Task C4 Step 9 adds the first guarded witness; write it here and leave it **commented out with `// UNCOMMENT IN TASK C4`**, exactly as Task A4 did for the boundary anti-vacuity test.

9. - [ ] **Step 9: Run both suites and see them pass, plus the stage-1 proof.** `cd "$PKG" && swift test --filter IDBackendCallGuardTests` (macOS, instant) and `DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendAttachDetachTests` — 9 tests passing on K3. Then `Scripts/iostest.sh RichTextEditorUIKitTests/BackendAttachDetachTests` on K1 — still green, proving the `publishedStates` addition to `FakeInputLifecycleClient` (Step 1) was purely additive.

10. - [ ] **Step 10: Commit.**
    ```sh
    cd /Users/isaac/build/telegram/telegram-ios && \
    git add submodules/TelegramUI/Components/RichTextEditor/Sources \
            submodules/TelegramUI/Components/RichTextEditor/Tests && \
    git commit -m "feat(inputdec): backend skeleton, client bridge, and neutral layout controller"
    ```

### Task C1: Extend the real-canvas harness with `.inputDec`

The seam plan's `makeBackendHarness` (Task 21) has signature `(backend:engine:facade:paragraphs:width:)`, its `RichTextInputBackendKind` has **one** case (`legacy`, with the comment "`case inputDec` is added only in stage 2"), and its harness exposes `canvas`, `facade`, `backendKind`, `layoutEngine`, `recorder`, `anchor`, `head`, `revision`, `layoutGeneration`, `markedRange`, `undoManager`. There is no `backend`, no `storageFacade`, no `blocks:` parameter and no `hostInWindow:` parameter (window hosting is the `hostInWindow()` *method*). This task adds exactly the missing members — additively, editing no existing test.

**Files:**
- Modify: `Tests/RichTextEditorUIKitTests/Support/RichTextInputBackendHarness.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDHarnessTests.swift`

**Interfaces:**
- Consumes: `makeBackendHarness(backend:engine:facade:paragraphs:width:)`, `RichTextInputBackendKind`, `RichTextInputCanvasFactory.make(_:)`, `TGRichTextInputDecAttachedBridge`.
- Produces: `RichTextInputBackendKind.inputDec`; `RichTextInputBackendHarness.backend: any RichTextInputBackend`; `RichTextInputBackendHarness.storageFacade: TGRichTextInputDecTextStorageFacade?`.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDHarnessTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)
   @MainActor
   final class IDHarnessTests: XCTestCase {
       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported(),
                             "the kernel is certified against exactly one OS build")
       }

       func test_harnessBuildsTheIDCanvasAndAttachesTheIDBackend() {
           let h = makeBackendHarness(backend: .inputDec)
           defer { h.tearDown() }
           XCTAssertTrue(h.canvas is IDDocumentCanvasView)
           XCTAssertTrue(h.backend is IDTextEditorBackend)
           XCTAssertTrue(h.backend.isAttached)
           XCTAssertEqual(h.backendKind, .inputDec)
       }

       /// ~1600 legacy tests assert on `boxes`, `anchor`, `head`, `undoManagerOverride`. Those must
       /// stay reachable through the harness for BOTH backends or no suite can be shared.
       func test_harnessExposesTheLegacyAssertionSurface() {
           let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"])
           defer { h.tearDown() }
           XCTAssertEqual(h.canvas.boxes.count, 2)
           XCTAssertNotNil(h.canvas.undoManagerOverride)
           XCTAssertTrue(h.undoManager === h.canvas.undoManagerOverride)
           h.select(1, 4)
           XCTAssertEqual(h.anchor, 1)
           XCTAssertEqual(h.head, 4)
       }

       /// The storage facade is the ID backend's mutation entry point; family 4's tests drive it
       /// directly, so the harness must vend it — and must vend nil for the legacy backend.
       func test_storageFacadeIsVendedForInputDecAndNilForLegacy() {
           let id = makeBackendHarness(backend: .inputDec); defer { id.tearDown() }
           XCTAssertNotNil(id.storageFacade)
           let legacy = makeBackendHarness(backend: .legacy); defer { legacy.tearDown() }
           XCTAssertNil(legacy.storageFacade)
       }

       func test_harnessTearsDownWithoutLeavingAnAttachedBridge() {
           let h = makeBackendHarness(backend: .inputDec)
           let canvas = h.canvas
           h.tearDown()
           XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
       }

       /// The engine flag must still be restored — a leaked `true` silently converts the rest of
       /// the bundle into a TextKit-1 run, and the .inputDec branch adds a new early-return path.
       func test_tearDownRestoresTheGlobalEngineFlagOnTheInputDecPath() {
           let before = BlockLayoutBackend.forceTextKit1
           let h = makeBackendHarness(backend: .inputDec, engine: .textKit1)
           h.tearDown()
           XCTAssertEqual(BlockLayoutBackend.forceTextKit1, before)
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDHarnessTests`. Expected: `type 'RichTextInputBackendKind' has no member 'inputDec'`.

3. - [ ] **Step 3: Extend the kind enum.** In `Tests/RichTextEditorUIKitTests/Support/RichTextInputBackendHarness.swift`, replace the one-case enum:
   ```swift
   enum RichTextInputBackendKind {
       case legacy
       /// Added by the InputDec project. Every test using it MUST
       /// `XCTSkipUnless(IDTextEditorBackend.isSupported())` — the kernel is certified against
       /// exactly one OS build (26.5 / 23F73) and answers false everywhere else.
       case inputDec
   }
   ```
   Note there is **no** `.spy` case: the seam plan's recording backend is a separate type (`SpyRichTextInputBackend`, `T/Support/SpyRichTextInputBackend.swift`) that the router suites install directly, not a harness kind.

4. - [ ] **Step 4: Add the two accessors.** In `RichTextInputBackendHarness`, add:
   ```swift
       /// The attached backend, as the protocol. Forwards to the canvas's own
       /// `private(set) var inputBackend: any RichTextInputBackend` (seam Task 20 Step 5) — the
       /// harness does not hold a second reference, so there is no way for the two to disagree.
       var backend: any RichTextInputBackend { canvas.inputBackend }

       /// The ID backend's NSTextStorage facade, or nil under `.legacy`. Family 4 drives it
       /// directly, because UIKit's real mutation entry point is a raw range replace on it.
       var storageFacade: TGRichTextInputDecTextStorageFacade? {
           (backend as? IDTextEditorBackend)?.storageFacadeForTesting
       }
   ```
   `storageFacadeForTesting` is a `#if DEBUG` `internal var` on `IDTextEditorBackend` returning `bridge?.storage`; add it in this step, next to the stored properties from Task C0 Step 5, with the comment *"test-only: the façade is backend-private, and nothing in production reads it."*

5. - [ ] **Step 5: Add the `.inputDec` construction branch.** In `makeBackendHarness`, the only change is the canvas construction — steps 1 (engine flag), 3 (seed), 4 (frame + layout), 5 (undo manager), 6 (recorder/facade) are already backend-agnostic and stay shared:
   ```swift
       // 2. Construct — the canvas attaches its backend in its own init.
       let canvas: DocumentCanvasView
       switch backend {
       case .legacy:
           canvas = DocumentCanvasView()
       case .inputDec:
           // `.inputDecRequired`, not `.inputDecIfSupported`: a silent fallback to the legacy
           // canvas would make every `.inputDec` test pass while testing the wrong backend.
           canvas = RichTextInputCanvasFactory.make(.inputDecRequired)
       }
   ```

6. - [ ] **Step 6: Run and see it pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDHarnessTests` — 5 tests passing.

7. - [ ] **Step 7: Prove nothing regressed for `.legacy`.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/RichTextInputBackendHarnessTests` on K1 — the seam plan's own 12 harness tests, unchanged and green. Then `TK1=1 Scripts/iostest.sh RichTextEditorUIKitTests/RichTextInputBackendHarnessTests`, also green.

8. - [ ] **Step 8: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests && \
   git commit -m "test(inputdec): backend harness supports .inputDec"
   ```

### Task C2: The fake-client harness

The seam plan's contract suites build a `FakeInputHost` and attach `LegacyRichTextInputBackend` **by name**. Client-boundary assertions for the ID backend need the same shape with `IDTextEditorBackend` — and `IDTextEditorBackend.attach(to:)` requires `host.hostInputView` to be an `IDDocumentCanvasView` (deviation D23 renamed the host member, because `DocumentCanvasView` already overrides `UIResponder.inputView`), so the fake host must vend one.

**Files:**
- Create: `Tests/RichTextEditorUIKitTests/InputDec/IDFakeClientHarness.swift`
- Modify: `Tests/RichTextEditorUIKitTests/InputBackend/Fakes/FakeInputDocumentClient.swift`
- Modify: `Tests/RichTextEditorUIKitTests/InputBackend/Fakes/FakeInputGeometryClient.swift`
- Modify: `Tests/RichTextEditorUIKitTests/InputBackend/Fakes/FakeInputCommandClient.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDFakeClientHarnessTests.swift`

**Interfaces:**
- Consumes: `FakeInputHost`, `FakeInputDocumentClient`, `FakeInputGeometryClient`, `FakeInputAnnotationClient`, `FakeInputPresentationClient`, `FakeInputLifecycleClient`, `FakeInputCommandClient`, `RichTextInputEventLog` (all seam Task 22).
- Produces:
  ```swift
  @MainActor @available(iOS 17.0, *)
  final class IDFakeClientHarness {
      let backend: IDTextEditorBackend
      let canvas: IDDocumentCanvasView
      let host: FakeInputHost
      let log: RichTextInputEventLog
      var document: FakeInputDocumentClient { host.document }
      var geometry: FakeInputGeometryClient { host.geometry }
      var annotation: FakeInputAnnotationClient { host.annotation }
      var presentation: FakeInputPresentationClient { host.presentation }
      var lifecycle: FakeInputLifecycleClient { host.lifecycle }
      var command: FakeInputCommandClient { host.command }
      var storageFacade: TGRichTextInputDecTextStorageFacade
      func tearDown()
  }
  @MainActor @available(iOS 17.0, *)
  func makeIDFakeClientHarness(paragraphs: [String] = ["Alpha", "Beta"],
                               width: CGFloat = 300) -> IDFakeClientHarness
  ```
- Produces (fake-client additions, all additive to stage-1 files): `FakeInputDocumentClient.text: String`, `.clampCallCount: Int`, `.settableRevision: UInt64`, `.receivedMutations: [RichTextInputMutation]`; `FakeInputGeometryClient.receivedRequests: [RichTextInputSelectionGeometryRequest]`; `FakeInputCommandClient.canPerformQueries: [RichTextInputCommand]`, `.prepared: [RichTextInputCommand]`, `.committed: [RichTextInputCommand]`, `.sawDoubleCommit: Bool` (the four Task C10 reads; the seam declares `sawDoubleCommit` on the *document* fake only). `FakeInputLifecycleClient.publishedStates` is added earlier, in Task C0 Step 1.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDFakeClientHarnessTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)
   @MainActor
   final class IDFakeClientHarnessTests: XCTestCase {
       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
       }

       func test_harnessAttachesTheIDBackendToFakeClients() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           XCTAssertTrue(h.backend.isAttached)
           XCTAssertEqual(h.lifecycle.didAttachCount, 1)
           XCTAssertTrue(h.host.hostInputView === h.canvas)
       }

       /// All seven fakes must share ONE log, or cross-client ordering is unassertable.
       func test_allFakesShareOneOrderedLog() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           XCTAssertTrue(h.document.log === h.log)
           XCTAssertTrue(h.geometry.log === h.log)
           XCTAssertTrue(h.command.log === h.log)
           XCTAssertTrue(h.presentation.log === h.log)
       }

       func test_theDocumentFakeSeedsTheRequestedText() {
           let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
           XCTAssertEqual(h.document.text, "Alpha\nBeta")
           XCTAssertEqual(h.document.utf16Length, 10)
       }

       func test_theNewCountersStartAtZeroAndAreMutable() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           XCTAssertEqual(h.document.clampCallCount, 0)
           XCTAssertEqual(h.document.rebaseCallCount, 0)
           XCTAssertTrue(h.geometry.receivedRequests.isEmpty)
           h.document.settableRevision += 1
           XCTAssertEqual(h.document.revision, 1)
       }

       func test_tearDownDetachesAndClearsTheAssociatedBridge() {
           let h = makeIDFakeClientHarness()
           let canvas = h.canvas
           h.tearDown()
           XCTAssertFalse(h.backend.isAttached)
           XCTAssertNil(TGRichTextInputDecAttachedBridge(canvas))
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** Expected: `cannot find 'makeIDFakeClientHarness' in scope`.

3. - [ ] **Step 3: Add the additive fake-client members.** Nine in total across three fakes — and nothing else, so the seam plan's contract suites are untouched. In `FakeInputDocumentClient`:
   ```swift
       /// The backing text. Stage 1 only ever asserted on mutations; Stage 2's family-1 tests
       /// compare a canvas projection against it directly.
       private(set) var text: String

       /// Incremented in `clamp(_:)`. Stage 1 never counted clamps; the ID backend's position
       /// arithmetic goes through the document client and the count is the observable.
       private(set) var clampCallCount = 0

       /// Test-writable revision. `revision` stays get-only for production code; this is the
       /// staleness-injection seam for `test_aStalePosition_isRebasedExactlyOnce`.
       var settableRevision: UInt64 {
           get { revision }
           set { revision = newValue }
       }

       /// Every mutation passed to `prepareMutation(_:expectedRevision:)`, TYPED. The shared log
       /// stores `documentPrepare(mutation: String, …)` — a description, which cannot be pattern-
       /// matched. The intent-latch tests must distinguish `.insertParagraphBreak` from
       /// `.insertText("\n")`, so they need the case, not its printed form.
       private(set) var receivedMutations: [RichTextInputMutation] = []
   ```
   Append to `receivedMutations` at the top of the existing `prepareMutation(_:expectedRevision:)` body, and increment `clampCallCount` at the top of `clamp(_:)`. Both are one line each; neither changes any existing behavior of the fake.
   and in `FakeInputGeometryClient`:
   ```swift
       /// Every bounded selection request, in order. The 500-block Select-All test asserts on the
       /// visibleRect the backend passed, which no call *count* can express.
       private(set) var receivedRequests: [RichTextInputSelectionGeometryRequest] = []
   ```
   and in `FakeInputCommandClient` — the four members Task C10 (family 7: responder commands and clipboard) asserts on. The seam's command fake records into the shared log only, and the log stores descriptions, which cannot be pattern-matched:
   ```swift
       /// Every command the backend asked about via `canPerform(_:)`, in order.
       private(set) var canPerformQueries: [RichTextInputCommand] = []

       /// Every command passed to `prepareCommand(_:)` / `commitPreparedCommand(_:)`, TYPED.
       private(set) var prepared: [RichTextInputCommand] = []
       private(set) var committed: [RichTextInputCommand] = []

       /// Set when `commitPreparedCommand` is handed a token that was already consumed. Mirrors
       /// `FakeInputDocumentClient.sawDoubleCommit`, which the seam declares on the DOCUMENT fake
       /// only — the command path has the identical prepare/commit token discipline and, until
       /// now, no fake that enforced it.
       private(set) var sawDoubleCommit = false
   ```
   Append to each collection at the top of the corresponding existing method body, and set `sawDoubleCommit` from the same already-consumed check the document fake uses. Record all three fakes' additions in the commit message as *additive changes to stage-1 fakes*.

4. - [ ] **Step 4: Write the harness.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDFakeClientHarness.swift`. The construction order matters: the canvas must exist before `FakeInputHost` is built (it vends `hostInputView`), and the backend is detached from the canvas and re-attached to the fake host.
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// The ID backend attached to the seam plan's seven fake clients, all sharing one ordered log.
   ///
   /// Distinct from `makeBackendHarness(backend: .inputDec)`, which attaches the REAL Telegram
   /// clients to a real canvas. Use this one when the assertion is about the client boundary
   /// (call counts, argument values, interleaving); use that one when the assertion is about
   /// canvas-visible behavior.
   @MainActor
   @available(iOS 17.0, *)
   final class IDFakeClientHarness {
       let backend: IDTextEditorBackend
       let canvas: IDDocumentCanvasView
       let host: FakeInputHost
       let log: RichTextInputEventLog

       var document: FakeInputDocumentClient { host.document }
       var geometry: FakeInputGeometryClient { host.geometry }
       var annotation: FakeInputAnnotationClient { host.annotation }
       var presentation: FakeInputPresentationClient { host.presentation }
       var lifecycle: FakeInputLifecycleClient { host.lifecycle }
       var command: FakeInputCommandClient { host.command }
       var storageFacade: TGRichTextInputDecTextStorageFacade { backend.storageFacadeForTesting! }

       init(backend: IDTextEditorBackend, canvas: IDDocumentCanvasView,
            host: FakeInputHost, log: RichTextInputEventLog) {
           self.backend = backend; self.canvas = canvas; self.host = host; self.log = log
       }

       func tearDown() {
           backend.detach()
           // The fake document client's own finish() flags an un-consumed preparation, which is
           // the seam plan's default "token consumed exactly once" assertion.
           document.finish()
       }
   }

   @MainActor
   @available(iOS 17.0, *)
   func makeIDFakeClientHarness(paragraphs: [String] = ["Alpha", "Beta"],
                                width: CGFloat = 300) -> IDFakeClientHarness {
       let log = RichTextInputEventLog()
       // The canvas attaches its injected backend to ITSELF in init (seam Task 20 Step 5). The
       // fake-client harness wants that same backend attached to the FAKE host instead, so it is
       // detached and re-attached. Constructing a SECOND IDTextEditorBackend would leave two
       // backends contending for one canvas's associated bridge — the thunks would answer whichever
       // set it last, and the failure would read as a random test-ordering flake.
       let backend = IDTextEditorBackend()
       let canvas = IDDocumentCanvasView(inputBackend: backend)
       canvas.frame = CGRect(x: 0, y: 0, width: width, height: 600)
       backend.detach()

       let host = FakeInputHost(hostInputView: canvas, log: log, text: paragraphs.joined(separator: "\n"))
       try! backend.attach(to: host)
       return IDFakeClientHarness(backend: backend, canvas: canvas, host: host, log: log)
   }
   #endif
   ```
   If `FakeInputHost`'s initializer in the landed seam code does not take `hostInputView:log:text:`, add exactly those parameters with defaults preserving the existing call sites — do not fork the type.

5. - [ ] **Step 5: Run and see it pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDFakeClientHarnessTests` — 5 tests passing.

6. - [ ] **Step 6: Prove the stage-1 contract suites are unaffected.** `cd "$PKG" && for s in BackendMutationContractTests BackendRevisionContractTests BackendAttachDetachTests; do Scripts/iostest.sh "RichTextEditorUIKitTests/$s" || echo "FAILED $s"; done` on K1 — no `FAILED` lines. The fake-client additions were purely additive; this is the proof.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests && \
   git commit -m "test(inputdec): fake-client harness for the ID backend

Additive members on three stage-1 fakes: FakeInputDocumentClient.{text, clampCallCount,
settableRevision, receivedMutations}, FakeInputGeometryClient.receivedRequests and
FakeInputCommandClient.{canPerformQueries, prepared, committed, sawDoubleCommit}. No
existing contract suite is edited; all eight still pass."
   ```

### Task C3: The backend-parameterised shared semantic suite, and inheriting stage 1's eight contract suites

This is what makes "the same suite runs against both backends" true rather than aspirational. There are **two** bodies of assertions to parameterise, and decision 10 changed how the second one works.

**(i) The semantic suite — this plan's own.** One abstract base class holding the assertions, two subclasses differing by one property. XCTest runs a superclass's `test_` methods once per concrete subclass, which is exactly the parameterisation needed. Unchanged from the original design.

**(ii) Stage 1's eight contract suites — 54 interleaving and token-discipline tests.** The original plan accepted losing these for `.inputDec`, on the grounds that rewriting eight stage-1 files after the Phase 6 gate would put this plan's risk on the legacy path. **Decision 10 (2026-08-17) rejected that trade.** Stage 1 now ships those suites already parameterised: Task 22a there builds `BackendContractCases`, an abstract base naming no concrete backend, and each of the eight suites is a subclass whose only concrete reference is its `makeBackend()` override.

So this task no longer works around them — it *subclasses* them, and Step 7 below is new:

| | Original design | After decision 10 |
| --- | --- | --- |
| Stage 1 files edited | none | none (stage 1 shipped them parameterised) |
| Contract coverage for `.inputDec` | semantic assertions only | semantic assertions **plus all 54** interleaving/token-discipline tests |
| Cost | — | eight 4-line subclasses in this task |

**Files:**
- Create: `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticContractCases.swift`
- Create: `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticSubclasses.swift`
- Create: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendContractSubclasses.swift` (decision 10 — the eight subclasses)
- Modify: `Scripts/matrix.sh` (Step 6 — widen the discovery regex to accept `BackendSemanticContractCases` and `BackendContractCases` subclasses)
- Test: all three files

**Interfaces:**
- Consumes: `makeBackendHarness(backend:engine:facade:paragraphs:width:)`, `RichTextInputBackendKind`; and from stage 1, `BackendContractCases` plus the eight `Backend*ContractTests` classes.
- Produces: `BackendSemanticContractCases` (abstract), `LegacyBackendSemanticTests`, `IDBackendSemanticTests`, and the eight `IDBackend*ContractTests` subclasses.

**Steps:**

1. - [ ] **Step 1: Write the base class with the family-1 cases only.** Families 2 and 3 are appended by Tasks C5 and C6; the file grows one `// MARK:` section per family and never gets rewritten. Create `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticContractCases.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// Assertions written ONCE and run against every backend, via one subclass per kind.
   ///
   /// XCTest runs inherited `test_` methods in each concrete subclass, so this base class is the
   /// parameterisation mechanism. The base class itself must contribute no runs: `defaultTestSuite`
   /// is overridden to be empty when `Self == BackendSemanticContractCases`, otherwise the
   /// abstract case runs with a nil kind and every test fails confusingly.
   @MainActor
   @available(iOS 16.0, *)
   class BackendSemanticContractCases: XCTestCase {

       /// Overridden by each subclass. nil marks the abstract base.
       class var backendKind: RichTextInputBackendKind? { nil }

       override class var defaultTestSuite: XCTestSuite {
           backendKind == nil ? XCTestSuite(name: "abstract") : super.defaultTestSuite
       }

       override func setUpWithError() throws {
           if Self.backendKind == .inputDec {
               guard #available(iOS 17.0, *), IDTextEditorBackend.isSupported() else {
                   throw XCTSkip("the InputDec kernel is not supported on this runtime")
               }
           }
       }

       func harness(_ paragraphs: [String] = ["Alpha", "Beta"]) -> RichTextInputBackendHarness {
           makeBackendHarness(backend: Self.backendKind!, paragraphs: paragraphs)
       }

       // MARK: - Family 1: document reads and position/range conversion

       func test_textInWholeDocumentRange_isTheDocumentProjection() {
           let h = harness(); defer { h.tearDown() }
           let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                          to: h.canvas.endOfDocument)!
           XCTAssertEqual(h.canvas.text(in: whole), "Alpha\nBeta")
       }

       func test_positionBeforeTheStartIsNil_andAfterTheStartIsNot() {
           let h = harness(); defer { h.tearDown() }
           let start = h.canvas.beginningOfDocument
           XCTAssertNil(h.canvas.position(from: start, offset: -1))
           XCTAssertNotNil(h.canvas.position(from: start, offset: 1))
       }

       func test_compareAndOffsetUseUTF16OffsetsOnly() {
           let h = harness(); defer { h.tearDown() }
           let a = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 2)!
           let b = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
           XCTAssertEqual(h.canvas.compare(a, to: b), .orderedAscending)
           XCTAssertEqual(h.canvas.offset(from: a, to: b), 3)
       }

       func test_endOfDocumentOffsetEqualsUTF16Length() {
           let h = harness(); defer { h.tearDown() }
           XCTAssertEqual(h.canvas.offset(from: h.canvas.beginningOfDocument,
                                          to: h.canvas.endOfDocument), 10)
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Write the two subclasses.** Create `Tests/RichTextEditorUIKitTests/InputDec/BackendSemanticSubclasses.swift`:
   ```swift
   #if canImport(UIKit)
   import XCTest
   @testable import RichTextEditorUIKit

   /// The legacy run. Green from the moment the base class exists — it pins what "the same" means.
   @MainActor
   @available(iOS 16.0, *)
   final class LegacyBackendSemanticTests: BackendSemanticContractCases {
       override class var backendKind: RichTextInputBackendKind? { .legacy }
   }

   /// The ID run. Skips wholesale off the certified OS band; on it, every inherited assertion must
   /// produce the identical result. A divergence is a bug in the adapter or an entry in
   /// DIVERGENCES.md — never a weakened base-class assertion.
   @MainActor
   @available(iOS 16.0, *)
   final class IDBackendSemanticTests: BackendSemanticContractCases {
       override class var backendKind: RichTextInputBackendKind? { .inputDec }
   }
   #endif
   ```

3. - [ ] **Step 3: Run the legacy subclass first.** `cd "$PKG" && Scripts/iostest.sh RichTextEditorUIKitTests/LegacyBackendSemanticTests` on K1 — 4 tests passing. **This must be green before the ID side is even attempted**: it is the definition of the expected answers, and a failure here means the base-class assertions are wrong, not that the ID backend is.

4. - [ ] **Step 4: Run the ID subclass and see it fail.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendSemanticTests`. Expected: all 4 fail (nothing routes yet — the ID backend's witnesses land in Task C4). Record the failure text; Task C4 Step 10 turns it green.

5. - [ ] **Step 5: Prove the abstract base contributes no runs.** In the Step 3 output, confirm no test named `BackendSemanticContractCases/test_…` appears. If it does, the `defaultTestSuite` override is not taking effect and every future family would be counted three times.

6. - [ ] **Step 6: Teach `matrix.sh` discovery about the subclassed suites.** `discover()` (seam Task 9 Step 6) greps `^final class [A-Za-z0-9_]+: XCTestCase`. Both suites created here are `final class …: BackendSemanticContractCases`, so **neither would be discovered** and the matrix would certify the ID backend without ever running the shared semantic suite — silently, because a missing `-only-testing:` class is not an error. Widen the one regex in `Scripts/matrix.sh`:
   ```sh
   # was: grep -rhoE '^final class [A-Za-z0-9_]+: XCTestCase' "$r"
   grep -rhoE '^final class [A-Za-z0-9_]+: (XCTestCase|BackendSemanticContractCases)' "$r" \
     | awk '{print "RichTextEditorUIKitTests/"$3}' | sed 's/:$//'
   ```
   The `awk '{print $3}'` field is unchanged (`final class Name: Base` → `$3` is `Name:`), so only the alternation moves. **Include `BackendContractCases` in the alternation too** (Step 7's eight subclasses have the same discovery problem). The regex becomes `(XCTestCase|BackendSemanticContractCases|BackendContractCases)`. Verify: `cd "$PKG" && Scripts/matrix.sh 2>&1 | head -1` reports a count ten larger than before (2 semantic + 8 contract), and `Scripts/matrix.sh 2>&1 | grep -c "BackendSemanticTests"` is 4 (two suites × two engines). This is the second and last matrix edit in the plan; the first was Task B1 Step 4's `ROOTS` line.

7. - [ ] **Step 7 (decision 10): Inherit stage 1's eight contract suites.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDBackendContractSubclasses.swift`. Each subclass overrides **only** `makeBackend()`; all 54 assertions are inherited verbatim from stage 1, which is the entire point — an assertion that had to be restated here would be one that stage 1 wrote against a concrete backend, i.e. a violation of stage 1's rule 5.
   ```swift
   #if canImport(UIKit)
   import XCTest
   @testable import RichTextEditorUIKit

   /// Decision 10 (2026-08-17). Stage 1 ships the eight contract suites parameterised over
   /// `BackendContractCases`, so `.inputDec` inherits all 54 interleaving and token-discipline
   /// tests instead of getting semantic assertions only. Nothing in stage 1 is edited.
   ///
   /// If any subclass below needs more than a `makeBackend()` override to compile or pass, that
   /// is a finding about the CONTRACT, not about this file: it means the ID backend cannot meet a
   /// requirement the legacy backend meets. Record it in DIVERGENCES.md and fix the backend --
   /// do NOT relax the inherited assertion, and do NOT override a `test_` method here.
   @available(iOS 17.0, *)
   final class IDBackendMutationContractTests: BackendMutationContractTests {
       @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
           IDTextEditorBackend()
       }
   }

   @available(iOS 17.0, *)
   final class IDBackendRevisionContractTests: BackendRevisionContractTests {
       @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
           IDTextEditorBackend()
       }
   }
   #endif
   ```
   Write the remaining six the same way, one per stage-1 suite: `IDBackendPublicationContractTests`, `IDBackendSelectionContractTests`, `IDBackendMarkedTextPolicyTests`, `IDBackendReentrancyTests`, `IDBackendAttachDetachTests`, `IDBackendEditPolicyTests`. Each subclasses the identically-named stage-1 class without the `ID` prefix.

   Note that the eight stage-1 suites are declared `final` in the seam plan's Task 22a sketch. **Stage 1 must drop `final` from those eight classes for this to compile** — that is a one-word change in eight files and it is stage 1's responsibility, listed in its decision table under decision 10. If you find them still `final`, stop: stage 1 did not land decision 10, and the Phase 6 gate's item 11 should have caught that.

8. - [ ] **Step 8: Run the eight ID contract suites and record the failures.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendMutationContractTests` and the other seven. Expected at this point: **most fail**, because nothing routes until Tasks C4–C14. That is the correct red state. Record the per-suite pass/fail counts in `DIVERGENCES.md` as the starting line — each family task from C4 onward states which of these suites its work is expected to turn green, and Task D5's exit gate requires all eight fully green.

9. - [ ] **Step 9: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/InputDec \
           submodules/TelegramUI/Components/RichTextEditor/Scripts/matrix.sh && \
   git commit -m "test(inputdec): parameterised semantic suite + inherit stage 1's eight contract suites

Decision 10: the ID backend now runs all 54 interleaving and token-discipline
tests from stage 1, not semantic assertions only. Eight 4-line subclasses
overriding makeBackend(); no stage-1 assertion is restated or relaxed.
Legacy green, ID red until the families route."
   ```

### Task C4: Family 1 — document reads and position/range conversion

**Files:**
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecPosition.h`, `…Range.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecPosition.m`, `…Range.m`
- Modify: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecClientBridge.h` (document group)
- Modify: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecLayoutController.m`
- Modify: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendClientBridge.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFamily1Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputDocumentClient.utf16Length`, `.plainText(in:)`, `.clamp(_:)`, `.isValidInsertionPosition(_:)`, `.rebase(_:fromRevision:)`, `.revision`.
- Produces (ObjC):
  ```objc
  @interface TGRichTextInputDecPosition : UITextPosition
  @property(nonatomic, readonly) NSInteger utf16Offset;
  @property(nonatomic, readonly) UITextStorageDirection affinity;
  @property(nonatomic, readonly) uint64_t documentRevision;
  + (instancetype)positionWithOffset:(NSInteger)offset
                            affinity:(UITextStorageDirection)affinity
                            revision:(uint64_t)revision;
  @end
  @interface TGRichTextInputDecRange : UITextRange
  + (instancetype)rangeFrom:(TGRichTextInputDecPosition *)start to:(TGRichTextInputDecPosition *)end;
  @end
  ```
- Produces (bridge):
  ```objc
  - (NSInteger)documentUTF16Length;
  - (uint64_t)documentRevision;
  - (nullable NSString *)documentPlainTextInRange:(NSRange)range;
  - (NSInteger)documentClampedOffset:(NSInteger)offset;
  - (BOOL)documentIsValidInsertionOffset:(NSInteger)offset;
  - (BOOL)documentRebaseOffset:(NSInteger)offset
                 fromRevision:(uint64_t)revision
                    outOffset:(NSInteger *)outOffset;
  ```

**Steps:**

1. - [ ] **Step 1: Write the failing family test.** These are the **ID-specific** assertions — backend-owned identity types and client call counts, which have no legacy counterpart. The backend-agnostic family-1 assertions already live in `BackendSemanticContractCases` (Task C3) and are not repeated here. Note which harness each test uses: canvas-visible facts go through `makeBackendHarness`, client-boundary facts through `makeIDFakeClientHarness`. Create `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFamily1Tests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)
   @MainActor
   final class IDBackendFamily1Tests: XCTestCase {
       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
       }

       func test_beginningAndEndOfDocument_areBackendOwnedIdentity() {
           let h = makeBackendHarness(backend: .inputDec); defer { h.tearDown() }
           XCTAssertTrue(h.canvas.beginningOfDocument is TGRichTextInputDecPosition,
                         "the ID backend must not vend the legacy identity type")
           XCTAssertTrue(h.canvas.endOfDocument is TGRichTextInputDecPosition)
       }

       func test_textInRange_matchesTheDocumentClientProjection() {
           let h = makeIDFakeClientHarness(paragraphs: ["Alpha", "Beta"]); defer { h.tearDown() }
           let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                          to: h.canvas.endOfDocument)!
           XCTAssertEqual(h.canvas.text(in: whole), h.document.text)
       }

       func test_positionArithmetic_clampsThroughTheDocumentClient() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           let start = h.canvas.beginningOfDocument
           XCTAssertNil(h.canvas.position(from: start, offset: -1))
           XCTAssertNotNil(h.canvas.position(from: start, offset: 1))
           XCTAssertEqual(h.document.clampCallCount, 2,
                          "position arithmetic must clamp through the client, not locally")
       }

       /// Position identity compares (utf16Offset, affinity) only. The revision is staleness
       /// metadata, not identity — otherwise two logically identical positions would compare
       /// unequal across an unrelated edit.
       func test_positionEqualityIgnoresTheRevision() {
           let a = TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 1)
           let b = TGRichTextInputDecPosition(offset: 3, affinity: .forward, revision: 9)
           XCTAssertEqual(a, b)
           XCTAssertEqual(a.hash, b.hash)
           XCTAssertNotEqual(a, TGRichTextInputDecPosition(offset: 3, affinity: .backward, revision: 1))
       }

       func test_aStalePosition_isRebasedExactlyOnce() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           let stale = TGRichTextInputDecPosition(offset: 3, affinity: .forward,
                                                  revision: h.document.revision)
           h.document.settableRevision += 1
           _ = h.canvas.offset(from: h.canvas.beginningOfDocument, to: stale)
           XCTAssertEqual(h.document.rebaseCallCount, 1,
                          "one rebase per operation — a second miss must give up, not loop")
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendFamily1Tests`. Expected: `cannot find type 'TGRichTextInputDecPosition' in scope`.

3. - [ ] **Step 3: Write the identity types.** `TGRichTextInputDecPosition.{h,m}` and `TGRichTextInputDecRange.{h,m}` per the Interfaces block above. `isEqual:`/`hash` compare `(utf16Offset, affinity)` only — the revision is metadata for staleness detection, not identity, or two logically identical positions would compare unequal across an unrelated edit.

4. - [ ] **Step 4: Add the document group to the bridge protocol** exactly as listed in Interfaces, with the doc comment: *"NO from `documentRebaseOffset:` means the position cannot be rebased; `outOffset` is untouched. Never fabricate 0."*

5. - [ ] **Step 5: Implement the Swift side.** In `IDTextEditorBackendClientBridge.swift`:
   ```swift
       func documentUTF16Length() -> Int { host?.documentClient.utf16Length ?? 0 }

       func documentRevision() -> UInt64 { host?.documentClient.revision ?? 0 }

       func documentPlainText(inRange range: NSRange) -> String? {
           host?.documentClient.plainText(in: range)
       }

       func documentClampedOffset(_ offset: Int) -> Int {
           guard let host else { return 0 }
           return host.documentClient.clamp(RichTextInputPosition(utf16Offset: offset,
                                                                  affinity: .downstream)).utf16Offset
       }

       func documentIsValidInsertionOffset(_ offset: Int) -> Bool {
           guard let host else { return false }
           return host.documentClient.isValidInsertionPosition(
               RichTextInputPosition(utf16Offset: offset, affinity: .downstream))
       }

       func documentRebaseOffset(_ offset: Int,
                                 fromRevision revision: UInt64,
                                 outOffset: UnsafeMutablePointer<Int>) -> Bool {
           guard let host,
                 let rebased = host.documentClient.rebase(
                     RichTextInputPosition(utf16Offset: offset, affinity: .downstream),
                     fromRevision: revision) else { return false }
           outOffset.pointee = rebased.utf16Offset
           return true
       }
   ```

6. - [ ] **Step 6: Implement the ObjC callbacks.** In `TGRichTextInputDecLayoutController.m`, implement `id_beginningOfDocument`, `id_endOfDocument`, `id_positionFromPosition:offset:`, `id_comparePosition:toPosition:`, `id_offsetFromPosition:toPosition:`, `id_textRangeFromPosition:toPosition:`, `id_emptyTextRangeAtPosition:`, `id_attributedTextInRange:`, `id_characterRangeForTextRange:`, `id_textRangeForCharacterRange:`, plus the staleness check that calls `documentRebaseOffset:` once per operation and gives up on the second miss.

7. - [ ] **Step 7: Add the category's family-1 rows.** In `Private/TGRichTextInputDecLayoutController+PrivateCallbacks.m`, one one-line forward per selector. The rows are **appendix rows 5-14, 16-19, 21-25, 31 and 40** — 21 selectors; their exact spellings, return/argument encodings and the `id_` transform are in the [Appendix](#appendix-the-47-incomingcallbacks-selectors-and-the-id_-rule). Each forward is literally `- (ReturnType)selector:(Arg)a { return [self id_selector:a]; }`.

8. - [ ] **Step 8: Route the backend witnesses.** In `IDTextEditorBackend+TextBackend.swift`, forward `text(in:)`, `textRange(from:to:)`, `position(from:offset:)`, `compare(_:to:)`, `offset(from:to:)`, `beginningOfDocument`, `endOfDocument` into `kernelInput`.

9. - [ ] **Step 9: Route every kernel call through the exception guard.** The witnesses added in Step 8 call `kernelInput`, whose `activeController` raises on any post-detach call (`IDUIKitInputControllerCapability.m:228`). Wrap each one:
   ```swift
       func text(in range: UITextRange) -> String? {
           var error: NSError?
           let value = TGRichTextInputDecPerformReturningObject({
               self.kernelInput?.text(in: range) as NSString?
           }, &error) as? String
           if let error { reportKernelFailure(error, witness: #function) }
           return value
       }
   ```
   `reportKernelFailure(_:witness:)` is a private method on `IDTextEditorBackend` added here: it appends to `report` and, in DEBUG, calls `RichTextInputContractViolation.report(_:)`. It must **not** throw or trap — a post-detach witness call returning the documented "absent" value is correct behavior, not a crash. Then uncomment `IDBackendCallGuardTests.test_thereAreGuardedKernelCallsToCheck` (written and disabled in Task C0 Step 8) and run `cd "$PKG" && swift test --filter IDBackendCallGuardTests` — both tests green.

10. - [ ] **Step 10: Run the ID-specific tests and see them pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendFamily1Tests` — 5 tests passing.

11. - [ ] **Step 11: Turn the shared semantic suite green for family 1.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendSemanticTests` — the 4 family-1 cases that were red at Task C3 Step 4 are now green. Then re-run `LegacyBackendSemanticTests` on K1 and confirm it is still green: **the same four test bodies, two backends, identical results.** A divergence here is the whole point of the suite — fix the adapter or write a `DIVERGENCES.md` entry, never edit `BackendSemanticContractCases`.

12. - [ ] **Step 12: Commit.**
    ```sh
    cd /Users/isaac/build/telegram/telegram-ios && \
    git add submodules/TelegramUI/Components/RichTextEditor && \
    git commit -m "feat(inputdec): family 1 — document reads and position/range conversion"
    ```

### Task C5: Family 2 — geometry

**Files:**
- Modify: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecClientBridge.h` (geometry group)
- Modify: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecLayoutController.m`
- Modify: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendClientBridge.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFamily2Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputGeometryClient.caretGeometry(at:revision:purpose:)`, `.selectionSegments(for:revision:)`, `.closestPosition(to:within:revision:purpose:)`, `.characterRange(at:revision:)`, `.firstRect(for:revision:purpose:)`, `.baseWritingDirection(at:revision:)`, `RichTextInputSelectionGeometryRequest`.
- Produces (bridge):
  ```objc
  typedef NS_ENUM(NSInteger, TGRichTextInputDecGeometryPurpose) {
      TGRichTextInputDecGeometryPurposeKeyboard,
      TGRichTextInputDecGeometryPurposeCaret,
      TGRichTextInputDecGeometryPurposeSelectionEndpoint,
      TGRichTextInputDecGeometryPurposeSelectionPresentation,
      TGRichTextInputDecGeometryPurposeLoupe,
      TGRichTextInputDecGeometryPurposeFloatingCursor,
      TGRichTextInputDecGeometryPurposeEditMenu,
      TGRichTextInputDecGeometryPurposeAccessibility,
  };

  - (BOOL)caretGeometryAtOffset:(NSInteger)utf16Offset
                       affinity:(UITextStorageDirection)affinity
                       revision:(uint64_t)revision
                        purpose:(TGRichTextInputDecGeometryPurpose)purpose
                        outRect:(CGRect *)outRect
            outWritingDirection:(NSWritingDirection *)outWritingDirection
            outLayoutGeneration:(uint64_t *)outLayoutGeneration;

  - (NSArray<TGRichTextInputDecSelectionRect *> *)selectionRectsForRange:(NSRange)range
                                                            visibleRect:(CGRect)visibleRect
                                                               revision:(uint64_t)revision;

  - (BOOL)closestOffsetToPoint:(CGPoint)point
                 withinRange:(NSRange)range
                    revision:(uint64_t)revision
                   outOffset:(NSInteger *)outOffset;
  ```

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily2Tests`, all five on `makeIDFakeClientHarness` (every assertion here is about the client boundary). Declare any case that uses `try XCTUnwrap` as `func test_…() throws`: `test_caretRectForAKnownOffset_matchesTheGeometryClient`; `test_missingGeometryIsNilAcrossTheBridge_butZeroAtTheUIKitWitness` (set the fake geometry client's caret result to nil, assert the bridge returned `NO` and that `canvas.caretRect(for:)` still returns `.zero` — the spec's "never a fabricated CGRect.zero" is a *client*-boundary rule, and the `.zero` at the UIKit edge is deviation D9's pinned behavior that callers already branch on); `test_selectionRectsAreBoundedByTheVisibleRect` (500-paragraph harness, select all, then `XCTAssertEqual(try XCTUnwrap(h.geometry.receivedRequests.last?.visibleRect), h.canvas.bounds)` — the double optional must be unwrapped, and `XCTUnwrap` fails loudly if no request was ever recorded, which is the vacuous case; `receivedRequests` is the array Task C2 added to `FakeInputGeometryClient` for exactly this); `test_selectAllRealizesNoAdditionalBlockViews` (the same fixture, asserting `h.canvas.realizedBlockViewCountForTesting` stays within the overscan window, mirroring the seam's `BoundedSelectionGeometryTests.test_boundedRequestRealizesNoAdditionalBlockViews`); `test_geometryPurposeReachesTheClientUnchanged` (one case per purpose, asserting on `h.log` `.geometryQuery(kind:revision:purpose:)` events).

2. - [ ] **Step 2: Run it and see it fail.** Expected: `value of type 'IDTextEditorBackendClientBridge' has no member 'caretGeometryAtOffset'`.

3. - [ ] **Step 3: Declare the geometry group** in `TGRichTextInputDecClientBridge.h` exactly as in Interfaces, with the doc comment: *"NO ⇒ no geometry exists. Out-params are untouched on NO: the bridge never fabricates CGRectZero."*

4. - [ ] **Step 4: Implement the Swift side.**
   ```swift
       func caretGeometry(atOffset utf16Offset: Int,
                          affinity: UITextStorageDirection,
                          revision: UInt64,
                          purpose: TGRichTextInputDecGeometryPurpose,
                          outRect: UnsafeMutablePointer<CGRect>,
                          outWritingDirection: UnsafeMutablePointer<NSWritingDirection>,
                          outLayoutGeneration: UnsafeMutablePointer<UInt64>) -> Bool {
           guard let host else { return false }
           let position = RichTextInputPosition(
               utf16Offset: utf16Offset,
               affinity: affinity == .backward ? .upstream : .downstream)
           guard let geometry = host.geometryClient.caretGeometry(
                   at: position, revision: revision, purpose: purpose.asSwift) else { return false }
           outRect.pointee = geometry.rect
           // MAP EXPLICITLY. `geometry.writingDirection` is `RichTextInputWritingDirection`, a
           // Swift `enum … : Int` in the shared types; the out-param is UIKit's `NSWritingDirection`.
           // A direct assignment does not compile, and `NSWritingDirection(rawValue:)` would silently
           // couple the two enums' case order forever — so the mapping is written out.
           outWritingDirection.pointee = (geometry.writingDirection == .rightToLeft)
               ? .rightToLeft : .leftToRight
           outLayoutGeneration.pointee = geometry.layoutGeneration
           return true
       }
   ```
   plus `selectionRects(forRange:visibleRect:revision:)` mapping each `RichTextInputSelectionSegment` to a `TGRichTextInputDecSelectionRect` — **applying the same explicit `RichTextInputWritingDirection` → `NSWritingDirection` mapping** to each segment's direction, for the same reason — and `closestOffset(toPoint:withinRange:revision:outOffset:)`.

5. - [ ] **Step 5: Implement the ObjC callbacks, resolving UIKit's intolerance of absence inside the backend-private class.**
   ```objc
   - (CGRect)id_insertionRectForPosition:(UITextPosition *)position
                        typingAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                   placeholderAttachment:(id)attachment
                           textContainer:(NSTextContainer **)textContainer {
       if (textContainer != NULL) { *textContainer = self.syntheticContainer; }
       TGRichTextInputDecPosition *p = (TGRichTextInputDecPosition *)position;
       CGRect rect; NSWritingDirection direction; uint64_t generation;
       if (![self.bridge caretGeometryAtOffset:p.utf16Offset
                                      affinity:p.affinity
                                      revision:p.documentRevision
                                       purpose:TGRichTextInputDecGeometryPurposeKeyboard
                                       outRect:&rect
                           outWritingDirection:&direction
                           outLayoutGeneration:&generation]) {
           // Backend-private fallback decision, NOT CGRectZero: the shared geometry client never
           // learns that UIKit is intolerant of absence.
           return CGRectNull;
       }
       return rect;
   }
   ```
   plus `id_selectionRectsForRange:fromView:forContainerPassingTest:` (answering `YES` for the single synthetic container), `id_boundingRectForCharacterRange:`, `id_cursorPositionAtPoint:inContainer:`, `id_nearestPositionAtPoint:inContainer:`, `id_baseWritingDirectionAtPosition:`, `id_requestTextGeometryAtPosition:typingAttributes:resultBlock:` (calls the bridge synchronously and invokes the block inline), `id_ensureLayoutForRange:` / `id_invalidateLayoutForRange:`, and the three container callbacks (`id_textContainers`, `id_firstTextContainer`, `id_textContainerForPosition:`) returning the synthetic container. That is appendix rows 2-4, 15, 20, 32-36, 38, 39; their exact signatures are in the [Appendix](#appendix-the-47-incomingcallbacks-selectors-and-the-id_-rule). **These nine callbacks have no home in the spec's six clients and are resolved here — no shared protocol grows to accommodate them.**

6. - [ ] **Step 6: Add the family-2 selector forwards** to the private-callbacks category — **appendix rows 2-4, 15, 20, 32-36, 38, 39** (12 selectors), with the same `id_` transform and the encodings given there.

7. - [ ] **Step 7: Route the witnesses, each through the exception guard.** `caretRect(for:)`, `selectionRects(for:)`, `firstRect(for:)`, `closestPosition(to:)`, `closestPosition(to:within:)`, `characterRange(at:)`, `baseWritingDirection(for:in:)` into `kernelInput`, each wrapped in `TGRichTextInputDecPerformReturningObject` per the Task C4 Step 9 pattern. `caretRect(for:)` returns `?? .zero`, preserving deviation D9's UIKit-edge behavior.

8. - [ ] **Step 8: Add the family-2 cases to the shared suite.** Append a `// MARK: - Family 2: geometry` section to `BackendSemanticContractCases` with the backend-agnostic assertions: `test_caretRectAtDocumentStartIsNonEmpty`, `test_selectionRectsForAWholeParagraphCoverItsHeight`, `test_closestPositionToAPointInsideTheFirstLineIsInTheFirstParagraph`, `test_caretRectForAnUnrenderablePositionIsZero` (deviation D9).

9. - [ ] **Step 9: Run the ID-specific tests and see them pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendFamily2Tests` — 5 tests passing.

10. - [ ] **Step 10: Run the shared suite on both backends.** `LegacyBackendSemanticTests` on K1 and `IDBackendSemanticTests` on K3, serialized — both green across families 1 and 2.

11. - [ ] **Step 11: Commit.** `cd /Users/isaac/build/telegram/telegram-ios && git add submodules/TelegramUI/Components/RichTextEditor && git commit -m "feat(inputdec): family 2 — geometry"`

### Task C6: Family 3 — selected range and input delegate

**Files:**
- Modify: the bridge header (selection + delegate group), the layout controller, the Swift bridge
- Modify: `Sources/RichTextInputDecObjC/Private/TGRichTextInputDecCanvasCallbacks.m` (the four input-delegate thunks)
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendFamily3Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputStateSnapshot`, `RichTextCanonicalSelection`, `RichTextInputLifecycleClient.backendDidPublishState(_:reason:)`, `RichTextInputPresentationClient.apply(_:)`.
- Produces (bridge): `- (void)delegateTextInputDidChangeSelection; - (void)delegateKeyboardInputChangedSelection; - (void)delegateTextInputDidChange;` and `- (void)setCanonicalSelectionAnchor:(NSInteger)anchor head:(NSInteger)head reason:(TGRichTextInputDecSelectionReason)reason;`

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily3Tests`, all on `makeIDFakeClientHarness` (each asserts on `h.log`, the shared ordered event log): `test_selectedTextRangeGetter_handsUIKitAnUnorderedRangeForAReversedSelection` (anchor 10 / head 3 ⇒ the returned range's start is the *anchor*, matching the legacy behavior pinned at `DocumentCanvasView+UITextInput.swift:143`); `test_reversedSelectionSurvivesTheRoundTrip`; `test_oneSelectionChangePublishesExactlyOneSnapshot` (`h.log.count("lifecyclePublish") == 1`); `test_publicationFollowsDidChangeNotifications` (`h.log.index(of: "lifecyclePublish")! > h.log.index(of: "delegateSelectionDidChange")!`); `test_selectedTextRangeSetterIsIgnoredDuringFloatingCursor`.

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Install the four input-delegate thunks** in `TGRichTextInputDecCanvasCallbacks.m` (`textInputDidChange:`, `textInputDidChangeSelection:`, `keyboardInputChangedSelection:`, `_deleteBackwardAndNotify:`), each three lines: read the bridge, return if nil, forward.

4. - [ ] **Step 4: Own the delegate notifications in Swift.** In `IDTextEditorBackend`, add `emitWillChange(_:)` and `adoptAndEmitDidChange(_:)` that send `textWillChange`/`selectionWillChange`/`selectionDidChange`/`textDidChange` on `host.inputDelegate` in the spec's order. **Hard invariant 10 — only the backend sends `UITextInputDelegate` notifications** — so the layout controller and the storage façade must never touch the delegate.

5. - [ ] **Step 5: Publish state exactly once per operation.** `publishState(reason:)` calls `host.presentationClient.apply(snapshot)` then `host.lifecycleClient.backendDidPublishState(state, reason:)`, in that pinned order (the order Phase 0 recorded for `.legacy`).

6. - [ ] **Step 6: Run the ID-specific tests and see them pass.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendFamily3Tests` — 5 tests on K3.

7. - [ ] **Step 7: Add the family-3 cases to the shared suite and run both backends.** Append `// MARK: - Family 3: selection and delegate order` to `BackendSemanticContractCases`: `test_settingASelectionMovesAnchorAndHead`, `test_aReversedSelectionRoundTripsThroughSelectedTextRange`, `test_selectAllSelectsTheWholeDocument`. Then `LegacyBackendSemanticTests` on K1 and `IDBackendSemanticTests` on K3 — both green across families 1-3. **Note:** the seam plan's `BackendPublicationContractTests` / `BackendSelectionContractTests` construct `LegacyRichTextInputBackend` by name and are *not* backend-parameterised; do not try to run them against `.inputDec`. The equivalent coverage is the shared suite plus this task's `h.log` assertions.

8. - [ ] **Step 8: Commit.** `cd /Users/isaac/build/telegram/telegram-ios && git add submodules/TelegramUI/Components/RichTextEditor && git commit -m "feat(inputdec): family 3 — selected range and input-delegate ownership"`

### Task C7: Family 4 — insertion and replacement (the storage façade and the intent latch)

**This is the highest-risk task in the plan.** `UITextInputController` mutates through `NSTextStorage.replaceCharactersInRange:withString:` — a raw range replace that destroys exactly the semantic intent (`insertParagraphBreak` vs `insertText("\n")` vs `deleteBackward`) that Telegram's document client requires. The recovery is an **intent latch** populated by the pre-mutation delegate callbacks UIKit sends *before* the storage mutation.

**Files:**
- Create: `Sources/RichTextInputDecObjC/include/TGRichTextInputDecTextStorageFacade.h`
- Create: `Sources/RichTextInputDecObjC/Host/TGRichTextInputDecTextStorageFacade.m`
- Create: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackendIntent.swift`
- Modify: `Private/TGRichTextInputDecCanvasCallbacks.m` (the pre-mutation thunks)
- Test: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendIntentLatchTests.swift`, `…/IDBackendFamily4Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputDocumentClient.prepareMutation(_:expectedRevision:)`, `.commitPreparedMutation(_:)`, `RichTextInputMutation`, `RichTextInputMutationPreparation`, `RichTextInputMutationResult`.
- Produces (ObjC):
  ```objc
  typedef NS_ENUM(NSInteger, TGRichTextInputDecIntent) {
      TGRichTextInputDecIntentProgrammatic,
      TGRichTextInputDecIntentInsertText,
      TGRichTextInputDecIntentMarkedText,
      TGRichTextInputDecIntentDeleteBackward,
      TGRichTextInputDecIntentPaste,
      TGRichTextInputDecIntentDictation,
  };

  typedef struct {
      uint64_t revision;
      NSInteger selectionAnchor;
      NSInteger selectionHead;
  } TGRichTextInputDecMutationOutcome;

  @interface TGRichTextInputDecTextStorageFacade : NSTextStorage
  @property(nonatomic, weak) id<TGRichTextInputDecClientBridging> bridge;
  @property(nonatomic) TGRichTextInputDecIntent currentIntent;   // the latch
  @property(nonatomic) uint64_t revision;
  /// The read model. NSTextStorage is ABSTRACT: its four primitives must be overridden, and
  /// UIKit calls `string` and `attributesAtIndex:effectiveRange:` constantly during layout and
  /// selection. The mirror answers those reads; the document remains the write authority.
  @property(nonatomic, strong, readonly) NSMutableAttributedString *mirror;
  @end
  ```
- Produces (bridge): `- (BOOL)prepareAndCommitReplacementInRange:(NSRange)range text:(NSString *)text intent:(TGRichTextInputDecIntent)intent expectedRevision:(uint64_t)expectedRevision outOutcome:(TGRichTextInputDecMutationOutcome *)outOutcome;`

**Steps:**

1. - [ ] **Step 1: Write the failing intent-latch test.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDBackendIntentLatchTests.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// UIKit hands the storage façade a raw range replace. Without the latch, "pressed Return"
   /// and "typed a newline" and "deleted backward" are the same call, and Telegram's document
   /// client would execute them correctly but DIFFERENTLY from the legacy backend.
   @available(iOS 17.0, *)
   @MainActor
   final class IDBackendIntentLatchTests: XCTestCase {
       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
       }

       func test_insertTextIntentWithNewline_becomesInsertParagraphBreak() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           h.storageFacade.currentIntent = .insertText
           h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "\n")
           guard case .insertParagraphBreak = h.document.receivedMutations.first else {
               return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
           }
       }

       /// `.insertText` is a THREE-value case — `(text: NSAttributedString, replacing:, origin:)`.
       /// A two-value `case .insertText(let text, _)` pattern does not compile, and `text` is an
       /// NSAttributedString, never a String.
       func test_insertTextIntentWithPlainText_becomesInsertText() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           h.storageFacade.currentIntent = .insertText
           h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
           guard case .insertText(let text, _, let origin) = h.document.receivedMutations.first,
                 text.string == "a", origin == .softwareKeyboard else {
               return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
           }
       }

       func test_deleteBackwardIntent_forwardsTheProposedRangeVerbatim() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           h.storageFacade.currentIntent = .deleteBackward
           h.storageFacade.replaceCharacters(in: NSRange(location: 2, length: 3), with: "")
           // `proposedRange` is `NSRange?`, so the comparison promotes the literal.
           guard case .deleteBackward(_, let proposed) = h.document.receivedMutations.first,
                 proposed == NSRange(location: 2, length: 3) else {
               return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
           }
       }

       /// Paste is an ORIGIN, not a mutation case — there is no `RichTextInputMutation.paste`.
       /// The assertion is therefore on the origin of an `.insertText`, which is also what the
       /// client's `allowsPaste` policy check reads.
       func test_pasteIntent_becomesInsertTextWithThePasteOrigin() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           h.storageFacade.currentIntent = .paste
           h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "xy")
           guard case .insertText(let text, _, let origin) = h.document.receivedMutations.first,
                 text.string == "xy", origin == .paste else {
               return XCTFail("got \(String(describing: h.document.receivedMutations.first))")
           }
       }

       /// The latch is single-transaction-scoped. A second replace with no intervening callback
       /// must NOT reuse the previous intent, or a programmatic edit inherits a keyboard intent.
       func test_theLatchIsClearedAfterEveryTransaction() {
           let h = makeIDFakeClientHarness(); defer { h.tearDown() }
           h.storageFacade.currentIntent = .deleteBackward
           h.storageFacade.replaceCharacters(in: NSRange(location: 2, length: 1), with: "")
           h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "z")
           XCTAssertEqual(h.storageFacade.currentIntent, .programmatic)
           guard case .replaceText = h.document.receivedMutations.last else {
               return XCTFail("second replace inherited an intent")
           }
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** Expected: `cannot find type 'TGRichTextInputDecTextStorageFacade' in scope`.

3. - [ ] **Step 3: Write the façade.** `Host/TGRichTextInputDecTextStorageFacade.m`:
   ```objc
   - (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
       TGRichTextInputDecMutationOutcome outcome = {0};
       BOOL applied = [self.bridge prepareAndCommitReplacementInRange:range
                                                                 text:string
                                                               intent:self.currentIntent
                                                     expectedRevision:self.revision
                                                           outOutcome:&outcome];
       self.currentIntent = TGRichTextInputDecIntentProgrammatic;   // single-transaction latch
       if (!applied) {
           // Rejected or no-change: no `edited:` post, no mirror mutation, no notifications.
           return;
       }
       [self beginEditing];
       [self.mirror replaceCharactersInRange:range withString:string];   // read-model mirror only
       [self edited:NSTextStorageEditedCharacters
              range:range
     changeInLength:(NSInteger)string.length - (NSInteger)range.length];
       [self endEditing];
       self.revision = outcome.revision;
   }
   ```
   `NSTextStorage` is abstract in **four** primitives, and only `replaceCharactersInRange:withString:` is shown above. Write the other three in the same file, all of them one-liners over `mirror` (which is `[[NSMutableAttributedString alloc] init]` in the designated initializer):
   ```objc
   - (NSString *)string { return self.mirror.string; }

   - (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location
                                                   effectiveRange:(NSRangePointer)range {
       return [self.mirror attributesAtIndex:location effectiveRange:range];
   }

   - (void)setAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes
                   range:(NSRange)range {
       // Attribute-only edits carry no semantic intent Telegram's document model consumes; they
       // are a read-model concern. The document is told about them via the typing-attributes
       // client, not through a mutation.
       [self.mirror setAttributes:attributes range:range];
       [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
   }
   ```
   Omitting any of the three makes UIKit's first layout pass raise "method only defined for abstract class" — an `NSException`, i.e. a crash Swift cannot catch.

4. - [ ] **Step 4: Write the Swift transaction.** In `IDTextEditorBackendClientBridge.swift`:
   ```swift
       func prepareAndCommitReplacement(
           in range: NSRange,
           text: String,
           intent: TGRichTextInputDecIntent,
           expectedRevision: UInt64,
           outOutcome: UnsafeMutablePointer<TGRichTextInputDecMutationOutcome>) -> Bool {
           guard let host else { return false }
           let mutation = IDTextEditorBackendIntent.mutation(
               for: intent, range: range, text: text, selection: backend.state.selection)
           switch host.documentClient.prepareMutation(mutation, expectedRevision: expectedRevision) {
           case .terminal(let result):
               // Spec step 2: for a terminal rejection/no-change, stop without notifications.
               if case .rejected(let reason) = result.disposition {
                   host.lifecycleClient.backendDidRejectMutation(mutation, reason: reason)
               }
               return false
           case .ready(let prepared):
               backend.emitWillChange(prepared)                                  // steps 3-4
               let result = host.documentClient.commitPreparedMutation(prepared) // step 5
               backend.adoptAndEmitDidChange(result)                             // steps 6-9
               outOutcome.pointee = TGRichTextInputDecMutationOutcome(
                   revision: result.revision,
                   selectionAnchor: result.selection.anchor.utf16Offset,
                   selectionHead: result.selection.head.utf16Offset)
               return result.disposition == .applied
           }
       }
   ```

5. - [ ] **Step 5: Write the intent mapper.** `IDTextEditorBackendIntent.swift`:
   ```swift
   #if canImport(UIKit)
   import RichTextInputDecObjC
   import UIKit

   /// Recovers semantic intent that UIKit's raw `replaceCharactersInRange:` destroys.
   /// The latch is set by the pre-mutation private input-delegate callbacks and cleared by the
   /// façade after every transaction.
   @available(iOS 17.0, *)
   enum IDTextEditorBackendIntent {
       static func mutation(for intent: TGRichTextInputDecIntent,
                            range: NSRange,
                            text: String,
                            selection: RichTextCanonicalSelection) -> RichTextInputMutation {
           // SHAPES. These are the stage-1 `RichTextInputMutation` cases verbatim (seam Task 27's
           // `legacyApplyMutation` switch is the authoritative reading of them):
           //   insertText(text: NSAttributedString, replacing: RichTextCanonicalSelection,
           //              origin: RichTextInputMutationOrigin)
           //   insertParagraphBreak(replacing: RichTextCanonicalSelection, origin: …)
           //   replaceText(range: NSRange, text: NSAttributedString, origin: …)
           //   setMarkedText(text: NSAttributedString, replacing: NSRange,
           //                 selectedRangeInMarkedText: NSRange)
           //   deleteBackward(selection: RichTextCanonicalSelection, proposedRange: NSRange?)
           //   unmarkText
           // There is NO `.paste` case: paste is an ORIGIN, not a mutation. Every text-bearing case
           // takes an NSAttributedString, never a String.
           let attributed = NSAttributedString(string: text)
           switch intent {
           case .insertText where text == "\n":
               return .insertParagraphBreak(replacing: selection, origin: .softwareKeyboard)
           case .insertText:
               return .insertText(text: attributed, replacing: selection, origin: .softwareKeyboard)
           case .markedText:
               return .setMarkedText(text: attributed,
                                     replacing: selection.normalizedRange,
                                     selectedRangeInMarkedText: NSRange(location: text.utf16.count,
                                                                        length: 0))
           case .deleteBackward:
               return .deleteBackward(selection: selection, proposedRange: range)
           case .paste:
               // The intent survives as the ORIGIN. `allowsPaste` is enforced by the edit policy on
               // the client side, which reads exactly this.
               return .insertText(text: attributed, replacing: selection, origin: .paste)
           case .dictation:
               return .insertText(text: attributed, replacing: selection, origin: .dictation)
           case .programmatic:
               return .replaceText(range: range, text: attributed, origin: .programmatic)
           @unknown default:
               return .replaceText(range: range, text: attributed, origin: .programmatic)
           }
       }
   }
   #endif
   ```

6. - [ ] **Step 6: Install the pre-mutation thunks that set the latch.** In `TGRichTextInputDecCanvasCallbacks.m`, add thunks for `keyboardInput:shouldInsertText:isMarkedText:` (sets `.insertText` or `.markedText`), `keyboardInputShouldDelete:` (sets `.deleteBackward`), and `textInput:shouldChangeCharactersInRanges:replacementText:`. Each reads the bridge, returns the default when nil, and sets the latch on the façade before returning `YES`.

7. - [ ] **Step 7: Run the intent-latch tests and see them pass.** 5 tests on K3.

8. - [ ] **Step 8: Write and run the family-4 semantic test.** `IDBackendFamily4Tests` with: `test_insertText_commitsExactlyOnce_andPublishesApplied`; `test_terminalRejection_emitsNoDelegateNotifications_andNoPublication`; `test_preparedTokenIsConsumedExactlyOnce` (`h.document.sawDoubleCommit == false && h.document.sawUnconsumedPreparation == false`); `test_replaceOverASelection_carriesTheCanonicalSelection`.

9. - [ ] **Step 9: Add the family-4 cases to the shared suite and run both backends.** Append `// MARK: - Family 4: insertion` to `BackendSemanticContractCases`: `test_insertTextAtTheCaretAppearsInTheDocument`, `test_insertNewlineSplitsTheParagraph`, `test_insertOverASelectionReplacesIt`, `test_insertTextIsOneUndoStepPerContiguousRun`. Run `LegacyBackendSemanticTests` on K1 then `IDBackendSemanticTests` on K3 — both green. `test_insertNewlineSplitsTheParagraph` is the assertion the intent latch exists for: if it passes for `.legacy` and fails for `.inputDec`, the latch is wrong, and the test must not be weakened. (The seam's `BackendMutationContractTests` names `LegacyRichTextInputBackend` directly and is not parameterisable; its ID-side coverage is `IDBackendFamily4Tests` plus these shared cases.)

10. - [ ] **Step 10: Commit.** `git commit -m "feat(inputdec): family 4 — storage facade, two-phase mutation, intent latch"`

### Task C8: Family 5 — backward deletion

**Files:** the bridge header (delete group), `TGRichTextInputDecLayoutController.m`, `IDTextEditorBackend+KeyInput.swift`; Test: `IDBackendFamily5Tests.swift`

**Interfaces:**
- Consumes: `IDUIKitInputControllerCapability.preflightBackwardDeleteRanges()`, `.backwardDeleteRange()` (which validate the private `_rangesForBackwardsDelete` + `unionRange` aggregate **without invoking it**), `RichTextInputMutation.deleteBackward(selection:proposedRange:)`.
- Produces: `IDTextEditorBackend.deleteBackward()` witness.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily5Tests`: `test_deleteBackwardUsesTheControllerProposedRange`; `test_deleteBackwardAtDocumentStart_isANoChange_andEmitsNoNotifications`; `test_deleteBackwardOverAGraphemeCluster_deletesTheWholeCluster` (a family emoji, so the proposed range is >1 UTF-16 unit); `test_deleteBackwardWithANonEmptySelection_deletesTheSelection`.

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Route `deleteBackward()`** in `IDTextEditorBackend+KeyInput.swift` to `kernelInput?.preflightBackwardDeleteRanges()` then `kernelInput?.deleteBackward()`, letting the façade + latch produce the `.deleteBackward` mutation.

4. - [ ] **Step 4: Implement `id_rangeOfCharacterClusterAtIndex:type:`** on the layout controller by grapheme-walking `documentPlainTextInRange:` — one of the nine callbacks with no spec-client home, resolved backend-privately.

5. - [ ] **Step 5: Run and see it pass.** 4 tests on K3.

6. - [ ] **Step 6: Run the shared deletion semantic suite for both backends.** Both green. If `backspace-merges-paragraphs` or `backspace-at-table-cell-start` diverges, that is a **stop**: the intent latch is the likely cause and it must be fixed, not the test.

7. - [ ] **Step 7: Commit.** `git commit -m "feat(inputdec): family 5 — backward deletion"`

### Task C9: Family 6 — marked text and prediction

**Files:** the bridge header (marked-text group), `TGRichTextInputDecLayoutController.m`, `IDTextEditorBackend+TextBackend.swift`; Test: `IDBackendFamily6Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputMutation.setMarkedText(text:replacing:selectedRangeInMarkedText:)` (three labelled values; `text` is an `NSAttributedString` and `replacing` is an `NSRange`, **not** a selection) and the **bare** `.unmarkText` case (it carries no associated values at all), `RichTextMarkedTextPolicy`, `RichTextInputStateSnapshot.markedRange` / `.isComposing`, the `prediction` capability (`setAttributedMarkedText:selectedRange:`).
- Produces: `setMarkedText(_:selectedRange:)`, `unmarkText()`, `markedTextRange`, `markedTextStyle` witnesses.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily6Tests`: `test_setMarkedTextPublishesIsComposing`; `test_unmarkTextCommitsTheComposition`; `test_markedTextIsNotMigratedAcrossDetachAndReattach`; `test_commitBeforeChangePolicy_commitsBeforeAdoptingTheNewRevision`; `test_preserveIfRebasablePolicy_keepsTheMarkedRangeWhenRebaseSucceeds`; `test_markedTextStyleGetterReturnsNil_andTheSetterIsANoOp` (pins the documented legacy behavior at `DocumentCanvasView+MarkedText.swift:28`).

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Add `.capabilityPrediction` to `requestedCapabilities`** and route the marked-text witnesses through `kernelInput`, with the latch set to `.markedText` by the `isMarkedText:YES` branch of the `keyboardInput:shouldInsertText:isMarkedText:` thunk.

4. - [ ] **Step 4: Implement `synchronizeAfterExternalChange(_:)`'s marked-text policy branch** in `IDTextEditorBackend`, honouring `.commitBeforeChange` / `.discard` / `.preserveIfRebasable`, using `documentClient.rebase(_:fromRevision:)` for the third. **Never** synthesize a counterfeit keyboard mutation for an external change.

5. - [ ] **Step 5: Run and see it pass.** 6 tests on K3.

6. - [ ] **Step 6: Add the family-6 cases to the shared suite and run both backends.** Append `// MARK: - Family 6: marked text`: `test_setMarkedTextPublishesAMarkedRange`, `test_unmarkTextClearsTheMarkedRange`, `test_markedTextIsReplacedNotAppendedOnASecondSetMarkedText`. `LegacyBackendSemanticTests` on K1 and `IDBackendSemanticTests` on K3 — both green. (`BackendMarkedTextPolicyTests` itself stays legacy-only; the policy branches are covered on the ID side by `IDBackendFamily6Tests`.)

7. - [ ] **Step 7: Commit.** `git commit -m "feat(inputdec): family 6 — marked text and prediction"`

### Task C10: Family 7 — responder commands and clipboard

**Files:** the bridge header (command group), `IDTextEditorBackend+Responder.swift`; Test: `IDBackendFamily7Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputCommandClient.canPerform(_:sender:)`, `.prepare(_:)`, `.commit(_:)`, `RichTextInputCommand`.
- Consumes (kernel): `IDUIKitInputControllerCapability.shouldHandlePasteAction(_:sender:)`, `.performCut(_:)`, `.performCopy(_:)`, `.performPaste(_:)`.
- Produces: `canPerformAction(_:withSender:)`, `cut(_:)`, `copy(_:)`, `paste(_:)`, `select(_:)`, `selectAll(_:)` routing.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily7Tests`: `test_canPerformPaste_consultsTheCommandClient_notThePrivateController` (assert `h.command.canPerformQueries` contains `.paste` and that the private controller was not asked when the policy already says no); `test_pasteGoesThroughPrepareThenCommit` (`h.command.prepared.count == 1 && h.command.committed.count == 1 && h.command.sawDoubleCommit == false`); `test_allowsPasteFalse_makesCanPerformPasteFalse`; `test_copyOfAReversedSelection_copiesTheLogicalRange`.

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Add `.capabilityPaste` to `requestedCapabilities`.**

4. - [ ] **Step 4: Route the responder actions through the command client, not the private controller.** InputDec routes cut/copy/paste straight into `UITextInputController`; that would let the private controller mutate the document directly, which the spec forbids. So `IDTextEditorBackend+Responder.swift` converts `_canHandleResponderAction:` / `cut:` / `copy:` / `paste:` into `commandClient.canPerform` / `prepare` / `commit`, and only asks `kernelInput.shouldHandlePasteAction(_:sender:)` for the *availability* question UIKit owns. Record this as a deliberate divergence from upstream in `DIVERGENCES.md`.

5. - [ ] **Step 5: Run and see it pass.** 4 tests on K3.

6. - [ ] **Step 6: Commit.** `git commit -m "feat(inputdec): family 7 — responder commands and clipboard through the command client"`

### Task C11: Family 8 — responder lifecycle

**Files:** `IDTextEditorBackend+Responder.swift`, the bridge header (lifecycle group); Test: `IDBackendFamily8Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputLifecycleClient.backendWillBeginEditing()`, `.backendDidBeginEditing()`, `.backendShouldEndEditing()`, `.backendDidEndEditing()`, `.editPolicy`.
- Consumes (kernel): `IDUIKitInteractionCapability.resignedFirstResponder()`.
- Produces: `canBecomeFirstResponder`, `becomeFirstResponder()`, `resignFirstResponder()` routing.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily8Tests`: `test_becomeFirstResponderConsultsWillBeginEditing_andRefusesWhenDenied`; `test_resignFirstResponderConsultsShouldEndEditing`; `test_editPolicyIsReadAtOperationTime_notCachedAtAttach` (flip `h.lifecycle.editPolicy` after attach; assert `editPolicyReadCount >= 2`); `test_notEditablePolicy_rejectsInsertText_withNoDelegateNotifications`; `test_removeFromWindowWhileDragging_stopsEveryDisplayLink` (drives `willMove(toWindow: nil)` and asserts no `CADisplayLink` remains — the scenario with **no test at all** in the legacy suite today).

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Implement the responder routing** with the lifecycle client consulted before each transition, and `kernelInteraction?.resignedFirstResponder()` called on resign.

4. - [ ] **Step 4: Run and see it pass.** 5 tests on K3.

5. - [ ] **Step 5: Add the family-8 cases to the shared suite and run both backends.** Append `// MARK: - Family 8: responder lifecycle`: `test_becomeFirstResponderSucceedsOnAnEditableCanvas`, `test_resignFirstResponderEndsEditing`, `test_notEditableRejectsInsertText`. `LegacyBackendSemanticTests` on K1 and `IDBackendSemanticTests` on K3 — both green. (`BackendEditPolicyTests` stays legacy-only; the ID-side policy assertions are `IDBackendFamily8Tests`.)

6. - [ ] **Step 6: Commit.** `git commit -m "feat(inputdec): family 8 — responder lifecycle"`

### Task C12: Family 9 — touch interaction and selection

**Files:** `IDTextEditorBackend+Interaction.swift`, `Private/TGRichTextInputDecCanvasCallbacks.m` (the three interaction-host thunks); Test: `IDBackendFamily9Tests.swift`

**Interfaces:**
- Consumes (kernel): `IDUIKitInteractionCapability.setSelectionActive(_:visible:)`, `.selectionChanged()`, `.setNeedsSelectionDisplayUpdate()`, `.setGestureRecognizersEnabled(_:)`, `.clearGestureRecognizersForced(_:)`, `.selectWord()`, `.selectAll(_:)`, `.detach()`.
- Consumes (preflight): `TGRichTextInputDecHostPreflight.requireInteractionHost(_:stage:)` — validates `interactionAssistant`, `_textInputViewForAddingGestureRecognizers`, `selectionContainerView` on the canvas class.
- Produces: the three canvas thunks and the interaction witnesses.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily9Tests`: `test_interactionCapabilityIsConstructedOnlyAfterTheHostPreflightPasses`; `test_interactionContainerViewIdentityIsStableForTheBackendLifetime` (record `ObjectIdentifier` at attach and after 50 mutations); `test_tapPlacesTheCaretThroughTheGeometryClient`; `test_selectWordRoutesThroughTheInteractionCapability`; `test_detachCancelsGesturesBeforeTearingDownPresentation`.

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Install the three interaction-host thunks** (`interactionAssistant`, `_textInputViewForAddingGestureRecognizers`, `selectionContainerView`). `interactionAssistant` returns `kernelInteraction.privateAssistant`; the other two return the canvas and the presentation client's `interactionContainerView`.

4. - [ ] **Step 4: Force the container view at attach.** `selectionChromeContainer` is `lazy` on the canvas today (`DocumentCanvasView.swift:386`), so the adapter must touch `host.presentationClient.interactionContainerView` during `attach` or the identity test fails on first use.

5. - [ ] **Step 5: Add `.capabilityInteraction` to `requestedCapabilities`** and construct `kernelInteraction` in `attach(to:)` after the input capability.

6. - [ ] **Step 6: Check Telegram's own drag-autoscroll for conflict.** With the `interaction` capability active, `UITextInteractionAssistant` owns the selection gestures while `DocumentCanvasView.swift:1392-1449` still runs its own drag auto-scroll. Run the manual check "drag a selection handle to the screen edge" (Stage D checklist item 11) **now**, before proceeding, and record the result in `DIVERGENCES.md`. If they fight, the resolution is to disable Telegram's link while `kernelInteraction` is attached, not to request `autoscrollEntry` (decision 6: settle this empirically, here).

7. - [ ] **Step 7: Run and see it pass.** 5 tests on K3.

8. - [ ] **Step 8: Commit.** `git commit -m "feat(inputdec): family 9 — touch interaction and selection"`

### Task C13: Family 10 — floating cursor (autoscroll deferred)

**Files:** `IDTextEditorBackend+Interaction.swift`; Test: `IDBackendFamily10Tests.swift`

**Interfaces:**
- Consumes (kernel): `IDUIKitInteractionCapability.beginFloatingCursorAtPoint(_:)`, `.updateFloatingCursorAtPoint(_:animated:)`, `.endFloatingCursor()`.
- Produces: `beginFloatingCursor(at:)`, `updateFloatingCursor(at:)`, `endFloatingCursor()` routing.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily10Tests`: `test_beginFloatingCursorMarksTheStateComposing_andSuppressesSelectedTextRangeWrites`; `test_updateFloatingCursorForwardsThePointVerbatim`; `test_endFloatingCursorLeavesACollapsedCaret`; `test_uikitRangePushesDuringTheFloatingCursorDoNotBecomeASelection` (pins the load-bearing behavior at `DocumentCanvasView+UITextInput.swift:149`).

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Add `.capabilityFloatingCursor` to `requestedCapabilities`.**

4. - [ ] **Step 4: Route the three witnesses.** Note the signature mismatch: UIKit's real witness is `updateFloatingCursor(at:)` with **no** `animated:` (implemented at `DocumentCanvasView+FloatingCursor.swift:41`), while the kernel's method is `updateFloatingCursorAtPoint:animated:`. Pass `animated: true`, matching what the private assistant does for the system control, and record it in `DIVERGENCES.md`. This is the one member that cannot be a one-line router in either direction (seam deviation D2).

5. - [ ] **Step 5: Record the autoscroll deferral.** Add to `DIVERGENCES.md`: `autoscrollEntry` is not requested; `startAutoscroll:` in InputDec reads `self.adjustedContentInset` / `contentSize` / `contentOffset`, i.e. it assumes the first responder **is** the scroll view, and Telegram's canvas is a `UIView` inside `GripYieldingScrollView`. Telegram's own drag-autoscroll keeps running. The ABI witness implements the two selectors so the manifest rows still validate, but they return `NO` / do nothing.

6. - [ ] **Step 6: Run and see it pass.** 4 tests on K3.

7. - [ ] **Step 7: Commit.** `git commit -m "feat(inputdec): family 10 — floating cursor (autoscroll deliberately deferred)"`

### Task C14: Family 11 — spellchecking and annotations

**Files:** the bridge header (annotation group), `TGRichTextInputDecLayoutController.m`, the private-callbacks category; Test: `IDBackendFamily11Tests.swift`

**Interfaces:**
- Consumes: `RichTextInputAnnotationClient.annotatedSubstring(in:revision:)`, `.annotationValue(for:at:revision:)`, `.addAnnotation(_:value:in:revision:)`, `.removeAnnotation(_:in:revision:)`, `.addRenderingAttributes(_:in:revision:)`, `.removeRenderingAttributes(_:in:revision:)`, `.invalidateTemporaryAttributes(in:revision:)`.
- Consumes (kernel): the `checking` capability (`setContinuousSpellCheckingEnabled:` / `continuousSpellCheckingEnabled`).
- Produces: the seven annotation callbacks and the two spellchecking thunks.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** `IDBackendFamily11Tests`: `test_theSevenAnnotationCallbacksMapOneToOneOntoTheAnnotationClient` (a table-driven test, one row per callback, asserting the client saw exactly one matching call); `test_annotationWritesCarryTheDocumentRevision`; `test_spellCheckingToggleReachesTheCanvasState` (`setContinuousSpellCheckingEnabled:` → `canvas.isSpellCheckingEnabled`); `test_annotationRangesAreNotRebasedAcrossAnEdit_documentedDivergence` (pins the *existing* Telegram behavior at `DocumentCanvasView.swift:486-488`, where annotation ranges deliberately do not shift — the spec wants explicit rebase-or-clear, and repairing it is a behavior change forbidden during extraction).

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Add `.capabilityChecking` to `requestedCapabilities`** and install the two spellchecking thunks.

4. - [ ] **Step 4: Implement the seven annotation callbacks** on the layout controller. They map almost 1:1 — the spec's annotation client was written from this list.

5. - [ ] **Step 5: Record the annotation-rebase divergence** in `DIVERGENCES.md`, citing `DocumentCanvasView.swift:486-488`.

6. - [ ] **Step 6: Run and see it pass.** 4 tests on K3.

7. - [ ] **Step 7: Verify the pre-existing Swift private-API client still works.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/NativeTextCheckingLiveTests`. `DocumentCanvasView+NativeTextCheckingClient.swift:90-126` vends five `@objc` private selectors on the canvas; those must keep functioning under the ID subclass, which inherits them. If the installed thunks collide with any of the five, that is a **stop** — resolve by renaming the thunk target, never by removing the pre-existing client.

8. - [ ] **Step 8: Commit.** `git commit -m "feat(inputdec): family 11 — spellchecking and annotations"`

---

## Stage D — full green under both layout engines, plus the manual pass

**Deliverable:** `IDBackendSemanticTests` passes the same inherited bodies `LegacyBackendSemanticTests` does, under TextKit 1 and TextKit 2; the differential trace runner shows both backends producing identical semantic event logs for every scenario; and the 22-item real-keyboard checklist has been run by a human on a physical device.

### Task D1: Extend `matrix.sh` to the `.inputDec` backend

**Files:**
- Modify: `…/RichTextEditor/Scripts/matrix.sh`
- Test: the script's own exit code

**Interfaces:**
- Consumes: `iostest.sh`'s `DEVICE`, `TK1`, and `EXTRA` passthroughs; `BlockLayoutBackend.forceTextKit1` via `RTE_FORCE_TK1`; the existing `ROOTS`/`discover()`/`MATRIX_MIN_SUITES` machinery in `Scripts/matrix.sh` (seam Task 9 Step 6, plus the `InputDec` root added by Task B1 Step 4 and the regex alternation added by Task C3).
- Produces: `matrix.sh` running both engines over the **discovered** suite set, with a name-derived device split — suites matching `RichTextEditorUIKitTests/ID*` on K3 (the certified iOS 26.5 / 23F73 band), everything else on K1. `discover()` is preserved verbatim; this task adds no hand-maintained list.

**Steps:**

1. - [ ] **Step 1: Confirm the engine override is orthogonal to the OS.** `BlockLayoutBackend.forceTextKit1` is a process-level override, not an OS gate, so TextKit 1 **can** be exercised on iOS 26.5. Verify with a one-off: `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 TK1=1 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendFamily2Tests` and confirm the geometry tests run (not skip).

2. - [ ] **Step 2: Read the existing script and record its discovered count.** `cd "$PKG" && cat Scripts/matrix.sh && Scripts/matrix.sh 2>&1 | head -1`. **There is no hand-maintained `SUITES` list to copy.** Seam Task 9 Step 6 wrote `SUITES="${SUITES:-$(discover)}"`, where `discover()` greps `^final class [A-Za-z0-9_]+: (XCTestCase|BackendSemanticContractCases)` (the alternation added by Task C3) over the directories in `ROOTS` — `Characterization`, `InputBackend`, `Support`, plus the `InputDec` root added by Task B1 Step 4. Write down the `=== matrix over <N> suites` number; Step 4 uses it as the floor. This task **edits the device selection only** and must not replace `discover()` with a literal list: a literal list is precisely the failure mode the seam closed, and it would silently drop the ~30 legacy suites the discovery finds.

3. - [ ] **Step 3: Add the device split, leaving discovery untouched.** Edit `Scripts/matrix.sh` in place. Keep the shebang, `set -o pipefail`, `ROOTS`, `discover()`, the `SUITES=`/`COUNT=`/`MATRIX_MIN_SUITES` block exactly as they are, and replace only the trailing `for engine … Scripts/iostest.sh "$s"` loop with:
   ```sh
   # Device split. The kernel is CERTIFIED against iOS 26.5 / 23F73, so every ID suite runs on K3 to
   # get the certified-band answer. Everything else runs on K1 (the repo's designated testing sim).
   # The split is derived from the discovered suite NAME — no second list to keep in sync, and a new
   # ID suite lands on the right device for free.
   #
   # DECISION 2 (2026-08-17) changed what a K1 run of an ID suite MEANS. The gate is now a 17.0
   # floor, not an exact build match, so on K1 `isSupported()` may well answer YES and the ID suites
   # will really execute rather than XCTSkip. That is not a bug — it is the first evidence of how far
   # the certified ABI travels, and Task D5 requires it to be recorded. Do NOT "fix" this by pinning
   # ID suites away from K1; if anything, an uncertified-OS run is now the more informative leg.
   K1=CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9
   K3=FA6F7462-AA97-42FE-9E57-8DA0593CE756
   fail=0
   for engine in tk2 tk1; do
     if [ "$engine" = "tk1" ]; then export TK1=1; else unset TK1; fi
     for s in $SUITES; do
       case "$s" in
         RichTextEditorUIKitTests/ID*) leg=inputDec; DEVICE=$K3 ;;
         *)                            leg=legacy;   DEVICE=$K1 ;;
       esac
       export DEVICE
       echo "=== $engine $leg $s"
       Scripts/iostest.sh "$s" || fail=1
     done
   done
   exit $fail
   ```
   `LegacyBackendSemanticTests` deliberately does not match `ID*` and so runs on K1; `IDBackendSemanticTests` does and runs on K3. Do **not** hand-add `RouterWitnessTests` or `InputTraceCharacterizationTests` anywhere — neither class exists, and discovery cannot invent them.

4. - [ ] **Step 4: Prove no suite was dropped, with the floor rather than a diff.** A textual before/after diff of the script is **vacuous** here: the pre-edit script contains no suite names at all (they are discovered at run time), so `comm -23` over `grep -o "RichTextEditorUIKitTests/…"` would compare two empty sets and pass while every suite vanished. Use the count instead, with `<N>` the number Step 2 printed:
   ```sh
   cd "$PKG" && MATRIX_MIN_SUITES=<N> Scripts/matrix.sh 2>&1 | head -1
   ```
   The first line must report a count `>= <N>` and the script must not exit 2. If it exits 2, the edit damaged `ROOTS` or `discover()`.

5. - [ ] **Step 5: Prove each leg is non-empty and lands on the right device.** Discovery guarantees every named class exists (it read the names *out of* the class declarations), so the risk is not a typo — it is a leg that silently matched nothing:
   ```sh
   cd "$PKG" && Scripts/matrix.sh 2>&1 | grep -c "tk2 inputDec"   # must be >= 17
   cd "$PKG" && Scripts/matrix.sh 2>&1 | grep -c "tk2 legacy"     # must equal the seam's count
   ```
   The 17 is this plan's ID suites: `IDHarnessTests`, `IDFakeClientHarnessTests`, `IDBackendSemanticTests`, `IDBackendAttachDetachTests`, `IDBackendIntentLatchTests`, `IDBackendDifferentialTraceTests` and `IDBackendFamily1Tests`…`IDBackendFamily11Tests`. A zero on either line means the `case` pattern or a discovery root is wrong.

6. - [ ] **Step 6: Run it.** `cd "$PKG" && MATRIX_MIN_SUITES=<N> Scripts/matrix.sh; echo "exit=$?"`. Expect `exit=0`. Budget wall time: two engines × ~50 suites, serialized.

7. - [ ] **Step 7: Triage any TK1-only failures honestly.** The only legitimate skips are the three documented TK1 trade-offs (no spoiler text-hiding, no loupe, no inline predictions). Anything else is a real divergence — fix it or record it in `DIVERGENCES.md` with a named owner, never `XCTSkip` it.

8. - [ ] **Step 8: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Scripts/matrix.sh && \
   git commit -m "test(inputdec): matrix runs both backends on both layout engines"
   ```

### Task D2: The differential trace runner

**There is no JSON golden corpus in this programme.** The seam plan's characterization is in-source XCTAssert expectations under `Tests/RichTextEditorUIKitTests/Characterization/`; it creates no `Fixtures/` directory, no `RichTextInputTrace` Codable type, no `TraceCorpus`, and no `RTE_RECORD_TRACES` workflow. So backend equivalence is established the way the available machinery actually supports it: **run the same scenario against both backends in one process and compare the two recorded event logs directly.** That is strictly stronger than comparing two checked-in files, because there is no recording step in which a divergence can be normalised away, and it needs no re-record workflow at all.

**Files:**
- Create: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendDifferentialTraceTests.swift`
- Test: same file

**Interfaces:**
- Consumes: `RichTextInputEventLog` and its `kinds` projection (seam Task 22), `makeIDFakeClientHarness` (Task C2), `RichTextInputBackendKind`.
- Produces:
  ```swift
  struct IDTraceScenario { let name: String; let body: @MainActor (IDFakeClientHarness) -> Void }
  enum IDTraceProjection { static func semantic(_ log: RichTextInputEventLog) -> [String] }
  func makeLegacyFakeClientHarness(paragraphs: [String], width: CGFloat) -> IDFakeClientHarness
  ```

**Steps:**

1. - [ ] **Step 1: Generalise the fake-client harness over the backend kind.** `makeIDFakeClientHarness` (Task C2) hard-codes `IDDocumentCanvasView` + `IDTextEditorBackend`. Add a `kind:` parameter defaulting to `.inputDec`, and a thin `makeLegacyFakeClientHarness` alias, so one scenario body can be driven twice:
   ```swift
   @MainActor
   @available(iOS 17.0, *)
   func makeIDFakeClientHarness(kind: RichTextInputBackendKind = .inputDec,
                                paragraphs: [String] = ["Alpha", "Beta"],
                                width: CGFloat = 300) -> IDFakeClientHarness {
       let log = RichTextInputEventLog()
       // Same detach/re-attach as the .inputDec-only version, now for either kind: the canvas
       // attaches its injected backend to itself in init, and the fake host wants it instead.
       let backend: any RichTextInputBackend =
           kind == .inputDec ? IDTextEditorBackend() : LegacyRichTextInputBackend()
       let canvas: DocumentCanvasView = kind == .inputDec
           ? IDDocumentCanvasView(inputBackend: backend)
           : DocumentCanvasView(inputBackend: backend)
       canvas.frame = CGRect(x: 0, y: 0, width: width, height: 600)
       backend.detach()

       let host = FakeInputHost(hostInputView: canvas, log: log, text: paragraphs.joined(separator: "\n"))
       try! backend.attach(to: host)
       return IDFakeClientHarness(backend: backend, canvas: canvas, host: host, log: log)
   }
   ```
   Note this deliberately does **not** go through `RichTextInputCanvasFactory`: the factory constructs the backend itself, and this harness needs to hold the instance in order to re-attach it. The factory's own selection logic is covered by `CanvasFactoryTests` (Task B3).

   `IDFakeClientHarness.backend` widens from `IDTextEditorBackend` to `any RichTextInputBackend`, and `canvas` from `IDDocumentCanvasView` to `DocumentCanvasView`. Update `storageFacade` to `(backend as? IDTextEditorBackend)?.storageFacadeForTesting` (now optional), and fix the three `IDFakeClientHarnessTests` assertions that named the concrete types — `test_harnessAttachesTheIDBackendToFakeClients` becomes `XCTAssertTrue(h.backend is IDTextEditorBackend)`, and `test_storageFacadeIsVendedForInputDecAndNilForLegacy` moves here from Task C1 with `kind:` driving it.

2. - [ ] **Step 2: Write the projection and the scenario type.** The projection is what makes the comparison meaningful: geometry legitimately differs (font metrics, and the two backends realize block views differently), so it is dropped; everything semantic is kept and compared exactly.
   ```swift
   /// The comparable slice of an event log. Geometry events are dropped — `caretRect` and
   /// `selectionRects` values are layout facts, not semantic ones, and the shared semantic suite
   /// already pins the ones that matter. Everything else is compared EXACTLY: an ordering
   /// difference between backends is precisely the bug this test exists to find.
   enum IDTraceProjection {
       static func semantic(_ log: RichTextInputEventLog) -> [String] {
           log.kinds.filter { $0 != "geometryQuery" && $0 != "presentationInvalidate" }
       }
   }

   /// One named, replayable interaction. The body runs against a freshly built harness and must
   /// be deterministic: no timers, no `DispatchQueue.main.async`, no window hosting.
   struct IDTraceScenario {
       let name: String
       let body: @MainActor (IDFakeClientHarness) -> Void
   }
   ```

3. - [ ] **Step 3: Write the failing comparison test with the five structural scenarios.** These five are the ones the intent latch can silently get wrong, and they are the reason this task exists at all. Each scenario seeds its caret with `setSelectionForTesting(anchor:head:)` — the seam's test-only selection-write seam (seam Task 1, repointed at the backend by Task 40a). There is **no** `canvas.setSelection(anchor:head:reason:)`: the canvas's own writers are `setSelectionHead(global:)`/`setSelectionAnchor(global:)`, and the backend's is `setSelection(_ selection: RichTextCanonicalSelection, reason:)`. Create `Tests/RichTextEditorUIKitTests/InputDec/IDBackendDifferentialTraceTests.swift`:
   ```swift
   #if canImport(UIKit)
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   /// The equivalence argument, in one place: the same scenario, both backends, one process, and
   /// the two semantic event logs must be identical.
   @available(iOS 17.0, *)
   @MainActor
   final class IDBackendDifferentialTraceTests: XCTestCase {

       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
       }

       static let structuralScenarios: [IDTraceScenario] = [
           IDTraceScenario(name: "type-one-char") { h in
               h.canvas.setSelectionForTesting(anchor: 5, head: 5)
               h.canvas.insertText("x")
           },
           IDTraceScenario(name: "return-splits-paragraph") { h in
               h.canvas.setSelectionForTesting(anchor: 5, head: 5)
               h.canvas.insertText("\n")
           },
           IDTraceScenario(name: "backspace-merges-paragraphs") { h in
               h.canvas.setSelectionForTesting(anchor: 6, head: 6)
               h.canvas.deleteBackward()
           },
           IDTraceScenario(name: "delete-over-selection") { h in
               h.canvas.setSelectionForTesting(anchor: 2, head: 7)
               h.canvas.deleteBackward()
           },
           IDTraceScenario(name: "cjk-compose-commit") { h in
               h.canvas.setSelectionForTesting(anchor: 5, head: 5)
               h.canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
               h.canvas.unmarkText()
           },
       ]

       private func trace(_ scenario: IDTraceScenario,
                          _ kind: RichTextInputBackendKind) -> [String] {
           let h = makeIDFakeClientHarness(kind: kind)
           defer { h.tearDown() }
           h.log.reset()
           scenario.body(h)
           return IDTraceProjection.semantic(h.log)
       }

       func test_structuralScenariosProduceTheSameSemanticTraceOnBothBackends() {
           for scenario in Self.structuralScenarios {
               let legacy = trace(scenario, .legacy)
               let inputDec = trace(scenario, .inputDec)
               XCTAssertEqual(legacy, inputDec,
                              "scenario '\(scenario.name)' diverges\n  legacy:   \(legacy)\n"
                              + "  inputDec: \(inputDec)")
           }
       }

       /// A scenario whose legacy trace is EMPTY proves nothing. This is the anti-vacuity guard:
       /// without it, a scenario body that silently no-ops passes the comparison forever.
       func test_everyScenarioProducesANonEmptyLegacyTrace() {
           for scenario in Self.structuralScenarios {
               XCTAssertFalse(trace(scenario, .legacy).isEmpty,
                              "scenario '\(scenario.name)' recorded nothing — it is vacuous")
           }
       }

       /// Determinism: the same scenario run twice on the same backend must trace identically, or
       /// a cross-backend difference cannot be attributed.
       func test_tracesAreDeterministicWithinABackend() {
           for scenario in Self.structuralScenarios {
               XCTAssertEqual(trace(scenario, .inputDec), trace(scenario, .inputDec),
                              "scenario '\(scenario.name)' is not deterministic")
           }
       }
   }
   #endif
   ```

4. - [ ] **Step 4: Run it and read every divergence.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendDifferentialTraceTests`. Expect `test_everyScenarioProducesANonEmptyLegacyTrace` and `test_tracesAreDeterministicWithinABackend` green immediately. For `test_structuralScenariosProduceTheSameSemanticTraceOnBothBackends`, read each printed pair line by line. **`return-splits-paragraph` and `backspace-merges-paragraphs` are the intent-latch tells:** if the ID trace shows a `documentPrepare(mutation: "replaceText…")` where legacy shows `insertParagraphBreak` / `deleteBackward`, the latch (Task C7) is wrong. Fix the latch; never adjust the projection to hide it.

5. - [ ] **Step 5: Run it under TextKit 1 too.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 TK1=1 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendDifferentialTraceTests` — same result. The projection drops geometry precisely so this is engine-independent; if it is not, the projection is letting a layout fact through.

6. - [ ] **Step 6: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests && \
   git commit -m "test(inputdec): in-process semantic trace equivalence, five structural scenarios"
   ```

### Task D3: The remaining differential scenarios

**Files:**
- Modify: `Tests/RichTextEditorUIKitTests/InputDec/IDBackendDifferentialTraceTests.swift`
- Test: same file

**Interfaces:**
- Consumes: `IDTraceScenario`, `IDTraceProjection` (Task D2).
- Produces: three further scenario groups and one test method each.

**Steps:**

1. - [ ] **Step 1: Add the selection group.** A `selectionScenarios` array plus `test_selectionScenariosMatch`, driven exactly like Step 3's method: `reverse-drag-selection` (set anchor 8 / head 2, then extend to head 0), `select-all-then-collapse`, `programmatic-selection-then-type`, `caret-across-paragraph-boundary`.

2. - [ ] **Step 2: Add the marked-text group.** `markedScenarios` plus `test_markedScenariosMatch`: `compose-then-cancel` (setMarkedText then `unmarkText` with an empty replacement), `compose-then-structural-edit` (setMarkedText then an external `synchronizeAfterExternalChange`), `compose-then-resign`.

3. - [ ] **Step 3: Add the command group.** `commandScenarios` plus `test_commandScenariosMatch`: `copy-then-paste`, `cut-collapses-the-selection`, `paste-over-a-selection`, `undo-after-typing`.

4. - [ ] **Step 4: Extend the anti-vacuity and determinism guards to every group.** Change both guard tests to iterate `Self.allScenarios` (the concatenation of the four arrays) rather than `structuralScenarios`, and add
   ```swift
       func test_theScenarioListIsTheUnionOfEveryGroup() {
           XCTAssertEqual(Self.allScenarios.count,
                          Self.structuralScenarios.count + Self.selectionScenarios.count
                          + Self.markedScenarios.count + Self.commandScenarios.count)
           XCTAssertEqual(Set(Self.allScenarios.map(\.name)).count, Self.allScenarios.count,
                          "duplicate scenario name — one of them is shadowing the other")
       }
   ```
   so a group added later and forgotten in `allScenarios` fails loudly.

5. - [ ] **Step 5: Run the whole suite on both engines.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendDifferentialTraceTests` then the same with `TK1=1`. Every group green on both.

6. - [ ] **Step 6: Record any accepted divergence.** A scenario that legitimately cannot match goes in `DIVERGENCES.md` **with its two traces pasted in**, and is moved into an `acceptedDivergences` array that `test_theScenarioListIsTheUnionOfEveryGroup` also counts — never silently deleted.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests \
           submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/InputBackend/InputDec/DIVERGENCES.md && \
   git commit -m "test(inputdec): differential trace coverage for selection, marked text and commands"
   ```

### Task D4: The manual real-keyboard pass

**Files:**
- Create: `docs/superpowers/plans/2026-08-16-inputdec-manual-checklist-results.md`

**Interfaces:** none. This is a human task; no automation substitutes for it.

**Steps:**

1. - [ ] **Step 1: Build and install.** Build `--configuration=debug_arm64` for a physical iPhone running the certified OS build (26.5 / 23F73 — confirm with Settings ▸ General ▸ About). If no device runs that build, run on the K3 simulator and record explicitly that the device pass is outstanding.

2. - [ ] **Step 2: Turn the flag on.** Debug Settings ▸ "Force Text Field v2" **on**, and (once Stage E Task E1 lands) "Text Field v2: InputDec backend" **on**. Before E1, use the Demo app with `.inputDecRequired`.

3. - [ ] **Step 3: Run items 1-6 (autocorrect, prediction, IME).** Type a sentence with a typo and accept the suggestion; reject one; accept an inline prediction by tap; move the caret with a prediction showing; compose and commit Japanese kana; interrupt a Simplified Chinese composition by tapping elsewhere. Record each as pass/fail with a screenshot.

4. - [ ] **Step 4: Run items 7-9 (structural Return/Backspace).** Return twice in a blockquote; Backspace at the start of the second paragraph; Backspace at the start of a table's first cell.

5. - [ ] **Step 5: Run items 10-16 (loupe, handles, BiDi, tables, floating cursor).** Long-press to raise the loupe and drag; drag a handle to the screen edge; select right-to-left, copy, paste; type Hebrew into an empty paragraph; scroll a wide table row then tap a cell; long-press the spacebar and drag; drag the floating cursor to the edge.

6. - [ ] **Step 6: Run items 17-22 (spelling, paste, detach, Select All, rotation).** Tap a misspelling and pick a guess, then Undo; toggle spellchecking off; paste a large markdown fragment and Undo twice; push another screen while focused and return; `Select All` in a ~500-block document; rotate with an active selection.

7. - [ ] **Step 7: Write the results file** with one line per item: item number, pass/fail, and for every failure the exact reproduction and whether the legacy backend does the same thing. **A failure that the legacy backend shares is not an InputDec bug** — file it separately.

8. - [ ] **Step 8: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add docs/superpowers/plans/2026-08-16-inputdec-manual-checklist-results.md && \
   git commit -m "docs(inputdec): manual real-keyboard checklist results"
   ```

### Task D4b: Run the InputDec differential corpus against `.inputDec` (decision 5)

Stage 1's Phase 0b vendored `Tests/TextInputDifferential/` and ran its 68-scenario / 612-transaction corpus against the **legacy** backend, producing `PKG/docs/input-backend-differential-baseline.md`. This task adds the fifth host kind and re-runs the same corpus against the ID backend. **This is the task that answers the original question — "do InputDec's tests pass against RichTextEditor" — for the ported backend.**

It is also, after decision 2 widened the OS gate from one certified build to a 17.0 floor, the *only* instrument that can catch a semantic drift on an uncertified OS (Honest constraints §1). Step 5's multi-OS run is therefore mandatory, not optional.

**Files:**
- Modify: `PKG/Tests/RichTextEditorUIKitTests/Differential/ObjC/IDTextInputScenario.h` (one enum case)
- Modify: `PKG/Tests/RichTextEditorUIKitTests/Differential/ObjC/IDTextInputTestHost.m`
- Modify: `PKG/Tests/RichTextEditorUIKitTests/Differential/TelegramDifferentialHost.swift`
- Create: `PKG/Tests/RichTextEditorUIKitTests/InputDec/IDDifferentialTests.swift`
- Modify: `PKG/docs/input-backend-differential-baseline.md`

**Interfaces:**
- Consumes: `IDTextInputTestHost`, `IDTextInputDifferentialRunner`, `IDTextInputScenario`, `TelegramDifferentialHost` (all stage 1, Phase 0b); `RichTextInputCanvasFactory`; `TGRichTextInputDecStorageFacade` (Task C7).
- Produces: `IDTextInputHostKindTelegramInputDec` (a fifth enum case), `TelegramDifferentialHost.makeInputDecInput(initialText:initialSelection:)`, and `IDDifferentialTests` with one test per family.

**Steps:**

1. - [ ] **Step 1: Add the fifth enum case.** In `IDTextInputScenario.h`, append `IDTextInputHostKindTelegramInputDec` **after** `IDTextInputHostKindTelegram`, so no existing raw value moves. Stage 1 Task 9b appended the fourth for the same reason.

2. - [ ] **Step 2: Add the Swift factory.** In `TelegramDifferentialHost.swift`, add a sibling to stage 1's `makeInput`, differing only in that it builds the canvas through `RichTextInputCanvasFactory` with `.inputDecRequired` (not `.inputDecIfSupported` — a silent fall back to legacy here would make the whole run a re-test of stage 1 while appearing to test the ID backend):
   ```swift
       @objc @MainActor static func makeInputDecInput(initialText: String,
                                                      initialSelection: NSRange) -> UIView? {
           guard let canvas = RichTextInputCanvasFactory.makeCanvas(
                   preference: .inputDecRequired, mapper: .init()) else { return nil }
           canvas.setParagraphs(initialText.components(separatedBy: "\n"))
           canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
           canvas.layoutIfNeeded()
           canvas.setSelectionForTesting(anchor: initialSelection.location,
                                         head: initialSelection.location + initialSelection.length)
           return canvas
       }
   ```
   Returning `nil` rather than falling back is deliberate: the ObjC host turns it into a `hostWithKind:` failure, and Step 4's `XCTUnwrap` reports it as an explicit error.

3. - [ ] **Step 3: Wire the ObjC branch, and give it a real `observedTextStorage`.** In `IDTextInputTestHost.m`, accept the fifth kind by runtime-looking-up `makeInputDecInput`. Unlike the legacy host kind, set `host.observedTextStorage` to the ID backend's storage façade (Task C7) and `host.comparesAnnotations = YES`. **This is the asymmetry stage 1's `DIFFERENTIAL.md` recorded**: `.inputDec` can answer the storage-dependent comparison fields (`blocks`, `inlineRuns`) that the legacy host declines, so the two host kinds run *different field sets* and their difference counts are not directly comparable. Step 6 handles that.

4. - [ ] **Step 4: Write the four failing family tests.** Create `Tests/RichTextEditorUIKitTests/InputDec/IDDifferentialTests.swift`, mirroring stage 1's `LegacyDifferentialTests` exactly but constructing the runner over `{Stock, TelegramInputDec}` and consulting an `IDDifferentialExpectations` table. Run: `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDDifferentialTests`. Expected: failures — this is the first time the corpus has driven the ID backend.

5. - [ ] **Step 5: Triage on K3, then repeat on K1 — both are required.** Classify every difference exactly as stage 1 Task 9c Step 4 did: (a) a real ID-backend divergence from stock, (b) a harness artifact, (c) an unsupported scenario. Then **re-run the whole corpus on K1** (iOS ≠ 26.5). Under decision 2 the ID backend may well be selected there, and a difference that appears on K1 but not K3 is the single most valuable signal this programme can produce: it is a semantic ABI drift that `isSupported()`'s type-encoding check cannot see. Any such difference is a **stop** — record it and escalate before Stage E, do not add it to the expectations table.

6. - [ ] **Step 6: Compare against the legacy baseline, field set by field set.** Append an `.inputDec` section to `PKG/docs/input-backend-differential-baseline.md` giving per-family scenario/difference counts for both K3 and K1. Compare only within the **shared** comparison fields — the ones the legacy host also answered — because the storage-dependent fields have no legacy number to compare to. State the shared-field set explicitly in the document. Any scenario green for legacy and red for `.inputDec` on a shared field is a port defect, and is the deliverable finding of this task.

7. - [ ] **Step 7: Commit.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git add submodules/TelegramUI/Components/RichTextEditor/Tests \
           submodules/TelegramUI/Components/RichTextEditor/docs/input-backend-differential-baseline.md && \
   git commit -m "test(inputdec): run InputDec's 68-scenario corpus against the ID backend

Fifth IDTextInputHostKind, built through the canvas factory with
.inputDecRequired so a fallback cannot masquerade as a pass. Run on both the
certified band (K3) and an uncertified one (K1) -- decision 2 made the second
leg the only check that can see semantic ABI drift. Per-family counts for both
legs appended to the differential baseline, compared on shared fields only."
   ```

### Task D5: Stage D exit gate

**Files:** none created; this task only runs and records verification.

**Interfaces:** none.

**Steps:**

1. - [ ] **Step 1: `Scripts/matrix.sh` exits 0, with a floor.** `cd "$PKG" && MATRIX_MIN_SUITES=<N+19> Scripts/matrix.sh; echo "exit=$?"`, where `<N>` is the count the prerequisite gate item 9 recorded and `+19` is this plan's added suites (`CanvasSubclassPerformanceTests`, `LegacyBackendSemanticTests`, and the 17 `ID*` suites Task D1 Step 5 enumerates). Without the floor, "the matrix exits 0" is also what a matrix that discovered nothing prints.

2. - [ ] **Step 2: Full legacy suite unchanged on K1.** `cd "$PKG" && Scripts/iostest.sh 2>&1 | tail -5` — zero failures, and the executed count equals the Stage B gate's plus every `.inputDec` test added since.

3. - [ ] **Step 3: No pinned legacy behavior changed.** The seam plan's characterization suites are the record; there is no JSON corpus. Both halves, so a wrong path cannot pass silently:
   ```sh
   cd "$PKG" && test "$(git ls-files Tests/RichTextEditorUIKitTests/Characterization/ | wc -l | tr -d ' ')" -gt 0 \
     || { echo "Characterization path is wrong — STOP"; exit 1; }
   git diff --stat inputdec-baseline -- Tests/RichTextEditorUIKitTests/Characterization/
   ```
   Non-zero file count, empty diff.

4. - [ ] **Step 4: The differential suite is non-vacuous.** `cd "$PKG" && DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/IDBackendDifferentialTraceTests 2>&1 | grep "Executed"` — the executed count must be non-zero and no test may have been skipped. A wholesale `XCTSkipUnless` skip here means the run was on the wrong simulator, not that the backends agree.

5. - [ ] **Step 5: Full app build green.** `Make.py build --configuration=debug_sim_arm64` → `BUILD SUCCEEDED`.

6. - [ ] **Step 6: Every open `DIVERGENCES.md` entry has an owner and a decision** (accepted / to-fix / blocking).

7. - [ ] **Step 7: Tag.**
   ```sh
   cd /Users/isaac/build/telegram/telegram-ios && \
   git commit --allow-empty -m "chore(inputdec): Stage D gate green" && \
   git tag inputdec-stage-d-green
   ```

---

## Stage E — rollout

**Deliverable:** the backend is reachable from Debug Settings on internal builds, defaults off, and has a comparison mode. No server flag, no default-on, in this plan.

### Task E1: The experimental setting and the Debug Settings switch

**Files:**
- Modify: `/Users/isaac/build/telegram/telegram-ios/submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift`
- Modify: `/Users/isaac/build/telegram/telegram-ios/submodules/DebugSettingsUI/Sources/DebugController.swift`
- Test: full app build + manual toggle

**Interfaces:**
- Consumes: `ExperimentalUISettings`, `ApplicationSpecificSharedDataKeys.experimentalUISettings`.
- Produces: `ExperimentalUISettings.inputDecTextBackend: Bool` (default `false`).

**Steps:**

1. - [ ] **Step 1: Add the stored property.** In `ExperimentalUISettings.swift`, six edits mirroring `coreListChatBackend` exactly:
   - after line 76 (`public var coreListChatBackend: Bool`) add `public var inputDecTextBackend: Bool`;
   - in `defaultSettings` (line 128) add `inputDecTextBackend: false`;
   - in the memberwise `init` parameter list (line 181) add `inputDecTextBackend: Bool`;
   - in the init body (line 231) add `self.inputDecTextBackend = inputDecTextBackend`;
   - in `init(from:)` (line 285) add `self.inputDecTextBackend = try container.decodeIfPresent(Bool.self, forKey: "inputDecTextBackend") ?? false`;
   - in `encode(to:)` (line 339) add `try container.encodeIfPresent(self.inputDecTextBackend, forKey: "inputDecTextBackend")`.

2. - [ ] **Step 2: Build and fix every memberwise-init call site.** `Make.py build --continueOnError` and add the new argument wherever the compiler asks.

3. - [ ] **Step 3: Add the Debug Settings entry.** In `DebugController.swift`:
   - add `case inputDecTextBackend(Bool)` after line 100;
   - add `.inputDecTextBackend` to the stable-id switch at line 141 and the section switch at line 240;
   - add the item, copied from the `coreListChatBackend` block at line 1323:
     ```swift
             case let .inputDecTextBackend(value):
                 return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Text Field v2: InputDec backend", value: value, sectionId: self.section, style: .blocks, updated: { value in
                     let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                         transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                             var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                             settings.inputDecTextBackend = value
                             return EnginePreferencesEntry(settings)
                         })
                     }).start()
                 })
     ```
   - append the entry next to line 1612, gated to internal/debug builds using the `browserExperiment` pattern at lines 1613-1619:
     ```swift
             #if DEBUG
             entries.append(.inputDecTextBackend(experimentalSettings.inputDecTextBackend))
             #else
             if sharedContext.applicationBindings.appBuildType == .internal {
                 entries.append(.inputDecTextBackend(experimentalSettings.inputDecTextBackend))
             }
             #endif
     ```

4. - [ ] **Step 4: Build and install.** `Make.py build --configuration=debug_sim_arm64`, then the whole-`.app` copy onto K3.

5. - [ ] **Step 5: Verify the switch persists.** Drive the simulator with `mcp__XcodeBuildMCP__*`: open Debug Settings, toggle "Text Field v2: InputDec backend" on, force-quit, relaunch, confirm it is still on. Then toggle it back off. (Nothing consumes it yet — that is Task E2.)

6. - [ ] **Step 6: Commit.**
   ```sh
   git add submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift \
           submodules/DebugSettingsUI/Sources/DebugController.swift && \
   git commit -m "feat(debug): InputDec text-backend setting, internal builds only"
   ```

### Task E2: Thread the preference into the composer

**Files:**
- Modify: `…/RichTextEditor/Sources/RichTextEditorUIKit/RichTextEditorView.swift`
- Modify: `…/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift`
- Modify: `…/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/EditorViewPreferenceTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum RichTextEditorInputBackendPreference { case legacy, inputDecIfSupported, inputDecRequired }
  public convenience init(frame: CGRect)
  public init(frame: CGRect, inputBackend: RichTextEditorInputBackendPreference)
  ```

**Steps:**

1. - [ ] **Step 1: Write the failing test.**
   ```swift
   #if canImport(UIKit)
   import UIKit
   import XCTest
   @testable import RichTextEditorUIKit

   final class EditorViewPreferenceTests: XCTestCase {
       func test_defaultInitStillProducesTheLegacyCanvas() {
           XCTAssertTrue(type(of: RichTextEditorView().canvas) == DocumentCanvasView.self)
       }

       func test_explicitLegacyPreferenceProducesTheLegacyCanvas() {
           let editor = RichTextEditorView(frame: .zero, inputBackend: .legacy)
           XCTAssertTrue(type(of: editor.canvas) == DocumentCanvasView.self)
       }

       @available(iOS 17.0, *)
       func test_inputDecIfSupportedProducesTheIDCanvasWhenSupported() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
           let editor = RichTextEditorView(frame: .zero, inputBackend: .inputDecIfSupported)
           XCTAssertTrue(editor.canvas is IDDocumentCanvasView)
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** Expected: `extra argument 'inputBackend' in call`.

3. - [ ] **Step 3: Add the public enum and the init overload.** In `RichTextEditorView.swift`:
   ```swift
   /// Which input backend this editor should be built for. Deliberately a KIND, not a backend
   /// type: no backend type is part of this view's public API (spec lines 92-98). External
   /// consumers cannot implement a backend, only name one of these.
   @available(iOS 13.0, *)
   public enum RichTextEditorInputBackendPreference {
       case legacy
       /// Use the InputDec backend when the runtime supports it; fall back to legacy otherwise.
       case inputDecIfSupported
       /// Debug/comparison only: trap instead of falling back.
       case inputDecRequired
   }
   ```
   and
   ```swift
       public convenience override init(frame: CGRect) {
           self.init(frame: frame, inputBackend: .legacy)
       }

       public init(frame: CGRect, inputBackend: RichTextEditorInputBackendPreference) {
           self.canvas = RichTextInputCanvasFactory.make(inputBackend.internalPreference)
           super.init(frame: frame)
           commonInit()
       }
   ```
   with a private `internalPreference` mapping onto `RichTextInputBackendPreference`.

   **Do not transcribe the existing initializer body into the new initializer.** Extract it instead, in the same edit: everything in `public override init(frame:)` **after** `super.init(frame: frame)` (`RichTextEditorView.swift:240` through the closing `}` at `:276` — the `addSubview(scrollView)` line down to the `canvas.onResignedFirstResponder` assignment, ~11 statements and their comments) moves verbatim into a new `private func commonInit()` declared immediately below. The old `public override init(frame:)` is then replaced by the convenience initializer above, so the body exists exactly once and no copy can drift. `required init?(coder:)` at `:277` still `fatalError`s and is untouched.

4. - [ ] **Step 4: Thread it through the composer.** In `RichTextEditorChatInputNode.swift`, change line 43 from `private let editorView = RichTextEditorView()` to `private let editorView: RichTextEditorView` and assign it in `init` from a new `inputBackend:` parameter. In `ChatTextInputPanelNode.swift`, in the block at lines 868-872 that reads `forceNewTextInput`, add:
   ```swift
           if context.sharedContext.immediateExperimentalUISettings.inputDecTextBackend {
               self.richTextInputBackendPreference = .inputDecIfSupported
           }
   ```
   and pass `self.richTextInputBackendPreference` into `loadTextInputNode` → `RichTextEditorChatInputNode.init`.

5. - [ ] **Step 5: Leave the article editor on legacy.** `RichTextAttachmentScreen.swift:586` stays `RichTextEditorView()`. The article editor is a second surface with its own metrics contract and should not be the first thing exercised. Add a one-line comment saying so.

6. - [ ] **Step 6: Run and see it pass.** 3 tests, on K3 for the third.

7. - [ ] **Step 7: Build the app and smoke-test both states.** Toggle the Debug Setting on, force-quit, relaunch, open a chat, type. Then off, relaunch, type. Both must work; the ID path must be visibly identical.

8. - [ ] **Step 8: Commit.**
   ```sh
   git add submodules/TelegramUI/Components/RichTextEditor \
           submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer \
           submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode && \
   git commit -m "feat(inputdec): select the InputDec backend from the composer preference"
   ```

### Task E3: Comparison mode

**Files:**
- Create: `…/RichTextEditorUIKit/RichTextEditorView+DebugBackendComparison.swift`
- Modify: `…/RichTextEditorUIKit/RichTextEditorView.swift` (Step 3 — three access-level widenings and the `rewireCanvasCallbacks()` extraction; a stage-1 file, so it lands as its own commit)
- Test: `Tests/RichTextEditorUIKitTests/InputDec/BackendComparisonTests.swift`

**Interfaces:**
- Consumes: `RichTextEditorView.document` (a settable `public var Document` — `RichTextEditorView.swift:279`; there is **no** `setDocument(_:)`), `DocumentCanvasView.setSelectionForTesting(anchor:head:)` (seam Task 1; Task 40a repoints it at the backend), `DocumentCanvasView.inputBackend` (`private(set) var`, seam Task 20) and its `state` / `detach()` / `setSelection(_:reason:)` members, `DocumentCanvasView.undoManagerOverride` (`DocumentCanvasView.swift:522`), `RichTextInputCanvasFactory.make(_:)` (Task B3).
- Produces: `#if DEBUG extension RichTextEditorView { func debugReplaceBackend(with preference: RichTextEditorInputBackendPreference) } #endif`, plus the three access-level changes named in Step 3.

**Steps:**

1. - [ ] **Step 1: Write the failing test.** Every member here is one that exists: the document is set through the `document` property, the selection is written through the seam's test-only `setSelectionForTesting(anchor:head:)`, and it is read back off the backend's `state` — `RichTextEditorView.EditorState` (`RichTextEditorView.swift:201-221`) carries `bold`/`italic`/…/`hasSelection`/`isInTable` and **no `selection`**, so `currentState().selection` does not exist on either the view or the canvas.
   ```swift
   #if canImport(UIKit) && DEBUG
   import UIKit
   import XCTest
   import RichTextEditorCore
   @testable import RichTextEditorUIKit

   @available(iOS 17.0, *)
   @MainActor
   final class BackendComparisonTests: XCTestCase {
       override func setUpWithError() throws {
           try XCTSkipUnless(IDTextEditorBackend.isSupported())
       }

       /// Built inline — there is no `.twoParagraphsDocument` fixture anywhere in the package, and
       /// inventing a shared one would put a new symbol in a stage-1 file.
       private func twoParagraphs() -> Document {
           Document(blocks: [
               .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Alpha")])),
               .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "Beta")])),
           ])
       }

       func test_replaceBackendTransfersDocumentAndSelection() throws {
           let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
           editor.document = twoParagraphs()
           editor.canvas.setSelectionForTesting(anchor: 4, head: 9)
           let documentBefore = editor.document
           editor.debugReplaceBackend(with: .inputDecRequired)
           XCTAssertTrue(editor.canvas is IDDocumentCanvasView)
           XCTAssertEqual(editor.document, documentBefore)
           XCTAssertEqual(editor.canvas.inputBackend.state.selection.anchor.utf16Offset, 4)
           XCTAssertEqual(editor.canvas.inputBackend.state.selection.head.utf16Offset, 9)
       }

       /// The undo manager is canvas-owned, so a canvas swap discards the stack. That is a real,
       /// user-visible consequence and must be pinned, not discovered.
       func test_replaceBackendDiscardsTheUndoStack() {
           let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
           editor.document = twoParagraphs()
           let um = UndoManager(); um.groupsByEvent = false
           editor.canvas.undoManagerOverride = um
           editor.canvas.insertText("x")
           XCTAssertTrue(um.canUndo)
           editor.debugReplaceBackend(with: .inputDecRequired)
           // The NEW canvas has no override installed at all, so this reads its own manager.
           XCTAssertFalse(editor.canvas.undoManagerOverride?.canUndo ?? false)
       }

       func test_replaceBackendDiscardsMarkedText() {
           let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
           editor.document = twoParagraphs()
           editor.canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
           editor.debugReplaceBackend(with: .inputDecRequired)
           XCTAssertNil(editor.canvas.markedTextRange)
       }
   }
   #endif
   ```

2. - [ ] **Step 2: Run it and see it fail.** Expected: `value of type 'RichTextEditorView' has no member 'debugReplaceBackend'`.

3. - [ ] **Step 3: Widen three access levels first, in `RichTextEditorView.swift`, and land that refactor on its own.** The extension below lives in a *different file*, and Swift's `private`/`private(set)` are file-scoped — so all three of these must change, not just the `let`:
   - `private let scrollView = GripYieldingScrollView()` (`:9`) → `let scrollView = GripYieldingScrollView()` (internal);
   - `let canvas = DocumentCanvasView()` (`:10`) → `internal private(set) var canvas: DocumentCanvasView` — and note that `private(set)` is **also file-scoped**, so the extension cannot write it from another file either. Declare it `internal var canvas: DocumentCanvasView` and rely on the module boundary plus a doc comment, or keep the swap function in `RichTextEditorView.swift` itself and skip this bullet. **Pick one and say which in the commit message**; do not write `private(set) var` and then assign from the other file.
   - `private func performLayout(size: CGSize) -> CGFloat` (`:362`) → `func performLayout(size: CGSize) -> CGFloat` (internal).
   
   Also factor the four `canvas.on…` callback assignments out of `commonInit()` (the private method Task E2 Step 3 extracted from `init(frame:)`; they are the last four statements of the original body) into `func rewireCanvasCallbacks()` (internal, same file), called from `commonInit()` and from the swap. Run the full UIKit suite and confirm it is green **before** adding the swap — this refactor touches a stage-1 file and must be attributable on its own.

4. - [ ] **Step 4: Implement the swap.**
   ```swift
   #if canImport(UIKit) && DEBUG
   import UIKit

   @available(iOS 13.0, *)
   extension RichTextEditorView {
       /// Debug comparison ONLY. Tears the current canvas down through the backend's detach order
       /// and rebuilds with `preference`.
       ///
       /// Transfers the Telegram document and the canonical selection and NOTHING ELSE. Active
       /// marked text, UIKit range identity, gestures, autoscroll, spellchecking transactions and
       /// undo-coalescing state are never migrated between live backends (spec lines 102-108) —
       /// and because the undo manager is canvas-owned (DocumentCanvasView.swift:522/529), the
       /// ENTIRE UNDO STACK is discarded. That is user-visible; it is the price of the spec's
       /// lifetime-fixed backend rule and is why this is DEBUG-only.
       func debugReplaceBackend(with preference: RichTextEditorInputBackendPreference) {
           let blocks = canvas.currentBlocks()
           // The canonical selection lives on the BACKEND (`state`), not on EditorState — which has
           // no `selection` member at all (RichTextEditorView.swift:201-221).
           let selection = canvas.inputBackend.state.selection
           let width = canvas.bounds.width
           canvas.inputBackend.detach()     // the protocol's own member; there is no
                                            // `canvas.detachInputBackend()`
           canvas.removeFromSuperview()
           canvas = RichTextInputCanvasFactory.make(preference.internalPreference)
           scrollView.canvas = canvas
           scrollView.addSubview(canvas)
           canvas.installSelectionInteractions()
           rewireCanvasCallbacks()          // the four closures set in init (lines 257-275)
           canvas.reload(blocks, width: width)
           canvas.inputBackend.setSelection(selection, reason: .externalSynchronization)
           _ = performLayout(size: bounds.size)
       }
   }
   #endif
   ```
   `setSelection(_:reason:)` takes a whole `RichTextCanonicalSelection` — there is no `setSelection(anchor:head:reason:)` on the canvas or the backend anywhere in either plan or the package (the canvas's own writers are `setSelectionHead(global:)` / `setSelectionAnchor(global:)`, and the test-side seam is `setSelectionForTesting(anchor:head:)`).

5. - [ ] **Step 5: Run and see it pass.** 3 tests on K3.

6. - [ ] **Step 6: Add a Debug Settings entry point.** Optional but recommended: a "Swap input backend (debug)" action in the composer's debug menu that calls `debugReplaceBackend`, so a human can A/B the same document without relaunching.

7. - [ ] **Step 7: Commit.**
   ```sh
   git add submodules/TelegramUI/Components/RichTextEditor && \
   git commit -m "feat(inputdec): debug comparison mode — new canvas, document + selection only"
   ```

### Task E4: Surface the behavior report

The kernel already builds an `IDUIKitBehaviorReport` describing which capabilities resolved, which were rejected, and what ABI mismatches were observed. Without surfacing it, an OS update degrades the backend silently.

**Files:**
- Modify: `Sources/RichTextEditorUIKit/InputBackend/InputDec/IDTextEditorBackend.swift`
- Modify: `/Users/isaac/build/telegram/telegram-ios/submodules/DebugSettingsUI/Sources/DebugController.swift`
- Test: `Tests/RichTextEditorUIKitTests/InputDec/BehaviorReportTests.swift`

**Interfaces:**
- Consumes: `IDUIKitBehaviorReport`, `IDUIKitCapabilityReport`, `IDUIKitContractResult.mismatches`.
- Produces: `IDTextEditorBackend.diagnosticsJSON() -> String?`.

**Steps:**

1. - [ ] **Step 1: Write the failing test.**
   ```swift
   func test_diagnosticsJSONNamesEveryRequestedCapabilityAndItsState() throws {
       try XCTSkipUnless(IDTextEditorBackend.isSupported())
       let h = makeBackendHarness(backend: .inputDec)
       let json = try XCTUnwrap((h.backend as? IDTextEditorBackend)?.diagnosticsJSON())
       for capability in ["inputController", "typingAttributes", "incomingCallbacks"] {
           XCTAssertTrue(json.contains(capability), "report omits \(capability)")
       }
   }

   func test_diagnosticsJSONIsNilBeforeAttach() {
       XCTAssertNil(IDTextEditorBackend().diagnosticsJSON())
   }
   ```

2. - [ ] **Step 2: Run it and see it fail.**

3. - [ ] **Step 3: Implement `diagnosticsJSON()`** by serialising `report` (the kernel already normalises it to JSON).

4. - [ ] **Step 4: Add a read-only Debug Settings row** that shows the last report, gated the same way as the toggle. A capability that silently degraded on a new OS build must be visible without a debugger.

5. - [ ] **Step 5: Run and see it pass.** 2 tests on K3.

6. - [ ] **Step 6: Commit.** `git commit -m "feat(inputdec): surface the kernel behavior report in Debug Settings"`

### Task E5: The promotion gate

No wider enablement happens in this plan. This task defines, in writing, what would have to be true — and verifies the kill switch.

**Files:**
- Create: `docs/superpowers/plans/2026-08-16-inputdec-promotion-criteria.md` — the only artifact; otherwise this task only runs and records verification.

**Interfaces:** none.

**Steps:**

1. - [ ] **Step 1: Verify the kill switch end to end.** With the setting **on**, install a build whose `isSupported()` is forced false (temporarily change `runtimeMatches` to `return false`), launch, open a chat, type. The factory must silently produce the legacy canvas, everything must work, and no crash or log spam may appear. Revert the temporary change. **This is the most important verification in Stage E:** the fallback lives in the factory, so a kernel that stops resolving on a new OS build must degrade to legacy, not fail.

2. - [ ] **Step 2: Write the criteria document** stating that wider enablement requires, at minimum: (a) two consecutive weeks of internal dogfood with no InputDec-attributed crash; (b) the certified OS band widened by an upstream re-certification run and re-export, not by loosening `runtimeMatches`; (c) an answer to the App Store private-API question (see Rollback / Open questions); (d) the trace-equivalence corpus green on the new OS band; (e) a server-side flag design (`ios_rich_input_backend`, mirroring `ios_rich_input_mode` at `ChatTextInputPanelNode.swift:862`) with a remote kill switch — which is explicitly **out of scope of this plan** and must not be built before (a)-(d).

3. - [ ] **Step 3: Record the App Store posture explicitly.** The kernel sends ~90 private selectors and adopts `UITextAutoscrolling` via `class_addProtocol`. The package already ships private-API integration (`Canvas/NativeTextChecking.swift:6-24`, `DocumentCanvasView+NativeTextCheckingClient.swift:90-126`), so this is a change in *degree*, not in kind — but a large one. State the three options and the recommendation in the document (see "Honest constraints" below).

4. - [ ] **Step 4: Commit.**
   ```sh
   git add docs/superpowers/plans/2026-08-16-inputdec-promotion-criteria.md && \
   git commit -m "docs(inputdec): promotion criteria and verified kill switch"
   ```

---

## Honest constraints — where InputDec's kernel cannot meet a Telegram requirement

These are not risks to be managed away. They are structural. **All six were decided on 2026-08-17** — each section below now records the decision taken, not an open choice. The constraints themselves have not gone away; what changed is that the trade-off is now chosen and owned.

### 1. OS floor: the kernel is certified against exactly one build

**Constraint.** The manifest's `runtime` block is a single pinned pair (`osVersion 26.5`, `osBuild 23F73`). InputDec's deployment target is iOS 26.0. `rg 'API_AVAILABLE|@available|__IPHONE_OS_VERSION|isOperatingSystemAtLeast'` over `ID/TextView`, `ID/PrivateUIKit`, `ID/App` returns **zero hits** — there is no version branching anywhere in its production source. Telegram's floor is iOS 13, and hard invariant 12 forbids raising it.

**Options.**
- (a) Compile the kernel at the floor, gate selection on an **exact** OS build match. Coverage: one build. Zero risk of running against an unvalidated ABI.
- (b) Gate on a `26.5.x` band. Slightly wider coverage; assumes Apple does not change private ABI in a patch release, which is exactly the assumption the manifest exists to avoid making.
- (c) Gate on `≥ 26.0` and trust the resolver's ABI acceptance alone. Widest coverage; the resolver *does* compare runtime type encodings and reject on mismatch, so this is not reckless — but a matching type encoding does not imply matching *semantics*.

**DECIDED 2026-08-17: (c), with the floor set at iOS 17.0** — chosen for parity with the editor's TextKit 2 availability story rather than for ABI reasons. Implemented in Task B6 as `minimumMajorVersion = 17`.

**What this decision costs, stated plainly.** The recommendation above was (a), and it was rejected. The consequence is real and must not be quietly walked back by a later reader who finds the exact-match argument persuasive:

- The manifest's `runtime` block **stops being a gate and becomes provenance.** `isSupported()` will say yes on iOS 17 through 26+, i.e. on every build except the one it was certified against.
- The only remaining live safety mechanism is `mandatoryContractsAccepted`, which re-evaluates the three mandatory contracts against the running runtime on every call. That is not nothing — the resolver compares real type encodings and rejects on mismatch, and the factory then falls back to legacy, so an ABI change degrades rather than crashes. But **a matching type encoding does not prove matching semantics**, and nothing in `isSupported()` can detect a private method that kept its signature and changed its behavior.
- Therefore the differential corpus (stage 1's Phase 0b, re-run against `.inputDec` in Stage D) is no longer a nice-to-have; it is the *only* instrument that would catch a semantic drift on an uncertified OS. Task D1 must run it on more than one OS version before any promotion under section 4.
- One factual note for whoever revisits this: the editor's TextKit 2 engine (`BlockLayout`) is gated `@available(iOS 16.0, *)`, not 17.0, so the 17.0 floor is one major stricter than TK2 availability alone requires. That is fine — it is a floor, and a stricter floor is always safe — but the stated rationale and the code do not line up exactly, and a future reader should not "correct" the constant to 16 on that basis without re-deciding.

### 2. Document coupling: `IDRichTextLayoutController` is a rewrite, not a port

**Constraint.** The kernel is genuinely document-neutral (`IDBlockDocument` appears nowhere in `PrivateUIKit/BehaviorKernel/`), but the object it is handed as `layoutController` is not: `IDRichTextLayoutController` is 1564 lines whose designated initializer is `initWithDocument:textStorageAdapter:blockStack:` and whose public properties are `IDBlockDocument *document` / `IDCanonicalTextStorageAdapter *textStorageAdapter`. All **47** incoming callbacks land in that class. It is not a neutral adapter with a document plugged in; it is InputDec's document-facing layer.

Worse, **nine of those callbacks have no home in the spec's six clients**: `textContainers` / `firstTextContainer` / `textContainerForPosition:` (UIKit demands container objects), `ensureLayoutForRange:` / `invalidateLayoutForRange:` / `invalidateDisplayForCharacterRange:` (UIKit *drives* layout, but the geometry client is declared side-effect-free), `requestTextGeometryAtPosition:typingAttributes:resultBlock:`, `insertionRectForPosition:…textContainer:` (out-writes a container), and `selectionRectsForRange:fromView:forContainerPassingTest:` (takes a container predicate).

**Options.**
- (a) Widen the six shared client protocols to accommodate them. Rejected: it bends Telegram's contract to InputDec's shape, which the spec forbids ("The future ID adapter conforms to Telegram's already-proven contract, not the reverse").
- (b) Resolve them inside a backend-private class. That is what `TGRichTextInputDecLayoutController` is for: one synthetic `NSTextContainer` with `canAccessLayoutManager` answering `NO` (upstream already does this), layout commands forwarded to `lifecycleClient.backendRequiresLayout` / `presentationClient.invalidate`, the block-callback geometry request answered synchronously and invoked inline, the container predicate answered `YES` for the single container.
- (c) Do not build the ID backend at all.

**Recommendation: (b).** It is what a backend-private class is for, and it keeps every one of these nine off the shared boundary. Budget Task C0 + C5 accordingly: this is the largest single work item in the plan. Its full input — all 47 `incomingCallbacks` selectors, their `@encode` signatures, the `id_` naming rule and the task that owns each row — is enumerated in the [Appendix](#appendix-the-47-incomingcallbacks-selectors-and-the-id_-rule).

### 3. UIKit destroys semantic intent, and the recovery is a latch

**Constraint.** `UITextInputController` mutates through `NSTextStorage.replaceCharactersInRange:withString:`. That call cannot distinguish "pressed Return" from "typed a newline" from "deleted backward" — exactly the paragraph-split / block-merge intent Telegram's document client is built around. A missed latch silently degrades a structural edit to a plain replace, which Telegram will then execute *correctly but differently* from the legacy backend.

**Options.**
- (a) The intent latch (Task C7): recover intent from the pre-mutation private input-delegate callbacks (`keyboardInput:shouldInsertText:isMarkedText:`, `keyboardInputShouldDelete:`, the paste selectors, `insertDictationResult:`) that UIKit sends *before* the storage mutation.
- (b) Send only `.replaceText` and let Telegram re-derive structure from the text. Simpler, and semantically divergent from the legacy backend at exactly the points users notice (Return in a quote, Backspace at a paragraph boundary).

**Recommendation: (a)**, pinned by `IDBackendIntentLatchTests` **first**, before any family-4 semantic test. Task C7 is written that way deliberately, and Task D2's differential runner cross-checks it against the legacy backend's actual mutation trace.

### 4. Private API in an App Store binary

**Constraint.** The exposure already exists — the package ships XOR-obfuscated private class/selector strings (`Canvas/NativeTextChecking.swift:6-24`) and five vended `@objc` private selectors (`DocumentCanvasView+NativeTextCheckingClient.swift:90-126`). The kernel adds `UITextInputController`, `UITextInteractionAssistant`, ~90 private selectors, and a `class_addProtocol` adoption of `UITextAutoscrolling`. This is a change in degree, not in kind — but a large one.

**Options.**
- (a) Debug/internal-only forever. Zero App Store risk; the work's value is a research and comparison instrument.
- (b) Ship enabled for a fraction of users behind a server flag. Requires an answer from whoever owns App Store risk for this app; not a decision this plan can make.
- (c) Do not vendor at all.

**DECIDED 2026-08-17: the private-API exposure is accepted and is not a constraint on this plan.** Task E5 therefore no longer needs to escalate it as a blocking question; it records the surface for the audit trail and proceeds.

The mitigations stand regardless and must not be dropped on the strength of this decision: every private name stays inside the Objective-C module (enforced by the boundary tests), the kernel refuses construction on any mandatory ABI mismatch, the factory falls back to legacy on refusal, and every kernel entry point is wrapped by `TGRichTextInputDecPerform` (Task A8) so an `NSException` on a contract path cannot become an uncatchable Swift crash. **Reverting Task A8 is not a valid rollback** — see the Rollback table's note 1.

One interaction worth flagging: this decision and decision 2 compound. Accepting the private-API surface *and* widening the OS gate from one certified build to a 17.0 floor together mean the binary may send ~90 private selectors on OS versions nobody has validated. Each decision is defensible alone; together they move essentially all of the safety onto `mandatoryContractsAccepted` plus the differential corpus. That is the reason section 1 now makes the multi-OS differential run a precondition for promotion rather than a recommendation.

### 5. Autoscroll cannot attach to Telegram's canvas as written

**Constraint.** InputDec's `startAutoscroll:` reads `self.adjustedContentInset`, `self.contentSize`, `self.contentOffset` — it assumes the first responder **is** the `UIScrollView`. Telegram's `DocumentCanvasView` is a plain `UIView` (`DocumentCanvasView.swift:59`) inside a separate `GripYieldingScrollView` (`GripYieldingScrollView.swift:13`). The spec's `RichTextInputInteractionBackend` does not model a scroll-container indirection.

**Options.** (a) Never request `autoscrollEntry`; keep Telegram's own drag-autoscroll (`DocumentCanvasView.swift:1392-1449`). (b) Vendor `TextView/Autoscroll/` (438 lines, genuinely neutral `UIScrollView` geometry) and add a scroll-container indirection to the backend.

**Recommendation: (a)**, recorded in `DIVERGENCES.md`, with (b) revisited only if Task C12 Step 6 finds the two mechanisms fighting.

### 6. Position identity models are incompatible

**Constraint.** InputDec's `IDRichTextPosition` holds an `IDRichTextAnchor` = `{weak IDBlockDocument, blockIdentifier, localOffset, bias}` — block-identity anchoring that survives edits. The spec mandates flat `(utf16Offset, affinity)` + revision + `rebase(_:fromRevision:)`.

**Consequence, stated plainly:** the vendored backend adopts the spec's model and **loses anchor-based edit survival**. The compensating mechanism is `documentClient.rebase(_:fromRevision:)`. If the seam shipped a `rebase` that merely clamps, marked-text survival across an external edit will be *worse* than InputDec's. Verify this specifically in Task C7 Step 4 before accepting family 6.

**Recommendation:** adopt the spec's model (the alternative is a stable-anchor concept the spec does not have and Telegram's document model does not provide), and treat a clamping-only `rebase` as a blocking finding against the seam, not against this plan.

---

## Rollback

Every stage is independently revertable, and the revert is always cheaper than the stage.

| Stage | What the revert is | How long |
| --- | --- | --- |
| **A** | `git revert` the telegram-ios commits in reverse order (A10 script, A9 docs, A8 exception guard, A7 Bazel, A6 SwiftPM, A5 integrity, A4 snapshot+boundary relaxation). Nothing depends on the module except `IDTextEditorBackendModuleProbe.swift`, which the A7 revert removes. **Revert A4 last**: it carries both the vendored tree and the R8/R1/R2 relaxation, and reverting the relaxation while an `InputBackend/InputDec/` file still exists turns the source-boundary suite red. The three InputDec-repo commits (A1-A3) are independent and can be kept — they touch no telegram-ios file. | One full `Make.py build` + one `swift test` to confirm — ~15-30 min wall, no thought required. |
| **B** | Three independent reverts, in this order if all are dropped. (i) The thunks / `isSupported()` / factory commits (B3-B6): `git revert`, and the factory disappears with them. (ii) The `final` removal on `DocumentCanvasView` (B2): reverted separately — it is deliberately its own commit precisely so it can be kept or dropped independently. (iii) The performance baseline (B1) is pure test code and is worth **keeping** even if everything else goes: it is the only measurement of these three hot paths anywhere in the package. Keeping A while dropping B is valid and leaves the module compiled and inert. | One `iostest.sh` full pass + one `Make.py build` — ~45 min. |
| **C** | Per family. Each family is one commit and the families are strictly additive: reverting family N leaves families 1..N-1 working, because nothing selects `.inputDec` in production during Stage C. The three infrastructure tasks (C1 harness, C2 fake-client harness, C3 shared suite) are reverted **last** and are worth keeping regardless — C3's `LegacyBackendSemanticTests` is net-new legacy coverage that stands on its own. If the intent latch (C7) cannot be made correct, stop at family 3 and record it: families 1-3 are read-only and still prove the bridge. | One family revert + the K3 suite for the remaining families — ~20 min per family. |
| **D** | Nothing to revert: D adds tests and a script rewrite only, and creates no checked-in artifacts. If the differential runner cannot go green, revert D2/D3 and leave the shared semantic suite in place — the equivalence claim is simply not made, and no legacy coverage is lost. `matrix.sh` (D1) must be reverted with `git revert` rather than hand-edited, so the seam plan's original single-device loop comes back intact — note D1 edits only the device-selection loop; `ROOTS`/`discover()`/`MATRIX_MIN_SUITES` are untouched by it and are reverted with B1/C3. | Minutes. |
| **E** | Three independent levels, in increasing order of speed: (i) a user toggles the Debug Setting off — instant, no build; (ii) `git revert` the E2 threading commit so no call site can pass anything but `.legacy` — one build; (iii) `git revert` the E1 setting commit so the toggle does not exist — one build. Because the fallback lives in the factory rather than the protocol, an `isSupported()` that starts returning false on a new OS is itself a zero-code rollback. | (i) seconds; (ii)/(iii) one `Make.py build` each. |

**Three rollback properties worth stating explicitly.**

1. **The kernel's own failure mode is safe *once the exception guard is in place*.** `IDUIKitBehaviorKernel` returns `nil` on any mandatory contract failure, and `RichTextInputCanvasFactory` falls back to `DocumentCanvasView`. But the kernel *raises* `NSException` on several other paths, and Swift cannot catch one — so "degrades to legacy without a code change" is true only because every kernel entry point is wrapped by `TGRichTextInputDecPerform` (Task A8). **Reverting Task A8 while keeping Stage C is not a valid rollback**; it converts every contract mismatch into a crash. Task E5 Step 1 verifies the fallback end to end and must not be skipped.
2. **The Telegram-only seam is never at risk.** Nothing in this plan modifies the six client protocols, `LegacyRichTextInputBackend`, or the eight seam contract suites. The shared-code edits are exactly seven, each individually revertable and individually covered by the existing suite: `final` on `DocumentCanvasView` (Task B2), the `canvas` property becoming factory-assigned (Task B3), the source-boundary exemption (Task A4), the harness kind enum plus two accessors (Task C1), the additive fake-client members on two fake clients (Task C2 Step 3), the `matrix.sh` discovery widenings (`ROOTS` in Task B1 Step 4, the regex in Task C3 Step 6), and the three `RichTextEditorView` access-level widenings plus `rewireCanvasCallbacks()` (Task E3 Step 3 — the only one that lands in Stage E, and the only one that is not needed unless comparison mode is wanted).
3. **The source-boundary relaxation is the one edit that must be reverted in the right order.** It lives in a stage-1 file, and reverting it while any `InputBackend/InputDec/` file survives makes `swift test` red for a reason unrelated to whatever is being rolled back. Revert Task A4 last, always.

---

## Decisions (all ten answered 2026-08-17)

**Every question below is closed.** The recommendation that was offered is kept for the record, followed by what was actually decided and where it landed. Three decisions went *against* the recommendation — 2, 5 and 10 — and those are the ones a later reader is most likely to try to undo, so each says explicitly what it costs and why it is not to be quietly reverted.

| # | Decided | Against recommendation? | Where it landed |
| --- | --- | --- | --- |
| 1 | Private-API surface accepted; not a constraint | no (matched (a)'s risk posture, dropped the escalation) | Honest constraints §4, Task E5 |
| 2 | `isSupported()` floor = **iOS 17.0** | **yes** — (c) with a 17.0 floor, not (a) exact-build | Task B6, Honest constraints §1, Task A9's CLAUDE.md text, and **all 21 `@available` annotations** swept 26.0 → 17.0 |
| 3 | Drop `final` from `DocumentCanvasView` | no | Task B2, gated on Task B1 baselines |
| 4 | The intent latch | no | Task C7, cross-checked by Task D2 |
| 5 | Run InputDec's tests against RichTextEditor — via the **differential harness**, in **stage 1** | **yes** — the recommendation was "no, keep them upstream" | Stage 1 Phase 0b (Tasks 9a–9d); this plan's Stage D re-runs the corpus for `.inputDec` |
| 6 | Settle autoscroll coexistence empirically | no | Task C12 Step 6 |
| 7 | Two-file allowlist (rule R1b) | no | stage 1 deviation D11; untouched here |
| 8 | Public `RichTextEditorInputBackendPreference` enum | no | Task E1/E2; stage 1 deviation D30 |
| 9 | **InputDec owns** the export script, tests in InputDec CI | no | Tasks A1–A3 |
| 10 | Parameterise stage 1's eight contract suites, **in stage 1** | **yes** — the recommendation was "accept the coverage difference" | stage 1 Task 22a + gate item 11; this plan's Task C3 Step 7 |

**Decision 5, in full.** The question as originally posed — "vendor the seven portable kernel test files?" — was the wrong question. Those test the kernel, which Stage A vendors byte-for-byte, so a green run proves the copy worked, not that the port works. The lifecycle contract suites (`IDIMECompositionLifecycleContractTests` and friends) *are* behavior specs but are hard-bound to `IDBlockTextView`/`IDBlockDocument`/`IDCanonicalTextStorageAdapter`/`IDRichTextAnchor`, i.e. the demo document the spec forbids porting; retargeting them is a rewrite. The instrument that actually answers "is the port complete" is `InputDec/Tests/TextInputDifferential/`, which is already host-parameterised over `UIView<UITextInput>` via a `{Stock, Reference, Minimal}` host-kind factory, with a declarative 68-scenario / 612-transaction corpus. Adding a fourth (Telegram) host kind makes it run against RichTextEditor; adding a fifth makes it run against `.inputDec`. Because it needs nothing from the seam **or** the kernel, it belongs in stage 1 where it doubles as an independent equivalence oracle for the legacy backend — see that plan's Phase 0b for the two recorded limitations (no single `NSTextStorage` under legacy; corpus provenance pinned to one simulator OS).

**Decision 9, and how it is actually enforced.** InputDec owns `Scripts/export-behavior-kernel.sh` and its three tests, so an upstream refactor that breaks the symbol-name carve fails upstream where it can be fixed.

**Verified 2026-08-17: InputDec has no CI.** There is no `.github/workflows`, no GitLab/Circle/Travis configuration — only `project.yml` (XcodeGen) and ~30 local scripts under `Scripts/`. What exists instead is a **standing manual discipline: the UIKit equivalence tests are run on every change.** That is the enforcement mechanism, and it is a real one — it is just not automation.

The consequence for this plan: the three export-script tests must join that per-change run rather than sit beside it as scripts someone remembers to invoke. Task A3 Step 7 adds them to InputDec's existing per-change test invocation, and Task A9 records the arrangement in both repos. Two properties follow, and both matter:

- **The upstream half is genuine but human.** A refactor that breaks the carve is caught the next time someone runs the equivalence tests, which is every change — not "eventually", but also not "mechanically".
- **Task A5 is therefore load-bearing, not a backstop.** It is the only *automated* check that an upstream drift reached the snapshot, and it fires on the telegram-ios side at sync time. Do not weaken or skip it on the grounds that upstream already tests: upstream tests the kernel, A5 tests that *this repo's copy of it* is intact.

---

## Original open questions (superseded — kept for the reasoning)

The text below is the state *before* the decisions above. It is retained because the options and trade-offs are the argument for the answers, not because anything here is still open. **Where this section and the table above disagree, the table wins.**

1. **Certified-OS policy for `isSupported()`** — exact build match (26.5 / 23F73), a `26.5.x` band, or `≥ 26.0` gated purely on the resolver's ABI acceptance?
   **Recommendation: exact `major.minor` match for the first ship**, widened only by an upstream re-certification run plus a re-export. The ABI gate is the whole reason to vendor this kernel; widening the band by editing a constant throws it away. (**Task B6** implements `major.minor` by comparing against `manifest.osVersion`; tighten to also compare `manifest.osBuild` against `kern.osversion` if you want the strictest reading — one extra line, and it makes the K1 leg of Task B6 Step 6 a stronger negative test.)

2. **App Store posture.** Is the ID backend permanently debug/internal-only, or is a fractional server-flagged rollout on the table?
   **Recommendation: debug/internal-only through this plan.** The private-API surface grows from ~2 files to ~90 selectors plus a `class_addProtocol`. That is a decision for whoever owns App Store risk, not for this plan. **Task E5** records the criteria; it does not presume the answer. Note the new input to this decision: the kernel raises `NSException` on contract mismatch and is certified against one OS build, so a shipped build's crash exposure is bounded by `TGRichTextInputDecPerform` (Task A8) rather than by the kernel itself.

3. **Is dropping `final` from `DocumentCanvasView` acceptable?** It is a 1743-line class with ~44 extensions, and the subclass rule forces it.
   **Recommendation: yes, as its own commit (Task B2), gated on the three baselines Task B1 creates**, measured before and after in one sitting, with a >15% regression treated as a stop. Note the honest caveat now written into Task B1 Step 3: if the run-to-run spread exceeds 10%, the numeric gate is not supportable on this hardware and the qualitative fallback applies. The alternative — a category on the shared class — directly violates spec lines 1171-1173 and would give the legacy canvas private selectors.

4. **The intent latch, or plain `.replaceText`?** Recovering `insertParagraphBreak`/`deleteBackward` from `keyboardInputShouldDelete:` / `keyboardInput:shouldInsertText:isMarkedText:` before UIKit's raw range replace reaches the façade, versus sending only `.replaceText` and letting Telegram re-derive structure.
   **Recommendation: the latch.** Plain `.replaceText` diverges from the legacy backend at exactly the points users notice (Return in a quote, Backspace at a paragraph boundary), and the divergence would be silent. **Task C7** pins the latch with `IDBackendIntentLatchTests` before any family-4 semantic test runs, and **Task D2**'s `return-splits-paragraph` / `backspace-merges-paragraphs` scenarios are the independent cross-check: they compare the two backends' actual mutation traces rather than trusting the latch's own unit tests.

5. **Should the seven portable InputDec kernel test files (~2000 lines, importing only kernel headers) be vendored as a SwiftPM ObjC test target?** SwiftPM's ObjC test-target support is unverified in this repo.
   **Recommendation: no.** Keep them upstream and rest the snapshot's provenance on a green InputDec K3 run recorded in `VENDOR.md` (the export script writes the evidence line). Vendoring them buys duplicate coverage of code we do not modify, at the cost of an unproven build configuration; the telegram-ios-side risk is in the *authored* host classes, which this plan tests directly.

6. **Can Telegram's own drag-autoscroll coexist with `UITextInteractionAssistant` owning the selection gestures** once the `interaction` capability is requested, or does deferring `autoscrollEntry` leave the two fighting?
   **Recommendation: find out empirically at Task C12 Step 6**, before family 10, by running manual checklist item 11. If they fight, disable Telegram's display link while `kernelInteraction` is attached — do **not** request `autoscrollEntry`, because `startAutoscroll:` assumes the responder is the scroll view and Telegram's is not.

7. **Must the pre-existing Swift private-selector client be carved into the ObjC module before the boundary test can pass**, or is a documented two-file allowlist sufficient?
   **Recommendation: the two-file allowlist (rule R1b), with a scheduled carve-out.** The two files (`Canvas/NativeTextChecking.swift:6-24`, `DocumentCanvasView+NativeTextCheckingClient.swift:90-126`) predate this work and are unrelated to InputDec; blocking on them conflates two projects. But the allowlist must be a *fixed list with a non-growing count*, not a pattern, and the carve-out should be scheduled before any decision under question 2. **This plan does not touch R1b** — Task A4's relaxation is explicitly scoped away from it.

8. **Is a public `RichTextEditorInputBackendPreference` enum acceptable** on `RichTextEditorView`, or does the spec's "no backend type in the public API" rule require an internal-only debug entry point?
   **Recommendation: the public kind-only enum is acceptable** — it names a *preference*, not a backend type, and external consumers still cannot implement or inject a backend. It is needed because `ChatTextInputPanelNode` lives in a different module from `RichTextEditorUIKit`. If a reviewer disagrees, the fallback is an internal `RichTextEditorView+ComposerHost` entry point plus a module-internal setter, which costs one indirection and no capability.

9. **Which repo owns the export script's long-term maintenance?** It reads `IDPrivateUIKit.m` by symbol name to carve the preflight, so an upstream refactor can break it.
   **Recommendation: InputDec owns it**, and its three tests (`Scripts/test-generate-contract-data.py` A1, `Scripts/test-carve-host-preflight.sh` A2, `Scripts/test-export-behavior-kernel.sh` A3) run in InputDec's CI so an upstream refactor that breaks the carve or the rename fails upstream, where it can be fixed, rather than silently rotting the snapshot. Note that the codegen test hard-asserts a **row count** (50 renamed of 130 capability members): that is deliberate — it converts "upstream reshaped the manifest" from a silent no-op into a loud failure.

10. **NEW — how much of the seam's contract coverage must be reproduced for `.inputDec`?** The seam plan's eight contract suites name `LegacyRichTextInputBackend` in their bodies and are not backend-parameterised. This plan therefore builds a **new** parameterised base class (`BackendSemanticContractCases`, Task C3) and grows it one family at a time, rather than rewriting eight stage-1 files. That is a real coverage difference: the ID backend gets the *semantic* assertions and this plan's own `IDBackendFamily<N>Tests`, but not the eight suites' 54 interleaving-and-token-discipline tests.
    **Recommendation: accept the difference for this plan, and re-open it only if `.inputDec` is ever proposed for default-on.** Rewriting the eight suites to take a backend factory is a change *inside* the seam's deliverable and would put this plan's risk on the legacy path — the exact inversion the two-plan split exists to prevent. If the reviewer disagrees, the alternative is a stage-1 follow-up task that parameterises the eight suites *before* this plan starts, which is a clean change but re-opens the Phase-6 gate.

---

## Appendix: the 47 `incomingCallbacks` selectors and the `id_` rule

Task C0 Step 3 builds `TGRichTextInputDecLayoutController`, and the "Honest constraints" section
calls it the largest single work item in the plan. This appendix is the list it is built against, so
no executor has to recover 47 selector names from prose.

**Re-derive it mechanically** rather than trusting the table (the manifest is the authority, and the
table is a snapshot of iOS 26.5 / 23F73):

```sh
cd /Users/isaac/Documents/InputDec && python3 -c '
import json
m = json.load(open("PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json"))
for r in m["capabilities"]["incomingCallbacks"]["members"]:
    print(r["name"], "|", r["returnType"], "|", ", ".join(r["argumentTypes"]) or "-")'
```

**The `id_` rule.** Each public (UIKit-facing) selector gets a one-line forward in the private
callbacks category; the neutral implementation lives on the internal header under the same selector
prefixed `id_`, with **a leading underscore stripped first**. Two worked pairs — one plain, one
underscored — are the template for all 47 (both verbatim from upstream's
`IDRichTextLayoutController+PrivateCallbacks.m:127` and `:295`):

```objc
// plain: textStorage  ->  id_textStorage
- (NSTextStorage *)textStorage { return [self id_textStorage]; }

// underscored: _invalidateTemporaryAttributesInRange:  ->  id_invalidateTemporaryAttributesInRange:
- (void)_invalidateTemporaryAttributesInRange:(NSRange)range {
    [self id_invalidateTemporaryAttributesInRange:range];
}
```

Multi-piece selectors keep every piece: `textRangeFromPosition:toPosition:` →
`id_textRangeFromPosition:toPosition:`.

**Return/argument type encodings are `@encode` strings** (`@` = object, `v` = void, `B` = BOOL,
`q` = NSInteger, `Q` = NSUInteger, `d` = CGFloat, `@?` = block, `^@` = object out-param,
`{_NSRange=QQ}` = NSRange, `{CGRect=…}` = CGRect). They are what
`IDInteractionABIMismatchForSignature` compares against, so a wrong signature is a rejected
capability, not a compile error.

**Which task implements which rows** (the families in Stage C):

| # | Selector | Returns | Arguments | Task |
| --- | --- | --- | --- | --- |
| 1 | `textStorage` | `@` | — | C0 |
| 2 | `textContainers` | `@` | — | C5 |
| 3 | `firstTextContainer` | `@` | — | C5 |
| 4 | `textContainerForPosition:` | `@` | `@` | C5 |
| 5 | `beginningOfDocument` | `@` | — | C4 |
| 6 | `endOfDocument` | `@` | — | C4 |
| 7 | `emptyTextRangeAtPosition:` | `@` | `@` | C4 |
| 8 | `textRangeFromPosition:toPosition:` | `@` | `@, @` | C4 |
| 9 | `positionFromPosition:offset:` | `@` | `@, q` | C4 |
| 10 | `positionFromPosition:offset:affinity:` | `@` | `@, q, q` | C4 |
| 11 | `positionFromPosition:inDirection:offset:affinity:anchorPositionOffset:` | `@` | `@, q, q, q, d` | C4 |
| 12 | `textRangeForLineEnclosingPosition:` | `@` | `@` | C4 |
| 13 | `textRangeForLineEnclosingPosition:effectiveAffinity:` | `@` | `@, q` | C4 |
| 14 | `attributesAtPosition:inDirection:` | `@` | `@, q` | C4 |
| 15 | `baseWritingDirectionAtPosition:` | `q` | `@` | C5 |
| 16 | `comparePosition:toPosition:` | `q` | `@, @` | C4 |
| 17 | `offsetFromPosition:toPosition:` | `q` | `@, @` | C4 |
| 18 | `affinityForPosition:` | `q` | `@` | C4 |
| 19 | `characterRangeForTextRange:` | `{_NSRange=QQ}` | `@` | C4 |
| 20 | `boundingRectForCharacterRange:` | `{CGRect={CGPoint=dd}{CGSize=dd}}` | `{_NSRange=QQ}` | C5 |
| 21 | `characterRangeForTextRange:clippedToDocument:` | `{_NSRange=QQ}` | `@, B` | C4 |
| 22 | `characterRangesForTextRange:clippedToDocument:` | `@` | `@, B` | C4 |
| 23 | `textRangeForCharacterRange:` | `@` | `{_NSRange=QQ}` | C4 |
| 24 | `textRangeForCharacterRanges:` | `@` | `@` | C4 |
| 25 | `positionWithOffset:affinity:` | `@` | `q, q` | C4 |
| 26 | `textInputController` | `@` | — | C0 |
| 27 | `adoptTextInputController:` | `v` | `@` | C0 |
| 28 | `detachFromTextInputController` | `v` | — | C0 |
| 29 | `canAccessLayoutManager` | `B` | — | C0 |
| 30 | `invalidateDisplayForCharacterRange:` | `v` | `{_NSRange=QQ}` | C6 |
| 31 | `rangeOfCharacterClusterAtIndex:type:` | `{_NSRange=QQ}` | `Q, q` | C4 |
| 32 | `selectionRectsForRange:fromView:forContainerPassingTest:` | `@` | `@, @, @?` | C5 |
| 33 | `requestTextGeometryAtPosition:typingAttributes:resultBlock:` | `v` | `@, @, @?` | C5 |
| 34 | `insertionRectForPosition:typingAttributes:placeholderAttachment:textContainer:` | `{CGRect={CGPoint=dd}{CGSize=dd}}` | `@, @, @, ^@` | C5 |
| 35 | `cursorPositionAtPoint:inContainer:` | `@` | `{CGPoint=dd}, @` | C5 |
| 36 | `nearestPositionAtPoint:inContainer:` | `@` | `{CGPoint=dd}, @` | C5 |
| 37 | `_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:` | `@` | `@, {CGPoint=dd}, @, q` | C12 |
| 38 | `ensureLayoutForRange:` | `v` | `@` | C5 |
| 39 | `invalidateLayoutForRange:` | `v` | `@` | C5 |
| 40 | `attributedTextInRange:` | `@` | `@` | C4 |
| 41 | `annotatedSubstringForRange:` | `@` | `@` | C14 |
| 42 | `addAnnotationAttribute:value:forRange:` | `v` | `@, @, @` | C14 |
| 43 | `annotationAttribute:atPosition:` | `@` | `@, @` | C14 |
| 44 | `removeAnnotationAttribute:forRange:` | `v` | `@, @` | C14 |
| 45 | `addRenderingAttributes:forRange:` | `v` | `@, @` | C14 |
| 46 | `removeRenderingAttributes:forRange:` | `v` | `@, @` | C14 |
| 47 | `_invalidateTemporaryAttributesInRange:` | `v` | `@` | C14 |

Rows 1 and 26-29 are the connection/teardown group and land in Task C0 Step 3 together with the
synthetic container; every other row lands with its family. `TGRichTextInputDecLayoutControllerInternal.h`
declares exactly the `id_…` counterparts of the rows already implemented — it grows one group per
task, never all at once.

---

## Review notes

Applied changes from the adversarial review, and the one finding that was checked against the real
files and deliberately narrowed.

**Applied in full.** Findings 1–12 and 14–15. The three structural consequences worth calling out:

- **Stage 1's artifacts, not the design note's.** The original document was written against
  `d3-verification-and-risk.md`, which *proposed* a JSON trace corpus, an `RTE_RECORD_TRACES`
  re-record workflow, three `XCTMetric` baselines and a `richtext-input-seam-baseline` tag. The seam
  plan as written implements none of them: its characterization is in-source XCTAssert expectations
  under `Tests/RichTextEditorUIKitTests/Characterization/`, `grep -c "Fixtures/InputTraces"` over it
  returns 0, and it names its baseline only as `<baseline>`. Every gate, constraint and task that
  referenced the imaginary artifacts now references the real ones, the baseline tag is created by
  this plan's own prerequisite Step 0, the performance suite is built by the new Task B1, and
  equivalence is established by an in-process differential runner (Tasks D2/D3) instead of checked-in
  goldens.
- **Three tasks were secretly enormous and were split.** Old Task A1 (codegen + carve + export script
  + four scripts, in seven steps) became A1/A2/A3. Old Task C1 (a harness that did not exist, plus a
  shared suite that did not exist) became C1/C2/C3. Old Task D2 (a corpus plus its comparison)
  became D2/D3. Nothing was shrunk to make a finding go away; the document grew.
- **Stage A gained a new task, A8.** The claim that the vendoring makes the kernel fail soft was
  true of exactly one function. Seven other `NSException` raise sites survive — including
  `IDUIKitInputControllerCapability.m:228`, which fires on *any* witness call after `detach()` — and
  Swift cannot catch an `NSException`. A8 adds the trampoline, `VENDOR.md` and `CLAUDE.md` now state
  the limitation instead of overstating the fix, and `IDBackendCallGuardTests` fails the suite on an
  unguarded call.

**Narrowed, with the reason.** Finding 5 (blocker, TARGET_OS_IOS guards on headers) is correct in
substance and has been applied — but its file list was wrong in one place. It named five unguarded
UIKit-importing headers; there are **four**. `grep -n "^#import <UIKit/UIKit.h>"` over
`PrivateUIKit/BehaviorKernel/*.h` plus `TextView/IDRichTextSelectionRect.h` returns exactly
`IDUIKitBehaviorKernel.h:1`, `IDUIKitInputControllerCapability.h:1`, `IDUIKitInteractionCapability.h:1`
and `IDRichTextSelectionRect.h:1`. `IDUIKitAutoscrollEntryCapability.h:1` is
`#import <Foundation/Foundation.h>` — it takes a `Class`, not a `UIView`, and imports no UIKit at all.
The fix in Task A3 Step 6 guards **every** copied header unconditionally rather than a hand-maintained
list, so the discrepancy cannot matter and cannot rot; the prose cites the three real kernel headers.

**One factual correction to a supporting claim.** Finding 12 states that the carved
`+requireInteractionHost:stage:` throws "inside the Telegram app, on an OS build that is not 23F73".
That is true of the method, but its single call site is already wrapped upstream:
`IDUIKitInteractionCapability.m:199-206` is a `@try`/`@catch` that converts the exception into
`IDUIKitInteractionCapabilityErrorInvalidHost`. The finding's substance stands regardless — the seven
*other* raise sites are unguarded, and `IDUIKitInteractionRuntimeContract()` at
`IDUIKitInteractionCapability.m:144` throws precisely *because* Edit 1 makes the manifest lookup
return nil — so Task A8 is written for those, and the preflight is listed in its table with the
`@try`-already-present caveat noted.

**Task-count note.** Stage A went from 8 tasks to 11, Stage B from 6 to 7, Stage C from 13 to 15,
Stage D from 4 to 5; Stage E is unchanged at 5. Total: 43 tasks.

**Superseded by the 2026-08-17 decisions**: Stage D gained Task D4b (run the differential corpus
against `.inputDec`), bringing the total to **44 tasks**. Task C3 also grew Steps 7-9 rather than
becoming a new task. See "Decisions (all ten answered 2026-08-17)".

---

### Second review pass (concreteness), applied

All 24 findings of the concreteness review were checked against the real files
(`.../RichTextEditor/Sources`, `/Users/isaac/Documents/InputDec`, and the seam plan) before being
applied. No task was deleted; the document only gained content (an appendix, one extra `matrix.sh`
step in Task B1, one in Task C3, and an access-level refactor bullet in Task E3). Task count is
unchanged at **43**.

The three that were partly wrong, and how they were narrowed:

- **Finding 5 (carve helper list) understated the gap.** It named two missing statics
  (`IDInteractionTypeMatches`, `IDInteractionABIMismatchForSignature`); there are **three** —
  `IDInteractionTypeMatches` calls `IDInteractionSkipTypeQualifiers` (`IDPrivateUIKit.m:987`), which
  the finding does not mention. All three are now carved, in dependency order.
  `IDInteractionInstanceABIMismatches` (`:1046`) is deliberately *not* carved: neither class method
  reaches it. The presence checks were also strengthened from substring greps to definition-line
  greps, since `grep -q IDInteractionABIMismatch` succeeds on a file containing only
  `IDInteractionABIMismatches`.
- **Finding 7 is right about `.selection`, wrong about `currentState()`.** `DocumentCanvasView`
  *does* have `currentState()` — `DocumentCanvasView+State.swift:49`, and `RichTextEditorView`'s own
  `currentState()` (`:237`) is a one-line forward to it. What does not exist is `EditorState.selection`,
  which is the finding's substance and is what the fix addresses (the read now goes through
  `canvas.inputBackend.state.selection`).
- **Finding 11's suggested replacement does not compile either.** It proposes
  `.caret(at: RichTextInputPosition(utf16Offset: 0, affinity: .downstream))`, but the seam's own
  type tests spell it `.caret(at: .downstream(0))` (seam Task 10 Step 3). The snapshot is now
  constructed memberwise with the seam's spelling, and no `static let empty` is added — so the
  Rollback shared-edit list needed no entry for it. (That list *did* grow, from five to seven, for
  the two `matrix.sh` discovery edits and Task E3's `RichTextEditorView` access widenings.)
