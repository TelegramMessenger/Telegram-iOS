import XCTest
import UIKit
import TelegramCore
import TelegramPresentationData
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02; found by the new `chatMention` fuzz op, edited seed 69, reduced).** A code block's
/// LANGUAGE line holding a space at either END — typed (`"MX "`, the space before the next word of "objective c"),
/// or the trailing space the avatar menu's Mention leaves (`"MXHarness "`) — is held by the engine but TRIMMED by the
/// read-back ("an emptied line means no language"). The next re-render of the line — a theme change (auto-night),
/// and anything else that re-renders from the model — drops the space from the line, and the selection JUMPS to
/// the end of the code body, wherever it was:
///
///     [p "top"] [code lang="MX" "let x = 1"] [p ""], caret after "MX", type " "  → engine "MX ", caret 7
///     dark theme and back                                                        → engine "MX",  caret 16 (body end)
///     the same with the caret moved to 1 first                                   → caret 16
///
/// The typed space is lost (the p13 decision: "the value is the user's") and the caret leaves the line being
/// typed in; the fuzz's theme round trip reported it as "a theme change moved the selection {28, 60} -> {107, 0}".
///
/// **Suspected cause.** The language read-back trims (`EngineDocumentBridge`, `block(for:from:)`'s code language)
/// while the engine keeps what was typed, so engine and model disagree for an edge space; the theme's re-render
/// replaces the line from the model and the selection is restored on a stale offset (one character longer than the
/// new document, past the language line). Either keep the language untrimmed in the model while editing (trim on
/// send / on an emptied line only) or re-render without moving the selection (`HarnessThemeChangeSelectionTests`'
/// rule). The fuzz's projection compares a language TRIMMED (`FuzzModel.EngineLine.language`), so the per-step
/// axis check never sees the disagreement; only the selection check after a re-render does.
///
/// **Severity.** Medium: the caret jumps while typing a language, and a typed space is removed.
///
/// **Tier 1**: `insertText`, the chat's avatar-menu Mention (`HarnessChatInserts`), a theme change through the
/// panel's presentation state.
@available(iOS 18.4, *)
final class HarnessCodeLanguageEdgeWhitespaceTests: XCTestCase {
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

    private static let document = ChatInputContent(blocks: [E.paragraph([E.run("top")]), .code(ChatInputCode(language: "MX", runs: [E.run("let x = 1")])), E.paragraph([])])

    private func caretAfterLanguage() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "MX")), length: 0))
        self.driver.settle()
    }

    private func themeRoundTrip() {
        for dark in [true, false] {
            self.driver.host.updatePresentationInterfaceState { $0.updatedTheme(dark ? defaultDarkPresentationTheme : defaultPresentationTheme) }
            self.driver.root.view.setNeedsLayout()
            self.driver.settle()
        }
    }

    // MARK: - Red

    func testATypedTrailingSpaceInALanguageSurvivesAThemeChangeWithTheCaret() {
        self.caretAfterLanguage()
        self.driver.insert(" ")
        self.driver.settle(0.2)
        let selection = self.driver.viewSelection()
        let text = self.driver.viewText()
        self.themeRoundTrip()
        XCTAssertEqual(self.driver.viewSelection(), selection, "the caret moved")
        XCTAssertEqual(self.driver.viewText(), text, "the language line changed")
    }

    func testACaretElsewhereStaysPutThroughAThemeChange() {
        self.caretAfterLanguage()
        self.driver.insert(" ")
        self.driver.settle(0.2)
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle()
        self.themeRoundTrip()
        XCTAssertEqual(self.driver.viewSelection(), NSRange(location: 1, length: 0), "a caret in the first paragraph jumped")
    }

    func testTheAvatarMentionsTrailingSpaceInALanguageSurvivesAThemeChange() {
        self.caretAfterLanguage()
        HarnessChatInserts.contextMenuMention(EnginePeer(HarnessPanelHost.chatPeer))(self.driver.host)
        self.driver.settle(0.2)
        let selection = self.driver.viewSelection()
        self.themeRoundTrip()
        XCTAssertEqual(self.driver.viewSelection(), selection, "the caret moved")
    }

    // MARK: - Controls

    func testControlAnInnerSpaceInALanguageKeepsTheCaret() {
        self.caretAfterLanguage()
        self.driver.insert(" c")
        self.driver.settle(0.2)
        let selection = self.driver.viewSelection()
        let text = self.driver.viewText()
        self.themeRoundTrip()
        XCTAssertEqual(self.driver.viewSelection(), selection)
        XCTAssertEqual(self.driver.viewText(), text)
    }

    func testControlALanguageWithoutEdgeSpaceKeepsTheCaret() {
        self.caretAfterLanguage()
        self.driver.insert("Y")
        self.driver.settle(0.2)
        let selection = self.driver.viewSelection()
        self.themeRoundTrip()
        XCTAssertEqual(self.driver.viewSelection(), selection)
    }
}
