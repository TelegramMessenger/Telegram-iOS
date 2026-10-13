import Foundation
import LottieSettings
import UIKit
import CoreText
import Metal
import MetalEngine
import AsyncDisplayKit
import Display
import PremiumDiamondComponent
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TextFormat
import LocalizedPeerData
import TelegramStringFormatting
import WallpaperBackgroundNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatControllerInteraction
import TextSelectionNode
import InvisibleInkDustNode
import WalletContext
import WalletCardComponent

private enum TransferCardStatus: Equatable {
    case waiting
    case pending
    case completed
    case unavailable
}

public enum WalletTransferArrivalAnimation {
    public static let climax = passTime(122.0)
    static let landing = climax - 0.08
    public static let duration = landing + 1.8

    static func passTime(_ x: CGFloat) -> Double {
        let e = min(1.0, max(0.0, (Double(x) + 30.0) / 320.0))
        return 0.05 + 1.1 * (0.5 - sin(asin(1.0 - 2.0 * e) / 3.0))
    }

    static func sheenX(_ time: Double) -> CGFloat? {
        let u = (time - 0.05) / 1.1
        guard u >= 0.0, u <= 1.0 else { return nil }
        return CGFloat(-30.0 + 320.0 * u * u * (3.0 - 2.0 * u))
    }

    static func crossing(_ point: CGPoint) -> CGFloat {
        // Card content is inset four points in the reference's 224 x 156 canvas.
        return point.x + 4.0 + 0.35 * (point.y + 4.0) - 13.7
    }

    static func lift(_ time: Double, at x: CGFloat) -> CGFloat {
        let t = time - passTime(x)
        guard t > 0.0, t < 0.8 else { return 0.0 }
        return CGFloat(sin(2.0 * .pi * 1.7 * t) * exp(-t / 0.2))
    }
}

private final class TransferArrivalTextView: UIView {
    private struct GlyphKey: Hashable {
        let font: String
        let size: CGFloat
        let glyph: CGGlyph
    }
    private struct Shape {
        let path: CGPath
        let advance: CGFloat
        let image: UIImage?
    }
    private struct Glyph {
        let path: CGPath
        let origin: CGPoint
        let color: CGColor
        let kind: Int
        let landing: CGFloat
        let value: Int?
        let column: Int
        let pitch: CGFloat
        let advance: CGFloat
        let digits: [Shape]
        let image: UIImage?
    }
    private static var shapes: [GlyphKey: Shape] = [:]
    private var glyphs: [Glyph] = []
    private var layouts: [(TextNodeLayout, CGRect)] = []
    private var integralCount = 0
    private var time: Double = 0.0
    private let addressGradient: CGGradient
    private let nameGradient: CGGradient

    override init(frame: CGRect) {
        func gradient(color: UIColor, peak: CGFloat) -> CGGradient {
            let alphas: [CGFloat] = [0.0, 0.18, 0.6, 1.0, 0.6, 0.18, 0.0]
            let colors = alphas.map { color.withAlphaComponent($0 * peak).cgColor }
            let locations: [CGFloat] = [0.0, 0.22, 0.4, 0.5, 0.6, 0.78, 1.0]
            return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
        }
        self.addressGradient = gradient(color: UIColor(red: 0.36, green: 0.86, blue: 1.0, alpha: 1.0), peak: 0.9)
        self.nameGradient = gradient(color: .white, peak: 0.25)
        super.init(frame: frame)
        self.isOpaque = false
        self.isUserInteractionEnabled = false
        self.accessibilityElementsHidden = true
        self.contentScaleFactor = UIScreenScale
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func shape(font: CTFont, glyph: CGGlyph) -> Shape {
        let key = GlyphKey(font: CTFontCopyPostScriptName(font) as String, size: CTFontGetSize(font), glyph: glyph)
        if let cached = self.shapes[key] { return cached }
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
                // Keep color-font glyphs (for example an emoji in a peer name).
                let format = UIGraphicsImageRendererFormat()
                format.scale = UIScreenScale
                image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { renderer in
                    let context = renderer.cgContext
                    context.translateBy(x: -bounds.minX, y: bounds.maxY)
                    context.scaleBy(x: 1, y: -1)
                    var position = CGPoint.zero
                    CTFontDrawGlyphs(font, &glyph, &position, 1, context)
                }
                path = CGPath(rect: bounds, transform: nil)
            } else {
                path = CGMutablePath()
            }
        }
        let result = Shape(path: path, advance: advance.width, image: image)
        self.shapes[key] = result
        return result
    }

    func update(nodes: [TextNode]) {
        let layouts = nodes.compactMap { node -> (TextNodeLayout, CGRect)? in
            node.cachedLayout.map { ($0, node.frame) }
        }
        if layouts.count == self.layouts.count && zip(layouts, self.layouts).allSatisfy({ $0.0.0 === $0.1.0 && $0.0.1 == $0.1.1 }) { return }
        self.layouts = layouts
        self.glyphs.removeAll(keepingCapacity: true)
        self.integralCount = 0
        var column = 0
        for (kind, entry) in layouts.enumerated() {
            let (layout, frame) = entry
            let string = (layout.attributedString?.string ?? "") as NSString
            layout.enumerateRenderedLines(in: CGRect(origin: .zero, size: frame.size)) { line, baseline in
                for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                    let attributes = CTRunGetAttributes(run) as NSDictionary
                    let font = attributes[kCTFontAttributeName] as! CTFont
                    let count = CTRunGetGlyphCount(run)
                    var glyphs = [CGGlyph](repeating: 0, count: count)
                    var positions = [CGPoint](repeating: .zero, count: count)
                    var indices = [CFIndex](repeating: 0, count: count)
                    CTRunGetGlyphs(run, CFRange(), &glyphs)
                    CTRunGetPositions(run, CFRange(), &positions)
                    CTRunGetStringIndices(run, CFRange(), &indices)
                    for i in 0 ..< count {
                        let shape = Self.shape(font: font, glyph: glyphs[i])
                        guard !shape.path.isEmpty else { continue }
                        let origin = CGPoint(x: frame.minX + baseline.x + positions[i].x, y: frame.minY + baseline.y - positions[i].y)
                        var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: origin.x, ty: origin.y)
                        guard let path = shape.path.copy(using: &transform) else { continue }
                        let index = indices[i]
                        var value: Int?
                        var digits: [Shape] = []
                        let color = (attributes[NSAttributedString.Key.foregroundColor.rawValue] as? UIColor)
                            ?? (index >= 0 && index < string.length ? layout.attributedString?.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor : nil)
                            ?? .white
                        if kind == 0, index >= 0, index < string.length {
                            let character = string.substring(with: string.rangeOfComposedCharacterSequence(at: index)).first
                            if let number = character?.wholeNumberValue, number < 10 {
                                // Verify the shaped glyph: a truncation token may reuse a string index.
                                var code = string.character(at: index)
                                var expected: CGGlyph = 0
                                if CTFontGetGlyphsForCharacters(font, &code, &expected, 1), expected == glyphs[i] {
                                    value = number
                                    for digit in 0 ..< 10 {
                                        var digitCode = UniChar(Int(code) - number + digit)
                                        var digitGlyph: CGGlyph = 0
                                        CTFontGetGlyphsForCharacters(font, &digitCode, &digitGlyph, 1)
                                        digits.append(Self.shape(font: font, glyph: digitGlyph))
                                    }
                                }
                            }
                        }
                        let isIntegral = CTFontGetSize(font) >= 17.0
                        if value != nil && isIntegral { self.integralCount += 1 }
                        let midpoint = CGPoint(x: path.boundingBoxOfPath.midX, y: path.boundingBoxOfPath.midY)
                        self.glyphs.append(Glyph(path: path, origin: origin, color: color.cgColor, kind: kind,
                            landing: WalletTransferArrivalAnimation.crossing(midpoint), value: value, column: column,
                            pitch: isIntegral ? 17.0 : 13.2, advance: shape.advance, digits: digits, image: shape.image))
                        if value != nil { column += 1 }
                    }
                }
            }
        }
        self.setNeedsDisplay()
    }

    func update(time: Double) {
        self.time = time
        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let namePath = CGMutablePath()
        let addressPath = CGMutablePath()
        for glyph in self.glyphs {
            let landing = WalletTransferArrivalAnimation.passTime(glyph.landing)
            func progress(_ back: Double) -> Double {
                return min(1.0, max(0.0, (self.time - back - 0.02) / max(landing - 0.02, 0.05)))
            }
            if let value = glyph.value, progress(0) < 0.999 {
                let distance = Double(value + 10 * min(glyph.column, 2))
                func position(_ back: Double) -> Double { distance * (1.0 - pow(1.0 - progress(back), 1.7)) }
                let now = position(0.0)
                let was = position(1.0 / 60.0)
                let travel = CGFloat(abs(now - was)) * glyph.pitch
                let samples = travel > 1.0 ? min(2 + Int(travel), 14) : 1
                let weights = (0 ..< samples).map { index -> CGFloat in
                    guard samples > 1 else { return 1.0 }
                    let q = CGFloat(index) / CGFloat(samples - 1) * 2.0 - 1.0
                    return 1.0 - 0.55 * q * q
                }
                let total = weights.reduce(0, +)
                let low = Int(floor(min(now, was))) - 1
                let high = Int(ceil(max(now, was))) + 1
                for n in low ... high {
                    let digit = ((n % 10) + 10) % 10
                    if digit == 0 && glyph.column == 0 && self.integralCount > 1 && value != 0 { continue }
                    let shape = glyph.digits[digit]
                    for sample in 0 ..< samples {
                        let q = samples > 1 ? Double(sample) / Double(samples - 1) : 1.0
                        let dy = CGFloat(was + (now - was) * q - Double(n)) * glyph.pitch
                        let edge = abs(dy) / (glyph.pitch * 0.58)
                        let alpha = (edge >= 1 ? 0 : 1 - pow(edge, 2.2)) * weights[sample] / total
                        guard alpha > 0.006 else { continue }
                        context.saveGState()
                        context.translateBy(x: glyph.origin.x + (glyph.advance - shape.advance) * 0.5, y: glyph.origin.y - dy)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.setAlpha(alpha)
                        context.setFillColor(glyph.color)
                        context.addPath(shape.path)
                        context.fillPath()
                        context.restoreGState()
                    }
                }
                continue
            }
            let lift = WalletTransferArrivalAnimation.lift(self.time, at: glyph.landing)
            let bounds = glyph.path.boundingBoxOfPath
            let scale = 1.0 + (glyph.kind == 0 ? 0.1 : 0.08) * lift
            var transform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY - (glyph.kind == 0 ? 1.2 : 0.9) * lift)
                .scaledBy(x: scale, y: scale).translatedBy(x: -bounds.midX, y: -bounds.midY)
            if let image = glyph.image {
                context.saveGState()
                context.concatenate(transform)
                image.draw(in: bounds)
                context.restoreGState()
                continue
            }
            guard let path = glyph.path.copy(using: &transform) else { continue }
            if glyph.kind == 2 {
                context.saveGState()
                context.translateBy(x: 0, y: 1)
                context.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
                context.addPath(path)
                context.fillPath()
                context.restoreGState()
                addressPath.addPath(path)
            } else if glyph.kind == 1 {
                namePath.addPath(path)
            }
            context.setFillColor(glyph.color)
            context.addPath(path)
            context.fillPath()
        }
        if let x = WalletTransferArrivalAnimation.sheenX(self.time) {
            for (path, gradient) in [(addressPath, self.addressGradient), (namePath, self.nameGradient)] {
                context.saveGState()
                context.addPath(path)
                context.clip()
                if path === namePath { context.setBlendMode(.plusLighter) }
                context.drawLinearGradient(gradient, start: CGPoint(x: x - 112 - 4, y: -4), end: CGPoint(x: x + 112 - 4, y: 112 * 0.7 - 4), options: [])
                context.restoreGState()
            }
        }
    }
}

private struct TransferCardWalletState: Equatable {
    let status: TransferCardStatus
    let operationId: String?
    let transactionHash: Data?
}

