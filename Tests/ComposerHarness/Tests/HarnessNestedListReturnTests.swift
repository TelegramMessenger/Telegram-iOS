import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Return on an EMPTY NESTED list item ends the list outright
/// instead of outdenting the item one level:
///
///     1. a
///        1. b|        Return → empty level-1 item → Return again
///       engine: [ordered 0 "a"] [ordered 1 "b"] [p ""]            (list ended; a following item restarts at 1.)
///       expected: [ordered 0 "a"] [ordered 1 "b"] [ordered 0 ""]  (outdented, still in the list)
///
/// The legacy rich editor outdents here (`DocumentCanvasView.insertParagraphBreak`: "a nested item
/// outdents one level, a top-level one ends the list"), shows "Press return to outdent" on such an item,
/// and the engine's own Backspace rule at an item's start already outdents first
/// (`applyBackspaceAtStartOfListItem`). Only Return skips the outdent step. Mid-list it also splits the
/// list in two: `1. a / 1. b / 2. c / 2. d`, Return twice after "c" gives a body paragraph between "c" and
/// "d", and "d" restarts at 1.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam: lists made by markdown paste (`- one / - two /   - nested`
/// and `1. a /    1. b /    2. c / 2. d`), `insertText:@"\n"` twice on the engine text view through lldb.
/// Seen 3× (1× bullet, 2× ordered). The level-0 case ends the list, as designed (control below).
///
/// **Suspected cause.** `decideReturnInListItem` (`RichTextEngineEditorView+Lists.swift`) calls
/// `endList(at:)` for ANY empty item, never `outdentItem` for `level > 0`.
///
/// **Tier 1**: `insertText("\n")` is the keyboard's Return; the model is readable in-process.
final class HarnessNestedListReturnTests: XCTestCase {
    private func item(_ text: String, level: Int32, marker: ChatInputListMarker = .ordered) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker, level: level),
                                             runs: text.isEmpty ? [] : [ChatInputRun(text: text)]))
    }

    /// Arranges `blocks`, puts the caret at `caret`, presses Return `count` times and returns the model.
    private func pressReturn(_ blocks: [ChatInputBlock], caret: Int, count: Int) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: caret, length: 0), "precondition: the caret did not land")

        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        for _ in 0 ..< count {
            keyInput.insertText("\n")
            HarnessEngine.settle(root)
        }
        return node.currentInputContent().content
    }

    private func membership(_ block: ChatInputBlock) -> ChatInputListMembership? {
        if case let .paragraph(paragraph) = block {
            return paragraph.list
        }
        return nil
    }

    func testReturnOnAnEmptyNestedItemOutdentsIt() throws {
        // "a\nb": the caret at the end of "b" is 3.
        let content = try self.pressReturn([self.item("a", level: 0), self.item("b", level: 1)], caret: 3, count: 2)
        XCTAssertEqual(content.blocks.count, 3, "expected a, b and one new item: \(content.blocks)")
        guard content.blocks.count == 3 else { return }
        let last = self.membership(content.blocks[2])
        XCTAssertNotNil(last, "Return on an empty NESTED item ended the list instead of outdenting it: \(content.blocks)")
        XCTAssertEqual(last?.level, 0, "the empty nested item was not outdented one level: \(content.blocks)")
        XCTAssertEqual(last?.marker, .ordered, "the outdented item changed its marker: \(content.blocks)")
    }

    func testReturnOnAnEmptyNestedItemMidListKeepsTheListWhole() throws {
        // "a\nb\nc\nd": the caret at the end of "c" is 5.
        let content = try self.pressReturn([
            self.item("a", level: 0), self.item("b", level: 1), self.item("c", level: 1), self.item("d", level: 0),
        ], caret: 5, count: 2)
        XCTAssertEqual(content.blocks.count, 5, "expected one new item between c and d: \(content.blocks)")
        XCTAssertTrue(content.blocks.allSatisfy { self.membership($0) != nil },
                      "the list was split by a body paragraph (d now restarts its numbering): \(content.blocks)")
    }

    /// Control: a TOP-LEVEL empty item ends the list, which is the designed double-Return exit.
    func testReturnOnAnEmptyTopLevelItemEndsTheList() throws {
        let content = try self.pressReturn([self.item("a", level: 0, marker: .bullet)], caret: 1, count: 2)
        XCTAssertEqual(content.blocks.count, 2, "\(content.blocks)")
        guard content.blocks.count == 2 else { return }
        XCTAssertNil(self.membership(content.blocks[1]), "the empty top-level item did not end the list: \(content.blocks)")
    }
}
