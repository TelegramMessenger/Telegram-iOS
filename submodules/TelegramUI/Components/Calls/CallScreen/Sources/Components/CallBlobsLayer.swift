import Foundation
import MetalKit
import MetalEngine
import Display

final class CallBlobsLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?
    
    struct Blob {
        var points: [Float]
        var nextPoints: [Float]
        
        init(count: Int) {
            self.points = (0 ..< count).map { _ in
                Float.random(in: 0.0 ... 1.0)
            }
            self.nextPoints = (0 ..< count).map { _ in
                Float.random(in: 0.0 ... 1.0)
            }
        }
        
        func interpolate(at t: Float) -> [Float] {
            var points: [Float] = Array(repeating: 0.0, count: self.points.count)
            for i in 0 ..< self.points.count {
                points[i] = interpolateFloat(self.points[i], self.nextPoints[i], at: t)
            }
            return points
        }
        
        mutating func advance() {
            self.points = self.nextPoints
            self.nextPoints = (0 ..< self.points.count).map { _ in
                Float.random(in: 0.0 ... 1.0)
            }
        }
    }
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "callBlobVertex"), let fragmentFunction = library.makeFunction(name: "callBlobFragment") else {
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
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    private var phase: Float = 0.0
    
    private var blobs: [Blob] = []
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    
    override init() {
        super.init()
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(30), { [weak self] deltaTime in
                guard let self else {
                    return
                }
                self.phase += 3.0 * Float(deltaTime)
                if self.phase >= 1.0 {
                    for i in 0 ..< self.blobs.count {
                        self.blobs[i].advance()
                    }
                }
                self.phase = self.phase.truncatingRemainder(dividingBy: 1.0)
                self.setNeedsUpdate()
            })
        }
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = nil
        }
        
        self.isOpaque = false
        self.blobs = (0 ..< 2).map { _ in
            Blob(count: 8)
        }
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(context: MetalEngineSubjectContext) {
        if self.bounds.isEmpty {
            return
        }
        
        let phase = self.phase
        let blobs = self.blobs
        
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: Int(self.bounds.width * 3.0), height: Int(self.bounds.height * 3.0)), edgeInset: 4), state: RenderState.self, layer: self, commands: { encoder, placement in
            let rect = placement.effectiveRect
            
            for i in 0 ..< blobs.count {
                var points = blobs[i].interpolate(at: phase)
                var count: Int32 = Int32(points.count)
                
                let insetFraction: CGFloat = CGFloat(i) * 0.1
                
                let blobRect = rect.insetBy(dx: insetFraction * 0.5 * rect.width, dy: insetFraction * 0.5 * rect.height)
                var rect = SIMD4<Float>(Float(blobRect.minX), Float(blobRect.minY), Float(blobRect.width), Float(blobRect.height))
                
                encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
                encoder.setVertexBytes(&points, length: MemoryLayout<Float>.size * points.count, index: 1)
                encoder.setVertexBytes(&count, length: MemoryLayout<Float>.size, index: 2)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * 8 * points.count)
            }
        })
    }
}
