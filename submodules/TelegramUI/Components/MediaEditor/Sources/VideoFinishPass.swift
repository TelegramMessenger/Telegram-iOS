import Foundation
import AVFoundation
import Metal
import MetalKit
import SwiftSignalKit

private func verticesData(
    textureRotation: TextureRotation,
    containerSize: CGSize,
    position: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    mirror: Bool = false,
    z: Float = 0.0
) -> [VertexData] {
    var topLeft: simd_float2
    var topRight: simd_float2
    var bottomLeft: simd_float2
    var bottomRight: simd_float2
    
    switch textureRotation {
    case .rotate0Degrees:
        topLeft = simd_float2(0.0, 1.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(1.0, 0.0)
    case .rotate0DegreesMirrored:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate180Degrees:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(0.0, 0.0)
        bottomLeft = simd_float2(1.0, 1.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate90Degrees:
        topLeft = simd_float2(1.0, 1.0)
        topRight = simd_float2(1.0, 0.0)
        bottomLeft = simd_float2(0.0, 1.0)
        bottomRight = simd_float2(0.0, 0.0)
    case .rotate90DegreesMirrored:
        topLeft = simd_float2(1.0, 0.0)
        topRight = simd_float2(1.0, 1.0)
        bottomLeft = simd_float2(0.0, 0.0)
        bottomRight = simd_float2(0.0, 1.0)
    case .rotate270Degrees:
        topLeft = simd_float2(0.0, 0.0)
        topRight = simd_float2(0.0, 1.0)
        bottomLeft = simd_float2(1.0, 0.0)
        bottomRight = simd_float2(1.0, 1.0)
    }
    
    if mirror {
        topLeft = simd_float2(1.0 - topLeft.x, topLeft.y)
        topRight = simd_float2(1.0 - topRight.x, topRight.y)
        bottomLeft = simd_float2(1.0 - bottomLeft.x, bottomLeft.y)
        bottomRight = simd_float2(1.0 - bottomRight.x, bottomRight.y)
    }
    
    let containerSize = CGSize(width: containerSize.width, height: containerSize.height)
    
    let angle = Float(.pi - rotation)
    let cosAngle = cos(angle)
    let sinAngle = sin(angle)

    let centerX = Float(position.x)
    let centerY = Float(position.y)

    let halfWidth = Float(size.width / 2.0)
    let halfHeight = Float(size.height / 2.0)
    
    return [
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topLeft,
            localPos: simd_float2(0.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topRight,
            localPos: simd_float2(1.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomLeft,
            localPos: simd_float2(0.0, 1.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomRight,
            localPos: simd_float2(1.0, 1.0)
        )
    ]
}

private func verticesData(
    size: CGSize,
    textureRotation: TextureRotation,
    containerSize: CGSize,
    textureRect: CGRect,
    scale: simd_float1,
    offset: simd_float2,
    z: Float = 0.0
) -> [VertexData] {
    let textureRect = CGRect(origin: CGPoint(x: textureRect.origin.x, y: containerSize.height - textureRect.maxY ), size: textureRect.size)
    
    let containerAspect = textureRect.width / textureRect.height
    let imageAspect = size.width / size.height
    
    var texCoordScale: simd_float2
    if imageAspect > containerAspect {
        texCoordScale = simd_float2(Float(containerAspect / imageAspect), 1.0)
    } else {
        texCoordScale = simd_float2(1.0, Float(imageAspect / containerAspect))
    }
    
    let adjustedOffset = simd_float2(
        offset.x / texCoordScale.x,
        offset.y / texCoordScale.y
    )
    
    texCoordScale *= 1.0 / scale
    
    let scaledTopLeft = simd_float2(0.5 - texCoordScale.x * 0.5, 0.5 + texCoordScale.y * 0.5) - adjustedOffset
    let scaledTopRight = simd_float2(0.5 + texCoordScale.x * 0.5, 0.5 + texCoordScale.y * 0.5) - adjustedOffset
    let scaledBottomLeft = simd_float2(0.5 - texCoordScale.x * 0.5, 0.5 - texCoordScale.y * 0.5) - adjustedOffset
    let scaledBottomRight = simd_float2(0.5 + texCoordScale.x * 0.5, 0.5 - texCoordScale.y * 0.5) - adjustedOffset
    
    let topLeft: simd_float2
    let topRight: simd_float2
    let bottomLeft: simd_float2
    let bottomRight: simd_float2
    
    switch textureRotation {
    case .rotate0Degrees:
          topLeft = scaledTopLeft
          topRight = scaledTopRight
          bottomLeft = scaledBottomLeft
          bottomRight = scaledBottomRight
      case .rotate0DegreesMirrored:
          topLeft = scaledTopRight
          topRight = scaledTopLeft
          bottomLeft = scaledBottomRight
          bottomRight = scaledBottomLeft
      case .rotate180Degrees:
          topLeft = scaledBottomRight
          topRight = scaledBottomLeft
          bottomLeft = scaledTopRight
          bottomRight = scaledTopLeft
      case .rotate90Degrees:
          topLeft = scaledTopRight
          topRight = scaledBottomRight
          bottomLeft = scaledTopLeft
          bottomRight = scaledBottomLeft
      case .rotate90DegreesMirrored:
          topLeft = scaledBottomRight
          topRight = scaledTopRight
          bottomLeft = scaledBottomLeft
          bottomRight = scaledTopLeft
      case .rotate270Degrees:
          topLeft = scaledBottomLeft
          topRight = scaledTopLeft
          bottomLeft = scaledBottomRight
          bottomRight = scaledTopRight
    }
    
    let containerSize = CGSize(width: containerSize.width, height: containerSize.height)
    
    let centerX = Float(textureRect.midX - containerSize.width / 2.0)
    let centerY = Float(textureRect.midY - containerSize.height / 2.0)

    let halfWidth = Float(textureRect.width / 2.0)
    let halfHeight = Float(textureRect.height / 2.0)
    
    let angle = Float.pi
    let cosAngle = cos(angle)
    let sinAngle = sin(angle)

    return [
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topLeft,
            localPos: simd_float2(0.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) - (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) + (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: topRight,
            localPos: simd_float2(1.0, 0.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX + (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY + (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomLeft,
            localPos: simd_float2(0.0, 1.0)
        ),
        VertexData(
            pos: simd_float4(
                x: (centerX - (halfWidth * cosAngle) + (halfHeight * sinAngle)) / Float(containerSize.width) * 2.0,
                y: (centerY - (halfWidth * sinAngle) - (halfHeight * cosAngle)) / Float(containerSize.height) * 2.0,
                z: z,
                w: 1
            ),
            texCoord: bottomRight,
            localPos: simd_float2(1.0, 1.0)
        )
    ]
}

private func lookupSpringValue(_ t: CGFloat) -> CGFloat {
    let table: [(CGFloat, CGFloat)] = [
        (0.0, 0.0),
        (0.0625, 0.1123005598783493),
        (0.125, 0.31598418951034546),
        (0.1875, 0.5103585720062256),
        (0.25, 0.6650152802467346),
        (0.3125, 0.777747631072998),
        (0.375, 0.8557760119438171),
        (0.4375, 0.9079672694206238),
        (0.5, 0.942038357257843),
        (0.5625, 0.9638798832893372),
        (0.625, 0.9776856303215027),
        (0.6875, 0.9863143563270569),
        (0.75, 0.991658091545105),
        (0.8125, 0.9949421286582947),
        (0.875, 0.9969474077224731),
        (0.9375, 0.9981651306152344),
        (1.0, 1.0)
    ]
    
    for i in 0 ..< table.count - 2 {
        let lhs = table[i]
        let rhs = table[i + 1]
        
        if t >= lhs.0 && t <= rhs.0 {
            let fraction = (t - lhs.0) / (rhs.0 - lhs.0)
            let value = lhs.1 + fraction * (rhs.1 - lhs.1)
            return value
        }
    }
    return 1.0
}

private var transitionDuration = 0.5
private var apperanceDuration = 0.2
private var videoRemovalDuration: Double = 0.2

struct VideoEncodeParameters {
    var dimensions: simd_float2
    var roundness: simd_float1
    var alpha: simd_float1
    var isOpaque: simd_float1
    var empty: simd_float1 = 0.0
}

final class VideoFinishPass: RenderPass {
    private var cachedTexture: MTLTexture?
    
    var gradientPipelineState: MTLRenderPipelineState?
    
    var mainPipelineState: MTLRenderPipelineState?
    var mainTextureRotation: TextureRotation = .rotate0Degrees
    var additionalTextureRotation: TextureRotation = .rotate0Degrees
    
    var pixelFormat: MTLPixelFormat  {
        return .bgra8Unorm
    }
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        let mainDescriptor = MTLRenderPipelineDescriptor()
        mainDescriptor.vertexFunction = library.makeFunction(name: "defaultVertexShader")
        mainDescriptor.fragmentFunction = library.makeFunction(name: "dualFragmentShader")
        mainDescriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        mainDescriptor.colorAttachments[0].isBlendingEnabled = true
        mainDescriptor.colorAttachments[0].rgbBlendOperation = .add
        mainDescriptor.colorAttachments[0].alphaBlendOperation = .add
        mainDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        mainDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        mainDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        mainDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        let gradientDescriptor = MTLRenderPipelineDescriptor()
        gradientDescriptor.vertexFunction = library.makeFunction(name: "defaultVertexShader")
        gradientDescriptor.fragmentFunction = library.makeFunction(name: "gradientFragmentShader")
        gradientDescriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        gradientDescriptor.colorAttachments[0].isBlendingEnabled = true
        gradientDescriptor.colorAttachments[0].rgbBlendOperation = .add
        gradientDescriptor.colorAttachments[0].alphaBlendOperation = .add
        gradientDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gradientDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        gradientDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        gradientDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.mainPipelineState = try device.makeRenderPipelineState(descriptor: mainDescriptor)
            self.gradientPipelineState = try device.makeRenderPipelineState(descriptor: gradientDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func encodeVideo(
        using encoder: MTLRenderCommandEncoder,
        containerSize: CGSize,
        texture: MTLTexture,
        textureRotation: TextureRotation,
        rect: CGRect,
        scale: CGFloat,
        offset: CGPoint,
        zPosition: Float,
        device: MTLDevice
    ) {
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(texture, index: 1)
        
        let vertices = verticesData(
            size: CGSize(width: texture.width, height: texture.height),
            textureRotation: textureRotation,
            containerSize: containerSize,
            textureRect: rect,
            scale: simd_float1(scale),
            offset: simd_float2(Float(offset.x / scale), Float(-offset.y / scale)),
            z: zPosition
        )
        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        
        var parameters = VideoEncodeParameters(
            dimensions: simd_float2(Float(rect.size.width), Float(rect.size.height)),
            roundness: 0.0,
            alpha: 1.0,
            isOpaque: 1.0
        )
        encoder.setFragmentBytes(&parameters, length: MemoryLayout<VideoEncodeParameters>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    func encodeVideo(
        using encoder: MTLRenderCommandEncoder,
        containerSize: CGSize,
        texture: MTLTexture,
        textureRotation: TextureRotation,
        maskTexture: MTLTexture?,
        hasTransparency: Bool,
        position: VideoPosition,
        roundness: Float,
        alpha: Float,
        zPosition: Float,
        device: MTLDevice
    ) {
        encoder.setFragmentTexture(texture, index: 0)
        if let maskTexture {
            encoder.setFragmentTexture(maskTexture, index: 1)
        } else {
            encoder.setFragmentTexture(texture, index: 1)
        }
        
        let center = CGPoint(
            x: position.position.x - containerSize.width / 2.0,
            y: containerSize.height - position.position.y - containerSize.height / 2.0
        )
        
        let size = CGSize(
            width: position.size.width * position.scale * position.baseScale,
            height: position.size.height * position.scale * position.baseScale
        )
        
        let vertices = verticesData(
            textureRotation: textureRotation,
            containerSize: containerSize,
            position: center,
            size: size,
            rotation: position.rotation,
            mirror: position.mirroring,
            z: zPosition
        )
        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        
        var parameters = VideoEncodeParameters(
            dimensions: simd_float2(Float(size.width), Float(size.height)),
            roundness: roundness,
            alpha: alpha,
            isOpaque: maskTexture == nil ? 1.0 : 0.0
        )
        encoder.setFragmentBytes(&parameters, length: MemoryLayout<VideoEncodeParameters>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    private let canvasSize = CGSize(width: 1080.0, height: 1920.0)
    private var gradientColors = GradientColors(topColor: simd_float4(0.0, 0.0, 0.0, 0.0), bottomColor: simd_float4(0.0, 0.0, 0.0, 0.0))
    func update(values: MediaEditorValues, videoDuration: Double?, additionalVideoDuration: Double?) {
        let position = CGPoint(
            x: canvasSize.width / 2.0 + values.cropOffset.x,
            y: canvasSize.height / 2.0 + values.cropOffset.y
        )
        
        self.isStory = values.isStory || values.isSticker || values.isAvatar || values.isCover
        self.isSticker = values.gradientColors?.first?.alpha == 0.0
        self.coverDimensions = values.coverDimensions
        
        self.mainPosition = VideoFinishPass.VideoPosition(position: position, size: self.mainPosition.size, scale: values.cropScale, rotation: values.cropRotation, mirroring: values.cropMirroring, baseScale: self.mainPosition.baseScale)
            
        if let position = values.additionalVideoPosition, let scale = values.additionalVideoScale, let rotation = values.additionalVideoRotation {
            self.additionalPosition = VideoFinishPass.VideoPosition(position: position, size: CGSize(width: 1080.0 / 4.0, height: 1440.0 / 4.0), scale: scale, rotation: rotation, mirroring: false, baseScale: self.additionalPosition.baseScale)
        }
        if !values.additionalVideoPositionChanges.isEmpty {
            self.videoPositionChanges = values.additionalVideoPositionChanges
        }
        self.videoDuration = videoDuration
        self.additionalVideoDuration = additionalVideoDuration
        self.videoRange = values.videoTrimRange
        self.additionalVideoRange = values.additionalVideoTrimRange
        self.additionalVideoOffset = values.additionalVideoOffset
        
        if let gradientColors = values.gradientColors, let top = gradientColors.first, let bottom = gradientColors.last {
            let (topRed, topGreen, topBlue, topAlpha) = top.components
            let (bottomRed, bottomGreen, bottomBlue, bottomAlpha) = bottom.components
            
            self.gradientColors = GradientColors(
                topColor: simd_float4(Float(topRed), Float(topGreen), Float(topBlue), Float(topAlpha)),
                bottomColor: simd_float4(Float(bottomRed), Float(bottomGreen), Float(bottomBlue), Float(bottomAlpha))
            )
        }
    }
    
    private var mainPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1080.0, height: 1920.0),
        scale: 1.0,
        rotation: 0.0,
        mirroring: false,
        baseScale: 1.0
    )
    
    private var additionalPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1440.0, height: 1920.0),
        scale: 0.5,
        rotation: 0.0,
        mirroring: false,
        baseScale: 1.0
    )
    
    private var isStory = true
    private var isSticker = true
    private var coverDimensions: CGSize?
    private var videoPositionChanges: [VideoPositionChange] = []
    private var videoDuration: Double?
    private var additionalVideoDuration: Double?
    private var videoRange: Range<Double>?
    private var additionalVideoRange: Range<Double>?
    private var additionalVideoOffset: Double?
    
    enum VideoType {
        case main
        case additional
        case transition
    }
    
    struct VideoPosition {
        let position: CGPoint
        let size: CGSize
        let scale: CGFloat
        let rotation: CGFloat
        let mirroring: Bool
        let baseScale: CGFloat
        
        func with(size: CGSize, baseScale: CGFloat) -> VideoPosition {
            return VideoPosition(position: self.position, size: size, scale: self.scale, rotation: self.rotation, mirroring: self.mirroring, baseScale: baseScale)
        }
        
        func mixed(with other: VideoPosition, fraction: CGFloat) -> VideoPosition {
            let position = CGPoint(
                x: self.position.x + (other.position.x - self.position.x) * fraction,
                y: self.position.y + (other.position.y - self.position.y) * fraction
            )
            let size = CGSize(
                width: self.size.width + (other.size.width - self.size.width) * fraction,
                height: self.size.height + (other.size.height - self.size.height) * fraction
            )
            let scale = self.scale + (other.scale - self.scale) * fraction
            let rotation = self.rotation + (other.rotation - self.rotation) * fraction
            
            return VideoPosition(
                position: position,
                size: size,
                scale: scale,
                rotation: rotation,
                mirroring: self.mirroring,
                baseScale: self.baseScale
            )
        }
    }
    
    struct VideoState {
        let texture: MTLTexture
        let textureRotation: TextureRotation
        let position: VideoPosition
        let roundness: Float
        let alpha: Float
    }
    
    private var additionalVideoRemovalStartTimestamp: Double?
    func animateAdditionalRemoval(completion: @escaping () -> Void) {
        self.additionalVideoRemovalStartTimestamp = CACurrentMediaTime()
        
        Queue.mainQueue().after(videoRemovalDuration) {
            completion()
            self.additionalVideoRemovalStartTimestamp = nil
        }
    }
    
    func transitionState(for time: CMTime, mainInput: MTLTexture, additionalInput: MTLTexture?) -> (VideoState, VideoState?, VideoState?) {
        let timestamp = time.seconds
        
        var backgroundTexture = mainInput
        var backgroundTextureRotation = self.mainTextureRotation
        
        var foregroundTexture = additionalInput
        var foregroundTextureRotation = self.additionalTextureRotation
        
        var mainPosition = self.mainPosition
        var additionalPosition = self.additionalPosition
        var disappearingPosition = self.mainPosition
        
        var transitionFraction = 1.0
        if let additionalInput {
            var previousChange: VideoPositionChange?
            for change in self.videoPositionChanges {
                if timestamp >= change.timestamp {
                    previousChange = change
                }
                if timestamp < change.timestamp {
                    break
                }
            }
            
            if let previousChange {
                if previousChange.additional {
                    backgroundTexture = additionalInput
                    backgroundTextureRotation = self.additionalTextureRotation
                    
                    mainPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation, mirroring: mainPosition.mirroring, baseScale: mainPosition.baseScale)
                    additionalPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: 1080.0 / 4.0, height: 1920.0 / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation, mirroring: additionalPosition.mirroring, baseScale: additionalPosition.baseScale)
                    
                    foregroundTexture = mainInput
                    foregroundTextureRotation = self.mainTextureRotation
                } else {
                    disappearingPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation, mirroring: mainPosition.mirroring, baseScale: mainPosition.baseScale)
                }
                if previousChange.timestamp > 0.0 && timestamp < previousChange.timestamp + transitionDuration {
                    transitionFraction = (timestamp - previousChange.timestamp) / transitionDuration
                }
            }
        }
        
        var backgroundVideoState = VideoState(texture: backgroundTexture, textureRotation: backgroundTextureRotation, position: mainPosition, roundness: 0.0, alpha: 1.0)
        var foregroundVideoState: VideoState?
        var disappearingVideoState: VideoState?
        
        if let foregroundTexture {
            var foregroundPosition = additionalPosition
            var foregroundAlpha: Float = 1.0
            if transitionFraction < 1.0 {
                let springFraction = lookupSpringValue(transitionFraction)
                
                let appearingPosition = VideoPosition(position: additionalPosition.position, size: additionalPosition.size, scale: 0.01, rotation: self.additionalPosition.rotation, mirroring: self.additionalPosition.mirroring, baseScale: self.additionalPosition.baseScale)
                let backgroundInitialPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: mainPosition.size.width / 4.0, height: mainPosition.size.height / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation, mirroring: additionalPosition.mirroring, baseScale: additionalPosition.baseScale)
                
                foregroundPosition = appearingPosition.mixed(with: additionalPosition, fraction: springFraction)
                
                disappearingVideoState = VideoState(texture: foregroundTexture, textureRotation: foregroundTextureRotation, position: disappearingPosition, roundness: 0.0, alpha: 1.0)
                backgroundVideoState = VideoState(texture: backgroundTexture, textureRotation: backgroundTextureRotation, position: backgroundInitialPosition.mixed(with: mainPosition, fraction: springFraction), roundness: Float(1.0 - springFraction), alpha: 1.0)
                
                foregroundAlpha = min(1.0, max(0.0, Float(transitionFraction) * 2.5))
            }
            
            var isVisible = true
            var trimRangeLowerBound: Double?
            var trimRangeUpperBound: Double?
            if let additionalVideoRange = self.additionalVideoRange {
                if let additionalVideoOffset = self.additionalVideoOffset {
                    trimRangeLowerBound = additionalVideoRange.lowerBound - additionalVideoOffset
                    trimRangeUpperBound = additionalVideoRange.upperBound - additionalVideoOffset
                } else {
                    trimRangeLowerBound = additionalVideoRange.lowerBound
                    trimRangeUpperBound = additionalVideoRange.upperBound
                }
            } else if let additionalVideoOffset = self.additionalVideoOffset {
                trimRangeLowerBound = -additionalVideoOffset
                if let additionalVideoDuration = self.additionalVideoDuration {
                    trimRangeUpperBound = -additionalVideoOffset + additionalVideoDuration
                }
            }
            
            if (trimRangeLowerBound != nil || trimRangeUpperBound != nil), let _ = self.videoDuration {
                let disappearingPosition = VideoPosition(position: foregroundPosition.position, size: foregroundPosition.size, scale: 0.01, rotation: foregroundPosition.rotation, mirroring: foregroundPosition.mirroring, baseScale: foregroundPosition.baseScale)
                
                let mainLowerBound = self.videoRange?.lowerBound ?? 0.0
                
                if let trimRangeLowerBound, trimRangeLowerBound > mainLowerBound + 0.1, timestamp < trimRangeLowerBound + apperanceDuration {
                    let visibilityFraction = max(0.0, min(1.0, (timestamp - trimRangeLowerBound) / apperanceDuration))
                    if visibilityFraction.isZero {
                        isVisible = false
                    }
                    foregroundAlpha = Float(visibilityFraction)
                    foregroundPosition = disappearingPosition.mixed(with: foregroundPosition, fraction: visibilityFraction)
                } else if let trimRangeUpperBound, timestamp > trimRangeUpperBound - apperanceDuration {
                    let visibilityFraction = 1.0 - max(0.0, min(1.0, (timestamp - trimRangeUpperBound) / apperanceDuration))
                    if visibilityFraction.isZero {
                        isVisible = false
                    }
                    foregroundAlpha = Float(visibilityFraction)
                    foregroundPosition = disappearingPosition.mixed(with: foregroundPosition, fraction: visibilityFraction)
                }
            }
            
            if isVisible {
                if let additionalVideoRemovalStartTimestamp {
                    let disappearingPosition = VideoPosition(position: foregroundPosition.position, size: foregroundPosition.size, scale: 0.01, rotation: foregroundPosition.rotation, mirroring: foregroundPosition.mirroring, baseScale: foregroundPosition.baseScale)
                    
                    let visibilityFraction = max(0.0, min(1.0, 1.0 - (CACurrentMediaTime() - additionalVideoRemovalStartTimestamp) / videoRemovalDuration))
                    if visibilityFraction.isZero {
                        isVisible = false
                    }
                    foregroundAlpha = Float(visibilityFraction)
                    foregroundPosition = disappearingPosition.mixed(with: foregroundPosition, fraction: visibilityFraction)
                }
                foregroundVideoState = VideoState(texture: foregroundTexture, textureRotation: foregroundTextureRotation, position: foregroundPosition, roundness: 1.0, alpha: foregroundAlpha)
            }
        }
        
        return (backgroundVideoState, foregroundVideoState, disappearingVideoState)
    }
    
    struct Input {
        let texture: MTLTexture
        let hasTransparency: Bool
        let rect: CGRect?
        let scale: CGFloat
        let offset: CGPoint
    }
    
    func process(
        input: Input,
        inputMask: MTLTexture?,
        hasTransparency: Bool,
        secondInput: [Input],
        timestamp: CMTime,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer
    ) -> MTLTexture? {
        if !self.isStory {
            return input.texture
        }
        
        let baseScale: CGFloat
        if let dimensions = self.coverDimensions {
            let fittedCanvasDimensions = dimensions.aspectFitted(canvasSize)
            baseScale = max(fittedCanvasDimensions.width / CGFloat(input.texture.width), fittedCanvasDimensions.height / CGFloat(input.texture.height))
        } else if !self.isSticker {
            if input.texture.height > input.texture.width {
                baseScale = max(canvasSize.width / CGFloat(input.texture.width), canvasSize.height / CGFloat(input.texture.height))
            } else {
                baseScale = canvasSize.width / CGFloat(input.texture.width)
            }
        } else {
            if input.texture.height > input.texture.width {
                baseScale = canvasSize.width / CGFloat(input.texture.width)
            } else {
                baseScale = canvasSize.width / CGFloat(input.texture.height)
            }
        }
        self.mainPosition = self.mainPosition.with(size: CGSize(width: input.texture.width, height: input.texture.height), baseScale: baseScale)
        
        let containerSize = canvasSize
        
        if self.cachedTexture == nil {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.textureType = .type2D
            textureDescriptor.width = Int(containerSize.width)
            textureDescriptor.height = Int(containerSize.height)
            textureDescriptor.pixelFormat = input.texture.pixelFormat
            textureDescriptor.storageMode = .private
            textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
                return input.texture
            }
            self.cachedTexture = texture
            texture.label = "finishedTexture"
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        if self.gradientColors.topColor.w > 0.0 {
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        } else {
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
        }
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input.texture
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(containerSize.width), height: Double(containerSize.height),
            znear: -1.0, zfar: 1.0)
        )
        
        if self.gradientColors.topColor.w > 0.0 {
            self.encodeGradient(
                using: renderCommandEncoder,
                containerSize: containerSize,
                device: device
            )
        }
        
        renderCommandEncoder.setRenderPipelineState(self.mainPipelineState!)
        
        if let rect = input.rect {
            self.encodeVideo(
                using: renderCommandEncoder,
                containerSize: containerSize,
                texture: input.texture,
                textureRotation: self.mainTextureRotation,
                rect: rect,
                scale: input.scale,
                offset: input.offset,
                zPosition: 0.0,
                device: device
            )
            
            for input in secondInput {
                if let rect = input.rect {
                    self.encodeVideo(
                        using: renderCommandEncoder,
                        containerSize: containerSize,
                        texture: input.texture,
                        textureRotation: self.mainTextureRotation,
                        rect: rect,
                        scale: input.scale,
                        offset: input.offset,
                        zPosition: 0.0,
                        device: device
                    )
                }
            }
        } else {
            let (mainVideoState, additionalVideoState, transitionVideoState) = self.transitionState(for: timestamp, mainInput: input.texture, additionalInput: secondInput.first?.texture)
            
            if let transitionVideoState {
                self.encodeVideo(
                    using: renderCommandEncoder,
                    containerSize: containerSize,
                    texture: transitionVideoState.texture,
                    textureRotation: transitionVideoState.textureRotation,
                    maskTexture: nil,
                    hasTransparency: false,
                    position: transitionVideoState.position,
                    roundness: transitionVideoState.roundness,
                    alpha: transitionVideoState.alpha,
                    zPosition: 0.75,
                    device: device
                )
            }
            
            self.encodeVideo(
                using: renderCommandEncoder,
                containerSize: containerSize,
                texture: mainVideoState.texture,
                textureRotation: mainVideoState.textureRotation,
                maskTexture: inputMask,
                hasTransparency: hasTransparency,
                position: mainVideoState.position,
                roundness: mainVideoState.roundness,
                alpha: mainVideoState.alpha,
                zPosition: 0.0,
                device: device
            )
            
            if let additionalVideoState {
                self.encodeVideo(
                    using: renderCommandEncoder,
                    containerSize: containerSize,
                    texture: additionalVideoState.texture,
                    textureRotation: additionalVideoState.textureRotation,
                    maskTexture: nil,
                    hasTransparency: false,
                    position: additionalVideoState.position,
                    roundness: additionalVideoState.roundness,
                    alpha: additionalVideoState.alpha,
                    zPosition: 0.5,
                    device: device
                )
            }
        }
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
    
    struct GradientColors {
        var topColor: simd_float4
        var bottomColor: simd_float4
    }
    
    func encodeGradient(
        using encoder: MTLRenderCommandEncoder,
        containerSize: CGSize,
        device: MTLDevice
    ) {
        encoder.setRenderPipelineState(self.gradientPipelineState!)
        
        let vertices = verticesDataForRotation(.rotate0Degrees)
        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&self.gradientColors, length: MemoryLayout<GradientColors>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
}
