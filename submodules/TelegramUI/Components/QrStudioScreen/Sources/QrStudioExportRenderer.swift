import Foundation
import UIKit

struct QrStudioExportPatternItem {
    enum Content: Equatable {
        case sticker(Int)
        case symbol
        case model
    }

    var content: Content
    var point: CGPoint
    var side: CGFloat
    var degrees: Double
    var hash: Double
}

struct QrStudioExportScene {
    enum Background {
        case mesh([QrStudioColor])
        case image(CGImage)
        case emoji(colors: [QrStudioColor], stickers: [QrStudioExportSticker], items: [QrStudioExportPatternItem])
        case gift(inner: QrStudioColor, outer: QrStudioColor, symbol: CGImage?, model: QrStudioExportSticker?, items: [QrStudioExportPatternItem])
    }

    var background: Background
    var card: CGImage
    var screenSize: CGSize
    var screenCard: CGRect
    var isLight: Bool

    init(background: Background, card: CGImage, screenSize: CGSize, screenCard: CGRect, isLight: Bool) {
        self.background = background
        self.card = card
        self.screenSize = screenSize
        self.screenCard = screenCard
        self.isLight = isLight
    }
}

func qrStudioTinted(_ image: CGImage, color: UIColor) -> CGImage? {
    let width = image.width
    let height = image.height
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
        return nil
    }
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    context.draw(image, in: rect)
    context.setBlendMode(.sourceIn)
    context.setFillColor(color.cgColor)
    context.fill(rect)
    return context.makeImage()
}

private func qrStudioMeshImage(colors: [QrStudioColor], width: Int, height: Int) -> CGImage? {
    guard colors.count == 9, width > 1, height > 1 else {
        return nil
    }
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    func node(_ c: Int, _ r: Int) -> QrStudioColor {
        return colors[min(max(r, 0), 2) * 3 + min(max(c, 0), 2)]
    }
    func smooth(_ x: CGFloat) -> CGFloat {
        return x * x * (3.0 - 2.0 * x)
    }
    for y in 0 ..< height {
        for x in 0 ..< width {
            let u = CGFloat(x) / CGFloat(width - 1) * 2.0
            let v = CGFloat(y) / CGFloat(height - 1) * 2.0
            let c0 = min(Int(u), 1)
            let r0 = min(Int(v), 1)
            let fu = smooth(u - CGFloat(c0))
            let fv = smooth(v - CGFloat(r0))
            let a = node(c0, r0)
            let b = node(c0 + 1, r0)
            let c = node(c0, r0 + 1)
            let d = node(c0 + 1, r0 + 1)
            func mix(_ p: CGFloat, _ q: CGFloat, _ s: CGFloat, _ t: CGFloat) -> UInt8 {
                let top = p + (q - p) * fu
                let bottom = s + (t - s) * fu
                return UInt8(min(max((top + (bottom - top) * fv) * 255.0, 0.0), 255.0))
            }
            let i = (y * width + x) * 4
            pixels[i] = mix(a.r, b.r, c.r, d.r)
            pixels[i + 1] = mix(a.g, b.g, c.g, d.g)
            pixels[i + 2] = mix(a.b, b.b, c.b, d.b)
        }
    }
    return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        return context?.makeImage()
    }
}

private func qrStudioDraw(_ image: CGImage, center: CGPoint, side: CGFloat, degrees: Double, alpha: CGFloat, in context: CGContext) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: CGFloat(degrees * Double.pi / 180.0))
    context.scaleBy(x: 1.0, y: -1.0)
    if alpha < 1.0 {
        context.setAlpha(alpha)
    }
    context.draw(image, in: CGRect(x: -side * 0.5, y: -side * 0.5, width: side, height: side))
    context.restoreGState()
}

private func qrStudioDrawPattern(_ items: [QrStudioExportPatternItem], scene: QrStudioExportScene, card: CGRect, size: CGSize, time: Double, wobble: CGFloat, in context: CGContext, image: (QrStudioExportPatternItem) -> CGImage?) {
    let scale = card.width / max(1.0, scene.screenCard.width)
    let squeeze = QrStudioEdgeSqueeze(size: size)
    for item in items {
        let motion = QrStudioExportMotion.wobble(hash: item.hash, at: time)
        let moved = CGPoint(x: item.point.x + motion.dx * wobble, y: item.point.y + motion.dy * wobble)
        let (point, k) = squeeze.apply(QrStudioExportLayout.map(moved, screenCard: scene.screenCard, card: card))
        let alpha = squeeze.alpha(k)
        guard alpha > 0.0, let picture = image(item) else {
            continue
        }
        qrStudioDraw(picture, center: point, side: item.side * scale * k, degrees: item.degrees + motion.degrees * Double(wobble), alpha: CGFloat(alpha), in: context)
    }
}

