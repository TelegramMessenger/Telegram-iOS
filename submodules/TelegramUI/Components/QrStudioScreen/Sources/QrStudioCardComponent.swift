import Foundation
import UIKit
import Display
import ComponentFlow
import QrCode
import AnimatedTextComponent

final class QrStudioCardComponent: Component {
    let link: String
    let username: String?
    let expires: Int32?
    let reservesTimer: Bool
    let animatesLinkChange: Bool
    let ink: QrStudioColor
    let isLight: Bool
    let bounceToken: String
    let fillSource: QrStudioThemeBackgroundView?

    init(link: String, username: String?, expires: Int32?, reservesTimer: Bool, animatesLinkChange: Bool, ink: QrStudioColor, isLight: Bool, bounceToken: String, fillSource: QrStudioThemeBackgroundView?) {
        self.link = link
        self.username = username
        self.expires = expires
        self.reservesTimer = reservesTimer
        self.animatesLinkChange = animatesLinkChange
        self.ink = ink
        self.isLight = isLight
        self.bounceToken = bounceToken
        self.fillSource = fillSource
    }

    static func ==(lhs: QrStudioCardComponent, rhs: QrStudioCardComponent) -> Bool {
        if lhs.link != rhs.link {
            return false
        }
        if lhs.username != rhs.username {
            return false
        }
        if lhs.expires != rhs.expires {
            return false
        }
        if lhs.reservesTimer != rhs.reservesTimer {
            return false
        }
        if lhs.animatesLinkChange != rhs.animatesLinkChange {
            return false
        }
        if lhs.ink != rhs.ink {
            return false
        }
        if lhs.isLight != rhs.isLight {
            return false
        }
        if lhs.bounceToken != rhs.bounceToken {
            return false
        }
        if lhs.fillSource !== rhs.fillSource {
            return false
        }
        return true
    }

    private final class FillLayer {
        let source: QrStudioThemeBackgroundView
        let owner: AnyObject?
        let view = UIView()
        let content: UIView?
        let dimView = UIView()

        init(source: QrStudioThemeBackgroundView) {
            self.source = source
            let fill = source.makeCodeFill()
            self.owner = fill?.owner
            self.content = fill?.view
            self.view.isUserInteractionEnabled = false
            self.view.layer.allowsGroupOpacity = true
            self.view.backgroundColor = .black
            if let content = self.content {
                self.view.addSubview(content)
            }
            self.dimView.backgroundColor = .black
            self.dimView.alpha = 0.3
            self.view.addSubview(self.dimView)
        }

        func layout(size: CGSize) {
            self.view.frame = CGRect(origin: CGPoint(), size: size)
            self.dimView.frame = CGRect(origin: CGPoint(), size: size)
            self.updatePosition()
        }

        func updatePosition() {
            guard let content = self.content else {
                return
            }
            let frame = self.source.convert(self.source.bounds, to: self.view)
            if content.frame != frame {
                content.frame = frame
            }
        }
    }

    private final class Fill {
        let container = UIView()
        let inkView = UIView()
        var layers: [FillLayer] = []
        var isRemoving = false

        init(ink: UIColor) {
            self.container.isUserInteractionEnabled = false
            self.container.clipsToBounds = true
            self.container.layer.cornerRadius = QrStudioCardMetrics.cornerRadius
            self.container.layer.cornerCurve = .continuous
            self.container.layer.compositingFilter = "screenBlendMode"
            self.inkView.backgroundColor = ink
            self.container.addSubview(self.inkView)
        }

        func layout(size: CGSize) {
            self.container.frame = CGRect(origin: CGPoint(), size: size)
            self.inkView.frame = CGRect(origin: CGPoint(), size: size)
            for layer in self.layers {
                layer.layout(size: size)
            }
        }

        func updatePosition() {
            for layer in self.layers {
                layer.updatePosition()
            }
        }
    }

    final class View: UIView {
        private let backgroundView = UIView()
        private let codeView = QrStudioCodeView()
        private let usernameLabel = UILabel()
        private let timerText = ComponentView<Empty>()
        private var timerLabel: UIView?
        private var timerTicker: Foundation.Timer?
        private var timerFrame = CGRect()

