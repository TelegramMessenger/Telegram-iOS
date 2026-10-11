#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorCore
import RichTextEditorDifferentialHarness
import RichTextInputDecObjC
@testable import RichTextEditorUIKit

/// **Task P1 — shared support for the ported stock-`UITextView` parity suites.**
///
/// NOT VENDORED. Written for telegram-ios; see `PROVENANCE.md` in this directory for what IS
/// vendored, from which upstream files, and every deviation.
///
/// ## What this file exists to make possible
///
/// Upstream (`/Users/isaac/Documents/InputDec/Tests/`) certifies its host `IDBlockTextView`
/// against a stock `UITextView` standing beside it in the same window. The port substitutes
/// **Telegram's** host — a `RichTextEditorView` built for the `.inputDec` backend, i.e. a
/// `IDDocumentCanvasView` — for `IDBlockTextView`, and keeps the stock arm verbatim.
///
/// ## Three structural facts that shape every ported assertion
///
/// 1. **The position axes differ.** Upstream's host is *canonically dense*: its `UITextInput`
///    position axis is a plain character count, so upstream compares
///    `-offsetFromPosition:beginningOfDocument toPosition:p` directly against a stock character
///    index. Telegram's is **sparse** — a top-level paragraph boundary occupies TWO position slots
///    while the projected text emits one `"\n"`, and `beginningOfDocument` is raw 1, not 0
///    (measured 2026-08-24, `Tests/DifferentialSupport/include/IDTelegramCharacterAxis.h`). A
///    verbatim offset comparison would therefore fail on *axis skew* rather than on the behaviour
///    under test — a maximally misleading red. Every ported comparison runs through
///    `IDTelegramCharacterIndexForPosition` / `IDTelegramTextRangeForCharacterRange`, the in-tree
///    map written for exactly this in Task 9c; it is exact on the stock arm by construction (for a
///    `UITextView` the prefix length IS the offset) and both arms run it unchanged.
///
/// 2. **Line metrics are not shared and cannot be made to match.** `BlockLayoutEngine` pins each
///    paragraph's line box (`minimumLineHeight == maximumLineHeight`, from
///    `RichTextRenderMetrics`), while a stock `UITextView` uses the font's natural leading. So the
///    two arms wrap at different y for the same font and width, and any probe point derived from
///    ONE arm's caret rect and applied to BOTH lands on different lines. Upstream can do that
///    because both of its arms are TextKit-shaped; we cannot. **Every geometric probe below is
///    therefore derived from the arm it is applied to** — the invariant asserted is "a point
///    between the carets of character N and N+1 resolves to N", which is the hit-testing claim
///    upstream is actually making, expressed so that it survives differing line boxes. Recorded as
///    a deviation, not silently loosened: the *weaker* claim "each arm agrees with itself" is
///    explicitly NOT what is asserted — the resolved CHARACTER INDEX is still compared across arms.
///
/// 3. **The kernel traps in DEBUG unless a reporter is installed.** Every `.inputDec` witness can
///    reach `IDTextEditorBackend.reportKernelFailure(_:witness:)` →
///    `RichTextInputContractViolation.report`, which is `assertionFailure()` with no reporter. Every
///    other `.inputDec` suite in this target installs a logging reporter; `installContractReporter`
///    below is the same one, and the ported suites capture violations so a kernel failure is
///    *reported as a test failure* rather than crashing the whole xctest process (which would take
///    the rest of the run with it and read as a hang).
@MainActor
enum IDStockParity {

    // MARK: - Geometry both arms are built with

    /// Upstream's fixture font (`IDBlockTouchSelectionParityTests.makeCustom:stock:`).
    static let fontSize: CGFloat = 20.0
    static var font: UIFont { UIFont.systemFont(ofSize: fontSize) }

    /// Upstream hosts the two arms side by side at 240×420 inside a 520×440 window. The host arm is
    /// given the same box.
    static let armFrame = CGRect(x: 0, y: 0, width: 240, height: 420)

    // MARK: - The stock arm (kept as close to upstream as the language allows)

