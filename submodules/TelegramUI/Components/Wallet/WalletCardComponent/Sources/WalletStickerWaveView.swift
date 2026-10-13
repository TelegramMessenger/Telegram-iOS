import UIKit
import Metal
import MetalKit

/// An on-demand Metal surface. The caller owns the animation clock; this view
/// has no display link and never draws while its pose is unchanged.
public final class WalletStickerWaveView: UIView {
    private static let device = MTLCreateSystemDefaultDevice()
    private static let commandQueue = device?.makeCommandQueue()
    private static let pipeline: MTLRenderPipelineState? = {
        guard let device, let library = walletCardMetalLibrary(device: device) else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "walletStickerVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "walletStickerFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }()

    private let metalView: MTKView
    private let fallback = UIImageView()
    private var texture: MTLTexture?
    private var artTexture: MTLTexture?
    private var artImage: UIImage?
    private var border: CGFloat = 1
    private var image: UIImage?
    private var front: CGFloat = 1
    private var bend: CGFloat = 0
    private var shade: CGFloat = 0

    public override init(frame: CGRect) {
        self.metalView = MTKView(frame: .zero, device: Self.device)
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.metalView.isOpaque = false
        self.metalView.backgroundColor = .clear
        self.metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        self.metalView.isPaused = true
        self.metalView.enableSetNeedsDisplay = false
        self.metalView.framebufferOnly = true
        self.metalView.autoResizeDrawable = true
        self.addSubview(self.metalView)
        self.fallback.contentMode = .scaleAspectFit
        self.addSubview(self.fallback)
        self.layer.shadowColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Bounds include 30% padding on every edge, as in the reference.
    public func update(image: UIImage, art: UIImage? = nil, border: CGFloat = 1, front: CGFloat, bend: CGFloat, shade: CGFloat, lift: CGFloat) {
        if self.image !== image {
            self.image = image
            self.fallback.image = image
            if let cgImage = image.cgImage, let device = Self.device {
                self.texture = try? MTKTextureLoader(device: device).newTexture(cgImage: cgImage,
                    options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
            }
        }
        if self.artImage !== art {
            self.artImage = art
            if let cgImage = art?.cgImage, let device = Self.device {
                self.artTexture = try? MTKTextureLoader(device: device).newTexture(cgImage: cgImage,
                    options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
            } else {
                self.artTexture = nil
            }
        }
        self.border = border
        self.front = front
        self.bend = bend
        self.shade = shade
        self.layer.shadowOpacity = Float(0.3 * lift)
        self.layer.shadowRadius = 3 + 15 * lift
        self.layer.shadowOffset = CGSize(width: 0, height: 2 + 18 * lift)
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.draw()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.metalView.frame = self.bounds
        self.fallback.frame = self.bounds.insetBy(dx: self.bounds.width * 0.3 / 1.6, dy: self.bounds.height * 0.3 / 1.6)
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil { self.draw() }
    }

    private func draw() {
        self.metalView.isHidden = false
        guard self.window != nil, self.bounds.width > 0,
              let pipeline = Self.pipeline, let texture = self.texture,
              let command = Self.commandQueue?.makeCommandBuffer(),
              let descriptor = self.metalView.currentRenderPassDescriptor,
              let drawable = self.metalView.currentDrawable,
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            self.fallback.isHidden = false
            self.metalView.isHidden = true
            return
        }
        self.fallback.isHidden = true
        self.metalView.isHidden = false
        let side = Float(self.bounds.width / 1.6)
        let uniforms = [SIMD4<Float>(side * 0.3, side * 0.3, side, side * 1.6),
                        SIMD4<Float>(Float(self.front), Float(self.bend), Float(self.shade), Float(self.border))]
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(self.artTexture ?? texture, index: 1)
        uniforms.withUnsafeBytes { bytes in
            if let base = bytes.baseAddress { encoder.setFragmentBytes(base, length: bytes.count, index: 0) }
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }
}

final class WalletCardStickerView: UIImageView {
    private let gloss = CAGradientLayer()
    private let silhouette = CALayer()
    private let ring = CAShapeLayer()
    private let degrees = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
        gloss.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.12).cgColor, UIColor.clear.cgColor]
        gloss.startPoint = CGPoint(x: 0, y: 0); gloss.endPoint = CGPoint(x: 1, y: 1)
        gloss.mask = silhouette
        layer.addSublayer(gloss)
        ring.fillColor = nil; ring.strokeColor = UIColor.white.cgColor; ring.lineWidth = 1
        layer.addSublayer(ring)
        degrees.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        degrees.textColor = .white; degrees.textAlignment = .center
        degrees.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        degrees.layer.cornerRadius = 11; degrees.clipsToBounds = true
        addSubview(degrees)
    }
    required init?(coder: NSCoder) { fatalError() }
    func update(press: CGFloat, angle: CGFloat, shine: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gloss.frame = bounds; silhouette.frame = bounds; silhouette.contents = image?.cgImage
        gloss.locations = [NSNumber(value: Double(max(0, shine - 0.14))), NSNumber(value: Double(shine)), NSNumber(value: Double(min(1, shine + 0.14)))]
        gloss.opacity = 0.5
        let center = CGPoint(x: bounds.midX, y: bounds.midY), radius = bounds.width * 0.6
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ring.path = path.cgPath; ring.opacity = Float(press * 0.45)
        degrees.alpha = press
        degrees.text = "\(Int((atan2(sin(angle), cos(angle)) * 180 / .pi).rounded()))°"
        degrees.bounds = CGRect(x: 0, y: 0, width: max(44, degrees.intrinsicContentSize.width + 16), height: 22)
        degrees.center = CGPoint(x: center.x + (radius + 20) * sin(angle), y: center.y + (radius + 20) * cos(angle))
        if let parent = self.superview {
            var labelCenter = self.convert(degrees.center, to: parent)
            let home = self.convert(center, to: parent)
            if labelCenter.y > parent.bounds.maxY - 14 { labelCenter.y = home.y - radius - 20 }
            labelCenter.x = min(parent.bounds.maxX - degrees.bounds.width / 2 - 4, max(degrees.bounds.width / 2 + 4, labelCenter.x))
            labelCenter.y = min(parent.bounds.maxY - 14, max(14, labelCenter.y))
            degrees.center = self.convert(labelCenter, from: parent)
        }
        degrees.transform = CGAffineTransform(rotationAngle: -angle)
        layer.shadowColor = UIColor.black.cgColor; layer.shadowOpacity = Float(press * 0.25)
        layer.shadowRadius = press * 9; layer.shadowOffset = CGSize(width: 0, height: press * 5)
        CATransaction.commit()
    }
}
