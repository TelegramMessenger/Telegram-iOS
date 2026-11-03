import Foundation
import UIKit
import Metal
import Display
import MetalEngine

/// What a `LiquidGlassShapesLayer` draws, supplied by the component that owns it.
public protocol LiquidGlassShapesSource: AnyObject {
    /// Moves the shapes on. Called on each display link tick while the layer animates.
    func liquidGlassShapesAdvance(by deltaTime: CGFloat)
    /// The shapes to draw now for a layer of `size`, or nil when there is nothing to draw yet.
    func liquidGlassShapes(size: CGSize, isFlat: Bool) -> LiquidGlassShapeSet?
    /// The look for the style the layer draws in.
    func liquidGlassAppearance(mode: LiquidGlassRenderMode, isDarkAppearance: Bool) -> LiquidGlassAppearance
}

private func colorVector(_ color: UIColor) -> SIMD4<Float> {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
}

private func encodeShapeKernel<Parameters>(commandBuffer: MTLCommandBuffer, pipelineState: MTLComputePipelineState, parameters: Parameters, sampleCount: Int, output: MTLBuffer) -> MTLBuffer? {
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        return nil
    }
    encoder.setComputePipelineState(pipelineState)
    withUnsafeBytes(of: parameters) { bytes in
        encoder.setBytes(bytes.baseAddress!, length: MemoryLayout<Parameters>.stride, index: 0)
    }
    encoder.setBuffer(output, offset: 0, index: 1)
    let threadCount = min(sampleCount, pipelineState.maxTotalThreadsPerThreadgroup)
    encoder.dispatchThreadgroups(MTLSize(width: 3, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: threadCount, height: 1, depth: 1))
    encoder.endEncoding()
    return output
}

/// Three stacked shapes (outer, middle, main) in a source's style: liquid glass on iOS 26 and later, the plain masked
/// color before it, the main shape alone when flat.
///
/// Everything is rendered by MetalEngine: a compute kernel builds the shapes from each one's points, and the layer
/// stack is evaluated per pixel as an affine function of the content behind the layer, which a multiply layer and an
/// additive layer reproduce exactly whether or not the layer is composited as an offscreen group. On iOS 26 and later
/// a slightly blurred backdrop layer refracts the content behind the layer along each edge through a
/// `displacementMap` filter.
public final class LiquidGlassShapesLayer: SimpleLayer, MetalEngineSubject {
    private enum Constants {
        /// Blur of the content under the shapes.
        static let glassBlurRadius: CGFloat = 1.0
        /// The backdrop is blurred anyway, so it is captured at 1x, as the legacy glass (LegacyGlassView) captures it.
        static let backdropScale: CGFloat = 1.0
        static let colorTransitionDuration: Double = 0.3
        static let edgeInset = 2
    }

    private struct ColorTransition {
        var from: (SIMD4<Float>, SIMD4<Float>)
        var startTimestamp: Double
    }

    public var internalData: MetalEngineSubjectInternalData?
    public weak var source: LiquidGlassShapesSource?

    /// Pixels per point of the displacement map and the backdrop mask. Both are smooth except across an edge, so a
    /// source whose edges run one way only needs the screen scale across them.
    public var glassMapScale: CGSize = CGSize(width: UIScreenScale, height: UIScreenScale)

    /// Whether to give the MetalEngine surfaces back while the layer is out of the window, for a layer kept long
    /// after it was last shown. They are allocated again, and the shapes redrawn, when it returns.
    public var releasesSurfacesWhenHidden: Bool {
        get {
            return self.surfaceReleasePolicy.releasesWhenHidden
        } set {
            self.surfaceReleasePolicy.releasesWhenHidden = newValue
        }
    }

