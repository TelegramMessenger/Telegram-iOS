import Foundation
import UIKit
import Metal
import Display
import MetalEngine
import QrCode

final class QrStudioAshLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?

    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        init?(device: MTLDevice) {
            guard let library = qrStudioMetalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "qrAshVertex"), let fragmentFunction = library.makeFunction(name: "qrAshFragment") else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    static let margin: CGFloat = 150.0
    private static let tail: Double = 0.9

    private var particleBuffer: SharedBuffer?
    private var particleCount: Int = 0
    private var uniforms: [Float] = Array(repeating: 0.0, count: 20)
    private var startedAt: Double?
    private var isActive = false

    override init() {
        super.init()

        self.isOpaque = false
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start(matrix: QrCodeMatrix, side: CGFloat, ink: QrStudioColor, at time: Double) {
        let size = matrix.size
        let unit = side / CGFloat(max(1, size))

        var particles: [Float] = []
        particles.reserveCapacity(size * size * 2 * 4)
        for y in 0 ..< size {
            let centerY = (CGFloat(y) + 0.5) * unit
            let born = Float(QrStudioSweep.time(at: centerY - QrStudioSweep.depth * 0.5, side: side))
            for x in 0 ..< size where matrix[x, y] && !QrStudioCodePaths.isInLogo(x: x, y: y, size: size) {
                let key = Int32(truncatingIfNeeded: y &* 977 &+ x)
                let count = 3 + Int(QrStudioSweep.hash(key, 1) * 2.99)
                for j in 0 ..< count {
                    particles.append(Float(x))
                    particles.append(Float(y))
                    particles.append(born)
                    particles.append(Float(y * 977 + x) * 0.37 + Float(j) * 0.618)
                }
            }
        }
        self.particleCount = particles.count / 4
        guard self.particleCount > 0, let buffer = MetalEngine.shared.sharedBuffer(spec: BufferSpec(length: particles.count * MemoryLayout<Float>.size)) else {
            self.particleCount = 0
            return
        }
        particles.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                memcpy(buffer.buffer.contents(), baseAddress, bytes.count)
            }
        }
        self.particleBuffer = buffer

        let pastel = ink.pastel
        self.uniforms[0] = Float(self.bounds.width)
        self.uniforms[1] = Float(self.bounds.height)
        self.uniforms[2] = Float(QrStudioAshLayer.margin)
        self.uniforms[3] = Float(QrStudioAshLayer.margin)
        self.uniforms[4] = Float(unit)
        self.uniforms[6] = Float(side)
        let tones: [QrStudioColor] = [QrStudioColor(1.0, 1.0, 1.0), pastel, ink]
        for i in 0 ..< 3 {
            self.uniforms[8 + i * 4 + 0] = Float(tones[i].r)
            self.uniforms[8 + i * 4 + 1] = Float(tones[i].g)
            self.uniforms[8 + i * 4 + 2] = Float(tones[i].b)
            self.uniforms[8 + i * 4 + 3] = 1.0
        }
        self.startedAt = time
        self.isActive = true
    }

    func tick(time: Double) {
        guard self.isActive, let startedAt = self.startedAt else {
            return
        }
        let since = time - startedAt
        if since > QrStudioSweep.transition + QrStudioAshLayer.tail {
            self.isActive = false
            self.particleBuffer = nil
            self.particleCount = 0
            self.releaseSurface()
            return
        }
        self.uniforms[5] = Float(since)
        self.uniforms[7] = Float(max(0.0, 1.0 - since / QrStudioSweep.transition))
        self.setNeedsUpdate()
    }

    var isRunning: Bool {
        return self.isActive
    }

    func update(context: MetalEngineSubjectContext) {
        guard self.isActive, let particleBuffer = self.particleBuffer, self.particleCount > 0, self.bounds.width > 0.0 else {
            return
        }
        let uniforms = self.uniforms
        let particleCount = self.particleCount
        let spec = RenderLayerSpec(size: RenderSize(width: Int(self.bounds.width * UIScreenScale), height: Int(self.bounds.height * UIScreenScale)))
        context.renderToLayer(spec: spec, state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            var uniforms = uniforms
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Float>.size * 20, index: 1)
            encoder.setVertexBuffer(particleBuffer.buffer, offset: 0, index: 2)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
        })
    }
}
