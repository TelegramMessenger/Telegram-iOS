import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AppBundle
import MoreHeaderButton

/// Renders one `NavigationBarComponent.Button`: a 44pt-tall tap target whose content dims to 0.6 while
/// highlighted. The caller resolves the content color (`navigationButtonContentColor`).
final class NavigationButtonComponent: Component {
    typealias EnvironmentType = NavigationButtonEnvironment

    let content: NavigationBarComponent.Button.Content
    let color: UIColor
    let isEnabled: Bool
    let pressed: (UIView) -> Void
    let contextAction: ((UIView, ContextGesture?) -> Void)?
    /// A node in the content is borrowed (`NavigationBarNodeLoan`): hosted only while lent, never its home.
    let borrowsNode: Bool

    init(
        content: NavigationBarComponent.Button.Content,
        color: UIColor,
        isEnabled: Bool,
        pressed: @escaping (UIView) -> Void,
        contextAction: ((UIView, ContextGesture?) -> Void)?,
        borrowsNode: Bool = false
    ) {
        self.content = content
        self.color = color
        self.isEnabled = isEnabled
        self.pressed = pressed
        self.contextAction = contextAction
        self.borrowsNode = borrowsNode
    }

    static func ==(lhs: NavigationButtonComponent, rhs: NavigationButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.borrowsNode != rhs.borrowsNode {
            return false
        }
        return true
    }

    private enum IconSource: Equatable {
        case bundle(String)
        case image(UIImage)
    }

    final class View: HighlightTrackingButton {
        private var textView: ImmediateTextView?

        private(set) var iconView: UIImageView?
        private var iconSource: IconSource?

        private var hostedNode: ASDisplayNode?
        /// Where the hosted node goes in this button, kept for when a loan of it ends.
        private var hostedNodeFrame = CGRect()

        private var customView: ComponentView<NavigationButtonEnvironment>?

        private(set) var moreButton: MoreHeaderButton?

        private var component: NavigationButtonComponent?
        private var currentColor: UIColor?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)

            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                var contentViews: [UIView] = [self.textView, self.customView?.view, self.iconView].compactMap { $0 }
                if let hostedNode = self.hostedNode, (hostedNode as? NavigationButtonCustomDisplayNode)?.isHighlightable ?? true {
                    contentViews.append(hostedNode.view)
                }
                if highlighted {
                    for view in contentViews {
                        view.alpha = 0.6
                    }
                } else {
                    for view in contentViews {
                        view.alpha = 1.0
                        view.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    }
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.component?.pressed(self)
        }

        /// Takes the hosted node back once its loan has ended (`NavigationBarNodeLoan.end`).
        func reclaimHostedNode() {
            guard let node = self.hostedNode, !NavigationBarNodeLoan.isLent(node) else {
                return
            }
            self.host(node)
        }

        /// Moves `node` into this button, unless that would take it out of the window it is in: this button is not
        /// in one yet (a new button for a new item, a capsule not yet on screen), and an animation the node runs would
        /// stop there (Lottie pauses a view that leaves its window). It then moves when this button enters the window,
        /// from wherever it is on screen, so it never leaves the window on the way.
        private func host(_ node: ASDisplayNode) {
            guard node.view.superview !== self else {
                return
            }
            if self.window == nil && node.view.window != nil {
                return
            }
            self.addSubnode(node)
            node.frame = self.hostedNodeFrame
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard self.window != nil, let node = self.hostedNode, let component = self.component else {
                return
            }
            // The node waited for this button to be on screen (`host`); a lent one belongs to the borrowing button. A
            // button the bar has replaced keeps its node as `hostedNode` but is no longer its home: put on screen with
            // an in-place change's leaving items, it would take the node out of the new button and away with it.
            if component.borrowsNode {
                if NavigationBarNodeLoan.isLent(node) {
                    self.host(node)
                }
            } else if !NavigationBarNodeLoan.isLent(node) && NavigationBarNodeLoan.isHome(self, of: node) {
                self.host(node)
            }
        }

        // A hosted node keeps its touches, so its descendants work (the chat avatar's long-press menu). The touches
        // they leave come up the responder chain rather than to the control, and press the button as
        // `NavigationButtonItemNode` did. A button node handles its own.
        private var forwardedTouchCount = 0

        private func isForwarded(_ touches: Set<UITouch>) -> Bool {
            guard let hostedNode = self.hostedNode, !(hostedNode is HighlightableButtonNode) else {
                return false
            }
            return touches.first?.view !== self
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            if self.isForwarded(touches) {
                if self.forwardedTouchCount == 0 {
                    self.highligthedChanged(true)
                }
                self.forwardedTouchCount += touches.count
                return
            }
            super.touchesBegan(touches, with: event)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            if self.isForwarded(touches) {
                return
            }
            super.touchesMoved(touches, with: event)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            if self.isForwarded(touches) {
                let previousCount = self.forwardedTouchCount
                self.forwardedTouchCount = max(0, self.forwardedTouchCount - touches.count)
                if previousCount != 0 && self.forwardedTouchCount == 0 {
                    self.highligthedChanged(false)
                    if self.isEnabled, let touch = touches.first, self.bounds.contains(touch.location(in: self)) {
                        self.pressed()
                    }
                }
                return
            }
            super.touchesEnded(touches, with: event)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            if self.isForwarded(touches) {
                let previousCount = self.forwardedTouchCount
                self.forwardedTouchCount = max(0, self.forwardedTouchCount - touches.count)
                if previousCount != 0 && self.forwardedTouchCount == 0 {
                    self.highligthedChanged(false)
                }
                return
            }
            super.touchesCancelled(touches, with: event)
        }