private enum TransferCardRibbonGeometry {
    private static let imageSize = CGSize(width: 54.800781, height: 54.800766)
    static let size = imageSize
    static let center = CGPoint(x: 33.057275 * size.width / imageSize.width, y: 21.743515 * size.height / imageSize.height)

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 50.114521, y: 24.658621))
        path.addLine(to: CGPoint(x: 30.142169, y: 4.686269))
        path.addCurve(to: CGPoint(x: 26.538727, y: 1.473573), control1: CGPoint(x: 28.412651, y: 2.956751), control2: CGPoint(x: 27.547891, y: 2.091991))
        path.addCurve(to: CGPoint(x: 23.648195, y: 0.276273), control1: CGPoint(x: 25.643999, y: 0.925288), control2: CGPoint(x: 24.668556, y: 0.521241))
        path.addCurve(to: CGPoint(x: 18.828456, y: 0.0), control1: CGPoint(x: 22.497317, y: 0.0), control2: CGPoint(x: 21.274368, y: 0.0))
        path.addLine(to: CGPoint(x: 4.897057, y: 0.0))
        path.addCurve(to: CGPoint(x: 0.701126, y: 0.479164), control1: CGPoint(x: 2.473808, y: 0.0), control2: CGPoint(x: 1.262181, y: 0.0))
        path.addCurve(to: CGPoint(x: 0.006188, y: 2.156895), control1: CGPoint(x: 0.214309, y: 0.894945), control2: CGPoint(x: -0.044041, y: 1.518656))
        path.addCurve(to: CGPoint(x: 2.634339, y: 5.462719), control1: CGPoint(x: 0.064078, y: 2.892458), control2: CGPoint(x: 0.920832, y: 3.749212))
        path.addLine(to: CGPoint(x: 49.338070, y: 52.166450))
        path.addCurve(to: CGPoint(x: 52.643895, y: 54.794601), control1: CGPoint(x: 51.051577, y: 53.879956), control2: CGPoint(x: 51.908330, y: 54.736710))
        path.addCurve(to: CGPoint(x: 54.321625, y: 54.099662), control1: CGPoint(x: 53.282136, y: 54.844833), control2: CGPoint(x: 53.905845, y: 54.586481))
        path.addCurve(to: CGPoint(x: 54.800818, y: 49.903712), control1: CGPoint(x: 54.800810, y: 53.538617), control2: CGPoint(x: 54.800810, y: 52.326999))
        path.addLine(to: CGPoint(x: 54.800816, y: 35.972328))
        path.addCurve(to: CGPoint(x: 54.524518, y: 31.152596), control1: CGPoint(x: 54.800816, y: 33.526424), control2: CGPoint(x: 54.800813, y: 32.303474))
        path.addCurve(to: CGPoint(x: 53.327218, y: 28.262064), control1: CGPoint(x: 54.279548, y: 30.132233), control2: CGPoint(x: 53.875502, y: 29.156791))
        path.addCurve(to: CGPoint(x: 50.114521, y: 24.658621), control1: CGPoint(x: 52.708799, y: 27.252899), control2: CGPoint(x: 51.844040, y: 26.388140))
        path.closeSubpath()
        var transform = CGAffineTransform(scaleX: size.width / imageSize.width, y: size.height / imageSize.height)
        return path.copy(using: &transform) ?? path
    }()

    static func compactPath(center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let radius: CGFloat = 7.0
        func point(_ angle: CGFloat) -> CGPoint {
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }

        let angles: [CGFloat] = [-.pi / 4.0, -.pi / 2.0, -.pi * 5.0 / 4.0, -.pi * 2.0, -.pi * 9.0 / 4.0]
        path.move(to: point(angles[0]))
        for corner in 0 ..< 4 {
            let startAngle = angles[corner]
            let step = (angles[corner + 1] - startAngle) / 3.0
            let controlLength = 4.0 / 3.0 * tan(step / 4.0) * radius
            path.addLine(to: point(startAngle))
            for segment in 0 ..< 3 {
                let angle = startAngle + CGFloat(segment) * step
                let nextAngle = angle + step
                let start = point(angle)
                let end = point(nextAngle)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x - sin(angle) * controlLength, y: start.y + cos(angle) * controlLength),
                    control2: CGPoint(x: end.x + sin(nextAngle) * controlLength, y: end.y - cos(nextAngle) * controlLength)
                )
            }
        }
        path.closeSubpath()
        return path
    }
}

private func transferCardTransactionHash(_ value: String?) -> Data? {
    guard let value else {
        return nil
    }
    let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    if parts.count == 2 && UInt64(parts[0]) == nil {
        return nil
    }
    guard let hash = parts.last.flatMap({ Data(base64Encoded: String($0)) }), hash.count == 32 else {
        return nil
    }
    return hash
}

private func transferCardWalletState(_ state: WalletContext.State, operationId: String?, transactionHash: Data?) -> TransferCardWalletState? {
    if let transaction = state.transactions.items.first(where: { transaction in
        guard transaction.direction == .outgoing, transaction.collectible == nil, transaction.kind == .transfer else {
            return false
        }
        return operationId.map { transaction.presentationId == "pending:\($0)" } == true
            || (transactionHash != nil && transferCardTransactionHash(transaction.transactionHash ?? transaction.id) == transactionHash)
    }) {
        let status: TransferCardStatus
        switch transaction.status {
        case .pending:
            status = .pending
        case .completed:
            status = .completed
        case .failed:
            status = .unavailable
        }
        return TransferCardWalletState(
            status: status,
            operationId: operationId ?? (transaction.presentationId.hasPrefix("pending:") ? String(transaction.presentationId.dropFirst("pending:".count)) : nil),
            transactionHash: transferCardTransactionHash(transaction.transactionHash ?? transaction.id) ?? transactionHash
        )
    }
    if let pending = state.pendingTransfers.first(where: { pending in
        pending.collectibleAddress == nil && (pending.id == operationId
            || (transactionHash != nil && transferCardTransactionHash(pending.transactionHash) == transactionHash))
    }) {
        let status: TransferCardStatus
        switch pending.status {
        case .broadcasting:
            status = .waiting
        case .pending, .submissionUnknown:
            status = .pending
        case .confirmed:
            status = .completed
        }
        return TransferCardWalletState(status: status, operationId: pending.id, transactionHash: transferCardTransactionHash(pending.transactionHash) ?? transactionHash)
    }
    return nil
}

private final class TransferCardShimmerView: UIView {
    let repeatAnimation: Bool
    let followsArrival: Bool
    var completion: (() -> Void)?

    private let surfaceLayer = SimpleGradientLayer()
    private let borderGlowLayer = SimpleGradientLayer()
    private let borderLayer = SimpleGradientLayer()
    private let borderGlowMask = SimpleShapeLayer()
    private let borderMask = SimpleShapeLayer()
    private let addressView = UIView()
    private let addressLayer = SimpleGradientLayer()
    private var currentLayout: (size: CGSize, addressFrame: CGRect)?
    private var animationStartTime: CFTimeInterval?

    init(addressMask: UIView, repeatAnimation: Bool, followsArrival: Bool = false) {
        self.repeatAnimation = repeatAnimation
        self.followsArrival = followsArrival

        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.cornerRadius = 20.0

        for (mask, width) in [(self.borderGlowMask, CGFloat(4.5)), (self.borderMask, CGFloat(1.3))] {
            mask.fillColor = UIColor.clear.cgColor
            mask.strokeColor = UIColor.white.cgColor
            mask.lineWidth = width
            mask.contentsScale = UIScreenScale
        }
        self.borderGlowLayer.mask = self.borderGlowMask
        self.borderLayer.mask = self.borderMask
        self.addressView.mask = addressMask
        self.addressView.layer.addSublayer(self.addressLayer)

        for (layer, color, peak) in [
            (self.surfaceLayer, UIColor.white, CGFloat(0.07)),
            (self.borderGlowLayer, UIColor.white, CGFloat(0.28)),
            (self.borderLayer, UIColor.white, CGFloat(0.55)),
            (self.addressLayer, UIColor(red: 0.36, green: 0.86, blue: 1.0, alpha: 1.0), CGFloat(0.9))
        ] {
            layer.colors = [CGFloat(0.0), 0.18, 0.6, 1.0, 0.6, 0.18, 0.0].map {
                color.withAlphaComponent(peak * $0).cgColor
            }
            layer.locations = [0.0, 0.22, 0.4, 0.5, 0.6, 0.78, 1.0]
            layer.opacity = 0.0
        }
        for layer in [self.surfaceLayer, self.borderGlowLayer, self.borderLayer] {
            self.layer.addSublayer(layer)
        }
        self.addSubview(self.addressView)
        self.addressView.isHidden = followsArrival
        self.surfaceLayer.compositingFilter = "screenBlendMode"
        self.borderGlowLayer.compositingFilter = "plusL"
        self.borderLayer.compositingFilter = "plusL"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, addressFrame: CGRect) {
        guard size.width > 0.0, size.height > 0.0 else { return }
        if let currentLayout = self.currentLayout, currentLayout.size == size, currentLayout.addressFrame == addressFrame {
            return
        }
        self.currentLayout = (size, addressFrame)
        if self.animationStartTime == nil {
            self.animationStartTime = CACurrentMediaTime() + 0.15
        }

        let bounds = CGRect(origin: .zero, size: size)
        self.frame = bounds
        for layer in [self.surfaceLayer, self.borderGlowLayer, self.borderLayer] {
            layer.frame = bounds
        }
        for mask in [self.borderGlowMask, self.borderMask] {
            mask.frame = bounds
            mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: 20.0).cgPath
        }
        self.addressView.frame = bounds
        self.addressView.mask?.frame = addressFrame
        self.addressLayer.frame = bounds

        if self.followsArrival { return }

        for (layer, width, frame) in [
            (self.surfaceLayer, CGFloat(160.0), bounds),
            (self.borderGlowLayer, CGFloat(128.0), bounds),
            (self.borderLayer, CGFloat(112.0), bounds),
            (self.addressLayer, CGFloat(112.0), bounds)
        ] {
            self.animateBand(layer, width: width, frame: frame, cardWidth: size.width + 8.0)
        }
    }

    func updateArrival(time: Double) {
        guard self.followsArrival, self.bounds.width > 0, self.bounds.height > 0 else { return }
        let x = WalletTransferArrivalAnimation.sheenX(time)
        for (layer, width) in [(self.surfaceLayer, CGFloat(160)), (self.borderGlowLayer, CGFloat(128)), (self.borderLayer, CGFloat(112))] {
            layer.opacity = x == nil ? 0 : 1
            if let x {
                layer.startPoint = CGPoint(x: (x - width - 4) / self.bounds.width, y: -4 / self.bounds.height)
                layer.endPoint = CGPoint(x: (x + width - 4) / self.bounds.width, y: (width * 0.7 - 4) / self.bounds.height)
            }
        }
    }

    private func animateBand(_ layer: SimpleGradientLayer, width: CGFloat, frame: CGRect, cardWidth: CGFloat) {
        guard frame.width > 0.0, frame.height > 0.0, let animationStartTime = self.animationStartTime else { return }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: (x - 4.0 - frame.minX) / frame.width, y: (y - 4.0 - frame.minY) / frame.height)
        }
        let fromX = -0.6 * cardWidth
        let toX = 1.6 * cardWidth
        let duration = 1.46
        let passFraction = 0.96 / duration
        let ease = CAMediaTimingFunction(controlPoints: 1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        var animations: [CAAnimation] = []
        for (keyPath, from, to) in [
            ("startPoint", point(fromX - width, 0.0), point(toX - width, 0.0)),
            ("endPoint", point(fromX + width, width * 0.7), point(toX + width, width * 0.7))
        ] {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = [NSValue(cgPoint: from), NSValue(cgPoint: to), NSValue(cgPoint: to)]
            animation.keyTimes = [0.0, NSNumber(value: passFraction), 1.0]
            animation.timingFunctions = [ease, CAMediaTimingFunction(name: .linear)]
            animation.duration = duration
            animations.append(animation)
        }
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.0, 0.0]
        opacity.keyTimes = [0.0, NSNumber(value: passFraction), 1.0]
        opacity.calculationMode = .discrete
        opacity.duration = duration
        animations.append(opacity)

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.beginTime = layer.convertTime(animationStartTime, from: nil)
        group.repeatCount = self.repeatAnimation ? .infinity : 0.0
        if !self.repeatAnimation, layer === self.surfaceLayer {
            group.completion = { [weak self] finished in
                if finished {
                    self?.completion?()
                }
            }
        }
        layer.add(group, forKey: "shimmer")
    }
}

