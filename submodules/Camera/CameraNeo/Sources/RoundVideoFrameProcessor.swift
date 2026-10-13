import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import Metal
import MetalPerformanceShaders
import Camera

private final class CameraBundleMarker: NSObject {
}

private struct FrameUniforms {
    var primaryRow0: SIMD4<Float>
    var primaryRow1: SIMD4<Float>
    var primaryRow2: SIMD4<Float>
    var primaryOffset: SIMD4<Float>
    var primarySource: SIMD4<Float>

    var secondaryRow0: SIMD4<Float>
    var secondaryRow1: SIMD4<Float>
    var secondaryRow2: SIMD4<Float>
    var secondaryOffset: SIMD4<Float>
    var secondarySource: SIMD4<Float>

    var blend: SIMD4<Float>
    var decoration: SIMD4<Float>
}

private struct ColorConversion {
    let row0: SIMD4<Float>
    let row1: SIMD4<Float>
    let row2: SIMD4<Float>
    let offset: SIMD4<Float>
}

struct VideoFrameSource {
    let pixelBuffer: CVPixelBuffer
    let formatDescription: CMFormatDescription
    let colorAttachments: [String: Any]
    let position: Camera.Position
    let orientation: AVCaptureVideoOrientation

    init(
        pixelBuffer: CVPixelBuffer,
        formatDescription: CMFormatDescription,
        position: Camera.Position,
        orientation: AVCaptureVideoOrientation
    ) {
        self.pixelBuffer = pixelBuffer
        self.formatDescription = formatDescription
        self.position = position
        self.orientation = orientation

        if let attachments = CMCopyDictionaryOfAttachments(
            allocator: kCFAllocatorDefault,
            target: pixelBuffer,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        ) as? [String: Any] {
            self.colorAttachments = attachments
        } else {
            self.colorAttachments = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] ?? [:]
        }
    }
}

struct ProcessedVideoFrame {
    let pixelBuffer: CVPixelBuffer
}

private final class RoundVideoMetalDecoration {
    static let blurWidth = 100
    static let blurHeight = 100

    let downsamplePipelineState: MTLComputePipelineState
    let compositePipelineState: MTLComputePipelineState
    let downsampleTexture: MTLTexture
    let blurredTexture: MTLTexture
    let watermarkTexture: MTLTexture
    let atlasTexture: MTLTexture
    let blur: MPSImageGaussianBlur

    init?(
        device: MTLDevice,
        library: MTLLibrary,
        resources: RoundVideoDecorationResources
    ) {
        guard let downsampleFunction = library.makeFunction(name: "downsampleNV12"),
              let compositeFunction = library.makeFunction(name: "compositeRoundVideo"),
              let downsamplePipelineState = try? device.makeComputePipelineState(function: downsampleFunction),
              let compositePipelineState = try? device.makeComputePipelineState(function: compositeFunction),
              let downsampleTexture = Self.makeWorkingTexture(device: device),
              let blurredTexture = Self.makeWorkingTexture(device: device),
              let watermarkTexture = Self.makeTexture(
                device: device,
                width: resources.watermark.width,
                height: resources.watermark.height,
                bytesPerRow: resources.watermark.bytesPerRow,
                data: resources.watermark.data
              ),
              let atlasTexture = Self.makeTexture(
                device: device,
                width: RoundVideoDecorationAnimation.width,
                height: RoundVideoDecorationAnimation.height,
                bytesPerRow: RoundVideoDecorationAnimation.bytesPerRow,
                data: resources.atlas.data
              ) else {
            return nil
        }

        let blur = MPSImageGaussianBlur(device: device, sigma: 7.5)
        blur.edgeMode = .clamp

        self.downsamplePipelineState = downsamplePipelineState
        self.compositePipelineState = compositePipelineState
        self.downsampleTexture = downsampleTexture
        self.blurredTexture = blurredTexture
        self.watermarkTexture = watermarkTexture
        self.atlasTexture = atlasTexture
        self.blur = blur
    }

    private static func makeWorkingTexture(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Self.blurWidth,
            height: Self.blurHeight,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private static func makeTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        data: Data
    ) -> MTLTexture? {
        guard width > 0, height > 0, bytesPerRow >= width * 4, data.count >= bytesPerRow * height else {
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        let uploaded = data.withUnsafeBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow
            )
            return true
        }
        return uploaded ? texture : nil
    }
}

final class RoundVideoFrameProcessor {
    static let outputWidth = 480
    static let outputHeight = 480

