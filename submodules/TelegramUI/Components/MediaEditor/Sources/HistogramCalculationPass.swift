import Foundation
import Metal
import simd
import MetalPerformanceShaders

final class HistogramCalculationPass: RenderPass {
    fileprivate var histogramInfoBuffer: MTLBuffer?
    fileprivate var calculation: MPSImageHistogram?
    
    var updated: ((Data) -> Void)?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: 256,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0,0,0,0),
            maxPixelValue: vector_float4(1,1,1,1)
        )
        
        let calculation = MPSImageHistogram(device: device, histogramInfo: &histogramInfo)
        calculation.zeroHistogram = false
        
        let bufferLength = calculation.histogramSize(forSourceFormat: .bgra8Unorm)
        
        if let histogramInfoBuffer = device.makeBuffer(length: bufferLength, options: [.storageModeShared]) {
            self.calculation = calculation
            self.histogramInfoBuffer = histogramInfoBuffer
        }
    }
    
    func process(input: MTLTexture, rotation: TextureRotation, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        if let histogramInfoBuffer = self.histogramInfoBuffer, let calculation = self.calculation {
            calculation.encode(to: commandBuffer, sourceTexture: input, histogram: histogramInfoBuffer, histogramOffset: 0)
            
            let data = Data(bytes: histogramInfoBuffer.contents(), count: histogramInfoBuffer.length)
            self.updated?(data)
        }
        
        return input
    }
}
