#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class CodeBlockBoxTests: XCTestCase {
    private func makeBox(_ text: String, language: String? = "swift") -> CodeBlockBox {
        CodeBlockBox(code: CodeBlock(id: BlockID("c1"), language: language, runs: [TextRun(text: text)]),
                     mapper: AttributedStringMapper(), width: 300)
    }

    /// A code block is a CONTAINER of [languagePara, codePara]: container(2) + (lang + 2) + (code + 2).
    func test_codeBox_nodeSizeCountsBothChildren() {
        let box = makeBox("a\nbb")                 // 4 UTF-16 units of code, "swift" = 5 of language
        XCTAssertEqual(box.nodeSize, 4 + 5 + 6)
        XCTAssertEqual(box.textLength, 4)
        XCTAssertEqual(box.languageLength, 5)
    }

    func test_codeBox_textRefIsCode() {
        XCTAssertEqual(makeBox("x").textRef, .code(BlockID("c1")))
    }

    func test_codeBox_usesFifteenPointFont_matchingQuote() {
        XCTAssertEqual(CodeBlockBox.codeFont.pointSize, 15, accuracy: 0.5, "code block font is 15pt, matching the quote")
    }

    /// Code text must take the theme's primary text colour. An attributed string with no
    /// `.foregroundColor` draws BLACK, so a dark theme rendered code invisible against its own band.
    func test_codeBox_textTakesThePrimaryTextColour() {
        let theme = RichTextEditorTheme(
            primaryText: .magenta, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray)
        let mapper = AttributedStringMapper(styleSheet: .default, theme: theme)
        let box = CodeBlockBox(code: CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "let x = 1")]),
                               mapper: mapper, width: 300)

        let colour = box.layout.attributedString.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(colour, .magenta)
    }

    /// Newly TYPED characters take it too — the typing attributes are a separate site from the box's
    /// own string, so fixing one without the other leaves fresh input black.
    func test_codeBox_typingAttributesTakeThePrimaryTextColour() {
        let theme = RichTextEditorTheme(
            primaryText: .magenta, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray)
        let attrs = CodeBlockBox.codeAttributes(textColor: theme.primaryText)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, .magenta)
    }

    /// Render-only: the colour must not reach the model, or it would ride into a sent message.
    func test_codeBox_textColourDoesNotEnterTheModel() {
        let theme = RichTextEditorTheme(
            primaryText: .magenta, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray)
        let mapper = AttributedStringMapper(styleSheet: .default, theme: theme)
        let box = CodeBlockBox(code: CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "let x = 1")]),
                               mapper: mapper, width: 300)

        guard case let .code(cb) = box.currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.runs.count, 1)
        XCTAssertNil(cb.runs[0].attributes.foreground, "code text colour is render-only")
    }

    func test_codeBox_currentBlockRoundTripsTextAndLanguage() {
        guard case let .code(cb) = makeBox("a\nb", language: "ruby").currentBlock() else {
            return XCTFail("expected .code")
        }
        XCTAssertEqual(cb.text, "a\nb")
        XCTAssertEqual(cb.language, "ruby")
    }

    /// TWO regions, in DOCUMENT order: the language line above, then the code text.
    func test_codeBox_leafRegionsAreLanguageThenText() {
        let box = makeBox("a\nb"); box.globalStart = 5
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].globalStart, 6)          // nodeStart + 1
        XCTAssertEqual(regions[0].length, 5)               // "swift"
        XCTAssertEqual(regions[0].ref, .codeLanguage(BlockID("c1")))
        XCTAssertEqual(regions[1].globalStart, box.textStart)
        XCTAssertEqual(regions[1].length, 3)
        XCTAssertEqual(regions[1].ref, .code(BlockID("c1")))
    }

    /// The code text sits at the block's own leading edge — the paragraph column — not inset by the
    /// quote's indent. The band reaches further out than the text; that is the bleed's job.
    func test_codeBox_textOriginIsTheParagraphColumn() {
        let box = makeBox("x")
        box.frame = CGRect(x: 10, y: 0, width: 300, height: 40)
        XCTAssertEqual(box.textOrigin.x, box.frame.minX, accuracy: 0.5)
    }

    /// `blockViewFrame` is the block's full DRAWN extent, and `BlockBackingView` clips to it — so the
    /// band is invisible unless the bleed is reflected here.
    func test_codeBox_blockViewFrameOutsetsByTheBleed() {
        let box = makeBox("x")
        box.horizontalBleed = (minXSide: 16, maxXSide: 16)
        box.frame = CGRect(x: 16, y: 0, width: 288, height: 40)

        XCTAssertEqual(box.blockViewFrame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(box.blockViewFrame.maxX, 320, accuracy: 0.5)
        XCTAssertEqual(box.blockViewFrame.minY, box.frame.minY, accuracy: 0.5)
        XCTAssertEqual(box.blockViewFrame.height, box.frame.height, accuracy: 0.5)
    }

    /// No bleed ⇒ the drawn extent is the frame, so an un-migrated container cannot make a code block
    /// punch out of it.
    func test_codeBox_blockViewFrameIsTheFrameWithoutBleed() {
        let box = makeBox("x")
        box.frame = CGRect(x: 16, y: 0, width: 288, height: 40)
        XCTAssertEqual(box.blockViewFrame, box.frame)
    }

    /// The fill travels with the box, so a code block nested in a quote is filled too. It was not:
    /// the quote underlay's feed walked top-level boxes only, and the code case lived there.
    func test_codeBox_isNotFedToTheQuoteUnderlay() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "x")]))], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        canvas.layoutIfNeeded()

        XCTAssertTrue(canvas.blockQuoteFillRects().isEmpty)
    }

    /// The language line is bold and takes the BODY size — the quote author's spec — rather than the old
    /// absolute 11pt monospace. It is shown AS TYPED: the line became an editable field, so lowercasing it
    /// here would fight the author's own keystrokes. The renderer still lowercases at display
    /// (`instantPageV2CodeLanguageDisplayText`), which is where casing is a display concern.
    func test_codeBox_languageLineIsBoldBodySizedAndAsTyped() {
        let box = makeBox("x", language: "Swift")
        let line = box.languageLayout.attributedString

        XCTAssertEqual(line.string, "Swift")
        let font = line.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize ?? 0, StyleSheet.default.metrics.body.size, accuracy: 0.5)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    /// No language, and an empty language, are the same state — an EMPTY but present region. The field is
    /// always visible (that is where the "Language" placeholder draws), so unlike the old display-only
    /// label it is never absent and always reserves its line.
    func test_codeBox_languageLineIsPresentButEmptyWhenAbsent() {
        for box in [makeBox("x", language: nil), makeBox("x", language: "")] {
            XCTAssertEqual(box.languageLength, 0)
            XCTAssertEqual(box.languageLayout.attributedString.string, "")
            XCTAssertGreaterThan(box.languageLineExtent, StyleSheet.default.metrics.code.languageSpacing)
            XCTAssertNil(box.currentCode().language)
        }
    }

    /// A labelled and an unlabelled block are the SAME height: both reserve the always-visible language
    /// line. (Before the field was editable, the label appeared only when set and added its height.)
    func test_codeBox_languageLineIsReservedWhetherOrNotItIsSet() {
        let plain = makeBox("x", language: nil)
        let labelled = makeBox("x", language: "swift")

        XCTAssertEqual(labelled.measuredHeight(forWidth: 300), plain.measuredHeight(forWidth: 300), accuracy: 0.5)
        XCTAssertGreaterThan(plain.measuredHeight(forWidth: 300), plain.topInset + plain.bottomInset)
    }

    func test_codeBox_factoryProducesCodeBlockBox() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "x")]))], width: 300)
        XCTAssertTrue(canvas.boxes.first is CodeBlockBox)
    }

    func test_theme_storesCodeBackground() {
        let theme = RichTextEditorTheme(
            primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .red)
        XCTAssertEqual(theme.codeBackground, .red)
    }

    func test_emptyCodeBox_showsPlaceholder() {
        let box = makeBox("", language: nil)
        box.placeholders = .default
        XCTAssertEqual(box.placeholderText, "Type code here")
    }
    func test_nonEmptyCodeBox_noPlaceholder() {
        let box = makeBox("x")
        box.placeholders = .default
        XCTAssertNil(box.placeholderText)
    }
    func test_placeholders_containerDefaults() {
        XCTAssertEqual(RichTextEditorPlaceholders.default.codeBlock, "Type code here")
        XCTAssertEqual(RichTextEditorPlaceholders.default.blockQuote, "Type a quote here")
    }
    func test_theme_containerPlaceholder_settable() {
        var theme = RichTextEditorTheme.default
        theme.containerPlaceholder = .red
        XCTAssertEqual(theme.containerPlaceholder, .red)
    }

    // Regression: a TextKit-2 text edit that does NOT change the container width must still re-flow the
    // layout — otherwise the box height stays stale (the "code block doesn't grow on Enter; only rotation,
    // a width change, fixes it" bug). setWidth(200) after building at 200 is a genuine no-op, so the edit's
    // own invalidation is the only thing that can re-flow the height.
    func test_codeBox_editAtSameWidth_reflowsHeight() {
        let box = makeBox("a\nb", language: nil)   // built at width 300
        box.setWidth(300)                          // same width → genuine no-op (does not re-flow)
        let before = box.height
        box.textLayout.replace(start: 0, end: 0,
                               with: NSAttributedString(string: "\n", attributes: CodeBlockBox.codeAttributes(textColor: .black)))
        XCTAssertGreaterThan(box.height, before, "height must grow after an insert even without a width change")
    }
}
#endif
