import Foundation
import UIKit
import XCTest
import LegacyComponents
import ComponentFlow
import Display
@testable import ChatMediaEditorScreen

final class ChatMediaEditorBottomControlsLayoutTests: XCTestCase {
    let size = CGSize(width: 402.0, height: 874.0)
    let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 20.0, right: 0.0)

    private func screenFrame(_ frame: CGRect, _ layout: ChatMediaEditorBottomControlsLayout) -> CGRect {
        return frame.offsetBy(dx: layout.panelFrame.minX, dy: layout.panelFrame.minY)
    }

    func testPanelSitsAboveTheBottomInset() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [44.0, 44.0, 44.0, 44.0], rightWidth: 46.0)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 0.0, y: 874.0 - 20.0 - 49.0, width: 402.0, height: 49.0))
    }

    func testGalleryMatchesLegacy() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [44.0, 44.0, 44.0, 44.0], rightWidth: chatMediaEditorBottomControlsRightWidth(.send))
        let y = 874.0 - 20.0 - 49.0
        XCTAssertEqual(screenFrame(layout.leftFrame, layout), CGRect(x: 26.0, y: y, width: 44.0, height: 44.0))
        XCTAssertEqual(screenFrame(layout.rightFrame, layout), CGRect(x: 330.0, y: y, width: 46.0, height: 44.0))
        XCTAssertEqual(layout.middleFrame.map { screenFrame($0, layout) }, CGRect(x: 98.0, y: y, width: 206.0, height: 44.0))
        XCTAssertEqual(layout.itemFrames.map { $0.minX }, [98.0, 152.0, 206.0, 260.0])
        XCTAssertEqual(layout.itemFrames.map { $0.width }, [44.0, 44.0, 44.0, 44.0])
        XCTAssertEqual(layout.itemFrames.map { $0.minY }, [0.0, 0.0, 0.0, 0.0])
    }

    func testCropMatchesLegacy() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [44.0, 44.0, 44.0], rightWidth: chatMediaEditorBottomControlsRightWidth(.check))
        XCTAssertEqual(layout.leftFrame.minX, 26.0)
        XCTAssertEqual(layout.leftFrame.maxX, 70.0)
        XCTAssertEqual(layout.middleFrame?.minX, 125.0)
        XCTAssertEqual(layout.middleFrame?.maxX, 277.0)
        XCTAssertEqual(layout.rightFrame.minX, 332.0)
        XCTAssertEqual(layout.rightFrame.maxX, 376.0)
    }

    func testScheduleIsAsWideAsSend() {
        XCTAssertEqual(chatMediaEditorBottomControlsRightWidth(.send), 46.0)
        XCTAssertEqual(chatMediaEditorBottomControlsRightWidth(.schedule), 46.0)
        XCTAssertEqual(chatMediaEditorBottomControlsRightWidth(.check), 44.0)
    }

    func testMiddleIsCenteredBetweenTheButtonSlotsNotTheSideButtons() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [44.0, 44.0, 44.0, 44.0], rightWidth: 46.0)
        let middle = layout.middleFrame!
        XCTAssertEqual(middle.minX - 44.0, 402.0 - 44.0 - middle.maxX)
    }

    func testTextItemsKeepTheSpacingAndStayCentered() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [60.0, 70.0, 50.0], rightWidth: 44.0)
        XCTAssertEqual(layout.itemFrames[1].minX - layout.itemFrames[0].maxX, 10.0)
        XCTAssertEqual(layout.itemFrames[2].minX - layout.itemFrames[1].maxX, 10.0)
        XCTAssertEqual(layout.middleFrame?.width, 200.0)
        XCTAssertEqual(layout.middleFrame?.midX, 201.0)
    }

    func testEmptyMiddleHasNoCapsule() {
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [], rightWidth: 44.0)
        XCTAssertNil(layout.middleFrame)
        XCTAssertEqual(layout.itemFrames, [])
    }

    func testLandscapeLayoutSendTopCancelBottom() {
        let landscapeSize = CGSize(width: 874.0, height: 402.0)
        let landscapeInsets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        let layout = chatMediaEditorBottomControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, middleItemWidths: [44.0, 44.0, 44.0, 44.0], rightWidth: chatMediaEditorBottomControlsRightWidth(.send), side: .left)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 62.0, y: 26.0, width: 49.0, height: 350.0))
        let right = screenFrame(layout.rightFrame, layout)
        let left = screenFrame(layout.leftFrame, layout)
        XCTAssertEqual(right.minY, 26.0)
        XCTAssertEqual(right.height, 44.0)
        XCTAssertEqual(left.maxY, 376.0)
        XCTAssertEqual(left.height, 44.0)
        XCTAssertEqual(right.minX, 62.0 + floorToScreenPixels(1.5))
        XCTAssertEqual(left.minX, 62.0 + floorToScreenPixels(2.5))
        XCTAssertEqual(layout.itemFrames.map { $0.midY }, [94.0, 148.0, 202.0, 256.0])
        XCTAssertEqual(layout.itemFrames.map { $0.minX }, Array(repeating: floorToScreenPixels(2.5), count: 4))
        XCTAssertEqual(layout.itemFrames.map { $0.size }, Array(repeating: CGSize(width: 44.0, height: 44.0), count: 4))
        XCTAssertEqual(layout.middleFrame, CGRect(x: floorToScreenPixels(2.5), y: 72.0, width: 44.0, height: 206.0))
    }

    func testLandscapeLayoutRightSideUsesRightColumn() {
        let landscapeSize = CGSize(width: 874.0, height: 402.0)
        let landscapeInsets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        let layout = chatMediaEditorBottomControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, middleItemWidths: [44.0, 44.0, 44.0], rightWidth: 44.0, side: .right)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 763.0, y: 26.0, width: 49.0, height: 350.0))
        XCTAssertEqual(screenFrame(layout.rightFrame, layout).minX, 763.0 + floorToScreenPixels(2.5))
        XCTAssertEqual(layout.itemFrames.map { $0.midY }, [121.0, 175.0, 229.0])
    }

    func testLandscapeLayoutEmptyMiddleHasNoCapsule() {
        let layout = chatMediaEditorBottomControlsLayout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0), middleItemWidths: [], rightWidth: 44.0, side: .left)
        XCTAssertNil(layout.middleFrame)
        XCTAssertEqual(layout.itemFrames, [])
    }

    func testLandscapeColumnKeepsClearOfReservedCorner() {
        let duoSize = CGSize(width: 678.0, height: 466.0)
        let duoInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: CGSize(width: 84.0, height: 82.0), bottomRight: nil)
        let layout = chatMediaEditorBottomControlsLayout(size: duoSize, safeInsets: duoInsets, middleItemWidths: [44.0], rightWidth: 44.0, side: .left, reservedCorners: corners)
        XCTAssertEqual(layout.panelFrame, chatMediaEditorLandscapeColumnFrame(size: duoSize, safeInsets: duoInsets, side: .left, reservedCorners: corners))
        XCTAssertEqual(screenFrame(layout.leftFrame, layout).maxY, 384.0)
    }

    func testPortraitBottomControlsUnchanged() {
        let fixtures: [([CGFloat], CGFloat, CGFloat)] = [
            ([44.0, 44.0, 44.0, 44.0], chatMediaEditorBottomControlsMiddleSpacing, 46.0),
            ([44.0, 44.0, 44.0], chatMediaEditorBottomControlsMiddleSpacing, 44.0),
            ([60.0, 70.0, 50.0], chatMediaEditorBottomControlsMiddleSpacing, 44.0),
            ([68.0, 81.0, 64.0], chatMediaEditorBottomControlsPaintSpacing, 44.0),
            ([], chatMediaEditorBottomControlsMiddleSpacing, 44.0)
        ]
        for (widths, spacing, rightWidth) in fixtures {
            XCTAssertEqual(
                chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: widths, middleSpacing: spacing, rightWidth: rightWidth, side: nil),
                chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: widths, middleSpacing: spacing, rightWidth: rightWidth)
            )
        }
        let layout = chatMediaEditorBottomControlsLayout(size: size, safeInsets: insets, middleItemWidths: [44.0, 44.0, 44.0, 44.0], rightWidth: 46.0, side: nil)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 0.0, y: 874.0 - 20.0 - 49.0, width: 402.0, height: 49.0))
        XCTAssertEqual(layout.middleFrame, CGRect(x: 98.0, y: 0.0, width: 206.0, height: 44.0))
    }
}

