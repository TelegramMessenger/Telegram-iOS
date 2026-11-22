# InputDec

## Project purpose

InputDec is a private, iOS 26.5-only research implementation of text editors built directly on
`UIScrollView`, `UITextInput`, and TextKit 2. The unchanged flat `IDTextView` remains the stock-like
oracle. The **Multi-Block Experiment** control swaps that editor area for `IDBlockTextView`, whose
canonical text is projected across independently laid-out blocks without hosting UIKit's ready-made
editor.

The demo is an exploration target, not a source-compatible replacement for every public or private
UIKit text feature.

## iOS and Xcode requirements

This repository was built and verified with:

- Xcode 26.5 (`17F42`).
- The iOS 26.5 (`23F73`) simulator runtime and SDK 26.5.
- The pinned iPhone 17 Pro K3 simulator with UUID
  `FA6F7462-AA97-42FE-9E57-8DA0593CE756`.
- An iOS 26.0 deployment target.
- XcodeGen available as `xcodegen` (the development machine uses `/opt/homebrew/bin/xcodegen`).

The private contracts are runtime-version-specific. A newer or older UIKit build is not assumed to
be compatible merely because it satisfies the deployment target.

## Private API and App Store warning

This app dynamically constructs private UIKit classes, sends private selectors, and adopts an
internal paste-support protocol. It is intentionally **not App Store-safe** and must not be shipped
as a production application. Private API rejection risk is separate from ordinary correctness: a
locally correct build can still be categorically unsuitable for App Store distribution, and an OS
update can break the recovered ABI.

The mandatory input contract has no reduced-fidelity fallback: a missing or
ABI-incompatible constructor/delegate contract rejects editor construction
before first-responder activation. Optional behavior capabilities fail closed
to project-owned plaintext editing, selection presentation, scrolling, or
paste behavior and are reported explicitly.

## Architecture and component graph

`IDTextView` is a `UIScrollView` and complete `UITextInput`/`UIKeyInput` implementation. It owns the
plain-text TextKit 2 graph. `IDTextLayoutCanvasView` is the clean-room composition mirror: it is the
viewport delegate and retains one custom rendering surface per live layout fragment instead of
drawing the entire document itself. Recovered UIKit private layout, input, and interaction
controllers supply semantic ranges/geometry and UIKit's native gestures, loupe, selection UI,
edit-menu behavior, paste pipeline, and floating cursor.

```text
IDTextView : UIScrollView <UITextInput>
├── NSTextContentStorage
│   └── NSTextStorage (plain text)
├── NSTextLayoutManager
│   ├── NSTextContainer ── private host association ──> IDTextLayoutCanvasView
│   └── NSTextViewportLayoutController
│       └── delegate ──> IDTextLayoutCanvasView
├── IDTextLayoutCanvasView
│   ├── NSMapTable (weak NSTextLayoutFragment keys, strong surface values)
│   │   └── IDTextRenderingSurfaceView ──> NSTextLayoutFragment drawAtPoint:inContext:
│   ├── IDTextCanvasAttachmentCoordinator
│   │   ├── ordinary TextKit attachment-provider views
│   │   └── paragraph-anchored provider/drawing surfaces
│   ├── external/custom rendering surfaces
│   ├── text-emphasis plane
│   ├── selection-container plane
│   ├── optional hover-effect layer
│   └── Writing Tools animated-layout state
├── _UITextKit2LayoutController (range and geometry adapter)
│   └── UITextInputController (selection, marked text, edits, tokenizer, undo)
└── UITextInteractionAssistant
    ├── UIKit-owned text gesture recognizers and loupe
    └── IDTextView selection-container view
```

Private declarations, class/selector lookup, Objective-C runtime mutation, and typed
`objc_msgSend` calls are confined to `PrivateUIKit/`. Public editor code talks to typed bridge
functions and does not import private SDK headers.

The private text-container host is deliberately the custom canvas, matching the recovered TextKit 2
composition. `IDTextView` remains the public input/scroll host. Production never instantiates,
subclasses, or asks UIKit to dequeue its private canvas class.

The experimental multi-block graph is separate from the flat oracle:

```text
IDBlockTextView : UIScrollView <UITextInput>
├── IDBlockDocument (the one canonical rich document)
│   └── U+000A separators are structural boundaries, never block contents
├── IDCanonicalTextStorageAdapter : NSTextStorage (the mandatory canonical façade)
├── IDBlockStackCanvasView
│   └── one IDBlockLayout / TextKit 2 graph / canvas per derived block
├── IDRichTextLayoutController (clean-room canonical range and geometry owner)
├── UITextInputController (one native input owner)
└── UITextInteractionAssistant (one native interaction owner)
```

Canonical offsets and selections are UTF-16 offsets into the blocks joined by one virtual newline
between neighbors. Return inserts a structural newline and splits a block; backward-delete at the
start of the following block deletes that newline and merges identities. Derived block storages are
layout mirrors only: edits enter through the canonical storage façade and reconcile every canvas.
Switching modes resigns, removes, and releases the old editor graph before installing the other;
the view hierarchy never contains both editors or two native owner pairs.

## Behavior backends and capability reports

`IDBlockTextView` has two iOS 26.5 behavior backends:

- `reference` is the public default and retains the recovered concrete UIKit
  layout/canvas path as the behavioral control.
- `minimal` constructs the UIKit input controller directly over
  `IDRichTextLayoutController`. It does not construct
  `_UITextLayoutControllerBase` or `_UITextKit2LayoutController`, access the
  private `+0x50` canvas map, or use UIKit's private canvas/rendering graph.
  UIKit still owns input semantics, interaction, floating cursor, checking,
  prediction, paste, and dictation when each independently audited capability
  is available. For vertical edge autoscroll, UIKit's interaction assistant
  still recognizes the gesture and calls the retained `UITextAutoscrolling`
  boundary, while `IDVerticalAutoscroll` owns edge geometry, 75 ms cadence,
  scrolling, and selection extension. The reference backend alone retains the
  concrete `UIAutoscroll` implementation.

Launch a block-editor demo in minimal mode with:

```text
-InputDecBehaviorBackend minimal
```

Omitting the argument, or passing `reference`, preserves the reference
default. Block scenarios expose `behavior-capability-status` as sorted JSON
with `backend` and `report`. The report records the pinned OS/build,
`detached`, and one entry per requested capability:

- `unavailable`: a required class/member is absent.
- `rejectedContract`: a present member has an incompatible ABI.
- `available`: the contract validated but was not activated.
- `active`: the validated capability is serving this editor.

Each entry also records its required members, observed ABIs, dependencies,
fallback, and rejection reason. Optional failures do not silently widen a
contract. The complete iOS 26.5 inventory is
`PrivateUIKit/Contracts/UIKitBehaviorContracts-iOS26.5.json`; reference-only
concrete layout/canvas entries are separate from the minimal capabilities,
and diagnostic introspection is isolated in the test-only manifest.

Pass 1 is certified only for iOS 26.5 build `23F73`. Porting this work into
Telegram, supporting iOS 16–25, and a limited TextKit 1 backend remain
explicitly deferred to later passes.

## Verified autocorrection scope

The English (US) iOS 26.5 decision slice passes all 21 combinations of three block locations and
seven accept, reject, and immediate-undo actions. Each stock/custom half runs after an independent
simulator erase so UIKit learning history cannot leak between hosts. See
`docs/superpowers/reports/2026-07-21-autocorrection-decision-parity.md` for the matrix and evidence.
Non-English/IME composition is explicitly outside this verified slice.

## Verified inline-prediction scope

The English (US) iOS 26.5 inline-prediction slice passes all nine combinations of three block
locations and accept, dismiss-then-type, and accept-then-delete lifecycles. The frozen stock
fixture types `i look forward `, observes UIKit's marked `to` prediction, and uses one physical
software-keyboard Space to accept it. The deletion lifecycle compares the first and second
Backspaces independently.

UIKit owns prediction generation, presentation, timing, acceptance, dismissal, and deletion
policy. InputDec forwards attributed marked text to its one native input controller and continues
to own only canonical storage plus custom layout and drawing. The authoritative matrix runs every
stock/custom pair twice in both orders after independently erasing each host execution. See
`docs/superpowers/reports/2026-07-23-inline-prediction-lifecycle-parity.md` for the complete matrix,
commands, and retained limitations.

