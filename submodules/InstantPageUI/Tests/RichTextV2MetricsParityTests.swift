import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The drift guard between the editor and the InstantPage V2 renderer.
///
/// `RichTextRenderMetrics` restates V2's line geometry as formulas, and `richTextSpacingBetweenBlocks`
/// restates its vertical rhythm. Both are transcriptions, and a transcription rots silently — nothing
/// in either module references the other at compile time. These tests call the RENDERER's own
/// functions and assert the editor's agree, so a change on either side that breaks parity fails here.
final class RichTextV2MetricsParityTests: XCTestCase {

    /// A string carrying the font and line-spacing factor `layoutTextItem` reads, exactly as the
    /// renderer's own layout paths build it.
    private func rendererString(_ text: String, font: UIFont, factor: CGFloat) -> NSAttributedString {
        let s = NSMutableAttributedString(string: text)
        s.addAttributes([
            .font: font,
            NSAttributedString.Key(rawValue: InstantPageLineSpacingFactorAttribute): factor as NSNumber
        ], range: NSRange(location: 0, length: s.length))
        return s
    }

    // MARK: Line geometry

    /// A single line, laid out by the renderer's own `layoutTextItem`, must measure what
    /// `RichTextRenderMetrics.textHeight` says it will.
    func test_singleLineHeight_matchesLayoutTextItem() {
        let metrics = RichTextRenderMetrics.default
        let sheet = StyleSheet.default
        for style in [ParagraphStyleName.heading1, .heading2, .heading3, .heading4,
                      .heading5, .heading6, .body, .caption] {
            let spec = metrics.spec(for: style)
            let font = sheet.font(for: style, attributes: .plain)
            let (_, _, size) = layoutTextItem(rendererString("Qwefqwef", font: font, factor: spec.lineSpacingFactor),
                                              boundingWidth: 1000, offset: .zero)
            XCTAssertEqual(size.height,
                           RichTextRenderMetrics.textHeight(font, factor: spec.lineSpacingFactor, lineCount: 1),
                           accuracy: 0.01, "single-line height for \(style)")
        }
    }

    /// Multi-line: the renderer's per-line baselines sit exactly one `linePitch` apart, its first
    /// baseline at `firstBaselineFromTop`, and its total height at `textHeight`.
    func test_linePitchFirstBaselineAndWrappedHeight_matchLayoutTextItem() throws {
        let metrics = RichTextRenderMetrics.default
        let sheet = StyleSheet.default
        for style in [ParagraphStyleName.body, .caption, .heading1, .heading6] {
            let spec = metrics.spec(for: style)
            let font = sheet.font(for: style, attributes: .plain)
            let string = rendererString("one two three four five six seven eight nine ten",
                                        font: font, factor: spec.lineSpacingFactor)
            let (item, _, size) = layoutTextItem(string, boundingWidth: 140, offset: .zero)
            let lines = try XCTUnwrap(item).lines
            XCTAssertGreaterThan(lines.count, 1, "the sample must wrap for \(style)")

            let expectedPitch = RichTextRenderMetrics.linePitch(font, factor: spec.lineSpacingFactor)
            for i in 1 ..< lines.count {
                XCTAssertEqual(lines[i].frame.minY - lines[i - 1].frame.minY, expectedPitch,
                               accuracy: 0.01, "pitch between lines \(i - 1) and \(i) for \(style)")
            }
            // A line's frame spans from the box top to its baseline, so maxY IS the baseline.
            XCTAssertEqual(lines[0].frame.maxY, RichTextRenderMetrics.firstBaselineFromTop(font),
                           accuracy: 0.01, "first baseline for \(style)")
            XCTAssertEqual(size.height,
                           RichTextRenderMetrics.textHeight(font, factor: spec.lineSpacingFactor,
                                                            lineCount: lines.count),
                           accuracy: 0.01, "wrapped height for \(style)")
        }
    }

    // MARK: Font resolution

