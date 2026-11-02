import UIKit

/// Where a bottom sheet sits across its container, and the side insets its content should lay out against.
///
/// The side safe insets differ only beside iPhone Duo's side strip. Everywhere else (both zero, or a notch on
/// each side in landscape) the placement is the one sheets always had, content insets included.
public struct SheetHorizontalPlacement: Equatable {
    /// The sheet's left edge, in the container's coordinates.
    public var minX: CGFloat
    public var width: CGFloat
    /// The part of each side safe inset the sheet overlaps (only `left` and `right` are set): zero on a
    /// side where the sheet sits clear of the strip, the whole inset where it runs to the screen edge.
    public var contentSideInsets: UIEdgeInsets

    public init(minX: CGFloat, width: CGFloat, contentSideInsets: UIEdgeInsets) {
        self.minX = minX
        self.width = width
        self.contentSideInsets = contentSideInsets
    }
}

/// A sheet `width` wide that is narrower than its container (`ResizableSheetComponent`'s compact sheet,
/// `min(width, height)` across, or its regular one, at most `maxWidth`).
///
/// With equal side insets the sheet narrows by both of them and centers on the container, as it always has.
/// Beside a side strip it narrows by the strip alone and centers in the band between the side insets, so it
/// stays clear of the strip and of the corner block at its end; its content then has no side inset to keep.
/// A sheet wider than the band (folded portrait) spans the container as a bottom panel, as before.
public func resizableSheetHorizontalPlacement(containerSize: CGSize, safeInsets: UIEdgeInsets, maxWidth: CGFloat?) -> SheetHorizontalPlacement {
    let left = safeInsets.left
    let right = safeInsets.right
    let originalInsets = UIEdgeInsets(top: 0.0, left: left, bottom: 0.0, right: right)
    if left == right {
        let width: CGFloat
        if let maxWidth {
            width = min(containerSize.width, maxWidth) - left * 2.0
        } else {
            width = min(containerSize.width, containerSize.height) - left * 2.0
        }
        return SheetHorizontalPlacement(minX: floor((containerSize.width - width) * 0.5), width: width, contentSideInsets: originalInsets)
    }

    let bandWidth = containerSize.width - left - right
    let width: CGFloat
    if let maxWidth {
        width = min(bandWidth, maxWidth)
    } else {
        width = min(containerSize.width, containerSize.height - left - right)
    }
    let minX: CGFloat
    if width <= bandWidth {
        minX = left + floor((bandWidth - width) * 0.5)
    } else {
        minX = floor((containerSize.width - width) * 0.5)
    }
    let contentSideInsets = UIEdgeInsets(top: 0.0, left: max(0.0, left - minX), bottom: 0.0, right: max(0.0, right - (containerSize.width - minX - width)))
    return SheetHorizontalPlacement(minX: minX, width: width, contentSideInsets: contentSideInsets)
}

/// Where a full-width sheet (`SheetComponent`) sits instead of spanning its container, or nil where it spans the
/// container as it always has.
///
/// Only a landscape layout beside a side strip has one: there the strip runs the full height and carries a corner
/// block at one end (the unfolded screen's status corner at the top, folded landscape-left's block at the bottom),
/// which a sheet spanning the container would run under, with its content kept to the band off the sheet's centre.
/// The whole sheet keeps to the band instead, clear of the strip and its block, and its content has no side inset
/// to keep. In portrait the sheet stays a bottom panel across the strip, below the status corner.
public func sheetBandPlacement(containerSize: CGSize, safeInsets: UIEdgeInsets) -> SheetHorizontalPlacement? {
    if containerSize.width <= containerSize.height || safeInsets.left == safeInsets.right {
        return nil
    }
    return SheetHorizontalPlacement(minX: safeInsets.left, width: containerSize.width - safeInsets.left - safeInsets.right, contentSideInsets: UIEdgeInsets())
}

/// The frame of a sheet shown as a centered card (where the layout `presentsFloatingPanels`) whose content is
/// `contentHeight` high, in a container `containerSize` large: as wide as `SheetComponent`'s and the modal
/// container's centered cards (half the longer side, at least 10pt from each edge), at most the shorter side less
/// 44pt above and below, centered on the container.
public func centeredSheetFrame(containerSize: CGSize, contentHeight: CGFloat) -> CGRect {
    let verticalInset: CGFloat = 44.0
    let maxSide = max(containerSize.width, containerSize.height)
    let minSide = min(containerSize.width, containerSize.height)
    let width = min(containerSize.width - 20.0, floor(maxSide / 2.0))
    let height = max(0.0, min(contentHeight, minSide - verticalInset * 2.0))
    return CGRect(origin: CGPoint(x: floor((containerSize.width - width) / 2.0), y: floor((containerSize.height - height) / 2.0)), size: CGSize(width: width, height: height))
}