final class ChatMediaEditorBottomControlsItemsTests: XCTestCase {
    private func items(
        mode: ChatMediaEditorBottomControlsMode,
        isGallery: Bool = true,
        isVideo: Bool = false,
        showsQuality: Bool = true,
        policy: ChatMediaEditorTabPolicy = .standard,
        sendButton: ChatMediaEditorBottomControlsRightItem = .send,
        highlightedTabs: TGPhotoEditorTab = [],
        disabledTabs: TGPhotoEditorTab = [],
        qualityHighQuality: Bool = false,
        qualityPreset: Int = 0
    ) -> ChatMediaEditorBottomControlsItems {
        return chatMediaEditorBottomControlsItems(
            mode: mode,
            isGallery: isGallery,
            isVideo: isVideo,
            showsQuality: showsQuality,
            policy: policy,
            sendButton: sendButton,
            highlightedTabs: highlightedTabs,
            disabledTabs: disabledTabs,
            qualityHighQuality: qualityHighQuality,
            qualityPreset: qualityPreset
        )
    }

    private func tabId(_ tab: TGPhotoEditorTab) -> String {
        return chatMediaEditorBottomControlsTabId(tab)
    }

    func testPhotoGalleryHasFourTabsInLegacyOrder() {
        let result = items(mode: .gallery(activeTab: []))
        XCTAssertEqual(result.left, .back)
        XCTAssertEqual(result.right, .send)
        XCTAssertEqual(result.middle.map(\.id), [tabId(.cropTab), tabId(.paintTab), tabId(.toolsTab), tabId(.qualityTab)])
        XCTAssertEqual(result.middle.map(\.action), [.tab(.cropTab), .tab(.paintTab), .tab(.toolsTab), .tab(.qualityTab)])
        XCTAssertEqual(result.middle[0].content, .icon("Media Editor/Crop"))
        XCTAssertEqual(result.middle[1].content, .icon("Media Editor/Pencil"))
        XCTAssertEqual(result.middle[2].content, .icon("Media Editor/Adjustments"))
        XCTAssertNil(result.selectedId)
    }

