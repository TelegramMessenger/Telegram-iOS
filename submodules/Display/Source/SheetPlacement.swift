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

/// The insets of the band a full-width sheet's content keeps to (`SheetComponent`), or nil where it spans
/// the container as it always has.
///
/// Only a landscape layout beside a side strip has one: there the strip runs the full height and carries a
/// corner block at one end, which a sheet tall enough to reach it would run under (folded landscape-left: the
/// bottom-right block beside the sheet's bottom button). The sheet's background still spans the container;
/// the content keeps to the band and has no side inset of its own. In portrait the sheet stays a bottom panel
/// across the strip, below the status corner.
public func sheetContentBandInsets(containerSize: CGSize, safeInsets: UIEdgeInsets) -> UIEdgeInsets? {
    if containerSize.width <= containerSize.height || safeInsets.left == safeInsets.right {
        return nil
    }
    return UIEdgeInsets(top: 0.0, left: safeInsets.left, bottom: 0.0, right: safeInsets.right)
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