    /// The editor must resolve the SAME `UIFont` the renderer does, since every line formula is a
    /// function of `ascender`/`descender`. Compared by face name and metrics, not by identity.
    ///
    /// The style-stack pushes mirror the renderer's `setupStyleStack(_:theme:attributes:)`, which is
    /// `private` and so cannot be called from here — only the font-determining subset matters.
    func test_fontResolution_matchesTheRenderersStyleStack() throws {
        let theme = InstantPageTheme.chatMessageGeometryTheme()
        var sheet = StyleSheet.default
        sheet.metrics = theme.richTextRenderMetrics()

        func rendererFont(_ attributes: InstantPageTextAttributes) throws -> UIFont {
            let stack = InstantPageTextStyleStack()
            switch attributes.font.style {
            case .sans:      stack.push(.fontSerif(false))
            case .serif:     stack.push(.fontSerif(true))
            case .monospace: stack.push(.fontFixed(true))
            }
            switch attributes.font.weight {
            case .regular: break
            case .medium:  stack.push(.medium)
            case .semibold: stack.push(.semibold)
            }
            stack.push(.fontSize(attributes.font.size))
            return try XCTUnwrap(stack.textAttributes()[NSAttributedString.Key.font] as? UIFont)
        }

        var cases: [(ParagraphStyleName, InstantPageTextAttributes)] = [
            (.body, theme.textCategories.paragraph),
            (.caption, theme.textCategories.caption)
        ]
        for level in 1...6 {
            let style: ParagraphStyleName = [.heading1, .heading2, .heading3, .heading4, .heading5, .heading6][level - 1]
            cases.append((style, theme.headingTextAttributes(level: Int32(level), link: false)))
        }

        for (style, attributes) in cases {
            let expected = try rendererFont(attributes)
            let actual = sheet.font(for: style, attributes: .plain)
            XCTAssertEqual(actual.fontName, expected.fontName, "\(style) face")
            XCTAssertEqual(actual.pointSize, expected.pointSize, "\(style) size")
            XCTAssertEqual(actual.ascender, expected.ascender, accuracy: 0.001, "\(style) ascender")
            XCTAssertEqual(actual.descender, expected.descender, accuracy: 0.001, "\(style) descender")
        }
    }

    // MARK: The rule table, exhaustively

    /// A representative `InstantPageBlock` for each editor-producible spacing kind. The pairing is the
    /// point: it asserts the editor's classification means what the renderer thinks it does.
    private static func kindPairs() -> [(RichTextBlockSpacingKind, InstantPageBlock)] {
        let bareCaption = InstantPageCaption(text: .empty, credit: .empty)
        let creditedCaption = InstantPageCaption(text: .empty, credit: .plain("c"))
        // `EngineMedia.Id`, not `MediaId`: TelegramCore does not re-export Postbox, so the raw Postbox
        // spelling is out of scope here (see the engine typealias cheat sheet in the root CLAUDE.md).
        let mediaId = EngineMedia.Id(namespace: 0, id: 1)
        return [
            (.paragraph, .paragraph(.plain("x"))),
            (.heading, .heading(text: .plain("x"), level: 1)),
            (.list, .list(items: [], ordered: false)),
            (.preformatted, .preformatted(text: .plain("x"), language: nil)),
            (.blockQuote, .blockQuote(blocks: [], caption: .empty, collapsed: false)),
            (.pullQuote, .pullQuote(text: .plain("x"), caption: .empty)),
            (.details, .details(title: .plain("x"), blocks: [], expanded: false)),
            (.table, .table(title: .empty, rows: [], bordered: false, striped: false, compact: false)),
            (.formula, .formula(latex: "x")),
            (.media(hasCredit: false, isRawMedia: true),
             .image(id: mediaId, caption: bareCaption, url: nil, webpageId: nil, spoiler: false)),
            (.media(hasCredit: true, isRawMedia: true),
             .image(id: mediaId, caption: creditedCaption, url: nil, webpageId: nil, spoiler: false)),
            (.media(hasCredit: false, isRawMedia: false),
             .audio(id: mediaId, caption: bareCaption))
        ]
    }

