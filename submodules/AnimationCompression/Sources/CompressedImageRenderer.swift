import Foundation
import UIKit
import Metal
import MetalKit
import simd
import DctHuffman

private struct Vertex {
    var position: vector_float2
    var textureCoordinate: vector_float2
}

public final class CompressedImageRenderer {
    private final class Shared {
        static let shared: Shared = {
            return Shared(sharedContext: AnimationCompressor.SharedContext.shared)!
        }()
        
        let sharedContext: AnimationCompressor.SharedContext
        
        let computeIdctPipelineState: MTLComputePipelineState
        let renderIdctPipelineState: MTLRenderPipelineState
        let renderRgbPipelineState: MTLRenderPipelineState
        let renderYuvaPipelineState: MTLRenderPipelineState
        let commandQueue: MTLCommandQueue
        
        init?(sharedContext: AnimationCompressor.SharedContext) {
            self.sharedContext = sharedContext
            
            guard let idctFunction = self.sharedContext.defaultLibrary.makeFunction(name: "idctKernel") else {
                return nil
            }
            
            guard let computeIdctPipelineState = try? self.sharedContext.device.makeComputePipelineState(function: idctFunction) else {
                return nil
            }
            self.computeIdctPipelineState = computeIdctPipelineState
            
            guard let vertexShader = self.sharedContext.defaultLibrary.makeFunction(name: "vertexShader") else {
                return nil
            }
            guard let samplingIdctShader = self.sharedContext.defaultLibrary.makeFunction(name: "samplingIdctShader") else {
                return nil
            }
            guard let samplingRgbShader = self.sharedContext.defaultLibrary.makeFunction(name: "samplingRgbShader") else {
                return nil
            }
            guard let samplingYuvaShader = self.sharedContext.defaultLibrary.makeFunction(name: "samplingYuvaShader") else {
                return nil
            }
            
            let idctPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            idctPipelineStateDescriptor.label = "Render IDCT Pipeline"
            idctPipelineStateDescriptor.vertexFunction = vertexShader
            idctPipelineStateDescriptor.fragmentFunction = samplingIdctShader
            idctPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            guard let renderIdctPipelineState = try? self.sharedContext.device.makeRenderPipelineState(descriptor: idctPipelineStateDescriptor) else {
                return nil
            }
            self.renderIdctPipelineState = renderIdctPipelineState
            
            let rgbPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            rgbPipelineStateDescriptor.label = "Render RGB Pipeline"
            rgbPipelineStateDescriptor.vertexFunction = vertexShader
            rgbPipelineStateDescriptor.fragmentFunction = samplingRgbShader
            rgbPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            guard let renderRgbPipelineState = try? self.sharedContext.device.makeRenderPipelineState(descriptor: rgbPipelineStateDescriptor) else {
                return nil
            }
            self.renderRgbPipelineState = renderRgbPipelineState
            
            let yuvaPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            yuvaPipelineStateDescriptor.label = "Render YUVA Pipeline"
            yuvaPipelineStateDescriptor.vertexFunction = vertexShader
            yuvaPipelineStateDescriptor.fragmentFunction = samplingYuvaShader
            yuvaPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            guard let renderYuvaPipelineState = try? self.sharedContext.device.makeRenderPipelineState(descriptor: yuvaPipelineStateDescriptor) else {
                return nil
            }
            self.renderYuvaPipelineState = renderYuvaPipelineState
            
            guard let commandQueue = self.sharedContext.device.makeCommandQueue() else {
                return nil
            }
            self.commandQueue = commandQueue
        }
    }
    
    private let sharedContext: AnimationCompressor.SharedContext
    private let shared: Shared
    
    private var compressedTextures: TextureSet?
    private var outputTextures: TextureSet?
    
    private var rgbTexture: Texture?
    
    private var yuvaTextures: TextureSet?

    public init?(sharedContext: AnimationCompressor.SharedContext) {
        self.sharedContext = sharedContext
        self.shared = Shared.shared
    }
    
