import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p23, 2026-10-01; what is drawn is not what arrives).** Format ▸ Monospace over a MENTION, a
/// DATE or a LINK, whole or in part, gives the model a run that is inline code AND the entity:
///
///     [p "Hi " [@777]"Alice" " there"], select 3..<8, Monospace     →  [p "Hi " [m,@777]"Alice" " there"]
///     the same over 4..<6 ("li")                                     →  "Hi " [@777]"A" [m,@777]"li" [@777]"ce" …
///     a date [date]"Noonx" / a link [url]"Sitex" the same
///     Link over a word already in inline code                        →  [m,url]
///
/// A paragraph like this goes the TEXT route (`chatComposerSendRoute`), which sends a `Code` entity
/// overlapping a `MentionName` / `FormattedDate` / `TextUrl` one. The platform's nesting rule (Bot API
/// "Formatting options": bold, italic, underline, strikethrough and spoiler may nest with anything EXCEPT
/// `pre` and `code`, and every other entity contains no other) does not allow that, so the composer shows a
/// monospaced mention that the server normalises (one of the two entities is dropped). The legacy composer
/// refuses the command: Monospace over a mention leaves it as it was (the control below). Bold, Italic,
/// Strikethrough, Underline and Spoiler over the same mention are allowed nestings, and the engine keeps
/// them (controls).
///
/// The p20 rule made a code BLOCK plain text for the same reason (`inlineFormatTargetRanges` skips a code
/// body; `HarnessSendPathCodeFormattingTests`). INLINE code has the same constraint against the entities and
/// was not covered.
///
/// **How it was seen.** p23 roam, Priority 4 (mention / date entities edited character by character), with
/// legacy as the oracle.
///
/// **Suspected cause.** `RichTextEngineEditorView+InlineCode.swift` / the Monospace toggle applies the code
/// marker over entity runs, and `Link` applies a URL over code runs. Neither asks whether the run carries an
/// entity the code span cannot hold. One rule fixes both: a range with an entity gets no inline code (refused,
/// as legacy does, or the entity dropped), and a code run gets no link.
///
/// **Tier 1**: view selection, `performFormatAction`, Format ▸ Link answered through `linkPromptOverride`.
@available(iOS 18.4, *)
final class HarnessInlineCodeOverEntityTests: XCTestCase {
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

    private static func document(_ entity: ChatInputRun) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("Hi "), entity, E.run(" there")])])
    }

    /// Runs that are inline code AND carry a mention, date or link entity.
    private static func codeWithEntity(_ content: ChatInputContent) -> [String] {
        var result: [String] = []
        for block in content.blocks {
            guard case let .paragraph(paragraph) = block else { continue }
            for run in paragraph.runs where run.attributes.monospace && run.attributes.entity != nil {
                result.append(run.text)
            }
        }
        return result
    }

    private func format(_ entity: ChatInputRun, _ range: NSRange, _ action: ChatRichTextFormatAction) -> ChatInputContent {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(entity))
        self.driver.setViewSelection(range)
        self.driver.settle(0.1)
        self.driver.node.performFormatAction(action)
        self.driver.settle(0.2)
        return self.driver.chatCopy()
    }

    private func assertNoCodeOverAnEntity(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(HarnessSendPath.send(model).route, .textEntities, "precondition: the text route", file: file, line: line)
        let overlapping = Self.codeWithEntity(model)
        XCTAssertTrue(overlapping.isEmpty, "inline code over an entity in \(overlapping): \(HarnessEdited.describe(model))", file: file, line: line)
    }

    // MARK: - Red

    func testMonospaceOverAWholeMentionDoesNotMakeACodeMention() {
        self.assertNoCodeOverAnEntity(self.format(E.mention("Alice"), NSRange(location: 3, length: 5), .monospace))
    }

    func testMonospaceOverPartOfAMentionDoesNotMakeACodeMention() {
        self.assertNoCodeOverAnEntity(self.format(E.mention("Alice"), NSRange(location: 4, length: 2), .monospace))
    }

    func testMonospaceOverADateDoesNotMakeACodeDate() {
        self.assertNoCodeOverAnEntity(self.format(E.date("Noonx"), NSRange(location: 3, length: 5), .monospace))
    }

    func testMonospaceOverALinkDoesNotMakeACodeLink() {
        self.assertNoCodeOverAnEntity(self.format(E.url("Sitex"), NSRange(location: 3, length: 5), .monospace))
    }

    func testALinkOverInlineCodeDoesNotMakeACodeLink() {
        let code = E.run("codex") { $0.monospace = true }
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(code))
        self.driver.setViewSelection(NSRange(location: 3, length: 5))
        self.driver.settle(0.1)
        self.driver.root.linkPromptOverride = { _, _ in "https://telegram.org" }
        defer { self.driver.root.linkPromptOverride = nil }
        self.driver.host.panel.formatAttributesLink(self.driver.host.panel)
        self.driver.settle(0.3)
        self.assertNoCodeOverAnEntity(self.driver.chatCopy())
    }

    // MARK: - Controls

    /// Bold and Spoiler may nest with a mention: kept, as the platform allows.
    func testControlBoldAndSpoilerOverPartOfAMentionAreKept() {
        let bold = self.format(E.mention("Alice"), NSRange(location: 4, length: 2), .bold)
        XCTAssertEqual(HarnessEdited.describe(bold), "[p body \"Hi \"+[@777]\"A\"+[b,@777]\"li\"+[@777]\"ce\"+\" there\"]")
        let spoiler = self.format(E.mention("Alice"), NSRange(location: 4, length: 2), .spoiler)
        XCTAssertEqual(HarnessEdited.describe(spoiler), "[p body \"Hi \"+[@777]\"A\"+[sp,@777]\"li\"+[@777]\"ce\"+\" there\"]")
    }

    /// Monospace over plain text next to the mention is inline code as usual.
    func testControlMonospaceOverPlainTextIsCode() {
        let model = self.format(E.mention("Alice"), NSRange(location: 9, length: 5), .monospace)
        XCTAssertEqual(HarnessEdited.describe(model), "[p body \"Hi \"+[@777]\"Alice\"+\" \"+[m]\"there\"]")
    }

    /// The oracle: the LEGACY composer refuses Monospace over a mention.
    func testControlLegacyRefusesMonospaceOverAMention() throws {
        let arranged = try HarnessLegacy.arrange(Self.document(E.mention("Alice")))
        defer { HarnessLegacy.restore(arranged) }
        arranged.textView.selectedRange = NSRange(location: 3, length: 5)
        HarnessEngine.settle(arranged.root, seconds: 0.1)
        arranged.node.performFormatAction(.monospace)
        HarnessEngine.settle(arranged.root, seconds: 0.2)
        XCTAssertEqual(HarnessEdited.describe(HarnessLegacy.content(arranged)), "[p body \"Hi \"+[@777]\"Alice\"+\" there\"]")
    }
}
