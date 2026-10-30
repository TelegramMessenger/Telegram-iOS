import Foundation
import UIKit
import Display

/// The side insets of the caption panel's rows from `minY` to `maxY` when it lays itself out in a full-screen container
/// (`updateContainerLayoutSize`, the media editors). Beside iPhone Duo's side strip a row keeps clear of a corner block
/// it reaches (a caption above the media sits in folded portrait's status corner) and spans the strip elsewhere, as the
/// chat's input panel does. Without reserved corners (every other device) the panel spans the container's full width
/// whatever the safe insets, as it always has.
public func legacyMessageInputPanelSideInsets(forRowsFrom minY: CGFloat, to maxY: CGFloat, containerHeight: CGFloat, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> (left: CGFloat, right: CGFloat) {
    if reservedCorners == .none {
        return (0.0, 0.0)
    }
    return bandSideInsets(forBandFrom: minY, to: maxY, containerHeight: containerHeight, safeInsets: safeInsets, reservedCorners: reservedCorners)
}
