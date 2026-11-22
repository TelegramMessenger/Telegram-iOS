import XCTest
import UIKit
import Display
import ChatMediaEditorScreen

final class ChatMediaEditorOrientationTests: XCTestCase {
    func testSupportedOrientationsWhenLockingPortrait() {
        let orientations = chatMediaEditorSupportedOrientations(locksPortrait: true)
        XCTAssertEqual(orientations, ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait))
    }

    func testPortraitLockWhilePaintingOrEditingCover() {
        XCTAssertTrue(chatMediaEditorLocksPortrait(isPainting: true, isEditingCover: false))
        XCTAssertTrue(chatMediaEditorLocksPortrait(isPainting: false, isEditingCover: true))
        XCTAssertTrue(chatMediaEditorLocksPortrait(isPainting: true, isEditingCover: true))
        XCTAssertFalse(chatMediaEditorLocksPortrait(isPainting: false, isEditingCover: false))
    }

    func testSupportedOrientationsOtherwise() {
        let orientations = chatMediaEditorSupportedOrientations(locksPortrait: false)
        XCTAssertEqual(orientations, ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown))
    }

    func testCaptionHiddenInLandscape() {
        XCTAssertFalse(chatMediaEditorCaptionIsVisible(toolbarSide: .left, isToolActive: false, isInterfaceHidden: false))
        XCTAssertFalse(chatMediaEditorCaptionIsVisible(toolbarSide: .right, isToolActive: false, isInterfaceHidden: false))
        XCTAssertTrue(chatMediaEditorCaptionIsVisible(toolbarSide: nil, isToolActive: false, isInterfaceHidden: false))
        XCTAssertFalse(chatMediaEditorCaptionIsVisible(toolbarSide: nil, isToolActive: true, isInterfaceHidden: false))
        XCTAssertFalse(chatMediaEditorCaptionIsVisible(toolbarSide: nil, isToolActive: false, isInterfaceHidden: true))
    }

    func testOrientationLockWhileTracking() {
        var set = ChatMediaEditorTrackingSet()
        XCTAssertFalse(chatMediaEditorLocksOrientation(isTracking: set.isTracking))
        set.update(true, source: "crop")
        set.update(true, source: "pager")
        XCTAssertTrue(chatMediaEditorLocksOrientation(isTracking: set.isTracking))
        set.update(false, source: "crop")
        XCTAssertTrue(chatMediaEditorLocksOrientation(isTracking: set.isTracking))
        set.update(false, source: "crop")
        XCTAssertTrue(chatMediaEditorLocksOrientation(isTracking: set.isTracking))
        set.update(false, source: "pager")
        XCTAssertFalse(chatMediaEditorLocksOrientation(isTracking: set.isTracking))
    }

    func testLockedOrientationMask() {
        XCTAssertEqual(chatMediaEditorLockedOrientationMask(.landscapeLeft), .landscapeLeft)
        XCTAssertEqual(chatMediaEditorLockedOrientationMask(.landscapeRight), .landscapeRight)
        XCTAssertEqual(chatMediaEditorLockedOrientationMask(.portrait), .portrait)
        XCTAssertNil(chatMediaEditorLockedOrientationMask(nil))
        XCTAssertNil(chatMediaEditorLockedOrientationMask(.unknown))
    }
}
