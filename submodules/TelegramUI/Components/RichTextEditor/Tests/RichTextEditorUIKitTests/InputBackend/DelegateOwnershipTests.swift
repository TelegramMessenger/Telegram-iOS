#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 43 — **the canvas holds no input-delegate, tokenizer or coalescing storage at all.**
///
/// The last member of the `SelectionAuthorityTests` (Task 35/40b) / `MarkedStateAuthorityTests`
/// (Task 41) / `FloatingCursorStateAuthorityTests` (Task 42) family, and the smallest: two of the
/// three properties this task deletes were already forwarders or dead by the time it ran, so its
/// subject is the SHAPE that remains — nothing on `DocumentCanvasView` stores, mints or shadows
/// input-delegate / tokenizer / notification-suppression state.
///
/// # What was actually here to delete (measured, not inherited)
///
/// The brief named three canvas properties. Measured in the tree this task started from:
///
///   * `textInputDelegate` — **already gone.** Task 26 deleted it; only a comment survived at
///     `DocumentCanvasView.swift:749`. `grep -rn textInputDelegate Sources` returned three comment
///     lines and no declaration.
///   * `inputTokenizer` (`DocumentCanvasView.swift:755`) — **dead storage with ZERO readers.**
///     `grep -rn inputTokenizer Sources` returned its declaration plus two comments. The live
///     tokenizer cache moved to `LegacyRichTextInputBackend.tokenizerStorage` at Task 24 and this
///     property was simply left behind.
///   * `coalescingSelectionNotifications` (`:909`) — a Task-26 COMPUTED FORWARDER onto
///     `inputBackend.suppressesSelectionNotifications`, with four canvas-side use sites (see
///     `test_coalescingFlagIsStoredOnlyInTheBackend`).
///
/// So only two declarations were deleted, and neither had ever been a second authority. The value of
/// this suite is that it makes the absence CHECKABLE: a `Mirror` sees a re-introduced stored property,
/// which no source scan in `InputBackendSourceBoundaryTests` can (`inputStateWriteCount` skips
/// declarations by design, and `identifierMentionCount` cannot tell a declaration from a read).
///
/// # Tokenizer lifetime (coordinator supplement §1) — ALREADY DECIDED, at Task 24
///
/// The supplement asked this task to decide what a tokenizer read does across detach/re-attach.
/// It does not need deciding: `LegacyRichTextInputBackend+Attachment.swift` builds `tokenizerStorage`
/// EAGERLY in `attach(to:)`, clears it in `performDetachSteps()` and in the attach throw path, and
/// `+TextReads.swift`'s getter answers a shared stateless `NoOpTextInputTokenizer` plus one
/// `RichTextInputContractViolation` when read detached. All three halves are already pinned by
/// `BackendAttachmentTests.test_tokenizerIsCachedAcrossReads` /
/// `…test_tokenizerIsClearedWhileDetached_notStaleFromThePreviousAttach` /
/// `…test_tokenizerIsRebuiltAfterDetachAndReattachToADifferentCanvas`.
///
/// What Task 43 changed is only the CONSTRUCTION SITE: `DocumentTokenizer(canvas:)` used to be minted
/// by a canvas hook (`DocumentCanvasView+UITextInput.swift`'s `legacyMakeTokenizer()`, a D24
/// clause-(a) forward) and is now minted by the backend directly. `test_theTokenizerIsOwnedByThe`
/// `BackendAndIsStable` asserts the stability half here, so this file states the whole policy in one
/// place; the three attachment tests above remain the lifetime pins and are NOT duplicated.
@MainActor
@available(iOS 16.0, *)
final class DelegateOwnershipTests: XCTestCase {

