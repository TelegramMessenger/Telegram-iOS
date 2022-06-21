#if targetEnvironment(simulator)
#else

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramVoip
import AVFoundation
import Metal
import MetalPerformanceShaders

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

private func getCubeVertexData(
    cropX: Int,
    cropY: Int,
    cropWidth: Int,
    cropHeight: Int,
    frameWidth: Int,
    frameHeight: Int,
    rotation: Int,
    mirrorHorizontally: Bool,
    mirrorVertically: Bool,
    buffer: UnsafeMutablePointer<Float>
) {
    var cropLeft = Float(cropX) / Float(frameWidth)
    var cropRight = Float(cropX + cropWidth) / Float(frameWidth)
    var cropTop = Float(cropY) / Float(frameHeight)
    var cropBottom = Float(cropY + cropHeight) / Float(frameHeight)

    if mirrorHorizontally {
        swap(&cropLeft, &cropRight)
    }
    if mirrorVertically {
        swap(&cropTop, &cropBottom)
    }

    switch rotation {
    default:
        var values: [Float] = [
            -1.0, -1.0, cropLeft, cropBottom,
            1.0, -1.0, cropRight, cropBottom,
            -1.0,  1.0, cropLeft, cropTop,
            1.0,  1.0, cropRight, cropTop
        ]
        memcpy(buffer, &values, values.count * MemoryLayout.size(ofValue: values[0]));
    }
}

@available(iOS 13.0, *)
private protocol FrameBufferRenderingState {
    var frameSize: CGSize? { get }
    var mirrorHorizontally: Bool { get }
    var mirrorVertically: Bool { get }

    func encode(renderingContext: MetalVideoRenderingContext, vertexBuffer: MTLBuffer, renderEncoder: MTLRenderCommandEncoder) -> Bool
}

@available(iOS 13.0, *)
private final class BlitRenderingState {
    static func encode(renderingContext: MetalVideoRenderingContext, texture: MTLTexture, vertexBuffer: MTLBuffer, renderEncoder: MTLRenderCommandEncoder) -> Bool {
        renderEncoder.setRenderPipelineState(renderingContext.blitPipelineState)

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        renderEncoder.setFragmentTexture(texture, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)

        return true
    }
}

@available(iOS 13.0, *)
private final class NV12FrameBufferRenderingState: FrameBufferRenderingState {
    private var yTexture: MTLTexture?
    private var uvTexture: MTLTexture?

    private(set) var mirrorHorizontally: Bool = false
    private(set) var mirrorVertically: Bool = false

    var frameSize: CGSize? {
        if let yTexture = self.yTexture {
            return CGSize(width: yTexture.width, height: yTexture.height)
        } else {
            return nil
        }
    }

    func updateTextureBuffers(renderingContext: MetalVideoRenderingContext, frameBuffer: OngoingGroupCallContext.VideoFrameData.NativeBuffer, mirrorHorizontally: Bool, mirrorVertically: Bool) {
        let pixelBuffer = frameBuffer.pixelBuffer

        var lumaTexture: MTLTexture?
        var chromaTexture: MTLTexture?
        var outTexture: CVMetalTexture?

        let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

        var indexPlane = 0
        var result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, renderingContext.textureCache, pixelBuffer, nil, .r8Unorm, lumaWidth, lumaHeight, indexPlane, &outTexture)
        if result == kCVReturnSuccess, let outTexture = outTexture {
            lumaTexture = CVMetalTextureGetTexture(outTexture)
        }
        outTexture = nil

        indexPlane = 1
        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, renderingContext.textureCache, pixelBuffer, nil, .rg8Unorm, lumaWidth / 2, lumaHeight / 2, indexPlane, &outTexture)
        if result == kCVReturnSuccess, let outTexture = outTexture {
            chromaTexture = CVMetalTextureGetTexture(outTexture)
        }
        outTexture = nil

        if let lumaTexture = lumaTexture, let chromaTexture = chromaTexture {
            self.yTexture = lumaTexture
            self.uvTexture = chromaTexture
        } else {
            self.yTexture = nil
            self.uvTexture = nil
        }

        self.mirrorHorizontally = mirrorHorizontally
        self.mirrorVertically = mirrorVertically
    }

    func encode(renderingContext: MetalVideoRenderingContext, vertexBuffer: MTLBuffer, renderEncoder: MTLRenderCommandEncoder) -> Bool {
        guard let yTexture = self.yTexture, let uvTexture = self.uvTexture else {
            return false
        }

        renderEncoder.setRenderPipelineState(renderingContext.nv12PipelineState)

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        renderEncoder.setFragmentTexture(yTexture, index: 0)
        renderEncoder.setFragmentTexture(uvTexture, index: 1)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)

        return true
    }
}

