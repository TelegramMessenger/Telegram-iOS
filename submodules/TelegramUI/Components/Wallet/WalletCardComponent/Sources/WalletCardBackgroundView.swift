import Foundation
import CoreMotion
import simd
import SwiftSignalKit
import Display
import Metal
import MetalKit
import MetalEngine
import UIKit

public final class WalletCardBackgroundMotion {
    public static let shared = WalletCardBackgroundMotion()

    private(set) var surfaceTilt = SIMD2<Double>(repeating: 0.0)
    var currentRotation: Double {
        return self.smoothedRotation
    }

    private static let lightDirection = simd_normalize(SIMD3<Double>(-0.5, 0.5, 1.0))

    private let motionManager = CMMotionManager()
    private var subscriberCount = 0
    private var startTime: TimeInterval = 0.0
    private var referenceAttitude: simd_quatd?
    private var interfaceOrientation: UIInterfaceOrientation?
    private var previousAngle: Double?
    private var targetRotation: Double = 0.0
    private var smoothedRotation: Double = 0.0
    private var lastUpdateTime: CFTimeInterval?
    private var isFrameCached = false

    private init() {
    }

    public func subscribe() -> Disposable {
        self.subscriberCount += 1
        if self.subscriberCount == 1 && self.motionManager.isDeviceMotionAvailable {
            self.startTime = ProcessInfo.processInfo.systemUptime
            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            self.motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        }
        return ActionDisposable { [weak self] in
            if Thread.isMainThread {
                self?.unsubscribe()
            } else {
                Queue.mainQueue().async { self?.unsubscribe() }
            }
        }
    }

    private func unsubscribe() {
        self.subscriberCount -= 1
        guard self.subscriberCount == 0 else { return }
        self.motionManager.stopDeviceMotionUpdates()
        self.referenceAttitude = nil
        self.interfaceOrientation = nil
        self.previousAngle = nil
        self.surfaceTilt = .zero
        self.targetRotation = self.smoothedRotation
        self.lastUpdateTime = nil
        self.isFrameCached = false
    }

    public func rotation(at time: CFTimeInterval, orientation: UIInterfaceOrientation) -> CGFloat {
        if self.isFrameCached {
            return CGFloat(self.smoothedRotation)
        }
        guard self.motionManager.isDeviceMotionActive,
              let motion = self.motionManager.deviceMotion, motion.timestamp >= self.startTime else {
            return CGFloat(self.smoothedRotation)
        }
        // The shared display link calls all clients synchronously. Reuse one result for that batch.
        self.isFrameCached = true
        Queue.mainQueue().async { [weak self] in
            self?.isFrameCached = false
        }
        let deltaTime = min(0.1, max(0.0, self.lastUpdateTime.map { time - $0 } ?? 0.0))
        self.lastUpdateTime = time

        let quaternion = motion.attitude.quaternion
        let attitude = simd_normalize(simd_quatd(ix: quaternion.x, iy: quaternion.y, iz: quaternion.z, r: quaternion.w))
        let referenceAttitude = self.referenceAttitude ?? attitude
        self.referenceAttitude = referenceAttitude

        // Keep the light fixed in the initial reference frame, then project it onto the screen.
        let direction = simd_act(attitude.conjugate * referenceAttitude, Self.lightDirection)
        func screenVector(_ vector: SIMD3<Double>) -> SIMD2<Double> {
            switch orientation {
            case .landscapeLeft:
                return SIMD2<Double>(vector.y, vector.x)
            case .landscapeRight:
                return SIMD2<Double>(-vector.y, -vector.x)
            case .portraitUpsideDown:
                return SIMD2<Double>(-vector.x, vector.y)
            default:
                return SIMD2<Double>(vector.x, -vector.y)
            }
        }
        let screenDirection = screenVector(direction)
        let normal = simd_act(referenceAttitude.conjugate * attitude, SIMD3<Double>(0.0, 0.0, 1.0))
        let screenNormal = screenVector(normal)
        let forward = max(normal.z, 0.15)
        self.surfaceTilt = SIMD2<Double>(atan2(-screenNormal.y, forward), atan2(screenNormal.x, forward))

        if self.interfaceOrientation != orientation {
            self.interfaceOrientation = orientation
            self.previousAngle = nil
            self.targetRotation = self.smoothedRotation
        }
        if simd_length(screenDirection) >= 0.1 {
            let angle = atan2(screenDirection.y, screenDirection.x)
            if let previousAngle = self.previousAngle {
                let delta = angle - previousAngle
                self.targetRotation += atan2(sin(delta), cos(delta))
            }
            self.previousAngle = angle
        }
        self.smoothedRotation += (self.targetRotation - self.smoothedRotation) * (1.0 - exp(-deltaTime / 0.1))
        return CGFloat(self.smoothedRotation)
    }
}

