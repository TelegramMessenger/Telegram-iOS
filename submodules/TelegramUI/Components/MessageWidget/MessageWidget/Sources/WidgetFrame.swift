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
    /// WidgetTreeRenderer.canvas as the tiles were drawn: the view paints the colour from `canvasTop` down.
    var canvasColor: CGColor? = nil
    var canvasTop: CGFloat = 0.0
    /// The colour of the drawn widget's bottom-left and bottom-right pixel (1 pt square, unpremultiplied; nil where
    /// transparent): what a bubble's tail continues, as a photo's tail continues the photo.
    var bottomLeftColor: CGColor? = nil
    var bottomRightColor: CGColor? = nil

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
    private var drawnCanvas: (color: CGColor, top: CGFloat)?
    private var drawnCorners: (left: CGColor?, right: CGColor?) = (nil, nil)

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
        let unchanged = WidgetFrame(size: self.drawnSize, scale: self.scale, tiles: [:], canvasColor: self.drawnCanvas?.color, canvasTop: self.drawnCanvas?.top ?? 0.0, bottomLeftColor: self.drawnCorners.left, bottomRightColor: self.drawnCorners.right)
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
        self.drawnCanvas = renderer.canvas
        if size.width >= 1.0 && size.height >= 1.0 {
            self.drawnCorners = (WidgetTileDrawer.color(of: renderer, at: CGRect(x: 0.0, y: size.height - 1.0, width: 1.0, height: 1.0)),
                                 WidgetTileDrawer.color(of: renderer, at: CGRect(x: size.width - 1.0, y: size.height - 1.0, width: 1.0, height: 1.0)))
        } else {
            self.drawnCorners = (nil, nil)
        }
        return WidgetFrame(size: size, scale: self.scale, tiles: tiles, canvasColor: self.drawnCanvas?.color, canvasTop: self.drawnCanvas?.top ?? 0.0, bottomLeftColor: self.drawnCorners.left, bottomRightColor: self.drawnCorners.right)
    }

    /// The colour `renderer` paints over `rect` (one pixel at 1x), unpremultiplied; nil where it is transparent.
    static func color(of renderer: WidgetTreeRenderer, at rect: CGRect) -> CGColor? {
        guard let image = renderer.image(rect: rect, scale: 1.0) else {
            return nil
        }
        var pixel: [UInt8] = [0, 0, 0, 0]
        let drawn = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
            return true
        }
        guard drawn, pixel[3] > 0 else {
            return nil
        }
        let alpha = CGFloat(pixel[3]) / 255.0
        let channel: (UInt8) -> CGFloat = { min(1.0, CGFloat($0) / 255.0 / alpha) }
        return CGColor(srgbRed: channel(pixel[0]), green: channel(pixel[1]), blue: channel(pixel[2]), alpha: alpha)
    }
}