    /// EVERY pair, plus both edges. A spot check cannot cover this: the renderer's function has ten
    /// arms whose ORDER matters, so any single wrong cell is a real bug.
    func test_everyBlockPairing_matchesSpacingBetweenBlocks() {
        let metrics = RichTextRenderMetrics.default
        let ipMetrics = InstantPageMetrics.unscaled
        let pairs = Self.kindPairs()

        for (upperKind, upperBlock) in pairs {
            for (lowerKind, lowerBlock) in pairs {
                XCTAssertEqual(
                    richTextSpacingBetweenBlocks(upper: upperKind, lower: lowerKind,
                                                 kind: .topLevel, metrics: metrics),
                    spacingBetweenBlocks(upper: upperBlock, lower: lowerBlock,
                                         kind: .topLevel, metrics: ipMetrics),
                    accuracy: 0.001, "\(upperKind) -> \(lowerKind)")
            }
        }

        for (kind, block) in pairs {
            XCTAssertEqual(
                richTextSpacingBetweenBlocks(upper: nil, lower: kind, kind: .topLevel, metrics: metrics),
                spacingBetweenBlocks(upper: nil, lower: block, kind: .topLevel, metrics: ipMetrics),
                accuracy: 0.001, "leading edge for \(kind)")
            XCTAssertEqual(
                richTextSpacingBetweenBlocks(upper: kind, lower: nil, kind: .topLevel, metrics: metrics),
                spacingBetweenBlocks(upper: block, lower: nil, kind: .topLevel, metrics: ipMetrics),
                accuracy: 0.001, "trailing edge for \(kind)")
        }
    }

    /// The same table inside a list sequence, where every pairing collapses.
    func test_everyBlockPairing_matchesInsideAListSequence() {
        let metrics = RichTextRenderMetrics.default
        let ipMetrics = InstantPageMetrics.unscaled
        for (upperKind, upperBlock) in Self.kindPairs() {
            for (lowerKind, lowerBlock) in Self.kindPairs() {
                XCTAssertEqual(
                    richTextSpacingBetweenBlocks(upper: upperKind, lower: lowerKind,
                                                 kind: .list, metrics: metrics),
                    spacingBetweenBlocks(upper: upperBlock, lower: lowerBlock,
                                         kind: .list, metrics: ipMetrics),
                    accuracy: 0.001, "in-list \(upperKind) -> \(lowerKind)")
            }
        }
    }

    // MARK: The adapter and the editor's default

    /// The editor's hardcoded `.default` must equal what the adapter produces for the chat-message
    /// theme. Without this the editor's standalone default and the app's real theme drift apart, and
    /// only the running app shows it — the composer relies on the default precisely because it cannot
    /// import InstantPageUI.
    func test_editorDefaultMetrics_equalTheAdaptedChatMessageTheme() {
        XCTAssertEqual(InstantPageTheme.chatMessageRenderMetrics(), RichTextRenderMetrics.default)
    }

    /// `edgeSpacingReduction` is the one field the adapter takes from its caller rather than the theme.
    func test_adapter_carriesEdgeSpacingReduction() {
        XCTAssertEqual(InstantPageTheme.chatMessageRenderMetrics(edgeSpacingReduction: 1.0).edgeSpacingReduction, 1.0)
    }

    /// The editor must lay code blocks out with the renderer's own numbers. These lived in two places
    /// before — `InstantPageMetrics` and the editor's `QuoteStyle` — which is exactly why the two
    /// surfaces shipped with 9/22 against 9/9 interior padding and 3pt against 6pt vertical.
    ///
    /// The pinned default is covered by `test_editorDefaultMetrics_equalTheAdaptedChatMessageTheme`
    /// above, which compares the whole struct; this pins the adapter against its source.
    func test_codeMetrics_crossTheContractUnchanged() {
        let m = InstantPageMetrics.unscaled
        let contract = InstantPageTheme.chatMessageRenderMetrics()

        XCTAssertEqual(contract.code.verticalInset, m.codeBlockVerticalInset, accuracy: 0.01)
        XCTAssertEqual(contract.code.languageSpacing, m.codeBlockLanguageSpacing, accuracy: 0.01)
    }
}
