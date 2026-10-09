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
import SideColumnLayout

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
    /// iPhone Duo: how a button behaves in the side column. Its title also labels the button for
    /// VoiceOver (Apple: always provide titles for icon items).
    public struct OverflowInfo: Equatable {
        public var title: String
        public var iconName: String?
        /// Higher overflows later; nil never overflows.
        public var priority: Int?

        public init(title: String, iconName: String?, priority: Int?) {
            self.title = title
            self.iconName = iconName
            self.priority = priority
        }
    }

    /// An item of the side column's "…" menu: a button that did not fit.
    public struct OverflowItem {
        public let id: AnyHashable
        public let title: String
        public let iconName: String?
        /// The button's own action; it gets the "…" button as its source view.
        public let action: (UIView) -> Void

        public init(id: AnyHashable, title: String, iconName: String?, action: @escaping (UIView) -> Void) {
            self.id = id
            self.title = title
            self.iconName = iconName
            self.action = action
        }
    }

    /// iPhone Duo: whether a navigation button goes into the side column. Icon buttons do; text
    /// buttons stay in the row (Apple: text-only items stay horizontal).
    static func isColumnItem(_ button: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>) -> Bool {
        guard let navigationButton = button.component.wrapped as? NavigationButtonComponent else {
            return false
        }
        if case .text = navigationButton.content {
            return false
        }
        return true
    }
    
    public final class Content: Equatable {
        public let title: String
        public let navigationBackTitle: String?
        public let titleComponent: AnyComponent<Empty>?
        public let chatListTitle: NetworkStatusTitle?
        public let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
        public let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>]
        public let backPressed: (() -> Void)?
        public let overflowInfo: [AnyHashable: OverflowInfo]
        
        public init(
            title: String,
            navigationBackTitle: String?,
            titleComponent: AnyComponent<Empty>?,
            chatListTitle: NetworkStatusTitle?,
            leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?,
            rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>],
            backPressed: (() -> Void)?,
            overflowInfo: [AnyHashable: OverflowInfo] = [:]
        ) {
            self.title = title
            self.navigationBackTitle = navigationBackTitle
            self.titleComponent = titleComponent
            self.chatListTitle = chatListTitle
            self.leftButton = leftButton
            self.rightButtons = rightButtons
            self.backPressed = backPressed
            self.overflowInfo = overflowInfo
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
            if lhs.overflowInfo != rhs.overflowInfo {
                return false
            }
            return true
        }
    }
    
    public let leftInset: CGFloat
    public let rightInset: CGFloat
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
    /// iPhone Duo: the side column's length (`SideColumnRegion.frame.height`); nil lays every
    /// button out in the row.
    public let sideColumnLength: CGFloat?
    public let openSideColumnOverflow: ((UIView, [OverflowItem]) -> Void)?
    /// iPhone Duo: how much further than `rightInset` the right buttons stay from the right edge, to clear the
    /// status island beside the bar (`ContainerViewLayout.navigationBarTrailingButtonsInset`). The title keeps
    /// centering on the bar.
    public let trailingButtonsInset: CGFloat
    
    public init(
        leftInset: CGFloat,
        rightInset: CGFloat,
        trailingButtonsInset: CGFloat = 0.0,
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
        toggleIsLocked: @escaping () -> Void,
        sideColumnLength: CGFloat? = nil,
        openSideColumnOverflow: ((UIView, [OverflowItem]) -> Void)? = nil
    ) {
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.trailingButtonsInset = trailingButtonsInset
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
        self.sideColumnLength = sideColumnLength
        self.openSideColumnOverflow = openSideColumnOverflow
    }
    
    public static func ==(lhs: ChatListHeaderComponent, rhs: ChatListHeaderComponent) -> Bool {
        if lhs.leftInset != rhs.leftInset {
            return false
        }
        if lhs.rightInset != rhs.rightInset {
            return false
        }
        if lhs.trailingButtonsInset != rhs.trailingButtonsInset {
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
        if lhs.sideColumnLength != rhs.sideColumnLength {
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
        /// iPhone Duo: this content's part of the side column; the header view hosts them.
        let columnBackContainer: UIView
        let columnButtonsContainer: UIView
        private(set) var columnLayout: SideColumnItemsLayout?
        private var overflowButtonView: ComponentView<NavigationButtonComponentEnvironment>?
        private var overflowItems: [OverflowItem] = []
        private var openOverflow: ((UIView, [OverflowItem]) -> Void)?
        
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
        
        var leftButtonCount: Int {
            var count = self.leftButtonViews.values.filter { $0.view?.superview === self.leftButtonsContainer }.count
            if let backButtonView = self.backButtonView, backButtonView.superview === self.leftButtonsContainer {
                count += 1
            }
            return count
        }
        var rightButtonCount: Int {
            return self.rightButtonViews.values.filter { $0.view?.superview === self.rightButtonsContainer }.count
        }

        /// Whether a button view is in the row (the side column is hit-tested by its host).
        private func isInRow(_ view: UIView) -> Bool {
            return view.superview === self.leftButtonsContainer || view.superview === self.rightButtonsContainer
        }
        
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
            self.columnBackContainer = UIView()
            self.columnButtonsContainer = UIView()

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
            if let backButtonView = self.backButtonView, self.isInRow(backButtonView) {
                if let result = backButtonView.hitTest(self.convert(point, to: backButtonView), with: event) {
                    return result
                }
            }
            for (_, buttonView) in self.leftButtonViews {
                if let view = buttonView.view, self.isInRow(view), let result = view.hitTest(self.convert(point, to: view), with: event) {
                    return result
                }
            }
            for (_, buttonView) in self.rightButtonViews {
                if let view = buttonView.view, self.isInRow(view), let result = view.hitTest(self.convert(point, to: view), with: event) {
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
            alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: fraction * 10.0)
            
            if let backButtonView = self.backButtonView {
                let offsetX: CGFloat = backButtonView.superview === self.leftButtonsContainer ? fraction * self.bounds.width * 0.5 : 0.0
                transition.setBounds(view: backButtonView, bounds: CGRect(origin: CGPoint(x: offsetX, y: 0.0), size: backButtonView.bounds.size), completion: { _ in
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
            alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(fraction, 2.0))
            alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(fraction, 2.0))
            alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
        }
        
        func updateNavigationTransitionAsPreviousInplace(nextView: ContentView, fraction: CGFloat, transition: ComponentTransition, completion: @escaping () -> Void) {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.3)

            alphaTransition.setAlpha(view: self.leftButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.leftButtonsContainer.layer, radius: fraction * 10.0)
            alphaTransition.setAlpha(view: self.rightButtonsContainer, alpha: pow(1.0 - fraction, 2.0), completion: { _ in
                completion()
            })
            alphaTransition.setBlur(layer: self.rightButtonsContainer.layer, radius: fraction * 10.0)
            alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(1.0 - fraction, 2.0))
            alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: fraction * 10.0)
            
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
            alphaTransition.setAlpha(view: self.columnBackContainer, alpha: pow(fraction, 2.0))
            alphaTransition.setAlpha(view: self.columnButtonsContainer, alpha: pow(fraction, 2.0))
            alphaTransition.setBlur(layer: self.columnButtonsContainer.layer, radius: (1.0 - fraction) * 10.0)
        }
        
        func openEmojiStatusSetup() {
            self.chatListTitleView?.openEmojiStatusSetup()
        }
        
        /// Updates the view of `button` and puts it into `container` at `frame(size)`; returns its size.
        /// A view moving between the row and the side column (folding, unfolding) is placed without
        /// animation, so it never flies across the screen.
        private func updateButtonView(_ button: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>, isLeft: Bool, container: UIView, accessibilityLabel: String?, theme: PresentationTheme, availableHeight: CGFloat, transition: ComponentTransition, alphaTransition: ComponentTransition, frame: (CGSize) -> CGRect) -> CGSize {
            var buttonTransition = transition
            var animateButtonIn = false
            let buttonView: ComponentView<NavigationButtonComponentEnvironment>
            if let current = isLeft ? self.leftButtonViews[button.id] : self.rightButtonViews[button.id] {
                buttonView = current
            } else {
                buttonTransition = .immediate
                animateButtonIn = true
                buttonView = ComponentView<NavigationButtonComponentEnvironment>()
                if isLeft {
                    self.leftButtonViews[button.id] = buttonView
                } else {
                    self.rightButtonViews[button.id] = buttonView
                }
            }
            let buttonSize = buttonView.update(
                transition: buttonTransition,
                component: button.component,
                environment: {
                    NavigationButtonComponentEnvironment(theme: theme)
                },
                containerSize: CGSize(width: 100.0, height: availableHeight)
            )
            if let buttonComponentView = buttonView.view {
                if buttonComponentView.superview !== container {
                    buttonTransition = .immediate
                    container.addSubview(buttonComponentView)
                }
                if let accessibilityLabel {
                    buttonComponentView.accessibilityLabel = accessibilityLabel
                }
                buttonTransition.setFrame(view: buttonComponentView, frame: frame(buttonSize))
                if animateButtonIn {
                    alphaTransition.animateBlur(layer: buttonComponentView.layer, fromRadius: 10.0, toRadius: 0.0)
                    alphaTransition.animateAlpha(view: buttonComponentView, from: 0.0, to: 1.0)
                }
            }
            return buttonSize
        }
        
        func update(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: Content, displayBackButton: Bool, leftInset: CGFloat, rightInset: CGFloat, sideContentWidth: CGFloat, sideContentFraction: CGFloat, size: CGSize, columnLength: CGFloat?, openOverflow: ((UIView, [OverflowItem]) -> Void)?, transition: ComponentTransition) {
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
            
            self.openOverflow = openOverflow
            
            // iPhone Duo: back and the icon buttons go into the side column (a left icon button
            // first, then the right ones); text buttons stay in the row. Without a column, or when it
            // cannot hold what must stay, every button is in the row as before.
            var columnItems: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            var leftButtonInColumn = false
            if columnLength != nil {
                if let leftButton = content.leftButton, ChatListHeaderComponent.isColumnItem(leftButton) {
                    columnItems.append(leftButton)
                    leftButtonInColumn = true
                }
                columnItems.append(contentsOf: content.rightButtons.filter(ChatListHeaderComponent.isColumnItem))
            }
            let columnLayout: SideColumnItemsLayout? = columnLength.flatMap { columnLength in
                return sideColumnItemsLayout(regionLength: columnLength, hasBack: displayBackButton, priorities: columnItems.map { content.overflowInfo[$0.id]?.priority })
            }
            self.columnLayout = columnLayout
            if columnLayout == nil {
                leftButtonInColumn = false
            }
            let rowLeftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>? = leftButtonInColumn ? nil : content.leftButton
            let rowRightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = columnLayout != nil ? content.rightButtons.filter { !ChatListHeaderComponent.isColumnItem($0) } : content.rightButtons
            
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
                }
                let backContainer: UIView = columnLayout?.backFrame != nil ? self.columnBackContainer : self.leftButtonsContainer
                if backButtonView.superview !== backContainer {
                    backButtonTransition = .immediate
                    backContainer.addSubview(backButtonView)
                }
                if let backFrame = columnLayout?.backFrame {
                    let backButtonSize = backButtonView.update(theme: theme, strings: strings, availableSize: backFrame.size, transition: backButtonTransition)
                    backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: floor((backFrame.width - backButtonSize.width) / 2.0), y: floor((backFrame.height - backButtonSize.height) / 2.0)), size: backButtonSize))
                } else {
                    let backButtonSize = backButtonView.update(theme: theme, strings: strings, availableSize: CGSize(width: 100.0, height: size.height), transition: backButtonTransition)
                    backButtonTransition.setFrame(view: backButtonView, frame: CGRect(origin: CGPoint(x: nextLeftButtonX, y: floor((size.height - backButtonSize.height) / 2.0)), size: backButtonSize))
                    if nextLeftButtonX != 0.0 {
                        nextLeftButtonX += buttonSpacing
                    }
                    nextLeftButtonX += backButtonSize.width
                }
            } else if let backButtonView = self.backButtonView {
                self.backButtonView = nil
                backButtonView.removeFromSuperview()
            }
            
            var validLeftButtons = Set<AnyHashable>()
            if let leftButton = rowLeftButton {
                validLeftButtons.insert(leftButton.id)
                if nextLeftButtonX != 0.0 {
                    nextLeftButtonX += buttonSpacing
                }
                let originX = nextLeftButtonX
                let buttonSize = self.updateButtonView(leftButton, isLeft: true, container: self.leftButtonsContainer, accessibilityLabel: content.overflowInfo[leftButton.id]?.title, theme: theme, availableHeight: size.height, transition: transition, alphaTransition: alphaTransition, frame: { buttonSize in
                    return CGRect(origin: CGPoint(x: originX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                })
                nextLeftButtonX += buttonSize.width
            }
            
            var nextRightButtonX: CGFloat = 0.0
            var validRightButtons = Set<AnyHashable>()
            for rightButton in rowRightButtons.reversed() {
                validRightButtons.insert(rightButton.id)
                if nextRightButtonX != 0.0 {
                    nextRightButtonX += buttonSpacing
                }
                let originX = nextRightButtonX
                let buttonSize = self.updateButtonView(rightButton, isLeft: false, container: self.rightButtonsContainer, accessibilityLabel: content.overflowInfo[rightButton.id]?.title, theme: theme, availableHeight: size.height, transition: transition, alphaTransition: alphaTransition, frame: { buttonSize in
                    return CGRect(origin: CGPoint(x: originX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
                })
                nextRightButtonX += buttonSize.width
            }
            
            var overflowItems: [OverflowItem] = []
            if let columnLayout {
                for (cellIndex, itemIndex) in columnLayout.visibleItems.enumerated() {
                    let item = columnItems[itemIndex]
                    let isLeft = leftButtonInColumn && itemIndex == 0
                    if isLeft {
                        validLeftButtons.insert(item.id)
                    } else {
                        validRightButtons.insert(item.id)
                    }
                    let cellFrame = columnLayout.cellFrames[cellIndex]
                    let _ = self.updateButtonView(item, isLeft: isLeft, container: self.columnButtonsContainer, accessibilityLabel: content.overflowInfo[item.id]?.title, theme: theme, availableHeight: cellFrame.height, transition: transition, alphaTransition: alphaTransition, frame: { buttonSize in
                        return CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - buttonSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - buttonSize.height) / 2.0)), size: buttonSize)
                    })
                }
                for itemIndex in columnLayout.overflowItems {
                    let item = columnItems[itemIndex]
                    guard let navigationButton = item.component.wrapped as? NavigationButtonComponent else {
                        continue
                    }
                    let info = content.overflowInfo[item.id]
                    overflowItems.append(OverflowItem(id: item.id, title: info?.title ?? "", iconName: info?.iconName, action: navigationButton.pressed))
                }
            }
            self.overflowItems = overflowItems
            
            if let columnLayout, !columnLayout.overflowItems.isEmpty, let cellFrame = columnLayout.cellFrames.last {
                var overflowButtonTransition = transition
                let overflowButtonView: ComponentView<NavigationButtonComponentEnvironment>
                if let current = self.overflowButtonView {
                    overflowButtonView = current
                } else {
                    overflowButtonTransition = .immediate
                    overflowButtonView = ComponentView<NavigationButtonComponentEnvironment>()
                    self.overflowButtonView = overflowButtonView
                }
                let overflowButtonSize = overflowButtonView.update(
                    transition: overflowButtonTransition,
                    component: AnyComponent(NavigationButtonComponent(
                        content: .more,
                        pressed: { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            self.openOverflow?(sourceView, self.overflowItems)
                        }
                    )),
                    environment: {
                        NavigationButtonComponentEnvironment(theme: theme)
                    },
                    containerSize: CGSize(width: 100.0, height: cellFrame.height)
                )
                if let overflowButtonComponentView = overflowButtonView.view {
                    if overflowButtonComponentView.superview !== self.columnButtonsContainer {
                        overflowButtonTransition = .immediate
                        self.columnButtonsContainer.addSubview(overflowButtonComponentView)
                        alphaTransition.animateAlpha(view: overflowButtonComponentView, from: 0.0, to: 1.0)
                    }
                    overflowButtonComponentView.accessibilityLabel = strings.Common_More
                    overflowButtonTransition.setFrame(view: overflowButtonComponentView, frame: CGRect(origin: CGPoint(x: cellFrame.minX + floor((cellFrame.width - overflowButtonSize.width) / 2.0), y: cellFrame.minY + floor((cellFrame.height - overflowButtonSize.height) / 2.0)), size: overflowButtonSize))
                }
            } else if let overflowButtonView = self.overflowButtonView {
                self.overflowButtonView = nil
                if let overflowButtonComponentView = overflowButtonView.view {
                    alphaTransition.setAlpha(view: overflowButtonComponentView, alpha: 0.0, completion: { [weak overflowButtonComponentView] _ in
                        overflowButtonComponentView?.removeFromSuperview()
                    })
                }
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

            let commonInset: CGFloat = max(leftInset + nextLeftButtonX, rightInset + nextRightButtonX) + 8.0
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
            
            // Measured from the bar's edges, so each side includes its own inset (they differ where the
            // system reserves one side, e.g. iPhone Duo's vertical status bar). With the standard 16pt
            // inset these equal the former `nextLeftButtonX + 4.0` / `nextRightButtonX + 20.0`.
            let centerContentLeftInset: CGFloat = leftInset + nextLeftButtonX - 12.0
            let centerContentRightInset: CGFloat = rightInset + nextRightButtonX + 4.0
            
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
                centerContentOffsetX = -max(0.0, centerOffset + titleContentRect.maxX - 2.0 - (size.width - rightInset - nextRightButtonX))
                
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
        /// iPhone Duo: the side column (back circle and capsule), laid out in its own bounds. The host
        /// (`ChatListNavigationBar`) adds it to its hierarchy and sets its frame.
        public let sideColumnView: UIView
        private let columnBackContainer: UIView
        private let columnButtonsContainer: UIView
        private var columnBackBackgroundContainer: GlassContextExtractableContainer?
        private var columnButtonsBackgroundContainer: GlassContextExtractableContainer?
        
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
            self.sideColumnView = SparseContainerView()
            self.columnBackContainer = UIView()
            self.columnButtonsContainer = UIView()
            self.columnButtonsContainer.clipsToBounds = true

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
            if let columnButtonsBackgroundContainer = self.columnButtonsBackgroundContainer, sourceView.isDescendant(of: columnButtonsBackgroundContainer) {
                return columnButtonsBackgroundContainer
            }
            if let columnBackBackgroundContainer = self.columnBackBackgroundContainer, sourceView.isDescendant(of: columnBackBackgroundContainer) {
                return columnBackBackgroundContainer
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
            
            // Content centered on the bar (the titles and the story list) is laid out in the band
            // between the two insets, so it stays centered in the visible area when the sides differ
            // (iPhone Duo reserves one side for its vertical status bar). Inside the band both sides
            // get the symmetric part of the inset; the button containers below use the full insets.
            // With equal insets the band is the whole bar.
            let symmetricInset = min(component.leftInset, component.rightInset)
            let centeredContentFrame = CGRect(
                x: component.leftInset - symmetricInset,
                y: 0.0,
                width: availableSize.width - (component.leftInset - symmetricInset) - (component.rightInset - symmetricInset),
                height: availableSize.height
            )
            
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
                    self.columnBackContainer.addSubview(primaryContentView.columnBackContainer)
                    self.columnButtonsContainer.addSubview(primaryContentView.columnButtonsContainer)
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
                        backPressed: primaryContent.backPressed,
                        overflowInfo: primaryContent.overflowInfo
                    )
                }
                
                primaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: primaryContent, displayBackButton: primaryContent.backPressed != nil, leftInset: symmetricInset, rightInset: symmetricInset + component.trailingButtonsInset, sideContentWidth: sideContentWidth, sideContentFraction: (1.0 - component.storiesFraction), size: centeredContentFrame.size, columnLength: component.sideColumnLength, openOverflow: component.openSideColumnOverflow, transition: primaryContentTransition)
                primaryContentTransition.setFrame(view: primaryContentView, frame: centeredContentFrame)
                
                primaryContentView.updateContentOffsetFraction(contentOffsetFraction: 1.0 - self.storyOffsetFraction, transition: primaryContentTransition)
            } else if let primaryContentView = self.primaryContentView {
                self.primaryContentView = nil
                primaryContentView.removeFromSuperview()
                primaryContentView.leftButtonsContainer.removeFromSuperview()
                primaryContentView.rightButtonsContainer.removeFromSuperview()
                primaryContentView.columnBackContainer.removeFromSuperview()
                primaryContentView.columnButtonsContainer.removeFromSuperview()
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
                        leftInset: symmetricInset,
                        rightInset: symmetricInset,
                        title: primaryTitle,
                        titleHasLock: primaryTitleHasLock,
                        titleHasActivity: primaryTitleHasActivity,
                        titlePeerStatus: primaryTitlePeerStatus,
                        minTitleX: self.primaryContentView?.centerContentLeftInset ?? 0.0,
                        maxTitleX: centeredContentFrame.width - (self.primaryContentView?.centerContentRightInset ?? 0.0),
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
                    containerSize: CGSize(width: centeredContentFrame.width, height: ChatListNavigationBar.storiesScrollHeight)
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
                    self.columnBackContainer.addSubview(secondaryContentView.columnBackContainer)
                    self.columnButtonsContainer.addSubview(secondaryContentView.columnButtonsContainer)
                }
                secondaryContentView.update(context: component.context, theme: component.theme, strings: component.strings, content: secondaryContent, displayBackButton: true, leftInset: symmetricInset, rightInset: symmetricInset + component.trailingButtonsInset, sideContentWidth: 0.0, sideContentFraction: 0.0, size: centeredContentFrame.size, columnLength: component.sideColumnLength, openOverflow: component.openSideColumnOverflow, transition: secondaryContentTransition)
                secondaryContentTransition.setFrame(view: secondaryContentView, frame: centeredContentFrame)
                
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
                            secondaryContentView?.columnBackContainer.removeFromSuperview()
                            secondaryContentView?.columnButtonsContainer.removeFromSuperview()
                            secondaryContentView?.removeFromSuperview()
                        })
                    } else {
                        primaryContentView.updateNavigationTransitionAsPrevious(nextView: secondaryContentView, width: availableSize.width, fraction: 0.0, transition: transition, completion: {})
                        secondaryContentView.updateNavigationTransitionAsNext(previousView: primaryContentView, storyPeerListView: self.storyPeerListView(), fraction: 0.0, transition: transition, completion: { [weak secondaryContentView] in
                            secondaryContentView?.leftButtonsContainer.removeFromSuperview()
                            secondaryContentView?.rightButtonsContainer.removeFromSuperview()
                            secondaryContentView?.columnBackContainer.removeFromSuperview()
                            secondaryContentView?.columnButtonsContainer.removeFromSuperview()
                            secondaryContentView?.removeFromSuperview()
                        })
                    }
                } else {
                    secondaryContentView.leftButtonsContainer.removeFromSuperview()
                    secondaryContentView.rightButtonsContainer.removeFromSuperview()
                    secondaryContentView.columnBackContainer.removeFromSuperview()
                    secondaryContentView.columnButtonsContainer.removeFromSuperview()
                    secondaryContentView.removeFromSuperview()
                }
            }
            
            if let storyPeerList = self.storyPeerList, let storyPeerListComponentView = storyPeerList.view as? StoryPeerListComponent.View {
                if storyPeerListComponentView.superview == nil {
                    self.addSubview(storyPeerListComponentView)
                }
                
                let storyPeerListMaxOffset: CGFloat = availableSize.height + 2.0
                
                var storiesX: CGFloat = centeredContentFrame.minX
                storiesX -= availableSize.width * component.secondaryTransition
                
                storyListTransition.setFrame(view: storyPeerListComponentView, frame: CGRect(origin: CGPoint(x: storiesX, y: storyPeerListMaxOffset), size: CGSize(width: centeredContentFrame.width, height: 79.0)))
                
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

            var visibleContentViews: [ContentView] = []
            if let primaryContentView = self.primaryContentView, self.secondaryContentView == nil || component.secondaryTransition < 1.0 {
                visibleContentViews.append(primaryContentView)
            }
            if let secondaryContentView = self.secondaryContentView, component.secondaryTransition > 0.0 {
                visibleContentViews.append(secondaryContentView)
            }
            let leftButtonCount = visibleContentViews.reduce(0, { $0 + $1.leftButtonCount })
            let rightButtonCount = visibleContentViews.reduce(0, { $0 + $1.rightButtonCount })

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
                let leftButtonsContainerFrame = CGRect(origin: CGPoint(x: component.leftInset, y: 0.0), size: CGSize(width: max(44.0, leftButtonsEffectiveWidth), height: 44.0))
                leftButtonsBackgroundContainerTransition.setFrame(view: leftButtonsBackgroundContainer, frame: leftButtonsContainerFrame)
                leftButtonsBackgroundContainer.update(size: leftButtonsContainerFrame.size, cornerRadius: leftButtonsContainerFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: leftButtonsBackgroundContainerTransition)
                leftButtonsBackgroundContainer.morphsIntoContextMenu = leftButtonCount == 1
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
                
                let rightButtonsContainerFrame = CGRect(origin: CGPoint(x: availableSize.width - component.rightInset - component.trailingButtonsInset - max(44.0, rightButtonsEffectiveWidth), y: 0.0), size: CGSize(width: max(44.0, rightButtonsEffectiveWidth), height: 44.0))
                
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
                rightButtonsBackgroundContainer.morphsIntoContextMenu = rightButtonCount == 1
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
            
            self.updateSideColumn(component: component, transition: transition)
            
            return availableSize
        }
        
        /// Lays out the side column from the contents' column layouts: crossfading contents (a forum
        /// opening inline) interpolate the capsule and share the back circle by `secondaryTransition`.
        private func updateSideColumn(component: ChatListHeaderComponent, transition: ComponentTransition) {
            var contents: [(view: ContentView, weight: CGFloat)] = []
            if let primaryContentView = self.primaryContentView {
                contents.append((primaryContentView, self.secondaryContentView == nil ? 1.0 : 1.0 - component.secondaryTransition))
            }
            if let secondaryContentView = self.secondaryContentView {
                contents.append((secondaryContentView, component.secondaryTransition))
            }
            
            var backAlpha: CGFloat = 0.0
            var capsuleAlpha: CGFloat = 0.0
            var capsuleFrame: CGRect?
            var columnBackFrame: CGRect?
            for (contentView, weight) in contents {
                guard let columnLayout = contentView.columnLayout else {
                    continue
                }
                if let layoutBackFrame = columnLayout.backFrame {
                    backAlpha += weight
                    if columnBackFrame == nil {
                        columnBackFrame = layoutBackFrame
                    }
                }
                if let frame = columnLayout.capsuleFrame {
                    capsuleAlpha += weight
                    if let current = capsuleFrame {
                        capsuleFrame = CGRect(x: frame.minX, y: current.minY * (1.0 - weight) + frame.minY * weight, width: frame.width, height: current.height * (1.0 - weight) + frame.height * weight)
                    } else {
                        capsuleFrame = frame
                    }
                }
            }
            let isDark = component.theme.overallDarkAppearance
            
            if backAlpha > 0.0, let backFrame = columnBackFrame {
                var backTransition = transition
                let backBackgroundContainer: GlassContextExtractableContainer
                if let current = self.columnBackBackgroundContainer {
                    backBackgroundContainer = current
                } else {
                    backTransition = backTransition.withAnimation(.none)
                    backBackgroundContainer = GlassContextExtractableContainer()
                    self.columnBackBackgroundContainer = backBackgroundContainer
                    self.sideColumnView.addSubview(backBackgroundContainer)
                    backBackgroundContainer.contentView.addSubview(self.columnBackContainer)
                    backBackgroundContainer.alpha = 0.0
                }
                backTransition.setFrame(view: backBackgroundContainer, frame: backFrame)
                backBackgroundContainer.update(size: backFrame.size, cornerRadius: backFrame.height * 0.5, isDark: isDark, tintColor: .init(kind: .panel), isInteractive: true, transition: backTransition)
                backTransition.setFrame(view: self.columnBackContainer, frame: backFrame)
                for (contentView, _) in contents {
                    backTransition.setFrame(view: contentView.columnBackContainer, frame: backFrame)
                }
                transition.setAlpha(view: backBackgroundContainer, alpha: backAlpha)
            } else if let backBackgroundContainer = self.columnBackBackgroundContainer {
                self.columnBackBackgroundContainer = nil
                transition.setAlpha(view: backBackgroundContainer, alpha: 0.0, completion: { [weak backBackgroundContainer] _ in
                    backBackgroundContainer?.removeFromSuperview()
                })
            }
            
            if let capsuleFrame {
                var capsuleTransition = transition
                let capsuleBackgroundContainer: GlassContextExtractableContainer
                if let current = self.columnButtonsBackgroundContainer {
                    capsuleBackgroundContainer = current
                } else {
                    capsuleTransition = capsuleTransition.withAnimation(.none)
                    capsuleBackgroundContainer = GlassContextExtractableContainer()
                    self.columnButtonsBackgroundContainer = capsuleBackgroundContainer
                    self.sideColumnView.addSubview(capsuleBackgroundContainer)
                    capsuleBackgroundContainer.contentView.addSubview(self.columnButtonsContainer)
                    capsuleBackgroundContainer.alpha = 0.0
                }
                capsuleTransition.setFrame(view: capsuleBackgroundContainer, frame: capsuleFrame)
                capsuleBackgroundContainer.update(size: capsuleFrame.size, cornerRadius: capsuleFrame.width * 0.5, isDark: isDark, tintColor: .init(kind: .panel), isInteractive: true, transition: capsuleTransition)
                capsuleBackgroundContainer.morphsIntoContextMenu = self.effectiveContentView?.columnLayout?.cellFrames.count == 1
                capsuleTransition.setFrame(view: self.columnButtonsContainer, frame: CGRect(origin: CGPoint(), size: capsuleFrame.size))
                for (contentView, _) in contents {
                    let size = contentView.columnLayout?.capsuleFrame?.size ?? capsuleFrame.size
                    capsuleTransition.setFrame(view: contentView.columnButtonsContainer, frame: CGRect(origin: CGPoint(), size: size))
                }
                transition.setAlpha(view: capsuleBackgroundContainer, alpha: capsuleAlpha)
            } else if let capsuleBackgroundContainer = self.columnButtonsBackgroundContainer {
                self.columnButtonsBackgroundContainer = nil
                transition.setAlpha(view: capsuleBackgroundContainer, alpha: 0.0, completion: { [weak capsuleBackgroundContainer] _ in
                    capsuleBackgroundContainer?.removeFromSuperview()
                })
            }
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
