#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A `BlockBox`'s text height must equal InstantPage V2's item height. With a pinned line box TextKit
/// reports `n * pitch`; V2 reports `ascender + (n-1) * pitch + |descender|`. The difference is a
/// constant per paragraph — `trailingHeightCorrection` — so it is applied once at the block level
/// rather than being folded into the paragraph style, where it would scale with the line count.
final class BlockBoxHeightParityTests: XCTestCase {
    private func box(_ text: String, style: ParagraphStyleName = .body, width: CGFloat = 300) -> BlockBox {
        let mapper = AttributedStringMapper(styleSheet: .default)
        let paragraph = ParagraphBlock(id: BlockID(UUID().uuidString), style: style,
                                       runs: text.isEmpty ? [] : [TextRun(text: text)])
        let b = BlockBox(paragraph: paragraph, mapper: mapper, width: width)
        b.topInset = 0
        b.bottomInset = 0
        b.setWidth(width)
        return b
    }

    private func expectedV2Height(_ style: ParagraphStyleName, lineCount: Int) -> CGFloat {
        let sheet = StyleSheet.default
        let font = sheet.font(for: style, attributes: .plain)
        let factor = sheet.metrics.spec(for: style).lineSpacingFactor
        return RichTextRenderMetrics.textHeight(font, factor: factor, lineCount: lineCount)
    }

    /// The number of laid-out lines, derived from the layout rather than assuming break positions.
    private func lineCount(_ b: BlockBox) -> Int {
        var count = 1
        var lastY = b.layout.caretRect(atOffset: 0).minY
        for i in 1...b.length {
            let y = b.layout.caretRect(atOffset: i).minY
            if y > lastY + 0.5 { count += 1; lastY = y }
        }
        return count
    }

    /// A single body line measures ascender + |descender| — NOT one pitch, which is larger.
    func test_singleLineBodyHeight_matchesV2() {
        XCTAssertEqual(box("Hello").height, expectedV2Height(.body, lineCount: 1), accuracy: 0.5)
    }

    /// A single heading line, whose pitch differs from body's, so the correction differs too.
    func test_singleLineHeadingHeight_matchesV2() {
        XCTAssertEqual(box("Hello", style: .heading1).height,
                       expectedV2Height(.heading1, lineCount: 1), accuracy: 0.5)
    }

    func test_singleLineCaptionHeight_matchesV2() {
        XCTAssertEqual(box("Hello", style: .caption).height,
                       expectedV2Height(.caption, lineCount: 1), accuracy: 0.5)
    }

    /// Wrapped body lines: each extra line adds exactly one pitch.
    func test_wrappedBodyHeight_matchesV2() {
        let b = box("one two three four five six seven eight nine ten eleven twelve", width: 130)
        let n = lineCount(b)
        XCTAssertGreaterThan(n, 1, "the sample must actually wrap at this width")
        XCTAssertEqual(b.height, expectedV2Height(.body, lineCount: n), accuracy: 0.5)
    }

    /// `measuredHeight(forWidth:)` is the stateless analogue and must agree with the laid-out height,
    /// or a host sizes its field wrong on the first pass.
    func test_measuredHeight_agreesWithLaidOutHeight() {
        let b = box("one two three four five six seven eight nine ten eleven twelve", width: 130)
        XCTAssertEqual(b.measuredHeight(forWidth: 130), b.height, accuracy: 0.5)
    }

    /// An EMPTY paragraph reserves exactly V2's one-line height, so a document does not change height
    /// when its first character is typed.
    func test_emptyParagraphReservesOneV2Line() {
        XCTAssertEqual(box("").height, expectedV2Height(.body, lineCount: 1), accuracy: 0.5)
    }

    /// The empty-paragraph list marker must land on the SAME baseline the first typed glyph will use,
    /// which under this model is simply the font's ascender.
    func test_emptyItemListMarkerBaseline_matchesTheFirstTypedGlyph() {
        let font = StyleSheet.default.font(for: .body, attributes: .plain)
        let empty = box("")
        let typed = box("A")
        XCTAssertEqual(empty.listMarkerBaselineFromTop(markerFont: font),
                       typed.listMarkerBaselineFromTop(markerFont: font), accuracy: 0.5)
        XCTAssertEqual(empty.listMarkerBaselineFromTop(markerFont: font),
                       RichTextRenderMetrics.firstBaselineFromTop(font), accuracy: 0.5)
    }
}
#endif
