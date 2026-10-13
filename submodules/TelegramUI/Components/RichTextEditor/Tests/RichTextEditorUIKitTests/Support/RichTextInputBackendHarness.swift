#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Which `RichTextInputBackend` conformer `makeBackendHarness` wires into the canvas it builds.
///
/// Exactly one case today. `case inputDec` is added only in stage 2, when a second backend exists to
/// select — adding it here is a one-line, additive change; nothing in this file's `.legacy` arm needs
/// to move for it to land, because the concrete legacy-backend construction lives in exactly one switch
/// arm below (see the "exactly one place" test in `RichTextInputBackendHarnessTests.swift`).
enum RichTextInputBackendKind {
    case legacy
}

/// Which `BlockLayoutEngine` conformer backs every box the harness builds, mirroring the
/// `BlockLayoutBackend.forceTextKit1` runtime toggle (`PKG/CLAUDE.md`, "Dual layout-engine back-port").
enum RichTextInputHarnessLayoutEngine {
    case textKit2
    case textKit1
}

/// The backend-agnostic test factory's product: a fully constructed, fully attached, NOT-yet-hosted
/// `DocumentCanvasView` plus the recorder wired to observe it, and (optionally) a facade wrapping a
/// SEPARATE canvas whose hooks are wired to the same recorder for the facade-hook events only.
///
/// This exists so stage 2 can re-run every stage-1 suite against `IDTextEditorBackend` by subclassing
/// and overriding only a factory method (decision 10) — nothing here may name a concrete backend type
/// except the one switch arm in `makeBackendHarness` that selects `.legacy`. Every stored/computed
/// member below reads through `canvas`/`recorder`, never through a concrete backend type, so a second
/// backend flavor changes nothing about how a subclassed suite consumes this type.
///
/// `~1600` existing tests assert against `v.boxes[i]`, `textStart`, `v.anchor`, `v.head`,
/// `(box as! BlockBox).currentParagraph().text` and `v.undoManagerOverride` — all of that stays
/// reachable because `canvas` is the real, concrete `DocumentCanvasView`, not a narrowed protocol view
/// of it.
@MainActor
@available(iOS 16.0, *)
final class RichTextInputBackendHarness {
    let canvas: DocumentCanvasView
    let facade: RichTextEditorView?
    let backendKind: RichTextInputBackendKind
    let layoutEngine: RichTextInputHarnessLayoutEngine
    let recorder: RichTextInputEventRecorder

    /// The value of `BlockLayoutBackend.forceTextKit1` captured BEFORE the factory wrote it.
    /// `tearDown()` restores it; a leaked `true` converts the rest of the bundle into a TK1 run.
    let previousEngine: Bool

    /// Hosting window for `hostInWindow()`. `nil` until that method runs; torn down by `tearDown()`.
    /// A view can only become first responder once it is in a window (`SelectionInteractionTests`),
    /// so this is also what makes `makeFirstResponder()` capable of succeeding.
    private var window: UIWindow?

    /// A class has no memberwise initializer, and the factory calls this exact six-parameter shape.
    init(canvas: DocumentCanvasView, facade: RichTextEditorView?,
         backendKind: RichTextInputBackendKind, layoutEngine: RichTextInputHarnessLayoutEngine,
         recorder: RichTextInputEventRecorder, previousEngine: Bool) {
        self.canvas = canvas
        self.facade = facade
        self.backendKind = backendKind
        self.layoutEngine = layoutEngine
        self.recorder = recorder
        self.previousEngine = previousEngine
    }

    // MARK: - Selection surface
    //
    // Plain pass-through to `canvas.anchor`/`canvas.head` — the exact surface ~1600 existing tests
    // already read/write directly (`v.anchor`, `v.head`), so the harness must not shadow it with
    // separate state that could drift from what `canvas` reports. (TASK 35: those are no longer canvas
    // STORAGE — they are forwarders onto the backend's `canonicalSelectionStorage`, which makes the
    // no-shadowing rule stricter, not looser: a harness copy would now diverge from the one authority
    // rather than from a second one. TASK 40a CONVERTED THE TWO SETTERS onto
    // `canvas.setSelectionForTesting(anchor:head:)`, which is why each reads the OTHER endpoint back
    // off the canvas: the seam writes BOTH, so a single-endpoint pass-through has to re-supply the
    // one it is not changing. `RichTextInputBackendHarnessTests.test_anchorAndHeadAreReadableAndWritable`
    // is the pin — it writes each endpoint separately and asserts the other did not move.)

