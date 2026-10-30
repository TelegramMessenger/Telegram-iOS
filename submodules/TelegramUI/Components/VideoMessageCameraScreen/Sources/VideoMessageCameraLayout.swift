import Foundation
import UIKit
import Display

/// iPhone Duo: the round preview on a phone, kept above the chat's input panel. On the folded screen the phone
/// placement (a circle as wide as the band, centred at 40% of the height above the keyboard) reaches far below the
/// panel's top when a bot keyboard is up (the window does not report it as input) or the system keyboard leaves a short
/// screen, and covers the panel's Cancel, trash and recording time. The circle then moves up and shrinks, as little as
/// needed, to end `bottomSpacing` above the panel, centred on the band again; it keeps `topY` at least. The spacing
/// keeps it clear of the flip and flash buttons that sit beside its lower corners, just above the panel. A circle
/// that already ends above the panel keeps `frame`.
func videoMessageCameraPreviewFrameAbovePanel(frame: CGRect, bandMinX: CGFloat, bandMaxX: CGFloat, topY: CGFloat, panelTop: CGFloat, bottomSpacing: CGFloat = 20.0) -> CGRect {
    let maxY = panelTop - bottomSpacing
    if frame.maxY <= maxY {
        return frame
    }
    let side = max(0.0, min(frame.width, maxY - topY))
    let x = bandMinX + floorToScreenPixels((bandMaxX - bandMinX - side) / 2.0)
    return CGRect(origin: CGPoint(x: x, y: maxY - side), size: CGSize(width: side, height: side))
}

/// The part of the right edge the trailing buttons' column in the rows `minY..maxY` keeps clear of: on iPhone Duo the
/// side strip where its corner block reaches the rows (folded portrait's status corner is 170pt tall, so the view-once
/// button above a bot keyboard's panel would sit under the clock), else none, as before on every other device.
func videoMessageCameraTrailingControlInset(minY: CGFloat, maxY: CGFloat, containerHeight: CGFloat, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners) -> CGFloat {
    if reservedCorners == .none {
        return 0.0
    }
    return bandSideInsets(forBandFrom: minY, to: maxY, containerHeight: containerHeight, safeInsets: safeInsets, reservedCorners: reservedCorners).right
}

/// Whether a touch at `y` goes to the chat's input panel below the camera screen. The window reports the system
/// keyboard as input, so everything from `inputPanelHeight` above it down passes, as before. A bot keyboard (or another
/// input node the chat shows in the keyboard's place) is not reported: the panel stays at `inputPanelFrame`, where it
/// was when recording began, and only its rows pass, the input node below it staying covered. Without that, the
/// panel's Cancel and trash buttons above a bot keyboard never received a touch, and recording could not be left.
func videoMessageCameraPassesTouchToInputPanel(y: CGFloat, layoutHeight: CGFloat, bottomInset: CGFloat, inputPanelFrame: CGRect, hasInputNode: Bool) -> Bool {
    if y > layoutHeight - bottomInset - inputPanelFrame.height {
        return true
    }
    if hasInputNode && y >= inputPanelFrame.minY && y <= inputPanelFrame.maxY {
        return true
    }
    return false
}

/// Whether the round preview takes a touch at `point`, in the preview's coordinates (`bounds` is its square). It claims
/// its whole square, though only the inscribed circle shows, except over the chat's input panel (`overInputPanel`):
/// there the square's lower corners lie over the panel's trash and send, so only the circle is the preview's. Above a
/// tall bot keyboard the square reached into the panel's rows on every phone, and those taps opened the preview.
func videoMessageCameraPreviewClaimsTouch(point: CGPoint, bounds: CGRect, overInputPanel: Bool) -> Bool {
    if !bounds.contains(point) {
        return false
    }
    if !overInputPanel {
        return true
    }
    let radius = min(bounds.width, bounds.height) / 2.0
    let dx = point.x - bounds.midX
    let dy = point.y - bounds.midY
    return dx * dx + dy * dy <= radius * radius
}
