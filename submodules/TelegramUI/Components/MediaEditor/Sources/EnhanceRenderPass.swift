import Foundation
import UIKit
import Metal
import MetalPerformanceShaders
import simd
import CoreImage

struct TextureSize {
    let width: Int
    let height: Int
}

private final class EnhanceLightnessPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    override var fragmentShaderFunctionName: String {
        return "rgbToLightnessFragmentShader"
    }
    
    override var pixelFormat: MTLPixelFormat {
        return .r8Unorm
    }
    
    func process(input: MTLTexture, size: TextureSize, scale: simd_float2, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        
        let width = size.width
        let height = size.height
      
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = width
            textureDescriptor.height = height
            textureDescriptor.pixelFormat = .r8Unorm
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return nil
            }
            texture.label = "lightnessTexture"
            self.cachedTexture = texture
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(size.width), height: Double(size.height),
            znear: -1.0, zfar: 1.0)
        )
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .mirrorRepeat
        samplerDescriptor.tAddressMode = .mirrorRepeat
        samplerDescriptor.rAddressMode = .mirrorRepeat
        
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            return nil
        }
        
        var scale = scale
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        renderCommandEncoder.setFragmentBytes(&scale, length: MemoryLayout<simd_float2>.size, index: 0)
        renderCommandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
}

private let binCount = 256
struct MediaEditorEnhanceLUTGeneratorParameters {
    var histogramBins: simd_uint1
    var clipLimit: simd_uint1
    var totalPixelCountPerTile: simd_uint1
    var numberOfLUTs: simd_uint1
}

private final class EnhanceLUTGeneratorPass: RenderPass {
    fileprivate var pipelineState: MTLComputePipelineState?
    fileprivate var histogramBuffer: MTLBuffer?
    fileprivate var calculation: MPSImageHistogram?
    
    private var lutTexture: MTLTexture?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        
    }
    
    func setup(gridSize: TextureSize, device: MTLDevice, library: MTLLibrary) {
        var histogramInfo = MPSImageHistogramInfo(
            numberOfHistogramEntries: binCount,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0,0,0,0),
            maxPixelValue: vector_float4(1,1,1,1)
        )
        
        let calculation = MPSImageHistogram(device: device, histogramInfo: &histogramInfo)
        calculation.zeroHistogram = false
        self.calculation = calculation
        
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.computeFunction = library.makeFunction(name: "enhanceGenerateLUT")
        
        do {
            self.pipelineState = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
    
    func process(input: MTLTexture, gridSize: TextureSize, clipLimit: Float, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        let lutCount = gridSize.width * gridSize.height
        let tileSize = TextureSize(width: input.width / gridSize.width, height: input.height / gridSize.height);
        let clipLimitValue = max(1, clipLimit * Float(tileSize.width * tileSize.height) / Float(binCount))
        
        if self.lutTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = binCount
            textureDescriptor.height = lutCount
            textureDescriptor.pixelFormat = .r8Unorm
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return nil
            }
            self.lutTexture = texture
            texture.label = "lutTexture"
        }
        
        guard let calculation = self.calculation, let histogramBuffer = device.makeBuffer(length: calculation.histogramSize(forSourceFormat: .r8Unorm) * lutCount, options: [.storageModePrivate]) else {
            return nil
        }
        
        let histogramSize = calculation.histogramSize(forSourceFormat: input.pixelFormat)
        for i in 0 ..< lutCount {
            let col = i % gridSize.width
            let row = i / gridSize.width
            calculation.clipRectSource = MTLRegionMake2D(col * tileSize.width, row * tileSize.height, tileSize.width, tileSize.height)
            
            calculation.encode(to: commandBuffer, sourceTexture: input, histogram: histogramBuffer, histogramOffset: i * histogramSize)
        }
    
        guard let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        guard let pipelineState = self.pipelineState else {
            return nil
        }
        
        var parameters = MediaEditorEnhanceLUTGeneratorParameters(
            histogramBins: UInt32(binCount),
            clipLimit: UInt32(clipLimitValue),
            totalPixelCountPerTile: UInt32(tileSize.width * tileSize.height),
            numberOfLUTs: UInt32(lutCount)
        )
        
        computeCommandEncoder.setComputePipelineState(pipelineState)
        computeCommandEncoder.setBuffer(histogramBuffer, offset: 0, index: 0)
        computeCommandEncoder.setBytes(&parameters, length: MemoryLayout<MediaEditorEnhanceLUTGeneratorParameters>.size, index: 1)
        computeCommandEncoder.setTexture(self.lutTexture, index: 0)

        let w = pipelineState.threadExecutionWidth
        let threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: (lutCount + w - 1) / w, height: 1, depth: 1)
        computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeCommandEncoder.endEncoding()
        
        return self.lutTexture!
    }
}

private final class EnhanceLookupPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    override var fragmentShaderFunctionName: String {
        return "enhanceColorLookupFragmentShader"
    }
    
    func process(input: MTLTexture, lookupTexture: MTLTexture, value: simd_float1, gridSize: simd_float2, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        
        let width = input.width
        let height = input.height
        
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = width
            textureDescriptor.height = height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input
            }
            self.cachedTexture = texture
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
        
        var gridSize = gridSize
        var value = value
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        renderCommandEncoder.setFragmentTexture(lookupTexture, index: 1)
        renderCommandEncoder.setFragmentBytes(&gridSize, length: MemoryLayout<simd_float2>.size, index: 0)
        renderCommandEncoder.setFragmentBytes(&value, length: MemoryLayout<simd_float1>.size, index: 1)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
}

final class EnhanceRenderPass: RenderPass {
    private let lightnessPass = EnhanceLightnessPass()
    private let lutGeneratorPass = EnhanceLUTGeneratorPass()
    private let lookupPass = EnhanceLookupPass()
    
    var value: simd_float1 = 0.0
    
    let clipLimit: Float = 1.25
    let tileGridSize: TextureSize = TextureSize(width: 4, height: 4)
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        self.lightnessPass.setup(device: device, library: library)
        self.lutGeneratorPass.setup(gridSize: self.tileGridSize, device: device, library: library)
        self.lookupPass.setup(device: device, library: library)
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard self.value > 0.005 else {
            return input
        }
        let dY = (self.tileGridSize.height - (input.height % self.tileGridSize.height)) % self.tileGridSize.height
        let dX = (self.tileGridSize.width - (input.width % self.tileGridSize.width)) % self.tileGridSize.width
        
        let lightnessSize = TextureSize(width: input.width + dX, height: input.height + dY)
        let lightnessScale = simd_float2(Float(input.width + dX) / Float(input.width), Float(input.height + dY) / Float(input.height))
        
        let lightness = self.lightnessPass.process(input: input, size: lightnessSize, scale: lightnessScale, device: device, commandBuffer: commandBuffer)
        
        let lookupTexture = self.lutGeneratorPass.process(input: lightness!, gridSize: self.tileGridSize, clipLimit: self.clipLimit, device: device, commandBuffer: commandBuffer)
        
        let gridSize = simd_float2(Float(self.tileGridSize.width), Float(self.tileGridSize.height))
        let output = self.lookupPass.process(input: input, lookupTexture: lookupTexture!, value: self.value, gridSize: gridSize, device: device, commandBuffer: commandBuffer)
        
        return output
    }
}