    private func updateIdctTextures(compressedImage: AnimationCompressor.CompressedImageData) {
        self.rgbTexture = nil
        self.yuvaTextures = nil
        
        let readBuffer = ReadBuffer(data: compressedImage.data)
        if readBuffer.readInt32() != 0x543ee445 {
            return
        }
        if readBuffer.readInt32() != 4 {
            return
        }
        
        let width = Int(readBuffer.readInt32())
        let height = Int(readBuffer.readInt32())
        
        let compressedTextures: TextureSet
        if let current = self.compressedTextures, current.width == width, current.height == height {
            compressedTextures = current
        } else {
            guard let textures = TextureSet(
                device: self.sharedContext.device,
                width: width,
                height: height,
                descriptions: [
                    TextureSet.Description(
                        fractionWidth: 1, fractionHeight: 1,
                        pixelFormat: .r32Float
                    ),
                    TextureSet.Description(
                        fractionWidth: 2, fractionHeight: 2,
                        pixelFormat: .r32Float
                    ),
                    TextureSet.Description(
                        fractionWidth: 2, fractionHeight: 2,
                        pixelFormat: .r32Float
                    ),
                    TextureSet.Description(
                        fractionWidth: 1, fractionHeight: 1,
                        pixelFormat: .r32Float
                    )
                ],
                usage: .shaderRead,
                isShared: true
            ) else {
                return
            }
            self.compressedTextures = textures
            compressedTextures = textures
        }
        
        for i in 0 ..< 4 {
            let planeWidth = Int(readBuffer.readInt32())
            let planeHeight = Int(readBuffer.readInt32())
            let bytesPerRow = Int(readBuffer.readInt32())
            
            let planeSize = Int(readBuffer.readInt32())
            let planeData = readBuffer.readDataNoCopy(length: planeSize)
            
            compressedTextures.textures[i].readDirect(width: planeWidth, height: planeHeight, bytesPerRow: bytesPerRow, read: { destination, maxLength in
                readDCTBlocks(Int32(planeWidth), Int32(planeHeight), planeData, destination.assumingMemoryBound(to: Float32.self), Int32(bytesPerRow / 4))
            })
        }
    }
    
