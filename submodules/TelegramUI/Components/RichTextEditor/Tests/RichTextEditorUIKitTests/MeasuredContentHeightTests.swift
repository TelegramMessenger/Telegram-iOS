#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class MeasuredContentHeightTests: XCTestCase {
    private func composerConfigure(_ e: RichTextEditorView) {
        e.contentPageMargin = 0.0
        e.minimumContentHeight = 0.0
        e.blockVerticalInset = 0.0
    }

    private func liveHeight(lineCount: Int, width: CGFloat) -> CGFloat {
        let e = RichTextEditorView()
        // Frame the reference editor exactly like the probe (and the real composer field on screen): the
        // content-height measure reads each box's laid-out top/bottom inset (set by the layout pass, which only
        // runs when framed), so an UNFRAMED editor measures too tall (default 8pt insets instead of the
        // composer's 0). This mirrors `RichTextEditorView.measuredContentHeight`'s probe framing.
        e.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 100.0))
        composerConfigure(e)
        e.document = Document(blocks: (0..<lineCount).map { _ in
            Block.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: [TextRun(text: "A")]))
        })
        return e.height(forWidth: width)
    }

    func test_measuredContentHeight_matchesLiveEditor_forThreeBodyLines() {
        let width: CGFloat = 240.0
        let expected = liveHeight(lineCount: 3, width: width)
        let measured = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, configure: composerConfigure)
        XCTAssertEqual(measured, expected, accuracy: 0.5)
    }

    func test_measuredContentHeight_isMonotonicInLineCount() {
        let width: CGFloat = 240.0
        let h1 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 1, configure: composerConfigure)
        let h3 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, configure: composerConfigure)
        XCTAssertGreaterThan(h3, h1)
        // Three lines is about three single lines tall (natural metrics, 0 inter-paragraph gap).
        XCTAssertEqual(h3, h1 * 3.0, accuracy: h1)
    }

    func test_measuredContentHeight_lineCountFloorsAtOne() {
        let width: CGFloat = 240.0
        let h0 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 0, configure: composerConfigure)
        let h1 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 1, configure: composerConfigure)
        XCTAssertEqual(h0, h1, accuracy: 0.5)
    }

    func test_measuredContentHeight_addsVerticalContentMargins() {
        let width: CGFloat = 240.0
        let bare = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, configure: composerConfigure)
        let margins = UIEdgeInsets(top: 4.5, left: 0.0, bottom: 4.5, right: 0.0)
        let margined = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, contentMargins: margins, configure: composerConfigure)
        // The vertical content inset is added to the height (mirroring the live textHeightForWidth), so the probe
        // equals the real field height. A horizontal-only margin would not change a short (non-wrapping) probe.
        XCTAssertEqual(margined, bare + margins.top + margins.bottom, accuracy: 0.5)
    }

    func test_measuredContentHeight_withMargins_matchesLiveEditor() {
        let width: CGFloat = 240.0
        let margins = UIEdgeInsets(top: 4.5, left: 0.0, bottom: 4.5, right: 0.0)
        let e = RichTextEditorView()
        e.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 100.0))   // framed like the real composer field (see liveHeight)
        composerConfigure(e)
        e.document = Document(blocks: (0..<3).map { _ in
            Block.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: [TextRun(text: "A")]))
        })
        // The probe must equal what the live editor reports when measured with the SAME margins — this is the
        // property the chat composer relies on (probe == live textHeightForWidth at 3 lines).
        let expected = e.height(forWidth: width, contentMargins: margins)
        let measured = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, contentMargins: margins, configure: composerConfigure)
        XCTAssertEqual(measured, expected, accuracy: 0.5)
    }
}
#endif
