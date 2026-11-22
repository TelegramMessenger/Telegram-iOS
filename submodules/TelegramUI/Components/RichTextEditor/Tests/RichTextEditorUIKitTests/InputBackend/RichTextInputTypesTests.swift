#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class RichTextInputTypesTests: XCTestCase {
    func test_positionDefaultsToDownstreamAffinity() {
        XCTAssertEqual(RichTextInputPosition(utf16Offset: 4).affinity, .downstream)
        XCTAssertEqual(RichTextInputPosition.downstream(4), RichTextInputPosition(utf16Offset: 4))
    }

    func test_normalizedRangeOrdersWithoutDestroyingAnchorHeadIdentity() {
        let sel = RichTextCanonicalSelection(anchor: .downstream(10), head: .downstream(3))
        XCTAssertEqual(sel.normalizedRange, NSRange(location: 3, length: 7))
        XCTAssertEqual(sel.anchor.utf16Offset, 10)
        XCTAssertEqual(sel.head.utf16Offset, 3)
    }

    func test_isCollapsedAndIsReversed() {
        XCTAssertTrue(RichTextCanonicalSelection.caret(at: .downstream(2)).isCollapsed)
        XCTAssertFalse(RichTextCanonicalSelection.caret(at: .downstream(2)).isReversed)
        XCTAssertTrue(RichTextCanonicalSelection(anchor: .downstream(9), head: .downstream(1)).isReversed)
    }

    func test_normalizedRangeOfACollapsedSelectionIsZeroLength() {
        XCTAssertEqual(RichTextCanonicalSelection.caret(at: .downstream(5)).normalizedRange,
                       NSRange(location: 5, length: 0))
    }

    /// The spec requires normalization never destroy anchor/head identity (direction is part of
    /// identity). This currently holds only because `Equatable` is compiler-synthesized elementwise
    /// over `(anchor, head)`; nothing else pins it against a future hand-rolled `==` written in terms
    /// of `normalizedRange`, which would silently conflate the two directions.
    func test_reversedSelectionIsNotEqualToItsForwardTwin() {
        XCTAssertNotEqual(
            RichTextCanonicalSelection(anchor: .downstream(1), head: .downstream(5)),
            RichTextCanonicalSelection(anchor: .downstream(5), head: .downstream(1)),
            "direction is part of identity: a reversed selection is NOT equal to its forward twin. If this "
             + "ever fails, someone has hand-written == in terms of normalizedRange, which the spec forbids.")
    }

    func test_presentationInvalidationAllContainsEveryMember() {
        let all = RichTextInputPresentationInvalidation.all
        for member: RichTextInputPresentationInvalidation in
            [.caret, .selection, .handles, .markedText, .annotations, .spelling, .layout, .editMenu] {
            XCTAssertTrue(all.contains(member))
        }
    }

    /// The `.all` membership check above can't catch two options sharing a bit (e.g. a copy-paste `1
    /// << 4` typo on `.spelling`): `.all` would still "contain" both members, since their shared bit is
    /// present. This asserts the 8 raw values are pairwise distinct, so a collision fails here even
    /// though the membership check above would stay green.
    func test_presentationInvalidationOptionsHaveDistinctBits() {
        let rawValues: [UInt] = [
            RichTextInputPresentationInvalidation.caret.rawValue,
            RichTextInputPresentationInvalidation.selection.rawValue,
            RichTextInputPresentationInvalidation.handles.rawValue,
            RichTextInputPresentationInvalidation.markedText.rawValue,
            RichTextInputPresentationInvalidation.annotations.rawValue,
            RichTextInputPresentationInvalidation.spelling.rawValue,
            RichTextInputPresentationInvalidation.layout.rawValue,
            RichTextInputPresentationInvalidation.editMenu.rawValue,
        ]
        XCTAssertEqual(Set(rawValues).count, rawValues.count,
                       "two presentation-invalidation options share a bit; each must be independently representable")
    }

    func test_legacyUnrestrictedEditPolicyPermitsEverything() {
        let p = RichTextInputEditPolicy.legacyUnrestricted
        XCTAssertTrue(p.isEditable && p.isSelectable && p.allowsRichText
                      && p.allowsPaste && p.allowsDictation && p.allowsWritingTools)
    }

    func test_stateSnapshotEquality() {
        let a = RichTextInputStateSnapshot(documentRevision: 3,
                                           selection: .caret(at: .downstream(1)),
                                           markedRange: nil, isComposing: false)
        let b = RichTextInputStateSnapshot(documentRevision: 3,
                                           selection: .caret(at: .downstream(1)),
                                           markedRange: nil, isComposing: false)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, RichTextInputStateSnapshot(documentRevision: 4,
                                                        selection: .caret(at: .downstream(1)),
                                                        markedRange: nil, isComposing: false))
    }

    func test_preparedMutationTokensAreDistinct() {
        let a = RichTextInputPreparedMutation(token: UUID(), expectedRevision: 1,
                                              contentWillChange: true, selectionWillChange: true)
        let b = RichTextInputPreparedMutation(token: UUID(), expectedRevision: 1,
                                              contentWillChange: true, selectionWillChange: true)
        XCTAssertNotEqual(a, b)
    }

    func test_mutationResultCarriesTheLegacyConservativeFlag() {
        let r = RichTextInputMutationResult(disposition: .applied, revision: 2,
                                            selection: .caret(at: .downstream(1)), markedRange: nil,
                                            affectedRange: NSRange(location: 0, length: 1),
                                            contentChanged: true, selectionChanged: true,
                                            legacyConservativePreparation: true)
        XCTAssertTrue(r.legacyConservativePreparation)
        XCTAssertEqual(r.disposition, .applied)
    }

    func test_lineIDComparesByBlockAndRegion() {
        let a = RichTextInputLineID(blockID: BlockID("p0"), regionIndex: 0)
        XCTAssertEqual(a, RichTextInputLineID(blockID: BlockID("p0"), regionIndex: 0))
        XCTAssertNotEqual(a, RichTextInputLineID(blockID: BlockID("p0"), regionIndex: 1))
    }

    func test_rejectionDispositionEquality() {
        XCTAssertEqual(RichTextInputMutationResult.Disposition.rejected(.notEditable),
                       .rejected(.notEditable))
        XCTAssertNotEqual(RichTextInputMutationResult.Disposition.rejected(.notEditable),
                          .rejected(.invalidRange))
    }

    func test_interactionStateCarriesTheActiveEndpoint() {
        XCTAssertEqual(RichTextInputInteractionState.selecting(activeEndpoint: .head),
                       .selecting(activeEndpoint: .head))
        XCTAssertNotEqual(RichTextInputInteractionState.selecting(activeEndpoint: .head),
                          .selecting(activeEndpoint: .anchor))
    }
}
#endif
