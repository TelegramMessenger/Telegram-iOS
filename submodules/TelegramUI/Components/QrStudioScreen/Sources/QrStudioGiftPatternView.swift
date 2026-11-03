import Foundation
import UIKit
import Metal
import MetalKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MetalEngine
import AnimationCache
import EmojiTextAttachmentView
import GenerateStickerPlaceholderImage

private final class QrStudioGiftSymbolsLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?

    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        init?(device: MTLDevice) {
            guard let library = qrStudioMetalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "qrGiftSymbolVertex"), let fragmentFunction = library.makeFunction(name: "qrGiftSymbolFragment") else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    static let instanceStride = 6
    static let maxInstances = 1024

    var renderSpec: RenderLayerSpec?
    var texture: MTLTexture?
    var placeholderTexture: MTLTexture?
    var textureMix: Float = 1.0
    var uniforms: [Float] = Array(repeating: 0.0, count: 16)
    var instanceCount: Int = 0
    private let instanceBuffer: SharedBuffer?

    override init() {
        self.instanceBuffer = MetalEngine.shared.sharedBuffer(spec: BufferSpec(length: QrStudioGiftSymbolsLayer.maxInstances * QrStudioGiftSymbolsLayer.instanceStride * MemoryLayout<Float>.size))

        super.init()

        self.isOpaque = false
    }

    override init(layer: Any) {
        self.instanceBuffer = nil

        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setInstances(_ values: [Float]) {
        guard let instanceBuffer = self.instanceBuffer else {
            return
        }
        let count = min(values.count / QrStudioGiftSymbolsLayer.instanceStride, QrStudioGiftSymbolsLayer.maxInstances)
        self.instanceCount = count
        guard count > 0 else {
            return
        }
        values.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                memcpy(instanceBuffer.buffer.contents(), baseAddress, count * QrStudioGiftSymbolsLayer.instanceStride * MemoryLayout<Float>.size)
            }
        }
    }

    func update(context: MetalEngineSubjectContext) {
        guard let renderSpec = self.renderSpec, let instanceBuffer = self.instanceBuffer else {
            return
        }
        let texture = self.texture ?? self.placeholderTexture
        let placeholderTexture = self.placeholderTexture ?? texture
        var textureMix: Float = self.texture == nil ? 0.0 : (self.placeholderTexture == nil ? 1.0 : self.textureMix)
        let uniforms = self.uniforms
        let instanceCount = self.instanceCount
        context.renderToLayer(spec: renderSpec, state: RenderState.self, layer: self, commands: { encoder, placement in
            guard let texture, let placeholderTexture, instanceCount > 0 else {
                return
            }
            let effectiveRect = placement.effectiveRect
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)

            var uniforms = uniforms
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Float>.size * 16, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Float>.size * 16, index: 1)
            encoder.setVertexBuffer(instanceBuffer.buffer, offset: 0, index: 2)
            encoder.setFragmentBytes(&textureMix, length: MemoryLayout<Float>.size, index: 2)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentTexture(placeholderTexture, index: 1)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: instanceCount)
        })
    }
}

private func qrStudioFraction(_ value: Double) -> Double {
    return value - floor(value)
}

final class QrStudioGiftPatternView: UIView, QrStudioBackgroundContent {
    private struct Spot {
        var point: CGPoint
        var side: CGFloat
        var angle: Double
        var hash: Double
        var key: Int64
    }

    private static let velocity = CGVector(dx: -2.5, dy: -4.0)
    private static let symbols = QrStudioLattice(dx: 44.0, dy: 38.0, velocity: QrStudioGiftPatternView.velocity, lag: 0.03 ... 0.16, orbit: 2.0 ... 7.0)
    private static let stickers = QrStudioLattice(dx: 170.0, dy: 150.0, velocity: QrStudioGiftPatternView.velocity, lag: 0.06 ... 0.2, orbit: 5.0 ... 12.0)
    private static let modelSide: CGFloat = 94.0

    private let context: AccountContext
    private let gift: QrStudioGift
    private let gradientLayer = CAGradientLayer()
    private let symbolsLayer = QrStudioGiftSymbolsLayer()
    private let modelsLayer = SimpleLayer()
    private var modelAnimation: QrStudioPhasedAnimation?
    private var modelLayers: [Int64: SimpleLayer] = [:]
    private var symbolDisposable: Disposable?

