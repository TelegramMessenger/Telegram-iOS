import Foundation
import UIKit
import Display
import ComponentFlow
import ListSectionComponent
import TelegramPresentationData
import AppBundle
import ChatListUI
import AccountContext
import Postbox
import TelegramCore

final class GreetingMessageListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let accountPeer: EnginePeer
    let message: EngineMessage
    let count: Int
    let action: (() -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        accountPeer: EnginePeer,
        message: EngineMessage,
        count: Int,
        action: (() -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.accountPeer = accountPeer
        self.message = message
        self.count = count
        self.action = action
    }

    static func ==(lhs: GreetingMessageListItemComponent, rhs: GreetingMessageListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton, ListSectionComponent.ChildView {
        private var component: GreetingMessageListItemComponent?
        private weak var componentState: EmptyComponentState?
        
        private var chatListPresentationData: ChatListPresentationData?
        private var chatListNodeInteraction: ChatListNodeInteraction?
        
        private var itemNode: ListViewItemNode?
        
        var customUpdateIsHighlighted: ((Bool) -> Void)?
        private(set) var separatorInset: CGFloat = 0.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.internalHighligthedChanged = { [weak self] isHighlighted in
                guard let self, let component = self.component, component.action != nil else {
                    return
                }
                if let customUpdateIsHighlighted = self.customUpdateIsHighlighted {
                    customUpdateIsHighlighted(isHighlighted)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.action?()
        }
        
        func update(component: GreetingMessageListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            self.isEnabled = component.action != nil
            
            let chatListPresentationData: ChatListPresentationData
            if let current = self.chatListPresentationData, let previousComponent, previousComponent.theme === component.theme {
                chatListPresentationData = current
            } else {
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                chatListPresentationData = ChatListPresentationData(
                    theme: component.theme,
                    fontSize: presentationData.listsFontSize,
                    strings: component.strings,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameSortOrder: presentationData.nameSortOrder,
                    nameDisplayOrder: presentationData.nameDisplayOrder,
                    disableAnimations: false
                )
                self.chatListPresentationData = chatListPresentationData
            }
            
            let chatListNodeInteraction: ChatListNodeInteraction
            if let current = self.chatListNodeInteraction {
                chatListNodeInteraction = current
            } else {
                chatListNodeInteraction = ChatListNodeInteraction(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    activateSearch: {
                    },
                    peerSelected: { _, _, _, _, _ in
                    },
                    disabledPeerSelected: { _, _, _ in
                    },
                    togglePeerSelected: { _, _ in
                    },
                    togglePeersSelection: { _, _ in
                    },
                    additionalCategorySelected: { _ in
                    },
                    messageSelected: { _, _, _, _ in
                    },
                    groupSelected: { _ in
                    },
                    addContact: { _ in
                    },
                    setPeerIdWithRevealedOptions: { _, _ in
                    },
                    setItemPinned: { _, _ in
                    },
                    setPeerMuted: { _, _ in
                    },
                    setPeerThreadMuted: { _, _, _ in
                    },
                    deletePeer: { _, _ in
                    },
                    deletePeerThread: { _, _ in
                    },
                    setPeerThreadStopped: { _, _, _ in
                    },
                    setPeerThreadPinned: { _, _, _ in
                    },
                    setPeerThreadHidden: { _, _, _ in
                    },
                    updatePeerGrouping: { _, _ in
                    },
                    togglePeerMarkedUnread: { _, _ in
                    },
                    toggleArchivedFolderHiddenByDefault: {
                    },
                    toggleThreadsSelection: { _, _ in
                    },
                    hidePsa: { _ in
                    },
                    activateChatPreview: { _, _, _, _, _ in
                    },
                    present: { _ in
                    },
                    openForumThread: { _, _ in
                    },
                    openStorageManagement: {
                    },
                    openPasswordSetup: {
                    },
                    openPremiumIntro: {
                    },
                    openPremiumGift: { _, _ in
                    },
                    openPremiumManagement: {
                    },
                    openActiveSessions: {
                    },
                    openBirthdaySetup: {
                    },
                    performActiveSessionAction: { _, _ in
                    },
                    openChatFolderUpdates: {
                    },
                    hideChatFolderUpdates: {
                    },
                    openStories: { _, _ in
                    },
                    openStarsTopup: { _ in
                    },
                    dismissNotice: { _ in
                    },
                    editPeer: { _ in
                    },
                    openWebApp: { _ in
                    },
                    openPhotoSetup: {
                    },
                    openAdInfo: { _, _ in
                    },
                    openAccountFreezeInfo: {
                    },
                    openUrl: { _ in
                    }
                )
                self.chatListNodeInteraction = chatListNodeInteraction
            }
            
            let chatListItem = ChatListItem(
                presentationData: chatListPresentationData,
                context: component.context,
                chatListLocation: .chatList(groupId: .root),
                filterData: nil,
                index: EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: component.message.index)),
                content: .peer(ChatListItemContent.PeerData(
                    messages: [component.message],
                    peer: EngineRenderedPeer(peer: component.accountPeer),
                    threadInfo: nil,
                    combinedReadState: nil,
                    isRemovedFromTotalUnreadCount: false,
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    draftState: nil,
                    mediaDraftContentType: nil,
                    inputActivities: nil,
                    promoInfo: nil,
                    ignoreUnreadBadge: false,
                    displayAsMessage: false,
                    hasFailedMessages: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    autoremoveTimeout: nil,
                    storyState: nil,
                    requiresPremiumForMessaging: false,
                    displayAsTopicList: false,
                    tags: [],
                    customMessageListData: ChatListItemContent.CustomMessageListData(
                        commandPrefix: nil,
                        searchQuery: nil,
                        messageCount: component.count,
                        hideSeparator: true,
                        hideDate: true,
                        hidePeerStatus: true
                    )
                )),
                editing: false,
                hasActiveRevealControls: false,
                selected: false,
                header: nil,
                enabledContextActions: nil,
                hiddenOffset: false,
                interaction: chatListNodeInteraction
            )
            var itemNode: ListViewItemNode?
            let params = ListViewItemLayoutParams(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 1000.0)
            if let current = self.itemNode {
                itemNode = current
                chatListItem.updateNode(
                    async: { f in f () },
                    node: {
                        return current
                    },
                    params: params,
                    previousItem: nil,
                    nextItem: nil, animation: .None,
                    completion: { layout, apply in
                        let nodeFrame = CGRect(origin: current.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                        
                        current.contentSize = layout.contentSize
                        current.insets = layout.insets
                        current.frame = nodeFrame
                        
                        apply(ListViewItemApply(isOnScreen: true))
                    })
            } else {
                var outItemNode: ListViewItemNode?
                chatListItem.nodeConfiguredForParams(
                    async: { f in f() },
                    params: params,
                    synchronousLoads: true,
                    previousItem: nil,
                    nextItem: nil,
                    completion: { node, apply in
                        outItemNode = node
                        apply().1(ListViewItemApply(isOnScreen: true))
                    }
                )
                itemNode = outItemNode
            }
            
            let size = CGSize(width: availableSize.width, height: itemNode?.contentSize.height ?? 44.0)
            
            if self.itemNode !== itemNode {
                self.itemNode?.removeFromSupernode()
                
                self.itemNode = itemNode
                if let itemNode {
                    itemNode.isUserInteractionEnabled = false
                    self.addSubview(itemNode.view)
                }
            }
            if let itemNode = self.itemNode {
                itemNode.frame = CGRect(origin: CGPoint(), size: size)
            }
            
            self.separatorInset = 76.0
            
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
