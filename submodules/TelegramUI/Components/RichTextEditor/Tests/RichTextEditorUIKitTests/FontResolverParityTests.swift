#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `FontResolver` must reproduce `InstantPageTextStyleStack`'s family scheme exactly, because the
/// V2 line formulas are functions of `ascender`/`descender` — resolving New York where the renderer
/// resolves Georgia changes every line position while still type-checking and looking plausible.
final class FontResolverParityTests: XCTestCase {
    private func spec(_ style: RichTextFontStyle, _ size: CGFloat, _ weight: RichTextFontWeight = .regular) -> RichTextFontSpec {
        RichTextFontSpec(style: style, size: size, lineSpacingFactor: 1.0, weight: weight)
    }

    /// Weighted serif (every heading) resolves to the system serif design, which ships real Medium
    /// and Semibold faces — NOT Georgia, which ships only Regular and Bold.
    func test_serifMedium_resolvesToSystemSerifDesign() {
        let font = FontResolver.font(spec: spec(.serif, 24, .medium), bold: false, italic: false, family: nil)
        XCTAssertEqual(font.pointSize, 24)
        // The system serif design reports fontName ".NewYork-Medium" and familyName
        // ".AppleSystemUIFontSerif" — note the family carries "Serif" and the name carries "NewYork"
        // with no space, which is the opposite of what reads naturally.
        XCTAssertTrue(font.familyName.contains("Serif") || font.fontName.contains("NewYork"),
                      "expected system serif design, got \(font.fontName) / \(font.familyName)")
        XCTAssertFalse(font.familyName.contains("Georgia"))
    }

    /// Regular-weight serif resolves to Georgia, the way the renderer's fall-through arms do.
    func test_serifRegular_resolvesToGeorgia() {
        let font = FontResolver.font(spec: spec(.serif, 18), bold: false, italic: false, family: nil)
        XCTAssertEqual(font.fontName, "Georgia")
        XCTAssertEqual(font.pointSize, 18)
    }

    func test_serifRegularBold_resolvesToGeorgiaBold() {
        let font = FontResolver.font(spec: spec(.serif, 18), bold: true, italic: false, family: nil)
        XCTAssertEqual(font.fontName, "Georgia-Bold")
    }

    func test_serifRegularItalic_resolvesToGeorgiaItalic() {
        let font = FontResolver.font(spec: spec(.serif, 18), bold: false, italic: true, family: nil)
        XCTAssertEqual(font.fontName, "Georgia-Italic")
    }

    func test_serifRegularBoldItalic_resolvesToGeorgiaBoldItalic() {
        let font = FontResolver.font(spec: spec(.serif, 18), bold: true, italic: true, family: nil)
        XCTAssertEqual(font.fontName, "Georgia-BoldItalic")
    }

    /// A weighted serif run keeps its family when bold or italic is added, rather than falling
    /// through to Georgia and mixing two serif families mid-heading.
    func test_serifMediumBold_staysInTheSystemSerifFamily() {
        let font = FontResolver.font(spec: spec(.serif, 24, .medium), bold: true, italic: false, family: nil)
        XCTAssertFalse(font.familyName.contains("Georgia"), "got \(font.familyName)")
    }

    func test_monospace_resolvesToMenloFamily() {
        XCTAssertEqual(FontResolver.font(spec: spec(.monospace, 15), bold: false, italic: false, family: nil).fontName, "Menlo-Regular")
        XCTAssertEqual(FontResolver.font(spec: spec(.monospace, 15), bold: true, italic: false, family: nil).fontName, "Menlo-Bold")
        XCTAssertEqual(FontResolver.font(spec: spec(.monospace, 15), bold: false, italic: true, family: nil).fontName, "Menlo-Italic")
        XCTAssertEqual(FontResolver.font(spec: spec(.monospace, 15), bold: true, italic: true, family: nil).fontName, "Menlo-BoldItalic")
    }

    func test_sansRegular_resolvesToTheSystemFont() {
        let font = FontResolver.font(spec: spec(.sans, 17), bold: false, italic: false, family: nil)
        XCTAssertEqual(font, UIFont.systemFont(ofSize: 17))
    }

    func test_sansMedium_resolvesToTheMediumSystemFont() {
        let font = FontResolver.font(spec: spec(.sans, 17, .medium), bold: false, italic: false, family: nil)
        XCTAssertEqual(font, UIFont.systemFont(ofSize: 17, weight: .medium))
    }

    func test_sansSemibold_resolvesToTheSemiboldSystemFont() {
        let font = FontResolver.font(spec: spec(.sans, 17, .semibold), bold: false, italic: false, family: nil)
        XCTAssertEqual(font, UIFont.systemFont(ofSize: 17, weight: .semibold))
    }

    /// An explicit user font family still wins over the spec's style, as it does today.
    func test_explicitFamily_overridesTheSpecStyle() {
        let font = FontResolver.font(spec: spec(.serif, 17, .medium), bold: false, italic: false, family: "Courier")
        XCTAssertTrue(font.familyName.contains("Courier"), "got \(font.familyName)")
    }
}
#endif
