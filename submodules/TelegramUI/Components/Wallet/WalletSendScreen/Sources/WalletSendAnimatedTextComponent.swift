import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent
import TelegramPresentationData

final class WalletSendAnimatedTextComponent: Component {
    let text: String
    let numberPrefix: String?
    let font: UIFont
    let color: UIColor
    let dateTimeFormat: PresentationDateTimeFormat
    let isVisible: Bool
    let timing: WalletSendAmountMotionTiming?
    let centered: Bool

    init(text: String, numberPrefix: String? = nil, font: UIFont, color: UIColor, dateTimeFormat: PresentationDateTimeFormat, isVisible: Bool, timing: WalletSendAmountMotionTiming?, centered: Bool = false) {
        self.text = text
        self.numberPrefix = numberPrefix
        self.font = font
        self.color = color
        self.dateTimeFormat = dateTimeFormat
        self.isVisible = isVisible
        self.timing = timing
        self.centered = centered
    }

    static func ==(lhs: WalletSendAnimatedTextComponent, rhs: WalletSendAnimatedTextComponent) -> Bool {
        return lhs.text == rhs.text
            && lhs.numberPrefix == rhs.numberPrefix
            && lhs.font == rhs.font
            && lhs.color == rhs.color
            && lhs.dateTimeFormat == rhs.dateTimeFormat
            && lhs.isVisible == rhs.isVisible
            && lhs.timing == rhs.timing
            && lhs.centered == rhs.centered
    }

    static func groupGlyphs(_ glyphs: inout [WalletSendAmountGlyph], dateTimeFormat: PresentationDateTimeFormat, numberPrefix: String? = nil) {
        let firstDigit = glyphs.firstIndex(where: { $0.text.first?.wholeNumberValue != nil })
        let lastDigit = glyphs.lastIndex(where: { $0.text.first?.wholeNumberValue != nil })
        // Keep the words on either side of an empty amount in their own groups.
        // AnimatedTextComponent lays out spaces without creating glyph views.
        let prefixCharacterCount = numberPrefix.map { $0.filter { !$0.isWhitespace }.count }
        var characterIndex = 0
        var inFraction = false
        for i in glyphs.indices {
            guard let firstDigit, let lastDigit else {
                if let prefixCharacterCount, characterIndex >= prefixCharacterCount {
                    glyphs[i].group = .suffix
                } else {
                    glyphs[i].group = .prefix
                }
                characterIndex += glyphs[i].text.filter { !$0.isWhitespace }.count
                continue
            }
            if i < firstDigit {
                glyphs[i].group = .prefix
            } else if i > lastDigit {
                glyphs[i].group = .suffix
            } else if glyphs[i].text == dateTimeFormat.decimalSeparator {
                inFraction = true
                glyphs[i].group = .fraction
            } else if !inFraction && glyphs[i].text == dateTimeFormat.groupingSeparator {
                glyphs[i].group = .grouping
            } else {
                glyphs[i].group = inFraction ? .fraction : .integer
            }
        }
    }

    final class View: UIView {
        private let canvas = WalletSendAmountCanvas(frame: .zero)
        private let title = ComponentView<Empty>()
        private let motion = WalletSendAmountMotion()
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var component: WalletSendAnimatedTextComponent?
        private var textSize = CGSize.zero
        private var widthFrom: CGFloat = 0.0
        private var frameDuration = 1.0 / 120.0
        private var isApplicationInForeground = UIApplication.shared.applicationState != .background
        private var glyphsAvailable = false
        var animationFrameUpdated: (() -> Void)?

        var currentWidth: CGFloat {
            return self.presentationWidth(at: CACurrentMediaTime())
        }

        var canAnimate: Bool {
            return self.component?.isVisible == true && self.isApplicationInForeground && self.window != nil && self.glyphsAvailable
        }

        var isAnimating: Bool {
            return self.canAnimate && self.motion.isAnimating(at: CACurrentMediaTime())
        }

        func widthAdjustment(at time: Double) -> CGFloat {
            return self.motion.widthAdjustment(at: time)
        }

        private func presentationWidth(at time: Double) -> CGFloat {
            let progress = self.motion.timing?.layoutProgress(at: time) ?? 1.0
            return self.widthFrom + (self.textSize.width - self.widthFrom) * progress + self.motion.widthAdjustment(at: time)
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = true
            self.accessibilityTraits = .staticText
            self.addSubview(self.canvas)
            self.canvas.onFrameReady = { [weak self] in
                self?.updateRendererVisibility()
            }
            NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.finishMotion), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.displayLink?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func applicationDidEnterBackground() {
            self.isApplicationInForeground = false
            self.finishMotion()
        }