    /// Verbatim port of upstream's `IDInlineFormattingOracleTextView`
    /// (`IDInlineFormattingStockOracleTests.m:4-20`): a `UITextView` that returns a 1×0 dummy
    /// `inputView` so becoming first responder does not try to raise a real software keyboard in a
    /// process that has no foreground keyboard scene.
    final class OracleTextView: UITextView {
        private var suppressedInputView: UIView?
        override var inputView: UIView? {
            get {
                if suppressedInputView == nil {
                    suppressedInputView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0))
                }
                return suppressedInputView
            }
            set { suppressedInputView = newValue }
        }
    }

    /// A stock `UITextView` configured the way upstream configures its stock arm.
    static func makeStock(frame: CGRect = armFrame, text: String = "") -> OracleTextView {
        let stock = OracleTextView(frame: frame)
        stock.font = font
        stock.textColor = .black
        stock.backgroundColor = .white
        stock.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        stock.textContainer.lineFragmentPadding = 5.0
        stock.text = text
        return stock
    }

    // MARK: - The host arm

    /// Telegram's host, built for `backend`, loaded with `paragraphs` as top-level body paragraphs.
    ///
    /// **`backend` is a parameter, not a constant, because the Legacy arm is the control.** A
    /// divergence from stock that the SHIPPING (legacy) canvas also shows is not something the
    /// InputDec port introduced; charging it to the port overstates the port's cost. The earlier
    /// differential corpus measured this precisely: 194 of 514 recorded differences were shared with
    /// Legacy. Every parity assertion in this directory therefore runs three ways — stock
    /// `UITextView` (the oracle), Telegram+InputDec, Telegram+Legacy — and classifies each failure
    /// as PORT-DEFECT or PRE-EXISTING.
    ///
    /// `.inputDecIfSupported` (never `.inputDecRequired`): the required form is a
    /// `preconditionFailure` — an un-catchable trap — on a runtime where `isSupported()` is false.
    /// Callers `XCTSkipUnless(IDTextEditorBackend.isSupported())` first, and this function then
    /// asserts the canvas really IS `IDDocumentCanvasView`, so a silent fallback to legacy cannot
    /// masquerade as a passing InputDec arm.
    @available(iOS 17.0, *)
    static func makeHost(paragraphs: [String],
                         backend: RichTextEditorInputBackendPreference,
                         frame: CGRect = armFrame,
                         fontSize: CGFloat = IDStockParity.fontSize) throws -> RichTextEditorView {
        let editor = RichTextEditorView(frame: frame, inputBackend: backend)
        var metrics = RichTextRenderMetrics.default
        metrics.body = RichTextFontSpec(style: .sans, size: fontSize, lineSpacingFactor: 1.0)
        editor.renderMetrics = metrics
        editor.document = Document(blocks: paragraphs.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"), runs: [TextRun(text: text)]))
        })
        switch backend {
        case .legacy:
            XCTAssertFalse(editor.canvasForTesting is IDDocumentCanvasView,
                           "the Legacy control arm was handed an InputDec canvas")
        default:
            _ = try XCTUnwrap(editor.canvasForTesting as? IDDocumentCanvasView,
                              "the editor fell back to the legacy canvas — this suite would then be "
                              + "certifying the WRONG backend while reporting green")
        }
        return editor
    }

    /// The canvas is the object that conforms to `UITextInput`; `RichTextEditorView` forwards
    /// `becomeFirstResponder()` to it (`RichTextEditorView.swift:805`). Reading the editor instead
    /// answers about a plain `UIView` — the trap `IDKeyboardActivationTests` records having fallen
    /// into once already.
    static func input(of editor: RichTextEditorView) -> DocumentCanvasView { editor.canvasForTesting }

    // MARK: - Hosting

    /// Hosts every view in one real key window and lays out. Upstream discovers an existing
    /// `UIWindowScene.keyWindow` with a `rootViewController`; a SwiftPM xctest bundle has no app
    /// delegate and therefore no such window, so the port creates its own — the convention every
    /// other UIKit suite in this target already uses (`IDKeyboardActivationTests.makeWindow`).
    @discardableResult
    static func host(_ views: [UIView], in testCase: XCTestCase,
                     size: CGSize = CGSize(width: 520, height: 440)) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
        } else {
            window = UIWindow(frame: CGRect(origin: .zero, size: size))
        }
        let controller = UIViewController()
        window.rootViewController = controller
        for view in views { controller.view.addSubview(view) }
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        for view in views { view.layoutIfNeeded() }
        testCase.addTeardownBlock {
            MainActor.assumeIsolated {
                for view in views { view.removeFromSuperview() }
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        return window
    }

    // MARK: - The character-axis map (the ONE conversion, applied to both arms identically)

    /// The whole document as text, through the same projection on both arms.
    static func plainText(_ input: UITextInput) -> String {
        guard let range = input.textRange(from: input.beginningOfDocument, to: input.endOfDocument)
        else { return "" }
        return input.text(in: range) ?? ""
    }

    /// `position`'s index on the STOCK character axis, or nil when the input cannot answer. Never
    /// falls back to 0, which is a real and very plausible index.
    static func characterIndex(_ input: UITextInput, _ position: UITextPosition?) -> Int? {
        IDTelegramCharacterIndexForPosition(input, position)?.intValue
    }

    /// `range` as an `NSRange` on the stock character axis.
    static func characterRange(_ input: UITextInput, _ range: UITextRange?) -> NSRange? {
        IDTelegramCharacterRangeForTextRange(input, range)?.rangeValue
    }

    /// The inverse. Steps the input's OWN positions, so non-renderable slots are skipped exactly as
    /// the editor skips them — raw-offset arithmetic is wrong past a boundary and wrong quietly
    /// (see `IDTelegramCharacterAxis.h`).
    static func position(_ input: UITextInput, atCharacterIndex index: Int) -> UITextPosition? {
        IDTelegramPositionForCharacterIndex(input, UInt(max(0, index)))
    }

    static func textRange(_ input: UITextInput, forCharacterRange range: NSRange) -> UITextRange? {
        IDTelegramTextRangeForCharacterRange(input, range)
    }

    /// The character index `closestPosition(to:)` resolves `point` to, on the stock axis.
    static func closestCharacterIndex(_ input: UITextInput, to point: CGPoint) -> Int? {
        guard let position = input.closestPosition(to: point) else { return nil }
        return characterIndex(input, position)
    }

    /// A probe point inside the glyph run of character `index`, at `fraction` of the way from that
    /// character's own caret to the next one, derived from **this arm's own** caret geometry (see
    /// fact 2 in the type comment). Returns nil when either caret is unavailable or the two are not
    /// on the same line (a wrap between them makes the interpolation meaningless).
    ///
    /// **`fraction` defaults to 0.25, not 0.5, and that is load-bearing.** At exactly 0.5 the point
    /// is equidistant from the two caret positions, so "the closest position" is a TIE and the answer
    /// is a tie-breaking policy rather than a hit-test result. Measured 2026-08-26: a stock
    /// `UITextView` breaks that tie **upward** (the midpoint of character 35's glyph resolves to 36)
    /// while both Telegram arms break it **downward** (35). A first draft of the parity suite probed
    /// at 0.5 and asserted that stock resolves to 35, which is simply false — the assertion was mine,
    /// not upstream's, and it reported "the ORACLE moved" for a claim upstream never makes. Interior
    /// points at 0.25 / 0.75 have an unambiguous nearest caret and are what "a tap inside this
    /// glyph" actually means; the tie is worth testing too, but as its own comparison.
    static func pointInsideCharacter(_ input: UITextInput, at index: Int,
                                     fraction: CGFloat = 0.25) -> CGPoint? {
        guard let start = position(input, atCharacterIndex: index),
              let end = position(input, atCharacterIndex: index + 1) else { return nil }
        let startCaret = input.caretRect(for: start)
        let endCaret = input.caretRect(for: end)
        guard startCaret.midY.isFinite, endCaret.midY.isFinite else { return nil }
        guard abs(startCaret.midY - endCaret.midY) < 1.0 else { return nil }
        let x = startCaret.midX + (endCaret.midX - startCaret.midX) * fraction
        return CGPoint(x: x, y: startCaret.midY)
    }

    /// True when `offset` falls strictly inside a composed character sequence of `string` — the
    /// predicate upstream names `offset:isInsideComposedClusterOfString:`.
    static func offset(_ offset: Int, isInsideComposedClusterOf string: String) -> Bool {
        let ns = string as NSString
        guard offset > 0, offset < ns.length else { return false }
        let cluster = ns.rangeOfComposedCharacterSequence(at: offset)
        return offset > cluster.location && offset < cluster.location + cluster.length
    }

    // MARK: - Kernel-failure capture

    /// Installs a capturing reporter in place of the DEBUG `assertionFailure`. Returns a box the
    /// test reads AFTER the action, so a failure message reports the violations that actually
    /// happened rather than re-deriving live state.
    final class ViolationLog {
        private(set) var messages: [String] = []
        func record(_ message: String) { messages.append(message) }
    }

    // MARK: - Three-arm readings and the PORT-DEFECT / PRE-EXISTING classification

    /// One arm's observable state, expressed in the SAME vocabulary for all three arms so the
    /// comparison is a value comparison and not a per-arm re-derivation.
    ///
    /// * `text` — the whole document through `-textInRange:` (stock: `UITextView.text`).
    /// * `selection` — `NSStringFromRange` of the selection **on the stock character axis** (see
    ///   fact 1 in the type comment); `"(no selection)"` when the arm reports none at all, which is
    ///   a different statement from `{0, 0}` and must not be conflated with it. Deliberately NOT
    ///   spelled `<none>`: the `<...>` form is reserved for a DECLINED probe, and the vacuity guard
    ///   in `assertField` would then fire on a perfectly real reading.
    /// * `traits` — one entry per character, each the sorted trait names
    ///   `IDNormalizedInlineTraitNames` defines (`bold`, `italic`, `underline`, `strikethrough`).
    struct Reading: Equatable {
        var text: String = ""
        var selection: String = "(no selection)"
        var traits: [[String]] = []

        /// A stable one-line rendering of `traits` for failure messages.
        var traitsDescription: String {
            traits.map { $0.isEmpty ? "-" : $0.joined(separator: "+") }.joined(separator: "|")
        }
    }

    /// What a single diverging field means, once the Legacy control has been consulted.
    ///
    /// The distinction is the deliverable. Without the Legacy arm every divergence looks like
    /// something the InputDec port broke; the earlier differential corpus measured that 194 of 514
    /// differences were in fact shared with Legacy, i.e. pre-existing canvas behaviour. Billing
    /// those to the port overstates its cost by ~38%.
    enum Verdict: String {
        /// InputDec matches stock. Nothing to do.
        case match = "MATCH"
        /// Legacy matches stock and InputDec does not — **the port introduced this**.
        case portDefect = "PORT-DEFECT"
        /// Neither Telegram backend matches stock — the editor has never matched stock here, and the
        /// InputDec port is not the cause (it may still be the reason it now MATTERS).
        case preExisting = "PRE-EXISTING"
        /// InputDec matches stock and Legacy does not. Rare, and worth knowing: the port FIXED it.
        case portImprovement = "PORT-IMPROVEMENT"
    }

    /// Compares one field across the three arms, fails with a classified message when InputDec
    /// diverges from the oracle, and returns the verdict so a suite can aggregate.
    ///
    /// **A `PRE-EXISTING` verdict still fails the test, deliberately.** It is a real divergence from
    /// the oracle this suite exists to certify against; downgrading it to a pass would be exactly the
    /// silent loosening the task brief forbids. The tag says who to bill, not whether it counts.
    @discardableResult
    static func assertField(_ field: String, scenario: String,
                            stock: String, inputDec: String, legacy: String,
                            note: String = "",
                            file: StaticString = #filePath, line: UInt = #line) -> Verdict {
        // VACUITY GUARD — the suite's single most important safety property. See `isDeclined`.
        for (arm, value) in [("stock", stock), ("inputDec", inputDec), ("legacy", legacy)]
        where isDeclined(value) {
            XCTFail("[DECLINED] \(scenario) · \(field) — the \(arm) arm produced no reading: "
                    + "\(value). This assertion measured nothing; do not read its verdict.",
                    file: file, line: line)
        }
        let verdict: Verdict
        switch (inputDec == stock, legacy == stock) {
        case (true, true):   verdict = .match
        case (true, false):  verdict = .portImprovement
        case (false, true):  verdict = .portDefect
        case (false, false): verdict = .preExisting
        }
        // EXHAUSTIVE, and deliberately not an `if`. It was an `if verdict == .portDefect ||
        // verdict == .preExisting` first, which left `.portImprovement` as an unmarked fall-through
        // — a computed verdict that did nothing at all and left no trace in the run. A `switch` over
        // every case forces each one to state what it does and why, and the compiler now requires a
        // new case to be handled rather than silently joining the do-nothing branch.
        switch verdict {
        case .portDefect, .preExisting:
            // ONE LINE, deliberately. `Scripts/iostest.sh` pipes xcodebuild through a line-based
            // `grep`, so a multi-line failure message loses everything after its first line — the
            // three values, which are the entire diagnostic. A first draft of this helper was
            // multi-line and the run reported only the verdict tag.
            let suffix = note.isEmpty ? "" : "  ·  note: \(note)"
            XCTFail("[\(verdict.rawValue)] \(scenario) · \(field) — "
                    + "stock=\(stock)  inputDec=\(inputDec)  legacy=\(legacy)\(suffix)",
                    file: file, line: line)
        case .portImprovement:
            // Does NOT fail, and that is correct: InputDec agrees with the oracle, which is the only
            // thing this suite certifies. But it must not be SILENT either — it means the shipping
            // Legacy backend diverges from stock here, which is a real finding about the code the
            // user runs today. Recorded as an activity so it lands in the result bundle.
            XCTContext.runActivity(named: "[PORT-IMPROVEMENT] \(scenario) · \(field)") { activity in
                activity.add(XCTAttachment(string:
                    "stock=\(stock)  inputDec=\(inputDec)  legacy=\(legacy)\n"
                    + "InputDec matches the oracle; the shipping Legacy backend does not."))
            }
        case .match:
            break
        }
        return verdict
    }

    /// Whether `value` contains a decline ANYWHERE, not only as the whole value.
    ///
    /// **This is the suite's single most important safety property and it had a real bypass.** The
    /// original guard tested `value.hasPrefix("<") && value.hasSuffix(">")` — a whole-value
    /// sentinel. Several probes compose a reading out of per-element tokens
    /// (`IDFloatingCursorParityTests`'s per-destination list, `IDBlockTextViewParityTests`'s `parts`
    /// join), so a decline for ONE element landed in the middle of the string and the composed value
    /// neither started with `<` nor ended with `>`. Three arms that all failed to produce a caret at
    /// the same destination then compared EQUAL on that token and, agreeing elsewhere, PASSED having
    /// measured nothing at that stop — the exact false green the guard exists to prevent.
    ///
    /// Two mechanisms, deliberately belt-and-braces:
    ///
    /// 1. Declines are minted by `decline(_:)`, whose marker cannot occur in any reading this
    ///    harness produces, and that marker is searched for ANYWHERE in the value.
    /// 2. The original whole-value `<…>` shape is still honoured, so a decline site that has not
    ///    been migrated (or one added later by hand) is still caught.
    ///
    /// Scanning for a bare `<…>` anywhere is deliberately NOT done: readings embed
    /// `String.debugDescription` of document text, and a fixture containing `<` would then be
    /// permanently unable to assert anything.
    static func isDeclined(_ value: String) -> Bool {
        value.contains(declineMarker) || (value.hasPrefix("<") && value.hasSuffix(">"))
    }

    /// The marker that makes a decline detectable inside a composed reading. Chosen so it cannot
    /// collide with anything a probe legitimately produces.
    static let declineMarker = "\u{27EA}DECLINED"

    /// Mints a decline. Every probe that cannot produce a reading must return one of these.
    ///
    /// Spelled `⟪DECLINED: reason⟫` rather than the old `<reason>` so that a decline for one element
    /// of a composed reading is still visible once it has been joined into a longer string.
    static func decline(_ reason: String) -> String { "\(declineMarker): \(reason)\u{27EB}" }

    /// `assertField` over every field of a `Reading`.
    @discardableResult
    static func assertReading(scenario: String, stock: Reading, inputDec: Reading, legacy: Reading,
                              note: String = "",
                              file: StaticString = #filePath, line: UInt = #line) -> [String: Verdict] {
        var verdicts: [String: Verdict] = [:]
        verdicts["text"] = assertField("text", scenario: scenario,
                                       stock: stock.text.debugDescription,
                                       inputDec: inputDec.text.debugDescription,
                                       legacy: legacy.text.debugDescription,
                                       note: note, file: file, line: line)
        verdicts["selection"] = assertField("selection", scenario: scenario,
                                            stock: stock.selection, inputDec: inputDec.selection,
                                            legacy: legacy.selection, note: note, file: file, line: line)
        verdicts["traits"] = assertField("traits", scenario: scenario,
                                         stock: stock.traitsDescription,
                                         inputDec: inputDec.traitsDescription,
                                         legacy: legacy.traitsDescription,
                                         note: note, file: file, line: line)
        return verdicts
    }

    static func installContractReporter(_ log: ViolationLog, in testCase: XCTestCase) {
        RichTextInputContractViolation.reporter = { message in
            NSLog("RichTextInput contract violation (recorded by the P1 stock-parity harness): %@", message)
            MainActor.assumeIsolated { log.record(message) }
        }
        testCase.addTeardownBlock {
            MainActor.assumeIsolated { RichTextInputContractViolation.reporter = nil }
        }
    }
}

