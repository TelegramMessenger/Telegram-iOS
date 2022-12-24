import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import ChatListTitleView
import AppBundle

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
        
        func update(component: HeaderNetworkStatusComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.state = state
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
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
        public let backTitle: String?
        public let backPressed: (() -> Void)?
        
        public init(
            title: String,
            navigationBackTitle: String?,
            titleComponent: AnyComponent<Empty>?,
            chatListTitle: NetworkStatusTitle?,
            leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?,
            rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>],
            backTitle: String?,
            backPressed: (() -> Void)?
        ) {
            self.title = title
            self.navigationBackTitle = navigationBackTitle
            self.titleComponent = titleComponent
            self.chatListTitle = chatListTitle
            self.leftButton = leftButton
            self.rightButtons = rightButtons
            self.backTitle = backTitle
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
            if lhs.backTitle != rhs.backTitle {
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
        let titleOffsetContainer: UIView
        let titleView: ImmediateTextView
        
        private var currentColor: UIColor?
        
        init(onPressed: @escaping () -> Void) {
            self.onPressed = onPressed
            
            self.arrowView = UIImageView()
            self.titleOffsetContainer = UIView()
            self.titleView = ImmediateTextView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.arrowView)
            
            self.addSubview(self.titleOffsetContainer)
            self.titleOffsetContainer.addSubview(self.titleView)
            
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
        
        func update(title: String, theme: PresentationTheme, availableSize: CGSize, transition: Transition) -> CGSize {
            self.titleView.attributedText = NSAttributedString(string: title, font: Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)
            let titleSize = self.titleView.updateLayout(CGSize(width: 100.0, height: 44.0))
            
            if self.currentColor != theme.rootController.navigationBar.accentTextColor {
                self.currentColor = theme.rootController.navigationBar.accentTextColor
                self.arrowView.image = NavigationBarTheme.generateBackArrowImage(color: theme.rootController.navigationBar.accentTextColor)
            }
            
            let iconSpacing: CGFloat = 8.0
            let iconOffset: CGFloat = -7.0
            
            let arrowSize = self.arrowView.image?.size ?? CGSize(width: 13.0, height: 22.0)
            
            let arrowFrame = CGRect(origin: CGPoint(x: iconOffset - 1.0, y: floor((availableSize.height - arrowSize.height) / 2.0)), size: arrowSize)
            transition.setPosition(view: self.arrowView, position: arrowFrame.center)
            transition.setBounds(view: self.arrowView, bounds: CGRect(origin: CGPoint(), size: arrowFrame.size))
            
            transition.setFrame(view: self.titleView, frame: CGRect(origin: CGPoint(x: iconOffset - 3.0 + arrowSize.width + iconSpacing, y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize))
            
            return CGSize(width: iconOffset + arrowSize.width + iconSpacing + titleSize.width, height: availableSize.height)
        }
    }
    
    private final class ContentView: UIView {
        let backPressed: () -> Void
        let openStatusSetup: (UIView) -> Void
        let toggleIsLocked: () -> Void
        
        let leftButtonOffsetContainer: UIView
        var leftButtonViews: [AnyHashable: ComponentView<NavigationButtonComponentEnvironment>] = [:]
        let rightButtonOffsetContainer: UIView
        var rightButtonViews: [AnyHashable: ComponentView<NavigationButtonComponentEnvironment>] = [:]
        var backButtonView: BackButtonView?
        
        let titleOffsetContainer: UIView
        let titleTextView: ImmediateTextView
        var titleContentView: ComponentView<Empty>?
        var chatListTitleView: ChatListTitleView?
        
        init(
            backPressed: @escaping () -> Void,
            openStatusSetup: @escaping (UIView) -> Void,
            toggleIsLocked: @escaping () -> Void
        ) {
            self.backPressed = backPressed
            self.openStatusSetup = openStatusSetup
            self.toggleIsLocked = toggleIsLocked
            
            self.leftButtonOffsetContainer = UIView()
            self.rightButtonOffsetContainer = UIView()
            self.titleOffsetContainer = UIView()
            
            self.titleTextView = ImmediateTextView()
            
            super.init(frame: CGRect())
            
            self.addSubview(self.titleOffsetContainer)
            self.addSubview(self.leftButtonOffsetContainer)
            self.addSubview(self.rightButtonOffsetContainer)
            
            self.titleOffsetContainer.addSubview(self.titleTextView)
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
        
        func updateNavigationTransitionAsPrevious(nextView: ContentView, fraction: CGFloat, transition: Transition, completion: @escaping () -> Void) {
            transition.setBounds(view: self.leftButtonOffsetContainer, bounds: CGRect(origin: CGPoint(x: fraction * self.bounds.width * 0.5, y: 0.0), size: self.leftButtonOffsetContainer.bounds.size), completion: { _ in
                completion()
            })
            transition.setAlpha(view: self.rightButtonOffsetContainer, alpha: pow(1.0 - fraction, 2.0))
            
            if let backButtonView = self.backButtonView {
                transition.setBounds(view: backButtonView, bounds: CGRect(origin: CGPoint(x: fraction * self.bounds.width * 0.5, y: 0.0), size: backButtonView.bounds.size), completion: { _ in
                    completion()
                })
            }
            
            if let chatListTitleView = self.chatListTitleView, let nextBackButtonView = nextView.backButtonView {
                let titleFrame = chatListTitleView.titleNode.view.convert(chatListTitleView.titleNode.bounds, to: self.titleOffsetContainer)
                let backButtonTitleFrame = nextBackButtonView.convert(nextBackButtonView.titleView.frame, to: nextView)
                
                let totalOffset = titleFrame.minX - backButtonTitleFrame.minX
                
                transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: totalOffset * fraction, y: 0.0), size: self.titleOffsetContainer.bounds.size))
                transition.setAlpha(view: self.titleOffsetContainer, alpha: pow(1.0 - fraction, 2.0))
            }
        }
        
        func updateNavigationTransitionAsNext(previousView: ContentView, fraction: CGFloat, transition: Transition, completion: @escaping () -> Void) {
            transition.setBounds(view: self.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: -(1.0 - fraction) * self.bounds.width, y: 0.0), size: self.titleOffsetContainer.bounds.size), completion: { _ in
                completion()
            })
            transition.setBounds(view: self.rightButtonOffsetContainer, bounds: CGRect(origin: CGPoint(x: -(1.0 - fraction) * self.bounds.width, y: 0.0), size: self.rightButtonOffsetContainer.bounds.size))
            if let backButtonView = self.backButtonView {
                transition.setScale(view: backButtonView.arrowView, scale: pow(max(0.001, fraction), 2.0))
                transition.setAlpha(view: backButtonView.arrowView, alpha: pow(fraction, 2.0))
                
                if let previousChatListTitleView = previousView.chatListTitleView {
                    let previousTitleFrame = previousChatListTitleView.titleNode.view.convert(previousChatListTitleView.titleNode.bounds, to: previousView.titleOffsetContainer)
                    let backButtonTitleFrame = backButtonView.convert(backButtonView.titleView.frame, to: self)
                    
                    let totalOffset = previousTitleFrame.minX - backButtonTitleFrame.minX
                    
                    transition.setBounds(view: backButtonView.titleOffsetContainer, bounds: CGRect(origin: CGPoint(x: -totalOffset * (1.0 - fraction), y: 0.0), size: backButtonView.titleOffsetContainer.bounds.size))
                    transition.setAlpha(view: backButtonView.titleOffsetContainer, alpha: pow(fraction, 2.0))
                }
            }
        }
        
        func update(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: Content, backTitle: String?, sideInset: CGFloat, size: CGSize, transition: Transition) {
            self.titleTextView.attributedText = NSAttributedString(string: content.title, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
            
            let buttonSpacing: CGFloat = 8.0
            
            var leftOffset = sideInset
            
            if let backTitle = backTitle {
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
                    self.addSubview(backButtonView)
                }
                let backButtonSize = backButtonView.update(title: backTitle, theme: theme, availableSize: CGSize(width: 100.0, height: size.height), transition: backButtonTransition)
                backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - backButtonSize.height) / 2.0)), size: backButtonSize))
                leftOffset += backButtonSize.width + buttonSpacing
            } else if let backButtonView = self.backButtonView {
                self.backButtonView = nil
                backButtonView.removeFromSuperview()
            }
            
            var validLeftButtons = Set<AnyHashable>()
            if let leftButton = content.leftButton {
                validLeftButtons.insert(leftButton.id)
                
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
                let buttonFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                if let buttonComponentView = buttonView.view {
                    if buttonComponentView.superview == nil {
                        self.leftButtonOffsetContainer.addSubview(buttonComponentView)
                    }
                    buttonTransition.setFrame(view: buttonComponentView, frame: buttonFrame)
                    if animateButtonIn {
                        transition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
                    }
                }
                leftOffset = buttonFrame.maxX + buttonSpacing
            }
            var removeLeftButtons: [AnyHashable] = []
            for (id, buttonView) in self.leftButtonViews {
                if !validLeftButtons.contains(id) {
                    if let buttonComponentView = buttonView.view {
                        transition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                            buttonComponentView?.removeFromSuperview()
                        })
                    }
                    removeLeftButtons.append(id)
                }
            }
            for id in removeLeftButtons {
                self.leftButtonViews.removeValue(forKey: id)
            }
            
            var rightOffset = size.width - sideInset
            var validRightButtons = Set<AnyHashable>()
            for rightButton in content.rightButtons {
                validRightButtons.insert(rightButton.id)
                
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
                let buttonFrame = CGRect(origin: CGPoint(x: rightOffset - buttonSize.width, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                if let buttonComponentView = buttonView.view {
                    if buttonComponentView.superview == nil {
                        self.rightButtonOffsetContainer.addSubview(buttonComponentView)
                    }
                    buttonTransition.setFrame(view: buttonComponentView, frame: buttonFrame)
                    if animateButtonIn {
                        transition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
                    }
                }
                rightOffset = buttonFrame.minX - buttonSpacing
            }
            var removeRightButtons: [AnyHashable] = []
            for (id, buttonView) in self.rightButtonViews {
                if !validRightButtons.contains(id) {
                    if let buttonComponentView = buttonView.view {
                        transition.setAlpha(view: buttonComponentView, alpha: 0.0, completion: { [weak buttonComponentView] _ in
                            buttonComponentView?.removeFromSuperview()
                        })
                    }
                    removeRightButtons.append(id)
                }
            }
            for id in removeRightButtons {
                self.rightButtonViews.removeValue(forKey: id)
            }
            
            let commonInset: CGFloat = max(leftOffset, size.width - rightOffset)
            let remainingWidth = size.width - commonInset * 2.0
            
            let titleTextSize = self.titleTextView.updateLayout(CGSize(width: remainingWidth, height: size.height))
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleTextSize.width) / 2.0), y: floor((size.height - titleTextSize.height) / 2.0)), size: titleTextSize)
            transition.setFrame(view: self.titleTextView, frame: titleFrame)
            
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
                        self.titleOffsetContainer.addSubview(titleContentComponentView)
                    }
                    titleContentTransition.setFrame(view: titleContentComponentView, frame: CGRect(origin: CGPoint(x: floor((size.width - titleContentSize.width) / 2.0), y: floor((size.height - titleContentSize.height) / 2.0)), size: titleContentSize))
                }
            } else {
                if let titleContentView = self.titleContentView {
                    self.titleContentView = nil
                    titleContentView.view?.removeFromSuperview()
                }
            }
            
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
                    self.titleOffsetContainer.addSubview(chatListTitleView)
                }
                
                let chatListTitleContentSize = size
                chatListTitleView.theme = theme
                chatListTitleView.strings = strings
                chatListTitleView.setTitle(chatListTitle, animated: false)
                chatListTitleView.updateLayout(size: chatListTitleContentSize, clearBounds: CGRect(origin: CGPoint(), size: chatListTitleContentSize), transition: transition.containedViewLayoutTransition)
                
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
                
                chatListTitleTransition.setFrame(view: chatListTitleView, frame: CGRect(origin: CGPoint(x: floor((size.width - chatListTitleContentSize.width) / 2.0), y: floor((size.height - chatListTitleContentSize.height) / 2.0)), size: chatListTitleContentSize))
            } else {
                if let chatListTitleView = self.chatListTitleView {
                    self.chatListTitleView = nil
                    chatListTitleView.removeFromSuperview()
                }
            }
            
            self.titleTextView.isHidden = self.chatListTitleView != nil || self.titleContentView != nil
        }
    }
    
    public final class View: UIView, NavigationBarHeaderView {
        private var component: ChatListHeaderComponent?
        private weak var state: EmptyComponentState?
        
        private var primaryContentView: ContentView?
        private var secondaryContentView: ContentView?
        
        private var effectiveContentView: ContentView? {
            return self.secondaryContentView ?? self.primaryContentView
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public var backArrowView: UIView? {
            return self.effectiveContentView?.backButtonView?.arrowView
        }
        
        public var backButtonTitleView: UIView? {
            return self.effectiveContentView?.backButtonView?.titleView
        }
        
        public var rightButtonView: UIView? {
            return self.effectiveContentView?.rightButtonViews.first?.value.view
        }
        
        public var titleContentView: UIView? {
            return self.effectiveContentView?.titleContentView?.view 
        }
        
        public func makeTransitionBackArrowView(accentColor: UIColor) -> UIView? {
            if let backArrowView = self.backArrowView {
                let view = UIImageView()
                view.image = NavigationBar.backArrowImage(color: accentColor)
                view.frame = backArrowView.convert(backArrowView.bounds, to: self)
                return view
            } else {
                return nil
            }
        }
        
        public func makeTransitionBackButtonView(accentColor: UIColor) -> UIView? {
            if let backButtonTitleView = self.backButtonTitleView as? ImmediateTextView {
                let view = ImmediateTextView()
                view.attributedText = NSAttributedString(string: backButtonTitleView.attributedText?.string ?? "", font: Font.regular(17.0), textColor: accentColor)
                let _ = view.updateLayout(CGSize(width: 100.0, height: 100.0))
                view.frame = backButtonTitleView.convert(backButtonTitleView.bounds, to: self)
                return view
            } else {
                return nil
            }
        }
        
        func update(component: ChatListHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.state = state
            
            let previousComponent = self.component
            self.component = component
            
            if let primaryContent = component.primaryContent {
                var primaryContentTransition = transition
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
                }
                primaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: primaryContent, backTitle: primaryContent.backTitle, sideInset: component.sideInset, size: availableSize, transition: primaryContentTransition)
                primaryContentTransition.setFrame(view: primaryContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
            } else if let primaryContentView = self.primaryContentView {
                self.primaryContentView = nil
                primaryContentView.removeFromSuperview()
            }
            
            if let secondaryContent = component.secondaryContent {
                var secondaryContentTransition = transition
                let secondaryContentView: ContentView
                if let current = self.secondaryContentView {
                    secondaryContentView = current
                } else {
                    secondaryContentTransition = .immediate
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
                    self.addSubview(secondaryContentView)
                }
                secondaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: secondaryContent, backTitle: component.primaryContent?.navigationBackTitle ?? component.primaryContent?.title, sideInset: component.sideInset, size: availableSize, transition: secondaryContentTransition)
                secondaryContentTransition.setFrame(view: secondaryContentView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let primaryContentView = self.primaryContentView {
                    if let previousComponent = previousComponent, previousComponent.secondaryContent == nil {
                        primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, fraction: 0.0, transition: .immediate, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, fraction: 0.0, transition: .immediate, completion: {})
                    }
                    
                    primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, fraction: component.secondaryTransition, transition: transition, completion: {})
                    secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, fraction: component.secondaryTransition, transition: transition, completion: {})
                }
            } else if let secondaryContentView = self.secondaryContentView {
                self.secondaryContentView = nil
                
                if let primaryContentView = self.primaryContentView {
                    primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, fraction: 0.0, transition: transition, completion: {})
                    secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, fraction: 0.0, transition: transition, completion: { [weak secondaryContentView] in
                        secondaryContentView?.removeFromSuperview()
                    })
                } else {
                    secondaryContentView.removeFromSuperview()
                }
            }
            
            return availableSize
        }
        
        public func findTitleView() -> ChatListTitleView? {
            return self.primaryContentView?.chatListTitleView
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class NavigationButtonComponentEnvironment: Equatable {
    public let theme: PresentationTheme
    
    public init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    public static func ==(lhs: NavigationButtonComponentEnvironment, rhs: NavigationButtonComponentEnvironment) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        return true
    }
}