        @objc private func applicationWillEnterForeground() {
            self.isApplicationInForeground = true
            self.renderFrame()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.finishMotion()
            } else {
                self.renderFrame()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.renderFrame()
        }

        func update(component: WalletSendAnimatedTextComponent, availableSize: CGSize) -> CGSize {
            let mayAnimate = self.canAnimate && component.isVisible
            let now = CACurrentMediaTime()
            let previousWidth = self.presentationWidth(at: now)
            self.component = component
            self.accessibilityLabel = component.text
            self.canvas.prepareGlyphs(text: component.text, font: component.font, separators: component.dateTimeFormat.decimalSeparator + component.dateTimeFormat.groupingSeparator)
            let size = self.title.update(
                transition: .immediate,
                component: AnyComponent(AnimatedTextComponent(
                    font: component.font,
                    color: component.color,
                    items: [.init(id: "text", content: .text(component.text))],
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: availableSize
            )
            var glyphs: [WalletSendAmountGlyph] = []
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    titleView.accessibilityElementsHidden = true
                    self.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: .zero, size: size)
                glyphs = walletSendAmountComponentGlyphs(titleView, origin: .zero)
            }
            WalletSendAnimatedTextComponent.groupGlyphs(&glyphs, dateTimeFormat: component.dateTimeFormat, numberPrefix: component.numberPrefix)
            self.glyphsAvailable = self.canvas.isAvailable && glyphs.allSatisfy { glyph in
                glyph.text.allSatisfy(\.isWhitespace) || self.canvas.glyphMask(for: glyph) != nil
            }
            if glyphs != self.motion.target || size != self.textSize {
                self.widthFrom = previousWidth
                self.textSize = size
                self.motion.update(glyphs, width: size.width, timing: mayAnimate && self.glyphsAvailable ? component.timing : nil, at: now, frameDuration: self.frameDuration)
            }
            if !self.canAnimate {
                self.finishMotion()
            } else {
                self.renderFrame()
            }
            if self.isAnimating && self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] duration in
                    guard let self else { return }
                    self.frameDuration += (Double(duration) - self.frameDuration) * 0.3
                    self.renderFrame()
                })
            }
            return size
        }

        private func updateRendererVisibility() {
            let usesMetal = self.glyphsAvailable && self.canvas.hasFrame && self.component?.isVisible == true && self.isApplicationInForeground && self.window != nil
            self.canvas.isHidden = !usesMetal
            self.title.view?.isHidden = usesMetal
        }

        private func renderFrame() {
            let now = CACurrentMediaTime()
            let isAnimating = self.canAnimate && self.motion.isAnimating(at: now)
            if !isAnimating {
                self.motion.finish()
                self.displayLink?.invalidate()
                self.displayLink = nil
            }
            let width = self.presentationWidth(at: now)
            let sprites = self.motion.frame(at: now, frameDuration: self.frameDuration)
            // Leave room for rolling glyphs and blur, even for small subtitle fonts.
            let padding = ceil(sprites.reduce(self.component?.font.lineHeight ?? 0.0) { height, sprite in
                max(height, sprite.glyph.font.lineHeight, sprite.morph?.from.font.lineHeight ?? 0.0)
            })
            let offsetX = self.component?.centered == true ? (self.textSize.width - width) * 0.5 : 0.0
            // A shrinking centered line can extend far to the left of its final
            // bounds. Move the canvas with that extent so outgoing text is not cut.
            let originX = min(0.0, offsetX) - padding
            self.canvas.frame = CGRect(
                x: originX, y: -padding,
                width: ceil((max(self.widthFrom, self.textSize.width, width) + max(0.0, offsetX) + 2.0 * padding) / 64.0) * 64.0,
                height: self.textSize.height + 2.0 * padding
            )
            self.canvas.isRenderingEnabled = self.component?.isVisible == true && self.isApplicationInForeground && self.window != nil
            self.canvas.frameDuration = self.frameDuration
            let canvasSprites = sprites.map { sprite -> WalletSendAmountSprite in
                var sprite = sprite
                sprite.glyph.position.x += offsetX - originX
                sprite.glyph.position.y += padding
                return sprite
            }
            self.canvas.update(sprites: canvasSprites, isAnimating: isAnimating)
            self.updateRendererVisibility()
            self.animationFrameUpdated?()
        }

        @objc func finishMotion() {
            self.motion.finish()
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.renderFrame()
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
