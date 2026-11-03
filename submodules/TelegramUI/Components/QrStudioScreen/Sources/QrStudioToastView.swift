import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import UIKitRuntimeUtils
import LottieComponent
import LottieSettings

enum QrStudioToastIcon: Equatable {
    case star
    case success
    case save
    case copy
    case clock
    case timer
    case image(String)

    fileprivate var animationName: String? {
        switch self {
        case .star:
            return "QrStudioToastStar"
        case .success:
            return "QrStudioToastSuccess"
        case .save:
            return "QrStudioToastSave"
        default:
            return nil
        }
    }

    fileprivate var imageName: String? {
        switch self {
        case .copy:
            return "QrStudio/ToastCopy"
        case .clock:
            return "QrStudio/ToastClock"
        case let .image(name):
            return name
        default:
            return nil
        }
    }
}

struct QrStudioToast {
    struct Action {
        var title: String
        var perform: () -> Void
    }

    var icon: QrStudioToastIcon
    var text: String
    var action: Action? = nil
}

private final class QrStudioToastTimerView: UIView {
    private let ringLayer = CAShapeLayer()
    private let handLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        for layer in [self.ringLayer, self.handLayer] {
            layer.fillColor = nil
            layer.lineWidth = 2.2
            layer.lineCap = .round
            self.layer.addSublayer(layer)
        }
        self.layer.addSublayer(self.dotLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(color: UIColor, delay: Double) {
        let side: CGFloat = 24.0
        let frame = CGRect(x: (self.bounds.width - side) * 0.5, y: (self.bounds.height - side) * 0.5, width: side, height: side)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = side * 0.5 - 2.5

        self.ringLayer.frame = self.bounds
        self.ringLayer.strokeColor = color.cgColor
        self.ringLayer.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi * 0.5, endAngle: .pi * 1.5, clockwise: true).cgPath

        let hand = UIBezierPath()
        hand.move(to: CGPoint(x: side * 0.5, y: side * 0.5))
        hand.addLine(to: CGPoint(x: side * 0.5, y: side * 0.5 - radius * 0.62))
        self.handLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: side, height: side))
        self.handLayer.position = center
        self.handLayer.strokeColor = color.cgColor
        self.handLayer.path = hand.cgPath

        self.dotLayer.fillColor = color.cgColor
        self.dotLayer.path = UIBezierPath(ovalIn: CGRect(x: center.x - 1.6, y: center.y - 1.6, width: 3.2, height: 3.2)).cgPath

        let beginTime = CACurrentMediaTime() + delay
        let ring = CABasicAnimation(keyPath: "strokeEnd")
        ring.fromValue = 0.0
        ring.toValue = 1.0
        ring.duration = 0.7
        ring.beginTime = beginTime
        ring.fillMode = .backwards
        ring.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.ringLayer.add(ring, forKey: "progress")

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0.0
        rotation.toValue = Double.pi * 2.0
        rotation.duration = 0.7
        rotation.beginTime = beginTime
        rotation.fillMode = .backwards
        rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.handLayer.add(rotation, forKey: "progress")
    }
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
    private let animationIcon = ComponentView<Empty>()
    private let timerView = QrStudioToastTimerView()
    private let actionLabel = UILabel()
    private var action: QrStudioToast.Action?
    private var phase: Phase?
    private var contentSize = CGSize()
    private var glassWidth: CGFloat = 0.0
    private var lastTick: Double?
    private var tint = GlassBackgroundView.TintColor(kind: .panel)
    private var isLight = false
    private var foregroundColor = UIColor.white
    private var displayLink: SharedDisplayLinkDriver.Link?
    var lottieSettings: LottieRenderingSettings = .noAccountFallback

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.isHidden = true

        self.addSubview(self.glass)

        self.iconView.contentMode = .center
        self.contentView.addSubview(self.iconView)

        self.label.font = UIFont.systemFont(ofSize: 14.0)
        self.label.numberOfLines = 2
        self.contentView.addSubview(self.label)

        self.actionLabel.font = Font.semibold(15.0)
        self.actionLabel.textColor = UIColor(red: 0.45, green: 0.73, blue: 1.0, alpha: 1.0)
        self.contentView.addSubview(self.actionLabel)

        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))

        self.contentView.layer.mask = self.contentMask
        self.addSubview(self.contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.action != nil, let phase = self.phase, !self.isHidden else {
            return nil
        }
        if case .closing = phase {
            return nil
        }
        let area = CGRect(x: self.bounds.width - 120.0, y: 0.0, width: 120.0, height: self.bounds.height)
        return area.contains(point) ? self : nil
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state, let action = self.action else {
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.action = nil
        self.isUserInteractionEnabled = false
        self.phase = .closing(QrStudioClock.now)
        action.perform()
    }

    func show(_ toast: QrStudioToast, isLight: Bool, glassTint: GlassBackgroundView.TintColor) {
        self.action = toast.action
        self.isUserInteractionEnabled = toast.action != nil
        self.actionLabel.text = toast.action?.title
        self.actionLabel.isHidden = toast.action == nil
        self.isLight = isLight
        self.tint = glassTint
        let color = isLight ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.96, alpha: 1.0)
        self.foregroundColor = color
        self.iconView.tintColor = color
        self.label.textColor = color
        self.label.text = toast.text
        self.layoutContent()
        self.setIcon(toast.icon)
        self.present()
    }

    private func setIcon(_ icon: QrStudioToastIcon) {
        let iconDelay = 0.08
        self.iconView.image = icon.imageName.flatMap { UIImage(bundleImageName: $0)?.withRenderingMode(.alwaysTemplate) }
        self.iconView.isHidden = self.iconView.image == nil

        if case .timer = icon {
            if self.timerView.superview == nil {
                self.contentView.addSubview(self.timerView)
            }
            self.timerView.isHidden = false
            self.timerView.frame = self.iconView.frame
            self.timerView.play(color: self.foregroundColor, delay: iconDelay)
        } else {
            self.timerView.isHidden = true
        }

        if let name = icon.animationName {
            let _ = self.animationIcon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(content: LottieComponent.AppBundleContent(name: name), color: self.foregroundColor, startingPosition: .begin, size: CGSize(width: 30.0, height: 30.0), lottieSettings: self.lottieSettings)),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.animationIcon.view as? LottieComponent.View {
                if view.superview == nil {
                    self.contentView.addSubview(view)
                }
                view.frame = self.iconView.frame
                view.isHidden = false
                view.playOnce(delay: iconDelay, force: true)
            }
        } else {
            self.animationIcon.view?.isHidden = true
        }
    }

    private func present() {
        self.glassWidth = self.contentSize.width
        self.contentView.transform = .identity
        self.isHidden = false
        self.phase = .opening(QrStudioClock.now)
        self.startDisplayLink()
        self.tick()
    }

    private func layoutContent() {
        let textCount = self.label.text?.count ?? 0
        let maxTextWidth: CGFloat = self.action != nil ? 200.0 : (textCount > 36 ? 260.0 : 270.0)
        let textSize = self.label.sizeThatFits(CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude))
        let textWidth = self.action != nil || textCount > 36 ? maxTextWidth : min(maxTextWidth, ceil(textSize.width))
        let textHeight = ceil(self.label.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)).height)
        let height = max(48.0, textHeight + 18.0)
        var actionWidth: CGFloat = 0.0
        if self.action != nil {
            actionWidth = 12.0 + ceil(self.actionLabel.sizeThatFits(CGSize(width: 200.0, height: 40.0)).width)
        }
        self.contentSize = CGSize(width: 14.0 + 30.0 + 12.0 + textWidth + actionWidth + 20.0, height: height)
        let iconFrame = CGRect(x: QrStudioToastView.iconFrame.minX, y: floor((height - 30.0) * 0.5), width: 30.0, height: 30.0)
        let transform = self.contentView.transform
        self.contentView.transform = .identity
        self.bounds = CGRect(origin: CGPoint(), size: self.contentSize)
        self.contentView.frame = self.bounds
        self.contentView.transform = transform
        self.iconView.frame = iconFrame
        self.animationIcon.view?.frame = iconFrame
        self.timerView.frame = iconFrame
        self.label.frame = CGRect(x: 14.0 + 30.0 + 12.0, y: floor((height - textHeight) * 0.5), width: textWidth, height: textHeight)
        if self.action != nil {
            let actionSize = self.actionLabel.sizeThatFits(CGSize(width: 200.0, height: 40.0))
            self.actionLabel.frame = CGRect(x: self.label.frame.maxX + 12.0, y: floor((height - ceil(actionSize.height)) * 0.5), width: ceil(actionSize.width), height: ceil(actionSize.height))
        }
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
            if QrStudioLens.closesAfterHold(holding: now - start) {
                self.phase = .closing(now)
            }
        case let .closing(start):
            if now - start >= QrStudioLens.closeDuration {
                self.phase = nil
                self.action = nil
                self.isUserInteractionEnabled = false
                self.displayLink = nil
                self.isHidden = true
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
        self.glass.nativeBlurRadius = QrStudioGlass.blurRadius(self.tint)
        self.glass.update(size: size, cornerRadius: cornerRadius, isDark: !self.isLight, tintColor: self.tint, transition: .immediate)

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
