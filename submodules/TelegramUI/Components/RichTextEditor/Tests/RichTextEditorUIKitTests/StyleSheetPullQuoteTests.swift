#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class StyleSheetPullQuoteTests: XCTestCase {
    func test_pullQuote_forcesItalicRegardlessOfRunItalic() {
        let ss = StyleSheet.default
        let font = ss.font(for: .pullQuote, attributes: CharacterAttributes())   // run has italic=false
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }
    func test_pullQuote_forcesCenterAlignment() {
        let ps = StyleSheet.default.paragraphStyle(for: .pullQuote, attributes: ParagraphAttributes())
        XCTAssertEqual(ps.alignment, .center)
    }
    func test_pullQuote_italicIsAmbient_notStoredOnReadback() {
        let mapper = AttributedStringMapper()
        let attr = mapper.attributedString(for: ParagraphBlock(id: BlockID("p"), style: .pullQuote, runs: [TextRun(text: "hi")]))
        let runs = mapper.runs(from: attr, style: .pullQuote)
        XCTAssertEqual(runs.map(\.text).joined(), "hi")
        XCTAssertFalse(runs.contains { $0.attributes.italic })   // forced italic never persists
    }
    func test_pullQuote_baseSizeIs15() {
        // Pull quotes render at 15pt like block quotes, not the ambient body size (17 in StyleSheet.default).
        let font = StyleSheet.default.font(for: .pullQuote, attributes: CharacterAttributes())
        XCTAssertEqual(font.pointSize, 15, accuracy: 0.001)
    }
}
#endif
