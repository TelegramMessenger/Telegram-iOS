import UIKit
import WalletCardComponent

final class WalletStickerTrashView: UIView {
    private let glass = UIVisualEffectView()
    private let tint = UIView()
    private let label = UILabel()
    private let outlineBody = UIImageView(), outlineLid = UIImageView()
    private let filledBody = UIImageView(), filledLid = UIImageView()
    private let show = WalletStickerSpring(0, 300, 0.7)
    private let hover = WalletStickerSpring(0, 420, 0.74)
    private let near = WalletStickerSpring(0, 260, 0.9)
    private let lid = WalletStickerSpring(0, 380, 0.62)
    private let swallow = WalletStickerSpring(0, 520, 0.38)
    private let flash = WalletStickerSpring(0, 90, 1)
    private let leanX = WalletStickerSpring(0, 220, 0.75), leanY = WalletStickerSpring(0, 220, 0.75)
    private var closingUntil: Double = 0
    var title: String = "" { didSet { self.label.text = title } }
    var attraction: CGFloat { min(1, max(0, self.hover.value)) }
    var iconCenter: CGPoint { CGPoint(x: self.center.x - self.openWidth / 2 + 31, y: self.center.y) }
    private var openWidth: CGFloat { 76 + self.label.intrinsicContentSize.width }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        if #available(iOS 26.0, *) { self.glass.effect = UIGlassEffect(style: .regular) }
        else { self.glass.effect = UIBlurEffect(style: .systemMaterial) }
        self.glass.clipsToBounds = true
        self.addSubview(self.glass); self.addSubview(self.tint)
        self.tint.backgroundColor = .systemRed
        self.label.font = .systemFont(ofSize: 17, weight: .semibold); self.label.textColor = .white
        for view in [outlineBody, outlineLid, filledBody, filledLid] { self.addSubview(view) }
        self.addSubview(self.label)
        self.layer.shadowColor = UIColor.black.cgColor; self.layer.shadowRadius = 14
        self.layer.shadowOffset = CGSize(width: 0, height: 6)
        self.alpha = 0; self.isHidden = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func setOpen(_ value: Bool) { self.hover.to(value ? 1 : 0) }
    func gulp() {
        self.closingUntil = CACurrentMediaTime() + 0.5
        self.lid.with(1100, 0.42).to(0)
        self.swallow.velocity += 6; self.flash.set(1).to(0)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    func reset() {
        for spring in [show, hover, near, lid, swallow, flash, leanX, leanY] { spring.set(0) }
        self.closingUntil = 0; self.isHidden = true
    }
    func step(_ dt: CGFloat, carrying: Bool, trashing: Bool, finger: CGPoint?) -> Bool {
        let closing = CACurrentMediaTime() < self.closingUntil
        self.show.to(carrying || trashing || closing ? 1 : 0)
        if trashing { self.hover.to(1) } else if !carrying { self.hover.to(0) }
        var proximity: CGFloat = 0, lean = CGPoint.zero
        if carrying, let finger {
            let dx = finger.x-center.x, dy = finger.y-center.y, d = max(1, hypot(dx, dy))
            proximity = min(1, max(0, (210-d)/140))
            lean = CGPoint(x: dx/d*9*proximity, y: dy/d*9*proximity)
        }
        self.near.to(proximity); self.leanX.to(lean.x); self.leanY.to(lean.y)
        if !closing { self.lid.to(trashing ? 1 : max(self.hover.target, proximity*0.35)) }
        var moving = false
        for spring in [show, hover, near, lid, swallow, flash, leanX, leanY] {
            spring.step(dt)
            if spring.resting() { spring.set(spring.target) } else { moving = true }
        }
        let h = min(1, max(0, hover.value)), height: CGFloat = 56
        let width = height+(openWidth-height)*min(1.12, max(0, hover.value))
        self.bounds.size = CGSize(width: width, height: height)
        self.glass.frame = self.bounds; self.glass.layer.cornerRadius = height/2
        self.tint.frame = self.bounds; self.tint.layer.cornerRadius = height/2
        self.tint.alpha = min(1, 0.82*h+0.35*flash.value)
        let iconX = width/2+(-width/2+31)*h
        let ink = traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor(white: h, alpha: 1)
        func glyph(_ parts: TrashParts?, body: UIImageView, top: UIImageView, opacity: CGFloat) {
            guard let parts else { return }
            body.image = parts.body.withRenderingMode(.alwaysTemplate)
            top.image = parts.lid.withRenderingMode(.alwaysTemplate)
            body.tintColor = ink; top.tintColor = ink; body.alpha = opacity; top.alpha = opacity
            let origin = CGPoint(x: iconX-parts.size.width/2, y: (height-parts.size.height)/2)
            body.frame = CGRect(origin: CGPoint(x: origin.x, y: origin.y+parts.split), size: parts.body.size)
            top.bounds = CGRect(origin: .zero, size: parts.lid.size)
            top.layer.anchorPoint = parts.hinge
            top.layer.position = CGPoint(x: origin.x+parts.hinge.x*parts.lid.size.width, y: origin.y+parts.hinge.y*parts.lid.size.height-3*lid.value)
            top.transform = CGAffineTransform(rotationAngle: -38 * .pi/180 * lid.value)
        }
        glyph(TrashParts.outline, body: outlineBody, top: outlineLid, opacity: 1-h)
        glyph(TrashParts.filled, body: filledBody, top: filledLid, opacity: h)
        label.bounds.size = label.intrinsicContentSize
        label.center = CGPoint(x: iconX+23+label.bounds.width/2-(1-h)*10, y: height/2)
        label.alpha = min(1, max(0, (h-0.35)/0.65))
        let jelly = max(-1, min(1, show.velocity*0.08))
        let scale = (0.5+0.5*show.value)*(1+0.08*near.value)*(1+0.11*swallow.value)
        self.transform = CGAffineTransform(translationX: leanX.value, y: leanY.value+(1-show.value)*120)
            .scaledBy(x: scale*(1-0.05*jelly), y: scale*(1+0.09*jelly))
        self.alpha = min(1, show.value*1.6); self.layer.shadowOpacity = Float(0.14*min(1, show.value))
        self.isHidden = show.value <= 0.01
        return moving || carrying || trashing || closing
    }
}

private struct TrashParts {
    let lid: UIImage
    let body: UIImage
    let size: CGSize
    let split: CGFloat
    let hinge: CGPoint

