import Foundation
import UIKit
import Display
import LegacyComponents
import MediaPickerUI
import MediaEditorBottomControls

let chatMediaEditorBottomControlsButtonSide: CGFloat = 44.0
let chatMediaEditorBottomControlsSideInset: CGFloat = 26.0
public let chatMediaEditorBottomControlsMiddleSpacing: CGFloat = 10.0
let chatMediaEditorBottomControlsTextInset: CGFloat = 16.0
let chatMediaEditorBottomControlsPaintSpacing: CGFloat = 20.0 - chatMediaEditorBottomControlsTextInset * 2.0

public struct ChatMediaEditorBottomControlsLayout: Equatable {
    public var panelFrame: CGRect
    public var leftFrame: CGRect
    public var middleFrame: CGRect?
    public var itemFrames: [CGRect]
    public var rightFrame: CGRect
}

public func chatMediaEditorBottomControlsLayout(size: CGSize, safeInsets: UIEdgeInsets, middleItemWidths: [CGFloat], middleSpacing: CGFloat = chatMediaEditorBottomControlsMiddleSpacing, rightWidth: CGFloat, side: ChatMediaEditorToolbarSide? = nil, reservedCorners: ContainerViewLayoutCorners = .none) -> ChatMediaEditorBottomControlsLayout {
    if let side {
        let panelFrame = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: safeInsets, side: side, reservedCorners: reservedCorners)
        let layout = chatMediaEditorBottomControlsColumnLocalLayout(size: panelFrame.size, middleItemWidths: middleItemWidths, middleSpacing: middleSpacing, leftWidth: chatMediaEditorBottomControlsButtonSide, rightWidth: rightWidth)
        return ChatMediaEditorBottomControlsLayout(panelFrame: panelFrame, leftFrame: layout.leftFrame, middleFrame: layout.middleFrame, itemFrames: layout.itemFrames, rightFrame: layout.rightFrame)
    }
    let panelFrame = chatMediaEditorBottomPanelFrame(size: size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight)
    return chatMediaEditorBottomControlsLocalLayout(panelFrame: panelFrame, middleItemWidths: middleItemWidths, middleSpacing: middleSpacing, rightWidth: rightWidth)
}

func chatMediaEditorBottomControlsColumnLocalLayout(size: CGSize, middleItemWidths: [CGFloat], middleSpacing: CGFloat, leftWidth: CGFloat, rightWidth: CGFloat) -> MediaEditorBottomControlsLayout {
    let side = chatMediaEditorBottomControlsButtonSide
    let rightFrame = CGRect(x: floorToScreenPixels((size.width - rightWidth) / 2.0), y: 0.0, width: rightWidth, height: side)
    let leftFrame = CGRect(x: floorToScreenPixels((size.width - leftWidth) / 2.0), y: size.height - side, width: leftWidth, height: side)
    let middleHeight = CGFloat(middleItemWidths.count) * side + CGFloat(max(0, middleItemWidths.count - 1)) * middleSpacing
    let middleMinY = floorToScreenPixels((size.height - middleHeight) / 2.0)
    let itemFrames = middleItemWidths.enumerated().map { index, width in
        return CGRect(x: floorToScreenPixels((size.width - width) / 2.0), y: middleMinY + CGFloat(index) * (side + middleSpacing), width: width, height: side)
    }
    var middleFrame: CGRect?
    if let first = itemFrames.first, let last = itemFrames.last {
        let width = itemFrames.map(\.width).max() ?? side
        middleFrame = CGRect(x: floorToScreenPixels((size.width - width) / 2.0), y: first.minY, width: width, height: last.maxY - first.minY)
    }
    return MediaEditorBottomControlsLayout(leftFrame: leftFrame, middleFrame: middleFrame, itemFrames: itemFrames, rightFrame: rightFrame)
}

