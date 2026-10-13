import Foundation
import UIKit
import Display
import ComponentFlow

final class WalletWordSuggestionsComponent: Component {
    typealias EnvironmentType = Empty

    static let height: CGFloat = 44.0
    static let notchHeight: CGFloat = 7.5

    let fieldIndex: Int
    let query: String
    let words: [String]
    let isInteractive: Bool
    let pulseId: Int
    let action: (String) -> Void

    init(
        fieldIndex: Int,
        query: String,
        words: [String],
        isInteractive: Bool = true,
        pulseId: Int = 0,
        action: @escaping (String) -> Void
    ) {
        self.fieldIndex = fieldIndex
        self.query = query
        self.words = Array(words.prefix(3))
        self.isInteractive = isInteractive
        self.pulseId = pulseId
        self.action = action
    }

    static func ==(lhs: WalletWordSuggestionsComponent, rhs: WalletWordSuggestionsComponent) -> Bool {
        return lhs.fieldIndex == rhs.fieldIndex
            && lhs.query == rhs.query
            && lhs.words == rhs.words
            && lhs.isInteractive == rhs.isInteractive
            && lhs.pulseId == rhs.pulseId
    }

    final class View: UIView, UIScrollViewDelegate {
        private struct ItemId: Hashable {
            let index: Int
            let word: String
        }

        private final class ItemButton: UIButton {
            private let backgroundLayer = SimpleShapeLayer()
            private let separatorLayer = SimpleLayer()

            var restingBackgroundColor: UIColor = .clear {
                didSet {
                    self.updateBackgroundColor()
                }
            }

            var touchesLeftEdge = false {
                didSet {
                    if self.touchesLeftEdge != oldValue {
                        self.setNeedsLayout()
                    }
                }
            }

            var touchesRightEdge = false {
                didSet {
                    if self.touchesRightEdge != oldValue {
                        self.setNeedsLayout()
                    }
                }
            }

            override var isHighlighted: Bool {
                didSet {
                    self.updateBackgroundColor()
                }
            }