    /// Nothing animates or renders while the layer is out of the window.
    public var isInWindow: Bool = false {
        didSet {
            if self.isInWindow != oldValue {
                if self.surfaceReleasePolicy.update(isInWindow: self.isInWindow) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.surfaceReleasePolicy.releasesNow else {
                            return
                        }
                        self.releaseSurfaces()
                    }
                }
                self.updateDisplayLink()
                if self.isInWindow {
                    self.setNeedsUpdate()
                }
            }
        }
    }

    /// The main shape only, still, for when animations are disabled to save energy.
    public var isFlat: Bool = false {
        didSet {
            if self.isFlat != oldValue {
                self.updateStyle()
                self.updateDisplayLink()
                self.setNeedsUpdate()
            }
        }
    }

    /// Whether the source's shapes move. The display link runs while they do, and while colors fade.
    public var isAnimating: Bool = false {
        didSet {
            if self.isAnimating != oldValue {
                self.updateDisplayLink()
            }
        }
    }

    public var isDarkAppearance: Bool = false {
        didSet {
            if self.isDarkAppearance != oldValue {
                self.setNeedsUpdate()
            }
        }
    }

    /// Length of the horizontal gradient between the two colors, in points.
    public var gradientLength: CGFloat = 1.0 {
        didSet {
            if self.gradientLength != oldValue {
                self.setNeedsUpdate()
            }
        }
    }

    private let contentLayer: MetalEngineSubjectLayer
    private var multiplyLayer: MetalEngineSubjectLayer?
    private var backdropLayers: LiquidGlassBackdropLayers?

    /// Shape samples written by a kernel and read by every pass of the same frame.
    private let crestBuffer: PooledBuffer
    private let radialBuffer: PooledBuffer

    private var colors: (SIMD4<Float>, SIMD4<Float>)
    private var targetColors: (SIMD4<Float>, SIMD4<Float>)
    private var colorTransition: ColorTransition?

    private var displayLink: SharedDisplayLinkDriver.Link?
    private var lastTimestamp: Double?

    private var surfaceReleasePolicy = LiquidGlassSurfaceReleasePolicy(releasesWhenHidden: false)

    public init(colors: (UIColor, UIColor)) {
        self.contentLayer = MetalEngineSubjectLayer()
        self.crestBuffer = MetalEngine.shared.pooledBuffer(spec: BufferSpec(length: 3 * LiquidGlassShapesConstants.crestSampleCount * MemoryLayout<Float>.size))
        self.radialBuffer = MetalEngine.shared.pooledBuffer(spec: BufferSpec(length: 3 * LiquidGlassShapesConstants.radialSampleCount * MemoryLayout<Float>.size))
        self.colors = (colorVector(colors.0), colorVector(colors.1))
        self.targetColors = self.colors

        super.init()

        self.isOpaque = false
        self.addSublayer(self.contentLayer)

        self.updateStyle()
    }

    override public init(layer: Any) {
        guard let layer = layer as? LiquidGlassShapesLayer else {
            preconditionFailure()
        }
        self.contentLayer = layer.contentLayer
        self.crestBuffer = layer.crestBuffer
        self.radialBuffer = layer.radialBuffer
        self.colors = layer.colors
        self.targetColors = layer.targetColors

        super.init(layer: layer)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    /// Lays the sublayers out for the current bounds; call after changing the frame.
    public func updateLayout() {
        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.contentLayer.frame = bounds
        self.multiplyLayer?.frame = bounds
        self.backdropLayers?.updateFrame(bounds)

        self.setNeedsUpdate()
    }

    public func updateColors(_ colors: (UIColor, UIColor), animated: Bool) {
        let targetColors = (colorVector(colors.0), colorVector(colors.1))
        if targetColors == self.targetColors {
            return
        }
        self.targetColors = targetColors
        if animated && self.isInWindow {
            self.colorTransition = ColorTransition(from: self.colors, startTimestamp: CACurrentMediaTime())
        } else {
            self.colorTransition = nil
            self.colors = targetColors
        }
        self.updateDisplayLink()
        self.setNeedsUpdate()
    }

    /// The glass style needs the refracting backdrop. Without it (before iOS 26, or if the backdrop or the filter is
    /// unavailable) the shapes are drawn as the plain masked color.
    private var usesGlass: Bool {
        return self.backdropLayers != nil
    }

    private func releaseSurfaces() {
        self.contentLayer.releaseSurface()
        self.multiplyLayer?.releaseSurface()
        self.backdropLayers?.backdropMaskLayer.releaseSurface()
        self.backdropLayers?.displacementMapLayer.releaseSurface()
    }

    private func updateStyle() {
        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)

        var wantsGlass = false
        if #available(iOS 26.0, *) {
            wantsGlass = !self.isFlat
        }
        if wantsGlass {
            if self.backdropLayers == nil, let backdropLayers = LiquidGlassBackdropLayers(blurRadius: Constants.glassBlurRadius, scale: Constants.backdropScale) {
                backdropLayers.updateFrame(bounds)
                self.insertSublayer(backdropLayers.containerLayer, at: 0)
                self.backdropLayers = backdropLayers
            }
        } else if let backdropLayers = self.backdropLayers {
            // Dropping the layers releases their MetalEngine surfaces.
            self.backdropLayers = nil
            backdropLayers.containerLayer.removeFromSuperlayer()
        }

        if self.usesGlass {
            if self.multiplyLayer == nil {
                let multiplyLayer = MetalEngineSubjectLayer()
                multiplyLayer.compositingFilter = "multiplyBlendMode"
                multiplyLayer.frame = bounds
                self.insertSublayer(multiplyLayer, below: self.contentLayer)
                self.multiplyLayer = multiplyLayer
            }
            self.contentLayer.compositingFilter = "plusL"
        } else {
            if let multiplyLayer = self.multiplyLayer {
                self.multiplyLayer = nil
                multiplyLayer.removeFromSuperlayer()
            }
            self.contentLayer.compositingFilter = nil
        }
    }

    private var isAnimatingShapes: Bool {
        return self.isInWindow && self.isAnimating && !self.isFlat
    }

    private func updateDisplayLink() {
        if self.isInWindow && ((self.isAnimating && !self.isFlat) || self.colorTransition != nil) {
            if self.displayLink == nil {
                self.lastTimestamp = nil
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
                    self?.displayLinkTick()
                })
            }
        } else if let displayLink = self.displayLink {
            self.displayLink = nil
            displayLink.invalidate()
        }
    }

    private func displayLinkTick() {
        let timestamp = CACurrentMediaTime()
        let deltaTime: CGFloat
        if let lastTimestamp = self.lastTimestamp {
            deltaTime = CGFloat(max(0.0, min(0.05, timestamp - lastTimestamp)))
        } else {
            deltaTime = 1.0 / 60.0
        }
        self.lastTimestamp = timestamp

        if self.isAnimatingShapes {
            self.source?.liquidGlassShapesAdvance(by: deltaTime)
        }

        if let colorTransition = self.colorTransition {
            let t = Float(max(0.0, min(1.0, (timestamp - colorTransition.startTimestamp) / Constants.colorTransitionDuration)))
            self.colors = (
                colorTransition.from.0 + (self.targetColors.0 - colorTransition.from.0) * t,
                colorTransition.from.1 + (self.targetColors.1 - colorTransition.from.1) * t
            )
            if t >= 1.0 {
                self.colorTransition = nil
                self.updateDisplayLink()
            }
        }

        self.setNeedsUpdate()
    }

    public func update(context: MetalEngineSubjectContext) {
        let size = self.bounds.size
        guard self.isInWindow, size.width > 0.0, size.height > 0.0, let source = self.source, let shapes = source.liquidGlassShapes(size: size, isFlat: self.isFlat) else {
            return
        }
        switch shapes {
        case let .crest(parameters):
            self.update(context: context, kind: LiquidGlassCrestKind.self, parameters: parameters, sampleBuffer: self.crestBuffer, shapeCenter: SIMD2<Float>(), size: size, source: source)
        case let .radial(parameters, center):
            self.update(context: context, kind: LiquidGlassRadialKind.self, parameters: parameters, sampleBuffer: self.radialBuffer, shapeCenter: center, size: size, source: source)
        }
    }

    private func update<Kind: LiquidGlassShapesKind, Parameters>(context: MetalEngineSubjectContext, kind: Kind.Type, parameters: Parameters, sampleBuffer: PooledBuffer, shapeCenter: SIMD2<Float>, size: CGSize, source: LiquidGlassShapesSource) {
        // Without samples the passes would clear their layers and draw nothing; skip the frame and keep the last one.
        guard LiquidGlassShapesPipelines.shared.computePipelineState(device: MetalEngine.shared.device, functionName: Kind.kernelFunctionName) != nil, let buffer = sampleBuffer.get(context: context) else {
            return
        }
        let samples = context.compute(state: LiquidGlassShapesComputeState<Kind>.self, inputs: buffer.placeholer, commands: { commandBuffer, state, buffer -> MTLBuffer? in
            guard let buffer else {
                return nil
            }
            return encodeShapeKernel(commandBuffer: commandBuffer, pipelineState: state.pipelineState, parameters: parameters, sampleCount: Kind.sampleCount, output: buffer)
        })

        let mode: LiquidGlassRenderMode
        if self.isFlat {
            mode = .flat
        } else if self.usesGlass {
            mode = .glass
        } else {
            mode = .plain
        }
        let baseUniforms = LiquidGlassShapesUniforms(
            appearance: source.liquidGlassAppearance(mode: mode, isDarkAppearance: self.isDarkAppearance),
            colors: self.colors,
            boundsSize: size,
            gradientLength: self.gradientLength,
            shapeCenter: shapeCenter,
            mode: mode,
            isDarkAppearance: self.isDarkAppearance,
            edgeInset: Float(Constants.edgeInset)
        )

        func render<Pass: LiquidGlassShapesPass>(_ pass: Pass.Type, layer: MetalEngineSubjectLayer, scale: CGSize) {
            let renderSize = RenderSize(width: max(1, Int(ceil(size.width * scale.width))), height: max(1, Int(ceil(size.height * scale.height))))
            var uniforms = baseUniforms
            uniforms.renderSize = SIMD2<Float>(Float(renderSize.width), Float(renderSize.height))

            // Every layer here is rendered on every frame, so a surface of its own is the cheapest place for it.
            let spec = RenderLayerSpec(size: renderSize, edgeInset: Constants.edgeInset, prefersDedicatedSurface: true)
            context.renderToLayer(spec: spec, state: LiquidGlassShapesRenderState<Pass, Kind>.self, layer: layer, inputs: samples, commands: { encoder, placement, samples in
                guard let samples else {
                    return
                }
                let effectiveRect = placement.effectiveRect
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)

                var uniforms = uniforms
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidGlassShapesUniforms>.stride, index: 0)
                encoder.setFragmentBuffer(samples, offset: 0, index: 1)

                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            })
        }

        let screenScale = CGSize(width: UIScreenScale, height: UIScreenScale)
        render(LiquidGlassContentPass.self, layer: self.contentLayer, scale: screenScale)
        if let multiplyLayer = self.multiplyLayer {
            render(LiquidGlassMultiplyPass.self, layer: multiplyLayer, scale: screenScale)
        }
        if let backdropLayers = self.backdropLayers {
            render(LiquidGlassBackdropMaskPass.self, layer: backdropLayers.backdropMaskLayer, scale: self.glassMapScale)
            render(LiquidGlassDisplacementPass.self, layer: backdropLayers.displacementMapLayer, scale: self.glassMapScale)
        }
    }
}