// MARK: - ============================================================================
// MARK: The substitution seam (Task P2)
// MARK: ============================================================================

/// Which backend an arm is running.
///
/// Upstream's suites name two things: a `custom` (its host, `IDBlockTextView`) and a `stock`
/// (`UITextView`). The port keeps that vocabulary and adds one more arm, because a divergence the
/// SHIPPING legacy canvas also shows was not introduced by the InputDec port.
enum IDParityArm: String, CaseIterable {
    /// The oracle. A `UITextView`, configured as upstream configures its stock arm.
    case stock
    /// Upstream's `custom`, substituted: Telegram's editor on the `.inputDec` backend.
    case inputDec
    /// The control: the identical Telegram editor on the shipping `.legacy` backend.
    case legacy
}

/// One arm, presented in the SAME shape whatever is behind it.
///
/// **This type is the whole architectural point of Task P2.** Upstream obtains its subject through
/// `-makeCustom:stock:` + `-hostCustom:stock:` and every suite then works against a `custom` and a
/// `stock`. Porting a suite is only mechanical if the port has the same pair — so `subject.input`
/// is a `UITextInput` on all three arms, `subject.view` is the hosted `UIView` on all three, and a
/// ported assertion reads them without knowing which arm it is on.
@MainActor
final class IDParitySubject {
    let arm: IDParityArm
    /// The hosted view. On the host arms this is the `RichTextEditorView`, NOT the canvas.
    let view: UIView
    /// The object that conforms to `UITextInput`. On the host arms this is the **canvas**, because
    /// `RichTextEditorView` is a plain `UIView` that forwards to it — reading the editor instead
    /// answers about the wrong object, the trap `IDKeyboardActivationTests` records falling into.
    let input: UITextInput
    /// Non-nil on `.inputDec` / `.legacy`.
    let editor: RichTextEditorView?
    /// Non-nil on `.stock`.
    let stock: UITextView?

