import Foundation
import Metal
import DctHuffman

private final class BundleHelper: NSObject {
}

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

final class Texture {
    final class DirectBuffer {
        let buffer: MTLBuffer
        let bytesPerRow: Int
        
        init?(device: MTLDevice, width: Int, height: Int, bytesPerRow: Int) {
            #if targetEnvironment(simulator)
            return nil
            #else
            if #available(iOS 12.0, *) {
                let pagesize = Int(getpagesize())
                let allocationSize = alignUp(size: bytesPerRow * height, align: pagesize)
                var data: UnsafeMutableRawPointer? = nil
                let result = posix_memalign(&data, pagesize, allocationSize)
                if result == noErr, let data = data {
                    self.bytesPerRow = bytesPerRow
                    
                    guard let buffer = device.makeBuffer(
                        bytesNoCopy: data,
                        length: allocationSize,
                        options: .storageModeShared,
                        deallocator: { _, _ in
                            free(data)
                        }
                    ) else {
                        return nil
                    }
                    
                    self.buffer = buffer
                } else {
                    return nil
                }
            } else {
                return nil
            }
            #endif
        }
    }
    
    let width: Int
    let height: Int
    let texture: MTLTexture
    
    let directBuffer: DirectBuffer?
    
    init?(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        isShared: Bool
    ) {
        self.width = width
        self.height = height
        
        if #available(iOS 12.0, *), isShared, usage.contains(.shaderRead) {
            switch pixelFormat {
            case .r32Float, .bgra8Unorm:
                let bytesPerPixel = 4
                let pixelRowAlignment = device.minimumTextureBufferAlignment(for: pixelFormat)
                let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
                self.directBuffer = DirectBuffer(device: device, width: width, height: height, bytesPerRow: bytesPerRow)
            case .r8Unorm, .r8Uint:
                let bytesPerPixel = 1
                let pixelRowAlignment = device.minimumTextureBufferAlignment(for: pixelFormat)
                let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
                self.directBuffer = DirectBuffer(device: device, width: width, height: height, bytesPerRow: bytesPerRow)
            case .rg8Unorm:
                let bytesPerPixel = 2
                let pixelRowAlignment = device.minimumTextureBufferAlignment(for: pixelFormat)
                let bytesPerRow = alignUp(size: width * bytesPerPixel, align: pixelRowAlignment)
                self.directBuffer = DirectBuffer(device: device, width: width, height: height, bytesPerRow: bytesPerRow)
            default:
                self.directBuffer = nil
            }
        } else {
            self.directBuffer = nil
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = pixelFormat
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.usage = usage
        
        if let directBuffer = self.directBuffer {
            textureDescriptor.storageMode = directBuffer.buffer.storageMode
            guard let texture = directBuffer.buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: directBuffer.bytesPerRow) else {
                return nil
            }
            self.texture = texture
        } else {
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return nil
            }
            self.texture = texture
        }
    }
    
    func replace(with image: AnimationCompressor.ImageData) {
        if image.width != self.width || image.height != self.height {
            assert(false, "Image size does not match")
            return
        }
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: image.width, height: image.height, depth: 1))
        
        if let directBuffer = self.directBuffer, directBuffer.bytesPerRow == image.bytesPerRow {
            image.data.withUnsafeBytes { bytes in
                let _ = memcpy(directBuffer.buffer.contents(), bytes.baseAddress!, image.bytesPerRow * self.height)
            }
        } else {
            image.data.withUnsafeBytes { bytes in
                self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: image.bytesPerRow)
            }
        }
    }
    
    func readDirect(width: Int, height: Int, bytesPerRow: Int, read: (UnsafeMutableRawPointer?) -> UnsafeRawPointer) {
        if let directBuffer = self.directBuffer, width == self.width, height == self.height, bytesPerRow == directBuffer.bytesPerRow {
            let _ = read(directBuffer.buffer.contents())
        } else {
            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1))
            self.texture.replace(region: region, mipmapLevel: 0, withBytes: read(nil), bytesPerRow: bytesPerRow)
        }
    }
}

final class TextureSet {
    struct Description {
        let fractionWidth: Int
        let fractionHeight: Int
        let pixelFormat: MTLPixelFormat
    }
    
    let width: Int
    let height: Int
    
    let textures: [Texture]
    
    init?(
        device: MTLDevice,
        width: Int,
        height: Int,
        descriptions: [Description],
        usage: MTLTextureUsage,
        isShared: Bool
    ) {
        self.width = width
        self.height = height
        
        var textures: [Texture] = []
        for i in 0 ..< descriptions.count {
            let planeWidth = width / descriptions[i].fractionWidth
            let planeHeight = height / descriptions[i].fractionHeight
            
            guard let texture = Texture(
                device: device,
                width: planeWidth,
                height: planeHeight,
                pixelFormat: descriptions[i].pixelFormat,
                usage: usage,
                isShared: isShared
            ) else {
                return nil
            }
            
            textures.append(texture)
        }
        
        self.textures = textures
    }
}

public final class AnimationCompressor {
    public final class ImageData {
        public let width: Int
        public let height: Int
        public let bytesPerRow: Int
        public let data: Data
        
        public init(width: Int, height: Int, bytesPerRow: Int, data: Data) {
            self.width = width
            self.height = height
            self.bytesPerRow = bytesPerRow
            self.data = data
        }
    }
    
