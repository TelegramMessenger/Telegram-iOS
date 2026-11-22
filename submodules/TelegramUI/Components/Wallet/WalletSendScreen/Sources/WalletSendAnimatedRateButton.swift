import Foundation
import UIKit
import AppBundle
import Display
import ComponentFlow
import GlassBackgroundComponent
import TelegramPresentationData

final class WalletSendAnimatedRateButton: UIControl {
    private let contentView = UIView()
    private let backgroundView = WalletSendCommentBackgroundView(frame: .zero)
    private let glassHighlightRecognizer = GlassHighlightGestureRecognizer(target: nil, action: nil)
    private let title = ComponentView<Empty>()
    private var titleSize = CGSize.zero
    private let gramIcon = UIImageView()
    private var arrows: [UIImageView] = []
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var arrowTiming: WalletSendAmountMotionTiming?
    private var arrowFrom: CGFloat = 0.0
    private var arrowTo: CGFloat = 0.0
    private var arrowPhase: CGFloat = 0.0
    private var arrowPaceFrom: CGFloat = 0.0
    private var arrowPace: CGFloat = 0.0
    private var geometryTiming: WalletSendAmountMotionTiming?
    private var previousMode: WalletSendInputMode?
    private var previousText = ""
    private var widthFrom: CGFloat = 22.0
    private var widthTo: CGFloat = 22.0
    private var currentWidth: CGFloat = 22.0
    private var gramFrom: CGFloat = 0.0
    private var gramTo: CGFloat = 0.0
    private var currentGram: CGFloat = 0.0
    private var visible = false
    private var theme: PresentationTheme?
    var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isExclusiveTouch = true
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addGestureRecognizer(self.glassHighlightRecognizer)
        self.glassHighlightRecognizer.isEnabled = false
        self.contentView.isUserInteractionEnabled = false
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = 13.0
        self.addSubview(self.contentView)
        self.contentView.addSubview(self.backgroundView)
        self.gramIcon.image = UIImage(bundleImageName: "Wallet/TopGram")
        self.gramIcon.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.gramIcon)
        for side in 0 ..< 2 {
            for _ in 0 ..< 5 {
                let view = UIImageView(image: UIImage(bundleImageName: "Wallet/Swap")?.withRenderingMode(.alwaysTemplate))
                view.contentMode = .scaleAspectFit
                let mask = CAShapeLayer()
                mask.path = CGPath(rect: CGRect(x: CGFloat(side) * 9.0, y: 0.0, width: 9.0, height: 18.0), transform: nil)
                view.layer.mask = mask
                self.contentView.addSubview(view)
                self.arrows.append(view)
            }
        }
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopAnimations), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionStatusChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resumePresentation), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillResignActive() {
        self.updateTouchEffect(isActive: false)
    }

    @objc private func stopAnimations() {
        self.updateTouchEffect(isActive: false)
        self.finishMotion()
    }

    @objc private func resumePresentation() {
        self.updateTouchEffect()
        self.setNeedsLayout()
    }

    @objc private func reduceMotionStatusChanged() {
        self.updateTouchEffect()
        self.finishMotion()
    }

    @objc private func pressed() { self.action?() }

    override var isEnabled: Bool {
        didSet {
            self.updateTouchEffect()
        }
    }

    private func updateTouchEffect(isActive: Bool = true) {
        let isEnabled = isActive && UIApplication.shared.applicationState == .active && self.window != nil && self.visible && self.isEnabled && !UIAccessibility.isReduceMotionEnabled
        self.glassHighlightRecognizer.isEnabled = isEnabled
        if !isEnabled {
            self.layer.removeAnimation(forKey: "sublayerTransform")
            self.layer.sublayerTransform = CATransform3DIdentity
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.updateTouchEffect()
        if self.window == nil { self.finishMotion() }
    }

    func update(
        text: String, displaysGramIcon: Bool, mode: WalletSendInputMode,
        dateTimeFormat: PresentationDateTimeFormat, theme: PresentationTheme,
        isVisible: Bool, isEnabled: Bool, timing sharedTiming: WalletSendAmountMotionTiming?,
        maxWidth: CGFloat
    ) -> CGSize {
        let wasVisible = self.visible
        self.visible = isVisible
        self.isEnabled = isEnabled
        self.theme = theme
        self.accessibilityLabel = displaysGramIcon ? "GRAM " + text : text
        for arrow in self.arrows { arrow.tintColor = theme.list.itemSecondaryTextColor }
        let now = CACurrentMediaTime()
        let switched = self.previousMode != nil && self.previousMode != mode
        let titleView = self.title.view as? WalletSendAnimatedTextComponent.View
        let previousProgress = self.geometryTiming?.layoutProgress(at: now) ?? 1.0
        let previousWidth = self.widthFrom + (self.widthTo - self.widthFrom) * previousProgress + (titleView?.widthAdjustment(at: now) ?? 0.0)
        let sharedStart = sharedTiming.flatMap { now - $0.start < $0.duration ? $0.start : nil }
        let timing: WalletSendAmountMotionTiming?
        if self.previousMode != nil && wasVisible && isVisible && titleView?.canAnimate == true {
            timing = WalletSendAmountMotionTiming(spin: switched, up: !(sharedTiming?.up ?? true), start: sharedStart ?? now)
        } else {
            timing = nil
        }
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(WalletSendAnimatedTextComponent(
                text: text,
                font: WalletSendAmountFonts.rate,
                color: theme.list.itemSecondaryTextColor,
                dateTimeFormat: dateTimeFormat,
                isVisible: isVisible,
                timing: timing
            )),
            environment: {}, containerSize: CGSize(width: max(1.0, maxWidth - 56.0), height: 26.0)
        )
        self.titleSize = titleSize
        let textWidth = titleSize.width
        let gramWidth: CGFloat = displaysGramIcon ? 19.0 : 0.0
        let width = min(maxWidth, max(22.0, 16.0 + gramWidth + textWidth + 3.0 + 18.0))
        if let titleView = self.title.view {
            if titleView.superview == nil {
                titleView.isUserInteractionEnabled = false
                titleView.accessibilityElementsHidden = true
                self.contentView.insertSubview(titleView, aboveSubview: self.backgroundView)
            }
        }
        if text != self.previousText || self.widthTo != width || self.gramTo != (displaysGramIcon ? 1.0 : 0.0) {
            self.widthFrom = previousWidth
            self.widthTo = width
            self.gramFrom = self.gramFrom + (self.gramTo - self.gramFrom) * previousProgress
            self.gramTo = displaysGramIcon ? 1.0 : 0.0
            self.geometryTiming = timing
            if switched {
                self.arrowTiming = timing
                self.arrowFrom = self.arrowPhase
                self.arrowTo = floor(self.arrowPhase) + 1.0
                self.arrowPaceFrom = self.arrowPace
            }
        }
        self.previousMode = mode
        self.previousText = text
        if !isVisible { self.finishMotion() }
        self.renderFrame()
        if self.isAnimating && self.displayLink == nil {
            self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.renderFrame()
            })
        }
        return CGSize(width: width, height: 26.0)
    }

    private var isAnimating: Bool {
        let now = CACurrentMediaTime()
        return self.visible && ((self.title.view as? WalletSendAnimatedTextComponent.View)?.isAnimating == true || (self.geometryTiming?.progress(at: now) ?? 1.0) < 1.0 || (self.arrowTiming?.progress(at: now) ?? 1.0) < 1.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.renderFrame()
    }

    private func renderFrame() {
        let now = CACurrentMediaTime()
        if !self.isAnimating {
            self.geometryTiming = nil
            self.arrowTiming = nil
        }
        let p = self.geometryTiming?.layoutProgress(at: now) ?? 1.0
        self.currentWidth = self.widthFrom + (self.widthTo - self.widthFrom) * p + ((self.title.view as? WalletSendAnimatedTextComponent.View)?.widthAdjustment(at: now) ?? 0.0)
        self.currentGram = self.gramFrom + (self.gramTo - self.gramFrom) * p
        self.contentView.bounds = CGRect(x: 0.0, y: 0.0, width: self.currentWidth, height: 26.0)
        self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.backgroundView.frame = self.contentView.bounds
        if let theme = self.theme {
            self.backgroundView.update(
                size: self.contentView.bounds.size,
                maxCornerRadius: 13.0,
                minCornerRadius: 13.0,
                theme: theme,
                hasTail: false
            )
        }
        self.title.view?.frame = CGRect(
            x: 8.0 + 19.0 * self.currentGram,
            y: floorToScreenPixels((26.0 - self.titleSize.height) / 2.0),
            width: self.titleSize.width,
            height: self.titleSize.height
        )
        self.gramIcon.frame = CGRect(x: 8.0, y: 5.0, width: 16.0, height: 16.0)
        self.gramIcon.alpha = self.currentGram
        let raw = self.arrowTiming?.progress(at: now) ?? 1.0
        self.arrowPhase = self.arrowFrom + (self.arrowTo - self.arrowFrom) * WalletSendAmountMotionTiming.ease(raw)
        let phase = self.arrowPhase.truncatingRemainder(dividingBy: 1.0)
        let speed = pow(1.0 - raw, 1.2)
        self.arrowPace = self.arrowPaceFrom + (speed - self.arrowPaceFrom) * WalletSendAmountMotionTiming.ease(min(1.0, raw / 0.15))
        let pace: CGFloat = self.arrowTiming?.reduced == true ? 0.0 : self.arrowPace
        let loop = phase < 0.5 ? phase * 2.0 : phase * 2.0 - 2.0
        let smear = 8.0 * pace
        let multiple = smear > 1.0
        let weights: [CGFloat] = [0.45, 0.8625, 1.0, 0.8625, 0.45]
        for (i, arrow) in self.arrows.enumerated() {
            let sample = i % 5
            let direction: CGFloat = i < 5 ? -1.0 : 1.0
            let k: CGFloat = multiple ? CGFloat(sample) / 4.0 - 0.5 : 0.0
            arrow.transform = .identity
            arrow.frame = CGRect(x: self.currentWidth - 26.0, y: 4.0, width: 18.0, height: 18.0)
            let travel = self.arrowTiming?.reduced == true ? 0.0 : direction * (22.0 * loop + k * smear)
            arrow.transform = CGAffineTransform(translationX: 0.0, y: travel).scaledBy(x: 1.0, y: 1.0 + 0.55 * pace)
            arrow.alpha = multiple ? weights[sample] / 3.625 : (sample == 0 ? 1.0 : 0.0)
        }
        if !self.isAnimating {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }

    private func finishMotion() {
        (self.title.view as? WalletSendAnimatedTextComponent.View)?.finishMotion()
        self.geometryTiming = nil
        self.arrowTiming = nil
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.renderFrame()
    }
}
