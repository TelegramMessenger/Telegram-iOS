import Foundation
import UIKit
import Display

public enum ChatMediaEditorToolbarSide: Equatable {
    case left
    case right
}

public let chatMediaEditorLandscapeColumnWidth: CGFloat = 49.0
public let chatMediaEditorLandscapeToolsPanelWidth: CGFloat = 220.0
public let chatMediaEditorLandscapeQualityPanelWidth: CGFloat = 75.0

public func chatMediaEditorToolbarSide(size: CGSize, orientation: UIInterfaceOrientation?, isTablet: Bool) -> ChatMediaEditorToolbarSide? {
    if isTablet || size.width <= size.height {
        return nil
    }
    if orientation == .landscapeLeft {
        return .left
    }
    return .right
}

public func chatMediaEditorLandscapeColumnFrame(
    size: CGSize,
    safeInsets: UIEdgeInsets,
    side: ChatMediaEditorToolbarSide,
    reservedCorners: ContainerViewLayoutCorners = .none
) -> CGRect {
    let x: CGFloat
    switch side {
    case .left:
        x = safeInsets.left
    case .right:
        x = size.width - safeInsets.right - chatMediaEditorLandscapeColumnWidth
    }
    var minY = max(safeInsets.top, chatMediaEditorBottomControlsSideInset)
    var maxY = min(size.height - safeInsets.bottom, size.height - chatMediaEditorBottomControlsSideInset)

    let topBlock: CGSize?
    let bottomBlock: CGSize?
    switch side {
    case .left:
        topBlock = reservedCorners.topLeft
        bottomBlock = reservedCorners.bottomLeft
    case .right:
        topBlock = reservedCorners.topRight
        bottomBlock = reservedCorners.bottomRight
    }
    func reachesColumn(_ block: CGSize) -> Bool {
        switch side {
        case .left:
            return block.width > x
        case .right:
            return size.width - block.width < x + chatMediaEditorLandscapeColumnWidth
        }
    }
    if let topBlock, reachesColumn(topBlock) {
        minY = max(minY, topBlock.height)
    }
    if let bottomBlock, reachesColumn(bottomBlock) {
        maxY = min(maxY, size.height - bottomBlock.height)
    }
    return CGRect(x: x, y: minY, width: chatMediaEditorLandscapeColumnWidth, height: max(0.0, maxY - minY))
}

public func chatMediaEditorLandscapeContentRect(size: CGSize, safeInsets: UIEdgeInsets, side: ChatMediaEditorToolbarSide, panelWidth: CGFloat) -> CGRect {
    let minX: CGFloat
    let maxX: CGFloat
    switch side {
    case .left:
        minX = safeInsets.left + chatMediaEditorLandscapeColumnWidth + panelWidth
        maxX = size.width - safeInsets.right
    case .right:
        minX = safeInsets.left
        maxX = size.width - safeInsets.right - chatMediaEditorLandscapeColumnWidth - panelWidth
    }
    return CGRect(
        x: minX,
        y: safeInsets.top,
        width: max(0.0, maxX - minX),
        height: max(0.0, size.height - safeInsets.top - safeInsets.bottom)
    )
}

extension ChatMediaEditorScreen.Node {
    func toolbarSide(layout: ContainerViewLayout) -> ChatMediaEditorToolbarSide? {
        return chatMediaEditorToolbarSide(size: layout.size, orientation: layout.metrics.orientation, isTablet: layout.metrics.isTablet || layout.deviceMetrics.type == .tablet)
    }
}
