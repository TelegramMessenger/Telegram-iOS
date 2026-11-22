import Foundation
import UIKit
import XCTest
import CallScreen

/// Pins where the call screen's tailed notice ("Tap here to turn on your camera") stands: as close to centered over
/// its target (the video button) as the band between the side insets allows, with the tail's tip over the target and
/// the tail kept on the straight part of the pill's edge.
final class PrivateCallNoticeTailLayoutTests: XCTestCase {
    private func layout(noticeWidth: CGFloat, targetX: CGFloat, bandMinX: CGFloat = 0.0, bandWidth: CGFloat = 402.0, containerWidth: CGFloat = 402.0) -> PrivateCallNoticeTailLayout {
        return PrivateCallNoticeTailLayout(noticeWidth: noticeWidth, cornerRadius: 16.0, targetX: targetX, bandMinX: bandMinX, bandWidth: bandWidth, containerWidth: containerWidth, sideInset: 16.0)
    }

    func testCenteredOverTargetWhenThereIsRoom() {
        let result = self.layout(noticeWidth: 100.0, targetX: 155.0)
        XCTAssertEqual(result.noticeX, 105.0)
        XCTAssertEqual(result.tailX, 50.0)
    }

    func testWideNoticeIsClampedToTheSideInsetAndTheTailStillPointsAtTheTarget() {
        // iPhone 18 Pro portrait: four buttons, the video button second.
        let result = self.layout(noticeWidth: 300.0, targetX: 155.0)
        XCTAssertEqual(result.noticeX, 16.0)
        XCTAssertEqual(result.noticeX + result.tailX, 155.0)
    }

    func testTargetNearTheTrailingEdge() {
        let result = self.layout(noticeWidth: 300.0, targetX: 380.0)
        XCTAssertEqual(result.noticeX, 402.0 - 16.0 - 300.0)
        // The tail stops before the pill's rounded corner: radius plus half the tail's width.
        XCTAssertEqual(result.tailX, 300.0 - 16.0 - PrivateCallNoticeTailLayout.tailWidth * 0.5)
    }

    func testTargetNearTheLeadingEdgeKeepsTheTailOffTheCorner() {
        let result = self.layout(noticeWidth: 300.0, targetX: 10.0)
        XCTAssertEqual(result.noticeX, 16.0)
        XCTAssertEqual(result.tailX, 16.0 + PrivateCallNoticeTailLayout.tailWidth * 0.5)
    }

    /// iPhone Duo folded portrait: the band ends at the right side inset (84).
    func testStaysInsideTheBand() {
        let result = self.layout(noticeWidth: 280.0, targetX: 300.0, bandMinX: 0.0, bandWidth: 318.0, containerWidth: 402.0)
        XCTAssertEqual(result.noticeX, 318.0 - 16.0 - 280.0)
        XCTAssertLessThanOrEqual(result.noticeX + 280.0, 318.0 - 16.0)
    }

    func testNoticeWiderThanTheBandIsCenteredOnTheContainer() {
        let result = self.layout(noticeWidth: 320.0, targetX: 155.0, bandMinX: 0.0, bandWidth: 318.0, containerWidth: 402.0)
        XCTAssertEqual(result.noticeX, 41.0)
        XCTAssertEqual(result.noticeX + result.tailX, 155.0)
    }

    func testNarrowNoticeKeepsTheTailCentered() {
        let result = self.layout(noticeWidth: 40.0, targetX: 10.0)
        XCTAssertEqual(result.tailX, 20.0)
    }
}
