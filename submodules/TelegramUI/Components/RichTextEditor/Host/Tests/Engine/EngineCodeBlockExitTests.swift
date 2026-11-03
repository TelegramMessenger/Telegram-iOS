import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// Legacy's double Return leaving a code block, keystroke by keystroke through the surface, each in
/// its own run-loop turn as on device (measured crash 2026-09-04: `declareFreshBlocks` removed a
/// role past the end after a double Return at the end of a last code block).
@available(iOS 18.4, *)
final class EngineCodeBlockExitTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }

    func test_doubleReturnAtTheEndOfALastCodeBlockOpensAParagraphAfterIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 14, length: 0)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["before", "swift", "x\u{2028}"])
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["before", "swift", "x", ""])
        XCTAssertEqual(editor.document.blocks.count, 3)
        guard case .paragraph = editor.document.blocks[2] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 15, length: 0), "the caret opens the paragraph after")
    }

    func test_doubleReturnAtTheEndOfTheOnlyCodeBlock() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["swift", "x", ""])
    }

    func test_doubleReturnInAnEmptyLastCodeBody() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 13, length: 0)
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["before", "swift", "\u{2028}"])
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["before", ""], "a wholly blank body un-makes")
    }

    func test_doubleReturnAfterMakingACodeBlockAndTypingIntoIt() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.makeCodeBlock(); turn()
        editor.engine.insertText("x"); turn()
        XCTAssertEqual(strings(), ["before", "", "x"])
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["before", "", "x", ""])
        editor.engine.insertText("y"); turn()
        XCTAssertEqual(strings(), ["before", "", "x", "y"])
    }

    func test_aThirdReturnAfterTheExitSplitsTheNewParagraph() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(strings(), ["swift", "x", "", ""], "a Return in the paragraph after the code splits it: the roles' offsets are true")
    }

    /// The roles after an exit read back from the engine, not from the plan built before the exit's
    /// own edits: the code body has lost its blank last line, and the paragraph after starts where
    /// the engine says it does.
    func test_theRolesAfterAnExitCarryTheEnginesText() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        editor.engine.insertText("\n"); turn()
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(editor.currentBlocks.map(\.flatText), ["swift", "x", ""])
        XCTAssertEqual(editor.document.blocks.map(\.flatText), ["x", ""], "the body without its blank last line")
    }

    /// A newline that reaches the controller past the gate (dictation, an IME) at the end of a LAST
    /// code body mints a last block behind a leaf body; settle rejoins it as a line separator. This
    /// was the crash: the rejoin removed a role at an index past the end.
    func test_aBypassNewlineAtTheEndOfALastCodeBodyIsRejoinedAsALineSeparator() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 7, length: 0)
        let controller = editor.engine.value(forKey: "id_behaviorInput") as AnyObject
        _ = controller.perform(#selector(UIKeyInput.insertText(_:)), with: "\n"); turn()
        XCTAssertEqual(strings(), ["swift", "x\u{2028}"])
        XCTAssertEqual(editor.currentRoles.count, 2)
        guard case .code = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        editor.engine.insertText("y"); turn()
        XCTAssertEqual(strings(), ["swift", "x\u{2028}y"])
    }
}