struct WalletCardBackgroundRotation {
    private(set) var value = WalletCardBackgroundMotion.shared.currentRotation
    private var transition: (time: CFTimeInterval, offset: Double)?

    mutating func reset(to rotation: Double) {
        self.value = rotation
        self.transition = nil
    }

    mutating func resume(at time: CFTimeInterval, to rotation: Double) {
        let delta = self.value - rotation
        self.transition = (time, atan2(sin(delta), cos(delta)))
    }

    mutating func update(at time: CFTimeInterval, to rotation: Double) {
        if let transition = self.transition {
            let progress = min(1.0, max(0.0, (time - transition.time) / 0.22))
            let remaining = 1.0 - progress
            self.value = rotation + transition.offset * remaining * remaining * remaining
            if progress >= 1.0 {
                self.transition = nil
            }
        } else {
            self.value = rotation
        }
    }
}

struct WalletCardProjectedQuad {
    var bottomLeft = SIMD4<Float>(-1.0, -1.0, 0.0, 1.0)
    var bottomRight = SIMD4<Float>(1.0, -1.0, 0.0, 1.0)
    var topLeft = SIMD4<Float>(-1.0, 1.0, 0.0, 1.0)
    var topRight = SIMD4<Float>(1.0, 1.0, 0.0, 1.0)
}

struct WalletCardQRChip {
    let frame: CGRect
    let alpha: CGFloat
    let blurRadius: CGFloat
}

private final class WalletCardBundleMarker: NSObject {
}

private var walletCardMetalLibraryValue: MTLLibrary?

func walletCardMetalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let walletCardMetalLibraryValue {
        return walletCardMetalLibraryValue
    }

    let containingBundle = Bundle(for: WalletCardBundleMarker.self)
    guard
        let bundlePath = containingBundle.path(
            forResource: "WalletCardComponentMetalSourcesBundle",
            ofType: "bundle"
        ),
        let resourceBundle = Bundle(path: bundlePath),
        let library = try? device.makeDefaultLibrary(bundle: resourceBundle)
    else {
        return nil
    }

    walletCardMetalLibraryValue = library
    return library
}

struct WalletCardLens {
    let center: CGPoint
    let hull: [CGPoint]
    let strength: CGFloat
    let spin: Float
}