@available(iOS 13.0, *)
private final class I420FrameBufferRenderingState: FrameBufferRenderingState {
    private var yTexture: MTLTexture?
    private var uTexture: MTLTexture?
    private var vTexture: MTLTexture?

    private var lumaTextureDescriptorSize: CGSize?
    private var lumaTextureDescriptor: MTLTextureDescriptor?
    private var chromaTextureDescriptor: MTLTextureDescriptor?

    private(set) var mirrorHorizontally: Bool = false
    private(set) var mirrorVertically: Bool = false

    var frameSize: CGSize? {
        if let yTexture = self.yTexture {
            return CGSize(width: yTexture.width, height: yTexture.height)
        } else {
            return nil
        }
    }

    func updateTextureBuffers(renderingContext: MetalVideoRenderingContext, frameBuffer: OngoingGroupCallContext.VideoFrameData.I420Buffer) {
        let lumaSize = CGSize(width: frameBuffer.width, height: frameBuffer.height)

        if lumaSize != lumaTextureDescriptorSize || lumaTextureDescriptor == nil || chromaTextureDescriptor == nil {
            self.lumaTextureDescriptorSize = lumaSize

            let lumaTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: frameBuffer.width, height: frameBuffer.height, mipmapped: false)
            lumaTextureDescriptor.usage = .shaderRead
            self.lumaTextureDescriptor = lumaTextureDescriptor

            self.yTexture = renderingContext.device.makeTexture(descriptor: lumaTextureDescriptor)

            let chromaTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: frameBuffer.width / 2, height: frameBuffer.height / 2, mipmapped: false)
            chromaTextureDescriptor.usage = .shaderRead
            self.chromaTextureDescriptor = chromaTextureDescriptor

            self.uTexture = renderingContext.device.makeTexture(descriptor: chromaTextureDescriptor)
            self.vTexture = renderingContext.device.makeTexture(descriptor: chromaTextureDescriptor)
        }

        guard let yTexture = self.yTexture, let uTexture = self.uTexture, let vTexture = self.vTexture else {
            return
        }

        frameBuffer.y.withUnsafeBytes { bufferPointer in
            if let baseAddress = bufferPointer.baseAddress {
                yTexture.replace(region: MTLRegionMake2D(0, 0, yTexture.width, yTexture.height), mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: frameBuffer.strideY)
            }
        }

        frameBuffer.u.withUnsafeBytes { bufferPointer in
            if let baseAddress = bufferPointer.baseAddress {
                uTexture.replace(region: MTLRegionMake2D(0, 0, uTexture.width, uTexture.height), mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: frameBuffer.strideU)
            }
        }

        frameBuffer.v.withUnsafeBytes { bufferPointer in
            if let baseAddress = bufferPointer.baseAddress {
                vTexture.replace(region: MTLRegionMake2D(0, 0, vTexture.width, vTexture.height), mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: frameBuffer.strideV)
            }
        }
    }

    func encode(renderingContext: MetalVideoRenderingContext, vertexBuffer: MTLBuffer, renderEncoder: MTLRenderCommandEncoder) -> Bool {
        guard let yTexture = self.yTexture, let uTexture = self.uTexture, let vTexture = self.vTexture else {
            return false
        }

        renderEncoder.setRenderPipelineState(renderingContext.i420PipelineState)

        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        renderEncoder.setFragmentTexture(yTexture, index: 0)
        renderEncoder.setFragmentTexture(uTexture, index: 1)
        renderEncoder.setFragmentTexture(vTexture, index: 2)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)

        return true
    }
}