            override init(frame: CGRect) {
                super.init(frame: frame)

                self.backgroundLayer.fillColor = UIColor.clear.cgColor
                self.layer.insertSublayer(self.backgroundLayer, at: 0)

                self.separatorLayer.backgroundColor = UIColor.white.withAlphaComponent(0.08).cgColor
                self.separatorLayer.opacity = 0.0
                self.layer.addSublayer(self.separatorLayer)
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            private func updateBackgroundColor() {
                self.backgroundLayer.fillColor = (self.isHighlighted
                    ? UIColor(rgb: 0x5a5a5e)
                    : self.restingBackgroundColor).cgColor
            }

            func updateDisplaysSeparator(_ displaysSeparator: Bool, transition: ComponentTransition) {
                transition.setAlpha(layer: self.separatorLayer, alpha: displaysSeparator ? 1.0 : 0.0)
            }

            override func layoutSubviews() {
                super.layoutSubviews()

                self.backgroundLayer.frame = self.bounds
                self.separatorLayer.frame = CGRect(
                    x: self.bounds.width - UIScreenPixel,
                    y: 0.0,
                    width: UIScreenPixel,
                    height: self.bounds.height
                )

                let edgeInset: CGFloat = 3.0
                let rect = CGRect(
                    x: edgeInset,
                    y: edgeInset,
                    width: self.bounds.width - edgeInset * 2.0,
                    height: self.bounds.height - edgeInset * 2.0
                )
                let leftRadius: CGFloat = self.touchesLeftEdge ? rect.height * 0.5 : 4.0
                let rightRadius: CGFloat = self.touchesRightEdge ? rect.height * 0.5 : 4.0

                let path = CGMutablePath()
                path.move(to: CGPoint(x: rect.minX + leftRadius, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - rightRadius, y: rect.minY))
                path.addArc(
                    tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY + rightRadius),
                    radius: rightRadius
                )
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rightRadius))
                path.addArc(
                    tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - rightRadius, y: rect.maxY),
                    radius: rightRadius
                )
                path.addLine(to: CGPoint(x: rect.minX + leftRadius, y: rect.maxY))
                path.addArc(
                    tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY - leftRadius),
                    radius: leftRadius
                )
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + leftRadius))
                path.addArc(
                    tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.minX + leftRadius, y: rect.minY),
                    radius: leftRadius
                )
                path.closeSubpath()
                self.backgroundLayer.path = path
            }
        }

        private static let itemFont = Font.semibold(14.0)

        private let blurView: BlurredBackgroundView
        private let backgroundLayer = SimpleShapeLayer()
        private let shadowLayer = SimpleLayer()
        private let scrollView = UIScrollView()
        private var itemButtons: [ItemId: ItemButton] = [:]

        private var component: WalletWordSuggestionsComponent?

        override init(frame: CGRect) {
            let backgroundColor = UIColor(rgb: 0x2c2c2e).withAlphaComponent(0.92)
            self.blurView = BlurredBackgroundView(color: backgroundColor, enableBlur: true)

            super.init(frame: frame)
            
            self.layer.allowsGroupOpacity = true

            self.disablesInteractiveTransitionGestureRecognizer = true
            self.disablesInteractiveKeyboardGestureRecognizer = true

            self.shadowLayer.shadowColor = UIColor.black.cgColor
            self.shadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.shadowLayer.shadowRadius = 15.0
            self.shadowLayer.shadowOpacity = 0.2

            self.backgroundLayer.fillColor = backgroundColor.cgColor
            self.blurView.layer.mask = self.backgroundLayer

            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.layer.cornerRadius = 16.0
            self.scrollView.layer.masksToBounds = true
            if #available(iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }

            self.layer.addSublayer(self.shadowLayer)
            self.addSubview(self.blurView)
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func adjustBackground(relativePositionX: CGFloat, transition: ComponentTransition) {
            self.updateBackground(
                size: self.bounds.size,
                relativePositionX: relativePositionX,
                transition: transition
            )
        }

        private func updateBackground(
            size: CGSize,
            relativePositionX: CGFloat,
            transition: ComponentTransition
        ) {
            guard size.width > 0.0, size.height > 0.0 else {
                return
            }

            let bodyMinY = WalletWordSuggestionsComponent.notchHeight
            let radius: CGFloat = 18.0
            let notchWidth: CGFloat = 19.0
            let notchBaseX = min(
                size.width - radius - notchWidth,
                max(radius, floor(relativePositionX - notchWidth / 2.0))
            )

            let path = CGMutablePath()
            path.move(to: CGPoint(x: radius, y: bodyMinY))
            path.addLine(to: CGPoint(x: notchBaseX, y: bodyMinY))
            path.addCurve(
                to: CGPoint(x: notchBaseX + 7.49968, y: bodyMinY - 5.32576),
                control1: CGPoint(x: notchBaseX + 2.10085, y: bodyMinY),
                control2: CGPoint(x: notchBaseX + 5.41005, y: bodyMinY - 3.11103)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 8.95665, y: bodyMinY - 6.61485),
                control1: CGPoint(x: notchBaseX + 8.2352, y: bodyMinY - 6.10531),
                control2: CGPoint(x: notchBaseX + 8.60297, y: bodyMinY - 6.49509)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 9.91544, y: bodyMinY - 6.61599),
                control1: CGPoint(x: notchBaseX + 9.29432, y: bodyMinY - 6.72919),
                control2: CGPoint(x: notchBaseX + 9.5775, y: bodyMinY - 6.72953)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 11.3772, y: bodyMinY - 5.32853),
                control1: CGPoint(x: notchBaseX + 10.2694, y: bodyMinY - 6.49707),
                control2: CGPoint(x: notchBaseX + 10.6387, y: bodyMinY - 6.10756)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + notchWidth, y: bodyMinY),
                control1: CGPoint(x: notchBaseX + 13.477, y: bodyMinY - 3.11363),
                control2: CGPoint(x: notchBaseX + 16.817, y: bodyMinY)
            )
            path.addLine(to: CGPoint(x: size.width - radius, y: bodyMinY))
            path.addArc(
                tangent1End: CGPoint(x: size.width, y: bodyMinY),
                tangent2End: CGPoint(x: size.width, y: bodyMinY + radius),
                radius: radius
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height - radius))
            path.addArc(
                tangent1End: CGPoint(x: size.width, y: size.height),
                tangent2End: CGPoint(x: size.width - radius, y: size.height),
                radius: radius
            )
            path.addLine(to: CGPoint(x: radius, y: size.height))
            path.addArc(
                tangent1End: CGPoint(x: 0.0, y: size.height),
                tangent2End: CGPoint(x: 0.0, y: size.height - radius),
                radius: radius
            )
            path.addLine(to: CGPoint(x: 0.0, y: bodyMinY + radius))
            path.addArc(
                tangent1End: CGPoint(x: 0.0, y: bodyMinY),
                tangent2End: CGPoint(x: radius, y: bodyMinY),
                radius: radius
            )
            path.closeSubpath()

            let frame = CGRect(origin: .zero, size: size)
            transition.setFrame(layer: self.shadowLayer, frame: frame)
            transition.setShadowPath(layer: self.shadowLayer, path: path)
            transition.setFrame(view: self.blurView, frame: frame)
            self.blurView.update(size: size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.backgroundLayer, frame: frame)
            transition.setShapeLayerPath(layer: self.backgroundLayer, path: path)
        }

        @objc private func itemPressed(_ sender: UIButton) {
            guard let component = self.component,
                  component.isInteractive,
                  component.words.indices.contains(sender.tag) else {
                return
            }
            component.action(component.words[sender.tag])
        }

        func update(
            component: WalletWordSuggestionsComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let resetScrollingPosition = self.component?.words != component.words
            let animatePulse = !component.isInteractive
                && component.pulseId != 0
                && self.component?.pulseId != component.pulseId
            self.component = component

            var itemWidths: [CGFloat] = []
            var contentWidth: CGFloat = 0.0
            for word in component.words {
                let textWidth = ceil((word as NSString).size(withAttributes: [.font: Self.itemFont]).width)
                let itemWidth = max(64.0, textWidth + 32.0)
                itemWidths.append(itemWidth)
                contentWidth += itemWidth
            }

            let width = min(availableSize.width, contentWidth)
            let size = CGSize(width: width, height: WalletWordSuggestionsComponent.height)
            let bodyHeight = WalletWordSuggestionsComponent.height - WalletWordSuggestionsComponent.notchHeight
            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(
                    x: 0.0,
                    y: WalletWordSuggestionsComponent.notchHeight,
                    width: width,
                    height: bodyHeight
                )
            )
            self.scrollView.contentSize = CGSize(width: contentWidth, height: bodyHeight)
            self.scrollView.alwaysBounceHorizontal = contentWidth > width
            if resetScrollingPosition {
                self.scrollView.contentOffset = .zero
            }

            var itemX: CGFloat = 0.0
            var validIds = Set<ItemId>()
            for index in component.words.indices {
                let word = component.words[index]
                let id = ItemId(index: index, word: word)
                validIds.insert(id)

                let button: ItemButton
                let isNew: Bool
                if let current = self.itemButtons[id] {
                    button = current
                    isNew = false
                } else {
                    button = ItemButton(type: .custom)
                    button.titleLabel?.font = Self.itemFont
                    button.addTarget(self, action: #selector(self.itemPressed(_:)), for: .touchUpInside)
                    self.itemButtons[id] = button
                    self.scrollView.addSubview(button)
                    isNew = true
                }

                let title = NSMutableAttributedString(
                    string: word,
                    attributes: [
                        .font: Self.itemFont,
                        .foregroundColor: UIColor(rgb: 0xb9b9ba),
                    ]
                )
                let queryLength = component.isInteractive
                    ? min((component.query as NSString).length, title.length)
                    : 0
                if queryLength > 0 {
                    title.addAttribute(
                        .foregroundColor,
                        value: UIColor.white,
                        range: NSRange(location: 0, length: queryLength)
                    )
                }
                button.tag = index
                button.setAttributedTitle(title, for: .normal)
                button.setAttributedTitle(title, for: .highlighted)
                button.setAttributedTitle(title, for: .disabled)
                button.isEnabled = component.isInteractive
                button.restingBackgroundColor = component.isInteractive && component.words.count > 1 && index == 0
                    ? UIColor(rgb: 0xffffff, alpha: 0.1)
                    : .clear
                button.touchesLeftEdge = index == component.words.startIndex
                button.touchesRightEdge = index == component.words.index(before: component.words.endIndex)
                button.updateDisplaysSeparator(
                    index != component.words.index(before: component.words.endIndex),
                    transition: isNew ? .immediate : transition
                )
                let buttonFrame = CGRect(x: itemX, y: 0.0, width: itemWidths[index], height: bodyHeight)
                if isNew {
                    button.frame = buttonFrame
                    button.alpha = 0.0
                    transition.setAlpha(view: button, alpha: 1.0)
                } else {
                    transition.setFrame(view: button, frame: buttonFrame)
                }
                button.accessibilityLabel = word
                var accessibilityTraits: UIAccessibilityTraits = component.isInteractive ? .button : .staticText
                if component.isInteractive && index == 0 {
                    accessibilityTraits.insert(.selected)
                }
                button.accessibilityTraits = accessibilityTraits
                if animatePulse && index == component.words.startIndex {
                    button.layoutIfNeeded()
                    button.titleLabel?.layer.animateKeyframes(
                        values: [1.0 as NSNumber, 1.04 as NSNumber, 1.0 as NSNumber],
                        duration: 0.2,
                        keyPath: "transform.scale",
                        timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue
                    )
                }

                itemX += itemWidths[index]
            }

            var removeIds: [ItemId] = []
            for (id, button) in self.itemButtons {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    button.isUserInteractionEnabled = false
                    transition.setAlpha(view: button, alpha: 0.0, completion: { [weak button] _ in
                        button?.removeFromSuperview()
                    })
                }
            }
            for id in removeIds {
                self.itemButtons.removeValue(forKey: id)
            }

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}
