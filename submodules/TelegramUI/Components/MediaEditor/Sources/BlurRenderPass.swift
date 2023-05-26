import Foundation
import Metal
import MetalPerformanceShaders
import simd

enum MediaEditorBlurMode {
    case off
    case radial
    case linear
    case portrait
}

struct MediaEditorBlur {
    var dimensions: simd_float2
    var position: simd_float2
    var aspectRatio: simd_float1
    var size: simd_float1
    var falloff: simd_float1
    var rotation: simd_float1
}

private final class BlurGaussianPass: RenderPass {
    private var cachedTexture: MTLTexture?
    fileprivate var blur: MPSImageGaussianBlur?
    
    var updated: ((Data) -> Void)?
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
    
    func process(input: MTLTexture, intensity: Float, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        let radius = round(4.0 + intensity * 26.0)
        if self.blur?.sigma != radius {
            self.blur = MPSImageGaussianBlur(device: device, sigma: radius)
            self.blur?.edgeMode = .clamp
        }
        
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = input.width
            textureDescriptor.height = input.height
            textureDescriptor.pixelFormat = input.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input
            }
            self.cachedTexture = texture
        }
        
        if let blur = self.blur, let destinationTexture = self.cachedTexture {
            blur.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: destinationTexture)
        }
        
        return self.cachedTexture
    }
}

private final class BlurLinearPass: DefaultRenderPass {
    override var fragmentShaderFunctionName: String {
        return "blurLinearFragmentShader"
    }
    
    func process(input: MTLTexture, blurredTexture: MTLTexture, values: MediaEditorBlur, output: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(input.width), height: Double(input.height),
            znear: -1.0, zfar: 1.0)
        )
        
        var values = values
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        renderCommandEncoder.setFragmentTexture(blurredTexture, index: 1)
        renderCommandEncoder.setFragmentBytes(&values, length: MemoryLayout<MediaEditorBlur>.size, index: 0)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return output
    }
}

private final class BlurRadialPass: DefaultRenderPass {
    override var fragmentShaderFunctionName: String {
        return "blurRadialFragmentShader"
    }
    
    func process(input: MTLTexture, blurredTexture: MTLTexture, values: MediaEditorBlur, output: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(input.width), height: Double(input.height),
            znear: -1.0, zfar: 1.0)
        )
        
        var values = values
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        renderCommandEncoder.setFragmentTexture(blurredTexture, index: 1)
        renderCommandEncoder.setFragmentBytes(&values, length: MemoryLayout<MediaEditorBlur>.size, index: 0)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return output
    }
}

private final class BlurPortraitPass: DefaultRenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    override var fragmentShaderFunctionName: String {
        return "blurPortraitFragmentShader"
    }
    
    func process(input: MTLTexture, blurredTexture: MTLTexture, maskTexture: MTLTexture, values: MediaEditorBlur, output: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.setupVerticesBuffer(device: device)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(input.width), height: Double(input.height),
            znear: -1.0, zfar: 1.0)
        )
        
        var values = values
        renderCommandEncoder.setFragmentTexture(input, index: 0)
        renderCommandEncoder.setFragmentTexture(blurredTexture, index: 1)
        renderCommandEncoder.setFragmentTexture(maskTexture, index: 2)
        renderCommandEncoder.setFragmentBytes(&values, length: MemoryLayout<MediaEditorBlur>.size, index: 0)
        
        self.encodeDefaultCommands(using: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        
        return output
    }
}


final class BlurRenderPass: RenderPass {
    fileprivate var cachedTexture: MTLTexture?
    
    var maskTexture: MTLTexture?
    
    private let blurPass = BlurGaussianPass()
    private let linearPass = BlurLinearPass()
    private let radialPass = BlurRadialPass()
    private let portraitPass = BlurPortraitPass()
    
    var value = MediaEditorBlur(
        dimensions: simd_float2(0.0, 0.0),
        position: simd_float2(0.5, 0.5),
        aspectRatio: 1.0,
        size: 0.2,
        falloff: 0.2,
        rotation: 0.0
    )
    var intensity: simd_float1 = 0.0
    var mode: MediaEditorBlurMode = .off
        
    func setup(device: MTLDevice, library: MTLLibrary) {
        self.blurPass.setup(device: device, library: library)
        self.linearPass.setup(device: device, library: library)
        self.radialPass.setup(device: device, library: library)
        self.portraitPass.setup(device: device, library: library)
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        self.process(input: input, maskTexture: self.maskTexture, device: device, commandBuffer: commandBuffer)
    }
    
    func process(input: MTLTexture, maskTexture: MTLTexture?, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard self.intensity > 0.005 && self.mode != .off else {
            return input
        }
        
        let width = input.width
        let height = input.height
                
        if self.cachedTexture == nil {
            self.value.aspectRatio = Float(height) / Float(width)
            
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
        
        guard let blurredTexture = self.blurPass.process(input: input, intensity: self.intensity, device: device, commandBuffer: commandBuffer), let output = self.cachedTexture else {
            return input
        }
        
        switch self.mode {
        case .linear:
            return self.linearPass.process(input: input, blurredTexture: blurredTexture, values: self.value, output: output, device: device, commandBuffer: commandBuffer)
        case .radial:
            return self.radialPass.process(input: input, blurredTexture: blurredTexture, values: self.value, output: output, device: device, commandBuffer: commandBuffer)
        case .portrait:
            if let maskTexture {
                return self.portraitPass.process(input: input, blurredTexture: blurredTexture, maskTexture: maskTexture, values: self.value, output: output, device: device, commandBuffer: commandBuffer)
            } else {
                return input
            }
        default:
            return input
        }
    }
}