## Native spelling pipeline

Spell checking follows UIKit's annotation and temporary-rendering path end to end:

```text
spellCheckingType / keyboard state
→ UITextInputController continuous-spelling state
→ UITextCheckingController checks the word whose selection was left
→ private spelling annotation on the annotated replacement
→ _UITextKit2LayoutController temporary rendering attributes
→ invalidation broadcast to the registered custom canvas
→ visible IDTextRenderingSurfaceView redraw
→ NSTextLayoutFragment renders the native red marker
```

No persistent public underline attribute and no handcrafted dotted line is added by InputDec.
Correcting the word removes the native temporary marker through the same TextKit path. Checking is
naturally asynchronous: the first departed word may remain unannotated while the real English
`UITextChecker` service loads, and subsequent words are checked once it is ready. Automated spelling
tests first verify the installed `en_US` checker, then wait for the native result and skip with an
explicit runtime reason only when that checker is unavailable.

## Layered text-input verification

Text-input verification is split by what it can prove. All three commands use
the pinned K3 simulator and a repository-wide lock. Simulator parallel testing
must remain disabled; do not overlap XCTest runs.

The routine `test-fast` gate runs the 54 versioned semantic scenarios through
fresh stock and custom hosts in both orders:

```sh
Scripts/run-text-input-fast.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-fast
```

Use `--without-building` after a prepared build. Tier 1 proves equivalent
responses to equal semantic UIKit transactions, including canonical text,
selection, marked text, delegate/storage traces, Undo state, traits, and
geometry. It does not prove candidate UI, keyboard learning, language
activation, or keyboard-process timing. The retained current-head run
`.inline-formatting-task9-fast-final/` passed 212/212 with zero skips in
9.059 seconds of XCTest time.

The representative `test-keyboard-sentinel` gate uses real system keyboards:

```sh
Scripts/run-text-input-keyboard-sentinels.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-keyboard-sentinels
```

Tier 2 covers 24 English, Japanese, and Simplified Chinese methods: twelve
reference controls and the same twelve explicit minimal-backend sentinels.
They cover autocorrection accept/reject, inline-prediction accept/dismiss, two
floating-cursor lifecycles, four semantic-inline-formatting lifecycles, IME
return/undo, and IME candidate commit. The formatting methods compare a stock
`UITextView` with `IDBlockTextView` while using the real English (US) keyboard
for bold typing, autocorrection replacement, inline-prediction accept/reject,
and marked-text commit.

The final Pass 1 iOS 26.5 run
`.minimal-kernel-pass1-final-keyboard/` passed 24/24 with zero failures or
skips in 784 seconds wall time. The companion fast differential
`.minimal-kernel-pass1-final-fast-complete/` passed 216/216 with zero failures
or skips in 11.665 seconds of XCTest time.

## Semantic inline formatting

The `inline-formatting` demo supports bold, italic, underline, and
strikethrough. Each command applies to the full selected range, including
selections spanning independent blocks. With a collapsed caret, the same
controls update explicit typing state without changing existing text or
creating an undo item; subsequent UIKit-owned insertion, correction,
prediction, and composition use that state.

Semantic inline markers are the document truth. Fonts, underline styles, and
strikethrough styles are derived presentation attributes and are never
imported back as author intent after normalization. Structural U+000A
separators between blocks always remain unformatted.

The demo exposes `inline-format-controls`, `inline-format-bold`,
`inline-format-italic`, `inline-format-underline`,
`inline-format-strikethrough`, and `inline-format-diagnostics` accessibility
identifiers. The real-keyboard stock/custom probe uses
`inline-formatting-keyboard-status`.

Run the fast semantic differential gate and the serialized real-keyboard gate
with:

```sh
Scripts/run-text-input-fast.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-fast

Scripts/run-text-input-keyboard-sentinels.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-keyboard-sentinels
```

All simulator XCTest execution is serialized. Every simulator
`xcodebuild test` command must include `-parallel-testing-enabled NO`, and
XCTest processes must never overlap on the pinned simulator.

The authoritative `test-certify-ios26` gate runs Tier 1, Tier 2, and every
independently isolated complete matrix:

