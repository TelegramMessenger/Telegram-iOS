import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

final class WalletSendButtonContentComponent: Component {
    let title: String
    let titlePrefix: String?
    let subtitle: String?
    let color: UIColor
    let isVisible: Bool
    let mode: WalletSendInputMode
    let dateTimeFormat: PresentationDateTimeFormat
    let timing: WalletSendAmountMotionTiming?

    init(title: String, titlePrefix: String?, subtitle: String?, color: UIColor, isVisible: Bool, mode: WalletSendInputMode, dateTimeFormat: PresentationDateTimeFormat, timing: WalletSendAmountMotionTiming?) {
        self.title = title
        self.titlePrefix = titlePrefix
        self.subtitle = subtitle
        self.color = color
        self.isVisible = isVisible
        self.mode = mode
        self.dateTimeFormat = dateTimeFormat
        self.timing = timing
    }

    static func ==(lhs: WalletSendButtonContentComponent, rhs: WalletSendButtonContentComponent) -> Bool {
        return lhs.title == rhs.title
            && lhs.titlePrefix == rhs.titlePrefix
            && lhs.subtitle == rhs.subtitle
            && lhs.color == rhs.color
            && lhs.isVisible == rhs.isVisible
            && lhs.mode == rhs.mode
            && lhs.dateTimeFormat == rhs.dateTimeFormat
            && lhs.timing == rhs.timing
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private var component: WalletSendButtonContentComponent?
        private var availableWidth: CGFloat = 0.0

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = true
            self.accessibilityTraits = .staticText
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletSendButtonContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previous = self.component
            self.availableWidth = availableSize.width
            var textTransition: ComponentTransition = .immediate
            if let previous = self.component, previous.isVisible, component.isVisible, self.window != nil,
               !UIAccessibility.isReduceMotionEnabled {
                if previous.title != component.title || previous.subtitle != component.subtitle {
                    textTransition = .easeInOut(duration: 0.22)
                } else {
                    textTransition = transition
                }
            }
            self.component = component
            self.accessibilityLabel = [component.title, component.subtitle].compactMap { $0 }.joined(separator: ", ")
            let now = CACurrentMediaTime()
            let sharedStart = component.timing.flatMap { now - $0.start < $0.duration ? $0.start : nil }
            let timing = WalletSendAmountMotionTiming(
                spin: previous != nil && previous?.mode != component.mode,
                up: component.timing?.up ?? true,
                start: sharedStart ?? now
            )

            // Measure at the normal font size, then fit long amounts without truncation.
            let textContainerSize = CGSize(width: 10000.0, height: availableSize.height)
            let titleSize = self.title.update(
                transition: textTransition,
                component: AnyComponent(WalletSendAnimatedTextComponent(
                    text: component.title,
                    numberPrefix: component.titlePrefix,
                    font: Font.semibold(17.0),
                    color: component.color,
                    dateTimeFormat: component.dateTimeFormat,
                    isVisible: component.isVisible,
                    timing: timing,
                    centered: true
                )),
                environment: {},
                containerSize: textContainerSize
            )
            let titleScale = min(1.0, availableSize.width / max(1.0, titleSize.width))

            var subtitleSize = CGSize.zero
            var subtitleScale: CGFloat = 1.0
            if let subtitle = component.subtitle ?? previous?.subtitle {
                let measuredSubtitleSize = self.subtitle.update(
                    transition: self.subtitle.view == nil ? .immediate : textTransition,
                    component: AnyComponent(WalletSendAnimatedTextComponent(
                        text: subtitle,
                        font: Font.medium(11.0),
                        color: component.color.withAlphaComponent(0.7),
                        dateTimeFormat: component.dateTimeFormat,
                        isVisible: component.isVisible && component.subtitle != nil,
                        timing: timing,
                        centered: true
                    )),
                    environment: {},
                    containerSize: textContainerSize
                )
                if component.subtitle != nil {
                    subtitleSize = measuredSubtitleSize
                    subtitleScale = min(1.0, availableSize.width / max(1.0, subtitleSize.width))
                }
            }

            let titleHeight = titleSize.height * titleScale
            let subtitleHeight = subtitleSize.height * subtitleScale
            let spacing: CGFloat = component.subtitle == nil ? 0.0 : 1.0
            let contentHeight = titleHeight + spacing + subtitleHeight
            let contentY = floorToScreenPixels((availableSize.height - contentHeight) / 2.0)
            if let titleView = self.title.view as? WalletSendAnimatedTextComponent.View {
                if titleView.superview == nil {
                    titleView.accessibilityElementsHidden = true
                    self.addSubview(titleView)
                    titleView.animationFrameUpdated = { [weak self, weak titleView] in
                        guard let self, let titleView else { return }
                        self.updateTextScale(titleView)
                    }
                }
                titleView.bounds = CGRect(origin: .zero, size: titleSize)
                textTransition.setPosition(view: titleView, position: CGPoint(x: availableSize.width / 2.0, y: contentY + titleHeight / 2.0))
                self.updateTextScale(titleView)
            }
            if let subtitleView = self.subtitle.view as? WalletSendAnimatedTextComponent.View {
                if subtitleView.superview == nil {
                    subtitleView.accessibilityElementsHidden = true
                    subtitleView.alpha = 0.0
                    self.addSubview(subtitleView)
                    subtitleView.animationFrameUpdated = { [weak self, weak subtitleView] in
                        guard let self, let subtitleView else { return }
                        self.updateTextScale(subtitleView)
                    }
                }
                if component.subtitle != nil {
                    // Lay out the hidden line before fading it in.
                    let layoutTransition: ComponentTransition = subtitleView.alpha == 0.0 ? .immediate : textTransition
                    subtitleView.bounds = CGRect(origin: .zero, size: subtitleSize)
                    layoutTransition.setPosition(view: subtitleView, position: CGPoint(x: availableSize.width / 2.0, y: contentY + titleHeight + spacing + subtitleHeight / 2.0))
                    self.updateTextScale(subtitleView)
                }
                textTransition.setAlpha(view: subtitleView, alpha: component.subtitle == nil ? 0.0 : 1.0)
            }

            // Keep the outer button content frame stable while its lines animate inside it.
            return availableSize
        }

        private func updateTextScale(_ view: WalletSendAnimatedTextComponent.View) {
            let scale = min(1.0, self.availableWidth / max(1.0, view.currentWidth))
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
