#if canImport(UIKit)
import UIKit
import QuartzCore
#if !SWIFT_PACKAGE
import AppBundle

private final class BundleHelper: NSObject {
}
#endif

/// The animated "dust" cloud drawn over one hidden spoiler run (the Telegram invisible-ink effect). Ported
/// from Telegram's `InvisibleInkDustNode`/`InvisibleInkDustView`
/// (`submodules/InvisibleInkDustNode/Sources/InvisibleInkDustNode.swift`): a `CAEmitterLayer` of tiny
/// speckles confined to the run's word rects, and on reveal a finger-attractor explosion + a radial mask
/// that dissolves the dust outward from the tap point. ASDisplayKit nodes → plain `UIView`/`UIImageView`,
/// Telegram helpers → UIKit equivalents. The editor restores the hidden text via a rendering attribute (no
/// `textNode`), so the text-mask half of Telegram's reveal is omitted; the emitter + its mask are kept
/// faithfully. Non-interactive; the canvas owns hit-test + reveal (`point(inside:)` just reports the run's
/// rects so a tap "lands" on dust).
@available(iOS 13.0, *)
final class SpoilerDustView: UIView {
    /// Hosts the emitter layer; gets the radial reveal mask (mirrors Telegram's `emitterNode`).
    private let emitterContainer = UIView()
    private let emitterLayer = CAEmitterLayer()
    private var cell = CAEmitterCell()
    /// Reveal mask = an inverse radial-gradient spot (transparent at the tap, opaque outward) over a white
    /// fill; the fill fades while the spot scales up, dissolving the dust outward from the tap point.
    private let emitterMask = UIView()
    private let emitterSpot = UIImageView()
    private let emitterMaskFill = UIView()
    private var lineRects: [CGRect] = []
    private(set) var isRevealed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        emitterContainer.isUserInteractionEnabled = false
        emitterContainer.clipsToBounds = true
        addSubview(emitterContainer)
        emitterContainer.layer.addSublayer(emitterLayer)

        emitterSpot.contentMode = .scaleToFill
        emitterMaskFill.backgroundColor = .white
        emitterMask.addSubview(emitterSpot)        // below the fill
        emitterMask.addSubview(emitterMaskFill)    // opaque white on top → mask fully open until reveal
        configureEmitter()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func configureEmitter() {
        let cell = CAEmitterCell()
        cell.contents = Self.speckleImage.cgImage
        cell.contentsScale = 1.8
        cell.emissionRange = .pi * 2.0
        cell.lifetime = 1.0
        cell.scale = 0.5
        cell.velocityRange = 20.0
        cell.name = "dustCell"
        cell.alphaRange = 1.0
        cell.setValue("point", forKey: "particleType")
        cell.setValue(3.0, forKey: "mass")
        cell.setValue(2.0, forKey: "massRange")
        self.cell = cell

        let attractor = CAEmitterCell.createEmitterBehavior(type: "simpleAttractor")
        attractor.setValue("fingerAttractor", forKey: "name")
        let alpha = CAEmitterCell.createEmitterBehavior(type: "valueOverLife")
        alpha.setValue("color.alpha", forKey: "keyPath")
        alpha.setValue([0.0, 0.0, 1.0, 0.0, -1.0], forKey: "values")
        alpha.setValue(true, forKey: "additive")

        emitterLayer.masksToBounds = true
        emitterLayer.allowsGroupOpacity = true
        emitterLayer.lifetime = 1
        emitterLayer.emitterCells = [cell]
        emitterLayer.emitterPosition = .zero
        emitterLayer.seed = arc4random()
        emitterLayer.emitterSize = CGSize(width: 1, height: 1)
        emitterLayer.emitterShape = CAEmitterLayerEmitterShape(rawValue: "rectangles")
        emitterLayer.setValue([attractor, alpha], forKey: "emitterBehaviors")
        emitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.fingerAttractor.stiffness")
        emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
    }

