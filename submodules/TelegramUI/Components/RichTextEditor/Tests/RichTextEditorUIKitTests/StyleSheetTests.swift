#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class StyleSheetTests: XCTestCase {
    func test_color_roundTrips() {
        let c = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let back = c.uiColor.rgba
        XCTAssertEqual(back.red, 0.2, accuracy: 0.01)
        XCTAssertEqual(back.alpha, 0.8, accuracy: 0.01)
    }

    func test_font_appliesBoldItalicAndSize() {
        let f = FontResolver.font(family: nil, size: 20, bold: true, italic: true)
        XCTAssertEqual(f.pointSize, 20, accuracy: 0.5)
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_styleSheet_headingIsLargerThanBody() {
        let sheet = StyleSheet.default
        let h1 = sheet.font(for: .heading1, attributes: .plain)
        let body = sheet.font(for: .body, attributes: .plain)
        XCTAssertGreaterThan(h1.pointSize, body.pointSize)
    }

    func test_caption_is15ptSans_andBodyIsSans() {
        let sheet = StyleSheet.default
        let caption = sheet.font(for: .caption, attributes: .plain)
        XCTAssertEqual(caption.pointSize, 15, accuracy: 0.5)
        XCTAssertEqual(caption.familyName, UIFont.systemFont(ofSize: 15).familyName, "captions are sans")
        XCTAssertEqual(sheet.font(for: .body, attributes: .plain).familyName,
                       UIFont.systemFont(ofSize: 17).familyName, "body is sans")
    }

    func test_heading_isSerif_andNotBoldByDefault() {
        let f = StyleSheet.default.font(for: .heading1, attributes: .plain)
        XCTAssertTrue(f.fontName.contains("NewYork"), "headings stay serif")
        XCTAssertFalse(f.fontDescriptor.symbolicTraits.contains(.traitBold),
                       "headings are regular weight by default — bold is user emphasis only")
    }

    func test_heading_userBoldStillApplies() {
        var bold = CharacterAttributes(); bold.bold = true
        let f = StyleSheet.default.font(for: .heading1, attributes: bold)
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitBold),
                      "a user can still bold a heading explicitly")
    }

    func test_body_is17pt() {
        XCTAssertEqual(StyleSheet.default.font(for: .body, attributes: .plain).pointSize, 17, accuracy: 0.5)
    }

    func test_tableCells_bodyIs15pt_headingsUnchanged() {
        let sheet = StyleSheet.tableCells
        XCTAssertEqual(sheet.font(for: .body, attributes: .plain).pointSize, 15, accuracy: 0.5,
                       "table-cell body base is 15pt")
        XCTAssertEqual(sheet.font(for: .heading1, attributes: .plain).pointSize, 22, accuracy: 0.5,
                       "headings keep their fixed size in cells")
        // The document body sheet is untouched.
        XCTAssertEqual(StyleSheet.default.font(for: .body, attributes: .plain).pointSize, 17, accuracy: 0.5)
    }

    func test_tableCells_explicitFontSizeStillWins() {
        var ca = CharacterAttributes(); ca.fontSize = 22
        XCTAssertEqual(StyleSheet.tableCells.font(for: .body, attributes: ca).pointSize, 22, accuracy: 0.5,
                       "an explicit run size overrides the cell base")
    }

    /// The ladder is V2's (22/20/18/…) — see `test_fontSizes_comeFromTheRenderMetrics` below for the
    /// full set.
    func test_headingSizes_matchTypeScale() {
        let sheet = StyleSheet.default
        XCTAssertEqual(sheet.font(for: .heading1, attributes: .plain).pointSize, 22, accuracy: 0.5)
        XCTAssertEqual(sheet.font(for: .heading2, attributes: .plain).pointSize, 20, accuracy: 0.5)
        XCTAssertEqual(sheet.font(for: .heading3, attributes: .plain).pointSize, 18, accuracy: 0.5)
    }

    // The former `test_perStyleSpacing_applied`, `test_textLayoutMetrics_*` and `test_compactMetrics_*`
    // tests pinned the retired model: per-style render paragraph spacing (body +8 after, headings +18
    // before) and a per-style `lineHeightMultiple`, tunable via `TextLayoutMetrics`. V2 keeps ALL
    // inter-block spacing in `spacingBetweenBlocks` and its strings carry none, so that spacing is gone
    // rather than re-tuned, and the line box is pinned instead of scaled. The replacements below assert
    // the new model; `test_paragraphStyle_stillHonoursModelParagraphSpacing` preserves the one part of
    // the old behaviour that survives — a model-level spacing is user content.

    /// The heading ladder and body/caption sizes now come from `RichTextRenderMetrics`, which carries
    /// V2's numbers — the editor's own ladder was a point short per level and a whole weight light.
    func test_fontSizes_comeFromTheRenderMetrics() {
        let sheet = StyleSheet.default
        XCTAssertEqual(sheet.font(for: .heading1, attributes: .plain).pointSize, 22)
        XCTAssertEqual(sheet.font(for: .heading2, attributes: .plain).pointSize, 20)
        XCTAssertEqual(sheet.font(for: .heading3, attributes: .plain).pointSize, 18)
        XCTAssertEqual(sheet.font(for: .heading4, attributes: .plain).pointSize, 17)
        XCTAssertEqual(sheet.font(for: .heading5, attributes: .plain).pointSize, 16)
        XCTAssertEqual(sheet.font(for: .heading6, attributes: .plain).pointSize, 15)
        XCTAssertEqual(sheet.font(for: .body, attributes: .plain).pointSize, 17)
        XCTAssertEqual(sheet.font(for: .caption, attributes: .plain).pointSize, 15)
    }

    /// Headings resolve through the weighted-serif path (system serif design), not Georgia.
    func test_headingFont_isWeightedSerif() {
        let font = StyleSheet.default.font(for: .heading1, attributes: .plain)
        XCTAssertFalse(font.familyName.contains("Georgia"), "got \(font.familyName)")
    }

    /// A per-run `fontSize` still overrides the style's size, and keeps the style's family/weight.
    func test_explicitRunFontSize_stillOverridesTheStyleSize() {
        var attrs = CharacterAttributes.plain
        attrs.fontSize = 30
        let font = StyleSheet.default.font(for: .body, attributes: attrs)
        XCTAssertEqual(font.pointSize, 30)
    }

    /// V2 puts ALL inter-block spacing in `spacingBetweenBlocks`; the attributed string carries none.
    /// Any residual per-style paragraph spacing here would double-count every gap.
    func test_paragraphStyle_carriesNoRenderParagraphSpacing() {
        let sheet = StyleSheet.default
        for style in [ParagraphStyleName.body, .caption, .heading1, .heading2, .heading3,
                      .heading4, .heading5, .heading6, .pullQuote] {
            let ps = sheet.paragraphStyle(for: style, attributes: .default)
            XCTAssertEqual(ps.paragraphSpacingBefore, 0, "\(style) spacingBefore")
            XCTAssertEqual(ps.paragraphSpacing, 0, "\(style) spacingAfter")
        }
    }

    /// A model-level paragraph spacing is user content and still applies.
    func test_paragraphStyle_stillHonoursModelParagraphSpacing() {
        var attrs = ParagraphAttributes.default
        attrs.paragraphSpacingBefore = 5
        attrs.paragraphSpacingAfter = 7
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: attrs)
        XCTAssertEqual(ps.paragraphSpacingBefore, 5)
        XCTAssertEqual(ps.paragraphSpacing, 7)
    }

    /// Table cells render body content at the metrics' `table` size (15pt), the reason a table reads
    /// denser than surrounding body text. Headings in cells keep their own sizes.
    func test_tableCellsVariant_rendersBodyAtTheTableSize() {
        let cells = StyleSheet.tableCells
        XCTAssertEqual(cells.font(for: .body, attributes: .plain).pointSize, 15)
        XCTAssertEqual(cells.font(for: .heading1, attributes: .plain).pointSize, 22)
    }

    /// Host-supplied metrics flow through, so a host can hand over its renderer's exact numbers.
    func test_hostSuppliedMetrics_changeTheResolvedFont() {
        var sheet = StyleSheet.default
        sheet.metrics.body = RichTextFontSpec(style: .sans, size: 13, lineSpacingFactor: 1.0)
        XCTAssertEqual(sheet.font(for: .body, attributes: .plain).pointSize, 13)
    }
}
#endif