    func testPhotoQualityTabShowsHdOrSd() {
        XCTAssertEqual(items(mode: .gallery(activeTab: []), qualityHighQuality: true).middle[3].content, .quality(isPhoto: true, highQuality: true, preset: 0))
        XCTAssertEqual(items(mode: .gallery(activeTab: []), qualityHighQuality: false).middle[3].content, .quality(isPhoto: true, highQuality: false, preset: 0))
    }

    func testVideoQualityTabShowsThePreset() {
        let result = items(mode: .gallery(activeTab: []), isVideo: true, qualityPreset: 4)
        XCTAssertEqual(result.middle.count, 4)
        XCTAssertEqual(result.middle[3].content, .quality(isPhoto: false, highQuality: false, preset: 4))
    }

    func testGifHasThreeTabs() {
        let result = items(mode: .gallery(activeTab: []), isVideo: true, showsQuality: false)
        XCTAssertEqual(result.middle.map(\.id), [tabId(.cropTab), tabId(.paintTab), tabId(.toolsTab)])
    }

    func testFilePreviewAndCropOnlyPolicies() {
        XCTAssertEqual(items(mode: .gallery(activeTab: []), policy: .filePreview).middle, [])
        XCTAssertEqual(items(mode: .gallery(activeTab: []), policy: .cropOnly).middle.map(\.id), [tabId(.cropTab)])
    }

    func testNonGalleryEditorUsesClose() {
        XCTAssertEqual(items(mode: .gallery(activeTab: []), isGallery: false).left, .close)
    }

    func testScheduleButtonIsKept() {
        XCTAssertEqual(items(mode: .gallery(activeTab: []), sendButton: .schedule).right, .schedule)
    }