@available(iOS 13.0, *)
final class MetalVideoRenderingView: UIView, VideoRenderingView {
    static override var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }

    private weak var renderingContext: MetalVideoRenderingContext?
    private var renderingContextIndex: Int?

    private let blur: Bool

    private let vertexBuffer: MTLBuffer

    private var frameBufferRenderingState: FrameBufferRenderingState?
    private var blurInputTexture: MTLTexture?
    private var blurOutputTexture: MTLTexture?

    fileprivate private(set) var isEnabled: Bool = false
    fileprivate var needsRedraw: Bool = false
    fileprivate let numberOfUsedDrawables = Atomic<Int>(value: 0)

    private var onFirstFrameReceived: ((Float) -> Void)?
    private var onOrientationUpdated: ((PresentationCallVideoView.Orientation, CGFloat) -> Void)?
    private var onIsMirroredUpdated: ((Bool) -> Void)?

    private var didReportFirstFrame: Bool = false
    private var currentOrientation: PresentationCallVideoView.Orientation = .rotation0
    private var currentAspect: CGFloat = 1.0

    private var disposable: Disposable?

    init?(renderingContext: MetalVideoRenderingContext, input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>, blur: Bool) {
        self.renderingContext = renderingContext
        self.blur = blur

        let vertexBufferArray = Array<Float>(repeating: 0, count: 16)
        guard let vertexBuffer = renderingContext.device.makeBuffer(bytes: vertexBufferArray, length: vertexBufferArray.count * MemoryLayout.size(ofValue: vertexBufferArray[0]), options: [.cpuCacheModeWriteCombined]) else {
            return nil
        }
        self.vertexBuffer = vertexBuffer

        super.init(frame: CGRect())

        self.renderingContextIndex = renderingContext.add(view: self)

        self.metalLayer.device = renderingContext.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.allowsNextDrawableTimeout = true

        self.disposable = input.start(next: { [weak self] videoFrameData in
            Queue.mainQueue().async {
                self?.addFrame(videoFrameData)
            }
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
        if let renderingContext = self.renderingContext, let renderingContextIndex = self.renderingContextIndex {
            renderingContext.remove(index: renderingContextIndex)
        }
    }

    private func addFrame(_ videoFrameData: OngoingGroupCallContext.VideoFrameData) {
        let aspect = CGFloat(videoFrameData.width) / CGFloat(videoFrameData.height)
        var isAspectUpdated = false
        if self.currentAspect != aspect {
            self.currentAspect = aspect
            isAspectUpdated = true
        }

        let videoFrameOrientation = PresentationCallVideoView.Orientation(videoFrameData.orientation)
        var isOrientationUpdated = false
        if self.currentOrientation != videoFrameOrientation {
            self.currentOrientation = videoFrameOrientation
            isOrientationUpdated = true
        }

        if isAspectUpdated || isOrientationUpdated {
            self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
        }

        if !self.didReportFirstFrame {
            self.didReportFirstFrame = true
            self.onFirstFrameReceived?(Float(self.currentAspect))
        }

        if self.isEnabled, let renderingContext = self.renderingContext {
            switch videoFrameData.buffer {
            case let .native(buffer):
                let renderingState: NV12FrameBufferRenderingState
                if let current = self.frameBufferRenderingState as? NV12FrameBufferRenderingState {
                    renderingState = current
                } else {
                    renderingState = NV12FrameBufferRenderingState()
                    self.frameBufferRenderingState = renderingState
                }
                renderingState.updateTextureBuffers(renderingContext: renderingContext, frameBuffer: buffer, mirrorHorizontally: videoFrameData.mirrorHorizontally, mirrorVertically: videoFrameData.mirrorVertically)
                self.needsRedraw = true
            case let .i420(buffer):
                let renderingState: I420FrameBufferRenderingState
                if let current = self.frameBufferRenderingState as? I420FrameBufferRenderingState {
                    renderingState = current
                } else {
                    renderingState = I420FrameBufferRenderingState()
                    self.frameBufferRenderingState = renderingState
                }
                renderingState.updateTextureBuffers(renderingContext: renderingContext, frameBuffer: buffer)
                self.needsRedraw = true
            default:
                break
            }
        }
    }

    fileprivate func encode(commandBuffer: MTLCommandBuffer) -> MTLDrawable? {
        guard let renderingContext = self.renderingContext else {
            return nil
        }
        if self.numberOfUsedDrawables.with({ $0 }) >= 2 {
            return nil
        }
        guard let frameBufferRenderingState = self.frameBufferRenderingState else {
            return nil
        }

        guard let frameSize = frameBufferRenderingState.frameSize else {
            return nil
        }
        let mirrorHorizontally = frameBufferRenderingState.mirrorHorizontally
        let mirrorVertically = frameBufferRenderingState.mirrorVertically

        let drawableSize: CGSize
        if self.blur {
            drawableSize = frameSize.aspectFitted(CGSize(width: 64.0, height: 64.0))
        } else {
            drawableSize = frameSize
        }

        if self.blur {
            if let current = self.blurInputTexture, current.width == Int(drawableSize.width) && current.height == Int(drawableSize.height) {
            } else {
                let blurTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
                blurTextureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

                if let texture = renderingContext.device.makeTexture(descriptor: blurTextureDescriptor) {
                    self.blurInputTexture = texture
                }
            }

            if let current = self.blurOutputTexture, current.width == Int(drawableSize.width) && current.height == Int(drawableSize.height) {
            } else {
                let blurTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
                blurTextureDescriptor.usage = [.shaderRead, .shaderWrite]

                if let texture = renderingContext.device.makeTexture(descriptor: blurTextureDescriptor) {
                    self.blurOutputTexture = texture
                }
            }
        }

        if self.metalLayer.drawableSize != drawableSize {
            self.metalLayer.drawableSize = drawableSize
        }

        getCubeVertexData(
            cropX: 0,
            cropY: 0,
            cropWidth: Int(drawableSize.width),
            cropHeight: Int(drawableSize.height),
            frameWidth: Int(drawableSize.width),
            frameHeight: Int(drawableSize.height),
            rotation: 0,
            mirrorHorizontally: mirrorHorizontally,
            mirrorVertically: mirrorVertically,
            buffer: self.vertexBuffer.contents().assumingMemoryBound(to: Float.self)
        )

        guard let drawable = self.metalLayer.nextDrawable() else {
            return nil
        }

        if let blurInputTexture = self.blurInputTexture, let blurOutputTexture = self.blurOutputTexture {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = blurInputTexture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.0,
                green: 0.0,
                blue: 0.0,
                alpha: 1.0
            )

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return nil
            }

            let _ = frameBufferRenderingState.encode(renderingContext: renderingContext, vertexBuffer: self.vertexBuffer, renderEncoder: renderEncoder)

            renderEncoder.endEncoding()

            renderingContext.blurKernel.encode(commandBuffer: commandBuffer, sourceTexture: blurInputTexture, destinationTexture: blurOutputTexture)

            let blitPassDescriptor = MTLRenderPassDescriptor()
            blitPassDescriptor.colorAttachments[0].texture = drawable.texture
            blitPassDescriptor.colorAttachments[0].loadAction = .clear
            blitPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.0,
                green: 0.0,
                blue: 0.0,
                alpha: 1.0
            )

            guard let blitEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: blitPassDescriptor) else {
                return nil
            }

            let _ = BlitRenderingState.encode(renderingContext: renderingContext, texture: blurOutputTexture, vertexBuffer: self.vertexBuffer, renderEncoder: blitEncoder)

            blitEncoder.endEncoding()
        } else {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.0,
                green: 0.0,
                blue: 0.0,
                alpha: 1.0
            )

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return nil
            }

            let _ = frameBufferRenderingState.encode(renderingContext: renderingContext, vertexBuffer: self.vertexBuffer, renderEncoder: renderEncoder)

            renderEncoder.endEncoding()
        }

        return drawable
    }

    func setOnFirstFrameReceived(_ f: @escaping (Float) -> Void) {
        self.onFirstFrameReceived = f
        self.didReportFirstFrame = false
    }

    func setOnOrientationUpdated(_ f: @escaping (PresentationCallVideoView.Orientation, CGFloat) -> Void) {
        self.onOrientationUpdated = f
    }

    func getOrientation() -> PresentationCallVideoView.Orientation {
        return self.currentOrientation
    }

    func getAspect() -> CGFloat {
        return self.currentAspect
    }

    func setOnIsMirroredUpdated(_ f: @escaping (Bool) -> Void) {
        self.onIsMirroredUpdated = f
    }

    func updateIsEnabled(_ isEnabled: Bool) {
        if self.isEnabled != isEnabled {
            self.isEnabled = isEnabled

            if self.isEnabled {
                self.needsRedraw = true
            }
        }
    }
}

