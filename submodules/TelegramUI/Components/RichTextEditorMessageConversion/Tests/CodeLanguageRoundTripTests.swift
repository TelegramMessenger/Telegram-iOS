import XCTest
import TelegramCore
import TextFormat
import RichTextEditorCore
@testable import RichTextEditorMessageConversion

/// The full send -> edit round-trip for a code block's language: the editor's Document becomes a message
/// (text + entities), the message becomes the composer's chat string, and that becomes ChatInputContent
/// again. The language must survive every hop.
final class CodeLanguageRoundTripTests: XCTestCase {
    private func sentMessage(language: String?) -> (text: String, entities: [MessageTextEntity]) {
        return buildEntityMessage(from: [
            .code(CodeBlock(id: BlockID("c"), language: language, runs: [TextRun(text: "let x = 1")]))
        ])
    }

    func testSendEmitsAPreEntityCarryingTheLanguage() {
        let message = sentMessage(language: "Swift")
        XCTAssertEqual(message.text, "let x = 1")
        let languages: [String?] = message.entities.compactMap { entity in
            if case let .Pre(language) = entity.type { return language }
            return nil
        }
        XCTAssertEqual(languages.count, 1, "exactly one .Pre entity")
        XCTAssertEqual(languages[0], "Swift")
    }

    func testEditingASentCodeBlockRecoversItsLanguage() {
        let message = sentMessage(language: "Swift")
        let attributed = chatInputStateStringWithAppliedEntities(message.text, entities: message.entities)
        let content = chatInputContent(from: attributed)
        guard case let .code(code) = content.blocks.first else {
            return XCTFail("expected a code block, got \(String(describing: content.blocks.first))")
        }
        XCTAssertEqual(code.language, "Swift")
        XCTAssertEqual(code.runs.map(\.text).joined(), "let x = 1")
    }

    func testALanguagelessCodeBlockStaysLanguageless() {
        let message = sentMessage(language: nil)
        let content = chatInputContent(from: chatInputStateStringWithAppliedEntities(message.text, entities: message.entities))
        guard case let .code(code) = content.blocks.first else { return XCTFail("expected a code block") }
        XCTAssertNil(code.language)
    }
}
