import XCTest
import UIKit
@testable import ChatRichTextEditorComposer

/// **What the panel measures the field with must be what the field gets.**
///
/// Reported from the device: a draft that wraps to seven lines sometimes opens as a six-line field
/// with the text scrolling inside it, although there was room for seven. Focusing the field fixes it,
/// and sometimes it is right to begin with.
///
/// That is a measurement made against the wrong column. The panel measures the field's height in
/// `calculateTextFieldMetrics` and applies the real insets afterwards, in the same pass, so the
/// measure ran against whatever margins a PREVIOUS pass had left behind. Measured in the running app
/// while opening a chat:
///
///     ZZMEASURE width=281.0 rightInsetArg=88.0 margins=(4.5, 0.0, 5.5, 56.0)
///
/// The panel says "the right inset this pass is 88" and the measure reserved 56 — 46pt of column the
/// text would not get. Text measured in a column wider than it is laid out in wraps into fewer lines,
/// and one line short is the report. The intermittency is the same fact: reopening a chat whose
/// previous margins happened to match already measured correctly.
///
/// The `rightInset` argument was already on the method; it was recorded for the next `update(...)`
/// and never used in the measurement it was passed to.
final class ComposerFieldHeightMeasureTests: XCTestCase {
    private let panelInset = UIEdgeInsets(top: 4.5, left: 0.0, bottom: 5.5, right: 42.0)

    /// **The measure uses the inset it is given, not the one left over from last time.** The numbers
    /// are the ones read out of the running app.
    func test_theMeasureAppliesThisPassesRightInset() {
        let stale = RichTextEditorChatInputNode.storedMargins(forPanelInset: panelInset)
        XCTAssertEqual(stale.right, 56.0, accuracy: 0.01, "the fixture is not the measured one")

        let measured = RichTextEditorChatInputNode.measurementMargins(applying: 88.0, to: stale)

        XCTAssertEqual(measured.right, 102.0, accuracy: 0.01,
                       "the measure reserved the stale 56 rather than this pass's 88")
    }

    /// **Measure and layout must agree about the column**, which is the invariant the defect broke.
    ///
    /// This one CANNOT catch the staleness, by construction: it feeds a right inset that already
    /// matches the tracked margins, which is exactly the case where the defect did not show — the
    /// "sometimes it opens fine" half of the report. It guards the pair of transforms instead.
    /// Asserted by deriving both from the same panel inset: if someone changes one transform without
    /// the other, a draft measures against a column it will not be laid out in and the field is built
    /// the wrong height again.
    func test_whatIsMeasuredIsWhatTheFieldGets() {
        let applied = RichTextEditorChatInputNode.storedMargins(forPanelInset: panelInset)
        let measured = RichTextEditorChatInputNode.measurementMargins(applying: panelInset.right,
                                                                     to: applied)
        XCTAssertEqual(measured.right, applied.right, accuracy: 0.01,
                       "the field is measured against a different column from the one it is given")
    }

    /// And the intermittency is gone at the source: the answer does not depend on what the previous
    /// pass happened to leave behind.
    func test_theMeasureDoesNotDependOnThePreviousPassesMargins() {
        let afterANarrowPass = RichTextEditorChatInputNode.measurementMargins(
            applying: 88.0,
            to: RichTextEditorChatInputNode.storedMargins(forPanelInset: panelInset))
        let afterAMatchingPass = RichTextEditorChatInputNode.measurementMargins(
            applying: 88.0,
            to: RichTextEditorChatInputNode.storedMargins(
                forPanelInset: UIEdgeInsets(top: 4.5, left: 0.0, bottom: 5.5, right: 88.0)))

        XCTAssertEqual(afterANarrowPass.right, afterAMatchingPass.right, accuracy: 0.01,
                       "the same pass measured two different columns depending on what preceded it")
    }

    /// The vertical half is untouched by any of this and must stay that way: the pair is deliberately
    /// lopsided (4.5 / 5.5) so the total is even, and a measure that "tidied" it would change every
    /// field height by a point.
    func test_theVerticalMarginsAreCarriedThroughUnchanged() {
        let measured = RichTextEditorChatInputNode.measurementMargins(
            applying: 88.0,
            to: RichTextEditorChatInputNode.storedMargins(forPanelInset: panelInset))
        XCTAssertEqual(measured.top, 4.5, accuracy: 0.01)
        XCTAssertEqual(measured.bottom, 5.5, accuracy: 0.01)
    }
}
