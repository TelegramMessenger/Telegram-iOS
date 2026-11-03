import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// Pins the shape of markdown-on-paste on the ENGINE backend, beyond "structure appears"
/// (`HarnessMarkdownPasteTests`):
///
/// - **Undo is two steps, legacy's shape**: the first undo leaves the raw text that was pasted,
///   the second removes it; redo walks back the same way. The engine closes the event's undo group
///   between the two steps by hand (`pasteTransformedPlainTextFromPasteboard`), so the group that
///   holds step 2 must still be closed at the end of the event — an edit typed afterwards has to be
///   a step of its own, not folded into the paste.
/// - **Mid-paragraph**: structure splits the host paragraph around the pasted blocks, and inline-only
///   markdown folds into the host paragraph.
/// - **Plain prose** (the parser answers nil) pastes literally through the engine's own path.
/// - **Inside a code block** markdown stays literal. Legacy DIFFERS here, deliberately not matched:
///   its second step `replaceRange`s the pasted text with the parsed blocks, and Core's
///   `insertingFragment` flattens a fragment into a code destination as each block's plain text, so
///   legacy silently deletes the `#`, `**` and `- ` the user pasted into their code.
///
/// **Tier 1**: `paste(_:)` and the view's `undoManager` are exactly what the edit menu and ⌘Z call.
final class HarnessMarkdownPasteShapeTests: XCTestCase {
    private struct Fixture {
        let root: HarnessRootViewController
        let host: HarnessPanelHost
        let node: ChatRichTextInputNode
        let textView: UIView
        let undoManager: UndoManager
    }


    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    private func fixture(_ content: ChatInputContent, caret: Int?) throws -> Fixture {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(content)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        if let caret {
            node.selectedRange = NSRange(location: caret, length: 0)
            HarnessEngine.settle(root)
            XCTAssertEqual(node.selectedRange, NSRange(location: caret, length: 0), "precondition: the caret did not land")
        }
        let textView = try HarnessEngine.textView(in: root)
        let undoManager = try XCTUnwrap(textView.undoManager, "precondition: the engine view has no undo manager")
        // The harness root outlives a test, and so does its editor's stack: without this, the steps
        // an earlier test left sit behind the paste and "nothing behind the paste" cannot be asserted.
        undoManager.removeAllActions()
        return Fixture(root: root, host: host, node: node, textView: textView, undoManager: undoManager)
    }

    private func paste(_ text: String, into fixture: Fixture) {
        UIPasteboard.general.string = text
        _ = fixture.textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(fixture.root)
    }

    private func content(_ fixture: Fixture) -> ChatInputContent {
        return fixture.node.currentInputContent().content
    }

    private func listItemCount(_ content: ChatInputContent) -> Int {
        return content.blocks.filter { block in
            if case let .paragraph(paragraph) = block {
                return paragraph.list != nil
            }
            return false
        }.count
    }

    func testUndoStepsFromRichToTheRawTextToNothingAndRedoWalksBack() throws {
        let f = try self.fixture(ChatInputContent(), caret: nil)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("# Title\n\n- one\n- two", into: f)
        XCTAssertFalse(self.content(f).plainText.contains("#"), "precondition: the paste did not parse: \(self.content(f).blocks)")
        XCTAssertEqual(self.listItemCount(self.content(f)), 2, "precondition: the list did not land: \(self.content(f).blocks)")

        f.undoManager.undo()
        HarnessEngine.settle(f.root)
        let raw = self.content(f)
        XCTAssertTrue(raw.plainText.contains("# Title"), "the first undo did not leave the raw text: \(raw.blocks)")
        XCTAssertTrue(raw.plainText.contains("- one") && raw.plainText.contains("- two"),
                      "the first undo did not leave the raw list lines: \(raw.blocks)")
        XCTAssertEqual(self.listItemCount(raw), 0, "the first undo left structure behind: \(raw.blocks)")

        f.undoManager.undo()
        HarnessEngine.settle(f.root)
        XCTAssertEqual(self.content(f).plainText, "", "the second undo did not remove the paste: \(self.content(f).blocks)")
        XCTAssertFalse(f.undoManager.canUndo, "a third step exists behind the paste")

        f.undoManager.redo()
        HarnessEngine.settle(f.root)
        XCTAssertTrue(self.content(f).plainText.contains("# Title"), "the first redo did not restore the raw text: \(self.content(f).blocks)")
        f.undoManager.redo()
        HarnessEngine.settle(f.root)
        XCTAssertFalse(self.content(f).plainText.contains("#"), "the second redo did not restore the parsed paste: \(self.content(f).blocks)")
        XCTAssertEqual(self.listItemCount(self.content(f)), 2, "the second redo did not restore the list: \(self.content(f).blocks)")
    }

