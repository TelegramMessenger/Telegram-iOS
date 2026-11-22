import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatContextQuery
import ChatPresentationInterfaceState
import ChatInputTextNode
import ChatTextInputPanelNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, an edit the USER makes through the chat rather than through
/// the editor wipes the undo stack: mention / hashtag / command autocomplete, an emoji-search
/// suggestion, an emoji tapped on the chat's emoji keyboard, the context menu's "Mention", the date
/// editor, the Commands button and Translate. Each computes a new input state from the current one and
/// hands it to `ChatPanelInterfaceInteraction.updateTextInputStateAndMode`; the chat pushes it back into
/// the panel, and `RichTextEditorChatInputNode.setInputContent` took the differing content for an
/// EXTERNAL set and called `discardUndoHistory()` (the p15 fix for Send's clear and draft syncs):
///
///     "Hi", type " @al", pick "Alice" from the mention list, ⌘Z   → nothing to undo; " @al" is lost too
///     "Hi", tap 😀 on the emoji keyboard, ⌘Z                      → nothing to undo
///
/// A stock text view offers the completion as one undoable step on top of the typing (so does the
/// engine's own paste, Format and link). The legacy composer is a control, not the target: its
/// `attributedText` set drops the typing steps too (see `testControlLegacy…`).
///
/// **How it was seen.** The p15 follow-up (2026-09-25), auditing every content-changing push that
/// reaches `setInputContent` after the p15 fix made that set clear the stack.
///
/// **The distinction the fix draws.** Every `updateTextInputStateAndMode` in the app transforms the
/// CURRENT input state on the user's behalf (`ChatControllerLoadDisplayNode`'s closure is the one
/// implementation). Send's clear, a draft synced from another device, a draft restored on open and an
/// edit-message load reach the panel another way — `updateChatPresentationInterfaceState` →
/// `ChatControllerNode` → `updateInputTextState` — and keep clearing (`HarnessExternalSetUndoTests`).
/// The interaction's closure (the app's, and the harness host's copy of it) runs the transform inside
/// `ChatRichTextInputNode.performUndoableInputChange`, and a push that lands inside that scope is
/// applied as ONE undo step on top of the stack (`RichTextEditor.performAsOneUndoStep`).
///
/// **Tier 1.** Each transform below is the chat's own closure body (TelegramUI is not linkable here, so
/// the few lines each panel runs are repeated over the same public helpers — `textInputStateContextQuery…`,
/// `replacingFlatRange`, `chatTextInputAdd…Attribute`), handed to the panel's interaction exactly as the
/// chat does.
@available(iOS 18.4, *)
final class HarnessChatSideEditUndoTests: XCTestCase {
    typealias Transform = (ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)

    // MARK: - The chat's transforms

