import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** Copying a TABLE out of the engine composer writes a plain-text representation with
/// the table's cells missing: `para before / | A | B | / | 1 | 2 | / para after`, Select All → Copy puts
/// `"para before\n\npara after"` in `public.utf8-plain-text`, and a selection covering only the table
/// puts `""`. Within the app nothing is lost (the private fragment type carries the table, and pasting
/// it into either composer restores it — checked on legacy too); any destination that reads plain text
/// gets an empty line where the table was.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam: a table made by markdown paste, `selectAll:` /
/// a selection inside the cells, `copy:` through lldb, then `UIPasteboard.general.string`. Seen 2×
/// (whole document, cells only).
///
/// **Suspected cause.** `RichTextEditorClipboard.pasteboardItem(for:)` builds the plain text with
/// `externalChecklistPlainText` → `blockPlainText`, whose `default` arm answers `""` for a table (and a
/// medium). Core already has `tableFlattenedText(_:)` (one line per row, used by "Copy Table") that could
/// supply the cells.
///
/// **Tier 1**: `copy(_:)` is what the edit menu calls; the pasteboard is this process's own.
final class HarnessTableCopyPlainTextTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testCopyingATableKeepsItsCellsInThePlainText() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        let textView = try HarnessEngine.textView(in: root)

        // The table comes from the composer's own markdown paste, so no table fixture is hand-built here.
        UIPasteboard.general.string = "para before\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\npara after"
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)
        let hasTable = node.currentInputContent().content.blocks.contains { block in
            if case .table = block { return true }
            return false
        }
        XCTAssertTrue(hasTable, "precondition: the markdown table did not become a table: \(node.currentInputContent().content.blocks)")

        _ = textView.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(root)

        let plain = UIPasteboard.general.string ?? ""
        XCTAssertTrue(plain.contains("para before") && plain.contains("para after"), "precondition: the copy did not happen: \(plain.debugDescription)")
        for cell in ["A", "B", "1", "2"] {
            XCTAssertTrue(plain.components(separatedBy: CharacterSet.alphanumerics.inverted).contains(cell),
                          "the plain-text copy lost the table cell \(cell): \(plain.debugDescription)")
        }
    }
}