private final class WalletCardMetalLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private struct VertexUniforms {
        var front = WalletCardProjectedQuad()
        var back = WalletCardProjectedQuad()
        var slices: Int32 = 0
    }

    private struct LensUniforms {
        var center = SIMD2<Float>(0.0, 0.0)
        var strength: Float = 0.0
        var spin: Float = 0.0
        var count: Int32 = 0
        var bounds = SIMD4<Float>(repeating: 0.0)
    }

    private struct FragmentUniforms {
        var time: Float = 0.0
        var reflectionRotation: Float = 0.0
        var highlightTiltX: Float = 0.0
        var highlightTiltY: Float = 0.0
        var cornerRadius: Float = 0.0
        var surfaceTilt = SIMD2<Float>(repeating: 0.0)
        var cardSize = SIMD2<Float>(repeating: 1.0)
        var qrRect = SIMD4<Float>(repeating: 0.0)
        // Chip opacity, blur radius in points, and whether the face has a bevel.
        var qrEffects = SIMD4<Float>(repeating: 0.0)
    }

    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        required init?(device: MTLDevice) {
            guard
                let library = walletCardMetalLibrary(device: device),
                let vertexFunction = library.makeFunction(name: "walletCardBackgroundVertex"),
                let fragmentFunction = library.makeFunction(name: "walletCardBackgroundFragment")
            else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.label = "Wallet Card Background Pipeline"
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

    private final class ChipState: ComputeState {
        let render: MTLRenderPipelineState
        let blur: MTLComputePipelineState

        required init?(device: MTLDevice) {
            guard let library = walletCardMetalLibrary(device: device),
                  let vertex = library.makeFunction(name: "walletChipVertex"),
                  let fragment = library.makeFunction(name: "walletChipFragment"),
                  let blur = library.makeFunction(name: "walletChipBlur") else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float
            guard let render = try? device.makeRenderPipelineState(descriptor: descriptor),
                  let compute = try? device.makeComputePipelineState(function: blur) else { return nil }
            self.render = render
            self.blur = compute
        }
    }

    private struct ChipFrame {
        let texture: MTLTexture
        let rect: SIMD4<Float>
    }

    private var chipTextures: [MTLTexture] = []

    var internalData: MetalEngineSubjectInternalData?

    private var starsTexture: MTLTexture?
    private var noiseTexture: MTLTexture?
    private var qrTexture: MTLTexture?
    private var vertexUniforms = VertexUniforms()
    var giftStyle = WalletCardStyleUniforms()
    private var fragmentUniforms = FragmentUniforms()
    private var lens: WalletCardLens?

    private static let sharedQRTexture: MTLTexture? = {
        guard let image = WalletCardTextures.qrImage().cgImage else { return nil }
        return try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: image, options: [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft
        ])
    }()

    var hasQRChip: Bool {
        return self.qrTexture != nil && self.fragmentUniforms.qrRect.z > 0.0
    }

    override init() {
        let textureLoader = MTKTextureLoader(device: MetalEngine.shared.device)
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft,
        ]
        if let starsImage = WalletCardTextures.starsImage().cgImage {
            self.starsTexture = try? textureLoader.newTexture(cgImage: starsImage, options: textureOptions)
        }
        if let noiseImage = WalletCardTextures.noiseImage().cgImage {
            self.noiseTexture = try? textureLoader.newTexture(cgImage: noiseImage, options: textureOptions)
        }

        super.init()

        self.isOpaque = false
        self.backgroundColor = nil
        self.contentsScale = UIScreenScale
        self.contentsGravity = .resize
        self.masksToBounds = false
    }

    override init(layer: Any) {
        super.init(layer: layer)

        if let layer = layer as? WalletCardMetalLayer {
            self.starsTexture = layer.starsTexture
            self.noiseTexture = layer.noiseTexture
            self.qrTexture = layer.qrTexture
            self.vertexUniforms = layer.vertexUniforms
            self.fragmentUniforms = layer.fragmentUniforms
            self.lens = layer.lens
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        time: Double,
        reflectionRotation: Double,
        highlightTiltX: Double,
        highlightTiltY: Double,
        surfaceTiltX: Double,
        surfaceTiltY: Double,
        cardSize: CGSize,
        cornerRadius: CGFloat,
        quad: WalletCardProjectedQuad,
        backQuad: WalletCardProjectedQuad?,
        qrChip: WalletCardQRChip?
    ) {
        self.vertexUniforms = VertexUniforms(front: quad, back: backQuad ?? quad)
        if qrChip != nil {
            self.qrTexture = Self.sharedQRTexture
        }
        self.fragmentUniforms = FragmentUniforms(
            time: Float(time),
            reflectionRotation: Float(reflectionRotation.truncatingRemainder(dividingBy: 2.0 * .pi)),
            highlightTiltX: Float(highlightTiltX),
            highlightTiltY: Float(highlightTiltY),
            cornerRadius: Float(cornerRadius),
            surfaceTilt: SIMD2<Float>(Float(surfaceTiltX), Float(surfaceTiltY)),
            cardSize: SIMD2<Float>(Float(max(cardSize.width, 1.0)), Float(max(cardSize.height, 1.0)))
        )
        self.fragmentUniforms.qrEffects.z = backQuad == nil ? 0.0 : 1.0
        if let qrChip, self.qrTexture != nil, !qrChip.frame.isEmpty {
            self.fragmentUniforms.qrRect = SIMD4<Float>(Float(qrChip.frame.minX), Float(qrChip.frame.minY), Float(qrChip.frame.width), Float(qrChip.frame.height))
            self.fragmentUniforms.qrEffects.x = Float(max(0.0, min(1.0, qrChip.alpha)))
            self.fragmentUniforms.qrEffects.y = Float(max(0.0, qrChip.blurRadius))
        }
        self.setNeedsUpdate()
    }

    private func sliceCount(drawableSize: CGSize) -> Int32 {
        func pixels(_ front: SIMD4<Float>, _ back: SIMD4<Float>) -> Float {
            let a = SIMD2<Float>(front.x, front.y) / max(front.w, 0.0001)
            let b = SIMD2<Float>(back.x, back.y) / max(back.w, 0.0001)
            return simd_length((a - b) * 0.5 * SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height)))
        }
        let front = self.vertexUniforms.front
        let back = self.vertexUniforms.back
        let shift = max(max(pixels(front.topLeft, back.topLeft), pixels(front.topRight, back.topRight)),
            max(pixels(front.bottomLeft, back.bottomLeft), pixels(front.bottomRight, back.bottomRight)))
        guard shift > 0.35 else { return 0 }
        return Int32(min(24.0, ceil(shift) + 1.0))
    }

    func updateLens(_ lens: WalletCardLens?) {
        if self.lens == nil && lens == nil { return }
        self.lens = lens
        self.setNeedsUpdate()
    }

    func update(context: MetalEngineSubjectContext) {
        guard
            !self.bounds.isEmpty,
            let starsTexture = self.starsTexture,
            let noiseTexture = self.noiseTexture
        else {
            return
        }

        let displayScale = UIScreenScale
        let drawableSize = CGSize(
            width: self.bounds.width * displayScale,
            height: self.bounds.height * displayScale
        )
        var currentVertexUniforms = self.vertexUniforms
        currentVertexUniforms.slices = self.sliceCount(drawableSize: drawableSize)
        let currentGiftStyle = self.giftStyle
        let currentFragmentUniforms = self.fragmentUniforms
        let qrTexture = self.qrTexture ?? noiseTexture

        let chipFrame = context.compute(state: ChipState.self, commands: { [weak self] commandBuffer, state -> ChipFrame? in
            guard let self, currentFragmentUniforms.qrEffects.x > 0,
                  currentFragmentUniforms.qrEffects.y > 0.01,
                  currentFragmentUniforms.qrRect.z > 0, currentFragmentUniforms.qrRect.w > 0 else {
                self?.chipTextures.removeAll()
                return nil
            }
            let scale: Float = 2
            let padding = ceil(max(8, currentFragmentUniforms.qrEffects.y) * 3) + 2
            let width = Int(ceil((currentFragmentUniforms.qrRect.z + padding * 2) * scale))
            let height = Int(ceil((currentFragmentUniforms.qrRect.w + padding * 2) * scale))
            if self.chipTextures.count != 3 || self.chipTextures.first?.width != width || self.chipTextures.first?.height != height {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                    width: width, height: height, mipmapped: false)
                descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
                descriptor.storageMode = .private
                self.chipTextures = (0..<3).compactMap { _ in MetalEngine.shared.device.makeTexture(descriptor: descriptor) }
            }
            guard self.chipTextures.count == 3 else { return nil }
            let textures = self.chipTextures
            var rect = SIMD4<Float>(currentFragmentUniforms.qrRect.x - padding,
                currentFragmentUniforms.qrRect.y - padding, Float(width) / scale, Float(height) / scale)
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = textures[0]
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            guard let render = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
            render.label = "Wallet chip texture"
            render.setRenderPipelineState(state.render)
            var uniforms = currentFragmentUniforms
            var style = currentGiftStyle
            render.setFragmentBytes(&uniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)
            render.setFragmentBytes(&style, length: MemoryLayout<WalletCardStyleUniforms>.stride, index: 1)
            render.setFragmentBytes(&rect, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
            render.setFragmentTexture(noiseTexture, index: 0)
            render.setFragmentTexture(qrTexture, index: 1)
            render.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            render.endEncoding()
            for index in 0..<2 {
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
                encoder.label = index == 0 ? "Wallet chip horizontal blur" : "Wallet chip vertical blur"
                encoder.setComputePipelineState(state.blur)
                encoder.setTexture(textures[index], index: 0)
                encoder.setTexture(textures[index + 1], index: 1)
                var sigma = currentFragmentUniforms.qrEffects.y * scale
                var direction = index == 0 ? SIMD2<Int32>(1, 0) : SIMD2<Int32>(0, 1)
                encoder.setBytes(&sigma, length: MemoryLayout<Float>.size, index: 0)
                encoder.setBytes(&direction, length: MemoryLayout<SIMD2<Int32>>.stride, index: 1)
                let w = state.blur.threadExecutionWidth
                let h = max(1, min(8, state.blur.maxTotalThreadsPerThreadgroup / w))
                encoder.dispatchThreadgroups(MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
                encoder.endEncoding()
            }
            return ChipFrame(texture: textures[2], rect: rect)
        })

        context.renderToLayer(
            spec: RenderLayerSpec(
                size: RenderSize(
                    width: max(1, Int(ceil(drawableSize.width))),
                    height: max(1, Int(ceil(drawableSize.height)))
                )
            ),
            state: RenderState.self,
            layer: self,
            inputs: chipFrame,
            commands: { encoder, placement, chipFrame in
                let effectiveRect = placement.effectiveRect
                var rect = SIMD4<Float>(
                    Float(effectiveRect.minX),
                    Float(effectiveRect.minY),
                    Float(effectiveRect.width),
                    Float(effectiveRect.height)
                )
                var vertexUniforms = currentVertexUniforms
                var antialiasingParameters = SIMD4<Float>(
                    Float(drawableSize.width),
                    Float(drawableSize.height),
                    currentFragmentUniforms.cardSize.x * Float(displayScale),
                    currentFragmentUniforms.cardSize.y * Float(displayScale)
                )
                var fragmentUniforms = currentFragmentUniforms

                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setVertexBytes(
                    &vertexUniforms,
                    length: MemoryLayout<VertexUniforms>.stride,
                    index: 1
                )
                encoder.setVertexBytes(
                    &antialiasingParameters,
                    length: MemoryLayout<SIMD4<Float>>.size,
                    index: 2
                )
                encoder.setFragmentBytes(
                    &fragmentUniforms,
                    length: MemoryLayout<FragmentUniforms>.stride,
                    index: 0
                )
                var giftStyle = currentGiftStyle
                encoder.setFragmentBytes(&giftStyle, length: MemoryLayout<WalletCardStyleUniforms>.stride, index: 3)
                // Diamond compute operations precede compositing, so read its current silhouette here.
                var lensUniforms = LensUniforms()
                var hull = [SIMD2<Float>(0.0, 0.0)]
                if let lens = self.lens, lens.hull.count > 2, lens.strength > 0.001 {
                    let count = min(64, lens.hull.count)
                    hull = (0 ..< count).map { index in
                        let point = lens.hull[index * lens.hull.count / count]
                        return SIMD2<Float>(Float(point.x), Float(point.y))
                    }
                    var minPoint = hull[0]
                    var maxPoint = hull[0]
                    for point in hull {
                        minPoint = simd_min(minPoint, point)
                        maxPoint = simd_max(maxPoint, point)
                    }
                    lensUniforms = LensUniforms(
                        center: SIMD2<Float>(Float(lens.center.x), Float(lens.center.y)),
                        strength: Float(min(1.0, lens.strength)), spin: lens.spin, count: Int32(hull.count),
                        bounds: SIMD4(minPoint.x, minPoint.y, maxPoint.x, maxPoint.y)
                    )
                }
                encoder.setFragmentBytes(&lensUniforms, length: MemoryLayout<LensUniforms>.stride, index: 1)
                hull.withUnsafeBytes { bytes in
                    encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 2)
                }
                encoder.setFragmentTexture(starsTexture, index: 0)
                encoder.setFragmentTexture(noiseTexture, index: 1)
                encoder.setFragmentTexture(qrTexture, index: 2)
                encoder.setFragmentTexture(chipFrame?.texture ?? qrTexture, index: 3)
                var chipRect = chipFrame?.rect ?? .zero
                encoder.setFragmentBytes(&chipRect, length: MemoryLayout<SIMD4<Float>>.stride, index: 4)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4,
                    instanceCount: Int(vertexUniforms.slices) + 1)
            }
        )
    }
}

