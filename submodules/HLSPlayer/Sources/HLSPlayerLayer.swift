import AVFoundation
import TelegramCore
import MetalKit
import MetalPerformanceShaders

public final class HLSPlayerLayer: CALayer {

    private weak var player: HLSPlayer?

    private var mtlDevice: MTLDevice?
    private var mtlCommandQueue: MTLCommandQueue?
    private var mtlLibrary: MTLLibrary?
    private var mtlTexture: MTLTexture?
    private var mtlRenderPipelineState: MTLRenderPipelineState?
    private var mtkView: MTKView?

    private var width = 0
    private var height = 0

    public init(player: HLSPlayer?) {
        self.player = player
        super.init()
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public func setPlayer(at player: HLSPlayer?) {
        self.player = player
        self.player?.layerDelegate = self
    }
}

// MARK: - LayerDelegate

extension HLSPlayerLayer: HLSPlayer.LayerDelegate {

    func play() {
        mtkView?.isPaused = false
    }

    func pause() {
        mtkView?.isPaused = true
    }

    func stop() {
        mtkView = nil
    }

    func rendering(at sampleBuffer: CMSampleBuffer) -> Bool {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              texture(at: pixelBuffer) else {
            // TODO: Modify without using Metal if necessary
            Logger.shared.log("HLSPlayer", "Error Metal not available")
            return false
        }

        replaceTexture(from: pixelBuffer)

        DispatchQueue.main.async {
            self.mtkView?.setNeedsDisplay()
        }

        return true
    }
}

// MARK: - MTKViewDelegate

extension HLSPlayerLayer: MTKViewDelegate {

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }
    
    public func draw(in view: MTKView) {
        guard let commandBuffer = mtlCommandQueue?.makeCommandBuffer(),
              let renderPipelineState = mtlRenderPipelineState,
              let texture = mtlTexture else {
            return
        }

        if let currentDrawable = view.currentDrawable {
            let passDescriptor = MTLRenderPassDescriptor()
            let colorAttachment = MTLRenderPassColorAttachmentDescriptor()
            colorAttachment.texture = texture
            colorAttachment.loadAction = .clear
            colorAttachment.storeAction = .store
            passDescriptor.colorAttachments[0] = colorAttachment
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
            renderEncoder?.setRenderPipelineState(renderPipelineState)
            renderEncoder?.setFragmentTexture(texture, index: 0)
            renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
            renderEncoder?.endEncoding()
            commandBuffer.present(currentDrawable)
        } else {
            DispatchQueue.main.async {
                /*
                let mpsImage = MPSImage(texture: texture, featureChannels: 4)
                self.contents = CIImage(mtlTexture: mpsImage.texture, options: nil)
                 */
                let ciContext = CIContext(mtlDevice: texture.device)
                if let ciImage = CIImage(mtlTexture: texture, options: nil) {
                    self.contents = ciContext.createCGImage(ciImage, from: ciImage.extent)
                }
            }
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

// MARK: - Configuration

private extension HLSPlayerLayer {

    func configure() {
        player?.layerDelegate = self

        configureMetal()

        let mtkView = MTKView()
        mtkView.device = mtlDevice
        mtkView.frame = frame
        mtkView.delegate = self
        mtkView.enableSetNeedsDisplay = true
        mtkView.contentScaleFactor = 1.0
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = true
        addSublayer(mtkView.layer)
        self.mtkView = mtkView

        shouldRasterize = true
        drawsAsynchronously = true
    }

    func configureMetal() {
        mtlDevice = MTLCreateSystemDefaultDevice()
        mtlCommandQueue = mtlDevice?.makeCommandQueue()
        let vertexShaderSource = """
        vertex float4 vertexShader(uint vertexID [[vertex_id]]) {
            return float4(vertexID, 0.0, 1.0, 1.0); 
        }
        """
        mtlLibrary = try? mtlDevice?.makeLibrary(source: vertexShaderSource, options: nil)
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = mtlLibrary?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = mtlLibrary?.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView?.colorPixelFormat ?? .bgra8Unorm
        mtlRenderPipelineState = try? mtlDevice?.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    func texture(at pixelBuffer: CVPixelBuffer) -> Bool {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        guard mtlTexture != nil, self.width == width else {
            let height = CVPixelBufferGetHeight(pixelBuffer)
            self.width = width
            self.height = height
            guard width > 0, height > 0 else { return false }
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            let texture = mtlDevice?.makeTexture(descriptor: textureDescriptor)
            mtlTexture = texture
            return texture != nil
        }
        return true
    }

    func replaceTexture(from pixelBuffer: CVPixelBuffer) {
        guard let commandBuffer = mtlCommandQueue?.makeCommandBuffer() else { return }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard let pixelBufferAdress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerImage = CVPixelBufferGetDataSize(pixelBuffer)
        mtlTexture?.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: pixelBufferAdress, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