    init(arm: IDParityArm, view: UIView, input: UITextInput,
         editor: RichTextEditorView? = nil, stock: UITextView? = nil) {
        self.arm = arm
        self.view = view
        self.input = input
        self.editor = editor
        self.stock = stock
    }

    /// The responder to focus. On the host arms `RichTextEditorView.becomeFirstResponder()`
    /// forwards to the canvas, so the editor is the right receiver.
    var responder: UIResponder { view }
}

/// The fixture three arms are built from — one description, three constructions.
///
/// Upstream spells this inline in each suite (`fixtureBlocks`, a font, a `textContainerInset`, a
/// `lineFragmentPadding`). Naming it is what lets a ported suite say "same fixture, different
/// numbers" instead of re-deriving the geometry three times.
struct IDParityFixture {
    var blocks: [String]
    var fontSize: CGFloat = IDStockParity.fontSize
    var textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
    var lineFragmentPadding: CGFloat = 5.0
    var armSize = CGSize(width: 240, height: 420)

    var font: UIFont { UIFont.systemFont(ofSize: fontSize) }

    /// The stock arm's text. Upstream joins its blocks with `"\n"`; the host arms get the same
    /// strings as separate top-level paragraphs, which is the same document.
    var text: String { blocks.joined(separator: "\n") }

