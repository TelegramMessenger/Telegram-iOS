import XCTest
@testable import MessageWidget

final class CorpusListingTests: XCTestCase {
    /// The DEBUG sender posts every folder but `attacks`, by path: 278 files, in order, each labelled with its path.
    func testTheSenderListsEveryFolderButAttacksInOrder() {
        let root = Bundle(for: CorpusListingTests.self).resourceURL!.appendingPathComponent("corpus")
        let items = MessageWidgetCorpusListing.items(in: root)
        XCTAssertEqual(items.count, 278)
        XCTAssertFalse(items.contains { $0.path.hasPrefix("attacks/") })
        XCTAssertEqual(items.map(\.path), items.map(\.path).sorted())
        XCTAssertEqual(items.first?.label, "widget-sandbox " + (items.first?.path ?? ""))
        XCTAssertTrue(items.allSatisfy { !$0.source.isEmpty })
    }
}
