import UIKit
import Display
import Metal
import MetalKit
import MetalEngine

private final class WalletStickerWaveLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState

        required init?(device: MTLDevice) {
            guard let library = walletCardMetalLibrary(device: device),
                  let vertexFunction = library.makeFunction(name: "walletStickerVertex"),
                  let fragmentFunction = library.makeFunction(name: "walletStickerFragment") else {
                return nil
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Wallet Sticker Pipeline"
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: descriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }

    var internalData: MetalEngineSubjectInternalData?

    var texture: MTLTexture?
    var artTexture: MTLTexture?
    var uniforms: [SIMD4<Float>] = []

    func update(context: MetalEngineSubjectContext) {
        guard !self.bounds.isEmpty, let texture = self.texture, self.uniforms.count == 2 else { return }
        let scale = UIScreenScale
        let uniforms = self.uniforms
        let artTexture = self.artTexture ?? texture
        context.renderToLayer(
            spec: RenderLayerSpec(size: RenderSize(
                width: max(1, Int(ceil(self.bounds.width * scale))),
                height: max(1, Int(ceil(self.bounds.height * scale)))
            )),
            state: RenderState.self,
            layer: self,
            commands: { encoder, placement in
                let effectiveRect = placement.effectiveRect
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY),
                    Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setFragmentTexture(artTexture, index: 1)
                uniforms.withUnsafeBytes { bytes in
                    if let base = bytes.baseAddress { encoder.setFragmentBytes(base, length: bytes.count, index: 0) }
                }
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        )
    }
}

/// Drawn through the shared MetalEngine; the caller owns the animation clock
/// and the layer only renders when its pose changes.
public final class WalletStickerWaveView: UIView {
    override public class var layerClass: AnyClass {
        return WalletStickerWaveLayer.self
    }

    private var waveLayer: WalletStickerWaveLayer {
        return self.layer as! WalletStickerWaveLayer
    }

    private var image: UIImage?
    private var artImage: UIImage?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.layer.shadowColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func makeTexture(_ image: UIImage?) -> MTLTexture? {
        guard let cgImage = image?.cgImage else { return nil }
        return try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: cgImage,
            options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
    }

    /// Bounds include 30% padding on every edge, as in the reference.
    public func update(image: UIImage, art: UIImage? = nil, border: CGFloat = 1, front: CGFloat, bend: CGFloat, shade: CGFloat, lift: CGFloat) {
        if self.image !== image {
            self.image = image
            self.waveLayer.texture = Self.makeTexture(image)
        }
        if self.artImage !== art {
            self.artImage = art
            self.waveLayer.artTexture = Self.makeTexture(art)
        }
        self.layer.shadowOpacity = Float(0.3 * lift)
        self.layer.shadowRadius = 3 + 15 * lift
        self.layer.shadowOffset = CGSize(width: 0, height: 2 + 18 * lift)
        let side = Float(self.bounds.width / 1.6)
        self.waveLayer.uniforms = [SIMD4<Float>(side * 0.3, side * 0.3, side, side * 1.6),
            SIMD4<Float>(Float(front), Float(bend), Float(shade), Float(border))]
        self.waveLayer.setNeedsUpdate()
    }
}

final class WalletCardStickerView: UIImageView {
    private let gloss = CAGradientLayer()
    private let silhouette = CALayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
        gloss.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor]
        gloss.startPoint = CGPoint(x: 0, y: 0); gloss.endPoint = CGPoint(x: 1, y: 1)
        gloss.mask = silhouette
        layer.addSublayer(gloss)
    }
    required init?(coder: NSCoder) { fatalError() }
    func update(press: CGFloat, shine: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gloss.frame = bounds; silhouette.frame = bounds; silhouette.contents = image?.cgImage
        gloss.locations = [NSNumber(value: Double(max(0, shine - 0.14))), NSNumber(value: Double(shine)), NSNumber(value: Double(min(1, shine + 0.14)))]
        gloss.opacity = 0.5
        layer.shadowColor = UIColor.black.cgColor; layer.shadowOpacity = Float(press * 0.25)
        layer.shadowRadius = press * 9; layer.shadowOffset = CGSize(width: 0, height: press * 5)
        CATransaction.commit()
    }
}
