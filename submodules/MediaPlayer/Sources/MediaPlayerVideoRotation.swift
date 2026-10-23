import CoreGraphics
import Foundation

// The layer's bounds already have the displayed (rotated) aspect ratio. Undo
// that axis swap before rotating the layer, otherwise .resize stretches the
// unrotated raster into the portrait bounds and rotates the stretched image.
func mediaPlayerVideoRotationTransform(size: CGSize, rotationAngle: Double) -> CGAffineTransform {
    guard size.width > 0.0, size.height > 0.0, size.width.isFinite, size.height.isFinite, rotationAngle.isFinite else {
        return .identity
    }
    var transform = CGAffineTransform(rotationAngle: CGFloat(rotationAngle))
    if abs(rotationAngle.truncatingRemainder(dividingBy: Double.pi)) > 0.1 {
        transform = transform.scaledBy(x: size.height / size.width, y: size.width / size.height)
    }
    return transform
}