    private let device: MTLDevice
    private let mediaQueue: DispatchQueue
    private let commandQueue: MTLCommandQueue
    private let plainPipelineState: MTLComputePipelineState
    private let decoration: RoundVideoMetalDecoration?
    private var textureCache: CVMetalTextureCache
    private let outputPool: CVPixelBufferPool
    private let outputPoolAuxiliaryAttributes: CFDictionary
    private var isRendering = false

    init?(mediaQueue: DispatchQueue, decorationResources: RoundVideoDecorationResources?) {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        let containingBundle = Bundle(for: CameraBundleMarker.self)
        guard let bundleUrl = containingBundle.url(forResource: "CameraNeoBundle", withExtension: "bundle"),
              let resourceBundle = Bundle(url: bundleUrl),
              let library = try? device.makeDefaultLibrary(bundle: resourceBundle),
              let function = library.makeFunction(name: "convertNV12"),
              let plainPipelineState = try? device.makeComputePipelineState(function: function) else {
            return nil
        }

        let decoration: RoundVideoMetalDecoration?
        if let decorationResources {
            guard let current = RoundVideoMetalDecoration(
                device: device,
                library: library,
                resources: decorationResources
            ) else {
                return nil
            }
            decoration = current
        } else {
            decoration = nil
        }

        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess, let textureCache else {
            return nil
        }

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 4
        ]
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Self.outputWidth,
            kCVPixelBufferHeightKey as String: Self.outputHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]
        var outputPool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &outputPool
        ) == kCVReturnSuccess, let outputPool else {
            return nil
        }

        self.device = device
        self.mediaQueue = mediaQueue
        self.commandQueue = commandQueue
        self.plainPipelineState = plainPipelineState
        self.decoration = decoration
        self.textureCache = textureCache
        self.outputPool = outputPool
        self.outputPoolAuxiliaryAttributes = [
            kCVPixelBufferPoolAllocationThresholdKey as String: 6
        ] as CFDictionary

        var preallocatedBuffers: [CVPixelBuffer] = []
        for _ in 0 ..< 4 {
            var pixelBuffer: CVPixelBuffer?
            if CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
                kCFAllocatorDefault,
                outputPool,
                self.outputPoolAuxiliaryAttributes,
                &pixelBuffer
            ) == kCVReturnSuccess, let pixelBuffer {
                preallocatedBuffers.append(pixelBuffer)
            }
        }
        preallocatedBuffers.removeAll()
    }

    func render(
        primary: VideoFrameSource,
        secondary: VideoFrameSource?,
        mixFactor: Float,
        animationTime: Double,
        completion: @escaping (ProcessedVideoFrame?) -> Void
    ) {
        guard !self.isRendering else {
            return
        }
        guard self.isSupportedInput(primary.pixelBuffer), secondary.map({ self.isSupportedInput($0.pixelBuffer) }) ?? true else {
            return
        }

        var outputPixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            self.outputPool,
            self.outputPoolAuxiliaryAttributes,
            &outputPixelBuffer
        ) == kCVReturnSuccess, let outputPixelBuffer else {
            return
        }

        guard let primaryTextures = self.makeInputTextures(pixelBuffer: primary.pixelBuffer),
              let outputTexture = self.makeOutputTexture(pixelBuffer: outputPixelBuffer) else {
            CVMetalTextureCacheFlush(self.textureCache, 0)
            return
        }

        let effectiveSecondary = secondary ?? primary
        let secondaryTextures: (y: CVMetalTexture, cbcr: CVMetalTexture)
        if secondary == nil {
            secondaryTextures = primaryTextures
        } else if let textures = self.makeInputTextures(pixelBuffer: effectiveSecondary.pixelBuffer) {
            secondaryTextures = textures
        } else {
            CVMetalTextureCacheFlush(self.textureCache, 0)
            return
        }

        guard let primaryY = CVMetalTextureGetTexture(primaryTextures.y),
              let primaryCbCr = CVMetalTextureGetTexture(primaryTextures.cbcr),
              let secondaryY = CVMetalTextureGetTexture(secondaryTextures.y),
              let secondaryCbCr = CVMetalTextureGetTexture(secondaryTextures.cbcr),
              let output = CVMetalTextureGetTexture(outputTexture),
              let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            CVMetalTextureCacheFlush(self.textureCache, 0)
            return
        }

        let primaryConversion = Self.colorConversion(for: primary)
        let secondaryConversion = Self.colorConversion(for: effectiveSecondary)
        var uniforms = FrameUniforms(
            primaryRow0: primaryConversion.row0,
            primaryRow1: primaryConversion.row1,
            primaryRow2: primaryConversion.row2,
            primaryOffset: primaryConversion.offset,
            primarySource: Self.sourceDescription(for: primary),
            secondaryRow0: secondaryConversion.row0,
            secondaryRow1: secondaryConversion.row1,
            secondaryRow2: secondaryConversion.row2,
            secondaryOffset: secondaryConversion.offset,
            secondarySource: Self.sourceDescription(for: effectiveSecondary),
            blend: SIMD4<Float>(max(0.0, min(1.0, mixFactor)), secondary == nil ? 0.0 : 1.0, 0.0, 0.0),
            decoration: SIMD4<Float>(0.0, 0.0, 0.0, 0.0)
        )

        if let decoration = self.decoration {
            let effectiveAnimationTime = animationTime.isFinite ? max(0.0, animationTime) : 0.0
            let frameIndex = Int(floor(effectiveAnimationTime * 30.0)) % RoundVideoDecorationAnimation.frameCount
            uniforms.decoration = SIMD4<Float>(
                Float(frameIndex),
                Float(RoundVideoDecorationAnimation.columns),
                Float(RoundVideoDecorationAnimation.rows),
                0.0
            )

            guard let downsampleEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            downsampleEncoder.setComputePipelineState(decoration.downsamplePipelineState)
            downsampleEncoder.setTexture(primaryY, index: 0)
            downsampleEncoder.setTexture(primaryCbCr, index: 1)
            downsampleEncoder.setTexture(secondaryY, index: 2)
            downsampleEncoder.setTexture(secondaryCbCr, index: 3)
            downsampleEncoder.setTexture(decoration.downsampleTexture, index: 4)
            downsampleEncoder.setBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
            Self.dispatch(
                encoder: downsampleEncoder,
                pipelineState: decoration.downsamplePipelineState,
                width: RoundVideoMetalDecoration.blurWidth,
                height: RoundVideoMetalDecoration.blurHeight
            )
            downsampleEncoder.endEncoding()

            decoration.blur.encode(
                commandBuffer: commandBuffer,
                sourceTexture: decoration.downsampleTexture,
                destinationTexture: decoration.blurredTexture
            )

            guard let compositeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            compositeEncoder.setComputePipelineState(decoration.compositePipelineState)
            compositeEncoder.setTexture(primaryY, index: 0)
            compositeEncoder.setTexture(primaryCbCr, index: 1)
            compositeEncoder.setTexture(secondaryY, index: 2)
            compositeEncoder.setTexture(secondaryCbCr, index: 3)
            compositeEncoder.setTexture(output, index: 4)
            compositeEncoder.setTexture(decoration.blurredTexture, index: 5)
            compositeEncoder.setTexture(decoration.watermarkTexture, index: 6)
            compositeEncoder.setTexture(decoration.atlasTexture, index: 7)
            compositeEncoder.setBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
            Self.dispatch(
                encoder: compositeEncoder,
                pipelineState: decoration.compositePipelineState,
                width: Self.outputWidth,
                height: Self.outputHeight
            )
            compositeEncoder.endEncoding()
        } else {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return
            }
            encoder.setComputePipelineState(self.plainPipelineState)
            encoder.setTexture(primaryY, index: 0)
            encoder.setTexture(primaryCbCr, index: 1)
            encoder.setTexture(secondaryY, index: 2)
            encoder.setTexture(secondaryCbCr, index: 3)
            encoder.setTexture(output, index: 4)
            encoder.setBytes(&uniforms, length: MemoryLayout<FrameUniforms>.stride, index: 0)
            Self.dispatch(
                encoder: encoder,
                pipelineState: self.plainPipelineState,
                width: Self.outputWidth,
                height: Self.outputHeight
            )
            encoder.endEncoding()
        }

        let retainedPixelBuffers = [primary.pixelBuffer, effectiveSecondary.pixelBuffer, outputPixelBuffer]
        let retainedTextures = [
            primaryTextures.y,
            primaryTextures.cbcr,
            secondaryTextures.y,
            secondaryTextures.cbcr,
            outputTexture
        ]
        self.isRendering = true
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            let processedFrame: ProcessedVideoFrame?
            if commandBuffer.status == .completed {
                processedFrame = ProcessedVideoFrame(pixelBuffer: outputPixelBuffer)
            } else {
                processedFrame = nil
            }
            self?.mediaQueue.async { [weak self] in
                guard let self else {
                    return
                }
                self.isRendering = false
                withExtendedLifetime(retainedPixelBuffers) {
                    withExtendedLifetime(retainedTextures) {
                        completion(processedFrame)
                    }
                }
            }
        }
        commandBuffer.commit()
    }

    private static func dispatch(
        encoder: MTLComputeCommandEncoder,
        pipelineState: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = pipelineState.threadExecutionWidth
        let threadHeight = max(1, pipelineState.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
    }

    static func videoColorProperties(from source: VideoFrameSource) -> [String: Any] {
        return [
            AVVideoColorPrimariesKey: source.colorAttachments[kCVImageBufferColorPrimariesKey as String] ?? AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: source.colorAttachments[kCVImageBufferTransferFunctionKey as String] ?? AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: source.colorAttachments[kCVImageBufferYCbCrMatrixKey as String] ?? AVVideoYCbCrMatrix_ITU_R_709_2
        ]
    }

    private func isSupportedInput(_ pixelBuffer: CVPixelBuffer) -> Bool {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        return CVPixelBufferGetPlaneCount(pixelBuffer) == 2 && (
            pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
            pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
    }

    private func makeInputTextures(pixelBuffer: CVPixelBuffer) -> (y: CVMetalTexture, cbcr: CVMetalTexture)? {
        var yTexture: CVMetalTexture?
        let yStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            self.textureCache,
            pixelBuffer,
            nil,
            .r8Unorm,
            CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
            CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
            0,
            &yTexture
        )

        var cbcrTexture: CVMetalTexture?
        let cbcrStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            self.textureCache,
            pixelBuffer,
            nil,
            .rg8Unorm,
            CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
            CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
            1,
            &cbcrTexture
        )

        guard yStatus == kCVReturnSuccess, cbcrStatus == kCVReturnSuccess, let yTexture, let cbcrTexture else {
            return nil
        }
        return (yTexture, cbcrTexture)
    }

    private func makeOutputTexture(pixelBuffer: CVPixelBuffer) -> CVMetalTexture? {
        var texture: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            self.textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            Self.outputWidth,
            Self.outputHeight,
            0,
            &texture
        ) == kCVReturnSuccess else {
            return nil
        }
        return texture
    }

    private static func sourceDescription(for source: VideoFrameSource) -> SIMD4<Float> {
        let width = Float(CVPixelBufferGetWidth(source.pixelBuffer))
        let height = Float(CVPixelBufferGetHeight(source.pixelBuffer))
        let rotation: Float
        switch (source.orientation, source.position) {
        case (.portrait, .front):
            rotation = 1.0
        case (.portrait, _):
            rotation = 1.0
        case (.landscapeLeft, .front):
            rotation = 0.0
        case (.landscapeLeft, _):
            rotation = 2.0
        case (.landscapeRight, .front):
            rotation = 2.0
        case (.landscapeRight, _):
            rotation = 0.0
        case (.portraitUpsideDown, .front):
            rotation = 3.0
        case (.portraitUpsideDown, _):
            rotation = 3.0
        @unknown default:
            rotation = 1.0
        }
        return SIMD4<Float>(width, height, rotation, source.position == .front ? 1.0 : 0.0)
    }

    private static func colorConversion(for source: VideoFrameSource) -> ColorConversion {
        let matrixName = source.colorAttachments[kCVImageBufferYCbCrMatrixKey as String] as? String

        let kr: Float
        let kb: Float
        if matrixName == kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String {
            kr = 0.299
            kb = 0.114
        } else if matrixName == kCVImageBufferYCbCrMatrix_ITU_R_2020 as String {
            kr = 0.2627
            kb = 0.0593
        } else {
            kr = 0.2126
            kb = 0.0722
        }

        let kg = 1.0 - kr - kb
        let isFullRange = CVPixelBufferGetPixelFormatType(source.pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let yScale: Float = isFullRange ? 1.0 : 255.0 / 219.0
        let chromaScale: Float = isFullRange ? 1.0 : 255.0 / 224.0
        let yOffset: Float = isFullRange ? 0.0 : -16.0 / 255.0
        let chromaOffset: Float = -128.0 / 255.0

        return ColorConversion(
            row0: SIMD4<Float>(yScale, 0.0, 2.0 * (1.0 - kr) * chromaScale, 0.0),
            row1: SIMD4<Float>(
                yScale,
                -2.0 * kb * (1.0 - kb) / kg * chromaScale,
                -2.0 * kr * (1.0 - kr) / kg * chromaScale,
                0.0
            ),
            row2: SIMD4<Float>(yScale, 2.0 * (1.0 - kb) * chromaScale, 0.0, 0.0),
            offset: SIMD4<Float>(yOffset, chromaOffset, chromaOffset, 0.0)
        )
    }
}