/// A centered card (`centeredSheetFrame`) whose bottom stays at `maxY`, where it rests, while its content is
/// `contentHeight` high: a card whose list rubber-bands grows and shrinks at its top only, as a bottom sheet does.
/// Its top never rises above the tallest card's: past that the card grows downward, within the margins.
public func centeredSheetFrame(containerSize: CGSize, contentHeight: CGFloat, maxY: CGFloat) -> CGRect {
    let tallest = centeredSheetFrame(containerSize: containerSize, contentHeight: .greatestFiniteMagnitude)
    let height = max(0.0, contentHeight)
    let minY = max(tallest.minY, maxY - height)
    return CGRect(origin: CGPoint(x: tallest.minX, y: minY), size: CGSize(width: tallest.width, height: height))
}

/// The side insets a centered alert (`AlertScreen`, `AlertControllerNode`) `alertWidth` wide, from `alertMinY` to
/// `alertMaxY`, centers between in a container `containerSize` large: the axis of the screen's sheets.
///
/// In portrait, where sheets span iPhone Duo's side strip below the status corner, a strip side counts only where the
/// screen-centered alert would reach one of its corner blocks (lifted by the keyboard in folded portrait), overlapping
/// it by more than 1pt (a 300pt alert on the 466pt folded screen ends 1pt inside the 84pt block), so the alert centers
/// on the screen whatever is behind it. In landscape, where sheets keep to the band (`resizableSheetHorizontalPlacement`,
/// `sheetBandPlacement`), the safe insets. Without corner blocks (every other device) the safe insets.
public func centeredAlertSideInsets(alertWidth: CGFloat, alertMinY: CGFloat, alertMaxY: CGFloat, containerSize: CGSize, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> (left: CGFloat, right: CGFloat) {
    if containerSize.width > containerSize.height {
        return (safeInsets.left, safeInsets.right)
    }
    let rowInsets = bandSideInsets(forBandFrom: alertMinY, to: alertMaxY, containerHeight: containerSize.height, safeInsets: safeInsets, reservedCorners: reservedCorners)
    let alertMinX = (containerSize.width - alertWidth) / 2.0
    let alertMaxX = alertMinX + alertWidth
    // A side whose inset is a corner block's strip (`bandSideInsets`' test) and whose blocks the alert's rows reach
    // keeps it only if the screen-centered alert also reaches into one of them horizontally.
    func inset(_ rowInset: CGFloat, blocks: [CGSize?], reaches: (CGSize) -> Bool) -> CGFloat {
        if rowInset <= 0.0 {
            return rowInset
        }
        let stripBlocks = blocks.compactMap { $0 }.filter { abs($0.width - rowInset) <= 1.0 }
        if stripBlocks.isEmpty {
            return rowInset
        }
        return stripBlocks.contains(where: reaches) ? rowInset : 0.0
    }
    return (
        inset(rowInsets.left, blocks: [reservedCorners.topLeft, reservedCorners.bottomLeft], reaches: { alertMinX < $0.width - 1.0 }),
        inset(rowInsets.right, blocks: [reservedCorners.topRight, reservedCorners.bottomRight], reaches: { alertMaxX > containerSize.width - $0.width + 1.0 })
    )
}

/// How much further in a sheet's header controls (close, title, trailing button) move on each side so they do
/// not sit under a top corner block (iPhone Duo's status corner, 84x170 in folded portrait), given the sheet's
/// horizontal frame and the highest its top edge can rise (`sheetMinY`, in the container's coordinates).
///
/// Only `left` and `right` are set. Zero on a side without a top block, where the sheet's edge is already clear
/// of the block's width, or where the sheet's top can never rise above the block's bottom, so a short sheet's
/// header keeps its usual symmetric layout.
public func sheetHeaderCornerInsets(containerWidth: CGFloat, sheetMinX: CGFloat, sheetWidth: CGFloat, sheetMinY: CGFloat, reservedCorners: ContainerViewLayoutCorners) -> UIEdgeInsets {
    var result = UIEdgeInsets()
    if let topLeft = reservedCorners.topLeft, sheetMinY < topLeft.height {
        result.left = max(0.0, topLeft.width - sheetMinX)
    }
    if let topRight = reservedCorners.topRight, sheetMinY < topRight.height {
        result.right = max(0.0, topRight.width - (containerWidth - sheetMinX - sheetWidth))
    }
    return result
}

/// The scroll offset a full-width sheet (`SheetComponent`) rests at: its bottom at the container's bottom, as always,
/// unless it is taller than the container. Such a sheet (the report reasons on iPhone Duo's unfolded landscape, 669pt
/// high, or any phone in landscape) rests with its top at the container's top, as it already opened and snapped back,
/// and scrolls up to its bottom; resting on its bottom after a rotation or a content change, it showed its header
/// (close button, title) above the screen. A sheet that grew by the keyboard's height, or cannot scroll to
/// its bottom (`keepsBottomVisible`), still rests on its bottom, keeping what is just above the keyboard, or its
/// action, in view.
public func sheetRestingScrollOffset(contentHeight: CGFloat, containerHeight: CGFloat, keepsBottomVisible: Bool) -> CGFloat {
    let bottomResting = contentHeight - containerHeight
    if keepsBottomVisible {
        return bottomResting
    }
    return min(bottomResting, 0.0)
}
