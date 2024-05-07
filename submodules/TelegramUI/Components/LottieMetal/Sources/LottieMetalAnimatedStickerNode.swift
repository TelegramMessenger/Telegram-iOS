import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AnimatedStickerNode
import MetalEngine
import LottieCpp
import GZip
import MetalKit
import HierarchyTrackingLayer

private final class BundleMarker: NSObject {
}

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }
    
    let mainBundle = Bundle(for: BundleMarker.self)
    guard let path = mainBundle.path(forResource: "LottieMetalSourcesBundle", ofType: "bundle") else {
        return nil
    }
    guard let bundle = Bundle(path: path) else {
        return nil
    }
    guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}

private func generateTexture(device: MTLDevice, sideSize: Int, msaaSampleCount: Int) -> MTLTexture {
    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.sampleCount = msaaSampleCount
    if msaaSampleCount == 1 {
        textureDescriptor.textureType = .type2D
    } else {
        textureDescriptor.textureType = .type2DMultisample
    }
    textureDescriptor.width = sideSize
    textureDescriptor.height = sideSize
    textureDescriptor.pixelFormat = .bgra8Unorm
    //textureDescriptor.storageMode = .memoryless
    textureDescriptor.storageMode = .private
    textureDescriptor.usage = [.renderTarget, .shaderRead]

    return device.makeTexture(descriptor: textureDescriptor)!
}