    func testGalleryHighlightsEditedToolsAndDisablesMutedQuality() {
        let result = items(mode: .gallery(activeTab: []), isVideo: true, highlightedTabs: [.cropTab, .toolsTab], disabledTabs: [.qualityTab])
        XCTAssertEqual(result.middle.map(\.isHighlighted), [true, false, true, false])
        XCTAssertEqual(result.middle.map(\.isDisabled), [false, false, false, true])
    }

    func testGallerySelectionOnlyForToolTabs() {
        XCTAssertEqual(items(mode: .gallery(activeTab: .paintTab)).selectedId, tabId(.paintTab))
        XCTAssertEqual(items(mode: .gallery(activeTab: .toolsTab)).selectedId, tabId(.toolsTab))
        XCTAssertNil(items(mode: .gallery(activeTab: .qualityTab)).selectedId)
    }

    func testCropTabsAndHighlights() {
        let result = items(mode: .crop(highlightedTabs: [.mirrorTab, .aspectRatioTab]))
        XCTAssertEqual(result.left, .close)
        XCTAssertEqual(result.right, .check)
        XCTAssertEqual(result.middle.map(\.id), [tabId(.rotateTab), tabId(.mirrorTab), tabId(.aspectRatioTab)])
        XCTAssertEqual(result.middle.map(\.content), [.icon("Editor/Rotate"), .icon("Media Editor/Mirror"), .icon("Editor/AspectRatio")])
        XCTAssertEqual(result.middle.map(\.isHighlighted), [false, true, true])
        XCTAssertNil(result.selectedId)
        XCTAssertEqual(items(mode: .crop(highlightedTabs: [])).middle.map(\.isHighlighted), [false, false, false])
    }

    func testCropIdsNeverReuseGalleryIds() {
        let gallery = Set(items(mode: .gallery(activeTab: [])).middle.map(\.id))
        let crop = Set(items(mode: .crop(highlightedTabs: [])).middle.map(\.id))
        XCTAssertTrue(gallery.isDisjoint(with: crop))
    }

    func testToolsTabsForPhotoAndVideo() {
        let photo = items(mode: .tools(selected: .tint, highlighted: []))
        XCTAssertEqual(photo.left, .close)
        XCTAssertEqual(photo.right, .check)
        XCTAssertEqual(photo.middle.map(\.id), ["tool.adjustments", "tool.tint", "tool.blur", "tool.curves"])
        XCTAssertEqual(photo.middle.map(\.action), [.tools(.adjustments), .tools(.tint), .tools(.blur), .tools(.curves)])
        XCTAssertEqual(photo.middle.map(\.content), [.icon("Media Editor/Adjustments"), .icon("Media Editor/Tint"), .icon("Media Editor/Blur"), .icon("Media Editor/Curves")])
        XCTAssertEqual(photo.selectedId, "tool.tint")
        let video = items(mode: .tools(selected: .adjustments, highlighted: []), isVideo: true)
        XCTAssertEqual(video.middle.map(\.id), ["tool.adjustments", "tool.tint", "tool.curves"])
        XCTAssertEqual(video.selectedId, "tool.adjustments")
    }

    func testToolsIdsNeverReuseGalleryIds() {
        let gallery = Set(items(mode: .gallery(activeTab: [])).middle.map(\.id))
        let tools = Set(items(mode: .tools(selected: .adjustments, highlighted: [])).middle.map(\.id))
        XCTAssertTrue(gallery.isDisjoint(with: tools))
    }

    func testToolsHighlightEditedTools() {
        let result = items(mode: .tools(selected: .tint, highlighted: [.adjustments, .curves]))
        XCTAssertEqual(result.middle.map(\.isHighlighted), [true, false, false, true])
        XCTAssertEqual(result.middleSpacing, 10.0)
    }

