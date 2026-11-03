import XCTest
@testable import RichTextEditorCore

final class SelfReferentialLinkTests: XCTestCase {
    // MARK: - The predicate

    func test_exactMatch_isSelfReferential() {
        XCTAssertTrue(linkIsSelfReferential(text: "https://example.com/foo", url: "https://example.com/foo"))
    }

    func test_labelledLink_isNotSelfReferential() {
        XCTAssertFalse(linkIsSelfReferential(text: "click here", url: "https://example.com"))
    }

    func test_schemeAddedByTheImporter_isSelfReferential() {
        XCTAssertTrue(linkIsSelfReferential(text: "www.example.com", url: "http://www.example.com"))
    }

    func test_mailtoPrefix_isSelfReferential() {
        XCTAssertTrue(linkIsSelfReferential(text: "user@example.com", url: "mailto:user@example.com"))
    }

    func test_percentEncodedPath_isSelfReferential() {
        XCTAssertTrue(linkIsSelfReferential(
            text: "https://ru.wikipedia.org/wiki/Привет",
            url: "https://ru.wikipedia.org/wiki/%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82"
        ))
    }

    func test_differentScheme_isNotSelfReferential() {
        XCTAssertFalse(linkIsSelfReferential(text: "http://example.com", url: "https://example.com"))
    }

    func test_emptyText_isNotSelfReferential() {
        XCTAssertFalse(linkIsSelfReferential(text: "  ", url: "https://example.com"))
    }

    /// The mention / date markers the composer stores in `link` never equal their own display text.
    func test_telegramMarkers_areNotSelfReferential() {
        XCTAssertFalse(linkIsSelfReferential(text: "Alice", url: "tg://user?id=1"))
        XCTAssertFalse(linkIsSelfReferential(text: "12:00", url: "tg://timestamp?t=43200"))
    }

    // MARK: - Stripping over a Document

    private func linked(_ text: String, _ url: String) -> TextRun {
        var attributes = CharacterAttributes.plain
        attributes.link = url
        return TextRun(text: text, attributes: attributes)
    }

    func test_strip_removesASelfReferentialLink() {
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [
            linked("https://example.com", "https://example.com")
        ]))])
        guard case let .paragraph(result) = document.strippingSelfReferentialLinks().blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(result.runs[0].text, "https://example.com")
        XCTAssertNil(result.runs[0].attributes.link)
    }

    func test_strip_keepsAGenuineTextLink() {
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [
            linked("click here", "https://example.com")
        ]))])
        XCTAssertEqual(document.strippingSelfReferentialLinks(), document)
    }

    func test_strip_preservesTheRunsOtherAttributes() {
        var attributes = CharacterAttributes.plain
        attributes.link = "https://example.com"
        attributes.bold = true
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [
            TextRun(text: "https://example.com", attributes: attributes)
        ]))])
        guard case let .paragraph(result) = document.strippingSelfReferentialLinks().blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertNil(result.runs[0].attributes.link)
        XCTAssertTrue(result.runs[0].attributes.bold)
    }

    func test_strip_joinsAdjacentRunsSharingTheSameLink() {
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [
            linked("https://example.com", "https://example.com/foo"),
            linked("/foo", "https://example.com/foo")
        ]))])
        guard case let .paragraph(result) = document.strippingSelfReferentialLinks().blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertNil(result.runs[0].attributes.link)
        XCTAssertNil(result.runs[1].attributes.link)
    }

    func test_strip_recursesIntoNestedContainers() {
        let run = linked("https://example.com", "https://example.com")
        let document = Document(blocks: [
            .code(CodeBlock(id: .generate(), language: nil, runs: [run])),
            .pullQuote(PullQuote(id: .generate(), runs: [run], author: [run])),
            .blockQuote(BlockQuote(id: .generate(), children: [
                .paragraph(ParagraphBlock(id: .generate(), runs: [run]))
            ])),
            .media(MediaBlock(id: .generate(), mediaID: "m", naturalSize: Size2D(width: 1, height: 1), caption: [run]))
        ])
        let stripped = document.strippingSelfReferentialLinks()

        guard case let .code(code) = stripped.blocks[0] else { return XCTFail("expected code") }
        XCTAssertNil(code.runs[0].attributes.link)
        guard case let .pullQuote(pullQuote) = stripped.blocks[1] else { return XCTFail("expected a pull quote") }
        XCTAssertNil(pullQuote.runs[0].attributes.link)
        XCTAssertNil(pullQuote.author[0].attributes.link)
        guard case let .blockQuote(blockQuote) = stripped.blocks[2] else { return XCTFail("expected a block quote") }
        guard case let .paragraph(inner) = blockQuote.children[0] else { return XCTFail("expected a paragraph") }
        XCTAssertNil(inner.runs[0].attributes.link)
        guard case let .media(media) = stripped.blocks[3] else { return XCTFail("expected media") }
        XCTAssertNil(media.caption[0].attributes.link)
    }
}
