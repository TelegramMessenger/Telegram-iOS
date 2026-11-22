import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke (CORRUPTS THE SENT MODEL).** Return with the caret at the START of a CHECKED checklist
/// item opens the new line above it, but the CHECK stays on the new empty line and the item's own
/// text becomes unchecked:
///
///     [☐ "todo"] [☑ "done"], caret before "done", Return
///       engine:   [☐ "todo"] [☑ ""] [☐ "done"]
///       expected: [☐ "todo"] [☐ ""] [☑ "done"]     (the item keeps its state; the new line is fresh)
///
/// The same at level 1. Sending then marks the wrong task done. Return at the END of a checked item
/// is right (a fresh unchecked item below; control inside), and an ordered item split at its start
/// is shape-only (control). The same product rule already exists for headings: Return at offset 0
/// opens an empty line above and keeps the block (`HarnessHeadingReturnAtStartTests`). Related, not
/// asserted: Return in the MIDDLE of a checked item leaves the tail unchecked (`[☑ "b"] [☐ "ee"]`).
///
/// **How it was seen.** p16 roam, 2026-09-25, hosted probes of checklist editing.
///
/// **Suspected cause.** The split keeps the block identity (and so the role, with `checked`) on the
/// upper, emptied half; the lower half is a block minted by the edit and gets the list
/// continuation's fresh membership (`checked: false`) — the list-continuation reconciliation in
/// `RichTextEngineEditorView+Paragraph.swift` / `decideReturnInListItem` (`+Lists.swift`) has no rule
/// for a caret at an item's start.
///
/// **Tier 1**: Return is `insertText("\n")` on the engine view, as the keyboard sends it.
final class HarnessChecklistReturnAtStartTests: XCTestCase {
    private typealias S = HarnessP16

    private func returnAt(_ caret: Int, in blocks: [ChatInputBlock]) throws -> ChatInputContent {
        let arranged = try S.arrange(blocks)
        defer { S.finish(arranged) }
        S.select(arranged, caret, caret)
        S.type(arranged, "\n")
        return S.content(arranged)
    }

    func testReturnAtTheStartOfACheckedItemKeepsItsCheck() throws {
        let content = try self.returnAt(5, in: [S.item("todo", .checklist, checked: false), S.item("done", .checklist, checked: true)])
        XCTAssertEqual(S.describe(content),
                       S.describe(ChatInputContent(blocks: [S.item("todo", .checklist, checked: false), S.item("", .checklist, checked: false),
                                                            S.item("done", .checklist, checked: true)])),
                       "Return at the start of a checked item moved its check onto the new empty line")
    }

    func testReturnAtTheStartOfANestedCheckedItemKeepsItsCheck() throws {
        let content = try self.returnAt(0, in: [S.item("done", .checklist, level: 1, checked: true)])
        XCTAssertEqual(S.describe(content),
                       S.describe(ChatInputContent(blocks: [S.item("", .checklist, level: 1, checked: false),
                                                            S.item("done", .checklist, level: 1, checked: true)])),
                       "Return at the start of a nested checked item moved its check onto the new empty line")
    }

    /// Control: Return at the end of a checked item leaves it checked and opens a fresh item below.
    func testControlReturnAtTheEndOfACheckedItem() throws {
        let content = try self.returnAt(4, in: [S.item("done", .checklist, checked: true)])
        XCTAssertEqual(S.describe(content),
                       S.describe(ChatInputContent(blocks: [S.item("done", .checklist, checked: true), S.item("", .checklist, checked: false)])))
    }

    /// Control: an ordered item split at its start keeps its shape on both halves.
    func testControlReturnAtTheStartOfAnOrderedItem() throws {
        let content = try self.returnAt(0, in: [S.item("done", .ordered)])
        XCTAssertEqual(S.describe(content), S.describe(ChatInputContent(blocks: [S.item("", .ordered), S.item("done", .ordered)])))
    }
}
