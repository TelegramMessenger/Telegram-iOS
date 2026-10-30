import Foundation
import UIKit
import MediaCropComponent
import Display

public struct ChatMediaEditorLayout: Equatable {
    public var previewFrame: CGRect
    public var toolbarFrame: CGRect
    public var captionPanelFrame: CGRect

    public init(previewFrame: CGRect, toolbarFrame: CGRect, captionPanelFrame: CGRect) {
        self.previewFrame = previewFrame
        self.toolbarFrame = toolbarFrame
        self.captionPanelFrame = captionPanelFrame
    }
}

public func chatMediaEditorBottomPanelFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarHeight: CGFloat) -> CGRect {
    return CGRect(x: 0.0, y: size.height - safeInsets.bottom - toolbarHeight, width: size.width, height: toolbarHeight)
}

public func chatMediaEditorLayout(
    size: CGSize,
    safeInsets: UIEdgeInsets,
    mediaSize: CGSize,
    toolbarHeight: CGFloat,
    captionPanelHeight: CGFloat,
    keyboardHeight: CGFloat,
    toolbarSide: ChatMediaEditorToolbarSide? = nil,
    reservedCorners: ContainerViewLayoutCorners = .none
) -> ChatMediaEditorLayout {
    if let toolbarSide {
        let contentRect = chatMediaEditorLandscapeContentRect(size: size, safeInsets: safeInsets, side: toolbarSide, panelWidth: 0.0)
        return ChatMediaEditorLayout(
            previewFrame: chatMediaEditorFittedFrame(mediaSize: mediaSize, in: contentRect),
            toolbarFrame: chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: safeInsets, side: toolbarSide, reservedCorners: reservedCorners),
            captionPanelFrame: CGRect(x: 0.0, y: size.height, width: size.width, height: captionPanelHeight)
        )
    }
    let toolbarFrame = chatMediaEditorBottomPanelFrame(size: size, safeInsets: safeInsets, toolbarHeight: toolbarHeight)

    let restingCaptionPanelMinY = toolbarFrame.minY - captionPanelHeight
    let captionPanelMinY: CGFloat
    if keyboardHeight > 0.0 {
        captionPanelMinY = size.height - keyboardHeight - captionPanelHeight
    } else {
        captionPanelMinY = restingCaptionPanelMinY
    }
    let captionPanelFrame = CGRect(x: 0.0, y: captionPanelMinY, width: size.width, height: captionPanelHeight)

    let availableRect = CGRect(
        x: safeInsets.left,
        y: 0.0,
        width: max(0.0, size.width - safeInsets.left - safeInsets.right),
        height: size.height
    )

    let previewFrame = chatMediaEditorScreenCenteredFrame(chatMediaEditorFittedFrame(mediaSize: mediaSize, in: availableRect), size: size, safeInsets: safeInsets)

    return ChatMediaEditorLayout(previewFrame: previewFrame, toolbarFrame: toolbarFrame, captionPanelFrame: captionPanelFrame)
}

public let chatMediaEditorVideoScrubberPanelHeight: CGFloat = 64.0
public let chatMediaEditorVideoHeaderHeight: CGFloat = 72.0
let chatMediaEditorVideoScrubberSideInset: CGFloat = 9.0

func chatMediaEditorLandscapeInnerEdge(size: CGSize, safeInsets: UIEdgeInsets, side: ChatMediaEditorToolbarSide) -> CGFloat {
    let columnFrame = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: safeInsets, side: side)
    switch side {
    case .left:
        return columnFrame.maxX
    case .right:
        return columnFrame.minX
    }
}

func chatMediaEditorLandscapeNotchEdge(size: CGSize, safeInsets: UIEdgeInsets, side: ChatMediaEditorToolbarSide, reservedCorners: ContainerViewLayoutCorners = .none, rowMinY: CGFloat = 0.0, rowMaxY: CGFloat = 0.0) -> CGFloat {
    func reachesRow(_ block: CGSize?, isTop: Bool) -> CGSize? {
        guard let block else {
            return nil
        }
        if isTop {
            return rowMinY < block.height ? block : nil
        } else {
            return rowMaxY > size.height - block.height ? block : nil
        }
    }
    switch side {
    case .left:
        var edge = size.width - safeInsets.right
        for block in [reachesRow(reservedCorners.topRight, isTop: true), reachesRow(reservedCorners.bottomRight, isTop: false)] {
            if let block {
                edge = min(edge, size.width - block.width)
            }
        }
        return edge
    case .right:
        var edge = safeInsets.left
        for block in [reachesRow(reservedCorners.topLeft, isTop: true), reachesRow(reservedCorners.bottomLeft, isTop: false)] {
            if let block {
                edge = max(edge, block.width)
            }
        }
        return edge
    }
}

