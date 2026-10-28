import Foundation
import CoreGraphics

// On a phone whose 9:16 viewfinder fits above its bottom controls, the shutter's centre sits this far above the
// viewfinder's bottom edge (half the 96pt shutter and 5pt).
private let shutterCenterAboveViewfinderBottom: CGFloat = 53.0

/// The centre of the dual camera's round front preview in a corner of the viewfinder's container.
///
/// The offsets from the corner scale with the viewfinder's width, as in the 1080-wide frame the capture composes it
/// into (`MediaEditorScreenImpl.PIPPosition`). `leftInset`/`rightInset` keep it off a side strip the container extends
/// under.
///
/// A bottom corner is measured from the viewfinder's bottom edge. On iPhone Duo the story viewfinder is as tall as the
/// folded screen and 238pt taller than the unfolded one, so there that edge put the preview under the shutter, or below
/// the screen with the edge: the caller passes the shutter's centre (`shutterCenterY`, container coordinates) and a
/// bottom corner keeps to the shutter as it does on a phone whose viewfinder fits. It only ever raises the corner;
/// `nil` keeps the viewfinder's corner.
func cameraDualPreviewCenter(
    isLeft: Bool,
    isBottom: Bool,
    viewfinderWidth: CGFloat,
    containerSize: CGSize,
    leftInset: CGFloat,
    rightInset: CGFloat,
    shutterCenterY: CGFloat?
) -> CGPoint {
    let offset = CGPoint(x: viewfinderWidth * 267.0 / 1080.0, y: viewfinderWidth * 438.0 / 1080.0)

    let x: CGFloat
    if isLeft {
        x = leftInset + offset.x
    } else {
        x = containerSize.width - rightInset - offset.x
    }

    var y: CGFloat
    if isBottom {
        y = containerSize.height - offset.y
        if let shutterCenterY {
            y = min(y, shutterCenterY + shutterCenterAboveViewfinderBottom - offset.y)
        }
    } else {
        y = offset.y
    }
    return CGPoint(x: x, y: y)
}