final class LottieContentLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private var animationContainer: LottieAnimationContainer?
    var frameIndex: Int = 0
    
    var internalData: MetalEngineSubjectInternalData?
    
    private var renderBufferHeap: MTLHeap?
    private var offscreenHeap: MTLHeap?
    
    private var multisampleTextureQueue: [MTLTexture] = []
    
    private let currentBezierIndicesBuffer = PathRenderBuffer()
    private let currentBuffer = PathRenderBuffer()
    
    final class PrepareState: ComputeState {
        let pathRenderContext: PathRenderContext
        
        init?(device: MTLDevice) {
            guard let pathRenderContext = PathRenderContext(device: device, msaaSampleCount: 1) else {
                return nil
            }
            self.pathRenderContext = pathRenderContext
        }
    }
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "blitVertex"), let fragmentFunction = library.makeFunction(name: "blitFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    init(animationContainer: LottieAnimationContainer) {
        self.animationContainer = animationContainer
        
        #if DEBUG && false
        let startTime = CFAbsoluteTimeGetCurrent()
        let buffer = WriteBuffer()
        for i in 0 ..< animationContainer.animation.frameCount {
            animationContainer.update(i)
            serializeNode(buffer: buffer, node: animationContainer.getCurrentRenderTree(for: CGSize(width: 512.0, height: 512.0)))
        }
        buffer.trim()
        let deltaTime = (CFAbsoluteTimeGetCurrent() - startTime)
        let zippedData = TGGZipData(buffer.data, 1.0)
        print("Serialized in \(deltaTime * 1000.0) size: \(zippedData.count / (1 * 1024 * 1024)) MB")
        #endif
        
        super.init()
        
        self.isOpaque = false
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func fillPath(frameState: PathFrameState, path: LottiePath, shading: PathShading, rule: LottieFillRule, transform: CATransform3D) {
        let fillState = PathRenderFillState(buffer: self.currentBuffer, bezierDataBuffer: self.currentBezierIndicesBuffer, fillRule: rule, shading: shading, transform: transform)
        
        path.enumerateItems { pathItem in
            switch pathItem.pointee.type {
            case .moveTo:
                let point = pathItem.pointee.points.0
                fillState.begin(point: SIMD2<Float>(Float(point.x), Float(point.y)))
            case .lineTo:
                let point = pathItem.pointee.points.0
                fillState.addLine(to: SIMD2<Float>(Float(point.x), Float(point.y)))
            case .curveTo:
                let cp1 = pathItem.pointee.points.0
                let cp2 = pathItem.pointee.points.1
                let point = pathItem.pointee.points.2
                
                fillState.addCurve(
                    to: SIMD2<Float>(Float(point.x), Float(point.y)),
                    cp1: SIMD2<Float>(Float(cp1.x), Float(cp1.y)),
                    cp2: SIMD2<Float>(Float(cp2.x), Float(cp2.y))
                )
            case .close:
                fillState.close()
            @unknown default:
                break
            }
        }
        
        fillState.close()
        
        frameState.add(fill: fillState)
    }
    
    private func strokePath(frameState: PathFrameState, path: LottiePath, width: CGFloat, join: CGLineJoin, cap: CGLineCap, miterLimit: CGFloat, color: LottieColor, transform: CATransform3D) {
        let strokeState = PathRenderStrokeState(buffer: self.currentBuffer, bezierDataBuffer: self.currentBezierIndicesBuffer, lineWidth: Float(width), lineJoin: join, lineCap: cap, miterLimit: Float(miterLimit), color: color, transform: transform)
        
        path.enumerateItems { pathItem in
            switch pathItem.pointee.type {
            case .moveTo:
                let point = pathItem.pointee.points.0
                strokeState.begin(point: SIMD2<Float>(Float(point.x), Float(point.y)))
            case .lineTo:
                let point = pathItem.pointee.points.0
                strokeState.addLine(to: SIMD2<Float>(Float(point.x), Float(point.y)))
            case .curveTo:
                let cp1 = pathItem.pointee.points.0
                let cp2 = pathItem.pointee.points.1
                let point = pathItem.pointee.points.2
                
                strokeState.addCurve(
                    to: SIMD2<Float>(Float(point.x), Float(point.y)),
                    cp1: SIMD2<Float>(Float(cp1.x), Float(cp1.y)),
                    cp2: SIMD2<Float>(Float(cp2.x), Float(cp2.y))
                )
            case .close:
                strokeState.close()
            @unknown default:
                break
            }
        }
        
        strokeState.complete()
        
        frameState.add(stroke: strokeState)
    }
    
    func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let size = CGSize(width: 800.0, height: 800.0)
        let msaaSampleCount = 1
        
        let renderSpec = RenderLayerSpec(size: RenderSize(width: Int(size.width), height: Int(size.height)))
        
        guard let animationContainer = self.animationContainer else {
            return
        }
        animationContainer.update(self.frameIndex)
        
        func defaultTransformForSize(_ size: CGSize) -> CATransform3D {
            var transform = CATransform3DIdentity
            transform = CATransform3DScale(transform, 2.0 / size.width, 2.0 / size.height, 1.0)
            transform = CATransform3DTranslate(transform, -size.width * 0.5, -size.height * 0.5, 0.0)
            transform = CATransform3DTranslate(transform, 0.0, size.height, 0.0)
            transform = CATransform3DScale(transform, 1.0, -1.0, 1.0)
            
            return transform
        }
        
        let canvasSize = size
        var transform = defaultTransformForSize(canvasSize)
        
        concat(CATransform3DMakeScale(canvasSize.width / animationContainer.animation.size.width, canvasSize.height / animationContainer.animation.size.height, 1.0))
        
        var transformStack: [CATransform3D] = []
        
        func saveState() {
            transformStack.append(transform)
        }
        
        func restoreState() {
            transform = transformStack.removeLast()
        }
        
        func concat(_ other: CATransform3D) {
            transform = CATransform3DConcat(other, transform)
        }
        
        func renderNodeContent(frameState: PathFrameState, item: LottieRenderContent, alpha: Double) {
            if let fill = item.fill {
                if let solidShading = fill.shading as? LottieRenderContentSolidShading {
                    self.fillPath(
                        frameState: frameState,
                        path: item.path,
                        shading: .color(LottieColor(r: solidShading.color.r, g: solidShading.color.g, b: solidShading.color.b, a: solidShading.color.a * solidShading.opacity * alpha)),
                        rule: fill.fillRule,
                        transform: transform
                    )
                } else if let gradientShading = fill.shading as? LottieRenderContentGradientShading {
                    let gradientType: PathShading.Gradient.GradientType
                    switch gradientShading.gradientType {
                    case .linear:
                        gradientType = .linear
                    case .radial:
                        gradientType = .radial
                    @unknown default:
                        gradientType = .linear
                    }
                    var colorStops: [PathShading.Gradient.ColorStop] = []
                    for colorStop in gradientShading.colorStops {
                        colorStops.append(PathShading.Gradient.ColorStop(
                            color: LottieColor(r: colorStop.color.r, g: colorStop.color.g, b: colorStop.color.b, a: colorStop.color.a * gradientShading.opacity * alpha),
                            location: Float(colorStop.location)
                        ))
                    }
                    let gradientShading = PathShading.Gradient(
                        gradientType: gradientType,
                        colorStops: colorStops,
                        start: SIMD2<Float>(Float(gradientShading.start.x), Float(gradientShading.start.y)),
                        end: SIMD2<Float>(Float(gradientShading.end.x), Float(gradientShading.end.y))
                    )
                    self.fillPath(
                        frameState: frameState,
                        path: item.path,
                        shading: .gradient(gradientShading),
                        rule: fill.fillRule,
                        transform: transform
                    )
                }
            } else if let stroke = item.stroke {
                if let solidShading = stroke.shading as? LottieRenderContentSolidShading {
                    let color = solidShading.color
                    strokePath(
                        frameState: frameState,
                        path: item.path,
                        width: stroke.lineWidth,
                        join: stroke.lineJoin,
                        cap: stroke.lineCap,
                        miterLimit: stroke.miterLimit,
                        color: LottieColor(r: color.r, g: color.g, b: color.b, a: color.a * solidShading.opacity * alpha),
                        transform: transform
                    )
                }
            }
        }
        
        func renderNode(frameState: PathFrameState, node: LottieRenderNode, globalSize: CGSize, parentAlpha: CGFloat) {
            let normalizedOpacity = node.opacity
            let layerAlpha = normalizedOpacity * parentAlpha
            
            if node.isHidden || normalizedOpacity == 0.0 {
                return
            }
            
            saveState()
            
            var needsTempContext = false
            if node.mask != nil {
                needsTempContext = true
            } else {
                needsTempContext = (layerAlpha != 1.0 && !node.hasSimpleContents) || node.masksToBounds
            }
            
            var maskSurface: PathFrameState.MaskSurface?
            
            if needsTempContext {
                if node.mask != nil || node.masksToBounds {
                    var maskMode: PathFrameState.MaskSurface.Mode = .regular
                    
                    frameState.pushOffscreen(width: Int(node.globalRect.width), height: Int(node.globalRect.height))
                    saveState()
                    
                    transform = defaultTransformForSize(node.globalRect.size)
                    concat(CATransform3DMakeTranslation(-node.globalRect.minX, -node.globalRect.minY, 0.0))
                    concat(node.globalTransform)
                    
                    if node.masksToBounds {
                        let fillState = PathRenderFillState(buffer: self.currentBuffer, bezierDataBuffer: self.currentBezierIndicesBuffer, fillRule: .evenOdd, shading: .color(.init(r: 1.0, g: 1.0, b: 1.0, a: 1.0)), transform: transform)
                        
                        fillState.begin(point: SIMD2<Float>(Float(node.bounds.minX), Float(node.bounds.minY)))
                        fillState.addLine(to: SIMD2<Float>(Float(node.bounds.minX), Float(node.bounds.maxY)))
                        fillState.addLine(to: SIMD2<Float>(Float(node.bounds.maxX), Float(node.bounds.maxY)))
                        fillState.addLine(to: SIMD2<Float>(Float(node.bounds.maxX), Float(node.bounds.minY)))
                        fillState.close()
                        
                        frameState.add(fill: fillState)
                    }
                    if let maskNode = node.mask {
                        if maskNode.isInvertedMatte {
                            maskMode = .inverse
                        }
                        renderNode(frameState: frameState, node: maskNode, globalSize: globalSize, parentAlpha: 1.0)
                    }
                    
                    restoreState()
                    
                    maskSurface = frameState.popOffscreenMask(mode: maskMode)
                }
                
                frameState.pushOffscreen(width: Int(node.globalRect.width), height: Int(node.globalRect.height))
                saveState()
                
                transform = defaultTransformForSize(node.globalRect.size)
                concat(CATransform3DMakeTranslation(-node.globalRect.minX, -node.globalRect.minY, 0.0))
                concat(node.globalTransform)
            } else {
                concat(CATransform3DMakeTranslation(node.position.x, node.position.y, 0.0))
                concat(CATransform3DMakeTranslation(-node.bounds.origin.x, -node.bounds.origin.y, 0.0))
                concat(node.transform)
            }
            
            var renderAlpha: CGFloat = 1.0
            if needsTempContext {
                renderAlpha = 1.0
            } else {
                renderAlpha = layerAlpha
            }
            
            if let renderContent = node.renderContent {
                renderNodeContent(frameState: frameState, item: renderContent, alpha: renderAlpha)
            }
            
            for subnode in node.subnodes {
                renderNode(frameState: frameState, node: subnode, globalSize: globalSize, parentAlpha: renderAlpha)
            }
            
            if needsTempContext {
                restoreState()
                
                concat(CATransform3DMakeTranslation(node.position.x, node.position.y, 0.0))
                concat(CATransform3DMakeTranslation(-node.bounds.origin.x, -node.bounds.origin.y, 0.0))
                concat(node.transform)
                concat(CATransform3DInvert(node.globalTransform))
                
                frameState.popOffscreen(rect: node.globalRect, transform: transform, opacity: Float(layerAlpha), mask: maskSurface)
            }
            
            restoreState()
        }
        
        self.currentBuffer.reset()
        self.currentBezierIndicesBuffer.reset()
        let frameState = PathFrameState(width: Int(size.width), height: Int(size.height), msaaSampleCount: 1, buffer: self.currentBuffer, bezierDataBuffer: self.currentBezierIndicesBuffer)
        
        let node = animationContainer.getCurrentRenderTree(for: CGSize(width: 512.0, height: 512.0))
        renderNode(frameState: frameState, node: node, globalSize: canvasSize, parentAlpha: 1.0)
        
        final class ComputeOutput {
            let pathRenderContext: PathRenderContext
            let renderBufferHeap: MTLHeap
            let multisampleTexture: MTLTexture
            let takenMultisampleTextures: [MTLTexture]
            
            init(pathRenderContext: PathRenderContext, renderBufferHeap: MTLHeap, multisampleTexture: MTLTexture, takenMultisampleTextures: [MTLTexture]) {
                self.pathRenderContext = pathRenderContext
                self.renderBufferHeap = renderBufferHeap
                self.multisampleTexture = multisampleTexture
                self.takenMultisampleTextures = takenMultisampleTextures
            }
        }
        
        var customCompletion: (() -> Void)?
        
        let computeOutput = context.compute(state: PrepareState.self, commands: { commandBuffer, state -> ComputeOutput? in
            let renderBufferHeap: MTLHeap
            if let current = self.renderBufferHeap {
                renderBufferHeap = current
            } else {
                let heapDescriptor = MTLHeapDescriptor()
                heapDescriptor.size = 32 * 1024 * 1024
                heapDescriptor.storageMode = .shared
                heapDescriptor.cpuCacheMode = .writeCombined
                if #available(iOS 13.0, *) {
                    heapDescriptor.hazardTrackingMode = .tracked
                }
                guard let value = MetalEngine.shared.device.makeHeap(descriptor: heapDescriptor) else {
                    print()
                    return nil
                }
                self.renderBufferHeap = value
                renderBufferHeap = value
            }
            
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            
            frameState.prepare(heap: renderBufferHeap)
            frameState.encodeCompute(context: state.pathRenderContext, computeEncoder: computeEncoder)
            
            computeEncoder.endEncoding()
            
            let multisampleTexture: MTLTexture
            if !self.multisampleTextureQueue.isEmpty {
                multisampleTexture = self.multisampleTextureQueue.removeFirst()
            } else {
                multisampleTexture = generateTexture(device: MetalEngine.shared.device, sideSize: Int(size.width), msaaSampleCount: 1)
            }
            
            let tempTexture: MTLTexture
            if !self.multisampleTextureQueue.isEmpty {
                tempTexture = self.multisampleTextureQueue.removeFirst()
            } else {
                tempTexture = generateTexture(device: MetalEngine.shared.device, sideSize: Int(size.width), msaaSampleCount: 1)
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = multisampleTexture
            if msaaSampleCount == 1 {
                renderPassDescriptor.colorAttachments[0].storeAction = .store
            } else {
                //renderPassDescriptor.colorAttachments[0].resolveTexture = self.currentDrawable?.texture
                renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
                preconditionFailure()
            }
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            
            renderPassDescriptor.colorAttachments[1].texture = tempTexture
            renderPassDescriptor.colorAttachments[1].loadAction = .clear
            renderPassDescriptor.colorAttachments[1].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            renderPassDescriptor.colorAttachments[1].storeAction = .dontCare
            
            if msaaSampleCount == 4 {
                renderPassDescriptor.setSamplePositions([
                    MTLSamplePosition(x: 0.25, y: 0.25),
                    MTLSamplePosition(x: 0.75, y: 0.25),
                    MTLSamplePosition(x: 0.75, y: 0.75),
                    MTLSamplePosition(x: 0.25, y: 0.75)
                ])
            }
            
            var offscreenHeapMemorySize = frameState.calculateOffscreenHeapMemorySize(device: MetalEngine.shared.device)
            offscreenHeapMemorySize = max(offscreenHeapMemorySize, 1 * 1024 * 1024)
            
            let offscreenHeap: MTLHeap
            if let current = self.offscreenHeap, current.size >= offscreenHeapMemorySize * 3 {
                offscreenHeap = current
            } else {
                print("Creating offscreen heap \(offscreenHeapMemorySize * 3 / (1024 * 1024)) MB (3 * \(offscreenHeapMemorySize / (1024 * 1024)) MB)")
                let heapDescriptor = MTLHeapDescriptor()
                heapDescriptor.size = offscreenHeapMemorySize * 3
                heapDescriptor.storageMode = .private
                heapDescriptor.cpuCacheMode = .defaultCache
                if #available(iOS 13.0, *) {
                    heapDescriptor.hazardTrackingMode = .tracked
                }
                offscreenHeap = MetalEngine.shared.device.makeHeap(descriptor: heapDescriptor)!
                self.offscreenHeap = offscreenHeap
            }
            
            frameState.encodeOffscreen(context: state.pathRenderContext, heap: offscreenHeap, commandBuffer: commandBuffer, canvasSize: canvasSize)
            
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                self.multisampleTextureQueue.append(multisampleTexture)
                self.multisampleTextureQueue.append(tempTexture)
                return nil
            }
            
            frameState.encodeRender(context: state.pathRenderContext, encoder: renderEncoder, canvasSize: canvasSize)
            
            renderEncoder.endEncoding()
            
            return ComputeOutput(
                pathRenderContext: state.pathRenderContext,
                renderBufferHeap: renderBufferHeap,
                multisampleTexture: multisampleTexture,
                takenMultisampleTextures: [multisampleTexture, tempTexture]
            )
        })
        
        context.renderToLayer(spec: renderSpec, state: RenderState.self, layer: self, inputs: computeOutput, commands: { [weak self] encoder, placement, computeOutput in
            guard let computeOutput else {
                return
            }
            
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            encoder.setFragmentTexture(computeOutput.multisampleTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            let takenMultisampleTextures = computeOutput.takenMultisampleTextures
            customCompletion = {
                guard let self else {
                    return
                }
                for texture in takenMultisampleTextures {
                    self.multisampleTextureQueue.append(texture)
                }
            }
        })
        
        context.addCustomCompletion({
            customCompletion?()
        })
    }
}