    init(blocks: [String]) { self.blocks = blocks }
}

/// Three arms, built from one fixture and hosted in ONE window.
///
/// **One window, not three, and that is upstream's shape.** `-hostCustom:stock:` puts both arms
/// side by side in a single `UIWindow` on a real `UIWindowScene`. Task P1 gave each arm its own
/// window; that is fine for pure `UITextInput` reads but it is wrong for anything scene-level — the
/// loupe test composites the whole scene and looks for a `_UITextMagnifiedGlassLoupeView` in *any*
/// window of it, and first-responder handoff between arms is only meaningful inside one key window.
@MainActor
struct IDParityArms {
    let stock: IDParitySubject
    let inputDec: IDParitySubject
    let legacy: IDParitySubject
    let window: UIWindow
    let fixture: IDParityFixture

    subscript(arm: IDParityArm) -> IDParitySubject {
        switch arm {
        case .stock: return stock
        case .inputDec: return inputDec
        case .legacy: return legacy
        }
    }

    /// Runs `probe` on all three arms. Every ported assertion goes through this, so a suite is a
    /// three-way value comparison rather than three separately-written arms that can drift.
    func each<T>(_ probe: (IDParitySubject) throws -> T) rethrows -> (stock: T, inputDec: T, legacy: T) {
        (try probe(stock), try probe(inputDec), try probe(legacy))
    }

