import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import UIKitRuntimeUtils
import LottieAnimationComponent

struct QrStudioToast: Equatable {
    var icon: String
    var text: String
    var animation: String? = nil
}

final class QrStudioToastView: UIView {
    private enum Phase {
        case opening(Double)
        case holding(Double)
        case closing(Double)
    }

    private static let iconFrame = CGRect(x: 14.0, y: 0.0, width: 30.0, height: 30.0)

    private let glass = GlassBackgroundView()
    private let contentView = UIView()
    private let contentMask = CAShapeLayer()
    private let iconView = UIImageView()
    private let label = UILabel()
    private let progressLayer = CAShapeLayer()
    private let cancelIconView = UIImageView()
    private let doneIcon = ComponentView<Empty>()
    private var phase: Phase?
    private var contentSize = CGSize()
    private var glassWidth: CGFloat = 0.0
    private var lastTick: Double?
    private var tint = GlassBackgroundView.TintColor(kind: .panel)
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var cancel: (() -> Void)?

    private(set) var isShowingProgress = false

    static func glassColor(ink: QrStudioColor, isLight: Bool) -> UIColor {
        return (isLight ? UIColor.black : ink.uiColor).withAlphaComponent(0.55)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.isHidden = true

        self.addSubview(self.glass)

        self.iconView.contentMode = .center
        self.iconView.tintColor = .white
        self.contentView.addSubview(self.iconView)

        let lineWidth: CGFloat = 2.5
        let ringSide = QrStudioToastView.iconFrame.width
        self.progressLayer.path = CGPath(ellipseIn: CGRect(x: 0.0, y: 0.0, width: ringSide, height: ringSide).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5), transform: nil)
        self.progressLayer.bounds = CGRect(x: 0.0, y: 0.0, width: ringSide, height: ringSide)
        self.progressLayer.lineWidth = lineWidth
        self.progressLayer.strokeColor = UIColor.white.cgColor
        self.progressLayer.fillColor = UIColor.clear.cgColor
        self.progressLayer.lineCap = .round
        self.progressLayer.isHidden = true
        self.contentView.layer.addSublayer(self.progressLayer)

        self.cancelIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Media Gallery/Close"), color: .white)
        self.cancelIconView.contentMode = .scaleAspectFit
        self.cancelIconView.isHidden = true
        self.contentView.addSubview(self.cancelIconView)

        self.label.font = UIFont.systemFont(ofSize: 14.0)
        self.label.textColor = .white
        self.label.numberOfLines = 2
        self.contentView.addSubview(self.label)

