import Foundation
import UIKit

/// The widest a toast gets on a regular-width layout (iPad, iPhone Duo unfolded in landscape): the toast of the
/// largest phone, 440pt wide less the toast's 12pt margins.
public let toastMaximumWidth: CGFloat = 416.0

/// The frame of a toast (a transient panel along the bottom or top of its container) given `band`, the frame it
/// fills on a phone: the band itself on a compact-width layout; on a regular-width one at most `toastMaximumWidth`
/// wide, centred on the band. The band is in the toast's own container, so a toast laid out in a split view's pane is
/// centred in that pane and one laid out in the window is centred in the window.
///
/// `anchorX` is an x the toast points at (an arrow at a tab): the narrowed frame moves off the centre, within the band,
/// as far as needed to keep `anchorMargin` on both sides of it.
public func toastFrame(_ band: CGRect, metrics: LayoutMetrics, anchorX: CGFloat? = nil, anchorMargin: CGFloat = 32.0) -> CGRect {
    guard case .regular = metrics.widthClass, band.width > toastMaximumWidth else {
        return band
    }
    var x = floorToScreenPixels(band.minX + (band.width - toastMaximumWidth) / 2.0)
    if let anchorX {
        x = min(max(x, anchorX + anchorMargin - toastMaximumWidth), anchorX - anchorMargin)
        x = floorToScreenPixels(max(band.minX, min(x, band.maxX - toastMaximumWidth)))
    }
    return CGRect(x: x, y: band.minY, width: toastMaximumWidth, height: band.height)
}
