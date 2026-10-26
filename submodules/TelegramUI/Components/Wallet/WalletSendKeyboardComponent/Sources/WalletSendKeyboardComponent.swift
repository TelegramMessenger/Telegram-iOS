import Foundation
import UIKit
import Display
import ComponentFlow
import BundleIconComponent
import MultilineTextComponent
import TelegramPresentationData

public final class WalletSendKeyboardComponent: Component {
    public enum Mode: Equatable {
        case decimal(separator: String)
        case numeric
    }

    public enum Action: Equatable {
        case insertText(String)
        case deleteBackward
    }

    let theme: PresentationTheme
    let safeInsets: UIEdgeInsets
    let isLandscape: Bool
    let minimumHeight: CGFloat
    let topInset: CGFloat?
    let mode: Mode
    let deleteTitle: String
    let isEnabled: Bool
    let action: (Action) -> Void

    public init(
        theme: PresentationTheme,
        safeInsets: UIEdgeInsets,
        isLandscape: Bool,
        minimumHeight: CGFloat = 0.0,
        topInset: CGFloat? = nil,
        mode: Mode,
        deleteTitle: String,
        isEnabled: Bool,
        action: @escaping (Action) -> Void
    ) {
        self.theme = theme
        self.safeInsets = safeInsets
        self.isLandscape = isLandscape
        self.minimumHeight = minimumHeight
        self.topInset = topInset
        self.mode = mode
        self.deleteTitle = deleteTitle
        self.isEnabled = isEnabled
        self.action = action
    }

    public static func ==(lhs: WalletSendKeyboardComponent, rhs: WalletSendKeyboardComponent) -> Bool {
        return lhs.theme === rhs.theme
            && lhs.safeInsets == rhs.safeInsets
            && lhs.isLandscape == rhs.isLandscape
            && lhs.minimumHeight == rhs.minimumHeight
            && lhs.topInset == rhs.topInset
            && lhs.mode == rhs.mode
            && lhs.deleteTitle == rhs.deleteTitle
            && lhs.isEnabled == rhs.isEnabled
    }

    private final class KeyTrackingGestureRecognizer: UIGestureRecognizer {
        private var trackedTouch: UITouch?
        private(set) var currentLocation: CGPoint = .zero
        var shouldBegin: ((CGPoint) -> Bool)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)

