import Foundation
import CoreGraphics

/// The centre of the dual camera's round front preview in a corner of the viewfinder's container.
///
/// The offsets from the corner scale with the viewfinder's width, as in the 1080-wide frame the capture composes it
/// into (`MediaEditorScreenImpl.PIPPosition`), so the preview shows where the capture will put it. `leftInset`/`rightInset`
/// keep it off a side strip the container extends under.
///
/// A bottom corner is measured from the viewfinder's bottom edge. Where that edge is below the screen (`visibleHeight`,
/// the container's height on screen: iPhone Duo unfolded, whose 9:16 viewfinder is 238pt taller than the screen) the
/// preview went there with it. If the caller passes the shutter's centre (`shutterCenterY`, container coordinates), a
/// bottom corner then keeps to the shutter as on a phone whose viewfinder fits, where the shutter's centre is
/// `shutterCenterAboveViewfinderBottom` above that edge. The capture keeps the frame's corner, which the screen does not
/// show there. A viewfinder that ends on the screen keeps its corner, also where the controls are lifted over it
/// (home-button phones, iPhone Duo folded), so that the preview matches the capture.
func cameraDualPreviewCenter(
    isLeft: Bool,
    isBottom: Bool,
    viewfinderWidth: CGFloat,
    containerSize: CGSize,
    visibleHeight: CGFloat,
    leftInset: CGFloat,
    rightInset: CGFloat,
    shutterCenterY: CGFloat?,
    shutterCenterAboveViewfinderBottom: CGFloat
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
        if let shutterCenterY, containerSize.height > visibleHeight {
            y = min(y, shutterCenterY + shutterCenterAboveViewfinderBottom - offset.y)
        }
    } else {
        y = offset.y
    }
    return CGPoint(x: x, y: y)
}
