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
        
        var currentIndex = 0
        
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
        
        func update(component: StoryInteractionGuideComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let strings = component.strings
            
            let sideInset: CGFloat = min(48.0, floor(availableSize.width * 0.1))
            
            let items: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "forward",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: strings.Story_Guide_ForwardTitle,
                            text: strings.Story_Guide_ForwardDescription,
                            animationName: "story_forward",
                            isPlaying: self.currentIndex == 0,
                            playbackCompleted: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.currentIndex = 1
                                self.state?.updated(transition: .easeInOut(duration: 0.3))
                            }
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "pause",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: strings.Story_Guide_PauseTitle,
                            text: strings.Story_Guide_PauseDescription,
                            animationName: "story_pause",
                            isPlaying: self.currentIndex == 1,
                            playbackCompleted: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.currentIndex = 2
                                self.state?.updated(transition: .easeInOut(duration: 0.3))
                            }
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "back",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: strings.Story_Guide_BackTitle,
                            text: strings.Story_Guide_BackDescription,
                            animationName: "story_back",
                            isPlaying: self.currentIndex == 2,
                            playbackCompleted: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.currentIndex = 3
                                self.state?.updated(transition: .easeInOut(duration: 0.3))
                            }
                        )
                    )
                ),
                AnyComponentWithIdentity(
                    id: "move",
                    component: AnyComponent(
                        GuideItemComponent(
                            context: component.context,
                            title: strings.Story_Guide_MoveTitle,
                            text: strings.Story_Guide_MoveDescription,
                            animationName: "story_move",
                            isPlaying: self.currentIndex == 3,
                            playbackCompleted: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.currentIndex = 0
                                self.state?.updated(transition: .easeInOut(duration: 0.3))
                            }
                        )
                    )
                )
            ]
            let itemsSize = self.guideItems.update(
                transition: transition,
                component: AnyComponent(List(items)),
                environment: {},
                containerSize: CGSize(width: min(500.0, availableSize.width - sideInset * 2.0), height: availableSize.height)
            )
            
            let textSpacing: CGFloat = 7.0
            let itemsSpacing: CGFloat = 36.0
            let buttonSpacing: CGFloat = 50.0
            
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Story_Guide_Title, font: Font.semibold(20.0), textColor: .white, paragraphAlignment: .center)))),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
           
            let textSize = self.descriptionLabel.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(text: .plain(NSAttributedString(string: strings.Story_Guide_Description, font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6), paragraphAlignment: .center)), maximumNumberOfLines: 0, lineSpacing: 0.2)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            let buttonSize = self.proceedButton.update(
                transition: .immediate,
                component: AnyComponent(Button(
                    content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Story_Guide_Proceed, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)))),
                    action: { [weak self] in
                        self?.handleTap()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
            )
            
            let totalHeight = titleSize.height + textSpacing + textSize.height + itemsSpacing + itemsSize.height + buttonSpacing + buttonSize.height
            let originY = floorToScreenPixels((availableSize.height - totalHeight) / 2.0)
            
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: originY), size: titleSize)
            if let view = self.titleLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = titleFrame
            }
            
            let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textSize.width) / 2.0), y: titleFrame.maxY + 7.0), size: textSize)
            if let view = self.descriptionLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = textFrame
            }
            
            let itemsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - itemsSize.width) / 2.0), y: textFrame.maxY + 40.0), size: itemsSize)
            if let view = self.guideItems.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = itemsFrame
            }
            
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class GuideItemComponent: Component {
    let context: AccountContext
    let title: String
    let text: String
    let animationName: String
    let isPlaying: Bool
    let playbackCompleted: () -> Void
    
    init(
        context: AccountContext,
        title: String,
        text: String,
        animationName: String,
        isPlaying: Bool,
        playbackCompleted: @escaping () -> Void
    ) {
        self.context = context
        self.title = title
        self.text = text
        self.animationName = animationName
        self.isPlaying = isPlaying
        self.playbackCompleted = playbackCompleted
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
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: GuideItemComponent?
        private weak var state: EmptyComponentState?
        
        private let containerView = UIView()
        private let selectionView = UIView()
        
        private let animation = ComponentView<Empty>()
        private let titleLabel = ComponentView<Empty>()
        private let descriptionLabel = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.selectionView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.1)
            self.selectionView.clipsToBounds = true
            self.selectionView.layer.cornerRadius = 16.0
            if #available(iOS 13.0, *) {
                self.selectionView.layer.cornerCurve = .continuous
            }
            self.selectionView.alpha = 0.0
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.selectionView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var isPlaying = false
        func update(component: GuideItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
                        
            let originX = availableSize.width / 2.0 - 120.0
            
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
                        loop: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let animationFrame = CGRect(origin: CGPoint(x: originX - 11.0, y: 15.0), size: animationSize)
            if let view = self.animation.view as? LottieComponent.View {
                if view.superview == nil {
                    view.externalShouldPlay = false
                    self.containerView.addSubview(view)
                }
                view.frame = animationFrame
                
                if component.isPlaying && !self.isPlaying {
                    self.isPlaying = true
                    Queue.mainQueue().justDispatch {
                        let completionBlock = { [weak self] in
                            guard let self else {
                                return
                            }
                            self.isPlaying = false
                            Queue.mainQueue().after(0.1) {
                                self.component?.playbackCompleted()
                            }
                        }
                                                
                        view.playOnce(force: true, completion: { [weak view] in
                            view?.playOnce(force: true, completion: {
                                completionBlock()
                            })
                        })
                    }
                }
            }
            
            let availableTextWidth = availableSize.width - originX - 60.0 - 18.0
            let titleSize = self.titleLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .natural)),
                        maximumNumberOfLines: 2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableTextWidth, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: originX + 60.0, y: 25.0), size: titleSize)
            if let view = self.titleLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = titleFrame
            }
            
            let textSize = self.descriptionLabel.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6), paragraphAlignment: .natural)),
                        maximumNumberOfLines: 3
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableTextWidth, height: availableSize.height)
            )
            let textFrame = CGRect(origin: CGPoint(x: originX + 60.0, y: titleFrame.maxY + 2.0), size: textSize)
            if let view = self.descriptionLabel.view {
                if view.superview == nil {
                    self.containerView.addSubview(view)
                }
                view.frame = textFrame
            }
            
            let size = CGSize(width: availableSize.width, height: 53.0 + titleSize.height + textSize.height)
            
            self.selectionView.frame = CGRect(origin: .zero, size: size).insetBy(dx: 10.0, dy: 8.0)
            transition.setAlpha(view: self.selectionView, alpha: component.isPlaying ? 1.0 : 0.0)
            
            self.containerView.bounds = CGRect(origin: .zero, size: size)
            self.containerView.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            transition.setScale(view: self.containerView, scale: component.isPlaying ? 1.1 : 1.0)
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
