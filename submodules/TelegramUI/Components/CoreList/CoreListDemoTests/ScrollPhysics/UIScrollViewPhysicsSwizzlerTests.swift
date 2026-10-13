import XCTest
import UIKit
@testable import CoreListDemo

final class UIScrollViewPhysicsSwizzlerTests: XCTestCase {
    func testSwizzledSetContentOffsetCapturesEveryWriteForTheTargetInstance() {
        let sink = CaptureSink()
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        scrollView.contentSize = CGSize(width: 320, height: 4000)

        UIScrollViewPhysicsSwizzler.installIfNeeded()
        sink.attach(to: scrollView)
        defer { sink.detach() }

        // setContentOffset:animated:false calls through to the bare setContentOffset: internally,
        // which is the selector we swizzle — so these writes are captured.
        scrollView.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        scrollView.setContentOffset(CGPoint(x: 0, y: 250), animated: false)

        XCTAssertEqual(sink.frames.map { $0.groundTruthOffset.y }, [100, 250])
        // No active gesture → frames are classified as decelerating with zeroed input.
        XCTAssertEqual(sink.frames.map { $0.phase }, [.decelerating, .decelerating])
        // The real offset is still applied (swizzle calls through to the original IMP).
        XCTAssertEqual(scrollView.contentOffset.y, 250, accuracy: 1e-9)
    }

    func testCaptureIsScopedToTheAttachedInstance() {
        let sink = CaptureSink()
        let target = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        let other = UIScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        other.contentSize = CGSize(width: 320, height: 4000)

        UIScrollViewPhysicsSwizzler.installIfNeeded()
        sink.attach(to: target)
        defer { sink.detach() }

        other.setContentOffset(CGPoint(x: 0, y: 99), animated: false)   // different instance
        XCTAssertTrue(sink.frames.isEmpty)                              // must NOT be captured
    }
}