    static let outline = make("trash")
    static let filled = make("trash.fill")

    private static func make(_ name: String) -> TrashParts? {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        guard let symbol = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(.black, renderingMode: .alwaysOriginal) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in symbol.draw(at: .zero) }
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var widths = [Int](repeating: 0, count: h)
        for row in 0..<h {
            let y = h - 1 - row
            var count = 0
            for x in 0..<w where data[(y * w + x) * 4 + 3] > 25 { count += 1 }
            widths[row] = count
        }
        let widest = widths.max() ?? 0
        guard widest > 0, let barStart = widths.firstIndex(where: { $0 >= widest * 9 / 10 }) else { return nil }
        let split = (barStart..<h).first { widths[$0] < widest * 9 / 10 } ?? h * 3 / 10
        guard let lid = cg.cropping(to: CGRect(x: 0, y: 0, width: w, height: split)),
              let body = cg.cropping(to: CGRect(x: 0, y: split, width: w, height: h - split)) else { return nil }
        let scale = CGFloat(3)
        return TrashParts(lid: UIImage(cgImage: lid, scale: scale, orientation: .up),
                          body: UIImage(cgImage: body, scale: scale, orientation: .up),
                          size: symbol.size, split: CGFloat(split) / scale,
                          hinge: CGPoint(x: 0.92, y: (CGFloat(barStart + split) / 2) / CGFloat(split)))
    }
}

