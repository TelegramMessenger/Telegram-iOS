#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Family 4 (Task C7) semantic tests over the two-phase (prepare/commit) transaction the storage
/// façade drives — distinct from `IDBackendIntentLatchTests`, which pins the INTENT the latch
/// recovers; this file pins the TRANSACTION shape itself (exactly-once commit, terminal-rejection
/// silence, and that the canonical selection reaches the mutation).
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily4Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// Would fail if `replaceCharactersInRange:withString:` were deleted from
    /// `TGRichTextInputDecTextStorageFacade`: `NSTextStorage`'s own abstract implementation of
    /// that primitive raises `NSInternalInconsistencyException` ("only defined for abstract
    /// class") rather than reaching the bridge at all, so `h.document.receivedMutations` — which
    /// only grows from INSIDE the override's call into `self.bridge` — would stay empty and this
    /// assertion would fail (or the process would trap first). It would likewise fail if the
    /// override existed but never called `self.mirror.replaceCharactersInRange:withString:` on an
    /// applied transaction, since `h.storageFacade.string` reads through `mirror`.
    func test_insertText_commitsExactlyOnce_andPublishesApplied() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let publishedBefore = h.lifecycle.publishedStates.count
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
        XCTAssertEqual(h.document.receivedMutations.count, 1)
        XCTAssertEqual(h.document.consumedTokens.count, 1,
                       "the prepared token must be committed exactly once")
        XCTAssertFalse(h.document.sawDoubleCommit)
        // Task R3: the mirror is no longer created-and-left-empty — `attach(to:)` seeds it from
        // the fake host's real content ("Alpha\nBeta", `makeIDFakeClientHarness`'s default
        // paragraphs) before this test body ever runs. Inserting "a" at {0,0} therefore PREPENDS
        // onto that seeded content, not onto an empty string. The assertion's ORIGINAL "a" baked
        // in the pre-R3 bug (the mirror started empty because nothing ever seeded it) as if it
        // were the expected value; this is the corrected one, pinning the same invariant the
        // comment above already states — "an applied transaction must mutate the read-model
        // mirror" — against the now-correct starting content.
        XCTAssertEqual(h.storageFacade.string, "aAlpha\nBeta",
                       "an applied transaction must mutate the read-model mirror")
        XCTAssertEqual(h.lifecycle.publishedStates.count, publishedBefore + 1,
                       "an applied transaction must publish exactly one new state")
    }

    /// A terminal rejection must produce NO mirror mutation, NO new published state, and exactly
    /// the one `backendDidRejectMutation` notification — never a will/did-notification bracket
    /// (there is nothing prepared to bracket). Would fail if the override applied the mirror
    /// mutation unconditionally rather than gating it on `applied`.
    func test_terminalRejection_emitsNoDelegateNotifications_andNoPublication() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let publishedBefore = h.lifecycle.publishedStates.count
        h.document.nextPreparationRejection = .notEditable
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
        // Task R3: same correction as `test_insertText_commitsExactlyOnce_andPublishesApplied`
        // above — the mirror starts seeded with the fake host's real content ("Alpha\nBeta"), not
        // empty, so "a rejected transaction must not mutate the mirror" now means "must still read
        // Alpha\nBeta", not "".
        XCTAssertEqual(h.storageFacade.string, "Alpha\nBeta", "a rejected transaction must not mutate the mirror")
        XCTAssertEqual(h.lifecycle.publishedStates.count, publishedBefore,
                       "a terminal rejection must publish nothing")
        XCTAssertEqual(h.lifecycle.lastRejectionReason, .notEditable)
        guard case .insertText = h.lifecycle.lastRejectedMutation else {
            return XCTFail("expected the rejected mutation to be recorded")
        }
        XCTAssertEqual(h.document.consumedTokens.count, 0,
                       "a terminal preparation issues no token, so nothing can be committed")
    }

    /// `FakeInputDocumentClient.finish()` (called from every suite's `tearDown`, and here a second
    /// time explicitly so the assertion runs inside the test body) is the seam plan's default
    /// "the prepared token is consumed exactly once before returning to the run loop" check.
    func test_preparedTokenIsConsumedExactlyOnce() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 0, length: 0), with: "a")
        h.document.finish()
        XCTAssertFalse(h.document.sawDoubleCommit, "the prepared token must never be committed twice")
        XCTAssertFalse(h.document.sawUnconsumedPreparation,
                       "the prepared token must be consumed before returning to the run loop")
    }

    /// The mutation the bridge constructs must carry the backend's CURRENT canonical selection
    /// (`backend.state.selection`), not a fabricated or stale one — the whole point of routing
    /// every replace through `prepareAndCommitReplacement(in:text:intent:expectedRevision:outOutcome:)`
    /// rather than reconstructing a selection from the raw `NSRange` UIKit hands the façade.
    func test_replaceOverASelection_carriesTheCanonicalSelection() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5)),
                               reason: .programmatic)
        h.storageFacade.currentIntent = .insertText
        h.storageFacade.replaceCharacters(in: NSRange(location: 2, length: 3), with: "Z")
        guard case .insertText(let text, let replacing, _) = h.document.receivedMutations.last,
              text.string == "Z",
              replacing == RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5)) else {
            return XCTFail("got \(String(describing: h.document.receivedMutations.last))")
        }
    }
}
#endif
