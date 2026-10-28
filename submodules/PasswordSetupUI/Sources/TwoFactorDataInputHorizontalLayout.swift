import Foundation
import UIKit
import Display
import AuthorizationUtils

/// The horizontal bands `TwoFactorDataInputScreen` lays out in (`minX`, `width` each).
struct TwoFactorDataInputHorizontalLayout: Equatable {
    /// The content above the button: icon, title, text and the fields.
    var contentMinX: CGFloat
    var contentWidth: CGFloat
    /// The band the bottom button is centred in.
    var bottomMinX: CGFloat
    var bottomWidth: CGFloat
    /// The row of the text actions that take the button's place while it is hidden ("Can't access your email?" or
    /// "Change Email", and "Re-send Code"), the left one at its leading edge and the right one at its trailing edge.
    var actionsMinX: CGFloat
    var actionsWidth: CGFloat
}

/// The content lays out in the band between the side insets when they differ (iPhone Duo's side strip: the fields ran
/// under it); across the screen otherwise. In the login flow (password recovery) it is centred on the full width on the
/// unfolded screen, as the other login screens do (`authorizationContentBand`).
///
/// The button spans iPhone Duo's side strip; it keeps clear only of a corner block at the bottom. In the login flow it
/// keeps to the content's axis (`authorizationBottomBand`): unfolded as above, folded in the content band.
///
/// The text actions in the button's row line up with the fields (`rowSideInset` into the content band), as they do
/// on every other device; in the login flow they keep to the button's frame.
func twoFactorDataInputHorizontalLayout(layout: ContainerViewLayout, isAuthorizationFlow: Bool, rowSideInset: CGFloat) -> TwoFactorDataInputHorizontalLayout {
    let insetsDiffer = layout.safeInsets.left != layout.safeInsets.right
    let contentBand: (minX: CGFloat, width: CGFloat)
    let bottomBand: (minX: CGFloat, width: CGFloat)
    if isAuthorizationFlow {
        contentBand = authorizationContentBand(layout: layout)
        bottomBand = authorizationBottomBand(layout: layout)
    } else {
        let bottomSideInsets = layout.bottomEdgeSideInsets()
        contentBand = insetsDiffer ? (layout.safeInsets.left, layout.size.width - layout.safeInsets.left - layout.safeInsets.right) : (0.0, layout.size.width)
        bottomBand = insetsDiffer ? (bottomSideInsets.left, layout.size.width - bottomSideInsets.left - bottomSideInsets.right) : (0.0, layout.size.width)
    }
    let actionsBand = isAuthorizationFlow ? bottomBand : contentBand
    return TwoFactorDataInputHorizontalLayout(
        contentMinX: contentBand.minX,
        contentWidth: contentBand.width,
        bottomMinX: bottomBand.minX,
        bottomWidth: bottomBand.width,
        actionsMinX: actionsBand.minX + rowSideInset,
        actionsWidth: actionsBand.width - rowSideInset * 2.0
    )
}
