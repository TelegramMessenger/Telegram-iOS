import Foundation
import UIKit
import CoreText
import Display
import SwiftSignalKit
import AppBundle
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ComponentFlow
import AvatarComponent
import BundleIconComponent
import MultilineTextComponent
import PlainButtonComponent

private final class WalletSendRecipientIntroView: UIView {
    private struct ShapeKey: Hashable {
        var font: String
        var size: CGFloat
        var glyph: CGGlyph
    }
    private struct Shape {
        var path: CGPath
        var image: UIImage?
        var advance: CGFloat
    }
    private struct Piece {
        var shape: Shape
        var font: CTFont
        var origin: CGPoint
        var width: CGFloat
        var color: UIColor
        var column: Int
        var space: Bool
    }
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    private var shapes: [ShapeKey: Shape] = [:]
    private var title: [Piece] = []
    private var address: [[Piece]] = []
    private var titleLayouts: [TextNodeLayout] = []
    private var titleFrames: [CGRect] = []
    private var addressLayout: TextNodeLayout?
    private var addressFrame = CGRect.zero
    private var avatarFrame = CGRect.zero
    private var avatarImage: UIImage?
    private var coarseAvatar: UIImage?
    private var fineAvatar: UIImage?
    private var font: CTFont = Font.monospace(14.0) as CTFont
    private var secondary = UIColor.gray
    private var primary = UIColor.black
    private var time: Double = 0.0
    private var loadingAddress = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.accessibilityElementsHidden = true
        self.contentScaleFactor = UIScreenScale
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func noise(_ a: Int, _ salt: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: a &* 73_856_093 ^ salt &* 19_349_663)
        x ^= x >> 13; x = x &* 0x5bd1_e995; x ^= x >> 15
        return Double(x % 10_000) / 10_000.0
    }

    private static func start(x: CGFloat, salt: Int, delay: Double = 0.0) -> Double {
        return 0.1 + delay + 0.5 * Double(x / 300.0) + 0.14 * self.noise(Int(x * 10.0), salt)
    }

    private static func path(_ u: Double) -> (p: Double, speed: Double) {
        let x = u - 1.0
        return (1.0 + 1.9 * x * x * x + 0.9 * x * x, 5.7 * x * x + 1.8 * x)
    }

    private static func passTime(_ target: Double) -> Double {
        var lo = 0.0, hi = 1.0
        for _ in 0 ..< 18 {
            let mid = (lo + hi) / 2.0
            if self.path(mid).p < target { lo = mid } else { hi = mid }
        }
        return hi
    }

    private static func smooth(_ value: Double) -> Double {
        let k = min(1.0, max(0.0, value))
        return k * k * (3.0 - 2.0 * k)
    }

    private func shape(font: CTFont, glyph: CGGlyph) -> Shape {
        let key = ShapeKey(font: CTFontCopyPostScriptName(font) as String, size: CTFontGetSize(font), glyph: glyph)
        if let shape = self.shapes[key] { return shape }
        var glyph = glyph
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
        let path: CGPath
        var image: UIImage?
        if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
            path = outline
        } else {
            let bounds = CTFontGetBoundingRectsForGlyphs(font, .horizontal, &glyph, nil, 1).integral
            if !bounds.isEmpty && !bounds.isInfinite && !bounds.isNull {
                let format = UIGraphicsImageRendererFormat()
                format.scale = UIScreenScale
                image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { renderer in
                    let context = renderer.cgContext
                    context.translateBy(x: -bounds.minX, y: bounds.maxY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    var position = CGPoint.zero
                    CTFontDrawGlyphs(font, &glyph, &position, 1, context)
                }
                path = CGPath(rect: bounds, transform: nil)
            } else {
                path = CGMutablePath()
            }
        }
        let result = Shape(path: path, image: image, advance: advance.width)
        self.shapes[key] = result
        return result
    }

    private func random(_ index: Int, salt: Int, font: CTFont, time: Double? = nil) -> Shape {
        let tick = Int(min(max(time ?? self.time, 0.0), 3600.0) / 0.045)
        let hash = (index &* 2_654_435_761) ^ (tick &* 40_503) ^ (salt &* 97)
        var code = String(Self.alphabet[(hash & 0x7fff_ffff) % Self.alphabet.count]).utf16.first!
        var glyph: CGGlyph = 0
        var font = font
        if !CTFontGetGlyphsForCharacters(font, &code, &glyph, 1) {
            font = Font.regular(CTFontGetSize(font)) as CTFont
            CTFontGetGlyphsForCharacters(font, &code, &glyph, 1)
        }
        return self.shape(font: font, glyph: glyph)
    }

    private func pieces(_ view: TextView, frame: CGRect) -> [[Piece]] {
        guard let layout = view.cachedLayout else { return [] }
        let text = (layout.attributedString?.string ?? "") as NSString
        var lines: [[Piece]] = []
        layout.enumerateRenderedLines(in: view.bounds) { line, baseline in
            var pieces: [Piece] = []
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attributes = CTRunGetAttributes(run) as NSDictionary
                let font = attributes[kCTFontAttributeName] as! CTFont
                let color = attributes[NSAttributedString.Key.foregroundColor.rawValue] as? UIColor ?? self.primary
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                var advances = [CGSize](repeating: .zero, count: count)
                var indices = [CFIndex](repeating: 0, count: count)
                CTRunGetGlyphs(run, CFRange(), &glyphs)
                CTRunGetPositions(run, CFRange(), &positions)
                CTRunGetAdvances(run, CFRange(), &advances)
                CTRunGetStringIndices(run, CFRange(), &indices)
                for i in 0 ..< count {
                    let index = indices[i]
                    let space = index >= 0 && index < text.length && text.character(at: index) == 32
                    pieces.append(Piece(shape: self.shape(font: font, glyph: glyphs[i]), font: font,
                        origin: CGPoint(x: frame.minX + baseline.x + positions[i].x, y: frame.minY + baseline.y - positions[i].y),
                        width: advances[i].width, color: color, column: pieces.count, space: space))
                }
            }
            lines.append(pieces)
        }
        return lines
    }

    func updateTitle(_ views: [TextView], frames: [CGRect], primary: UIColor, secondary: UIColor) {
        self.primary = primary
        self.secondary = secondary
        let layouts = views.compactMap { $0.cachedLayout }
        guard self.titleFrames != frames || layouts.count != self.titleLayouts.count
            || !zip(layouts, self.titleLayouts).allSatisfy({ $0.0 === $0.1 }) else { return }
        self.titleLayouts = layouts
        self.titleFrames = frames
        self.title = zip(views, frames).flatMap { view, frame in
            self.pieces(view, frame: frame).flatMap { $0 }.filter { !$0.space }
        }
    }

    func updateAddress(_ view: TextView, frame: CGRect, loading: Bool) {
        self.loadingAddress = loading
        guard self.addressLayout !== view.cachedLayout || self.addressFrame != frame else { return }
        self.addressLayout = view.cachedLayout
        self.addressFrame = frame
        self.address = self.pieces(view, frame: frame)
        if let font = self.address.first?.first?.font { self.font = font }
    }

    func updateAvatar(_ view: UIView, frame: CGRect) {
        self.avatarFrame = frame
        guard self.avatarImage == nil, !view.bounds.isEmpty else { return }
        func display(_ layer: CALayer) {
            layer.displayIfNeeded()
            for child in layer.sublayers ?? [] { display(child) }
        }
        display(view.layer)
        let alpha = view.alpha
        view.alpha = 1.0
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { renderer in
            view.layer.render(in: renderer.cgContext)
        }
        view.alpha = alpha
        self.avatarImage = image
        let grid = self.avatarGrid
        func sample(_ split: Int) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let size = CGSize(width: CGFloat(grid.columns * split), height: CGFloat(grid.rows * split))
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        self.coarseAvatar = sample(2)
        self.fineAvatar = sample(4)
    }

    func update(time: Double) {
        self.time = time
        self.setNeedsDisplay()
    }

    private func fill(_ shape: Shape, at origin: CGPoint, color: UIColor, alpha: CGFloat = 1.0, context: CGContext) {
        context.saveGState()
        context.setAlpha(alpha)
        if let image = shape.image {
            let bounds = shape.path.boundingBoxOfPath
            image.draw(in: CGRect(x: origin.x + bounds.minX, y: origin.y - bounds.maxY, width: bounds.width, height: bounds.height))
        } else {
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: 1.0, y: -1.0)
            context.setFillColor(color.cgColor)
            context.addPath(shape.path)
            context.fillPath()
        }
        context.restoreGState()
    }

    private func smear(_ shape: Shape, at origin: CGPoint, font: CTFont, velocity: CGFloat,
                        color: UIColor, alpha: CGFloat, context: CGContext) {
        guard alpha > 0.01 else { return }
        let length = min(max(velocity, 0.0) * 0.04, CTFontGetSize(font) * 1.2)
        let samples = length > 1.0 ? min(2 + Int(length / 1.2), 14) : 1
        let weights = (0 ..< samples).map { index -> CGFloat in
            let k = samples > 1 ? CGFloat(index) / CGFloat(samples - 1) : 0.0
            return pow(1.0 - k, 1.6)
        }
        let total = max(weights.dropFirst().reduce(0.0, +), 0.001)
        for index in 0 ..< samples {
            let k = samples > 1 ? CGFloat(index) / CGFloat(samples - 1) : 0.0
            self.fill(shape, at: origin.offsetBy(dx: 0.0, dy: -length * k),
                color: index == 0 ? color : self.secondary,
                alpha: alpha * (index == 0 ? 0.8 : weights[index] / total * 1.4), context: context)
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for (index, piece) in self.title.enumerated() {
            let start = Self.start(x: piece.origin.x, salt: 51 + index)
            let fall = 0.3 + 0.08 * Self.noise(index, 52)
            let u = min((self.time - start) / fall, 1.0)
            guard u > 0.0 else { continue }
            if u >= 1.0 {
                self.fill(piece.shape, at: piece.origin, color: piece.color, context: context)
            } else {
                let path = Self.path(u)
                let drop: CGFloat = 22.0 * 1.1
                let shape = u > 0.72 ? piece.shape : self.random(index, salt: 53, font: piece.font)
                let origin = piece.origin.offsetBy(dx: (piece.width - shape.advance) / 2.0, dy: -drop * CGFloat(1.0 - path.p))
                self.smear(shape, at: origin, font: piece.font, velocity: CGFloat(path.speed) * drop / CGFloat(fall),
                    color: piece.color, alpha: CGFloat(min(u / 0.4, 1.0)), context: context)
            }
        }
        self.drawAddress(context)
        self.drawAvatar(context)
    }

    private func addressTiming(_ column: Int) -> (start: Double, fall: Double) {
        let x = self.address.first?.first(where: { $0.column == column })?.origin.x ?? self.addressFrame.minX
        return (Self.start(x: x, salt: 1, delay: 0.08), 0.36 + 0.1 * Self.noise(column, 2))
    }

    private func drawAddress(_ context: CGContext) {
        let columns = self.address.map { $0.count }.max() ?? 0
        for column in 0 ..< columns {
            let rows = self.address.indices.filter { column < self.address[$0].count && !self.address[$0][column].space }
            guard let last = rows.last else { continue }
            let bottom = self.address[last][column]
            let firstBaseline = self.address.first?.first?.origin.y ?? bottom.origin.y
            let line = self.address.count > 1 ? self.address[1][0].origin.y - firstBaseline : CTFontGetAscent(self.font) + CTFontGetDescent(self.font) + 2.0
            let top = firstBaseline - line
            let timing = self.addressTiming(column)
            let local = self.time - timing.start
            guard local > 0.0 else { continue }
            let u = min(local / timing.fall, 1.0)
            let path = Self.path(u)
            let head = top + (bottom.origin.y - top) * CGFloat(path.p)
            for row in rows where row != last {
                let piece = self.address[row][column]
                guard head >= piece.origin.y else { continue }
                let passed = Self.passTime(Double((piece.origin.y - top) / (bottom.origin.y - top)))
                self.putAddress(row: row, column: column, last: last, settled: local - passed * timing.fall > 0.14, context: context)
            }
            if u < 1.0 {
                let shape = u > 0.72 ? bottom.shape : self.random(column, salt: 7, font: bottom.font)
                let enter = min(max((head - top) / line, 0.0), 1.0)
                self.smear(shape, at: CGPoint(x: bottom.origin.x + (bottom.width - shape.advance) / 2.0, y: head),
                    font: bottom.font, velocity: CGFloat(path.speed) * (bottom.origin.y - top) / CGFloat(timing.fall),
                    color: self.primary.withMultipliedAlpha(0.95), alpha: enter * enter, context: context)
            } else {
                self.putAddress(row: last, column: column, last: last, settled: true, context: context)
            }
        }
    }

    private func putAddress(row: Int, column: Int, last: Int, settled: Bool, context: CGContext) {
        let piece = self.address[row][column]
        if !settled {
            let shape = self.random(column, salt: 11 + row, font: piece.font)
            self.fill(shape, at: piece.origin.offsetBy(dx: (piece.width - shape.advance) / 2.0, dy: 0.0),
                color: self.secondary.withMultipliedAlpha(0.55), context: context)
            return
        }
        if self.loadingAddress {
            self.fill(piece.shape, at: piece.origin, color: piece.color, context: context)
            return
        }
        var from = column, to = column
        while from > 0 && !self.address[row][from - 1].space { from -= 1 }
        while to + 1 < self.address[row].count && !self.address[row][to + 1].space { to += 1 }
        let ready = (from ... to).map { column -> Double in
            let timing = self.addressTiming(column)
            return timing.start + timing.fall + (row == last ? 0.0 : 0.14)
        }.max() ?? 0.0
        let k = CGFloat(Self.smooth((self.time - ready - 0.06) / 0.24))
        var ar: CGFloat = 0.0, ag: CGFloat = 0.0, ab: CGFloat = 0.0, aa: CGFloat = 0.0
        var br: CGFloat = 0.0, bg: CGFloat = 0.0, bb: CGFloat = 0.0, ba: CGFloat = 0.0
        self.secondary.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        piece.color.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let color = UIColor(red: ar + (br - ar) * k, green: ag + (bg - ag) * k,
                            blue: ab + (bb - ab) * k, alpha: aa + (ba - aa) * k)
        self.fill(piece.shape, at: piece.origin, color: color, context: context)
    }

    private var avatarGrid: (columns: Int, rows: Int, cell: CGSize) {
        var zero: UniChar = 48, glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(self.font, &zero, &glyph, 1)
        let columns = max(3, Int(self.avatarFrame.width / max(1.0, self.shape(font: self.font, glyph: glyph).advance)))
        let rows = max(2, Int(self.avatarFrame.height / 10.5))
        return (columns, rows, CGSize(width: self.avatarFrame.width / CGFloat(columns), height: self.avatarFrame.height / CGFloat(rows)))
    }

    private func drawAvatar(_ context: CGContext) {
        guard let image = self.avatarImage else { return }
        let grid = self.avatarGrid
        let cap = CTFontGetCapHeight(self.font)
        func baseline(_ row: Int) -> CGFloat {
            return self.avatarFrame.minY + grid.cell.height * CGFloat(row) + (grid.cell.height + cap) / 2.0
        }
        let top = baseline(0) - grid.cell.height * 1.6
        let bottom = baseline(grid.rows - 1)
        for column in 0 ..< grid.columns {
            let x = self.avatarFrame.minX + grid.cell.width * CGFloat(column)
            let start = Self.start(x: x, salt: 31)
            let fall = 0.3 + 0.08 * Self.noise(column, 32)
            for row in 0 ..< grid.rows {
                let last = row == grid.rows - 1
                let passed = start + Self.passTime(Double((baseline(row) - top) / (bottom - top))) * fall
                let settled = last ? start + fall : passed + 0.14
                let decodeStart = settled + 0.1 + 0.04 * Self.noise(row * 7 + column, 71)
                let k = (self.time - decodeStart) / 0.24
                let id = row * grid.columns + column
                let origin = CGPoint(x: x, y: baseline(row))
                if self.time >= (last ? settled : passed), k < 1.0 / 3.0 {
                    let still = self.time >= settled
                    let shape = self.random(id, salt: still ? 77 : 78, font: self.font, time: still ? 0.0 : nil)
                    self.fill(shape, at: origin.offsetBy(dx: (grid.cell.width - shape.advance) / 2.0, dy: 0.0),
                        color: still ? self.secondary : self.secondary.withMultipliedAlpha(0.55),
                        alpha: CGFloat(k > 0.0 ? 1.0 - k * 3.0 : 1.0), context: context)
                }
                if k > 0.0 {
                    context.saveGState()
                    context.addEllipse(in: self.avatarFrame)
                    context.clip()
                    let rect = CGRect(x: x, y: self.avatarFrame.minY + grid.cell.height * CGFloat(row), width: grid.cell.width, height: grid.cell.height)
                    context.clip(to: rect.insetBy(dx: -0.5, dy: -0.5))
                    context.interpolationQuality = k < 2.0 / 3.0 ? .none : .high
                    let sample = k < 1.0 / 3.0 ? self.coarseAvatar : (k < 2.0 / 3.0 ? self.fineAvatar : image)
                    sample?.draw(in: self.avatarFrame)
                    if k < 1.0 / 3.0 {
                        let shape = self.random(id, salt: 77, font: self.font, time: 0.0)
                        self.fill(shape, at: origin.offsetBy(dx: (grid.cell.width - shape.advance) / 2.0, dy: 0.0),
                            color: .white, alpha: CGFloat(1.0 - k * 3.0), context: context)
                    }
                    context.restoreGState()
                }
            }
            let u = (self.time - start) / fall
            if u > 0.0 && u < 1.0 {
                let path = Self.path(u)
                let y = top + (bottom - top) * CGFloat(path.p)
                let id = (grid.rows - 1) * grid.columns + column
                let shape = u > 0.72 ? self.random(id, salt: 77, font: self.font, time: 0.0) : self.random(column, salt: 79, font: self.font)
                let enter = min(max((y - top) / grid.cell.height, 0.0), 1.0)
                self.smear(shape, at: CGPoint(x: x + (grid.cell.width - shape.advance) / 2.0, y: y), font: self.font,
                    velocity: CGFloat(path.speed) * (bottom - top) / CGFloat(fall), color: self.primary.withMultipliedAlpha(0.95),
                    alpha: enter * enter, context: context)
            }
        }
    }
}

