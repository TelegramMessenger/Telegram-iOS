import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import ChatListTitleView
import StoryPeerListComponent
import TelegramCore
import NavigationBarComponent

/// The chat list's header: the generic navigation bar row (`NavigationBarComponent`) plus what only the chat
/// list has: the story list, the chat-list title (network status, lock, emoji status) and the proxy button.
public final class ChatListHeaderComponent: Component {
    public final class Content: Equatable {
        public let title: String
        public let titleComponent: AnyComponent<Empty>?
        public let chatListTitle: NetworkStatusTitle?
        public let leftButton: NavigationBarComponent.Button?
        public let rightButtons: [NavigationBarComponent.Button]
        public let backPressed: (() -> Void)?
        /// iPhone Duo: the buttons' column behavior and VoiceOver titles, by button id.
        public let overflowInfo: [AnyHashable: NavigationBarComponent.OverflowInfo]

        public init(
            title: String,
            titleComponent: AnyComponent<Empty>?,
            chatListTitle: NetworkStatusTitle?,
            leftButton: NavigationBarComponent.Button?,
            rightButtons: [NavigationBarComponent.Button],
            backPressed: (() -> Void)?,
            overflowInfo: [AnyHashable: NavigationBarComponent.OverflowInfo] = [:]
        ) {
            self.title = title
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
    public let openSideColumnOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)?
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
        openSideColumnOverflow: ((UIView, [NavigationBarComponent.OverflowItem]) -> Void)? = nil
    ) {
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.trailingButtonsInset = trailingButtonsInset
        self.primaryContent = primaryContent
        self.secondaryContent = secondaryContent
        self.secondaryTransition = secondaryTransition
        self.context = context
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

    public final class View: UIView {
        private var component: ChatListHeaderComponent?
        private weak var state: EmptyComponentState?

        private let navigationBar = ComponentView<Empty>()
        private var navigationBarTheme: (source: PresentationTheme, value: NavigationBarTheme)?
        private var navigationBarStrings: (source: PresentationStrings, value: NavigationBarStrings)?

        private let storyPeerListExternalState = StoryPeerListComponent.ExternalState()
        private var storyPeerList: ComponentView<Empty>?
        public var storyPeerAction: ((EnginePeer?) -> Void)?
        public var storyContextPeerAction: ((ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void)?
        public var storyComposeAction: ((CGFloat) -> Void)?

        private var navigationBarView: NavigationBarComponent.View? {
            return self.navigationBar.view as? NavigationBarComponent.View
        }

        /// The row the chat list's header is built on (the regular bar's component).
        public var navigationBarComponentView: NavigationBarComponent.View? {
            return self.navigationBarView
        }
        /// The content the row shows, for a navigation transition's capsules: the inline forum's from halfway in.
        public private(set) var transitionContent: NavigationBarComponent.Content?
        public private(set) var navigationBarThemeValue: NavigationBarTheme?
        public private(set) var navigationBarStringsValue: NavigationBarStrings?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// iPhone Duo: the side column (back circle and capsule), laid out in its own bounds. The host
        /// (`ChatListNavigationBar`) adds it to its hierarchy and sets its frame. Nil before the first update.
        public var sideColumnView: UIView? {
            return self.navigationBarView?.sideColumnView
        }

        public var rightButtonViews: [AnyHashable: UIView] {
            return self.navigationBarView?.rightButtonViews ?? [:]
        }

        public func storyPeerListView() -> StoryPeerListComponent.View? {
            return self.storyPeerList?.view as? StoryPeerListComponent.View
        }

        public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
            return self.navigationBarView?.navigationButtonContextContainer(sourceView: sourceView)
        }

        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let storyPeerListView = self.storyPeerList?.view {
                if let result = storyPeerListView.hitTest(self.convert(point, to: storyPeerListView), with: event) {
                    return result
                }
            }
            if let navigationBarView = self.navigationBarView, navigationBarView.isUserInteractionEnabled, navigationBarView.alpha >= 0.01, !navigationBarView.isHidden {
                if let result = navigationBarView.hitTest(self.convert(point, to: navigationBarView), with: event) {
                    return result
                }
            }
            return super.hitTest(point, with: event)
        }

        func openEmojiStatusSetup() {
            if let storyPeerListView = self.storyPeerList?.view as? StoryPeerListComponent.View {
                storyPeerListView.openEmojiStatusSetup()
            } else {
                self.findTitleView()?.openEmojiStatusSetup()
            }
        }

        public func findTitleView() -> ChatListTitleView? {
            return (self.navigationBarView?.primaryTitleView as? ChatListTitleComponent.View)?.titleView
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

        private func resolvedNavigationBarTheme(_ theme: PresentationTheme) -> NavigationBarTheme {
            if let current = self.navigationBarTheme, current.source === theme {
                return current.value
            }
            let value = NavigationBarTheme(rootControllerTheme: theme)
            self.navigationBarTheme = (theme, value)
            return value
        }

        private func resolvedNavigationBarStrings(_ strings: PresentationStrings) -> NavigationBarStrings {
            if let current = self.navigationBarStrings, current.source === strings {
                return current.value
            }
            let value = NavigationBarStrings(presentationStrings: strings)
            self.navigationBarStrings = (strings, value)
            return value
        }

        /// The chat list's content as the generic bar's. While there are stories the story list draws the
        /// primary title, so the bar's is empty. Exactly one title kind is set per content in practice: the chat
        /// list's root sets `chatListTitle`, a forum sets `titleComponent`.
        private func navigationBarContent(_ content: Content, isSecondary: Bool, component: ChatListHeaderComponent) -> NavigationBarComponent.Content {
            let title: NavigationBarComponent.Title
            if !isSecondary && component.storySubscriptions != nil {
                title = .text("")
            } else if let chatListTitle = content.chatListTitle {
                title = .custom(AnyComponent(ChatListTitleComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    title: chatListTitle,
                    sideContentFraction: isSecondary ? 0.0 : (1.0 - component.storiesFraction),
                    openStatusSetup: component.openStatusSetup,
                    toggleIsLocked: component.toggleIsLocked
                )))
            } else if let titleComponent = content.titleComponent {
                title = .component(titleComponent)
            } else {
                title = .text(content.title)
            }

            let overflowInfo = content.overflowInfo
            let applyOverflowInfo: (NavigationBarComponent.Button) -> NavigationBarComponent.Button = { button in
                if let info = overflowInfo[button.id] {
                    return button.withOverflow(info)
                }
                return button
            }

            return NavigationBarComponent.Content(
                title: title,
                back: (isSecondary || content.backPressed != nil) ? .back : nil,
                leftButton: content.leftButton.map(applyOverflowInfo),
                rightButtons: content.rightButtons.map(applyOverflowInfo),
                backPressed: content.backPressed ?? {}
            )
        }

        func update(component: ChatListHeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.state = state
            self.component = component

            let primaryContent = component.primaryContent.flatMap { self.navigationBarContent($0, isSecondary: false, component: component) }
            let secondaryContent = component.secondaryContent.flatMap { self.navigationBarContent($0, isSecondary: true, component: component) }
            self.transitionContent = NavigationBarComponent.visibleContent(primary: primaryContent, secondary: secondaryContent, secondaryTransition: component.secondaryTransition)
            let navigationBarTheme = self.resolvedNavigationBarTheme(component.theme)
            let navigationBarStrings = self.resolvedNavigationBarStrings(component.strings)
            self.navigationBarThemeValue = navigationBarTheme
            self.navigationBarStringsValue = navigationBarStrings

            let navigationBarSize = self.navigationBar.update(
                transition: transition,
                component: AnyComponent(NavigationBarComponent(
                    theme: navigationBarTheme,
                    strings: navigationBarStrings,
                    leftInset: component.leftInset,
                    rightInset: component.rightInset,
                    trailingButtonsInset: component.trailingButtonsInset,
                    primaryContent: primaryContent,
                    secondaryContent: secondaryContent,
                    secondaryTransition: component.secondaryTransition,
                    sideColumnLength: component.sideColumnLength,
                    openSideColumnOverflow: component.openSideColumnOverflow
                )),
                environment: {},
                containerSize: availableSize
            )
            guard let navigationBarView = self.navigationBarView else {
                return availableSize
            }
            if navigationBarView.superview == nil {
                self.addSubview(navigationBarView)
                navigationBarView.frame = CGRect(origin: CGPoint(), size: navigationBarSize)
            } else {
                transition.setFrame(view: navigationBarView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
            }

            let centeredContentFrame = navigationBarView.centeredContentFrame
            let symmetricInset = min(component.leftInset, component.rightInset)

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
                        minTitleX: navigationBarView.primaryCenterContentInsets.left,
                        maxTitleX: centeredContentFrame.width - navigationBarView.primaryCenterContentInsets.right,
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

            if let storyPeerList = self.storyPeerList, let storyPeerListComponentView = storyPeerList.view as? StoryPeerListComponent.View {
                if storyPeerListComponentView.superview == nil {
                    navigationBarView.underButtonsView.addSubview(storyPeerListComponentView)
                }

                let storyPeerListMaxOffset: CGFloat = availableSize.height + 2.0

                var storiesX: CGFloat = centeredContentFrame.minX
                storiesX -= availableSize.width * component.secondaryTransition

                storyListTransition.setFrame(view: storyPeerListComponentView, frame: CGRect(origin: CGPoint(x: storiesX, y: storyPeerListMaxOffset), size: CGSize(width: centeredContentFrame.width, height: 79.0)))

                let storyListNormalAlpha: CGFloat = 1.0

                let storyListAlpha: CGFloat = (1.0 - component.secondaryTransition) * storyListNormalAlpha
                storyListTransition.setAlpha(view: storyPeerListComponentView, alpha: storyListAlpha)
            }

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
