import Foundation
import CoreGraphics

/// Geometry of the article editor's glass media buttons, all `buttonSize` circles: the container's "+" and
/// layout toggle in its top-right corner, and each photo/video tile's "…" in the tile's top-left corner.
/// Pure, so the layout is unit-tested (`MediaChromeLayoutTests`).
enum MediaChromeLayout {
    static let buttonSize = CGSize(width: 36.0, height: 36.0)
    static let inset: CGFloat = 8.0
    static let spacing: CGFloat = 6.0

    /// The container-level buttons, in container coordinates: "+" in the top-right corner and the toggle
    /// immediately left of it; with "+" hidden (a full album) the toggle takes the corner.
    static func containerControlFrames(containerWidth: CGFloat, showsAdd: Bool, showsToggle: Bool) -> (add: CGRect?, toggle: CGRect?) {
        let corner = CGRect(x: containerWidth - inset - buttonSize.width, y: inset, width: buttonSize.width, height: buttonSize.height)
        let add: CGRect? = showsAdd ? corner : nil
        let toggle: CGRect? = showsToggle ? (showsAdd ? corner.offsetBy(dx: -(spacing + buttonSize.width), dy: 0.0) : corner) : nil
        return (add, toggle)
    }

    /// Where a tile's "…" goes, in the tile's own coordinates. Top-left unless that comes within `spacing`
    /// of a container button (`containerControls`, container coordinates, as is `cellFrame`), which happens
    /// to a narrow tile in the top-right corner (#28: a square photo beside a portrait video); the button
    /// then moves down, below the container buttons, at the same left inset. A tile too short for that gets
    /// it as low as the tile allows, inside the tile.
    static func moreButtonOrigin(cellFrame: CGRect, avoiding containerControls: [CGRect]) -> CGPoint {
        let topLeft = CGPoint(x: inset, y: inset)
        let atTopLeft = CGRect(origin: CGPoint(x: cellFrame.minX + topLeft.x, y: cellFrame.minY + topLeft.y), size: buttonSize)
        let blockingMaxY = containerControls
            .filter { $0.insetBy(dx: -spacing, dy: -spacing).intersects(atTopLeft) }
            .map(\.maxY)
            .max()
        guard let blockingMaxY else {
            return topLeft
        }
        let belowY = blockingMaxY + spacing - cellFrame.minY
        let lowestY = max(topLeft.y, cellFrame.height - inset - buttonSize.height)
        return CGPoint(x: topLeft.x, y: min(belowY, lowestY))
    }
}