```sh
Scripts/run-text-input-ios26-certification.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output .text-input-ios26-certification
```

Tier 3 contains 24 IME, 21 autocorrection, and 9 inline-prediction logical
rows, each repeated twice in both stock/custom orders: 216 comparisons and
432 independently isolated host executions. It remains the authority for OS
keyboard integration and is intentionally a multi-hour certification run,
not a per-edit gate. Preserved evidence roots are
`.ime-task9-complete-matrix-attempt5/`,
`.autocorrection-task6-complete-matrix-green2/`, and
`.inline-prediction-task6-complete-matrix-attributed3/`. The smaller
`.inline-prediction-task6-complete-matrix-stable1/` export supplies all nine
identifiers used by the provenance-only check below.

The versioned 54-scenario corpus can be cross-checked against the exported
stock evidence without rerunning the matrices:

```sh
Scripts/validate-text-input-scenario-provenance.py \
  --fixture-root TestFixtures/TextInputScenarios \
  --ime-evidence .ime-task9-complete-matrix-attempt5 \
  --autocorrection-evidence .autocorrection-task6-complete-matrix-green2 \
  --inline-prediction-evidence .inline-prediction-task6-complete-matrix-stable1
```

This opt-in check fails closed when evidence is missing, an identifier is
absent, repetitions disagree, or a fixture terminal document diverges. The
ordinary unit suite stays portable and never depends on untracked evidence.

## Build, test, install, and launch

Generate the project:

```sh
xcodegen generate
```

Run the complete clean test suite on the pinned simulator:

```sh
rm -rf .derivedData-final
xcodebuild clean test -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -derivedDataPath .derivedData-final
```

Build independently against SDK 26.5:

```sh
xcodebuild build -project InputDec.xcodeproj -scheme InputDec \
  -sdk iphonesimulator26.5 \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -derivedDataPath .derivedData-final
```

Install and launch the built app:

```sh
xcrun simctl install FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  .derivedData-final/Build/Products/Debug-iphonesimulator/InputDec.app
xcrun simctl launch FA6F7462-AA97-42FE-9E57-8DA0593CE756 com.inputdec.demo
```

The app is storyboard-free and opens directly into the demo editor when compatibility checks pass.

### Deterministic UI scenarios

The five canvas UI regressions launch private demo-only scenarios for caret scrolling, selection
and handle dragging, long-press insertion movement, native spelling pixels, and attachment-provider
viewport stability:

```sh
xcodebuild test -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -derivedDataPath .derivedData-ui \
  -only-testing:InputDecUITests/IDTextLayoutCanvasUITests
```

For manual inspection, install the app and launch one of `caret`, `selection`, `spelling`, or
`attachment`:

```sh
xcrun simctl launch FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  com.inputdec.demo --id-ui-scenario spelling
```

Ordinary launch arguments leave the normal exploration demo unchanged. Scenario-only accessibility
status elements expose selection/caret/visible geometry, spelling state, and the attachment
provider's document frame so UI tests do not depend on undocumented accessibility identities for
the caret, handles, or loupe.

The multi-block UI suite uses real public keyboard input for insertion, Return splitting,
backward-delete merging, caret autoscroll, and spelling. Launch it with:

```sh
xcodebuild test -parallel-testing-enabled NO -project InputDec.xcodeproj -scheme InputDec \
  -destination 'platform=iOS Simulator,id=FA6F7462-AA97-42FE-9E57-8DA0593CE756' \
  -derivedDataPath .derivedData-ui \
  -only-testing:InputDecUITests/IDBlockTextViewUITests
```

Each launch uses one of `caret`, `selection`, `boundary`, or `spelling`:

```sh
xcrun simctl launch FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  com.inputdec.demo --id-block-ui-scenario boundary
```

The `block-status` accessibility value is deterministic, locale-independent JSON. Tests parse the
object and compare exact values rather than matching display fragments:

```json
{
  "blockCount": 2,
  "blockOrigins": [{"x": 0, "y": 0}, {"x": 0, "y": 32}],
  "canonical": "alpha\nbeta",
  "caret": {"height": 24, "width": 2, "x": 36, "y": 32},
  "scenario": "selection",
  "selection": {"length": 4, "location": 3},
  "spelling": "none",
  "state": "public-selection",
  "visible": true
}
```