func qrStudioDrawExportFrame(_ scene: QrStudioExportScene, canvas: QrStudioExportCanvas, time: Double, in context: CGContext) {
    let size = canvas.size
    let pixel = canvas.pixelSize
    context.saveGState()
    context.translateBy(x: 0.0, y: pixel.height)
    context.scaleBy(x: pixel.width / size.width, y: -pixel.height / size.height)
    context.interpolationQuality = .high
    let card = QrStudioExportLayout.cardRect(canvas: size, cardSize: scene.screenCard.size, screenSize: scene.screenSize, screenCard: scene.screenCard)
    let bounds = CGRect(origin: CGPoint(), size: size)

    switch scene.background {
    case let .mesh(colors):
        if let mesh = qrStudioMeshImage(colors: colors, width: 72, height: 128) {
            context.saveGState()
            context.translateBy(x: 0.0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(mesh, in: bounds)
            context.restoreGState()
        }
    case let .image(image):
        let imageSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
        let fill = max(size.width / imageSize.width, size.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
        context.saveGState()
        context.translateBy(x: 0.0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(x: (size.width - drawSize.width) * 0.5, y: (size.height - drawSize.height) * 0.5, width: drawSize.width, height: drawSize.height))
        context.restoreGState()
    case let .emoji(colors, stickers, items):
        if let mesh = qrStudioMeshImage(colors: colors, width: 72, height: 128) {
            context.saveGState()
            context.translateBy(x: 0.0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(mesh, in: bounds)
            context.restoreGState()
        }
        qrStudioDrawPattern(items, scene: scene, card: card, size: size, time: time, wobble: 1.0, in: context, image: { item in
            guard case let .sticker(index) = item.content, index >= 0, index < stickers.count else {
                return nil
            }
            return stickers[index].image(phase: QrStudioExportMotion.phase(hash: item.hash), at: time)
        })
    case let .gift(inner, outer, symbol, model, items):
        context.setFillColor(outer.uiColor.cgColor)
        context.fill(bounds)
        let scale = card.width / max(1.0, scene.screenCard.width)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [inner.uiColor.cgColor, outer.uiColor.cgColor] as CFArray, locations: [0.0, 1.0]) {
            let center = QrStudioExportLayout.map(CGPoint(x: scene.screenSize.width * 0.5, y: scene.screenSize.height * 0.5), screenCard: scene.screenCard, card: card)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: 500.0 * scale, options: [.drawsAfterEndLocation])
        }
        qrStudioDrawPattern(items.filter { $0.content == .symbol }, scene: scene, card: card, size: size, time: time, wobble: 0.5, in: context, image: { _ in
            return symbol
        })
        qrStudioDrawPattern(items.filter { $0.content == .model }, scene: scene, card: card, size: size, time: time, wobble: 1.0, in: context, image: { item in
            return model?.image(phase: QrStudioExportMotion.phase(hash: item.hash), at: time)
        })
    }

    let k = card.width / max(1.0, scene.screenCard.width)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0.0, height: -12.0 * k * canvas.scale), blur: 22.0 * k * canvas.scale, color: UIColor.black.withAlphaComponent(scene.isLight ? 0.12 : 0.08).cgColor)
    context.translateBy(x: card.minX, y: card.maxY)
    context.scaleBy(x: 1.0, y: -1.0)
    context.draw(scene.card, in: CGRect(origin: CGPoint(), size: card.size))
    context.restoreGState()
    context.restoreGState()
}

func qrStudioExportImage(_ scene: QrStudioExportScene, canvas: QrStudioExportCanvas) -> UIImage? {
    let pixel = canvas.pixelSize
    guard let context = CGContext(data: nil, width: Int(pixel.width), height: Int(pixel.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
        return nil
    }
    qrStudioDrawExportFrame(scene, canvas: canvas, time: 0.0, in: context)
    return context.makeImage().map { UIImage(cgImage: $0) }
}
