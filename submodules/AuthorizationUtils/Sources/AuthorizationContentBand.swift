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