@available(iOS 13.0, *)
class MetalVideoRenderingContext {
    private final class ViewReference {
        weak var view: MetalVideoRenderingView?

        init(view: MetalVideoRenderingView) {
            self.view = view
        }
    }

    fileprivate let device: MTLDevice
    fileprivate let textureCache: CVMetalTextureCache
    fileprivate let blurKernel: MPSImageGaussianBlur

    fileprivate let blitPipelineState: MTLRenderPipelineState
    fileprivate let nv12PipelineState: MTLRenderPipelineState
    fileprivate let i420PipelineState: MTLRenderPipelineState

    private let commandQueue: MTLCommandQueue

    private var displayLink: ConstantDisplayLinkAnimator?
    private var viewReferences = Bag<ViewReference>()

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device

        var textureCache: CVMetalTextureCache?
        let _ = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &textureCache)
        if let textureCache = textureCache {
            self.textureCache = textureCache
        } else {
            return nil
        }

        let mainBundle = Bundle(for: MetalVideoRenderingView.self)

        guard let path = mainBundle.path(forResource: "TelegramCallsUIBundle", ofType: "bundle") else {
            return nil
        }
        guard let bundle = Bundle(path: path) else {
            return nil
        }
        guard let defaultLibrary = try? self.device.makeDefaultLibrary(bundle: bundle) else {
            return nil
        }

        self.blurKernel = MPSImageGaussianBlur(device: self.device, sigma: 3.0)

        func makePipelineState(vertexProgram: String, fragmentProgram: String) -> MTLRenderPipelineState? {
            guard let loadedVertexProgram = defaultLibrary.makeFunction(name: vertexProgram) else {
                return nil
            }
            guard let loadedFragmentProgram = defaultLibrary.makeFunction(name: fragmentProgram) else {
                return nil
            }

            let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
            pipelineStateDescriptor.vertexFunction = loadedVertexProgram
            pipelineStateDescriptor.fragmentFunction = loadedFragmentProgram
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) else {
                return nil
            }

            return pipelineState
        }

        guard let blitPipelineState = makePipelineState(vertexProgram: "nv12VertexPassthrough", fragmentProgram: "blitFragmentColorConversion") else {
            return nil
        }
        self.blitPipelineState = blitPipelineState

        guard let nv12PipelineState = makePipelineState(vertexProgram: "nv12VertexPassthrough", fragmentProgram: "nv12FragmentColorConversion") else {
            return nil
        }
        self.nv12PipelineState = nv12PipelineState

        guard let i420PipelineState = makePipelineState(vertexProgram: "i420VertexPassthrough", fragmentProgram: "i420FragmentColorConversion") else {
            return nil
        }
        self.i420PipelineState = i420PipelineState

        guard let commandQueue = self.device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
        
        self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.redraw()
        })
        self.displayLink?.isPaused = false
    }

    func updateVisibility(isVisible: Bool) {
        self.displayLink?.isPaused = !isVisible
    }

    fileprivate func add(view: MetalVideoRenderingView) -> Int {
        return self.viewReferences.add(ViewReference(view: view))
    }

    fileprivate func remove(index: Int) {
        self.viewReferences.remove(index)
    }

    private func redraw() {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }

        var drawables: [MTLDrawable] = []
        var takenViewReferences: [ViewReference] = []

        for viewReference in self.viewReferences.copyItems() {
            guard let videoView = viewReference.view else {
                continue
            }

            if !videoView.needsRedraw {
                continue
            }
            videoView.needsRedraw = false

            if let drawable = videoView.encode(commandBuffer: commandBuffer) {
                let numberOfUsedDrawables = videoView.numberOfUsedDrawables
                let _ = numberOfUsedDrawables.modify {
                    return $0 + 1
                }
                takenViewReferences.append(viewReference)

                drawable.addPresentedHandler { _ in
                    let _ = numberOfUsedDrawables.modify {
                        return max(0, $0 - 1)
                    }
                }

                drawables.append(drawable)
            }
        }

        if drawables.isEmpty {
            return
        }

        if drawables.count > 10 {
            print("Schedule \(drawables.count) drawables")
        }

        commandBuffer.addScheduledHandler { _ in
            for drawable in drawables {
                drawable.present()
            }
        }

        commandBuffer.commit()
    }
}

#endif
