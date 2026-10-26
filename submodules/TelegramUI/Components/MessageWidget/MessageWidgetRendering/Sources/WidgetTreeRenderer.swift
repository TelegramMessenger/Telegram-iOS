import CoreGraphics
import CoreText
import Foundation
import WidgetRuntimeIOS

/// One widget's pixels on WidgetRuntime (M1d plan, Task 8): the layer tree its session last published, drawn as tiles,
/// and the badge a frozen widget shows over the bottom of its last frame. Every call inside the widget's tasks, as the
/// session's are; the trees it keeps are immutable and paint on the task's thread.
public final class WidgetTreeRenderer {
    public static let minimumHeight: CGFloat = 50.0
    public static let maximumHeight: CGFloat = 600.0
    static let maximumImagePixels: CGFloat = 4096.0 * 4096.0
    static let changeHistoryLimit = 64

    /// One more for every publish, freeze and width change: what the drawer draws since.
    public private(set) var generation: UInt64 = 0
    private var tree: WRTree?
    /// Whether a tree was published (a widget made stopped draws its badge alone).
    public var hasTree: Bool {
        return self.tree != nil
    }
    /// The width the session is laid out at (a frozen widget: the width it froze at stays its layout's).
    private var width: CGFloat
    private var frozenWidth: CGFloat?
    private var height: CGFloat = 0.0
    /// The most `documentSize` is tall: `maximumHeight`, or a bubble's fixed height under it.
    private var heightLimit: CGFloat
    private var badge: String?
    private var changes: [(generation: UInt64, rects: [CGRect]?)] = []

    /// `maximumHeight`: the most the document may be tall, clamped to minimumHeight...maximumHeight (a bubble with a
    /// fixed height passes it, so its stopped badge stays inside the clip).
    public init(width: CGFloat, maximumHeight: CGFloat = WidgetTreeRenderer.maximumHeight) {
        self.width = width
        self.heightLimit = min(max(maximumHeight, WidgetTreeRenderer.minimumHeight), WidgetTreeRenderer.maximumHeight)
    }

    /// A new most the document may be tall (an edit changed the bubble's fixed height), clamped like the initializer's.
    public func setMaximumHeight(_ maximumHeight: CGFloat) {
        let limit = min(max(maximumHeight, WidgetTreeRenderer.minimumHeight), WidgetTreeRenderer.maximumHeight)
        guard limit.isFinite, abs(limit - self.heightLimit) >= 0.01 else {
            return
        }
        self.heightLimit = limit
        self.note(nil)
    }

    /// A tree the session published at `contentSize`, changed against the last in `rects` (nil for everything). A
    /// frozen renderer keeps its last tree.
    public func publish(_ tree: WRTree, changed rects: [CGRect]?, contentSize: CGSize) {
        guard self.badge == nil else {
            return
        }
        let height = contentSize.height.isFinite ? ceil(contentSize.height) : 0.0
        // The same tree (the session hands out one object per publish) with nothing changed: nothing to draw.
        if tree === self.tree, rects?.isEmpty == true, height == self.height {
            return
        }
        self.tree = tree
        self.height = height
        self.note(rects)
    }

    /// The width laid out at. A frozen widget keeps its last tree, drawn at its own layout and clipped to the new width.
    public func setWidth(_ width: CGFloat) {
        guard width.isFinite, abs(width - self.width) >= 0.01 else {
            return
        }
        self.width = width
        if self.badge != nil {
            self.note(nil)
        }
    }

    /// Stops taking trees and draws `label`'s badge over the bottom of the last one; the height stays.
    public func freeze(label: String) {
        guard self.badge == nil else {
            return
        }
        self.frozenWidth = self.width
        self.badge = label
        self.note(self.badgeRect().map { [$0] })
    }

    /// The label of the badge a frozen renderer draws; nil while live.
    public var frozenLabel: String? {
        return self.badge
    }

    /// The canvas colour of the tree drawn (CSS 2.1 §14.2: the root's background, or the body's it propagates), and where
    /// the tree's painting of it ends: the document's height in whole CSS px, as the painter rounds boxes (from the
    /// rounded-up height a band up to a pixel tall stayed the bubble's colour); nil when the widget sets no background.
    /// A host view taller than the document (the 50 pt minimum, a bubble's fixed height) paints it from `top` down (R4).
    public var canvas: (color: CGColor, top: CGFloat)? {
        guard let tree = self.tree, tree.canvasColor & 0xff != 0 else {
            return nil
        }
        let rgba = tree.canvasColor
        let channel: (UInt32) -> CGFloat = { shift in CGFloat((rgba >> shift) & 0xff) / 255.0 }
        return (CGColor(srgbRed: channel(24), green: channel(16), blue: channel(8), alpha: channel(0)), floor(tree.size.height))
    }

    /// The widget's size, the old ops renderer's (its `documentSize`): the width laid out at, which content wider
    /// than it overflows and is clipped to, and the height clamped to minimumHeight and the renderer's own maximum.
    public var documentSize: CGSize {
        let width = self.frozenWidth.map { min($0, self.width) } ?? self.width
        return CGSize(width: width, height: min(max(self.height, WidgetTreeRenderer.minimumHeight), self.heightLimit))
    }

