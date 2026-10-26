import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** Copying PART of a list item (a word, any range inside one item) and pasting it
/// inside another line splits that line in three, the pasted text becoming a list item of its own:
///
///     [• "one"] [• "two"], copy "ne" (1..<3), paste after "t"
///       engine:   [• "one"] [• "t"] [• "ne"] [• "wo"]
///       expected: [• "one"] [• "tnewo"]
///     [• "one two"], copy "two", paste after "one" → [• "one"] [• "two"] [• " two"]
///     [☑ "done"] [☐ "todo"], copy "on", paste after "to" → [☑ done] [☐ to] [☑ on] [☐ do]
///     [• "one"] [p "two"], copy "on", paste after "t" → [• one] [p t] [• on] [p wo]
///
/// A word copied from a plain paragraph splices inline into an item (control). A stock `UITextView`
/// pastes a partial copy inline and the host paragraph keeps its own paragraph style. A heading's
/// partial copy shatters the same way (`[h1 "Title"]`, copy "it", paste in a body line →
/// `[p t] [h1 it] [p wo]`); `isInlineMergeable` keeps a heading block whole BY DECISION for copied
/// whole headings ("pasting a copied rich message loses its headings"), so that face is left to the
/// fix wave to decide and not asserted here.
///
/// **How it was seen.** p16 roam, 2026-09-25, hosted probes of copy/paste across block kinds.
///
/// **Suspected cause.** `Document.extractFragment` (Core, `DocumentFragment.swift`) gives a range inside
/// ONE list item's text a paragraph that keeps the item's `list` membership, and
/// `isInlineMergeable` refuses any paragraph with `list != nil`, so `insertingFragment` places it as a
/// block, splitting the host. A fragment that covers no paragraph break is text, not a block.
///
/// **Tier 1**: Copy and Paste are the edit-menu actions on the engine view; the pasteboard is written
/// by the Copy before anything reads it.
final class HarnessPartialFragmentPasteTests: XCTestCase {
    private typealias S = HarnessP16

    private func copyPaste(_ blocks: [ChatInputBlock], copy: (Int, Int), at caret: Int) throws -> ChatInputContent {
        let arranged = try S.arrange(blocks)
        defer { S.finish(arranged) }
        S.select(arranged, copy.0, copy.1)
        S.perform(arranged, #selector(UIResponderStandardEditActions.copy(_:)))
        S.select(arranged, caret, caret)
        S.perform(arranged, #selector(UIResponderStandardEditActions.paste(_:)))
        return S.content(arranged)
    }

    private func assertContent(_ content: ChatInputContent, _ expected: [ChatInputBlock], _ message: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(S.describe(content), S.describe(ChatInputContent(blocks: expected)), message, file: file, line: line)
    }

    func testAWordFromAListItemPastesInlineIntoAnotherItem() throws {
        let content = try self.copyPaste([S.item("one"), S.item("two")], copy: (1, 3), at: 5)
        self.assertContent(content, [S.item("one"), S.item("tnewo")], "a word copied from a list item split the item it was pasted into")
    }

    func testAWordFromAListItemPastesInlineIntoItsOwnItem() throws {
        let content = try self.copyPaste([S.item("one two")], copy: (4, 7), at: 3)
        self.assertContent(content, [S.item("onetwo two")], "a word pasted back into its own list item split it")
    }

    func testAWordFromAChecklistItemPastesInlineIntoAnotherItem() throws {
        let content = try self.copyPaste([S.item("done", .checklist, checked: true), S.item("todo", .checklist, checked: false)], copy: (1, 3), at: 7)
        self.assertContent(content, [S.item("done", .checklist, checked: true), S.item("toondo", .checklist, checked: false)],
                           "a word copied from a checked item became a checked item of its own")
    }

    func testAWordFromAListItemPastesInlineIntoAParagraph() throws {
        let content = try self.copyPaste([S.item("one"), S.paragraph("two")], copy: (0, 2), at: 5)
        self.assertContent(content, [S.item("one"), S.paragraph("tonwo")], "a word copied from a list item became a list item inside a paragraph")
    }

    /// Control: a word from a plain paragraph splices inline into a list item.
    func testControlAWordFromAParagraphPastesInlineIntoAnItem() throws {
        let content = try self.copyPaste([S.paragraph("one"), S.item("two")], copy: (0, 3), at: 5)
        self.assertContent(content, [S.paragraph("one"), S.item("tonewo")], "control")
    }

    /// Control (p16 fix wave): ALL of an item's text still copies as the item — the partial-copy rule is
    /// for a part of one item only.
    func testControlAllOfAnItemsTextPastesAsAnItem() throws {
        let content = try self.copyPaste([S.item("one"), S.paragraph("xy")], copy: (0, 3), at: 6)
        self.assertContent(content, [S.item("one"), S.paragraph("xy"), S.item("one")], "control")
    }

    /// Control (p16 fix wave): a copy across two checklist items pastes as the two items, checks kept.
    func testControlSeveralItemsPasteAsItems() throws {
        let content = try self.copyPaste([S.item("one", .checklist, checked: true), S.item("two", .checklist, checked: false), S.paragraph("xy")],
                                         copy: (0, 7), at: 10)
        self.assertContent(content, [S.item("one", .checklist, checked: true), S.item("two", .checklist, checked: false), S.paragraph("xy"),
                                     S.item("one", .checklist, checked: true), S.item("two", .checklist, checked: false)], "control")
    }

    /// Oracle: a stock `UITextView` pastes a partial copy of a styled paragraph inline, the host
    /// paragraph keeping its own style.
    func testControlStockPastesAPartialCopyInline() throws {
        let root = try HarnessEngine.root()
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 120.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        let indented = NSMutableParagraphStyle()
        indented.headIndent = 20.0
        indented.firstLineHeadIndent = 20.0
        let text = NSMutableAttributedString(string: "one\n", attributes: [.font: UIFont.systemFont(ofSize: 17.0), .paragraphStyle: indented])
        text.append(NSAttributedString(string: "two", attributes: [.font: UIFont.systemFont(ofSize: 17.0)]))
        textView.smartInsertDeleteType = .no
        textView.attributedText = text
        _ = textView.becomeFirstResponder()
        textView.selectedRange = NSRange(location: 0, length: 2)
        textView.copy(nil)
        HarnessEngine.settle(root, seconds: 0.2)
        textView.selectedRange = NSRange(location: 5, length: 0)
        textView.paste(nil)
        // UITextView's paste lands asynchronously.
        let deadline = Date().addingTimeInterval(3.0)
        while textView.text == "one\ntwo" && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(textView.text, "one\ntonwo", "oracle: inline")
        let style = textView.attributedText.attribute(.paragraphStyle, at: 4, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.headIndent ?? 0.0, 0.0, "oracle: the host paragraph keeps its own style")
    }
}
