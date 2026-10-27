import Foundation
import UIKit
import Metal
import CoreVideo
import simd

struct MediaEditorCompositionLayer {
    enum Origin {
        case topLeft
        case bottomLeft
    }

    let texture: MTLTexture
    let origin: Origin
    let transform: CGAffineTransform
    let alphaMask: MTLTexture?
    var perspective: MediaEditorPerspectiveHomography? = nil
}

struct MediaEditorCompositionScene {
    var outputSize: CGSize
    var background: SIMD4<Float>?
    var backgroundRect: CGRect
    var layers: [MediaEditorCompositionLayer]
    var finalMask: (texture: MTLTexture, transform: CGAffineTransform)?
    var backgroundTransform: CGAffineTransform = .identity
    var clipRect: CGRect?
}

private struct MediaEditorComposeVertex {
    var position: SIMD4<Float>
    var texCoord: SIMD2<Float>
}

private func mediaEditorAffineMatrix(_ transform: CGAffineTransform) -> simd_double3x3 {
    return simd_double3x3(rows: [
        simd_double3(Double(transform.a), Double(transform.c), Double(transform.tx)),
        simd_double3(Double(transform.b), Double(transform.d), Double(transform.ty)),
        simd_double3(0.0, 0.0, 1.0)
    ])
}

private let mediaEditorComposeColorCurveSize = 4097
private let mediaEditorComposeColorCurveDomain: ClosedRange<Float> = -1.0 ... 3.0
private let mediaEditorComposeColorModelTolerance: Float = 0.002

private struct MediaEditorComposeColorConversion {
    var column0: SIMD4<Float>
    var column1: SIMD4<Float>
    var column2: SIMD4<Float>
    var domain: SIMD4<Float>
}

private struct MediaEditorComposeColorModel {
    let curve: [Float]
    let parameters: MediaEditorComposeColorConversion
    let curveBuffer: MTLBuffer

    func linearize(_ value: Float) -> Float {
        let domain = self.parameters.domain
        let position = (min(max(value, domain.x), domain.y) - domain.x) / (domain.y - domain.x) * Float(self.curve.count - 1)
        let index = min(Int(position), self.curve.count - 2)
        let fraction = position - Float(index)
        return self.curve[index] + (self.curve[index + 1] - self.curve[index]) * fraction
    }

    func convert(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let linear = SIMD3<Float>(self.linearize(rgb.x), self.linearize(rgb.y), self.linearize(rgb.z))
        let converted = self.parameters.column0 * linear.x + self.parameters.column1 * linear.y + self.parameters.column2 * linear.z
        func encode(_ value: Float) -> Float {
            let magnitude = abs(value)
            let encoded = magnitude <= 0.0031308 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1.0 / 2.4) - 0.055
            return value < 0.0 ? -encoded : encoded
        }
        return SIMD3<Float>(encode(converted.x), encode(converted.y), encode(converted.z))
    }
}

private struct MediaEditorComposeRenderPipelines {
    let layer: MTLRenderPipelineState
    let maskedLayer: MTLRenderPipelineState
    let color: MTLRenderPipelineState
    let finalMask: MTLRenderPipelineState
    let clip: MTLRenderPipelineState
}

private func makeComposeRenderPipelines(device: MTLDevice, library: MTLLibrary, pixelFormat: MTLPixelFormat) -> MediaEditorComposeRenderPipelines? {
    func makePipeline(fragment: String, sourceFactor: MTLBlendFactor, destinationFactor: MTLBlendFactor) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "editorComposeVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        guard descriptor.vertexFunction != nil, descriptor.fragmentFunction != nil else {
            return nil
        }
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = pixelFormat
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = sourceFactor
        attachment.sourceAlphaBlendFactor = sourceFactor
        attachment.destinationRGBBlendFactor = destinationFactor
        attachment.destinationAlphaBlendFactor = destinationFactor
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    guard let layer = makePipeline(fragment: "editorComposeLayerFragmentShader", sourceFactor: .one, destinationFactor: .oneMinusSourceAlpha),
          let maskedLayer = makePipeline(fragment: "editorComposeMaskedLayerFragmentShader", sourceFactor: .one, destinationFactor: .oneMinusSourceAlpha),
          let color = makePipeline(fragment: "editorComposeColorFragmentShader", sourceFactor: .one, destinationFactor: .oneMinusSourceAlpha),
          let finalMask = makePipeline(fragment: "editorComposeFinalMaskFragmentShader", sourceFactor: .zero, destinationFactor: .sourceAlpha),
          let clip = makePipeline(fragment: "editorComposeClipFragmentShader", sourceFactor: .zero, destinationFactor: .sourceAlpha) else {
        return nil
    }
    return MediaEditorComposeRenderPipelines(layer: layer, maskedLayer: maskedLayer, color: color, finalMask: finalMask, clip: clip)
}