    public final class CompressedImageData {
        public let data: Data
        
        public init(data: Data) {
            self.data = data
        }
    }
    
    public final class SharedContext {
        public static let shared: SharedContext = SharedContext()!
        
        public let device: MTLDevice
        let defaultLibrary: MTLLibrary
        private let computeDctPipelineState: MTLComputePipelineState
        private let commandQueue: MTLCommandQueue
        
        public init?() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                return nil
            }
            self.device = device
            
            let mainBundle = Bundle(for: BundleHelper.self)

            guard let path = mainBundle.path(forResource: "AnimationCompressionBundle", ofType: "bundle") else {
                return nil
            }
            guard let bundle = Bundle(path: path) else {
                return nil
            }
            
            if #available(iOS 10.0, *) {
                guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
                    return nil
                }
                self.defaultLibrary = defaultLibrary
            } else {
                preconditionFailure()
            }
            
            guard let dctFunction = self.defaultLibrary.makeFunction(name: "dctKernel") else {
                return nil
            }
            
            guard let computeDctPipelineState = try? self.device.makeComputePipelineState(function: dctFunction) else {
                return nil
            }
            self.computeDctPipelineState = computeDctPipelineState
            
            guard let commandQueue = self.device.makeCommandQueue() else {
                return nil
            }
            self.commandQueue = commandQueue
        }
        
        func compress(compressor: AnimationCompressor, image: ImageData, completion: @escaping (CompressedImageData) -> Void) {
            let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
            
            assert(image.width % 8 == 0)
            assert(image.height % 8 == 0)
            
            let inputTexture: Texture
            if let current = compressor.inputTexture, current.width == image.width, current.height == image.height {
                inputTexture = current
            } else {
                guard let texture = Texture(
                    device: self.device,
                    width: image.width,
                    height: image.height,
                    pixelFormat: .bgra8Unorm,
                    usage: .shaderRead,
                    isShared: true
                ) else {
                    return
                }
                inputTexture = texture
                compressor.inputTexture = texture
            }
            
            inputTexture.replace(with: image)
            
            let compressedTextures: TextureSet
            if let current = compressor.compressedTextures, current.width == image.width, current.height == image.height {
                compressedTextures = current
            } else {
                guard let textures = TextureSet(
                    device: self.device,
                    width: image.width,
                    height: image.height,
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
                    usage: [.shaderWrite],
                    isShared: false
                ) else {
                    return
                }
                compressedTextures = textures
                compressor.compressedTextures = textures
            }
            
            guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                return
            }
            commandBuffer.label = "ImageCompressor"
            
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            computeEncoder.setComputePipelineState(self.computeDctPipelineState)
            
            computeEncoder.setTexture(inputTexture.texture, index: 0)
            
            for colorPlane in 0 ..< 4 {
                computeEncoder.setTexture(compressedTextures.textures[colorPlane].texture, index: 1)
                
                var colorPlaneInt32 = Int32(colorPlane)
                computeEncoder.setBytes(&colorPlaneInt32, length: 4, index: 2)
                
                let threadgroupCount = MTLSize(width: (compressedTextures.textures[colorPlane].width + threadgroupSize.width - 1) / threadgroupSize.width, height: (compressedTextures.textures[colorPlane].height + threadgroupSize.height - 1) / threadgroupSize.height, depth: 1)
                
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            }
            
            computeEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { _ in
                let buffer = WriteBuffer()
                
                buffer.writeInt32(0x543ee445)
                buffer.writeInt32(4)
                buffer.writeInt32(Int32(compressedTextures.textures[0].width))
                buffer.writeInt32(Int32(compressedTextures.textures[0].height))
                
                for i in 0 ..< 4 {
                    let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: compressedTextures.textures[i].width, height: compressedTextures.textures[i].height, depth: 1))
                    let bytesPerRow = 4 * compressedTextures.textures[i].width
                    
                    buffer.writeInt32(Int32(compressedTextures.textures[i].width))
                    buffer.writeInt32(Int32(compressedTextures.textures[i].height))
                    buffer.writeInt32(Int32(bytesPerRow))
                    
                    var textureBytes = Data(count: bytesPerRow * compressedTextures.textures[i].height)
                    textureBytes.withUnsafeMutableBytes { bytes in
                        compressedTextures.textures[i].texture.getBytes(bytes.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerRow * compressedTextures.textures[i].height, from: region, mipmapLevel: 0, slice: 0)
                        
                        let huffmanData = writeDCTBlocks(Int32(compressedTextures.textures[i].width), Int32(compressedTextures.textures[i].height), bytes.baseAddress!.assumingMemoryBound(to: Float32.self))!
                        buffer.writeInt32(Int32(huffmanData.count))
                        buffer.write(huffmanData)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(CompressedImageData(data: buffer.makeData()))
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    private let sharedContext: SharedContext
    
    private var inputTexture: Texture?
    private var compressedTextures: TextureSet?
    
    public init(sharedContext: SharedContext) {
        self.sharedContext = sharedContext
    }
    
    public func compress(image: ImageData, completion: @escaping (CompressedImageData) -> Void) {
        self.sharedContext.compress(compressor: self, image: image, completion: completion)
    }
}