        func update(component: NavigationButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.isEnabled = component.isEnabled

            let environmentValue = environment[NavigationButtonEnvironment.self].value
            let color = component.color
            // Rebuilt on a color change, not on a new theme object: a host may recreate an equal theme every update.
            let colorUpdated = self.currentColor != color
            self.currentColor = color

            var textString: NSAttributedString?
            var iconSource: IconSource?
            var node: ASDisplayNode?
            var customComponent: AnyComponent<NavigationButtonEnvironment>?
            var isMore = false

            switch component.content {
            case let .text(title, isBold):
                if title == "___done" {
                    iconSource = .bundle("Navigation/Done")
                } else {
                    textString = NSAttributedString(string: title, font: isBold ? Font.bold(17.0) : Font.medium(17.0), textColor: color)
                }
            case .more:
                isMore = true
            case let .icon(imageName):
                iconSource = .bundle(imageName)
            case let .image(image):
                iconSource = .image(image)
            case let .node(nodeValue):
                node = nodeValue
            case let .custom(customComponentValue):
                customComponent = customComponentValue
            }

            var size = CGSize(width: 0.0, height: availableSize.height)

            if let textString {
                let textView: ImmediateTextView
                if let current = self.textView {
                    textView = current
                } else {
                    textView = ImmediateTextView()
                    textView.isUserInteractionEnabled = false
                    self.textView = textView
                    self.addSubview(textView)
                }

                textView.attributedText = textString
                let textSize = textView.updateLayout(availableSize)
                let textInset: CGFloat = 12.0
                size.width = max(44.0, textSize.width + textInset * 2.0)

                textView.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((availableSize.height - textSize.height) / 2.0)), size: textSize)
            } else if let textView = self.textView {
                self.textView = nil
                textView.removeFromSuperview()
            }

            if let iconSource {
                let iconView: UIImageView
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    iconView.isUserInteractionEnabled = false
                    self.iconView = iconView
                    self.addSubview(iconView)
                }
                if self.iconSource != iconSource || colorUpdated {
                    self.iconSource = iconSource
                    switch iconSource {
                    case let .bundle(imageName):
                        iconView.image = generateTintedImage(image: UIImage(bundleImageName: imageName), color: color)
                        iconView.tintColor = nil
                    case let .image(image):
                        iconView.image = image
                        iconView.tintColor = image.renderingMode == .alwaysTemplate ? color : nil
                    }
                }

                if let iconSize = iconView.image?.size {
                    size.width = max(44.0, iconSize.width)

                    iconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
            } else if let iconView = self.iconView {
                self.iconView = nil
                iconView.removeFromSuperview()
                self.iconSource = nil
            }

            if let node {
                let isLent = NavigationBarNodeLoan.isLent(node)
                let nodeSize = node.measure(availableSize)
                size.width = max(44.0, nodeSize.width)
                self.hostedNodeFrame = CGRect(origin: CGPoint(x: floor((size.width - nodeSize.width) / 2.0), y: floor((availableSize.height - nodeSize.height) / 2.0)), size: nodeSize)
                if self.hostedNode !== node {
                    if let hostedNode = self.hostedNode, hostedNode.view.superview === self {
                        hostedNode.view.removeFromSuperview()
                    }
                    self.hostedNode = node
                    if !component.borrowsNode && !isLent {
                        self.host(node)
                    }
                }
                if component.borrowsNode {
                    if isLent {
                        self.host(node)
                    }
                } else {
                    NavigationBarNodeLoan.setHome(self, of: node)
                }
                // A lent node is laid out by the button borrowing it.
                if node.view.superview === self {
                    node.frame = self.hostedNodeFrame
                }
            } else if let hostedNode = self.hostedNode {
                self.hostedNode = nil
                if hostedNode.view.superview === self {
                    hostedNode.view.removeFromSuperview()
                }
            }

            if let customComponent {
                var customTransition = transition
                let customView: ComponentView<NavigationButtonEnvironment>
                if let current = self.customView {
                    customView = current
                } else {
                    customTransition = .immediate
                    customView = ComponentView<NavigationButtonEnvironment>()
                    self.customView = customView
                }
                let customSize = customView.update(
                    transition: customTransition,
                    component: customComponent,
                    environment: {
                        environmentValue
                    },
                    containerSize: availableSize
                )
                if let customComponentView = customView.view {
                    if customComponentView.superview == nil {
                        // Taps and highlight belong to the button.
                        customComponentView.isUserInteractionEnabled = false
                        self.addSubview(customComponentView)
                    }
                    customTransition.setFrame(view: customComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: floor((availableSize.height - customSize.height) / 2.0)), size: customSize))
                }
                size.width = customSize.width
            } else if let customView = self.customView {
                self.customView = nil
                customView.view?.removeFromSuperview()
            }

            if isMore {
                let moreButton: MoreHeaderButton
                if let current = self.moreButton, !colorUpdated {
                    moreButton = current
                } else {
                    if let moreButton = self.moreButton {
                        moreButton.removeFromSupernode()
                        self.moreButton = nil
                    }

                    moreButton = MoreHeaderButton(color: color)
                    moreButton.isUserInteractionEnabled = true
                    moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: color)))
                    moreButton.onPressed = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.pressed(self)
                    }
                    moreButton.contextAction = { [weak self] _, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.contextAction?(self, gesture)
                    }
                    self.moreButton = moreButton
                    self.addSubnode(moreButton)
                }

                let buttonSize = CGSize(width: 44.0, height: 44.0)
                size.width = 44.0

                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: color)))

                moreButton.frame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
            } else if let moreButton = self.moreButton {
                self.moreButton = nil
                moreButton.removeFromSupernode()
            }

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