public final class ChatMessageTransferBubbleContentNode: ChatMessageBubbleContentNode {
    private struct BackgroundRotationAnimation {
        let duration: CFTimeInterval
        let turns: CGFloat
        var start: (time: CFTimeInterval, offset: CGFloat)?
    }

    private let labelNode: TextNode
    private var labelBackgroundNode: WallpaperBubbleBackgroundNode?
    private let labelBackgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?

    private let mediaContainerNode: ASDisplayNode
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let cardNode: ASDisplayNode
    private let cardBackgroundNode: ASImageNode
    private var cardBackgroundRotation: CGFloat = 0.0
    private var cardBackgroundMotion: (rotation: CGFloat, time: CFTimeInterval)?
    private var cardBackgroundDeviceMotion: Disposable?
    private var cardBackgroundRotationAnimation: BackgroundRotationAnimation?
    private var cardIcon: InteractiveDiamondComponent.View?
    private var isAwaitingTransferFlight = false
    private let amountNode: TextNode
    private let nameNode: TextNode
    private let addressNode: TextNode
    private let addressHighlightNode: TextNode
    private let addressShimmerMaskNode: TextNode
    private var shimmerView: TransferCardShimmerView?
    private var isHighlighted = false
    private var isPlayingHighlightShimmer = false
    private let sendingClockNode: ASDisplayNode
    private let clockFrameNode: ASImageNode
    private let clockMinNode: ASImageNode
    private let captionNode: TextNode
    private var captionTextSelectionNode: TextSelectionNode?
    private var captionDustNode: InvisibleInkDustNode?
    private let ribbonBackgroundNode: ASImageNode
    private let ribbonTextNode: TextNode
    private let ribbonTextContainerNode: ASDisplayNode
    private let ribbonTextMaskNode: ASImageNode
    private var ribbonAnimationLayer: SimpleShapeLayer?
    private var ribbonAnimationMaskLayer: SimpleShapeLayer?
    private var ribbonGlintLayer: SimpleGradientLayer?
    private var completionAnimationId = 0
    private var arrivalTextView: TransferArrivalTextView?
    private var arrivalStartTime: CFTimeInterval?
    private var arrivalDidLand = false
    private var arrivalDidGlint = false

    private weak var walletContext: WalletContext?
    private var walletStateDisposable: MetaDisposable?
    private var renderedFiatState: WalletContext.FiatState?
    private var transferOperationId: String?
    private var transferTransactionHash: Data?
    private var transferStatus: TransferCardStatus?
    private var isIncomingTransfer = false

    #if DEBUG
    private var debugTransferStatus: TransferCardStatus?
    #endif

    private var displayedTransferStatus: TransferCardStatus? {
        #if DEBUG
        if let debugTransferStatus = self.debugTransferStatus {
            return debugTransferStatus
        }
        #endif
        return self.transferStatus
    }

    private var isSendingTransfer: Bool {
        return !self.isIncomingTransfer && self.displayedTransferStatus != nil && self.displayedTransferStatus != .completed
    }

    private var cachedLabelBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?

    public var scrollTiltProvider: ((CFTimeInterval) -> Float)? {
        didSet {
            self.cardIcon?.scrollTiltProvider = self.scrollTiltProvider
        }
    }

    override public var disablesClipping: Bool {
        return true
    }

    override public func didEnterHierarchy() {
        super.didEnterHierarchy()
        self.updateIncomingTransferVisibility()
        // UIKit may attach the backing view to its window after the node enters hierarchy.
        DispatchQueue.main.async { [weak self] in
            self?.updateIncomingTransferVisibility()
        }
    }

