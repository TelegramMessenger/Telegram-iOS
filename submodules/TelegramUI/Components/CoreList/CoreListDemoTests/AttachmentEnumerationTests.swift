import XCTest
@testable import CoreListDemo

final class AttachmentEnumerationTests: XCTestCase {
    private func groupedItems(count: Int = 60, groupSize: Int = 5) -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index, height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "group\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
    }

    func testLoadedAttachmentViewsAreTheSettledWindowsAttachmentViews() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let expected = fixture.activeWindow.attachments.map { ObjectIdentifier($0.view) }
        XCTAssertFalse(expected.isEmpty, "precondition: the fixture must produce attachment runs")

        let actual = Array(fixture.listView.loadedAttachmentViews).map { ObjectIdentifier($0) }
        XCTAssertEqual(actual, expected, "same views, same order as the settled window")
    }

    func testAListWithNoAttachmentsEnumeratesNothing() {
        let fixture = VirtualListFixture(itemCount: 40)
        XCTAssertTrue(Array(fixture.listView.loadedAttachmentViews).isEmpty)
    }
}
