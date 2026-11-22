#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class AttributedStringMapperInlineCodeTests: XCTestCase {
    // Inline-code background must come from the theme, not a hardcoded color.
    func test_inlineCode_backgroundComesFromTheme() {
        let theme = RichTextEditorTheme(
            primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .gray,
            inlineCodeBackground: .magenta
        )
        let mapper = AttributedStringMapper(theme: theme)
        let dict = mapper.attributes(for: CharacterAttributes(inlineCode: true), style: .body)
        XCTAssertEqual(dict[.backgroundColor] as? UIColor, .magenta)
    }

    // Default mapper still reproduces the prior `.systemGray5` pill.
    func test_inlineCode_defaultBackgroundIsSystemGray5() {
        let dict = AttributedStringMapper().attributes(for: CharacterAttributes(inlineCode: true), style: .body)
        XCTAssertEqual(dict[.backgroundColor] as? UIColor, .systemGray5)
    }
}
#endif