public final class LottieMetalAnimatedStickerNode: ASDisplayNode, AnimatedStickerNode {
    private final class LoadFrameTask {
        var isCancelled: Bool = false
    }
    
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    public var automaticallyLoadFirstFrame: Bool = false
    public var automaticallyLoadLastFrame: Bool = false
    public var playToCompletionOnStop: Bool = false
    
    private var layoutSize: CGSize?
    private var lottieInstance: LottieAnimationContainer?
    private var renderLayer: LottieContentLayer?
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    
    private var didStart: Bool = false
    public var started: () -> Void = {}
    
    public var completed: (Bool) -> Void = { _ in }
    private var didComplete: Bool = false
    
    public var frameUpdated: (Int, Int) -> Void = { _, _ in }
    public var currentFrameIndex: Int {
        get {
            return self.frameIndex
        } set(value) {
        }
    }
    public var currentFrameCount: Int {
        get {
            if let lottieInstance = self.lottieInstance {
                return Int(lottieInstance.animation.frameCount)
            } else {
                return 0
            }
        } set(value) {
        }
    }
    public var currentFrameImage: UIImage? {
        return nil
    }
    
    public private(set) var isPlaying: Bool = false
    public var stopAtNearestLoop: Bool = false
    
    private let statusPromise = Promise<AnimatedStickerStatus>()
    public var status: Signal<AnimatedStickerStatus, NoError> {
        return self.statusPromise.get()
    }
    
