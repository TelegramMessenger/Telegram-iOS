#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// A no-op `UITextInputTokenizer` returned by `stubbedTokenizer`'s default — nothing in a router-spy
/// test reads a real tokenization result (mirrors `BackendAttachmentTests.NoOpTokenizer`, kept as a
/// separate private type here rather than reused across files/targets since neither file may depend on
/// the other's `private` declarations).
@available(iOS 13.0, *)
private final class SpyNoOpTokenizer: NSObject, UITextInputTokenizer {
    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextRange? { nil }
    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextPosition? { nil }
    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
}

/// The Phase-4 router-spy backend. Plugged in via `DocumentCanvasView(inputBackend: spy)`, it records
/// EVERY `RichTextInputBackend` witness call into one flat ordered log (`calls`) and answers every
/// witness with either an IMPROBABLE stubbed value (a plain scalar/struct — equality proves a router
/// forwarded the return unmodified) or a SENTINEL reference object returned VERBATIM (identity, checked
/// with `===`, proves a router forwarded the object itself rather than transforming or rebuilding it —
/// the trap a naive router that reconstructs a `UITextPosition`/`UITextRange` from the sentinel's
/// content, instead of returning the very instance, would fall into and `==` could never catch).
///
/// `final`, not `class`: unlike the eight `BackendContractCases` suites (which stage 2 subclasses to
/// re-run the same 67 tests against a second real backend), this is a TEST DOUBLE — it exists to be
/// constructed and inspected directly by a router-spy test, never subclassed or driven through
/// `makeBackend()`. unsupported members are LOUD only in the sense that every call is recorded — see
/// the header note on "loud vs. plausible" below for the two members where a plain stub would have
/// been actively misleading.
///
/// "Loud, not plausible" in practice: every witness records its call FIRST — so a router that forwards
/// to the wrong backend member, or never forwards at all, is caught by `XCTAssertSingleBackendCall`
/// finding the wrong (or zero) entries, not by a plausible-looking return value. The two members with no
/// sensible constant to return AT ALL are `hostWillMove(toWindow:)` and `canPerformCommand`'s `sender`/
/// `performCommand`'s `sender` — an `Any?` has no meaningful equality, so their arguments are recorded
/// as type-described strings (loud enough to see IN the log that something arrived) rather than a
/// fabricated comparable value this spy does not have grounds to invent.
@MainActor
@available(iOS 16.0, *)
final class SpyRichTextInputBackend: RichTextInputBackend {

    // MARK: - Call log

    struct Call: Equatable, CustomStringConvertible {
        let member: String
        let arguments: [String]

        var description: String {
            arguments.isEmpty ? member : "\(member)(\(arguments.joined(separator: ", ")))"
        }
    }

    private(set) var calls: [Call] = []

    /// TASK 39b (coordinator supplement, RULING 4) — the recorded `synchronizeAfterExternalChange`
    /// arguments, in call order. Added HERE rather than on a subclass: this class is deliberately
    /// `final` (see the header), and its witness for that member was an empty body that recorded
    /// NOTHING — a real gap against this file's own claim to record "EVERY witness call". The witness
    /// now appends to both this array and `calls`, so the flat log stays honest too.
    private(set) var observedExternalChanges: [RichTextInputExternalChange] = []

    func reset() {
        calls.removeAll()
        observedExternalChanges.removeAll()
    }

    private func note(_ member: String, _ arguments: String...) {
        calls.append(Call(member: member, arguments: arguments))
    }

    // task-23 fix round 1 (review Major 1): explicit init so `stubbedSelectionRects` can default to
    // `[sentinelSelectionRect]` rather than `[]` — `[]` is EXACTLY what a non-routing canvas returns
    // for `selectionRects(for:)` on a nonsense sentinel range, which made Task 25's return-propagation
    // assertion for that member unfalsifiable and left `sentinelSelectionRect` completely unused.
    init() {
        self.stubbedSelectionRects = [self.sentinelSelectionRect]
    }

    // MARK: - Sentinels — returned VERBATIM, never rebuilt, so `===` catches a router that reconstructs
    // instead of forwarding. Improbable values so a coincidental pass (e.g. a router that happens to
    // build an equivalent-looking but DIFFERENT object) cannot slip through unnoticed in the log either.

    let sentinelPosition: UITextPosition = DocumentTextPosition(-9_009)
    let sentinelRange: UITextRange = DocumentTextRange(DocumentTextPosition(-9_009), DocumentTextPosition(-9_008))
    let sentinelSelectionRect: UITextSelectionRect = DocumentSelectionRect(
        rect: CGRect(x: 11, y: 22, width: 33, height: 44), containsStart: true, containsEnd: true)

