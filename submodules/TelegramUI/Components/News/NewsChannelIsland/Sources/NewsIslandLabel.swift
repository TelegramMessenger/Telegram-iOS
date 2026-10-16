import Foundation
import UIKit
import CoreText
import Display
import NewsFeedSupport

/// One label of the island cut into a layer per glyph, icons included, so each glyph rolls on its own (spec §2,
/// `RollRenderer`). Glyphs are drawn one by one from the shaped line, so shaping and kerning are the line's.
final class NewsIslandLabel {
    enum Piece {
        case text(String)
        /// An inline image whose bottom sits on the baseline (on its own baseline for a symbol), moved by
        /// `baselineOffset` (positive raises it, as SwiftUI's `baselineOffset`).
        case icon(UIImage, baselineOffset: CGFloat)
    }

    /// One glyph: the outer layer moves, fades and blurs; the inner one is the colour, cut out by the glyph's mask.
    final class Glyph {
        let layer = SimpleLayer()
        let colorLayer = SimpleLayer()
        let maskLayer = SimpleLayer()
    }

    let layer = SimpleLayer()
    let size: CGSize
    /// The line box's top inside `layer`: the label is centred on its line, not on icons hanging below it.
    let lineTop: CGFloat
    let lineHeight: CGFloat
    private let glyphs: [Glyph]

    init(pieces: [Piece], font: UIFont) {
        /// Room around a glyph for its blur.
        let pad: CGFloat = 6.0
        let baseline = font.ascender
        let lineHeight = font.ascender - font.descender

        var cuts: [(rect: CGRect, draw: (CGContext) -> Void)] = []
        var x: CGFloat = 0.0
        for piece in pieces {
            switch piece {
            case let .text(string):
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font]))
                for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
                    let count = CTRunGetGlyphCount(run)
                    if count == 0 {
                        continue
                    }
                    let attributes = CTRunGetAttributes(run) as NSDictionary
                    // A fallback font when the run's characters are not in `font`.
                    let runFont: CTFont = attributes[kCTFontAttributeName as String].map { $0 as! CTFont } ?? (font as CTFont)
                    var glyphs = [CGGlyph](repeating: 0, count: count)
                    var positions = [CGPoint](repeating: CGPoint(), count: count)
                    var advances = [CGSize](repeating: CGSize(), count: count)
                    CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
                    CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
                    CTRunGetAdvances(run, CFRange(location: 0, length: count), &advances)
                    for i in 0 ..< count {
                        let glyphX = x + positions[i].x
                        let glyph = glyphs[i]
                        let rect = CGRect(x: glyphX, y: 0.0, width: advances[i].width, height: lineHeight)
                        cuts.append((rect, { context in
                            context.saveGState()
                            context.translateBy(x: glyphX, y: baseline)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.setFillColor(UIColor.white.cgColor)
                            var drawnGlyph = glyph
                            var origin = CGPoint()
                            CTFontDrawGlyphs(runFont, &drawnGlyph, &origin, 1, context)
                            context.restoreGState()
                        }))
                    }
                }
                x += CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            case let .icon(image, baselineOffset):
                // nil for an image without a baseline (the bells); a symbol's own baseline otherwise.
                let bottom = baseline + (image.baselineOffsetFromBottom ?? 0.0) - baselineOffset
                let rect = CGRect(x: x, y: bottom - image.size.height, width: image.size.width, height: image.size.height)
                cuts.append((rect, { _ in
                    image.draw(in: rect)
                }))
                x += image.size.width
            }
        }

        let minY = min(0.0, cuts.map { $0.rect.minY }.min() ?? 0.0)
        let maxY = max(lineHeight, cuts.map { $0.rect.maxY }.max() ?? lineHeight)
        self.size = CGSize(width: ceil(x), height: ceil(maxY - minY))
        self.lineTop = -minY
        self.lineHeight = lineHeight

        var glyphs: [Glyph] = []
        for cut in cuts {
            let frame = cut.rect.offsetBy(dx: 0.0, dy: -minY).insetBy(dx: -pad, dy: -pad)
            let renderer = UIGraphicsImageRenderer(size: frame.size)
            let image = renderer.image { rendererContext in
                let context = rendererContext.cgContext
                context.translateBy(x: pad - cut.rect.minX, y: pad - cut.rect.minY)
                cut.draw(context)
            }
            let glyph = Glyph()
            glyph.layer.frame = frame
            glyph.colorLayer.frame = glyph.layer.bounds
            glyph.maskLayer.frame = glyph.layer.bounds
            glyph.maskLayer.contents = image.cgImage
            glyph.maskLayer.contentsScale = image.scale
            glyph.colorLayer.mask = glyph.maskLayer
            glyph.layer.addSublayer(glyph.colorLayer)
            self.layer.addSublayer(glyph.layer)
            glyphs.append(glyph)
        }
        self.glyphs = glyphs
        self.layer.bounds = CGRect(origin: CGPoint(), size: self.size)
    }

    /// `rollProgress` nil: at rest (shown if incoming, hidden if outgoing).
    func apply(color: CGColor, rollProgress: CGFloat?, isIncoming: Bool) {
        let count = self.glyphs.count
        for (index, glyph) in self.glyphs.enumerated() {
            glyph.colorLayer.backgroundColor = color
            let state: NewsGlyphRoll
            if let rollProgress {
                let local = NewsLabelRoll.local(rollProgress, index: index, count: count)
                state = isIncoming ? NewsLabelRoll.incoming(local) : NewsLabelRoll.outgoing(local)
            } else {
                state = NewsGlyphRoll(dy: 0.0, alpha: isIncoming ? 1.0 : 0.0, blur: 0.0)
            }
            glyph.layer.transform = CATransform3DMakeTranslation(0.0, state.dy, 0.0)
            glyph.layer.opacity = Float(state.alpha)
            if state.blur > 0.05, let blur = CALayer.blur() {
                blur.setValue(state.blur as NSNumber, forKey: "inputRadius")
                glyph.layer.filters = [blur]
            } else if glyph.layer.filters != nil {
                glyph.layer.filters = nil
            }
        }
    }
}