    override public func didExitHierarchy() {
        super.didExitHierarchy()
        self.cancelIncomingTransferAnimation()
    }

    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if (oldValue != .none) != (self.visibility != .none) {
                self.cardIcon?.isRenderingEnabled = self.visibility != .none && !self.isAwaitingTransferFlight
                if self.visibility == .none {
                    self.cancelIncomingTransferAnimation()
                    self.mediaContainerNode.layer.removeAnimation(forKey: "transferFlightLanding")
                    self.stopCardBackgroundMotion()
                    self.finishCompletionAnimation()
                    self.isPlayingHighlightShimmer = false
                }
                self.updateSendingClockAnimation()
                self.updateShimmer(animated: false)
            }
            self.updateIncomingTransferVisibility()
        }
    }

    required public init(lottieSettings: LottieRenderingSettings) {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.labelBackgroundMaskNode = ASImageNode()
        self.labelBackgroundMaskNode.displaysAsynchronously = false

        self.mediaContainerNode = ASDisplayNode()
        self.mediaContainerNode.clipsToBounds = false

        self.cardNode = ASDisplayNode()
        self.cardNode.clipsToBounds = true
        self.cardNode.cornerRadius = 20.0

        self.cardBackgroundNode = ASImageNode()
        self.cardBackgroundNode.isLayerBacked = true
        self.cardBackgroundNode.isUserInteractionEnabled = false
        self.cardBackgroundNode.isOpaque = true
        self.cardBackgroundNode.displaysAsynchronously = false
        self.cardBackgroundNode.displayWithoutProcessing = true
        self.cardBackgroundNode.contentMode = .scaleToFill
        self.cardBackgroundNode.image = UIImage(bundleImageName: "Wallet/CardChatGradient")

        self.amountNode = TextNode()
        self.amountNode.isUserInteractionEnabled = false
        self.amountNode.displaysAsynchronously = false

        self.nameNode = TextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false

        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.displaysAsynchronously = false

        self.addressHighlightNode = TextNode()
        self.addressHighlightNode.isUserInteractionEnabled = false
        self.addressHighlightNode.displaysAsynchronously = false
        self.addressHighlightNode.alpha = 0.06

        self.addressShimmerMaskNode = TextNode()
        self.addressShimmerMaskNode.isUserInteractionEnabled = false
        self.addressShimmerMaskNode.displaysAsynchronously = false

        self.sendingClockNode = ASDisplayNode()
        self.sendingClockNode.isUserInteractionEnabled = false
        self.sendingClockNode.alpha = 0.0

        self.clockFrameNode = ASImageNode()
        self.clockFrameNode.isLayerBacked = true
        self.clockFrameNode.displaysAsynchronously = false
        self.clockFrameNode.displayWithoutProcessing = true

        self.clockMinNode = ASImageNode()
        self.clockMinNode.isLayerBacked = true
        self.clockMinNode.displaysAsynchronously = false
        self.clockMinNode.displayWithoutProcessing = true

        self.captionNode = TextNode()
        self.captionNode.isUserInteractionEnabled = false
        self.captionNode.displaysAsynchronously = false

        self.ribbonBackgroundNode = ASImageNode()
        self.ribbonBackgroundNode.displaysAsynchronously = false
        self.ribbonBackgroundNode.displayWithoutProcessing = true
        self.ribbonBackgroundNode.image = generateTintedImage(
            image: UIImage(bundleImageName: "Wallet/MessageRibbon"),
            color: .white
        )

        self.ribbonTextNode = TextNode()
        self.ribbonTextNode.isUserInteractionEnabled = false
        self.ribbonTextNode.displaysAsynchronously = false

        self.ribbonTextContainerNode = ASDisplayNode()
        self.ribbonTextContainerNode.isUserInteractionEnabled = false
        self.ribbonTextMaskNode = ASImageNode()
        self.ribbonTextMaskNode.displaysAsynchronously = false
        self.ribbonTextMaskNode.displayWithoutProcessing = true
        self.ribbonTextMaskNode.image = UIImage(bundleImageName: "Wallet/MessageRibbon")

        super.init(lottieSettings: lottieSettings)

        self.cardNode.addSubnode(self.cardBackgroundNode)
        self.cardNode.addSubnode(self.amountNode)
        self.cardNode.addSubnode(self.nameNode)
        self.cardNode.addSubnode(self.addressHighlightNode)
        self.cardNode.addSubnode(self.addressNode)
        self.cardNode.addSubnode(self.sendingClockNode)
        self.sendingClockNode.addSubnode(self.clockFrameNode)
        self.sendingClockNode.addSubnode(self.clockMinNode)

        self.addSubnode(self.mediaContainerNode)
        self.mediaContainerNode.addSubnode(self.cardNode)
        self.mediaContainerNode.addSubnode(self.ribbonBackgroundNode)
        self.mediaContainerNode.addSubnode(self.ribbonTextContainerNode)
        self.ribbonTextContainerNode.addSubnode(self.ribbonTextNode)
        self.mediaContainerNode.addSubnode(self.captionNode)
        self.addSubnode(self.labelNode)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.cardBackgroundDeviceMotion?.dispose()
        self.walletStateDisposable?.dispose()
    }

    private func stopCardBackgroundMotion() {
        self.cardBackgroundDeviceMotion?.dispose()
        self.cardBackgroundDeviceMotion = nil
        self.cardBackgroundRotationAnimation = nil
        self.cardBackgroundMotion = nil
    }

    private func updateCardBackgroundRotation(_ state: InteractiveDiamondComponent.MotionState?) {
        guard let state, self.visibility != .none,
              UIApplication.shared.applicationState != .background, !UIAccessibility.isReduceMotionEnabled,
              !self.isAwaitingTransferFlight, let window = self.cardIcon?.window else {
            self.stopCardBackgroundMotion()
            return
        }
        if self.cardBackgroundDeviceMotion == nil {
            self.cardBackgroundDeviceMotion = WalletCardBackgroundMotion.shared.subscribe()
            if self.cardBackgroundRotationAnimation == nil {
                self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 0.22, turns: 0.0)
            }
        }
        let deviceRotation = WalletCardBackgroundMotion.shared.rotation(
            at: CACurrentMediaTime(),
            orientation: window.windowScene?.interfaceOrientation ?? .portrait
        )

        let rotation: CGFloat
        if let transferEnergy = state.transferEnergy,
           (!self.isIncomingTransfer && self.displayedTransferStatus == .pending) || (self.arrivalStartTime != nil && !self.arrivalDidLand) {
            self.cardBackgroundRotationAnimation = nil
            defer {
                self.cardBackgroundMotion = (state.rotation, state.time)
            }
            guard let previous = self.cardBackgroundMotion, state.time >= previous.time else { return }
            let delta = state.rotation - previous.rotation
            let energy = min(1.0, max(0.0, transferEnergy))
            let step = atan2(sin(delta), cos(delta)) * 2.0 * (1.0 - 0.5 * energy)
                + 0.12 * CGFloat(state.time - previous.time)
            rotation = self.cardBackgroundRotation + step
        } else {
            self.cardBackgroundMotion = nil
            if var animation = self.cardBackgroundRotationAnimation {
                let start: (time: CFTimeInterval, offset: CGFloat)
                if let current = animation.start {
                    start = current
                } else {
                    let delta = self.cardBackgroundRotation - deviceRotation
                    start = (state.time, atan2(sin(delta), cos(delta)) - animation.turns * 2.0 * .pi)
                    animation.start = start
                }
                let progress = CGFloat(min(1.0, max(0.0, (state.time - start.time) / animation.duration)))
                let remaining = 1.0 - progress
                rotation = deviceRotation + start.offset * remaining * remaining * remaining
                self.cardBackgroundRotationAnimation = progress < 1.0 ? animation : nil
            } else {
                rotation = deviceRotation
            }
        }
        let normalizedRotation = rotation.truncatingRemainder(dividingBy: 2.0 * .pi)
        guard self.cardBackgroundRotation != normalizedRotation else { return }
        self.cardBackgroundRotation = normalizedRotation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.cardBackgroundNode.transform = CATransform3DMakeRotation(self.cardBackgroundRotation, 0.0, 0.0, 1.0)
        CATransaction.commit()
    }

    private func updateDiamond() {
        guard let item = self.item else { return }
        let size = CGSize(width: 64.0, height: 64.0)
        let component = InteractiveDiamondComponent(
            size: size, diamondWidth: 38.0,
            isVisible: self.visibility != .none && !self.isAwaitingTransferFlight,
            theme: item.presentationData.theme.theme, appearance: .cool,
            expansionStyle: .downward, tapToSpin: true
        )
        let diamond = self.cardIcon ?? component.makeView()
        self.cardIcon = diamond
        diamond.update(component: component)
        diamond.isHidden = self.isAwaitingTransferFlight
        diamond.isUserInteractionEnabled = !self.isAwaitingTransferFlight && !self.isSendingTransfer
        diamond.scrollTiltProvider = self.scrollTiltProvider
        diamond.onExpansionChanged = { [weak self] isExpanded in
            guard let self else { return }
            if isExpanded {
                self.cancelIncomingTransferAnimation()
                if self.cardBackgroundRotationAnimation != nil {
                    self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 0.22, turns: 0.0)
                }
                self.cardBackgroundMotion = nil
            }
            self.updateDiamondRefraction()
        }
        diamond.onMotionUpdated = { [weak self] state in
            guard let self else { return }
            if state == nil {
                self.mediaContainerNode.layer.removeAnimation(forKey: "sublayerTransform.scale")
            }
            if UIAccessibility.isReduceMotionEnabled {
                self.mediaContainerNode.layer.removeAnimation(forKey: "transferFlightLanding")
            }
            self.updateCardBackgroundRotation(state)
        }
        diamond.onLanding = { [weak self] power in
            self?.animateDiamondLandingBump(power: power)
        }
        if diamond.superview !== self.cardNode.view {
            self.cardNode.view.addSubview(diamond)
        }
        diamond.bounds = CGRect(origin: .zero, size: size)
        diamond.center = CGPoint(x: floorToScreenPixels((self.cardNode.bounds.width - 38.0) * 0.5) + 19.0, y: 35.0)
    }

    public var canPlayIncomingTransferAnimation: Bool {
        return self.isIncomingTransfer && self.visibility != .none && self.cardNode.bounds.width > 0
            && self.isNodeLoaded && self.view.window != nil
            && self.cardIcon?.isExpanded != true
            && self.item?.controllerInteraction.canReadHistory == true
            && UIApplication.shared.applicationState == .active
    }

    override public func unreadMessageRangeUpdated() {
        self.updateIncomingTransferVisibility()
    }

    private func updateIncomingTransferVisibility() {
        guard let item = self.item, self.isIncomingTransfer, self.cardNode.bounds.width > 0 else { return }
        let isUnread = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)]?.contains(item.message.id.id) == true
        var state = item.controllerInteraction.walletTransferArrivalState?(item.message.id)
        if state == nil, isUnread, self.canPlayIncomingTransferAnimation {
            item.controllerInteraction.requestWalletTransferArrival?(item.message)
            state = item.controllerInteraction.walletTransferArrivalState?(item.message.id)
        }
        if UIAccessibility.isReduceMotionEnabled {
            self.finishIncomingTransferAnimation()
            return
        }
        switch state {
        case let .queued(rise):
            self.prepareIncomingTransferAnimation(rise: rise)
        case let .playing(startTime, rise):
            self.prepareIncomingTransferAnimation(rise: rise)
            self.updateIncomingTransferAnimation(startTime: startTime, rise: rise, at: CACurrentMediaTime())
        case .finished:
            self.finishIncomingTransferAnimation()
        case nil:
            // Prepare before visibility and history-reading readiness allow the scene to start.
            if isUnread, item.controllerInteraction.requestWalletTransferArrival != nil, self.cardIcon?.isExpanded != true {
                self.prepareIncomingTransferAnimation(rise: item.controllerInteraction.freshWalletTransferMessageIds.contains(item.message.id))
            } else {
                self.finishIncomingTransferAnimation()
            }
        }
    }

    private func prepareIncomingTransferAnimation(rise: Bool) {
        guard self.arrivalTextView == nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.finishCompletionAnimation()
        self.isPlayingHighlightShimmer = false
        self.mediaContainerNode.layer.removeAnimation(forKey: "sublayerTransform.scale")
        self.shimmerView?.removeFromSuperview()
        self.shimmerView = nil
        let text = TransferArrivalTextView(frame: self.cardNode.bounds)
        self.arrivalTextView = text
        self.cardNode.view.addSubview(text)
        text.update(nodes: [self.amountNode, self.nameNode, self.addressNode])
        for node in [self.amountNode, self.nameNode, self.addressNode, self.addressHighlightNode] {
            node.alpha = 0.0
        }
        self.sendingClockNode.alpha = 0.0
        self.ribbonBackgroundNode.alpha = 0.0
        self.ribbonTextContainerNode.alpha = 0.0
        self.mediaContainerNode.alpha = rise ? 0.0 : 1.0
        self.updateShimmer(animated: false)
        CATransaction.commit()
    }

    public func updateIncomingTransferAnimation(startTime: CFTimeInterval, rise: Bool, at timestamp: CFTimeInterval) {
        guard self.canPlayIncomingTransferAnimation else { return }
        if UIAccessibility.isReduceMotionEnabled {
            self.cancelIncomingTransferAnimation()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.prepareIncomingTransferAnimation(rise: rise)
        if self.arrivalStartTime == nil {
            self.arrivalStartTime = startTime
            self.cardBackgroundRotationAnimation = nil
            self.cardBackgroundMotion = nil
            self.cardIcon?.beginReceivingTransfer(at: startTime, completionDelay: WalletTransferArrivalAnimation.landing)
        }
        let t = max(0.0, timestamp - startTime)
        let finish = t - WalletTransferArrivalAnimation.landing
        self.arrivalTextView?.update(time: t)
        self.shimmerView?.updateArrival(time: t)

        let bounce = finish > 0 && finish < 1.2 ? -sin(2 * .pi * 2 * finish) * exp(-finish / 0.25) : 0
        let scale: CGFloat
        let y: CGFloat
        if rise {
            let spring = t < 0.8 ? 1 - exp(-9 * t) * (cos(13 * t) + 9.0 / 13.0 * sin(13 * t)) : 1
            scale = CGFloat(0.86 + 0.14 * spring) * CGFloat(1 + 0.045 * bounce)
            y = CGFloat(70 * (1 - spring)) + (1 - scale) * self.mediaContainerNode.bounds.height * 0.5
            self.mediaContainerNode.alpha = CGFloat(min(1, t / 0.12))
        } else {
            let pop = t < 1.2 ? 0.05 * sin(2 * .pi * 1.8 * t) * exp(-t / 0.22) : 0
            scale = CGFloat((1 + pop) * (1 + 0.045 * bounce))
            y = 0
            self.mediaContainerNode.alpha = 1
        }
        self.mediaContainerNode.layer.sublayerTransform = CATransform3DScale(CATransform3DMakeTranslation(0, y, 0), scale, scale, 1)

        if finish >= 0 {
            if !self.arrivalDidLand {
                self.arrivalDidLand = true
                self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 1.8, turns: 2)
            }
            let tau = 0.08, w = 2 * Double.pi * 1.6
            let length = 1 - exp(-finish / tau) * (cos(w * finish) + sin(w * finish) / (tau * w))
            let width = 1 - pow(1 - min(1, finish / 0.3), 2.2)
            let pivot = CGPoint(x: 200, y: 24)
            let center = self.ribbonBackgroundNode.position
            let transform = CGAffineTransform(translationX: pivot.x - center.x, y: pivot.y - center.y)
                .rotated(by: .pi / 4).scaledBy(x: CGFloat(max(0.001, length)), y: CGFloat(0.2 + 0.8 * width))
                .rotated(by: -.pi / 4).translatedBy(x: center.x - pivot.x, y: center.y - pivot.y)
            self.ribbonBackgroundNode.transform = CATransform3DMakeAffineTransform(transform)
            self.ribbonTextContainerNode.transform = CATransform3DMakeAffineTransform(transform)
            self.ribbonBackgroundNode.alpha = CGFloat(min(1, max(0, length * 4)))
            self.ribbonTextContainerNode.alpha = self.ribbonBackgroundNode.alpha * CGFloat(min(1, max(0, (length - 0.6) / 0.35)))
            if finish >= 0.6 && !self.arrivalDidGlint {
                self.arrivalDidGlint = true
                self.animateRibbonGlint()
            }
        }
    }

    private func cancelIncomingTransferAnimation() {
        guard self.arrivalTextView != nil, let item = self.item else { return }
        item.controllerInteraction.cancelWalletTransferArrival?(item.message.id)
        self.finishIncomingTransferAnimation()
    }

    public func finishIncomingTransferAnimation() {
        guard let text = self.arrivalTextView else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.arrivalTextView = nil
        text.removeFromSuperview()
        self.arrivalStartTime = nil
        self.arrivalDidLand = false
        self.arrivalDidGlint = false
        for node in [self.amountNode, self.nameNode, self.addressNode, self.addressHighlightNode] {
            node.alpha = 1.0
        }
        self.addressHighlightNode.alpha = 0.06
        self.mediaContainerNode.alpha = 1.0
        self.mediaContainerNode.layer.sublayerTransform = CATransform3DIdentity
        self.ribbonBackgroundNode.transform = CATransform3DIdentity
        self.ribbonTextContainerNode.transform = CATransform3DIdentity
        self.cardIcon?.endReceivingTransfer()
        self.cardBackgroundMotion = nil
        self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 0.22, turns: 0)
        self.finishCompletionAnimation()
        self.updateShimmer(animated: false)
        CATransaction.commit()
    }

    public func transferDiamondTarget(in view: UIView) -> (center: CGPoint, width: CGFloat)? {
        guard self.visibility != .none, self.cardNode.isNodeLoaded,
              let window = self.cardNode.view.window, window === view.window,
              self.cardNode.bounds.width > 0.0 else { return nil }
        let layer = self.cardNode.layer.presentation() ?? self.cardNode.layer
        let targetLayer = view.layer.presentation() ?? view.layer
        let center = CGPoint(x: floorToScreenPixels((self.cardNode.bounds.width - 38.0) * 0.5) + 19.0, y: 35.0)
        let point = layer.convert(center, to: targetLayer)
        let left = layer.convert(CGPoint(x: center.x - 19.0, y: center.y), to: targetLayer)
        let right = layer.convert(CGPoint(x: center.x + 19.0, y: center.y), to: targetLayer)
        return (point, hypot(right.x - left.x, right.y - left.y))
    }

    public func setAwaitingTransferFlight(_ awaiting: Bool, animated: Bool = false) {
        guard self.isAwaitingTransferFlight != awaiting else { return }
        self.isAwaitingTransferFlight = awaiting
        self.stopCardBackgroundMotion()
        self.cardIcon?.isHidden = awaiting
        self.cardIcon?.isRenderingEnabled = !awaiting && self.visibility != .none
        self.cardIcon?.isUserInteractionEnabled = !awaiting && !self.isSendingTransfer
        if awaiting {
            self.mediaContainerNode.layer.removeAnimation(forKey: "transferFlightLanding")
            self.cardIcon?.updateTransferState(isSending: false, animateCompletion: false)
        }
        self.updateTransferAppearance(previousStatus: nil, animated: false)
        if !awaiting && animated {
            self.cardIcon?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            let statusNode = self.isSendingTransfer ? self.sendingClockNode : self.ribbonBackgroundNode
            statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            if !self.isSendingTransfer {
                self.ribbonTextContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            }
        }
    }

    public func acceptTransferDiamond(_ diamond: InteractiveDiamondComponent.View) {
        self.cardIcon?.onMotionUpdated = nil
        self.cardIcon?.isRenderingEnabled = false
        self.cardIcon?.removeFromSuperview()
        self.cardIcon = diamond
        self.isAwaitingTransferFlight = false
        diamond.transform = .identity
        diamond.alpha = 1.0
        self.updateDiamond()
        diamond.updateTransferState(isSending: true, animateCompletion: false)
        diamond.spin(4.5, decay: 0.7)
        self.finishCompletionAnimation()
        self.updateTransferAppearance(previousStatus: .pending, animated: true)
        self.animateTransferFlightLanding()
    }

    private func animateTransferFlightLanding() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let duration = 1.2
        let count = Int(duration * 120.0)
        let impact = (0 ... count).map { index -> Double in
            let time = duration * Double(index) / Double(count)
            return index == count ? 0.0 : sin(2.0 * .pi * 2.2 * time) * exp(-time / 0.2)
        }
        let scale = CAKeyframeAnimation(keyPath: "sublayerTransform.scale")
        scale.values = impact.map { 1.0 - 0.025 * $0 }
        let offset = CAKeyframeAnimation(keyPath: "sublayerTransform.translation.y")
        offset.values = impact.map { 4.0 * $0 }
        for animation in [scale, offset] {
            animation.duration = duration
            animation.calculationMode = .linear
        }
        let group = CAAnimationGroup()
        group.animations = [scale, offset]
        group.duration = duration
        self.mediaContainerNode.layer.add(group, forKey: "transferFlightLanding")
    }

    private func updateDiamondRefraction() {
        guard let diamond = self.cardIcon else { return }
        guard diamond.isExpanded else {
            diamond.updateRefractionSource(nil)
            return
        }

        let sourceRect = self.amountNode.frame.insetBy(dx: -2.0, dy: -2.0).integral
        let scale = UIScreen.main.scale
        let width = Int(ceil(sourceRect.width * scale))
        let height = Int(ceil(sourceRect.height * scale))
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data else {
            diamond.updateRefractionSource(nil)
            return
        }
        context.clear(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        context.translateBy(x: 0.0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: self.amountNode.frame.minX - sourceRect.minX, y: self.amountNode.frame.minY - sourceRect.minY)
        UIGraphicsPushContext(context)
        TextNode.draw(self.amountNode.bounds,
            withParameters: TextNode.DrawingParameters(cachedLayout: self.amountNode.cachedLayout, renderContentTypes: .all),
            isCancelled: { false }, isRasterizing: true)
        UIGraphicsPopContext()

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = MetalEngine.shared.device.makeTexture(descriptor: descriptor) else {
            diamond.updateRefractionSource(nil)
            return
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: context.bytesPerRow)
        let rect = self.cardNode.view.convert(sourceRect, to: diamond)
            .offsetBy(dx: -diamond.bounds.midX, dy: -diamond.bounds.midY)
        diamond.updateRefractionSource(InteractiveDiamondComponent.RefractionSource(
            texture: texture, uv: SIMD4(0.0, 0.0, 1.0, 1.0), rect: rect, preservesColors: true
        ))
    }

    private func updateWalletSubscription(item: ChatMessageBubbleContentItem, isIncoming: Bool, transactionId: String, fiatState: WalletContext.FiatState?, isSameMessage: Bool) {
        if !isSameMessage {
            self.walletStateDisposable?.dispose()
            self.walletStateDisposable = nil
            self.transferOperationId = nil
            self.transferTransactionHash = nil
            self.transferStatus = nil
            #if DEBUG
            self.debugTransferStatus = nil
            #endif
            self.finishCompletionAnimation()
            self.shimmerView?.removeFromSuperview()
            self.shimmerView = nil
            self.isHighlighted = false
            self.isPlayingHighlightShimmer = false
        }

        let walletContext = item.context.walletContext
        if self.walletContext !== walletContext {
            self.walletStateDisposable?.dispose()
            self.walletStateDisposable = nil
            self.walletContext = walletContext
        }

        self.renderedFiatState = fiatState
        self.requestWalletFiatUpdateIfNeeded()

        if isIncoming {
            self.updateTransferStatus(.completed, animated: false)
        } else {
            let pending = item.message.attributes.compactMap { $0 as? PendingWalletTransferMessageAttribute }.first
            self.transferOperationId = pending?.operationId ?? self.transferOperationId
            self.transferTransactionHash = transferCardTransactionHash(pending?.transactionId)
                ?? transferCardTransactionHash(transactionId)
                ?? self.transferTransactionHash

            self.applyWalletState(walletContext.flatMap {
                transferCardWalletState($0.stateValue, operationId: self.transferOperationId, transactionHash: self.transferTransactionHash)
            }, animated: isSameMessage)
        }

        guard self.walletStateDisposable == nil, let walletContext else {
            return
        }
        let disposable = MetaDisposable()
        self.walletStateDisposable = disposable
        disposable.set((walletContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else {
                return
            }
            if self.transferStatus != .completed {
                self.applyWalletState(
                    transferCardWalletState(state, operationId: self.transferOperationId, transactionHash: self.transferTransactionHash),
                    animated: true
                )
            }
            self.requestWalletFiatUpdateIfNeeded()
        }))
    }

    private func requestWalletFiatUpdateIfNeeded() {
        Queue.mainQueue().justDispatch { [weak self] in
            guard let self, let item = self.item, let fiatState = self.walletContext?.stateValue.fiat else {
                return
            }
            guard self.renderedFiatState?.selectedCurrency != fiatState.selectedCurrency
                || self.renderedFiatState?.selectedRate?.unitsPerGram != fiatState.selectedRate?.unitsPerGram else {
                return
            }
            item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
        }
    }

    private func applyWalletState(_ state: TransferCardWalletState?, animated: Bool) {
        if let state {
            self.transferOperationId = state.operationId ?? self.transferOperationId
            self.transferTransactionHash = state.transactionHash ?? self.transferTransactionHash
            self.updateTransferStatus(state.status, animated: animated)
        } else if self.transferStatus == .pending || self.transferStatus == .unavailable {
            self.updateTransferStatus(.unavailable, animated: animated)
        } else {
            self.updateTransferStatus(self.transferOperationId == nil ? .completed : .waiting, animated: animated)
        }
    }

    private func updateTransferStatus(_ status: TransferCardStatus, animated: Bool) {
        guard self.transferStatus != .completed else {
            return
        }
        let previousStatus = self.displayedTransferStatus
        self.transferStatus = status
        self.updateTransferAppearance(previousStatus: previousStatus, animated: animated)
    }

    private func updateTransferAppearance(previousStatus: TransferCardStatus?, animated: Bool) {
        let status = self.displayedTransferStatus
        if self.arrivalTextView != nil { return }
        if self.isAwaitingTransferFlight {
            self.finishCompletionAnimation()
            self.updateShimmer(animated: false)
            return
        }
        if self.isSendingTransfer {
            self.cardBackgroundRotationAnimation = nil
        }
        self.cardIcon?.isUserInteractionEnabled = !self.isSendingTransfer
        if previousStatus == status {
            self.cardIcon?.updateTransferState(isSending: self.isSendingTransfer, animateCompletion: false)
            if status == .pending {
                self.updateShimmer(animated: false)
            }
            return
        }
        self.finishCompletionAnimation()
        self.updateShimmer(animated: animated && previousStatus != nil)
        let animateCompletion = !self.isIncomingTransfer && status == .completed && previousStatus != nil && animated && self.visibility != .none
        if status == .completed {
            self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(
                duration: animateCompletion ? 1.8 : 0.22,
                turns: animateCompletion ? 2.0 : 0.0
            )
        }
        self.cardIcon?.updateTransferState(isSending: self.isSendingTransfer, animateCompletion: animateCompletion)
        if animateCompletion {
            self.playCompletionHaptics()
            self.animateCompletion()
        }
    }

    private func updateSendingClockAnimation() {
        let shouldAnimate = self.isSendingTransfer && !self.isAwaitingTransferFlight && self.visibility != .none
        for (node, duration) in [(self.clockFrameNode, 6.0), (self.clockMinNode, 1.0)] {
            let key = "transferClockRotation"
            if shouldAnimate {
                if node.layer.animation(forKey: key) == nil {
                    node.layer.transform = CATransform3DIdentity
                    let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                    animation.fromValue = 0.0 as NSNumber
                    animation.toValue = (Double.pi * 2.0) as NSNumber
                    animation.duration = duration
                    animation.repeatCount = .infinity
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    node.layer.add(animation, forKey: key)
                }
            } else if node.layer.animation(forKey: key) != nil {
                let transform = node.layer.presentation()?.transform ?? CATransform3DIdentity
                node.layer.removeAnimation(forKey: key)
                node.layer.transform = transform
            }
        }
    }

    private func updateShimmer(animated: Bool) {
        if let text = self.arrivalTextView {
            let shimmer: TransferCardShimmerView
            if let current = self.shimmerView, current.followsArrival {
                shimmer = current
            } else {
                self.shimmerView?.removeFromSuperview()
                shimmer = TransferCardShimmerView(addressMask: self.addressShimmerMaskNode.view, repeatAnimation: false, followsArrival: true)
                self.shimmerView = shimmer
                self.cardNode.view.insertSubview(shimmer, belowSubview: text)
            }
            shimmer.update(size: self.cardNode.bounds.size, addressFrame: self.addressNode.frame)
            if let diamond = self.cardIcon { self.cardNode.view.bringSubviewToFront(diamond) }
            return
        }
        let displayShimmer = !self.isAwaitingTransferFlight && (self.displayedTransferStatus == .pending || self.isPlayingHighlightShimmer) && self.visibility != .none
        if displayShimmer {
            let repeatAnimation = !self.isPlayingHighlightShimmer
            let shimmerView: TransferCardShimmerView
            if let current = self.shimmerView, current.repeatAnimation == repeatAnimation {
                shimmerView = current
            } else {
                self.shimmerView?.removeFromSuperview()
                shimmerView = TransferCardShimmerView(addressMask: self.addressShimmerMaskNode.view, repeatAnimation: repeatAnimation)
                self.shimmerView = shimmerView
                self.cardNode.view.addSubview(shimmerView)
                if !repeatAnimation {
                    self.animateHighlightBump()
                    shimmerView.completion = { [weak self, weak shimmerView] in
                        guard let self, let shimmerView, self.shimmerView === shimmerView else {
                            return
                        }
                        self.isPlayingHighlightShimmer = false
                        self.shimmerView = nil
                        shimmerView.removeFromSuperview()
                        self.updateShimmer(animated: false)
                    }
                }
            }
            if let iconView = self.cardIcon, iconView.superview === self.cardNode.view {
                self.cardNode.view.bringSubviewToFront(iconView)
            }
            shimmerView.layer.removeAnimation(forKey: "opacity")
            shimmerView.alpha = 1.0
            shimmerView.update(size: self.cardNode.bounds.size, addressFrame: self.addressNode.frame)
            self.addressShimmerMaskNode.recursivelyEnsureDisplaySynchronously(true)
        } else if let shimmerView = self.shimmerView {
            if animated && self.visibility != .none {
                guard shimmerView.alpha != 0.0 else {
                    return
                }
                shimmerView.alpha = 0.0
                let fadeValues = (0 ... 36).map { NSNumber(value: pow(1.0 - Double($0) / 36.0, 2.2)) }
                shimmerView.layer.animateKeyframes(values: fadeValues, duration: 0.3, keyPath: "opacity", completion: { [weak self, weak shimmerView] finished in
                    guard finished, let self, let shimmerView, self.shimmerView === shimmerView, shimmerView.alpha == 0.0 else {
                        return
                    }
                    shimmerView.removeFromSuperview()
                    self.shimmerView = nil
                })
            } else {
                shimmerView.removeFromSuperview()
                self.shimmerView = nil
            }
        }
    }

    private func animateDiamondLandingBump(power: CGFloat) {
        guard self.visibility != .none, !self.isSendingTransfer,
              UIApplication.shared.applicationState == .active, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let duration = 1.0
        let frameCount = Int(duration * 120.0)
        let values = (0 ... frameCount).map { index -> NSNumber in
            let time = duration * Double(index) / Double(frameCount)
            let bounce = index == frameCount ? 0.0 : sin(2.0 * .pi * 2.4 * time) * exp(-time / 0.2)
            return NSNumber(value: 1.0 - 0.05 * Double(power) * bounce)
        }
        self.mediaContainerNode.layer.animateKeyframes(
            values: values,
            duration: duration,
            keyPath: "sublayerTransform.scale"
        )
    }

    private func animateHighlightBump() {
        guard self.visibility != .none, UIApplication.shared.applicationState == .active,
              !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let delay = 0.18
        let durationFactor = 1.7
        let duration = 0.9 * durationFactor
        let frameCount = Int(ceil(duration * 120.0))
        var values: [NSNumber] = [1.0]
        var keyTimes: [NSNumber] = [0.0]
        for index in 0 ... frameCount {
            let progress = Double(index) / Double(frameCount)
            let time = duration * progress / durationFactor
            let bump = index == frameCount ? 0.0 : sin(2.0 * .pi * 1.6 * time) * exp(-time / 0.2)
            values.append(NSNumber(value: 1.0 + 0.06 * bump))
            keyTimes.append(NSNumber(value: (delay + duration * progress) / (delay + duration)))
        }
        self.mediaContainerNode.layer.animateKeyframes(
            values: values,
            keyTimes: keyTimes,
            duration: delay + duration,
            keyPath: "transform.scale"
        )
        Queue.mainQueue().after(delay, { [weak self, weak shimmerView = self.shimmerView] in
            guard let self, let shimmerView, self.shimmerView === shimmerView, self.visibility != .none else {
                return
            }
            self.cardIcon?.pushFromBelow(strength: 1.5)
        })
    }

    private func removeRibbonAnimation() {
        self.ribbonAnimationLayer?.removeAllAnimations()
        self.ribbonAnimationLayer?.removeFromSuperlayer()
        self.ribbonAnimationLayer = nil
        if let ribbonAnimationMaskLayer = self.ribbonAnimationMaskLayer {
            ribbonAnimationMaskLayer.removeAllAnimations()
            self.ribbonAnimationMaskLayer = nil
            self.ribbonTextContainerNode.layer.mask = nil
        }
        self.ribbonTextContainerNode.view.mask = self.ribbonTextMaskNode.view
    }

    private func finishCompletionAnimation() {
        guard self.arrivalTextView == nil else { return }
        self.completionAnimationId &+= 1
        self.removeRibbonAnimation()
        self.ribbonGlintLayer?.removeAllAnimations()
        self.ribbonGlintLayer?.removeFromSuperlayer()
        self.ribbonGlintLayer = nil
        self.ribbonBackgroundNode.layer.removeAnimation(forKey: "opacity")
        self.ribbonTextNode.layer.removeAnimation(forKey: "opacity")
        self.ribbonTextNode.layer.removeAnimation(forKey: "transform.scale")
        self.sendingClockNode.layer.removeAnimation(forKey: "opacity")
        self.sendingClockNode.layer.removeAnimation(forKey: "transform.scale")
        self.mediaContainerNode.layer.removeAnimation(forKey: "transform.scale")
        let sending = self.isSendingTransfer
        self.sendingClockNode.alpha = sending && !self.isAwaitingTransferFlight ? 1.0 : 0.0
        self.ribbonBackgroundNode.alpha = sending || self.isAwaitingTransferFlight ? 0.0 : 1.0
        self.ribbonTextContainerNode.alpha = sending || self.isAwaitingTransferFlight ? 0.0 : 1.0
        self.ribbonTextNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateTintColor(
            layer: self.ribbonBackgroundNode.layer,
            color: UIColor(rgb: self.isIncomingTransfer ? 0x42b0ff : 0x00cf00)
        )
        self.updateSendingClockAnimation()
    }

    private func playCompletionHaptics() {
        guard UIApplication.shared.applicationState == .active else { return }
        Haptics.strong()
        let animationId = self.completionAnimationId
        for (delay, intensity) in [(0.13, CGFloat(0.7)), (0.3, CGFloat(0.45))] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.completionAnimationId == animationId,
                      self.visibility != .none, self.displayedTransferStatus == .completed,
                      UIApplication.shared.applicationState == .active else { return }
                Haptics.hit(intensity)
            }
        }
    }

    private func animateRibbonGlint() {
        let size = self.ribbonBackgroundNode.bounds.size
        let center = self.ribbonBackgroundNode.position
        let frame = CGRect(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5, width: size.width, height: size.height)
        guard frame.width > 0.0, frame.height > 0.0 else {
            return
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: (x - frame.minX) / frame.width, y: (y - frame.minY) / frame.height)
        }

        let glintLayer = SimpleGradientLayer()
        glintLayer.frame = frame
        glintLayer.colors = [UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.7).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
        glintLayer.locations = [0.0, 0.5, 1.0]
        glintLayer.opacity = 0.0
        glintLayer.compositingFilter = "plusL"

        let maskLayer = SimpleShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: frame.size)
        maskLayer.contentsScale = UIScreenScale
        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.path = TransferCardRibbonGeometry.path
        glintLayer.mask = maskLayer
        self.ribbonGlintLayer = glintLayer
        self.mediaContainerNode.layer.insertSublayer(glintLayer, above: self.ribbonBackgroundNode.layer)

        let delay = 0.6
        let duration = 0.55
        glintLayer.startPoint = point(226.0, 0.0)
        glintLayer.endPoint = point(254.0, 12.0)
        for (keyPath, from, to) in [
            ("startPoint", point(136.0, 0.0), glintLayer.startPoint),
            ("endPoint", point(164.0, 12.0), glintLayer.endPoint)
        ] {
            glintLayer.animate(from: NSValue(cgPoint: from), to: NSValue(cgPoint: to), keyPath: keyPath, timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration, delay: delay)
        }

        let frameCount = Int(ceil(duration * 120.0))
        var values: [NSNumber] = [0.0]
        var keyTimes: [NSNumber] = [0.0]
        for index in 0 ... frameCount {
            let progress = Double(index) / Double(frameCount)
            values.append(NSNumber(value: index == frameCount ? 0.0 : sin(.pi * progress)))
            keyTimes.append(NSNumber(value: (delay + duration * progress) / (delay + duration)))
        }
        glintLayer.animateKeyframes(values: values, keyTimes: keyTimes, duration: delay + duration, keyPath: "opacity")
    }

    private func animateCompletion() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let animationId = self.completionAnimationId
        let ribbonFrame = self.ribbonBackgroundNode.frame
        let clockCenter = CGPoint(
            x: self.cardNode.frame.minX + self.sendingClockNode.position.x - ribbonFrame.minX,
            y: self.cardNode.frame.minY + self.sendingClockNode.position.y - ribbonFrame.minY
        )
        let finalPath = TransferCardRibbonGeometry.path
        let ribbonCenter = TransferCardRibbonGeometry.center
        let overshootOffset = -0.02 * (ribbonCenter.x + ribbonCenter.y)
        var overshootTransform = CGAffineTransform(a: 1.02, b: 0.02, c: 0.02, d: 1.02, tx: overshootOffset, ty: overshootOffset)
        let paths = [
            TransferCardRibbonGeometry.compactPath(center: clockCenter),
            finalPath,
            finalPath.copy(using: &overshootTransform) ?? finalPath,
            finalPath
        ]
        let keyTimes = [0.0, 0.28 / 0.42, 0.34 / 0.42, 1.0].map { NSNumber(value: $0) }

        let ribbonLayer = SimpleShapeLayer()
        ribbonLayer.frame = ribbonFrame
        ribbonLayer.contentsScale = UIScreenScale
        ribbonLayer.fillColor = UIColor(rgb: 0x00cf00).cgColor
        ribbonLayer.path = finalPath
        self.ribbonAnimationLayer = ribbonLayer
        self.mediaContainerNode.layer.insertSublayer(ribbonLayer, below: self.ribbonBackgroundNode.layer)
        self.ribbonBackgroundNode.alpha = 0.0

        let maskLayer = SimpleShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: ribbonFrame.size)
        maskLayer.contentsScale = UIScreenScale
        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.path = finalPath
        self.ribbonAnimationMaskLayer = maskLayer
        self.ribbonTextContainerNode.view.mask = nil
        self.ribbonTextContainerNode.layer.mask = maskLayer

        for layer in [ribbonLayer, maskLayer] {
            layer.animateKeyframes(values: paths, keyTimes: keyTimes, duration: 0.42, keyPath: "path", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        }
        ribbonLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
        self.sendingClockNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12)
        self.sendingClockNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.12)
        self.ribbonTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.22, delay: 0.06)
        self.ribbonTextNode.layer.animateScale(from: 0.65, to: 1.0, duration: 0.28)

        self.ribbonBackgroundNode.alpha = 1.0
        self.ribbonBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.06, delay: 0.42, completion: { [weak self] finished in
            guard finished, let self, self.completionAnimationId == animationId else {
                return
            }
            self.removeRibbonAnimation()
        })
        self.animateRibbonGlint()

        let bounceDuration = 1.2
        let bounceFrameCount = Int(bounceDuration * 120.0)
        let bounceValues = (0 ... bounceFrameCount).map { index -> NSNumber in
            let time = bounceDuration * Double(index) / Double(bounceFrameCount)
            let bounce = index == bounceFrameCount ? 0.0 : -sin(2.0 * Double.pi * 2.0 * time) * exp(-time / 0.25)
            return NSNumber(value: 1.0 + 0.045 * bounce)
        }
        self.mediaContainerNode.layer.animateKeyframes(
            values: bounceValues,
            duration: bounceDuration,
            keyPath: "transform.scale",
            timingFunction: CAMediaTimingFunctionName.linear.rawValue,
            completion: { [weak self] finished in
                guard finished, let self, self.completionAnimationId == animationId else {
                    return
                }
                self.finishCompletionAnimation()
            }
        )
    }

    #if DEBUG
    private func toggleDebugTransferStatus() {
        guard !self.isIncomingTransfer else {
            return
        }
        let previousStatus = self.displayedTransferStatus
        self.debugTransferStatus = previousStatus == .completed ? .pending : .completed
        self.updateTransferAppearance(previousStatus: previousStatus, animated: true)
    }
    #endif

    private func removeCaptionTextSelection(animated: Bool) {
        guard let textSelectionNode = self.captionTextSelectionNode else {
            return
        }
        self.captionTextSelectionNode = nil
        self.updateIsTextSelectionActive?(false)

        if animated {
            textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.highlightAreaNode.removeFromSupernode()
                textSelectionNode?.removeFromSupernode()
            })
        } else {
            textSelectionNode.highlightAreaNode.removeFromSupernode()
            textSelectionNode.removeFromSupernode()
        }
    }

    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            self.removeCaptionTextSelection(animated: true)
        }
    }

    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        if value {
            guard self.captionTextSelectionNode == nil,
                  let item = self.item,
                  !self.captionNode.isHidden,
                  let attributedText = self.captionNode.cachedLayout?.attributedString,
                  attributedText.length > 0,
                  let rootNode = item.controllerInteraction.chatControllerNode() else {
                return
            }

            let knobColor: UIColor
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                knobColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
            } else {
                knobColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionKnobColor
            }

            let textSelectionNode = TextSelectionNode(
                theme: TextSelectionTheme(
                    selection: UIColor.white.withAlphaComponent(0.4),
                    knob: knobColor,
                    isDark: item.presentationData.theme.theme.overallDarkAppearance
                ),
                strings: item.presentationData.strings,
                textNodeOrView: .node(self.captionNode),
                updateIsActive: { [weak self] value in
                    self?.updateIsTextSelectionActive?(value)
                },
                present: { [weak self] controller, arguments in
                    self?.item?.controllerInteraction.presentGlobalOverlayController(controller, arguments)
                },
                rootView: { [weak rootNode] in
                    return rootNode?.view
                },
                performAction: { [weak self] text, action in
                    guard let self, let item = self.item else {
                        return
                    }
                    item.controllerInteraction.performTextSelectionAction(item.message, true, text, nil, action)
                }
            )
            textSelectionNode.enableCopy = true
            textSelectionNode.enableQuote = false
            textSelectionNode.enableShare = true

            self.captionTextSelectionNode = textSelectionNode
            self.mediaContainerNode.addSubnode(textSelectionNode)
            self.mediaContainerNode.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.captionNode)
            textSelectionNode.frame = self.captionNode.frame
            textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
        } else {
            self.removeCaptionTextSelection(animated: true)
        }
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeAmountLayout = TextNode.asyncLayout(self.amountNode)
        let makeNameLayout = TextNode.asyncLayout(self.nameNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let makeAddressHighlightLayout = TextNode.asyncLayout(self.addressHighlightNode)
        let makeAddressShimmerMaskLayout = TextNode.asyncLayout(self.addressShimmerMaskNode)
        let makeCaptionLayout = TextNode.asyncLayout(self.captionNode)
        let makeRibbonTextLayout = TextNode.asyncLayout(self.ribbonTextNode)
        let cachedLabelBackgroundImage = self.cachedLabelBackgroundImage

        return { [weak self] item, _, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(
                hidesSimpleAuthorHeader: true,
                headerSpacing: 0.0,
                hidesBackground: .always,
                forceFullCorners: false,
                forceAlignment: .center
            )

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, _ in
                let engineMessage = EngineMessage(item.message)
                guard let action = item.message.media.first(where: { media in
                    guard let action = media as? TelegramMediaAction else {
                        return false
                    }
                    if case .gramTransfer = action.action {
                        return true
                    } else {
                        return false
                    }
                }) as? TelegramMediaAction else {
                    return (0.0, { _ in
                        return (CGSize(), { _, _, _ in })
                    })
                }
                guard case let .gramTransfer(amount, peerAddress, transactionId, comment, commentEncrypted) = action.action else {
                    return (0.0, { _ in
                        return (CGSize(), { _, _, _ in })
                    })
                }
                let isIncoming = engineMessage.effectivelyIncoming(item.context.account.peerId)
                let caption = commentEncrypted ? "" : (comment ?? "")
                let hasEncryptedCaption = commentEncrypted

                let fiatState = item.context.walletContext?.stateValue.fiat
                let fiatValue: String?
                if let fiatState, let rate = fiatState.selectedRate {
                    fiatValue = formatTonFiatValue(
                        amount,
                        rate: rate.unitsPerGram,
                        currencySymbol: fiatState.selectedCurrency.symbol,
                        dateTimeFormat: item.presentationData.dateTimeFormat
                    )
                } else {
                    fiatValue = nil
                }
                let serviceText = walletTransferServiceMessageString(
                    presentationData: (item.presentationData.theme.theme, item.presentationData.theme.wallpaper),
                    strings: item.presentationData.strings,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    message: engineMessage,
                    isIncoming: isIncoming,
                    amount: amount,
                    fiatValue: fiatValue
                )

                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(
                    attributedString: serviceText,
                    backgroundColor: nil,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    constrainedSize: CGSize(width: max(1.0, constrainedSize.width - 32.0), height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let cardSize = CGSize(width: 216.0, height: 148.0)

                let amountFont = Font.with(
                    size: 18.0,
                    design: .round,
                    weight: .bold
                )
                let fractionalAmountFont = Font.with(
                    size: 14.0,
                    design: .round,
                    weight: .bold
                )
                let sign: String
                if isIncoming {
                    sign = "+"
                } else {
                    sign = "−"
                }
                let formattedAmount = formatTonAmountText(
                    amount,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    maxDecimalPositions: 3
                )
                let localizedAmount = formatTonAmountText(
                    amount,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    maxDecimalPositions: 3,
                    formatString: item.presentationData.strings.Currency_Grams
                )
                let amountText = NSMutableAttributedString(
                    string: localizedAmount,
                    font: amountFont,
                    textColor: UIColor(rgb: 0x0fddff)
                )
                let amountRange = (localizedAmount as NSString).range(of: formattedAmount)
                if amountRange.location != NSNotFound {
                    amountText.replaceCharacters(in: amountRange, with: tonAmountAttributedString(
                        sign + formattedAmount,
                        integralFont: amountFont,
                        fractionalFont: fractionalAmountFont,
                        color: .white,
                        decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator
                    ))
                }
                let (amountLayout, amountApply) = makeAmountLayout(TextNodeLayoutArguments(
                    attributedString: amountText,
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 24.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let peerName = item.message.id.peerId.isTelegramNotifications ? item.presentationData.strings.Notification_GramTransfer_UnknownUser : item.message.peers[item.message.id.peerId].flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder).uppercased() ?? ""
                let (nameLayout, nameApply) = makeNameLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: peerName,
                        font: Font.with(size: 12.0, design: .monospace, weight: .semibold),
                        textColor: UIColor(rgb: 0x0bdbff),
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                var addressGroups: [String] = []
                var addressIndex = peerAddress.startIndex
                while addressIndex < peerAddress.endIndex {
                    let endIndex = peerAddress.index(addressIndex, offsetBy: 4, limitedBy: peerAddress.endIndex) ?? peerAddress.endIndex
                    addressGroups.append(String(peerAddress[addressIndex ..< endIndex]))
                    addressIndex = endIndex
                }
                let addressLayoutArguments = TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: addressGroups.joined(separator: " "),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: UIColor(rgb: 0x0036b2),
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 2,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 24.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    lineSpacing: 0.05,
                    cutout: nil,
                    insets: UIEdgeInsets()
                )
                let (addressLayout, addressApply) = makeAddressLayout(addressLayoutArguments)
                let whiteAddressLayoutArguments = addressLayoutArguments.withAttributedString(
                    NSAttributedString(
                        string: addressGroups.joined(separator: " "),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: .white,
                        paragraphAlignment: .center
                    )
                )
                let (_, addressHighlightApply) = makeAddressHighlightLayout(whiteAddressLayoutArguments)
                let (_, addressShimmerMaskApply) = makeAddressShimmerMaskLayout(whiteAddressLayoutArguments)

                let hasCaption = hasEncryptedCaption || !caption.isEmpty
                let (captionLayout, captionApply) = makeCaptionLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: caption,
                        font: Font.regular(13.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    constrainedSize: CGSize(width: max(1.0, cardSize.width - 24.0), height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))
                let captionSize = hasEncryptedCaption
                    ? CGSize(width: 120.0, height: ceil(Font.regular(13.0).lineHeight))
                    : captionLayout.size

                let ribbonTitle: String
                if isIncoming {
                    ribbonTitle = item.presentationData.strings.Chat_GramTransfer_Received
                } else {
                    ribbonTitle = item.presentationData.strings.Chat_GramTransfer_Sent
                }
                let ribbonTextLayoutArguments = TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: ribbonTitle,
                        font: Font.semibold(11.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                )
                var (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(ribbonTextLayoutArguments)
                let ribbonTextMaxWidth: CGFloat = 52.0
                if ribbonTextLayout.size.width > ribbonTextMaxWidth {
                    (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(ribbonTextLayoutArguments.withAttributedString(
                        NSAttributedString(
                            string: ribbonTitle,
                            font: Font.semibold(11.0 * ribbonTextMaxWidth / ribbonTextLayout.size.width),
                            textColor: .white,
                            paragraphAlignment: .center
                        )
                    ))
                }

                var labelRects = labelLayout.linesRects()
                if labelRects.count > 1 {
                    let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                    for index in sortedIndices {
                        for offset in -1 ... 1 where offset != 0 {
                            let adjacentIndex = index + offset
                            if adjacentIndex >= 0 && adjacentIndex < labelRects.count && abs(labelRects[adjacentIndex].width - labelRects[index].width) < 40.0 {
                                let width = max(labelRects[adjacentIndex].width, labelRects[index].width)
                                labelRects[adjacentIndex].size.width = width
                                labelRects[index].size.width = width
                            }
                        }
                    }
                }
                for index in labelRects.indices {
                    labelRects[index] = labelRects[index].insetBy(dx: -7.0, dy: floor((labelRects[index].height - 22.0) / 2.0))
                    labelRects[index].size.height = 22.0
                    labelRects[index].origin.x = floor((labelLayout.size.width - labelRects[index].width) / 2.0)
                }

                let labelBackgroundImage: (CGPoint, UIImage)?
                var labelBackgroundUpdated = false
                if let (currentOffset, currentImage, currentRects) = cachedLabelBackgroundImage, currentRects == labelRects {
                    labelBackgroundImage = (currentOffset, currentImage)
                } else {
                    labelBackgroundImage = LinkHighlightingNode.generateImage(
                        color: .black,
                        inset: 0.0,
                        innerRadius: 11.0,
                        outerRadius: 11.0,
                        rects: labelRects,
                        useModernPathCalculation: false
                    )
                    labelBackgroundUpdated = true
                }

                let outerInset: CGFloat = 4.0
                let captionSpacing = hasCaption ? 7.0 : 0.0
                let captionBottomInset = hasCaption ? 4.0 : 0.0
                let mediaSize = CGSize(
                    width: cardSize.width + outerInset * 2.0,
                    height: cardSize.height + outerInset * 2.0 + captionSpacing + (hasCaption ? captionSize.height : 0.0) + captionBottomInset
                )
                let totalSize = CGSize(
                    width: max(mediaSize.width, labelLayout.size.width),
                    height: labelLayout.size.height + 13.0 + mediaSize.height
                )

                return (totalSize.width, { boundingWidth in
                    return (totalSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        let isSameMessage = self.item?.context.account === item.context.account
                            && self.item?.message.id.peerId == item.message.id.peerId
                            && self.item?.message.stableId == item.message.stableId
                        if !isSameMessage {
                            self.cancelIncomingTransferAnimation()
                            self.mediaContainerNode.layer.removeAnimation(forKey: "transferFlightLanding")
                            self.stopCardBackgroundMotion()
                            self.cardIcon?.isRenderingEnabled = false
                            self.cardIcon?.removeFromSuperview()
                            self.cardIcon = nil
                            self.cardBackgroundRotation = 0.0
                            self.cardBackgroundMotion = nil
                            self.cardBackgroundNode.transform = CATransform3DIdentity
                        }
                        self.item = item
                        self.isIncomingTransfer = isIncoming
                        let wasAwaitingTransferFlight = self.isAwaitingTransferFlight
                        self.isAwaitingTransferFlight = !isIncoming
                            && item.controllerInteraction.isAwaitingWalletTransferFlight?(item.message) == true

                        let refractionContentChanged = self.amountNode.cachedLayout !== amountLayout
                        let _ = labelApply()
                        let _ = amountApply()
                        let _ = nameApply()
                        let _ = addressApply()
                        let _ = addressHighlightApply()
                        let _ = addressShimmerMaskApply()
                        let _ = captionApply()
                        let _ = ribbonTextApply()

                        let labelFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((boundingWidth - labelLayout.size.width) * 0.5), y: 2.0),
                            size: labelLayout.size
                        )
                        self.labelNode.frame = labelFrame

                        let mediaFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((boundingWidth - mediaSize.width) * 0.5), y: labelLayout.size.height + 13.0),
                            size: mediaSize
                        )
                        let cardFrame = CGRect(
                            origin: CGPoint(x: outerInset, y: outerInset),
                            size: cardSize
                        )
                        if self.mediaContainerNode.frame != mediaFrame {
                            self.finishCompletionAnimation()
                        }
                        animation.animator.updateFrame(layer: self.mediaContainerNode.layer, frame: mediaFrame, completion: nil)
                        self.cardNode.frame = cardFrame
                        self.cardBackgroundNode.bounds = CGRect(origin: .zero, size: CGSize(width: 380.0, height: 295.0))
                        self.cardBackgroundNode.position = CGPoint(x: cardSize.width * 0.5, y: cardSize.height * 0.5)

                        let clockSize = CGSize(width: 14.0, height: 14.0)
                        let clockInset = 12.0 + (1.0 - UIScreenPixel)
                        self.sendingClockNode.frame = CGRect(origin: CGPoint(x: cardSize.width - clockSize.width - clockInset, y: clockInset), size: clockSize)
                        for node in [self.clockFrameNode, self.clockMinNode] {
                            node.bounds = CGRect(origin: .zero, size: clockSize)
                            node.position = CGPoint(x: clockSize.width * 0.5, y: clockSize.height * 0.5)
                        }
                        if self.clockFrameNode.image == nil {
                            let graphics = PresentationResourcesChat.principalGraphics(
                                theme: item.presentationData.theme.theme,
                                wallpaper: item.presentationData.theme.wallpaper,
                                bubbleCorners: item.presentationData.chatBubbleCorners
                            )
                            let clockColor = UIColor.white
                            self.clockFrameNode.image = generateTintedImage(image: graphics.clockMediaFrameImage, color: clockColor)
                            self.clockMinNode.image = generateTintedImage(image: graphics.clockMediaMinImage, color: clockColor)
                        }

                        self.updateDiamond()
                        self.amountNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - amountLayout.size.width) * 0.5), y: 62.0),
                            size: amountLayout.size
                        )
                        self.nameNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - nameLayout.size.width) * 0.5), y: 97.0),
                            size: nameLayout.size
                        )
                        if refractionContentChanged, self.cardIcon?.isExpanded == true {
                            self.updateDiamondRefraction()
                        }
                        self.addressNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - addressLayout.size.width) * 0.5), y: 114.0),
                            size: addressLayout.size
                        )
                        self.addressHighlightNode.frame = self.addressNode.frame.offsetBy(dx: 0.0, dy: 1.0)
                        self.addressShimmerMaskNode.frame = self.addressNode.frame

                        let ribbonSize = TransferCardRibbonGeometry.size
                        if self.arrivalTextView != nil {
                            // Apply layout in model coordinates, then restore the arrival pose below.
                            self.ribbonBackgroundNode.transform = CATransform3DIdentity
                            self.ribbonTextContainerNode.transform = CATransform3DIdentity
                        }
                        let ribbonFrame = CGRect(
                            origin: CGPoint(x: cardFrame.maxX - ribbonSize.width + 2.0, y: cardFrame.minY - 2.0),
                            size: ribbonSize
                        )
                        self.ribbonBackgroundNode.frame = ribbonFrame
                        self.ribbonTextContainerNode.frame = ribbonFrame
                        self.ribbonTextMaskNode.frame = CGRect(origin: .zero, size: ribbonSize)
                        if let ribbonAnimationMaskLayer = self.ribbonAnimationMaskLayer {
                            ribbonAnimationMaskLayer.frame = CGRect(origin: .zero, size: ribbonSize)
                        } else {
                            self.ribbonTextContainerNode.view.mask = self.ribbonTextMaskNode.view
                        }
                        let ribbonCenter = TransferCardRibbonGeometry.center
                        let ribbonTextPosition = CGPoint(x: ribbonCenter.x, y: ribbonCenter.y + 1.0)
                        self.ribbonTextNode.transform = CATransform3DMakeRotation(.pi / 4.0, 0.0, 0.0, 1.0)
                        self.ribbonTextNode.bounds = CGRect(origin: .zero, size: ribbonTextLayout.size)
                        self.ribbonTextNode.position = ribbonTextPosition

                        self.captionNode.isHidden = !hasCaption || hasEncryptedCaption
                        if hasEncryptedCaption {
                            self.removeCaptionTextSelection(animated: false)
                        } else if let captionDustNode = self.captionDustNode {
                            captionDustNode.removeFromSupernode()
                            self.captionDustNode = nil
                        }
                        if hasCaption {
                            let captionFrame = CGRect(
                                origin: CGPoint(
                                    x: floorToScreenPixels((mediaSize.width - captionSize.width) * 0.5),
                                    y: cardFrame.maxY + captionSpacing
                                ),
                                size: captionSize
                            )
                            self.captionNode.frame = captionFrame
                            if hasEncryptedCaption {
                                let dustNode: InvisibleInkDustNode
                                if let current = self.captionDustNode {
                                    dustNode = current
                                } else {
                                    dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                                    dustNode.isUserInteractionEnabled = false
                                    self.captionDustNode = dustNode
                                    self.mediaContainerNode.addSubnode(dustNode)
                                }
                                dustNode.frame = captionFrame.insetBy(dx: -3.0, dy: -3.0)
                                let rect = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: captionSize).insetBy(dx: 0.0, dy: 2.0)
                                dustNode.update(size: dustNode.frame.size, color: .white, textColor: .white, rects: [rect], wordRects: [rect])
                            }
                            if let textSelectionNode = self.captionTextSelectionNode {
                                let shouldUpdateLayout = textSelectionNode.frame.size != captionFrame.size
                                textSelectionNode.frame = captionFrame
                                textSelectionNode.highlightAreaNode.frame = captionFrame
                                if shouldUpdateLayout {
                                    textSelectionNode.updateLayout()
                                }
                            }
                        } else {
                            self.removeCaptionTextSelection(animated: false)
                            self.captionNode.frame = CGRect()
                        }

                        if self.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true
                            backgroundContent.cornerRadius = 24.0
                            self.mediaBackgroundContent = backgroundContent
                            self.mediaContainerNode.insertSubnode(backgroundContent, at: 0)
                        }
                        if let mediaBackgroundContent = self.mediaBackgroundContent {
                            animation.animator.updateFrame(layer: mediaBackgroundContent.layer, frame: CGRect(origin: .zero, size: mediaSize), completion: nil)
                            mediaBackgroundContent.cornerRadius = 24.0
                        }

                        let baseLabelBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                        if let (offset, image) = labelBackgroundImage {
                            if self.labelBackgroundNode == nil, let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                self.labelBackgroundNode = backgroundNode
                                self.insertSubnode(backgroundNode, at: 0)
                            }
                            if labelBackgroundUpdated, let labelBackgroundNode = self.labelBackgroundNode {
                                if labelRects.count == 1 {
                                    labelBackgroundNode.clipsToBounds = true
                                    labelBackgroundNode.cornerRadius = labelRects[0].height * 0.5
                                    labelBackgroundNode.view.mask = nil
                                } else {
                                    labelBackgroundNode.clipsToBounds = false
                                    labelBackgroundNode.cornerRadius = 0.0
                                    labelBackgroundNode.view.mask = self.labelBackgroundMaskNode.view
                                }
                            }
                            if let labelBackgroundNode = self.labelBackgroundNode {
                                animation.animator.updateFrame(
                                    layer: labelBackgroundNode.layer,
                                    frame: CGRect(
                                        origin: CGPoint(x: baseLabelBackgroundFrame.minX + offset.x, y: baseLabelBackgroundFrame.minY + offset.y),
                                        size: image.size
                                    ),
                                    completion: nil
                                )
                            }
                            self.labelBackgroundMaskNode.image = image
                            self.labelBackgroundMaskNode.frame = CGRect(origin: .zero, size: image.size)
                            self.cachedLabelBackgroundImage = (offset, image, labelRects)
                        }

                        if let (rect, size) = self.absoluteRect {
                            self.updateAbsoluteRect(rect, within: size)
                        }
                        self.updateWalletSubscription(item: item, isIncoming: isIncoming, transactionId: transactionId, fiatState: fiatState, isSameMessage: isSameMessage)
                        if wasAwaitingTransferFlight != self.isAwaitingTransferFlight {
                            self.updateTransferAppearance(previousStatus: nil, animated: false)
                        }
                        self.shimmerView?.update(size: cardSize, addressFrame: self.addressNode.frame)
                        self.arrivalTextView?.frame = self.cardNode.bounds
                        self.arrivalTextView?.update(nodes: [self.amountNode, self.nameNode, self.addressNode])
                        self.updateIncomingTransferVisibility()
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)

    }

    override public func updateHighlightedState(animated: Bool) -> Bool {
        guard let item = self.item else {
            return false
        }
        let highlighted = item.controllerInteraction.highlightedState?.messageStableId == item.message.stableId
        if self.isHighlighted != highlighted {
            self.isHighlighted = highlighted
            if highlighted && self.arrivalTextView == nil {
                self.isPlayingHighlightShimmer = true
                self.shimmerView?.removeFromSuperview()
                self.shimmerView = nil
                self.updateShimmer(animated: false)
            }
        }
        return highlighted
    }

    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }

        var rects: [(CGRect, CGRect)]?
        let textNodeFrame = self.labelNode.frame
        if let point, let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(
            x: point.x - textNodeFrame.minX,
            y: point.y - textNodeFrame.minY
        )) {
            let possibleNames = [TelegramTextAttributes.URL, TelegramTextAttributes.PeerMention]
            for name in possibleNames where attributes[NSAttributedString.Key(rawValue: name)] != nil {
                rects = self.labelNode.lineAndAttributeRects(name: name, at: index)
                break
            }
        }

        if let rects {
            let mappedRects = rects.map { lineRect, attributeRect -> CGRect in
                var attributeRect = attributeRect
                attributeRect.origin.x = floor((textNodeFrame.size.width - lineRect.width) * 0.5) + attributeRect.origin.x
                return attributeRect
            }
            let highlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                highlightingNode = current
            } else {
                let serviceColor = serviceMessageColorComponents(
                    theme: item.presentationData.theme.theme,
                    wallpaper: item.presentationData.theme.wallpaper
                )
                highlightingNode = LinkHighlightingNode(color: serviceColor.linkHighlight)
                highlightingNode.inset = 2.5
                self.linkHighlightingNode = highlightingNode
                self.insertSubnode(highlightingNode, belowSubnode: self.labelNode)
            }
            highlightingNode.frame = self.labelNode.frame.offsetBy(dx: 0.0, dy: 1.5)
            highlightingNode.updateRects(mappedRects)
        } else if let highlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            highlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak highlightingNode] _ in
                highlightingNode?.removeFromSupernode()
            })
        }
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let iconView = self.cardIcon,
           iconView.isUserInteractionEnabled,
           iconView.point(inside: iconView.convert(point, from: self.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        if gesture == .tap, let (_, attributes) = self.labelNode.attributesAtPoint(CGPoint(
            x: point.x - self.labelNode.frame.minX,
            y: point.y - self.labelNode.frame.minY
        )) {
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                    guard let self, let item = self.item else {
                        return
                    }
                    let controller = item.context.sharedContext.makeWalletInfoScreen(
                        context: item.context,
                        mode: .gram,
                        completion: nil
                    )
                    if let navigationController = item.controllerInteraction.navigationController() {
                        navigationController.pushViewController(controller)
                    } else {
                        item.controllerInteraction.presentControllerInCurrent(controller, nil)
                    }
                }))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                #if DEBUG
                if !self.isIncomingTransfer {
                    return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                        self?.toggleDebugTransferStatus()
                    }))
                }
                #endif
                return ChatMessageBubbleContentTapAction(content: .peerMention(
                    peerId: peerMention.peerId,
                    mention: peerMention.mention,
                    openProfile: false
                ))
            }
        }

        let mediaPoint = self.mediaContainerNode.view.convert(point, from: self.view)
        if gesture == .tap, let captionDustNode = self.captionDustNode, captionDustNode.frame.contains(mediaPoint) {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                guard let self, let item = self.item else {
                    return
                }
                let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default, decryptWalletComment: true))
            }))
        }
        if self.cardNode.frame.contains(mediaPoint) || self.captionNode.frame.contains(mediaPoint) || self.mediaBackgroundContent?.frame.contains(mediaPoint) == true {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}