    /// Reconfigures the cloud for a hidden run: `size` = the view's bounds, `wordRects` confine the particles
    /// to where ink is (Telegram's `spoilerWords`), `lineRects` are the hit-test area. All in the view's own
    /// coordinates.
    func update(size: CGSize, color: UIColor, lineRects: [CGRect], wordRects: [CGRect]) {
        guard !isRevealed else { return }   // a dissolving view is fading out + about to remove itself
        self.lineRects = lineRects
        frame.size = size
        let bounds = CGRect(origin: .zero, size: size)
        emitterContainer.frame = bounds
        emitterLayer.frame = bounds
        emitterMask.frame = bounds
        emitterMaskFill.frame = bounds
        cell.color = color.cgColor
        emitterLayer.setValue(wordRects, forKey: "emitterRects")
        let radius = max(size.width, size.height)
        emitterLayer.setValue(radius, forKeyPath: "emitterBehaviors.fingerAttractor.radius")
        emitterLayer.setValue(radius * -0.5, forKeyPath: "emitterBehaviors.fingerAttractor.falloff")
        let area = wordRects.reduce(Float(0)) { $0 + Float($1.width * $1.height) }
        cell.birthRate = min(100_000, area * 0.35)
    }

    /// Reveal. With a tap `point`: the finger-attractor pulls the particles toward it while a radial mask
    /// dissolves the dust outward from that point (Telegram's `revealAtLocation`). With `nil` (a caret-driven
    /// reveal): a plain cross-fade. Either way the view removes itself and calls `completion` when done.
    /// Idempotent. The underlying text is restored separately (by the canvas's rendering attribute).
    func dissolve(explodingAt point: CGPoint?, completion: @escaping () -> Void) {
        guard !isRevealed else { completion(); return }
        isRevealed = true

        guard let location = point else {
            UIView.animate(withDuration: 0.3, animations: { self.alpha = 0 }, completion: { _ in
                self.removeFromSuperview(); completion()
            })
            return
        }

        wasExploded = true
        emitterLayer.setValue(true, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
        emitterLayer.setValue(location, forKeyPath: "emitterBehaviors.fingerAttractor.position")

        // Build the inverse radial mask off the main thread (matches Telegram), then install + animate it.
        let maskSize = emitterContainer.frame.size
        DispatchQueue.global().async { [weak self] in
            let image = Self.emitterMaskImage(size: maskSize, position: location)
            DispatchQueue.main.async { [weak self] in self?.emitterSpot.image = image }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.emitterContainer.mask = self.emitterMask
            let mw = self.emitterMask.frame.width, mh = self.emitterMask.frame.height
            self.emitterSpot.frame = CGRect(x: 0, y: 0, width: mw * 3.0, height: mh * 3.0)

            let cw = max(self.emitterContainer.frame.width, 1), ch = max(self.emitterContainer.frame.height, 1)
            let xFactor = (location.x / cw - 0.5) * 2.0
            let yFactor = (location.y / ch - 0.5) * 2.0
            let maxFactor = max(abs(xFactor), abs(yFactor))
            var scaleAddition = maxFactor * 4.0
            var durationAddition = -maxFactor * 0.2
            if ch > 0, cw / ch < 0.7 { scaleAddition *= 5.0; durationAddition *= 2.0 }

            if mw > 0, mh > 0 {
                self.emitterSpot.layer.anchorPoint = CGPoint(x: location.x / mw, y: location.y / mh)
                self.emitterSpot.layer.position = location
            }
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.3333
            scaleAnim.toValue = 10.5 + scaleAddition
            scaleAnim.duration = 0.55 + durationAddition
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            self.emitterSpot.layer.add(scaleAnim, forKey: "scale")

            let fillAnim = CABasicAnimation(keyPath: "opacity")
            fillAnim.fromValue = 1.0
            fillAnim.toValue = 0.0
            fillAnim.duration = 0.15
            fillAnim.fillMode = .forwards
            fillAnim.isRemovedOnCompletion = false
            self.emitterMaskFill.layer.add(fillAnim, forKey: "opacity")
        }
        // Timer-driven teardown (fires even without a render server, so headless tests complete): after the
        // mask dissolve, drop the attractor + the view. Mirrors Telegram's 0.8s post-reveal cleanup.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { completion(); return }
            self.emitterLayer.setValue(false, forKeyPath: "emitterBehaviors.fingerAttractor.enabled")
            self.alpha = 0
            self.emitterContainer.mask = nil
            self.removeFromSuperview()
            completion()
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard !isRevealed else { return false }
        return lineRects.contains { $0.contains(point) }
    }

    /// The inverse radial-gradient mask spot (transparent at `position`, opaque outward) — Telegram's
    /// `generateMaskImage(inverse: true)`. The >640pt downscale branch is omitted (text runs never reach it).
    private static func emitterMaskImage(size: CGSize, position: CGPoint) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.clear(CGRect(origin: .zero, size: size))
            let locations: [CGFloat] = [0.0, 0.7, 0.95, 1.0]
            let colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0).cgColor,
                          UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 1).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: locations) else { return }
            let endRadius = min(10.0, min(size.width, size.height) * 0.4)
            c.drawRadialGradient(gradient, startCenter: position, startRadius: 0,
                                 endCenter: position, endRadius: endRadius, options: .drawsAfterEndLocation)
        }
    }

    /// Telegram's actual particle texture (`textSpeckle_Normal.png`, a 4×4 soft gray+alpha speckle), bundled
    /// as a package resource — this is what makes the dust read as fine shimmer rather than coarse blobs. Falls
    /// back to a tiny generated dot only if the bundled asset can't be found.
    private static let speckleImage: UIImage = {
        #if SWIFT_PACKAGE
        if let asset = UIImage(named: "TextSpeckle", in: .module, with: nil) { return asset }
        #else
        if let asset = UIImage(bundleImageName: "Components/TextSpeckle") { return asset }
        #endif
        let side: CGFloat = 4
        let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return r.image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawRadialGradient(g, startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                                 endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2,
                                 options: [])
        }
    }()

    // MARK: Test accessors
    /// True iff `dissolve(explodingAt:)` was called with a non-nil point — i.e. the tap-to-reveal explosion
    /// path was taken rather than a plain cross-fade. Set synchronously; never reset. Test seam.
    private(set) var wasExploded = false
    var emitterLayerForTesting: CAEmitterLayer { emitterLayer }
    /// The bundled Telegram particle texture, resolved from THIS module's resource bundle (`.module` here
    /// means RichTextEditorUIKit's bundle, not a test bundle). nil ⇒ the resource was dropped/misconfigured.
    static var bundledSpeckleForTesting: UIImage? {
        #if SWIFT_PACKAGE
        return UIImage(named: "TextSpeckle", in: .module, with: nil)
        #else
        return UIImage(named: "TextSpeckle", in: Bundle(for: BundleHelper.self), with: nil)
        #endif
    }
}

/// Private `CAEmitterBehavior` bridge (no public API exists for the twinkle / attractor). Ported from the
/// reference's `LegacyComponents` category.
@available(iOS 13.0, *)
extension CAEmitterCell {
    static func createEmitterBehavior(type: String) -> NSObject {
        let selector = ["behaviorWith", "Type:"].joined()
        let behaviorClass = NSClassFromString(["CA", "Emitter", "Behavior"].joined()) as! NSObject.Type
        let behaviorWithType = behaviorClass.method(for: NSSelectorFromString(selector))!
        let castedBehaviorWithType = unsafeBitCast(
            behaviorWithType, to: (@convention(c) (Any?, Selector, Any?) -> NSObject).self)
        return castedBehaviorWithType(behaviorClass, NSSelectorFromString(selector), type)
    }
}

@available(iOS 13.0, *)
extension CAEmitterLayer {
    /// Birth rate of the first emitter cell (test seam).
    var birthRateForCellForTesting: Float { (emitterCells?.first?.birthRate) ?? 0 }
}
#endif
