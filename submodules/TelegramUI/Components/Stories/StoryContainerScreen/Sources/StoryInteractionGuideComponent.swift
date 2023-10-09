import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent

final class StoryInteractionGuideComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let action: () -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.action = action
    }

    static func ==(lhs: StoryInteractionGuideComponent, rhs: StoryInteractionGuideComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: StoryInteractionGuideComponent?
        private weak var state: EmptyComponentState?
        
        private let effectView: UIVisualEffectView
        private let containerView = UIView()
        private let titleLabel = ComponentView<Empty>()
        private let descriptionLabel = ComponentView<Empty>()
        private let guideItems = ComponentView<Empty>()
        private let proceedButton = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.effectView = UIVisualEffectView(effect: nil)
            
            super.init(frame: frame)
            
            self.addSubview(self.effectView)
            self.addSubview(self.containerView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func handleTap() {
            if let component = self.component {
                component.action()
            }
        }
        
        var didAnimateOut = false
        
        func animateIn() {
            self.didAnimateOut = false
            UIView.animate(withDuration: 0.2) {
                self.effectView.effect = UIBlurEffect(style: .dark)
            }
            self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.containerView.layer.animateScale(from: 0.85, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            guard !self.didAnimateOut else {
                return
            }
            self.didAnimateOut = true
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.containerView.layer.animateScale(from: 1.0, to: 1.1, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
        
        func update(component: StoryInteractionGuideComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 48.0
            
//TODO:localize
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Watching Stories", font: Font.semibold(20.0), textColor: .white, paragraphAlignment: .center)))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 146.0), size: titleSize)
            if let view = self.titleLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = titleFrame
            }
            
            let textSize = self.descriptionLabel.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(text: .plain(NSAttributedString(string: "You can use these gestures to control playback.", font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6), paragraphAlignment: .center)), maximumNumberOfLines: 0, lineSpacing: 0.2)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0), y: titleFrame.maxY + 7.0), size: textSize)
            if let view = self.descriptionLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = textFrame
            }
            
            let items: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "forward",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: "Go forward",
                            text: "Tap the screen",
                            animationName: "story_forward"
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "pause",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: "Pause and Seek",
                            text: "Hold and move sideways",
                            animationName: "story_pause"
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "back",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: "Go back",
                            text: "Tap the left edge",
                            animationName: "story_back"
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "move",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: "Move between stories",
                            text: "Swipe left or right",
                            animationName: "story_move"
                        )
                    )
                )
            ]
            
            let itemsSize = self.guideItems.update(
                transition: .immediate,
                component: AnyComponent(List(items)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let itemsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - itemsSize.width) / 2.0), y: textFrame.maxY + 40.0), size: itemsSize)
            if let view = self.guideItems.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = itemsFrame
            }
            
            let buttonSize = self.proceedButton.update(
                transition: .immediate,
                component: AnyComponent(Button(
                    content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Tap to keep watching", font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)))),
                    action: { [weak self] in
                        self?.handleTap()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: itemsFrame.maxY + 57.0), size: buttonSize)
            if let view = self.proceedButton.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = buttonFrame
            }
            
            let bounds = CGRect(origin: .zero, size: availableSize)
            self.effectView.frame = bounds
            self.containerView.frame = bounds
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class GuideItemComponent: Component {
    let context: AccountContext
    let title: String
    let text: String
    let animationName: String
    
    init(
        context: AccountContext,
        title: String,
        text: String,
        animationName: String
    ) {
        self.context = context
        self.title = title
        self.text = text
        self.animationName = animationName
    }

    static func ==(lhs: GuideItemComponent, rhs: GuideItemComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.animationName != rhs.animationName {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: GuideItemComponent?
        private weak var state: EmptyComponentState?
        
        private let animation = ComponentView<Empty>()
        private let titleLabel = ComponentView<Empty>()
        private let descriptionLabel = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: GuideItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 48.0
            
            let size = CGSize(width: availableSize.width, height: 90.0)
            let originX = availableSize.width / 2.0 - 110.0
            
            let animationSize = self.animation.update(
                transition: .immediate,
                component: AnyComponent(
                    LottieComponent(
                        content: LottieComponent.AppBundleContent(name: component.animationName),
                        color: .white,
                        placeholderColor: nil,
                        startingPosition: .begin,
                        size: CGSize(width: 60.0, height: 60.0),
                        renderingScale: UIScreen.main.scale,
                        loop: true
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let animationFrame = CGRect(origin: CGPoint(x: originX - 11.0, y: 15.0), size: animationSize)
            if let view = self.animation.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = animationFrame
            }
            
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .natural)))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: originX + 60.0, y: 25.0), size: titleSize)
            if let view = self.titleLabel.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = titleFrame
            }
            
            let textSize = self.descriptionLabel.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6), paragraphAlignment: .natural)), maximumNumberOfLines: 0)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            let textFrame = CGRect(origin: CGPoint(x: originX + 60.0, y: titleFrame.maxY + 2.0), size: textSize)
            if let view = self.descriptionLabel.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = textFrame
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