    func testPaintSegmentsUseLegacyModeSpacing() {
        let result = items(mode: .paint(selected: .draw))
        XCTAssertEqual(result.middleSpacing, -12.0)
        let layout = chatMediaEditorBottomControlsLayout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 20.0, right: 0.0), middleItemWidths: [36.0 + 32.0, 49.0 + 32.0, 32.0 + 32.0], middleSpacing: result.middleSpacing, rightWidth: 44.0)
        XCTAssertEqual(layout.middleFrame?.width, 36.0 + 49.0 + 32.0 + 16.0 * 2.0 + 20.0 * 2.0)
        XCTAssertEqual(layout.itemFrames[1].minX + 16.0 - (layout.itemFrames[0].maxX - 16.0), 20.0)
    }

    func testSelectionPillKeepsTheSameInsetOnEverySide() {
        XCTAssertEqual(chatMediaEditorBottomControlsSelectionFrame(itemFrame: CGRect(x: 10.0, y: 0.0, width: 44.0, height: 44.0)), CGRect(x: 13.0, y: 3.0, width: 38.0, height: 38.0))
        XCTAssertEqual(chatMediaEditorBottomControlsSelectionFrame(itemFrame: CGRect(x: 0.0, y: 0.0, width: 68.0, height: 44.0)), CGRect(x: 3.0, y: 3.0, width: 62.0, height: 38.0))
    }

    func testFirstAndLastPaintPillsSitInsideTheCapsuleLikeTopAndBottom() {
        let layout = chatMediaEditorBottomControlsLayout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 20.0, right: 0.0), middleItemWidths: [68.0, 81.0, 64.0], middleSpacing: chatMediaEditorBottomControlsPaintSpacing, rightWidth: 44.0)
        let middle = layout.middleFrame!
        let first = chatMediaEditorBottomControlsSelectionFrame(itemFrame: layout.itemFrames[0])
        let last = chatMediaEditorBottomControlsSelectionFrame(itemFrame: layout.itemFrames[2])
        XCTAssertEqual(first.minX - middle.minX, first.minY - middle.minY)
        XCTAssertEqual(middle.maxX - last.maxX, middle.maxY - last.maxY)
    }

    func testPaintSegments() {
        let result = items(mode: .paint(selected: .sticker))
        XCTAssertEqual(result.left, .close)
        XCTAssertEqual(result.right, .check)
        XCTAssertEqual(result.middle.map(\.id), ["paint.draw", "paint.sticker", "paint.text"])
        XCTAssertEqual(result.middle.map(\.content), [.paintMode(.draw), .paintMode(.sticker), .paintMode(.text)])
        XCTAssertEqual(result.middle.map(\.action), [.paint(.draw), .paint(.sticker), .paint(.text)])
        XCTAssertEqual(result.selectedId, "paint.sticker")
    }

    func testQualityHasNoMiddle() {
        let result = items(mode: .quality, isVideo: true)
        XCTAssertEqual(result.left, .close)
        XCTAssertEqual(result.right, .check)
        XCTAssertEqual(result.middle, [])
        XCTAssertNil(result.selectedId)
    }

    func testRightItemFromGalleryDoneButton() {
        XCTAssertEqual(chatMediaEditorBottomControlsRightItem(doneButton: TGPhotoEditorDoneButtonSend), .send)
        XCTAssertEqual(chatMediaEditorBottomControlsRightItem(doneButton: TGPhotoEditorDoneButtonSchedule), .schedule)
        XCTAssertEqual(chatMediaEditorBottomControlsRightItem(doneButton: TGPhotoEditorDoneButtonDone), .check)
        XCTAssertEqual(chatMediaEditorBottomControlsRightItem(doneButton: TGPhotoEditorDoneButtonCheck), .check)
    }
}

private func tap(_ view: UIView?) {
    guard let control = view as? UIControl else {
        XCTFail("not a control")
        return
    }
    for target in control.allTargets {
        for action in control.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
            let _ = (target as NSObject).perform(Selector(action))
        }
    }
}

private func basicAnimation(_ layer: CALayer, _ key: String) -> CABasicAnimation? {
    return layer.animation(forKey: key) as? CABasicAnimation
}

private func animatedOriginX(_ layer: CALayer, atStart: Bool) -> CGFloat {
    var positionX = layer.position.x
    if let animation = basicAnimation(layer, "position") {
        let value = (atStart ? animation.fromValue : animation.toValue) as? NSValue
        if let point = value?.cgPointValue {
            positionX = animation.isAdditive ? layer.position.x + point.x : point.x
        }
    }
    var width = layer.bounds.width
    if let animation = basicAnimation(layer, "bounds.size") ?? basicAnimation(layer, "bounds") {
        let value = (atStart ? animation.fromValue : animation.toValue) as? NSValue
        if let value {
            if animation.keyPath == "bounds" {
                width = value.cgRectValue.width
            } else {
                width = value.cgSizeValue.width
            }
        }
    }
    return positionX - width * layer.anchorPoint.x
}