public final class NavigationButtonComponent: Component {
    public typealias EnvironmentType = NavigationButtonComponentEnvironment
    
    public enum Content: Equatable {
        case text(title: String, isBold: Bool)
        case more
        case icon(imageName: String)
        case proxy(status: ChatTitleProxyStatus)
    }
    
    public let content: Content
    public let pressed: (UIView) -> Void
    public let contextAction: ((UIView, ContextGesture?) -> Void)?
    
    public init(
        content: Content,
        pressed: @escaping (UIView) -> Void,
        contextAction: ((UIView, ContextGesture?) -> Void)? = nil
    ) {
        self.content = content
        self.pressed = pressed
        self.contextAction = contextAction
    }
    
    public static func ==(lhs: NavigationButtonComponent, rhs: NavigationButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private var textView: ImmediateTextView?
        
        private var iconView: UIImageView?
        private var iconImageName: String?
        
        private var proxyNode: ChatTitleProxyNode?
        
        private var moreButton: MoreHeaderButton?
        
        private var component: NavigationButtonComponent?
        private var theme: PresentationTheme?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.textView?.alpha = 0.6
                    self.proxyNode?.alpha = 0.6
                    self.iconView?.alpha = 0.6
                } else {
                    self.textView?.alpha = 1.0
                    self.textView?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    
                    self.proxyNode?.alpha = 1.0
                    self.proxyNode?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    
                    self.iconView?.alpha = 1.0
                    self.iconView?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.pressed(self)
        }
        