let chatMediaEditorBottomControlsSpec = MediaEditorBottomControlsLayoutSpec(sideInset: chatMediaEditorBottomControlsSideInset, middleCentering: .screenBand(inset: chatMediaEditorBottomControlsButtonSide), buttonSide: chatMediaEditorBottomControlsButtonSide)

func chatMediaEditorBottomControlsScreenStableFrame(_ frame: CGRect, fromCapsuleOrigin: CGPoint, toCapsuleOrigin: CGPoint) -> CGRect {
    return mediaEditorBottomControlsScreenStableFrame(frame, fromCapsuleOrigin: fromCapsuleOrigin, toCapsuleOrigin: toCapsuleOrigin)
}

func chatMediaEditorBottomControlsSelectionFrame(itemFrame: CGRect) -> CGRect {
    return mediaEditorBottomControlsSelectionFrame(itemFrame: itemFrame)
}

func chatMediaEditorBottomControlsLocalLayout(panelFrame: CGRect, middleItemWidths: [CGFloat], middleSpacing: CGFloat = chatMediaEditorBottomControlsMiddleSpacing, rightWidth: CGFloat) -> ChatMediaEditorBottomControlsLayout {
    let layout = mediaEditorBottomControlsLocalLayout(width: panelFrame.width, spec: chatMediaEditorBottomControlsSpec, middleItemWidths: middleItemWidths, middleSpacing: middleSpacing, leftWidth: chatMediaEditorBottomControlsButtonSide, rightWidth: rightWidth)
    return ChatMediaEditorBottomControlsLayout(panelFrame: panelFrame, leftFrame: layout.leftFrame, middleFrame: layout.middleFrame, itemFrames: layout.itemFrames, rightFrame: layout.rightFrame)
}

public enum ChatMediaEditorBottomControlsLeftItem: Equatable {
    case back
    case close
}

public enum ChatMediaEditorBottomControlsRightItem: Equatable {
    case send
    case schedule
    case check
}

public func chatMediaEditorBottomControlsRightWidth(_ item: ChatMediaEditorBottomControlsRightItem) -> CGFloat {
    switch item {
    case .send, .schedule:
        return 46.0
    case .check:
        return chatMediaEditorBottomControlsButtonSide
    }
}

public func chatMediaEditorBottomControlsRightItem(doneButton: TGPhotoEditorDoneButton) -> ChatMediaEditorBottomControlsRightItem {
    switch doneButton {
    case TGPhotoEditorDoneButtonSend:
        return .send
    case TGPhotoEditorDoneButtonSchedule:
        return .schedule
    default:
        return .check
    }
}

public enum ChatMediaEditorToolsTab: Hashable {
    case adjustments
    case tint
    case blur
    case curves
}

public enum ChatMediaEditorPaintTab: Equatable {
    case draw
    case sticker
    case text
}

public enum ChatMediaEditorBottomControlsMode: Equatable {
    case gallery(activeTab: TGPhotoEditorTab)
    case crop(highlightedTabs: TGPhotoEditorTab)
    case tools(selected: ChatMediaEditorToolsTab, highlighted: Set<ChatMediaEditorToolsTab>)
    case paint(selected: ChatMediaEditorPaintTab)
    case quality
}

public enum ChatMediaEditorBottomControlsAction: Equatable {
    case tab(TGPhotoEditorTab)
    case tools(ChatMediaEditorToolsTab)
    case paint(ChatMediaEditorPaintTab)
}

public enum ChatMediaEditorBottomControlsContent: Equatable {
    case icon(String)
    case quality(isPhoto: Bool, highQuality: Bool, preset: Int)
    case paintMode(ChatMediaEditorPaintTab)
}

public struct ChatMediaEditorBottomControlsMiddleItem: Equatable {
    public var id: String
    public var action: ChatMediaEditorBottomControlsAction
    public var content: ChatMediaEditorBottomControlsContent
    public var isHighlighted: Bool
    public var isDisabled: Bool
}