The numeric example illustrates the schema; runtime geometry comes from layout. All caret fields
are finite and nonzero, and the origin array is finite and ordered. The four scenarios respectively
cover type/split/scroll visibility, public Shift+Right selection across the structural newline,
boundary merge, and native temporary spelling pixels.

## Diagnostics behavior

Tap **Diagnostics** to display the active layout-construction path and the complete required
class/selector/protocol report. A compatible runtime shows `All required contracts present`.

If compatibility fails at launch, the app does not allocate an `IDTextView` or any private editor
controller. Instead it presents the complete report in a scrollable view. The report supports the
Copy responder action, long-press copying, and an accessibility Copy action so it can be preserved
without relying on the private text stack that failed validation.

The preflight covers the complete unconditional private controller, assistant, layout, and
container selector inventory. Optional/fallback sends are labeled separately. Immediately after
input-controller construction, the editor safely queries `_rangesForBackwardsDelete` and validates
that its non-nil aggregate supports `unionRange`, without invoking the aggregate or changing text,
selection, or undo history. The action path repeats that guard immediately before its typed
`unionRange` send; TextKit 2 range adapters are likewise validated at use. If private editor
construction raises that internal compatibility exception, the demo catches only that exception
class and presents its stage and reason in the same copyable fatal report; unrelated exceptions
continue to fail fast.

## Manual transient-UI matrix

This is an executable manual specification and truth record. An unchecked item is **unverified in
the final Task 7 touch-selection session**, even if deterministic geometry or graph tests cover
related behavior. Checked touch-selection items are backed by stock/custom range comparisons and
retained visible screenshots; no IME, autocorrection, or other transient UI is inferred from
construction.

- [ ] Native caret shape and blink in both flat and multi-block modes — unverified.
- [x] Single-tap at the beginning, middle, and end of wrapped lines; confirm placement is nearest to the touch.
- [x] Double-tap word selection.
- [x] Triple-tap paragraph selection.
- [x] Native loupe appearance and tracking.
- [x] Leading and trailing native selection handles.
- [x] Drag a selection handle to the top and bottom edge; confirm selection autoscroll.
- [x] Floating cursor across blocks — verified on the pinned iOS 26.5 simulator for collapsed
  movement, selection extension/reversal, structural boundaries, mixed BiDi, upper/lower
  autoscroll, normal end, and lifecycle interruption.
- [x] Reject autocorrection at and away from a block boundary.
- [x] Accept autocorrection at and away from a block boundary, including immediate undo.
- [x] Accept, dismiss-then-type, and accept-then-delete an inline prediction at and away from a
  block boundary; confirm exact selection and caret placement after every phase.
- [ ] Japanese marked text at a structural boundary — unverified.
- [ ] Chinese marked text at a structural boundary — unverified.
- [ ] Cancel and commit marked-text composition — unverified.
- [ ] Dictate a sentence and confirm insertion at the selected range.
- [ ] Hardware-key character/word/line/document navigation — unverified.
- [ ] Hardware-key selection extension — unverified.
- [ ] Verify Cut, Copy, Paste, Select, and Select All from the native edit menu.
- [ ] Verify insertion, cut, and paste Undo and Redo through the responder chain.
- [ ] Toggle Editable off; confirm selection remains possible while keyboard mutation is blocked.
- [ ] Toggle Selectable off and on; confirm native interaction gestures disappear and return without duplicates.
- [ ] Scroll the long sample, then use Reset and confirm the original text and top position return.
- [ ] Open Diagnostics and confirm `All required contracts present` and the complete report are visible.
- [ ] Dark mode — unverified.
- [ ] Accessibility Dynamic Type — unverified.
- [ ] Landscape — unverified.
- [ ] iPad — unverified.

## Automated coverage

By the explicit lexical convention “Objective-C methods whose signature begins `- (void)test`,”
the current source defines 499 unit/integration tests under `Tests/` and 117 UI tests under
`UITests/` (616 total), including the flat-canvas, multi-block, touch-selection, and floating-cursor
scenarios. Simulator tests must run with `-parallel-testing-enabled NO`; parallel execution is
unsupported by this harness and does not count as verification evidence.

