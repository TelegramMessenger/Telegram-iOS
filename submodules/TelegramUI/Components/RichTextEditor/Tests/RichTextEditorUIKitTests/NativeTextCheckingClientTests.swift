#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class NativeTextCheckingClientTests: XCTestCase {
    private func makeCanvas(_ text: String, id: String = "p") -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func firstStart(_ v: DocumentCanvasView) -> Int { v.boxes[0].textStart }

    func test_applyNativeAnnotations_populatesRegionLocalWithStyle() {
        let v = makeCanvas("hello wrold today")
        let base = firstStart(v)               // 1-based axis
        v.applyNativeAnnotations(global: NSRange(location: base + 6, length: 5), style: .spelling)   // "wrold"
        let entry = v.spellResults[BlockID("p")]
        XCTAssertEqual(entry?.ranges.map { $0.range }, [NSRange(location: 6, length: 5)])
        XCTAssertEqual(entry?.ranges.map { $0.style }, [.spelling])
    }
    func test_clearNativeAnnotations_removesRange() {
        let v = makeCanvas("hello wrold")
        let base = firstStart(v)
        v.applyNativeAnnotations(global: NSRange(location: base + 6, length: 5), style: .spelling)
        v.clearNativeAnnotations(global: NSRange(location: base + 6, length: 5))
        XCTAssertEqual(v.spellResults[BlockID("p")]?.ranges.count ?? 0, 0)
    }
    func test_applyNativeAnnotations_dropsLinkExcludedRange() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [
            TextRun(text: "see "), TextRun(text: "wrold", attributes: CharacterAttributes(link: "https://x.com"))]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let base = v.boxes[0].textStart
        v.applyNativeAnnotations(global: NSRange(location: base + 4, length: 5), style: .spelling)  // "wrold" (link)
        XCTAssertEqual(v.spellResults[BlockID("p")]?.ranges.count ?? 0, 0)   // excluded
    }

    // MARK: N3 — style classification + style-aware color

    func test_style_spellingFromDisplayStyle2() {
        // Observed live: a spelling flag carries NSTextAlternativesDisplayStyle == 2 and no alternatives.
        let attrs: [NSAttributedString.Key: Any] = [DocumentCanvasView.displayStyleKey: 2]
        XCTAssertEqual(DocumentCanvasView.style(from: attrs), .spelling)
    }
    func test_style_grammarFromOtherDisplayStyle() {
        let attrs: [NSAttributedString.Key: Any] = [DocumentCanvasView.displayStyleKey: 1]
        XCTAssertEqual(DocumentCanvasView.style(from: attrs), .grammar)
    }
    func test_style_correctionWhenAlternativesPresent() {
        // style(from:) only checks PRESENCE of the alternatives key (the correction data), so any non-nil value.
        let attrs: [NSAttributedString.Key: Any] = [
            DocumentCanvasView.displayStyleKey: 0,
            DocumentCanvasView.alternativesKey: "correction-alternatives",
        ]
        XCTAssertEqual(DocumentCanvasView.style(from: attrs), .correction)
    }
    // MARK: N4 — `.correction` alternatives stash (via `nativeReplace`, the real controller-facing path)

    /// Stands in for the private, non-publicly-constructible `NSTextAlternatives`: exposes the same two
    /// KVC-readable properties the production code reads (`alternativeStrings`/`primaryString`).
    private final class FakeTextAlternatives: NSObject {
        @objc let alternativeStrings: [String]
        @objc let primaryString: String
        init(alternativeStrings: [String], primaryString: String) {
            self.alternativeStrings = alternativeStrings
            self.primaryString = primaryString
        }
    }

    func test_nativeReplace_correctionStashesAlternativesViaKVC() {
        let v = makeCanvas("hello wrold today")
        let base = firstStart(v)
        let range = v.nativeTextRange(forGlobalLocation: base + 6, length: 5)!
        let alt = FakeTextAlternatives(alternativeStrings: ["world", "word"], primaryString: "world")
        let s = NSAttributedString(string: "wrold", attributes: [
            DocumentCanvasView.displayStyleKey: 0,
            DocumentCanvasView.alternativesKey: alt,
        ])
        v.nativeReplace(range, withAnnotatedString: s, relativeReplacementRange: NSRange(location: 0, length: 5))
        let stashed = v.spellingAlternatives[BlockID("p")]?.first { $0.range == NSRange(location: 6, length: 5) }
        XCTAssertEqual(stashed?.candidates, ["world", "word"])
        XCTAssertEqual(stashed?.primary, "world")
        XCTAssertEqual(v.spellResults[BlockID("p")]?.ranges.map { $0.style }, [.correction])
    }

    func test_nativeReplace_correctionWithUnexpectedAlternativesShape_doesNotCrashOrStash() {
        let v = makeCanvas("hello wrold today")
        let base = firstStart(v)
        let range = v.nativeTextRange(forGlobalLocation: base + 6, length: 5)!
        // Not an NSTextAlternatives-shaped object — the KVC reads must guard and no-op, not crash.
        let s = NSAttributedString(string: "wrold", attributes: [
            DocumentCanvasView.displayStyleKey: 0,
            DocumentCanvasView.alternativesKey: "not-an-NSTextAlternatives-instance",
        ])
        v.nativeReplace(range, withAnnotatedString: s, relativeReplacementRange: NSRange(location: 0, length: 5))
        XCTAssertNil(v.spellingAlternatives[BlockID("p")]?.first { $0.range == NSRange(location: 6, length: 5) })
        // The style classification + `spellResults` flag are unaffected by the missing candidates.
        XCTAssertEqual(v.spellResults[BlockID("p")]?.ranges.map { $0.style }, [.correction])
    }

    func test_underlineColor_perStyle() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "x")]))], width: 320)
        XCTAssertEqual(v.spellingUnderlineColor(.spelling), v.mapper.theme.misspellingUnderline)
        XCTAssertEqual(v.spellingUnderlineColor(.grammar), v.mapper.theme.grammarUnderline)
        XCTAssertEqual(v.spellingUnderlineColor(.correction), v.mapper.theme.correctionUnderline)
    }
    func test_themeDefaults_grammarGreen_correctionPeriwinkle() {
        XCTAssertEqual(RichTextEditorTheme.default.grammarUnderline, .systemGreen)
        // Measured from a real UITextView's native iOS 26 autocorrect underline (#99ACEB) — see Task 2 brief.
        XCTAssertEqual(RichTextEditorTheme.default.correctionUnderline,
                        UIColor(red: 153.0/255.0, green: 172.0/255.0, blue: 235.0/255.0, alpha: 1.0))
    }
}
#endif