public func chatMediaEditorVideoHeaderFrame(size: CGSize, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, safeInsets: UIEdgeInsets = .zero, toolbarSide: ChatMediaEditorToolbarSide? = nil, reservedCorners: ContainerViewLayoutCorners = .none) -> CGRect {
    if let toolbarSide {
        let y = size.height - safeInsets.bottom - chatMediaEditorVideoScrubberPanelHeight
        let innerEdge = chatMediaEditorLandscapeInnerEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let notchEdge = chatMediaEditorLandscapeNotchEdge(size: size, safeInsets: safeInsets, side: toolbarSide, reservedCorners: reservedCorners, rowMinY: y, rowMaxY: y + chatMediaEditorVideoScrubberPanelHeight)
        let minX = min(innerEdge, notchEdge)
        let maxX = max(innerEdge, notchEdge)
        return CGRect(x: minX, y: y, width: max(0.0, maxX - minX), height: chatMediaEditorVideoScrubberPanelHeight)
    }
    return CGRect(x: 0.0, y: toolbarMinY - 74.0 - captionBaseHeight, width: size.width, height: chatMediaEditorVideoHeaderHeight)
}

public func chatMediaEditorScrubberFrame(size: CGSize, safeInsets: UIEdgeInsets, headerFrame: CGRect, scrubberHeight: CGFloat, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    let y = headerFrame.minY + floor((headerFrame.height - scrubberHeight) / 2.0)
    if toolbarSide != nil {
        let width = max(0.0, headerFrame.width - chatMediaEditorVideoScrubberSideInset * 2.0)
        return CGRect(x: headerFrame.minX + chatMediaEditorVideoScrubberSideInset, y: y, width: width, height: scrubberHeight)
    }
    let width = max(0.0, size.width - safeInsets.left - safeInsets.right - chatMediaEditorVideoScrubberSideInset * 2.0)
    return CGRect(x: safeInsets.left + chatMediaEditorVideoScrubberSideInset, y: y, width: width, height: scrubberHeight)
}

public func chatMediaEditorScrubberFramesCount(trackWidth: CGFloat, mediaSize: CGSize) -> Int {
    let trackHeight: CGFloat = 39.0
    var aspectRatio: CGFloat = 0.66
    if mediaSize.height > 0.0 {
        aspectRatio = max(0.66, mediaSize.width / mediaSize.height)
    }
    return max(1, Int(ceil(trackWidth / (trackHeight * aspectRatio))))
}

public enum ChatMediaEditorToolPreviewKind {
    case paint
    case tools
    case chatTools
    case quality
}

let chatMediaEditorPaintTopPanelHeight: CGFloat = 44.0
let chatMediaEditorPaintBottomPanelHeight: CGFloat = 79.0
let chatMediaEditorLegacyEditorPanelHeight: CGFloat = 115.0
let chatMediaEditorToolsPanelHeight: CGFloat = 180.0
let chatMediaEditorToolsButtonsInset: CGFloat = 8.0