final class ChatMediaEditorBottomControlsComponentTests: XCTestCase {
    private let panelSize = CGSize(width: 402.0, height: 49.0)

    private func makeItems(_ mode: ChatMediaEditorBottomControlsMode) -> ChatMediaEditorBottomControlsItems {
        return chatMediaEditorBottomControlsItems(
            mode: mode,
            isGallery: true,
            isVideo: false,
            showsQuality: true,
            policy: .standard,
            sendButton: .send,
            highlightedTabs: [],
            disabledTabs: [],
            qualityHighQuality: true,
            qualityPreset: 0
        )
    }

    private func update(
        _ view: ComponentView<Empty>,
        _ items: ChatMediaEditorBottomControlsItems,
        transition: ComponentTransition,
        isHidden: Bool = false,
        isMiddleEnabled: Bool = true,
        isRightEnabled: Bool = true,
        leftPressed: @escaping () -> Void = {},
        rightPressed: @escaping () -> Void = {},
        pressed: @escaping (ChatMediaEditorBottomControlsAction) -> Void = { _ in }
    ) -> ChatMediaEditorBottomControlsComponent.View {
        let _ = view.update(
            transition: transition,
            component: AnyComponent(ChatMediaEditorBottomControlsComponent(
                items: items,
                isHidden: isHidden,
                isMiddleEnabled: isMiddleEnabled,
                areSideButtonsEnabled: true,
                isRightEnabled: isRightEnabled,
                infoString: nil,
                paintModeTitle: { _ in "Draw" },
                leftPressed: leftPressed,
                rightPressed: rightPressed,
                rightLongPressed: { _ in },
                middlePressed: pressed
            )),
            environment: {},
            forceUpdate: true,
            containerSize: panelSize
        )
        return view.view as! ChatMediaEditorBottomControlsComponent.View
    }

    private func screenX(_ itemView: UIView, in controls: ChatMediaEditorBottomControlsComponent.View, atStart: Bool) -> CGFloat {
        var x = itemView.convert(itemView.bounds, to: controls).minX
        guard atStart else {
            return x
        }
        var view: UIView? = itemView
        while let current = view, current !== controls {
            x += animatedOriginX(current.layer, atStart: true) - animatedOriginX(current.layer, atStart: false)
            view = current.superview
        }
        return x
    }

    func testLandscapeColumnLaysTheGlassOutVertically() {
        let view = ComponentView<Empty>()
        let columnSize = CGSize(width: 49.0, height: 382.0)
        let _ = view.update(
            transition: .immediate,
            component: AnyComponent(ChatMediaEditorBottomControlsComponent(
                items: makeItems(.gallery(activeTab: [])),
                isHidden: false,
                isMiddleEnabled: true,
                areSideButtonsEnabled: true,
                isRightEnabled: true,
                infoString: nil,
                paintModeTitle: { _ in "Draw" },
                leftPressed: {},
                rightPressed: {},
                rightLongPressed: { _ in },
                middlePressed: { _ in },
                side: .left
            )),
            environment: {},
            forceUpdate: true,
            containerSize: columnSize
        )
        let controls = view.view as! ChatMediaEditorBottomControlsComponent.View
        let ids = [TGPhotoEditorTab.cropTab, .paintTab, .toolsTab, .qualityTab].map(chatMediaEditorBottomControlsTabId)
        XCTAssertEqual(ids.compactMap { controls.middleItemFrame(id: $0, in: controls)?.midY }, [110.0, 164.0, 218.0, 272.0])
        XCTAssertEqual(ids.compactMap { controls.middleItemFrame(id: $0, in: controls)?.minX }, Array(repeating: floorToScreenPixels(2.5), count: 4))
        XCTAssertEqual(controls.rightButtonFrame(in: controls), CGRect(x: floorToScreenPixels(1.5), y: 0.0, width: 46.0, height: 44.0))
        XCTAssertEqual(controls.leftButtonView.map { $0.convert($0.bounds, to: controls) }, CGRect(x: floorToScreenPixels(2.5), y: 338.0, width: 44.0, height: 44.0))
        XCTAssertEqual(controls.middleCapsuleView.bounds.size, CGSize(width: 44.0, height: 206.0))
    }

