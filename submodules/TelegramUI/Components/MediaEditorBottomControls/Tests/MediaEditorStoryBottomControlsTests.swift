import Foundation
import UIKit
import XCTest
@testable import MediaEditorBottomControls

final class MediaEditorStoryBottomControlsTests: XCTestCase {
    func testIPhone18ProRestGeometryMatchesTheStoryEditor() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 402.0, height: 874.0), isTablet: false, statusBarHeight: 54.0, safeBottomInset: 874.0 - 714.667 - 59.0, hasStatusIsland: false, hasReservedCorners: false)
        XCTAssertEqual(geometry.panelFrame.minY, 781.7, accuracy: 0.05)
        XCTAssertEqual(geometry.spec.sideInset, 16.0)
        XCTAssertEqual(geometry.spec.middleCentering, .betweenSideButtons)
        let layout = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: geometry.spec, middleItemWidths: [44.0, 44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 83.0)
        XCTAssertEqual(layout.leftFrame.minX, 16.0)
        XCTAssertEqual(layout.leftFrame.maxX, 60.0)
        XCTAssertEqual(layout.rightFrame.minX, 303.0)
        XCTAssertEqual(layout.rightFrame.maxX, 386.0)
        XCTAssertEqual(layout.middleFrame!.minX, 78.3, accuracy: 0.5)
        XCTAssertEqual(layout.middleFrame!.maxX, 284.3, accuracy: 0.5)
    }

    func testNarrowScreenUsesInset9() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 320.0, height: 640.0), isTablet: false, statusBarHeight: 20.0, safeBottomInset: 40.0, hasStatusIsland: false, hasReservedCorners: false)
        XCTAssertEqual(geometry.spec.sideInset, 9.0)
    }

    func testTabletUsesInset30() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 820.0, height: 1180.0), isTablet: true, statusBarHeight: 24.0, safeBottomInset: 50.0, hasStatusIsland: false, hasReservedCorners: false)
        XCTAssertEqual(geometry.spec.sideInset, 30.0)
        XCTAssertEqual(geometry.panelFrame.minY, 1180.0 - 50.0 + 8.0)
    }

    func testTabletRightButtonKeepsClearOfTheBottomEdgeInset() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 900.0, height: 700.0), isTablet: true, statusBarHeight: 24.0, safeBottomInset: 50.0, hasStatusIsland: false, hasReservedCorners: true, bottomEdgeRightInset: 36.0)
        XCTAssertEqual(geometry.spec.sideInset, 30.0)
        XCTAssertEqual(geometry.spec.rightExtraInset, 36.0)
        let layout = mediaEditorBottomControlsLocalLayout(width: 900.0, spec: geometry.spec, middleItemWidths: [44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 44.0)
        XCTAssertEqual(layout.leftFrame.minX, 30.0)
        XCTAssertEqual(layout.rightFrame.maxX, 900.0 - 36.0 - 30.0)
    }

    func testPhoneIgnoresTheBottomEdgeInsetAsToday() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 402.0, height: 874.0), isTablet: false, statusBarHeight: 54.0, safeBottomInset: 100.333, hasStatusIsland: false, hasReservedCorners: false, bottomEdgeRightInset: 36.0)
        XCTAssertEqual(geometry.spec.rightExtraInset, 0.0)
        let zero = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 900.0, height: 700.0), isTablet: true, statusBarHeight: 24.0, safeBottomInset: 50.0, hasStatusIsland: false, hasReservedCorners: false, bottomEdgeRightInset: 0.0)
        XCTAssertEqual(zero.spec.rightExtraInset, 0.0)
    }

    func testShortScreenLiftsTheBarBy62() {
        let geometry = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 375.0, height: 667.0), isTablet: false, statusBarHeight: 20.0, safeBottomInset: 0.0, hasStatusIsland: false, hasReservedCorners: false)
        XCTAssertEqual(geometry.panelFrame.minY, 667.0 + 8.0 - 62.0)
        XCTAssertEqual(geometry.spec.sideInset, 9.0)
        let island = mediaEditorStoryBottomControlsGeometry(size: CGSize(width: 375.0, height: 667.0), isTablet: false, statusBarHeight: 30.0, safeBottomInset: 0.0, hasStatusIsland: true, hasReservedCorners: false)
        XCTAssertEqual(island.panelFrame.minY, 667.0 + 8.0 - (30.0 + 31.0 + 30.0))
        XCTAssertEqual(island.spec.sideInset, 16.0)
    }

    func testStoryRestItems() {
        let story = mediaEditorStoryBottomControlsItems(state: .rest(.story(isEditingStory: false, isNarrow: false)))
        XCTAssertEqual(story.left, .back)
        XCTAssertEqual(story.middle, [.draw, .text, .sticker, .tools])
        XCTAssertEqual(story.right, .next(isDone: false))
        XCTAssertNil(story.selected)
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .rest(.story(isEditingStory: true, isNarrow: false))).right, .next(isDone: true))
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .rest(.story(isEditingStory: false, isNarrow: true))).right, .nextIcon)
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .rest(.botPreview)).right, .add)
    }

    func testOtherModesRestItems() {
        let sticker = mediaEditorStoryBottomControlsItems(state: .rest(.sticker(isEmpty: false)))
        XCTAssertEqual(sticker.middle, [.draw, .text, .sticker, .tools])
        XCTAssertEqual(sticker.right, .check)
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .rest(.sticker(isEmpty: true))).middle, [.draw, .text, .sticker])
        let avatar = mediaEditorStoryBottomControlsItems(state: .rest(.avatar))
        XCTAssertEqual(avatar.middle, [.rotate, .flip, .draw, .tools])
        XCTAssertEqual(avatar.right, .check)
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .rest(.cover)).middle, [.rotate, .flip, .draw, .tools])
    }

    func testDrawItems() {
        let items = mediaEditorStoryBottomControlsItems(state: .draw(.sticker))
        XCTAssertEqual(items.left, .close)
        XCTAssertEqual(items.middle, [.paint(.drawing), .paint(.sticker), .paint(.text)])
        XCTAssertEqual(items.selected, .paint(.sticker))
        XCTAssertEqual(items.right, .check)
    }

    func testToolsItems() {
        let items = mediaEditorStoryBottomControlsItems(state: .tools(selected: .tint, active: [.adjustments], hidesBlur: false))
        XCTAssertEqual(items.left, .close)
        XCTAssertEqual(items.middle, [.tool(.adjustments), .tool(.tint), .tool(.blur), .tool(.curves)])
        XCTAssertEqual(items.selected, .tool(.tint))
        XCTAssertEqual(items.highlighted, [.tool(.adjustments)])
        XCTAssertEqual(items.right, .check)
        XCTAssertEqual(mediaEditorStoryBottomControlsItems(state: .tools(selected: .curves, active: [], hidesBlur: true)).middle, [.tool(.adjustments), .tool(.tint), .tool(.curves)])
    }

    func testIdsNeverRepeatAcrossStates() {
        let rest = Set(mediaEditorStoryBottomControlsItems(state: .rest(.story(isEditingStory: false, isNarrow: false))).middle.map(\.id))
        let draw = Set(mediaEditorStoryBottomControlsItems(state: .draw(.drawing)).middle.map(\.id))
        let tools = Set(mediaEditorStoryBottomControlsItems(state: .tools(selected: .adjustments, active: [], hidesBlur: false)).middle.map(\.id))
        XCTAssertTrue(rest.isDisjoint(with: draw))
        XCTAssertTrue(rest.isDisjoint(with: tools))
        XCTAssertTrue(draw.isDisjoint(with: tools))
        XCTAssertEqual(MediaEditorStoryBottomControlsRight.next(isDone: false).id, "next")
        XCTAssertEqual(MediaEditorStoryBottomControlsRight.next(isDone: true).id, "done")
    }

    func testCaptionEditingHidesTheBar() {
        XCTAssertTrue(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: false, isDismissing: false, isInteractingWithEntities: false, isEditingText: false, isEditingCaption: true))
    }

    func testHidingRule() {
        XCTAssertFalse(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: false, isDismissing: false, isInteractingWithEntities: false, isEditingText: false, isEditingCaption: false))
        XCTAssertTrue(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: true, isDismissing: false, isInteractingWithEntities: false, isEditingText: false, isEditingCaption: false))
        XCTAssertTrue(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: false, isDismissing: true, isInteractingWithEntities: false, isEditingText: false, isEditingCaption: false))
        XCTAssertTrue(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: false, isDismissing: false, isInteractingWithEntities: true, isEditingText: false, isEditingCaption: false))
        XCTAssertTrue(mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: false, isDismissing: false, isInteractingWithEntities: false, isEditingText: true, isEditingCaption: false))
    }
}
