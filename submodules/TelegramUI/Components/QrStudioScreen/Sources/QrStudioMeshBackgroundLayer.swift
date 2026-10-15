import Foundation
import UIKit
import Metal
import Display
import MetalEngine

protocol QrStudioBackgroundContent: UIView {
    var wantsFullFrameRate: Bool { get }

    func update(size: CGSize, revealCenter: CGPoint)
    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>)
    func beginReveal(at time: Double)
    func setVisible(_ isVisible: Bool)
}

private final class QrStudioMeshBackgroundLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?

    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        init?(device: MTLDevice) {
            guard let library = qrStudioMetalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "qrMeshVertex"), let fragmentFunction = library.makeFunction(name: "qrMeshFragment") else {
                return nil
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    private static let segments = 48

    var renderSpec: RenderLayerSpec? {
        didSet {
            if self.renderSpec != oldValue {
                self.setNeedsUpdate()
            }
        }
    }

    var points: [SIMD4<Float>] = Array(repeating: SIMD4<Float>(), count: 9)
    var colors: [SIMD4<Float>] = Array(repeating: SIMD4<Float>(), count: 9)

    override init() {
        super.init()

        self.isOpaque = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(context: MetalEngineSubjectContext) {
        guard let renderSpec = self.renderSpec else {
            return
        }
        let points = self.points
        let colors = self.colors
        context.renderToLayer(spec: renderSpec, state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)

            var points = points
            encoder.setVertexBytes(&points, length: MemoryLayout<SIMD4<Float>>.size * 9, index: 1)
            var colors = colors
            encoder.setVertexBytes(&colors, length: MemoryLayout<SIMD4<Float>>.size * 9, index: 2)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: QrStudioMeshBackgroundLayer.segments * QrStudioMeshBackgroundLayer.segments * 6)
        })
    }
}

final class QrStudioMeshBackgroundView: UIView, QrStudioBackgroundContent {
    private let meshLayer = QrStudioMeshBackgroundLayer()
    private var size = CGSize()

    let wantsFullFrameRate: Bool = false

    init(palette: QrStudioPalette) {
        super.init(frame: CGRect())

        self.backgroundColor = palette.colors[4].uiColor
        self.meshLayer.colors = palette.colors.map { color -> SIMD4<Float> in
            let (l, a, b) = color.oklab
            return SIMD4<Float>(Float(l), Float(a), Float(b), 1.0)
        }
        self.layer.addSublayer(self.meshLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, revealCenter: CGPoint) {
        guard self.size != size else {
            return
        }
        self.size = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.meshLayer.frame = CGRect(origin: CGPoint(), size: size)
        CATransaction.commit()
        let scale = UIScreenScale * 0.5
        self.meshLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: max(1, Int(size.width * scale)), height: max(1, Int(size.height * scale))), prefersDedicatedSurface: true)
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
        guard self.size.width > 0.0, self.size.height > 0.0 else {
            return
        }
        let stretch = pan.stretch(at: time)
        let points = QrStudioMesh.points(at: time, pull: SIMD2(Double(stretch.width / self.size.width), Double(stretch.height / self.size.height)))
        self.meshLayer.points = points.map { SIMD4<Float>($0.x, $0.y, 0.0, 0.0) }
        self.meshLayer.setNeedsUpdate()
    }

    func beginReveal(at time: Double) {
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            self.meshLayer.setNeedsUpdate()
        } else {
            self.meshLayer.releaseSurface()
        }
    }
}
