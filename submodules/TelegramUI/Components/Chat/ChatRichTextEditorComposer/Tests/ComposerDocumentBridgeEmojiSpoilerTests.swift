import XCTest
import TelegramCore
import RichTextEditorCore
import TextFormat
@testable import ChatRichTextEditorComposer

/// The composer attributed-string → `Document` bridge, for an emoji that is ALSO a spoiler.
///
/// This path is host-push: initial load, draft restore, edit. It used to build the emoji run from
/// `CharacterAttributes.plain` and return early, so an emoji inside a spoiler came back unspoilered —
/// the run would render unhidden with the dust split around it.
///
/// `emoji` and `spoiler` are independent model fields; an atom can be concealed like any other
/// character. The identical defect existed in `AttributedStringMapper` and in the chat's own insert
/// path, so this is the third place the same "an emoji run is purely the atom" shortcut lost data.
final class ComposerDocumentBridgeEmojiSpoilerTests: XCTestCase {

    private func emojiAttributedString(spoilered: Bool) -> NSAttributedString {
        let emoji = ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil, fileId: 5202, file: nil)
        var attributes: [NSAttributedString.Key: Any] = [ChatTextInputAttributes.customEmoji: emoji]
        if spoilered { attributes[ChatTextInputAttributes.spoiler] = true as NSNumber }
        let result = NSMutableAttributedString(string: "ab")
        result.append(NSAttributedString(string: "😀", attributes: attributes))
        return result
    }

    private func runs(of document: Document) -> [TextRun] {
        document.blocks.flatMap { block -> [TextRun] in
            guard case let .paragraph(paragraph) = block else { return [] }
            return paragraph.runs
        }
    }

    func test_aSpoileredEmojiKeepsItsSpoiler() {
        let document = ComposerDocumentBridge.document(from: emojiAttributedString(spoilered: true))

        let emojiRuns = runs(of: document).filter { $0.attributes.emoji != nil }
        XCTAssertEqual(emojiRuns.count, 1, "the emoji run did not survive the bridge")
        XCTAssertTrue(emojiRuns[0].attributes.spoiler,
                      "the emoji lost its spoiler, so it will render unhidden inside the spoiler")
    }

    /// THE CONTROL. An emoji that is NOT spoilered must not acquire one, or the assertion above would
    /// pass against a bridge that spoilers every emoji.
    func test_control_anUnspoileredEmojiStaysUnspoilered() {
        let document = ComposerDocumentBridge.document(from: emojiAttributedString(spoilered: false))

        let emojiRuns = runs(of: document).filter { $0.attributes.emoji != nil }
        XCTAssertEqual(emojiRuns.count, 1)
        XCTAssertFalse(emojiRuns[0].attributes.spoiler)
    }

    /// The emoji must still be ONE canonical position regardless — the invariant the editor's whole
    /// offset mapping rests on.
    func test_theEmojiRemainsASingleObjectReplacementCharacter() {
        let document = ComposerDocumentBridge.document(from: emojiAttributedString(spoilered: true))
        let emojiRuns = runs(of: document).filter { $0.attributes.emoji != nil }
        XCTAssertEqual(emojiRuns.first?.text, "\u{FFFC}",
                       "the emoji run is not a single object-replacement character")
    }
}