private final class WalletCardMetalView: UIView {
    override class var layerClass: AnyClass {
        return WalletCardMetalLayer.self
    }

    var metalLayer: WalletCardMetalLayer {
        return self.layer as! WalletCardMetalLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class WalletCardBackgroundView: UIView {
    func updateGiftStyle(_ value: WalletCardStyleUniforms) {
        self.metalView.metalLayer.giftStyle = value
        self.metalView.metalLayer.setNeedsUpdate()
    }

    static let projectionPadding: CGFloat = 56.0

    private let fallbackView = UIView()
    private let fallbackBaseGradient = CAGradientLayer()
    private let fallbackRadialGradient = CAGradientLayer()
    private let metalView = WalletCardMetalView()
    private var cardSize = CGSize.zero
    private var cornerRadius: CGFloat = 0.0
    private var currentTime = 0.0
    private var currentReflectionRotation = WalletCardBackgroundMotion.shared.currentRotation

    var displaysQRChip: Bool {
        return self.metalView.metalLayer.contents != nil && self.metalView.metalLayer.hasQRChip
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = false
        self.configureFallback()
        self.addSubview(self.metalView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutContent()
    }

    func update(cardSize: CGSize, cornerRadius: CGFloat) {
        self.cardSize = cardSize
        self.cornerRadius = cornerRadius
        self.layoutContent()
        self.renderStaticFrame(time: self.currentTime, reflectionRotation: self.currentReflectionRotation)
    }

    func updateFallbackTransform(_ transform: CATransform3D) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fallbackView.layer.transform = transform
        CATransaction.commit()
    }

    func updateLens(_ lens: WalletCardLens?) {
        self.metalView.metalLayer.updateLens(lens)
    }

    func render(
        time: Double,
        reflectionRotation: Double,
        highlightTiltX: Double,
        highlightTiltY: Double,
        surfaceTiltX: Double,
        surfaceTiltY: Double,
        quad: WalletCardProjectedQuad,
        backQuad: WalletCardProjectedQuad? = nil,
        qrChip: WalletCardQRChip? = nil
    ) {
        self.currentTime = time
        self.currentReflectionRotation = reflectionRotation
        // The fallback is an alternative to Metal, not a second background to
        // composite through the projected quad. Keeping it visible after the
        // engine has allocated its surface makes any transient uncovered area
        // look like a different card.
        self.fallbackView.isHidden = self.metalView.metalLayer.contents != nil
        self.metalView.metalLayer.update(
            time: time,
            reflectionRotation: reflectionRotation,
            highlightTiltX: highlightTiltX,
            highlightTiltY: highlightTiltY,
            surfaceTiltX: surfaceTiltX,
            surfaceTiltY: surfaceTiltY,
            cardSize: self.cardSize,
            cornerRadius: self.cornerRadius,
            quad: quad,
            backQuad: backQuad,
            qrChip: qrChip
        )
    }

    private func layoutContent() {
        let padding = WalletCardBackgroundView.projectionPadding
        self.fallbackView.bounds = CGRect(origin: .zero, size: self.cardSize)
        self.fallbackView.center = CGPoint(
            x: padding + self.cardSize.width * 0.5,
            y: padding + self.cardSize.height * 0.5
        )
        self.fallbackView.layer.cornerRadius = self.cornerRadius
        if #available(iOS 13.0, *) {
            self.fallbackView.layer.cornerCurve = .continuous
        }
        self.fallbackBaseGradient.frame = self.fallbackView.bounds
        self.fallbackRadialGradient.frame = self.fallbackView.bounds

        self.metalView.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: self.cardSize.width + padding * 2.0,
                height: self.cardSize.height + padding * 2.0
            )
        )
    }

    func renderStaticFrame(time: Double = 0.0, reflectionRotation: Double) {
        guard self.cardSize.width > 0.0, self.cardSize.height > 0.0 else {
            return
        }

        let padding = WalletCardBackgroundView.projectionPadding
        let paddedWidth = self.cardSize.width + padding * 2.0
        let paddedHeight = self.cardSize.height + padding * 2.0

        func clipPosition(_ point: CGPoint) -> SIMD4<Float> {
            return SIMD4<Float>(
                Float(((point.x + padding) / paddedWidth) * 2.0 - 1.0),
                Float(1.0 - ((point.y + padding) / paddedHeight) * 2.0),
                0.0,
                1.0
            )
        }

        self.render(
            time: time,
            reflectionRotation: reflectionRotation,
            highlightTiltX: 0.0,
            highlightTiltY: 0.0,
            surfaceTiltX: 0.0,
            surfaceTiltY: 0.0,
            quad: WalletCardProjectedQuad(
                bottomLeft: clipPosition(CGPoint(x: 0.0, y: self.cardSize.height)),
                bottomRight: clipPosition(CGPoint(x: self.cardSize.width, y: self.cardSize.height)),
                topLeft: clipPosition(.zero),
                topRight: clipPosition(CGPoint(x: self.cardSize.width, y: 0.0))
            )
        )
    }

    private func configureFallback() {
        self.fallbackView.backgroundColor = UIColor(
            red: 0x0f / 255.0,
            green: 0x83 / 255.0,
            blue: 0xff / 255.0,
            alpha: 1.0
        )
        self.fallbackView.isUserInteractionEnabled = false
        self.fallbackView.clipsToBounds = true
        self.fallbackView.layer.allowsEdgeAntialiasing = true
        self.fallbackView.layer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerTopEdge, .layerBottomEdge]
        self.addSubview(self.fallbackView)

        self.fallbackBaseGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.fallbackBaseGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        // Use the same blue/azure palette as Wallet/CardChatGradient and the Metal material.
        self.fallbackBaseGradient.colors = [
            UIColor(red: 0x08 / 255.0, green: 0x72 / 255.0, blue: 0xfe / 255.0, alpha: 1.0).cgColor,
            UIColor(red: 0x10 / 255.0, green: 0x85 / 255.0, blue: 0xfe / 255.0, alpha: 1.0).cgColor,
        ]
        self.fallbackBaseGradient.locations = [0.0, 1.0]
        self.fallbackView.layer.addSublayer(self.fallbackBaseGradient)

        self.fallbackRadialGradient.type = .radial
        self.fallbackRadialGradient.startPoint = CGPoint(x: 0.42, y: 0.48)
        self.fallbackRadialGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.fallbackRadialGradient.colors = [
            UIColor(red: 0x1f / 255.0, green: 0xac / 255.0, blue: 0xff / 255.0, alpha: 0.35).cgColor,
            UIColor.clear.cgColor,
        ]
        self.fallbackRadialGradient.locations = [0.0, 1.0]
        self.fallbackView.layer.addSublayer(self.fallbackRadialGradient)
    }
}
