import Foundation
import Metal
import MetalEngine
import simd

private var metalLibraryValue: MTLLibrary?

func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }

    let mainBundle = Bundle(for: InteractiveDiamondLayer.self)
    guard let path = mainBundle.path(forResource: "PremiumDiamondComponentBundle", ofType: "bundle"),
          let bundle = Bundle(path: path),
          let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }

    metalLibraryValue = library
    return library
}

final class DiamondRenderer: ComputeState {
    struct StarUniforms {
        var projection: simd_float4x4
        var animation: SIMD4<Float>
        var layout: SIMD4<Float>
        var appearance: SIMD4<Float>
        var tint: SIMD4<Float>
    }
    struct Uniforms {
        var model: simd_float4x4
        var projection: simd_float4x4
        var inverseModel: simd_float4x4
        var parameters: SIMD4<Float>
        var viewport: SIMD4<Float>
        var sparkleShape: SIMD4<Float>
        var sparkleHalo: SIMD4<Float>
        var crownGradient: SIMD4<Float>
        var pavilionGradient: SIMD4<Float>
        var lightSweep: SIMD4<Float>
        var facetProjection: SIMD4<Float>
        var crownSweep: SIMD4<Float>
        var rightCrownSweep: SIMD4<Float>
        var leftCrownSweep: SIMD4<Float>
        var pavilionSweep: SIMD4<Float>
        var rightPavilionSweep: SIMD4<Float>
        var leftPavilionSweep: SIMD4<Float>
        var appearance: SIMD4<Float>
        var referenceCrownFlash: SIMD4<Float>
        var referencePavilionFlash: SIMD4<Float>
    }

    private struct LensUniforms {
        var rect: SIMD4<Float>
        var uv: SIMD4<Float>
        var viewport: SIMD4<Float> // pixel center, pixels per point, edge count
        var parameters: SIMD4<Float> // strength, yaw, radius in points, light background
        var center: SIMD4<Float> // projected stone center in points, preserves source colors, reserved
    }

    private struct Lens {
        let pipeline: MTLRenderPipelineState
        let texture: MTLTexture
        var uniforms: LensUniforms
        let edges: [SIMD4<Float>]
        let hull: [SIMD2<Float>]
    }