    /// `MentionChatInputContextPanelNode`'s `peerSelected` for a peer with no username: the query and its
    /// "@" become the peer's name as a mention entity, then a space.
    static func mentionAutocomplete(peerId: EnginePeer.Id, title: String) -> Transform {
        return { textInputState, inputMode in
            var mentionQueryRange: NSRange?
            inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                if type == [.mention] {
                    mentionQueryRange = range
                    break inner
                }
            }
            if let range = mentionQueryRange {
                let replacementText = NSMutableAttributedString()
                replacementText.append(NSAttributedString(string: title, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peerId)]))
                replacementText.append(NSAttributedString(string: " "))
                let updatedRange = NSRange(location: range.location - 1, length: range.length + 1)
                return (textInputState.replacingFlatRange(updatedRange, with: replacementText), inputMode)
            }
            return (textInputState, inputMode)
        }
    }

    /// `HashtagChatInputContextPanelNode`'s `hashtagSelected`.
    static func hashtagAutocomplete(_ text: String) -> Transform {
        return { textInputState, inputMode in
            for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) where type == [.hashtag] {
                return (textInputState.replacingFlatRange(range, with: text), inputMode)
            }
            return (textInputState, inputMode)
        }
    }

    /// `CommandChatInputContextPanelNode`'s `commandSelected` (not sent immediately).
    static func commandAutocomplete(_ command: String) -> Transform {
        return { textInputState, inputMode in
            for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) where type == [.command] {
                return (textInputState.replacingFlatRange(range, with: command + " "), inputMode)
            }
            return (textInputState, inputMode)
        }
    }

    /// `EmojisChatInputContextPanelNode`'s `emojiSelected` for a plain emoji: ":query" becomes the emoji.
    static func emojiSearchSuggestion(_ emoji: String) -> Transform {
        return { textInputState, inputMode in
            for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) where type == [.emojiSearch] {
                let widened = NSRange(location: range.location - 1, length: range.length + 1)
                return (textInputState.replacingFlatRange(widened, with: NSAttributedString(string: emoji)), inputMode)
            }
            return (textInputState, inputMode)
        }
    }

    // The chat's emoji keyboard and the avatar menu's Mention are NOT transforms any more: both go
    // through the shared decision the chat itself calls (`HarnessChatInserts`,
    // `ChatComposerUserInserts.swift`), which inserts through the engine node.

    /// `ChatControllerLoadDisplayNode`'s `openDateEditing` completion.
    static func addDate(_ selectionRange: Range<Int>, date: Int32) -> Transform {
        return { current, inputMode in
            return (chatTextInputAddDateAttribute(current, selectionRange: selectionRange, date: date), inputMode)
        }
    }

    /// `ChatTextInputPanelNode`'s Commands accessory button.
    static let commandsButton: Transform = { _, _ in
        return (ChatTextInputState(inputText: NSAttributedString(string: "/")), .text)
    }

    /// `ChatTextInputPanelNode._translate`'s completion with a selection.
    static func translateSelection(_ translated: String) -> Transform {
        return { current, _ in
            let range = NSRange(location: current.selectionRange.lowerBound, length: current.selectionRange.count)
            return (current.replacingFlatRange(range, with: NSAttributedString(string: translated)), .text)
        }
    }

    // MARK: - Driving

    private func type(_ driver: EngineFuzzDriver, _ text: String) {
        for character in text {
            driver.insert(String(character))
        }
        driver.settle(0.2)
    }

    private func apply(_ host: HarnessPanelHost, _ transform: @escaping Transform) {
        host.panel.interfaceInteraction?.updateTextInputStateAndMode(transform)
    }

    private func undo(_ driver: EngineFuzzDriver) {
        driver.undoManager?.undo()
        driver.settle(0.2)
    }

    private func redo(_ driver: EngineFuzzDriver) {
        driver.undoManager?.redo()
        driver.settle(0.2)
    }

    /// An interaction transform, applied as the chat applies one.
    private static func viaInteraction(_ transform: @escaping Transform) -> (HarnessPanelHost) -> Void {
        return { host in host.panel.interfaceInteraction?.updateTextInputStateAndMode(transform) }
    }

    /// Arranges `start`, types `typed`, applies `edit` and checks the edit is ONE step on top of the
    /// typing: undo gives back the typed text, undo again the start, and redo replays both.
    private func assertOneUndoableStep(start: String, typed: String, expected: String,
                                       selecting: NSRange? = nil,
                                       edit: (HarnessPanelHost) -> Void,
                                       landed: ((ChatInputContent) -> Bool)? = nil,
                                       file: StaticString = #filePath, line: UInt = #line) throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText(start))
        self.type(driver, typed)
        let typedModel = driver.model()
        XCTAssertEqual(typedModel.plainText, start + typed, "precondition: typing did not land", file: file, line: line)
        if let selecting {
            driver.setViewSelection(selecting)
            driver.settle(0.2)
            XCTAssertEqual(driver.host.interfaceState.interfaceState.effectiveInputState.selectionRange, selecting.location ..< NSMaxRange(selecting),
                           "precondition: the chat's copy of the selection is not the composer's", file: file, line: line)
        }

        edit(driver.host)
        driver.settle(0.2)
        let pushed = driver.model()
        XCTAssertEqual(pushed.plainText, expected, "precondition: the chat's edit did not land", file: file, line: line)
        if let landed {
            XCTAssertTrue(landed(pushed), "precondition: the chat's edit landed without its entity: \(pushed)", file: file, line: line)
        }

        XCTAssertEqual(driver.undoManager?.canUndo, true, "the chat's edit left nothing to undo (the stack was emptied)", file: file, line: line)
        self.undo(driver)
        XCTAssertEqual(driver.model(), typedModel, "one undo after the chat's edit did not restore exactly the text before it", file: file, line: line)
        self.undo(driver)
        XCTAssertEqual(driver.model().plainText, start, "the typing before the chat's edit could not be undone", file: file, line: line)

        self.redo(driver)
        XCTAssertEqual(driver.model(), typedModel, "redo did not replay the typing", file: file, line: line)
        self.redo(driver)
        XCTAssertEqual(driver.model(), pushed, "redo did not replay the chat's edit", file: file, line: line)
    }

    private static func hasMention(_ content: ChatInputContent) -> Bool {
        return content.blocks.contains { block in
            guard case let .paragraph(paragraph) = block else { return false }
            return paragraph.runs.contains { run in
                if case .mention = run.attributes.entity { return true }
                return false
            }
        }
    }

    // MARK: - The paths

    func testMentionAutocompleteIsOneUndoableStep() throws {
        let peerId = HarnessPanelHost.chatPeer.id
        try self.assertOneUndoableStep(start: "Hi", typed: " @al", expected: "Hi Alice ",
                                       edit: Self.viaInteraction(Self.mentionAutocomplete(peerId: peerId, title: "Alice")),
                                       landed: Self.hasMention)
    }

    func testHashtagAutocompleteIsOneUndoableStep() throws {
        try self.assertOneUndoableStep(start: "Hi", typed: " #tel", expected: "Hi #telegram ",
                                       edit: Self.viaInteraction(Self.hashtagAutocomplete("telegram ")))
    }

    func testCommandAutocompleteIsOneUndoableStep() throws {
        try self.assertOneUndoableStep(start: "", typed: "/sta", expected: "/start ",
                                       edit: Self.viaInteraction(Self.commandAutocomplete("start")))
    }

    func testEmojiSearchSuggestionIsOneUndoableStep() throws {
        try self.assertOneUndoableStep(start: "Hi", typed: " :smi", expected: "Hi 😄",
                                       edit: Self.viaInteraction(Self.emojiSearchSuggestion("😄")))
    }

    func testEmojiKeyboardInsertIsOneUndoableStep() throws {
        try self.assertOneUndoableStep(start: "Hi", typed: " there", expected: "Hi there😀",
                                       edit: HarnessChatInserts.emojiKeyboard(NSAttributedString(string: "😀")))
    }

    func testCustomEmojiKeyboardInsertIsOneUndoableStep() throws {
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
        try self.assertOneUndoableStep(start: "Hi", typed: " there", expected: "Hi there😀",
                                       edit: HarnessChatInserts.emojiKeyboard(NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: attribute])),
                                       landed: { content in
            content.blocks.contains { block in
                guard case let .paragraph(paragraph) = block else { return false }
                return paragraph.runs.contains { if case .customEmoji = $0.attributes.entity { return true }; return false }
            }
        })
    }

    func testContextMenuMentionIsOneUndoableStep() throws {
        let peer = EnginePeer(HarnessPanelHost.chatPeer)
        let title = peer.compactDisplayTitle
        try self.assertOneUndoableStep(start: "Hi", typed: " ", expected: "Hi " + title + " ",
                                       edit: HarnessChatInserts.contextMenuMention(peer),
                                       landed: Self.hasMention)
    }

    func testDateEditingIsOneUndoableStep() throws {
        let range = NSRange(location: 5, length: 8)
        try self.assertOneUndoableStep(start: "Meet", typed: " tomorrow", expected: "Meet tomorrow", selecting: range,
                                       edit: Self.viaInteraction(Self.addDate(range.location ..< NSMaxRange(range), date: 1_800_000_000)),
                                       landed: { content in
            content.blocks.contains { block in
                guard case let .paragraph(paragraph) = block else { return false }
                return paragraph.runs.contains { if case .date = $0.attributes.entity { return true }; return false }
            }
        })
    }

    func testCommandsButtonIsOneUndoableStep() throws {
        try self.assertOneUndoableStep(start: "Hi", typed: " there", expected: "/",
                                       edit: Self.viaInteraction(Self.commandsButton))
    }

    func testTranslateIsOneUndoableStep() throws {
        let range = NSRange(location: 3, length: 5)
        try self.assertOneUndoableStep(start: "Hi", typed: " there", expected: "Hi là-bas", selecting: range,
                                       edit: Self.viaInteraction(Self.translateSelection("là-bas")))
    }

    // MARK: - Controls

    /// Control: an edit the EDITOR performs (a link set through the node, which is how the chat's link
    /// editor reaches the engine) is already one step on top of the typing.
    func testControlNativeLinkIsOneUndoableStep() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText("Hi"))
        self.type(driver, " there")
        let typedModel = driver.model()
        driver.setViewSelection(NSRange(location: 3, length: 5))
        driver.settle(0.2)
        driver.node.applyRichTextLink("https://example.org")
        driver.settle(0.2)
        XCTAssertNotEqual(driver.model(), typedModel, "precondition: the link did not land")
        self.undo(driver)
        XCTAssertEqual(driver.model(), typedModel)
        self.undo(driver)
        XCTAssertEqual(driver.model().plainText, "Hi")
    }

    /// Control: a push that does NOT come through the interaction — Send's clear, a draft sync — still
    /// empties the stack (the same case as `HarnessExternalSetUndoTests`, next to its counterpart here).
    func testControlAnExternalSetStillClearsTheStack() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(HarnessContent.plainText("Hi"))
        self.type(driver, " there")
        HarnessExternalSetUndoTests.push(driver.host, HarnessContent.plainText("remote draft"))
        driver.settle(0.2)
        XCTAssertEqual(driver.model().plainText, "remote draft")
        XCTAssertEqual(driver.undoManager?.canUndo, false)
    }

    /// Control: the legacy composer. Its `setInputContent` sets `attributedText`, which (outside the
    /// panel's own `performUndoableTextChange`) empties UIKit's stack when the characters change, so the
    /// same mention autocomplete leaves nothing to undo there. Recorded, not a target: the engine goes
    /// further than legacy here, as a stock text view's completion does.
    func testControlLegacyMentionAutocompleteEmptiesTheStack() throws {
        let arranged = try HarnessLegacy.arrange(HarnessContent.plainText("Hi"))
        defer { HarnessLegacy.restore(arranged) }
        for character in " @al" {
            arranged.textView.insertText(String(character))
        }
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(arranged.textView.undoManager?.canUndo, true, "precondition: legacy registered no typing step")
        self.apply(arranged.host, Self.mentionAutocomplete(peerId: HarnessPanelHost.chatPeer.id, title: "Alice"))
        HarnessEngine.settle(arranged.root)
        XCTAssertEqual(HarnessLegacy.content(arranged).plainText, "Hi Alice ", "precondition: the autocomplete did not land")
        XCTAssertEqual(arranged.textView.undoManager?.canUndo, false)
    }
}
