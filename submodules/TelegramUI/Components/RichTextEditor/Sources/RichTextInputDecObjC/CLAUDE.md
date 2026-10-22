# InputDec behaviour kernel (`Sources/RichTextInputDecObjC`)

The private-UIKit behaviour kernel the InputDec backends call into. This repo owns it: edit it here. Ownership of the
engine tree is in `Sources/RichTextInputDecUpstream/CLAUDE.md`; the private-UIKit-name rule and the verification traps
are in the package `CLAUDE.md` (`submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md`); the engine's own suites
are in `Host/Engine/`.

## Layout and build

- **The kernel sits next to `Sources/RichTextEditorUIKit/`, not inside it.** `BUILD`'s `RichTextEditorUIKit`
  `swift_library` globs only `Sources/RichTextEditorUIKit/**/*.swift`, so an `.m` or `.h` placed under that tree still
  compiles under SwiftPM (which takes the whole directory) but silently drops out of the Bazel app build.
- **The public headers import the kernel as `"Kernel/…"`.** SwiftPM does not propagate `cSettings.headerSearchPath` to
  a Swift importer's module build; only `include/` reaches dependents. So `include/TGRichTextInputDec.h` and
  `include/TGRichTextInputDecContract.h` use the quoted spelling, which resolves relative to the including file first.
  Bazel's `includes` lists both `include` and `include/Kernel` and accepts either spelling, so "simplifying" those
  imports to bare names breaks SwiftPM while Bazel stays green.
- **Generated, pinned artifacts:** `Vendor/`'s pristine manifest JSON and `Generated/TGRichTextInputDecContractData.m`.
  `VendorSnapshotIntegrityTests` (Core) hashes both against pins recorded in `VENDOR.md` and in the test file: an
  accidental edit fails, a deliberate one re-records the pin in the same commit. Regenerate them
  (`Host/Engine/Scripts/generate-contract-data.py`) rather than editing them.

## The kernel is invisible to a macOS build

The kernel compiles for iOS 13 and later. Every vendored `.h` and `.m` except `Host/TGRichTextInputDecModuleAnchor.m`
(left unguarded so the module has one real symbol on macOS) opens with `#if TARGET_OS_IOS`;
`IDUIKitBehaviorKernel.h`, `IDUIKitInputControllerCapability.h` and `IDUIKitInteractionCapability.h` import
`<UIKit/UIKit.h>` just inside the guard; nothing uses `API_AVAILABLE` or `@available`. So a macOS `swift build`
compiles empty objects with no symbols and no classes, where an iOS-simulator build defines the kernel's Objective-C
classes (`IDInteractionABISpec` … `TGRichTextInputDecSelectionRect`), and a broken import spelling still passes. Only an
iOS-simulator or Bazel build tells you anything about this code.

## Swift calls the kernel only through the exception guard

The kernel raises `NSException` on a contract mismatch; only the two manifest-resource lookups return nil instead. The
raise sites are `IDUIKitBehaviorReport.m:83`, `IDUIKitInteractionCapability.m:119,132,237` and
`IDUIKitInputControllerCapability.m:134,231,534` (`Vendor/VENDOR.md`); one is the `activeController` accessor, which
raises on any call after `detach()`. Swift cannot catch an `NSException`, so the only way in is
`TGRichTextInputDecPerform` / `TGRichTextInputDecPerformReturningObject` (`TGRichTextInputDecExceptionGuard.h`, written
in this repo, not part of the vendored snapshot). `IDBackendCallGuardTests` (Core) fails on a kernel entry point under
`InputBackend/InputDec/` outside the guard; the policy's doc comment is `IDTextEditorBackendKernelCallPolicy` in
`IDTextEditorBackendModuleProbe.swift`.

## OS certification

- The kernel is certified against exactly one OS build: iOS 26.5 / 23F73 (`Vendor/VENDOR.md`).
- Selection uses a floor, not that build: `IDTextEditorBackend.isSupported()` accepts iOS 17.0 and later and evaluates
  the mandatory contracts against the live runtime on every call, so an ABI change on an uncertified OS falls back to
  the legacy backend.
- Before enabling the backend more widely, re-run the differential corpus (`docs/input-backend-differential-baseline.md`,
  which covers only the legacy backend today) against it on more than one OS build. A matching manifest type encoding
  does not prove matching behaviour on an OS the kernel was never certified for.

## What this code may contain

No canvas-shaped selector may leak into the kernel; `IDProjectSmokeTests` (`Host/Engine/`) checks this from the source
side. `VendorSnapshotIntegrityTests` guards only the two generated artifacts.
