import Foundation
import UIKit
import Display
import ComponentFlow
import PremiumDiamondComponent
import TelegramPresentationData
import WalletContext

func walletSendAmountComponentGlyphs(_ view: UIView, origin: CGPoint) -> [WalletSendAmountGlyph] {
    return view.subviews.sorted { $0.frame.minX < $1.frame.minX }.flatMap { child -> [WalletSendAmountGlyph] in
        guard let textView = child as? TextView, let layout = textView.cachedLayout,
              let text = layout.attributedString, let line = layout.linesRects().first else { return [] }
        return WalletSendAmountGlyph.text(text, origin: CGPoint(x: origin.x + child.frame.minX + line.minX, y: origin.y + child.frame.minY + line.minY), group: .suffix)
    }
}

// Shared with the screen's entrance clock; independent of amount-entry motion.
struct WalletSendAmountIntro {
    static let duration = InteractiveDiamondIntro.duration
    var progress: CGFloat = 1.0
    var caret: CGFloat = 1.0
    var lift: CGFloat { InteractiveDiamondIntro(progress: self.progress).lift }
    var scale: CGFloat { InteractiveDiamondIntro(progress: self.progress).scale }
    var rise: CGFloat { 56.0 * (1.0 - self.progress) }

    init(time: Double?) {
        guard let time, time < Self.duration else { return }
        let k = min(max((time - 0.78) / 0.2, 0.0), 1.0)
        self.caret = CGFloat(k * k * (3.0 - 2.0 * k))
        self.progress = InteractiveDiamondIntro(time: time).progress
    }

    func finishing(_ progress: CGFloat) -> WalletSendAmountIntro {
        var result = self
        result.progress += (1.0 - result.progress) * progress
        result.caret += (1.0 - result.caret) * progress
        return result
    }
}

final class WalletSendAnimatedAmountField: WalletSendAmountField {
    private struct Layout {
        var width: CGFloat
        var height: CGFloat
        var gram: CGRect
        var fiat: CGRect
        var caret: CGRect

        func interpolate(to other: Layout, progress p: CGFloat) -> Layout {
            return Layout(
                width: self.width + (other.width - self.width) * p,
                height: self.height + (other.height - self.height) * p,
                gram: walletSendAmountMotionRect(self.gram, other.gram, p),
                fiat: walletSendAmountMotionRect(self.fiat, other.fiat, p),
                caret: walletSendAmountMotionRect(self.caret, other.caret, p)
            )
        }
    }

    private struct SymbolState {
        var drop: CGFloat
        var tilt: CGFloat
        var blur: CGFloat
        var alpha: CGFloat

        var transform: CATransform3D {
            var transform = CATransform3DIdentity
            transform = CATransform3DRotate(transform, self.tilt, 0.0, 0.0, 1.0)
            return CATransform3DTranslate(transform, 0.0, self.drop, 0.0)
        }
    }

    private struct SymbolTransition {
        let timing: WalletSendAmountMotionTiming
        let toGram: Bool
        var gramFrom: SymbolState?
        var fiatFrom: SymbolState?

        var duration: Double { return self.timing.reduced ? self.timing.duration : self.timing.duration + 1.5 }

        func state(gram: Bool, at time: Double) -> SymbolState {
            let elapsed = max(0.0, time - self.timing.start)
            let p = self.timing.layoutProgress(at: time)
            let arriving = gram == self.toGram
            let from = gram ? self.gramFrom : self.fiatFrom
            let toAlpha: CGFloat = arriving ? 1.0 : 0.0
            let fromAlpha = from?.alpha ?? (1.0 - toAlpha)
            let alpha = fromAlpha + (toAlpha - fromAlpha) * p
            if self.timing.reduced {
                return SymbolState(drop: 0.0, tilt: 0.0, blur: 0.0, alpha: alpha)
            }
            let tail = max(0.0, elapsed - 0.3)
            let fromDrop = from?.drop ?? (arriving ? 16.0 : 0.0)
            let toDrop: CGFloat = arriving ? 0.0 : 16.0
            return SymbolState(
                drop: fromDrop + (toDrop - fromDrop) * p,
                tilt: CGFloat(20.0 * sin(2.0 * .pi * 1.6 * tail) * exp(-tail / 0.5)) * .pi / 180.0
                    + (from?.tilt ?? 0.0) * (1.0 - p),
                blur: 6.0 * sin(.pi * alpha),
                alpha: alpha
            )
        }
    }