public func chatMediaEditorToolPreviewFrame(
    kind: ChatMediaEditorToolPreviewKind,
    size: CGSize,
    safeInsets: UIEdgeInsets,
    mediaSize: CGSize,
    toolbarHeight: CGFloat,
    toolbarSide: ChatMediaEditorToolbarSide? = nil
) -> CGRect {
    if let toolbarSide {
        let panelWidth: CGFloat?
        switch kind {
        case .tools, .chatTools:
            panelWidth = chatMediaEditorLandscapeToolsPanelWidth
        case .quality:
            panelWidth = chatMediaEditorLandscapeQualityPanelWidth
        case .paint:
            panelWidth = nil
        }
        if let panelWidth {
            let contentRect = chatMediaEditorLandscapeContentRect(size: size, safeInsets: safeInsets, side: toolbarSide, panelWidth: panelWidth)
            return chatMediaEditorFittedFrame(mediaSize: mediaSize, in: contentRect)
        }
    }
    let width = max(0.0, size.width - safeInsets.left - safeInsets.right)
    let availableRect: CGRect
    switch kind {
    case .paint:
        availableRect = CGRect(
            x: safeInsets.left,
            y: safeInsets.top + chatMediaEditorPaintTopPanelHeight,
            width: width,
            height: max(0.0, size.height - safeInsets.top - safeInsets.bottom - toolbarHeight - chatMediaEditorPaintTopPanelHeight - chatMediaEditorPaintBottomPanelHeight)
        )
    case .tools:
        let bottom = size.height - safeInsets.bottom - toolbarHeight - chatMediaEditorToolsButtonsInset - chatMediaEditorToolsPanelHeight
        availableRect = CGRect(
            x: safeInsets.left,
            y: safeInsets.top,
            width: width,
            height: max(0.0, bottom - safeInsets.top)
        )
    case .chatTools:
        availableRect = CGRect(
            x: safeInsets.left,
            y: safeInsets.top,
            width: width,
            height: max(0.0, size.height - safeInsets.top - safeInsets.bottom - toolbarHeight - chatMediaEditorLegacyEditorPanelHeight)
        )
    case .quality:
        let bottom = size.height - safeInsets.bottom - toolbarHeight - chatMediaEditorQualityPanelSize
        availableRect = CGRect(
            x: safeInsets.left,
            y: safeInsets.top,
            width: width,
            height: max(0.0, bottom - safeInsets.top)
        )
    }
    return chatMediaEditorScreenCenteredFrame(chatMediaEditorFittedFrame(mediaSize: mediaSize, in: availableRect), size: size, safeInsets: safeInsets)
}

public func chatMediaEditorLandscapeToolsPanelFrame(size: CGSize, safeInsets: UIEdgeInsets, side: ChatMediaEditorToolbarSide) -> CGRect {
    let x: CGFloat
    switch side {
    case .left:
        x = safeInsets.left + chatMediaEditorLandscapeColumnWidth
    case .right:
        x = size.width - safeInsets.right - chatMediaEditorLandscapeColumnWidth - chatMediaEditorLandscapeToolsPanelWidth
    }
    return CGRect(
        x: x,
        y: safeInsets.top,
        width: chatMediaEditorLandscapeToolsPanelWidth,
        height: max(0.0, size.height - safeInsets.top - safeInsets.bottom)
    )
}

public func chatMediaEditorQualityPanelFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarSide: ChatMediaEditorToolbarSide?) -> CGRect {
    if let toolbarSide {
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = safeInsets.left + chatMediaEditorLandscapeColumnWidth
        case .right:
            x = size.width - safeInsets.right - chatMediaEditorLandscapeColumnWidth - chatMediaEditorLandscapeQualityPanelWidth
        }
        return CGRect(
            x: x,
            y: safeInsets.top,
            width: chatMediaEditorLandscapeQualityPanelWidth,
            height: max(0.0, size.height - safeInsets.top - safeInsets.bottom)
        )
    }
    let toolbarMinY = chatMediaEditorBottomPanelFrame(size: size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight).minY
    return CGRect(
        x: 0.0,
        y: toolbarMinY - chatMediaEditorQualityPanelSize + chatMediaEditorQualityPanelTopInset,
        width: size.width,
        height: chatMediaEditorQualityPanelSize - chatMediaEditorQualityPanelTopInset
    )
}

public func chatMediaEditorScreenCenteredFrame(_ frame: CGRect, size: CGSize, safeInsets: UIEdgeInsets) -> CGRect {
    if safeInsets.left == safeInsets.right {
        return frame
    }
    let x = size.width / 2.0 - frame.width / 2.0
    if x < safeInsets.left || x + frame.width > size.width - safeInsets.right {
        return frame
    }
    return CGRect(x: x, y: frame.minY, width: frame.width, height: frame.height)
}

public struct ChatMediaEditorRecipientLayout: Equatable {
    public var arrowFrame: CGRect
    public var labelFrame: CGRect
}