    public func renderIdct(metalLayer: CALayer, compressedImage: AnimationCompressor.CompressedImageData, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            self.updateIdctTextures(compressedImage: compressedImage)
            
            DispatchQueue.main.async {
                guard let compressedTextures = self.compressedTextures else {
                    return
                }
                
                guard let commandBuffer = self.shared.commandQueue.makeCommandBuffer() else {
                    return
                }
                commandBuffer.label = "MyCommand"
                
                guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    return
                }
                
                computeEncoder.setComputePipelineState(self.shared.computeIdctPipelineState)
                
                let outputTextures: TextureSet
                if let current = self.outputTextures, current.width == compressedTextures.textures[0].width, current.height == compressedTextures.textures[0].height {
                    outputTextures = current
                } else {
                    guard let textures = TextureSet(
                        device: self.sharedContext.device,
                        width: compressedTextures.textures[0].width,
                        height: compressedTextures.textures[0].height,
                        descriptions: [
                            TextureSet.Description(
                                fractionWidth: 1, fractionHeight: 1,
                                pixelFormat: .r8Unorm
                            ),
                            TextureSet.Description(
                                fractionWidth: 2, fractionHeight: 2,
                                pixelFormat: .r8Unorm
                            ),
                            TextureSet.Description(
                                fractionWidth: 2, fractionHeight: 2,
                                pixelFormat: .r8Unorm
                            ),
                            TextureSet.Description(
                                fractionWidth: 1, fractionHeight: 1,
                                pixelFormat: .r8Unorm
                            )
                        ],
                        usage: [.shaderRead, .shaderWrite],
                        isShared: false
                    ) else {
                        return
                    }
                    self.outputTextures = textures
                    outputTextures = textures
                }
                
                for i in 0 ..< 4 {
                    computeEncoder.setTexture(compressedTextures.textures[i].texture, index: 0)
                    computeEncoder.setTexture(outputTextures.textures[i].texture, index: 1)
                    
                    var colorPlaneInt32 = Int32(i)
                    computeEncoder.setBytes(&colorPlaneInt32, length: 4, index: 2)
                    
                    let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
                    let threadgroupCount = MTLSize(width: (compressedTextures.textures[i].width + threadgroupSize.width - 1) / threadgroupSize.width, height: (compressedTextures.textures[i].height + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
                    
                    computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
                }
                
                computeEncoder.endEncoding()
                
                let drawableSize = CGSize(width: CGFloat(outputTextures.textures[0].width), height: CGFloat(outputTextures.textures[0].height))
                
                var maybeDrawable: CAMetalDrawable?
        #if targetEnvironment(simulator)
                if #available(iOS 13.0, *) {
                    if let metalLayer = metalLayer as? CAMetalLayer {
                        if metalLayer.drawableSize != drawableSize {
                            metalLayer.drawableSize = drawableSize
                        }
                        maybeDrawable = metalLayer.nextDrawable()
                    }
                } else {
                    preconditionFailure()
                }
        #else
                if let metalLayer = metalLayer as? CAMetalLayer {
                    if metalLayer.drawableSize != drawableSize {
                        metalLayer.drawableSize = drawableSize
                    }
                    maybeDrawable = metalLayer.nextDrawable()
                }
        #endif
                
                guard let drawable = maybeDrawable else {
                    commandBuffer.commit()
                    completion()
                    return
                }

                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = drawable.texture
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
                
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                    return
                }
                renderEncoder.label = "MyRenderEncoder"
                
                renderEncoder.setRenderPipelineState(self.shared.renderIdctPipelineState)
                
                for i in 0 ..< 4 {
                    renderEncoder.setFragmentTexture(outputTextures.textures[i].texture, index: i)
                }
                
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                
                renderEncoder.endEncoding()
                
                commandBuffer.present(drawable)
                
                commandBuffer.addCompletedHandler { _ in
                    DispatchQueue.main.async {
                        completion()
                    }
                }
                
                commandBuffer.commit()
            }
        }
    }
    
    private func updateRgbTexture(width: Int, height: Int, bytesPerRow: Int, data: Data) {
        self.compressedTextures = nil
        self.outputTextures = nil
        self.yuvaTextures = nil
        
        let rgbTexture: Texture
        if let current = self.rgbTexture, current.width == width, current.height == height {
            rgbTexture = current
        } else {
            guard let texture = Texture(device: self.sharedContext.device, width: width, height: height, pixelFormat: .bgra8Unorm, usage: .shaderRead, isShared: true) else {
                return
            }
            self.rgbTexture = texture
            rgbTexture = texture
        }
        
        rgbTexture.readDirect(width: width, height: height, bytesPerRow: bytesPerRow, read: { destination, maxLength in
            data.copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), from: 0 ..< min(maxLength, data.count))
        })
    }
    
    public func renderRgb(metalLayer: CALayer, width: Int, height: Int, bytesPerRow: Int, data: Data, completion: @escaping () -> Void) {
        self.updateRgbTexture(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
        
        guard let rgbTexture = self.rgbTexture else {
            return
        }
        
        guard let commandBuffer = self.shared.commandQueue.makeCommandBuffer() else {
            return
        }
        commandBuffer.label = "MyCommand"
        
        let drawableSize = CGSize(width: CGFloat(rgbTexture.width), height: CGFloat(rgbTexture.height))
        
        var maybeDrawable: CAMetalDrawable?
#if targetEnvironment(simulator)
        if #available(iOS 13.0, *) {
            if let metalLayer = metalLayer as? CAMetalLayer {
                if metalLayer.drawableSize != drawableSize {
                    metalLayer.drawableSize = drawableSize
                }
                maybeDrawable = metalLayer.nextDrawable()
            }
        } else {
            preconditionFailure()
        }
#else
        if let metalLayer = metalLayer as? CAMetalLayer {
            if metalLayer.drawableSize != drawableSize {
                metalLayer.drawableSize = drawableSize
            }
            maybeDrawable = metalLayer.nextDrawable()
        }
#endif
        
        guard let drawable = maybeDrawable else {
            commandBuffer.commit()
            completion()
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.label = "MyRenderEncoder"
        
        renderEncoder.setRenderPipelineState(self.shared.renderRgbPipelineState)
        renderEncoder.setFragmentTexture(rgbTexture.texture, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
        
        commandBuffer.commit()
    }
    
    private func updateYuvaTextures(width: Int, height: Int, data: Data) {
        self.compressedTextures = nil
        self.outputTextures = nil
        self.rgbTexture = nil
        
        let yuvaTextures: TextureSet
        if let current = self.yuvaTextures, current.width == width, current.height == height {
            yuvaTextures = current
        } else {
            guard let textures = TextureSet(
                device: self.sharedContext.device,
                width: width,
                height: height,
                descriptions: [
                    TextureSet.Description(
                        fractionWidth: 1, fractionHeight: 1,
                        pixelFormat: .r8Unorm
                    ),
                    TextureSet.Description(
                        fractionWidth: 2, fractionHeight: 2,
                        pixelFormat: .rg8Unorm
                    ),
                    TextureSet.Description(
                        fractionWidth: 1, fractionHeight: 1,
                        pixelFormat: .r8Uint
                    )
                ],
                usage: .shaderRead,
                isShared: true
            ) else {
                return
            }
            self.yuvaTextures = textures
            yuvaTextures = textures
        }
        
        data.withUnsafeBytes { yuvaBuffer in
            guard let yuva = yuvaBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            
            yuvaTextures.textures[0].readDirect(width: width, height: height, bytesPerRow: width, read: { destination, maxLength in
                memcpy(destination, yuva.advanced(by: 0), min(width * height, maxLength))
            })
            
            yuvaTextures.textures[1].readDirect(width: width / 2, height: height / 2, bytesPerRow: width, read: { destination, maxLength in
                memcpy(destination, yuva.advanced(by: width * height), min(width * height, maxLength))
            })
            
            var unpackedAlpha = Data(count: width * height)
            unpackedAlpha.withUnsafeMutableBytes { alphaBuffer in
                let alphaBytes = alphaBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let alpha = yuva.advanced(by: width * height * 2)
                
                var i = 0
                for y in 0 ..< height {
                    let alphaRow = alphaBytes.advanced(by: y * width)
                    
                    var x = 0
                    while x < width {
                        let a = alpha[i / 2]
                        let a1 = (a & (0xf0))
                        let a2 = ((a & (0x0f)) << 4)
                        alphaRow[x + 0] = a1 | (a1 >> 4);
                        alphaRow[x + 1] = a2 | (a2 >> 4);
                        
                        x += 2
                        i += 2
                    }
                }
                
                yuvaTextures.textures[2].readDirect(width: width, height: height, bytesPerRow: width, read: { destination, maxLength in
                    memcpy(destination, alphaBytes, min(maxLength, width * height))
                })
            }
        }
    }
    
    public func renderYuva(metalLayer: CALayer, width: Int, height: Int, data: Data, completion: @escaping () -> Void) {
        self.updateYuvaTextures(width: width, height: height, data: data)
        
        guard let yuvaTextures = self.yuvaTextures else {
            return
        }
        
        guard let commandBuffer = self.shared.commandQueue.makeCommandBuffer() else {
            return
        }
        commandBuffer.label = "MyCommand"
        
        let drawableSize = CGSize(width: CGFloat(yuvaTextures.width), height: CGFloat(yuvaTextures.height))
        
        var maybeDrawable: CAMetalDrawable?
#if targetEnvironment(simulator)
        if #available(iOS 13.0, *) {
            if let metalLayer = metalLayer as? CAMetalLayer {
                if metalLayer.drawableSize != drawableSize {
                    metalLayer.drawableSize = drawableSize
                }
                maybeDrawable = metalLayer.nextDrawable()
            }
        } else {
            preconditionFailure()
        }
#else
        if let metalLayer = metalLayer as? CAMetalLayer {
            if metalLayer.drawableSize != drawableSize {
                metalLayer.drawableSize = drawableSize
            }
            maybeDrawable = metalLayer.nextDrawable()
        }
#endif
        
        guard let drawable = maybeDrawable else {
            commandBuffer.commit()
            completion()
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.label = "MyRenderEncoder"
        
        renderEncoder.setRenderPipelineState(self.shared.renderYuvaPipelineState)
        renderEncoder.setFragmentTexture(yuvaTextures.textures[0].texture, index: 0)
        renderEncoder.setFragmentTexture(yuvaTextures.textures[1].texture, index: 1)
        renderEncoder.setFragmentTexture(yuvaTextures.textures[2].texture, index: 2)
        
        var alphaWidth: Int32 = Int32(yuvaTextures.textures[2].texture.width)
        renderEncoder.setFragmentBytes(&alphaWidth, length: 4, index: 3)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
        
        commandBuffer.commit()
    }
}
