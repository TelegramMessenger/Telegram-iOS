#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MapperTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func formulaRenderResult(size: CGSize = CGSize(width: 28.0, height: 12.0)) -> RichTextFormulaRenderResult {
        let image = UIGraphicsImageRenderer(size: size).image { _ in }
        return RichTextFormulaRenderResult(image: image, size: size, ascent: 9.0, descent: 3.0)
    }

    func test_characterAttributes_roundTripThroughDict() {
        // No link here: a link deliberately suppresses foreground/underline on read-back (covered by
        // AttributedStringMapperLinkTests), so those fields are exercised here on an unlinked run.
        // Use a NON-default foreground (red) so it round-trips as explicit — an explicit color equal to the
        // theme's default would be stripped to nil (that behavior is covered by its own test below).
        let ca = CharacterAttributes(bold: true, italic: true, underline: true, strikethrough: true,
                                     fontSize: 18, foreground: RGBAColor(red: 1, green: 0, blue: 0),
                                     highlight: RGBAColor(red: 1, green: 1, blue: 0),
                                     baselineOffset: 4)
        let dict = mapper.attributes(for: ca, style: .body)
        let back = mapper.characterAttributes(from: dict)
        XCTAssertTrue(back.bold); XCTAssertTrue(back.italic)
        XCTAssertTrue(back.underline); XCTAssertTrue(back.strikethrough)
        XCTAssertEqual(back.foreground, RGBAColor(red: 1, green: 0, blue: 0))
        XCTAssertEqual(back.baselineOffset ?? 0, 4, accuracy: 0.01)
        XCTAssertNotNil(back.highlight)
    }

    func test_uncoloredRun_staysNilThroughRoundTrip() {
        // A run with no explicit color renders in the theme default but must read back as nil (unset),
        // so re-theming recolors it and serialization stays clean.
        let dict = mapper.attributes(for: CharacterAttributes(), style: .body)
        XCTAssertEqual(dict[.foregroundColor] as? UIColor, RichTextEditorTheme.default.primaryText,
                       "un-colored body text renders in the primary text color")
        let back = mapper.characterAttributes(from: dict, style: .body)
        XCTAssertNil(back.foreground, "the injected default must be stripped back to nil")
    }

    func test_explicitColorEqualToDefault_isStripped() {
        // An explicit foreground that happens to equal the theme default is indistinguishable from the
        // injected default and is stripped to nil (visually identical, and re-themable). Documented behavior.
        let ca = CharacterAttributes(foreground: RichTextEditorTheme.default.primaryText.rgba)
        let dict = mapper.attributes(for: ca, style: .body)
        let back = mapper.characterAttributes(from: dict, style: .body)
        XCTAssertNil(back.foreground)
    }

    func test_captionUsesSecondaryDefault_andStripsIt() {
        let theme = RichTextEditorTheme(primaryText: .red, secondaryText: .blue, placeholder: .placeholderText,
                                        accent: .green, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .placeholderText)
        let m = AttributedStringMapper(theme: theme)
        // Caption renders in secondary; body renders in primary.
        XCTAssertEqual(m.attributes(for: CharacterAttributes(), style: .caption)[.foregroundColor] as? UIColor, UIColor.blue)
        XCTAssertEqual(m.attributes(for: CharacterAttributes(), style: .body)[.foregroundColor] as? UIColor, UIColor.red)
        // The caption default is stripped only when read back WITH the caption style.
        let captionDict = m.attributes(for: CharacterAttributes(), style: .caption)
        XCTAssertNil(m.characterAttributes(from: captionDict, style: .caption).foreground)
        // Reading the caption dict back with the WRONG style (body) must NOT strip the secondary color —
        // guards against a caller forgetting to pass .caption (e.g. MediaBlockBox captions).
        XCTAssertNotNil(m.characterAttributes(from: captionDict, style: .body).foreground,
                        "caption secondary must not be stripped when read back as body style")
    }

    func test_linkUsesAccentColor() {
        let theme = RichTextEditorTheme(primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
                                        accent: .green, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .placeholderText)
        let m = AttributedStringMapper(theme: theme)
        let dict = m.attributes(for: CharacterAttributes(link: "https://example.com"), style: .body)
        XCTAssertEqual(dict[.foregroundColor] as? UIColor, UIColor.green)
        // Link foreground is render-only and never captured into the model.
        XCTAssertNil(m.characterAttributes(from: dict, style: .body).foreground)
    }

    func test_paragraphBlock_roundTripsRuns() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body, runs: [
            TextRun(text: "Plain "),
            TextRun(text: "bold", attributes: CharacterAttributes(bold: true)),
        ])
        let attr = mapper.attributedString(for: block)
        XCTAssertEqual(attr.string, "Plain bold")
        let runs = mapper.runs(from: attr)
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].text, "Plain ")
        XCTAssertFalse(runs[0].attributes.bold)
        XCTAssertEqual(runs[1].text, "bold")
        XCTAssertTrue(runs[1].attributes.bold)
    }

    func test_serifHeadingFont_doesNotReadBackAsFontFamily() {
        let m = AttributedStringMapper()
        // .heading1 resolves to the system serif (New York); a default CharacterAttributes has no fontFamily.
        let attrs = m.attributes(for: CharacterAttributes(), style: .heading1)
        let ca = m.characterAttributes(from: attrs)
        XCTAssertNil(ca.fontFamily, "serif heading font is style-derived and must not leak into the model as a user fontFamily")
    }

    func test_substitutedFontFamily_doesNotLeakIntoModel() throws {
        // TextKit's automatic font substitution (e.g. for Arabic/Hebrew/CJK glyphs the style font can't
        // render) rewrites `.font` in the storage to a script-specific family. That is a display artifact,
        // not user intent, and must NOT round-trip into the model — otherwise a rebuild (e.g. the paragraph
        // merge on backspace) re-applies the substituted family and the font visibly changes.
        let substituted = try XCTUnwrap(UIFont(name: "Helvetica Neue", size: 17),
                                        "test needs a font with a non-default family")
        XCTAssertNotEqual(substituted.familyName, UIFont.systemFont(ofSize: 17).familyName,
                          "precondition: the test font has a non-default family")
        let ca = AttributedStringMapper().characterAttributes(from: [.font: substituted], style: .body)
        XCTAssertNil(ca.fontFamily, "a display-substituted font family must not round-trip into the model")
    }

    func test_inlineCode_rendersMonospace_andRoundTripsClean() {
        let ca = CharacterAttributes(inlineCode: true)
        let dict = mapper.attributes(for: ca, style: .body)
        let font = dict[.font] as? UIFont
        XCTAssertNotNil(font)
        XCTAssertNotEqual(font?.fontName, UIFont.systemFont(ofSize: 16).fontName,
                          "inline code must render with a non-system (monospace) font")
        let back = mapper.characterAttributes(from: dict)
        XCTAssertTrue(back.inlineCode)
        XCTAssertNil(back.fontFamily, "the mono font name must not leak into fontFamily")
        XCTAssertNil(back.highlight, "the code background must not be read back as a highlight")
        XCTAssertNil(back.fontSize, "a plain inline-code run must not pin a font size")
        XCTAssertFalse(back.bold, "monospaced .regular carries no bold trait")
        XCTAssertFalse(back.italic, "monospaced .regular carries no italic trait")
        XCTAssertEqual((dict[.font] as? UIFont)?.pointSize, 17, "body inline code renders at the body base size")
    }

    func test_formulaDisplaysRawLatex_andRoundTripsMetadata() {
        let latex = "x_{1,2}=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}"
        let block = ParagraphBlock(id: BlockID("formula"), style: .body, runs: [
            TextRun(text: latex, attributes: CharacterAttributes(formula: latex))
        ])

        let attr = mapper.attributedString(for: block)
        XCTAssertEqual(attr.string, latex)

        let runs = mapper.runs(from: attr)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].text, latex)
        XCTAssertEqual(runs[0].attributes.formula, latex)
    }

    func test_formulaRendererDisplaysAttachmentAtom_andRoundTripsMetadata() throws {
        let latex = "e^{I\\pi}=-1"
        var capturedContext: RichTextFormulaRenderContext?
        let mapper = AttributedStringMapper(formulaRenderer: { context in
            capturedContext = context
            return self.formulaRenderResult()
        })
        let block = ParagraphBlock(id: BlockID("formula"), style: .body, runs: [
            TextRun(text: latex, attributes: CharacterAttributes(formula: latex))
        ])

        let attr = mapper.attributedString(for: block)
        XCTAssertEqual(attr.string, "\u{FFFC}")
        XCTAssertEqual(capturedContext?.latex, latex)
        XCTAssertEqual(capturedContext?.fontSize ?? 0.0, 17.0, accuracy: 0.01)

        let attachment = try XCTUnwrap(attr.attribute(.attachment, at: 0, effectiveRange: nil) as? FormulaTextAttachment)
        XCTAssertEqual(attachment.latex, latex)

        let runs = mapper.runs(from: attr)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].text, "\u{FFFC}")
        XCTAssertEqual(runs[0].attributes.formula, latex)
    }
}
#endif
