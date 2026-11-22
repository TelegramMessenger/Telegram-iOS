import XCTest
import UIKit
import TelegramCore
import TextFormat
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** A CUSTOM emoji picked on the chat's emoji keyboard while the caret is on a code block's
/// LANGUAGE line lands in the model as a bare `U+FFFC` inside the language string, which is a plain
/// string with no place for an entity:
///
///     [code lang="swift" "cd"], caret at the end of "swift", emoji keyboard ▸ custom 😀
///       → [code lang="swift\u{FFFC}" "cd"]       sent as a `Pre` whose language is "swift\u{FFFC}"
///     the same into the code BODY → "cd😀" (the alt text, the p16 rule for atoms in plain text)
///
/// The send oracle does not object, because what is sent reloads to the same corrupt language; the fuzz's
/// bare-`U+FFFC` invariant did not look at languages (it does now).
///
/// **How it was seen.** p21 roam (2026-10-01), driving the chat's own insert paths (`HarnessChatInserts`,
/// the shared `chatComposerInsertTextOnUsersBehalf` the app calls) into every kind of line, then sending
/// and reloading each result.
///
/// **Suspected cause.** `RichTextEditor.insertInlineRunsOnUsersBehalf` (`+HostInsert.swift`) inserts a
/// custom emoji with `insertEmoji`, which puts the attachment into whatever line holds the caret; the
/// language line is plain text (the move refusal `destinationHolds` and the p16 flattening rule both know
/// it) and the read-back of the language line keeps the attachment character as text. The host insert
/// should insert the alt text there, as the code body gets, or refuse.
///
/// **Severity.** CORRUPTS WHAT IS SENT (narrow): the message's code block carries a replacement character
/// in its language.
///
/// **Tier 1**: the chat's shared insert function, called as the app's emoji keyboard calls it.
@available(iOS 18.4, *)
final class HarnessCustomEmojiIntoCodeLanguageTests: XCTestCase {
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

    private static let start = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Top"),
        .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "cd")])),
        HarnessEngine.paragraph("end"),
    ])

    private static func customEmoji() -> NSAttributedString {
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
        return NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: attribute])
    }

    /// The code block after inserting `text` through the chat's emoji keyboard at the end of `target`.
    private func code(afterInserting text: NSAttributedString, after target: String) -> ChatInputCode? {
        HarnessComposerFuzzTests.arrange(self.driver, Self.start)
        let range = (self.driver.viewText() as NSString).range(of: target)
        self.driver.setViewSelection(NSRange(location: NSMaxRange(range), length: 0))
        self.driver.settle(0.1)
        HarnessChatInserts.emojiKeyboard(text)(self.driver.host)
        self.driver.settle(0.2)
        for block in self.driver.model().blocks {
            if case let .code(code) = block {
                return code
            }
        }
        return nil
    }

    func testACustomEmojiOnTheLanguageLineLeavesNoBareAttachmentInTheLanguage() throws {
        let code = try XCTUnwrap(self.code(afterInserting: Self.customEmoji(), after: "swift"), "precondition: the code block is gone")
        let language = code.language ?? ""
        XCTAssertFalse(language.contains("\u{FFFC}"), "the language holds a bare U+FFFC: \(fuzzEscaped(language))")
        let sent = HarnessSendPath.send(self.driver.model())
        let preLanguages = sent.messages.flatMap { $0.entities }.compactMap { entity -> String? in
            if case let .Pre(language) = entity.type { return language ?? "" }
            return nil
        }
        XCTAssertFalse(preLanguages.contains { $0.contains("\u{FFFC}") }, "the sent Pre's language holds a bare U+FFFC: \(preLanguages.map(fuzzEscaped))")
    }

    /// Control: the same insert into the code BODY lands as the emoji's alt text.
    func testControlACustomEmojiInTheCodeBodyLandsAsItsAltText() throws {
        let code = try XCTUnwrap(self.code(afterInserting: Self.customEmoji(), after: "cd"))
        XCTAssertEqual(code.runs.map(\.text).joined(), "cd😀")
        XCTAssertEqual(code.language, "swift")
    }

    /// Control: a static emoji on the language line is ordinary text there.
    func testControlAStaticEmojiOnTheLanguageLineIsText() throws {
        let code = try XCTUnwrap(self.code(afterInserting: NSAttributedString(string: "😀"), after: "swift"))
        XCTAssertFalse((code.language ?? "").contains("\u{FFFC}"))
    }
}