private enum MediaEditorComposeColorPath {
    case none
    case gpu(MediaEditorComposeColorModel)
    case coreGraphics(CGColorSpace)
}

private struct MediaEditorComposeYuvParameters {
    var range: SIMD4<Float>
    var coefficients: SIMD4<Float>
}

func mediaEditorComposeMaxTextureSide(device: MTLDevice) -> Int {
    return device.supportsFamily(.apple3) ? 16384 : 8192
}

private func roundedOut(_ rect: CGRect) -> CGRect {
    let tolerance: CGFloat = 1.0 / 1024.0
    let minX = (rect.minX + tolerance).rounded(.down)
    let minY = (rect.minY + tolerance).rounded(.down)
    let maxX = (rect.maxX - tolerance).rounded(.up)
    let maxY = (rect.maxY - tolerance).rounded(.up)
    return CGRect(x: minX, y: minY, width: max(0.0, maxX - minX), height: max(0.0, maxY - minY))
}

final class MediaEditorFrameCompositor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache
    private let library: MTLLibrary
    private var renderPipelines: [MTLPixelFormat: MediaEditorComposeRenderPipelines] = [:]
    private let resolvePipeline: MTLRenderPipelineState
    private var scratchTexture: MTLTexture?
    private let yuvPipeline: MTLComputePipelineState
    private let yuvColorConvertedPipeline: MTLComputePipelineState
    private let colorConvertPipeline: MTLComputePipelineState
    private var colorModels: [(source: CGColorSpace, destination: CGColorSpace, model: MediaEditorComposeColorModel?)] = []

    private var retainedTextures: [CVMetalTexture] = []
    private var availableTextures: [MTLTexture] = []
    private var texturesInUse: [MTLTexture] = []
    private var lastConversionCommandBuffer: MTLCommandBuffer?
    private(set) var allocatedTextureCount = 0

    init?(device: MTLDevice, commandQueue: MTLCommandQueue) {
        let mainBundle = Bundle(for: MediaEditorFrameCompositor.self)
        guard let path = mainBundle.path(forResource: "MediaEditorBundle", ofType: "bundle"), let bundle = Bundle(path: path) else {
            return nil
        }
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            return nil
        }
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        guard let textureCache else {
            return nil
        }

        guard let pipelines = makeComposeRenderPipelines(device: device, library: library, pixelFormat: .bgra8Unorm) else {
            return nil
        }
        let resolveDescriptor = MTLRenderPipelineDescriptor()
        resolveDescriptor.vertexFunction = library.makeFunction(name: "editorComposeVertexShader")
        resolveDescriptor.fragmentFunction = library.makeFunction(name: "editorComposeResolveFragmentShader")
        resolveDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard resolveDescriptor.vertexFunction != nil, resolveDescriptor.fragmentFunction != nil, let resolvePipeline = try? device.makeRenderPipelineState(descriptor: resolveDescriptor) else {
            return nil
        }
        guard let yuvFunction = library.makeFunction(name: "editorComposeYuvToRgbKernel"), let yuvPipeline = try? device.makeComputePipelineState(function: yuvFunction) else {
            return nil
        }
        guard let yuvColorConvertedFunction = library.makeFunction(name: "editorComposeYuvToRgbColorConvertedKernel"), let yuvColorConvertedPipeline = try? device.makeComputePipelineState(function: yuvColorConvertedFunction) else {
            return nil
        }
        guard let colorConvertFunction = library.makeFunction(name: "editorComposeColorConvertKernel"), let colorConvertPipeline = try? device.makeComputePipelineState(function: colorConvertFunction) else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.textureCache = textureCache
        self.library = library
        self.renderPipelines[.bgra8Unorm] = pipelines
        self.resolvePipeline = resolvePipeline
        self.yuvPipeline = yuvPipeline
        self.yuvColorConvertedPipeline = yuvColorConvertedPipeline
        self.colorConvertPipeline = colorConvertPipeline
    }

    func render(scene: MediaEditorCompositionScene, into pixelBuffer: CVPixelBuffer) -> Bool {
        defer {
            self.releaseFrameTextures()
        }
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            return false
        }
        guard scene.outputSize.width > 0.0, scene.outputSize.height > 0.0 else {
            return false
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var targetRef: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &targetRef) == kCVReturnSuccess, let targetRef, let target = CVMetalTextureGetTexture(targetRef) else {
            return false
        }
        guard let scratch = self.scratchTexture(width: width, height: height) else {
            return false
        }
        return withExtendedLifetime(targetRef) {
            return self.encode(scene: scene, target: scratch, resolveTarget: target)
        }
    }

    private func scratchTexture(width: Int, height: Int) -> MTLTexture? {
        if let scratchTexture = self.scratchTexture, scratchTexture.width == width, scratchTexture.height == height {
            return scratchTexture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        self.scratchTexture = self.device.makeTexture(descriptor: descriptor)
        return self.scratchTexture
    }

    func render(scene: MediaEditorCompositionScene, into target: MTLTexture) -> Bool {
        defer {
            self.releaseFrameTextures()
        }
        guard scene.outputSize.width > 0.0, scene.outputSize.height > 0.0 else {
            return false
        }
        return self.encode(scene: scene, target: target, resolveTarget: nil)
    }

    private func encode(scene: MediaEditorCompositionScene, target: MTLTexture, resolveTarget: MTLTexture?) -> Bool {
        let width = target.width
        let height = target.height
        let pipelines: MediaEditorComposeRenderPipelines
        if let current = self.renderPipelines[target.pixelFormat] {
            pipelines = current
        } else if let created = makeComposeRenderPipelines(device: self.device, library: self.library, pixelFormat: target.pixelFormat) {
            self.renderPipelines[target.pixelFormat] = created
            pipelines = created
        } else {
            return false
        }
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            return false
        }
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = target
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            return false
        }
        encoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0))

        let outputSize = scene.outputSize
        func normalized(_ point: CGPoint) -> SIMD4<Float> {
            return SIMD4<Float>(Float(point.x / outputSize.width * 2.0 - 1.0), Float(point.y / outputSize.height * 2.0 - 1.0), 0.0, 1.0)
        }
        func normalized(homogeneous point: simd_double3) -> SIMD4<Float> {
            return SIMD4<Float>(Float(point.x / Double(outputSize.width) * 2.0 - point.z), Float(point.y / Double(outputSize.height) * 2.0 - point.z), 0.0, Float(point.z))
        }

        if let background = scene.background, !scene.backgroundRect.isEmpty {
            let rect = scene.backgroundRect
            let transform = scene.backgroundTransform
            var vertices = [
                MediaEditorComposeVertex(position: normalized(CGPoint(x: rect.minX, y: rect.minY).applying(transform)), texCoord: .zero),
                MediaEditorComposeVertex(position: normalized(CGPoint(x: rect.maxX, y: rect.minY).applying(transform)), texCoord: .zero),
                MediaEditorComposeVertex(position: normalized(CGPoint(x: rect.minX, y: rect.maxY).applying(transform)), texCoord: .zero),
                MediaEditorComposeVertex(position: normalized(CGPoint(x: rect.maxX, y: rect.maxY).applying(transform)), texCoord: .zero)
            ]
            var color = background
            encoder.setRenderPipelineState(pipelines.color)
            encoder.setVertexBytes(&vertices, length: MemoryLayout<MediaEditorComposeVertex>.stride * vertices.count, index: 0)
            encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        let outputBounds = CGRect(origin: .zero, size: outputSize)
        let scaleX = CGFloat(width) / outputSize.width
        let scaleY = CGFloat(height) / outputSize.height
        for layer in scene.layers {
            let layerWidth = CGFloat(layer.texture.width)
            let layerHeight = CGFloat(layer.texture.height)
            let layerRect = CGRect(x: 0.0, y: 0.0, width: layerWidth, height: layerHeight)
            let transform = layer.transform
            let determinant = transform.a * transform.d - transform.b * transform.c
            guard abs(determinant) > .ulpOfOne else {
                continue
            }
            let projection = mediaEditorAffineMatrix(transform) * (layer.perspective?.m ?? matrix_identity_double3x3)
            func project(_ point: CGPoint) -> simd_double3 {
                return projection * simd_double3(Double(point.x), Double(point.y), 1.0)
            }
            if layer.perspective != nil {
                let depths = [CGPoint(x: 0.0, y: 0.0), CGPoint(x: layerWidth, y: 0.0), CGPoint(x: 0.0, y: layerHeight), CGPoint(x: layerWidth, y: layerHeight)].map { project($0).z }
                guard depths.allSatisfy({ $0 > 1e-3 }) else {
                    continue
                }
            }
            let projectedCorners = [CGPoint(x: 0.0, y: 0.0), CGPoint(x: layerWidth, y: 0.0), CGPoint(x: 0.0, y: layerHeight), CGPoint(x: layerWidth, y: layerHeight)].map { corner -> CGPoint in
                let point = project(corner)
                return CGPoint(x: point.x / point.z, y: point.y / point.z)
            }
            if layer.perspective != nil {
                guard projectedCorners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                    continue
                }
            }
            let projectedBounds: CGRect
            if layer.perspective != nil {
                let xs = projectedCorners.map(\.x)
                let ys = projectedCorners.map(\.y)
                projectedBounds = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            } else {
                projectedBounds = layerRect.applying(transform)
            }
            let renderRect = roundedOut(projectedBounds).intersection(outputBounds)
            guard !renderRect.isNull, !renderRect.isEmpty else {
                continue
            }
            let scissorMinX = max(0, min(width, Int((renderRect.minX * scaleX).rounded(.down))))
            let scissorMaxX = max(0, min(width, Int((renderRect.maxX * scaleX).rounded(.up))))
            let scissorMinY = max(0, min(height, Int(((outputSize.height - renderRect.maxY) * scaleY).rounded(.down))))
            let scissorMaxY = max(0, min(height, Int(((outputSize.height - renderRect.minY) * scaleY).rounded(.up))))
            guard scissorMaxX > scissorMinX, scissorMaxY > scissorMinY else {
                continue
            }
            encoder.setScissorRect(MTLScissorRect(x: scissorMinX, y: scissorMinY, width: scissorMaxX - scissorMinX, height: scissorMaxY - scissorMinY))

            let sampleRect = layer.perspective != nil ? layerRect : roundedOut(renderRect.applying(transform.inverted()))
            let minV: CGFloat
            let maxV: CGFloat
            switch layer.origin {
            case .topLeft:
                minV = layerHeight - sampleRect.maxY
                maxV = layerHeight - sampleRect.minY
            case .bottomLeft:
                minV = sampleRect.minY
                maxV = sampleRect.maxY
            }
            var sampleBounds = SIMD4<Float>(
                Float((sampleRect.minX + 0.5) / layerWidth),
                Float((minV + 0.5) / layerHeight),
                Float((sampleRect.maxX - 0.5) / layerWidth),
                Float((maxV - 0.5) / layerHeight)
            )

            let minScale: CGFloat
            if layer.perspective != nil {
                let horizontal = min(hypot(projectedCorners[1].x - projectedCorners[0].x, projectedCorners[1].y - projectedCorners[0].y), hypot(projectedCorners[3].x - projectedCorners[2].x, projectedCorners[3].y - projectedCorners[2].y)) / layerWidth
                let vertical = min(hypot(projectedCorners[2].x - projectedCorners[0].x, projectedCorners[2].y - projectedCorners[0].y), hypot(projectedCorners[3].x - projectedCorners[1].x, projectedCorners[3].y - projectedCorners[1].y)) / layerHeight
                minScale = min(horizontal, vertical)
            } else {
                minScale = min(hypot(transform.a, transform.b), hypot(transform.c, transform.d))
            }
            let margin = max(1.0, 1.5 / max(minScale, .ulpOfOne))
            let corners = [
                CGPoint(x: -margin, y: -margin),
                CGPoint(x: layerWidth + margin, y: -margin),
                CGPoint(x: -margin, y: layerHeight + margin),
                CGPoint(x: layerWidth + margin, y: layerHeight + margin)
            ]
            var vertices = corners.map { corner -> MediaEditorComposeVertex in
                let u = corner.x / layerWidth
                let v: CGFloat
                switch layer.origin {
                case .topLeft:
                    v = 1.0 - corner.y / layerHeight
                case .bottomLeft:
                    v = corner.y / layerHeight
                }
                return MediaEditorComposeVertex(position: normalized(homogeneous: project(corner)), texCoord: SIMD2<Float>(Float(u), Float(v)))
            }
            if let alphaMask = layer.alphaMask {
                encoder.setRenderPipelineState(pipelines.maskedLayer)
                encoder.setFragmentTexture(alphaMask, index: 1)
            } else {
                encoder.setRenderPipelineState(pipelines.layer)
            }
            encoder.setVertexBytes(&vertices, length: MemoryLayout<MediaEditorComposeVertex>.stride * vertices.count, index: 0)
            encoder.setFragmentBytes(&sampleBounds, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            encoder.setFragmentTexture(layer.texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: width, height: height))

        if let finalMask = scene.finalMask {
            let maskWidth = CGFloat(finalMask.texture.width)
            let maskHeight = CGFloat(finalMask.texture.height)
            let inverse = finalMask.transform.inverted()
            let corners = [
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: outputSize.width, y: 0.0),
                CGPoint(x: 0.0, y: outputSize.height),
                CGPoint(x: outputSize.width, y: outputSize.height)
            ]
            var vertices = corners.map { corner -> MediaEditorComposeVertex in
                let maskPoint = corner.applying(inverse)
                return MediaEditorComposeVertex(position: normalized(corner), texCoord: SIMD2<Float>(Float(maskPoint.x / maskWidth), Float(1.0 - maskPoint.y / maskHeight)))
            }
            encoder.setRenderPipelineState(pipelines.finalMask)
            encoder.setVertexBytes(&vertices, length: MemoryLayout<MediaEditorComposeVertex>.stride * vertices.count, index: 0)
            encoder.setFragmentTexture(finalMask.texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        if let clipRect = scene.clipRect {
            var clip = SIMD4<Float>(
                Float(clipRect.minX * scaleX),
                Float((outputSize.height - clipRect.maxY) * scaleY),
                Float(clipRect.maxX * scaleX),
                Float((outputSize.height - clipRect.minY) * scaleY)
            )
            if clip.x > 0.0 || clip.y > 0.0 || clip.z < Float(width) || clip.w < Float(height) {
                var vertices = [
                    MediaEditorComposeVertex(position: SIMD4<Float>(-1.0, -1.0, 0.0, 1.0), texCoord: .zero),
                    MediaEditorComposeVertex(position: SIMD4<Float>(1.0, -1.0, 0.0, 1.0), texCoord: .zero),
                    MediaEditorComposeVertex(position: SIMD4<Float>(-1.0, 1.0, 0.0, 1.0), texCoord: .zero),
                    MediaEditorComposeVertex(position: SIMD4<Float>(1.0, 1.0, 0.0, 1.0), texCoord: .zero)
                ]
                encoder.setRenderPipelineState(pipelines.clip)
                encoder.setVertexBytes(&vertices, length: MemoryLayout<MediaEditorComposeVertex>.stride * vertices.count, index: 0)
                encoder.setFragmentBytes(&clip, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }

        encoder.endEncoding()

        if let resolveTarget {
            let resolveDescriptor = MTLRenderPassDescriptor()
            resolveDescriptor.colorAttachments[0].texture = resolveTarget
            resolveDescriptor.colorAttachments[0].loadAction = .dontCare
            resolveDescriptor.colorAttachments[0].storeAction = .store
            guard let resolveEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: resolveDescriptor) else {
                return false
            }
            var vertices = [
                MediaEditorComposeVertex(position: SIMD4<Float>(-1.0, -1.0, 0.0, 1.0), texCoord: .zero),
                MediaEditorComposeVertex(position: SIMD4<Float>(1.0, -1.0, 0.0, 1.0), texCoord: .zero),
                MediaEditorComposeVertex(position: SIMD4<Float>(-1.0, 1.0, 0.0, 1.0), texCoord: .zero),
                MediaEditorComposeVertex(position: SIMD4<Float>(1.0, 1.0, 0.0, 1.0), texCoord: .zero)
            ]
            resolveEncoder.setRenderPipelineState(self.resolvePipeline)
            resolveEncoder.setVertexBytes(&vertices, length: MemoryLayout<MediaEditorComposeVertex>.stride * vertices.count, index: 0)
            resolveEncoder.setFragmentTexture(target, index: 0)
            resolveEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            resolveEncoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return commandBuffer.status == .completed
    }

    func renderImage(scene: MediaEditorCompositionScene) -> UIImage? {
        let width = Int(scene.outputSize.width.rounded())
        let height = Int(scene.outputSize.height.rounded())
        guard width > 0, height > 0 else {
            return nil
        }
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer) == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }
        guard self.render(scene: scene, into: pixelBuffer) else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerRow = width * 4
        var data = Data(count: bytesPerRow * height)
        data.withUnsafeMutableBytes { buffer in
            for row in 0 ..< height {
                memcpy(buffer.baseAddress! + row * bytesPerRow, baseAddress + row * sourceBytesPerRow, bytesPerRow)
            }
        }
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    func texture(for pixelBuffer: CVPixelBuffer, convertingTo destination: CGColorSpace?, extendedRange: Bool = true) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let colorPath = destination.flatMap { self.colorPath(for: pixelBuffer, pixelFormat: pixelFormat, destination: $0) } ?? .none
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            switch colorPath {
            case .none:
                guard let (textureRef, texture) = self.cachedTexture(pixelBuffer, pixelFormat: .bgra8Unorm, width: width, height: height, plane: 0) else {
                    return nil
                }
                self.retainedTextures.append(textureRef)
                return texture
            case let .gpu(model):
                guard let (textureRef, texture) = self.cachedTexture(pixelBuffer, pixelFormat: .bgra8Unorm, width: width, height: height, plane: 0) else {
                    return nil
                }
                self.retainedTextures.append(textureRef)
                return self.convertColors(texture, model: model, extendedRange: extendedRange)
            case let .coreGraphics(source):
                return self.coreGraphicsTexture(pixelBuffer, colorSpace: source, width: width, height: height)
            }
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return self.convertYuv(pixelBuffer, width: width, height: height, isVideoRange: pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, colorPath: colorPath, extendedRange: extendedRange)
        default:
            return nil
        }
    }

    func texture(for image: CGImage) -> MTLTexture? {
        return self.drawnTexture(image)
    }

    private func coreGraphicsTexture(_ pixelBuffer: CVPixelBuffer, colorSpace: CGColorSpace, width: Int, height: Int) -> MTLTexture? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let provider = CGDataProvider(dataInfo: nil, data: baseAddress, size: bytesPerRow * height, releaseData: { _, _, _ in }) else {
            return nil
        }
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        return self.drawnTexture(image)
    }

    private func reusableTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, storageMode: MTLStorageMode) -> MTLTexture? {
        if let index = self.availableTextures.firstIndex(where: { $0.width == width && $0.height == height && $0.pixelFormat == pixelFormat && $0.storageMode == storageMode }) {
            let texture = self.availableTextures.remove(at: index)
            self.texturesInUse.append(texture)
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = storageMode
        guard let texture = self.device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        self.allocatedTextureCount += 1
        self.texturesInUse.append(texture)
        return texture
    }

    private func dispatch(_ encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, width: Int, height: Int) {
        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerGroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let groups = MTLSize(width: (width + threadWidth - 1) / threadWidth, height: (height + threadHeight - 1) / threadHeight, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
    }

    private func convertColors(_ texture: MTLTexture, model: MediaEditorComposeColorModel, extendedRange: Bool) -> MTLTexture? {
        guard let output = self.reusableTexture(width: texture.width, height: texture.height, pixelFormat: extendedRange ? .rgba16Float : .bgra8Unorm, storageMode: .private), let commandBuffer = self.commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        var parameters = model.parameters
        parameters.domain.w = extendedRange ? 0.0 : 1.0
        encoder.setComputePipelineState(self.colorConvertPipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBuffer(model.curveBuffer, offset: 0, index: 0)
        encoder.setBytes(&parameters, length: MemoryLayout<MediaEditorComposeColorConversion>.stride, index: 1)
        self.dispatch(encoder, pipeline: self.colorConvertPipeline, width: texture.width, height: texture.height)
        encoder.endEncoding()
        commandBuffer.commit()
        self.lastConversionCommandBuffer = commandBuffer
        return output
    }

    private func drawnTexture(_ image: CGImage) -> MTLTexture? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, width <= mediaEditorComposeMaxTextureSide(device: self.device), height <= mediaEditorComposeMaxTextureSide(device: self.device) else {
            return nil
        }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                return false
            }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
            return true
        }
        guard drawn else {
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = self.device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        bytes.withUnsafeBytes { buffer in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: buffer.baseAddress!, bytesPerRow: bytesPerRow)
        }
        return texture
    }

    private func cachedTexture(_ pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, width: Int, height: Int, plane: Int) -> (CVMetalTexture, MTLTexture)? {
        var textureRef: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, nil, pixelFormat, width, height, plane, &textureRef) == kCVReturnSuccess, let textureRef, let texture = CVMetalTextureGetTexture(textureRef) else {
            return nil
        }
        return (textureRef, texture)
    }

    private func convertYuv(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int, isVideoRange: Bool, colorPath: MediaEditorComposeColorPath, extendedRange: Bool) -> MTLTexture? {
        guard let (yRef, yTexture) = self.cachedTexture(pixelBuffer, pixelFormat: .r8Unorm, width: CVPixelBufferGetWidthOfPlane(pixelBuffer, 0), height: CVPixelBufferGetHeightOfPlane(pixelBuffer, 0), plane: 0),
              let (cbcrRef, cbcrTexture) = self.cachedTexture(pixelBuffer, pixelFormat: .rg8Unorm, width: CVPixelBufferGetWidthOfPlane(pixelBuffer, 1), height: CVPixelBufferGetHeightOfPlane(pixelBuffer, 1), plane: 1) else {
            return nil
        }
        self.retainedTextures.append(yRef)
        self.retainedTextures.append(cbcrRef)
        var coreGraphicsSource: CGColorSpace?
        if case let .coreGraphics(source) = colorPath {
            coreGraphicsSource = source
        }
        var isColorConverted = false
        if case .gpu = colorPath {
            isColorConverted = extendedRange
        }
        guard let output = self.reusableTexture(width: width, height: height, pixelFormat: isColorConverted ? .rgba16Float : .bgra8Unorm, storageMode: coreGraphicsSource == nil ? .private : .shared), let commandBuffer = self.commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        let (kr, kb): (Float, Float)
        let matrix = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, nil) as? String
        if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String) {
            (kr, kb) = (0.2126, 0.0722)
        } else if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_2020 as String) {
            (kr, kb) = (0.2627, 0.0593)
        } else {
            (kr, kb) = (0.299, 0.114)
        }
        let kg = 1.0 - kr - kb
        let range = isVideoRange ? SIMD4<Float>(16.0 / 255.0, 255.0 / 219.0, 128.0 / 255.0, 255.0 / 224.0) : SIMD4<Float>(0.0, 1.0, 128.0 / 255.0, 1.0)
        var parameters = MediaEditorComposeYuvParameters(
            range: range,
            coefficients: SIMD4<Float>(2.0 * (1.0 - kr), -2.0 * kb * (1.0 - kb) / kg, -2.0 * kr * (1.0 - kr) / kg, 2.0 * (1.0 - kb))
        )

        let pipeline: MTLComputePipelineState
        if case let .gpu(model) = colorPath {
            pipeline = self.yuvColorConvertedPipeline
            var conversion = model.parameters
            encoder.setBuffer(model.curveBuffer, offset: 0, index: 1)
            encoder.setBytes(&conversion, length: MemoryLayout<MediaEditorComposeColorConversion>.stride, index: 2)
        } else {
            pipeline = self.yuvPipeline
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(yTexture, index: 0)
        encoder.setTexture(cbcrTexture, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&parameters, length: MemoryLayout<MediaEditorComposeYuvParameters>.stride, index: 0)
        self.dispatch(encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        self.lastConversionCommandBuffer = commandBuffer

        guard let coreGraphicsSource else {
            return output
        }
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            return nil
        }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        bytes.withUnsafeMutableBytes { buffer in
            output.getBytes(buffer.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: coreGraphicsSource, bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        return self.drawnTexture(image)
    }

    private func sourceColorSpace(for pixelBuffer: CVPixelBuffer, pixelFormat: OSType) -> CGColorSpace? {
        if pixelFormat == kCVPixelFormatType_32BGRA, let attachment = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, nil), CFGetTypeID(attachment) == CGColorSpace.typeID {
            return (attachment as! CGColorSpace)
        }
        guard let attachments = CVBufferCopyAttachments(pixelBuffer, .shouldPropagate) else {
            return nil
        }
        return CVImageBufferCreateColorSpaceFromAttachments(attachments)?.takeRetainedValue()
    }

    private func colorPath(for pixelBuffer: CVPixelBuffer, pixelFormat: OSType, destination: CGColorSpace) -> MediaEditorComposeColorPath {
        guard let source = self.sourceColorSpace(for: pixelBuffer, pixelFormat: pixelFormat), source != destination else {
            return .none
        }
        if let entry = self.colorModels.first(where: { $0.source == source && $0.destination == destination }) {
            return entry.model.flatMap { .gpu($0) } ?? .coreGraphics(source)
        }
        let model = self.makeColorModel(source: source, destination: destination)
        self.colorModels.append((source, destination, model))
        if self.colorModels.count > 4 {
            self.colorModels.removeFirst()
        }
        return model.flatMap { .gpu($0) } ?? .coreGraphics(source)
    }

    private func drawFloatPixels(_ pixels: [SIMD3<Float>], from source: CGColorSpace, to destination: CGColorSpace) -> [SIMD3<Float>]? {
        let width = pixels.count
        let bytesPerRow = width * 16
        var input = [Float](repeating: 1.0, count: width * 4)
        for (index, pixel) in pixels.enumerated() {
            input[index * 4] = pixel.x
            input[index * 4 + 1] = pixel.y
            input[index * 4 + 2] = pixel.z
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes: input, count: input.count * 4) as CFData), let image = CGImage(width: width, height: 1, bitsPerComponent: 32, bitsPerPixel: 128, bytesPerRow: bytesPerRow, space: source, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            return nil
        }
        var output = [Float](repeating: 0.0, count: width * 4)
        let drawn = output.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: 1, bitsPerComponent: 32, bytesPerRow: bytesPerRow, space: destination, bitmapInfo: bitmapInfo.rawValue) else {
                return false
            }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: 1.0))
            return true
        }
        guard drawn else {
            return nil
        }
        return (0 ..< width).map { SIMD3<Float>(output[$0 * 4], output[$0 * 4 + 1], output[$0 * 4 + 2]) }
    }

    private func makeColorModel(source: CGColorSpace, destination: CGColorSpace) -> MediaEditorComposeColorModel? {
        guard source.model == .rgb, destination.model == .rgb, !CGColorSpaceUsesITUR_2100TF(source), !CGColorSpaceUsesITUR_2100TF(destination) else {
            return nil
        }
        guard let extendedSource = CGColorSpaceCreateExtended(source), let linearColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else {
            return nil
        }
        let size = mediaEditorComposeColorCurveSize
        let domain = mediaEditorComposeColorCurveDomain
        var samples: [SIMD3<Float>] = (0 ..< size).map { index in
            return SIMD3<Float>(repeating: domain.lowerBound + (domain.upperBound - domain.lowerBound) * Float(index) / Float(size - 1))
        }
        samples.append(SIMD3<Float>(1.0, 0.0, 0.0))
        samples.append(SIMD3<Float>(0.0, 1.0, 0.0))
        samples.append(SIMD3<Float>(0.0, 0.0, 1.0))
        guard let converted = self.drawFloatPixels(samples, from: extendedSource, to: linearColorSpace) else {
            return nil
        }
        let column0 = SIMD4<Float>(converted[size].x, converted[size].y, converted[size].z, 0.0)
        let column1 = SIMD4<Float>(converted[size + 1].x, converted[size + 1].y, converted[size + 1].z, 0.0)
        let column2 = SIMD4<Float>(converted[size + 2].x, converted[size + 2].y, converted[size + 2].z, 0.0)
        let greenRowSum = column0.y + column1.y + column2.y
        guard greenRowSum > 0.0 else {
            return nil
        }
        var curve = (0 ..< size).map { converted[$0].y / greenRowSum }
        let step = (domain.upperBound - domain.lowerBound) / Float(size - 1)
        let zeroIndex = Int((-domain.lowerBound / step).rounded())
        let toeSlope = curve[zeroIndex + 1] / step
        for index in 0 ..< zeroIndex {
            curve[index] = Float(index - zeroIndex) * step * toeSlope
        }
        guard let curveBuffer = curve.withUnsafeBytes({ self.device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else {
            return nil
        }
        let model = MediaEditorComposeColorModel(curve: curve, parameters: MediaEditorComposeColorConversion(column0: column0, column1: column1, column2: column2, domain: SIMD4<Float>(domain.lowerBound, domain.upperBound, Float(size), 0.0)), curveBuffer: curveBuffer)

        var probes: [SIMD3<Float>] = []
        let levels: [Float] = [0.02, 0.1, 0.25, 0.45, 0.6, 0.8, 0.98]
        for r in levels {
            for g in levels {
                for b in levels {
                    probes.append(SIMD3<Float>(r, g, b))
                }
            }
        }
        guard let expected = self.drawFloatPixels(probes, from: source, to: destination) else {
            return nil
        }
        for (probe, expected) in zip(probes, expected) {
            let actual = simd_clamp(model.convert(probe), SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0))
            if simd_reduce_max(simd_abs(actual - simd_clamp(expected, SIMD3<Float>(repeating: 0.0), SIMD3<Float>(repeating: 1.0)))) > mediaEditorComposeColorModelTolerance {
                return nil
            }
        }
        return model
    }

    func releaseFrameTextures() {
        self.lastConversionCommandBuffer?.waitUntilCompleted()
        self.lastConversionCommandBuffer = nil
        self.retainedTextures.removeAll()
        if !self.texturesInUse.isEmpty {
            self.availableTextures = self.texturesInUse
            self.texturesInUse.removeAll()
        }
        CVMetalTextureCacheFlush(self.textureCache, 0)
    }
}
