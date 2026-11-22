import Foundation
import UIKit
import Display

// The width of the login flow's content column (its fields and texts are at most this wide).
private let authorizationContentColumnWidth: CGFloat = 430.0

/// The horizontal band (`minX`, `width`) the login flow lays out and centres its content in.
///
/// With equal side insets (every device but iPhone Duo beside a side strip) it is the full width. On iPhone Duo's
/// unfolded screen the content is centred on the full width, in line with the bottom button and the keyboard, keeping
/// clear of the side inset on both sides, when that leaves room for the content column. Otherwise (the folded screen)
/// it keeps to the band between the side insets.
public func authorizationContentBand(size: CGSize, safeInsets: UIEdgeInsets, deviceMetrics: DeviceMetrics) -> (minX: CGFloat, width: CGFloat) {
    let left = safeInsets.left
    let right = safeInsets.right
    if left == right {
        return (0.0, size.width)
    }
    if deviceMetrics.isIPhoneDuoInnerScreen(size: size) {
        let inset = max(left, right)
        let width = size.width - inset * 2.0
        if width >= authorizationContentColumnWidth {
            return (inset, width)
        }
    }
    return (left, size.width - left - right)
}

public func authorizationContentBand(layout: ContainerViewLayout) -> (minX: CGFloat, width: CGFloat) {
    return authorizationContentBand(size: layout.size, safeInsets: layout.safeInsets, deviceMetrics: layout.deviceMetrics)
}

/// The horizontal band (`minX`, `width`) the login flow centres its bottom button in (and what sits beside it: the
/// divider above Sign in with Apple, the actions in the button's rows).
///
/// With equal side insets it is the full width. On iPhone Duo's unfolded screen the button spans the side strip,
/// keeping clear only of a corner block at the bottom (`bottomEdgeSideInsets`), on the axis of the content centred by
/// `authorizationContentBand`. Elsewhere (the folded screen) it keeps to the content band, so the title, the fields and
/// the button share one axis; only the system keyboard spans the strip there.
public func authorizationBottomBand(size: CGSize, safeInsets: UIEdgeInsets, bottomEdgeSideInsets: (left: CGFloat, right: CGFloat), deviceMetrics: DeviceMetrics) -> (minX: CGFloat, width: CGFloat) {
    if safeInsets.left == safeInsets.right {
        return (0.0, size.width)
    }
    if deviceMetrics.isIPhoneDuoInnerScreen(size: size) {
        return (bottomEdgeSideInsets.left, size.width - bottomEdgeSideInsets.left - bottomEdgeSideInsets.right)
    }
    return authorizationContentBand(size: size, safeInsets: safeInsets, deviceMetrics: deviceMetrics)
}

public func authorizationBottomBand(layout: ContainerViewLayout) -> (minX: CGFloat, width: CGFloat) {
    return authorizationBottomBand(size: layout.size, safeInsets: layout.safeInsets, bottomEdgeSideInsets: layout.bottomEdgeSideInsets(), deviceMetrics: layout.deviceMetrics)
}