    public var autoplay: Bool = true
    
    public var visibility: Bool = false {
        didSet {
            self.updatePlayback()
        }
    }
    
    public var overrideVisibility: Bool = false
    
    public var isPlayingChanged: (Bool) -> Void = { _ in }
    
    private var sourceDisposable: Disposable?
    private var playbackSize: CGSize?
    
    private var frameIndex: Int = 0
    private var playbackMode: AnimatedStickerPlaybackMode = .loop
    
    override public init() {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        super.init()
        
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updatePlayback()
        }
        self.hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updatePlayback()
        }
    }
    
    deinit {
        self.sourceDisposable?.dispose()
    }
    
    public func cloneCurrentFrame(from otherNode: AnimatedStickerNode?) {
    }
    
    public func setup(source: AnimatedStickerNodeSource, width: Int, height: Int, playbackMode: AnimatedStickerPlaybackMode, mode: AnimatedStickerMode) {
        self.didStart = false
        self.didComplete = false
        
        self.sourceDisposable?.dispose()
        
        self.playbackSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        self.playbackMode = playbackMode
        
        self.sourceDisposable = (source.directDataPath(attemptSynchronously: false)
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self] path in
            guard let self, let path = path else {
                return
            }
            
            if source.isVideo {
            } else {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                    return
                }
                
                let decompressedData = TGGUnzipData(data, 8 * 1024 * 1024) ?? data
                guard let lottieAnimation = LottieAnimation(data: decompressedData) else {
                    print("Could not load sticker data")
                    return
                }
                let lottieInstance = LottieAnimationContainer(animation: lottieAnimation)
                self.setupPlayback(lottieInstance: lottieInstance)
            }
        }).strict()
    }
    
    private func updatePlayback() {
        let isPlaying = self.visibility && self.lottieInstance != nil
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.isPlayingChanged(self.isPlaying)
        }
        
        if isPlaying, let lottieInstance = self.lottieInstance {
            if self.displayLinkSubscription == nil {
                let fps: Int
                if lottieInstance.animation.framesPerSecond == 30 {
                    fps = 30
                } else {
                    fps = 60
                }
                self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(fps), { [weak self] deltaTime in
                    guard let self, let lottieInstance = self.lottieInstance, let renderLayer = self.renderLayer else {
                        return
                    }
                    if renderLayer.frameIndex == lottieInstance.animation.frameCount - 1 {
                        switch self.playbackMode {
                        case .loop:
                            self.completed(false)
                        case let .count(count):
                            if count <= 1 {
                                if !self.didComplete {
                                    self.didComplete = true
                                    self.completed(true)
                                }
                                return
                            } else {
                                self.playbackMode = .count(count - 1)
                                self.completed(false)
                            }
                        case .once:
                            if !self.didComplete {
                                self.didComplete = true
                                self.completed(true)
                            }
                            return
                        case .still:
                            break
                        }
                    }
                    
                    self.frameIndex = (self.frameIndex + 1) % lottieInstance.animation.frameCount
                    renderLayer.frameIndex = self.frameIndex
                    renderLayer.setNeedsUpdate()
                })
                
                self.renderLayer?.setNeedsUpdate()
            }
        } else {
            self.displayLinkSubscription = nil
        }
    }
    
    private func advanceFrameIfPossible() {
        /*var frameCount: Int?
        if let lottieInstance = self.lottieInstance {
            frameCount = Int(lottieInstance.frameCount)
        } else if let videoSource = self.videoSource {
            frameCount = Int(videoSource.frameCount)
        }
        guard let frameCount = frameCount else {
            return
        }
        
        if self.frameIndex == frameCount - 1 {
            switch self.playbackMode {
            case .loop:
                self.completed(false)
            case let .count(count):
                if count <= 1 {
                    if !self.didComplete {
                        self.didComplete = true
                        self.completed(true)
                    }
                    return
                } else {
                    self.playbackMode = .count(count - 1)
                    self.completed(false)
                }
            case .once:
                if !self.didComplete {
                    self.didComplete = true
                    self.completed(true)
                }
                return
            case .still:
                break
            }
        }
        
        let nextFrameIndex = (self.frameIndex + 1) % frameCount
        self.frameIndex = nextFrameIndex
        
        self.updateFrameImageIfNeeded()
        self.updateLoadFrameTasks()*/
    }
    
    private func setupPlayback(lottieInstance: LottieAnimationContainer) {
        self.lottieInstance = lottieInstance
        
        let renderLayer = LottieContentLayer(animationContainer: lottieInstance)
        self.renderLayer = renderLayer
        if let layoutSize = self.layoutSize {
            renderLayer.frame = CGRect(origin: CGPoint(), size: layoutSize)
        }
        self.layer.addSublayer(renderLayer)
        
        self.updatePlayback()
    }
    
    public func reset() {
    }
    
    public func playOnce() {
    }
    
    public func playLoop() {
    }
    
    public func play(firstFrame: Bool, fromIndex: Int?) {
        if let fromIndex = fromIndex {
            self.frameIndex = fromIndex
        }
    }
    
    public func pause() {
    }
    
    public func stop() {
    }
    
    public func seekTo(_ position: AnimatedStickerPlaybackPosition) {
    }
    
    public func playIfNeeded() -> Bool {
        return false
    }
    
    public func updateLayout(size: CGSize) {
        self.layoutSize = size
        if let renderLayer = self.renderLayer {
            renderLayer.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
    
    public func setOverlayColor(_ color: UIColor?, replace: Bool, animated: Bool) {
    }
}