    var anchor: Int {
        get { canvas.anchor }
        set { canvas.setSelectionForTesting(anchor: newValue, head: canvas.head) }
    }
    var head: Int {
        get { canvas.head }
        set { canvas.setSelectionForTesting(anchor: canvas.anchor, head: newValue) }
    }

    var revision: UInt64 { canvas.documentRevision }
    var layoutGeneration: UInt64 { canvas.layoutGeneration }

    /// `canvas.markedRange` is a bare `(from: Int, to: Int)?` tuple (DocumentCanvasView.swift); this
    /// mirrors `RichTextInputEventRecorder.record(_:)`'s own flatten-then-map so the two never disagree
    /// on shape.
    var markedRange: NSRange? {
        canvas.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) }
    }

    /// The isolated per-test undo manager the factory installs into `canvas.undoManagerOverride`
    /// (`UndoBufferIsolationTests`'s seam). Force-unwrapped: the factory always installs one before
    /// returning, so a nil here would mean the factory itself is broken, not a caller error.
    var undoManager: UndoManager { canvas.undoManagerOverride! }

    // MARK: - Seeding (only meaningful before the initial `layoutIfNeeded()` the factory already ran —
    // callers that reseed after that point are responsible for their own `simulateParentLayout()` /
    // `layoutIfNeeded()` follow-up, exactly like every existing canvas-direct test).

    func setParagraphs(_ texts: [String], width: CGFloat) {
        canvas.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: width)
    }

    func setBlocks(_ blocks: [Block], width: CGFloat) {
        canvas.setBlocks(blocks, width: width)
    }

    // MARK: - Selection helpers
    //
    // Route through `setSelectionForTesting(anchor:head:)` (the one supported raw-selection test seam,
    // `DocumentCanvasView.swift`) rather than assigning `anchor`/`head` above directly — matching the
    // established convention every new suite in this plan follows.

    func caret(_ offset: Int) {
        canvas.setSelectionForTesting(anchor: offset, head: offset)
    }

    func select(_ from: Int, _ to: Int) {
        canvas.setSelectionForTesting(anchor: from, head: to)
    }

    // MARK: - Hosting / first responder
    //
    // Deliberately two SEPARATE steps, never combined: `hostInWindow()` only makes first-responder
    // activation POSSIBLE (a view must be in a window first); it must never itself call
    // `becomeFirstResponder()`. Attach already completed synchronously inside `DocumentCanvasView.init`
    // (steps 1-4 of the spec's six-step order: canvas + clients construction, backend selection in
    // `makeBackendHarness`'s switch, `attach(to:)` seeding the initial revision/selection) before this
    // harness object could even be constructed, so first-responder activation — only reachable through
    // the explicit `makeFirstResponder()` below — can never precede it.

    /// Canonical window-hosting shape, lifted from `SelectionInteractionTests.swift:9-35`.
    /// `installSelectionInteractions()` runs FIRST, mirroring `canvasWithInteraction()` there (gesture
    /// recognizers installed before the view enters a window).
    func hostInWindow() {
        canvas.installSelectionInteractions()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.addSubview(canvas)
        window.makeKeyAndVisible()
        canvas.layoutIfNeeded()
        self.window = window
    }

    @discardableResult
    func makeFirstResponder() -> Bool {
        canvas.becomeFirstResponder()
    }

    // MARK: - Layout

    /// Chains through whatever is currently installed on `canvas.onContentSizeChange` — which, after
    /// the factory's `recorder.attach(canvas:)`, is the recorder's own recording wrapper — rather than
    /// overwriting it the way the plain `DocumentCanvasView.simulateParentLayout()` test helper does.
    /// Overwriting here would silently drop the recorder's `.canvasContentSizeChanged` event for every
    /// later edit, which is exactly the kind of self-invented, disclosed-but-unpinned choice the task
    /// brief warns about — so `RichTextInputBackendHarnessTests.test_simulateParentLayoutChainsThroughTheRecorder`
    /// pins both halves (the recorder still sees the event AND the relayout still runs).
    func simulateParentLayout() {
        let previous = canvas.onContentSizeChange
        canvas.onContentSizeChange = { [weak canvas] in
            previous?()
            canvas?.layoutContent()
        }
    }

    func drainMainQueue(_ testCase: XCTestCase) {
        recorder.drainMainQueue(testCase)
    }

    /// Every suite using the harness MUST call this from XCTestCase.tearDown(). The engine flag is
    /// process-global (BlockLayoutEngine.swift:148), so a leaked `true` silently converts every
    /// later suite in the bundle into a TextKit-1 run — a failure that looks like an unrelated
    /// layout regression hundreds of tests away.
    func tearDown() {
        recorder.reset()
        window?.isHidden = true
        window?.resignKey()
        window = nil
        BlockLayoutBackend.forceTextKit1 = previousEngine
    }
}