    /// The group that holds step 2 is opened by hand; if the end of the event did not close it, the
    /// next edit would register INTO it and one undo would take the paste away with the typing.
    func testAnEditAfterThePasteIsAStepOfItsOwn() throws {
        let f = try self.fixture(ChatInputContent(), caret: nil)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("- one\n- two", into: f)
        XCTAssertEqual(self.listItemCount(self.content(f)), 2, "precondition: the list did not land: \(self.content(f).blocks)")
        let keyInput = try XCTUnwrap(f.textView as? UIKeyInput)
        keyInput.insertText("X")
        HarnessEngine.settle(f.root)
        XCTAssertTrue(self.content(f).plainText.contains("twoX"), "precondition: typing did not land after the paste: \(self.content(f).blocks)")

        f.undoManager.undo()
        HarnessEngine.settle(f.root)
        XCTAssertFalse(self.content(f).plainText.contains("X"), "undo did not remove the typing: \(self.content(f).blocks)")
        XCTAssertEqual(self.listItemCount(self.content(f)), 2, "one undo took the paste away with the typing: \(self.content(f).blocks)")
    }

    func testStructuralMarkdownPastedMidParagraphSplitsItAroundTheBlocks() throws {
        // "Hello |world"
        let f = try self.fixture(ChatInputContent(blocks: [HarnessEngine.paragraph("Hello world")]), caret: 6)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("- one\n- two", into: f)
        let result = self.content(f)
        XCTAssertFalse(result.plainText.contains("- "), "the list markers were pasted literally: \(result.blocks)")
        XCTAssertEqual(self.listItemCount(result), 2, "the list did not become a list: \(result.blocks)")
        let texts = result.blocks.compactMap { block -> String? in
            if case let .paragraph(paragraph) = block {
                return paragraph.runs.map(\.text).joined()
            }
            return nil
        }
        XCTAssertEqual(texts.first, "Hello ", "the head of the host paragraph was not kept before the list: \(result.blocks)")
        XCTAssertEqual(texts.last, "world", "the tail of the host paragraph was not kept after the list: \(result.blocks)")
    }

    func testInlineMarkdownPastedMidParagraphFoldsIntoIt() throws {
        let f = try self.fixture(ChatInputContent(blocks: [HarnessEngine.paragraph("Hello world")]), caret: 6)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("**bold** text ", into: f)
        let result = self.content(f)
        XCTAssertEqual(result.blocks.count, 1, "inline markdown split the host paragraph: \(result.blocks)")
        XCTAssertFalse(result.plainText.contains("**"), "the bold markers were pasted literally: \(result.blocks)")
        XCTAssertTrue(result.plainText.hasPrefix("Hello bold text"), "the paste did not land at the caret: \(result.plainText)")
        XCTAssertTrue(result.plainText.hasSuffix("world"), "the host paragraph's tail was lost: \(result.plainText)")
        guard case let .paragraph(paragraph)? = result.blocks.first else {
            return XCTFail("the host is no longer a paragraph: \(result.blocks)")
        }
        XCTAssertTrue(paragraph.runs.contains { $0.text == "bold" && $0.attributes.bold },
                      "the bold span did not become bold: \(paragraph.runs)")
    }

    func testPlainProsePastesLiterally() throws {
        let f = try self.fixture(ChatInputContent(blocks: [HarnessEngine.paragraph("Hello world")]), caret: 6)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("just some words", into: f)
        let result = self.content(f)
        XCTAssertEqual(result.blocks.count, 1, "plain prose became structure: \(result.blocks)")
        XCTAssertTrue(result.plainText.contains("just some words"), "the plain text did not land: \(result.plainText)")
        XCTAssertTrue(result.plainText.hasPrefix("Hello ") && result.plainText.hasSuffix("world"),
                      "the host paragraph was not kept around the paste: \(result.plainText)")

        f.undoManager.undo()
        HarnessEngine.settle(f.root)
        XCTAssertEqual(self.content(f).plainText, "Hello world", "one undo did not remove a plain paste: \(self.content(f).plainText)")
    }

    func testMarkdownPastedIntoACodeBlockStaysLiteral() throws {
        // Flat axis: "Intro" 0..<5, then the code body from 6; 10 is "let |x = 1".
        let f = try self.fixture(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]), caret: 10)
        defer { _ = f.node.resignInputFirstResponder() }

        self.paste("# Title\n**b** ", into: f)
        let blocks = self.content(f).blocks
        XCTAssertEqual(blocks.count, 2, "the paste changed the block structure: \(blocks)")
        guard case let .code(code)? = blocks.last else {
            return XCTFail("the last block is no longer the code block: \(blocks)")
        }
        XCTAssertEqual(code.text, "let # Title\n**b** x = 1", "markdown pasted into code was not kept literally")
    }
}