    private let canvas = WalletSendAmountCanvas(frame: .zero)
    private let caretView = UIView()
    private static let caretBlinkAnimationKey = "walletSendCaretBlink"
    private static let inputRefusalAnimationKey = "walletSendInputRefusal"
    private static let symbolTransitionKey = "walletSendSymbolTransition"
    private static let symbolPulseKey = "walletSendSymbolPulse"
    private let motion = WalletSendAmountMotion(liquid: true)
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var opening: WalletSendAmountIntro?
    private var diamondIsExpanded = false
    var openingInterrupted: (() -> Void)?
    private var previousMode: WalletSendInputMode?
    private var previousText = ""
    private var layoutFrom: Layout?
    private var layoutTo: Layout?
    private var currentLayout: Layout?
    private var visible = false
    private var isApplicationInForeground = UIApplication.shared.applicationState != .background
    private var updating = false
    private var rendering = false
    private var nativeInteraction = false
    private var symbolTransition: SymbolTransition?
    private var placeholder: NSAttributedString?
    private var previousSelection: NSRange?
    private var availableWidth: CGFloat = 0.0
    private var frameDuration = 1.0 / 120.0
    private(set) var motionTiming: WalletSendAmountMotionTiming?

    private var isSwitchingSymbols: Bool {
        guard let transition = self.symbolTransition else { return false }
        return transition.timing.progress(at: CACurrentMediaTime()) < 1.0
    }

    override var usesAnimatedPresentation: Bool { return true }
    private var hasTransferredDiamond = false

    func updateOpening(_ value: WalletSendAmountIntro?) {
        let wasOpening = self.opening != nil
        guard value != nil || wasOpening else { return }
        self.opening = value
        if value != nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        if wasOpening != (value != nil) {
            self.resetCaretBlink()
        }
        guard self.currentLayout != nil, self.canvas.isAvailable else { return }
        if value != nil || self.motion.isAnimating(at: CACurrentMediaTime()) {
            self.renderFrame()
            self.setNativeTextVisible(false)
            if value == nil { self.startMotionDisplayLinkIfNeeded() }
        } else {
            self.finishMotion()
        }
        if value == nil {
            (self.gramIcon.view as? InteractiveDiamondComponent.View)?.updateOpeningScale(nil)
            self.layer.zPosition = self.diamondIsExpanded ? 1.0 : 0.0
        }
    }

