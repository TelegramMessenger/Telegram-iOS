import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import BundleIconComponent
import MultilineTextComponent
import MoreButtonNode
import AccountContext
import TelegramPresentationData
import LottieAnimationComponent

final class FullscreenControlsComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let title: String
    let isVerified: Bool
    let insets: UIEdgeInsets
    let statusBarStyle: StatusBarStyle
    var hasBack: Bool
    let backPressed: () -> Void
    let minimizePressed: () -> Void
    let morePressed: (ASDisplayNode, ContextGesture?) -> Void

    init(
        context: AccountContext,
        strings: PresentationStrings,
        title: String,
        isVerified: Bool,
        insets: UIEdgeInsets,
        statusBarStyle: StatusBarStyle,
        hasBack: Bool,
        backPressed: @escaping () -> Void,
        minimizePressed: @escaping () -> Void,
        morePressed: @escaping (ASDisplayNode, ContextGesture?) -> Void
    ) {
        self.context = context
        self.strings = strings
        self.title = title
        self.isVerified = isVerified
        self.insets = insets
        self.statusBarStyle = statusBarStyle
        self.hasBack = hasBack
        self.backPressed = backPressed
        self.minimizePressed = minimizePressed
        self.morePressed = morePressed
    }

    static func ==(lhs: FullscreenControlsComponent, rhs: FullscreenControlsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isVerified != rhs.isVerified {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.statusBarStyle != rhs.statusBarStyle {
            return false
        }
        if lhs.hasBack != rhs.hasBack {
            return false
        }
        return true
    }

    final class View: UIView {
        private let leftBackgroundView: BlurredBackgroundView
        private let rightBackgroundView: BlurredBackgroundView
        
        private let closeIcon = ComponentView<Empty>()
        private let leftButton = HighlightTrackingButton()
        
        private let titleClippingView = UIView()
        private let title = ComponentView<Empty>()
        private let credibility = ComponentView<Empty>()
        private let buttonTitle = ComponentView<Empty>()
        private let minimizeButton = ComponentView<Empty>()
        private let moreNode = MoreButtonNode(theme: defaultPresentationTheme, size: CGSize(width: 36.0, height: 36.0), encircled: false)
        
        private var displayTitle = true
        private var timer: Timer?
        
        private var component: FullscreenControlsComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.leftBackgroundView = BlurredBackgroundView(color: nil)
            self.rightBackgroundView = BlurredBackgroundView(color: nil)
            
            super.init(frame: frame)
            
            self.titleClippingView.clipsToBounds = true
            self.titleClippingView.isUserInteractionEnabled = false
            
            self.leftBackgroundView.clipsToBounds = true
            self.addSubview(self.leftBackgroundView)
            self.addSubview(self.leftButton)
            
            self.addSubview(self.titleClippingView)
            
            self.rightBackgroundView.clipsToBounds = true
            self.addSubview(self.rightBackgroundView)
            
            self.addSubview(self.moreNode.view)
            
            self.moreNode.updateColor(.white, transition: .immediate)
            
            self.leftButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    if let view = self.closeIcon.view {
                        view.layer.removeAnimation(forKey: "opacity")
                        view.alpha = 0.6
                    }
                    if let view = self.buttonTitle.view {
                        view.layer.removeAnimation(forKey: "opacity")
                        view.alpha = 0.6
                    }
                } else {
                    if let view = self.closeIcon.view {
                        view.alpha = 1.0
                        view.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    }
                    if let view = self.buttonTitle.view {
                        view.alpha = 1.0
                        view.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.leftButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
        }
        
        @objc private func closePressed() {
            guard let component = self.component else {
                return
            }
            component.backPressed()
        }
        
        @objc private func timerEvent() {
            self.timer?.invalidate()
            self.timer = nil
            
            self.displayTitle = false
            self.state?.updated(transition: .spring(duration: 0.3))
        }
        
        func update(component: FullscreenControlsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            let previousComponent = self.component
            self.component = component
            self.state = state
                        
            let sideInset: CGFloat = 16.0
            let leftBackgroundSize = CGSize(width: 30.0, height: 30.0)
            let rightBackgroundSize = CGSize(width: 72.0, height: 30.0)
            
            let backgroundColor: UIColor = component.statusBarStyle == .Black ? UIColor(white: 0.7, alpha: 0.35) : UIColor(white: 0.45, alpha: 0.25)
            let textColor: UIColor = component.statusBarStyle == .Black ? UIColor(rgb: 0x808080) : .white
            
            self.leftBackgroundView.updateColor(color: backgroundColor, transition: transition.containedViewLayoutTransition)
            self.rightBackgroundView.updateColor(color: backgroundColor, transition: transition.containedViewLayoutTransition)
                        
            let rightBackgroundFrame = CGRect(origin: CGPoint(x: availableSize.width - component.insets.right - sideInset - rightBackgroundSize.width, y: 0.0), size: rightBackgroundSize)
            self.rightBackgroundView.update(size: rightBackgroundSize, cornerRadius: rightBackgroundFrame.height / 2.0, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.rightBackgroundView, frame: rightBackgroundFrame)
            
            var isAnimatingTextTransition = false
            self.moreNode.updateColor(textColor, transition: .immediate)
            
            var additionalLeftWidth: CGFloat = 0.0
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.with(size: 13.0, design: .round, weight: .semibold), textColor: textColor)))),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: self.displayTitle ? 3.0 : -titleSize.width - 15.0, y: floorToScreenPixels((leftBackgroundSize.height - titleSize.height) / 2.0)), size: titleSize)
            if let view = self.title.view {
                if view.superview == nil {
                    self.titleClippingView.addSubview(view)
                }
                
                if !view.alpha.isZero && !self.displayTitle {
                    isAnimatingTextTransition = true
                }
                
                transition.setFrame(view: view, frame: titleFrame)
                transition.setAlpha(view: view, alpha: self.displayTitle ? 1.0 : 0.0)
            }
            
            let buttonTitleUpdated = (previousComponent?.hasBack ?? false) != component.hasBack
            let animationMultiplier = !component.hasBack ? -1.0 : 1.0
            if buttonTitleUpdated && !self.displayTitle {
                isAnimatingTextTransition = true
                
                if let view = self.buttonTitle.view, let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = view.frame
                    self.titleClippingView.addSubview(snapshotView)
                    snapshotView.layer.animatePosition(from: .zero, to: CGPoint(x: -(snapshotView.frame.width * 1.5) * animationMultiplier, y: 0.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                        snapshotView.removeFromSuperview()
                    })
                }
            }
                        
            let buttonTitleSize = self.buttonTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.hasBack ? component.strings.Common_Back : component.strings.Common_Close, font: Font.with(size: 13.0, design: .round, weight: .semibold), textColor: textColor)))),
                environment: {},
                containerSize: availableSize
            )
            
            if self.displayTitle {
                additionalLeftWidth += titleSize.width + 10.0
            } else {
                additionalLeftWidth += buttonTitleSize.width + 10.0
            }
            
            let buttonTitleFrame = CGRect(origin: CGPoint(x: self.displayTitle ? leftBackgroundSize.width + additionalLeftWidth + 3.0 : 3.0, y: floorToScreenPixels((leftBackgroundSize.height - buttonTitleSize.height) / 2.0)), size: buttonTitleSize)
            if let view = self.buttonTitle.view {
                if view.superview == nil {
                    self.titleClippingView.addSubview(view)
                }
                transition.setFrame(view: view, frame: buttonTitleFrame)
                
                if buttonTitleUpdated {
                    view.layer.animatePosition(from: CGPoint(x: (view.frame.width * 1.5) * animationMultiplier, y: 0.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                }
            }
            
            if component.isVerified {
                let credibilitySize = self.credibility.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(name: "Instant View/Verified", tintColor: textColor)),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.credibility.view {
                    if view.superview == nil {
                        view.alpha = 0.6
                        self.titleClippingView.addSubview(view)
                    }
                    let credibilityFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 2.0, y: floorToScreenPixels((leftBackgroundSize.height - credibilitySize.height) / 2.0)), size: credibilitySize)
                    transition.setFrame(view: view, frame: credibilityFrame)
                }
                if self.displayTitle {
                    additionalLeftWidth += credibilitySize.width + 2.0
                }
            }
                        
            var leftBackgroundTransition = transition
            if buttonTitleUpdated {
                leftBackgroundTransition = .spring(duration: 0.3)
            }
            
            let leftBackgroundFrame = CGRect(origin: CGPoint(x: sideInset + component.insets.left, y: 0.0), size: CGSize(width: leftBackgroundSize.width + additionalLeftWidth, height: leftBackgroundSize.height))
            self.leftBackgroundView.update(size: leftBackgroundFrame.size, cornerRadius: leftBackgroundSize.height / 2.0, transition: leftBackgroundTransition.containedViewLayoutTransition)
            leftBackgroundTransition.setFrame(view: self.leftBackgroundView, frame: leftBackgroundFrame)
            self.leftButton.frame = leftBackgroundFrame
            
            if isAnimatingTextTransition, self.titleClippingView.mask == nil {
                if let maskImage = generateGradientImage(size: CGSize(width: 42.0, height: 10.0), colors: [UIColor.clear, UIColor.black, UIColor.black, UIColor.clear], locations: [0.0, 0.1, 0.9, 1.0], direction: .horizontal) {
                    let maskView = UIImageView(image: maskImage.stretchableImage(withLeftCapWidth: 4, topCapHeight: 0))
                    self.titleClippingView.mask = maskView
                    maskView.frame = CGRect(origin: .zero, size: CGSize(width: self.titleClippingView.bounds.width, height: self.titleClippingView.bounds.height))
                }
            }
            
            transition.setFrame(view: self.titleClippingView, frame: CGRect(origin: CGPoint(x: sideInset + component.insets.left + leftBackgroundSize.height - 3.0, y: 0.0), size: CGSize(width: leftBackgroundFrame.width - leftBackgroundSize.height, height: leftBackgroundSize.height)))
            if let maskView = self.titleClippingView.mask {
                leftBackgroundTransition.setFrame(view: maskView, frame: CGRect(origin: .zero, size: CGSize(width: self.titleClippingView.bounds.width, height: self.titleClippingView.bounds.height)), completion: { _ in
                    self.titleClippingView.mask = nil
                })
            }
                
            let backButtonSize = self.closeIcon.update(
                transition: .immediate,
                component: AnyComponent(
                    LottieAnimationComponent(
                        animation: LottieAnimationComponent.AnimationItem(
                            name: "web_backToCancel",
                            mode: .animating(loop: false),
                            range: component.hasBack ? (0.5, 1.0) : (0.0, 0.5)
                        ),
                        colors: ["__allcolors__": textColor],
                        size: CGSize(width: 30.0, height: 30.0)
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.closeIcon.view {
                if view.superview == nil {
                    view.isUserInteractionEnabled = false
                    self.addSubview(view)
                }
                let buttonFrame = CGRect(origin: CGPoint(x: leftBackgroundFrame.minX, y: 0.0), size: backButtonSize)
                transition.setFrame(view: view, frame: buttonFrame)
            }
            
            let minimizeButtonSize = self.minimizeButton.update(
                transition: .immediate,
                component: AnyComponent(Button(
                    content: AnyComponent(
                        BundleIconComponent(name: "Instant View/MinimizeArrow", tintColor: textColor)
                    ),
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.minimizePressed()
                    }
                ).minSize(CGSize(width: 30.0, height: 30.0))),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            if let view = self.minimizeButton.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let buttonFrame = CGRect(origin: CGPoint(x: rightBackgroundFrame.minX + 2.0, y: 0.0), size: minimizeButtonSize)
                transition.setFrame(view: view, frame: buttonFrame)
            }
                
            transition.setFrame(view: self.moreNode.view, frame: CGRect(origin: CGPoint(x: rightBackgroundFrame.maxX - 42.0, y: -4.0), size: CGSize(width: 36.0, height: 36.0)))
            self.moreNode.action = { [weak self] node, gesture in
                guard let self, let component = self.component else {
                    return
                }
                component.morePressed(node, gesture)
            }
            
            if isFirstTime {
                let timer = Timer(timeInterval: 2.5, target: self, selector: #selector(self.timerEvent), userInfo: nil, repeats: false)
                self.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            }

            return CGSize(width: availableSize.width, height: leftBackgroundSize.height)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self {
                return nil
            }
            return result
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