    // MARK: - Fixtures

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    @discardableResult
    private func laidOut(_ v: DocumentCanvasView) -> DocumentCanvasView {
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hello world")]))],
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    private func realCanvas() -> (DocumentCanvasView, LegacyRichTextInputBackend) {
        let v = laidOut(DocumentCanvasView())
        return (v, v.inputBackend as! LegacyRichTextInputBackend)
    }

    /// Every negative `Mirror` assertion in this file is preceded by these two positives. A misspelled
    /// name reports "no stored property" exactly as convincingly as a deleted one, which would make
    /// every negative vacuous.
    private func canvasLabels(_ v: DocumentCanvasView) -> Set<String> {
        let labels = Set(Mirror(reflecting: v).children.compactMap(\.label))
        XCTAssertTrue(labels.contains("lastLayoutWidth"),
                      "control: the Mirror must see DocumentCanvasView's own stored properties, or "
                      + "every assertion below is vacuous — saw \(labels.count) labels")
        XCTAssertTrue(labels.contains("quoteStyle"), "control, second stored property")
        return labels
    }

    // MARK: - 1. No delegate or tokenizer storage on the canvas

    /// `textInputDelegate` was Task 26's deletion and `inputTokenizer` is this task's. Both are
    /// asserted here by NAME and by TYPE: a re-introduction under a different name still shows up as a
    /// child whose value is a `UITextInputDelegate`/`UITextInputTokenizer`, which is the property that
    /// actually matters (rule R16 makes the backend the package's only sender of delegate
    /// notifications, and a canvas-side copy is how a second sender starts).
    ///
    /// **HONEST LIMIT OF THE TYPED HALF.** It is a FORWARD guard, and unlike the named half it was
    /// never observed red — nothing in the tree has ever stored a tokenizer or a delegate on the
    /// canvas under a different name, so there was no mutation available that did not amount to
    /// planting a fake property in production source. Its non-vacuity rests on the same control as
    /// everything else here: `canvasLabels(_:)` proves the `Mirror` sees `DocumentCanvasView`'s own
    /// stored properties, so the loop is iterating over a non-empty set. Note also that
    /// `Mirror.children` sees Swift stored properties only; an ObjC ivar would be invisible to both
    /// halves, which is why the source-boundary scans exist alongside this suite rather than instead
    /// of it.
    func test_theCanvasHasNoDelegateStorage() {
        let (v, backend) = realCanvas()
        let labels = canvasLabels(v)

        for name in ["textInputDelegate", "inputTokenizer", "tokenizerStorage", "inputDelegateStorage"] {
            XCTAssertFalse(labels.contains(name),
                           "`\(name)` is STORAGE on the canvas. The input delegate and the tokenizer "
                           + "are the backend's (R16 / Task 24); a canvas-side copy is a second "
                           + "sender of `UITextInputDelegate` notifications waiting to happen.")
        }

        // The typed half — catches a re-introduction under any name at all.
        for child in Mirror(reflecting: v).children {
            XCTAssertFalse(child.value is UITextInputDelegate,
                           "canvas stored property `\(child.label ?? "?")` holds a UITextInputDelegate")
            XCTAssertFalse(child.value is UITextInputTokenizer,
                           "canvas stored property `\(child.label ?? "?")` holds a UITextInputTokenizer")
        }

        // …and the positive: both live on the backend.
        let backendLabels = Set(Mirror(reflecting: backend).children.compactMap(\.label))
        XCTAssertTrue(backendLabels.contains("isAttached"),
                      "control: the Mirror must see the backend's own stored properties — saw "
                      + "\(backendLabels.count) labels")
        XCTAssertTrue(backendLabels.contains("inputDelegate"), "the delegate must be backend STORAGE")
        XCTAssertTrue(backendLabels.contains("tokenizerStorage"), "the tokenizer cache must be backend STORAGE")
    }

    // MARK: - 2. The tokenizer is the backend's, and it is stable

    /// The brief's `test_theTokenizerIsOwnedByTheBackendAndIsStable`. "Stable" is defined against a
    /// backend that CAN detach, so all three windows are stated:
    ///
    ///   * ATTACHED — repeated reads vend the identical `DocumentTokenizer` (the cache).
    ///   * The canvas's `tokenizer` witness and the backend's property are the SAME object — the
    ///     witness is a one-line router (Task 24) and must not mint anything of its own.
    /// The canvas no longer MINTS one either — `legacyMakeTokenizer()` is deleted — but that half is
    /// **not assertable from here**, and the first draft of this test got it wrong in a way worth
    /// recording: it read `XCTAssertFalse(v.responds(to: Selector(("legacyMakeTokenizer"))))`, which
    /// passes whether or not the method exists, because a plain Swift method is not `@objc`. It was RUN
    /// against the unmodified tree and passed, which is how it was caught. The real pin is
    /// `InputBackendSourceBoundaryTests.test_theTokenizerHasExactlyOneConstructionSite` — which the
    /// review then found evadable in ITS first version too (`DocumentTokenizer.init(canvas:)` slipped
    /// past its regex), so it is now a construction scan plus an exact mention allowance, with all
    /// five valid spellings planted and reddened. Two rounds to replace one vacuous assertion.
    ///
    /// Detached/re-attached behaviour is `BackendAttachmentTests`' three tokenizer tests (see the file
    /// header) and is deliberately not restated here.
    func test_theTokenizerIsOwnedByTheBackendAndIsStable() {
        let (v, backend) = realCanvas()

        let first = backend.tokenizer
        let second = backend.tokenizer
        XCTAssertTrue(first is DocumentTokenizer,
                      "the attached read must vend the real tokenizer, not the detached fallback")
        XCTAssertTrue(first === second, "the tokenizer is a stable instance for the attachment, not per-read")
        XCTAssertTrue(v.tokenizer === first,
                      "the canvas's UITextInput `tokenizer` witness is a router onto the backend's "
                      + "instance — it must not mint a second one")
    }

    // MARK: - 3. The coalescing flag

    /// The canvas's `coalescingSelectionNotifications` was a computed forwarder, so a `Mirror` could
    /// never have seen it — which is exactly why this test asserts the flag is BACKEND storage and
    /// that the canvas has no `Bool` of its own under either name.
    ///
    /// Its four canvas-side use sites now write/read `inputBackend.suppressesSelectionNotifications`
    /// directly: `DocumentCanvasView.swift`'s `beginCoalescedSelectionDrag()` (set true),
    /// `endCoalescedSelectionDrag()`'s guard (read) and its clear (set false), and
    /// `DocumentCanvasView+NativeTextCheckingClient.swift`'s `nativeCheckOnSelectionChange()` guard
    /// (read). That count is pinned in
    /// `InputBackendSourceBoundaryTests.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`;
    /// the behaviour those four sites drive is pinned, unchanged, by the four coalescing tests in
    /// `DelegateTraceCharacterizationTests`.
    func test_coalescingFlagIsStoredOnlyInTheBackend() {
        let (v, backend) = realCanvas()
        let labels = canvasLabels(v)

        for name in ["coalescingSelectionNotifications", "suppressesSelectionNotifications"] {
            XCTAssertFalse(labels.contains(name),
                           "`\(name)` is STORAGE on the canvas — a second suppression authority. The "
                           + "flag has TWO backend consumers that must never disagree "
                           + "(`setSelection`'s publish-deferral and `notifyingSelectionChange`'s "
                           + "suppression), which is the whole reason D33 put it on the backend.")
        }

        let backendLabels = Set(Mirror(reflecting: backend).children.compactMap(\.label))
        XCTAssertTrue(backendLabels.contains("suppressesSelectionNotifications"),
                      "the flag must be STORAGE on the backend — it is the one authority")

        // Behavioural: the canvas gesture entry points write the backend's flag, and nothing else.
        XCTAssertFalse(backend.suppressesSelectionNotifications)
        v.beginCoalescedSelectionDrag()
        XCTAssertTrue(backend.suppressesSelectionNotifications,
                      "beginCoalescedSelectionDrag must write the BACKEND's flag")
        v.endCoalescedSelectionDrag()
        XCTAssertFalse(backend.suppressesSelectionNotifications,
                       "endCoalescedSelectionDrag must clear the BACKEND's flag")
    }

    // MARK: - 4. Deviation D14 — undo state does NOT move

    /// Asserted BY NAME, as the brief requires, because the deviation is a decision and a decision
    /// with no test is a comment. Undo registration and coalescing policy belong to the document
    /// client: the canvas is the thing that knows what a "typing run" is, and `undoManagerOverride`
    /// is the seam `UndoBufferIsolationTests` injects through.
    ///
    /// Both directions, like `FloatingCursorStateAuthorityTests`' `floatingScrollLink` non-move: the
    /// five names must be canvas-side, and must NOT have acquired a backend twin.
    func test_undoStateStaysWithTheDocumentClient() {
        let (v, backend) = realCanvas()
        let labels = canvasLabels(v)

        for name in ["openUndoRun", "undoRegistrationCount", "ownUndoManager", "undoManagerOverride"] {
            XCTAssertTrue(labels.contains(name),
                          "D14: `\(name)` stays canvas storage. Undo registration and coalescing "
                          + "policy belong to the document client, not the input backend.")
        }

        let backendLabels = Set(Mirror(reflecting: backend).children.compactMap(\.label))
        for name in ["openUndoRun", "undoRegistrationCount", "ownUndoManager", "undoManagerOverride"] {
            XCTAssertFalse(backendLabels.contains(name),
                           "D14: `\(name)` must NOT have gained a backend copy — two undo-run owners "
                           + "is how a typing run coalesces against the wrong caret.")
        }

        // The test seam D14 exists to protect, exercised rather than merely named.
        let injected = UndoManager()
        v.undoManagerOverride = injected
        XCTAssertTrue(v.effectiveUndoManager === injected,
                      "`undoManagerOverride` is `UndoBufferIsolationTests`' injection seam (D14)")

        // `breakUndoCoalescing()` is the canvas's, and it closes the run the canvas opened.
        v.setCaret(global: v.boxes[0].textStart)
        v.insertText("a")
        XCTAssertNotNil(v.openUndoRun, "control: typing must open a coalescing run on the CANVAS")
        v.breakUndoCoalescing()
        XCTAssertNil(v.openUndoRun)
    }
}
#endif