    func testGalleryFramesMatchLegacy() {
        let view = ComponentView<Empty>()
        let controls = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let ids = [TGPhotoEditorTab.cropTab, .paintTab, .toolsTab, .qualityTab].map(chatMediaEditorBottomControlsTabId)
        XCTAssertEqual(ids.compactMap { controls.middleItemFrame(id: $0, in: controls)?.minX }, [98.0, 152.0, 206.0, 260.0])
        XCTAssertEqual(controls.rightButtonFrame(in: controls), CGRect(x: 330.0, y: 0.0, width: 46.0, height: 44.0))
    }

    func testInsertedButtonsStayStillOnScreenWhileTheCapsuleResizes() {
        let view = ComponentView<Empty>()
        let _ = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let controls = update(view, makeItems(.crop(highlightedTabs: [])), transition: .easeInOut(duration: 0.3))
        let ids = chatMediaEditorCropToolbarTabs().map(chatMediaEditorBottomControlsTabId)
        for (id, expected) in zip(ids, [125.0, 179.0, 233.0] as [CGFloat]) {
            let itemView = controls.middleItemView(id: id)!
            XCTAssertEqual(screenX(itemView, in: controls, atStart: true), expected, accuracy: 0.01, id)
            XCTAssertEqual(screenX(itemView, in: controls, atStart: false), expected, accuracy: 0.01, id)
        }
    }

    func testRemovedButtonsStayStillOnScreenAndInTheClippedCapsule() {
        let view = ComponentView<Empty>()
        let gallery = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let cropView = gallery.middleItemView(id: chatMediaEditorBottomControlsTabId(.cropTab))!
        let qualityView = gallery.middleItemView(id: chatMediaEditorBottomControlsTabId(.qualityTab))!
        let controls = update(view, makeItems(.crop(highlightedTabs: [])), transition: .easeInOut(duration: 0.3))
        XCTAssertNil(controls.middleItemView(id: chatMediaEditorBottomControlsTabId(.cropTab)))
        let rotate = controls.middleItemView(id: chatMediaEditorBottomControlsTabId(.rotateTab))!
        XCTAssertTrue(cropView.superview === rotate.superview)
        XCTAssertEqual(rotate.superview?.subviews.count, 7)
        XCTAssertTrue(rotate.superview?.clipsToBounds ?? false)
        for (removed, expected) in [(cropView, 98.0), (qualityView, 260.0)] as [(UIView, CGFloat)] {
            XCTAssertEqual(screenX(removed, in: controls, atStart: true), expected, accuracy: 0.01)
            XCTAssertEqual(screenX(removed, in: controls, atStart: false), expected, accuracy: 0.01)
            XCTAssertEqual(removed.alpha, 0.0)
        }
    }

