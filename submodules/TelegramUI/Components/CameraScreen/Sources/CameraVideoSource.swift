import AVFoundation
import Metal
import CoreVideo
import Display
import SwiftSignalKit
import Camera
import MetalEngine

final class CameraVideoSource: VideoSource {
    private var device: MTLDevice
    private var textureCache: CVMetalTextureCache?
        
    private(set) var cameraVideoOutput: CameraVideoOutput!
    
    public private(set) var currentOutput: Output?
    private var onUpdatedListeners = Bag<() -> Void>()
        
    public var sourceId: Int = 0
    public var sizeMultiplicator: CGPoint = CGPoint(x: 1.0, y: 1.0)
    
    public init?() {
        self.device = MetalEngine.shared.device
                
        self.cameraVideoOutput = CameraVideoOutput(sink: { [weak self] buffer, mirror in
            self?.push(buffer, mirror: mirror)
        })

        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache)
    }
    
    public func addOnUpdated(_ f: @escaping () -> Void) -> Disposable {
        let index = self.onUpdatedListeners.add(f)
        
        return ActionDisposable { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.onUpdatedListeners.remove(index)
            }
        }
    }
    
    private func push(_ sampleBuffer: CMSampleBuffer, mirror: Bool) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
                  
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var cvMetalTextureY: CVMetalTexture?
        var status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
        guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
            return
        }
        var cvMetalTextureUV: CVMetalTexture?
        status = CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache!, buffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
        guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
            return
        }

        var resolution = CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height))
        resolution.width = floor(resolution.width * self.sizeMultiplicator.x)
        resolution.height = floor(resolution.height * self.sizeMultiplicator.y)
        
        self.currentOutput = Output(
            resolution: resolution,
            textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                y: yTexture,
                uv: uvTexture
            )),
            dataBuffer: Output.NativeDataBuffer(pixelBuffer: buffer),
            mirrorDirection: mirror ? [.vertical] : [],
            sourceId: self.sourceId
        )
        
        for onUpdated in self.onUpdatedListeners.copyItems() {
            onUpdated()
        }
    }
}