    private var size = CGSize()
    private var revealCenter = CGPoint()
    private var bornAt: Double = -10.0
    private var shownAt: Double?
    private var symbolTextureAt: Double?
    private var isVisible = true

    let wantsFullFrameRate: Bool = true
    static func canonicalExportItems(size: CGSize) -> [QrStudioExportPatternItem] {
        let squeeze = QrStudioEdgeSqueeze(size: size)
        let drift = QrStudioDrift()
        let tilt = SIMD2<Double>(0.0, 0.0)
        let spots = QrStudioGiftPatternView.stickers.cells(in: size, at: 0.0, offset: CGSize(), margin: squeeze.margin + 60.0, drift: drift, tilt: tilt).map(QrStudioGiftPatternView.spot)
        var items: [QrStudioExportPatternItem] = []
        for spot in spots {
            items.append(QrStudioExportPatternItem(content: .model, point: CGPoint(x: spot.point.x, y: spot.point.y + CGFloat(3.0 * sin(spot.hash * 2.0 * .pi))), side: spot.side, degrees: spot.angle, hash: spot.hash))
        }
        for cell in QrStudioGiftPatternView.symbols.cells(in: size, at: 0.0, offset: CGSize(), margin: squeeze.margin, drift: drift, tilt: tilt) {
            let h = cell.hash
            guard qrStudioFraction(h * 23.17) > 0.24 else {
                continue
            }
            let raw = CGPoint(x: cell.point.x + CGFloat(qrStudioFraction(h * 3.1) - 0.5) * 38.0, y: cell.point.y + CGFloat(qrStudioFraction(h * 6.7) - 0.5) * 32.0)
            if spots.contains(where: { hypot($0.point.x - raw.x, $0.point.y - raw.y) < $0.side * 0.66 }) {
                continue
            }
            let h2 = qrStudioFraction(h * 7.31)
            let h5 = qrStudioFraction(h * 41.9)
            items.append(QrStudioExportPatternItem(content: .symbol, point: raw, side: CGFloat(21.0 * (0.55 + 0.75 * h5 * h5)), degrees: (h2 - 0.5) * 70.0, hash: h))
        }
        return items
    }

