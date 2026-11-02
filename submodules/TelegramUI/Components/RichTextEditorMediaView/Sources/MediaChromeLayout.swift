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

    /// Where a tile's "…" goes, in the tile's own coordinates (`cellFrame` and `containerControls` are in
    /// container coordinates). Top-left, unless that comes within `spacing` of a container button, which
    /// happens to a narrow tile in the top-right corner (#28: a square photo beside a portrait video). Then,
    /// the first of these that fits in the tile and keeps clear of the container buttons:
    /// - below the container buttons, at the same left inset;
    /// - in their row, just left of them, closer than `inset` to the tile's left edge.
    /// A tile too small for either (a square of ~70–85pt in the top-right corner of some 4/6/7-item albums)
    /// still gets the row position, overflowing its left edge onto its neighbour by up to `maxOverflow`
    /// (`MediaItemNodeView` hit-tests it beyond the tile and draws the tile above its neighbours). Beyond
    /// that it keeps the top-left spot and the overlap it always had: only in editors narrower than 375pt
    /// (`MediaChromeLayoutTests` sweeps the album layouts). `moreButtonOrigins` also keeps an overflowing
    /// "…" clear of the other tiles' ones.
    static func moreButtonOrigin(cellFrame: CGRect, avoiding containerControls: [CGRect]) -> CGPoint {
        func blockers(_ origin: CGPoint) -> [CGRect] {
            let button = CGRect(origin: CGPoint(x: cellFrame.minX + origin.x, y: cellFrame.minY + origin.y), size: buttonSize)
            return containerControls.filter { $0.insetBy(dx: -spacing, dy: -spacing).intersects(button) }
        }
        let topLeft = CGPoint(x: inset, y: inset)
        let blocking = blockers(topLeft)
        guard let blockingMaxY = blocking.map(\.maxY).max(), let blockingMinX = blocking.map(\.minX).min() else {
            return topLeft
        }
        let below = CGPoint(x: inset, y: blockingMaxY + spacing - cellFrame.minY)
        let beside = CGPoint(x: blockingMinX - spacing - buttonSize.width - cellFrame.minX, y: inset)
        for candidate in [below, beside] where !self.isOutsideTile(origin: candidate, tileSize: cellFrame.size) && blockers(candidate).isEmpty {
            return candidate
        }
        return -beside.x <= self.maxOverflow && blockers(beside).isEmpty ? beside : topLeft
    }

    /// The "…" origins of all the tiles of a mosaic (`moreButtonOrigin` each), except that a "…" overflowing
    /// its tile which would come within `spacing` of another tile's "…" keeps its top-left spot instead.
    static func moreButtonOrigins(cellFrames: [CGRect], avoiding containerControls: [CGRect]) -> [CGPoint] {
        var origins = cellFrames.map { self.moreButtonOrigin(cellFrame: $0, avoiding: containerControls) }
        func button(_ index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: cellFrames[index].minX + origins[index].x, y: cellFrames[index].minY + origins[index].y), size: buttonSize)
        }
        var changed = true
        while changed {
            changed = false
            for index in origins.indices where self.overflowsTile(origins[index]) {
                let area = button(index).insetBy(dx: -spacing, dy: -spacing)
                if origins.indices.contains(where: { $0 != index && button($0).intersects(area) }) {
                    origins[index] = CGPoint(x: inset, y: inset)
                    changed = true
                }
            }
        }
        return origins
    }

    /// How far a "…" may stick out of its tile: three quarters of it, so at least 9pt stays on its own tile.
    static let maxOverflow: CGFloat = buttonSize.width * 0.75

    /// Whether a "…" at `origin` (tile coordinates) is in the controls' row overflowing its tile's left edge.
    static func overflowsTile(_ origin: CGPoint) -> Bool {
        return origin.x < 0.0
    }

    /// Whether a "…" at `origin` (tile coordinates) sticks out of a tile of `tileSize`.
    static func isOutsideTile(origin: CGPoint, tileSize: CGSize) -> Bool {
        return !CGRect(origin: .zero, size: tileSize).contains(CGRect(origin: origin, size: buttonSize))
    }
}