            guard self.trackedTouch == nil, let touch = touches.first else {
                for touch in touches {
                    self.ignore(touch, for: event)
                }
                return
            }
            for otherTouch in touches where otherTouch !== touch {
                self.ignore(otherTouch, for: event)
            }
            self.currentLocation = touch.location(in: self.view)
            guard self.shouldBegin?(self.currentLocation) == true else {
                self.state = .failed
                return
            }
            self.trackedTouch = touch
            self.state = .began
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesMoved(touches, with: event)
            guard self.state == .began || self.state == .changed,
                  let touch = self.trackedTouch, touches.contains(touch) else { return }
            self.currentLocation = touch.location(in: self.view)
            self.state = .changed
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesEnded(touches, with: event)
            guard self.state == .began || self.state == .changed,
                  let touch = self.trackedTouch, touches.contains(touch) else { return }
            self.currentLocation = touch.location(in: self.view)
            self.state = .ended
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            self.cancel()
        }

        func cancel() {
            if self.state == .began || self.state == .changed {
                self.state = .cancelled
            }
        }

        override func reset() {
            super.reset()
            self.trackedTouch = nil
            self.currentLocation = .zero
        }
    }

    private final class KeyButton: HighlightTrackingButton {
        private let numberText = ComponentView<Empty>()
        private let lettersText = ComponentView<Empty>()
        private var numberTextSize: CGSize = .zero
        private var lettersTextSize: CGSize = .zero
        private var icon: ComponentView<Empty>?
        private var keyAction: Action = .deleteBackward
        private var normalColor: UIColor = .clear
        private var pressedColor: UIColor = .clear
        private var usesAlphaHighlight = false
        private var repeatTimer: Foundation.Timer?
        private var isPressActive = false
        private var hasRepeatedDeletion = false

        var action: ((Action) -> Void)?

        override var isHighlighted: Bool {
            didSet {
                self.backgroundColor = self.isHighlighted ? self.pressedColor : self.normalColor
            }
        }

        override var isEnabled: Bool {
            didSet {
                if !self.isEnabled {
                    self.cancelPress()
                }
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.layer.cornerRadius = 12.0
            self.layer.cornerCurve = .continuous
            self.isExclusiveTouch = true
            self.isAccessibilityElement = true

            self.highligthedChanged = { [weak self] highlighted in
                self?.updateHighlightAlpha(highlighted)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.repeatTimer?.invalidate()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.cancelPress()
            }
        }

        func beginPress() {
            guard self.isEnabled else { return }
            self.isPressActive = true
            self.hasRepeatedDeletion = false
            self.isHighlighted = true
            self.highligthedChanged(true)
            if self.keyAction == .deleteBackward {
                self.scheduleRepeat(after: 0.5)
            }
        }

        func endPress() {
            let shouldPerformAction = self.isEnabled && self.isPressActive && !self.hasRepeatedDeletion
            self.cancelPress()
            if shouldPerformAction {
                self.action?(self.keyAction)
            }
        }

        private func scheduleRepeat(after delay: TimeInterval) {
            self.repeatTimer?.invalidate()
            let timer = Foundation.Timer(timeInterval: delay, repeats: false, block: { [weak self] _ in
                guard let self, self.isPressActive, self.isEnabled, self.window != nil else { return }
                self.hasRepeatedDeletion = true
                self.action?(self.keyAction)
                if self.isPressActive, self.isEnabled {
                    self.scheduleRepeat(after: 0.1)
                }
            })
            self.repeatTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func updateHighlightAlpha(_ highlighted: Bool) {
            if highlighted && self.usesAlphaHighlight {
                self.layer.removeAnimation(forKey: "opacity")
                self.alpha = 0.7
            } else if self.alpha != 1.0 {
                let previousAlpha = self.alpha
                self.alpha = 1.0
                self.layer.animateAlpha(from: previousAlpha, to: 1.0, duration: 0.2)
            }
        }

        func cancelPress() {
            self.repeatTimer?.invalidate()
            self.repeatTimer = nil
            self.isPressActive = false
            self.hasRepeatedDeletion = false
            self.isHighlighted = false
            self.highligthedChanged(false)
        }

        override func accessibilityActivate() -> Bool {
            guard self.isEnabled else { return false }
            self.action?(self.keyAction)
            return true
        }

        func update(action: Action, letters: String, size: CGSize, component: WalletSendKeyboardComponent) {
            if self.keyAction != action {
                self.cancelPress()
            }
            self.keyAction = action
            self.isEnabled = component.isEnabled
            self.accessibilityTraits = component.isEnabled ? [.keyboardKey] : [.keyboardKey, .notEnabled]

            let isDark = component.theme.overallDarkAppearance
            let textColor: UIColor = isDark ? .white : .black
            let isDecimal: Bool
            if case let .decimal(separator) = component.mode {
                isDecimal = action == .insertText(separator)
            } else {
                isDecimal = false
            }
            let hasBackground: Bool
            let number: String
            switch action {
            case let .insertText(text):
                number = text
                if let icon = self.icon {
                    icon.view?.removeFromSuperview()
                    self.icon = nil
                }
                self.accessibilityLabel = text
                hasBackground = !isDecimal
            case .deleteBackward:
                number = ""
                let icon = self.icon ?? ComponentView<Empty>()
                self.icon = icon
                let iconSize = icon.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(name: "Wallet/Backspace", tintColor: textColor)),
                    environment: {},
                    containerSize: size
                )
                if let iconView = icon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        iconView.isAccessibilityElement = false
                        iconView.accessibilityElementsHidden = true
                        self.addSubview(iconView)
                    }
                    iconView.frame = CGRect(
                        origin: CGPoint(
                            x: floorToScreenPixels((size.width - iconSize.width) / 2.0),
                            y: floorToScreenPixels((size.height - iconSize.height) / 2.0)
                        ),
                        size: iconSize
                    )
                }
                self.accessibilityLabel = component.deleteTitle
                hasBackground = false
            }
            self.numberTextSize = self.numberText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: number, font: Font.regular(22.0), textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 28.0)
            )
            if let numberTextView = self.numberText.view {
                if numberTextView.superview == nil {
                    numberTextView.isUserInteractionEnabled = false
                    numberTextView.isAccessibilityElement = false
                    numberTextView.accessibilityElementsHidden = true
                    self.addSubview(numberTextView)
                }
                numberTextView.isHidden = number.isEmpty
            }
            self.lettersTextSize = self.lettersText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: letters, attributes: [
                        .font: Font.medium(12.0),
                        .foregroundColor: textColor,
                        .kern: 2.0
                    ])),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 16.0)
            )
            if let lettersTextView = self.lettersText.view {
                if lettersTextView.superview == nil {
                    lettersTextView.isUserInteractionEnabled = false
                    lettersTextView.isAccessibilityElement = false
                    lettersTextView.accessibilityElementsHidden = true
                    self.addSubview(lettersTextView)
                }
                lettersTextView.isHidden = letters.isEmpty
            }
            self.normalColor = hasBackground ? (isDark ? UIColor(rgb: 0x6b6b6f) : .white) : .clear
            self.pressedColor = hasBackground ? (isDark ? UIColor(rgb: 0x8c8c90) : UIColor(rgb: 0xe9eaed)) : .clear
            self.usesAlphaHighlight = !hasBackground
            self.backgroundColor = self.isHighlighted ? self.pressedColor : self.normalColor
            self.updateHighlightAlpha(self.isHighlighted)

            let contentOffset: CGFloat = isDecimal || number == "0" ? 0.0 : -1.0
            let numberTextFrame = CGRect(
                x: floorToScreenPixels((size.width - self.numberTextSize.width) / 2.0),
                y: (component.isLandscape || number == "0"
                    ? floorToScreenPixels((size.height - self.numberTextSize.height) / 2.0)
                    : 5.0 + floorToScreenPixels((28.0 - self.numberTextSize.height) / 2.0)) + contentOffset,
                width: self.numberTextSize.width,
                height: self.numberTextSize.height
            )
            if let numberTextView = self.numberText.view {
                numberTextView.frame = numberTextFrame
            }
            if let lettersTextView = self.lettersText.view {
                lettersTextView.frame = CGRect(
                    x: component.isLandscape
                        ? numberTextFrame.maxX + 8.0
                        : floorToScreenPixels((size.width - self.lettersTextSize.width) / 2.0) + 1.0,
                    y: (component.isLandscape
                        ? floorToScreenPixels((size.height - self.lettersTextSize.height) / 2.0)
                        : 30.0 + floorToScreenPixels((16.0 - self.lettersTextSize.height) / 2.0) - UIScreenPixel) + contentOffset,
                    width: self.lettersTextSize.width,
                    height: self.lettersTextSize.height
                )
            }
        }
    }

    public final class View: UIView {
        private var buttons: [KeyButton?] = Array(repeating: nil, count: 12)
        private var component: WalletSendKeyboardComponent?
        private let keyTrackingGesture = KeyTrackingGestureRecognizer(target: nil, action: nil)
        private var highlightedButton: KeyButton?

        public override init(frame: CGRect) {
            super.init(frame: frame)

            self.layer.cornerRadius = 28.0
            self.layer.cornerCurve = .continuous
            self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.clipsToBounds = true
            self.isExclusiveTouch = true

            self.keyTrackingGesture.shouldBegin = { [weak self] point in
                guard let self, self.component?.isEnabled == true else { return false }
                return self.button(at: point) != nil
            }
            self.keyTrackingGesture.addTarget(self, action: #selector(self.trackKey(_:)))
            self.addGestureRecognizer(self.keyTrackingGesture)

            NotificationCenter.default.addObserver(self, selector: #selector(self.cancelKeyPresses), name: UIApplication.willResignActiveNotification, object: nil)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else { return nil }
            // One touch session owns the whole keyboard, even when it crosses key boundaries.
            return result.isDescendant(of: self) ? self : result
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.cancelKeyPresses()
            }
        }

        private func button(at point: CGPoint) -> KeyButton? {
            guard self.bounds.contains(point) else { return nil }
            return self.buttons.compactMap { $0 }.first(where: {
                // Split the 6 pt gaps between adjacent keys without leaving dead zones.
                $0.isEnabled && $0.frame.insetBy(dx: -3.0, dy: -3.0).contains(point)
            })
        }

        private func updateHighlightedButton(at point: CGPoint) {
            let button = self.button(at: point)
            guard self.highlightedButton !== button else { return }
            self.highlightedButton?.cancelPress()
            self.highlightedButton = button
            button?.beginPress()
        }

        @objc private func trackKey(_ recognizer: KeyTrackingGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                self.updateHighlightedButton(at: recognizer.currentLocation)
            case .ended:
                self.updateHighlightedButton(at: recognizer.currentLocation)
                let button = self.highlightedButton
                self.highlightedButton = nil
                button?.endPress()
            case .cancelled, .failed:
                self.highlightedButton?.cancelPress()
                self.highlightedButton = nil
            default:
                break
            }
        }

        @objc public func cancelKeyPresses() {
            self.keyTrackingGesture.cancel()
            self.highlightedButton = nil
            for case let button? in self.buttons {
                button.cancelPress()
            }
        }

        func update(component: WalletSendKeyboardComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if let previousComponent = self.component, previousComponent.isLandscape != component.isLandscape || previousComponent.minimumHeight != component.minimumHeight || previousComponent.topInset != component.topInset || previousComponent.mode != component.mode {
                self.cancelKeyPresses()
            }
            self.component = component
            self.keyTrackingGesture.isEnabled = component.isEnabled
            if !component.isEnabled {
                self.cancelKeyPresses()
            }
            self.backgroundColor = UIColor(rgb: component.theme.overallDarkAppearance ? 0x2c2c2e : 0xe2e3e7)

            let keyHeight: CGFloat = component.isLandscape ? 30.0 : 48.0
            let spacing: CGFloat = 6.0
            let topInset: CGFloat = component.topInset ?? (component.isLandscape ? 5.0 : 16.0)
            let bottomInset: CGFloat = component.isLandscape ? 21.0 : 30.0
            let leftInset: CGFloat = 5.0 + component.safeInsets.left
            let rightInset: CGFloat = 5.0 + component.safeInsets.right
            let contentWidth = max(0.0, availableSize.width - leftInset - rightInset)
            let keyWidth: CGFloat = component.isLandscape ? 114.0 : max(0.0, (contentWidth - spacing * 2.0) / 3.0)
            let keysLeftInset = component.isLandscape ? leftInset + (contentWidth - keyWidth * 3.0 - spacing * 2.0) / 2.0 : leftInset
            let size = CGSize(width: availableSize.width, height: max(component.minimumHeight, topInset + keyHeight * 4.0 + spacing * 3.0 + bottomInset))
            let letters = ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ", "", "", ""]

            for index in 0 ..< self.buttons.count {
                let action: Action
                switch index {
                case 9:
                    guard case let .decimal(separator) = component.mode else {
                        if let button = self.buttons[index] {
                            button.cancelPress()
                            button.removeFromSuperview()
                            self.buttons[index] = nil
                        }
                        continue
                    }
                    action = .insertText(separator)
                case 10:
                    action = .insertText("0")
                case 11:
                    action = .deleteBackward
                default:
                    action = .insertText(String(index + 1))
                }
                let button: KeyButton
                if let current = self.buttons[index] {
                    button = current
                } else {
                    button = KeyButton(frame: .zero)
                    button.action = { [weak self] action in
                        guard let self, let component = self.component, component.isEnabled else { return }
                        component.action(action)
                    }
                    self.buttons[index] = button
                    self.addSubview(button)
                }
                let column = CGFloat(index % 3)
                let left = floorToScreenPixels(keysLeftInset + column * (keyWidth + spacing))
                let right = floorToScreenPixels(keysLeftInset + column * (keyWidth + spacing) + keyWidth)
                button.update(action: action, letters: letters[index], size: CGSize(width: right - left, height: keyHeight), component: component)
                transition.setFrame(view: button, frame: CGRect(
                    x: left,
                    y: topInset + CGFloat(index / 3) * (keyHeight + spacing),
                    width: right - left,
                    height: keyHeight
                ))
            }
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
