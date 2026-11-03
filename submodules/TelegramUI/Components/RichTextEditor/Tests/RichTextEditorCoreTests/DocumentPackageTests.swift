import XCTest
@testable import RichTextEditorCore

final class DocumentPackageTests: XCTestCase {
    func test_package_writeThenReadRoundTrips() throws {
        let doc = Document(
            blocks: [.media(MediaBlock(id: BlockID("i1"), mediaID: "i1.png",
                                       naturalSize: Size2D(width: 1, height: 1)))]
        )
        let pkg = DocumentPackage(document: doc, assets: ["i1.png": Data([0xDE, 0xAD])])

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pkgtest-\(UUID().uuidString)")
            .appendingPathComponent("Doc.rtdoc")
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

        try pkg.write(to: dir)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("document.json").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("assets/i1.png").path))

        let read = try DocumentPackage.read(from: dir)
        XCTAssertEqual(read.document, doc)
        XCTAssertEqual(read.assets["i1.png"], Data([0xDE, 0xAD]))
    }
}