Native spelling-marker verification uses a persistent English-US profile on the pinned K3
simulator. Install or restore it explicitly after running an IME suite:

```bash
Scripts/with-inputdec-simulator-test-lock.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 -- \
  Scripts/provision-english-us-keyboard.sh \
    FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
    <fresh-evidence-directory> --verify
```

Ordinary spelling verification is read-only with respect to simulator keyboard state:

```bash
Scripts/run-verification-stabilization.sh \
  --udid FA6F7462-AA97-42FE-9E57-8DA0593CE756 \
  --output <fresh-evidence-directory>
```

The runner validates the exact locale, language, and keyboard inventory before Xcode starts, then
requires both public UIKit input-mode readings to be `en-US`. It does not reboot, provision,
restart the keyboard service, or retry a failed stock spelling preflight.

The final Task 7 current-head floating-cursor gate passed 209/209 with zero skips, and the inherited
UI gate passed 31/31 with zero skips. Inherited parity passed 11/12; the sole retained failure is
the known native spelling-pixel density difference (custom 104, stock 162, tolerance 12). The
result bundles and exact commands are recorded in
[`2026-07-20-floating-cursor-interaction-parity.md`](docs/superpowers/reports/2026-07-20-floating-cursor-interaction-parity.md).

Coverage is organized as follows:

- `IDProjectSmokeTests`: app shell, compatible/incompatible/construction-failure demo branches,
  failure-safe temporary windows, accessibility layouts, mechanical compatibility-inventory
  audits, source boundaries, and the forbidden-editor source guard.
- `IDPrivateUIKitTests`: required iOS 26 contracts, compatibility reporting, construction paths,
  typed ABI shapes, and runtime recognizer ownership.
- `IDTextCanvasTests`, `IDTextLayoutCanvasViewTests`, and `IDTextRenderingSurfaceViewTests`: TextKit
  2 layout, viewport transactions, keyed surface reuse/teardown, exact geometry, drawing, and
  attachment hosting.
- `IDTextCanvasInvalidationTests`, `IDSpellingIntegrationTests`, and
  `IDTextCanvasAttachmentCoordinatorTests`: native/custom invalidation, real spelling markers, and
  attachment diff/lifecycle behavior.
- `IDTextLayoutCanvasParityTests`: seven normalized comparisons against a stock TextKit 2 editor for
  visible surface geometry, scrolling, content size, caret, selection rects, spelling pixels, and
  attachment provider frames.
- `IDTextViewTests`: text/range semantics, marked text, traits, delegate ordering, commands, paste,
  selection affinity, and controller-owned undo/redo.
- `IDInteractionIntegrationTests`: controller graph, native gestures, selection hosting, geometry,
  insertion- and navigation-driven caret visibility, scrolling, staged aggregate validation,
  responder commands, and public/private callback boundaries.
- `IDTextViewUITests`, `IDProjectUITests`, and `IDTextLayoutCanvasUITests`: launch, one-editor
  identity, typing, toggles, reset, scrolling, keyboard dismissal, diagnostics, caret visibility,
  gesture-driven selection/insertion, native spelling pixels, and attachment viewport return.
- `IDBlockTextViewParityTests` and `IDBlockTextViewUITests`: normalized stock-oracle canonical,
  caret, selection, tokenizer, navigation, BiDi, editing/marked-text/undo, rich structural-run, and
  public-input scenario coverage over the multi-block graph.

The touch-selection UI suite proves UIKit-owned loupe appearance/tracking/dismissal and two native
selection handles through retained pixel evidence rather than accessibility identities. It also
proves stock/custom tap ranges, logical endpoint dragging, and upper/lower edge autoscroll while
the opposite endpoint remains fixed. Autocorrection UI, IME behavior, dictation, hardware-key
navigation, and unchecked device or appearance variants remain unverified checklist items above.

Floating-cursor UI tests use a reusable software-keyboard HID scheduler, atomic status/screenshot
capture, and aligned stock/custom hosts. That support exists only under `UITests/`; production has
no XCTest event-record types, keyboard HID bridge, custom trackpad recognizer, cursor renderer, or
editor-owned floating-cursor timer.