        func update(component: NavigationButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonComponentEnvironment>, transition: Transition) -> CGSize {
            self.component = component
            
            let theme = environment[NavigationButtonComponentEnvironment.self].value.theme
            var themeUpdated = false
            if self.theme !== theme {
                self.theme = theme
                themeUpdated = true
            }
            
            let iconOffset: CGFloat = 4.0
            
            var textString: NSAttributedString?
            var imageName: String?
            var proxyStatus: ChatTitleProxyStatus?
            var isMore: Bool = false
            
            switch component.content {
            case let .text(title, isBold):
                textString = NSAttributedString(string: title, font: isBold ? Font.bold(17.0) : Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)
            case .more:
                isMore = true
            case let .icon(imageNameValue):
                imageName = imageNameValue
            case let .proxy(status):
                proxyStatus = status
            }
            
            var size = CGSize(width: 0.0, height: availableSize.height)
            
            if let textString = textString {
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
                size.width = textSize.width
                
                textView.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((availableSize.height - textSize.height) / 2.0)), size: textSize)
            } else if let textView = self.textView {
                self.textView = nil
                textView.removeFromSuperview()
            }
            
            if let imageName = imageName {
                let iconView: UIImageView
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    iconView.isUserInteractionEnabled = false
                    self.iconView = iconView
                    self.addSubview(iconView)
                }
                if self.iconImageName != imageName || themeUpdated {
                    self.iconImageName = imageName
                    iconView.image = generateTintedImage(image: UIImage(bundleImageName: imageName), color: theme.rootController.navigationBar.accentTextColor)
                }
                
                if let iconSize = iconView.image?.size {
                    size.width = iconSize.width
                    
                    iconView.frame = CGRect(origin: CGPoint(x: iconOffset, y: floor((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
            } else if let iconView = self.iconView {
                self.iconView = nil
                iconView.removeFromSuperview()
                self.iconImageName = nil
            }
            
            if let proxyStatus = proxyStatus {
                let proxyNode: ChatTitleProxyNode
                if let current = self.proxyNode {
                    proxyNode = current
                } else {
                    proxyNode = ChatTitleProxyNode(theme: theme)
                    proxyNode.isUserInteractionEnabled = false
                    self.proxyNode = proxyNode
                    self.addSubnode(proxyNode)
                }
                
                let proxySize = CGSize(width: 30.0, height: 30.0)
                size.width = proxySize.width
                
                proxyNode.theme = theme
                proxyNode.status = proxyStatus
                
                proxyNode.frame = CGRect(origin: CGPoint(x: iconOffset, y: floor((availableSize.height - proxySize.height) / 2.0)), size: proxySize)
            } else if let proxyNode = self.proxyNode {
                self.proxyNode = nil
                proxyNode.removeFromSupernode()
            }
            
            if isMore {
                let moreButton: MoreHeaderButton
                if let current = self.moreButton, !themeUpdated {
                    moreButton = current
                } else {
                    if let moreButton = self.moreButton {
                        moreButton.removeFromSupernode()
                        self.moreButton = nil
                    }
                    
                    moreButton = MoreHeaderButton(color: theme.rootController.navigationBar.buttonColor)
                    moreButton.isUserInteractionEnabled = true
                    moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: theme.rootController.navigationBar.buttonColor)))
                    moreButton.onPressed = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.pressed(self)
                    }
                    moreButton.contextAction = { [weak self] sourceNode, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.contextAction?(self, gesture)
                    }
                    self.moreButton = moreButton
                    self.addSubnode(moreButton)
                }
                
                let buttonSize = CGSize(width: 26.0, height: 44.0)
                size.width = buttonSize.width
                
                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: theme.rootController.navigationBar.buttonColor)))
                
                moreButton.frame = CGRect(origin: CGPoint(x: iconOffset, y: floor((availableSize.height - buttonSize.height) / 2.0)), size: buttonSize)
            } else if let moreButton = self.moreButton {
                self.moreButton = nil
                moreButton.removeFromSupernode()
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonComponentEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
