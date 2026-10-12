import Foundation
import UIKit
import Metal
import MetalEngine
import CompanionRenderer

private final class CompanionFrameState: ComputeState {
    init?(device: MTLDevice) {}
}

private final class CompanionBlitState: RenderToLayerState {
    let pipelineState: MTLRenderPipelineState

    init?(device: MTLDevice) {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct V { float4 position [[position]]; float2 uv; };
        vertex V companionVertex(uint id [[vertex_id]], constant float4 &rect [[buffer(0)]]) {
            float2 p=float2(id&1,id>>1);
            V v; v.position=float4((rect.xy+p*rect.zw)*2-1,0,1); v.uv=float2(p.x,1-p.y); return v;
        }
        fragment float4 companionFragment(V v [[stage_in]], texture2d<float> image [[texture(0)]]) {
            constexpr sampler s(filter::linear,address::clamp_to_edge); return image.sample(s,v.uv);
        }
        """
        guard let library = try? device.makeLibrary(source: source, options: nil) else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "companionVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "companionFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.pipelineState = pipeline
    }
}

final class CompanionLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?
    var renderer: CompanionRenderer?
    var deltaTime: Float = 0
    var active = false

    override init() { super.init(); self.isOpaque = false }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(context: MetalEngineSubjectContext) {
        guard self.active, let renderer = self.renderer, self.bounds.width > 0, self.bounds.height > 0 else { return }
        let scale = min(UIScreen.main.scale, 2.0)
        let width = min(2048, Int(self.bounds.width * scale))
        let height = min(2048, Int(self.bounds.height * scale))
        let delta = self.deltaTime
        let texture = context.compute(state: CompanionFrameState.self) { buffer, _ -> MTLTexture? in
            return renderer.encodeFrame(buffer, width: UInt(width), height: UInt(height), deltaTime: delta)
        }
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: width, height: height), prefersDedicatedSurface: true), state: CompanionBlitState.self, layer: self, inputs: texture) { encoder, placement, texture in
            guard let texture else { return }
            let r = placement.effectiveRect
            var rect = SIMD4<Float>(Float(r.minX), Float(r.minY), Float(r.width), Float(r.height))
            encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }
}