public struct ChatMediaEditorBottomControlsItems: Equatable {
    public var left: ChatMediaEditorBottomControlsLeftItem
    public var middle: [ChatMediaEditorBottomControlsMiddleItem]
    public var selectedId: String?
    public var right: ChatMediaEditorBottomControlsRightItem
    public var middleSpacing: CGFloat

    public init(left: ChatMediaEditorBottomControlsLeftItem, middle: [ChatMediaEditorBottomControlsMiddleItem], selectedId: String?, right: ChatMediaEditorBottomControlsRightItem, middleSpacing: CGFloat = chatMediaEditorBottomControlsMiddleSpacing) {
        self.left = left
        self.middle = middle
        self.selectedId = selectedId
        self.right = right
        self.middleSpacing = middleSpacing
    }
}

public func chatMediaEditorBottomControlsTabId(_ tab: TGPhotoEditorTab) -> String {
    return "tab.\(tab.rawValue)"
}

private let chatMediaEditorBottomControlsSelectableTabs: [TGPhotoEditorTab] = [.cropTab, .paintTab, .eraserTab, .toolsTab, .tintTab, .blurTab, .curvesTab]

private func chatMediaEditorBottomControlsTabIcon(_ tab: TGPhotoEditorTab) -> String {
    return mediaPickerPhotoToolbarTabIconName(tab)
}

private func chatMediaEditorBottomControlsToolsTabs(isVideo: Bool) -> [ChatMediaEditorToolsTab] {
    return isVideo ? [.adjustments, .tint, .curves] : [.adjustments, .tint, .blur, .curves]
}

private func chatMediaEditorBottomControlsToolsId(_ tab: ChatMediaEditorToolsTab) -> String {
    switch tab {
    case .adjustments:
        return "tool.adjustments"
    case .tint:
        return "tool.tint"
    case .blur:
        return "tool.blur"
    case .curves:
        return "tool.curves"
    }
}

private func chatMediaEditorBottomControlsToolsIcon(_ tab: ChatMediaEditorToolsTab) -> String {
    switch tab {
    case .adjustments:
        return mediaPickerPhotoToolbarTabIconName(.toolsTab)
    case .tint:
        return mediaPickerPhotoToolbarTabIconName(.tintTab)
    case .blur:
        return mediaPickerPhotoToolbarTabIconName(.blurTab)
    case .curves:
        return mediaPickerPhotoToolbarTabIconName(.curvesTab)
    }
}

private func chatMediaEditorBottomControlsPaintId(_ tab: ChatMediaEditorPaintTab) -> String {
    switch tab {
    case .draw:
        return "paint.draw"
    case .sticker:
        return "paint.sticker"
    case .text:
        return "paint.text"
    }
}