        private var component: QrStudioCardComponent?
        private var fill: Fill?
        private var appliedInkUsesFill = false
        private var matrix: QrCodeMatrix?
        private var matrixLink: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.backgroundColor = .white
            self.backgroundView.layer.cornerRadius = QrStudioCardMetrics.cornerRadius
            self.backgroundView.layer.cornerCurve = .continuous
            self.addSubview(self.backgroundView)
            self.addSubview(self.codeView)

            self.usernameLabel.textAlignment = .center
            self.usernameLabel.adjustsFontSizeToFitWidth = true
            self.usernameLabel.minimumScaleFactor = 0.5
        self.usernameLabel.baselineAdjustment = .alignCenters
            self.addSubview(self.usernameLabel)

            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowRadius = 46.0
            self.layer.shadowOffset = CGSize(width: 0.0, height: 22.0)
            self.layer.shadowOpacity = 0.0
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.timerTicker?.invalidate()
        }

        func exportImage(scale: CGFloat, staticPlane: Bool) -> (image: CGImage, planeRect: CGRect)? {
            let size = self.bounds.size
            guard size.width > 0.0, size.height > 0.0, let planeView = self.codeView.planeView else {
                return nil
            }
            let planeRect = self.codeView.convert(planeView.frame, to: self)
            let planeWasHidden = planeView.isHidden
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            let shadowOpacity = self.layer.shadowOpacity
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.layer.shadowOpacity = 0.0
            planeView.isHidden = true
            let fillImage: UIImage? = self.fill.map { fill in
                return UIGraphicsImageRenderer(size: size, format: format).image { context in
                    fill.container.layer.render(in: context.cgContext)
                }
            }
            let fillAlpha = self.fill?.container.alpha ?? 1.0
            self.fill?.container.isHidden = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                self.layer.render(in: context.cgContext)
                if let fillImage {
                    context.cgContext.saveGState()
                    UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: QrStudioCardMetrics.cornerRadius).addClip()
                    fillImage.draw(in: CGRect(origin: CGPoint(), size: size), blendMode: .screen, alpha: fillAlpha)
                    context.cgContext.restoreGState()
                }
                if staticPlane, !planeWasHidden, let icon = generateTintedImage(image: UIImage(bundleImageName: "Share/QrPlaneIcon"), color: .white) {
                    icon.draw(in: planeRect)
                }
            }
            planeView.isHidden = planeWasHidden
            self.fill?.container.isHidden = false
            self.layer.shadowOpacity = shadowOpacity
            CATransaction.commit()
            guard let cgImage = image.cgImage else {
                return nil
            }
            return (cgImage, planeRect)
        }

        private func animateBounce() {
            let dip = CABasicAnimation(keyPath: "transform.scale")
            dip.fromValue = 0.0
            dip.toValue = -0.05
            dip.isAdditive = true
            dip.duration = 0.12
            dip.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let spring = CASpringAnimation(keyPath: "transform.scale")
            spring.fromValue = -0.05
            spring.toValue = 0.0
            spring.isAdditive = true
            spring.mass = 1.0
            spring.stiffness = 130.5
            spring.damping = 11.42
            spring.beginTime = 0.12
            spring.duration = 0.7

            let group = CAAnimationGroup()
            group.animations = [dip, spring]
            group.duration = 0.82
            self.layer.add(group, forKey: "bounce")
        }

        func update(component: QrStudioCardComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component

            if let previousComponent, previousComponent.bounceToken != component.bounceToken, !transition.animation.isImmediate {
                self.animateBounce()
            }

            if self.matrixLink != component.link {
                self.matrixLink = component.link
                if !component.link.isEmpty, let matrix = qrCodeMatrix(string: component.link, ecl: "Q") {
                    self.matrix = matrix
                }
            }

            let size = CGSize(width: QrStudioCardMetrics.width, height: QrStudioCardMetrics.height(showsUsername: component.username != nil || component.expires != nil || component.reservesTimer))

            self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
            self.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: QrStudioCardMetrics.cornerRadius).cgPath
            let shadowOpacity: Float = component.isLight ? 0.13 : 0.0
            if self.layer.shadowOpacity != shadowOpacity {
                if !transition.animation.isImmediate {
                    let animation = CABasicAnimation(keyPath: "shadowOpacity")
                    animation.fromValue = self.layer.presentation()?.shadowOpacity ?? self.layer.shadowOpacity
                    animation.toValue = shadowOpacity
                    animation.duration = 0.45
                    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.layer.add(animation, forKey: "shadowOpacity")
                }
                self.layer.shadowOpacity = shadowOpacity
            }

            let codeSide = QrStudioCardMetrics.codeSide
            self.codeView.frame = CGRect(x: (size.width - codeSide) * 0.5, y: 50.0, width: codeSide, height: codeSide)
            let usernameFont = Font.with(size: 24.0, design: .round, weight: .bold)
            let usernameMidY = (50.0 + codeSide + size.height) * 0.5
            let usernameBaseline = usernameMidY + usernameFont.capHeight * 0.5
            let usernameHeight = ceil(usernameFont.lineHeight)
            let usernameY = usernameBaseline - usernameFont.ascender - (usernameHeight - usernameFont.lineHeight) * 0.5
            self.usernameLabel.frame = CGRect(x: 20.0, y: (usernameY * UIScreenScale).rounded() / UIScreenScale, width: size.width - 40.0, height: usernameHeight)
            self.timerFrame = self.usernameLabel.frame

            let animated = previousComponent != nil && !transition.animation.isImmediate
            self.updateFill(component: component, previousInk: previousComponent?.ink, size: size, animated: animated)
            let linkChanged = previousComponent.flatMap { $0.link != component.link } ?? false
            self.applyInk(component: component, animated: animated, animatesCode: linkChanged && component.animatesLinkChange)

            return size
        }

        private func updateFill(component: QrStudioCardComponent, previousInk: QrStudioColor?, size: CGSize, animated: Bool) {
            if let source = component.fillSource {
                let fill: Fill
                let fadesIn: Bool
                if let current = self.fill {
                    fill = current
                    fill.isRemoving = false
                    fadesIn = animated
                } else {
                    fill = Fill(ink: (previousInk ?? component.ink).uiColor)
                    self.addSubview(fill.container)
                    self.fill = fill
                    fadesIn = animated && previousInk != nil
                }
                if fill.layers.last?.source !== source {
                    let layer = FillLayer(source: source)
                    fill.container.addSubview(layer.view)
                    fill.layers.append(layer)
                    layer.layout(size: size)
                    if fadesIn {
                        layer.view.alpha = 0.0
                        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseInOut], animations: {
                            layer.view.alpha = 1.0
                        }, completion: { [weak fill] _ in
                            guard let fill, let index = fill.layers.firstIndex(where: { $0 === layer }) else {
                                return
                            }
                            for previous in fill.layers[..<index] {
                                previous.view.removeFromSuperview()
                            }
                            fill.layers.removeFirst(index)
                        })
                    } else {
                        for previous in fill.layers.dropLast() {
                            previous.view.removeFromSuperview()
                        }
                        fill.layers = [layer]
                    }
                }
            } else if let fill = self.fill, !fill.isRemoving {
                fill.inkView.backgroundColor = component.ink.uiColor
                if animated {
                    fill.isRemoving = true
                    UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseInOut], animations: {
                        for layer in fill.layers {
                            layer.view.alpha = 0.0
                        }
                    }, completion: { [weak self, weak fill] _ in
                        guard let self, let fill, self.fill === fill, fill.isRemoving else {
                            return
                        }
                        self.removeFill()
                    })
                } else {
                    self.removeFill()
                }
            }
            self.fill?.layout(size: size)
        }

        func playCodeReveal(delay: Double) {
            self.codeView.playReveal(delay: delay)
        }

        private func removeFill() {
            self.fill?.container.removeFromSuperview()
            self.fill = nil
            if let component = self.component {
                self.applyInk(component: component, animated: false)
            }
        }

        private func applyInk(component: QrStudioCardComponent, animated: Bool, animatesCode: Bool = false) {
            let usesFill = self.fill != nil
            let ink = usesFill ? QrStudioColor(rgb: 0x000000) : component.ink
            let canAnimate = animated && self.appliedInkUsesFill == usesFill
            self.appliedInkUsesFill = usesFill
            self.codeView.update(matrix: self.matrix, ink: ink, cardColor: .white, transition: canAnimate || animatesCode ? .easeInOut(duration: 0.5) : .immediate, animatesInk: canAnimate)

            if component.username == nil, component.expires != nil {
                self.usernameLabel.isHidden = true
                self.updateTimer(transition: animatesCode ? .easeInOut(duration: 0.3) : .immediate)
                self.startTimerTicker()
                return
            }
            self.stopTimer()
            guard let username = component.username else {
                self.usernameLabel.isHidden = true
                return
            }
            let text = NSMutableAttributedString()
            let color = ink.uiColor
            text.append(NSAttributedString(string: "@", attributes: [
                .font: Font.with(size: 24.0, design: .round, weight: .heavy),
                .foregroundColor: color,
                .kern: -0.24
            ]))
            text.append(NSAttributedString(string: username.uppercased(), attributes: [
                .font: Font.with(size: 24.0, design: .round, weight: .bold),
                .foregroundColor: color,
                .kern: -0.24
            ]))
            if canAnimate, self.usernameLabel.attributedText != nil, self.usernameLabel.attributedText != text {
                UIView.transition(with: self.usernameLabel, duration: 0.5, options: [.transitionCrossDissolve], animations: {
                    self.usernameLabel.attributedText = text
                }, completion: nil)
            } else {
                self.usernameLabel.attributedText = text
            }
            self.usernameLabel.isHidden = false
        }

        private func startTimerTicker() {
            guard self.timerTicker == nil else {
                return
            }
            let now = Date().timeIntervalSince1970
            let ticker = Foundation.Timer(fire: Date(timeIntervalSince1970: floor(now) + 1.0), interval: 1.0, repeats: true, block: { [weak self] _ in
                self?.updateTimer(transition: .easeInOut(duration: 0.3))
            })
            RunLoop.main.add(ticker, forMode: .common)
            self.timerTicker = ticker
        }

        private func stopTimer() {
            self.timerTicker?.invalidate()
            self.timerTicker = nil
            self.timerText.view?.isHidden = true
            self.timerLabel?.isHidden = true
        }

        private func updateTimer(transition: ComponentTransition) {
            guard let component = self.component, let expires = component.expires else {
                return
            }
            let remaining = Int(max(0.0, Double(expires) - Date().timeIntervalSince1970).rounded(.up))
            let usesFill = self.fill != nil
            let color = (usesFill ? QrStudioColor(rgb: 0x000000) : component.ink).uiColor
            if #available(iOS 17.0, *) {
                let label: QrStudioTimerLabel
                if let current = self.timerLabel as? QrStudioTimerLabel {
                    label = current
                } else {
                    label = QrStudioTimerLabel()
                    self.timerLabel = label
                    self.addSubview(label)
                }
                let wasHidden = label.isHidden
                label.isHidden = false
                label.frame = self.timerFrame.insetBy(dx: -8.0, dy: -4.0)
                label.update(remaining: remaining, color: color, animated: !transition.animation.isImmediate && !wasHidden)
                return
            }
            let size = self.timerText.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 24.0, design: .round, weight: .bold, traits: .monospacedNumbers),
                    color: color,
                    items: [
                        AnimatedTextComponent.Item(id: AnyHashable(0), content: .number(remaining / 60, minDigits: 1)),
                        AnimatedTextComponent.Item(id: AnyHashable(1), content: .text(":")),
                        AnimatedTextComponent.Item(id: AnyHashable(2), content: .number(remaining % 60, minDigits: 2))
                    ],
                    preferredDirectionIsDown: true
                )),
                environment: {},
                containerSize: self.timerFrame.size
            )
            if let view = self.timerText.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.isHidden = false
                view.frame = CGRect(x: floor(self.timerFrame.midX - size.width * 0.5), y: floor(self.timerFrame.midY - size.height * 0.5), width: size.width, height: size.height)
            }
        }

        func updateFillPosition() {
            self.fill?.updatePosition()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.fill?.updatePosition()
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
