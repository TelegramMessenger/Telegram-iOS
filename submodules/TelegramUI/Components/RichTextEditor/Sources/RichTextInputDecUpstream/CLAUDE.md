# InputDec text engine (`Sources/RichTextInputDecUpstream`)

The vendored InputDec text engine that the engine editor drives. This repo owns it: edit it here, with no upstream to
change first, no re-port and no hash list. Kernel-only rules are in `Sources/RichTextInputDecObjC/CLAUDE.md`, the editor
that drives the engine in `Sources/RichTextEngineEditor/CLAUDE.md`, shared rules in the package `CLAUDE.md`
(`submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md`).

## Provenance

Read `PROVENANCE.md` before touching the engine: it records the revision each file was taken at and every way this copy
differs from its source. Two of them:
- Every file is wrapped in `#if TARGET_OS_IOS`, so the module compiles to nothing on macOS. A `swift build` proves
  nothing about this code.
- `IDPrivateUIKit.m`'s `IDInteractionABISpec` carries an `objc_runtime_name` attribute.
  `Host/TGRichTextInputDecHostPreflight.m` was carved out of that file and defines a class with the same name; without
  the attribute the two collide at link time.

All of InputDec (source, tests, fixtures, scripts, docs) is in this repo; nothing exists only in `~/Documents/InputDec`.

## Tests

- The engine's own suites (unit, the stock-`UITextView` oracle host, fixtures, UI tests) are in `Host/Engine/`
  (`Host/Engine/README.md`):
  `xcodebuild test -project Host/InputDecHost.xcodeproj -scheme InputDecEngine -destination "platform=iOS Simulator,id=<udid>" -parallel-testing-enabled NO`.
  They drive a real keyboard on a shared simulator, so `-parallel-testing-enabled NO` is required;
  `IDProjectSmokeTests` checks that documented test commands include it. `Scripts/hostapp.sh test` runs this scheme
  too: a change here must pass the engine's contracts, not just the host's.
- The engine is on the app graph:
  `//Telegram:Telegram → … → ChatRichTextEditorComposer → RichTextEngineEditor → RichTextInputDecUpstream`
  (`bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'`).
- `Tests/RichTextEditorUIKitTests/InputDecUpstreamHostSmokeTests.swift` starts the host, makes it first responder and
  types into it, and pins the runtime contract gate at 140 preflighted contracts, fed by the pristine manifest (a count
  of 0 means the gate checks nothing). It does not run automatically.

## Rules

- **No `+load`.** `IDBlockTextView` installs the private `UIKeyboardInput` protocol in its initializer, where a failure
  lands in an existing `@catch` and becomes a failed construction the host can check for. A `+load` that throws is an
  uncaught `NSException` before `main()`, which no guard or flag can stop. Check:
  `grep -rn "^+ (void)load" Sources/RichTextInputDecUpstream/`.
- **No `UITextView` or private canvas class/selector in the source**, even in a comment (`IDProjectSmokeTests`).
- **Private UIKit names**: every name crossed with UIKit is spelled through `TGPN_<name>()` (generated from
  `Scripts/private-runtime-names.txt`), UIKit's callbacks are compiled under neutral `tgpn_` names that `+initialize`
  adds under the private ones, and the embedded contract tables are stored encoded. `PrivateRuntimeNamesTests` guards
  the sources and `Scripts/scan-private-runtime-names.py` a release binary; the full rules are in the package
  `CLAUDE.md`, "Private UIKit names are not in the binary".
