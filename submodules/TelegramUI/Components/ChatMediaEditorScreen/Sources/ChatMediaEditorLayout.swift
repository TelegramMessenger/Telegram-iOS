import Foundation
import UIKit
import MediaCropComponent

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
    keyboardHeight: CGFloat
) -> ChatMediaEditorLayout {
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

public func chatMediaEditorVideoHeaderFrame(size: CGSize, toolbarMinY: CGFloat, captionBaseHeight: CGFloat) -> CGRect {
    return CGRect(x: 0.0, y: toolbarMinY - 74.0 - captionBaseHeight, width: size.width, height: chatMediaEditorVideoHeaderHeight)
}

public func chatMediaEditorScrubberFrame(size: CGSize, safeInsets: UIEdgeInsets, headerFrame: CGRect, scrubberHeight: CGFloat) -> CGRect {
    let width = max(0.0, size.width - safeInsets.left - safeInsets.right - chatMediaEditorVideoScrubberSideInset * 2.0)
    let y = headerFrame.minY + floor((headerFrame.height - scrubberHeight) / 2.0)
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
    toolbarHeight: CGFloat
) -> CGRect {
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

public func chatMediaEditorRecipientLayout(size: CGSize, safeInsets: UIEdgeInsets, arrowSize: CGSize, labelSize: CGSize, statusIsland: ChatMediaEditorStatusIslandRow? = nil) -> ChatMediaEditorRecipientLayout {
    let screenWidth = min(size.width, size.height)
    var labelWidth = max(0.0, min(labelSize.width, screenWidth - 150.0))
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

public func chatMediaEditorCropContainerFrame(size: CGSize, safeInsets: UIEdgeInsets, toolbarHeight: CGFloat, hasRotationWheel: Bool, hasPerspective: Bool = false) -> CGRect {
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