    // MARK: - Stubbed scalar/struct returns — improbable values so a coincidental pass is impossible.

    var stubbedText: String? = "SENTINEL\u{1F600}\u{0301}"
    var stubbedComparison: ComparisonResult = .orderedDescending
    var stubbedOffset: Int = -7
    var stubbedWritingDirection: NSWritingDirection = .rightToLeft
    var stubbedCaretRect: CGRect = CGRect(x: 11, y: 22, width: 33, height: 44)
    var stubbedFirstRect: CGRect = CGRect(x: 55, y: 66, width: 77, height: 88)
    var stubbedSelectionRects: [UITextSelectionRect]
    // task-23 fix round 1 (review Major 2): NOT all `true` — the canvas's own pre-seam answer for
    // `hasText`/`canBecomeFirstResponder`/`isEditableForWritingTools` is `true`
    // (an unconditional `canBecomeFirstResponder` override, `isEditable`'s literal in
    // `+UITextInput.swift`, and `hasText`'s `documentSize > 0`, respectively; `canResignFirstResponder`
    // was unoverridden, so it was `UIResponder`'s own `true`), so a `true` default here made
    // return-propagation a COINCIDENTAL pass for Tasks 24/31 — a router that never forwarded at all
    // would still read back `true`.
    //
    // TASK 31 FIX ROUND 1: the two line citations this note carried (`DocumentCanvasView.swift:740`,
    // `+UITextInput.swift:215`) are dropped rather than repaired — Task 31 ROUTED both witnesses, so
    // the literals they located now live on `LegacyRichTextInputBackend+Responder.swift`. The polarity
    // argument is unaffected and became live rather than hypothetical: routing
    // `canBecomeFirstResponder` means these stubs now gate `super.becomeFirstResponder()` for real, so
    // a spy-backed canvas cannot take focus unless `stubbedCanBecomeFirstResponder` says it may —
    // which `ResponderRouterTests.test_becomeFirstResponder_stillCallsSuperOnTheCanvas` turns into the
    // proof that `super` is both still called and still honoured.
    // `false` is not the non-routing answer for any of those four, so a passing return-propagation
    // assertion is now real signal.
    //
    // FIX ROUND 2 (review item 4) — CORRECTED for `stubbedCanPerformCommand`: `false` does NOT make
    // return-propagation real signal for this member the way it does for the other four. The canvas
    // answers `canPerformCommand` PER COMMAND (`+EditMenu.swift:83-104`), and `false` IS the
    // non-routing answer for copy/cut/paste, the five `legacy*` items, and the six spelling items
    // under the standard collapsed-caret factory — so for THIS member the coincidence MOVED rather
    // than went away, and no single constant default can fix it. This is a documented PER-TEST
    // POLARITY OBLIGATION for Task 30: `stubbedCanPerformCommand` must be set per command in each
    // `canPerformCommand` router test (e.g. `true` for a command whose non-routing collapsed-caret
    // answer is `false`, and vice versa for any command whose non-routing answer is `true`), not left
    // at this shared default. **TASK 30 HONOURED IT**:
    // `CommandRouterTests.test_canPerformAction_mapsAKnownSelectorAndAsksTheBackend` sets it `true`
    // for `copy:` (whose non-routing answer under a collapsed caret is `false`) and `false` for
    // `select:` (whose non-routing answer under a collapsed caret inside a word is `true`), so neither
    // direction can pass by coincidence. The obligation stands for every future test of this member.
    var stubbedHasText: Bool = false
    var stubbedCanBecomeFirstResponder: Bool = false
    var stubbedCanResignFirstResponder: Bool = false
    var stubbedIsEditableForWritingTools: Bool = false
    var stubbedCanPerformCommand: Bool = false
    var stubbedTokenizer: UITextInputTokenizer = SpyNoOpTokenizer()

    // MARK: - Plain get/set storage for the two `{ get set }` witnesses with no comparable-by-value
    // sentinel of their own (an `UITextInputDelegate` and a style dictionary are not identity-checked by
    // any router test today; recording the call is what a family task needs).

    private var inputDelegateStorage: UITextInputDelegate?
    private var markedTextStyleStorage: [NSAttributedString.Key: Any]?

