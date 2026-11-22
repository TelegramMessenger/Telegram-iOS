#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class RichTextEditorThemeTests: XCTestCase {
    // The four new fields default to the exact OS-semantic colors their render sites use today,
    // so `.default` reproduces the prior look (the SwiftPM Demo + suite depend on this).
    func test_default_newFields_matchPriorHardcodedColors() {
        let d = RichTextEditorTheme.default
        XCTAssertEqual(d.listMarker, .label)
        XCTAssertEqual(d.inlineCodeBackground, .systemGray5)
        XCTAssertEqual(d.markedTextUnderline, .label)
        XCTAssertEqual(d.spoilerDust, .secondaryLabel)
    }

    // A host can set each new field independently.
    func test_customTheme_storesNewFields() {
        let t = RichTextEditorTheme(
            primaryText: .red, secondaryText: .green, placeholder: .blue, accent: .orange,
            tableBorder: .gray, tableHeaderBackground: .yellow, codeBackground: .cyan,
            listMarker: .magenta, inlineCodeBackground: .brown,
            markedTextUnderline: .purple, spoilerDust: .systemPink
        )
        XCTAssertEqual(t.listMarker, .magenta)
        XCTAssertEqual(t.inlineCodeBackground, .brown)
        XCTAssertEqual(t.markedTextUnderline, .purple)
        XCTAssertEqual(t.spoilerDust, .systemPink)
    }

    // The existing 7-arg call site (chat composer) must still compile: the new params default,
    // so omitting them yields the prior-look colors.
    func test_sevenArgInit_newFieldsTakeDefaults() {
        let t = RichTextEditorTheme(
            primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray
        )
        XCTAssertEqual(t.listMarker, .label)
        XCTAssertEqual(t.inlineCodeBackground, .systemGray5)
        XCTAssertEqual(t.markedTextUnderline, .label)
        XCTAssertEqual(t.spoilerDust, .secondaryLabel)
    }

    // MARK: - quoteAuthorText / quoteAuthorPlaceholder (dedicated author-line colors)

    // Omitting the two new params defaults them to the existing shared colors, so there is no visual
    // regression until a host sets distinct values.
    func test_quoteAuthorColors_defaultToSharedColors() {
        let t = RichTextEditorTheme(
            primaryText: .black, secondaryText: .green, placeholder: .blue,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray
        )
        XCTAssertEqual(t.quoteAuthorText, .green)      // == secondaryText
        XCTAssertEqual(t.quoteAuthorPlaceholder, .blue) // == placeholder
    }

    // `.default` itself must also fall back (it uses the un-parameterized init).
    func test_default_quoteAuthorColors_matchSharedDefaults() {
        let d = RichTextEditorTheme.default
        XCTAssertEqual(d.quoteAuthorText, d.secondaryText)
        XCTAssertEqual(d.quoteAuthorPlaceholder, d.placeholder)
    }

    // A host can set the two new fields independently of the shared colors.
    func test_quoteAuthorColors_canBeSetDistinctly() {
        let t = RichTextEditorTheme(
            primaryText: .black, secondaryText: .green, placeholder: .blue,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray,
            quoteAuthorText: .red, quoteAuthorPlaceholder: .purple
        )
        XCTAssertEqual(t.quoteAuthorText, .red)
        XCTAssertEqual(t.quoteAuthorPlaceholder, .purple)
        // Sanity: the shared colors are untouched.
        XCTAssertEqual(t.secondaryText, .green)
        XCTAssertEqual(t.placeholder, .blue)
    }
}
#endif
