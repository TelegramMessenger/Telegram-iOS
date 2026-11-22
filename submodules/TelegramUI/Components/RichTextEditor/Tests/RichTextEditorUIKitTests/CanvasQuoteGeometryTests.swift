#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasQuoteGeometryTests: XCTestCase {
    func test_applyQuoteStyle_preservesTheme() {
        let v = DocumentCanvasView()
        var theme = RichTextEditorTheme.default
        theme.accent = .magenta
        v.applyTheme(theme)
        v.applyQuoteStyle(.default)   // must NOT reset the theme
        XCTAssertEqual(v.mapper.theme.accent, .magenta)
    }

    func test_facade_quoteStyle_roundTrips() {
        let view = RichTextEditorView(frame: .zero)
        var qs = QuoteStyle.default
        qs.leadingInset = 9
        view.quoteStyle = qs
        XCTAssertEqual(view.quoteStyle.leadingInset, 9, accuracy: 0.01)
    }
}
#endif
