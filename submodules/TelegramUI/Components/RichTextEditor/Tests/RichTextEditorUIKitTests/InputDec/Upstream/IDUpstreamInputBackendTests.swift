#if canImport(UIKit)
import XCTest
import UIKit
import RichTextInputDecUpstream
@testable import RichTextEditorUIKit

/// PHASE 2'S EXIT CRITERION — Telegram's `RichTextInputBackend` drives upstream InputDec's REAL host.
///
/// Phase 1 proved the ported engine stands up and accepts typing when driven DIRECTLY
/// (`InputDecUpstreamHostSmokeTests`). This suite proves the same thing through
/// `IDUpstreamInputBackend`, i.e. through Telegram's own protocol, and — just as importantly —
/// proves the things this port exists to stop being true:
///
///   * that the identity family crossing the seam is the ENGINE's (`IDRichTextPosition` /
///     `IDRichTextRange`), never Telegram-minted;
///   * that a foreign position is a NAMED report rather than a silent nil or a process abort;
///   * that all 58 unimplemented requirements are LOUD — every one of them, enumerated, not sampled;
///   * that phase 2 consumes NONE of the 54 client-side requirements, proven by a shared event log
///     that must still be empty at the end.
///
/// **Assertions are on CAPTURED values.** Typed text is checked against the engine's
/// `attributedBlocks` (a snapshot taken at the moment of assertion from the document itself), and
/// contract violations against `recordedViolations` (appended at the moment each one happened) —
/// not against a live re-read of a derived property, which has produced false green in this package
/// repeatedly.
@MainActor
@available(iOS 18.4, *)  // IDBlockTextView and its collaborators are gated at 18.4 for the host's iOS 15 floor.
final class IDUpstreamInputBackendTests: XCTestCase {