public func chatMediaEditorBottomControlsItems(
    mode: ChatMediaEditorBottomControlsMode,
    isGallery: Bool,
    isVideo: Bool,
    showsQuality: Bool,
    policy: ChatMediaEditorTabPolicy,
    sendButton: ChatMediaEditorBottomControlsRightItem,
    highlightedTabs: TGPhotoEditorTab,
    disabledTabs: TGPhotoEditorTab,
    qualityHighQuality: Bool,
    qualityPreset: Int
) -> ChatMediaEditorBottomControlsItems {
    switch mode {
    case let .gallery(activeTab):
        let tabs = chatMediaEditorToolbarTabs(showsQuality: showsQuality, policy: policy)
        let middle = tabs.map { tab -> ChatMediaEditorBottomControlsMiddleItem in
            let content: ChatMediaEditorBottomControlsContent
            if tab == .qualityTab {
                content = .quality(isPhoto: !isVideo, highQuality: isVideo ? false : qualityHighQuality, preset: isVideo ? qualityPreset : 0)
            } else {
                content = .icon(chatMediaEditorBottomControlsTabIcon(tab))
            }
            return ChatMediaEditorBottomControlsMiddleItem(
                id: chatMediaEditorBottomControlsTabId(tab),
                action: .tab(tab),
                content: content,
                isHighlighted: highlightedTabs.contains(tab),
                isDisabled: disabledTabs.contains(tab)
            )
        }
        var selectedId: String?
        if let selectedTab = tabs.first(where: { $0 == activeTab }), chatMediaEditorBottomControlsSelectableTabs.contains(selectedTab) {
            selectedId = chatMediaEditorBottomControlsTabId(selectedTab)
        }
        return ChatMediaEditorBottomControlsItems(left: isGallery ? .back : .close, middle: middle, selectedId: selectedId, right: sendButton)
    case let .crop(cropHighlightedTabs):
        let middle = chatMediaEditorCropToolbarTabs().map { tab in
            return ChatMediaEditorBottomControlsMiddleItem(
                id: chatMediaEditorBottomControlsTabId(tab),
                action: .tab(tab),
                content: .icon(chatMediaEditorBottomControlsTabIcon(tab)),
                isHighlighted: cropHighlightedTabs.contains(tab),
                isDisabled: false
            )
        }
        return ChatMediaEditorBottomControlsItems(left: .close, middle: middle, selectedId: nil, right: .check)
    case let .tools(selected, highlighted):
        let tabs = chatMediaEditorBottomControlsToolsTabs(isVideo: isVideo)
        let middle = tabs.map { tab in
            return ChatMediaEditorBottomControlsMiddleItem(
                id: chatMediaEditorBottomControlsToolsId(tab),
                action: .tools(tab),
                content: .icon(chatMediaEditorBottomControlsToolsIcon(tab)),
                isHighlighted: highlighted.contains(tab),
                isDisabled: false
            )
        }
        let selectedId = tabs.contains(selected) ? chatMediaEditorBottomControlsToolsId(selected) : nil
        return ChatMediaEditorBottomControlsItems(left: .close, middle: middle, selectedId: selectedId, right: .check)
    case let .paint(selected):
        let middle = [ChatMediaEditorPaintTab.draw, .sticker, .text].map { tab in
            return ChatMediaEditorBottomControlsMiddleItem(
                id: chatMediaEditorBottomControlsPaintId(tab),
                action: .paint(tab),
                content: .paintMode(tab),
                isHighlighted: false,
                isDisabled: false
            )
        }
        return ChatMediaEditorBottomControlsItems(left: .close, middle: middle, selectedId: chatMediaEditorBottomControlsPaintId(selected), right: .check, middleSpacing: chatMediaEditorBottomControlsPaintSpacing)
    case .quality:
        return ChatMediaEditorBottomControlsItems(left: .close, middle: [], selectedId: nil, right: .check)
    }
}

// The row hides for a keyboard that covers it, not for caption editing as such: with a hardware keyboard (an iPad's)
// the caption is edited with no keyboard on screen, and Send has to stay.
public func chatMediaEditorBottomControlsAreHidden(mode: ChatMediaEditorBottomControlsMode, keyboardHeight: CGFloat, paintControlsVisible: Bool) -> Bool {
    switch mode {
    case .gallery:
        return keyboardHeight > 0.0
    case .paint:
        return keyboardHeight > 0.0 || !paintControlsVisible
    case .crop, .quality, .tools:
        return false
    }
}

public func chatMediaEditorBottomControlsSideTapAllowed(now: Double, lastSideItemsChange: Double?) -> Bool {
    return mediaEditorBottomControlsSideTapAllowed(now: now, lastSideItemsChange: lastSideItemsChange)
}

public enum ChatMediaEditorBottomControlsPlacement: Equatable {
    case belowCaptionDim
    case aboveEmbeddedTool
}

public func chatMediaEditorBottomControlsPlacement(hasEmbeddedTool: Bool) -> ChatMediaEditorBottomControlsPlacement {
    return hasEmbeddedTool ? .aboveEmbeddedTool : .belowCaptionDim
}