    /// Same, but the probe only sees the `UITextInput` — the common case.
    func eachInput<T>(_ probe: (UITextInput) throws -> T) rethrows -> (stock: T, inputDec: T, legacy: T) {
        try each { try probe($0.input) }
    }

    /// Makes exactly one arm visible and first responder, hiding the others.
    ///
    /// Upstream does this by hand in the tests that need a live responder (`custom.hidden = YES;
    /// stock.hidden = NO;` around each half of the loupe sequence). It is required, not cosmetic:
    /// only one responder in a window can be first, and a hidden sibling editor still answers
    /// hit-tests otherwise.
    @discardableResult
    func focus(_ arm: IDParityArm) -> Bool {
        for candidate in IDParityArm.allCases { self[candidate].view.isHidden = (candidate != arm) }
        window.layoutIfNeeded()
        let subject = self[arm]
        subject.view.layoutIfNeeded()
        return subject.responder.becomeFirstResponder()
    }

    /// Restores all three arms to visible.
    func unfocusAll() {
        for candidate in IDParityArm.allCases {
            self[candidate].view.resignFirstResponder()
            self[candidate].view.isHidden = false
        }
        window.layoutIfNeeded()
    }
}

@MainActor
extension IDStockParity {

    /// **The substitution seam.** Upstream's `-makeCustom:stock:` + `-hostCustom:stock:`, with
    /// Telegram's editor substituted for `IDBlockTextView` and a Legacy control added.
    ///
    /// Everything a ported suite needs to know about how the three arms are constructed lives here
    /// and nowhere else. Porting an upstream suite is then: replace `makeCustom:stock:` with
    /// `makeArms`, replace `custom`/`stock` with `arms.inputDec.input`/`arms.stock.input`, and
    /// route each comparison through `assertField`. That is the "swap a factory rather than rewrite
    /// assertions" the task exists to deliver.
    ///
    /// `.inputDecIfSupported` (never `.inputDecRequired`): the required form is a
    /// `preconditionFailure` — an un-catchable trap — on a runtime where `isSupported()` is false.
    /// Callers `XCTSkipUnless(IDTextEditorBackend.isSupported())` first, and the InputDec arm is
    /// then asserted to really BE an `IDDocumentCanvasView`, so a silent fallback to legacy cannot
    /// masquerade as a passing InputDec arm.
    @available(iOS 17.0, *)
    static func makeArms(_ fixture: IDParityFixture, in testCase: XCTestCase) throws -> IDParityArms {
        let size = fixture.armSize
        let gap: CGFloat = 20.0
        func frame(_ column: Int) -> CGRect {
            CGRect(x: (size.width + gap) * CGFloat(column), y: 0, width: size.width, height: size.height)
        }

        let stockView = makeStock(frame: frame(0), text: fixture.text)
        stockView.font = fixture.font
        stockView.textContainerInset = fixture.textContainerInset
        stockView.textContainer.lineFragmentPadding = fixture.lineFragmentPadding

        let inputDecEditor = try makeHost(paragraphs: fixture.blocks, backend: .inputDecIfSupported,
                                          frame: frame(1), fontSize: fixture.fontSize)
        let legacyEditor = try makeHost(paragraphs: fixture.blocks, backend: .legacy,
                                        frame: frame(2), fontSize: fixture.fontSize)

        let windowSize = CGSize(width: (size.width + gap) * 3, height: size.height + gap)
        let window = host([stockView, inputDecEditor, legacyEditor], in: testCase, size: windowSize)

        return IDParityArms(
            stock: IDParitySubject(arm: .stock, view: stockView, input: stockView, stock: stockView),
            inputDec: IDParitySubject(arm: .inputDec, view: inputDecEditor,
                                      input: input(of: inputDecEditor), editor: inputDecEditor),
            legacy: IDParitySubject(arm: .legacy, view: legacyEditor,
                                    input: input(of: legacyEditor), editor: legacyEditor),
            window: window,
            fixture: fixture)
    }

