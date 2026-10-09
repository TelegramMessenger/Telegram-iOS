import Foundation
import UIKit

public func horizontalContainerFillingSizeForLayout(layout: ContainerViewLayout, sideInset: CGFloat) -> CGFloat {
    if case .regular = layout.metrics.widthClass {
        return min(layout.size.width, 414.0) - sideInset * 2.0
    } else {
        return min(layout.size.width, 440.0) - sideInset * 2.0
    }
}

/// Where a container sits that is centered across `layout` and as wide as `horizontalContainerFillingSizeForLayout`
/// allows with `margin` on each side, plus the side safe insets when `includesSafeInsets`.
///
/// With equal side safe insets (every device but iPhone Duo) this is what callers always computed: centered on the
/// screen, `left == right`. Beside the Duo's side strip the container is centered in the band between the side
/// insets and at least `margin` from its edges, so it stays clear of the strip and the corner block at its end.
///
/// `anchoredAtBottom`: a container at the bottom edge (an action sheet, a share sheet) keeps clear only of a corner
/// block at the bottom (iPhone Duo's folded landscape-left), not of the rest of a side strip, and on iPhone Duo in
/// compact width spans the screen rather than the 440pt cap for compact layouts (its screens are wider), like the
/// other sheets. Every other device is unaffected.
public func horizontalContainerFillingPlacementForLayout(layout: ContainerViewLayout, margin: CGFloat, includesSafeInsets: Bool, anchoredAtBottom: Bool = false) -> (left: CGFloat, width: CGFloat, right: CGFloat) {
    var safeLeft = layout.safeInsets.left
    var safeRight = layout.safeInsets.right
    if anchoredAtBottom, case .iPhoneDuo = layout.deviceMetrics {
        let bottomInsets = layout.bottomEdgeSideInsets()
        if case .compact = layout.metrics.widthClass {
            let left = margin + bottomInsets.left
            let right = margin + bottomInsets.right
            return (left, layout.size.width - left - right, right)
        }
        safeLeft = bottomInsets.left
        safeRight = bottomInsets.right
    }
    if safeLeft == safeRight {
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: margin + (includesSafeInsets ? safeLeft : 0.0))
        let inset = floor((layout.size.width - width) / 2.0)
        return (inset, width, inset)
    }
    let bandWidth = layout.size.width - safeLeft - safeRight
    let width = min(horizontalContainerFillingSizeForLayout(layout: layout, sideInset: margin), bandWidth - margin * 2.0)
    let left = safeLeft + floor((bandWidth - width) / 2.0)
    return (left, width, layout.size.width - left - width)
}
