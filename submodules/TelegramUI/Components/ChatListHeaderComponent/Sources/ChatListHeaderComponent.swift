import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import ChatListTitleView
import AppBundle
import StoryPeerListComponent
import TelegramCore
import MoreHeaderButton
import GlassBackgroundComponent

public final class HeaderNetworkStatusComponent: Component {
    public enum Content: Equatable {
        case connecting
        case updating
    }
    
    public let content: Content
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    
    public init(
        content: Content,
        theme: PresentationTheme,
        strings: PresentationStrings
    ) {
        self.content = content
        self.theme = theme
        self.strings = strings
    }
    
    public static func ==(lhs: HeaderNetworkStatusComponent, rhs: HeaderNetworkStatusComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: HeaderNetworkStatusComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: HeaderNetworkStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.state = state
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ChatListHeaderComponent: Component {
    public final class Content: Equatable {
        public let title: String
        public let navigationBackTitle: String?
        public let titleComponent: AnyComponent<Empty>?
        public let chatListTitle: NetworkStatusTitle?
        public let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
        public let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>]
        public let backPressed: (() -> Void)?
        
        public init(
            title: String,
            navigationBackTitle: String?,
            titleComponent: AnyComponent<Empty>?,
            chatListTitle: NetworkStatusTitle?,
            leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?,
            rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>],
            backPressed: (() -> Void)?
        ) {
            self.title = title
            self.navigationBackTitle = navigationBackTitle
            self.titleComponent = titleComponent
            self.chatListTitle = chatListTitle
            self.leftButton = leftButton
            self.rightButtons = rightButtons
            self.backPressed = backPressed
        }
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            if lhs.title != rhs.title {
                return false
            }
            if lhs.navigationBackTitle != rhs.navigationBackTitle {
                return false
            }
            if lhs.titleComponent != rhs.titleComponent {
                return false
            }
            if lhs.chatListTitle != rhs.chatListTitle {
                return false
            }
            if lhs.leftButton != rhs.leftButton {
                return false
            }
            if lhs.rightButtons != rhs.rightButtons {
                return false
            }
            if (lhs.backPressed == nil) != (rhs.backPressed == nil) {
                return false
            }
            return true
        }
    }
    
    public let sideInset: CGFloat
    public let primaryContent: Content?
    public let secondaryContent: Content?
    public let secondaryTransition: CGFloat
    public let networkStatus: HeaderNetworkStatusComponent.Content?
    public let storySubscriptions: EngineStorySubscriptions?
    public let storiesIncludeHidden: Bool
    public let storiesFraction: CGFloat
    public let storiesUnlocked: Bool
    public let uploadProgress: [EnginePeer.Id: Float]
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    
    public let openStatusSetup: (UIView) -> Void
    public let toggleIsLocked: () -> Void
    
    public init(
        sideInset: CGFloat,
        primaryContent: Content?,
        secondaryContent: Content?,
        secondaryTransition: CGFloat,
        networkStatus: HeaderNetworkStatusComponent.Content?,
        storySubscriptions: EngineStorySubscriptions?,
        storiesIncludeHidden: Bool,
        storiesFraction: CGFloat,
        storiesUnlocked: Bool,
        uploadProgress: [EnginePeer.Id: Float],
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        openStatusSetup: @escaping (UIView) -> Void,
        toggleIsLocked: @escaping () -> Void
    ) {
        self.sideInset = sideInset
        self.primaryContent = primaryContent
        self.secondaryContent = secondaryContent
        self.secondaryTransition = secondaryTransition
        self.context = context
        self.networkStatus = networkStatus
        self.storySubscriptions = storySubscriptions
        self.storiesIncludeHidden = storiesIncludeHidden
        self.storiesFraction = storiesFraction
        self.storiesUnlocked = storiesUnlocked
        self.uploadProgress = uploadProgress
        self.theme = theme
        self.strings = strings
        self.openStatusSetup = openStatusSetup
        self.toggleIsLocked = toggleIsLocked
    }
    
    public static func ==(lhs: ChatListHeaderComponent, rhs: ChatListHeaderComponent) -> Bool {
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        if lhs.primaryContent != rhs.primaryContent {
            return false
        }
        if lhs.secondaryContent != rhs.secondaryContent {
            return false
        }
        if lhs.secondaryTransition != rhs.secondaryTransition {
            return false
        }
        if lhs.networkStatus != rhs.networkStatus {
            return false
        }
        if lhs.storySubscriptions != rhs.storySubscriptions {
            return false
        }
        if lhs.storiesIncludeHidden != rhs.storiesIncludeHidden {
            return false
        }
        if lhs.storiesFraction != rhs.storiesFraction {
            return false
        }
        if lhs.storiesUnlocked != rhs.storiesUnlocked {
            return false
        }
        if lhs.uploadProgress != rhs.uploadProgress {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }
    
    private final class BackButtonView: HighlightableButton {
        private let onPressed: () -> Void
        
        let arrowView: UIImageView
        
        private var currentColor: UIColor?
        
        init(onPressed: @escaping () -> Void) {
            self.onPressed = onPressed
            
            self.arrowView = UIImageView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.arrowView)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.alpha = 0.6
                } else {
                    self.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.onPressed()
        }
        
        func update(theme: PresentationTheme, strings: PresentationStrings, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.accessibilityLabel = strings.Common_Back
            self.accessibilityTraits = [.button]
            
            if self.currentColor != theme.chat.inputPanel.panelControlColor {
                self.currentColor = theme.chat.inputPanel.panelControlColor
                let imageSize = CGSize(width: 44.0, height: 44.0)
                let topRightPoint = CGPoint(x: 24.6, y: 14.0)
                let centerPoint = CGPoint(x: 17.0, y: imageSize.height * 0.5)
                self.arrowView.image = generateImage(imageSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.move(to: topRightPoint)
                    context.addLine(to: centerPoint)
                    context.addLine(to: CGPoint(x: topRightPoint.x, y: size.height - topRightPoint.y))
                    context.strokePath()
                })?.withRenderingMode(.alwaysTemplate)
                self.arrowView.tintColor = theme.chat.inputPanel.panelControlColor
            }
            
            let size = CGSize(width: 44.0, height: availableSize.height)
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 13.0, height: 22.0)
            
            let arrowFrame = arrowSize.centered(in: CGRect(origin: CGPoint(), size: size))
            transition.setPosition(view: self.arrowView, position: arrowFrame.center)
            transition.setBounds(view: self.arrowView, bounds: CGRect(origin: CGPoint(), size: arrowFrame.size))
            
            return size
        }
    }
    
    private final class ContentView: UIView {
        let backPressed: () -> Void
        let openStatusSetup: (UIView) -> Void
        let toggleIsLocked: () -> Void
        
        let leftButtonsContainer: UIView
        var leftButtonViews: [AnyHashable: ComponentView<NavigationButtonComponentEnvironment>] = [:]
        let rightButtonsContainer: UIView
        var rightButtonViews: [AnyHashable: ComponentView<NavigationButtonComponentEnvironment>] = [:]
        var backButtonView: BackButtonView?
        
        let titleOffsetContainer: UIView
        let titleScaleContainer: UIView
        let titleTextView: ImmediateTextView
        var titleContentView: ComponentView<Empty>?
        var chatListTitleView: ChatListTitleView?
        
        var contentOffsetFraction: CGFloat = 0.0
        private(set) var centerContentWidth: CGFloat = 0.0
        private(set) var centerContentLeftInset: CGFloat = 0.0
        private(set) var centerContentRightInset: CGFloat = 0.0
        
        private(set) var centerContentOffsetX: CGFloat = 0.0
        private(set) var centerContentOrigin: CGFloat = 0.0

        private(set) var leftButtonsWidth: CGFloat = 0.0
        private(set) var rightButtonsWidth: CGFloat = 0.0
        
        init(
            backPressed: @escaping () -> Void,
            openStatusSetup: @escaping (UIView) -> Void,
            toggleIsLocked: @escaping () -> Void
        ) {
            self.backPressed = backPressed
            self.openStatusSetup = openStatusSetup
            self.toggleIsLocked = toggleIsLocked
            
            self.leftButtonsContainer = UIView()            
            self.rightButtonsContainer = UIView()

            self.titleOffsetContainer = UIView()
            self.titleScaleContainer = UIView()
            
            self.titleTextView = ImmediateTextView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.titleOffsetContainer)
            self.titleOffsetContainer.addSubview(self.titleScaleContainer)
            
            self.titleScaleContainer.addSubview(self.titleTextView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let backButtonView = self.backButtonView {
                if let result = backButtonView.hitTest(self.convert(point, to: backButtonView), with: event) {
                    return result
                }
            }
            for (_, buttonView) in self.leftButtonViews {
                if let view = buttonView.view, let result = view.hitTest(self.convert(point, to: view), with: event) {
                    return result
                }
            }
            for (_, buttonView) in self.rightButtonViews {
                if let view = buttonView.view, let result = view.hitTest(self.convert(point, to: view), with: event) {
                    return result
                }
            }
            if let view = self.titleContentView?.view, let result = view.hitTest(self.convert(point, to: view), with: event) {
                return result
            }
            if let view = self.chatListTitleView, let result = view.hitTest(self.convert(point, to: view), with: event) {
                return result
            }
            return nil
        }
        
        func updateContentOffsetFraction(contentOffsetFraction: CGFloat, transition: ComponentTransition) {
            if self.contentOffsetFraction == contentOffsetFraction {
                return
            }
            self.contentOffsetFraction = contentOffsetFraction
            
            let translation = 44.0 * contentOffsetFraction * 0.5
            
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, translation, 0.0, 0.0)
            transition.setSublayerTransform(view: self.titleOffsetContainer, transform: transform)
        }
        
        func updateNavigationTransitionAsPrevious(nextView: ContentView, width: CGFloat, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)
            alphaTransition.setAlpha(view: self.leftButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: fraction * 10.0)
            alphaTransition.setAlpha(view: self.rightButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.rightButtonsContainer.layer, radius: fraction * 10.0)
            
            if let backButtonView = self.backButtonView {
                transition.setBounds(view: backButtonView, bounds: CGRect(origin: CGPoint(x: fraction * self.bounds.width * 0.5, y: 0.0), size: backButtonView.bounds.size), completion: { _ in
                    completion()
                })
            }
            
            let totalOffset = -width * fraction
            
            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: totalOffset * fraction, y: 0.0), size: self.titleOffsetContainer.bounds.size))
            transition.setAlpha(view: self.titleOffsetContainer, alpha: pow(1.0 - fraction, 2.0))
        }
        
        func updateNavigationTransitionAsNext(previousView: ContentView, storyPeerListView: StoryPeerListComponent.View?, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: -(1.0 - fraction) * self.bounds.width, y: 0.0), size: self.titleOffsetContainer.bounds.size), completion: { _ in
                completion()
            })
            alphaTransition.setAlpha(view: self.rightButtonsContainer, alpha: pow(fraction, 2.0))

            alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
            alphaTransition.setBlur(layer: self.rightButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
        }
        
        func updateNavigationTransitionAsPreviousInplace(nextView: ContentView, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

            alphaTransition.setAlpha(view: self.leftButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: fraction * 10.0)
            alphaTransition.setAlpha(view: self.rightButtonsContainer, alpha: pow(1.0 - fraction, 2.0), completion: { _ in
                completion()
            })
            alphaTransition.setBlur(layer: self.rightButtonsContainer.layer, radius: fraction * 10.0)
            
            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.titleOffsetContainer.bounds.size))
            transition.setAlpha(view: self.titleOffsetContainer, alpha: pow(1.0 - fraction, 2.0))
        }
        
        func updateNavigationTransitionAsNextInplace(previousView: ContentView, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.titleOffsetContainer.bounds.size), completion: { _ in
                completion()
            })
            alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
            alphaTransition.setAlpha(view: self.leftButtonsContainer, alpha: pow(fraction, 2.0))
            alphaTransition.setBlur(layer: self.rightButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
            alphaTransition.setAlpha(view: self.rightButtonsContainer, alpha: pow(fraction, 2.0))
        }
        
        func openEmojiStatusSetup() {
            self.chatListTitleView?.openEmojiStatusSetup()
        }
        
        func update(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: Content, displayBackButton: Bool, sideInset: CGFloat, sideContentWidth: CGFloat, sideContentFraction: CGFloat, size: CGSize, transition: ComponentTransition) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

            transition.setPosition(view: self.titleOffsetContainer, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: self.titleOffsetContainer.bounds.origin, size: size))
            
            transition.setPosition(view: self.titleScaleContainer, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            transition.setBounds(view: self.titleScaleContainer, bounds: CGRect(origin: self.titleScaleContainer.bounds.origin, size: size))
            
            let titleText = NSAttributedString(string: content.title, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
            let titleTextUpdated = self.titleTextView.attributedText != titleText
            self.titleTextView.attributedText = titleText
            
            let buttonSpacing: CGFloat = 0.0
            var nextLeftButtonX: CGFloat = 0.0
            
            if displayBackButton {
                var backButtonTransition = transition
                let backButtonView: BackButtonView
                if let current = self.backButtonView {
                    backButtonView = current
                } else {
                    backButtonTransition = .immediate
                    backButtonView = BackButtonView(onPressed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.backPressed()
                    })
                    self.backButtonView = backButtonView
                    self.leftButtonsContainer.addSubview(backButtonView)
                }
                let backButtonSize = backButtonView.update(theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: size.height), transition: backButtonTransition)
                backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: nextLeftButtonX, y: floor((size.height - backButtonSize.height) / 2.0)), size: backButtonSize))
                if nextLeftButtonX != 0.0 {
                    nextLeftButtonX += buttonSpacing
                }
                nextLeftButtonX += backButtonSize.width
            } else if let backButtonView = self.backButtonView {
                self.backButtonView = nil
                backButtonView.removeFromSuperview()
            }
            
            var validLeftButtons = Set<AnyHashable>()
            if let leftButton = content.leftButton {
                validLeftButtons.insert(leftButton.id)

                if nextLeftButtonX != 0.0 {
                    nextLeftButtonX += buttonSpacing
                }
                
                var buttonTransition = transition
                var animateButtonIn = false
                let buttonView: ComponentView<NavigationButtonComponentEnvironment>
                if let current = self.leftButtonViews[leftButton.id] {
                    buttonView = current
                } else {
                    buttonTransition = .immediate
                    animateButtonIn = true
                    buttonView = ComponentView<NavigationButtonComponentEnvironment>()
                    self.leftButtonViews[leftButton.id] = buttonView
                }
                let buttonSize = buttonView.update(
                    transition: buttonTransition,
                    component: leftButton.component,
                    environment: {
                        NavigationButtonComponentEnvironment(theme: theme)
                    },
                    containerSize: CGSize(width: 100.0, height: size.height)
                )
                let buttonFrame = CGRect(origin: CGPoint(x: nextLeftButtonX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                if let buttonComponentView = buttonView.view {
                    if buttonComponentView.superview == nil {
                        self.leftButtonsContainer.addSubview(buttonComponentView)
                    }
                    buttonTransition.setFrame(view: buttonComponentView, frame: buttonFrame)
                    if animateButtonIn {
                        alphaTransition.animateBlur(layer: buttonComponentView.layer, fromRadius: 10.0, toRadius: 0.0)
                        alphaTransition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
                    }
                }
                nextLeftButtonX += buttonSize.width
            }
            var removeLeftButtons: [AnyHashable] = []
            for (id, buttonView) in self.leftButtonViews {
                if !validLeftButtons.contains(id) {
                    if let buttonComponentView = buttonView.view {
                        alphaTransition.setBlur(layer: buttonComponentView.layer, radius: 10.0)
                        alphaTransition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                            buttonComponentView?.removeFromSuperview()
                        })
                    }
                    removeLeftButtons.append(id)
                }
            }
            for id in removeLeftButtons {
                self.leftButtonViews.removeValue(forKey: id)
            }
            
            var nextRightButtonX: CGFloat = 0.0
            var validRightButtons = Set<AnyHashable>()
            for rightButton in content.rightButtons.reversed() {
                validRightButtons.insert(rightButton.id)

                if nextRightButtonX != 0.0 {
                    nextRightButtonX += buttonSpacing
                }
                
                var buttonTransition = transition
                var animateButtonIn = false
                let buttonView: ComponentView<NavigationButtonComponentEnvironment>
                if let current = self.rightButtonViews[rightButton.id] {
                    buttonView = current
                } else {
                    buttonTransition = .immediate
                    animateButtonIn = true
                    buttonView = ComponentView<NavigationButtonComponentEnvironment>()
                    self.rightButtonViews[rightButton.id] = buttonView
                }
                let buttonSize = buttonView.update(
                    transition: buttonTransition,
                    component: rightButton.component,
                    environment: {
                        NavigationButtonComponentEnvironment(theme: theme)
                    },
                    containerSize: CGSize(width: 100.0, height: size.height)
                )
                let buttonFrame = CGRect(origin: CGPoint(x: nextRightButtonX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                if let buttonComponentView = buttonView.view {
                    if buttonComponentView.superview == nil {
                        self.rightButtonsContainer.addSubview(buttonComponentView)
                    }
                    buttonTransition.setFrame(view: buttonComponentView, frame: buttonFrame)
                    if animateButtonIn {
                        alphaTransition.animateBlur(layer: buttonComponentView.layer, fromRadius: 10.0, toRadius: 0.0)
                        alphaTransition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
                    }
                }
                nextRightButtonX += buttonSize.width
            }
            var removeRightButtons: [AnyHashable] = []
            for (id, buttonView) in self.rightButtonViews {
                if !validRightButtons.contains(id) {
                    if let buttonComponentView = buttonView.view {
                        alphaTransition.setBlur(layer: buttonComponentView.layer, radius: 10.0)
                        alphaTransition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                            buttonComponentView?.removeFromSuperview()
                        })
                    }
                    removeRightButtons.append(id)
                }
            }
            for id in removeRightButtons {
                self.rightButtonViews.removeValue(forKey: id)
            }

            self.leftButtonsWidth = nextLeftButtonX
            self.rightButtonsWidth = nextRightButtonX

            let commonInset: CGFloat = sideInset + max(nextLeftButtonX, nextRightButtonX) + 8.0
            let remainingWidth = size.width - commonInset * 2.0
            
            let titleTextSize = self.titleTextView.updateLayout(CGSize(width: remainingWidth, height: size.height))
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleTextSize.width) / 2.0) + sideContentWidth, y: floor((size.height - titleTextSize.height) / 2.0)), size: titleTextSize)
            if titleTextUpdated {
                self.titleTextView.frame = titleFrame
            } else {
                transition.setFrame(view: self.titleTextView, frame: titleFrame)
            }
            
            if let titleComponent = content.titleComponent {
                var titleContentTransition = transition
                let titleContentView: ComponentView<Empty>
                if let current = self.titleContentView {
                    titleContentView = current
                } else {
                    titleContentTransition = .immediate
                    titleContentView = ComponentView<Empty>()
                    self.titleContentView = titleContentView
                }
                let titleContentSize = titleContentView.update(
                    transition: titleContentTransition,
                    component: titleComponent,
                    environment: {},
                    containerSize: CGSize(width: remainingWidth, height: size.height)
                )
                
                if let titleContentComponentView = titleContentView.view {
                    if titleContentComponentView.superview == nil {
                        self.titleScaleContainer.addSubview(titleContentComponentView)
                    }
                    titleContentTransition.setFrame(view: titleContentComponentView, frame: CGRect(origin: CGPoint(x: floor((size.width - titleContentSize.width) / 2.0), y: floor((size.height - titleContentSize.height) / 2.0)), size: titleContentSize))
                }
            } else {
                if let titleContentView = self.titleContentView {
                    self.titleContentView = nil
                    titleContentView.view?.removeFromSuperview()
                }
            }
            
            var centerContentLeftInset: CGFloat = 0.0
            centerContentLeftInset = nextLeftButtonX + 4.0
            
            var centerContentRightInset: CGFloat = 0.0
            centerContentRightInset = nextRightButtonX + 20.0
            
            var centerContentWidth: CGFloat = 0.0
            var centerContentOffsetX: CGFloat = 0.0
            var centerContentOrigin: CGFloat = 0.0
            if let chatListTitle = content.chatListTitle {
                var chatListTitleTransition = transition
                let chatListTitleView: ChatListTitleView
                if let current = self.chatListTitleView {
                    chatListTitleView = current
                } else {
                    chatListTitleTransition = .immediate
                    chatListTitleView = ChatListTitleView(context: context, theme: theme, strings: strings, animationCache: context.animationCache, animationRenderer: context.animationRenderer)
                    chatListTitleView.manualLayout = true
                    self.chatListTitleView = chatListTitleView
                    self.titleScaleContainer.addSubview(chatListTitleView)
                }
                
                let chatListTitleContentSize = size
                chatListTitleView.theme = theme
                chatListTitleView.strings = strings
                chatListTitleView.setTitle(chatListTitle, animated: false)
                let titleContentRect = chatListTitleView.updateLayoutInternal(size: chatListTitleContentSize, transition: transition.containedViewLayoutTransition)
                centerContentWidth = floor((chatListTitleContentSize.width * 0.5 - titleContentRect.minX) * 2.0)
                
                let centerOffset = sideContentWidth * 0.5
                centerContentOffsetX = -max(0.0, centerOffset + titleContentRect.maxX - 2.0 - (size.width - sideInset - nextRightButtonX))
                
                chatListTitleView.openStatusSetup = { [weak self] sourceView in
                    guard let self else {
                        return
                    }
                    self.openStatusSetup(sourceView)
                }
                chatListTitleView.toggleIsLocked = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.toggleIsLocked()
                }
                
                let chatListTitleOffset: CGFloat
                if chatListTitle.activity {
                    chatListTitleOffset = 0.0
                } else {
                    chatListTitleOffset = (centerOffset + centerContentOffsetX) * sideContentFraction
                }
                
                centerContentOrigin = chatListTitleOffset + size.width * 0.5 - centerContentWidth * 0.5
                
                chatListTitleTransition.setFrame(view: chatListTitleView, frame: CGRect(origin: CGPoint(x: chatListTitleOffset + floor((size.width - chatListTitleContentSize.width) / 2.0), y: floor((size.height - chatListTitleContentSize.height) / 2.0)), size: chatListTitleContentSize))
            } else {
                if let chatListTitleView = self.chatListTitleView {
                    self.chatListTitleView = nil
                    chatListTitleView.removeFromSuperview()
                }
            }
            
            self.titleTextView.isHidden = self.chatListTitleView != nil || self.titleContentView != nil
            self.centerContentWidth = centerContentWidth
            self.centerContentOffsetX = centerContentOffsetX
            self.centerContentOrigin = centerContentOrigin
            self.centerContentRightInset = centerContentRightInset
            self.centerContentLeftInset = centerContentLeftInset
        }
    }
    
    public final class View: UIView {
        private var component: ChatListHeaderComponent?
        private weak var state: EmptyComponentState?
        
        private var primaryContentView: ContentView?
        private var secondaryContentView: ContentView?
        private var storyOffsetFraction: CGFloat = 0.0

        private let leftButtonsContainer: UIView
        private let rightButtonsContainer: UIView
        private var leftButtonsBackgroundContainer: GlassContextExtractableContainer?
        private var rightButtonsBackgroundContainer: GlassContextExtractableContainer?
        
        private let storyPeerListExternalState = StoryPeerListComponent.ExternalState()
        private var storyPeerList: ComponentView<Empty>?
        public var storyPeerAction: ((EnginePeer?) -> Void)?
        public var storyContextPeerAction: ((ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void)?
        public var storyComposeAction: ((CGFloat) -> Void)?
        
        private var effectiveContentView: ContentView? {
            return self.secondaryContentView ?? self.primaryContentView
        }
        
        override init(frame: CGRect) {
            self.leftButtonsContainer = UIView()
            self.rightButtonsContainer = UIView()
            self.rightButtonsContainer.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)

            super.init(frame: frame)
            
            self.storyOffsetFraction = 1.0
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public var backArrowView: UIView? {
            return self.effectiveContentView?.backButtonView?.arrowView
        }
        
        public var rightButtonView: UIView? {
            return self.effectiveContentView?.rightButtonViews.first?.value.view
        }
        
        public var rightButtonViews: [AnyHashable: UIView] {
            return self.effectiveContentView?.rightButtonViews.reduce(into: [:], { result, view in
                result[view.key] = view.value.view
            }) ?? [:]
        }
        
        public var titleContentView: UIView? {
            return self.effectiveContentView?.titleContentView?.view 
        }
        
        public func storyPeerListView() -> StoryPeerListComponent.View? {
            return self.storyPeerList?.view as? StoryPeerListComponent.View
        }
        
        public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
            if let leftButtonsBackgroundContainer = self.leftButtonsBackgroundContainer, sourceView.isDescendant(of: leftButtonsBackgroundContainer) {
                return leftButtonsBackgroundContainer
            }
            if let rightButtonsBackgroundContainer = self.rightButtonsBackgroundContainer, sourceView.isDescendant(of: rightButtonsBackgroundContainer) {
                return rightButtonsBackgroundContainer
            }
            return nil
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let storyPeerListView = self.storyPeerList?.view {
                if let result = storyPeerListView.hitTest(self.convert(point, to: storyPeerListView), with: event) {
                    return result
                }
            }
            
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.alpha < 0.01 || subview.isHidden {
                    continue
                }
                if subview === self.storyPeerList?.view {
                    continue
                }
                if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                    return result
                }
            }
            
            let defaultResult = super.hitTest(point, with: event)
            
            if let defaultResult, defaultResult !== self {
                return defaultResult
            }
            
            return defaultResult
        }
        
        private func updateContentStoryOffsets(transition: ComponentTransition) {
        }
        
        func openEmojiStatusSetup() {
            if let storyPeerListView = self.storyPeerList?.view as? StoryPeerListComponent.View {
                storyPeerListView.openEmojiStatusSetup()
            } else {
                self.primaryContentView?.openEmojiStatusSetup()
            }
        }
        
        func update(component: ChatListHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.state = state
            
            let previousComponent = self.component
            self.component = component
            
            var primaryContentTransition = transition
            if var primaryContent = component.primaryContent {
                let primaryContentView: ContentView
                if let current = self.primaryContentView {
                    primaryContentView = current
                } else {
                    primaryContentTransition = .immediate
                    primaryContentView = ContentView(
                        backPressed: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.primaryContent?.backPressed?()
                        },
                        openStatusSetup: { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            self.component?.openStatusSetup(sourceView)
                        },
                        toggleIsLocked: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.toggleIsLocked()
                        }
                    )
                    self.primaryContentView = primaryContentView
                    self.addSubview(primaryContentView)
                    self.leftButtonsContainer.addSubview(primaryContentView.leftButtonsContainer)
                    self.rightButtonsContainer.addSubview(primaryContentView.rightButtonsContainer)
                }
                
                let sideContentWidth: CGFloat = 0.0
                
                if component.storySubscriptions != nil {
                    primaryContent = Content(
                        title: "",
                        navigationBackTitle: primaryContent.navigationBackTitle,
                        titleComponent: nil,
                        chatListTitle: nil,
                        leftButton: primaryContent.leftButton,
                        rightButtons: primaryContent.rightButtons,
                        backPressed: primaryContent.backPressed
                    )
                }
                
                primaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: primaryContent, displayBackButton: primaryContent.backPressed != nil, sideInset: component.sideInset, sideContentWidth: sideContentWidth, sideContentFraction: (1.0 - component.storiesFraction), size: availableSize, transition: primaryContentTransition)
                primaryContentTransition.setFrame(view: primaryContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                primaryContentView.updateContentOffsetFraction(contentOffsetFraction: 1.0 - self.storyOffsetFraction, transition: primaryContentTransition)
            } else if let primaryContentView = self.primaryContentView {
                self.primaryContentView = nil
                primaryContentView.removeFromSuperview()
                primaryContentView.leftButtonsContainer.removeFromSuperview()
                primaryContentView.rightButtonsContainer.removeFromSuperview()
            }
            
            var storyListTransition = transition
            if let storySubscriptions = component.storySubscriptions {
                let storyPeerList: ComponentView<Empty>
                if let current = self.storyPeerList {
                    storyPeerList = current
                } else {
                    storyListTransition = .immediate
                    storyPeerList = ComponentView()
                    self.storyPeerList = storyPeerList
                }
                
                var primaryTitle = ""
                var primaryTitleHasLock = false
                var primaryTitleHasActivity = false
                var primaryTitlePeerStatus: StoryPeerListComponent.PeerStatus?
                if let primaryContent = component.primaryContent {
                    if let chatListTitle = primaryContent.chatListTitle {
                        primaryTitle = chatListTitle.text
                        primaryTitleHasLock = chatListTitle.isPasscodeSet
                        primaryTitleHasActivity = chatListTitle.activity
                        if let peerStatus = chatListTitle.peerStatus {
                            switch peerStatus {
                            case .premium:
                                primaryTitlePeerStatus = .premium
                            case let .emoji(status):
                                primaryTitlePeerStatus = .emoji(status)
                            }
                        }
                    } else {
                        primaryTitle = primaryContent.title
                    }
                }
                
                let _ = storyPeerList.update(
                    transition: storyListTransition,
                    component: AnyComponent(StoryPeerListComponent(
                        externalState: self.storyPeerListExternalState,
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        sideInset: component.sideInset,
                        title: primaryTitle,
                        titleHasLock: primaryTitleHasLock,
                        titleHasActivity: primaryTitleHasActivity,
                        titlePeerStatus: primaryTitlePeerStatus,
                        minTitleX: self.primaryContentView?.centerContentLeftInset ?? 0.0,
                        maxTitleX: availableSize.width - (self.primaryContentView?.centerContentRightInset ?? 0.0),
                        useHiddenList: component.storiesIncludeHidden,
                        storySubscriptions: storySubscriptions,
                        collapseFraction: 1.0 - component.storiesFraction,
                        unlocked: component.storiesUnlocked,
                        uploadProgress: component.uploadProgress,
                        peerAction: { [weak self] peer in
                            guard let self else {
                                return
                            }
                            self.storyPeerAction?(peer)
                        },
                        contextPeerAction: { [weak self] sourceNode, gesture, peer in
                            guard let self else {
                                return
                            }
                            self.storyContextPeerAction?(sourceNode, gesture, peer)
                        },
                        openStatusSetup: { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            self.component?.openStatusSetup(sourceView)
                        },
                        lockAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.toggleIsLocked()
                        },
                        composeAction: { [weak self] offset in
                            guard let self else {
                                return
                            }
                            self.storyComposeAction?(offset)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: ChatListNavigationBar.storiesScrollHeight)
                )
            }
            
            var secondaryContentTransition = transition
            var secondaryContentIsAnimatingIn = false
            var removedSecondaryContentView: ContentView?
            if let secondaryContent = component.secondaryContent {
                let secondaryContentView: ContentView
                if let current = self.secondaryContentView {
                    secondaryContentView = current
                } else {
                    secondaryContentTransition = .immediate
                    secondaryContentIsAnimatingIn = true
                    secondaryContentView = ContentView(
                        backPressed: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.secondaryContent?.backPressed?()
                        },
                        openStatusSetup: { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            self.component?.openStatusSetup(sourceView)
                        },
                        toggleIsLocked: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.toggleIsLocked()
                        }
                    )
                    self.secondaryContentView = secondaryContentView
                    if let primaryContentView = self.primaryContentView {
                        self.insertSubview(secondaryContentView, aboveSubview: primaryContentView)
                    } else {
                        self.addSubview(secondaryContentView)
                    }
                    self.leftButtonsContainer.addSubview(secondaryContentView.leftButtonsContainer)
                    self.rightButtonsContainer.addSubview(secondaryContentView.rightButtonsContainer)
                }
                secondaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: secondaryContent, displayBackButton: true, sideInset: component.sideInset, sideContentWidth: 0.0, sideContentFraction: 0.0, size: availableSize, transition: secondaryContentTransition)
                secondaryContentTransition.setFrame(view: secondaryContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                secondaryContentView.updateContentOffsetFraction(contentOffsetFraction: 1.0 - self.storyOffsetFraction, transition: secondaryContentTransition)
                
                if let primaryContentView = self.primaryContentView {
                    if let previousComponent = previousComponent, previousComponent.secondaryContent == nil {
                        if self.storyOffsetFraction < 0.8 {
                            primaryContentView.updateNavigationTransitionAsPreviousInplace(nextView: secondaryContentView, fraction: 0.0, transition: .immediate, completion: {})
                            secondaryContentView.updateNavigationTransitionAsNextInplace(previousView: primaryContentView, fraction: 0.0, transition: .immediate, completion: {})
                        } else {
                            primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView,  width: availableSize.width, fraction: 0.0, transition: .immediate, completion: {})
                            secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, storyPeerListView: self.storyPeerListView(), fraction: 0.0, transition: .immediate, completion: {})
                        }
                    }
                    
                    if self.storyOffsetFraction < 0.8 {
                        primaryContentView.updateNavigationTransitionAsPreviousInplace(nextView: secondaryContentView, fraction: component.secondaryTransition, transition: transition, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNextInplace(previousView: primaryContentView, fraction: component.secondaryTransition, transition: transition, completion: {})
                    } else {
                        primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, width: availableSize.width, fraction: component.secondaryTransition, transition: transition, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, storyPeerListView: self.storyPeerListView(), fraction: component.secondaryTransition, transition: transition, completion: {})
                    }
                }
            } else if let secondaryContentView = self.secondaryContentView {
                self.secondaryContentView = nil
                removedSecondaryContentView = secondaryContentView
                
                if let primaryContentView = self.primaryContentView {
                    if self.storyOffsetFraction < 0.8 {
                        primaryContentView.updateNavigationTransitionAsPreviousInplace(nextView: secondaryContentView, fraction: 0.0, transition: transition, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNextInplace(previousView: primaryContentView, fraction: 0.0, transition: transition, completion: { [weak secondaryContentView] in
                            secondaryContentView?.leftButtonsContainer.removeFromSuperview()
                            secondaryContentView?.rightButtonsContainer.removeFromSuperview()
                            secondaryContentView?.removeFromSuperview()
                        })
                    } else {
                        primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, width: availableSize.width, fraction: 0.0, transition: transition, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, storyPeerListView: self.storyPeerListView(), fraction: 0.0, transition: transition, completion: { [weak secondaryContentView] in
                            secondaryContentView?.leftButtonsContainer.removeFromSuperview()
                            secondaryContentView?.rightButtonsContainer.removeFromSuperview()
                            secondaryContentView?.removeFromSuperview()
                        })
                    }
                } else {
                    secondaryContentView.leftButtonsContainer.removeFromSuperview()
                    secondaryContentView.rightButtonsContainer.removeFromSuperview()
                    secondaryContentView.removeFromSuperview()
                }
            }
            
            if let storyPeerList = self.storyPeerList, let storyPeerListComponentView = storyPeerList.view as? StoryPeerListComponent.View {
                if storyPeerListComponentView.superview == nil {
                    self.addSubview(storyPeerListComponentView)
                }
                
                let storyPeerListMaxOffset: CGFloat = availableSize.height + 2.0
                
                var storiesX: CGFloat = 0.0
                storiesX -= availableSize.width * component.secondaryTransition
                
                storyListTransition.setFrame(view: storyPeerListComponentView, frame: CGRect(origin: CGPoint(x: storiesX, y: storyPeerListMaxOffset), size: CGSize(width: availableSize.width, height: 79.0)))
                
                let storyListNormalAlpha: CGFloat = 1.0
                
                let storyListAlpha: CGFloat = (1.0 - component.secondaryTransition) * storyListNormalAlpha
                storyListTransition.setAlpha(view: storyPeerListComponentView, alpha: storyListAlpha)
            }

            var leftButtonsEffectiveWidth: CGFloat = 0.0
            var rightButtonsEffectiveWidth: CGFloat = 0.0
            if let primaryContentView = self.primaryContentView, let secondaryContentView = self.secondaryContentView {

                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth * (1.0 - component.secondaryTransition) + secondaryContentView.leftButtonsWidth * component.secondaryTransition
                rightButtonsEffectiveWidth = primaryContentView.rightButtonsWidth * (1.0 - component.secondaryTransition) + secondaryContentView.rightButtonsWidth * component.secondaryTransition

                primaryContentTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
                secondaryContentTransition.setFrame(view: secondaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.leftButtonsWidth), height: 44.0)))

                primaryContentTransition.setFrame(view: primaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - primaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.rightButtonsWidth), height: 44.0)))

                if secondaryContentIsAnimatingIn {
                    secondaryContentView.rightButtonsContainer.frame = CGRect(origin: CGPoint(x: self.rightButtonsContainer.bounds.width - secondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.rightButtonsWidth), height: 44.0))
                }
                transition.setFrame(view: secondaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - secondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, secondaryContentView.rightButtonsWidth), height: 44.0)))
            } else if let primaryContentView = self.primaryContentView {
                leftButtonsEffectiveWidth = primaryContentView.leftButtonsWidth
                rightButtonsEffectiveWidth = primaryContentView.rightButtonsWidth

                primaryContentTransition.setFrame(view: primaryContentView.leftButtonsContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.leftButtonsWidth), height: 44.0)))
                primaryContentTransition.setFrame(view: primaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - primaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, primaryContentView.rightButtonsWidth), height: 44.0)))

                if let removedSecondaryContentView {
                    transition.setFrame(view: removedSecondaryContentView.rightButtonsContainer, frame: CGRect(origin: CGPoint(x: rightButtonsEffectiveWidth - removedSecondaryContentView.rightButtonsWidth, y: 0.0), size: CGSize(width: max(44.0, removedSecondaryContentView.rightButtonsWidth), height: 44.0)))
                }
            }

            if leftButtonsEffectiveWidth != 0.0 {
                let leftButtonsBackgroundContainer: GlassContextExtractableContainer
                var leftButtonsBackgroundContainerTransition = transition
                if let current = self.leftButtonsBackgroundContainer {
                    leftButtonsBackgroundContainer = current
                } else {
                    leftButtonsBackgroundContainerTransition = leftButtonsBackgroundContainerTransition.withAnimation(.none)
                    leftButtonsBackgroundContainer = GlassContextExtractableContainer()
                    self.leftButtonsBackgroundContainer = leftButtonsBackgroundContainer
                    self.addSubview(leftButtonsBackgroundContainer)
                    leftButtonsBackgroundContainer.contentView.addSubview(self.leftButtonsContainer)
                }
                let leftButtonsContainerFrame = CGRect(origin: CGPoint(x: component.sideInset, y: 0.0), size: CGSize(width: max(44.0, leftButtonsEffectiveWidth), height: 44.0))
                leftButtonsBackgroundContainerTransition.setFrame(view: leftButtonsBackgroundContainer, frame: leftButtonsContainerFrame)
                leftButtonsBackgroundContainer.update(size: leftButtonsContainerFrame.size, cornerRadius: leftButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: leftButtonsBackgroundContainerTransition)
                leftButtonsBackgroundContainerTransition.setFrame(view: self.leftButtonsContainer, frame: CGRect(origin: CGPoint(), size: leftButtonsContainerFrame.size)) 
            } else {
                if let leftButtonsBackgroundContainer = self.leftButtonsBackgroundContainer {
                    self.leftButtonsBackgroundContainer = nil
                    transition.setAlpha(view: leftButtonsBackgroundContainer, alpha: 0.0, completion: { [weak leftButtonsBackgroundContainer] _ in
                        leftButtonsBackgroundContainer?.removeFromSuperview()
                    })
                }
            }

            if rightButtonsEffectiveWidth != 0.0 {
                let rightButtonsBackgroundContainer: GlassContextExtractableContainer
                var rightButtonsBackgroundContainerTransition = transition
                
                let rightButtonsContainerFrame = CGRect(origin: CGPoint(x: availableSize.width - component.sideInset - max(44.0, rightButtonsEffectiveWidth), y: 0.0), size: CGSize(width: max(44.0, rightButtonsEffectiveWidth), height: 44.0))
                
                if let current = self.rightButtonsBackgroundContainer {
                    rightButtonsBackgroundContainer = current
                } else {
                    rightButtonsBackgroundContainerTransition = rightButtonsBackgroundContainerTransition.withAnimation(.none)
                    rightButtonsBackgroundContainer = GlassContextExtractableContainer()
                    self.rightButtonsBackgroundContainer = rightButtonsBackgroundContainer
                    self.addSubview(rightButtonsBackgroundContainer)
                    rightButtonsBackgroundContainer.contentView.addSubview(self.rightButtonsContainer)
                    
                    rightButtonsBackgroundContainer.update(size: rightButtonsContainerFrame.size, cornerRadius: rightButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: false, transition: .immediate)
                }
                rightButtonsBackgroundContainerTransition.setFrame(view: rightButtonsBackgroundContainer, frame: rightButtonsContainerFrame)
                rightButtonsBackgroundContainer.update(size: rightButtonsContainerFrame.size, cornerRadius: rightButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
                rightButtonsBackgroundContainerTransition.setFrame(view: self.rightButtonsContainer, frame: CGRect(origin: CGPoint(), size: rightButtonsContainerFrame.size))
            } else {
                if let rightButtonsBackgroundContainer = self.rightButtonsBackgroundContainer {
                    self.rightButtonsBackgroundContainer = nil
                    
                    rightButtonsBackgroundContainer.update(size: rightButtonsBackgroundContainer.bounds.size, cornerRadius: rightButtonsBackgroundContainer.bounds.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: false, transition: transition)
                    transition.attachAnimation(view: rightButtonsBackgroundContainer, id: "remove", completion: { [weak rightButtonsBackgroundContainer] _ in
                        rightButtonsBackgroundContainer?.removeFromSuperview()
                    })
                }
            }
            
            return availableSize
        }
        
        public func findTitleView() -> ChatListTitleView? {
            return self.primaryContentView?.chatListTitleView
        }
        
        public func emojiStatus() -> PeerEmojiStatus? {
            guard let component = self.component else {
                return nil
            }
            if let _ = component.storySubscriptions, let primaryContent = component.primaryContent, let chatListTitle = primaryContent.chatListTitle, let peerStatus = chatListTitle.peerStatus, case let .emoji(emojiStatus) = peerStatus {
                return emojiStatus
            } else if let peerStatus = self.findTitleView()?.title.peerStatus, case let .emoji(emojiStatus) = peerStatus {
                return emojiStatus
            }
            return nil
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