    /// ONE arm of the seam, hosted in its own window.
    ///
    /// **Why both this and `makeArms` exist.** Upstream's read-only suites build their pair once per
    /// test and probe it; `makeArms` is that. Its MUTATING suites cannot: a test that types into an
    /// arm needs a FRESH arm for each scenario, and the inline-formatting suite builds several per
    /// test (its calibration deliberately builds two same-backend editors so the second is not
    /// looking at the first's mutation — sharing them would silently gut the test).
    ///
    /// Building all three arms when a scenario needs one is not free either, and not merely slow:
    /// constructing an `.inputDec` editor attaches the kernel, so an unused InputDec arm can push
    /// entries into the shared `ViolationLog` and turn another arm's `assertNoKernelFailures` red
    /// for something that never ran. This factory builds exactly the arm asked for.
    @available(iOS 17.0, *)
    static func makeSubject(_ arm: IDParityArm, _ fixture: IDParityFixture,
                            in testCase: XCTestCase, focused: Bool = true) throws -> IDParitySubject {
        let frame = CGRect(origin: .zero, size: fixture.armSize)
        let subject: IDParitySubject
        switch arm {
        case .stock:
            let stockView = makeStock(frame: frame, text: fixture.text)
            stockView.font = fixture.font
            stockView.textContainerInset = fixture.textContainerInset
            stockView.textContainer.lineFragmentPadding = fixture.lineFragmentPadding
            subject = IDParitySubject(arm: .stock, view: stockView, input: stockView, stock: stockView)
        case .inputDec, .legacy:
            let editor = try makeHost(paragraphs: fixture.blocks,
                                      backend: arm == .legacy ? .legacy : .inputDecIfSupported,
                                      frame: frame, fontSize: fixture.fontSize)
            subject = IDParitySubject(arm: arm, view: editor, input: input(of: editor), editor: editor)
        }
        host([subject.view], in: testCase, size: fixture.armSize)
        if focused {
            XCTAssertTrue(subject.responder.becomeFirstResponder(),
                          "the \(arm.rawValue) arm could not become first responder")
        }
        return subject
    }

    /// `assertField` over a `(stock, inputDec, legacy)` triple, which is what `IDParityArms.each`
    /// returns. Saves every ported assertion three argument labels and removes the possibility of
    /// wiring an arm into the wrong slot — a mistake that would silently invert every verdict.
    @discardableResult
    static func assertArms<T>(_ field: String, scenario: String,
                              _ readings: (stock: T, inputDec: T, legacy: T),
                              note: String = "",
                              file: StaticString = #filePath, line: UInt = #line) -> Verdict {
        assertField(field, scenario: scenario,
                    stock: "\(readings.stock)", inputDec: "\(readings.inputDec)",
                    legacy: "\(readings.legacy)", note: note, file: file, line: line)
    }

