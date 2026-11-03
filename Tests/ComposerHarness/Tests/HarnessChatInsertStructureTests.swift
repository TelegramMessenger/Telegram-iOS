import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatPresentationInterfaceState
import ChatInputTextNode
import ChatTextInputPanelNode
@testable import ComposerHarnessLib

/// **What broke (CORRUPTS THE SENT MODEL).** On the engine backend, two of the chat's own edits rebuild
/// the WHOLE composer through the `NSAttributedString` compat currency and so destroy every structure
/// that currency cannot express. They are:
/// - an emoji tapped on the chat's emoji keyboard, static or custom
///   (`ChatControllerLoadDisplayNode`'s `insertText` closure);
/// - the avatar context menu's Mention (`chatTextInputAddMentionAttribute`).
///
///     [h1 "Title"] [p "Hi"], caret at the end, tap 😀   → [p "Title"] [p "Hi😀"]   (heading lost)
///     [• one] [• two], tap 😀                           → [p "one"] [p "two😀"]    (list lost)
///     [p "Intro"] [table …] [p "Hi"], tap 😀            → the table is gone
///     typing 😀 at the same caret (the oracle)            → structure intact
///
/// The closure reads `textInputState.inputText`, replaces the flat selection in it, and hands the
/// result to `ChatTextInputState(inputText:selectionRange:)`. The doc comment on `inputText` warns that
/// this "retypes every block as a body paragraph". The p15 follow-up made these paths one undo step
/// (`HarnessChatSideEditUndoTests`) but drove them over a plain "Hi" only, where the rebuild is
/// lossless. The ⌘B shortcuts had the same shape (findings row 81) and were fixed by routing them to
/// the engine's own commands. Mention autocomplete, hashtag, command, emoji search and Translate with
/// a selection use `replacingFlatRange` and keep structure (the controls below).
///
/// A second face: with the caret in a block that is OFF the composer's flat axis (a table cell, a
/// media caption, a details title or body), the node reports the caret at the end of the flat text
/// (the documented rule, `isOnComposerAxis`). So the emoji is inserted at the end of the last
/// paragraph instead of in the cell the user is typing in.
///
/// **How it was seen.** p18 roam: auditing every `ChatTextInputState(inputText:)` built from an existing
/// state in the chat sources (`rg "ChatTextInputState\(inputText:"`).
///
/// **Cause.** `ChatControllerLoadDisplayNode.swift` `insertText:` and `ChatTextFormat.swift`
/// `chatTextInputAddMentionAttribute` had no engine branch (the link editor did, `openLinkEditing`).
///
/// **Fixed (2026-09-25).** Both now go through ONE decision, `chatComposerInsertTextOnUsersBehalf` /
/// `chatComposerInsertMention` (`ChatTextInputPanelNode/Sources/ChatComposerUserInserts.swift`), which
/// asks the input node first: the engine inserts at its OWN selection through
/// `RichTextEditor.insertInlineRunsOnUsersBehalf` (typing for text, `insertEmoji` for a custom emoji,
/// `setLink` over a mention), as one undo step; a node that declines (legacy) keeps the old flat
/// transform, moved verbatim to `chatTextInputStateInsertingText`.
///
/// **Tier 1.** These tests call the SAME functions the chat calls (`HarnessChatInserts`), handed the
/// harness panel's node and its interaction — no copy of the chat's closure is left to drift.
@available(iOS 18.4, *)
final class HarnessChatInsertStructureTests: XCTestCase {
    typealias Insert = (HarnessPanelHost) -> Void

    // MARK: - Driving

    private struct Outcome {
        let viaChat: ChatInputContent
        let typed: ChatInputContent
    }

    /// Arranges `content`, puts the caret at `caret` (engine axis), applies `insert` as the chat does;
    /// then re-arranges and TYPES `typed` at the same caret (the oracle).
    private func run(_ content: ChatInputContent, caret: Int?, insert: Insert, typed: String) throws -> Outcome {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        func place() {
            let caretOffset = caret ?? (driver.viewText() as NSString).length
            driver.setViewSelection(NSRange(location: caretOffset, length: 0))
            driver.settle(0.2)
        }
        driver.arrange(content)
        place()
        insert(driver.host)
        driver.settle(0.3)
        let viaChat = FuzzModel.normalized(driver.model())

        driver.arrange(content)
        place()
        driver.insert(typed)
        driver.settle(0.3)
        let typedModel = FuzzModel.normalized(driver.model())
        return Outcome(viaChat: viaChat, typed: typedModel)
    }

    private func assertSame(_ outcome: Outcome, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(outcome.viaChat, outcome.typed,
                       "\(what): the chat's edit did not do what typing the same text does\n  chat  \(HarnessP16.describe(outcome.viaChat))\n  typed \(HarnessP16.describe(outcome.typed))",
                       file: file, line: line)
    }

    private static let emoji = NSAttributedString(string: "😀")

