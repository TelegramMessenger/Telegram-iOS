import CoreGraphics
import Foundation
import MessageWidgetRendering

/// A widget's pixels as 128 pt tiles (spec 2026-10-15 D4), each a CGImage the renderer rasterized into a bitmap context
/// of its own at `scale`. As a task's result it holds the tiles the task changed; as main's frame, every tile.
struct WidgetFrame {
    static let tileSize: CGFloat = 128.0

    /// The document size the tiles cover.
    var size: CGSize
    var scale: CGFloat
    /// Keyed by `key(row:column:)`.
    var tiles: [Int: CGImage]

    static func key(row: Int, column: Int) -> Int {
        return row << 16 | column
    }

    /// The tile's rect in document coordinates: 128 pt, cut to `size` at the right and bottom edges.
    static func rect(forKey key: Int, size: CGSize) -> CGRect {
        let row = key >> 16, column = key & 0xffff
        let tile = CGRect(x: CGFloat(column) * WidgetFrame.tileSize, y: CGFloat(row) * WidgetFrame.tileSize, width: WidgetFrame.tileSize, height: WidgetFrame.tileSize)
        return tile.intersection(CGRect(origin: .zero, size: size))
    }

    /// Every tile key that covers `size`.
    static func grid(for size: CGSize) -> [Int] {
        let columns = max(0, Int(ceil(size.width / WidgetFrame.tileSize)))
        let rows = max(0, Int(ceil(size.height / WidgetFrame.tileSize)))
        var keys: [Int] = []
        for row in 0 ..< rows {
            for column in 0 ..< columns {
                keys.append(WidgetFrame.key(row: row, column: column))
            }
        }
        return keys
    }
}

/// Draws a renderer's changes since its last draw as tiles. Where the widget's work runs, never on main (spec D2).
/// Nothing draws in `CALayer.draw(in:)`: LiteHTML's shadow code assumes an identity base CTM, which a layer's backing
/// context does not have at 2x/3x. Memory follows the widget's area (at most 900 pt high), not its CSS.
final class WidgetTileDrawer {
    let scale: CGFloat
    /// What the last draw was of: the renderer's generation and the document size.
    private var drawnGeneration: UInt64 = .max
    private var drawnSize: CGSize = .zero

    init(scale: CGFloat) {
        self.scale = scale
    }

    /// Whether `renderer` changed since the last draw (or was never drawn).
    func needsDraw(_ renderer: WidgetTreeRenderer) -> Bool {
        return renderer.generation != self.drawnGeneration || renderer.documentSize != self.drawnSize
    }

    /// The tiles that changed since the last draw: every tile when the size changed (or on the first draw), else those
    /// the renderer's changed rects touch; none when nothing changed. A tile that cannot be drawn (nothing published
    /// yet) draws nothing: the result is the last size with no tiles, so main keeps the last frame.
    func draw(_ renderer: WidgetTreeRenderer) -> WidgetFrame {
        let unchanged = WidgetFrame(size: self.drawnSize, scale: self.scale, tiles: [:])
        let size = renderer.documentSize
        let generation = renderer.generation
        if generation == self.drawnGeneration && size == self.drawnSize {
            return unchanged
        }
        let full = size != self.drawnSize || self.drawnGeneration == .max
        let dirty: [CGRect]? = full ? nil : renderer.changedRects(since: self.drawnGeneration)
        let keys = WidgetFrame.grid(for: size).filter { key in
            let rect = WidgetFrame.rect(forKey: key, size: size)
            return dirty.map { dirty in dirty.contains(where: { $0.intersects(rect) }) } ?? true
        }
        // The tiles are drawn in parallel (the user's goal, 2026-10-19: minimal boot and update latency; a boot draws
        // every tile, ~2/3 of the slowest boots' time): a published tree paints on any thread, and each tile is a
        // bitmap of its own.
        let scale = self.scale
        let images = UnsafeMutableBufferPointer<CGImage?>.allocate(capacity: keys.count)
        images.initialize(repeating: nil)
        defer {
            images.deinitialize()
            images.deallocate()
        }
        if keys.count > 1 {
            DispatchQueue.concurrentPerform(iterations: keys.count) { i in
                images[i] = renderer.image(rect: WidgetFrame.rect(forKey: keys[i], size: size), scale: scale)
            }
        } else if let key = keys.first {
            images[0] = renderer.image(rect: WidgetFrame.rect(forKey: key, size: size), scale: scale)
        }
        var tiles: [Int: CGImage] = [:]
        for (i, key) in keys.enumerated() {
            guard let image = images[i] else {
                return unchanged
            }
            tiles[key] = image
        }
        self.drawnGeneration = generation
        self.drawnSize = size
        return WidgetFrame(size: size, scale: self.scale, tiles: tiles)
    }
}