final class WalletSendRecipientComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let peer: EnginePeer?
    let address: String
    let isLoading: Bool
    let openChat: (() -> Void)?
    let copyAddress: () -> Void
    let openInfo: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        nameDisplayOrder: PresentationPersonNameOrder,
        peer: EnginePeer?,
        address: String,
        isLoading: Bool,
        openChat: (() -> Void)?,
        copyAddress: @escaping () -> Void,
        openInfo: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.peer = peer
        self.address = address
        self.isLoading = isLoading
        self.openChat = openChat
        self.copyAddress = copyAddress
        self.openInfo = openInfo
    }

    static func ==(lhs: WalletSendRecipientComponent, rhs: WalletSendRecipientComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.theme === rhs.theme
            && lhs.nameDisplayOrder == rhs.nameDisplayOrder
            && lhs.peer == rhs.peer
            && lhs.address == rhs.address
            && lhs.isLoading == rhs.isLoading
            && (lhs.openChat == nil) == (rhs.openChat == nil)
    }

    final class View: UIView {
        private enum AddressPhase {
            case loading
            case revealing
            case ready
        }

        private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        private static let flipDuration = 0.14
        private static let sweepDuration = 0.4
        private static let settleDuration = 0.546

        private let contentView = UIView()
        private let backgroundView = UIView()
        private var introView: WalletSendRecipientIntroView?
        private var openingTime: Double? = UIAccessibility.isReduceMotionEnabled ? nil : 0.0
        private var renderedAddressTick: Int?
        private var renderedRevealStep: Int?
        private let avatar = ComponentView<Empty>()
        private let tonIconView = UIImageView()
        private let name = ComponentView<Empty>()
        private let username = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let infoButton = ComponentView<Empty>()
        private var component: WalletSendRecipientComponent?
        private var addressPhase: AddressPhase = .ready
        private var animationElapsed: CFTimeInterval = 0
        private var revealElapsed: CFTimeInterval = 0
        private var lastAnimationTimestamp: CFTimeInterval?
        private var animationTimer: Foundation.Timer?
        private var isAnimationVisible = false
        private var applicationIsActive = false
        private let applicationIsActiveDisposable = MetaDisposable()
        private var formattedAddressLines: [String] = []
        private var addressAttributes: [NSAttributedString.Key: Any] = [:]
        private var addressTextWidth: CGFloat = 0
        private var addressSize: CGSize = .zero
        private var renderedAddress: NSAttributedString?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.contentView.clipsToBounds = true
            self.addSubview(self.contentView)
            self.backgroundView.isUserInteractionEnabled = false
            self.contentView.addSubview(self.backgroundView)

            self.tonIconView.image = UIImage(bundleImageName: "Wallet/Ton")
            self.tonIconView.contentMode = .scaleAspectFill
            self.tonIconView.clipsToBounds = true
            self.tonIconView.isUserInteractionEnabled = false
            self.tonIconView.accessibilityElementsHidden = true
            self.contentView.addSubview(self.tonIconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.animationTimer?.invalidate()
            self.applicationIsActiveDisposable.dispose()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            self.updateAnimationActivity()
        }

        func setAnimationVisible(_ isVisible: Bool) {
            guard self.isAnimationVisible != isVisible else { return }
            self.isAnimationVisible = isVisible
            self.updateAnimationActivity()
        }

        private func advanceAnimation(to timestamp: CFTimeInterval) {
            guard let previousTimestamp = self.lastAnimationTimestamp else { return }
            let delta = max(0.0, timestamp - previousTimestamp)
            self.lastAnimationTimestamp = timestamp
            self.animationElapsed += delta
            if self.addressPhase == .revealing && self.openingTime == nil {
                self.revealElapsed += delta
                if self.revealElapsed >= Self.settleDuration {
                    self.addressPhase = .ready
                }
            }
        }

        private func updateAnimationActivity() {
            let timestamp = CACurrentMediaTime()
            self.advanceAnimation(to: timestamp)
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            if reduceMotion {
                if self.addressPhase == .revealing { self.addressPhase = .ready }
                self.openingTime = nil
                self.refreshOpeningContents()
            }
            self.updateAddressText()

            let shouldAnimate = self.component != nil && self.addressPhase != .ready
                && self.isAnimationVisible && self.window != nil && self.applicationIsActive && !reduceMotion && self.openingTime == nil
            if shouldAnimate {
                if self.animationTimer == nil {
                    self.lastAnimationTimestamp = timestamp
                    let timer = Foundation.Timer(timeInterval: 0.035, repeats: true, block: { [weak self] _ in
                        self?.updateAnimationActivity()
                    })
                    self.animationTimer = timer
                    RunLoop.main.add(timer, forMode: .common)
                }
            } else {
                self.animationTimer?.invalidate()
                self.animationTimer = nil
                self.lastAnimationTimestamp = self.openingTime != nil && self.isAnimationVisible && self.window != nil ? timestamp : nil
            }
        }

        func updateOpening(time: Double?) {
            self.advanceAnimation(to: CACurrentMediaTime())
            self.openingTime = UIAccessibility.isReduceMotionEnabled ? nil : time
            self.updateAnimationActivity()
            self.refreshOpeningContents()
        }

        private func refreshOpeningContents() {
            guard let component = self.component else { return }
            let active = self.openingTime != nil && !UIAccessibility.isReduceMotionEnabled
            if active {
                let intro: WalletSendRecipientIntroView
                if let current = self.introView {
                    intro = current
                } else {
                    intro = WalletSendRecipientIntroView(frame: self.contentView.bounds)
                    self.introView = intro
                    self.contentView.addSubview(intro)
                }
                intro.frame = self.contentView.bounds
                let titleViews = [self.name.view, component.peer?.addressName?.isEmpty == false ? self.username.view : nil].compactMap { $0 as? TextView }
                intro.updateTitle(titleViews, frames: titleViews.map { $0.frame },
                    primary: component.theme.list.itemPrimaryTextColor, secondary: component.theme.list.itemSecondaryTextColor)
                if let addressView = self.address.view as? PlainButtonComponent.View,
                   let textView = addressView.contentView as? TextView {
                    intro.updateAddress(textView, frame: textView.convert(textView.bounds, to: self.contentView), loading: self.addressPhase != .ready)
                }
                if component.peer != nil, let avatarView = self.avatar.view as? PlainButtonComponent.View, let imageView = avatarView.contentView {
                    intro.updateAvatar(imageView, frame: avatarView.frame)
                } else if component.peer == nil {
                    intro.updateAvatar(self.tonIconView, frame: self.tonIconView.frame)
                }
                let t = self.openingTime ?? 0.0
                intro.update(time: t)
                let omega = 2.0 * Double.pi / 0.52
                let wd = omega * sqrt(1.0 - 0.36 * 0.36)
                let k = exp(-0.36 * omega * t) * (cos(wd * t) + 0.36 * omega / wd * sin(wd * t))
                self.contentView.transform = CGAffineTransform(translationX: 0.0, y: CGFloat(26.0 * k))
                    .scaledBy(x: CGFloat(1.0 - 0.07 * k), y: CGFloat(1.0 - 0.07 * k))
            } else {
                self.introView?.removeFromSuperview()
                self.introView = nil
                self.contentView.transform = .identity
            }
            self.name.view?.alpha = active ? 0.0 : 1.0
            self.username.view?.alpha = active || component.peer?.addressName?.isEmpty != false ? 0.0 : 1.0
            (self.address.view as? PlainButtonComponent.View)?.contentView?.alpha = active ? 0.0 : 1.0
            (self.avatar.view as? PlainButtonComponent.View)?.contentView?.alpha = active ? 0.0 : 1.0
            self.tonIconView.alpha = active || component.peer != nil ? 0.0 : 1.0
        }

        private func updateAddressText(force: Bool = false) {
            guard let component = self.component else { return }
            let total = self.formattedAddressLines.reduce(0) { $0 + $1.count }
            let tick = self.addressPhase == .ready ? -1 : Int(self.animationElapsed / Self.flipDuration)
            let revealStep = self.addressPhase == .revealing ? Int(self.revealElapsed / Self.sweepDuration * Double(max(total - 1, 1))) : -1
            guard force || self.renderedAddress == nil || tick != self.renderedAddressTick || revealStep != self.renderedRevealStep else { return }
            self.renderedAddressTick = tick
            self.renderedRevealStep = revealStep
            let attributedAddress = NSMutableAttributedString()
            var place = 0
            for (row, line) in self.formattedAddressLines.enumerated() {
                if row != 0 {
                    attributedAddress.append(NSAttributedString(string: "\n", attributes: self.addressAttributes))
                }
                for (column, group) in line.split(separator: " ").enumerated() {
                    if column != 0 {
                        attributedAddress.append(NSAttributedString(string: " ", attributes: self.addressAttributes))
                        place += 1
                    }
                    let color = (row + column).isMultiple(of: 2)
                        ? component.theme.list.itemPrimaryTextColor
                        : component.theme.list.itemSecondaryTextColor
                    for character in group {
                        let settled = self.addressPhase == .ready || (self.addressPhase == .revealing
                            && self.revealElapsed >= Self.sweepDuration * Double(place) / Double(max(total - 1, 1)))
                        var attributes = self.addressAttributes
                        attributes[.foregroundColor] = settled ? color : color.withMultipliedAlpha(0.35)
                        let displayedCharacter: Character
                        if settled {
                            displayedCharacter = character
                        } else {
                            let hash = (place &* 2_654_435_761) ^ (tick &* 40_503)
                            displayedCharacter = Self.alphabet[(hash & 0x7fff_ffff) % Self.alphabet.count]
                        }
                        attributedAddress.append(NSAttributedString(string: String(displayedCharacter), attributes: attributes))
                        place += 1
                    }
                }
            }
            guard force || self.renderedAddress?.isEqual(to: attributedAddress) != true else { return }
            self.renderedAddress = attributedAddress

            self.addressSize = self.address.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(attributedAddress),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    action: { [weak self] in self?.component?.copyAddress() },
                    isEnabled: !component.isLoading && !component.address.isEmpty,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: self.addressTextWidth, height: .greatestFiniteMagnitude)
            )
            if let addressView = self.address.view as? PlainButtonComponent.View {
                addressView.isAccessibilityElement = !component.isLoading && !component.address.isEmpty
                addressView.accessibilityLabel = component.address
                addressView.contentView?.accessibilityElementsHidden = true
            }
            self.refreshOpeningContents()
        }

        private static func addressLines(_ address: String, groupsPerLine: Int) -> [String] {
            var lines: [String] = []
            var groups: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                groups.append(String(address[index ..< endIndex]))
                index = endIndex
                if groups.count == groupsPerLine {
                    lines.append(groups.joined(separator: " "))
                    groups.removeAll(keepingCapacity: true)
                }
            }
            if !groups.isEmpty {
                lines.append(groups.joined(separator: " "))
            }
            return lines
        }

        func update(component: WalletSendRecipientComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.advanceAnimation(to: CACurrentMediaTime())
            let contextChanged = self.component?.context !== component.context
            if self.component?.peer?.id != component.peer?.id {
                self.introView?.removeFromSuperview()
                self.introView = nil
            }
            if contextChanged {
                self.applicationIsActive = false
            }
            let hasPeer = component.peer != nil
            let displaysPlaceholder = hasPeer && (component.isLoading || component.address.isEmpty)
            if self.component?.peer?.id != component.peer?.id || self.component?.address != component.address || self.component?.isLoading != component.isLoading {
                let continuesLoading = self.component?.peer?.id == component.peer?.id
                    && self.addressPhase == .loading
                if !continuesLoading {
                    self.animationElapsed = 0
                }
                self.revealElapsed = 0
                if displaysPlaceholder {
                    self.addressPhase = .loading
                } else if hasPeer && continuesLoading && self.openingTime == nil {
                    self.addressPhase = .revealing
                } else {
                    self.addressPhase = .ready
                }
            }
            self.component = component
            if UIAccessibility.isReduceMotionEnabled && self.addressPhase == .revealing {
                self.addressPhase = .ready
            }
            let canOpenInfo = !component.isLoading && !component.address.isEmpty
            let textOriginX: CGFloat = 60.0
            let textWidth = max(1.0, availableSize.width - textOriginX - 42.0)
            let addressFont = Font.monospace(14.0)
            let addressKerning = ("0" as NSString).size(withAttributes: [.font: addressFont]).width * 0.08
            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: addressFont,
                .foregroundColor: component.theme.list.itemSecondaryTextColor,
                .kern: addressKerning
            ]
            var groupsPerLine = 6
            while groupsPerLine > 1 {
                let sample = Array(repeating: "0000", count: groupsPerLine).joined(separator: " ")
                if ceil((sample as NSString).size(withAttributes: addressAttributes).width) <= textWidth {
                    break
                }
                groupsPerLine -= 1
            }

            let addressText = displaysPlaceholder ? String(repeating: "0", count: 48) : (component.address.isEmpty ? "—" : component.address)
            self.formattedAddressLines = Self.addressLines(addressText, groupsPerLine: groupsPerLine)
            self.addressAttributes = addressAttributes
            self.addressTextWidth = textWidth
            self.updateAddressText(force: true)
            let addressSize = self.addressSize

            let avatarSize = CGSize(width: 36.0, height: 36.0)
            var nameSize: CGSize = .zero
            var usernameSize: CGSize = .zero
            var usernameText: String?
            if let peer = component.peer {
                let _ = self.avatar.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(AvatarComponent(context: component.context, theme: component.theme, peer: peer, size: avatarSize)),
                        action: { component.openChat?() },
                        isEnabled: component.openChat != nil,
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: avatarSize
                )
                if let addressName = peer.addressName, !addressName.isEmpty {
                    usernameText = "@\(addressName)"
                    usernameSize = self.username.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "@\(addressName)",
                                font: Font.regular(14.0),
                                textColor: component.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        environment: {},
                        containerSize: CGSize(width: floor(textWidth * 0.45), height: 30.0)
                    )
                }
            }
            nameSize = self.name.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.peer?.displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder) ?? component.strings.Wallet_Recipient_GramWallet,
                        font: Font.semibold(16.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, textWidth - usernameSize.width - (usernameText == nil ? 0.0 : 6.0)), height: 30.0)
            )
            let infoButtonSize = self.infoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/AddressInfo",
                        tintColor: component.theme.list.itemAccentColor,
                        maxSize: CGSize(width: 24.0, height: 24.0)
                    )),
                    minSize: CGSize(width: 44.0, height: 44.0),
                    action: component.openInfo,
                    isEnabled: canOpenInfo
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )

            let titleHeight = max(19.0, max(nameSize.height, usernameSize.height))
            let titleSpacing: CGFloat = 2.0
            let textHeight = titleHeight + titleSpacing + addressSize.height
            let size = CGSize(width: availableSize.width, height: max(68.0, textHeight + 12.0))
            let textOriginY = floorToScreenPixels((size.height - textHeight) / 2.0) + 1.0
            let addressFrame = CGRect(x: textOriginX, y: textOriginY + titleHeight + titleSpacing, width: addressSize.width, height: addressSize.height)

            self.contentView.bounds = CGRect(origin: .zero, size: size)
            self.contentView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.contentView.layer.cornerRadius = size.height / 2.0
            self.backgroundView.backgroundColor = component.theme.list.itemInputField.backgroundColor
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setCornerRadius(layer: self.backgroundView.layer, cornerRadius: size.height / 2.0)

            let avatarFrame = CGRect(x: 16.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0), width: avatarSize.width, height: avatarSize.height)
            transition.setFrame(view: self.tonIconView, frame: avatarFrame)
            self.tonIconView.layer.cornerRadius = avatarSize.width / 2.0
            transition.setAlpha(view: self.tonIconView, alpha: hasPeer ? 0.0 : 1.0)

            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.contentView.addSubview(avatarView)
                }
                avatarView.isUserInteractionEnabled = hasPeer && component.openChat != nil
                avatarView.isAccessibilityElement = hasPeer && component.openChat != nil
                avatarView.accessibilityLabel = component.peer?.displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder)
                transition.setFrame(view: avatarView, frame: avatarFrame)
                transition.setAlpha(view: avatarView, alpha: hasPeer ? 1.0 : 0.0)
            }
            if let nameView = self.name.view {
                if nameView.superview == nil {
                    nameView.isUserInteractionEnabled = false
                    self.contentView.addSubview(nameView)
                }
                transition.setFrame(view: nameView, frame: CGRect(x: textOriginX, y: textOriginY - 1.0, width: nameSize.width, height: nameSize.height))
            }
            if let usernameView = self.username.view {
                if usernameView.superview == nil {
                    usernameView.isUserInteractionEnabled = false
                    self.contentView.addSubview(usernameView)
                }
                usernameView.isAccessibilityElement = usernameText != nil
                usernameView.accessibilityLabel = usernameText
                let baselineOffset = floorToScreenPixels(Font.semibold(16.0).ascender) - floorToScreenPixels(Font.regular(14.0).ascender)
                transition.setFrame(view: usernameView, frame: CGRect(x: textOriginX + nameSize.width + 6.0, y: textOriginY + baselineOffset - 1.0, width: usernameSize.width, height: usernameSize.height))
                transition.setAlpha(view: usernameView, alpha: usernameText == nil ? 0.0 : 1.0)
            }
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.contentView.addSubview(addressView)
                }
                addressView.isUserInteractionEnabled = canOpenInfo
                transition.setFrame(view: addressView, frame: addressFrame)
            }
            if let infoButtonView = self.infoButton.view {
                if infoButtonView.superview == nil {
                    self.contentView.addSubview(infoButtonView)
                }
                infoButtonView.isUserInteractionEnabled = canOpenInfo
                transition.setFrame(view: infoButtonView, frame: CGRect(x: size.width - 6.0 - infoButtonSize.width, y: floorToScreenPixels((size.height - infoButtonSize.height) / 2.0), width: infoButtonSize.width, height: infoButtonSize.height))
                transition.setAlpha(view: infoButtonView, alpha: 1.0)
            }

            if contextChanged {
                self.applicationIsActiveDisposable.set((component.context.sharedContext.applicationBindings.applicationIsActive
                |> distinctUntilChanged
                |> deliverOnMainQueue).start(next: { [weak self] isActive in
                    guard let self else { return }
                    self.applicationIsActive = isActive
                    self.updateAnimationActivity()
                }))
            }
            self.updateAnimationActivity()
            self.refreshOpeningContents()
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
