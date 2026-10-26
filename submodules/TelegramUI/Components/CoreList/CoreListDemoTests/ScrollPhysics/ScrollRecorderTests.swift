import XCTest
import UIKit
@testable import CoreListDemo

final class ScrollRecorderTests: XCTestCase {
    func testProgrammaticScrollProducesNonEmptyRecordingWithGeometry() {
        let vc = ScrollRecorderViewController()
        vc.loadViewIfNeeded()
        vc.view.frame = CGRect(x: 0, y: 0, width: 320, height: 800)
        vc.view.layoutIfNeeded()

        vc.beginRecording(named: "smoke")
        // Frames are event-sourced from setContentOffset writes via the swizzle (no captureFrame).
        // With no active gesture, the pan recognizer is idle → frames classify as .decelerating.
        vc.scrollView.setContentOffset(CGPoint(x: 0, y: 40), animated: false)
        vc.scrollView.setContentOffset(CGPoint(x: 0, y: 70), animated: false)
        let recording = vc.endRecording()

        XCTAssertEqual(recording.name, "smoke")
        XCTAssertEqual(recording.frames.count, 2)
        XCTAssertEqual(recording.frames.map { $0.groundTruthOffset.y }, [40, 70])  // captured at-write
        XCTAssertEqual(recording.frames[0].phase, .decelerating)
        XCTAssertEqual(recording.geometry.boundsHeight, 800, accuracy: 1e-9)
        XCTAssertGreaterThan(recording.geometry.contentHeight, 800)   // tall content
    }

    func testFixtureNamePrefixesTrackpadOnly() {
        XCTAssertEqual(ScrollRecorderViewController.fixtureName(scenario: "medium-flick", trackpad: true),
                       "trackpad-medium-flick")
        XCTAssertEqual(ScrollRecorderViewController.fixtureName(scenario: "medium-flick", trackpad: false),
                       "medium-flick")
    }
}
