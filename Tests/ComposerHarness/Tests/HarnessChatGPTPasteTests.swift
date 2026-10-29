import XCTest
import UIKit
import TelegramCore
@testable import ComposerHarnessLib

/// **What broke (#70).** A reply copied with ChatGPT's Copy button is markdown text with one "**Key:** value"
/// per line and blank lines between paragraphs. Markdown on paste read it as CommonMark: the single newlines
/// became spaces ("Position: Private Household Butler Employment: Full-time") and the blank lines were dropped,
/// so the message went out as one block.
///
/// **Now.** The paste reads line breaks as written (`MarkdownSourceLineBreaks.keep`); the source's blank lines
/// stay when the content is sent as text + entities, and a rich message (heading, list) gets none.
///
/// **Tier 1**: `paste(_:)` is what the edit menu calls, and the pasteboard is this process's own.
final class HarnessChatGPTPasteTests: XCTestCase {
    private func paste(_ text: String) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }

        UIPasteboard.general.string = text
        let textView = try HarnessEngine.textView(in: root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)
        return node.currentInputContent().content
    }

    func testKeyValueLinesAndBlankLinesSurviveAnInlineOnlyPaste() throws {
        let content = try self.paste("**Position Summary**\n\n**Position:** Private Household Butler\n**Employment:** Full-time\n\nWe are looking for a candidate.")
        XCTAssertEqual(content.plainText, "Position Summary\n\nPosition: Private Household Butler\nEmployment: Full-time\n\nWe are looking for a candidate.", "\(content.blocks)")
        XCTAssertTrue(content.isEntityExpressible())
    }

    func testRichPasteKeepsLineBreaksButGetsNoBlankLines() throws {
        let content = try self.paste("### Position Summary\n\n**Position:** Private Household Butler\n**Employment:** Full-time\n\n- one\n- two\n\nWe are looking for a candidate.")
        XCTAssertEqual(content.plainText, "Position Summary\nPosition: Private Household Butler\nEmployment: Full-time\none\ntwo\nWe are looking for a candidate.", "\(content.blocks)")
        XCTAssertFalse(content.isEntityExpressible())
    }

    /// A `---` between sections has no source position and no form in the composer: it is the blank line.
    func testThematicBreakBetweenInlineOnlySectionsIsABlankLine() throws {
        let content = try self.paste("**Salary:** Competitive\n\n---\n\n**Day Off:** 1 day per week")
        XCTAssertEqual(content.plainText, "Salary: Competitive\n\nDay Off: 1 day per week", "\(content.blocks)")
    }
}
