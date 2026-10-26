import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02; audit of the p23 inline-code-vs-entity refusal).** The avatar context menu's
/// Mention, with the caret INSIDE an inline-code run or at its END, inserts the peer's name as plain inline code:
/// the mention entity is lost, so the message mentions nobody.
///
///     [p "hi " [m]"code" " end"], caret after "co", avatar menu ▸ Mention
///       → [p "hi " [m]"coHarness de" " end"]           (no mention entity)
///     caret after "code" (the run's end)  → [m]"codeHarness "   (no mention entity)
///     caret in plain text                 → [@]"Harness" " "     (control: the mention is kept)
///
/// The chat's OTHER mention path disagrees: typing "@ha" in the same place and picking from the autocomplete
/// (`MentionChatInputContextPanelNode`, a set through `updateTextInputStateAndMode`) keeps the MENTION and drops the
/// inline code from it — the p23 decision for content arriving with both (`withoutInlineCodeOverLinks`: "the entity
/// carries data, the code is a face").
///
/// **Suspected cause.** `insertInlineRunsOnUsersBehalf` (`+HostInsert.swift`) inserts a link run as TYPED text and
/// then calls `setLink` over it. Typed inside or after inline code, the text takes the code's typing attributes, and
/// since the p23 fix wave `setLink` refuses any range holding inline code (`linkReachesSelection`). The refusal is
/// right for the Format ▸ Link COMMAND; the host insert is content arriving on the user's behalf, which p23 decided
/// keeps the entity. Before p23 the link was applied and the read-back's `withoutInlineCodeOverLinks` dropped the
/// code, keeping the mention, so this is a regression of the p23 fix wave. Either the insert clears inline code from
/// the typed run before linking (as the set path does), or it inserts the run with its link already set.
///
/// **Severity.** CORRUPTS WHAT IS SENT: the user picked a mention and the message carries a code span instead.
///
/// **Tier 1**: the chat's shared insert (`chatComposerInsertMention`, through `HarnessChatInserts`) and the chat's
/// autocomplete transform (`HarnessChatSideEditUndoTests.mentionAutocomplete`), as the app calls them.
@available(iOS 18.4, *)
final class HarnessMentionIntoInlineCodeTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private static var start: ChatInputContent {
        var mono = ChatInputInlineAttributes()
        mono.monospace = true
        return ChatInputContent(blocks: [E.paragraph([E.run("hi "), ChatInputRun(text: "code", attributes: mono), E.run(" end")])])
    }

    private func mentionRuns(_ content: ChatInputContent) -> [ChatInputRun] {
        guard case let .paragraph(paragraph)? = content.blocks.first else { return [] }
        return paragraph.runs.filter { run in
            if case .mention? = run.attributes.entity { return true }
            return false
        }
    }

    private func mentionFromAvatarMenu(at caret: Int) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, Self.start)
        self.driver.setViewSelection(NSRange(location: caret, length: 0))
        self.driver.settle(0.1)
        HarnessChatInserts.contextMenuMention(EnginePeer(HarnessPanelHost.chatPeer))(self.driver.host)
        self.driver.settle(0.3)
        return self.driver.model()
    }

    // MARK: - Red

    func testAMentionInsertedInsideInlineCodeKeepsItsEntity() {
        let model = self.mentionFromAvatarMenu(at: 5)
        XCTAssertTrue(model.plainText.contains("Harness"), "precondition: the mention's text did not land: \(E.describe(model))")
        XCTAssertEqual(self.mentionRuns(model).map(\.text), ["Harness"], "the mention was inserted without its entity: \(E.describe(model))")
        XCTAssertTrue(self.driver.unfilteredViolations().isEmpty, "\(self.driver.unfilteredViolations())")
    }

    func testAMentionInsertedAtTheEndOfInlineCodeKeepsItsEntity() {
        let model = self.mentionFromAvatarMenu(at: 7)
        XCTAssertTrue(model.plainText.contains("Harness"), "precondition: the mention's text did not land: \(E.describe(model))")
        XCTAssertEqual(self.mentionRuns(model).map(\.text), ["Harness"], "the mention was inserted without its entity: \(E.describe(model))")
    }

    /// The two chat paths for "a mention here" agree: the avatar menu gives the entity autocomplete gives.
    func testTheAvatarMenuAndTheAutocompleteAgreeInsideInlineCode() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.start)
        self.driver.setViewSelection(NSRange(location: 7, length: 0))
        self.driver.settle(0.1)
        for character in " @ha" { self.driver.insert(String(character)) }
        self.driver.settle(0.2)
        self.driver.host.panel.interfaceInteraction?.updateTextInputStateAndMode(HarnessChatSideEditUndoTests.mentionAutocomplete(peerId: HarnessPanelHost.chatPeer.id, title: "Harness"))
        self.driver.settle(0.3)
        let autocompleted = self.mentionRuns(self.driver.model()).map(\.text)
        let fromMenu = self.mentionRuns(self.mentionFromAvatarMenu(at: 7)).map(\.text)
        XCTAssertEqual(autocompleted, ["Harness"], "precondition: the autocomplete kept the mention")
        XCTAssertEqual(fromMenu, autocompleted, "the avatar menu's Mention and the autocomplete disagree")
    }

    // MARK: - Controls

    func testControlAMentionInsertedInPlainTextKeepsItsEntity() {
        let model = self.mentionFromAvatarMenu(at: 1)
        XCTAssertEqual(self.mentionRuns(model).map(\.text), ["Harness"], E.describe(model))
    }

    /// The refusal the insert runs into is right for the COMMAND: Link over a selection holding inline code
    /// applies nothing (p23).
    func testControlTheLinkCommandOverInlineCodeIsRefused() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.start)
        self.driver.setViewSelection(NSRange(location: 1, length: 6))
        self.driver.settle(0.1)
        self.driver.root.linkPromptOverride = { _, _ in "https://telegram.org" }
        defer { self.driver.root.linkPromptOverride = nil }
        self.driver.host.panel.formatAttributesLink(self.driver.host.panel)
        self.driver.settle(0.2)
        XCTAssertEqual(FuzzModel.normalized(self.driver.model()), FuzzModel.normalized(Self.start))
    }
}
