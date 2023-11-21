import Foundation
import AVFoundation
import Metal
import MetalKit

private func verticesData(
    textureRotation: TextureRotation,
    containerSize: CGSize,
    position: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    z: Float = 0.0
) -> [VertexData] {
    let topLeft: simd_float2
    let topRight: simd_float2
    let bottomLeft: simd_float2
    let bottomRight: simd_float2
    
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

final class VideoFinishPass: RenderPass {
    private var cachedTexture: MTLTexture?
    
    var mainPipelineState: MTLRenderPipelineState?
    var mainVerticesBuffer: MTLBuffer?
    var mainTextureRotation: TextureRotation = .rotate0Degrees
    
    var additionalVerticesBuffer: MTLBuffer?
    var additionalTextureRotation: TextureRotation = .rotate0Degrees
    
    var pixelFormat: MTLPixelFormat  {
        return .bgra8Unorm
    }
    
    func setup(device: MTLDevice, library: MTLLibrary) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "defaultVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "dualFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = self.pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            self.mainPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func encodeVideo(
        using encoder: MTLRenderCommandEncoder,
        containerSize: CGSize,
        texture: MTLTexture,
        textureRotation: TextureRotation,
        position: VideoPosition,
        roundness: Float,
        alpha: Float,
        zPosition: Float,
        device: MTLDevice
    ) {
        encoder.setFragmentTexture(texture, index: 0)
        
        let center = CGPoint(
            x: position.position.x - containerSize.width / 2.0,
            y: containerSize.height - position.position.y - containerSize.height / 2.0
        )
        
        let size = CGSize(
            width: position.size.width * position.scale,
            height: position.size.height * position.scale
        )
        
        let vertices = verticesData(textureRotation: textureRotation, containerSize: containerSize, position: center, size: size, rotation: position.rotation, z: zPosition)
        let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<VertexData>.stride * vertices.count,
            options: [])
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        
        var resolution = simd_uint2(UInt32(size.width), UInt32(size.height))
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<simd_uint2>.size * 2, index: 0)
        
        var roundness = roundness
        encoder.setFragmentBytes(&roundness, length: MemoryLayout<simd_float1>.size, index: 1)
        
        var alpha = alpha
        encoder.setFragmentBytes(&alpha, length: MemoryLayout<simd_float1>.size, index: 2)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    func update(values: MediaEditorValues) {
        if let position = values.additionalVideoPosition, let scale = values.additionalVideoScale, let rotation = values.additionalVideoRotation {
            self.additionalPosition = VideoFinishPass.VideoPosition(position: position, size: CGSize(width: 1080.0 / 4.0, height: 1440.0 / 4.0), scale: scale, rotation: rotation)
        }
        if !values.additionalVideoPositionChanges.isEmpty {
            self.videoPositionChanges = values.additionalVideoPositionChanges
        }
        if let additionalVideoTrimRange = values.additionalVideoTrimRange {
            self.additionalVideoRange = additionalVideoTrimRange
        }
        if let additionalVideoOffset = values.additionalVideoOffset {
            self.additionalVideoOffset = additionalVideoOffset
        }
    }
    
    private var mainPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1080.0, height: 1920.0),
        scale: 1.0,
        rotation: 0.0
    )
    
    private var additionalPosition = VideoPosition(
        position: CGPoint(x: 1080 / 2.0, y: 1920.0 / 2.0),
        size: CGSize(width: 1440.0, height: 1920.0),
        scale: 0.5,
        rotation: 0.0
    )
    
    private var transitionDuration = 0.5
    private var apperanceDuration = 0.2
    private var videoPositionChanges: [VideoPositionChange] = []
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
                rotation: rotation
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
                    
                    mainPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation)
                    additionalPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: 1080.0 / 4.0, height: 1920.0 / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation)
                    
                    foregroundTexture = mainInput
                    foregroundTextureRotation = self.mainTextureRotation
                } else {
                    disappearingPosition = VideoPosition(position: mainPosition.position, size: CGSize(width: 1440.0, height: 1920.0), scale: mainPosition.scale, rotation: mainPosition.rotation)
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
                
                let appearingPosition = VideoPosition(position: additionalPosition.position, size: additionalPosition.size, scale: 0.01, rotation: self.additionalPosition.rotation)
                let backgroundInitialPosition = VideoPosition(position: additionalPosition.position, size: CGSize(width: mainPosition.size.width / 4.0, height: mainPosition.size.height / 4.0), scale: additionalPosition.scale, rotation: additionalPosition.rotation)
                
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
            }
            
            if trimRangeLowerBound != nil || trimRangeUpperBound != nil {
                let disappearingPosition = VideoPosition(position: foregroundPosition.position, size: foregroundPosition.size, scale: 0.01, rotation: foregroundPosition.rotation)
                if let trimRangeLowerBound, trimRangeLowerBound > 0.0, timestamp < trimRangeLowerBound + apperanceDuration {
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
                foregroundVideoState = VideoState(texture: foregroundTexture, textureRotation: foregroundTextureRotation, position: foregroundPosition, roundness: 1.0, alpha: foregroundAlpha)
            }
        }
        
        return (backgroundVideoState, foregroundVideoState, disappearingVideoState)
    }
    
    func process(input: MTLTexture, secondInput: MTLTexture?, timestamp: CMTime, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard max(input.width, input.height) > 1920 || secondInput != nil else {
            return input
        }
        
        let scaledSize = CGSize(width: input.width, height: input.height).fitted(CGSize(width: 1920.0, height: 1920.0))
        let width: Int
        let height: Int
        
        if secondInput != nil {
            width = 1080
            height = 1920
        } else {
            width = Int(scaledSize.width)
            height = Int(scaledSize.height)
        }
        self.mainPosition = VideoPosition(position: CGPoint(x: width / 2, y: height / 2), size: CGSize(width: width, height: height), scale: 1.0, rotation: 0.0)
        
        let containerSize = CGSize(width: width, height: height)
        
        if self.cachedTexture == nil || self.cachedTexture?.width != width || self.cachedTexture?.height != height {
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
            texture.label = "scaledVideoTexture"
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = self.cachedTexture!
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return input
        }
        
        renderCommandEncoder.setViewport(MTLViewport(
            originX: 0, originY: 0,
            width: Double(width), height: Double(height),
            znear: -1.0, zfar: 1.0)
        )
        
        renderCommandEncoder.setRenderPipelineState(self.mainPipelineState!)
        
        let (mainVideoState, additionalVideoState, transitionVideoState) = self.transitionState(for: timestamp, mainInput: input, additionalInput: secondInput)
        
        if let transitionVideoState {
            self.encodeVideo(
                using: renderCommandEncoder,
                containerSize: containerSize,
                texture: transitionVideoState.texture,
                textureRotation: transitionVideoState.textureRotation,
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
                position: additionalVideoState.position,
                roundness: additionalVideoState.roundness,
                alpha: additionalVideoState.alpha,
                zPosition: 0.5,
                device: device
            )
        }
        
        renderCommandEncoder.endEncoding()
        
        return self.cachedTexture!
    }
    
    func process(input: MTLTexture, device: MTLDevice, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        return nil
    }
}
