import Foundation
import Metal
import simd
import MetalPerformanceShaders

final class HistogramCalculationPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    fileprivate var histogramBuffer: MTLBuffer?
    fileprivate var calculation: MPSImageHistogram?
    
    var isEnabled = false
    var updated: ((Data) -> Void)?
    
    override var fragmentShaderFunctionName: String {
        return "histogramPrepareFragmentShader"
    }
    
    override var pixelFormat: MTLPixelFormat  {
        return .r8Unorm
    }
    
    override func setup(device: MTLDevice, library: MTLLibrary) {
        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: 256,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0,0,0,0),
            maxPixelValue: vector_float4(1,1,1,1)
        )
        
        let calculation = MPSImageHistogram(device: device, histogramInfo: &histogramInfo)
        calculation.zeroHistogram = true
                
        let histogramBufferLength = calculation.histogramSize(forSourceFormat: .bgra8Unorm)
        let lumaHistogramBufferLength = calculation.histogramSize(forSourceFormat: .r8Unorm)
        
        if let histogramBuffer = device.makeBuffer(length: histogramBufferLength + lumaHistogramBufferLength, options: [.storageModeShared]) {
            self.calculation = calculation
            self.histogramBuffer = histogramBuffer
        }
        
        super.setup(device: device, library: library)
    }
    
    override func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        if self.isEnabled {
            self.setupVerticesBuffer(device: device)
            
            let width = input.width
            let height = input.height
            
            if self.cachedTexture == nil || self.cachedTexture?.width != width || self.cachedTexture?.height != height {
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.textureType = .type2D
                textureDescriptor.width = width
                textureDescriptor.height = height
                textureDescriptor.pixelFormat = .r8Unorm
                textureDescriptor.storageMode = .shared
                textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
                guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                    return input
                }
                self.cachedTexture = texture
                texture.label = "lumaTexture"
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return input
            }
            
            renderCommandEncoder.setViewport(MTLViewport(
                originX: 0, originY: 0,
                width: Double(width), height: Double(height),
                znear: -1.0, zfar: 1.0)
            )
            
            renderCommandEncoder.setFragmentTexture(input, index: 0)

            self.encodeDefaultCommands(using: renderCommandEncoder)
            
            renderCommandEncoder.endEncoding()
            
            if let histogramBuffer = self.histogramBuffer, let calculation = self.calculation {
                calculation.encode(to: commandBuffer, sourceTexture: input, histogram: histogramBuffer, histogramOffset: 0)
                
                let lumaHistogramBufferLength = calculation.histogramSize(forSourceFormat: .r8Unorm)
                calculation.encode(to: commandBuffer, sourceTexture: self.cachedTexture!, histogram: histogramBuffer, histogramOffset: histogramBuffer.length - lumaHistogramBufferLength)
                
                let histogramData = Data(bytes: histogramBuffer.contents(), count: histogramBuffer.length)
                self.updated?(histogramData)
            }
        }
        
        return input
    }
}