        self.contentView.layer.mask = self.contentMask
        self.addSubview(self.contentView)

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard self.isShowingProgress else {
            return false
        }
        return self.cancelArea.contains(point)
    }

    private var cancelArea: CGRect {
        let icon = self.iconView.frame
        return CGRect(x: icon.minX - 12.0, y: 0.0, width: icon.width + 24.0, height: self.bounds.height)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard self.isShowingProgress, self.cancelArea.contains(recognizer.location(in: self)) else {
            return
        }
        let cancel = self.cancel
        self.cancel = nil
        self.isShowingProgress = false
        self.isUserInteractionEnabled = false
        self.dismiss()
        cancel?()
    }

    func show(_ toast: QrStudioToast, ink: QrStudioColor, isLight: Bool) {
        self.isShowingProgress = false
        self.cancel = nil
        self.isUserInteractionEnabled = false
        if let animation = toast.animation {
            self.setIcon(.animation(animation))
        } else {
            self.iconView.image = UIImage(bundleImageName: toast.icon)?.withRenderingMode(.alwaysTemplate)
            self.setIcon(.image)
        }
        self.present(text: toast.text, ink: ink, isLight: isLight)
    }

    func showProgress(text: String, ink: QrStudioColor, isLight: Bool, cancel: @escaping () -> Void) {
        self.isShowingProgress = true
        self.cancel = cancel
        self.isUserInteractionEnabled = true
        self.progressLayer.strokeEnd = 0.027
        self.setIcon(.progress)
        self.present(text: text, ink: ink, isLight: isLight)
        if self.progressLayer.animation(forKey: "rotation") == nil {
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.duration = 2.0
            rotation.fromValue = 0.0 as NSNumber
            rotation.toValue = (Double.pi * 2.0) as NSNumber
            rotation.repeatCount = Float.infinity
            rotation.timingFunction = CAMediaTimingFunction(name: .linear)
            self.progressLayer.add(rotation, forKey: "rotation")
        }
    }

    func updateProgress(_ value: Float) {
        guard self.isShowingProgress else {
            return
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        self.progressLayer.strokeEnd = CGFloat(max(0.027, min(1.0, value)))
        CATransaction.commit()
    }

    func completeProgress(text: String) {
        guard self.isShowingProgress else {
            return
        }
        self.isShowingProgress = false
        self.cancel = nil
        self.isUserInteractionEnabled = false
        self.setIcon(.animation("anim_savemedia"))
        self.label.text = text
        self.layoutContent()
        let fade = CATransition()
        fade.type = .fade
        fade.duration = 0.2
        self.label.layer.add(fade, forKey: "text")
        self.phase = .holding(QrStudioClock.now)
        self.startDisplayLink()
    }

    func dismiss() {
        switch self.phase {
        case .opening, .holding:
            self.phase = .closing(QrStudioClock.now)
            self.startDisplayLink()
        default:
            break
        }
    }

    private enum IconMode: Equatable {
        case image
        case progress
        case animation(String)
    }

    private func setIcon(_ mode: IconMode) {
        self.iconView.isHidden = mode != .image
        self.progressLayer.isHidden = mode != .progress
        self.cancelIconView.isHidden = mode != .progress
        if mode != .progress {
            self.progressLayer.removeAnimation(forKey: "rotation")
        }
        if case let .animation(name) = mode {
            let _ = self.doneIcon.update(
                transition: .immediate,
                component: AnyComponent(LottieAnimationComponent(animation: LottieAnimationComponent.AnimationItem(name: name, mode: .animating(loop: false)), colors: [:], size: CGSize(width: 30.0, height: 30.0))),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.doneIcon.view {
                if view.superview == nil {
                    self.contentView.addSubview(view)
                }
                view.frame = self.iconView.frame
                view.isHidden = false
                view.alpha = 0.0
                UIView.animate(withDuration: 0.2, animations: {
                    view.alpha = 1.0
                })
                (view as? LottieAnimationComponent.View)?.playOnce()
            }
        } else {
            self.doneIcon.view?.removeFromSuperview()
            self.doneIcon.view?.isHidden = true
        }
    }

    private func present(text: String, ink: QrStudioColor, isLight: Bool) {
        self.label.text = text
        self.layoutContent()
        self.glassWidth = self.contentSize.width
        self.contentView.transform = .identity
        self.tint = GlassBackgroundView.TintColor(kind: .custom(style: .default, color: QrStudioToastView.glassColor(ink: ink, isLight: isLight)))
        self.isHidden = false
        self.phase = .opening(QrStudioClock.now)
        self.startDisplayLink()
        self.tick()
    }

    private func layoutContent() {
        let textSize = self.label.sizeThatFits(CGSize(width: 270.0, height: CGFloat.greatestFiniteMagnitude))
        let textWidth = min(270.0, ceil(textSize.width))
        let textHeight = ceil(textSize.height)
        let height = max(48.0, textHeight + 18.0)
        self.contentSize = CGSize(width: 14.0 + 30.0 + 12.0 + textWidth + 20.0, height: height)
        let iconFrame = CGRect(x: QrStudioToastView.iconFrame.minX, y: floor((height - 30.0) * 0.5), width: 30.0, height: 30.0)
        let transform = self.contentView.transform
        self.contentView.transform = .identity
        self.bounds = CGRect(origin: CGPoint(), size: self.contentSize)
        self.contentView.frame = self.bounds
        self.contentView.transform = transform
        self.iconView.frame = iconFrame
        self.progressLayer.position = CGPoint(x: iconFrame.midX, y: iconFrame.midY)
        self.cancelIconView.frame = iconFrame.insetBy(dx: 8.0, dy: 8.0)
        self.doneIcon.view?.frame = iconFrame
        self.label.frame = CGRect(x: 14.0 + 30.0 + 12.0, y: floor((height - textHeight) * 0.5), width: textWidth, height: textHeight)
    }

    private func startDisplayLink() {
        if self.displayLink == nil {
            self.lastTick = nil
            self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
                self?.tick()
            })
        }
    }

    private func tick() {
        guard let phase = self.phase else {
            return
        }
        let now = QrStudioClock.now
        let dt = self.lastTick.map { now - $0 } ?? 0.0
        self.lastTick = now
        self.glassWidth = QrStudioLens.approach(self.glassWidth, to: self.contentSize.width, dt: dt)
        let p: CGFloat
        switch phase {
        case let .opening(start):
            p = QrStudioLens.opening(now - start)
            if now - start >= QrStudioLens.openDuration * 1.6 {
                self.phase = .holding(now)
            }
        case let .holding(start):
            p = 1.0
            if QrStudioLens.closesAfterHold(holding: now - start, isPersistent: self.isShowingProgress) {
                self.phase = .closing(now)
            } else if self.isShowingProgress && self.glassWidth == self.contentSize.width {
                self.displayLink = nil
            }
        case let .closing(start):
            if now - start >= QrStudioLens.closeDuration {
                self.phase = nil
                self.displayLink = nil
                self.isHidden = true
                self.isShowingProgress = false
                self.isUserInteractionEnabled = false
                self.progressLayer.removeAnimation(forKey: "rotation")
                return
            }
            p = QrStudioLens.closing(now - start)
        }
        self.apply(p)
    }

    private func apply(_ p: CGFloat) {
        let size = QrStudioLens.size(p, width: self.glassWidth, height: self.contentSize.height)
        let c = QrStudioLens.ramp(p, 0.2, 0.95)
        let cornerRadius = min(size.height * 0.5, 24.0)
        let glassFrame = CGRect(x: (self.contentSize.width - size.width) * 0.5, y: (self.contentSize.height - size.height) * 0.5, width: size.width, height: size.height)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        self.glass.frame = glassFrame
        self.glass.update(size: size, cornerRadius: cornerRadius, isDark: true, tintColor: self.tint, transition: .immediate)

        let scale = 1.0 + 0.85 * (1.0 - c)
        self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.contentView.alpha = QrStudioLens.ramp(p, 0.08, 0.5)

        let radius = 5.0 * (1.0 - c)
        if radius > 0.05, let filter = makeBlurFilter() {
            filter.setValue(radius as NSNumber, forKey: "inputRadius")
            self.contentView.layer.filters = [filter]
        } else {
            self.contentView.layer.filters = nil
        }

        let center = CGPoint(x: self.contentSize.width * 0.5, y: self.contentSize.height * 0.5)
        let local = CGRect(x: center.x + (glassFrame.minX - center.x) / scale, y: center.y + (glassFrame.minY - center.y) / scale, width: glassFrame.width / scale, height: glassFrame.height / scale)
        self.contentMask.frame = CGRect(origin: CGPoint(), size: self.contentSize)
        self.contentMask.path = UIBezierPath(roundedRect: local, cornerRadius: cornerRadius / scale).cgPath

        CATransaction.commit()
    }
}
