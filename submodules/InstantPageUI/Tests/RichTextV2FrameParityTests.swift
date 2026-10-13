import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// End-to-end parity: the same document, laid out by the editor, must put its text where the
/// InstantPage V2 renderer's own primitives say it goes.
///
/// `RichTextV2MetricsParityTests` pins the PRIMITIVES in isolation (the line formulas against
/// `layoutTextItem`, the rule table against `spacingBetweenBlocks`). This pins the COMPOSITION: that
/// `BlockStack` accumulates gaps and block heights into the same running origin. Both could be right
/// individually while the document still drifts — a missing ceiling, a gap counted twice, an edge gap
/// omitted.
///
/// **Why it composes the expectation rather than calling `layoutInstantPageV2`:** that entry point
/// requires a `PresentationStrings`, which cannot be built in a test bundle — the default instance
/// force-unwraps a `Localizable.strings` lookup against the app bundle, and a hand-made one trips an
/// assertion inside `PresentationStrings` on an empty dictionary. So the expectation is built from the
/// renderer's own two measuring functions instead, which take no strings.
///
/// **Limitation, stated rather than hidden:** this therefore does not exercise `layoutBlockSequence`
/// itself, so renderer-side sequence behaviour beyond "sum the gaps and the item heights" is not
/// covered here. It is still a genuine cross-check: the expectation runs entirely through renderer code
/// and shares no path with the editor's `BlockStack`.
@available(iOS 13.0, *)
final class RichTextV2FrameParityTests: XCTestCase {
    private let width: CGFloat = 320.0

    /// One corpus entry: the editor's block, and the renderer's view of the same block.
    private struct Sample {
        let block: Block
        let pageBlock: InstantPageBlock
        let style: ParagraphStyleName
        let text: String
    }

    private func para(_ text: String, _ style: ParagraphStyleName = .body) -> Sample {
        let block = Block.paragraph(ParagraphBlock(id: BlockID(UUID().uuidString), style: style,
                                                  runs: [TextRun(text: text)]))
        let pageBlock: InstantPageBlock
        switch style {
        case .body, .caption: pageBlock = .paragraph(.plain(text))
        case .heading1: pageBlock = .heading(text: .plain(text), level: 1)
        case .heading2: pageBlock = .heading(text: .plain(text), level: 2)
        case .heading3: pageBlock = .heading(text: .plain(text), level: 3)
        case .heading4: pageBlock = .heading(text: .plain(text), level: 4)
        case .heading5: pageBlock = .heading(text: .plain(text), level: 5)
        case .heading6: pageBlock = .heading(text: .plain(text), level: 6)
        case .pullQuote: pageBlock = .pullQuote(text: .plain(text), caption: .empty)
        }
        return Sample(block: block, pageBlock: pageBlock, style: style, text: text)
    }

    /// The height `layoutTextItem` measures for this sample — the renderer's own measurement, including
    /// its `ceil`.
    private func rendererItemHeight(_ sample: Sample) -> CGFloat {
        let metrics = RichTextRenderMetrics.default
        let sheet = StyleSheet.default
        let spec = metrics.spec(for: sample.style)
        let font = sheet.font(for: sample.style, attributes: .plain)
        let string = NSMutableAttributedString(string: sample.text)
        string.addAttributes([
            .font: font,
            NSAttributedString.Key(rawValue: InstantPageLineSpacingFactorAttribute): spec.lineSpacingFactor as NSNumber
        ], range: NSRange(location: 0, length: string.length))
        let (_, _, size) = layoutTextItem(string, boundingWidth: width, offset: .zero)
        return size.height
    }

    /// Where the renderer's primitives put each sample's text, and the sequence's total height.
    private func expectedGeometry(_ samples: [Sample]) -> (origins: [CGFloat], height: CGFloat) {
        let ipMetrics = InstantPageMetrics.unscaled
        func gap(_ upper: InstantPageBlock?, _ lower: InstantPageBlock?) -> CGFloat {
            return spacingBetweenBlocks(upper: upper, lower: lower, kind: .topLevel, metrics: ipMetrics)
        }
        var origins: [CGFloat] = []
        var y = gap(nil, samples.first?.pageBlock)
        for (i, sample) in samples.enumerated() {
            origins.append(y)
            y += rendererItemHeight(sample)
            if i + 1 < samples.count {
                y += gap(sample.pageBlock, samples[i + 1].pageBlock)
            }
        }
        y += gap(samples.last?.pageBlock, nil)
        return (origins, y)
    }

    /// Where the editor actually put it.
    private func editorGeometry(_ samples: [Sample]) -> (origins: [CGFloat], height: CGFloat) {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: width, height: 4000))
        editor.contentPageMargin = 0
        editor.minimumContentHeight = 0
        editor.renderMetrics = .default
        editor.document = Document(blocks: samples.map { $0.block })
        _ = editor.update(size: CGSize(width: width, height: 4000), insets: .zero)
        let snapshot = editor.layoutSnapshot()
        return (snapshot.textOrigins.map { $0.y }, snapshot.contentHeight)
    }

    private func assertParity(_ samples: [Sample], _ label: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expected = expectedGeometry(samples)
        let actual = editorGeometry(samples)
        XCTAssertEqual(actual.origins.count, expected.origins.count, "\(label): block count",
                       file: file, line: line)
        guard actual.origins.count == expected.origins.count else { return }
        for (i, (a, e)) in zip(actual.origins, expected.origins).enumerated() {
            XCTAssertEqual(a, e, accuracy: 0.01, "\(label): text origin \(i)", file: file, line: line)
        }
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.01, "\(label): content height",
                       file: file, line: line)
    }

    func test_singleBodyParagraph() {
        assertParity([para("Hello there")], "single paragraph")
    }

    func test_twoBodyParagraphs() {
        assertParity([para("First"), para("Second")], "two paragraphs")
    }

    func test_headingThenBody() {
        assertParity([para("Title", .heading1), para("Body text")], "heading then body")
    }

    func test_theWholeHeadingLadder() {
        assertParity([para("H1", .heading1), para("H2", .heading2), para("H3", .heading3),
                      para("H4", .heading4), para("H5", .heading5), para("H6", .heading6),
                      para("Body")], "heading ladder")
    }

    /// Wrapped text, asserted unconditionally: the Task-0 spike measured 50/50 line-break agreement
    /// between TextKit and `CTTypesetterSuggestLineBreak`, so the two sides break identically.
    func test_wrappedParagraphs() {
        assertParity([
            para("The quick brown fox jumps over the lazy dog and keeps going well past the margin."),
            para("A second paragraph that also wraps across more than one line at this width.")
        ], "wrapped paragraphs")
    }

    /// The case a per-block rounding error would only reveal at length.
    func test_manyParagraphs_doNotDriftCumulatively() {
        assertParity((0 ..< 12).map { para("Paragraph number \($0) with enough text to be real.") },
                     "twelve paragraphs")
    }

    func test_alternatingHeadingsAndBody_doNotDriftCumulatively() {
        var samples: [Sample] = []
        for i in 0 ..< 6 {
            samples.append(para("Section \(i)", .heading2))
            samples.append(para("Body text under section \(i), long enough to wrap at this width."))
        }
        assertParity(samples, "alternating headings and body")
    }
}