    /// Document rects changed since `generation` was current; nil = everything (or unknown).
    public func changedRects(since generation: UInt64) -> [CGRect]? {
        if generation == self.generation {
            return []
        }
        guard generation < self.generation, let first = self.changes.first, first.generation <= generation + 1 else {
            return nil
        }
        var rects: [CGRect] = []
        for change in self.changes where change.generation > generation {
            guard let changed = change.rects else {
                return nil
            }
            rects.append(contentsOf: changed)
        }
        return rects
    }

    /// Pixels of `rect` (document coordinates) at `scale`: the tree, and the badge where it covers the rect. The tiles of
    /// one draw pass one `effects`, so that each filter and backdrop result they show is made once.
    public func image(rect: CGRect, scale: CGFloat, effects: WREffectStore? = nil) -> CGImage? {
        guard let tree = self.tree, scale.isFinite, scale > 0.0, rect.minX.isFinite, rect.minY.isFinite, rect.width.isFinite, rect.height.isFinite, rect.width > 0.0, rect.height > 0.0, rect.width * scale * rect.height * scale <= WidgetTreeRenderer.maximumImagePixels else {
            return nil
        }
        guard let base = tree.copyImage(of: rect, scale: scale, effects: effects) else {
            return nil
        }
        guard let label = self.badge, let badge = self.badgeRect(), badge.intersects(rect) else {
            return base
        }
        let pw = base.width, ph = base.height
        guard let context = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return base
        }
        context.draw(base, in: CGRect(x: 0, y: 0, width: pw, height: ph))
        // y up, in pixels: a document point (x, y) is at ((x - rect.minX) × scale, (rect.maxY - y) × scale).
        let pill = CGRect(x: (badge.minX - rect.minX) * scale, y: (rect.maxY - badge.maxY) * scale, width: badge.width * scale, height: badge.height * scale)
        context.setFillColor(CGColor(srgbRed: 60.0 / 255.0, green: 60.0 / 255.0, blue: 60.0 / 255.0, alpha: 0.75))
        // CGPath requires a radius of at most half of each side.
        let radius = min(WidgetTreeRenderer.badgeRadius * scale, pill.width / 2.0, pill.height / 2.0)
        context.addPath(CGPath(roundedRect: pill, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
        let line = WidgetTreeRenderer.badgeLine(label, scale: scale)
        let font = WidgetTreeRenderer.badgeFont(scale: scale)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        let lineHeight = WidgetTreeRenderer.badgeFontSize * WidgetTreeRenderer.badgeLineHeight * scale
        context.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.textPosition = CGPoint(x: pill.minX + WidgetTreeRenderer.badgePadding.width * scale, y: pill.minY + WidgetTreeRenderer.badgePadding.height * scale + (lineHeight - ascent - descent) / 2.0 + descent)
        CTLineDraw(line, context)
        return context.makeImage() ?? base
    }

    // MARK: the badge

    /// The old ops renderer's frozen chrome (its `frozenStyle`), drawn rather than built: 6 px from the left and the
    /// bottom (the old one's right corner is where a captionless widget's bubble draws its date pill), `font: 11px/1.3
    /// -apple-system`, white on rgba(60,60,60,.75), padding 2 px × 7 px, radius 9 px.
    static let badgeInset: CGFloat = 6.0
    static let badgeFontSize: CGFloat = 11.0
    static let badgeLineHeight: CGFloat = 1.3
    static let badgePadding = CGSize(width: 7.0, height: 2.0)
    static let badgeRadius: CGFloat = 9.0

    private static func badgeFont(scale: CGFloat) -> CTFont {
        return CTFontCreateUIFontForLanguage(.system, WidgetTreeRenderer.badgeFontSize * scale, nil) ?? CTFontCreateWithName("Helvetica" as CFString, WidgetTreeRenderer.badgeFontSize * scale, nil)
    }

    private static func badgeLine(_ label: String, scale: CGFloat) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): WidgetTreeRenderer.badgeFont(scale: scale),
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attributes))
    }

    /// The badge's box in document coordinates, at the bottom left of the widget; nil when not frozen.
    private func badgeRect() -> CGRect? {
        guard let label = self.badge else {
            return nil
        }
        let line = WidgetTreeRenderer.badgeLine(label, scale: 1.0)
        let textWidth = ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
        let size = CGSize(width: textWidth + 2.0 * WidgetTreeRenderer.badgePadding.width, height: WidgetTreeRenderer.badgeFontSize * WidgetTreeRenderer.badgeLineHeight + 2.0 * WidgetTreeRenderer.badgePadding.height)
        let document = self.documentSize
        return CGRect(x: WidgetTreeRenderer.badgeInset, y: max(0.0, document.height - WidgetTreeRenderer.badgeInset - size.height), width: size.width, height: size.height)
    }

    // MARK: generations

    private func note(_ rects: [CGRect]?) {
        self.generation += 1
        if rects == nil {
            self.changes.removeAll()
        }
        self.changes.append((generation: self.generation, rects: rects))
        if self.changes.count > WidgetTreeRenderer.changeHistoryLimit {
            self.changes.removeFirst(self.changes.count - WidgetTreeRenderer.changeHistoryLimit)
        }
    }
}
