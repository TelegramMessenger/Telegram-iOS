#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// What one keystroke costs a host, counted in synchronous layout passes. Each pass is a full
/// `layoutContent()` over every box on the main thread, in the shipping composer and article editor.
///
/// After the host-driven caret reveal landed (2026-09-17) a keystroke cost FIVE: the edit's epilogue
/// reported a content-size change AND a selection change, both asked the host for a reveal, the host
/// answered each with a full `update`, and the reveal laid the canvas out once more inside each. Every
/// edit reports a selection change, so the content-size path asking as well was a duplicate, and the
/// reveal's own pass right after `update`'s was a duplicate of that. Found in review of the squash
/// (2026-10-12).
final class CaretRevealLayoutPassTests: XCTestCase {
    /// A host wired as the chat composer wires it (`RichTextEditorChatInputNode`): `onChange` re-lays
    /// the field out at its committed geometry, and `onCaretRevealNeeded` re-applies it with a reveal.
    private func composerLikeHost(window: UIWindow) -> (editor: RichTextEditorView, reveals: () -> Int) {
        let editor = RichTextEditorView(frame: window.bounds)
        window.addSubview(editor)
        editor.document = Document(blocks: (0..<40).map {
            Block.paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        })
        editor.layoutIfNeeded()
        let size = window.bounds.size
        var reveals = 0
        editor.onChange = { [unowned editor] in
            _ = editor.update(size: size, insets: .zero, contentMargins: .zero, scrollIndicatorInsets: nil)
        }
        editor.onCaretRevealNeeded = { [unowned editor] in
            reveals += 1
            _ = editor.update(size: size, insets: .zero, contentMargins: .zero, scrollIndicatorInsets: nil,
                              caretReveal: .ifNeeded(.immediate))
        }
        return (editor, { reveals })
    }

    func test_aKeystrokeCostsTwoLayoutPassesAndOneRevealRequest() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let (editor, reveals) = composerLikeHost(window: window)
        XCTAssertTrue(editor.becomeFirstResponder())
        let last = editor.canvas.boxes.last!
        let endPos = DocumentTextPosition(last.textStart + last.textLength)
        editor.canvas.selectedTextRange = DocumentTextRange(endPos, endPos)

        let revealsBefore = reveals()
        editor.performLayoutCountForTesting = 0
        editor.canvas.insertText("Z")

        XCTAssertEqual(reveals() - revealsBefore, 1, "one keystroke asked the host for more than one reveal")
        XCTAssertEqual(editor.performLayoutCountForTesting, 2,
                       "one keystroke ran \(editor.performLayoutCountForTesting) synchronous layout passes: the host's onChange pass and its reveal pass are the two it needs")
    }

    /// What the reveal is FOR still holds: typing at a caret the user scrolled away from brings it back.
    func test_theKeystrokeStillBringsAnOffScreenCaretBack() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let (editor, _) = composerLikeHost(window: window)
        XCTAssertTrue(editor.becomeFirstResponder())
        let last = editor.canvas.boxes.last!
        let endPos = DocumentTextPosition(last.textStart + last.textLength)
        editor.canvas.selectedTextRange = DocumentTextRange(endPos, endPos)
        editor.contentOffsetForTesting = .zero
        XCTAssertEqual(editor.contentOffsetForTesting.y, 0, accuracy: 0.5, "precondition: scrolled to the top")

        editor.canvas.insertText("Z")
        XCTAssertGreaterThan(editor.contentOffsetForTesting.y, 0, "the keystroke did not bring the caret back")
    }
}
#endif