    /// `assertField` for a SEQUENCE of measurements compared within a tolerance, which is what
    /// upstream's `XCTAssertEqualWithAccuracy` sweeps are.
    ///
    /// **Do not express a tolerance by bucketing the numbers into a string and comparing strings.**
    /// A first draft of the caret-profile sweep did exactly that, and a value sitting a hundredth of
    /// a point either side of a bucket edge reported a full-bucket divergence — an instrument
    /// artefact indistinguishable, in the failure message, from a real 1.5pt geometry difference.
    /// This compares element by element and reports the FIRST real divergence with both raw values,
    /// so the message says how big the difference actually is.
    @discardableResult
    static func assertNumericArms(_ field: String, scenario: String,
                                  _ readings: (stock: [CGFloat], inputDec: [CGFloat], legacy: [CGFloat]),
                                  tolerance: CGFloat, note: String = "",
                                  file: StaticString = #filePath, line: UInt = #line) -> Verdict {
        func firstDivergence(_ arm: [CGFloat]) -> String? {
            guard arm.count == readings.stock.count else {
                return "count \(arm.count) vs stock \(readings.stock.count)"
            }
            for (index, value) in arm.enumerated() where abs(value - readings.stock[index]) > tolerance {
                return String(format: "[%d] %.2f vs stock %.2f (Δ%.2f > %.2f)",
                              index, value, readings.stock[index],
                              abs(value - readings.stock[index]), tolerance)
            }
            return nil
        }
        let inputDecDivergence = firstDivergence(readings.inputDec)
        let legacyDivergence = firstDivergence(readings.legacy)
        let verdict: Verdict
        switch (inputDecDivergence == nil, legacyDivergence == nil) {
        case (true, true):   verdict = .match
        case (true, false):  verdict = .portImprovement
        case (false, true):  verdict = .portDefect
        case (false, false): verdict = .preExisting
        }
        if verdict == .portDefect || verdict == .preExisting {
            let suffix = note.isEmpty ? "" : "  ·  note: \(note)"
            XCTFail("[\(verdict.rawValue)] \(scenario) · \(field) — "
                    + "inputDec=\(inputDecDivergence ?? "matches stock")  "
                    + "legacy=\(legacyDivergence ?? "matches stock")\(suffix)",
                    file: file, line: line)
        }
        return verdict
    }

    /// A comparison against the **Legacy control alone**, for use when the stock oracle is provably
    /// not answering.
    ///
    /// **This is deliberately NOT `assertField`, and the name says so at every call site.** It makes
    /// a strictly weaker claim: "the InputDec backend behaves differently from the shipping backend"
    /// — a regression statement, not a correctness one. A divergence it reports could in principle
    /// be an InputDec improvement over a Legacy bug, which is exactly why the three-arm form exists
    /// and why this must never be used where stock can answer.
    ///
    /// It exists because throwing the whole comparison away when the oracle is silent throws away a
    /// real finding with it: in the floating-cursor suite the stock arm resolves EVERY drag point to
    /// the document end (it does not respond to programmatic `updateFloatingCursor` at all), while
    /// Legacy tracks the drag exactly and InputDec is pinned at offset 0. "No oracle" is the right
    /// verdict about stock and the wrong verdict about that.
    @discardableResult
    static func assertAgainstControl(_ field: String, scenario: String,
                                     inputDec: String, legacy: String, note: String = "",
                                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        for (arm, value) in [("inputDec", inputDec), ("legacy", legacy)] where isDeclined(value) {
            XCTFail("[DECLINED] \(scenario) · \(field) — the \(arm) arm produced no reading: "
                    + "\(value). This assertion measured nothing; do not read its verdict.",
                    file: file, line: line)
            return false
        }
        if inputDec != legacy {
            let suffix = note.isEmpty ? "" : "  ·  note: \(note)"
            XCTFail("[REGRESSION vs LEGACY] \(scenario) · \(field) — "
                    + "inputDec=\(inputDec)  legacy=\(legacy)  ·  the stock oracle is not "
                    + "answering here, so this compares the InputDec backend against the SHIPPING "
                    + "one only: it says the port changed the behaviour, not which one is "
                    + "correct.\(suffix)", file: file, line: line)
            return false
        }
        return true
    }

    /// The kernel-violation check every ported suite must make after a mutating action.
    ///
    /// It lived twice: `IDBlockTouchSelectionParityTests` defined and called it,
    /// `IDInlineFormattingStockOracleParityTests` defined it and never called it (P1 review finding
    /// 4 — every test there inlined the check instead). One definition, here, called by both.
    static func assertNoKernelFailures(_ log: ViolationLog, _ scenario: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(log.messages, [],
                       "[PORT-DEFECT] \(scenario) · the InputDec kernel reported contract violations",
                       file: file, line: line)
    }
}

#endif