    private var window: UIWindow!
    private var previousReporter: ((String) -> Void)?
    /// Violations seen through the SANCTIONED channel, captured as they happen. Kept alongside the
    /// backend's own `recordedViolations` deliberately: two independent records of the same event,
    /// so a test cannot pass because one of the two channels quietly stopped firing.
    private var reportedViolations: [String] = []

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
        previousReporter = RichTextInputContractViolation.reporter
        reportedViolations = []
        RichTextInputContractViolation.reporter = { [weak self] message in
            self?.reportedViolations.append(message)
        }
    }

    override func tearDown() {
        RichTextInputContractViolation.reporter = previousReporter
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    // MARK: - Fixture

    /// The host is a BARE `UIView`, not a `DocumentCanvasView`.
    ///
    /// That is the phase's central constraint made structural (`task-PORT-PLAN.md` §3.2, "What phase 1
    /// must NOT do"): the InputDec host draws itself and nothing routes through Telegram's canvas. A
    /// fixture that handed the adapter a `DocumentCanvasView` would let a future change start leaning
    /// on it without any test noticing.
    ///
    /// The six clients are the ordinary recording fakes, sharing ONE log, so
    /// `test_theAdapterConsumesNoClientSideRequirement` can assert that log is still empty.
    private final class UpstreamFakeHost: RichTextInputHost {
        let log: RichTextInputEventLog
        let container: UIView
        let documentClient: any RichTextInputDocumentClient
        let geometryClient: any RichTextInputGeometryClient
        let annotationClient: any RichTextInputAnnotationClient
        let presentationClient: any RichTextInputPresentationClient
        let lifecycleClient: any RichTextInputLifecycleClient
        let commandClient: any RichTextInputCommandClient

        init(log: RichTextInputEventLog) {
            self.log = log
            self.container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            self.documentClient = FakeInputDocumentClient(log: log)
            self.geometryClient = FakeInputGeometryClient(log: log)
            self.annotationClient = FakeInputAnnotationClient(log: log)
            self.presentationClient = FakeInputPresentationClient(log: log)
            self.lifecycleClient = FakeInputLifecycleClient(log: log)
            self.commandClient = FakeInputCommandClient(log: log)
        }

        var hostInputView: UIView { container }
    }

    private struct Fixture {
        let host: UpstreamFakeHost
        let backend: IDUpstreamInputBackend
        let log: RichTextInputEventLog
    }

    /// Attaches and returns the fixture. Upstream constructs its own test hosts with a font and a
    /// colour on every block (`InputDec/Tests/IDBlockTextViewTests.m:325-342`) because
    /// `IDBlockTextView` seeds its typing attributes from the document defaults; the adapter's
    /// `emptyDocumentBlocks()` does the same, and a seeded fixture spells it out here.
    private func makeAttached(_ strings: [String] = ["Hello"]) throws -> Fixture {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17.0),
            .foregroundColor: UIColor.label,
        ]
        let blocks = strings.map { NSAttributedString(string: $0, attributes: attributes) }
        let log = RichTextInputEventLog()
        let host = UpstreamFakeHost(log: log)
        window.addSubview(host.container)
        let backend = IDUpstreamInputBackend(attributedBlocks: blocks)
        try backend.attach(to: host)
        host.container.layoutIfNeeded()
        return Fixture(host: host, backend: backend, log: log)
    }

    /// The engine host, or a failure. Reaching for it is legitimate ONLY as an oracle — every
    /// assertion about what the adapter DID goes through the adapter.
    private func engine(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line)
        throws -> IDBlockTextView
    {
        try XCTUnwrap(fixture.backend.engineHostForTesting, "no engine host", file: file, line: line)
    }

    // MARK: - Attachment

    func test_attachBuildsThePortedEngineAndParentsItIntoTheHostView() throws {
        let fixture = try makeAttached()

        XCTAssertTrue(fixture.backend.isAttached)
        let view = try engine(fixture)
        // The object the adapter forwards to is the PORTED HOST, not a stand-in. A cast that could
        // never succeed is one of the ten defects this port replaces; this is the positive control.
        XCTAssertTrue(view.isKind(of: IDBlockTextView.self))
        XCTAssertTrue(view.superview === fixture.host.container,
                      "the engine is not parented into hostInputView")
        XCTAssertEqual(fixture.backend.recordedViolations, [])
        XCTAssertEqual(reportedViolations, [])
    }

    func test_attachingTwiceThrowsAlreadyAttached() throws {
        let fixture = try makeAttached()
        let second = UpstreamFakeHost(log: fixture.log)
        XCTAssertThrowsError(try fixture.backend.attach(to: second)) { error in
            guard case RichTextInputBackendAttachmentError.alreadyAttached = error else {
                return XCTFail("expected .alreadyAttached, got \(error)")
            }
        }
        XCTAssertTrue(try engine(fixture).superview === fixture.host.container,
                      "the failed second attach disturbed the first attachment")
    }

    func test_detachIsIdempotentAndTakesTheEngineDown() throws {
        let fixture = try makeAttached()
        let view = try engine(fixture)

        fixture.backend.detach()
        XCTAssertFalse(fixture.backend.isAttached)
        XCTAssertNil(view.superview, "the engine was left in the host's view hierarchy")
        XCTAssertNil(fixture.backend.engineHostForTesting)
        XCTAssertEqual(fixture.backend.recordedViolations, [],
                       "a clean detach reported something: \(fixture.backend.recordedViolations)")

        fixture.backend.detach()   // idempotent: a second call must be a no-op, not a violation
        XCTAssertFalse(fixture.backend.isAttached)
        XCTAssertEqual(fixture.backend.recordedViolations, [])
    }

    /// **The kernel is torn down by DEALLOCATION, so `detach()` has to actually release the engine.**
    ///
    /// `IDBlockTextView.dealloc` → `id_tearDownEditorGraph` is what detaches the behavior kernel, the
    /// interaction capability and the layout controller; that method lives in
    /// `IDBlockTextViewInternal.h` and this side cannot call it. So a leaked engine host is a leaked
    /// KERNEL ATTACHMENT, not merely a leaked view — and it would be invisible: every adapter member
    /// would keep reporting "detached" exactly as it should.
    func test_detachReleasesTheEngineSoTheKernelTearsDown() throws {
        weak var weakEngine: IDBlockTextView?
        try autoreleasepool {
            let fixture = try makeAttached(["Hello"])
            weakEngine = try engine(fixture)
            XCTAssertNotNil(weakEngine)
            fixture.backend.detach()
        }
        XCTAssertNil(weakEngine,
                     "the engine host survived detach() — its kernel is still attached, and no "
                     + "adapter member can tell, because they all correctly report 'detached'")
    }

    func test_reattachingAfterDetachBuildsAFreshEngine() throws {
        let fixture = try makeAttached(["ab"])
        let first = try engine(fixture)
        fixture.backend.detach()

        try fixture.backend.attach(to: fixture.host)
        let second = try engine(fixture)
        XCTAssertFalse(first === second, "re-attach reused the previous engine host")
        XCTAssertTrue(second.superview === fixture.host.container)
    }

    // MARK: - Identity

    /// The engine mints its own family and the adapter mints none. `IDRichTextLayoutController`
    /// validates with `isMemberOfClass:IDRichTextPosition.class` and RAISES otherwise, so this is
    /// not a stylistic claim: a Telegram-minted position is a process abort, or was, three times.
    func test_theEngineOwnsTheIdentityFamilyAndTheAdapterMintsNone() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        let start = backend.beginningOfDocument
        let end = backend.endOfDocument
        XCTAssertTrue(start is IDRichTextPosition,
                      "beginningOfDocument is a \(type(of: start)) — the adapter minted identity")
        XCTAssertTrue(end is IDRichTextPosition,
                      "endOfDocument is a \(type(of: end)) — the adapter minted identity")

        let range = try XCTUnwrap(backend.textRange(from: start, to: end))
        XCTAssertTrue(range is IDRichTextRange,
                      "textRange(from:to:) is a \(type(of: range)) — the adapter minted identity")

        let stepped = try XCTUnwrap(backend.position(from: start, offset: 2))
        XCTAssertTrue(stepped is IDRichTextPosition)

        // Nothing from the legacy family may cross this seam.
        XCTAssertFalse(start is LegacyTextPosition)
        XCTAssertFalse(range is LegacyTextRange)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    /// A foreign position must be REPORTED BY NAME, and must not reach the engine (where
    /// `IDRichRaise` would throw an NSException Swift cannot catch).
    func test_aForeignPositionIsNamedAndNeverReachesTheEngine() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let foreign = LegacyTextPosition(0)

        let offset = backend.offset(from: foreign, to: backend.endOfDocument)
        let comparison = backend.compare(foreign, to: backend.beginningOfDocument)
        let stepped = backend.position(from: foreign, offset: 1)

        XCTAssertEqual(offset, 0)
        XCTAssertEqual(comparison, .orderedSame)
        XCTAssertNil(stepped)

        let captured = backend.recordedViolations
        XCTAssertEqual(captured.count, 3, "expected one report per foreign call: \(captured)")
        for message in captured {
            XCTAssertTrue(message.contains("LegacyTextPosition"),
                          "the report does not name the class it received: \(message)")
            XCTAssertTrue(message.contains("IDRichTextPosition"),
                          "the report does not name what the engine expects: \(message)")
        }
        XCTAssertEqual(reportedViolations.count, 3,
                       "the sanctioned reporter channel did not see them: \(reportedViolations)")
    }

    func test_aForeignRangeIsNamedAndNeverReachesTheEngine() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let foreign = LegacyTextRange(LegacyTextPosition(0), LegacyTextPosition(2))

        XCTAssertNil(backend.text(in: foreign))
        backend.replace(foreign, withText: "x")

        let captured = backend.recordedViolations
        XCTAssertEqual(captured.count, 2, "expected one report per foreign call: \(captured)")
        XCTAssertTrue(captured.allSatisfy { $0.contains("LegacyTextRange") })
        // The engine's document is untouched: the foreign range never reached it.
        XCTAssertEqual(try engine(fixture).attributedBlocks[0].string, "Hello")
    }

    // MARK: - Document reads

    func test_documentReadsForwardToTheEngine() throws {
        let fixture = try makeAttached(["ab", "cd"])
        let backend = fixture.backend

        let start = backend.beginningOfDocument
        let end = backend.endOfDocument
        // The dense canonical axis: one "\n" per block boundary, so "ab" + "\n" + "cd" == 5.
        XCTAssertEqual(backend.offset(from: start, to: end), 5)
        let whole = try XCTUnwrap(backend.textRange(from: start, to: end))
        XCTAssertEqual(backend.text(in: whole), "ab\ncd")
        XCTAssertEqual(backend.compare(start, to: end), .orderedAscending)
        XCTAssertTrue(backend.hasText)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    func test_replaceForwardsToTheEngineDocument() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        let from = try XCTUnwrap(backend.position(from: backend.beginningOfDocument, offset: 0))
        let to = try XCTUnwrap(backend.position(from: backend.beginningOfDocument, offset: 5))
        let range = try XCTUnwrap(backend.textRange(from: from, to: to))
        backend.replace(range, withText: "Bye")

        XCTAssertEqual(try engine(fixture).attributedBlocks[0].string, "Bye",
                       "replace() did not reach the engine's DOCUMENT")
        XCTAssertEqual(backend.recordedViolations, [])
    }

    // MARK: - Typing (the phase's headline)

    func test_typingThroughInsertTextReachesTheEngineDocument() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let view = try engine(fixture)
        XCTAssertTrue(view.becomeFirstResponder())

        backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 5)), reason: .programmatic)
        backend.insertText("!")

        // CAPTURED from the document itself, not from a derived read.
        XCTAssertEqual(view.attributedBlocks[0].string, "Hello!",
                       "the adapter accepted the character and dropped it")
        XCTAssertEqual(backend.offset(from: backend.beginningOfDocument,
                                      to: backend.endOfDocument), 6)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    /// More than one character, then a delete — a host can accept exactly one insertion and then
    /// desynchronise its storage adapter from its document, which one `insertText` cannot see.
    func test_typingAndDeletingStayInSyncThroughTheAdapter() throws {
        let fixture = try makeAttached(["ab"])
        let backend = fixture.backend
        let view = try engine(fixture)
        XCTAssertTrue(view.becomeFirstResponder())
        backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 2)), reason: .programmatic)

        for character in ["c", "d", "e"] {
            backend.insertText(character)
        }
        XCTAssertEqual(view.attributedBlocks[0].string, "abcde")

        backend.deleteBackward()
        XCTAssertEqual(view.attributedBlocks[0].string, "abcd")
        XCTAssertEqual(backend.offset(from: backend.beginningOfDocument,
                                      to: backend.endOfDocument), 4)
        XCTAssertTrue(backend.hasText)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    // MARK: - Selection

    func test_selectionRoundTripsThroughTheEngine() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        backend.setSelection(
            RichTextCanonicalSelection(anchor: RichTextInputPosition(utf16Offset: 1),
                                       head: RichTextInputPosition(utf16Offset: 4)),
            reason: .programmatic)

        let readBack = backend.canonicalSelection
        XCTAssertEqual(readBack.anchor.utf16Offset, 1)
        XCTAssertEqual(readBack.head.utf16Offset, 4)
        XCTAssertFalse(readBack.isCollapsed)
        // And the same selection is visible on the UIKit surface, as the engine's own range object.
        let uiKitRange = try XCTUnwrap(backend.selectedTextRange)
        XCTAssertTrue(uiKitRange is IDRichTextRange)
        XCTAssertEqual(backend.text(in: uiKitRange), "ell")
        XCTAssertEqual(backend.recordedViolations, [])
    }

    func test_caretSelectionRoundTrips() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 3)), reason: .touch)
        let readBack = backend.canonicalSelection
        XCTAssertTrue(readBack.isCollapsed)
        XCTAssertEqual(readBack.head.utf16Offset, 3)
    }

    /// RECORDED GAP, pinned so it cannot be mistaken for a working feature: the engine publishes an
    /// ORDERED `UITextRange` and exposes no selection direction, so a reversed selection is not
    /// representable through this adapter. `isReversed` reads `false` no matter which way it went in.
    func test_aReversedSelectionIsNotRepresentable_recordedGap() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        backend.setSelection(
            RichTextCanonicalSelection(anchor: RichTextInputPosition(utf16Offset: 4),
                                       head: RichTextInputPosition(utf16Offset: 1)),
            reason: .touch)

        let readBack = backend.canonicalSelection
        XCTAssertFalse(readBack.isReversed,
                       "the engine started publishing a selection direction — this gap can close")
        XCTAssertEqual(readBack.normalizedRange, NSRange(location: 1, length: 3),
                       "the endpoints themselves must still survive the round trip")
    }

    // MARK: - Published state

    func test_stateForwardsTheEnginesRevisionSelectionAndCompositionFlag() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let view = try engine(fixture)
        XCTAssertTrue(view.becomeFirstResponder())
        backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 5)), reason: .programmatic)

        let before = backend.state
        XCTAssertNil(before.markedRange)
        XCTAssertFalse(before.isComposing)
        XCTAssertEqual(before.selection.head.utf16Offset, 5)

        backend.insertText("!")
        let after = backend.state

        XCTAssertGreaterThan(after.documentRevision, before.documentRevision,
                             "the engine's document revision did not advance across an insertion — "
                             + "`state` is not reading the engine's counter")
        XCTAssertEqual(after.selection.head.utf16Offset, 6)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    // MARK: - External synchronization

    /// The FORWARDED half applies; the UNADOPTABLE half is reported by name rather than swallowed.
    func test_synchronizeAppliesTheSelectionAndReportsWhatItCannotAdopt() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        let change = RichTextInputExternalChange(
            oldRevision: 0,
            newRevision: 99,
            reason: .documentReplacement,
            changedRangeBefore: NSRange(location: 0, length: 5),
            changedRangeAfter: NSRange(location: 0, length: 5),
            selection: .caret(at: RichTextInputPosition(utf16Offset: 2)),
            markedTextPolicy: .discard)
        backend.synchronizeAfterExternalChange(change)

        XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 2,
                       "the selection half was not applied")
        let captured = backend.recordedViolations
        XCTAssertEqual(captured.count, 1, "expected exactly one report: \(captured)")
        let message = try XCTUnwrap(captured.first)
        XCTAssertTrue(message.contains("documentReplacement"))
        XCTAssertTrue(message.contains("NOT adopted"),
                      "the report does not say what was dropped: \(message)")
        // And the revision it refused to adopt really did not land.
        XCTAssertNotEqual(backend.state.documentRevision, 99)
    }

    /// `.layoutOnly` claims nothing about the document, so it is applied without a report.
    func test_synchronizeWithLayoutOnlyReportsNothing() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 0, newRevision: 0, reason: .layoutOnly,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: RichTextInputPosition(utf16Offset: 1)),
            markedTextPolicy: .preserveIfRebasable))
        XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 1)
        XCTAssertEqual(backend.recordedViolations, [])
    }

    // MARK: - Tokenizer

    func test_theTokenizerIsTheEnginesOwn() throws {
        let fixture = try makeAttached(["Hello world"])
        let tokenizer = fixture.backend.tokenizer
        let engineTokenizer = try engine(fixture).tokenizer
        XCTAssertTrue(tokenizer === engineTokenizer,
                      "the adapter vended a tokenizer that is not the engine's — a Telegram-minted "
                      + "tokenizer hands Telegram-minted positions back into engine witnesses")
        XCTAssertEqual(fixture.backend.recordedViolations, [])
    }

    func test_aDetachedTokenizerReadIsReportedAndInert() throws {
        let fixture = try makeAttached(["Hello"])
        fixture.backend.detach()
        let tokenizer = fixture.backend.tokenizer
        XCTAssertNil(tokenizer.position(from: UITextPosition(), toBoundary: .word,
                                        inDirection: .storage(.forward)))
        XCTAssertEqual(fixture.backend.recordedViolations.count, 1)
        XCTAssertTrue(try XCTUnwrap(fixture.backend.recordedViolations.first).contains("detached"))
    }

    // MARK: - Detached operation

    /// Every one of the 29 must report when there is no engine — none may answer plausibly.
    func test_everyImplementedMemberReportsWhileDetached() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let position = backend.beginningOfDocument
        let range = try XCTUnwrap(backend.textRange(from: position, to: backend.endOfDocument))
        backend.detach()

        var seen: [String] = []
        func expectReport(_ label: String, _ body: () -> Void) {
            let before = backend.recordedViolations.count
            body()
            let after = backend.recordedViolations.count
            if after == before { seen.append(label) }
        }

        expectReport("state") { _ = backend.state }
        expectReport("canonicalSelection") { _ = backend.canonicalSelection }
        expectReport("setSelection") {
            backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 0)), reason: .programmatic)
        }
        expectReport("synchronizeAfterExternalChange") {
            backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
                oldRevision: 0, newRevision: 0, reason: .layoutOnly,
                changedRangeBefore: nil, changedRangeAfter: nil,
                selection: .caret(at: RichTextInputPosition(utf16Offset: 0)),
                markedTextPolicy: .discard))
        }
        expectReport("inputDelegate.get") { _ = backend.inputDelegate }
        expectReport("inputDelegate.set") { backend.inputDelegate = nil }
        expectReport("tokenizer") { _ = backend.tokenizer }
        expectReport("selectedTextRange.get") { _ = backend.selectedTextRange }
        expectReport("selectedTextRange.set") { backend.selectedTextRange = nil }
        expectReport("markedTextRange") { _ = backend.markedTextRange }
        expectReport("beginningOfDocument") { _ = backend.beginningOfDocument }
        expectReport("endOfDocument") { _ = backend.endOfDocument }
        expectReport("text(in:)") { _ = backend.text(in: range) }
        expectReport("replace(_:withText:)") { backend.replace(range, withText: "x") }
        expectReport("position(from:offset:)") { _ = backend.position(from: position, offset: 1) }
        expectReport("textRange(from:to:)") { _ = backend.textRange(from: position, to: position) }
        expectReport("compare(_:to:)") { _ = backend.compare(position, to: position) }
        expectReport("offset(from:to:)") { _ = backend.offset(from: position, to: position) }
        expectReport("hasText") { _ = backend.hasText }
        expectReport("insertText(_:)") { backend.insertText("x") }
        expectReport("deleteBackward()") { backend.deleteBackward() }
        // PHASE 3 — the seven responder requirements the settled model made forwardable. They obey
        // the same rule as the original 22: with no engine there is nothing to forward TO, so each
        // reports rather than answering `false`/`nil`/nothing. `hostWillMove(toWindow:)` is in the
        // list deliberately even though it does nothing when ATTACHED — the invariant "every member
        // reports when there is no engine" is worth having no exception to.
        expectReport("canBecomeFirstResponder") { _ = backend.canBecomeFirstResponder }
        expectReport("canResignFirstResponder") { _ = backend.canResignFirstResponder }
        expectReport("isEditableForWritingTools") { _ = backend.isEditableForWritingTools }
        expectReport("undoManager") { _ = backend.undoManager }
        expectReport("canPerformCommand(_:sender:)") { _ = backend.canPerformCommand(.copy, sender: nil) }
        expectReport("performCommand(_:sender:)") { backend.performCommand(.copy, sender: nil) }
        expectReport("hostWillMove(toWindow:)") { backend.hostWillMove(toWindow: nil) }
        // PHASE 3b — the responder hand-off pair. Detached, there is no engine to hand the role TO,
        // so each reports rather than answering `.performedByBackend(succeeded: false)` silently.
        expectReport("acquireFirstResponder()") { _ = backend.acquireFirstResponder() }
        expectReport("relinquishFirstResponder()") { _ = backend.relinquishFirstResponder() }

        XCTAssertEqual(seen, [], "these answered silently while detached: \(seen)")
        // `isAttached` is the one member that must NOT report — it is the question itself.
        let before = backend.recordedViolations.count
        XCTAssertFalse(backend.isAttached)
        XCTAssertEqual(backend.recordedViolations.count, before)
    }

    // MARK: - The unimplemented requirements

    /// **EVERY unimplemented requirement is loud — enumerated, not sampled.**
    ///
    /// §9.9 of the port plan names "plausible stubs" as this programme's signature failure, and the
    /// reconstruction shipped ten of them. This calls every member the adapter does not implement and
    /// asserts each one produced a report. A member that quietly returned `.zero`/`false`/`nil` shows
    /// up here as a named entry in the failure message.
    ///
    /// **The count is NOT in this test's name any more** (phase 3 review, Minor 7). It was
    /// `test_allSixtyFiveUnimplementedRequirementsReport`, then `…FiftyEight…`, and it moves every
    /// phase — a number in a SYMBOL is the worst of the five places phase 3 restated it, because
    /// renaming a test is the one edit nobody makes for free. The partition is derived and asserted
    /// once, in
    /// `InputDecUpstreamAdapterBoundaryTests.test_everyDeclaredRequirementIsEitherImplementedOrLoud`;
    /// `test_theRuntimeEnumerationCallsEveryUnwitnessedRequirement` reconciles THIS list to that one,
    /// which is the check `XCTAssertEqual(count, 60)` below cannot make (a dropped member paired with
    /// a duplicated one leaves the count intact).
    ///
    /// The list shrank by seven at phase 3, which settled the responder model and moved seven of the
    /// fifteen `RichTextInputResponderBackend` requirements onto real forwards. Those seven did not
    /// become silent — they moved to `test_everyImplementedMemberReportsWhileDetached`, which requires
    /// each of them to report when there is no engine, and to `IDUpstreamResponderModelTests`, which
    /// asserts what each one actually forwards. Phase 3b added two implemented members and moved none
    /// off this list.
    func test_everyUnimplementedRequirementReports() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let position = backend.beginningOfDocument
        let range = try XCTUnwrap(backend.textRange(from: position, to: backend.endOfDocument))
        let baseline = backend.recordedViolations.count
        let reporterBaseline = reportedViolations.count

        var silent: [String] = []
        var count = 0
        func expectReport(_ label: String, _ body: () -> Void) {
            count += 1
            let before = backend.recordedViolations.count
            body()
            if backend.recordedViolations.count == before { silent.append(label) }
        }

        // RichTextInputTextBackend — 16
        expectReport("markedTextStyle.get") { _ = backend.markedTextStyle }
        expectReport("markedTextStyle.set") { backend.markedTextStyle = nil }
        expectReport("setMarkedText") { backend.setMarkedText("a", selectedRange: NSRange(location: 0, length: 1)) }
        expectReport("unmarkText") { backend.unmarkText() }
        expectReport("position(from:in:offset:)") { _ = backend.position(from: position, in: .right, offset: 1) }
        expectReport("position(within:farthestIn:)") { _ = backend.position(within: range, farthestIn: .right) }
        expectReport("characterRange(byExtending:in:)") { _ = backend.characterRange(byExtending: position, in: .right) }
        expectReport("baseWritingDirection") { _ = backend.baseWritingDirection(for: position, in: .forward) }
        expectReport("setBaseWritingDirection") { backend.setBaseWritingDirection(.leftToRight, for: range) }
        expectReport("firstRect(for:)") { _ = backend.firstRect(for: range) }
        expectReport("caretRect(for:)") { _ = backend.caretRect(for: position) }
        expectReport("selectionRects(for:)") { _ = backend.selectionRects(for: range) }
        expectReport("closestPosition(to:)") { _ = backend.closestPosition(to: .zero) }
        expectReport("closestPosition(to:within:)") { _ = backend.closestPosition(to: .zero, within: range) }
        expectReport("characterRange(at:)") { _ = backend.characterRange(at: .zero) }
        expectReport("textStyling(at:in:)") { _ = backend.textStyling(at: position, in: .forward) }
        expectReport("insertDictationResult") { backend.insertDictationResult([]) }

        // RichTextInputResponderBackend — 8 of 15 (phase 3 implemented the other seven; the
        // measurements and the rejected wirings are in `IDUpstreamInputBackend+Responder.swift`)
        expectReport("hostWillBecomeFirstResponder") { backend.hostWillBecomeFirstResponder() }
        expectReport("hostDidBecomeFirstResponder") { backend.hostDidBecomeFirstResponder() }
        expectReport("hostDidFailToBecomeFirstResponder") { backend.hostDidFailToBecomeFirstResponder() }
        expectReport("hostWillResignFirstResponder") { backend.hostWillResignFirstResponder() }
        expectReport("hostDidResignFirstResponder") { backend.hostDidResignFirstResponder() }
        expectReport("hostDidFailToResignFirstResponder") { backend.hostDidFailToResignFirstResponder() }
        expectReport("editPolicyDidChange") { backend.editPolicyDidChange() }
        expectReport("textInputTraitsDidChange") { backend.textInputTraitsDidChange() }

        // RichTextInputInteractionBackend — 8
        expectReport("installInteractions") { backend.installInteractions() }
        expectReport("removeInteractions") { backend.removeInteractions() }
        expectReport("viewportDidChange") { backend.viewportDidChange() }
        expectReport("layoutDidChange") { backend.layoutDidChange(generation: 1) }
        expectReport("beginFloatingCursor") { backend.beginFloatingCursor(at: .zero) }
        expectReport("updateFloatingCursor") { backend.updateFloatingCursor(at: .zero) }
        expectReport("endFloatingCursor") { backend.endFloatingCursor() }
        expectReport("cancelActiveInteraction") { backend.cancelActiveInteraction(reason: .backendDetach) }

        // RichTextInputCheckingBackend — 3
        expectReport("installCheckingIfNeeded") { backend.installCheckingIfNeeded() }
        expectReport("checkOnSelectionChange") { backend.checkOnSelectionChange() }
        expectReport("globalRange(ofCheckingRange:)") { _ = backend.globalRange(ofCheckingRange: range) }

        // RichTextInputBackend — 23
        expectReport("canonicalSelectionAnchorOffset") { _ = backend.canonicalSelectionAnchorOffset }
        expectReport("canonicalSelectionHeadOffset") { _ = backend.canonicalSelectionHeadOffset }
        expectReport("setCanonicalAnchor") { backend.setCanonicalAnchor(0) }
        expectReport("setCanonicalHead") { backend.setCanonicalHead(0) }
        expectReport("markedRange") { _ = backend.markedRange }
        expectReport("isComposingPrediction") { _ = backend.isComposingPrediction }
        expectReport("isComposing") { _ = backend.isComposing }
        expectReport("compositionSnapshot") { _ = backend.compositionSnapshot }
        expectReport("setCompositionMarkedRange") { backend.setCompositionMarkedRange(nil, isPrediction: false) }
        expectReport("setCompositionSnapshot") { backend.setCompositionSnapshot(nil) }
        expectReport("clearCompositionState") { backend.clearCompositionState() }
        expectReport("floatingCursorActive") { _ = backend.floatingCursorActive }
        expectReport("floatingCursorPoint") { _ = backend.floatingCursorPoint }
        expectReport("floatingScrollVelocity") { _ = backend.floatingScrollVelocity }
        expectReport("setFloatingCursorActive") { backend.setFloatingCursorActive(true) }
        expectReport("setFloatingCursorPoint") { backend.setFloatingCursorPoint(.zero) }
        expectReport("setFloatingScrollVelocity") { backend.setFloatingScrollVelocity(1.0) }
        expectReport("suppressesSelectionNotifications.get") { _ = backend.suppressesSelectionNotifications }
        expectReport("suppressesSelectionNotifications.set") { backend.suppressesSelectionNotifications = true }
        expectReport("notifyingContentAndSelectionChange") { backend.notifyingContentAndSelectionChange {} }
        expectReport("notifyingSelectionChange") { backend.notifyingSelectionChange {} }
        expectReport("notifyingSelectionChangeIgnoringCoalescing") { backend.notifyingSelectionChangeIgnoringCoalescing {} }
        expectReport("notifyingContentChange") { backend.notifyingContentChange {} }
        expectReport("notifyCoalescedSelectionResync") { backend.notifyCoalescedSelectionResync() }

        // 58 REQUIREMENTS, 60 CALLS: `markedTextStyle` and `suppressesSelectionNotifications` are
        // `{ get set }`, so each is one requirement exercised twice. The count is asserted so this
        // list cannot silently lose an entry.
        XCTAssertEqual(count, 60, "the enumeration lost or gained an entry")
        XCTAssertEqual(silent, [], "these returned a plausible value with NO report: \(silent)")
        XCTAssertEqual(backend.recordedViolations.count - baseline, 60,
                       "one report per call, no more and no fewer")
        // F8 — and through the SANCTIONED channel too. The report's "two independent records, so a
        // test cannot pass because one channel quietly stopped firing" was only true of the
        // three-report identity test until this line; the largest test in the suite checked one.
        XCTAssertEqual(reportedViolations.count - reporterBaseline, 60,
                       "RichTextInputContractViolation.reporter saw a different number of violations "
                       + "than the backend recorded — one of the two channels is not firing")
    }

    /// The four `notifying…` brackets report AND run the body. Dropping the caller's closure would be
    /// a strictly worse failure than the missing bracket, so this pins that they run.
    func test_theNotifyingBracketsStillRunTheirBody() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        var ran = 0
        backend.notifyingContentAndSelectionChange { ran += 1 }
        backend.notifyingSelectionChange { ran += 1 }
        backend.notifyingSelectionChangeIgnoringCoalescing { ran += 1 }
        backend.notifyingContentChange { ran += 1 }
        XCTAssertEqual(ran, 4, "a notifying bracket discarded the caller's body")
        XCTAssertEqual(backend.recordedViolations.count, 4)
    }

    // MARK: - Attachment truth, the edit policy, and the write-side gaps (fix round 1)

    /// **F9 — `isAttached` is DERIVED from the engine, so the two cannot disagree.**
    ///
    /// An earlier draft stored a `Bool` next to `engine` and `requireEngine` checked both. That is
    /// "a pair a backend can half-implement", which this package's own `selectionPairReason` and this
    /// repo's `enableUnreadAlignment` / `settledContentOffsets` history both warn about. This asserts
    /// the two agree in all three states; it would have caught the stored version diverging.
    func test_isAttachedTracksTheEngineInEveryState() throws {
        let log = RichTextInputEventLog()
        let host = UpstreamFakeHost(log: log)
        window.addSubview(host.container)
        let backend = IDUpstreamInputBackend(attributedBlocks: IDUpstreamInputBackend.emptyDocumentBlocks())

        XCTAssertEqual(backend.isAttached, backend.engineHostForTesting != nil)
        XCTAssertFalse(backend.isAttached)

        try backend.attach(to: host)
        XCTAssertEqual(backend.isAttached, backend.engineHostForTesting != nil)
        XCTAssertTrue(backend.isAttached)

        backend.detach()
        XCTAssertEqual(backend.isAttached, backend.engineHostForTesting != nil)
        XCTAssertFalse(backend.isAttached)
    }

    /// **F14 — the edit policy is the CALLER's, and the four fields the engine cannot honour are
    /// reported by name.** `IDBlockTextView` has `isEditable`/`isSelectable` and nothing for the
    /// other four, so a caller asking for one of those gets a named report rather than a silently
    /// ignored restriction.
    func test_anEditPolicyTheEngineCannotHonourIsNamedAtAttach() throws {
        let log = RichTextInputEventLog()
        let host = UpstreamFakeHost(log: log)
        window.addSubview(host.container)
        let restrictive = RichTextInputEditPolicy(
            isEditable: true, isSelectable: true, allowsRichText: true,
            allowsPaste: false, allowsDictation: false, allowsWritingTools: true)
        let backend = IDUpstreamInputBackend(
            attributedBlocks: IDUpstreamInputBackend.emptyDocumentBlocks(),
            editPolicy: restrictive)

        try backend.attach(to: host)

        XCTAssertEqual(backend.recordedViolations.count, 1)
        let message = try XCTUnwrap(backend.recordedViolations.first)
        XCTAssertTrue(message.contains("allowsPaste"), message)
        XCTAssertTrue(message.contains("allowsDictation"), message)
        XCTAssertFalse(message.contains("allowsRichText"),
                       "a field the caller did NOT restrict was reported as refused: \(message)")
        XCTAssertTrue(message.contains("NOT applied"), message)
    }

    /// The two fields the engine CAN honour really are honoured — otherwise the policy parameter
    /// would be decoration and the report above would be the only evidence it exists.
    func test_theEditPolicysTwoHonourableFieldsReachTheEngine() throws {
        let log = RichTextInputEventLog()
        let host = UpstreamFakeHost(log: log)
        window.addSubview(host.container)
        let readOnly = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        let backend = IDUpstreamInputBackend(
            attributedBlocks: IDUpstreamInputBackend.emptyDocumentBlocks(),
            editPolicy: readOnly)
        try backend.attach(to: host)

        let view = try XCTUnwrap(backend.engineHostForTesting)
        XCTAssertFalse(view.isEditable, "the policy's isEditable did not reach the engine")
        XCTAssertTrue(view.isSelectable)
        // Nothing in that policy is unhonourable, so nothing is reported.
        XCTAssertEqual(backend.recordedViolations, [])
    }

    /// **F4 — a write-side `.upstream` affinity is NAMED, not dropped.** The engine mints positions at
    /// `UITextStorageDirectionForward` and exposes no affinity-taking member, so `.upstream` cannot be
    /// applied; the selection endpoints still land.
    func test_anUpstreamAffinityRequestIsNamedAndTheOffsetsStillLand() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend

        backend.setSelection(
            RichTextCanonicalSelection(
                anchor: RichTextInputPosition(utf16Offset: 1, affinity: .upstream),
                head: RichTextInputPosition(utf16Offset: 4, affinity: .downstream)),
            reason: .programmatic)

        XCTAssertEqual(backend.recordedViolations.count, 1,
                       "expected exactly one report: \(backend.recordedViolations)")
        let message = try XCTUnwrap(backend.recordedViolations.first)
        XCTAssertTrue(message.contains("anchor"), message)
        XCTAssertFalse(message.contains("head"),
                       "the .downstream endpoint was reported as refused; the engine produces "
                       + ".downstream anyway, so it was not refused: \(message)")
        XCTAssertTrue(message.contains("NOT applied"), message)

        // The gap is affinity ONLY — the offsets are unaffected.
        XCTAssertEqual(backend.canonicalSelection.normalizedRange, NSRange(location: 1, length: 3))
    }

    /// The silent half of F4's rule: `.downstream` is what the engine produces, so asking for it was
    /// not a refusal and must not be reported. A rule that fired on every selection write would train
    /// a reader to ignore the channel the whole phase rests on.
    func test_aDownstreamAffinityRequestIsNotReported() throws {
        let fixture = try makeAttached(["Hello"])
        fixture.backend.setSelection(
            RichTextCanonicalSelection(
                anchor: RichTextInputPosition(utf16Offset: 1, affinity: .downstream),
                head: RichTextInputPosition(utf16Offset: 4, affinity: .downstream)),
            reason: .programmatic)
        XCTAssertEqual(fixture.backend.recordedViolations, [])
    }

    /// **F11 — a backend released while still attached must not leave the engine (and its live
    /// kernel) parented to the host.** There is no production caller today, so this guards the type
    /// rather than a caller: the failure mode is silent, because every member of a dropped backend
    /// would go on correctly reporting "detached" while the kernel stayed attached.
    ///
    /// `deinit` is nonisolated and hops to the main actor, so the release is asynchronous — the
    /// expectation is what makes this test honest rather than timing-dependent.
    func test_droppingAnAttachedBackendStillTakesTheEngineDown() throws {
        let log = RichTextInputEventLog()
        let host = UpstreamFakeHost(log: log)
        window.addSubview(host.container)
        weak var weakEngine: IDBlockTextView?

        autoreleasepool {
            let backend = IDUpstreamInputBackend(
                attributedBlocks: IDUpstreamInputBackend.emptyDocumentBlocks())
            try? backend.attach(to: host)
            weakEngine = backend.engineHostForTesting
            XCTAssertNotNil(weakEngine)
            XCTAssertEqual(host.container.subviews.count, 1)
            // NO detach() — the backend simply goes out of scope.
        }

        // POLLED, not a single async hop: `deinit`'s main-actor hop is not ordered against a
        // `DispatchQueue.main.async` enqueued here, so a one-shot check would be a coin flip that
        // happened to land. This fails only if the engine is STILL parented after two seconds.
        let released = expectation(description: "the engine leaves the host's view hierarchy")
        func poll(_ attemptsLeft: Int) {
            if host.container.subviews.isEmpty { return released.fulfill() }
            guard attemptsLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { poll(attemptsLeft - 1) }
        }
        poll(200)
        wait(for: [released], timeout: 3.0)
        XCTAssertNil(weakEngine,
                     "a dropped backend left the engine alive in hostInputView.subviews — its "
                     + "kernel is still attached and nothing can observe it")
    }

    // MARK: - The client side

    /// **PHASE 2 CONSUMES NONE OF THE 54 CLIENT-SIDE REQUIREMENTS.** The six fakes share one log; a
    /// single crossing would leave an entry in it. Asserting emptiness after a full exercise is what
    /// makes that claim measured rather than asserted.
    func test_theAdapterConsumesNoClientSideRequirement() throws {
        let fixture = try makeAttached(["Hello"])
        let backend = fixture.backend
        let view = try engine(fixture)
        XCTAssertTrue(view.becomeFirstResponder())

        backend.setSelection(.caret(at: RichTextInputPosition(utf16Offset: 5)), reason: .programmatic)
        backend.insertText("!")
        backend.deleteBackward()
        _ = backend.state
        _ = backend.canonicalSelection
        _ = backend.hasText
        _ = backend.text(in: try XCTUnwrap(backend.textRange(from: backend.beginningOfDocument,
                                                            to: backend.endOfDocument)))
        backend.detach()

        XCTAssertEqual(fixture.log.events, [],
                       "the adapter reached a client-side requirement: \(fixture.log.kinds)")
    }
}
#endif