## Hopper provenance

[`docs/hopper/UIKitCore-iOS26.5.md`](docs/hopper/UIKitCore-iOS26.5.md) is the contract ledger. It
records the UIKitCore procedure addresses actually examined in Hopper, pseudo-code responsibilities,
typed message-send shapes, simulator/device divergence, live-runtime observations, and the mapping
from recovered behavior to this implementation. Entries without a recoverable procedure address
are labeled as live-runtime contracts; no address is inferred or fabricated.

## Project organization

- `App/`: scene lifecycle, demo controls, sample corpus, diagnostics, and incompatible-runtime UI.
- `TextView/`: public editor, TextKit 2 ownership, canvas rendering, input forwarding, interactions,
  scrolling, accessibility, and internal cross-file state.
- `PrivateUIKit/`: compatibility ledger enforcement, runtime calls, typed private bridge, and all
  callbacks required by the private controllers.
- `Tests/`: unit, live-runtime contract, integration, source-boundary, and demo smoke coverage.
- `UITests/`: end-to-end launch, typing, controls, scroll, keyboard, and diagnostics coverage.
- `docs/hopper/`: recovered UIKitCore provenance and ABI notes.
- `docs/superpowers/`: design specification and task-by-task implementation plan.
- `project.yml`: reproducible XcodeGen project, targets, settings, deployment target, and scheme.

## Known limitations and divergences

- The public editor API remains plain text. Rich-text mutation, links, data detectors, text
  drag/drop, and find UI are out of scope. The canvas does support TextKit-supplied ordinary
  attachment provider views, paragraph-anchored attachment surfaces, and external/custom rendering
  surfaces; the demo's attachment scenario injects attributed storage internally to exercise that
  recovered composition path.
- Compatibility is pinned to the tested iOS 26.5 runtime. The device UIKitCore image exposes the
  `_UITextLayoutControllerBase` factory, while the iOS 26.5 simulator uses the documented direct
  `_UITextKit2LayoutController` initializer path.
- Three optional input methods absent from the live private controller use documented public
  primitives: two character-offset methods derive positions/ranges, and dictation phrases insert
  their concatenated text through the controller's ordinary insertion path.
- The custom canvas matches the seven normalized stock-reference geometry/rendering oracles on the
  pinned simulator but does not claim pixel-for-pixel identity for every UIKit animation, transient
  overlay, hover implementation, or accessibility mode.
- Automatic caret visibility currently applies its internal content-offset correction synchronously
  without animation. UIKit's recovered path chooses animation from the active animation state and
  temporarily preserves the scroll animation duration; matching that policy remains a fidelity gap.
- Native autocorrection, inline prediction, dictation, IME UI, and hardware-key navigation depend
  on simulator/device services and remain unverified above. Native loupe presentation and tracking
  are verified on the pinned iOS 26.5 simulator by the retained Task 7 screenshots.
- The optional hover-effect layer remains absent unless the runtime supplies one. Writing Tools
  animated-layout state and external-surface ordering are mirrored, but the repository does not
  provide a separate visible hover renderer.
- The two exported demo attachment identifiers exist only to pass UIFoundation's real
  `UTType`/provider-class gate in deterministic demo and test fixtures. The canvas consumes providers
  produced by TextKit and never synthesizes a private provider.
- The simulator can emit unrelated haptic-library, Remote Text Input, debugger-snapshot, and WebKit
  accessibility-loader diagnostics during tests; these must not be hidden globally or confused with
  compiler warnings or test failures.

## No-forbidden-UIKit-editor invariant

No `UITextView` object may be instantiated, subclassed, embedded, proxied, or referenced by
production source. `IDTextView` must remain the only editor view. Unit tests scan `App/`,
`TextView/`, and `PrivateUIKit/` for the forbidden class token, and final verification also rejects
an exact `UITextView` class string in the app executable:

```sh
! strings .derivedData-final/Build/Products/Debug-iphonesimulator/InputDec.app/InputDec \
  | rg '^UITextView$'
```

Documentation and the Hopper ledger name UIKit's class only to explain the invariant and recovered
reference behavior; they do not create a runtime dependency.