    enum Failure: LocalizedError {
        case unavailable, resource(String)
        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Metal unavailable"
            case .resource(let name):
                return "Metal resource failure: \(name)."
            }
        }
    }

    let device: MTLDevice
    let sampleCount: Int
    private let sdrPipelines: Pipelines
    private lazy var hdrPipelines: Pipelines? = try? Pipelines(device: self.device, sampleCount: self.sampleCount, pixelFormat: .rgba16Float)
    private let depthState: MTLDepthStencilState
    private let sparkleDepthState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let planeBuffer: MTLBuffer
    private let mainSparkleBuffer: MTLBuffer
    private let smallSparkleBuffer: MTLBuffer
    private let streakBuffer: MTLBuffer
    private let streakVertexCount: Int
    private let sparkleAnchorBuffer: MTLBuffer
    private let mainSparkleVertexCount: Int
    private let smallSparkleVertexCount: Int
    private let vertexCount: Int
    private let planeCount: Int
    private let geometry: DiamondGeometry
    private let facetProjection: SIMD4<Float>
    private lazy var referenceHighlights = DiamondSparkleGeometry.Reference(geometry: self.geometry)
    private lazy var whiteReferenceHighlights = DiamondSparkleGeometry.Reference(geometry: self.geometry, appearance: .white)
    private let silhouette: DiamondSilhouette
    private let lensVertices: [SIMD4<Float>]

    // Geometry is shared; the extra pipeline set is created only for the first HDR expansion.
    private final class Pipelines {
        let device: MTLDevice
        let library: MTLLibrary
        let sampleCount: Int
        let pixelFormat: MTLPixelFormat
        let stone: MTLRenderPipelineState
        let sparkle: MTLRenderPipelineState
        let referenceHighlight: MTLRenderPipelineState

        lazy var stars = try? self.make(vertex: "backgroundStarVertex", fragment: "backgroundStarFragment", blending: true)
        lazy var glass = try? self.make(vertex: "diamondVertex", fragment: "diamondFragment", blending: true)
        lazy var lens = try? self.make(vertex: "diamondVertex", fragment: "diamondLensFragment", blending: true)

        init(device: MTLDevice, sampleCount: Int, pixelFormat: MTLPixelFormat) throws {
            guard let library = metalLibrary(device: device) else {
                throw Failure.resource("PremiumDiamondComponentBundle/default.metallib")
            }
            self.device = device
            self.library = library
            self.sampleCount = sampleCount
            self.pixelFormat = pixelFormat
            func make(vertex: String, fragment: String, blending: Bool) throws -> MTLRenderPipelineState {
                return try DiamondRenderer.makePipeline(device: device, library: library, sampleCount: sampleCount,
                    pixelFormat: pixelFormat, vertex: vertex, fragment: fragment, blending: blending)
            }
            self.stone = try make(vertex: "diamondVertex", fragment: "diamondFragment", blending: false)
            self.sparkle = try make(vertex: "sparkleVertex", fragment: "sparkleFragment", blending: true)
            self.referenceHighlight = try make(vertex: "referenceHighlightVertex", fragment: "sparkleFragment", blending: true)
        }

        private func make(vertex: String, fragment: String, blending: Bool) throws -> MTLRenderPipelineState {
            return try DiamondRenderer.makePipeline(device: self.device, library: self.library, sampleCount: self.sampleCount,
                pixelFormat: self.pixelFormat, vertex: vertex, fragment: fragment, blending: blending)
        }
    }

    required convenience init?(device: MTLDevice) {
        do {
            try self.init(device: device, sampleCount: device.supportsTextureSampleCount(4) ? 4 : 1)
        } catch {
            return nil
        }
    }

    private init(device: MTLDevice, sampleCount: Int) throws {
        self.device = device
        self.sampleCount = sampleCount
        let cachedData = DiamondRenderData.load()
        let renderData: DiamondRenderData
        if let cachedData {
            renderData = cachedData
        } else {
            renderData = DiamondRenderData()
            renderData.store()
        }
        let geometry = renderData.geometry
        self.geometry = geometry
        self.facetProjection = renderData.facetProjection
        self.silhouette = renderData.silhouette
        self.lensVertices = renderData.lensVertices
        vertexCount = geometry.vertices.count
        planeCount = geometry.planes.count
        guard let vb = geometry.vertices.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }), let pb = geometry.planes.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw Failure.resource("geometry") }
        vertexBuffer = vb
        planeBuffer = pb
        vertexBuffer.label = "GramDiamond • bevelled cut"
        planeBuffer.label = "GramDiamond • optical hull"
        let sparkles = renderData.sparkles
        mainSparkleVertexCount = sparkles.main.count
        smallSparkleVertexCount = sparkles.small.count
        streakVertexCount = sparkles.streakVertices.count
        guard let main = sparkles.main.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }), let small = sparkles.small.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }), let streaks = sparkles.streakVertices.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw Failure.resource("sparkle contours") }
        mainSparkleBuffer = main
        smallSparkleBuffer = small
        streakBuffer = streaks
        let anchors = renderData.anchors
        guard let anchorBuffer = anchors.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw Failure.resource("sparkle anchors") }
        sparkleAnchorBuffer = anchorBuffer

        self.sdrPipelines = try Pipelines(device: device, sampleCount: sampleCount, pixelFormat: .bgra8Unorm)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let ds = device.makeDepthStencilState(descriptor: depth) else { throw Failure.resource("depth") }
        depthState = ds
        depth.isDepthWriteEnabled = false
        depth.depthCompareFunction = .always
        guard let ss = device.makeDepthStencilState(descriptor: depth) else { throw Failure.resource("sparkle depth") }
        sparkleDepthState = ss
    }

    private static func makePipeline(device: MTLDevice, library: MTLLibrary, sampleCount: Int, pixelFormat: MTLPixelFormat,
                                     vertex: String, fragment: String, blending: Bool) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "GramDiamond • \(fragment)"
        guard let vertexFunction = library.makeFunction(name: vertex),
              let fragmentFunction = library.makeFunction(name: fragment) else {
            throw Failure.resource("\(vertex) / \(fragment)")
        }
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.rasterSampleCount = sampleCount
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        if blending {
            let attachment = descriptor.colorAttachments[0]!
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: descriptor) else {
            throw Failure.resource("pipeline \(vertex) / \(fragment)")
        }
        return pipelineState
    }

    private func lens(source: InteractiveDiamondComponent.RefractionSource?, strength: Float, yaw: Float, pipeline: MTLRenderPipelineState?,
                      uniforms: Uniforms, pixelsPerPoint: Float, lightBackground: Bool) -> Lens? {
        guard let source, let pipeline else { return nil }
        // Prepare once when the field supplies its glyph, before the first press.
        let vertices = self.lensVertices
        guard strength > 0.001, !source.rect.isEmpty, pixelsPerPoint > 0 else { return nil }
        let halfSize = SIMD2(uniforms.viewport.x, uniforms.viewport.y) / (2 * pixelsPerPoint)
        let transform = uniforms.projection * uniforms.model
        func project(_ vertex: SIMD4<Float>) -> SIMD2<Float> {
            let p = transform * vertex
            return SIMD2(p.x, -p.y) / p.w * halfSize
        }
        // Project the origin rather than using the hull's centroid, which changes with rotation.
        let center = project(SIMD4(0, 0, 0, 1))
        var points = vertices.map { center + (project($0) - center) * 0.96 }
        let radius = points.reduce(Float(0)) { max($0, simd_length($1 - center)) }
        points.sort { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        func cross(_ origin: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            return (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
        }
        var lower: [SIMD2<Float>] = []
        var upper: [SIMD2<Float>] = []
        for point in points {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        for point in points.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        var hull = Array(lower.dropLast())
        hull.append(contentsOf: upper.dropLast())
        guard hull.count >= 3 else { return nil }
        // Bound both the fragment loop and the inline Metal buffer size.
        if hull.count > 128 {
            hull = (0 ..< 128).map { hull[$0 * hull.count / 128] }
        }
        var edges: [SIMD4<Float>] = []
        edges.reserveCapacity(hull.count)
        for i in hull.indices {
            let a = hull[i], b = hull[(i + 1) % hull.count]
            let d = b - a
            let normal = SIMD2(-d.y, d.x) / max(simd_length(d), 0.0001)
            edges.append(SIMD4(normal.x, normal.y, -simd_dot(normal, a), 0))
        }
        let rect = source.rect
        return Lens(pipeline: pipeline, texture: source.texture,
            uniforms: LensUniforms(
                rect: SIMD4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height)),
                uv: source.uv,
                viewport: SIMD4(uniforms.viewport.x * 0.5, uniforms.viewport.y * 0.5, pixelsPerPoint, Float(edges.count)),
                parameters: SIMD4(min(1, strength), yaw, radius, lightBackground ? 1 : 0),
                center: SIMD4(center.x, center.y, source.preservesColors ? 1 : 0, 0)),
            edges: edges, hull: hull)
    }

    private func uniforms(size: CGSize, time: Float, motion: DiamondMotion, style: DiamondStyle,
                          grow: Float, pixelsPerPoint: Float, reduceMotion: Bool, heldProgress: Float, highlightBoost: Float) -> Uniforms {
        let model = DiamondMath.rotation(x: motion.pitch, y: motion.renderedYaw)
        let horizontalScale: Float = style.widthCompensation
            ? silhouette.horizontalScale(yaw: motion.renderedYaw, pitch: motion.pitch) : 1
        let zoom: Float
        if style.widthPoints > 0 && size.width > 0 && size.height > 0 {
            let aspect = Float(size.width / size.height)
            let base = style.widthPoints * pixelsPerPoint * 1.52 * max(aspect, 1) / Float(size.width)
            zoom = min(2.4, max(0.05, motion.zoom * base * grow))
        } else if style.dragGrow != 1 || grow != 1 {
            zoom = min(2.4, max(0.05, motion.zoom * style.zoom * grow))
        } else {
            zoom = min(1.6, max(0.6, motion.zoom * style.zoom))
        }
        var projection = DiamondMath.projection(aspect: Float(size.width / max(size.height, 1)),
                                               zoom: zoom)
        projection.columns.0.x *= horizontalScale
        var shift = style.growShift * (grow - 1) + style.verticalOffset
        if style.floatAmplitude != 0 && style.floatPeriod > 0 && !reduceMotion {
            shift += style.floatAmplitude * sin(2 * .pi * time / style.floatPeriod) * (1 - heldProgress)
        }
        if shift != 0 && size.height > 0 {
            let dy = -2 * shift * pixelsPerPoint / Float(size.height)
            projection.columns.0.y += dy * projection.columns.0.w
            projection.columns.1.y += dy * projection.columns.1.w
            projection.columns.2.y += dy * projection.columns.2.w
            projection.columns.3.y += dy * projection.columns.3.w
        }
        let animationTime = reduceMotion ? 0 : DiamondEntrance.highlightTime(
            at: time, entrance: style.animationMode == .entrance)
        let sparkle: DiamondSparkleAnimation.State
        let mainSparkle: DiamondSparkleAnimation.MainPlacement
        if style.mainSparkleOnRotation {
            sparkle = motion.rotationSparkle.state
            mainSparkle = DiamondSparkleAnimation.mainPlacement(model: model, rotationTriggered: true)
        } else {
            sparkle = DiamondSparkleAnimation.state(time: animationTime, appearance: style.appearance)
            let lookAhead: Float = 1 / 120
            var nextMotion = motion
            nextMotion.step(dt: lookAhead, speed: style.isRotating ? style.rotationSpeed : 0,
                            reduceMotion: reduceMotion, mode: style.animationMode, time: time + lookAhead, appearance: style.appearance)
            let yawDelta = atan2(sin(nextMotion.yaw - motion.yaw), cos(nextMotion.yaw - motion.yaw))
            let angularSpeed = simd_length(SIMD2(yawDelta, nextMotion.pitch - motion.pitch)) / lookAhead
            mainSparkle = DiamondSparkleAnimation.mainPlacement(model: model, angularSpeed: angularSpeed)
        }
        let light = DiamondLightAnimation.state(time: animationTime)
        let flashes = style.appearance == .white && style.animationMode == .reference && style.sparkles && !reduceMotion
            ? DiamondReferenceHighlights.facetFlashes(at: animationTime) : (.zero, .zero)
        return Uniforms(model: model,
                        projection: projection,
                        inverseModel: model.transpose,
                        parameters: SIMD4(animationTime, min(1, max(0, style.refraction)), max(0, style.brightness),
                                          style.sparkles && !reduceMotion ? 1 : 0),
                        viewport: SIMD4(Float(size.width), Float(size.height), Float(planeCount), 0),
                        sparkleShape: sparkle.shape,
                        sparkleHalo: SIMD4(sparkle.haloScale, mainSparkle.faceRotation,
                                          horizontalScale, mainSparkle.visibility),
                        crownGradient: light.crown, pavilionGradient: light.pavilion, lightSweep: light.sweep,
                        facetProjection: facetProjection,
                        crownSweep: light.crownSweep, rightCrownSweep: light.rightCrownSweep,
                        leftCrownSweep: light.leftCrownSweep, pavilionSweep: light.pavilionSweep,
                        rightPavilionSweep: light.rightPavilionSweep, leftPavilionSweep: light.leftPavilionSweep,
                        appearance: SIMD4(Float(style.appearance.rawValue), min(1, max(0, style.whiten)), max(0, highlightBoost), 0),
                        referenceCrownFlash: flashes.0, referencePavilionFlash: flashes.1)
    }

    func encode(encoder: MTLRenderCommandEncoder, size: CGSize, time: Float, starBursts: [DiamondStarBurst], starOffset: CGPoint, motion: DiamondMotion, style: DiamondStyle, grow: Float, pixelsPerPoint: Float, reduceMotion: Bool, lightBackground: Bool, refractionSource: InteractiveDiamondComponent.RefractionSource?, refractionStrength: Float, highlightBoost: Float, colorPixelFormat: MTLPixelFormat, refractionUpdated: ((InteractiveDiamondComponent.RefractionGeometry?) -> Void)? = nil) {
        guard let pipelines = colorPixelFormat == .rgba16Float ? self.hdrPipelines : self.sdrPipelines else { return }
        let sparklePipeline = pipelines.sparkle
        let referenceHighlightPipeline = pipelines.referenceHighlight
        var u = uniforms(size: size, time: time, motion: motion, style: style, grow: grow, pixelsPerPoint: pixelsPerPoint,
            reduceMotion: reduceMotion, heldProgress: refractionStrength, highlightBoost: highlightBoost)
        let lens = self.lens(source: refractionSource, strength: refractionStrength, yaw: motion.renderedYaw,
            pipeline: refractionSource == nil ? nil : pipelines.lens, uniforms: u, pixelsPerPoint: pixelsPerPoint, lightBackground: lightBackground)
        if let refractionUpdated {
            refractionUpdated(lens.map { lens in
                InteractiveDiamondComponent.RefractionGeometry(
                    center: CGPoint(x: CGFloat(lens.uniforms.center.x), y: CGFloat(lens.uniforms.center.y)),
                    hull: lens.hull.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) },
                    strength: CGFloat(refractionStrength), rotation: motion.renderedYaw
                )
            })
        }
        let stonePipeline: MTLRenderPipelineState
        if let lens {
            stonePipeline = lens.pipeline
        } else if style.whiten > 0, let glassPipeline = pipelines.glass {
            stonePipeline = glassPipeline
        } else {
            stonePipeline = pipelines.stone
            u.appearance.y = 0
        }
        if style.backgroundStars && style.starOpacity > 0.001 && !reduceMotion, let starPipeline = pipelines.stars {
            let entrance = style.animationMode == .entrance
            // A larger render target reveals more flight without scaling particles or their trajectories.
            let starZoomScale = style.starReferenceSize > 0
                ? style.starReferenceSize * pixelsPerPoint / Float(max(1, min(size.width, size.height)))
                : 1.0
            var stars = StarUniforms(
                projection: DiamondMath.projection(aspect: Float(size.width/max(size.height,1)), zoom: max(0.2, style.starZoom) * starZoomScale, perspective: false),
                animation: SIMD4(0, DiamondEntrance.particleTime(at:time,entrance:entrance),
                                 0, lightBackground ? 1 : 0),
                layout: SIMD4(Float(size.width),Float(size.height),Float(DiamondEntrance.steadyStarCount),0),
                appearance: u.appearance,
                tint: SIMD4(1, min(1, max(0, style.starOpacity)), max(0.05, style.starEmission), max(0.001, style.burstFadeInDuration)))
            stars.appearance.w = style.rightwardStars ? 1 : 0
            stars.projection.columns.3.x += 2 * Float(starOffset.x) * pixelsPerPoint / Float(size.width)
            stars.projection.columns.3.y -= 2 * (style.verticalOffset + Float(starOffset.y)) * pixelsPerPoint / Float(size.height)
            encoder.setCullMode(.none)
            encoder.setDepthStencilState(sparkleDepthState)
            encoder.setRenderPipelineState(starPipeline)
            if style.steadyStars {
                encoder.setVertexBytes(&stars,length:MemoryLayout<StarUniforms>.stride,index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,
                    instanceCount:DiamondEntrance.steadyStarCount)
            }
            for burst in starBursts where time >= burst.startTime && time - burst.startTime < DiamondStarBurst.lifetime {
                var burstStars = stars
                if burst.isFromTap {
                    // Tap bursts keep their flight and brightness if a transfer finishes meanwhile.
                    burstStars.projection = DiamondMath.projection(aspect: Float(size.width/max(size.height,1)), zoom: starZoomScale, perspective: false)
                    burstStars.projection.columns.3.x = stars.projection.columns.3.x
                    burstStars.projection.columns.3.y = stars.projection.columns.3.y
                    burstStars.tint.x = 1.6
                    burstStars.tint.z = 0.5
                    burstStars.tint.w = 0.03
                }
                burstStars.animation.x = time - burst.startTime
                burstStars.animation.z = 1
                burstStars.layout.w = Float(burst.seed)
                encoder.setVertexBytes(&burstStars,length:MemoryLayout<StarUniforms>.stride,index:0)
                let count = Int(Float(DiamondEntrance.burstStarCount) * (burst.isFromTap ? 1 : min(1, max(0, style.burstSize))))
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,
                    instanceCount:max(count, 1),baseInstance:DiamondEntrance.steadyStarCount)
            }
        }
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        encoder.setRenderPipelineState(stonePipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setVertexBuffer(planeBuffer, offset: 0, index: 2)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBuffer(planeBuffer, offset: 0, index: 2)
        if var lens {
            encoder.setFragmentBytes(&lens.uniforms, length: MemoryLayout<LensUniforms>.stride, index: 3)
            lens.edges.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    encoder.setFragmentBytes(base, length: buffer.count * MemoryLayout<SIMD4<Float>>.stride, index: 4)
                }
            }
            encoder.setFragmentTexture(lens.texture, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        if style.sparkles && !reduceMotion {
            encoder.setCullMode(.none)
            encoder.setRenderPipelineState(sparklePipeline)
            encoder.setDepthStencilState(sparkleDepthState)
            encoder.setVertexBuffer(sparkleAnchorBuffer, offset: 0, index: 3)
            encoder.setVertexBuffer(mainSparkleBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mainSparkleVertexCount)
            if style.animationMode == .reference {
                encoder.setRenderPipelineState(referenceHighlightPipeline)
                func draw(_ instances: [DiamondSparkleGeometry.HighlightInstance], buffer: MTLBuffer, vertexCount: Int) {
                    guard !instances.isEmpty else { return }
                    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                    instances.withUnsafeBytes { bytes in
                        encoder.setVertexBytes(bytes.baseAddress!, length: bytes.count, index: 3)
                    }
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount,
                                           instanceCount: instances.count)
                }
                let highlights = style.appearance == .white ? whiteReferenceHighlights : referenceHighlights
                draw(highlights.smallInstances(at: time), buffer: smallSparkleBuffer, vertexCount: smallSparkleVertexCount)
                draw(highlights.streakInstances(at: time), buffer: streakBuffer, vertexCount: streakVertexCount)
            } else {
                encoder.setVertexBuffer(smallSparkleBuffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: smallSparkleVertexCount,
                                       instanceCount: 7, baseInstance: 1)
            }
        }
    }
}
