import Foundation
import XCTest
import ChatMediaSend
import ChatMediaEditorScreen

final class ChatMediaEditorLivePhotoPlaybackTests: XCTestCase {
    func testLiveAutoplaysOnceAndFadesAtEnd() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        XCTAssertEqual(model.update(itemId: "a", mode: .live, isActive: true), .playForward(fromStart: true))
        XCTAssertEqual(model.update(itemId: "a", mode: .live, isActive: true), .none)
        XCTAssertEqual(model.reachedEnd(), .fadeOut)
        XCTAssertEqual(model.reachedStart(), .none)
    }

    func testModeChangeToLiveAutoplays() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        XCTAssertEqual(model.update(itemId: "a", mode: .off, isActive: true), .none)
        XCTAssertEqual(model.update(itemId: "a", mode: .live, isActive: true), .playForward(fromStart: true))
        XCTAssertEqual(model.update(itemId: "a", mode: .off, isActive: true), .hide)
    }

    func testLoopRestartsAtEnd() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        XCTAssertEqual(model.update(itemId: "a", mode: .loop, isActive: true), .playForward(fromStart: true))
        XCTAssertEqual(model.reachedEnd(), .playForward(fromStart: true))
        XCTAssertEqual(model.reachedEnd(), .playForward(fromStart: true))
        XCTAssertEqual(model.holdBegan(), .none)
    }

    func testBouncePlaysForwardThenBackward() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        XCTAssertEqual(model.update(itemId: "a", mode: .bounce, isActive: true), .playForward(fromStart: true))
        XCTAssertEqual(model.reachedStart(), .none)
        XCTAssertEqual(model.reachedEnd(), .playBackward)
        XCTAssertTrue(model.isPlayingBackward)
        XCTAssertEqual(model.reachedEnd(), .none)
        XCTAssertEqual(model.reachedStart(), .playForward(fromStart: false))
        XCTAssertFalse(model.isPlayingBackward)
        XCTAssertEqual(model.reachedEnd(), .playBackward)
    }

    func testHoldLoopsWhileHeldAndSuppressesNextTap() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        let _ = model.update(itemId: "a", mode: .live, isActive: true)
        XCTAssertTrue(model.holdGatesTap)
        XCTAssertTrue(model.allowsSelectionTap)
        XCTAssertEqual(model.holdBegan(), .playForward(fromStart: true))
        XCTAssertFalse(model.allowsSelectionTap)
        XCTAssertEqual(model.reachedEnd(), .playForward(fromStart: true))
        XCTAssertEqual(model.holdEnded(), .fadeOut)
        XCTAssertEqual(model.holdEnded(), .none)
        XCTAssertEqual(model.reachedEnd(), .fadeOut)
    }

    func testHoldOnlyInLiveMode() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        XCTAssertEqual(model.holdBegan(), .none)
        let _ = model.update(itemId: "a", mode: .bounce, isActive: true)
        XCTAssertEqual(model.holdBegan(), .none)
        XCTAssertFalse(model.holdGatesTap)
        XCTAssertTrue(model.allowsSelectionTap)
        let _ = model.update(itemId: "a", mode: .live, isActive: false)
        XCTAssertEqual(model.holdBegan(), .none)
        XCTAssertFalse(model.holdGatesTap)
    }

    func testStopsWhenInactiveAndRestartsWhenActiveAgain() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        let _ = model.update(itemId: "a", mode: .loop, isActive: true)
        XCTAssertEqual(model.update(itemId: "a", mode: .loop, isActive: false), .hide)
        XCTAssertEqual(model.reachedEnd(), .none)
        XCTAssertEqual(model.update(itemId: "a", mode: .loop, isActive: true), .playForward(fromStart: true))
    }

    func testPageChangeStopsAndStartsTheNewItem() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        let _ = model.update(itemId: "a", mode: .live, isActive: true)
        let _ = model.holdBegan()
        XCTAssertEqual(model.update(itemId: "b", mode: .live, isActive: true), .playForward(fromStart: true))
        XCTAssertFalse(model.isHolding)
        XCTAssertTrue(model.allowsSelectionTap)
        XCTAssertEqual(model.update(itemId: "c", mode: .off, isActive: true), .hide)
        XCTAssertEqual(model.update(itemId: nil, mode: .off, isActive: false), .none)
    }

    func testHoldWithoutTapLeavesNextTapEnabled() {
        let model = ChatMediaEditorLivePhotoPlaybackModel()
        let _ = model.update(itemId: "a", mode: .live, isActive: true)
        let _ = model.holdBegan()
        let _ = model.holdEnded()
        XCTAssertTrue(model.allowsSelectionTap)
        XCTAssertTrue(model.allowsSelectionTap)
        let _ = model.holdBegan()
        let _ = model.update(itemId: "a", mode: .live, isActive: false)
        XCTAssertTrue(model.allowsSelectionTap)
    }

    func testPaintingOverlayHidesVideoWithoutFade() {
        XCTAssertTrue(chatMediaEditorLivePhotoFadesOut(hasPaintingOverlay: false))
        XCTAssertFalse(chatMediaEditorLivePhotoFadesOut(hasPaintingOverlay: true))
    }
}