    private func startMotionDisplayLinkIfNeeded() {
        guard self.displayLink == nil, self.opening == nil else { return }
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] duration in
            guard let self else { return }
            self.frameDuration += (Double(duration) - self.frameDuration) * 0.3
            self.renderFrame()
        })
    }

    func spinForTransfer() {
        guard !self.hasTransferredDiamond, self.isApplicationInForeground,
              let diamond = self.gramIcon.view as? InteractiveDiamondComponent.View,
              diamond.window != nil else { return }
        Haptics.hit(0.95)
        diamond.spin(-10.0, decay: 0.9)
    }

    func takeTransferDiamond(spinStartedAt: CFTimeInterval?) -> WalletSendTransferAnimationSource? {
        guard !self.hasTransferredDiamond, self.mode == .gram,
              let diamond = self.gramIcon.view as? InteractiveDiamondComponent.View,
              let source = WalletSendTransferAnimationSource.capture(diamond: diamond, width: 34.0, spinStartedAt: spinStartedAt) else { return nil }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        self.stopSymbolAnimations()
        self.hasTransferredDiamond = true
        self.gramIcon = ComponentView<Empty>()
        diamond.prepareForWalletTransfer()
        return source
    }
    override var gramAnimationSize: CGSize { return CGSize(width: 96.0, height: 96.0) }
    override var fiatSymbolFont: UIFont { return Font.with(size: 34.0, design: .round, weight: .bold, traits: [.alternateDollarSign]) }

    override var isUserInteractionEnabled: Bool {
        didSet {
            if !self.isUserInteractionEnabled {
                self.stopInputRefusal()
            }
            self.updateDiamondVisibility()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.canvas.isHidden = true
        self.canvas.onFrameReady = { [weak self] in
            guard let self, self.visible, self.isApplicationInForeground, self.window != nil, !self.nativeInteraction else { return }
            self.setNativeTextVisible(false)
            self.textField.displaysNativeCaret = self.opening == nil && !self.motion.isAnimating(at: CACurrentMediaTime())
        }
        self.contentView.addSubview(self.canvas)
        self.caretView.isUserInteractionEnabled = false
        self.caretView.accessibilityElementsHidden = true
        self.caretView.layer.cornerRadius = 1.5
        self.caretView.isHidden = true
        self.contentView.addSubview(self.caretView)
        self.textField.usesCustomCaret = true
        self.textField.interactionBegan = { [weak self] in
            self?.openingInterrupted?()
            self?.nativeInteraction = true
            self?.finishMotion()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.stopInputRefusal()
            self.stopSymbolAnimations()
            self.finishMotion()
        } else {
            self.updateDiamondVisibility()
            self.setNeedsLayout()
        }
    }

    @objc private func applicationWillEnterForeground() {
        self.isApplicationInForeground = true
        self.updateDiamondVisibility()
        self.setNeedsLayout()
        self.updateCaretAppearance()
    }

    @objc private func applicationWillResignActive() {
        self.stopInputRefusal()
    }

    @objc private func applicationDidEnterBackground() {
        self.isApplicationInForeground = false
        self.stopInputRefusal()
        self.canvas.isRenderingEnabled = false
        self.stopSymbolAnimations()
        self.finishMotion()
    }

    @objc private func reduceMotionChanged() {
        if UIAccessibility.isReduceMotionEnabled {
            self.layer.removeAnimation(forKey: Self.inputRefusalAnimationKey)
        }
        self.stopSymbolAnimations()
        self.finishMotion()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isHidden, self.alpha > 0.01, self.isUserInteractionEnabled,
           let diamond = self.gramIcon.view as? InteractiveDiamondComponent.View,
           let hit = diamond.hitTest(diamond.convert(point, from: self), with: event) {
            return hit
        }
        if event?.type == .touches, self.point(inside: point, with: event) {
            self.openingInterrupted?()
            self.nativeInteraction = true
            self.finishMotion()
        }
        return super.hitTest(point, with: event)
    }

    override func update(
        mode: WalletSendInputMode, amount: Int64, rate: Double?, fiatCurrency: WalletContext.FiatCurrency,
        dateTimeFormat: PresentationDateTimeFormat, theme: PresentationTheme,
        isVisible: Bool, transition: ComponentTransition
    ) {
        self.updating = true
        defer { self.updating = false }
        let previousCaretColor = self.caretView.layer.presentation()?.backgroundColor ?? self.caretView.layer.backgroundColor
        let modeChanged = mode != self.mode
        if !isVisible {
            self.stopInputRefusal()
        }
        self.visible = isVisible
        if !isVisible { self.stopSymbolAnimations() }
        self.canvas.prepareGlyphs(separators: dateTimeFormat.decimalSeparator + dateTimeFormat.groupingSeparator, currencyCode: fiatCurrency.code)
        self.canvas.isRenderingEnabled = isVisible && self.isApplicationInForeground
        super.update(mode: mode, amount: amount, rate: rate, fiatCurrency: fiatCurrency, dateTimeFormat: dateTimeFormat, theme: theme, isVisible: isVisible, transition: .immediate)
        self.placeholder = self.textField.attributedPlaceholder
        self.layoutIfNeeded()
        if modeChanged, isVisible, self.window != nil, let previousCaretColor, let timing = self.motionTiming {
            let animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.fromValue = previousCaretColor
            animation.toValue = self.textField.caretColor.cgColor
            animation.duration = timing.duration
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.8, 0.45, 1.0)
            self.caretView.layer.add(animation, forKey: "backgroundColor")
        }
        if !isVisible {
            self.finishMotion()
        }
    }

    override func updateGramIcon(theme: PresentationTheme, isVisible: Bool, transition: ComponentTransition) {
        guard !self.hasTransferredDiamond else { return }
        let _ = self.gramIcon.update(
            transition: .immediate,
            component: AnyComponent(InteractiveDiamondComponent(
                size: self.gramAnimationSize,
                diamondWidth: 34.0,
                isVisible: isVisible && self.isApplicationInForeground && (self.mode == .gram || self.previousMode == .gram || self.isSwitchingSymbols),
                theme: theme
            )),
            environment: {},
            containerSize: self.gramAnimationSize
        )
        if let view = self.gramIcon.view as? InteractiveDiamondComponent.View, view.superview == nil {
            self.contentView.addSubview(view)
            view.layer.zPosition = 1.0
            for gesture in self.gestureRecognizers ?? [] where gesture is UITapGestureRecognizer {
                gesture.require(toFail: view.pressGesture)
            }
            view.onExpansionChanged = { [weak self, weak view] expanded in
                guard let self else { return }
                self.diamondIsExpanded = expanded
                self.layer.zPosition = expanded || self.opening != nil ? 1.0 : 0.0
                if expanded {
                    self.openingInterrupted?()
                    view?.layer.removeAnimation(forKey: Self.symbolPulseKey)
                }
            }
        }
        self.updateDiamondVisibility()
    }

    override func inputAccepted(_ insertedText: String) {
        guard self.visible, UIApplication.shared.applicationState == .active, self.window != nil else { return }
        let velocity: Float
        if insertedText.isEmpty {
            velocity = 6.5
        } else if let digit = insertedText.last(where: { $0.wholeNumberValue != nil })?.wholeNumberValue {
            velocity = -(5.5 + 0.25 * Float(digit))
        } else {
            velocity = -3.5
        }
        if self.mode == .gram {
            (self.gramIcon.view as? InteractiveDiamondComponent.View)?.spin(velocity, decay: 0.7)
        }
        self.pulseSymbols(at: CACurrentMediaTime())
    }

    override func willApplyText(_ text: String, selection: NSRange?) {
        if text != (self.textField.text ?? "") || (selection != nil && selection != self.textField.selectionRange) {
            self.nativeInteraction = false
            self.resetCaretBlink()
        }
        guard self.previousMode != nil, self.visible, self.window != nil else { return }
        self.textField.displaysNativeCaret = false
    }

    override func setAmount(_ amount: Int64) {
        super.setAmount(amount)
        if !self.updating { self.layoutIfNeeded() }
    }

    @discardableResult
    override func insertText(_ text: String) -> Bool {
        let accepted = super.insertText(text)
        if accepted { self.layoutIfNeeded() }
        return accepted
    }

    @discardableResult
    override func deleteBackward() -> Bool {
        let accepted = super.deleteBackward()
        if accepted { self.layoutIfNeeded() }
        return accepted
    }

    override func inputRejected() {
        guard self.visible, UIApplication.shared.applicationState == .active, self.window != nil,
              self.isUserInteractionEnabled, self.isInputActive else { return }
        
        Haptics.refuse()

        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let initialOffset: CGFloat
        if self.layer.animation(forKey: Self.inputRefusalAnimationKey) != nil {
            initialOffset = (self.layer.presentation()?.transform.m41 ?? self.layer.transform.m41) - self.layer.transform.m41
        } else {
            initialOffset = 0.0
        }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = (0 ... 60).map { step -> NSNumber in
            let t = CGFloat(step) / 60.0
            let carry = max(0.0, 1.0 - 6.0 * t)
            let x = 9.0 * sin(6.0 * .pi * t) * (1.0 - t) + initialOffset * carry * carry
            return NSNumber(value: Double(x))
        }
        animation.duration = 0.42
        animation.calculationMode = .linear
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isAdditive = true
        self.layer.add(animation, forKey: Self.inputRefusalAnimationKey)
    }

    private func stopInputRefusal() {
        Haptics.cancelRefusal()
        self.layer.removeAnimation(forKey: Self.inputRefusalAnimationKey)
    }

    override func textFieldDidChangeSelection(_ textField: UITextField) {
        super.textFieldDidChangeSelection(textField)
        if !self.isApplyingText && !self.rendering && !self.updating,
           self.previousText == (textField.text ?? ""), self.previousSelection != self.textField.selectionRange {
            self.nativeInteraction = true
            self.resetCaretBlink()
            self.finishMotion()
        }
    }

    override func textFieldDidBeginEditing(_ textField: UITextField) {
        super.textFieldDidBeginEditing(textField)
        self.resetCaretBlink()
        self.finishMotion()
    }

    override func textFieldDidEndEditing(_ textField: UITextField) {
        (self.gramIcon.view as? InteractiveDiamondComponent.View)?.cancelInteraction()
        self.stopInputRefusal()
        self.finishMotion()
        super.textFieldDidEndEditing(textField)
    }

    override func layoutSubviews() {
        guard !self.rendering else { return }
        self.rendering = true
        defer { self.rendering = false }
        let now = CACurrentMediaTime()
        let sourceLayout = self.presentationLayout(at: now)
        self.gramIcon.view?.transform = .identity
        self.fiatIcon.view?.transform = .identity
        super.layoutSubviews()
        guard self.dateTimeFormat != nil else { return }

        let rawText = self.textField.text ?? ""
        let textLayout = self.amountTextLayout(rawText.isEmpty ? "0" : rawText)
        let attributedText = rawText.isEmpty ? (self.placeholder ?? textLayout.attributedText) : textLayout.attributedText
        self.textField.layoutIfNeeded()
        let caret = self.textField.nativeCaretRect(for: self.textField.beginningOfDocument)
        let hasCaretGeometry = !caret.isNull && !caret.isInfinite && caret.height > 0.0
        let textRect = self.textField.isEditing ? self.textField.editingRect(forBounds: self.textField.bounds) : self.textField.textRect(forBounds: self.textField.bounds)
        let baseline = self.textField.frame.minY + self.textField.amountTextBaseline(font: self.integralFont)
        let origin = CGPoint(x: self.textField.frame.minX + (hasCaretGeometry ? caret.minX : textRect.minX), y: baseline)
        var glyphs = WalletSendAmountGlyph.text(attributedText, origin: origin, group: .integer)
        let decimal = self.dateTimeFormat?.decimalSeparator ?? "."
        let fractionOffset = (attributedText.string as NSString).range(of: decimal).location
        var offset = 0
        for i in glyphs.indices {
            if fractionOffset != NSNotFound && offset >= fractionOffset { glyphs[i].group = .fraction }
            offset += glyphs[i].text.utf16.count
        }
        for position in textLayout.groupingPositions {
            glyphs += WalletSendAmountGlyph.text(textLayout.groupingSeparator, origin: CGPoint(x: origin.x + position - textLayout.groupingSeparatorSize.width, y: baseline), group: .grouping)
        }
        if let suffixView = self.suffix.view {
            glyphs += walletSendAmountComponentGlyphs(suffixView, origin: suffixView.frame.origin)
        }
        let selectedCaret = self.textField.amountCaretRect(for: self.textField.selectedTextRange?.end ?? self.textField.beginningOfDocument)
        let targetLayout = Layout(
            width: self.contentView.bounds.width, height: self.contentView.bounds.height,
            gram: self.gramIcon.view?.frame ?? .zero, fiat: self.fiatIcon.view?.frame ?? .zero,
            caret: selectedCaret.offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY)
        )
        let modeChanged = self.previousMode != nil && self.previousMode != self.mode
        if modeChanged {
            self.resetCaretBlink()
        }
        let sizeChanged = self.availableWidth != self.bounds.width
        self.availableWidth = self.bounds.width
        if glyphs != self.motion.target {
            // Focus and initial layout can refine positions without changing
            // the amount. Only content changes should start a glyph transition.
            let contentChanged = self.previousText != rawText || modeChanged || glyphs.count != self.motion.target.count
                || zip(glyphs, self.motion.target).contains { lhs, rhs in
                    lhs.text != rhs.text || lhs.font != rhs.font || lhs.color != rhs.color || lhs.group != rhs.group
                }
            let mayAnimate = contentChanged && self.previousMode != nil && self.visible && self.isApplicationInForeground && self.window != nil && self.canvas.isAvailable && !sizeChanged && (self.textField.selectionRange?.length ?? 0) == 0
            let oldValue = Double(self.previousText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let newValue = Double(rawText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let timing = mayAnimate ? WalletSendAmountMotionTiming(spin: modeChanged, up: newValue >= oldValue, start: now) : nil
            self.layoutFrom = sourceLayout ?? targetLayout
            self.layoutTo = targetLayout
            self.motion.update(glyphs, width: targetLayout.width, timing: timing, at: now, frameDuration: self.frameDuration,
                fromPlaceholder: self.previousText.isEmpty && !rawText.isEmpty && !modeChanged)
            self.motionTiming = timing
            if modeChanged {
                self.switchSymbols(timing: timing, at: now)
            } else if self.previousMode == nil {
                self.stopSymbolAnimations()
            }
        } else if self.previousSelection != self.textField.selectionRange {
            self.motion.finish()
        }
        self.previousText = rawText
        self.previousMode = self.mode
        self.previousSelection = self.textField.selectionRange
        if self.motion.isAnimating(at: now), self.visible, !sizeChanged {
            self.textField.displaysNativeCaret = false
            self.renderFrame(at: now)
            self.setNativeTextVisible(false)
            self.startMotionDisplayLinkIfNeeded()
        } else {
            self.layoutTo = targetLayout
            self.currentLayout = targetLayout
            self.finishMotion()
        }
    }

    private func setNativeTextVisible(_ visible: Bool) {
        let wasRendering = self.rendering
        self.rendering = true
        defer { self.rendering = wasRendering }
        let visible = !self.canvas.isAvailable || (self.opening == nil && (visible || !self.canvas.hasFrame))
        if !visible { self.textField.displaysNativeCaret = false }
        self.textField.rendersText = visible
        if let placeholder = self.placeholder {
            let text = NSMutableAttributedString(attributedString: placeholder)
            if !visible { text.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: text.length)) }
            self.textField.attributedPlaceholder = text
        }
        self.suffix.view?.alpha = visible ? 1.0 : 0.0
        self.canvas.isHidden = visible
        if visible {
            self.textField.layoutIfNeeded()
            self.textField.displaysNativeCaret = true
            self.textField.layoutIfNeeded()
        }
    }

    private func presentationLayout(at time: Double) -> Layout? {
        if let timing = self.motion.timing, let from = self.layoutFrom, let to = self.layoutTo {
            var layout = from.interpolate(to: to, progress: timing.layoutProgress(at: time))
            layout.width += self.motion.widthAdjustment(at: time)
            layout.caret.origin.x = self.motion.caretPosition(at: time, fromX: from.caret.midX, toX: to.caret.midX) - layout.caret.width / 2.0
            return layout
        }
        return self.currentLayout
    }

    private func renderFrame(at now: Double = CACurrentMediaTime()) {
        guard self.opening != nil || self.motion.isAnimating(at: now), let layout = self.presentationLayout(at: now) else {
            self.finishMotion()
            return
        }
        self.currentLayout = layout
        UIView.performWithoutAnimation {
            self.apply(layout: layout)
            self.drawText(layout: layout, at: now)
            self.contentView.bringSubviewToFront(self.canvas)
            self.contentView.bringSubviewToFront(self.caretView)
            self.updateCaretAppearance()
        }
    }

    private func drawText(layout: Layout, at now: Double) {
        self.canvas.isRenderingEnabled = self.visible && self.isApplicationInForeground
        // Keep the drawable size fixed throughout a transition; centering is
        // owned by contentView, so no GPU surface needs resizing every frame.
        let width = ceil(max(self.bounds.width, layout.width, self.layoutFrom?.width ?? 0, self.layoutTo?.width ?? 0) / 64.0) * 64.0
        self.canvas.frame = CGRect(x: -32.0, y: -32.0, width: width + 64.0, height: layout.height + 64.0)
        self.canvas.frameDuration = self.frameDuration
        let frame = self.motion.frame(at: now, frameDuration: self.frameDuration)
        var shift: CGFloat = 0.0
        var alpha: CGFloat = 1.0
        var reveal = SIMD2<Float>.zero
        if let opening = self.opening, opening.progress < 1.0 {
            let left = frame.map { $0.glyph.leadingEdge }.min() ?? 0.0
            let right = frame.map { $0.glyph.leadingEdge + $0.glyph.width }.max() ?? 0.0
            shift = (layout.width / 2.0 - 64.0 - (left + right) / 2.0) * (1.0 - opening.progress)
            alpha = min(1.0, max(0.0, opening.progress) / 0.08)
            let edge = layout.width / 2.0 + (layout.gram.midX - layout.width / 2.0) * opening.progress + 32.0
            reveal = SIMD2(Float(edge - 4.0), Float(edge + 22.0))
        }
        let sprites = frame.map { sprite in
            var sprite = sprite
            sprite.glyph.position.x += 32.0 + shift
            sprite.glyph.position.y += 32.0
            sprite.alpha *= alpha
            return sprite
        }
        self.canvas.update(sprites: sprites, isAnimating: self.opening != nil || self.motion.isAnimating(at: now), reveal: reveal)
        self.updateDiamondRefraction(textOffset: shift)
    }

    private func updateDiamondRefraction(textOffset: CGFloat) {
        guard let diamond = self.gramIcon.view as? InteractiveDiamondComponent.View else { return }
        guard self.mode == .gram,
              let glyph = self.motion.target.first(where: { $0.group == .integer && $0.text.first?.wholeNumberValue != nil }),
              let mask = self.canvas.glyphMask(for: glyph) else {
            diamond.updateRefractionSource(nil)
            return
        }
        let rect = self.contentView.convert(mask.rect.offsetBy(dx: glyph.position.x + textOffset, dy: glyph.position.y), to: diamond)
            .offsetBy(dx: -diamond.bounds.midX, dy: -diamond.bounds.midY)
        diamond.updateRefractionSource(InteractiveDiamondComponent.RefractionSource(texture: mask.texture, uv: mask.uv, rect: rect))
    }

    private func resetCaretBlink() {
        self.caretView.layer.removeAnimation(forKey: Self.caretBlinkAnimationKey)
    }

    private func updateCaretAppearance() {
        guard self.visible, self.isApplicationInForeground, self.window != nil, self.isInputActive,
              self.textField.selectionRange?.length == 0, let layout = self.currentLayout,
              !layout.caret.isNull, !layout.caret.isInfinite, layout.caret.height > 0.0 else {
            self.caretView.isHidden = true
            self.resetCaretBlink()
            return
        }
        self.caretView.frame = layout.caret
        self.caretView.backgroundColor = self.textField.caretColor
        self.caretView.isHidden = false
        if let opening = self.opening, self.canvas.isAvailable, opening.caret < 1.0 {
            self.resetCaretBlink()
            self.caretView.alpha = opening.caret
            return
        }
        self.caretView.alpha = 1.0
        self.contentView.bringSubviewToFront(self.caretView)
        guard self.caretView.layer.animation(forKey: Self.caretBlinkAnimationKey) == nil else { return }

        let hold = 0.45
        let fade = 0.42
        let duration = (hold + fade) * 2.0
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0, 1.0, 0.0, 0.0, 1.0]
        animation.keyTimes = [0.0, hold / duration, (hold + fade) / duration, (hold * 2.0 + fade) / duration, 1.0].map { NSNumber(value: $0) }
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        animation.duration = duration
        animation.repeatCount = .infinity
        self.caretView.layer.add(animation, forKey: Self.caretBlinkAnimationKey)
    }

    private func apply(layout: Layout) {
        self.contentView.bounds = CGRect(x: 0.0, y: 0.0, width: layout.width, height: layout.height)
        self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        let scale = min(1.0, self.bounds.width / max(1.0, layout.width))
        self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        for (view, rect) in [(self.gramIcon.view, layout.gram), (self.fiatIcon.view, layout.fiat)] {
            guard let view else { continue }
            view.bounds = CGRect(origin: .zero, size: rect.size)
            if let opening = self.opening, self.canvas.isAvailable {
                view.center = CGPoint(x: layout.width / 2.0 + (rect.midX - layout.width / 2.0) * opening.progress,
                                      y: rect.midY + opening.lift)
            } else {
                view.center = CGPoint(x: rect.midX, y: rect.midY)
            }
        }
        (self.gramIcon.view as? InteractiveDiamondComponent.View)?.updateOpeningScale(self.canvas.isAvailable ? self.opening?.scale : nil)
        if self.opening != nil { self.layer.zPosition = 1.0 }
    }

    private func switchSymbols(timing: WalletSendAmountMotionTiming?, at now: Double) {
        guard let timing else {
            self.stopSymbolAnimations()
            return
        }
        var transition = SymbolTransition(timing: timing, toGram: self.mode == .gram)
        if let previous = self.symbolTransition {
            transition.gramFrom = previous.state(gram: true, at: now)
            transition.fiatFrom = previous.state(gram: false, at: now)
        }
        self.symbolTransition = transition
        self.updateDiamondVisibility()
        (self.gramIcon.view as? InteractiveDiamondComponent.View)?.spin(timing.up ? -9.0 : 9.0, decay: 0.8)

        for (view, gram) in [(self.gramIcon.view, true), (self.fiatIcon.view, false)] {
            guard let view else { continue }
            // Only the arriving symbol needs the settling tail. The hidden
            // diamond can stop drawing as soon as the fade is over.
            let arriving = gram == transition.toGram
            let duration = arriving ? transition.duration : timing.duration
            let count = Int(ceil(duration * 120.0))
            let states = (0 ... count).map { index in
                transition.state(gram: gram, at: timing.start + duration * Double(index) / Double(count))
            }
            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = states.map { NSValue(caTransform3D: $0.transform) }
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = states.map { NSNumber(value: Double($0.alpha)) }
            let blur = CAKeyframeAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            blur.values = states.map { NSNumber(value: Double($0.blur)) }
            let animations = timing.reduced ? [opacity] : [transform, opacity, blur]
            for animation in animations {
                animation.duration = duration
                animation.calculationMode = .linear
            }
            UIView.performWithoutAnimation {
                view.layer.transform = CATransform3DIdentity
                view.alpha = arriving ? 1.0 : 0.0
                if !timing.reduced, let filter = CALayer.blur() {
                    filter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                    view.layer.filters = [filter]
                }
            }
            let group = CAAnimationGroup()
            group.animations = animations
            group.duration = duration
            group.beginTime = view.layer.convertTime(timing.start, from: nil)
            group.timingFunction = CAMediaTimingFunction(name: .linear)
            if #available(iOS 15.0, *) {
                group.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: Float(UIScreen.main.maximumFramesPerSecond), preferred: Float(UIScreen.main.maximumFramesPerSecond))
            }
            group.completion = { [weak self, weak view] completed in
                guard let self, completed, self.symbolTransition?.timing.start == timing.start else { return }
                view?.layer.filters = nil
                if arriving {
                    self.symbolTransition = nil
                }
                self.updateDiamondVisibility()
            }
            view.layer.add(group, forKey: Self.symbolTransitionKey)
        }
        self.pulseSymbols(at: now)
    }

    private func pulseSymbols(at now: Double) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for view in [self.gramIcon.view, self.fiatIcon.view] {
            guard let view else { continue }
            if let diamond = view as? InteractiveDiamondComponent.View, diamond.isExpanded { continue }
            let fromScale = view.layer.presentation()?.sublayerTransform.m11 ?? 1.0
            let pulse = CAKeyframeAnimation(keyPath: "sublayerTransform")
            pulse.values = (0 ... 51).map { index in
                let t = CGFloat(index) / 51.0
                let scale = 1.0 + 0.14 * sin(.pi * t) * (1.0 - 0.3 * t)
                    + (fromScale - 1.0) * (1.0 - WalletSendAmountMotionTiming.ease(t))
                return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1.0))
            }
            pulse.duration = 0.42
            pulse.beginTime = view.layer.convertTime(now, from: nil)
            pulse.calculationMode = .linear
            view.layer.add(pulse, forKey: Self.symbolPulseKey)
        }
    }

    private func updateDiamondVisibility() {
        guard let diamond = self.gramIcon.view as? InteractiveDiamondComponent.View else { return }
        let visible = self.visible && self.isApplicationInForeground && self.window != nil
        diamond.isRenderingEnabled = visible && (self.mode == .gram || self.isSwitchingSymbols)
        diamond.isUserInteractionEnabled = visible && self.isUserInteractionEnabled && self.mode == .gram && !self.isSwitchingSymbols
    }

    private func stopSymbolAnimations() {
        self.symbolTransition = nil
        UIView.performWithoutAnimation {
            for (view, gram) in [(self.gramIcon.view, true), (self.fiatIcon.view, false)] {
                guard let view else { continue }
                view.layer.removeAnimation(forKey: Self.symbolTransitionKey)
                view.layer.removeAnimation(forKey: Self.symbolPulseKey)
                view.layer.transform = CATransform3DIdentity
                view.layer.sublayerTransform = CATransform3DIdentity
                view.layer.filters = nil
                view.alpha = (gram == (self.mode == .gram)) ? 1.0 : 0.0
            }
        }
        self.updateDiamondVisibility()
    }

    private func finishMotion() {
        let wasRendering = self.rendering
        self.rendering = true
        defer { self.rendering = wasRendering }
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.motion.finish()
        if !self.visible || self.window == nil || !self.isApplicationInForeground {
            self.caretView.layer.removeAnimation(forKey: "backgroundColor")
        }
        UIView.performWithoutAnimation {
            if let layout = self.layoutTo {
                self.currentLayout = layout
                self.apply(layout: layout)
                self.caretView.frame = layout.caret
            }
            if let layout = self.currentLayout, self.visible, self.isApplicationInForeground, self.window != nil {
                self.drawText(layout: layout, at: CACurrentMediaTime())
            }
            self.setNativeTextVisible(self.nativeInteraction || !self.visible || !self.isApplicationInForeground)
            self.textField.displaysNativeCaret = self.opening == nil || !self.canvas.isAvailable
            if let selection = self.textField.selectedTextRange, var layout = self.currentLayout {
                layout.caret = self.textField.amountCaretRect(for: selection.end).offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY)
                self.currentLayout = layout
                self.layoutTo = layout
            }
            self.previousSelection = self.textField.selectionRange
            self.updateCaretAppearance()
        }
        self.updateDiamondVisibility()
    }
}
