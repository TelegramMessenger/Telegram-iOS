#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EmptyBoxCaretDirectionTests: XCTestCase {
    func test_emptyBox_autoMode_withArabicKeyboard_caretOnRight() {
        let v = DocumentCanvasView()
        v.keyboardLanguageProviderForTesting = { "ar" }
        v.setParagraphs([ParagraphBlock(id: BlockID("a"))], width: 300)   // empty paragraph
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()
        let caret = v.boxes[0].textLayout.caretRect(atOffset: 0)
        XCTAssertGreaterThan(caret.minX, 150, "empty RTL-keyboard caret sits in the right half")
    }

    func test_emptyBox_autoMode_withLatinKeyboard_caretOnLeft() {
        let v = DocumentCanvasView()
        v.keyboardLanguageProviderForTesting = { "en" }
        v.setParagraphs([ParagraphBlock(id: BlockID("a"))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()
        let caret = v.boxes[0].textLayout.caretRect(atOffset: 0)
        XCTAssertLessThan(caret.minX, 150, "empty LTR-keyboard caret sits in the left half")
    }

    func test_emptyBox_forcedRTL_caretOnRight() {
        let v = DocumentCanvasView()
        v.applyWritingDirectionOverride(.rightToLeft)
        v.setParagraphs([ParagraphBlock(id: BlockID("a"))], width: 300)   // empty paragraph
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()
        let caret = v.boxes[0].textLayout.caretRect(atOffset: 0)
        XCTAssertGreaterThan(caret.minX, 150, "forced-RTL empty caret sits in the right half")
    }

    func test_emptyBox_forcedLTR_caretOnLeft() {
        let v = DocumentCanvasView()
        v.applyWritingDirectionOverride(.leftToRight)
        v.setParagraphs([ParagraphBlock(id: BlockID("a"))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()
        let caret = v.boxes[0].textLayout.caretRect(atOffset: 0)
        XCTAssertLessThan(caret.minX, 150, "forced-LTR empty caret sits in the left half")
    }

    /// Switching the input language (globe key) while on an empty paragraph must re-flip the caret live,
    /// without a reload/refocus — the canvas observes `currentInputModeDidChangeNotification`.
    func test_inputModeChange_reflipsEmptyCaret_whenInputLanguageBecomesRTL() {
        let v = DocumentCanvasView()
        v.keyboardLanguageProviderForTesting = { "en" }
        v.setParagraphs([ParagraphBlock(id: BlockID("a"))], width: 300)   // empty, auto mode
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 120); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()
        XCTAssertLessThan(v.boxes[0].textLayout.caretRect(atOffset: 0).minX, 150, "starts LTR")
        // Input language switches to RTL; the system posts the input-mode-change notification.
        v.keyboardLanguageProviderForTesting = { "ar" }
        NotificationCenter.default.post(name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
        XCTAssertGreaterThan(v.boxes[0].textLayout.caretRect(atOffset: 0).minX, 150,
                             "RTL input language re-flips the empty-paragraph caret to the right")
    }
}
#endif