/// Backend-agnostic test factory. `backend: .legacy` is the only case today; the concrete legacy
/// backend type is named in exactly ONE place in this file — the `.legacy` switch arm immediately below
/// — so stage 2 adds a second arm without editing this one.
///
/// Ordering is load-bearing (spec's six-step attach order, mirrored here):
/// 1. The layout-engine flag is read at BLOCK-CONSTRUCTION time (`BlockLayoutEngine.swift:151`), so it
///    is written BEFORE any `setBlocks`/`setParagraphs` call below (and before `DocumentCanvasView.init`,
///    which lays out nothing on its own but whose backend attach doesn't touch layout either way).
/// 2. Backend SELECTION happens here, in the switch; construction of the canvas (which itself
///    constructs the six Telegram input clients and calls `inputBackend.attach(to: self)` before its
///    `init` returns) is step 1 of the spec order, backend selection is step 2, and initial
///    revision/selection installation + `attach(to:)` are steps 3-4 — ALL of that completes
///    synchronously inside the `DocumentCanvasView(inputBackend:)` call below.
/// 3. Seed the initial content.
/// 4. Frame + layout, matching the fixture shape ~124 existing test files already use.
/// 5. Install the isolated undo manager (the seam every undo test uses).
/// 6. Attach the recorder (step 5, "install interactions", is the LATER `hostInWindow()` call — see its
///    doc comment — never here); optionally build the facade; `reset()` so attach-time noise from the
///    steps above never pollutes a caller's first assertion. First-responder activation (step 6) is
///    reachable ONLY via the harness's own `makeFirstResponder()`, which this factory never calls.
@MainActor
@available(iOS 16.0, *)
func makeBackendHarness(backend: RichTextInputBackendKind = .legacy,
                        engine: RichTextInputHarnessLayoutEngine = .textKit2,
                        facade: Bool = false,
                        paragraphs: [String] = ["Alpha", "Beta"],
                        width: CGFloat = 300) -> RichTextInputBackendHarness {
    let previousEngine = BlockLayoutBackend.forceTextKit1
    BlockLayoutBackend.forceTextKit1 = (engine == .textKit1)

    let canvas: DocumentCanvasView
    switch backend {
    case .legacy:
        canvas = DocumentCanvasView(inputBackend: LegacyRichTextInputBackend())
    }

    canvas.setParagraphs(paragraphs.enumerated().map {
        ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
    }, width: width)
    canvas.frame = CGRect(x: 0, y: 0, width: width, height: 600)
    canvas.layoutIfNeeded()

    let undo = UndoManager()
    undo.groupsByEvent = false
    canvas.undoManagerOverride = undo

    let recorder = RichTextInputEventRecorder()
    recorder.attach(canvas: canvas)
    var editor: RichTextEditorView?
    if facade {
        let view = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        view.layoutIfNeeded()
        recorder.attach(facade: view)
        editor = view
    }
    recorder.reset()

    return RichTextInputBackendHarness(canvas: canvas, facade: editor, backendKind: backend,
                                       layoutEngine: engine, recorder: recorder,
                                       previousEngine: previousEngine)
}
#endif