    init(context: AccountContext, gift: QrStudioGift) {
        self.context = context
        self.gift = gift

        super.init(frame: CGRect())

        self.clipsToBounds = true
        self.backgroundColor = gift.outer.uiColor

        self.gradientLayer.type = .radial
        self.gradientLayer.colors = [gift.inner.uiColor.cgColor, gift.outer.uiColor.cgColor]
        self.layer.addSublayer(self.gradientLayer)
        self.layer.addSublayer(self.symbolsLayer)
        self.layer.addSublayer(self.modelsLayer)

        let pattern = gift.patternColor
        let light = gift.text
        self.symbolsLayer.uniforms[0] = Float(pattern.r)
        self.symbolsLayer.uniforms[1] = Float(pattern.g)
        self.symbolsLayer.uniforms[2] = Float(pattern.b)
        self.symbolsLayer.uniforms[3] = 1.0
        self.symbolsLayer.uniforms[4] = Float(light.r)
        self.symbolsLayer.uniforms[5] = Float(light.g)
        self.symbolsLayer.uniforms[6] = Float(light.b)
        self.symbolsLayer.uniforms[7] = 1.0

        let animation = QrStudioPhasedAnimation(context: context, file: gift.model, pointSize: CGSize(width: QrStudioGiftPatternView.modelSide, height: QrStudioGiftPatternView.modelSide), hostLayer: self.layer, placeholderColor: gift.patternColor.uiColor.withAlphaComponent(0.55))
        if animation.hasPlaceholder || animation.hasFrames {
            self.shownAt = QrStudioClock.now
        } else {
            animation.onFirstFrame = { [weak self] in
                self?.shownAt = QrStudioClock.now
            }
        }
        self.modelAnimation = animation

        let patternFile = gift.pattern
        let symbolSize = CGSize(width: 96.0, height: 96.0)
        if let data = patternFile.immediateThumbnailData, let placeholder = generateStickerPlaceholderImage(data: data, size: symbolSize, scale: 1.0, imageSize: patternFile.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: .white)?.cgImage {
            self.symbolsLayer.placeholderTexture = try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: placeholder, options: [.SRGB: false as NSNumber, .generateMipmaps: true as NSNumber])
        }
        self.symbolDisposable = context.animationRenderer.loadFirstFrameAsImage(
            cache: context.animationCache,
            itemId: patternFile.resource.id.stringRepresentation,
            size: symbolSize,
            fetch: animationCacheFetchFile(context: context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: patternFile), resource: patternFile.resource), type: AnimationCacheAnimationType(file: patternFile), keyframeOnly: false, customColor: .white),
            completion: { [weak self] image in
                Queue.mainQueue().async {
                    guard let self, let image else {
                        return
                    }
                    self.symbolsLayer.texture = try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: image, options: [.SRGB: false as NSNumber, .generateMipmaps: true as NSNumber])
                    self.symbolTextureAt = QrStudioClock.now
                }
            }
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.symbolDisposable?.dispose()
    }

    func update(size: CGSize, revealCenter: CGPoint) {
        self.revealCenter = revealCenter
        guard self.size != size, size.width > 0.0, size.height > 0.0 else {
            return
        }
        self.size = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let frame = CGRect(origin: CGPoint(), size: size)
        self.gradientLayer.frame = frame
        self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.gradientLayer.endPoint = CGPoint(x: 0.5 + 500.0 / size.width, y: 0.5 + 500.0 / size.height)
        self.symbolsLayer.frame = frame
        self.modelsLayer.frame = frame
        CATransaction.commit()
        self.symbolsLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(size.width * UIScreenScale), height: Int(size.height * UIScreenScale)), prefersDedicatedSurface: true)
    }

    func beginReveal(at time: Double) {
        self.bornAt = time
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        self.modelAnimation?.setPaused(!isVisible)
        if !isVisible {
            self.symbolsLayer.releaseSurface()
        }
    }

    private static func spot(_ cell: QrStudioLattice.Cell) -> Spot {
        let h = cell.hash
        return Spot(
            point: CGPoint(x: cell.point.x + CGFloat(qrStudioFraction(h * 3.7) - 0.5) * 76.0, y: cell.point.y + CGFloat(qrStudioFraction(h * 5.3) - 0.5) * 64.0),
            side: 62.0 + 32.0 * CGFloat(qrStudioFraction(h * 11.9)),
            angle: (qrStudioFraction(h * 17.3) - 0.5) * 22.0,
            hash: h,
            key: (Int64(cell.r) << 32) | Int64(UInt32(truncatingIfNeeded: cell.c))
        )
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
        guard self.isVisible, self.size.width > 0.0, self.size.height > 0.0 else {
            return
        }
        let size = self.size
        let squeeze = QrStudioEdgeSqueeze(size: size)
        let offset = pan.offset(at: time)
        let since = time - self.bornAt

        let spots = QrStudioGiftPatternView.stickers.cells(in: size, at: time, offset: offset, margin: squeeze.margin + 60.0, drift: drift, tilt: tilt).map(QrStudioGiftPatternView.spot)

        var instances: [Float] = []
        instances.reserveCapacity(400 * QrStudioGiftSymbolsLayer.instanceStride)
        for cell in QrStudioGiftPatternView.symbols.cells(in: size, at: time, offset: offset, margin: squeeze.margin, drift: drift, tilt: tilt) {
            let h = cell.hash
            guard qrStudioFraction(h * 23.17) > 0.24 else {
                continue
            }
            let raw = CGPoint(x: cell.point.x + CGFloat(qrStudioFraction(h * 3.1) - 0.5) * 38.0, y: cell.point.y + CGFloat(qrStudioFraction(h * 6.7) - 0.5) * 32.0)
            var isCovered = false
            for spot in spots {
                if hypot(spot.point.x - raw.x, spot.point.y - raw.y) < spot.side * 0.66 {
                    isCovered = true
                    break
                }
            }
            if isCovered {
                continue
            }
            let (point, k) = squeeze.apply(raw)
            let alpha = squeeze.alpha(k)
            let enter = QrStudioReveal.entrance(point, center: self.revealCenter, since: since)
            guard alpha > 0.0, enter > 0.01 else {
                continue
            }
            let h2 = qrStudioFraction(h * 7.31)
            let h5 = qrStudioFraction(h * 41.9)
            let side = 21.0 * (0.55 + 0.75 * h5 * h5) * Double(k) * enter
            instances.append(Float(point.x))
            instances.append(Float(point.y))
            instances.append(Float(side))
            instances.append(Float((h2 - 0.5) * 70.0 * .pi / 180.0))
            instances.append(Float(alpha))
            instances.append(Float(h))
        }
        self.symbolsLayer.setInstances(instances)
        if let symbolTextureAt = self.symbolTextureAt {
            self.symbolsLayer.textureMix = Float(QrStudioCurve.smooth(QrStudioCurve.clamp01((time - symbolTextureAt) / 0.25)))
        }

        let strength = QrStudioCurve.smooth(QrStudioCurve.clamp01(hypot(tilt.x, tilt.y) / 0.14))
        self.symbolsLayer.uniforms[8] = Float(size.width)
        self.symbolsLayer.uniforms[9] = Float(size.height)
        self.symbolsLayer.uniforms[10] = Float(self.revealCenter.x)
        self.symbolsLayer.uniforms[11] = Float(self.revealCenter.y)
        self.symbolsLayer.uniforms[12] = Float(time.truncatingRemainder(dividingBy: 3600.0))
        self.symbolsLayer.uniforms[13] = Float(min(since, 100.0))
        self.symbolsLayer.uniforms[14] = Float(0.5 + tilt.x * 1.6 + tilt.y * 1.2)
        self.symbolsLayer.uniforms[15] = Float(strength)
        self.symbolsLayer.setNeedsUpdate()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var usedKeys = Set<Int64>()
        if let shownAt = self.shownAt, let modelAnimation = self.modelAnimation {
            let appear = QrStudioCurve.clamp01((time - shownAt) / 0.4)
            let modelSide = QrStudioGiftPatternView.modelSide
            for spot in spots {
                let (point, k) = squeeze.apply(CGPoint(x: spot.point.x, y: spot.point.y + CGFloat(3.0 * sin(time * 0.35 + spot.hash * 2.0 * .pi))))
                let alpha = squeeze.alpha(k) * appear
                let enter = QrStudioReveal.entrance(point, center: self.revealCenter, since: since)
                guard alpha > 0.0, enter > 0.01 else {
                    continue
                }
                usedKeys.insert(spot.key)
                let modelLayer: SimpleLayer
                if let current = self.modelLayers[spot.key] {
                    modelLayer = current
                } else {
                    modelLayer = SimpleLayer()
                    modelLayer.bounds = CGRect(x: 0.0, y: 0.0, width: modelSide, height: modelSide)
                    self.modelsLayer.addSublayer(modelLayer)
                    self.modelLayers[spot.key] = modelLayer
                    modelAnimation.attach(modelLayer, group: qrStudioPhaseGroup(hash: spot.hash))
                }
                let scale = spot.side * k * CGFloat(enter) / modelSide
                modelLayer.position = point
                modelLayer.opacity = Float(alpha)
                modelLayer.transform = CATransform3DRotate(CATransform3DMakeScale(scale, scale, 1.0), CGFloat(spot.angle * .pi / 180.0), 0.0, 0.0, 1.0)
            }
        } else if let modelAnimation = self.modelAnimation, self.modelLayers.isEmpty {
            let probeKey: Int64 = Int64.min
            let probeLayer = SimpleLayer()
            probeLayer.isHidden = true
            self.modelsLayer.addSublayer(probeLayer)
            self.modelLayers[probeKey] = probeLayer
            modelAnimation.attach(probeLayer, group: 0)
            usedKeys.insert(probeKey)
        } else {
            usedKeys.formUnion(self.modelLayers.keys)
        }
        for (key, modelLayer) in self.modelLayers where !usedKeys.contains(key) {
            self.modelAnimation?.detach(modelLayer)
            modelLayer.removeFromSuperlayer()
            self.modelLayers.removeValue(forKey: key)
        }
        CATransaction.commit()
    }
}
