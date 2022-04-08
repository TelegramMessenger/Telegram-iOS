import Foundation
import UIKit
import Metal
import MetalKit
import simd
import DctHuffman
import MetalImageView

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
        }
    }
    
    private let sharedContext: AnimationCompressor.SharedContext
    private let shared: Shared
    
    private var compressedTextures: TextureSet?
    private var outputTextures: TextureSet?
    
    private var rgbTexture: Texture?
    
    private var yuvaTextures: TextureSet?
    
    private let commandQueue: MTLCommandQueue
    
    private var isRendering: Bool = false

    public init?(sharedContext: AnimationCompressor.SharedContext) {
        self.sharedContext = sharedContext
        self.shared = Shared.shared
        
        guard let commandQueue = self.sharedContext.device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue
    }
    
    private var drawableRequestTimestamp: Double?
    
    private func getNextDrawable(layer: MetalImageLayer, drawableSize: CGSize) -> MetalImageLayer.Drawable? {
        layer.renderer.drawableSize = drawableSize
        return layer.renderer.nextDrawable()
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
            
            var tempData: Data?
            compressedTextures.textures[i].readDirect(width: planeWidth, height: planeHeight, bytesPerRow: bytesPerRow, read: { destinationBytes in
                if let destinationBytes = destinationBytes {
                    readDCTBlocks(Int32(planeWidth), Int32(planeHeight), planeData, destinationBytes.assumingMemoryBound(to: Float32.self), Int32(bytesPerRow / 4))
                    return UnsafeRawPointer(destinationBytes)
                } else {
                    tempData = Data(count: bytesPerRow * planeHeight)
                    return tempData!.withUnsafeMutableBytes { bytes -> UnsafeRawPointer in
                        readDCTBlocks(Int32(planeWidth), Int32(planeHeight), planeData, bytes.baseAddress!.assumingMemoryBound(to: Float32.self), Int32(bytesPerRow / 4))
                        return UnsafeRawPointer(bytes.baseAddress!)
                    }
                }
            })
        }
    }
    
    public func renderIdct(layer: MetalImageLayer, compressedImage: AnimationCompressor.CompressedImageData, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            self.updateIdctTextures(compressedImage: compressedImage)
            
            DispatchQueue.main.async {
                guard let compressedTextures = self.compressedTextures else {
                    return
                }
                
                guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
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
                
                guard let drawable = self.getNextDrawable(layer: layer, drawableSize: drawableSize) else {
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
                
                var storedDrawable: MetalImageLayer.Drawable? = drawable
                commandBuffer.addCompletedHandler { _ in
                    DispatchQueue.main.async {
                        autoreleasepool {
                            storedDrawable?.present(completion: completion)
                            storedDrawable = nil
                        }
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
        
        rgbTexture.readDirect(width: width, height: height, bytesPerRow: bytesPerRow, read: { destinationBytes in
            return data.withUnsafeBytes { bytes -> UnsafeRawPointer in
                if let destinationBytes = destinationBytes {
                    memcpy(destinationBytes, bytes.baseAddress!, bytes.count)
                    return UnsafeRawPointer(destinationBytes)
                } else {
                    return bytes.baseAddress!
                }
            }
        })
    }
    
    public func renderRgb(layer: MetalImageLayer, width: Int, height: Int, bytesPerRow: Int, data: Data, completion: @escaping () -> Void) {
        self.updateRgbTexture(width: width, height: height, bytesPerRow: bytesPerRow, data: data)
        
        guard let rgbTexture = self.rgbTexture else {
            return
        }
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return
        }
        commandBuffer.label = "MyCommand"
        
        let drawableSize = CGSize(width: CGFloat(rgbTexture.width), height: CGFloat(rgbTexture.height))
        
        guard let drawable = self.getNextDrawable(layer: layer, drawableSize: drawableSize) else {
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
        
        var storedDrawable: MetalImageLayer.Drawable? = drawable
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                autoreleasepool {
                    storedDrawable?.present(completion: completion)
                    storedDrawable = nil
                }
            }
        }
        
        commandBuffer.commit()
    }
    
    private func updateYuvaTextures(width: Int, height: Int, data: Data) {
        if width % 2 != 0 || height % 2 != 0 {
            return
        }
        
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
                        fractionWidth: 2, fractionHeight: 1,
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
            
            yuvaTextures.textures[0].readDirect(width: width, height: height, bytesPerRow: width, read: { destinationBytes in
                if let destinationBytes = destinationBytes {
                    memcpy(destinationBytes, yuva.advanced(by: 0), width * height)
                    return UnsafeRawPointer(destinationBytes)
                } else {
                    return UnsafeRawPointer(yuva.advanced(by: 0))
                }
            })
            
            yuvaTextures.textures[1].readDirect(width: width / 2, height: height / 2, bytesPerRow: width, read: { destinationBytes in
                if let destinationBytes = destinationBytes {
                    memcpy(destinationBytes, yuva.advanced(by: width * height), width * height / 2)
                    return UnsafeRawPointer(destinationBytes)
                } else {
                    return UnsafeRawPointer(yuva.advanced(by: width * height))
                }
            })
            
            yuvaTextures.textures[2].readDirect(width: width / 2, height: height, bytesPerRow: width / 2, read: { destinationBytes in
                if let destinationBytes = destinationBytes {
                    memcpy(destinationBytes, yuva.advanced(by: width * height * 2), width / 2 * height)
                    return UnsafeRawPointer(destinationBytes)
                } else {
                    return UnsafeRawPointer(yuva.advanced(by: width * height * 2))
                }
            })
        }
    }
    
    public func renderYuva(layer: MetalImageLayer, width: Int, height: Int, data: Data, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            autoreleasepool {
                //let renderStartTime = CFAbsoluteTimeGetCurrent()
                
                var beginTime: Double = 0.0
                var duration: Double = 0.0
                beginTime = CFAbsoluteTimeGetCurrent()
                
                self.updateYuvaTextures(width: width, height: height, data: data)
                
                duration = CFAbsoluteTimeGetCurrent() - beginTime
                if duration > 1.0 / 60.0 {
                    print("update textures lag \(duration * 1000.0)")
                }
                
                guard let yuvaTextures = self.yuvaTextures else {
                    DispatchQueue.main.async {
                        completion()
                    }
                    return
                }
                
                beginTime = CFAbsoluteTimeGetCurrent()
                
                guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                    DispatchQueue.main.async {
                        completion()
                    }
                    return
                }
                
                commandBuffer.label = "MyCommand"
                
                let drawableSize = CGSize(width: CGFloat(yuvaTextures.width), height: CGFloat(yuvaTextures.height))
                
                guard let drawable = self.getNextDrawable(layer: layer, drawableSize: drawableSize) else {
                    commandBuffer.commit()
                    DispatchQueue.main.async {
                        completion()
                    }
                    return
                }
                
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = drawable.texture
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
                
                guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                    DispatchQueue.main.async {
                        completion()
                    }
                    return
                }
                renderEncoder.label = "MyRenderEncoder"
                
                renderEncoder.setRenderPipelineState(self.shared.renderYuvaPipelineState)
                renderEncoder.setFragmentTexture(yuvaTextures.textures[0].texture, index: 0)
                renderEncoder.setFragmentTexture(yuvaTextures.textures[1].texture, index: 1)
                renderEncoder.setFragmentTexture(yuvaTextures.textures[2].texture, index: 2)
                
                var alphaSize = simd_uint2(UInt32(yuvaTextures.textures[0].texture.width), UInt32(yuvaTextures.textures[0].texture.height))
                renderEncoder.setFragmentBytes(&alphaSize, length: 8, index: 3)
                
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                
                renderEncoder.endEncoding()
                
                var storedDrawable: MetalImageLayer.Drawable? = drawable
                commandBuffer.addCompletedHandler { _ in
                    DispatchQueue.main.async {
                        autoreleasepool {
                            storedDrawable?.present(completion: completion)
                            storedDrawable = nil
                        }
                    }
                }
                
                commandBuffer.commit()
                
                duration = CFAbsoluteTimeGetCurrent() - beginTime
                if duration > 1.0 / 60.0 {
                    print("commit lag \(duration * 1000.0)")
                }
            }
        }
    }
}