public func chatMediaEditorRecipientLayout(size: CGSize, safeInsets: UIEdgeInsets, arrowSize: CGSize, labelSize: CGSize, statusIsland: ChatMediaEditorStatusIslandRow? = nil, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> ChatMediaEditorRecipientLayout {
    let screenWidth = min(size.width, size.height)
    var labelWidth = max(0.0, min(labelSize.width, screenWidth - 150.0))
    if let toolbarSide {
        let arrowY = floor(chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets, toolbarSide: toolbarSide).midY - arrowSize.height / 2.0)
        let labelY = arrowY - 2.0
        let contentRect = chatMediaEditorLandscapeContentRect(size: size, safeInsets: safeInsets, side: toolbarSide, panelWidth: 0.0)
        let arrowX = floor(contentRect.midX - (arrowSize.width + 6.0 + labelWidth) / 2.0)
        let arrowFrame = CGRect(origin: CGPoint(x: arrowX, y: arrowY), size: arrowSize)
        let labelFrame = CGRect(x: arrowFrame.maxX + 6.0, y: labelY, width: labelWidth, height: labelSize.height)
        return ChatMediaEditorRecipientLayout(arrowFrame: arrowFrame, labelFrame: labelFrame)
    }
    let topInset = safeInsets.top
    var arrowFrame = CGRect(origin: CGPoint(x: safeInsets.left + chatMediaEditorScreenEdgeInset, y: topInset + 16.0), size: arrowSize)
    if let statusIsland {
        // Beside iPhone Duo's status island the row sits on the island's clock line with the check button, which moved
        // left of the island: a long chat name stops 8pt short of the check.
        arrowFrame.origin.y = statusIsland.clockLineY - arrowSize.height / 2.0
        let checkFrame = chatMediaEditorCheckButtonFrame(size: size, safeInsets: safeInsets, statusIsland: statusIsland)
        labelWidth = max(0.0, min(labelSize.width, checkFrame.minX - 8.0 - (arrowFrame.maxX + 6.0)))
    }
    let labelFrame = CGRect(x: arrowFrame.maxX + 6.0, y: arrowFrame.minY - 2.0, width: labelWidth, height: labelSize.height)
    return ChatMediaEditorRecipientLayout(arrowFrame: arrowFrame, labelFrame: labelFrame)
}

private func chatMediaEditorFittedFrame(mediaSize: CGSize, in availableRect: CGRect) -> CGRect {
    var fittedSize = availableRect.size
    if mediaSize.width > 0.0 && mediaSize.height > 0.0 && availableRect.width > 0.0 && availableRect.height > 0.0 {
        let scale = min(availableRect.width / mediaSize.width, availableRect.height / mediaSize.height)
        fittedSize = CGSize(width: mediaSize.width * scale, height: mediaSize.height * scale)
    }
    return CGRect(
        x: availableRect.midX - fittedSize.width / 2.0,
        y: availableRect.midY - fittedSize.height / 2.0,
        width: fittedSize.width,
        height: fittedSize.height
    )
}

let chatMediaEditorCropPanelHeight: CGFloat = 115.0
let chatMediaEditorCropPanelHeightWithoutWheel: CGFloat = 60.0
let chatMediaEditorCropSelectorDialSpacing: CGFloat = 12.0

let chatMediaEditorCropLandscapeResetStripWidth: CGFloat = 61.0
let chatMediaEditorCropLandscapeDialStripWidth: CGFloat = 100.0

func chatMediaEditorCropLandscapeSelectorBlockWidth(hasRotationWheel: Bool, hasPerspective: Bool) -> CGFloat {
    return hasRotationWheel && hasPerspective ? mediaCropAdjustmentSelectorHeight + chatMediaEditorCropSelectorDialSpacing : 0.0
}

public func chatMediaEditorCropContainerFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarHeight: CGFloat, hasRotationWheel: Bool, hasPerspective: Bool = false, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if let toolbarSide {
        let panelWidth = (hasRotationWheel ? chatMediaEditorCropLandscapeDialStripWidth + chatMediaEditorCropLandscapeResetStripWidth : chatMediaEditorCropLandscapeResetStripWidth) + chatMediaEditorCropLandscapeSelectorBlockWidth(hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective)
        return chatMediaEditorLandscapeContentRect(size: size, safeInsets: safeInsets, side: toolbarSide, panelWidth: panelWidth)
    }
    var panelHeight = hasRotationWheel ? chatMediaEditorCropPanelHeight : chatMediaEditorCropPanelHeightWithoutWheel
    if hasRotationWheel && hasPerspective {
        panelHeight += mediaCropAdjustmentSelectorHeight + chatMediaEditorCropSelectorDialSpacing
    }
    var minX = safeInsets.left
    var width = max(0.0, size.width - safeInsets.left - safeInsets.right)
    if safeInsets.left != safeInsets.right && size.width > size.height {
        let sideInset = max(safeInsets.left, safeInsets.right)
        minX = sideInset
        width = max(0.0, size.width - sideInset * 2.0)
    }
    return CGRect(
        x: minX,
        y: safeInsets.top,
        width: width,
        height: max(0.0, size.height - toolbarHeight - panelHeight - safeInsets.top - safeInsets.bottom)
    )
}