    private static func table() -> ChatInputBlock {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        return .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
            ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Value")]),
            ChatInputTableRow(cells: [cell("alpha"), cell("1")]),
        ]))
    }

    // MARK: - Emoji keyboard, structure elsewhere in the composer

    func testEmojiKeyboardKeepsAHeading() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Title", style: .heading1), HarnessP16.paragraph("Hi")])
        self.assertSame(try self.run(content, caret: nil, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "heading")
    }

    func testEmojiKeyboardKeepsAList() throws {
        let content = ChatInputContent(blocks: [HarnessP16.item("one"), HarnessP16.item("two")])
        self.assertSame(try self.run(content, caret: nil, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "list")
    }

    func testEmojiKeyboardKeepsATable() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Intro"), Self.table(), HarnessP16.paragraph("Hi")])
        self.assertSame(try self.run(content, caret: nil, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "table")
    }

    func testEmojiKeyboardKeepsAPullQuoteAuthor() throws {
        let content = ChatInputContent(blocks: [
            HarnessP16.paragraph("Hi"),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Words to live by.")], author: [ChatInputRun(text: "Someone")])),
        ])
        self.assertSame(try self.run(content, caret: 2, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "pull quote")
    }

    func testCustomEmojiKeyboardKeepsAHeading() throws {
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
        let custom = NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: attribute])
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Title", style: .heading1), HarnessP16.paragraph("Hi")])
        let outcome = try self.run(content, caret: nil, insert: HarnessChatInserts.emojiKeyboard(custom), typed: "😀")
        guard case let .paragraph(first)? = outcome.viaChat.blocks.first else {
            return XCTFail("no first paragraph: \(HarnessP16.describe(outcome.viaChat))")
        }
        XCTAssertEqual(first.style, .heading1, "a custom emoji from the chat's keyboard demoted the heading: \(HarnessP16.describe(outcome.viaChat))")
    }

    // MARK: - Emoji keyboard, caret in a block off the flat axis

    /// The caret is at the end of the table's last cell ("1"); typing puts the emoji there.
    func testEmojiKeyboardInsertsIntoTheTableCellWithTheCaret() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Intro"), Self.table(), HarnessP16.paragraph("Hi")])
        // Engine axis: "Intro\nName\nValue\nalpha\n1\nHi"; the end of "1" is 23.
        self.assertSame(try self.run(content, caret: 23, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "caret in a cell")
    }

    // MARK: - Avatar context menu ▸ Mention

    func testContextMenuMentionKeepsAHeading() throws {
        let peer = EnginePeer(HarnessPanelHost.chatPeer)
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Title", style: .heading1), HarnessP16.paragraph("Hi ")])
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(content)
        driver.settle(0.2)
        HarnessChatInserts.contextMenuMention(peer)(driver.host)
        driver.settle(0.3)
        let model = FuzzModel.normalized(driver.model())
        XCTAssertTrue(model.plainText.hasSuffix(peer.compactDisplayTitle + " "), "precondition: the mention did not land: \(HarnessP16.describe(model))")
        guard case let .paragraph(first)? = model.blocks.first else {
            return XCTFail("no first paragraph: \(HarnessP16.describe(model))")
        }
        XCTAssertEqual(first.style, .heading1, "the context menu's Mention demoted the heading: \(HarnessP16.describe(model))")
    }

    // MARK: - What the chat's old transform did right, kept by the insert through the node

    /// A custom emoji tapped inside a SPOILER stays inside it: the old flat transform inherited the
    /// spoiler from the character before the caret (a device trace, `"Qwfe"/sp=1 EMOJI/sp=0`, is why),
    /// and the engine insert must too — typing a plain character there inherits it through the
    /// typed-text policy, but an atom does not go in by typing.
    func testCustomEmojiKeyboardInsideASpoilerStaysHidden() throws {
        let spoiler = ChatInputInlineAttributes(spoiler: true)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "Qwfe", attributes: spoiler), ChatInputRun(text: "qwffqw", attributes: spoiler),
        ]))])
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
        let custom = NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: attribute])
        let outcome = try self.run(content, caret: 4, insert: HarnessChatInserts.emojiKeyboard(custom), typed: "😀")
        guard case let .paragraph(paragraph)? = outcome.viaChat.blocks.first else {
            return XCTFail("no paragraph: \(HarnessP16.describe(outcome.viaChat))")
        }
        let emojiRuns = paragraph.runs.filter { if case .customEmoji = $0.attributes.entity { return true } else { return false } }
        XCTAssertEqual(emojiRuns.count, 1, "precondition: the custom emoji did not land: \(HarnessP16.describe(outcome.viaChat))")
        XCTAssertTrue(paragraph.runs.allSatisfy { $0.attributes.spoiler },
                      "a custom emoji inserted inside a spoiler split it: \(HarnessP16.describe(outcome.viaChat))")
    }

    /// The avatar menu's Mention is usually chosen with the keyboard DOWN — the editor is not first
    /// responder — and the insert through the node must land there too.
    func testContextMenuMentionWithTheEditorUnfocusedKeepsAHeading() throws {
        let peer = EnginePeer(HarnessPanelHost.chatPeer)
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Title", style: .heading1), HarnessP16.paragraph("Hi ")])
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(content)
        driver.settle(0.2)
        _ = driver.node.resignInputFirstResponder()
        driver.settle(0.2)
        XCTAssertFalse(driver.node.isInputFirstResponder, "precondition: the editor is still focused")
        HarnessChatInserts.contextMenuMention(peer)(driver.host)
        driver.settle(0.3)
        let model = FuzzModel.normalized(driver.model())
        XCTAssertTrue(model.plainText.hasSuffix(peer.compactDisplayTitle + " "), "the mention did not land with the editor unfocused: \(HarnessP16.describe(model))")
        guard case let .paragraph(first)? = model.blocks.first else {
            return XCTFail("no first paragraph: \(HarnessP16.describe(model))")
        }
        XCTAssertEqual(first.style, .heading1, "the context menu's Mention demoted the heading: \(HarnessP16.describe(model))")
    }

    // MARK: - Controls

    /// Control: the same insert into plain paragraphs is what typing does.
    func testControlEmojiKeyboardOverPlainParagraphs() throws {
        let content = HarnessContent.plainText("First\nHi")
        self.assertSame(try self.run(content, caret: nil, insert: HarnessChatInserts.emojiKeyboard(Self.emoji), typed: "😀"), "plain")
    }

    /// Control: a chat edit that goes through `replacingFlatRange` (mention autocomplete) keeps a
    /// heading.
    func testControlMentionAutocompleteKeepsAHeading() throws {
        let content = ChatInputContent(blocks: [HarnessP16.paragraph("Title", style: .heading1), HarnessP16.paragraph("Hi @al")])
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(content)
        driver.settle(0.2)
        driver.host.panel.interfaceInteraction?.updateTextInputStateAndMode(
            HarnessChatSideEditUndoTests.mentionAutocomplete(peerId: HarnessPanelHost.chatPeer.id, title: "Alice"))
        driver.settle(0.3)
        let model = FuzzModel.normalized(driver.model())
        XCTAssertTrue(model.plainText.hasSuffix("Alice "), "precondition: the completion did not land: \(HarnessP16.describe(model))")
        guard case let .paragraph(first)? = model.blocks.first else {
            return XCTFail("no first paragraph: \(HarnessP16.describe(model))")
        }
        XCTAssertEqual(first.style, .heading1)
    }

    /// Control, the LEGACY composer: the node declines the insert, so the shared decision takes the flat
    /// transform — the chat's old closure body, moved verbatim to `chatTextInputStateInsertingText` — and
    /// the composer ends exactly where that transform puts it.
    func testControlLegacyEmojiKeyboardTakesTheFlatTransform() throws {
        let arranged = try HarnessLegacy.arrange(HarnessContent.plainText("Hi there"))
        defer { HarnessLegacy.restore(arranged) }
        HarnessLegacy.select(arranged, NSRange(location: 2, length: 0))
        HarnessEngine.settle(arranged.root)
        XCTAssertFalse(arranged.node.insertTextOnUsersBehalf(NSAttributedString(string: "")),
                       "precondition: the legacy node takes the insert itself")
        let before = arranged.host.interfaceState.interfaceState.effectiveInputState
        let expected = chatTextInputStateInsertingText(before, text: Self.emoji).content
        HarnessChatInserts.emojiKeyboard(Self.emoji)(arranged.host)
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(HarnessLegacy.content(arranged), expected)
        XCTAssertEqual(HarnessLegacy.content(arranged).plainText, "Hi😀 there")
    }
}

/// The chat's inserts on the user's behalf, as the chat makes them: the SAME shared functions its
/// closures call (`ChatComposerUserInserts.swift`), handed the harness panel's input node and
/// interaction. Used by this file, `HarnessChatSideEditUndoTests` and the fuzz's `chatInsert` op (not
/// availability-gated, so the fuzz can reach it).
enum HarnessChatInserts {
    /// `ChatControllerLoadDisplayNode`'s `insertText` — the chat's emoji keyboard.
    static func emojiKeyboard(_ text: NSAttributedString) -> (HarnessPanelHost) -> Void {
        return { host in
            guard let interfaceInteraction = host.panel.interfaceInteraction else {
                XCTFail("the harness panel has no interface interaction")
                return
            }
            chatComposerInsertTextOnUsersBehalf(text, richTextInputNode: host.panel.richTextInputNode, interfaceInteraction: interfaceInteraction)
        }
    }

    /// `ChatController`'s avatar context menu ▸ Mention.
    static func contextMenuMention(_ peer: EnginePeer) -> (HarnessPanelHost) -> Void {
        return { host in
            chatComposerInsertMention(peer, richTextInputNode: host.panel.richTextInputNode, interfaceInteraction: host.panel.interfaceInteraction)
        }
    }
}