    func testSendBecomesNarrowerCheckInTheSameSourceView() {
        let view = ComponentView<Empty>()
        let gallery = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let sourceView = gallery.rightButtonSourceView
        let controls = update(view, makeItems(.crop(highlightedTabs: [])), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(controls.rightButtonFrame(in: controls), CGRect(x: 332.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertTrue(controls.rightButtonSourceView === sourceView)
    }

    func testQualityFadesTheMiddleCapsuleOutAndGalleryBringsItBack() {
        let view = ComponentView<Empty>()
        let gallery = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let galleryWidth = gallery.middleCapsuleView.bounds.width
        var controls = update(view, makeItems(.quality), transition: .immediate)
        XCTAssertEqual(controls.middleCapsuleView.bounds.width, galleryWidth)
        XCTAssertTrue(controls.middleItemViews.isEmpty)
        controls = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        XCTAssertEqual(controls.middleCapsuleView.transform.a, 1.0)
        XCTAssertEqual(controls.middleCapsuleView.alpha, 1.0)
        XCTAssertEqual(controls.middleItemFrame(id: chatMediaEditorBottomControlsTabId(.cropTab), in: controls)?.minX, 98.0)
    }

    func testMiddleCapsuleHidesItsGlassInPlaceInsteadOfCollapsing() {
        let view = ComponentView<Empty>()
        let gallery = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate)
        let galleryWidth = gallery.middleCapsuleView.bounds.width
        let galleryCenter = gallery.middleCapsuleView.center
        let controls = update(view, makeItems(.quality), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(controls.middleCapsuleView.transform.a, 1.0)
        XCTAssertEqual(controls.middleCapsuleView.alpha, 1.0)
        XCTAssertEqual(controls.middleCapsuleView.bounds.width, galleryWidth)
        XCTAssertEqual(controls.middleCapsuleView.center, galleryCenter)
    }

    func testMiddleCapsuleAppearsAtItsFinalFrameWithoutScaling() {
        let view = ComponentView<Empty>()
        let _ = update(view, makeItems(.quality), transition: .immediate)
        let controls = update(view, makeItems(.gallery(activeTab: [])), transition: .easeInOut(duration: 0.3))
        XCTAssertEqual(controls.middleCapsuleView.frame.width, 206.0, accuracy: 0.01)
        XCTAssertEqual(controls.middleCapsuleView.center.x, 201.0, accuracy: 0.01)
        XCTAssertNil(controls.middleCapsuleView.layer.animation(forKey: "position"))
        XCTAssertNil(controls.middleCapsuleView.layer.animationKeys()?.first(where: { $0.contains("transform") }))
        XCTAssertEqual(controls.middleCapsuleView.alpha, 1.0)
    }

    func testSelectionPillSitsBehindTheActiveTool() {
        let view = ComponentView<Empty>()
        let controls = update(view, makeItems(.gallery(activeTab: .paintTab)), transition: .immediate)
        XCTAssertEqual(controls.selectionPillView.alpha, 1.0)
        XCTAssertEqual(controls.selectionPillView.frame, CGRect(x: 54.0 + 3.0, y: 3.0, width: 38.0, height: 38.0))
        let none = update(view, makeItems(.gallery(activeTab: .qualityTab)), transition: .immediate)
        XCTAssertEqual(none.selectionPillView.alpha, 0.0)
    }

    func testHiddenControlsFadeOutAndTakeNoTouches() {
        let view = ComponentView<Empty>()
        let controls = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate, isHidden: true)
        XCTAssertEqual(controls.leftCapsuleView.alpha, 0.0)
        XCTAssertFalse(controls.leftCapsuleView.isUserInteractionEnabled)
        XCTAssertFalse(controls.rightButtonSourceView.isUserInteractionEnabled)
        XCTAssertEqual(controls.middleCapsuleView.alpha, 0.0)
        XCTAssertFalse(controls.middleCapsuleView.isUserInteractionEnabled)
    }

    func testDisabledSendAndMiddleAreDimmed() {
        let view = ComponentView<Empty>()
        let controls = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate, isMiddleEnabled: false, isRightEnabled: false)
        XCTAssertEqual(controls.rightButtonSourceView.alpha, 0.2, accuracy: 0.001)
        XCTAssertFalse(controls.rightButtonSourceView.isUserInteractionEnabled)
        XCTAssertTrue(controls.leftCapsuleView.isUserInteractionEnabled)
        XCTAssertEqual(controls.middleCapsuleView.alpha, 0.2, accuracy: 0.001)
        XCTAssertFalse(controls.middleCapsuleView.isUserInteractionEnabled)
    }

    func testTapsRouteToTheirActions() {
        let view = ComponentView<Empty>()
        var actions: [ChatMediaEditorBottomControlsAction] = []
        var left = 0
        var right = 0
        let controls = update(view, makeItems(.gallery(activeTab: [])), transition: .immediate, leftPressed: { left += 1 }, rightPressed: { right += 1 }, pressed: { actions.append($0) })
        tap(controls.middleItemView(id: chatMediaEditorBottomControlsTabId(.paintTab)))
        tap(controls.leftButtonView)
        tap(controls.rightButtonView)
        XCTAssertEqual(actions, [.tab(.paintTab)])
        XCTAssertEqual(left, 1)
        XCTAssertEqual(right, 1)
    }
}