    /// Deterministic (key-sorted) rendering of a style dictionary for `markedTextStyle.set`'s log
    /// argument. `String(describing:)` over a `Dictionary` directly is NOT safe here — per-process
    /// element order is unspecified, so a multi-entry dictionary could describe differently between
    /// two runs of the same test, a real flake risk task-23 fix round 2 found before it shipped.
    private static func describeSorted(_ style: [NSAttributedString.Key: Any]?) -> String {
        guard let style else { return "nil" }
        let pairs = style.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)=\(String(describing: $0.value))" }
        return "[" + pairs.joined(separator: ", ") + "]"
    }

    // MARK: - RichTextInputBackend composite surface — NOT logged (matches
    // `BackendAttachmentTests.SpyBackend`'s precedent). CORRECTION (task-23 fix round 1, review Minor
    // 4): this is NOT true in general that these are "not a `DocumentCanvasView` router target" — the
    // D33 seven (`canonicalSelection*`, `setCanonical{Anchor,Head}`, `clearCompositionState`,
    // `suppressesSelectionNotifications`) each name a real canvas forwarder in
    // `RichTextInputBackend.swift:255-316` (Tasks 26/35/41/44), and
    // `DocumentCanvasView.swift`'s `coalescingSelectionNotifications` was exactly what Task 26 turned
    // into a forwarder onto `suppressesSelectionNotifications` below — TASK 43 deleted it, so the
    // canvas now names this member directly at four sites. The accurate claim: this surface
    // is not routed BY PHASE 4 (which routes only the witness sub-protocols the `calls` log
    // covers) — extend with logging when Task 26/35/41/44 needs call-level proof for one of these,
    // not before.

    private(set) var isAttached = false
    private(set) weak var capturedHost: (any RichTextInputHost)?

    func attach(to host: any RichTextInputHost) throws {
        capturedHost = host
        isAttached = true
    }
    func detach() {
        isAttached = false
        capturedHost = nil
    }
    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {
        note("synchronizeAfterExternalChange",
             "\(change.reason)", "\(change.markedTextPolicy)",
             "\(change.oldRevision)->\(change.newRevision)")
        observedExternalChanges.append(change)
    }
    func setSelection(_ selection: RichTextCanonicalSelection, reason: RichTextSelectionChangeReason) {}

    var state: RichTextInputStateSnapshot {
        RichTextInputStateSnapshot(documentRevision: 0, selection: .caret(at: .downstream(0)), markedRange: nil, isComposing: false)
    }
    /// TASK 35 — REAL STORAGE, not a constant, and this is load-bearing for the router suites rather
    /// than a convenience. `DocumentCanvasView.anchor`/`.head` stopped being canvas storage in that
    /// task and are now forwarders onto these four members, so a spy that answered a constant `0` and
    /// swallowed the setters would freeze `canvas.anchor`/`canvas.head` at `0` for every spy-backed
    /// test — silently turning `RouterStateSnapshot`'s `anchor`/`head` fields (and therefore
    /// `XCTAssertRoutesOnly`'s "and nothing else moved" clause) VACUOUS in exactly the family
    /// `SelectionRouterTests`' own header calls out as the one where that clause is non-inert. With
    /// storage here, a canvas router that kept a copy of the pre-seam inline body alongside its
    /// forward still moves the snapshot and is still caught.
    ///
    /// Deliberately NOT logged and NOT written by `setSelection` above: this reproduces the pre-Task-35
    /// arrangement exactly (the canvas owned this storage; the spy's `setSelection` was, and remains,
    /// an unrecorded no-op), so no existing spy-backed assertion changes meaning.
    var canonicalSelectionStorage: RichTextCanonicalSelection = .caret(at: .downstream(0))
    var canonicalSelection: RichTextCanonicalSelection { canonicalSelectionStorage }
    var canonicalSelectionAnchorOffset: Int { canonicalSelectionStorage.anchor.utf16Offset }
    var canonicalSelectionHeadOffset: Int { canonicalSelectionStorage.head.utf16Offset }
    func setCanonicalAnchor(_ utf16Offset: Int) {
        canonicalSelectionStorage.anchor = .downstream(utf16Offset)
    }
    func setCanonicalHead(_ utf16Offset: Int) {
        canonicalSelectionStorage.head = .downstream(utf16Offset)
    }
    /// TASK 41 — RECORDED, unlike its D33 siblings, and for a reason specific to this member: it is
    /// the ONE composition door with a `Sources/` call site (`registerUndo`'s restore closure), so a
    /// spy-backed test can only prove that call happened by seeing it in the log.
    /// `MarkedStateAuthorityTests.test_clearCompositionStateIsCalledFromTheUndoRestorePath` is that
    /// test. It clears the storage below too, so the spy's own state stays coherent.
    func clearCompositionState() {
        note("clearCompositionState")
        markedRangeStorage = nil
        markedTextIsPredictionStorage = false
        compositionSnapshotStorage = nil
    }
    var suppressesSelectionNotifications: Bool = false

    /// TASK 41 — REAL STORAGE, for exactly the reason `canonicalSelectionStorage` above carries:
    /// `DocumentCanvasView.markedRange`/`.markedTextIsPrediction` stopped being canvas storage in that
    /// task and are now projections of these members, so a spy that answered a constant `nil` and
    /// swallowed the setters would freeze every spy-backed canvas at "not composing" — silently
    /// disabling the composition half of every spy-backed test.
    ///
    /// The raw setters are deliberately NOT logged (matching `setCanonicalAnchor`/`setCanonicalHead`):
    /// they reproduce writes that were plain canvas field assignments before the seam, so recording
    /// them would add entries to `calls` at sites that recorded nothing pre-seam and change the
    /// meaning of every `XCTAssertRoutesOnly` "and nothing else" clause.
    var markedRangeStorage: NSRange?
    var markedTextIsPredictionStorage: Bool = false
    var compositionSnapshotStorage: RichTextCompositionSnapshot?
    var markedRange: NSRange? { markedRangeStorage }
    var isComposingPrediction: Bool { markedRangeStorage != nil && markedTextIsPredictionStorage }
    var isComposing: Bool { markedRangeStorage != nil }
    var compositionSnapshot: RichTextCompositionSnapshot? { compositionSnapshotStorage }
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        if let range, range.length > 0 {
            markedRangeStorage = range
            markedTextIsPredictionStorage = isPrediction
        } else {
            markedRangeStorage = nil
            markedTextIsPredictionStorage = false
        }
    }
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        compositionSnapshotStorage = snapshot
    }

    /// TASK 42 — REAL STORAGE, for exactly the reason `canonicalSelectionStorage` and the composition
    /// trio above carry: `DocumentCanvasView.floatingCursorActive`/`.floatingCursorPoint`/
    /// `.floatingScrollVelocity` stopped being canvas storage in that task and are now projections of
    /// these members, so a spy that answered constants and swallowed the setters would freeze every
    /// spy-backed canvas at "no floating cursor" — silently disabling that half of any spy-backed test.
    ///
    /// The setters are deliberately NOT logged, matching `setCanonicalAnchor`/`setCanonicalHead` and the
    /// composition pair: they reproduce writes that were plain canvas field assignments before the seam,
    /// so recording them would add entries to `calls` at sites that recorded nothing pre-seam and change
    /// the meaning of every `XCTAssertRoutesOnly` "and nothing else" clause.
    var floatingCursorActive: Bool = false
    var floatingCursorPoint: CGPoint = .zero
    var floatingScrollVelocity: CGFloat = 0
    func setFloatingCursorActive(_ active: Bool) { floatingCursorActive = active }
    func setFloatingCursorPoint(_ point: CGPoint) { floatingCursorPoint = point }
    func setFloatingScrollVelocity(_ velocity: CGFloat) { floatingScrollVelocity = velocity }

    // Task 26's five delegate brackets. Each RUNS ITS BODY and records the call, but sends nothing to
    // `inputDelegateStorage` — a spy publishes nothing to anyone (the same reasoning the
    // `setMarkedText` stub above carries). Running the body is not optional: these brackets wrap real
    // canvas state changes, so a spy that swallowed the body would silently disable every canvas
    // operation a spy-backed router test performs during setup.
    func notifyingContentAndSelectionChange(_ body: () -> Void) {
        note("notifyingContentAndSelectionChange"); body()
    }
    func notifyingSelectionChange(_ body: () -> Void) {
        note("notifyingSelectionChange"); body()
    }
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) {
        note("notifyingSelectionChangeIgnoringCoalescing"); body()
    }
    func notifyingContentChange(_ body: () -> Void) {
        note("notifyingContentChange"); body()
    }
    func notifyCoalescedSelectionResync() { note("notifyCoalescedSelectionResync") }

    // MARK: - RichTextInputTextBackend

    var inputDelegate: UITextInputDelegate? {
        get { note("inputDelegate.get"); return inputDelegateStorage }
        set {
            // task-23 fix round 1 (review Minor 3): ObjectIdentifier, not just the delegate's TYPE
            // name — Task 26 routes this member, and two distinct delegates of the same type were
            // indistinguishable under the old encoding.
            note("inputDelegate.set", newValue.map { ObjectIdentifier($0 as AnyObject).debugDescription } ?? "nil")
            inputDelegateStorage = newValue
        }
    }

    var tokenizer: UITextInputTokenizer {
        note("tokenizer"); return stubbedTokenizer
    }

    var selectedTextRange: UITextRange? {
        get { note("selectedTextRange.get"); return sentinelRange }
        set { note("selectedTextRange.set", newValue.map { ObjectIdentifier($0).debugDescription } ?? "nil") }
    }

    var markedTextRange: UITextRange? {
        note("markedTextRange"); return sentinelRange
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { note("markedTextStyle.get"); return markedTextStyleStorage }
        set {
            // task-23 fix round 1 (review Minor 3): the DESCRIBED dictionary, not just nil/non-nil —
            // Task 29 routes this member, and the old encoding discarded the dictionary entirely.
            // FIX ROUND 2 (review item 2): `String(describing:)` directly over a `Dictionary` has
            // UNSPECIFIED per-process element order, so a multi-entry style could flake between runs
            // of the same test. `describeSorted(_:)` sorts by key first. Task 29 must not assert a
            // multi-entry `markedTextStyle` argument string without this same deterministic encoding.
            note("markedTextStyle.set", Self.describeSorted(newValue))
            markedTextStyleStorage = newValue
        }
    }

    var beginningOfDocument: UITextPosition {
        note("beginningOfDocument"); return sentinelPosition
    }

    var endOfDocument: UITextPosition {
        note("endOfDocument"); return sentinelPosition
    }

    func text(in range: UITextRange) -> String? {
        note("text(in:)", ObjectIdentifier(range).debugDescription); return stubbedText
    }

    func replace(_ range: UITextRange, withText text: String) {
        note("replace(_:withText:)", ObjectIdentifier(range).debugDescription, text)
    }

    /// TASK 22f's protocol doc comment obligation (`RichTextInputBackend.swift`: a conformer MUST
    /// publish `.markedText` exactly once) is a REAL-backend obligation, not something this test double
    /// need honor — a spy never publishes anything to anyone. Recording the call is this member's whole
    /// job here.
    func setMarkedText(_ text: String?, selectedRange: NSRange) {
        note("setMarkedText(_:selectedRange:)", text ?? "nil", String(describing: selectedRange))
    }

    func unmarkText() {
        note("unmarkText()")
    }

    func textRange(from: UITextPosition, to: UITextPosition) -> UITextRange? {
        note("textRange(from:to:)", ObjectIdentifier(from).debugDescription, ObjectIdentifier(to).debugDescription)
        return sentinelRange
    }

    func position(from: UITextPosition, offset: Int) -> UITextPosition? {
        note("position(from:offset:)", ObjectIdentifier(from).debugDescription, String(offset))
        return sentinelPosition
    }

    func position(from: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        note("position(from:in:offset:)", ObjectIdentifier(from).debugDescription, String(describing: direction), String(offset))
        return sentinelPosition
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        note("compare(_:to:)", ObjectIdentifier(position).debugDescription, ObjectIdentifier(other).debugDescription)
        return stubbedComparison
    }

    func offset(from: UITextPosition, to other: UITextPosition) -> Int {
        note("offset(from:to:)", ObjectIdentifier(from).debugDescription, ObjectIdentifier(other).debugDescription)
        return stubbedOffset
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        note("position(within:farthestIn:)", ObjectIdentifier(range).debugDescription, String(describing: direction))
        return sentinelPosition
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        note("characterRange(byExtending:in:)", ObjectIdentifier(position).debugDescription, String(describing: direction))
        return sentinelRange
    }

    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        note("baseWritingDirection(for:in:)", ObjectIdentifier(position).debugDescription, String(describing: direction))
        return stubbedWritingDirection
    }

    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {
        note("setBaseWritingDirection(_:for:)", String(describing: direction), ObjectIdentifier(range).debugDescription)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        note("firstRect(for:)", ObjectIdentifier(range).debugDescription)
        return stubbedFirstRect
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        note("caretRect(for:)", ObjectIdentifier(position).debugDescription); return stubbedCaretRect
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        note("selectionRects(for:)", ObjectIdentifier(range).debugDescription)
        return stubbedSelectionRects
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        note("closestPosition(to:)", String(describing: point))
        return sentinelPosition
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        note("closestPosition(to:within:)", String(describing: point), ObjectIdentifier(range).debugDescription)
        return sentinelPosition
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        note("characterRange(at:)", String(describing: point))
        return sentinelRange
    }

    /// Deviation D15: the legacy backend never witnesses this member for real (grep: zero call sites),
    /// and this spy is not in the business of inventing a real backend's behavior — `nil`, unconditionally,
    /// matches the one real conformer's own permanent answer.
    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? {
        note("textStyling(at:in:)", ObjectIdentifier(position).debugDescription, String(describing: direction))
        return nil
    }

    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        note("insertDictationResult(_:)", String(dictationResult.count))
    }

    // MARK: - RichTextKeyInputBackend

    var hasText: Bool {
        note("hasText"); return stubbedHasText
    }

    func insertText(_ text: String) {
        note("insertText(_:)", text)
    }

    func deleteBackward() {
        note("deleteBackward()")
    }

    // MARK: - RichTextInputResponderBackend

    var canBecomeFirstResponder: Bool {
        note("canBecomeFirstResponder"); return stubbedCanBecomeFirstResponder
    }

    var canResignFirstResponder: Bool {
        note("canResignFirstResponder"); return stubbedCanResignFirstResponder
    }

    func hostWillBecomeFirstResponder() { note("hostWillBecomeFirstResponder()") }
    func hostDidBecomeFirstResponder() { note("hostDidBecomeFirstResponder()") }
    func hostDidFailToBecomeFirstResponder() { note("hostDidFailToBecomeFirstResponder()") }
    func hostWillResignFirstResponder() { note("hostWillResignFirstResponder()") }
    func hostDidResignFirstResponder() { note("hostDidResignFirstResponder()") }
    func hostDidFailToResignFirstResponder() { note("hostDidFailToResignFirstResponder()") }

    func hostWillMove(toWindow window: UIWindow?) {
        note("hostWillMove(toWindow:)", window == nil ? "nil" : "non-nil")
    }

    func editPolicyDidChange() { note("editPolicyDidChange()") }
    func textInputTraitsDidChange() { note("textInputTraitsDidChange()") }

    var isEditableForWritingTools: Bool {
        note("isEditableForWritingTools"); return stubbedIsEditableForWritingTools
    }

    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        note("canPerformCommand(_:sender:)", String(describing: command), sender == nil ? "nil" : "non-nil")
        return stubbedCanPerformCommand
    }

    func performCommand(_ command: RichTextInputCommand, sender: Any?) {
        note("performCommand(_:sender:)", String(describing: command), sender == nil ? "nil" : "non-nil")
    }

    /// TASK 30 — D28's third member. `stubbedUndoManager` is a FRESH manager owned by this spy, never
    /// the canvas's: the non-routing answer for `DocumentCanvasView.undoManager` is
    /// `effectiveUndoManager` (always non-nil), so `nil` would be indistinguishable signal but a
    /// distinct instance is not — a router test asserts `canvas.undoManager === spy.stubbedUndoManager`
    /// and `!== canvas.effectiveUndoManager`, which a non-routing override cannot satisfy.
    var stubbedUndoManager: UndoManager? = UndoManager()

    var undoManager: UndoManager? {
        note("undoManager"); return stubbedUndoManager
    }

    // MARK: - RichTextInputInteractionBackend

    func installInteractions() { note("installInteractions()") }
    func removeInteractions() { note("removeInteractions()") }
    func viewportDidChange() { note("viewportDidChange()") }

    func layoutDidChange(generation: UInt64) {
        note("layoutDidChange(generation:)", String(generation))
    }

    func beginFloatingCursor(at point: CGPoint) {
        note("beginFloatingCursor(at:)", String(describing: point))
    }

    func updateFloatingCursor(at point: CGPoint) {
        note("updateFloatingCursor(at:)", String(describing: point))
    }

    func endFloatingCursor() { note("endFloatingCursor()") }

    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {
        note("cancelActiveInteraction(reason:)", String(describing: reason))
    }

    // MARK: - RichTextInputCheckingBackend (Task 34, deviation D37)
    //
    // Recording-only, like every other void witness here: the point of a spy canvas is that a router
    // test can prove the canvas call site reached the BACKEND and did no checking of its own. A spy
    // that quietly ran the real checking would make `XCTAssertRoutesOnly`'s "the canvas did no work"
    // half unfalsifiable for this family.

    func installCheckingIfNeeded() { note("installCheckingIfNeeded()") }
    func checkOnSelectionChange() { note("checkOnSelectionChange()") }
}
#endif
