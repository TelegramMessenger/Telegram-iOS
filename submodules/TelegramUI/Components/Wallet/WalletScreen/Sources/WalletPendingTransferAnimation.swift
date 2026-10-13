import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ListSectionComponent
import PremiumDiamondComponent
import WalletSendScreen
import WalletTransactionItemComponent

final class WalletPendingTransferAnimation {
    private struct Star {
        let angle: Double
        let speed: Double
        let size: Double
        let life: Double
        let delay: Double
        let phase: Double
        let tone: Int
    }

    private static let stars: [Star] = {
        var seed: UInt64 = 31 &* 0x9E37_79B9_7F4A_7C15 | 1
        func random(_ lower: Double, _ upper: Double) -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return lower + (upper - lower) * Double(seed % 1_000_000) / 1_000_000.0
        }
        return (0 ..< 34).map { i in
            Star(angle: i % 2 == 0 ? .pi + random(-0.75, 0.75) : random(0.0, 2.0 * .pi),
                speed: random(160.0, 760.0), size: random(2.6, 6.2), life: random(0.6, 1.15),
                delay: random(0.0, 0.09), phase: random(0.0, 2.0 * .pi), tone: Int(random(0.0, 2.99)))
        }
    }()

    private static let starImages: [CGImage] = [UIColor(rgb: 0x30a1f5), UIColor(rgb: 0x5cccff), UIColor(rgb: 0x2178f7)].compactMap { color in
        return generateImage(CGSize(width: 48.0, height: 48.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color.withAlphaComponent(0.28).cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray, locations: [0.0, 1.0]) {
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0.0, endCenter: center, endRadius: 24.0, options: [])
            }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x + 15.0, y: center.y))
            for i in 1 ... 4 {
                let angle = CGFloat(i) * .pi / 2.0
                path.addQuadCurve(to: CGPoint(x: center.x + cos(angle) * 15.0, y: center.y + sin(angle) * 15.0),
                    controlPoint: CGPoint(x: center.x + cos(angle - .pi / 4.0) * 2.7, y: center.y + sin(angle - .pi / 4.0) * 2.7))
            }
            path.close()
            context.addPath(path.cgPath)
            context.setFillColor(color.cgColor)
            context.fillPath()
        })?.cgImage
    }

    let id: String
    var isPending = true
    var finished = false
    var start: CFTimeInterval?
    var completion: CFTimeInterval?
    var landing: CFTimeInterval?
    private(set) var isVisible = false
    private weak var row: ListSectionContentView.ItemView?
    private weak var content: WalletTransactionItemComponent.View?
    private let separatorMask = CALayer()
    private let surface = CALayer()
    private let sheen = CALayer()
    private let particles = CALayer()
    private var bands: [CAGradientLayer] = []
    private var starLayers: [CALayer] = []
    private var diamond: InteractiveDiamondComponent.View?
    private let diamondComponent = ComponentView<Empty>()
    private var flightSource: WalletSendTransferAnimationSource?
    private var flightOverlay: UIView?
    private var flightStart: CFTimeInterval?
    private var laidOutSize = CGSize.zero
    private var isDark = false

    var isFlying: Bool { return self.flightSource != nil }

    func waitForFlightLayout(at time: CFTimeInterval) -> Bool {
        guard let flightStart = self.flightStart, time - flightStart < 0.5 else {
            self.suspend()
            return false
        }
        self.flightSource?.updateFlightHaptics(at: time)
        return true
    }

    init(id: String) {
        self.id = id
        self.separatorMask.backgroundColor = UIColor.white.cgColor
        self.separatorMask.opacity = 0.0
        self.surface.cornerRadius = 22.0
        self.surface.shadowColor = UIColor.black.cgColor
        self.surface.shadowRadius = 14.0
        self.surface.shadowOffset = CGSize(width: 0.0, height: 6.0)
        self.particles.masksToBounds = true
        self.particles.cornerRadius = 22.0
        for (index, specification) in [(150.0, 0.07, 0.0), (60.0, 0.07, 0.0), (120.0, 0.22, 5.0), (90.0, 0.85, 1.2)].enumerated() {
            let band = CAGradientLayer()
            let color = index % 2 == 0 ? UIColor(rgb: 0x5cccff) : UIColor(rgb: 0x30a1f5)
            let peak = CGFloat(specification.1)
            let alphas: [CGFloat] = [0.0, peak * 0.35, peak, peak * 0.35, 0.0]
            band.colors = alphas.map { color.withAlphaComponent($0).cgColor }
            band.locations = [0.0, 0.3, 0.5, 0.7, 1.0]
            let mask = CAShapeLayer()
            mask.lineWidth = specification.2
            mask.fillColor = specification.2 == 0.0 ? UIColor.black.cgColor : nil
            mask.strokeColor = specification.2 == 0.0 ? nil : UIColor.black.cgColor
            band.mask = mask
            self.sheen.addSublayer(band)
            self.bands.append(band)
        }
    }

    deinit {
        self.detach()
        self.flightOverlay?.removeFromSuperview()
        self.diamond?.isRenderingEnabled = false
    }

    func launch(_ source: WalletSendTransferAnimationSource, at now: CFTimeInterval) {
        guard let window = source.window else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.diamond?.removeFromSuperview()
        self.diamond?.isRenderingEnabled = false
        self.diamond = source.diamond
        let overlay = UIView(frame: window.bounds)
        overlay.isUserInteractionEnabled = false
        overlay.accessibilityElementsHidden = true
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        overlay.addSubview(source.diamond)
        source.diamond.center = source.center
        source.diamond.transform = CGAffineTransform(rotationAngle: source.rotation)
        source.diamond.updateWalletTransfer(width: source.width, rotationSpeed: 2.0 * .pi / 26.0, completion: false, isDark: self.isDark)
        source.diamond.isRenderingEnabled = true
        self.flightOverlay = overlay
        self.flightSource = source
        self.flightStart = now
        self.start = now + 0.1
    }

    private func detach() {
        self.row?.transform = .identity
        self.row?.layer.zPosition = 0.0
        self.row?.separatorLayer.isHidden = false
        if self.row?.separatorLayer.mask === self.separatorMask {
            self.row?.separatorLayer.mask = nil
        }
        self.content?.resetTransferPresentation()
        self.surface.removeFromSuperlayer()
        self.sheen.removeFromSuperlayer()
        self.particles.removeFromSuperlayer()
        if !self.isFlying { self.diamond?.removeFromSuperview() }
        self.row = nil
        self.content = nil
    }

    func bind(row: ListSectionContentView.ItemView?, content: WalletTransactionItemComponent.View?, theme: PresentationTheme) {
        self.isDark = theme.overallDarkAppearance
        if self.row !== row || self.content !== content {
            self.detach()
            self.row = row
            self.content = content
            self.laidOutSize = .zero
        }
        guard let row, content != nil else { return }
        row.separatorLayer.mask = self.separatorMask
        self.separatorMask.frame = row.separatorLayer.bounds
        if self.surface.superlayer == nil {
            row.layer.insertSublayer(self.surface, at: 0)
            row.layer.addSublayer(self.sheen)
            row.layer.addSublayer(self.particles)
        }
        self.surface.backgroundColor = theme.list.itemBlocksBackgroundColor.cgColor
        if row.bounds.size != self.laidOutSize {
            self.laidOutSize = row.bounds.size
            let bounds = row.bounds
            self.surface.frame = bounds
            self.surface.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 22.0).cgPath
            self.sheen.frame = bounds
            self.particles.frame = bounds
            for band in self.bands {
                band.frame = bounds
                (band.mask as? CAShapeLayer)?.path = UIBezierPath(roundedRect: bounds, cornerRadius: 22.0).cgPath
            }
        }
        if self.diamond == nil && !UIAccessibility.isReduceMotionEnabled {
            let _ = self.diamondComponent.update(transition: .immediate,
                component: AnyComponent(InteractiveDiamondComponent(size: CGSize(width: 150.0, height: 150.0), diamondWidth: 34.0,
                    isVisible: false, theme: theme)), environment: {}, containerSize: CGSize(width: 150.0, height: 150.0))
            self.diamond = self.diamondComponent.view as? InteractiveDiamondComponent.View
            self.diamond?.prepareForWalletTransfer()
        }
        if !self.isFlying, let diamond = self.diamond, diamond.superview !== row {
            row.addSubview(diamond)
        }
    }

    func suspend() {
        self.isVisible = false
        self.diamond?.isRenderingEnabled = false
        if self.isFlying {
            self.diamond?.transform = .identity
            self.flightSource = nil
            self.flightStart = nil
            self.flightOverlay?.removeFromSuperview()
            self.flightOverlay = nil
            self.diamond?.removeFromSuperview()
            self.landing = nil
        }
        if !self.isPending { self.finished = true }
    }

    static func spring(_ time: Double, damping: Double = 7.0, frequency: Double = 14.0) -> CGFloat {
        guard time > 0.0 else { return 0.0 }
        return CGFloat(1.0 - exp(-damping * time) * (cos(frequency * time) + damping / frequency * sin(frequency * time)))
    }

    func update(at now: CFTimeInterval, visible: Bool) {
        self.isVisible = visible
        guard visible, let row = self.row, let content = self.content else {
            self.suspend()
            return
        }
        if self.start == nil {
            guard self.isPending else { self.finished = true; return }
            self.start = now
        }
        let reduced = UIAccessibility.isReduceMotionEnabled
        if reduced && self.isFlying {
            self.suspend()
            self.isVisible = true
        }
        self.flightSource?.updateFlightHaptics(at: now)
        if !self.isPending && self.completion == nil && !self.isFlying {
            self.completion = now
            Haptics.hit(0.9)
        }
        let elapsed = max(0.0, now - (self.start ?? now))
        let finish = self.completion.map { max(0.0, now - $0) }
        var lift = reduced ? CGFloat(0.0) : Self.spring(now - (self.start ?? now))
        if let finish { lift *= 1.0 - Self.spring(finish, damping: 8.0, frequency: 13.0) }
        let big: CGFloat = reduced ? 0.0 : finish.map { CGFloat(pow(1.0 - min(1.0, $0 / 0.3), 3.0)) } ?? 1.0
        let impact = self.landing.map { now - $0 } ?? 0.0
        let dip = !reduced && impact > 0.0 && impact < 1.2
            ? CGFloat(5.0 * sin(2.0 * .pi * 2.2 * impact) * exp(-impact / 0.2)) : 0.0
        let scale = 1.0 + 0.035 * lift - 0.004 * dip
        row.transform = CGAffineTransform(translationX: 0.0, y: -2.0 * lift + dip).scaledBy(x: scale, y: scale)
        row.layer.zPosition = 1.0
        row.separatorLayer.isHidden = false
        self.surface.opacity = Float(max(0.0, min(1.0, lift)))
        self.surface.shadowOpacity = 0.13
        let iconAlpha: CGFloat
        if reduced { iconAlpha = 1.0 }
        else if let finish { iconAlpha = min(1.0, max(0.0, Self.spring(finish - 0.32, damping: 8.0, frequency: 17.0))) }
        else { iconAlpha = 0.0 }
        let clockAlpha = finish.map { 0.5 + 0.5 * CGFloat(cos(.pi * min(1.0, $0 / (reduced ? 0.15 : 0.35)))) } ?? 1.0
        self.separatorMask.opacity = Float(1.0 - clockAlpha)
        let iconScale = reduced ? 1.0 : finish.map { 0.2 + 0.8 * Self.spring($0 - 0.32, damping: 8.0, frequency: 17.0) } ?? 0.2
        content.applyTransferPresentation(expansion: big, iconAlpha: iconAlpha, iconScale: iconScale, clockAlpha: clockAlpha, time: reduced ? 0.0 : elapsed)
        self.updateSheen(elapsed: elapsed, opacity: !reduced && finish == nil ? 1.0 : 0.0)

        let icon = content.transferIconFrame
        let normal = content.convert(CGPoint(x: icon.midX, y: icon.midY), to: row)
        let pending = CGPoint(x: row.bounds.width - 34.5, y: row.bounds.height * 0.5)
        var slot = CGPoint(x: normal.x + (pending.x - normal.x) * big, y: normal.y + (pending.y - normal.y) * big)
        if let finish, finish < 0.34 { slot.y -= CGFloat(sin(.pi * finish / 0.34)) * 11.0 }
        if let source = self.flightSource, let start = self.flightStart, let overlay = self.flightOverlay, let diamond = self.diamond {
            let t = min(1.0, max(0.0, now - start) / 0.5)
            let rowLayer = row.layer.presentation() ?? row.layer
            let target = rowLayer.convert(slot, to: overlay.layer.presentation() ?? overlay.layer)
            let d = target.y - source.center.y
            let rise = 44.0 + max(0.0, -d)
            let b = -2.0 * rise - 2.0 * sqrt(max(0.0, rise * rise + rise * d))
            diamond.transform = CGAffineTransform(rotationAngle: source.rotation * (1.0 - t))
            diamond.center = CGPoint(x: source.center.x + (target.x - source.center.x) * t,
                y: source.center.y + b * t + (d - b) * t * t)
            let edge = rowLayer.convert(CGPoint(x: slot.x + 34.0, y: slot.y), to: overlay.layer.presentation() ?? overlay.layer)
            let targetWidth = hypot(edge.x - target.x, edge.y - target.y)
            let width = (source.width + (targetWidth - source.width) * t) * (1.0 + 0.28 * sin(.pi * min(1.0, t / 0.75)))
            let speed = Float(2.0 * .pi / 26.0 + (6.5 - 2.0 * .pi / 26.0) * min(1.0, t / 0.6))
            diamond.updateWalletTransfer(width: width, rotationSpeed: speed, completion: false, isDark: self.isDark)
            diamond.isRenderingEnabled = !reduced
            if t >= 1.0 || reduced {
                self.flightSource = nil
                self.flightStart = nil
                row.addSubview(diamond)
                diamond.transform = .identity
                diamond.center = slot
                diamond.updateWalletTransfer(width: 34.0, rotationSpeed: 6.5, completion: false, isDark: self.isDark)
                self.flightOverlay?.removeFromSuperview()
                self.flightOverlay = nil
                self.landing = now
                diamond.spin(7.0, decay: 0.7)
                Haptics.hit(0.8)
            }
        } else if let diamond = self.diamond {
            var width: CGFloat = 34.0
            if let finish {
                let pop = CGFloat(sin(.pi * min(1.0, finish / 0.26))) * 0.3
                let shrink = CGFloat(max(0.0, min(1.0, (finish - 0.18) / 0.16)))
                width = 34.0 * (1.0 + pop) * (1.0 - shrink) + icon.width * shrink
            } else if impact > 0.0 && impact < 0.36 {
                width *= 1.0 + 0.26 * CGFloat(sin(.pi * impact / 0.36) * (1.0 - 0.3 * impact / 0.36))
            }
            if diamond.superview !== row { row.addSubview(diamond) }
            diamond.center = slot
            diamond.alpha = reduced ? 0.0 : finish.map { CGFloat(max(0.0, min(1.0, 1.0 - ($0 - 0.35) / 0.1))) } ?? 1.0
            diamond.updateWalletTransfer(width: width, rotationSpeed: 6.5, completion: finish != nil, isDark: self.isDark)
            diamond.isRenderingEnabled = !reduced && diamond.alpha > 0.0
        }
        self.updateStars(time: reduced ? nil : finish, origin: pending)
        if let finish, finish >= (reduced ? 0.15 : 1.3) { self.finished = true }
    }

    private func updateSheen(elapsed: Double, opacity: Float) {
        let u = (elapsed + 0.2).truncatingRemainder(dividingBy: 2.5) / 1.5
        self.sheen.opacity = u <= 1.0 ? opacity * Float(sin(.pi * u)) : 0.0
        guard u <= 1.0, self.laidOutSize.width > 0.0, self.laidOutSize.height > 0.0 else { return }
        let x = (-0.25 + 1.5 * (0.5 - 0.5 * cos(.pi * u))) * self.laidOutSize.width
        for (band, width) in zip(self.bands, [150.0, 60.0, 120.0, 90.0]) {
            band.startPoint = CGPoint(x: (x - width) / self.laidOutSize.width, y: 0.0)
            band.endPoint = CGPoint(x: (x + width) / self.laidOutSize.width, y: width * 0.55 / self.laidOutSize.height)
        }
    }

    private func updateStars(time: Double?, origin: CGPoint) {
        guard let time, time < 1.25 else { self.particles.isHidden = true; return }
        self.particles.isHidden = false
        if self.starLayers.isEmpty {
            for star in Self.stars {
                let layer = CALayer()
                layer.contents = Self.starImages.indices.contains(star.tone) ? Self.starImages[star.tone] : nil
                layer.bounds = CGRect(x: 0.0, y: 0.0, width: star.size * 4.8, height: star.size * 4.8)
                self.particles.addSublayer(layer)
                self.starLayers.append(layer)
            }
        }
        for (star, layer) in zip(Self.stars, self.starLayers) {
            let age = time - star.delay
            guard age > 0.0 && age < star.life else { layer.opacity = 0.0; continue }
            let u = age / star.life
            let distance = star.speed * (1.0 - exp(-2.6 * age)) / 2.6
            layer.position = CGPoint(x: origin.x + cos(star.angle) * distance, y: origin.y + sin(star.angle) * distance * 0.45)
            layer.opacity = Float(min(1.0, u / 0.12) * (1.0 - u * u))
            let scale = (0.55 + 0.45 * (1.0 - u)) * (0.72 + 0.28 * sin(age * 19.0 + star.phase))
            layer.setAffineTransform(CGAffineTransform(rotationAngle: star.phase + age * 2.4).scaledBy(x: scale, y: scale))
        }
    }
}
