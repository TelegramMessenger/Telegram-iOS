import XCTest
@testable import RichTextEditorCore

final class DocumentBlockKindTests: XCTestCase {
    func test_documentKind_isCaptionless_likeAudio() {
        XCTAssertTrue(MediaKind.document.isCaptionless)
        XCTAssertTrue(MediaKind.audio.isCaptionless)
        XCTAssertFalse(MediaKind.image.isCaptionless)
        XCTAssertFalse(MediaKind.video.isCaptionless)
        XCTAssertFalse(MediaKind.location.isCaptionless)
    }

    func test_documentKind_rawValueIsStable() {
        // The raw value is persisted in drafts/.rtdoc packages; changing it breaks stored documents.
        XCTAssertEqual(MediaKind.document.rawValue, "document")
        XCTAssertEqual(MediaKind(rawValue: "document"), .document)
    }

    func test_documentBlock_isCaptionless() {
        let block = MediaBlock(id: BlockID("d"), mediaID: "f1", kind: .document,
                               naturalSize: Size2D(width: 1, height: 1))
        XCTAssertTrue(block.isCaptionless)
        XCTAssertFalse(block.isAudio)   // the pre-existing audio-only accessor is unchanged
    }

    func test_documentBlock_treeShapeIsACaptionlessAtom() {
        // nodeSize 3 = 1 media atom + 2 container tokens, with NO caption paragraph node — the audio shape.
        let doc = Document(blocks: [
            .media(MediaBlock(id: BlockID("d"), mediaID: "f1", kind: .document,
                              naturalSize: Size2D(width: 1, height: 1)))
        ])
        let tree = DocumentTree.build(from: doc)
        guard case .doc(let children) = tree, case .mediaBlock(_, let inner)? = children.first else {
            return XCTFail("expected a .mediaBlock node")
        }
        XCTAssertEqual(inner.count, 1)
        guard case .mediaAtom = inner[0] else { return XCTFail("expected a lone .mediaAtom child") }
        XCTAssertEqual(DocumentTree.documentSize(doc), DocumentTree.documentSize(Document(blocks: [
            .media(MediaBlock(id: BlockID("a"), mediaID: "f1", kind: .audio,
                              naturalSize: Size2D(width: 1, height: 1)))
        ])), "a document block must size identically to an audio block")
    }
}
