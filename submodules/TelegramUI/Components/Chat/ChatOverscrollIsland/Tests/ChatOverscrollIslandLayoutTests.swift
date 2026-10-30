import XCTest
import CoreGraphics
import ChatOverscrollIslandLayout

private func assertRect(_ rect: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(rect.minX, expected.minX, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rect.minY, expected.minY, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rect.width, expected.width, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rect.height, expected.height, accuracy: 0.001, file: file, line: line)
}

final class ChatOverscrollIslandLayoutTests: XCTestCase {
    private let anchor = CGRect(x: 100.0, y: 500.0, width: 200.0, height: 44.0)

    // The pull begins as a 14pt drop centred 2pt inside the control's top edge, which swells to the island's height
    // by progress 0.55 while still overlapping the control by 2pt.
    func testDropGrowsOutOfTheAnchor() {
        assertRect(chatOverscrollIslandFrame(progress: 0.0, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 193.0, y: 495.0, width: 14.0, height: 14.0))
        assertRect(chatOverscrollIslandFrame(progress: 0.55, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 178.0, y: 458.0, width: 44.0, height: 44.0))
    }

    // Then it stretches to its full width and rises until it stands 12pt clear of the control.
    func testIslandStretchesAndRises() {
        assertRect(chatOverscrollIslandFrame(progress: 0.775, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 129.0, y: 451.0, width: 142.0, height: 44.0))
        assertRect(chatOverscrollIslandFrame(progress: 1.0, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 80.0, y: 444.0, width: 240.0, height: 44.0))
        assertRect(chatOverscrollIslandFrame(progress: 1.4, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 80.0, y: 444.0, width: 240.0, height: 44.0))
        assertRect(chatOverscrollIslandFrame(progress: -0.2, anchorFrame: self.anchor, fullWidth: 240.0), CGRect(x: 193.0, y: 495.0, width: 14.0, height: 14.0))
    }

    // The avatar, title and count show only once the island has nearly taken its shape.
    func testContentFadesInLate() {
        XCTAssertEqual(chatOverscrollIslandContentAlpha(progress: 0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(chatOverscrollIslandContentAlpha(progress: 0.8), 0.0, accuracy: 0.001)
        XCTAssertEqual(chatOverscrollIslandContentAlpha(progress: 0.9), 0.5, accuracy: 0.001)
        XCTAssertEqual(chatOverscrollIslandContentAlpha(progress: 1.0), 1.0, accuracy: 0.001)
    }

    // Avatar (48pt lead) or none (18pt), the title, 8pt and the count when there is one, 18pt; a long title is cut to
    // what the container leaves, 16pt clear on each side.
    func testWidths() {
        let withCount = chatOverscrollIslandTextWidths(titleWidth: 120.0, countWidth: 10.0, hasAvatar: true, maxWidth: 300.0)
        XCTAssertEqual(withCount.title, 120.0, accuracy: 0.001)
        XCTAssertEqual(withCount.full, 204.0, accuracy: 0.001)
        let plain = chatOverscrollIslandTextWidths(titleWidth: 100.0, countWidth: 0.0, hasAvatar: false, maxWidth: 300.0)
        XCTAssertEqual(plain.title, 100.0, accuracy: 0.001)
        XCTAssertEqual(plain.full, 136.0, accuracy: 0.001)
        let long = chatOverscrollIslandTextWidths(titleWidth: 400.0, countWidth: 20.0, hasAvatar: true, maxWidth: 300.0)
        XCTAssertEqual(long.title, 206.0, accuracy: 0.001)
        XCTAssertEqual(long.full, 300.0, accuracy: 0.001)
        XCTAssertEqual(chatOverscrollIslandMaxWidth(containerWidth: 100.0), 120.0, accuracy: 0.001)
        XCTAssertEqual(chatOverscrollIslandMaxWidth(containerWidth: 375.0), 343.0, accuracy: 0.001)
    }

    // Let go short of the switch, it sinks back into a 14pt drop just inside the control's top edge.
    func testSinksIntoTheAnchor() {
        assertRect(chatOverscrollIslandSinkFrame(anchorFrame: self.anchor), CGRect(x: 193.0, y: 502.0, width: 14.0, height: 14.0))
    }
}
