import XCTest
import AccountContext
import ChatTextInputPanelNode

// A support template chosen from the panel goes in at the caret. A chat's composer starts with no blocks, which the
// flat replace leaves unchanged, so the template was dropped until something had been typed.
final class SupportTemplateInputStateTests: XCTestCase {
    private let template = NSAttributedString(string: "Hello")

    func testAnUntouchedComposerTakesTheTemplate() {
        let untouched = ChatTextInputState()
        XCTAssertTrue(untouched.content.blocks.isEmpty)
        let state = supportTemplateInputState(untouched, inserting: self.template, replacing: nil)
        XCTAssertEqual(state.inputText.string, "Hello")
        XCTAssertEqual(state.selectionRange, 5 ..< 5)
    }

    func testAClearedComposerTakesTheTemplate() {
        let cleared = ChatTextInputState(inputText: NSAttributedString(string: ""))
        XCTAssertEqual(cleared.content.blocks.count, 1)
        let state = supportTemplateInputState(cleared, inserting: self.template, replacing: nil)
        XCTAssertEqual(state.inputText.string, "Hello")
        XCTAssertEqual(state.selectionRange, 5 ..< 5)
    }

    func testTextAtTheCaretKeepsTheFlatReplace() {
        let current = ChatTextInputState(inputText: NSAttributedString(string: "Hi "), selectionRange: 3 ..< 3)
        let state = supportTemplateInputState(current, inserting: self.template, replacing: nil)
        XCTAssertEqual(state, current.replacingFlatRange(NSRange(location: 3, length: 0), with: self.template))
        XCTAssertEqual(state.inputText.string, "Hi Hello")
        XCTAssertEqual(state.selectionRange, 8 ..< 8)
    }

    func testAKeyRangeIsReplaced() {
        let current = ChatTextInputState(inputText: NSAttributedString(string: "a /key"), selectionRange: 6 ..< 6)
        let state = supportTemplateInputState(current, inserting: self.template, replacing: NSRange(location: 2, length: 4))
        XCTAssertEqual(state.inputText.string, "a Hello")
        XCTAssertEqual(state.selectionRange, 7 ..< 7)
    }
}