private func walletTransferServiceMessageString(
    presentationData: (PresentationTheme, TelegramWallpaper),
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat,
    message: EngineMessage,
    isIncoming: Bool,
    amount: Int64,
    fiatValue: String?
) -> NSAttributedString {
    let primaryTextColor = serviceMessageColorComponents(theme: presentationData.0, wallpaper: presentationData.1).primaryText
    let regularFont = Font.regular(13.0)
    let semiboldFont = Font.semibold(13.0)
    let conversationPeer = message.enginePeers[message.id.peerId] ?? message.author
    let peerName = conversationPeer?.compactDisplayTitle ?? ""
    let peerMentionAttributes: [NSAttributedString.Key: Any]
    if let peerId = conversationPeer?.id {
        peerMentionAttributes = [
            NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention): TelegramPeerMention(peerId: peerId, mention: "")
        ]
    } else {
        peerMentionAttributes = [:]
    }

    let amountText = formatTonAmountText(
        amount,
        dateTimeFormat: dateTimeFormat,
        maxDecimalPositions: 3,
        formatString: strings.Currency_Grams
    )
    let text: PresentationStrings.FormattedString
    if let fiatValue {
        text = isIncoming
            ? (message.id.peerId.isTelegramNotifications ? strings.Notification_GramTransferUnknown_WithFiat(amountText, fiatValue) : strings.Notification_GramTransfer_WithFiat(peerName, amountText, fiatValue))
            : strings.Notification_GramTransfer_WithFiatYou(peerName, amountText, fiatValue)
    } else {
        text = isIncoming
            ? (message.id.peerId.isTelegramNotifications ? strings.Notification_GramTransferUnknown(amountText) : strings.Notification_GramTransfer(peerName, amountText))
            : strings.Notification_GramTransferYou(peerName, amountText)
    }
    let result = NSMutableAttributedString(string: text.string, font: regularFont, textColor: primaryTextColor)
    for range in text.ranges {
        if range.index == 0 {
            result.addAttributes(peerMentionAttributes, range: range.range)
            if isIncoming {
                result.addAttribute(.font, value: semiboldFont, range: range.range)
            }
        } else if range.index == 1 {
            result.addAttribute(.font, value: semiboldFont, range: range.range)
        }
    }

    return result
}
