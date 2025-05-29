import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import AccountContext
import PeerOnlineMarkerNode
import LocalizedPeerData
import PeerPresenceStatusManager
import PhotoResources
import ChatListSearchItemNode
import ContextUI
import ChatInterfaceState
import TextFormat
import InvisibleInkDustNode
import GalleryUI
import HierarchyTrackingLayer
import TextNodeWithEntities
import ComponentFlow
import EmojiStatusComponent
import AvatarVideoNode
import AppBundle
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ShimmerEffect

public enum ChatListItemContent {
    public final class ThreadInfo: Equatable {
        public let id: Int64
        public let info: EngineMessageHistoryThread.Info
        public let isOwnedByMe: Bool
        public let isClosed: Bool
        public let isHidden: Bool
        public let threadPeer: EnginePeer?
        
        public init(id: Int64, info: EngineMessageHistoryThread.Info, isOwnedByMe: Bool, isClosed: Bool, isHidden: Bool, threadPeer: EnginePeer?) {
            self.id = id
            self.info = info
            self.isOwnedByMe = isOwnedByMe
            self.isClosed = isClosed
            self.isHidden = isHidden
            self.threadPeer = threadPeer
        }
        
        public static func ==(lhs: ThreadInfo, rhs: ThreadInfo) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.info != rhs.info {
                return false
            }
            if lhs.isOwnedByMe != rhs.isOwnedByMe {
                return false
            }
            if lhs.isClosed != rhs.isClosed {
                return false
            }
            if lhs.isHidden != rhs.isHidden {
                return false
            }
            if lhs.threadPeer != rhs.threadPeer {
                return false
            }
            return true
        }
    }
    
    public final class DraftState: Equatable {
        let text: String
        let entities: [MessageTextEntity]

        public init(draft: EngineChatList.Draft) {
            self.text = draft.text
            self.entities = draft.entities
        }

        public static func ==(lhs: DraftState, rhs: DraftState) -> Bool {
            if lhs.text != rhs.text {
                return false
            }
            if lhs.entities != rhs.entities {
                return false
            }
            return true
        }
    }
    
    public struct StoryState: Equatable {
        public var stats: EngineChatList.StoryStats
        public var hasUnseenCloseFriends: Bool
        
        public init(
            stats: EngineChatList.StoryStats,
            hasUnseenCloseFriends: Bool
        ) {
            self.stats = stats
            self.hasUnseenCloseFriends = hasUnseenCloseFriends
        }
    }
    
    public struct Tag: Equatable {
        public var id: Int32
        public var title: ChatFolderTitle
        public var colorId: Int32
        
        public init(id: Int32, title: ChatFolderTitle, colorId: Int32) {
            self.id = id
            self.title = title
            self.colorId = colorId
        }
    }
    
    public struct CustomMessageListData: Equatable {
        public var commandPrefix: String?
        public var searchQuery: String?
        public var messageCount: Int?
        public var hideSeparator: Bool
        public var hideDate: Bool
        public var hidePeerStatus: Bool
        
        public init(commandPrefix: String?, searchQuery: String?, messageCount: Int?, hideSeparator: Bool, hideDate: Bool, hidePeerStatus: Bool) {
            self.commandPrefix = commandPrefix
            self.searchQuery = searchQuery
            self.messageCount = messageCount
            self.hideSeparator = hideSeparator
            self.hideDate = hideDate
            self.hidePeerStatus = hidePeerStatus
        }
    }
    
    public struct PeerData {
        public var messages: [EngineMessage]
        public var peer: EngineRenderedPeer
        public var threadInfo: ThreadInfo?
        public var combinedReadState: EnginePeerReadCounters?
        public var isRemovedFromTotalUnreadCount: Bool
        public var presence: EnginePeer.Presence?
        public var hasUnseenMentions: Bool
        public var hasUnseenReactions: Bool
        public var draftState: DraftState?
        public var mediaDraftContentType: EngineChatList.MediaDraftContentType?
        public var inputActivities: [(EnginePeer, PeerInputActivity)]?
        public var promoInfo: ChatListNodeEntryPromoInfo?
        public var ignoreUnreadBadge: Bool
        public var displayAsMessage: Bool
        public var hasFailedMessages: Bool
        public var forumTopicData: EngineChatList.ForumTopicData?
        public var topForumTopicItems: [EngineChatList.ForumTopicData]
        public var autoremoveTimeout: Int32?
        public var storyState: StoryState?
        public var requiresPremiumForMessaging: Bool
        public var displayAsTopicList: Bool
        public var tags: [Tag]
        public var customMessageListData: CustomMessageListData?
        
        public init(
            messages: [EngineMessage],
            peer: EngineRenderedPeer,
            threadInfo: ThreadInfo?,
            combinedReadState: EnginePeerReadCounters?,
            isRemovedFromTotalUnreadCount: Bool,
            presence: EnginePeer.Presence?,
            hasUnseenMentions: Bool,
            hasUnseenReactions: Bool,
            draftState: DraftState?,
            mediaDraftContentType: EngineChatList.MediaDraftContentType?,
            inputActivities: [(EnginePeer, PeerInputActivity)]?,
            promoInfo: ChatListNodeEntryPromoInfo?,
            ignoreUnreadBadge: Bool,
            displayAsMessage: Bool,
            hasFailedMessages: Bool,
            forumTopicData: EngineChatList.ForumTopicData?,
            topForumTopicItems: [EngineChatList.ForumTopicData],
            autoremoveTimeout: Int32?,
            storyState: StoryState?,
            requiresPremiumForMessaging: Bool,
            displayAsTopicList: Bool,
            tags: [Tag],
            customMessageListData: CustomMessageListData? = nil
        ) {
            self.messages = messages
            self.peer = peer
            self.threadInfo = threadInfo
            self.combinedReadState = combinedReadState
            self.isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCount
            self.presence =  presence
            self.hasUnseenMentions = hasUnseenMentions
            self.hasUnseenReactions =  hasUnseenReactions
            self.draftState = draftState
            self.mediaDraftContentType = mediaDraftContentType
            self.inputActivities = inputActivities
            self.promoInfo = promoInfo
            self.ignoreUnreadBadge = ignoreUnreadBadge
            self.displayAsMessage = displayAsMessage
            self.hasFailedMessages = hasFailedMessages
            self.forumTopicData = forumTopicData
            self.topForumTopicItems = topForumTopicItems
            self.autoremoveTimeout = autoremoveTimeout
            self.storyState = storyState
            self.requiresPremiumForMessaging = requiresPremiumForMessaging
            self.displayAsTopicList = displayAsTopicList
            self.tags = tags
            self.customMessageListData = customMessageListData
        }
    }
    
    public struct GroupReferenceData {
        public var groupId: EngineChatList.Group
        public var peers: [EngineChatList.GroupItem.Item]
        public var message: EngineMessage?
        public var unreadCount: Int
        public var hiddenByDefault: Bool
        public var storyState: StoryState?
        
        public init(
            groupId: EngineChatList.Group,
            peers: [EngineChatList.GroupItem.Item],
            message: EngineMessage?,
            unreadCount: Int,
            hiddenByDefault: Bool,
            storyState: StoryState?
        ) {
            self.groupId = groupId
            self.peers = peers
            self.message = message
            self.unreadCount = unreadCount
            self.hiddenByDefault = hiddenByDefault
            self.storyState = storyState
        }
    }

    case loading
    case peer(PeerData)
    case groupReference(GroupReferenceData)
    
    public var chatLocation: ChatLocation? {
        switch self {
        case .loading:
            return nil
        case let .peer(peerData):
            return .peer(id: peerData.peer.peerId)
        case .groupReference:
            return nil
        }
    }
}

private let tagBackgroundImage: UIImage? = {
    return generateStretchableFilledCircleImage(diameter: 8.0, color: .white)?.withRenderingMode(.alwaysTemplate)
}()

private final class ChatListItemTagListComponent: Component {
    let context: AccountContext
    let tags: [ChatListItemContent.Tag]
    let theme: PresentationTheme
    let sizeFactor: CGFloat
    
    init(
        context: AccountContext,
        tags: [ChatListItemContent.Tag],
        theme: PresentationTheme,
        sizeFactor: CGFloat
    ) {
        self.context = context
        self.tags = tags
        self.theme = theme
        self.sizeFactor = sizeFactor
    }
    
    static func ==(lhs: ChatListItemTagListComponent, rhs: ChatListItemTagListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.tags != rhs.tags {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.sizeFactor != rhs.sizeFactor {
            return false
        }
        return true
    }
    
    private final class ItemView: UIView {
        let backgroundView: UIImageView
        let title = ComponentView<Empty>()
        
        private var currentTitle: ChatFolderTitle?
        
        override init(frame: CGRect) {
            self.backgroundView = UIImageView(image: tagBackgroundImage)
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(context: AccountContext, title: ChatFolderTitle, backgroundColor: UIColor, foregroundColor: UIColor, sizeFactor: CGFloat) -> CGSize {
            self.currentTitle = title
            
            let titleValue = ChatFolderTitle(text: title.text.isEmpty ? " " : title.text, entities: title.entities, enableAnimations: title.enableAnimations)
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    placeholderColor: foregroundColor.withMultipliedAlpha(0.1),
                    text: .plain(titleValue.attributedString(font: Font.semibold(floor(11.0 * sizeFactor)), textColor: foregroundColor)),
                    manualVisibilityControl: true,
                    resetAnimationsOnVisibilityChange: true
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let backgroundSideInset: CGFloat = floorToScreenPixels(4.0 * sizeFactor)
            let backgroundVerticalInset: CGFloat = floorToScreenPixels(2.0 * sizeFactor)
            let backgroundSize = CGSize(width: titleSize.width + backgroundSideInset * 2.0, height: titleSize.height + backgroundVerticalInset * 2.0)
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.backgroundView.frame = backgroundFrame
            self.backgroundView.tintColor = backgroundColor
            
            let titleFrame = titleSize.centered(in: backgroundFrame)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            return backgroundSize
        }
        
        func updateVisibility(_ isVisible: Bool) {
            guard let currentTitle = self.currentTitle else {
                return
            }
            if let titleView = self.title.view as? MultilineTextWithEntitiesComponent.View {
                titleView.updateVisibility(isVisible && currentTitle.enableAnimations)
            }
        }
    }
    
    final class View: UIView {
        private var itemViews: [Int32: ItemView] = [:]
        
        var isVisible: Bool = false {
            didSet {
                if self.isVisible != oldValue {
                    for (_, itemView) in self.itemViews {
                        itemView.updateVisibility(self.isVisible)
                    }
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: ChatListItemTagListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var validIds: [Int32] = []
            let spacing: CGFloat = floorToScreenPixels(5.0 * component.sizeFactor)
            var nextX: CGFloat = 0.0
            for tag in component.tags {
                if nextX != 0.0 {
                    nextX += spacing
                }
                
                let itemId: Int32
                let itemTitle: ChatFolderTitle
                let itemBackgroundColor: UIColor
                let itemForegroundColor: UIColor
                
                if validIds.count >= 3 {
                    itemId = Int32.max
                    itemTitle = ChatFolderTitle(text: "+\(component.tags.count - validIds.count)", entities: [], enableAnimations: true)
                    itemForegroundColor = component.theme.chatList.dateTextColor
                    itemBackgroundColor = itemForegroundColor.withMultipliedAlpha(0.1)
                } else {
                    itemId = tag.id
                    
                    let tagColor = PeerNameColor(rawValue: tag.colorId)
                    let resolvedColor = component.context.peerNameColors.getChatFolderTag(tagColor, dark: component.theme.overallDarkAppearance)
                    
                    itemTitle = ChatFolderTitle(text: tag.title.text.uppercased(), entities: tag.title.entities, enableAnimations: tag.title.enableAnimations)
                    itemBackgroundColor = resolvedColor.main.withMultipliedAlpha(0.1)
                    itemForegroundColor = resolvedColor.main
                }
                
                let itemView: ItemView
                if let current = self.itemViews[itemId] {
                    itemView = current
                } else {
                    itemView = ItemView()
                    self.itemViews[itemId] = itemView
                    self.addSubview(itemView)
                }
                
                let itemSize = itemView.update(context: component.context, title: itemTitle, backgroundColor: itemBackgroundColor, foregroundColor: itemForegroundColor, sizeFactor: component.sizeFactor)
                let itemFrame = CGRect(origin: CGPoint(x: nextX, y: 0.0), size: itemSize)
                itemView.frame = itemFrame
                itemView.updateVisibility(self.isVisible)
                
                validIds.append(itemId)
                nextX += itemSize.width
                
                if validIds.count >= 4 {
                    break
                }
            }
            var removedIds: [Int32] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    itemView.removeFromSuperview()
                    removedIds.append(id)
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
            }
            
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

public class ChatListItem: ListViewItem, ChatListSearchItemNeighbour {
    public enum EnabledContextActions {
        public struct Actions: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let toggleUnread = Actions(rawValue: 1 << 0)
            public static let delete = Actions(rawValue: 1 << 1)
            public static let togglePinned = Actions(rawValue: 1 << 2)
        }
        
        case custom(Actions)
        case auto
    }
    
    let presentationData: ChatListPresentationData
    let context: AccountContext
    let chatListLocation: ChatListControllerLocation
    let filterData: ChatListItemFilterData?
    let index: EngineChatList.Item.Index
    public let content: ChatListItemContent
    let editing: Bool
    let hasActiveRevealControls: Bool
    let selected: Bool
    let enabledContextActions: EnabledContextActions?
    let hiddenOffset: Bool
    let interaction: ChatListNodeInteraction
    
    public let selectable: Bool = true
    
    public var approximateHeight: CGFloat {
        return self.hiddenOffset ? 0.0 : 44.0
    }
    
    let header: ListViewItemHeader?
    
    public var isPinned: Bool {
        switch self.index {
        case let .chatList(index):
            return index.pinningIndex != nil
        case let .forum(pinnedIndex, _, _, _, _):
            if case .index = pinnedIndex {
                return true
            } else {
                return false
            }
        }
    }
    
    public init(presentationData: ChatListPresentationData, context: AccountContext, chatListLocation: ChatListControllerLocation, filterData: ChatListItemFilterData?, index: EngineChatList.Item.Index, content: ChatListItemContent, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, header: ListViewItemHeader?, enabledContextActions: EnabledContextActions?, hiddenOffset: Bool, interaction: ChatListNodeInteraction) {
        self.presentationData = presentationData
        self.chatListLocation = chatListLocation
        self.filterData = filterData
        self.context = context
        self.index = index
        self.content = content
        self.editing = editing
        self.hasActiveRevealControls = hasActiveRevealControls
        self.selected = selected
        self.header = header
        self.enabledContextActions = enabledContextActions
        self.hiddenOffset = hiddenOffset
        self.interaction = interaction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListItemNode()
            let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
            node.insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, first, last, firstWithHeader, nextIsPinned)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        node.setupItem(item: self, synchronousLoads: synchronousLoads)
                        apply(synchronousLoads, false)
                        node.updateIsHighlighted(transition: .immediate)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListItemNode)
            if let nodeValue = node() as? ChatListItemNode {
                nodeValue.setupItem(item: self, synchronousLoads: false)
                let layout = nodeValue.asyncLayout()
                async {
                    let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: self, previousItem: previousItem, nextItem: nextItem)
                    var animated = true
                    if case .None = animation {
                        animated = false
                    }
                    
                    let (nodeLayout, apply) = layout(self, params, first, last, firstWithHeader, nextIsPinned)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        switch self.content {
        case .loading:
            break
        case let .peer(peerData):
            if let message = peerData.messages.last, let peer = peerData.peer.peer {
                var threadId: Int64?
                if case let .forum(_, _, threadIdValue, _, _) = self.index {
                    threadId = threadIdValue
                }
                if threadId == nil, self.interaction.searchTextHighightState != nil, case let .channel(channel) = peerData.peer.peer, channel.isForumOrMonoForum {
                    threadId = message.threadId
                }
                self.interaction.messageSelected(peer, threadId, message, peerData.promoInfo)
            } else if let peer = peerData.peer.peer {
                self.interaction.peerSelected(peer, nil, nil, peerData.promoInfo, false)
            } else if let peer = peerData.peer.peers[peerData.peer.peerId] {
                self.interaction.peerSelected(peer, nil, nil, peerData.promoInfo, false)
            }
        case let .groupReference(groupReferenceData):
            self.interaction.groupSelected(groupReferenceData.groupId)
        }
    }
        
    static func mergeType(item: ChatListItem, previousItem: ListViewItem?, nextItem: ListViewItem?) -> (first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool) {
        var first = false
        var last = false
        var firstWithHeader = false
        if let previousItem = previousItem {
            if let header = item.header {
                if let previousItem = previousItem as? ChatListItem {
                    firstWithHeader = header.id != previousItem.header?.id
                } else {
                    firstWithHeader = true
                }
            }
        } else {
            first = true
            firstWithHeader = item.header != nil
        }
        var nextIsPinned = false
        if let nextItem = nextItem as? ChatListItem {
            if case let .chatList(nextIndex) = nextItem.index, nextIndex.pinningIndex != nil {
                nextIsPinned = true
            }
        } else {
            last = true
        }
        return (first, last, firstWithHeader, nextIsPinned)
    }
}

private let pinIcon = ItemListRevealOptionIcon.animation(animation: "anim_pin", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let unpinIcon = ItemListRevealOptionIcon.animation(animation: "anim_unpin", scale: 1.0, offset: 0.0, replaceColors: [0x1993fa], flip: false)
private let muteIcon = ItemListRevealOptionIcon.animation(animation: "anim_mute", scale: 1.0, offset: 0.0, replaceColors: [0xff9500], flip: false)
private let unmuteIcon = ItemListRevealOptionIcon.animation(animation: "anim_unmute", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let deleteIcon = ItemListRevealOptionIcon.animation(animation: "anim_delete", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let groupIcon = ItemListRevealOptionIcon.animation(animation: "anim_group", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let ungroupIcon = ItemListRevealOptionIcon.animation(animation: "anim_ungroup", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let readIcon = ItemListRevealOptionIcon.animation(animation: "anim_read", scale: 1.0, offset: 0.0, replaceColors: nil, flip: false)
private let unreadIcon = ItemListRevealOptionIcon.animation(animation: "anim_unread", scale: 1.0, offset: 0.0, replaceColors: [0x2194fa], flip: false)
private let archiveIcon = ItemListRevealOptionIcon.animation(animation: "anim_archive", scale: 1.0, offset: 2.0, replaceColors: [0xa9a9ad], flip: false)
private let unarchiveIcon = ItemListRevealOptionIcon.animation(animation: "anim_unarchive", scale: 0.642, offset: -9.0, replaceColors: [0xa9a9ad], flip: false)
private let hideIcon = ItemListRevealOptionIcon.animation(animation: "anim_hide", scale: 1.0, offset: 2.0, replaceColors: [0xbdbdc2], flip: false)
private let unhideIcon = ItemListRevealOptionIcon.animation(animation: "anim_hide", scale: 1.0, offset: -20.0, replaceColors: [0xbdbdc2], flip: true)
private let startIcon = ItemListRevealOptionIcon.animation(animation: "anim_play", scale: 1.0, offset: 0.0, replaceColors: [0xbdbdc2], flip: false)
private let closeIcon = ItemListRevealOptionIcon.animation(animation: "anim_pause", scale: 1.0, offset: 0.0, replaceColors: [0xbdbdc2], flip: false)

private enum RevealOptionKey: Int32 {
    case pin
    case unpin
    case mute
    case unmute
    case delete
    case group
    case ungroup
    case toggleMarkedUnread
    case archive
    case unarchive
    case hide
    case unhide
    case hidePsa
    case open
    case close
    case edit
}

private func canArchivePeer(id: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Bool {
    if id.isTelegramNotifications {
        return false
    }
    if id == accountPeerId {
        return false
    }
    return true
}

public struct ChatListItemFilterData: Equatable {
    public var excludesArchived: Bool
    
    public init(excludesArchived: Bool) {
        self.excludesArchived = excludesArchived
    }
}

private func revealOptions(strings: PresentationStrings, theme: PresentationTheme, isPinned: Bool, isMuted: Bool?, location: ChatListControllerLocation, peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id, canDelete: Bool, isEditing: Bool, filterData: ChatListItemFilterData?) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if case .savedMessagesChats = location {
            if isPinned {
                options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            }
        } else if case .chatList(.archive) = location {
            if isPinned {
                options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            }
        } else {
            if let isMuted = isMuted {
                if isMuted {
                    options.append(ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: strings.ChatList_Unmute, icon: unmuteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
                } else {
                    options.append(ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: strings.ChatList_Mute, icon: muteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
                }
            }
        }
    }
    if canDelete {
        options.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: strings.Common_Delete, icon: deleteIcon, color: theme.list.itemDisclosureActions.destructive.fillColor, textColor: theme.list.itemDisclosureActions.destructive.foregroundColor))
    }
    if case .savedMessagesChats = location {
    } else {
        if !isEditing {
            var canArchive = false
            var canUnarchive = false
            if let filterData = filterData {
                if filterData.excludesArchived {
                    canArchive = true
                }
            } else {
                if case let .chatList(groupId) = location {
                    if case .root = groupId {
                        canArchive = true
                    } else {
                        canUnarchive = true
                    }
                }
            }
            if canArchive {
                if canArchivePeer(id: peerId, accountPeerId: accountPeerId) {
                    options.append(ItemListRevealOption(key: RevealOptionKey.archive.rawValue, title: strings.ChatList_ArchiveAction, icon: archiveIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.inactive.foregroundColor))
                }
            } else if canUnarchive {
                options.append(ItemListRevealOption(key: RevealOptionKey.unarchive.rawValue, title: strings.ChatList_UnarchiveAction, icon: unarchiveIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.inactive.foregroundColor))
            }
        }
    }
    return options
}

private func groupReferenceRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isEditing: Bool, hiddenByDefault: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if hiddenByDefault {
            options.append(ItemListRevealOption(key: RevealOptionKey.unhide.rawValue, title: strings.ChatList_UnhideAction, icon: unhideIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
        } else {
            options.append(ItemListRevealOption(key: RevealOptionKey.hide.rawValue, title: strings.ChatList_HideAction, icon: hideIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
        }
    }
    return options
}

private func forumGeneralRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isMuted: Bool?, isClosed: Bool, isEditing: Bool, canOpenClose: Bool, canHide: Bool, hiddenByDefault: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if let isMuted = isMuted {
            if isMuted {
                options.append(ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: strings.ChatList_Unmute, icon: unmuteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: strings.ChatList_Mute, icon: muteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            }
        }
    }
    if canOpenClose && !hiddenByDefault {
        if !isEditing {
            if !isClosed {

            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.open.rawValue, title: strings.ChatList_StartAction, icon: startIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            }
        }
    }
    if canHide {
        if !isEditing {
            if hiddenByDefault {
                options.append(ItemListRevealOption(key: RevealOptionKey.unhide.rawValue, title: strings.ChatList_ThreadUnhideAction, icon: unhideIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.hide.rawValue, title: strings.ChatList_ThreadHideAction, icon: hideIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
            }
        }
    }
    return options
}

private func forumThreadRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isMuted: Bool?, isClosed: Bool, isEditing: Bool, canOpenClose: Bool, canDelete: Bool) -> [ItemListRevealOption] {
    var options: [ItemListRevealOption] = []
    if !isEditing {
        if let isMuted = isMuted {
            if isMuted {
                options.append(ItemListRevealOption(key: RevealOptionKey.unmute.rawValue, title: strings.ChatList_Unmute, icon: unmuteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.mute.rawValue, title: strings.ChatList_Mute, icon: muteIcon, color: theme.list.itemDisclosureActions.neutral2.fillColor, textColor: theme.list.itemDisclosureActions.neutral2.foregroundColor))
            }
        }
    }
    if canDelete {
        options.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: strings.Common_Delete, icon: deleteIcon, color: theme.list.itemDisclosureActions.destructive.fillColor, textColor: theme.list.itemDisclosureActions.destructive.foregroundColor))
    }
    if canOpenClose {
        if !isEditing {
            if !isClosed {
                options.append(ItemListRevealOption(key: RevealOptionKey.close.rawValue, title: strings.ChatList_CloseAction, icon: closeIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.inactive.foregroundColor))
            } else {
                options.append(ItemListRevealOption(key: RevealOptionKey.open.rawValue, title: strings.ChatList_StartAction, icon: startIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
            }
        }
    }
    return options
}

private func leftRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isUnread: Bool, isEditing: Bool, isPinned: Bool, isSavedMessages: Bool, location: ChatListControllerLocation, peer: EnginePeer, filterData: ChatListItemFilterData?) -> [ItemListRevealOption] {
    switch location {
    case let .chatList(groupId):
        if case .root = groupId {
            var options: [ItemListRevealOption] = []
            if isUnread {
                options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Read, icon: readIcon, color: theme.list.itemDisclosureActions.inactive.fillColor, textColor: theme.list.itemDisclosureActions.neutral1.foregroundColor))
            } else {
                var canMarkUnread = true
                if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                    canMarkUnread = false
                }
                
                if canMarkUnread {
                    options.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: strings.DialogList_Unread, icon: unreadIcon, color: theme.list.itemDisclosureActions.accent.fillColor, textColor: theme.list.itemDisclosureActions.accent.foregroundColor))
                }
            }
            if !isEditing {
                if isPinned {
                    options.append(ItemListRevealOption(key: RevealOptionKey.unpin.rawValue, title: strings.DialogList_Unpin, icon: unpinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
                } else {
                    if filterData == nil || peer.id.namespace != Namespaces.Peer.SecretChat {
                        options.append(ItemListRevealOption(key: RevealOptionKey.pin.rawValue, title: strings.DialogList_Pin, icon: pinIcon, color: theme.list.itemDisclosureActions.constructive.fillColor, textColor: theme.list.itemDisclosureActions.constructive.foregroundColor))
                    }
                }
            }
            return options
        } else {
            return []
        }
    case .forum:
       return []
    case .savedMessagesChats:
        return []
    }
}

private final class ChatListItemAccessibilityCustomAction: UIAccessibilityCustomAction {
    let key: Int32
    
    init(name: String, target: Any?, selector: Selector, key: Int32) {
        self.key = key
        
        super.init(name: name, target: target, selector: selector)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

private final class CachedChatListSearchResult {
    let text: String
    let searchQuery: String
    let resultRanges: [Range<String.Index>]
    
    init(text: String, searchQuery: String, resultRanges: [Range<String.Index>]) {
        self.text = text
        self.searchQuery = searchQuery
        self.resultRanges = resultRanges
    }
    
    func matches(text: String, searchQuery: String) -> Bool {
        if self.text != text {
            return false
        }
        if self.searchQuery != searchQuery {
            return false
        }
        return true
    }
}

private final class CachedCustomTextEntities {
    let text: String
    let textEntities: [MessageTextEntity]
    
    init(text: String, textEntities: [MessageTextEntity]) {
        self.text = text
        self.textEntities = textEntities
    }
    
    func matches(text: String) -> Bool {
        if self.text != text {
            return false
        }
        return true
    }
}

private let playIconImage = UIImage(bundleImageName: "Chat List/MiniThumbnailPlay")?.precomposed()

private final class ChatListMediaPreviewNode: ASDisplayNode {
    private let context: AccountContext
    let message: EngineMessage
    let media: EngineMedia
    
    private let imageNode: TransformImageNode
    private let playIcon: ASImageNode
    
    private var requestedImage: Bool = false
    private var disposable: Disposable?
    
    init(context: AccountContext, message: EngineMessage, media: EngineMedia) {
        self.context = context
        self.message = message
        self.media = media
        
        self.imageNode = TransformImageNode()
        self.playIcon = ASImageNode()
        self.playIcon.image = playIconImage
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playIcon)
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateLayout(size: CGSize, synchronousLoads: Bool) {
        if let image = self.playIcon.image {
            self.playIcon.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        let hasSpoiler = self.message.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute })
        
        var isRound = false
        var dimensions = CGSize(width: 100.0, height: 100.0)
        if case let .image(image) = self.media {
            self.playIcon.isHidden = true
            if let largest = largestImageRepresentation(image.representations) {
                dimensions = largest.dimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessagePhoto(account: self.context.account, userLocation: .peer(self.message.id.peerId), photoReference: .message(message: MessageReference(self.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 36.0, height: 36.0), blurred: hasSpoiler, synchronousLoad: synchronousLoads)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            } else {
                let signal = chatSecretPhoto(account: self.context.account, userLocation: .peer(self.message.id.peerId), photoReference: .standalone(media: image), ignoreFullSize: true, synchronousLoad: synchronousLoads)
                self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
            }
        } else if case let .action(action) = self.media, case let .suggestedProfilePhoto(image) = action.action, let image = image {
            isRound = true
            self.playIcon.isHidden = true
            if let largest = largestImageRepresentation(image.representations) {
                dimensions = largest.dimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessagePhoto(account: self.context.account, userLocation: .peer(self.message.id.peerId), photoReference: .message(message: MessageReference(self.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 36.0, height: 36.0), synchronousLoad: synchronousLoads)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        } else if case let .file(file) = self.media {
            if file.isInstantVideo {
                isRound = true
            }
            if file.isVideo && !file.isAnimated {
                self.playIcon.isHidden = false
            } else {
                self.playIcon.isHidden = true
            }
            if let mediaDimensions = file.dimensions {
                dimensions = mediaDimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessageVideo(postbox: self.context.account.postbox, userLocation: .peer(self.message.id.peerId), videoReference: .message(message: MessageReference(self.message._asMessage()), media: file), synchronousLoad: synchronousLoads, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true, blurred: hasSpoiler)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        }
        
        let radius: CGFloat
        if isRound {
            radius = size.width / 2.0
        } else if size.width >= 30.0 {
            radius = 8.0
        } else {
            radius = 2.0
        }
        
        let makeLayout = self.imageNode.asyncLayout()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()
    }
}

private let telegramCodeRegex = try? NSRegularExpression(pattern: "(?<=: )\\b\\d{5,8}\\b(?=\\.)", options: [])
private let loginCodeRegex = try? NSRegularExpression(pattern: "\\b\\d{5,8}\\b", options: [])

public class ChatListItemNode: ItemListRevealOptionsItemNode {
    final class TopicItemNode: ASDisplayNode {
        let topicTitleNode: TextNode
        let titleTopicIconView: ComponentHostView<Empty>?
        var titleTopicAvatarNode: AvatarNode?
        var titleTopicIconComponent: EmojiStatusComponent?
        
        var visibilityStatus: Bool = false {
            didSet {
                if self.visibilityStatus != oldValue {
                    if let titleTopicIconView = self.titleTopicIconView, let titleTopicIconComponent = self.titleTopicIconComponent {
                        let _ = titleTopicIconView.update(
                            transition: .immediate,
                            component: AnyComponent(titleTopicIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                            environment: {},
                            containerSize: titleTopicIconView.bounds.size
                        )
                    }
                }
            }
        }
        
        private init(topicTitleNode: TextNode, titleTopicIconView: ComponentHostView<Empty>?, titleTopicAvatarNode: AvatarNode?, titleTopicIconComponent: EmojiStatusComponent?) {
            self.topicTitleNode = topicTitleNode
            self.titleTopicIconView = titleTopicIconView
            self.titleTopicAvatarNode = titleTopicAvatarNode
            self.titleTopicIconComponent = titleTopicIconComponent
            
            super.init()
            
            self.addSubnode(self.topicTitleNode)
            if let titleTopicAvatarNode = self.titleTopicAvatarNode {
                self.view.addSubview(titleTopicAvatarNode.view)
            }
            if let titleTopicIconView = self.titleTopicIconView {
                self.view.addSubview(titleTopicIconView)
            }
        }
        
        static func asyncLayout(_ currentNode: TopicItemNode?) -> (_ constrainedWidth: CGFloat, _ context: AccountContext, _ theme: PresentationTheme, _ threadId: Int64, _ threadPeer: EnginePeer?, _ title: NSAttributedString, _ iconId: Int64?, _ iconColor: Int32?) -> (CGSize, () -> TopicItemNode) {
            let makeTopicTitleLayout = TextNode.asyncLayout(currentNode?.topicTitleNode)
            
            return { constrainedWidth, context, theme, threadId, threadPeer, title, iconId, iconColor in
                let remainingWidth = max(1.0, constrainedWidth - (((iconId == nil && iconColor == nil && threadPeer == nil) ? 1.0 : 18.0) + 2.0))
                
                let topicTitleArguments = TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: remainingWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0))
                
                let topicTitleLayout = makeTopicTitleLayout(topicTitleArguments)
                
                return (CGSize(width: ((iconId == nil && iconColor == nil && threadPeer == nil) ? 1.0 : 18.0) + 2.0 + topicTitleLayout.0.size.width, height: topicTitleLayout.0.size.height), {
                    let topicTitleNode = topicTitleLayout.1()
                    
                    let titleTopicIconContent: EmojiStatusComponent.Content?
                    if threadId == 1 {
                        titleTopicIconContent = .image(image: PresentationResourcesChatList.generalTopicSmallIcon(theme), tintColor: nil)
                    } else if let fileId = iconId, fileId != 0 {
                        titleTopicIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 36.0, height: 36.0), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: theme.list.itemAccentColor, loopMode: .count(0))
                    } else if let iconColor {
                        titleTopicIconContent = .topic(title: String(title.string.prefix(1)), color: iconColor, size: CGSize(width: 18.0, height: 18.0))
                    } else {
                        titleTopicIconContent = nil
                    }
                    
                    var titleTopicIconComponent: EmojiStatusComponent?
                    var titleTopicIconView: ComponentHostView<Empty>?
                    
                    if let titleTopicIconContent {
                        titleTopicIconComponent = EmojiStatusComponent(
                            context: context,
                            animationCache: context.animationCache,
                            animationRenderer: context.animationRenderer,
                            content: titleTopicIconContent,
                            isVisibleForAnimations: (currentNode?.visibilityStatus ?? false) && context.sharedContext.energyUsageSettings.loopEmoji,
                            action: nil
                        )
                        
                        if let current = currentNode?.titleTopicIconView {
                            titleTopicIconView = current
                        } else {
                            titleTopicIconView = ComponentHostView<Empty>()
                        }
                    }
                    
                    var titleTopicAvatarNode: AvatarNode?
                    if let _ = threadPeer {
                        if let current = currentNode?.titleTopicAvatarNode {
                            titleTopicAvatarNode = current
                        } else {
                            titleTopicAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                        }
                    }
                    
                    let targetNode = currentNode ?? TopicItemNode(topicTitleNode: topicTitleNode, titleTopicIconView: titleTopicIconView, titleTopicAvatarNode: titleTopicAvatarNode, titleTopicIconComponent: titleTopicIconComponent)
                    
                    targetNode.titleTopicIconComponent = titleTopicIconComponent
                    
                    if let titleTopicIconView, let titleTopicIconComponent {
                        let iconSize = titleTopicIconView.update(
                            transition: .immediate,
                            component: AnyComponent(titleTopicIconComponent),
                            environment: {},
                            containerSize: CGSize(width: 18.0, height: 18.0)
                        )
                        titleTopicIconView.frame = CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: iconSize)
                        
                        topicTitleNode.frame = CGRect(origin: CGPoint(x: 18.0 + 2.0, y: 0.0), size: topicTitleLayout.0.size)
                    } else if let titleTopicAvatarNode, let threadPeer {
                        let iconSize = CGSize(width: 18.0, height: 18.0)
                        
                        titleTopicAvatarNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: iconSize)
                        titleTopicAvatarNode.updateSize(size: iconSize)
                        if threadPeer.smallProfileImage != nil {
                            titleTopicAvatarNode.setPeerV2(context: context, theme: theme, peer: threadPeer, overrideImage: nil, emptyColor: theme.list.mediaPlaceholderColor, clipStyle: .round, synchronousLoad: false, displayDimensions: iconSize)
                        } else {
                            titleTopicAvatarNode.setPeer(context: context, theme: theme, peer: threadPeer, overrideImage: nil, emptyColor: theme.list.mediaPlaceholderColor, clipStyle: .round, synchronousLoad: false, displayDimensions: iconSize)
                        }
                        
                        topicTitleNode.frame = CGRect(origin: CGPoint(x: 18.0 + 2.0, y: 0.0), size: topicTitleLayout.0.size)
                    } else {
                        topicTitleNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: topicTitleLayout.0.size)
                    }
                    
                    return targetNode
                })
            }
        }
    }
    
    public final class AuthorNode: ASDisplayNode {
        public let authorNode: TextNode
        var titleTopicArrowNode: ASImageNode?
        var topicNodes: [Int64: TopicItemNode] = [:]
        var topicNodeOrder: [Int64] = []
        
        public var visibilityStatus: Bool = false {
            didSet {
                if self.visibilityStatus != oldValue {
                    for (_, topicNode) in self.topicNodes {
                        topicNode.visibilityStatus = self.visibilityStatus
                    }
                }
            }
        }
        
        override public init() {
            self.authorNode = TextNode()
            self.authorNode.displaysAsynchronously = true
            
            super.init()
            
            self.addSubnode(self.authorNode)
        }
        
        func setFirstTopicHighlighted(_ isHighlighted: Bool) {
            guard let id = self.topicNodeOrder.first, let itemNode = self.topicNodes[id] else {
                return
            }
            if isHighlighted {
                itemNode.layer.removeAnimation(forKey: "opacity")
                itemNode.alpha = 0.65
            } else {
                itemNode.alpha = 1.0
                itemNode.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
            }
        }
        
        func assignParentNode(parentNode: ASDisplayNode?) {
            for (id, topicNode) in self.topicNodes {
                if id == self.topicNodeOrder.first, let parentNode {
                    if topicNode.supernode !== parentNode {
                        parentNode.addSubnode(topicNode)
                    }
                } else {
                    if topicNode.supernode !== self {
                        self.addSubnode(topicNode)
                    }
                }
            }
        }
        
        func asyncLayout() -> (_ context: AccountContext, _ constrainedWidth: CGFloat, _ theme: PresentationTheme, _ authorTitle: NSAttributedString?, _ topics: [(id: Int64, threadPeer: EnginePeer?, title: NSAttributedString, iconId: Int64?, iconColor: Int32?)]) -> (CGSize, () -> CGRect?) {
            let makeAuthorLayout = TextNode.asyncLayout(self.authorNode)
            var makeExistingTopicLayouts: [Int64: (_ constrainedWidth: CGFloat, _ context: AccountContext, _ theme: PresentationTheme, _ threadId: Int64, _ threadPeer: EnginePeer?, _ title: NSAttributedString, _ iconId: Int64?, _ iconColor: Int32?) -> (CGSize, () -> TopicItemNode)] = [:]
            for (topicId, topicNode) in self.topicNodes {
                makeExistingTopicLayouts[topicId] = TopicItemNode.asyncLayout(topicNode)
            }
            
            return { [weak self] context, constrainedWidth, theme, authorTitle, topics in
                var maxTitleWidth = constrainedWidth
                if !topics.isEmpty {
                    maxTitleWidth = floor(constrainedWidth * 0.7)
                }
                
                let authorTitleLayout = makeAuthorLayout(TextNodeLayoutArguments(attributedString: authorTitle, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTitleWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
                
                var remainingWidth = constrainedWidth - authorTitleLayout.0.size.width
                
                var arrowIconImage: UIImage?
                if !topics.isEmpty {
                    if authorTitle != nil {
                        arrowIconImage = PresentationResourcesChatList.topicArrowIcon(theme)
                        if let arrowIconImage = arrowIconImage {
                            remainingWidth -= arrowIconImage.size.width + 6.0 * 2.0
                        }
                    }
                }
                
                var topicsSizeAndApply: [(Int64, CGSize, () -> TopicItemNode)] = []
                for topic in topics {
                    if remainingWidth <= ((topic.iconId == nil && topic.iconColor == nil) ? 8.0 : 22.0) + 2.0 + 10.0 {
                        break
                    }
                    
                    let makeTopicLayout = makeExistingTopicLayouts[topic.id] ?? TopicItemNode.asyncLayout(nil)
                    let (topicSize, topicApply) = makeTopicLayout(remainingWidth, context, theme, topic.id, topic.threadPeer, topic.title, topic.iconId, topic.iconColor)
                    topicsSizeAndApply.append((topic.id, topicSize, topicApply))
                    
                    remainingWidth -= topicSize.width + 4.0
                }
                
                var size = authorTitleLayout.0.size
                if !topicsSizeAndApply.isEmpty {
                    for item in topicsSizeAndApply {
                        size.height = max(size.height, item.1.height)
                        size.width += 10.0 + item.1.width
                    }
                }
                
                return (size, {
                    guard let self else {
                        return nil
                    }
                    
                    let _ = authorTitleLayout.1()
                    let authorFrame = CGRect(origin: CGPoint(), size: authorTitleLayout.0.size)
                    self.authorNode.frame = authorFrame
                    
                    var nextX = authorFrame.maxX - 1.0
                    if authorTitle == nil {
                        nextX = 0.0
                    }
                    
                    if let arrowIconImage = arrowIconImage {
                        let titleTopicArrowNode: ASImageNode
                        if let current = self.titleTopicArrowNode {
                            titleTopicArrowNode = current
                        } else {
                            titleTopicArrowNode = ASImageNode()
                            self.titleTopicArrowNode = titleTopicArrowNode
                            self.addSubnode(titleTopicArrowNode)
                        }
                        titleTopicArrowNode.image = arrowIconImage
                        nextX += 6.0
                        titleTopicArrowNode.frame = CGRect(origin: CGPoint(x: nextX, y: 5.0), size: arrowIconImage.size)
                        nextX += arrowIconImage.size.width + 6.0
                    } else {
                        if let titleTopicArrowNode = self.titleTopicArrowNode {
                            self.titleTopicArrowNode = nil
                            titleTopicArrowNode.removeFromSupernode()
                        }
                    }
                    
                    var topTopicRect: CGRect?
                    var topicNodeOrder: [Int64] = []
                    for item in topicsSizeAndApply {
                        topicNodeOrder.append(item.0)
                        let itemNode = item.2()
                        if self.topicNodes[item.0] != itemNode {
                            self.topicNodes[item.0]?.removeFromSupernode()
                            self.topicNodes[item.0] = itemNode
                        }
                        let itemFrame = CGRect(origin: CGPoint(x: nextX - 1.0, y: 0.0), size: item.1)
                        itemNode.frame = itemFrame
                        if topTopicRect == nil {
                            topTopicRect = itemFrame
                        }
                        nextX += item.1.width + 4.0
                    }
                    var removeIds: [Int64] = []
                    for (id, itemNode) in self.topicNodes {
                        if !topicsSizeAndApply.contains(where: { $0.0 == id }) {
                            removeIds.append(id)
                            itemNode.removeFromSupernode()
                        }
                    }
                    for id in removeIds {
                        self.topicNodes.removeValue(forKey: id)
                    }
                    self.topicNodeOrder = topicNodeOrder
                    
                    return topTopicRect
                })
            }
        }
    }
    
    private struct ContentImageSpec {
        var message: EngineMessage
        var media: EngineMedia
        var size: CGSize
        
        init(message: EngineMessage, media: EngineMedia, size: CGSize) {
            self.message = message
            self.media = media
            self.size = size
        }
    }
    
    var item: ChatListItem?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let contextContainer: ContextControllerSourceNode
    let mainContentContainerNode: ASDisplayNode
    
    public let avatarContainerNode: ASDisplayNode
    public let avatarNode: AvatarNode
    var avatarIconView: ComponentHostView<Empty>?
    var avatarIconComponent: EmojiStatusComponent?
    var avatarVideoNode: AvatarVideoNode?
    var avatarTapRecognizer: UITapGestureRecognizer?
    private var avatarMediaNode: ChatListMediaPreviewNode?
    
    private var inlineNavigationMarkLayer: SimpleLayer?
    
    public let titleNode: TextNode
    private var titleBadge: (backgroundView: UIImageView, textNode: TextNode)?
    public let authorNode: AuthorNode
    private var compoundHighlightingNode: LinkHighlightingNode?
    private var textArrowNode: ASImageNode?
    private var compoundTextButtonNode: HighlightTrackingButtonNode?
    let measureNode: TextNode
    private var currentItemHeight: CGFloat?
    let forwardedIconNode: ASImageNode
    public let textNode: TextNodeWithEntities
    var trailingTextBadgeNode: TextNode?
    var trailingTextBadgeBackground: UIImageView?
    var dustNode: InvisibleInkDustNode?
    let inputActivitiesNode: ChatListInputActivitiesNode
    public let dateNode: TextNode
    var dateStatusIconNode: ASImageNode?
    var dateDisclosureIconView: UIImageView?
    public let separatorNode: ASDisplayNode
    let statusNode: ChatListStatusNode
    let badgeNode: ChatListBadgeNode
    let mentionBadgeNode: ChatListBadgeNode
    var avatarBadgeNode: ChatListBadgeNode?
    var avatarBadgeBackground: ASImageNode?
    let onlineNode: PeerOnlineMarkerNode
    var avatarTimerBadge: AvatarBadgeView?
    private var starView: StarView?
    let pinnedIconNode: ASImageNode
    var secretIconNode: ASImageNode?
    var verifiedIconView: ComponentHostView<Empty>?
    var verifiedIconComponent: EmojiStatusComponent?
    var credibilityIconView: ComponentHostView<Empty>?
    var credibilityIconComponent: EmojiStatusComponent?
    var statusIconView: ComponentHostView<Empty>?
    var statusIconComponent: EmojiStatusComponent?
    let mutedIconNode: ASImageNode
    var itemTagList: ComponentView<Empty>?
    var actionButtonTitleNode: TextNode?
    var actionButtonBackgroundView: UIImageView?
    var actionButtonNode: HighlightableButtonNode?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    private var cachedDataDisposable = MetaDisposable()
    
    private var currentTextLeftCutout: CGFloat = 0.0
    private var currentMediaPreviewSpecs: [ContentImageSpec] = []
    private var mediaPreviewNodes: [EngineMedia.Id: ChatListMediaPreviewNode] = [:]
    
    var selectableControlNode: ItemListSelectableControlNode?
    var reorderControlNode: ItemListEditableReorderControlNode?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    
    private var cachedChatListText: (String, String)?
    private var cachedChatListSearchResult: CachedChatListSearchResult?
    private var cachedChatListQuoteSearchResult: CachedChatListSearchResult?
    private var cachedCustomTextEntities: CachedCustomTextEntities?
    
    var layoutParams: (ChatListItem, first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool, ListViewItemLayoutParams, countersSize: CGFloat)?
    
    private var isHighlighted: Bool = false
    private var skipFadeout: Bool = false
    private var customAnimationInProgress: Bool = false
    
    private var onlineIsVoiceChat: Bool = false
    private var currentOnline: Bool?
    
    override public var canBeSelected: Bool {
        if self.selectableControlNode != nil || self.item?.editing == true {
            return false
        } else {
            return super.canBeSelected
        }
    }
    
    override public var defaultAccessibilityLabel: String? {
        get {
            return self.accessibilityLabel
        } set(value) {
        }
    }
    override public var accessibilityAttributedLabel: NSAttributedString? {
        get {
            return self.accessibilityLabel.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    override public var accessibilityAttributedValue: NSAttributedString? {
        get {
            return self.accessibilityValue.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    
    override public var accessibilityLabel: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case .loading:
                    return nil
                case let .groupReference(groupReferenceData):
                    var result = item.presentationData.strings.ChatList_ArchivedChatsTitle
                let allCount = groupReferenceData.unreadCount
                    if allCount > 0 {
                        result += "\n\(item.presentationData.strings.VoiceOver_Chat_UnreadMessages(Int32(allCount)))"
                    }
                    return result
                case let .peer(peerData):
                    guard let chatMainPeer = peerData.peer.chatOrMonoforumMainPeer else {
                        return nil
                    }
                    var result = ""
                    if item.context.account.peerId == chatMainPeer.id {
                        result += item.presentationData.strings.DialogList_SavedMessages
                    } else {
                        result += chatMainPeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    }
                    if let combinedReadState = peerData.combinedReadState, combinedReadState.count > 0 {
                        result += "\n\(item.presentationData.strings.VoiceOver_Chat_UnreadMessages(combinedReadState.count))"
                    }
                    return result
            }
        } set(value) {
        }
    }
    
    override public var accessibilityValue: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case .loading:
                    return nil
                case let .groupReference(groupReferenceData):
                    let peers = groupReferenceData.peers
                    let messageValue = groupReferenceData.message
                    if let message = messageValue, let peer = peers.first?.peer {
                        let messages = [message]
                        var result = ""
                        if message.flags.contains(.Incoming) {
                            result += item.presentationData.strings.VoiceOver_ChatList_Message
                        } else {
                            result += item.presentationData.strings.VoiceOver_ChatList_OutgoingMessage
                        }
                        let (_, initialHideAuthor, messageText, _, _) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, contentSettings: item.context.currentContentSettings.with { $0 }, messages: messages, chatPeer: peer, accountPeerId: item.context.account.peerId, isPeerGroup: false)
                        if message.flags.contains(.Incoming), !initialHideAuthor, let author = message.author, case .user = author {
                            result += "\n\(item.presentationData.strings.VoiceOver_ChatList_MessageFrom(author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)).string)"
                        }
                        result += "\n\(messageText)"
                        return result
                    } else if !peers.isEmpty {
                        var result = ""
                        var isFirst = true
                        for peer in peers {
                            if let chatMainPeer = peer.peer.chatOrMonoforumMainPeer {
                                let peerTitle = chatMainPeer.compactDisplayTitle
                                if !peerTitle.isEmpty {
                                    if isFirst {
                                        isFirst = false
                                    } else {
                                        result.append(", ")
                                    }
                                    result.append(peerTitle)
                                }
                            }
                        }
                        return result
                    } else {
                        return item.presentationData.strings.VoiceOver_ChatList_MessageEmpty
                    }
                case let .peer(peerData):
                    if let message = peerData.messages.last {
                        var result = ""
                        if message.flags.contains(.Incoming) {
                            result += item.presentationData.strings.VoiceOver_ChatList_Message
                        } else {
                            result += item.presentationData.strings.VoiceOver_ChatList_OutgoingMessage
                        }
                        let (_, initialHideAuthor, messageText, _, _) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, contentSettings: item.context.currentContentSettings.with { $0 }, messages: peerData.messages, chatPeer: peerData.peer, accountPeerId: item.context.account.peerId, isPeerGroup: false)
                        if message.flags.contains(.Incoming), !initialHideAuthor, let author = message.author, case .user = author {
                            result += "\n\(item.presentationData.strings.VoiceOver_ChatList_MessageFrom(author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)).string)"
                        }
                        if !message.flags.contains(.Incoming), let combinedReadState = peerData.combinedReadState, combinedReadState.isOutgoingMessageIndexRead(message.index) {
                            result += "\n\(item.presentationData.strings.VoiceOver_ChatList_MessageRead)"
                        }
                        result += "\n\(messageText)"
                        return result
                    } else {
                        return item.presentationData.strings.VoiceOver_ChatList_MessageEmpty
                    }
            }
        } set(value) {
        }
    }
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = self.visibilityStatus
            let isVisible: Bool
            switch self.visibility {
                case let .visible(fraction, _):
                    isVisible = fraction > 0.2
                case .none:
                    isVisible = false
            }
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                if self.visibilityStatus {
                    self.avatarVideoNode?.resetPlayback()
                }
                self.updateVideoVisibility()
                
                self.textNode.visibilityRect = self.visibilityStatus ? CGRect.infinite : nil
                
                if let verifiedIconView = self.verifiedIconView, let verifiedIconComponent = self.verifiedIconComponent {
                    let _ = verifiedIconView.update(
                        transition: .immediate,
                        component: AnyComponent(verifiedIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: verifiedIconView.bounds.size
                    )
                }
                if let credibilityIconView = self.credibilityIconView, let credibilityIconComponent = self.credibilityIconComponent {
                    let _ = credibilityIconView.update(
                        transition: .immediate,
                        component: AnyComponent(credibilityIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: credibilityIconView.bounds.size
                    )
                }
                if let avatarIconView = self.avatarIconView, let avatarIconComponent = self.avatarIconComponent {
                    let _ = avatarIconView.update(
                        transition: .immediate,
                        component: AnyComponent(avatarIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: avatarIconView.bounds.size
                    )
                }
                self.authorNode.visibilityStatus = self.visibilityStatus
                
                if let itemTagListView = self.itemTagList?.view as? ChatListItemTagListComponent.View {
                    itemTagListView.isVisible = self.visibilityStatus
                }
            }
        }
    }
    
    private var trackingIsInHierarchy: Bool = false {
        didSet {
            if self.trackingIsInHierarchy != oldValue {
                Queue.mainQueue().justDispatch {
                    if self.trackingIsInHierarchy {
                        self.avatarVideoNode?.resetPlayback()
                    }
                    self.updateVideoVisibility()
                }
            }
        }
    }
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.avatarContainerNode = ASDisplayNode()
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.mainContentContainerNode = ASDisplayNode()
        self.mainContentContainerNode.clipsToBounds = true
        
        self.measureNode = TextNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = true
        
        self.authorNode = AuthorNode()
        self.authorNode.isUserInteractionEnabled = false
        
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.displaysAsynchronously = true
        self.textNode.textNode.anchorPoint = CGPoint()
        
        self.inputActivitiesNode = ChatListInputActivitiesNode()
        self.inputActivitiesNode.isUserInteractionEnabled = false
        self.inputActivitiesNode.alpha = 0.0
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.displaysAsynchronously = true
        
        self.statusNode = ChatListStatusNode()
        self.badgeNode = ChatListBadgeNode()
        self.mentionBadgeNode = ChatListBadgeNode()
        self.onlineNode = PeerOnlineMarkerNode()
        
        self.forwardedIconNode = ASImageNode()
        self.forwardedIconNode.isLayerBacked = true
        self.forwardedIconNode.displaysAsynchronously = false
        self.forwardedIconNode.displayWithoutProcessing = true
        
        self.pinnedIconNode = ASImageNode()
        self.pinnedIconNode.isLayerBacked = true
        self.pinnedIconNode.displaysAsynchronously = false
        self.pinnedIconNode.displayWithoutProcessing = true
        
        self.mutedIconNode = ASImageNode()
        self.mutedIconNode.isLayerBacked = true
        self.mutedIconNode.displaysAsynchronously = false
        self.mutedIconNode.displayWithoutProcessing = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.contextContainer)
        self.contextContainer.addSubnode(self.mainContentContainerNode)
        
        self.avatarContainerNode.addSubnode(self.avatarNode)
        self.contextContainer.addSubnode(self.avatarContainerNode)
        self.avatarNode.addSubnode(self.onlineNode)
        
        self.mainContentContainerNode.addSubnode(self.titleNode)
        self.mainContentContainerNode.addSubnode(self.authorNode)
        self.mainContentContainerNode.addSubnode(self.textNode.textNode)
        self.mainContentContainerNode.addSubnode(self.dateNode)
        self.mainContentContainerNode.addSubnode(self.statusNode)
        self.mainContentContainerNode.addSubnode(self.pinnedIconNode)
        self.mainContentContainerNode.addSubnode(self.badgeNode)
        self.mainContentContainerNode.addSubnode(self.mentionBadgeNode)
        self.mainContentContainerNode.addSubnode(self.mutedIconNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.5, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4)
                let _ = apply(false, false)
            }
        })
        
        self.contextContainer.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let item = strongSelf.item else {
                return false
            }
            
            strongSelf.contextContainer.additionalActivationProgressLayer = nil
            if let inlineNavigationLocation = item.interaction.inlineNavigationLocation {
                if case let .peer(peerId) = inlineNavigationLocation.location {
                    if case let .chatList(index) = item.index, index.messageIndex.id.peerId == peerId {
                        return false
                    }
                }
                strongSelf.contextContainer.targetNodeForActivationProgress = strongSelf.avatarContainerNode
            } else if let value = strongSelf.hitTest(location, with: nil), value === strongSelf.compoundTextButtonNode?.view {
                strongSelf.contextContainer.targetNodeForActivationProgress = strongSelf.compoundTextButtonNode
                strongSelf.contextContainer.additionalActivationProgressLayer = strongSelf.compoundHighlightingNode?.layer
            } else {
                strongSelf.contextContainer.targetNodeForActivationProgress = nil
            }
            
            return true
        }
        
        self.contextContainer.activated = { [weak self] gesture, location in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            var threadId: Int64?
            if let value = strongSelf.hitTest(location, with: nil), value === strongSelf.compoundTextButtonNode?.view {
                if case let .peer(peerData) = item.content, let topicItem = peerData.topForumTopicItems.first {
                    threadId = topicItem.id
                }
            }
            item.interaction.activateChatPreview?(item, threadId, strongSelf.contextContainer, gesture, nil)
        }
        
        self.onDidLoad { [weak self] _  in
            guard let self else {
                return
            }
            let avatarTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.avatarStoryTapGesture(_:)))
            self.avatarTapRecognizer = avatarTapRecognizer
            self.avatarNode.view.addGestureRecognizer(avatarTapRecognizer)
        }
    }
    
    deinit {
        self.cachedDataDisposable.dispose()
    }
    
    override public func secondaryAction(at point: CGPoint) {
        guard let item = self.item else {
            return
        }
        item.interaction.activateChatPreview?(item, nil, self.contextContainer, nil, point)
    }
    
    func setupItem(item: ChatListItem, synchronousLoads: Bool) {
        let previousItem = self.item
        self.item = item
        
        var storyState: ChatListItemContent.StoryState?
        if case let .peer(peerData) = item.content {
            storyState = peerData.storyState
        } else if case let .groupReference(groupReference) = item.content {
            storyState = groupReference.storyState
        }
        
        var peer: EnginePeer?
        var displayAsMessage = false
        var enablePreview = true
        var peerIsMonoforum = false
        switch item.content {
        case .loading:
            displayAsMessage = true
            enablePreview = false
        case let .peer(peerData):
            displayAsMessage = peerData.displayAsMessage
            if displayAsMessage, case let .user(author) = peerData.messages.last?.author {
                peer = .user(author)
            } else {
                peer = peerData.peer.chatOrMonoforumMainPeer
                if case let .channel(channel) = peerData.peer.peer, channel.isMonoForum {
                    peerIsMonoforum = true
                }
            }
            if peerData.peer.peerId.namespace == Namespaces.Peer.SecretChat {
                enablePreview = false
            }
        case let .groupReference(groupReferenceData):
            if let previousItem = previousItem, case let .groupReference(previousGroupReferenceData) = previousItem.content, groupReferenceData.hiddenByDefault != previousGroupReferenceData.hiddenByDefault {
                UIView.transition(with: self.avatarNode.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                }, completion: nil)
            }
            self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: .archivedChatsIcon(hiddenByDefault: groupReferenceData.hiddenByDefault), emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
        }
        
        if item.interaction.activateChatPreview == nil {
            enablePreview = false
        }
        
        self.avatarNode.setStoryStats(storyStats: storyState.flatMap { storyState in
            return AvatarNode.StoryStats(
                totalCount: storyState.stats.totalCount,
                unseenCount: storyState.stats.unseenCount,
                hasUnseenCloseFriendsItems: storyState.hasUnseenCloseFriends
            )
        }, presentationParams: AvatarNode.StoryPresentationParams(
            colors: AvatarNode.Colors(theme: item.presentationData.theme),
            lineWidth: 2.33,
            inactiveLineWidth: 1.33
        ), transition: .immediate)
        self.avatarNode.isUserInteractionEnabled = storyState != nil
        
        if let peer = peer {
            var overrideImage: AvatarNodeImageOverride?
            if case let .peer(peerData) = item.content, peerData.customMessageListData != nil {
            } else if peer.id.isReplies {
                overrideImage = .repliesIcon
            } else if peer.id.isAnonymousSavedMessages {
                overrideImage = .anonymousSavedMessagesIcon(isColored: true)
            } else if peer.id == item.context.account.peerId && !displayAsMessage {
                if case .savedMessagesChats = item.chatListLocation {
                    overrideImage = .myNotesIcon
                } else {
                    overrideImage = .savedMessagesIcon
                }
            } else if peer.isDeleted {
                overrideImage = .deletedIcon
            }
            var isForumAvatar = false
            if peerIsMonoforum {
                isForumAvatar = true
            }
            if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                isForumAvatar = true
            }
            if case let .peer(data) = item.content {
                if data.displayAsTopicList {
                    isForumAvatar = true
                }
            }
            
            var avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            
            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                avatarDiameter = 40.0
            }
                
            if avatarDiameter != 60.0 {
                let avatarFontSize = floor(avatarDiameter * 26.0 / 60.0)
                if self.avatarNode.font.pointSize != avatarFontSize {
                    self.avatarNode.font = avatarPlaceholderFont(size: avatarFontSize)
                }
            }
            let avatarClipStyle: AvatarNodeClipStyle
            if peerIsMonoforum {
                avatarClipStyle = .bubble
            } else if isForumAvatar {
                avatarClipStyle = .roundedRect
            } else {
                avatarClipStyle = .round
            }
            
            if peer.smallProfileImage != nil && overrideImage == nil {
                self.avatarNode.setPeerV2(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: avatarClipStyle, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: avatarDiameter, height: avatarDiameter))
            } else {
                self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: avatarClipStyle, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: 60.0, height: 60.0))
            }
            
            if peer.isPremium && peer.id != item.context.account.peerId {
                let context = item.context
                self.cachedDataDisposable.set((context.account.postbox.peerView(id: peer.id)
                |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
                    guard let strongSelf = self else {
                        return
                    }
                    let cachedPeerData = peerView.cachedData as? CachedUserData
                    var personalPhoto: TelegramMediaImage?
                    var profilePhoto: TelegramMediaImage?
                    var isKnown = false
                    
                    if let cachedPeerData = cachedPeerData {
                        if case let .known(maybePersonalPhoto) = cachedPeerData.personalPhoto {
                            personalPhoto = maybePersonalPhoto
                            isKnown = true
                        }
                        if case let .known(maybePhoto) = cachedPeerData.photo {
                            profilePhoto = maybePhoto
                            isKnown = true
                        }
                    }
                    
                    if isKnown {
                        let photo = personalPhoto ?? profilePhoto
                        if let photo = photo, item.context.sharedContext.energyUsageSettings.loopEmoji, (!photo.videoRepresentations.isEmpty || photo.emojiMarkup != nil) {
                            let videoNode: AvatarVideoNode
                            if let current = strongSelf.avatarVideoNode {
                                videoNode = current
                            } else {
                                videoNode = AvatarVideoNode(context: item.context)
                                strongSelf.avatarNode.contentNode.addSubnode(videoNode)
                                strongSelf.avatarVideoNode = videoNode
                            }
                            videoNode.update(peer: peer, photo: photo, size: CGSize(width: 60.0, height: 60.0))
                            
                            if strongSelf.hierarchyTrackingLayer == nil {
                                let hierarchyTrackingLayer = HierarchyTrackingLayer()
                                hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.trackingIsInHierarchy = true
                                }
                                
                                hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.trackingIsInHierarchy = false
                                }
                                strongSelf.hierarchyTrackingLayer = hierarchyTrackingLayer
                                strongSelf.layer.addSublayer(hierarchyTrackingLayer)
                            }
                        } else {
                            if let avatarVideoNode = strongSelf.avatarVideoNode {
                                avatarVideoNode.removeFromSupernode()
                                strongSelf.avatarVideoNode = nil
                            }
                            strongSelf.hierarchyTrackingLayer?.removeFromSuperlayer()
                            strongSelf.hierarchyTrackingLayer = nil
                        }                 
                        strongSelf.updateVideoVisibility()
                    } else {
                        if let photo = peer.largeProfileImage, photo.hasVideo {
                            let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).startStandalone()
                        }
                    }
                }))
            } else {
                self.cachedDataDisposable.set(nil)
                
                self.avatarVideoNode?.removeFromSupernode()
                self.avatarVideoNode = nil
                
                self.hierarchyTrackingLayer?.removeFromSuperlayer()
                self.hierarchyTrackingLayer = nil
            }
        }
        
        self.contextContainer.isGestureEnabled = enablePreview && !item.editing
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (first, last, firstWithHeader, nextIsPinned) = ChatListItem.mergeType(item: item as! ChatListItem, previousItem: previousItem, nextItem: nextItem)
        let (nodeLayout, apply) = layout(item as! ChatListItem, params, first, last, firstWithHeader, nextIsPinned)
        apply(false, false)
        self.contentSize = nodeLayout.contentSize
        self.insets = nodeLayout.insets
    }
    
    class func insets(first: Bool, last: Bool, firstWithHeader: Bool) -> UIEdgeInsets {
        return UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        self.isHighlighted = highlighted
        
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    var reallyHighlighted: Bool {
        var reallyHighlighted = self.isHighlighted
        if let item = self.item {
            if let itemChatLocation = item.content.chatLocation {
                if itemChatLocation == item.interaction.highlightedChatLocation?.location {
                    reallyHighlighted = true
                }
            }
        }
        return reallyHighlighted
    }
    
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        let highlightProgress: CGFloat = self.item?.interaction.highlightedChatLocation?.progress ?? 1.0
        
        if self.reallyHighlighted {
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
                self.highlightedBackgroundNode.alpha = 0.0
            }
            self.highlightedBackgroundNode.layer.removeAllAnimations()
            transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: highlightProgress)
            
            if let compoundHighlightingNode = self.compoundHighlightingNode {
                transition.updateAlpha(layer: compoundHighlightingNode.layer, alpha: 0.0)
            }
            
            if let item = self.item, case .chatList = item.index {
                self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted, voiceChat: self.onlineIsVoiceChat), color: nil, transition: transition)
                self.starView?.setOutlineColor(item.presentationData.theme.chatList.itemHighlightedBackgroundColor, transition: transition)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                transition.updateAlpha(layer: self.highlightedBackgroundNode.layer, alpha: 1.0 - highlightProgress, completion: { [weak self] completed in
                    if let strongSelf = self {
                        if completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    }
                })
            }
            
            if let compoundHighlightingNode = self.compoundHighlightingNode {
                transition.updateAlpha(layer: compoundHighlightingNode.layer, alpha: self.authorNode.alpha)
            }
            
            if let item = self.item {
                let onlineIcon: UIImage?
                let effectiveBackgroundColor: UIColor
                if item.isPinned {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned, voiceChat: self.onlineIsVoiceChat)
                    effectiveBackgroundColor = item.presentationData.theme.chatList.pinnedItemBackgroundColor
                } else {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular, voiceChat: self.onlineIsVoiceChat)
                    effectiveBackgroundColor = item.presentationData.theme.chatList.itemBackgroundColor
                }
                self.onlineNode.setImage(onlineIcon, color: nil, transition: transition)
                self.starView?.setOutlineColor(effectiveBackgroundColor, transition: transition)
            }
        }
    }
    
    override public func tapped() {
        guard let item = self.item, item.editing else {
            return
        }
        if case let .peer(peerData) = item.content {
            if peerData.promoInfo == nil, let mainPeer = peerData.peer.peer {
                switch item.index {
                case let .forum(_, _, threadIdValue, _, _):
                    item.interaction.toggleThreadsSelection([threadIdValue], !item.selected)
                case .chatList:
                    item.interaction.togglePeerSelected(mainPeer, nil)
                }
            }
        }
    }
    
    func asyncLayout() -> (_ item: ChatListItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool, _ firstWithHeader: Bool, _ nextIsPinned: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let dateLayout = TextNode.asyncLayout(self.dateNode)
        let textLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let makeTrailingTextBadgeLayout = TextNode.asyncLayout(self.trailingTextBadgeNode)
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let titleBadgeLayout = TextNode.asyncLayout(self.titleBadge?.textNode)
        let authorLayout = self.authorNode.asyncLayout()
        let makeMeasureLayout = TextNode.asyncLayout(self.measureNode)
        let inputActivitiesLayout = self.inputActivitiesNode.asyncLayout()
        let badgeLayout = self.badgeNode.asyncLayout()
        let mentionBadgeLayout = self.mentionBadgeNode.asyncLayout()
        let onlineLayout = self.onlineNode.asyncLayout()
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        let makeActionButtonTitleNodeLayout = TextNode.asyncLayout(self.actionButtonTitleNode)
        
        let currentItem = self.layoutParams?.0
        let currentChatListText = self.cachedChatListText
        let currentChatListSearchResult = self.cachedChatListSearchResult
        let currentChatListQuoteSearchResult = self.cachedChatListQuoteSearchResult
        let currentCustomTextEntities = self.cachedCustomTextEntities
        
        return { item, params, first, last, firstWithHeader, nextIsPinned in
            let titleFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let italicTextFont = Font.italic(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let badgeFont = Font.with(size: floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
            let avatarBadgeFont = Font.with(size: floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
            
            let account = item.context.account
            var messages: [EngineMessage]
            enum ContentPeer {
                case chat(EngineRenderedPeer)
                case group([EngineChatList.GroupItem.Item])
            }
            let contentPeer: ContentPeer
            let combinedReadState: EnginePeerReadCounters?
            let unreadCount: (count: Int32, unread: Bool, muted: Bool, mutedCount: Int32?, isProvisonal: Bool)
            let isRemovedFromTotalUnreadCount: Bool
            let peerPresence: EnginePeer.Presence?
            let draftState: ChatListItemContent.DraftState?
            let mediaDraftContentType: EngineChatList.MediaDraftContentType?
            let hasUnseenMentions: Bool
            let hasUnseenReactions: Bool
            let inputActivities: [(EnginePeer, PeerInputActivity)]?
            let isPeerGroup: Bool
            let promoInfo: ChatListNodeEntryPromoInfo?
            let displayAsMessage: Bool
            let hasFailedMessages: Bool
            var threadInfo: ChatListItemContent.ThreadInfo?
            var forumTopicData: EngineChatList.ForumTopicData?
            var topForumTopicItems: [EngineChatList.ForumTopicData] = []
            var autoremoveTimeout: Int32?
            var itemTags: [ChatListItemContent.Tag] = []
            
            var groupHiddenByDefault = false
            
            switch item.content {
                case .loading:
                    messages = []
                    contentPeer = .group([])
                    combinedReadState = nil
                    unreadCount = (0, false, false, nil, false)
                    isRemovedFromTotalUnreadCount = false
                    peerPresence = nil
                    draftState = nil
                    mediaDraftContentType = nil
                    hasUnseenMentions = false
                    hasUnseenReactions = false
                    inputActivities = nil
                    isPeerGroup = false
                    promoInfo = nil
                    displayAsMessage = true
                    hasFailedMessages = false
                case let .peer(peerData):
                    let messagesValue = peerData.messages
                    let peerValue = peerData.peer
                    let threadInfoValue = peerData.threadInfo
                    let combinedReadStateValue = peerData.combinedReadState
                    let isRemovedFromTotalUnreadCountValue = peerData.isRemovedFromTotalUnreadCount
                    let peerPresenceValue = peerData.presence
                    let hasUnseenMentionsValue = peerData.hasUnseenMentions
                    let hasUnseenReactionsValue = peerData.hasUnseenReactions
                    let draftStateValue = peerData.draftState
                    let inputActivitiesValue = peerData.inputActivities
                    let promoInfoValue = peerData.promoInfo
                    let ignoreUnreadBadge = peerData.ignoreUnreadBadge
                    let displayAsMessageValue = peerData.displayAsMessage
                    let forumTopicDataValue = peerData.forumTopicData
                    let topForumTopicItemsValue = peerData.topForumTopicItems
                    
                    itemTags = peerData.tags
                
                    autoremoveTimeout = peerData.autoremoveTimeout
                
                    messages = messagesValue
                    contentPeer = .chat(peerValue)
                    combinedReadState = combinedReadStateValue
                    if let combinedReadState = combinedReadState, promoInfoValue == nil && !ignoreUnreadBadge {
                        unreadCount = (combinedReadState.count, combinedReadState.isUnread, isRemovedFromTotalUnreadCountValue || combinedReadState.isMuted, nil, !combinedReadState.hasEverRead)
                    } else {
                        unreadCount = (0, false, false, nil, false)
                    }
                    if let _ = promoInfoValue {
                        isRemovedFromTotalUnreadCount = false
                    } else {
                        isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCountValue
                    }
                    peerPresence = peerPresenceValue.flatMap { presence -> EnginePeer.Presence in
                        return EnginePeer.Presence(status: presence.status, lastActivity: 0)
                    }
                    draftState = draftStateValue
                    mediaDraftContentType = peerData.mediaDraftContentType
                    threadInfo = threadInfoValue
                    hasUnseenMentions = hasUnseenMentionsValue
                    hasUnseenReactions = hasUnseenReactionsValue
                    forumTopicData = forumTopicDataValue
                    topForumTopicItems = topForumTopicItemsValue
                
                    if item.interaction.searchTextHighightState != nil, threadInfo == nil, topForumTopicItems.isEmpty, let message = messagesValue.first, let threadId = message.threadId, let associatedThreadInfo = message.associatedThreadInfo {
                        topForumTopicItems = [EngineChatList.ForumTopicData(id: threadId, title: associatedThreadInfo.title, iconFileId: associatedThreadInfo.icon, iconColor: associatedThreadInfo.iconColor, maxOutgoingReadMessageId: message.id, isUnread: false, threadPeer: nil)]
                    }
                    
                    switch peerValue.peer {
                    case .user, .secretChat:
                        if let peerPresence = peerPresence, case .present = peerPresence.status {
                            inputActivities = inputActivitiesValue
                        } else {
                            inputActivities = nil
                        }
                    default:
                        inputActivities = inputActivitiesValue
                    }
                    
                    isPeerGroup = false
                    promoInfo = promoInfoValue
                    displayAsMessage = displayAsMessageValue
                    hasFailedMessages = messagesValue.last?.flags.contains(.Failed) ?? false // hasFailedMessagesValue
                case let .groupReference(groupReferenceData):
                    let peers = groupReferenceData.peers
                    let messageValue = groupReferenceData.message
                    let unreadCountValue = groupReferenceData.unreadCount
                    let hiddenByDefault = groupReferenceData.hiddenByDefault
                
                    if let _ = messageValue, !peers.isEmpty {
                        contentPeer = .chat(peers[0].peer)
                    } else {
                        contentPeer = .group(peers)
                    }
                    if let message = messageValue {
                        messages = [message]
                    } else {
                        messages = []
                    }
                    combinedReadState = nil
                    isRemovedFromTotalUnreadCount = false
                    draftState = nil
                    mediaDraftContentType = nil
                    hasUnseenMentions = false
                    hasUnseenReactions = false
                    inputActivities = nil
                    isPeerGroup = true
                    groupHiddenByDefault = hiddenByDefault
                    unreadCount = (Int32(unreadCountValue), unreadCountValue != 0, true, nil, false)
                    peerPresence = nil
                    promoInfo = nil
                    displayAsMessage = false
                    hasFailedMessages = false
            }
            
            if let messageValue = messages.last {
                for media in messageValue.media {
                    if let media = media as? TelegramMediaAction, case .historyCleared = media.action {
                        messages = []
                    }
                }
            }
            
            let useChatListLayout: Bool
            if case .chatList = item.chatListLocation {
                useChatListLayout = true
            } else if case .savedMessagesChats = item.chatListLocation {
                useChatListLayout = true
            } else if displayAsMessage {
                useChatListLayout = true
            } else {
                useChatListLayout = false
            }
            
            let theme = item.presentationData.theme.chatList
            
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            var authorAttributedString: NSAttributedString?
            var authorIsCurrentChat: Bool = false
            var textAttributedString: NSAttributedString?
            var textLeftCutout: CGFloat = 0.0
            var dateAttributedString: NSAttributedString?
            var titleAttributedString: NSAttributedString?
            var titleBadgeText: String?
            var badgeContent = ChatListBadgeContent.none
            var mentionBadgeContent = ChatListBadgeContent.none
            var statusState = ChatListStatusNodeState.none
            
            var currentBadgeBackgroundImage: UIImage?
            var currentAvatarBadgeBackgroundImage: UIImage?
            var currentMentionBadgeImage: UIImage?
            var currentPinnedIconImage: UIImage?
            var currentMutedIconImage: UIImage?
            var currentCredibilityIconContent: EmojiStatusComponent.Content?
            var currentVerifiedIconContent: EmojiStatusComponent.Content?
            var currentStatusIconContent: EmojiStatusComponent.Content?
            var currentStatusIconParticleColor: UIColor?
            var currentSecretIconImage: UIImage?
            var currentForwardedIcon: UIImage?
            var currentStoryIcon: UIImage?
            var currentGiftIcon: UIImage?
            var currentLocationIcon: UIImage?
            
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            if item.editing {
                let selectionControlStyle: ItemListSelectableControlNode.Style
                if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                    selectionControlStyle = .small
                } else {
                    selectionControlStyle = .compact
                }
                
                let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, item.selected, selectionControlStyle)
                if promoInfo == nil && !isPeerGroup {
                    selectableControlSizeAndApply = sizeAndApply
                }
                editingOffset = sizeAndApply.0
                
                var canReorder = false
                
                if case let .chatList(index) = item.index, index.pinningIndex != nil, promoInfo == nil, !isPeerGroup {
                    canReorder = true
                } else if case let .forum(pinnedIndex, _, _, _, _) = item.index, case .index = pinnedIndex {
                    if case let .chat(itemPeer) = contentPeer, case let .channel(channel) = itemPeer.peer {
                        let canPin = channel.flags.contains(.isCreator) || channel.hasPermission(.pinMessages)
                        if canPin {
                            canReorder = true
                        }
                    }
                }
                
                if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                    canReorder = true
                }
                
                if canReorder {
                    let sizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = sizeAndApply
                    reorderInset = sizeAndApply.0
                }
            } else {
                editingOffset = 0.0
            }
            
            let enableChatListPhotos = true
            
            // if changed, adjust setupItem accordingly
            var avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            let avatarLeftInset: CGFloat
            
            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                avatarDiameter = 40.0
                avatarLeftInset = 17.0 + avatarDiameter
            } else {
                if item.interaction.isInlineMode {
                    avatarLeftInset = 12.0
                } else if !useChatListLayout {
                    avatarLeftInset = 50.0
                } else {
                    avatarLeftInset = 18.0 + avatarDiameter
                }
            }
            
            let badgeDiameter = floor(item.presentationData.fontSize.baseDisplaySize * 20.0 / 17.0)
            let avatarBadgeDiameter: CGFloat = floor(floor(item.presentationData.fontSize.itemListBaseFontSize * 22.0 / 17.0))
            let avatarTimerBadgeDiameter: CGFloat = floor(floor(item.presentationData.fontSize.itemListBaseFontSize * 24.0 / 17.0))
            
            let currentAvatarBadgeCleanBackgroundImage: UIImage? = PresentationResourcesChatList.badgeBackgroundBorder(item.presentationData.theme, diameter: avatarBadgeDiameter + 4.0)
            
            let leftInset: CGFloat = params.leftInset + avatarLeftInset
            
            enum ContentData {
                case chat(itemPeer: EngineRenderedPeer, threadInfo: ChatListItemContent.ThreadInfo?, peer: EnginePeer?, hideAuthor: Bool, messageText: String, spoilers: [NSRange]?, customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)]?)
                case group(peers: [EngineChatList.GroupItem.Item])
            }
            
            let contentData: ContentData
            
            var hideAuthor = false
            switch contentPeer {
                case let .chat(itemPeer):
                    var (peer, initialHideAuthor, messageText, spoilers, customEmojiRanges) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, contentSettings: item.context.currentContentSettings.with { $0 }, messages: messages, chatPeer: itemPeer, accountPeerId: item.context.account.peerId, enableMediaEmoji: !enableChatListPhotos, isPeerGroup: isPeerGroup)
                    
                    if case let .psa(_, maybePsaText) = promoInfo, let psaText = maybePsaText {
                        initialHideAuthor = true
                        messageText = psaText
                    }
                
                    switch itemPeer.peer {
                    case .user:
                        if let attribute = messages.first?._asMessage().reactionsAttribute {
                            loop: for recentPeer in attribute.recentPeers {
                                if recentPeer.isUnseen {
                                    switch recentPeer.value {
                                    case let .builtin(value):
                                        messageText = item.presentationData.strings.ChatList_UserReacted(value).string
                                    case .custom:
                                        break
                                    case .stars:
                                        break
                                    }
                                    break loop
                                }
                            }
                        }
                    default:
                        break
                    }
                    
                    contentData = .chat(itemPeer: itemPeer, threadInfo: threadInfo, peer: peer, hideAuthor: hideAuthor, messageText: messageText, spoilers: spoilers, customEmojiRanges: customEmojiRanges)
                    hideAuthor = initialHideAuthor
                case let .group(groupPeers):
                    contentData = .group(peers: groupPeers)
                    hideAuthor = true
            }
            
            var attributedText: NSAttributedString
            var hasDraft = false
            
            var inlineAuthorPrefix: String?
            var useInlineAuthorPrefix = false
            if case .groupReference = item.content {
                useInlineAuthorPrefix = true
            }
            if !itemTags.isEmpty {
                forumTopicData = nil
                topForumTopicItems = []
                
                if case let .chat(itemPeer, _, _, _, _, _, _) = contentData {
                    if let messagePeer = itemPeer.chatMainPeer {
                        switch messagePeer {
                        case let .channel(channel):
                            if case .group = channel.info {
                                useInlineAuthorPrefix = true
                            }
                        case .legacyGroup:
                            useInlineAuthorPrefix = true
                        default:
                            break
                        }
                    }
                }
            }
            
            if useInlineAuthorPrefix {
                if case let .user(author) = messages.last?.author {
                    if author.id == item.context.account.peerId {
                        inlineAuthorPrefix = item.presentationData.strings.DialogList_You
                    } else if messages.last?.id.peerId.namespace != Namespaces.Peer.CloudUser && messages.last?.id.peerId.namespace != Namespaces.Peer.SecretChat {
                        inlineAuthorPrefix = EnginePeer.user(author).compactDisplayTitle
                    }
                }
            }
            
            var chatListText: (String, String)?
            var chatListSearchResult: CachedChatListSearchResult?
            var chatListQuoteSearchResult: CachedChatListSearchResult?
            var customTextEntities: CachedCustomTextEntities?
            
            let contentImageSide: CGFloat = max(10.0, min(20.0, floor(item.presentationData.fontSize.baseDisplaySize * 18.0 / 17.0)))
            let contentImageSize = CGSize(width: contentImageSide, height: contentImageSide)
            let contentImageSpacing: CGFloat = 2.0
            let forwardedIconSpacing: CGFloat = 6.0
            let contentImageTrailingSpace: CGFloat = 5.0
            
            var contentImageSpecs: [ContentImageSpec] = []
            var avatarContentImageSpec: ContentImageSpec?
            var forumThread: (id: Int64, title: String, iconId: Int64?, iconColor: Int32, threadPeer: EnginePeer?, isUnread: Bool)?
            
            var displayForwardedIcon = false
            var displayStoryReplyIcon = false
            var displayGiftIcon = false
            var displayLocationIcon = false
            var ignoreForwardedIcon = false
            
            switch contentData {
                case let .chat(itemPeer, _, _, _, text, spoilers, customEmojiRanges):
                    var isUser = false
                    if case .user = itemPeer.chatMainPeer {
                        isUser = true
                    }

                    var peerText: String?
                    if case .savedMessagesChats = item.chatListLocation {
                        if let message = messages.last, let forwardInfo = message.forwardInfo, let author = forwardInfo.author {
                            if author.id != itemPeer.chatMainPeer?.id {
                                peerText = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                            }
                        }
                    } else if case .groupReference = item.content {
                        if let messagePeer = itemPeer.chatMainPeer {
                            peerText = messagePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                        }
                    } else if let message = messages.last, let author = message.author?._asPeer(), let peer = itemPeer.chatMainPeer {
                        if peer.id.isVerificationCodes {
                            if let message = messages.last, let forwardInfo = message.forwardInfo, let author = forwardInfo.author {
                                peerText = EnginePeer(author).compactDisplayTitle
                            }
                        } else if !isUser {
                            if case let .channel(peer) = peer, case .broadcast = peer.info {
                            } else if !displayAsMessage {
                                if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported), let authorSignature = forwardInfo.authorSignature {
                                    peerText = authorSignature
                                } else {
                                    peerText = author.id == account.peerId ? item.presentationData.strings.DialogList_You : EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                    authorIsCurrentChat = author.id == peer.id
                                }
                            }
                        }
                    }
                
                    if case .chatList = item.chatListLocation, itemPeer.peerId == item.context.account.peerId, let message = messages.first {
                        var effectiveAuthor: Peer? = message.author?._asPeer()
                        if let forwardInfo = message.forwardInfo {
                            effectiveAuthor = forwardInfo.author
                            if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                                effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                            }
                        }
                        if let sourceAuthorInfo = message._asMessage().sourceAuthorInfo {
                            if let originalAuthor = sourceAuthorInfo.originalAuthor, let peer = message.peers[originalAuthor] {
                                effectiveAuthor = peer
                            } else if let authorSignature = sourceAuthorInfo.originalAuthorName {
                                effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                            }
                        }
                        
                        if let effectiveAuthor, effectiveAuthor.id != itemPeer.chatMainPeer?.id {
                            authorIsCurrentChat = false
                            peerText = EnginePeer(effectiveAuthor).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                            ignoreForwardedIcon = true
                        }
                    }
                
                    if let _ = peerText, case let .channel(channel) = itemPeer.chatMainPeer, channel.isForumOrMonoForum, threadInfo == nil {
                        if let forumTopicData {
                            forumThread = (forumTopicData.id, forumTopicData.title, forumTopicData.iconFileId, forumTopicData.iconColor, forumTopicData.threadPeer, forumTopicData.isUnread)
                        } else if let threadInfo {
                            forumThread = (threadInfo.id, threadInfo.info.title, threadInfo.info.icon, threadInfo.info.iconColor, nil, false)
                        }
                    }
                    
                    let messageText: String
                    if let currentChatListText = currentChatListText, currentChatListText.0 == text {
                        messageText = currentChatListText.1
                        chatListText = currentChatListText
                    } else {
                        if let spoilers = spoilers, !spoilers.isEmpty {
                            messageText = text
                        } else if let customEmojiRanges = customEmojiRanges, !customEmojiRanges.isEmpty {
                            messageText = text
                        } else {
                            messageText = foldLineBreaks(text)
                        }
                        chatListText = (text, messageText)
                    }
                    
                    if inlineAuthorPrefix == nil, let mediaDraftContentType {
                        hasDraft = true
                        authorAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Draft, font: textFont, textColor: theme.messageDraftTextColor)
                        
                        switch mediaDraftContentType {
                        case .audio:
                            attributedText = NSAttributedString(string: item.presentationData.strings.Message_Audio, font: textFont, textColor: theme.messageTextColor)
                        case .video:
                            attributedText = NSAttributedString(string: item.presentationData.strings.Message_VideoMessage, font: textFont, textColor: theme.messageTextColor)
                        }
                    } else if inlineAuthorPrefix == nil, let draftState = draftState {
                        hasDraft = true
                        let draftText = stringWithAppliedEntities(draftState.text, entities: draftState.entities, baseColor: theme.messageTextColor, linkColor: theme.messageTextColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, message: nil)
                        
                        if !itemTags.isEmpty {
                            let tempAttributedText = foldLineBreaks(draftText)
                            let attributedTextWithDraft = NSMutableAttributedString()
                            attributedTextWithDraft.append(NSAttributedString(string: item.presentationData.strings.DialogList_Draft + ": ", font: textFont, textColor: theme.messageDraftTextColor))
                            attributedTextWithDraft.append(tempAttributedText)
                            attributedText = attributedTextWithDraft
                        } else {
                            authorAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Draft, font: textFont, textColor: theme.messageDraftTextColor)
                            
                            attributedText = foldLineBreaks(draftText)
                        }
                    } else if let message = messages.last {
                        var composedString: NSMutableAttributedString
                        
                        if let peerText = peerText {
                            authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                        }
                        
                        var entities = (message._asMessage().textEntitiesAttribute?.entities ?? []).filter { entity in
                            switch entity.type {
                            case .Spoiler, .CustomEmoji:
                                return true
                            case .Strikethrough, .Underline, .Italic, .Bold:
                                return true
                            default:
                                return false
                            }
                        }
                        
                        if message.id.peerId.isTelegramNotifications || message.id.peerId.isVerificationCodes {
                            let regex: NSRegularExpression?
                            if message.id.peerId.isTelegramNotifications {
                                regex = telegramCodeRegex
                            } else {
                                regex = loginCodeRegex
                            }
                            if let cached = currentCustomTextEntities, cached.matches(text: message.text) {
                                customTextEntities = cached
                            } else if let matches = regex?.matches(in: message.text, options: [], range: NSMakeRange(0, (message.text as NSString).length)) {
                                var entities: [MessageTextEntity] = []
                                if let first = matches.first {
                                    entities.append(MessageTextEntity(range: first.range.location ..< first.range.location + first.range.length, type: .Spoiler))
                                }
                                customTextEntities = CachedCustomTextEntities(text: message.text, textEntities: entities)
                            }
                        }
                        
                        if let customTextEntities, !customTextEntities.textEntities.isEmpty {
                            entities.append(contentsOf: customTextEntities.textEntities)
                        }
                        
                        let messageString: NSAttributedString
                        if !message.text.isEmpty && entities.count > 0 {
                            var messageText = message.text
                            var entities = entities
                            if !"".isEmpty, let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, !translation.text.isEmpty {
                                messageText = translation.text
                                entities = translation.entities
                            }
                            
                            messageString = foldLineBreaks(stringWithAppliedEntities(messageText, entities: entities, baseColor: theme.messageTextColor, linkColor: theme.messageTextColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: italicTextFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message._asMessage()))
                        } else if spoilers != nil || customEmojiRanges != nil {
                            let mutableString = NSMutableAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                            if let spoilers = spoilers {
                                for range in spoilers {
                                    var range = range
                                    if range.location > mutableString.length {
                                        continue
                                    } else if range.location + range.length > mutableString.length {
                                        range.length = mutableString.length - range.location
                                    }
                                    mutableString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true, range: range)
                                }
                            }
                            if let customEmojiRanges = customEmojiRanges {
                                for (range, attribute) in customEmojiRanges {
                                    var range = range
                                    if range.location > mutableString.length {
                                        continue
                                    } else if range.location + range.length > mutableString.length {
                                        range.length = mutableString.length - range.location
                                    }
                                    mutableString.addAttribute(ChatTextInputAttributes.customEmoji, value: attribute, range: range)
                                }
                            }
                            messageString = mutableString
                        } else {
                            messageString = NSAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                        }
                        if let inlineAuthorPrefix = inlineAuthorPrefix {
                            composedString = NSMutableAttributedString()
                            composedString.append(NSAttributedString(string: "\(inlineAuthorPrefix): ", font: textFont, textColor: theme.titleColor))
                            composedString.append(messageString)
                        } else {
                            composedString = NSMutableAttributedString(attributedString: messageString)
                        }
                        
                        var composedReplyString: NSMutableAttributedString?
                        if let searchQuery = item.interaction.searchTextHighightState {
                            var quoteText: String?
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    if let quote = attribute.quote {
                                        quoteText = quote.text
                                    }
                                } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                                    if let quote = attribute.quote {
                                        quoteText = quote.text
                                    }
                                }
                            }
                            if let quoteText {
                                let quoteString = foldLineBreaks(stringWithAppliedEntities(quoteText, entities: [], baseColor: theme.messageTextColor, linkColor: theme.messageTextColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: italicTextFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: nil))
                                composedReplyString = NSMutableAttributedString(attributedString: quoteString)
                            }
                            
                            if let cached = currentChatListSearchResult, cached.matches(text: composedString.string, searchQuery: searchQuery) {
                                chatListSearchResult = cached
                            } else {
                                let (ranges, text) = findSubstringRanges(in: composedString.string, query: searchQuery)
                                chatListSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                            }
                            
                            if let composedReplyString {
                                if let cached = currentChatListQuoteSearchResult, cached.matches(text: composedReplyString.string, searchQuery: searchQuery) {
                                    chatListQuoteSearchResult = cached
                                } else {
                                    let (ranges, text) = findSubstringRanges(in: composedReplyString.string, query: searchQuery)
                                    chatListQuoteSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                                }
                            } else {
                                chatListQuoteSearchResult = nil
                            }
                        } else {
                            chatListSearchResult = nil
                            chatListQuoteSearchResult = nil
                        }
                        
                        if let chatListSearchResult = chatListSearchResult, let firstRange = chatListSearchResult.resultRanges.first {
                            for range in chatListSearchResult.resultRanges {
                                let stringRange = NSRange(range, in: chatListSearchResult.text)
                                if stringRange.location >= 0 && stringRange.location + stringRange.length <= composedString.length {
                                    var stringRange = stringRange
                                    if stringRange.location > composedString.length {
                                        continue
                                    } else if stringRange.location + stringRange.length > composedString.length {
                                        stringRange.length = composedString.length - stringRange.location
                                    }
                                    composedString.addAttribute(.foregroundColor, value: theme.messageHighlightedTextColor, range: stringRange)
                                }
                            }
                            
                            let firstRangeOrigin = chatListSearchResult.text.distance(from: chatListSearchResult.text.startIndex, to: firstRange.lowerBound)
                            if firstRangeOrigin > 24 && !chatListSearchResult.searchQuery.hasPrefix("#") {
                                var leftOrigin: Int = 0
                                (composedString.string as NSString).enumerateSubstrings(in: NSMakeRange(0, firstRangeOrigin), options: [.byWords, .reverse]) { (str, range1, _, _) in
                                    let distanceFromEnd = firstRangeOrigin - range1.location
                                    if (distanceFromEnd > 12 || range1.location == 0) && leftOrigin == 0 {
                                        leftOrigin = range1.location
                                    }
                                }
                                composedString = composedString.attributedSubstring(from: NSMakeRange(leftOrigin, composedString.length - leftOrigin)).mutableCopy() as! NSMutableAttributedString
                                composedString.insert(NSAttributedString(string: "\u{2026}", attributes: [NSAttributedString.Key.font: textFont, NSAttributedString.Key.foregroundColor: theme.messageTextColor]), at: 0)
                            }
                        } else if var composedReplyString, let chatListQuoteSearchResult, let firstRange = chatListQuoteSearchResult.resultRanges.first {
                            for range in chatListQuoteSearchResult.resultRanges {
                                let stringRange = NSRange(range, in: chatListQuoteSearchResult.text)
                                if stringRange.location >= 0 && stringRange.location + stringRange.length <= composedReplyString.length {
                                    var stringRange = stringRange
                                    if stringRange.location > composedReplyString.length {
                                        continue
                                    } else if stringRange.location + stringRange.length > composedReplyString.length {
                                        stringRange.length = composedReplyString.length - stringRange.location
                                    }
                                    composedReplyString.addAttribute(.foregroundColor, value: theme.messageHighlightedTextColor, range: stringRange)
                                }
                            }
                            
                            let firstRangeOrigin = chatListQuoteSearchResult.text.distance(from: chatListQuoteSearchResult.text.startIndex, to: firstRange.lowerBound)
                            if firstRangeOrigin > 24 {
                                var leftOrigin: Int = 0
                                (composedReplyString.string as NSString).enumerateSubstrings(in: NSMakeRange(0, firstRangeOrigin), options: [.byWords, .reverse]) { (str, range1, _, _) in
                                    let distanceFromEnd = firstRangeOrigin - range1.location
                                    if (distanceFromEnd > 12 || range1.location == 0) && leftOrigin == 0 {
                                        leftOrigin = range1.location
                                    }
                                }
                                composedReplyString = composedReplyString.attributedSubstring(from: NSMakeRange(leftOrigin, composedReplyString.length - leftOrigin)).mutableCopy() as! NSMutableAttributedString
                                composedReplyString.insert(NSAttributedString(string: "\u{2026}", attributes: [NSAttributedString.Key.font: textFont, NSAttributedString.Key.foregroundColor: theme.messageTextColor]), at: 0)
                            }
                            
                            composedString = composedReplyString
                        }
                        
                        attributedText = composedString
                        
                        if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, let commandPrefix = customMessageListData.commandPrefix {
                            let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
                            let boldTextFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
                            mutableAttributedText.insert(NSAttributedString(string: commandPrefix + " ", font: boldTextFont, textColor: theme.titleColor), at: 0)
                            if let searchQuery = customMessageListData.searchQuery {
                                let range = (mutableAttributedText.string as NSString).range(of: searchQuery)
                                if range.location == 0 {
                                    mutableAttributedText.addAttribute(.foregroundColor, value: item.presentationData.theme.list.itemAccentColor, range: range)
                                }
                            }
                            attributedText = mutableAttributedText
                        }
                        
                        if !ignoreForwardedIcon {
                            if case .savedMessagesChats = item.chatListLocation {
                                displayForwardedIcon = false
                            } else if let forwardInfo = message.forwardInfo, !forwardInfo.flags.contains(.isImported) && !message.id.peerId.isVerificationCodes {
                                displayForwardedIcon = true
                            } else if let _ = message.attributes.first(where: { $0 is ReplyStoryAttribute }) {
                                displayStoryReplyIcon = true
                            } else {
                                for media in message.media {
                                    if let _ = media as? TelegramMediaMap {
                                        displayLocationIcon = true
                                    } else if let action = media as? TelegramMediaAction {
                                        switch action.action {
                                        case .giftPremium, .giftStars, .starGift, .starGiftUnique:
                                            displayGiftIcon = true
                                        case let .giftCode(_, _, _, boostPeerId, _, _, _, _, _, _, _):
                                            if boostPeerId == nil {
                                                displayGiftIcon = true
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    break
                                }
                            }
                        }
                
                        var displayMediaPreviews = true
                        if message._asMessage().containsSecretMedia {
                            displayMediaPreviews = false
                        } else if let _ = message.peers[message.id.peerId] as? TelegramSecretChat {
                            displayMediaPreviews = false
                        }
                        if displayMediaPreviews {
                            let contentImageFillSize = CGSize(width: 8.0, height: contentImageSize.height)
                            _ = contentImageFillSize
                            
                            var contentImageIsDisplayedAsAvatar = false
                            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                                contentImageIsDisplayedAsAvatar = true
                            }
                            
                            for message in messages {
                                if contentImageSpecs.count >= 3 {
                                    break
                                }
                                
                                inner: for media in message.media {
                                    if let paidContent = media as? TelegramMediaPaidContent {
                                        let fitSize = contentImageSize
                                        var index: Int64 = 0
                                        for media in paidContent.extendedMedia.prefix(3) {
                                            switch media {
                                            case let .preview(dimensions, immediateThumbnailData, videoDuration):
                                                if let immediateThumbnailData {
                                                    if let videoDuration {
                                                        let thumbnailMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: index), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Video(duration: Double(videoDuration), size: dimensions ?? PixelDimensions(width: 1, height: 1), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
                                                        contentImageSpecs.append(ContentImageSpec(message: message, media:  .file(thumbnailMedia), size: fitSize))
                                                    } else {
                                                        let thumbnailMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: index), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                                                        contentImageSpecs.append(ContentImageSpec(message: message, media:  .image(thumbnailMedia), size: fitSize))
                                                    }
                                                    index += 1
                                                }
                                            case let .full(fullMedia):
                                                if let image = fullMedia as? TelegramMediaImage {
                                                    if let _ = largestImageRepresentation(image.representations) {
                                                        contentImageSpecs.append(ContentImageSpec(message: message, media:  .image(image), size: fitSize))
                                                    }
                                                } else if let file = fullMedia as? TelegramMediaFile {
                                                    if file.isVideo, !file.isVideoSticker, let _ = file.dimensions {
                                                        contentImageSpecs.append(ContentImageSpec(message: message,  media: .file(file), size: fitSize))
                                                    }
                                                }
                                            }
                                        }
                                        break inner
                                    } else if let image = media as? TelegramMediaImage {
                                        if let _ = largestImageRepresentation(image.representations) {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append(ContentImageSpec(message: message, media:  .image(image), size: fitSize))
                                        }
                                        break inner
                                    } else if let file = media as? TelegramMediaFile {
                                        if file.isVideo, !file.isVideoSticker, let _ = file.dimensions {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append(ContentImageSpec(message: message,  media: .file(file), size: fitSize))
                                        } else if contentImageIsDisplayedAsAvatar && (file.isSticker || file.isVideoSticker) {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append(ContentImageSpec(message: message,  media: .file(file), size: fitSize))
                                        } else if !file.previewRepresentations.isEmpty, let _ = file.dimensions, !file.isSticker && !file.isAnimatedSticker && !file.isVideoSticker {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append(ContentImageSpec(message: message,  media: .file(file), size: fitSize))
                                        }
                                        break inner
                                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                        let imageTypes = ["photo", "video", "embed", "gif", "document", "telegram_album"]
                                        if let image = content.image, let type = content.type, imageTypes.contains(type) {
                                            if let _ = largestImageRepresentation(image.representations) {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append(ContentImageSpec(message: message, media: .image(image), size: fitSize))
                                            }
                                            break inner
                                        } else if let file = content.file {
                                            if file.isVideo, !file.isInstantVideo, let _ = file.dimensions {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append(ContentImageSpec(message: message, media: .file(file), size: fitSize))
                                            }
                                            break inner
                                        }
                                    } else if let action = media as? TelegramMediaAction, case let .suggestedProfilePhoto(image) = action.action, let _ = image {
                                        let fitSize = contentImageSize
                                        contentImageSpecs.append(ContentImageSpec(message: message, media: .action(action), size: fitSize))
                                    } else if let storyMedia = media as? TelegramMediaStory, let story = message.associatedStories[storyMedia.storyId], !story.data.isEmpty, case let .item(storyItem) = story.get(Stories.StoredItem.self) {
                                        if let image = storyItem.media as? TelegramMediaImage {
                                            if let _ = largestImageRepresentation(image.representations) {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append(ContentImageSpec(message: message, media: .image(image), size: fitSize))
                                            }
                                            break inner
                                        } else if let file = storyItem.media as? TelegramMediaFile {
                                            if file.isVideo, !file.isInstantVideo, let _ = file.dimensions {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append(ContentImageSpec(message: message, media: .file(file), size: fitSize))
                                            }
                                            break inner
                                        }
                                    }
                                }
                            }
                            
                            if contentImageIsDisplayedAsAvatar {
                                avatarContentImageSpec = contentImageSpecs.first
                                contentImageSpecs.removeAll()
                            }
                        }
                    } else {
                        attributedText = NSAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                        
                        var peerText: String?
                        if case .groupReference = item.content {
                            if let messagePeer = itemPeer.chatMainPeer {
                                peerText = messagePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                            }
                        }
                        
                        if let peerText = peerText {
                            authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                        }
                    }
                case let .group(peers):
                    let textString = NSMutableAttributedString(string: "")
                    var isFirst = true
                    for peer in peers {
                        if let chatMainPeer = peer.peer.chatMainPeer {
                            let peerTitle = chatMainPeer.compactDisplayTitle
                            if !peerTitle.isEmpty {
                                if isFirst {
                                    isFirst = false
                                } else {
                                    textString.append(NSAttributedString(string: ", ", font: textFont, textColor: theme.messageTextColor))
                                }
                                textString.append(NSAttributedString(string: peerTitle, font: textFont, textColor: peer.isUnread ? theme.authorNameColor : theme.messageTextColor))
                            }
                        }
                    }
                    if textString.length == 0, case let .groupReference(data) = item.content, let storyState = data.storyState, storyState.stats.totalCount != 0 {
                        let storyText: String = item.presentationData.strings.ChatList_ArchiveStoryCount(Int32(storyState.stats.totalCount))
                        textString.append(NSAttributedString(string: storyText, font: textFont, textColor: theme.messageTextColor))
                    }
                    attributedText = textString
            }
            
            if displayForwardedIcon {
                currentForwardedIcon = PresentationResourcesChatList.forwardedIcon(item.presentationData.theme)
            }
            
            if displayStoryReplyIcon {
                currentStoryIcon = PresentationResourcesChatList.storyReplyIcon(item.presentationData.theme)
            }
            
            if displayGiftIcon {
                currentGiftIcon = PresentationResourcesChatList.giftIcon(item.presentationData.theme)
            }
            
            if displayLocationIcon {
                currentLocationIcon = PresentationResourcesChatList.locationIcon(item.presentationData.theme)
            }
            
            if let currentForwardedIcon {
                textLeftCutout += currentForwardedIcon.size.width
                if !contentImageSpecs.isEmpty {
                    textLeftCutout += forwardedIconSpacing
                } else {
                    textLeftCutout += contentImageTrailingSpace
                }
            }
            
            if let currentStoryIcon {
                textLeftCutout += currentStoryIcon.size.width
                if !contentImageSpecs.isEmpty {
                    textLeftCutout += forwardedIconSpacing
                } else {
                    textLeftCutout += contentImageTrailingSpace
                }
            }
            
            if let currentGiftIcon {
                textLeftCutout += currentGiftIcon.size.width
                if !contentImageSpecs.isEmpty {
                    textLeftCutout += forwardedIconSpacing
                } else {
                    textLeftCutout += contentImageTrailingSpace
                }
            }
            
            if let currentLocationIcon {
                textLeftCutout += currentLocationIcon.size.width
                if !contentImageSpecs.isEmpty {
                    textLeftCutout += forwardedIconSpacing
                } else {
                    textLeftCutout += contentImageTrailingSpace
                }
            }
            
            for i in 0 ..< contentImageSpecs.count {
                if i != 0 {
                    textLeftCutout += contentImageSpacing
                }
                textLeftCutout += contentImageSpecs[i].size.width
                if i == contentImageSpecs.count - 1 {
                    textLeftCutout += contentImageTrailingSpace
                }
            }
            
            switch contentData {
                case let .chat(itemPeer, threadInfo, _, _, _, _, _):
                    if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData {
                        if customMessageListData.commandPrefix != nil {
                            titleAttributedString = nil
                        } else {
                            if let displayTitle = itemPeer.chatOrMonoforumMainPeer?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder) {
                                let textColor: UIColor
                                if case let .chatList(index) = item.index, index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat {
                                    textColor = theme.secretTitleColor
                                } else {
                                    textColor = theme.titleColor
                                }
                                titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: textColor)
                                
                                if case let .channel(channel) = itemPeer.peer, channel.flags.contains(.isMonoforum) {
                                    titleBadgeText = item.presentationData.strings.ChatList_MonoforumLabel
                                }
                            }
                        }
                    } else if let threadInfo = threadInfo {
                        titleAttributedString = NSAttributedString(string: threadInfo.info.title, font: titleFont, textColor: theme.titleColor)
                    } else if let message = messages.last, case let .user(author) = message.author, displayAsMessage {
                        titleAttributedString = NSAttributedString(string: author.id == account.peerId ? item.presentationData.strings.DialogList_You : EnginePeer.user(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: titleFont, textColor: theme.titleColor)
                    } else if isPeerGroup {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_ArchivedChatsTitle, font: titleFont, textColor: theme.titleColor)
                    } else if itemPeer.chatMainPeer?.id == item.context.account.peerId {
                        if case .savedMessagesChats = item.chatListLocation {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_MyNotes, font: titleFont, textColor: theme.titleColor)
                        } else {
                            titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleFont, textColor: theme.titleColor)
                        }
                    } else if let id = itemPeer.chatMainPeer?.id, id.isReplies {
                         titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Replies, font: titleFont, textColor: theme.titleColor)
                    } else if let id = itemPeer.chatMainPeer?.id, id.isAnonymousSavedMessages {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_AuthorHidden, font: titleFont, textColor: theme.titleColor)
                    } else if let displayTitle = itemPeer.chatOrMonoforumMainPeer?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder) {
                        let textColor: UIColor
                        if case let .chatList(index) = item.index, index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat {
                            textColor = theme.secretTitleColor
                        } else {
                            textColor = theme.titleColor
                        }
                        if case let .channel(channel) = itemPeer.peer, channel.flags.contains(.isMonoforum) {
                            titleBadgeText = item.presentationData.strings.ChatList_MonoforumLabel
                        }
                        titleAttributedString = NSAttributedString(string: displayTitle, font: titleFont, textColor: textColor)
                    }
                case .group:
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_ArchivedChatsTitle, font: titleFont, textColor: theme.titleColor)
            }
            
            textAttributedString = attributedText
            
            let dateText: String
            var topIndex: MessageIndex?
            switch item.content {
            case .loading:
                break
            case let .groupReference(groupReferenceData):
                topIndex = groupReferenceData.message?.index
            case let .peer(peerData):
                topIndex = peerData.messages.first?.index
            }
            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, let messageCount = customMessageListData.messageCount, customMessageListData.commandPrefix == nil {
                dateText = "\(messageCount)"
            } else if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.hideDate {
                dateText = " "
            } else if let topIndex {
                var t = Int(topIndex.timestamp)
                var timeinfo = tm()
                localtime_r(&t, &timeinfo)
                
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                
                dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: topIndex.timestamp, relativeTo: timestamp, dateTimeFormat: item.presentationData.dateTimeFormat)
            } else {
                dateText = ""
            }
            
            if isPeerGroup {
                dateAttributedString = NSAttributedString(string: "", font: dateFont, textColor: theme.dateTextColor)
            } else if let promoInfo = promoInfo {
                switch promoInfo {
                case .proxy:
                    dateAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_AdLabel, font: dateFont, textColor: theme.dateTextColor)
                case let .psa(type, _):
                    var text = item.presentationData.strings.ChatList_GenericPsaLabel
                    let key = "ChatList.PsaLabel.\(type)"
                    if let string = item.presentationData.strings.primaryComponent.dict[key] {
                        text = string
                    } else if let string = item.presentationData.strings.secondaryComponent?.dict[key] {
                        text = string
                    }
                    dateAttributedString = NSAttributedString(string: text, font: dateFont, textColor: theme.dateTextColor)
                }
            } else {
                dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: theme.dateTextColor)
            }
            
            if !isPeerGroup, let message = messages.last, message.author?.id == account.peerId && !hasDraft {
                if message.flags.isSending && !message._asMessage().isSentOrAcknowledged {
                    statusState = .clock(PresentationResourcesChatList.clockFrameImage(item.presentationData.theme), PresentationResourcesChatList.clockMinImage(item.presentationData.theme))
                } else if message.id.peerId != account.peerId {
                    if hasFailedMessages {
                        statusState = .failed(item.presentationData.theme.chatList.failedFillColor, item.presentationData.theme.chatList.failedForegroundColor)
                    } else {
                        if let forumTopicData = forumTopicData {
                            if message.id.namespace == forumTopicData.maxOutgoingReadMessageId.namespace, message.id.id >= forumTopicData.maxOutgoingReadMessageId.id {
                                statusState = .read(item.presentationData.theme.chatList.checkmarkColor)
                            } else {
                                statusState = .delivered(item.presentationData.theme.chatList.checkmarkColor)
                            }
                        } else {
                            if let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIndexRead(message.index) {
                                statusState = .read(item.presentationData.theme.chatList.checkmarkColor)
                            } else {
                                statusState = .delivered(item.presentationData.theme.chatList.checkmarkColor)
                            }
                        }
                    }
                }
            }
            
            if unreadCount.unread {
                if !isPeerGroup, let message = messages.last, message.tags.contains(.unseenPersonalMessage), unreadCount.count == 1 {
                } else {
                    let badgeTextColor: UIColor
                    if unreadCount.muted {
                        if unreadCount.isProvisonal, case .forum = item.chatListLocation {
                            badgeTextColor = theme.unreadBadgeInactiveBackgroundColor
                            currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactiveProvisional(item.presentationData.theme, diameter: badgeDiameter)
                            currentAvatarBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactiveProvisional(item.presentationData.theme, diameter: avatarBadgeDiameter)
                        } else {
                            badgeTextColor = theme.unreadBadgeInactiveTextColor
                            currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: badgeDiameter)
                            currentAvatarBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: avatarBadgeDiameter)
                        }
                    } else {
                        if unreadCount.isProvisonal, case .forum = item.chatListLocation {
                            badgeTextColor = theme.unreadBadgeActiveBackgroundColor
                            currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActiveProvisional(item.presentationData.theme, diameter: badgeDiameter)
                            currentAvatarBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActiveProvisional(item.presentationData.theme, diameter: avatarBadgeDiameter)
                        } else {
                            badgeTextColor = theme.unreadBadgeActiveTextColor
                            currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: badgeDiameter)
                            currentAvatarBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: avatarBadgeDiameter)
                        }
                    }
                    let unreadCountText = compactNumericCountString(Int(unreadCount.count), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                    if unreadCount.count > 0 {
                        badgeContent = .text(NSAttributedString(string: unreadCountText, font: badgeFont, textColor: badgeTextColor))
                    } else if isPeerGroup {
                        badgeContent = .none
                    } else {
                        badgeContent = .blank
                    }
                    
                    if let mutedCount = unreadCount.mutedCount, mutedCount > 0 {
                        let mutedUnreadCountText = compactNumericCountString(Int(mutedCount), decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator)
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: badgeDiameter)
                        mentionBadgeContent = .text(NSAttributedString(string: mutedUnreadCountText, font: badgeFont, textColor: theme.unreadBadgeInactiveTextColor))
                    }
                }
            }

            if !isPeerGroup {
                if hasUnseenMentions {
                    if case .chatList(.archive) = item.chatListLocation {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundInactiveMention(item.presentationData.theme, diameter: badgeDiameter)
                    } else {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundMention(item.presentationData.theme, diameter: badgeDiameter)
                    }
                    mentionBadgeContent = .mention
                } else if hasUnseenReactions {
                    if isRemovedFromTotalUnreadCount {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundInactiveReactions(item.presentationData.theme, diameter: badgeDiameter)
                    } else {
                        currentMentionBadgeImage = PresentationResourcesChatList.badgeBackgroundReactions(item.presentationData.theme, diameter: badgeDiameter)
                    }
                    mentionBadgeContent = .mention
                } else if item.isPinned, promoInfo == nil, currentBadgeBackgroundImage == nil {
                    currentPinnedIconImage = PresentationResourcesChatList.badgeBackgroundPinned(item.presentationData.theme, diameter: badgeDiameter)
                }
            }
            
            let isMuted = isRemovedFromTotalUnreadCount
            if isMuted {
                currentMutedIconImage = PresentationResourcesChatList.mutedIcon(item.presentationData.theme)
            }
            
            var statusWidth: CGFloat
            if case .none = statusState {
                statusWidth = 0.0
            } else {
                statusWidth = 24.0
            }
            
            var dateIconImage: UIImage?
            if let threadInfo, threadInfo.isClosed {
                dateIconImage = PresentationResourcesChatList.statusLockIcon(item.presentationData.theme)
            }
            
            if let dateIconImage {
                statusWidth += dateIconImage.size.width + 4.0
            }
            
            var titleIconsWidth: CGFloat = 0.0
            if let currentMutedIconImage = currentMutedIconImage {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                }
                titleIconsWidth += currentMutedIconImage.size.width
            }
    
            var isSubscription = false
            var isSecret = false
            if !isPeerGroup {
                if case let .chatList(index) = item.index, index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat {
                    isSecret = true
                }
            }
            if isSecret {
                currentSecretIconImage = PresentationResourcesChatList.secretIcon(item.presentationData.theme)
            }
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: item.context.currentAppConfiguration.with { $0 })
            var isAccountPeer = false
            if case let .chatList(index) = item.index, index.messageIndex.id.peerId == item.context.account.peerId {
                isAccountPeer = true
            }
            
            if !isPeerGroup && !isAccountPeer && threadInfo == nil {
                if displayAsMessage {
                    switch item.content {
                    case let .peer(peerData):
                        if let peer = peerData.messages.last?.author {
                            if case let .peer(peerData) = item.content, peerData.customMessageListData != nil {
                                currentCredibilityIconContent = nil
                            } else if case .savedMessagesChats = item.chatListLocation, peer.id == item.context.account.peerId {
                                currentCredibilityIconContent = nil
                            } else if peer.isScam {
                                currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                            } else if peer.isFake {
                                currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                            } else if let emojiStatus = peer.emojiStatus {
                                currentStatusIconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                                if let color = emojiStatus.color {
                                    currentStatusIconParticleColor = UIColor(rgb: UInt32(bitPattern: color))
                                }
                            } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                                currentCredibilityIconContent = .premium(color: item.presentationData.theme.list.itemAccentColor)
                            }
                            
                            if peer.isVerified {
                                currentCredibilityIconContent = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                            }
                            if let verificationIconFileId = peer.verificationIconFileId {
                                currentVerifiedIconContent = .animation(content: .customEmoji(fileId: verificationIconFileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0))
                            }
                        }
                    default:
                        break
                    }
                } else if case let .chat(itemPeer) = contentPeer, let peer = itemPeer.chatOrMonoforumMainPeer {
                    if peer.isSubscription {
                        isSubscription = true
                    }
                    if case let .peer(peerData) = item.content, peerData.customMessageListData?.hidePeerStatus == true {
                        currentCredibilityIconContent = nil
                    } else if case let .savedMessagesChats(peerId) = item.chatListLocation, peer.id == peerId {
                        currentCredibilityIconContent = nil
                    } else if peer.isScam {
                        currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                    } else if peer.isFake {
                        currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                    } else if let emojiStatus = peer.emojiStatus {
                        currentStatusIconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                        if let color = emojiStatus.color {
                            currentStatusIconParticleColor = UIColor(rgb: UInt32(bitPattern: color))
                        }
                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                        currentCredibilityIconContent = .premium(color: item.presentationData.theme.list.itemAccentColor)
                    }
                    
                    if peer.isVerified {
                        currentCredibilityIconContent = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                    }
                    if let verificationIconFileId = peer.verificationIconFileId {
                        currentVerifiedIconContent = .animation(content: .customEmoji(fileId: verificationIconFileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0))
                    }
                }
            }
            if let currentSecretIconImage = currentSecretIconImage {
                titleIconsWidth += currentSecretIconImage.size.width + 2.0
            }
            
            var titleLeftOffset: CGFloat = 0.0
            if let currentVerifiedIconContent {
                if titleLeftOffset.isZero, case .animation = currentVerifiedIconContent {
                    titleLeftOffset += 19.0
                }
                
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                } else {
                    titleIconsWidth += 2.0
                }
                switch currentVerifiedIconContent {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    titleIconsWidth += floor(stringRect.width) + 11.0
                default:
                    titleIconsWidth += 8.0
                }
            }
            
            if let currentCredibilityIconContent {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                } else {
                    titleIconsWidth += 2.0
                }
                switch currentCredibilityIconContent {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    titleIconsWidth += floor(stringRect.width) + 11.0
                default:
                    titleIconsWidth += 8.0
                }
            }
            
            if let currentStatusIconContent {
                if titleIconsWidth.isZero {
                    titleIconsWidth += 4.0
                } else {
                    titleIconsWidth += 2.0
                }
                switch currentStatusIconContent {
                case let .text(_, string):
                    let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                    let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                    titleIconsWidth += floor(stringRect.width) + 11.0
                default:
                    titleIconsWidth += 8.0
                }
            }
            
            let layoutOffset: CGFloat = 0.0
            
            let rawContentWidth = params.width - leftInset - params.rightInset - 10.0 - editingOffset
            
            let (dateLayout, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (badgeLayout, badgeApply) = badgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentBadgeBackgroundImage, badgeContent)
            
            let (mentionBadgeLayout, mentionBadgeApply) = mentionBadgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentMentionBadgeImage, mentionBadgeContent)
            
            var actionButtonTitleNodeLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if case .none = badgeContent, case .none = mentionBadgeContent, case let .chat(itemPeer) = contentPeer, case let .user(user) = itemPeer.chatMainPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                actionButtonTitleNodeLayoutAndApply = makeActionButtonTitleNodeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.ChatList_InlineButtonOpenApp, font: Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0)), textColor: theme.unreadBadgeActiveTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            var badgeSize: CGFloat = 0.0
            if !badgeLayout.width.isZero {
                badgeSize += badgeLayout.width + 5.0
            }
            if !mentionBadgeLayout.width.isZero {
                if !badgeSize.isZero {
                    badgeSize += mentionBadgeLayout.width + 4.0
                } else {
                    badgeSize += mentionBadgeLayout.width + 5.0
                }
            }
            let countersSize = badgeSize
            if let currentPinnedIconImage = currentPinnedIconImage {
                if !badgeSize.isZero {
                    badgeSize += 4.0
                } else {
                    badgeSize += 5.0
                }
                badgeSize += currentPinnedIconImage.size.width
            }
            if let (actionButtonTitleNodeLayout, _) = actionButtonTitleNodeLayoutAndApply {
                if !badgeSize.isZero {
                    badgeSize += 4.0
                } else {
                    badgeSize += 5.0
                }
                badgeSize += actionButtonTitleNodeLayout.size.width + 12.0 * 2.0
            }
            badgeSize = max(badgeSize, reorderInset)
            
            if !itemTags.isEmpty {
                authorAttributedString = nil
            }
            
            var effectiveAuthorTitle = (hideAuthor && !hasDraft) ? nil : authorAttributedString
            
            let isSearching = item.interaction.searchTextHighightState != nil
            
            var isFirstForumThreadSelectable = false
            var forumThreads: [(id: Int64, threadPeer: EnginePeer?, title: NSAttributedString, iconId: Int64?, iconColor: Int32?)] = []
            if case .savedMessagesChats = item.chatListLocation {
            } else if case let .peer(peer) = item.content, case let .channel(channel) = peer.peer.peer, channel.flags.contains(.isMonoforum) {
                if forumThread != nil || !topForumTopicItems.isEmpty {
                    if let forumThread {
                        isFirstForumThreadSelectable = false
                        forumThreads.append((id: forumThread.id, threadPeer: forumThread.threadPeer, title: NSAttributedString(string: forumThread.threadPeer?.compactDisplayTitle ?? " ", font: textFont, textColor: forumThread.isUnread || isSearching ? theme.authorNameColor : theme.messageTextColor), iconId: nil, iconColor: nil))
                    }
                    for topicItem in topForumTopicItems {
                        if forumThread?.id != topicItem.id {
                            forumThreads.append((id: topicItem.id, threadPeer: topicItem.threadPeer, title: NSAttributedString(string: topicItem.threadPeer?.compactDisplayTitle ?? " ", font: textFont, textColor: topicItem.isUnread || isSearching ? theme.authorNameColor : theme.messageTextColor), iconId: nil, iconColor: nil))
                        }
                    }
                    
                    if let effectiveAuthorTitle, let textAttributedStringValue = textAttributedString {
                        let mutableTextAttributedString = NSMutableAttributedString()
                        mutableTextAttributedString.append(NSAttributedString(string: effectiveAuthorTitle.string + ": ", font: textFont, textColor: theme.authorNameColor))
                        mutableTextAttributedString.append(textAttributedStringValue)
                        
                        textAttributedString = mutableTextAttributedString
                    }
                    
                    effectiveAuthorTitle = nil
                }
            } else if forumThread != nil || !topForumTopicItems.isEmpty {
                if let forumThread = forumThread {
                    isFirstForumThreadSelectable = forumThread.isUnread
                    forumThreads.append((id: forumThread.id, threadPeer: forumThread.threadPeer, title: NSAttributedString(string: forumThread.title, font: textFont, textColor: forumThread.isUnread || isSearching ? theme.authorNameColor : theme.messageTextColor), iconId: forumThread.iconId, iconColor: forumThread.iconColor))
                }
                for topicItem in topForumTopicItems {
                    if case let .peer(peer) = item.content, peer.peer.peerId.id._internalGetInt64Value() == topicItem.id {
                        
                    } else if forumThread?.id != topicItem.id {
                        forumThreads.append((id: topicItem.id, threadPeer: topicItem.threadPeer, title: NSAttributedString(string: topicItem.title, font: textFont, textColor: topicItem.isUnread || isSearching ? theme.authorNameColor : theme.messageTextColor), iconId: topicItem.iconFileId, iconColor: topicItem.iconColor))
                    }
                }
                
                if let effectiveAuthorTitle, let textAttributedStringValue = textAttributedString {
                    let mutableTextAttributedString = NSMutableAttributedString()
                    mutableTextAttributedString.append(NSAttributedString(string: effectiveAuthorTitle.string + ": ", font: textFont, textColor: theme.authorNameColor))
                    mutableTextAttributedString.append(textAttributedStringValue)
                    
                    textAttributedString = mutableTextAttributedString
                }
                
                effectiveAuthorTitle = nil
            }
            
            if authorIsCurrentChat {
                effectiveAuthorTitle = nil
            }
            
            let (authorLayout, authorApply) = authorLayout(item.context, rawContentWidth - badgeSize, item.presentationData.theme, effectiveAuthorTitle, forumThreads)
            
            var textBottomRightCutout: CGFloat = 0.0
            
            let trailingTextBadgeInsets = UIEdgeInsets(top: 2.0 - UIScreenPixel, left: 5.0, bottom: 2.0 - UIScreenPixel, right: 5.0)
            var trailingTextBadgeLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil, let messageCount = customMessageListData.messageCount, messageCount > 1 {
                let trailingText: String
                trailingText = item.presentationData.strings.ChatList_ItemMoreMessagesFormat(Int32(messageCount - 1))
                let trailingAttributedText = NSAttributedString(string: trailingText, font: Font.regular(12.0), textColor: theme.messageTextColor)
                let (layout, apply) = makeTrailingTextBadgeLayout(TextNodeLayoutArguments(attributedString: trailingAttributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                trailingTextBadgeLayoutAndApply = (layout, apply)
                textBottomRightCutout += layout.size.width + 4.0 + trailingTextBadgeInsets.left + trailingTextBadgeInsets.right
            }
            
            var textCutout: TextNodeCutout?
            if !textLeftCutout.isZero || !textBottomRightCutout.isZero {
                textCutout = TextNodeCutout(topLeft: textLeftCutout.isZero ? nil : CGSize(width: textLeftCutout, height: 10.0), topRight: nil, bottomRight: textBottomRightCutout.isZero ? nil : CGSize(width: textBottomRightCutout, height: 10.0))
            }
            
            var textMaxWidth = rawContentWidth - badgeSize
            
            var textArrowImage: UIImage?
            if isFirstForumThreadSelectable {
                textArrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
                textMaxWidth -= 18.0
            }
            
            let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: textAttributedString, backgroundColor: nil, maximumNumberOfLines: (authorAttributedString == nil && itemTags.isEmpty) ? 2 : 1, truncationType: .end, constrainedSize: CGSize(width: textMaxWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: textCutout, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            let maxTitleLines: Int
            switch item.index {
            case .forum:
                maxTitleLines = 2
            case .chatList:
                maxTitleLines = 1
            }
            
            var titleLeftCutout: CGFloat = 0.0
            if item.interaction.isInlineMode {
                titleLeftCutout = 22.0
            }
            
            if let titleAttributedStringValue = titleAttributedString, titleAttributedStringValue.length == 0 {
                titleAttributedString = NSAttributedString(string: " ", font: titleFont, textColor: theme.titleColor)
            }
                        
            var titleRectWidth = rawContentWidth - dateLayout.size.width - 10.0 - statusWidth - titleIconsWidth
            var titleCutout: TextNodeCutout?
            if !titleLeftCutout.isZero {
                titleCutout = TextNodeCutout(topLeft: CGSize(width: titleLeftCutout, height: 10.0), topRight: nil, bottomRight: nil)
            }
            
            var titleBadgeLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let titleBadgeText {
                let titleBadgeLayoutAndApplyValue = titleBadgeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: titleBadgeText, font: Font.semibold(11.0), textColor: theme.titleColor.withMultipliedAlpha(0.4)), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                titleBadgeLayoutAndApply = titleBadgeLayoutAndApplyValue
                titleRectWidth = max(10.0, titleRectWidth - titleBadgeLayoutAndApplyValue.0.size.width - 8.0)
            }
            
            let (titleLayout, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: maxTitleLines, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: titleCutout, insets: UIEdgeInsets()))
        
            var inputActivitiesSize: CGSize?
            var inputActivitiesApply: (() -> Void)?
            var chatPeerId: EnginePeer.Id?
            if case let .chatList(index) = item.index {
                chatPeerId = index.messageIndex.id.peerId
            } else if case let .forum(peerId) = item.chatListLocation {
                chatPeerId = peerId
            }
            if let inputActivities = inputActivities, !inputActivities.isEmpty, let chatPeerId {
                let (size, apply) = inputActivitiesLayout(CGSize(width: rawContentWidth - badgeSize, height: 40.0), item.presentationData, item.presentationData.theme.chatList.messageTextColor, chatPeerId, inputActivities)
                inputActivitiesSize = size
                inputActivitiesApply = apply
            } else {
                let (size, apply) = inputActivitiesLayout(CGSize(width: rawContentWidth - badgeSize, height: 40.0), item.presentationData, item.presentationData.theme.chatList.messageTextColor, nil, [])
                inputActivitiesSize = size
                inputActivitiesApply = apply
            }
            
            var online = false
            var animateOnline = false
            var onlineIsVoiceChat = false
            
            var isPinned = false
            if case let .chatList(index) = item.index {
                isPinned = index.pinningIndex != nil
            } else if case let .forum(pinnedIndex, _, _, _, _) = item.index {
                if case .index = pinnedIndex {
                    isPinned = true
                }
            }

            var peerRevealOptions: [ItemListRevealOption]
            var peerLeftRevealOptions: [ItemListRevealOption]
            switch item.content {
                case .loading:
                    peerRevealOptions = []
                    peerLeftRevealOptions = []
                case let .peer(peerData):
                    let renderedPeer = peerData.peer
                    let presence = peerData.presence
                    let displayAsMessage = peerData.displayAsMessage
                
                    if !displayAsMessage {
                        if case let .user(peer) = renderedPeer.chatMainPeer, let presence = presence, !isServicePeer(peer) && !peer.flags.contains(.isSupport) && peer.id != item.context.account.peerId {
                            let updatedPresence = EnginePeer.Presence(status: presence.status, lastActivity: 0)
                            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                            let relativeStatus = relativeUserPresenceStatus(updatedPresence, relativeTo: timestamp)
                            if case .online = relativeStatus {
                                online = true
                            }
                            animateOnline = true
                        } else if case let .channel(channel) = renderedPeer.peer, case .chatList = item.index {
                            onlineIsVoiceChat = true
                            if channel.flags.contains(.hasActiveVoiceChat) && item.interaction.searchTextHighightState == nil {
                                online = true
                            }
                            animateOnline = true
                        } else if case let .legacyGroup(group) = renderedPeer.peer, case .chatList = item.index {
                            onlineIsVoiceChat = true
                            if group.flags.contains(.hasActiveVoiceChat) && item.interaction.searchTextHighightState == nil {
                                online = true
                            }
                            animateOnline = true
                        }
                    }
                    
                    if let enabledContextActions = item.enabledContextActions {
                        switch enabledContextActions {
                        case .auto:
                            if case .forum = item.chatListLocation {
                                if case let .chat(itemPeer) = contentPeer, case let .channel(channel) = itemPeer.peer {
                                    var canOpenClose = false
                                    if channel.flags.contains(.isCreator) {
                                        canOpenClose = true
                                    } else if channel.hasPermission(.manageTopics) {
                                        canOpenClose = true
                                    } else if let threadInfo = threadInfo, threadInfo.isOwnedByMe {
                                        canOpenClose = true
                                    }
                                    let canDelete = channel.hasPermission(.deleteAllMessages)
                                    var isClosed = false
                                    if let threadInfo {
                                        isClosed = threadInfo.isClosed
                                    }
                                    if let threadInfo, threadInfo.id == 1 {
                                        peerRevealOptions = forumGeneralRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isMuted: (currentMutedIconImage != nil), isClosed: isClosed, isEditing: item.editing, canOpenClose: canOpenClose, canHide: channel.flags.contains(.isCreator) || channel.hasPermission(.manageTopics), hiddenByDefault: threadInfo.isHidden)
                                    } else {
                                        peerRevealOptions = forumThreadRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isMuted: (currentMutedIconImage != nil), isClosed: isClosed, isEditing: item.editing, canOpenClose: canOpenClose, canDelete: canDelete)
                                    }
                                    peerLeftRevealOptions = []
                                } else {
                                    peerRevealOptions = []
                                    peerLeftRevealOptions = []
                                }
                            } else if case .psa = promoInfo {
                                peerRevealOptions = [
                                    ItemListRevealOption(key: RevealOptionKey.hidePsa.rawValue, title: item.presentationData.strings.ChatList_HideAction, icon: deleteIcon, color: item.presentationData.theme.list.itemDisclosureActions.inactive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.neutral1.foregroundColor)
                                ]
                                peerLeftRevealOptions = []
                            } else if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData {
                                peerLeftRevealOptions = []
                                if customMessageListData.commandPrefix != nil {
                                    peerRevealOptions = [
                                        ItemListRevealOption(key: RevealOptionKey.edit.rawValue, title: item.presentationData.strings.ChatList_ItemMenuEdit, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.neutral2.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.neutral2.foregroundColor),
                                        ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.presentationData.strings.ChatList_ItemMenuDelete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)
                                    ]
                                } else {
                                    peerRevealOptions = []
                                }
                            } else if promoInfo == nil {
                                peerRevealOptions = revealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isPinned: isPinned, isMuted: !isAccountPeer ? (currentMutedIconImage != nil) : nil, location: item.chatListLocation, peerId: renderedPeer.peerId, accountPeerId: item.context.account.peerId, canDelete: true, isEditing: item.editing, filterData: item.filterData)
                                if case let .chat(itemPeer) = contentPeer {
                                    peerLeftRevealOptions = leftRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isUnread: unreadCount.unread, isEditing: item.editing, isPinned: isPinned, isSavedMessages: itemPeer.peerId == item.context.account.peerId, location: item.chatListLocation, peer: itemPeer.peers[itemPeer.peerId]!, filterData: item.filterData)
                                } else {
                                    peerLeftRevealOptions = []
                                }
                            } else {
                                peerRevealOptions = []
                                peerLeftRevealOptions = []
                            }
                        case let .custom(actions):
                            peerRevealOptions = []
                            peerLeftRevealOptions = []
                            
                            if actions.contains(.toggleUnread) {
                                if unreadCount.unread {
                                    peerLeftRevealOptions.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: item.presentationData.strings.DialogList_Read, icon: readIcon, color: item.presentationData.theme.list.itemDisclosureActions.inactive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.neutral1.foregroundColor))
                                } else {
                                    peerLeftRevealOptions.append(ItemListRevealOption(key: RevealOptionKey.toggleMarkedUnread.rawValue, title: item.presentationData.strings.DialogList_Unread, icon: unreadIcon, color: item.presentationData.theme.list.itemDisclosureActions.accent.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.accent.foregroundColor))
                                }
                            }
                            if actions.contains(.delete) {
                                peerRevealOptions.append(ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.presentationData.strings.Common_Delete, icon: deleteIcon, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor))
                            }
                        }
                    } else {
                        peerRevealOptions = []
                        peerLeftRevealOptions = []
                    }
                case .groupReference:
                    peerRevealOptions = groupReferenceRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isEditing: item.editing, hiddenByDefault: groupHiddenByDefault)
                    peerLeftRevealOptions = []
            }
            
            if item.interaction.inlineNavigationLocation != nil {
                peerRevealOptions = []
                peerLeftRevealOptions = []
            }
            
            let (onlineLayout, onlineApply) = onlineLayout(online, onlineIsVoiceChat)
            var animateContent = false
            if let currentItem = currentItem, currentItem.content.chatLocation == item.content.chatLocation {
                animateContent = true
            }
            
            let (measureLayout, measureApply) = makeMeasureLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: " ", font: titleFont, textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = -1.0
            let authorSpacing: CGFloat = -3.0
            var itemHeight: CGFloat = 8.0 * 2.0 + 1.0
            itemHeight -= 21.0
            if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.commandPrefix != nil {
                itemHeight += measureLayout.size.height * 2.0
                itemHeight += 20.0
            } else {
                itemHeight += titleLayout.size.height
                itemHeight += measureLayout.size.height * 3.0
                itemHeight += titleSpacing
                itemHeight += authorSpacing
            }
                        
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: layoutOffset + floor(item.presentationData.fontSize.itemListBaseFontSize * 8.0 / 17.0)), size: CGSize(width: rawContentWidth, height: itemHeight - 12.0 - 9.0))
            
            let insets = ChatListItemNode.insets(first: first, last: last, firstWithHeader: firstWithHeader)
            var heightOffset: CGFloat = 0.0
            if item.hiddenOffset {
                heightOffset = -itemHeight
            }
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: max(0.0, itemHeight + heightOffset)), insets: insets)
            
            var customActions: [ChatListItemAccessibilityCustomAction] = []
            for option in peerLeftRevealOptions {
                customActions.append(ChatListItemAccessibilityCustomAction(name: option.title, target: nil, selector: #selector(ChatListItemNode.performLocalAccessibilityCustomAction(_:)), key: option.key))
            }
            for option in peerRevealOptions {
                customActions.append(ChatListItemAccessibilityCustomAction(name: option.title, target: nil, selector: #selector(ChatListItemNode.performLocalAccessibilityCustomAction(_:)), key: option.key))
            }
            
            return (layout, { [weak self] synchronousLoads, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, first, last, firstWithHeader, nextIsPinned, params, countersSize)
                    strongSelf.currentItemHeight = itemHeight
                    strongSelf.cachedChatListText = chatListText
                    strongSelf.cachedChatListSearchResult = chatListSearchResult
                    strongSelf.cachedChatListQuoteSearchResult = chatListQuoteSearchResult
                    strongSelf.cachedCustomTextEntities = customTextEntities
                    strongSelf.onlineIsVoiceChat = onlineIsVoiceChat
                    
                    var animateOnline = animateOnline
                    if let currentOnline = strongSelf.currentOnline, currentOnline == online {
                        animateOnline = false
                    }
                    strongSelf.currentOnline = online
                    
                    if item.hiddenOffset {
                        strongSelf.layer.zPosition = -1.0
                    }
                                       
                    if case .groupReference = item.content {
                        strongSelf.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, layout.contentSize.height - itemHeight, 0.0)
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.presentationData.theme.chatList.itemSeparatorColor
                    }
                    
                    let revealOffset = 0.0
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    let contextContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: itemHeight))
//                    strongSelf.contextContainer.position = contextContainerFrame.center
                    transition.updatePosition(node: strongSelf.contextContainer, position: contextContainerFrame.center)
                    transition.updateBounds(node: strongSelf.contextContainer, bounds: contextContainerFrame.offsetBy(dx: -strongSelf.revealOffset, dy: 0.0))
                    
                    var mainContentFrame: CGRect
                    var mainContentBoundsOffset: CGFloat
                    var mainContentAlpha: CGFloat = 1.0
                    
                    if useChatListLayout {
                        mainContentFrame = CGRect(origin: CGPoint(x: leftInset - 2.0, y: 0.0), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height))
                        mainContentBoundsOffset = mainContentFrame.origin.x
                        
                        if let inlineNavigationLocation = item.interaction.inlineNavigationLocation {
                            mainContentAlpha = 1.0 - inlineNavigationLocation.progress
                            mainContentBoundsOffset += (mainContentFrame.width - mainContentFrame.minX) * inlineNavigationLocation.progress
                        }
                    } else {
                        mainContentFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height))
                        mainContentBoundsOffset = 0.0
                    }
                    
                    transition.updatePosition(node: strongSelf.mainContentContainerNode, position: mainContentFrame.center)
                    
                    transition.updateBounds(node: strongSelf.mainContentContainerNode, bounds: CGRect(origin: CGPoint(x: mainContentBoundsOffset, y: 0.0), size: mainContentFrame.size))
                    transition.updateAlpha(node: strongSelf.mainContentContainerNode, alpha: mainContentAlpha)
                    
                    var crossfadeContent = false
                    if let selectableControlSizeAndApply = selectableControlSizeAndApply {
                        let selectableControlSize = CGSize(width: selectableControlSizeAndApply.0, height: layout.contentSize.height)
                        let selectableControlFrame = CGRect(origin: CGPoint(x: params.leftInset + revealOffset, y: layoutOffset), size: selectableControlSize)
                        if strongSelf.selectableControlNode == nil {
                            crossfadeContent = true
                            let selectableControlNode = selectableControlSizeAndApply.1(selectableControlSize, false)
                            strongSelf.selectableControlNode = selectableControlNode
                            strongSelf.addSubnode(selectableControlNode)
                            selectableControlNode.frame = selectableControlFrame
                            transition.animatePosition(node: selectableControlNode, from: CGPoint(x: -selectableControlFrame.size.width / 2.0, y: layoutOffset + selectableControlFrame.midY))
                            selectableControlNode.alpha = 0.0
                            transition.updateAlpha(node: selectableControlNode, alpha: 1.0)
                        } else if let selectableControlNode = strongSelf.selectableControlNode {
                            transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
                            let _ = selectableControlSizeAndApply.1(selectableControlSize, transition.isAnimated)
                        }
                    } else if let selectableControlNode = strongSelf.selectableControlNode {
                        crossfadeContent = true
                        var selectableControlFrame = selectableControlNode.frame
                        selectableControlFrame.origin.x = -selectableControlFrame.size.width
                        strongSelf.selectableControlNode = nil
                        transition.updateAlpha(node: selectableControlNode, alpha: 0.0)
                        transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame, completion: { [weak selectableControlNode] _ in
                            selectableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    var animateBadges = animateContent
                    if let reorderControlSizeAndApply = reorderControlSizeAndApply {
                        let reorderControlFrame = CGRect(origin: CGPoint(x: params.width + revealOffset - params.rightInset - reorderControlSizeAndApply.0, y: layoutOffset), size: CGSize(width: reorderControlSizeAndApply.0, height: layout.contentSize.height))
                        if strongSelf.reorderControlNode == nil {
                            let reorderControlNode = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            strongSelf.reorderControlNode = reorderControlNode
                            strongSelf.addSubnode(reorderControlNode)
                            reorderControlNode.frame = reorderControlFrame
                            reorderControlNode.alpha = 0.0
                            transition.updateAlpha(node: reorderControlNode, alpha: 1.0)
                            
                            transition.updateAlpha(node: strongSelf.dateNode, alpha: 0.0)
                            if let dateStatusIconNode = strongSelf.dateStatusIconNode {
                                transition.updateAlpha(node: dateStatusIconNode, alpha: 0.0)
                            }
                            transition.updateAlpha(node: strongSelf.badgeNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.pinnedIconNode, alpha: 0.0)
                            transition.updateAlpha(node: strongSelf.statusNode, alpha: 0.0)
                        } else if let reorderControlNode = strongSelf.reorderControlNode {
                            let _ = reorderControlSizeAndApply.1(layout.contentSize.height, false, .immediate)
                            transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
                        }
                    } else if let reorderControlNode = strongSelf.reorderControlNode {
                        animateBadges = false
                        strongSelf.reorderControlNode = nil
                        transition.updateAlpha(node: reorderControlNode, alpha: 0.0, completion: { [weak reorderControlNode] _ in
                            reorderControlNode?.removeFromSupernode()
                        })
                        transition.updateAlpha(node: strongSelf.dateNode, alpha: 1.0)
                        if let dateStatusIconNode = strongSelf.dateStatusIconNode {
                            transition.updateAlpha(node: dateStatusIconNode, alpha: 1.0)
                        }
                        transition.updateAlpha(node: strongSelf.badgeNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.mentionBadgeNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.pinnedIconNode, alpha: 1.0)
                        transition.updateAlpha(node: strongSelf.statusNode, alpha: 1.0)
                    }
                    
                    let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + revealOffset, dy: 0.0)
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: leftInset - avatarLeftInset + editingOffset + 10.0 + revealOffset, y: floor((itemHeight - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
                    var avatarScaleOffset: CGFloat = 0.0
                    var avatarScale: CGFloat = 1.0
                    if let inlineNavigationLocation = item.interaction.inlineNavigationLocation {
                        let targetAvatarScale: CGFloat = floor(item.presentationData.fontSize.itemListBaseFontSize * 54.0 / 17.0) / avatarFrame.width
                        avatarScale = targetAvatarScale * inlineNavigationLocation.progress + 1.0 * (1.0 - inlineNavigationLocation.progress)
                        
                        let targetAvatarScaleOffset: CGFloat = -(avatarFrame.width - avatarFrame.width * avatarScale) * 0.5
                        avatarScaleOffset = targetAvatarScaleOffset * inlineNavigationLocation.progress
                    }
                    
                    transition.updateFrame(node: strongSelf.avatarContainerNode, frame: avatarFrame)
                    transition.updatePosition(node: strongSelf.avatarNode, position: avatarFrame.offsetBy(dx: -avatarFrame.minX, dy: -avatarFrame.minY).center.offsetBy(dx: avatarScaleOffset, dy: 0.0))
                    transition.updateBounds(node: strongSelf.avatarNode, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                    transition.updateTransformScale(node: strongSelf.avatarNode, scale: avatarScale)
                    strongSelf.avatarNode.updateSize(size: avatarFrame.size)
                    strongSelf.updateVideoVisibility()
                    
                    var itemPeerId: EnginePeer.Id?
                    if case let .chatList(index) = item.index {
                        itemPeerId = index.messageIndex.id.peerId
                    }
                    
                    if let itemPeerId = itemPeerId, let inlineNavigationLocation = item.interaction.inlineNavigationLocation, inlineNavigationLocation.location.peerId == itemPeerId {
                        let inlineNavigationMarkLayer: SimpleLayer
                        var animateIn = false
                        if let current = strongSelf.inlineNavigationMarkLayer {
                            inlineNavigationMarkLayer = current
                        } else {
                            inlineNavigationMarkLayer = SimpleLayer()
                            strongSelf.inlineNavigationMarkLayer = inlineNavigationMarkLayer
                            inlineNavigationMarkLayer.cornerRadius = 4.0
                            animateIn = true
                            strongSelf.layer.addSublayer(inlineNavigationMarkLayer)
                        }
                        inlineNavigationMarkLayer.backgroundColor = item.presentationData.theme.list.itemAccentColor.cgColor
                        let markHeight: CGFloat = 50.0
                        var markFrame = CGRect(origin: CGPoint(x: -4.0, y: avatarFrame.midY - markHeight * 0.5), size: CGSize(width: 8.0, height: markHeight))
                        markFrame.origin.x -= (1.0 - inlineNavigationLocation.progress) * markFrame.width * 0.5
                        if animateIn {
                            inlineNavigationMarkLayer.frame = markFrame
                            transition.animatePositionAdditive(layer: inlineNavigationMarkLayer, offset: CGPoint(x: -markFrame.width * 0.5, y: 0.0))
                        } else {
                            transition.updateFrame(layer: inlineNavigationMarkLayer, frame: markFrame)
                        }
                    } else {
                        if let inlineNavigationMarkLayer = strongSelf.inlineNavigationMarkLayer {
                            strongSelf.inlineNavigationMarkLayer = nil
                            transition.updatePosition(layer: inlineNavigationMarkLayer, position: CGPoint(x: -inlineNavigationMarkLayer.bounds.width * 0.5, y: avatarFrame.midY))
                        }
                    }
                    
                    if let inlineNavigationLocation = item.interaction.inlineNavigationLocation, badgeContent != .none {
                        var animateIn = false
                        
                        let avatarBadgeBackground: ASImageNode
                        if let current = strongSelf.avatarBadgeBackground {
                            avatarBadgeBackground = current
                        } else {
                            avatarBadgeBackground = ASImageNode()
                            strongSelf.avatarBadgeBackground = avatarBadgeBackground
                            strongSelf.avatarNode.addSubnode(avatarBadgeBackground)
                        }
                        
                        avatarBadgeBackground.image = currentAvatarBadgeCleanBackgroundImage
                        
                        let avatarBadgeNode: ChatListBadgeNode
                        if let current = strongSelf.avatarBadgeNode {
                            avatarBadgeNode = current
                        } else {
                            animateIn = true
                            avatarBadgeNode = ChatListBadgeNode()
                            avatarBadgeNode.disableBounce = true
                            strongSelf.avatarBadgeNode = avatarBadgeNode
                            strongSelf.avatarNode.addSubnode(avatarBadgeNode)
                        }
                        
                        let makeAvatarBadgeLayout = avatarBadgeNode.asyncLayout()
                        let (avatarBadgeLayout, avatarBadgeApply) = makeAvatarBadgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), avatarBadgeDiameter, avatarBadgeFont, currentAvatarBadgeBackgroundImage, badgeContent)
                        let _ = avatarBadgeApply(animateBadges, false)
                        let avatarBadgeFrame = CGRect(origin: CGPoint(x: avatarFrame.width - avatarBadgeLayout.width, y: avatarFrame.height - avatarBadgeLayout.height), size: avatarBadgeLayout)
                        avatarBadgeNode.position = avatarBadgeFrame.center
                        avatarBadgeNode.bounds = CGRect(origin: CGPoint(), size: avatarBadgeFrame.size)
                        
                        let avatarBadgeBackgroundFrame = avatarBadgeFrame.insetBy(dx: -2.0, dy: -2.0)
                        avatarBadgeBackground.position = avatarBadgeBackgroundFrame.center
                        avatarBadgeBackground.bounds = CGRect(origin: CGPoint(), size: avatarBadgeBackgroundFrame.size)
                        
                        if animateIn {
                            ContainedViewLayoutTransition.immediate.updateSublayerTransformScale(node: avatarBadgeNode, scale: 0.00001)
                            ContainedViewLayoutTransition.immediate.updateTransformScale(layer: avatarBadgeBackground.layer, scale: 0.00001)
                        }
                        transition.updateSublayerTransformScale(node: avatarBadgeNode, scale: max(0.00001, inlineNavigationLocation.progress))
                        transition.updateTransformScale(layer: avatarBadgeBackground.layer, scale: max(0.00001, inlineNavigationLocation.progress))
                    } else if let avatarBadgeNode = strongSelf.avatarBadgeNode {
                        strongSelf.avatarBadgeNode = nil
                        transition.updateSublayerTransformScale(node: avatarBadgeNode, scale: 0.00001, completion: { [weak avatarBadgeNode] _ in
                            avatarBadgeNode?.removeFromSupernode()
                        })
                        if let avatarBadgeBackground = strongSelf.avatarBadgeBackground {
                            strongSelf.avatarBadgeBackground = nil
                            transition.updateTransformScale(layer: avatarBadgeBackground.layer, scale: 0.00001, completion: { [weak avatarBadgeBackground] _ in
                                avatarBadgeBackground?.removeFromSupernode()
                            })
                        }
                    }
                    
                    if let threadInfo = threadInfo, !displayAsMessage {
                        let avatarIconView: ComponentHostView<Empty>
                        if let current = strongSelf.avatarIconView {
                            avatarIconView = current
                        } else {
                            avatarIconView = ComponentHostView<Empty>()
                            strongSelf.avatarIconView = avatarIconView
                            strongSelf.mainContentContainerNode.view.addSubview(avatarIconView)
                        }
                        
                        let avatarIconContent: EmojiStatusComponent.Content
                        if threadInfo.id == 1 {
                            avatarIconContent = .image(image: PresentationResourcesChatList.generalTopicIcon(item.presentationData.theme), tintColor: nil)
                        } else if let fileId = threadInfo.info.icon, fileId != 0 {
                            avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(0))
                        } else {
                            avatarIconContent = .topic(title: String(threadInfo.info.title.prefix(1)), color: threadInfo.info.iconColor, size: CGSize(width: 32.0, height: 32.0))
                        }
                        
                        let avatarIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: avatarIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus && item.context.sharedContext.energyUsageSettings.loopEmoji,
                            action: nil
                        )
                        strongSelf.avatarIconComponent = avatarIconComponent
                        
                        let iconSize = avatarIconView.update(
                            transition: .immediate,
                            component: AnyComponent(avatarIconComponent),
                            environment: {},
                            containerSize: item.interaction.isInlineMode ? CGSize(width: 18.0, height: 18.0) : CGSize(width: 32.0, height: 32.0)
                        )
                        
                        let avatarIconFrame: CGRect
                        if item.interaction.isInlineMode {
                            avatarIconFrame = CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y + 1.0), size: iconSize)
                        } else {
                            avatarIconFrame = CGRect(origin: CGPoint(x: editingOffset + params.leftInset + floor((leftInset - params.leftInset - iconSize.width) / 2.0) + revealOffset, y: contentRect.origin.y + 2.0), size: iconSize)
                        }
                        transition.updateFrame(view: avatarIconView, frame: avatarIconFrame)
                    } else if let avatarIconView = strongSelf.avatarIconView {
                        strongSelf.avatarIconView = nil
                        avatarIconView.removeFromSuperview()
                    }
                    
                    if !useChatListLayout {
                        strongSelf.avatarContainerNode.isHidden = true
                    } else {
                        strongSelf.avatarContainerNode.isHidden = false
                    }
                    
                    let onlineFrame: CGRect
                    if onlineIsVoiceChat {
                        onlineFrame = CGRect(origin: CGPoint(x: avatarFrame.width - onlineLayout.width + 1.0 - UIScreenPixel, y: avatarFrame.height - onlineLayout.height + 1.0 - UIScreenPixel), size: onlineLayout)
                    } else {
                        onlineFrame = CGRect(origin: CGPoint(x: avatarFrame.width - onlineLayout.width - 2.0, y: avatarFrame.height - onlineLayout.height - 2.0), size: onlineLayout)
                    }
                    transition.updateFrame(node: strongSelf.onlineNode, frame: onlineFrame)
                    
                    let onlineInlineNavigationFraction: CGFloat = item.interaction.inlineNavigationLocation?.progress ?? 0.0
                    transition.updateAlpha(node: strongSelf.onlineNode, alpha: 1.0 - onlineInlineNavigationFraction)
                    transition.updateSublayerTransformScale(node: strongSelf.onlineNode, scale: (1.0 - onlineInlineNavigationFraction) * 1.0 + onlineInlineNavigationFraction * 0.00001)
                    
                    let onlineIcon: UIImage?
                    let effectiveBackgroundColor: UIColor
                    if strongSelf.reallyHighlighted {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted, voiceChat: onlineIsVoiceChat)
                        effectiveBackgroundColor = item.presentationData.theme.chatList.itemHighlightedBackgroundColor
                    } else if case let .chatList(index) = item.index, index.pinningIndex != nil {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned, voiceChat: onlineIsVoiceChat)
                        effectiveBackgroundColor = item.presentationData.theme.chatList.pinnedItemBackgroundColor
                    } else {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular, voiceChat: onlineIsVoiceChat)
                        effectiveBackgroundColor = item.presentationData.theme.chatList.itemBackgroundColor
                    }
                    strongSelf.onlineNode.setImage(onlineIcon, color: item.presentationData.theme.list.itemCheckColors.foregroundColor, transition: .immediate)
                    
                    if isSubscription, autoremoveTimeout == nil {
                        let starView: StarView
                        if let current = strongSelf.starView {
                            starView = current
                        } else {
                            starView = StarView()
                            strongSelf.starView = starView
                            strongSelf.contextContainer.view.addSubview(starView)
                        }
                        starView.outlineColor = effectiveBackgroundColor
                        
                        let starSize = CGSize(width: 20.0, height: 20.0)
                        let starFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX - starSize.width + 1.0, y: avatarFrame.maxY - starSize.height + 1.0), size: starSize)
                        transition.updateFrame(view: starView, frame: starFrame)
                    } else if let starView = strongSelf.starView {
                        strongSelf.starView = nil
                        starView.removeFromSuperview()
                    }
                    
                    let autoremoveTimeoutFraction: CGFloat
                    if online {
                        autoremoveTimeoutFraction = 0.0
                    } else {
                        autoremoveTimeoutFraction = 1.0 - onlineInlineNavigationFraction
                    }
                    
                    if let autoremoveTimeout = autoremoveTimeout {
                        let avatarTimerBadge: AvatarBadgeView
                        var avatarTimerTransition = transition
                        if !avatarTimerTransition.isAnimated, animateOnline {
                            avatarTimerTransition = .animated(duration: 0.3, curve: .spring)
                        }
                        if let current = strongSelf.avatarTimerBadge {
                            avatarTimerBadge = current
                        } else {
                            avatarTimerTransition = .immediate
                            avatarTimerBadge = AvatarBadgeView(frame: CGRect())
                            strongSelf.avatarTimerBadge = avatarTimerBadge
                            strongSelf.avatarNode.view.addSubview(avatarTimerBadge)
                        }
                        let avatarBadgeSize = CGSize(width: avatarTimerBadgeDiameter, height: avatarTimerBadgeDiameter)
                        avatarTimerBadge.update(size: avatarBadgeSize, text: shortTimeIntervalString(strings: item.presentationData.strings, value: autoremoveTimeout, useLargeFormat: true))
                        let avatarBadgeFrame = CGRect(origin: CGPoint(x: avatarFrame.width - avatarBadgeSize.width, y: avatarFrame.height - avatarBadgeSize.height), size: avatarBadgeSize)
                        avatarTimerTransition.updatePosition(layer: avatarTimerBadge.layer, position: avatarBadgeFrame.center)
                        avatarTimerTransition.updateBounds(layer: avatarTimerBadge.layer, bounds: CGRect(origin: CGPoint(), size: avatarBadgeFrame.size))
                        avatarTimerTransition.updateTransformScale(layer: avatarTimerBadge.layer, scale: autoremoveTimeoutFraction * 1.0 + (1.0 - autoremoveTimeoutFraction) * 0.00001)
                        
                        strongSelf.avatarNode.badgeView = avatarTimerBadge
                    } else if let avatarTimerBadge = strongSelf.avatarTimerBadge {
                        strongSelf.avatarTimerBadge = nil
                        strongSelf.avatarNode.badgeView = nil
                        avatarTimerBadge.removeFromSuperview()
                    }
                                  
                    let _ = measureApply()
                    let _ = dateApply()
                    
                    var currentTextSnapshotView: UIView?
                    if transition.isAnimated, let currentItem, currentItem.editing != item.editing, strongSelf.textNode.textNode.cachedLayout?.linesRects() != textLayout.linesRects() {
                        if let textSnapshotView = strongSelf.textNode.textNode.view.snapshotContentTree() {
                            textSnapshotView.layer.anchorPoint = CGPoint()
                            currentTextSnapshotView = textSnapshotView
                            strongSelf.textNode.textNode.view.superview?.insertSubview(textSnapshotView, aboveSubview: strongSelf.textNode.textNode.view)
                            textSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSnapshotView] _ in
                                textSnapshotView?.removeFromSuperview()
                            })
                            strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                        }
                    }
                    
                    let _ = textApply(TextNodeWithEntities.Arguments(
                        context: item.context,
                        cache: item.interaction.animationCache,
                        renderer: item.interaction.animationRenderer,
                        placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor,
                        attemptSynchronous: synchronousLoads
                    ))
                    
                    var topForumTopicRect = authorApply()
                    if !isFirstForumThreadSelectable {
                        topForumTopicRect = nil
                    }
                    
                    let _ = titleApply()
                    let _ = badgeApply(animateBadges, !isMuted)
                    let _ = mentionBadgeApply(animateBadges, true)
                    let _ = onlineApply(animateContent && animateOnline)
                    
                    var dateFrame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size)
                    
                    if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData, customMessageListData.messageCount != nil, customMessageListData.commandPrefix == nil {
                        dateFrame.origin.x -= 10.0
                        
                        let dateDisclosureIconView: UIImageView
                        if let current = strongSelf.dateDisclosureIconView {
                            dateDisclosureIconView = current
                        } else {
                            dateDisclosureIconView = UIImageView(image: UIImage(bundleImageName: "Item List/DisclosureArrow")?.withRenderingMode(.alwaysTemplate))
                            strongSelf.dateDisclosureIconView = dateDisclosureIconView
                            strongSelf.mainContentContainerNode.view.addSubview(dateDisclosureIconView)
                        }
                        dateDisclosureIconView.tintColor = item.presentationData.theme.list.disclosureArrowColor
                        let iconScale: CGFloat = 0.7
                        if let image = dateDisclosureIconView.image {
                            let imageSize = CGSize(width: floor(image.size.width * iconScale), height: floor(image.size.height * iconScale))
                            let iconFrame = CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - imageSize.width + 4.0, y: floorToScreenPixels(dateFrame.midY - imageSize.height * 0.5)), size: imageSize)
                            dateDisclosureIconView.frame = iconFrame
                        }
                    } else if let dateDisclosureIconView = strongSelf.dateDisclosureIconView {
                        strongSelf.dateDisclosureIconView = nil
                        dateDisclosureIconView.removeFromSuperview()
                    }
                    
                    transition.updateFrame(node: strongSelf.dateNode, frame: dateFrame)
                    
                    var statusOffset: CGFloat = 0.0
                    if let dateIconImage {
                        statusOffset += 2.0 + dateIconImage.size.width + 4.0
                        
                        let dateStatusIconNode: ASImageNode
                        if let current = strongSelf.dateStatusIconNode {
                            dateStatusIconNode = current
                        } else {
                            dateStatusIconNode = ASImageNode()
                            strongSelf.dateStatusIconNode = dateStatusIconNode
                            strongSelf.mainContentContainerNode.addSubnode(dateStatusIconNode)
                        }
                        dateStatusIconNode.image = dateIconImage
                        
                        var dateStatusX: CGFloat = contentRect.origin.x
                        dateStatusX += contentRect.size.width
                        dateStatusX += -dateLayout.size.width - 4.0 - dateIconImage.size.width
                        
                        var dateStatusY: CGFloat = contentRect.origin.y + 2.0 + UIScreenPixel
                        dateStatusY += -UIScreenPixel + floor((dateLayout.size.height - dateIconImage.size.height) / 2.0)
                        
                        transition.updateFrame(node: dateStatusIconNode, frame: CGRect(origin: CGPoint(x: dateStatusX, y: dateStatusY), size: dateIconImage.size))
                    } else if let dateStatusIconNode = strongSelf.dateStatusIconNode {
                        strongSelf.dateStatusIconNode = nil
                        dateStatusIconNode.removeFromSupernode()
                    }
                    
                    let statusSize = CGSize(width: 24.0, height: 24.0)
                    
                    var statusX: CGFloat = contentRect.origin.x
                    statusX += contentRect.size.width
                    statusX += -dateLayout.size.width - statusSize.width - statusOffset
                    
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: statusX, y: contentRect.origin.y + 2.0 - UIScreenPixel + floor((dateLayout.size.height - statusSize.height) / 2.0)), size: statusSize)
                    strongSelf.statusNode.fontSize = item.presentationData.fontSize.itemListBaseFontSize
                    let _ = strongSelf.statusNode.transitionToState(statusState, animated: animateContent)
                    
                    var nextBadgeX: CGFloat = contentRect.maxX
                    if let _ = currentBadgeBackgroundImage {
                        let badgeFrame = CGRect(x: nextBadgeX - badgeLayout.width, y: contentRect.maxY - badgeLayout.height - 2.0, width: badgeLayout.width, height: badgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.badgeNode, frame: badgeFrame)
                        nextBadgeX -= badgeLayout.width + 6.0
                    }
                    
                    if currentMentionBadgeImage != nil || currentBadgeBackgroundImage != nil {
                        let badgeFrame = CGRect(x: nextBadgeX - mentionBadgeLayout.width, y: contentRect.maxY - mentionBadgeLayout.height - 2.0, width: mentionBadgeLayout.width, height: mentionBadgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.mentionBadgeNode, frame: badgeFrame)
                        nextBadgeX -= mentionBadgeLayout.width + 6.0
                    }
                    
                    if let currentPinnedIconImage = currentPinnedIconImage {
                        strongSelf.pinnedIconNode.image = currentPinnedIconImage
                        strongSelf.pinnedIconNode.isHidden = false
                        
                        let pinnedIconSize = currentPinnedIconImage.size
                        let pinnedIconFrame = CGRect(x: nextBadgeX - pinnedIconSize.width, y: contentRect.maxY - pinnedIconSize.height - 2.0, width: pinnedIconSize.width, height: pinnedIconSize.height)
                        
                        strongSelf.pinnedIconNode.frame = pinnedIconFrame
                        nextBadgeX -= pinnedIconSize.width + 6.0
                    } else {
                        strongSelf.pinnedIconNode.image = nil
                        strongSelf.pinnedIconNode.isHidden = true
                    }
                    
                    if let (actionButtonTitleNodeLayout, apply) = actionButtonTitleNodeLayoutAndApply {
                        let actionButtonSideInset = floor(item.presentationData.fontSize.itemListBaseFontSize * 12.0 / 17.0)
                        let actionButtonTopInset = floor(item.presentationData.fontSize.itemListBaseFontSize * 5.0 / 17.0)
                        let actionButtonBottomInset = floor(item.presentationData.fontSize.itemListBaseFontSize * 4.0 / 17.0)
                        
                        let actionButtonSize = CGSize(width: actionButtonTitleNodeLayout.size.width + actionButtonSideInset * 2.0, height: actionButtonTitleNodeLayout.size.height + actionButtonTopInset + actionButtonBottomInset)
                        var actionButtonFrame = CGRect(x: nextBadgeX - actionButtonSize.width, y: contentRect.minY + floor((contentRect.height - actionButtonSize.height) * 0.5), width: actionButtonSize.width, height: actionButtonSize.height)
                        actionButtonFrame.origin.y = max(actionButtonFrame.origin.y, dateFrame.maxY + floor(item.presentationData.fontSize.itemListBaseFontSize * 4.0 / 17.0))
                        
                        let actionButtonNode: HighlightableButtonNode
                        if let current = strongSelf.actionButtonNode {
                            actionButtonNode = current
                        } else {
                            actionButtonNode = HighlightableButtonNode()
                            strongSelf.actionButtonNode = actionButtonNode
                            strongSelf.mainContentContainerNode.addSubnode(actionButtonNode)
                            actionButtonNode.addTarget(strongSelf, action: #selector(strongSelf.actionButtonPressed), forControlEvents: .touchUpInside)
                        }
                        
                        let actionButtonBackgroundView: UIImageView
                        if let current = strongSelf.actionButtonBackgroundView {
                            actionButtonBackgroundView = current
                        } else {
                            actionButtonBackgroundView = UIImageView()
                            strongSelf.actionButtonBackgroundView = actionButtonBackgroundView
                            actionButtonNode.view.addSubview(actionButtonBackgroundView)
                        }
                        
                        if actionButtonBackgroundView.image?.size.height != actionButtonSize.height {
                            actionButtonBackgroundView.image = generateStretchableFilledCircleImage(diameter: actionButtonSize.height, color: .white)?.withRenderingMode(.alwaysTemplate)
                        }
                        
                        actionButtonBackgroundView.tintColor = theme.unreadBadgeActiveBackgroundColor
                        
                        let actionButtonTitleNode = apply()
                        if strongSelf.actionButtonTitleNode !== actionButtonTitleNode {
                            strongSelf.actionButtonTitleNode?.removeFromSupernode()
                            strongSelf.actionButtonTitleNode = actionButtonTitleNode
                            actionButtonNode.addSubnode(actionButtonTitleNode)
                        }
                        
                        actionButtonNode.frame = actionButtonFrame
                        actionButtonBackgroundView.frame = CGRect(origin: CGPoint(), size: actionButtonFrame.size)
                        actionButtonTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((actionButtonFrame.width - actionButtonTitleNodeLayout.size.width) * 0.5), y: actionButtonTopInset), size: actionButtonTitleNodeLayout.size)
                        
                        nextBadgeX -= actionButtonSize.width + 6.0
                    } else {
                        if let actionButtonTitleNode = strongSelf.actionButtonTitleNode {
                            actionButtonTitleNode.removeFromSupernode()
                            strongSelf.actionButtonTitleNode = nil
                        }
                        if let actionButtonBackgroundView = strongSelf.actionButtonBackgroundView {
                            actionButtonBackgroundView.removeFromSuperview()
                            strongSelf.actionButtonBackgroundView = nil
                        }
                        if let actionButtonNode = strongSelf.actionButtonNode {
                            actionButtonNode.removeFromSupernode()
                            strongSelf.actionButtonNode = nil
                        }
                    }
                    
                    var titleOffset: CGFloat = titleLeftOffset
                    if let currentSecretIconImage = currentSecretIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.secretIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.mainContentContainerNode.addSubnode(iconNode)
                            strongSelf.secretIconNode = iconNode
                        }
                        iconNode.image = currentSecretIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleLeftOffset, y: contentRect.origin.y + floor((titleLayout.size.height - currentSecretIconImage.size.height) / 2.0)), size: currentSecretIconImage.size))
                        titleOffset += currentSecretIconImage.size.width + 3.0
                    } else if let secretIconNode = strongSelf.secretIconNode {
                        strongSelf.secretIconNode = nil
                        secretIconNode.removeFromSupernode()
                    }
                    
                    let contentDelta = CGPoint(x: contentRect.origin.x - (strongSelf.titleNode.frame.minX - titleOffset), y: contentRect.origin.y - (strongSelf.titleNode.frame.minY - UIScreenPixel))
                    let titleFrame = CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: contentRect.origin.y + UIScreenPixel), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    if let (titleBadgeLayout, titleBadgeApply) = titleBadgeLayoutAndApply {
                        let titleBadgeNode = titleBadgeApply()
                        let backgroundView: UIImageView
                        if let current = strongSelf.titleBadge {
                            backgroundView = current.backgroundView
                        } else {
                            backgroundView = UIImageView(image: generateStretchableFilledCircleImage(radius: 4.0, color: .white)?.withRenderingMode(.alwaysTemplate))
                            strongSelf.titleBadge = (backgroundView, titleBadgeNode)
                            
                            strongSelf.mainContentContainerNode.view.addSubview(backgroundView)
                            strongSelf.mainContentContainerNode.addSubnode(titleBadgeNode)
                        }
                        let titleBadgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + titleIconsWidth + 10.0, y: titleFrame.minY + floor((titleFrame.height - titleBadgeLayout.size.height) * 0.5)), size: titleBadgeLayout.size)
                        titleBadgeNode.frame = titleBadgeFrame
                        
                        var titleBadgeBackgroundFrame = titleBadgeFrame.insetBy(dx: -4.0, dy: -2.0)
                        titleBadgeBackgroundFrame.size.height -= 1.0
                        backgroundView.frame = titleBadgeBackgroundFrame
                        if item.presentationData.theme.overallDarkAppearance {
                            backgroundView.tintColor = theme.titleColor.withMultipliedAlpha(0.1)
                        } else {
                            backgroundView.tintColor = theme.titleColor.withMultipliedAlpha(0.05)
                        }
                    } else if let titleBadge = strongSelf.titleBadge {
                        strongSelf.titleBadge = nil
                        titleBadge.backgroundView.removeFromSuperview()
                        titleBadge.textNode.removeFromSupernode()
                    }
                    
                    let authorNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x - 1.0, y: contentRect.minY + titleLayout.size.height), size: authorLayout)
                    strongSelf.authorNode.frame = authorNodeFrame
                    let textNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x - 1.0, y: contentRect.minY + titleLayout.size.height - 1.0 + UIScreenPixel + (authorLayout.height.isZero ? 0.0 : (authorLayout.height - 3.0))), size: textLayout.size)
                    
                    if let topForumTopicRect, !isSearching {
                        let compoundHighlightingNode: LinkHighlightingNode
                        if let current = strongSelf.compoundHighlightingNode {
                            compoundHighlightingNode = current
                        } else {
                            compoundHighlightingNode = LinkHighlightingNode(color: .clear)
                            compoundHighlightingNode.alpha = strongSelf.authorNode.alpha
                            compoundHighlightingNode.useModernPathCalculation = true
                            strongSelf.compoundHighlightingNode = compoundHighlightingNode
                            strongSelf.mainContentContainerNode.insertSubnode(compoundHighlightingNode, at: 0)
                        }
                        
                        let compoundTextButtonNode: HighlightTrackingButtonNode
                        if let current = strongSelf.compoundTextButtonNode {
                            compoundTextButtonNode = current
                        } else {
                            compoundTextButtonNode = HighlightTrackingButtonNode()
                            strongSelf.compoundTextButtonNode = compoundTextButtonNode
                            strongSelf.mainContentContainerNode.addSubnode(compoundTextButtonNode)
                            compoundTextButtonNode.addTarget(strongSelf, action: #selector(strongSelf.compoundTextButtonPressed), forControlEvents: .touchUpInside)
                            compoundTextButtonNode.highligthedChanged = { highlighted in
                                guard let strongSelf = self, let compoundHighlightingNode = strongSelf.compoundHighlightingNode else {
                                    return
                                }
                                if highlighted {
                                    compoundHighlightingNode.layer.removeAnimation(forKey: "opacity")
                                    compoundHighlightingNode.alpha = 0.65
                                    strongSelf.textNode.textNode.alpha = strongSelf.authorNode.alpha * 0.65
                                    strongSelf.authorNode.setFirstTopicHighlighted(true)
                                } else {
                                    compoundHighlightingNode.alpha = 1.0
                                    compoundHighlightingNode.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                                    
                                    let prevAlpha = strongSelf.textNode.textNode.alpha
                                    strongSelf.textNode.textNode.alpha = strongSelf.authorNode.alpha
                                    strongSelf.textNode.textNode.layer.animateAlpha(from: prevAlpha, to: strongSelf.authorNode.alpha, duration: 0.2)
                                    strongSelf.authorNode.setFirstTopicHighlighted(false)
                                }
                            }
                        }
                        
                        var topRect = topForumTopicRect
                        topRect.origin.x -= 1.0
                        topRect.size.width += 2.0
                        var textRect = textNodeFrame.offsetBy(dx: -authorNodeFrame.minX, dy: -authorNodeFrame.minY)
                        textRect.origin.x = topRect.minX
                        textRect.size.height -= 1.0
                        textRect.size.width += 16.0
                        
                        compoundHighlightingNode.frame = CGRect(origin: CGPoint(x: authorNodeFrame.minX, y: authorNodeFrame.minY), size: CGSize(width: textNodeFrame.maxX - authorNodeFrame.minX, height: textNodeFrame.maxY - authorNodeFrame.minY))
                        
                        let midY = floor((topForumTopicRect.minY + textRect.maxY) / 2.0) + 1.0
                        
                        let finalTopRect = CGRect(origin: topRect.origin, size: CGSize(width: topRect.width, height: midY - topRect.minY))
                        var finalBottomRect = CGRect(origin: CGPoint(x: textRect.minX, y: midY), size: CGSize(width: textRect.width, height: textRect.maxY - midY))
                        if finalBottomRect.maxX < finalTopRect.maxX && abs(finalBottomRect.maxX - finalTopRect.maxX) < 5.0 {
                            finalBottomRect.size.width = finalTopRect.maxX - finalBottomRect.minX
                        }
                        
                        compoundHighlightingNode.inset = 0.0
                        compoundHighlightingNode.outerRadius = floor(finalBottomRect.height * 0.5)
                        compoundHighlightingNode.innerRadius = 4.0
                        
                        compoundHighlightingNode.updateRects([
                            finalTopRect,
                            finalBottomRect
                        ], color: theme.pinnedItemBackgroundColor.mixedWith(theme.unreadBadgeInactiveBackgroundColor, alpha: 0.1))
                        
                        transition.updateFrame(node: compoundTextButtonNode, frame: compoundHighlightingNode.frame)
                        
                        if let textArrowImage = textArrowImage {
                            let textArrowNode: ASImageNode
                            if let current = strongSelf.textArrowNode {
                                textArrowNode = current
                            } else {
                                textArrowNode = ASImageNode()
                                strongSelf.textArrowNode = textArrowNode
                                compoundHighlightingNode.addSubnode(textArrowNode)
                            }
                            textArrowNode.image = textArrowImage
                            let arrowScale: CGFloat = 0.75
                            let textArrowSize = CGSize(width: floor(textArrowImage.size.width * arrowScale), height: floor(textArrowImage.size.height * arrowScale))
                            textArrowNode.frame = CGRect(origin: CGPoint(x: finalBottomRect.maxX - 0.0 - textArrowSize.width, y: finalBottomRect.minY + floorToScreenPixels((finalBottomRect.height - textArrowSize.height) / 2.0)), size: textArrowSize)
                        } else if let textArrowNode = strongSelf.textArrowNode {
                            strongSelf.textArrowNode = nil
                            textArrowNode.removeFromSupernode()
                        }
                    } else {
                        if let compoundHighlightingNode = strongSelf.compoundHighlightingNode {
                            strongSelf.compoundHighlightingNode = nil
                            compoundHighlightingNode.removeFromSupernode()
                        }
                        if let compoundTextButtonNode = strongSelf.compoundTextButtonNode {
                            strongSelf.compoundTextButtonNode = nil
                            compoundTextButtonNode.removeFromSupernode()
                        }
                        if let textArrowNode = strongSelf.textArrowNode {
                            strongSelf.textArrowNode = nil
                            textArrowNode.removeFromSupernode()
                        }
                    }
                    
                    if let compoundTextButtonNode = strongSelf.compoundTextButtonNode {
                        if strongSelf.textNode.textNode.supernode !== compoundTextButtonNode {
                            compoundTextButtonNode.addSubnode(strongSelf.textNode.textNode)
                            if let dustNode = strongSelf.dustNode {
                                compoundTextButtonNode.addSubnode(dustNode)
                            }
                        }
                        strongSelf.textNode.textNode.frame = textNodeFrame.offsetBy(dx: -compoundTextButtonNode.frame.minX, dy: -compoundTextButtonNode.frame.minY)
                        
                        strongSelf.authorNode.assignParentNode(parentNode: compoundTextButtonNode)
                    } else {
                        if strongSelf.textNode.textNode.supernode !== strongSelf.mainContentContainerNode {
                            strongSelf.mainContentContainerNode.addSubnode(strongSelf.textNode.textNode)
                            if let dustNode = strongSelf.dustNode {
                                strongSelf.mainContentContainerNode.addSubnode(dustNode)
                            }
                        }
                        strongSelf.textNode.textNode.frame = textNodeFrame
                        
                        strongSelf.authorNode.assignParentNode(parentNode: nil)
                    }
                    
                    if let currentTextSnapshotView {
                        transition.updatePosition(layer: currentTextSnapshotView.layer, position: textNodeFrame.origin)
                    }
                    
                    if let trailingTextBadgeLayoutAndApply {
                        let badgeSize = CGSize(width: trailingTextBadgeLayoutAndApply.0.size.width + trailingTextBadgeInsets.left + trailingTextBadgeInsets.right, height: trailingTextBadgeLayoutAndApply.0.size.height + trailingTextBadgeInsets.top + trailingTextBadgeInsets.bottom - UIScreenPixel)
                        
                        var badgeFrame: CGRect
                        if textLayout.numberOfLines > 1 {
                            badgeFrame = CGRect(origin: CGPoint(x: textLayout.trailingLineWidth + 4.0, y: textNodeFrame.height - 3.0 - badgeSize.height), size: badgeSize)
                        } else {
                            let firstLineFrame = textLayout.linesRects().first ?? CGRect(origin: CGPoint(), size: textNodeFrame.size)
                            badgeFrame = CGRect(origin: CGPoint(x: 0.0, y: firstLineFrame.height + 5.0), size: badgeSize)
                        }
                            
                        if badgeFrame.origin.x + badgeFrame.width >= textNodeFrame.width - 2.0 - 10.0 {
                            badgeFrame.origin.x = textNodeFrame.width - 2.0 - badgeFrame.width
                        }
                        
                        let trailingTextBadgeBackground: UIImageView
                        if let current = strongSelf.trailingTextBadgeBackground {
                            trailingTextBadgeBackground = current
                        } else {
                            trailingTextBadgeBackground = UIImageView(image: tagBackgroundImage)
                            strongSelf.trailingTextBadgeBackground = trailingTextBadgeBackground
                            strongSelf.textNode.textNode.view.addSubview(trailingTextBadgeBackground)
                        }
                        trailingTextBadgeBackground.tintColor = theme.pinnedItemBackgroundColor.mixedWith(theme.unreadBadgeInactiveBackgroundColor, alpha: 0.1)
                        
                        trailingTextBadgeBackground.frame = badgeFrame
                        
                        let trailingTextBadgeFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + trailingTextBadgeInsets.left, y: badgeFrame.minY + trailingTextBadgeInsets.top), size: trailingTextBadgeLayoutAndApply.0.size)
                        let trailingTextBadgeNode = trailingTextBadgeLayoutAndApply.1()
                        if strongSelf.trailingTextBadgeNode !== trailingTextBadgeNode {
                            strongSelf.trailingTextBadgeNode?.removeFromSupernode()
                            strongSelf.trailingTextBadgeNode = trailingTextBadgeNode
                            
                            strongSelf.textNode.textNode.addSubnode(trailingTextBadgeNode)
                            
                            trailingTextBadgeNode.layer.anchorPoint = CGPoint()
                        }
                        
                        trailingTextBadgeNode.frame = trailingTextBadgeFrame
                    } else {
                        if let trailingTextBadgeNode = strongSelf.trailingTextBadgeNode {
                            strongSelf.trailingTextBadgeNode = nil
                            trailingTextBadgeNode.removeFromSupernode()
                        }
                        if let trailingTextBadgeBackground = strongSelf.trailingTextBadgeBackground {
                            strongSelf.trailingTextBadgeBackground = nil
                            trailingTextBadgeBackground.removeFromSuperview()
                        }
                    }
                    
                    if !itemTags.isEmpty {
                        let sizeFactor = item.presentationData.fontSize.itemListBaseFontSize / 17.0
                        
                        let itemTagListFrame = CGRect(origin: CGPoint(x: contentRect.minX, y: contentRect.minY + measureLayout.size.height * 2.0 + floorToScreenPixels(2.0 * sizeFactor)), size: CGSize(width: contentRect.width, height: floorToScreenPixels(20.0 * sizeFactor)))
                        
                        var itemTagListTransition = transition
                        let itemTagList: ComponentView<Empty>
                        if let current = strongSelf.itemTagList {
                            itemTagList = current
                        } else {
                            itemTagListTransition = .immediate
                            itemTagList = ComponentView()
                            strongSelf.itemTagList = itemTagList
                        }
                        let _ = itemTagList.update(
                            transition: .immediate,
                            component: AnyComponent(ChatListItemTagListComponent(
                                context: item.context,
                                tags: itemTags,
                                theme: item.presentationData.theme,
                                sizeFactor: sizeFactor
                            )),
                            environment: {},
                            containerSize: itemTagListFrame.size
                        )
                        if let itemTagListView = itemTagList.view as? ChatListItemTagListComponent.View {
                            if itemTagListView.superview == nil {
                                itemTagListView.isUserInteractionEnabled = false
                                strongSelf.mainContentContainerNode.view.addSubview(itemTagListView)
                            }
                            
                            itemTagListTransition.updateFrame(view: itemTagListView, frame: itemTagListFrame)
                            itemTagListView.isVisible = strongSelf.visibilityStatus && item.context.sharedContext.energyUsageSettings.loopEmoji
                        }
                    } else {
                        if let itemTagList = strongSelf.itemTagList {
                            strongSelf.itemTagList = nil
                            itemTagList.view?.removeFromSuperview()
                        }
                    }
                    
                    if !textLayout.spoilers.isEmpty {
                        let dustNode: InvisibleInkDustNode
                        if let current = strongSelf.dustNode {
                            dustNode = current
                        } else {
                            dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                            dustNode.isUserInteractionEnabled = false
                            strongSelf.dustNode = dustNode
                            
                            strongSelf.textNode.textNode.supernode?.insertSubnode(dustNode, aboveSubnode: strongSelf.textNode.textNode)
                        }
                        dustNode.update(size: textNodeFrame.size, color: theme.messageTextColor, textColor: theme.messageTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 0.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 0.0, dy: 1.0) })
                        dustNode.frame = textNodeFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
                     
                    } else if let dustNode = strongSelf.dustNode {
                        strongSelf.dustNode = nil
                        dustNode.removeFromSupernode()
                    }
                    
                    var animateInputActivitiesFrame = false
                    let inputActivities = inputActivities?.filter({
                        switch $0.1 {
                            case .speakingInGroupCall, .seeingEmojiInteraction:
                                return false
                            default:
                                return true
                        }
                    })
                    
                    if let inputActivities = inputActivities, !inputActivities.isEmpty {
                        if strongSelf.inputActivitiesNode.supernode == nil {
                            strongSelf.mainContentContainerNode.addSubnode(strongSelf.inputActivitiesNode)
                        } else {
                            animateInputActivitiesFrame = true
                        }
                        
                        if strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 1.0
                            strongSelf.textNode.textNode.alpha = 0.0
                            strongSelf.authorNode.alpha = 0.0
                            strongSelf.compoundHighlightingNode?.alpha = 0.0
                            strongSelf.forwardedIconNode.alpha = 0.0
                            
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.textNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.compoundHighlightingNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.dustNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.forwardedIconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                            }
                        }
                        strongSelf.dustNode?.alpha = 0.0
                    } else {
                        if !strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 0.0
                            strongSelf.textNode.textNode.alpha = 1.0
                            strongSelf.authorNode.alpha = 1.0
                            strongSelf.compoundHighlightingNode?.alpha = 1.0
                            strongSelf.forwardedIconNode.alpha = 1.0
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { value in
                                    if let strongSelf = self, value {
                                        strongSelf.inputActivitiesNode.removeFromSupernode()
                                    }
                                })
                                strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.compoundHighlightingNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.dustNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.forwardedIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            } else {
                                strongSelf.inputActivitiesNode.removeFromSupernode()
                            }
                        }
                        strongSelf.dustNode?.alpha = 1.0
                    }
                    if let inputActivitiesSize = inputActivitiesSize {
                        let inputActivitiesFrame = CGRect(origin: CGPoint(x: contentRect.minX, y: authorNodeFrame.minY + UIScreenPixel), size: inputActivitiesSize)
                        if animateInputActivitiesFrame {
                            transition.updateFrame(node: strongSelf.inputActivitiesNode, frame: inputActivitiesFrame)
                        } else {
                            strongSelf.inputActivitiesNode.frame = inputActivitiesFrame
                        }
                    }
                    inputActivitiesApply?()
                    
                    var mediaPreviewOffset = textNodeFrame.origin.offsetBy(dx: 1.0, dy: 1.0 + floor((measureLayout.size.height - contentImageSize.height) / 2.0))
                    
                    var messageTypeIcon: UIImage?
                    var messageTypeIconOffset = mediaPreviewOffset
                    if let currentForwardedIcon {
                        messageTypeIcon = currentForwardedIcon
                        messageTypeIconOffset.y += 3.0
                    } else if let currentStoryIcon {
                        messageTypeIcon = currentStoryIcon
                    } else if let currentGiftIcon {
                        messageTypeIcon = currentGiftIcon
                        messageTypeIconOffset.y -= 2.0 - UIScreenPixel
                    } else if let currentLocationIcon {
                        messageTypeIcon = currentLocationIcon
                        messageTypeIconOffset.y -= 2.0 - UIScreenPixel
                    }
                    
                    if let messageTypeIcon {
                        strongSelf.forwardedIconNode.image = messageTypeIcon
                        if strongSelf.forwardedIconNode.supernode == nil {
                            strongSelf.mainContentContainerNode.addSubnode(strongSelf.forwardedIconNode)
                        }
                        transition.updateFrame(node: strongSelf.forwardedIconNode, frame: CGRect(origin: messageTypeIconOffset, size: messageTypeIcon.size))
                        mediaPreviewOffset.x += messageTypeIcon.size.width + forwardedIconSpacing
                    } else if strongSelf.forwardedIconNode.supernode != nil {
                        strongSelf.forwardedIconNode.removeFromSupernode()
                    }
                    
                    var validMediaIds: [EngineMedia.Id] = []
                    for spec in contentImageSpecs {
                        let message = spec.message
                        let media = spec.media
                        let mediaSize = spec.size
                        
                        var mediaId = media.id
                        if mediaId == nil, case let .action(action) = media, case let .suggestedProfilePhoto(image) = action.action {
                            mediaId = image?.id
                        }
                        guard let mediaId = mediaId else {
                            continue
                        }
                        validMediaIds.append(mediaId)
                        let previewNode: ChatListMediaPreviewNode
                        var previewNodeTransition = transition
                        var previewNodeAlphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                        if let current = strongSelf.mediaPreviewNodes[mediaId] {
                            previewNode = current
                        } else {
                            previewNodeTransition = .immediate
                            previewNodeAlphaTransition = .immediate
                            previewNode = ChatListMediaPreviewNode(context: item.context, message: message, media: media)
                            strongSelf.mediaPreviewNodes[mediaId] = previewNode
                            strongSelf.mainContentContainerNode.addSubnode(previewNode)
                        }
                        previewNode.updateLayout(size: mediaSize, synchronousLoads: synchronousLoads)
                        previewNodeAlphaTransition.updateAlpha(node: previewNode, alpha: strongSelf.inputActivitiesNode.alpha.isZero ? 1.0 : 0.0)
                        previewNodeTransition.updateFrame(node: previewNode, frame: CGRect(origin: mediaPreviewOffset, size: mediaSize))
                        mediaPreviewOffset.x += mediaSize.width + contentImageSpacing
                    }
                    var removeMediaIds: [EngineMedia.Id] = []
                    for (mediaId, itemNode) in strongSelf.mediaPreviewNodes {
                        if !validMediaIds.contains(mediaId) {
                            removeMediaIds.append(mediaId)
                            itemNode.removeFromSupernode()
                        }
                    }
                    for mediaId in removeMediaIds {
                        strongSelf.mediaPreviewNodes.removeValue(forKey: mediaId)
                    }
                    strongSelf.currentMediaPreviewSpecs = contentImageSpecs
                    strongSelf.currentTextLeftCutout = textLeftCutout
                    
                    if let avatarContentImageSpec {
                        strongSelf.avatarNode.isHidden = true
                        
                        if let previous = strongSelf.avatarMediaNode, previous.media != avatarContentImageSpec.media {
                            strongSelf.avatarMediaNode = nil
                            previous.removeFromSupernode()
                        }
                        
                        var avatarMediaNodeTransition = transition
                        let avatarMediaNode: ChatListMediaPreviewNode
                        if let current = strongSelf.avatarMediaNode {
                            avatarMediaNode = current
                        } else {
                            avatarMediaNodeTransition = .immediate
                            avatarMediaNode = ChatListMediaPreviewNode(context: item.context, message: avatarContentImageSpec.message, media: avatarContentImageSpec.media)
                            strongSelf.avatarMediaNode = avatarMediaNode
                            strongSelf.contextContainer.addSubnode(avatarMediaNode)
                        }
                        
                        avatarMediaNodeTransition.updateFrame(node: avatarMediaNode, frame: avatarFrame)
                        avatarMediaNode.updateLayout(size: avatarFrame.size, synchronousLoads: synchronousLoads)
                    } else {
                        strongSelf.avatarNode.isHidden = false
                        
                        if let avatarMediaNode = strongSelf.avatarMediaNode {
                            strongSelf.avatarMediaNode = nil
                            avatarMediaNode.removeFromSupernode()
                        }
                    }
                    
                    if !contentDelta.x.isZero || !contentDelta.y.isZero {
                        let titlePosition = strongSelf.titleNode.position
                        transition.animatePosition(node: strongSelf.titleNode, from: CGPoint(x: titlePosition.x - contentDelta.x, y: titlePosition.y - contentDelta.y))
                        
                        if strongSelf.textNode.textNode.supernode === strongSelf.mainContentContainerNode {
                            transition.animatePositionAdditive(node: strongSelf.textNode.textNode, offset: CGPoint(x: -contentDelta.x, y: -contentDelta.y))
                            if let dustNode = strongSelf.dustNode {
                                transition.animatePositionAdditive(node: dustNode, offset: CGPoint(x: -contentDelta.x, y: -contentDelta.y))
                            }
                        }
                        
                        let authorPosition = strongSelf.authorNode.position
                        transition.animatePosition(node: strongSelf.authorNode, from: CGPoint(x: authorPosition.x - contentDelta.x, y: authorPosition.y - contentDelta.y))
                        if let compoundHighlightingNode = strongSelf.compoundHighlightingNode {
                            let compoundHighlightingPosition = compoundHighlightingNode.position
                            transition.animatePosition(node: compoundHighlightingNode, from: CGPoint(x: compoundHighlightingPosition.x - contentDelta.x, y: compoundHighlightingPosition.y - contentDelta.y))
                        }
                    }
                    
                    if crossfadeContent {
                        strongSelf.authorNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.titleNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.textNode.textNode.recursivelyEnsureDisplaySynchronously(true)
                    }
                    
                    var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleLayout.trailingLineWidth + 3.0 + titleOffset
                    let lastLineRect: CGRect
                    if let rect = titleLayout.linesRects().last {
                        lastLineRect = CGRect(origin: CGPoint(x: 0.0, y: titleLayout.size.height - rect.height - 2.0), size: CGSize(width: rect.width, height: rect.height + 2.0))
                    } else {
                        lastLineRect = CGRect(origin: CGPoint(), size: titleLayout.size)
                    }
                                        
                    if let currentStatusIconContent {
                        let statusIconView: ComponentHostView<Empty>
                        if let current = strongSelf.statusIconView {
                            statusIconView = current
                        } else {
                            statusIconView = ComponentHostView<Empty>()
                            strongSelf.statusIconView = statusIconView
                            strongSelf.mainContentContainerNode.view.addSubview(statusIconView)
                        }
                                                        
                        let statusIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: currentStatusIconContent,
                            particleColor: currentStatusIconParticleColor,
                            isVisibleForAnimations: strongSelf.visibilityStatus && item.context.sharedContext.energyUsageSettings.loopEmoji,
                            action: nil
                        )
                        strongSelf.statusIconComponent = statusIconComponent
                        
                        let iconOrigin: CGFloat = nextTitleIconOrigin
                        let containerSize = CGSize(width: 20.0, height: 20.0)
                        let iconSize = statusIconView.update(
                            transition: .immediate,
                            component: AnyComponent(statusIconComponent),
                            environment: {},
                            containerSize: containerSize
                        )
                        transition.updateFrame(view: statusIconView, frame: CGRect(origin: CGPoint(x: iconOrigin, y: floorToScreenPixels(titleFrame.maxY - lastLineRect.height * 0.5 - iconSize.height / 2.0) - UIScreenPixel), size: iconSize))
                        nextTitleIconOrigin += statusIconView.bounds.width + 4.0
                    } else if let statusIconView = strongSelf.statusIconView {
                        strongSelf.statusIconView = nil
                        statusIconView.removeFromSuperview()
                    }
                    
                    if let currentCredibilityIconContent {
                        let credibilityIconView: ComponentHostView<Empty>
                        if let current = strongSelf.credibilityIconView {
                            credibilityIconView = current
                        } else {
                            credibilityIconView = ComponentHostView<Empty>()
                            strongSelf.credibilityIconView = credibilityIconView
                            strongSelf.mainContentContainerNode.view.addSubview(credibilityIconView)
                        }
                                                
                        let credibilityIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: currentCredibilityIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus && item.context.sharedContext.energyUsageSettings.loopEmoji,
                            action: nil
                        )
                        strongSelf.credibilityIconComponent = credibilityIconComponent
                        
                        let iconOrigin: CGFloat = nextTitleIconOrigin
                        let containerSize: CGSize
                        if case .verified = currentCredibilityIconContent {
                            containerSize = CGSize(width: 16.0, height: 16.0)
                        } else {
                            containerSize = CGSize(width: 20.0, height: 20.0)
                        }
                        let iconSize = credibilityIconView.update(
                            transition: .immediate,
                            component: AnyComponent(credibilityIconComponent),
                            environment: {},
                            containerSize: containerSize
                        )
                        transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: iconOrigin, y: floorToScreenPixels(titleFrame.maxY - lastLineRect.height * 0.5 - iconSize.height / 2.0) - UIScreenPixel), size: iconSize))
                        nextTitleIconOrigin += credibilityIconView.bounds.width + 4.0
                    } else if let credibilityIconView = strongSelf.credibilityIconView {
                        strongSelf.credibilityIconView = nil
                        credibilityIconView.removeFromSuperview()
                    }
                    
                    if let currentVerifiedIconContent {
                        let verifiedIconView: ComponentHostView<Empty>
                        if let current = strongSelf.verifiedIconView {
                            verifiedIconView = current
                        } else {
                            verifiedIconView = ComponentHostView<Empty>()
                            strongSelf.verifiedIconView = verifiedIconView
                            strongSelf.mainContentContainerNode.view.addSubview(verifiedIconView)
                        }
                        
                        let verifiedIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: currentVerifiedIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus && item.context.sharedContext.energyUsageSettings.loopEmoji,
                            action: nil
                        )
                        strongSelf.verifiedIconComponent = verifiedIconComponent
                        
                        let iconOrigin: CGFloat
                        if case .animation = currentVerifiedIconContent {
                            iconOrigin = contentRect.origin.x
                        } else {
                            iconOrigin = nextTitleIconOrigin
                        }
                        let containerSize = CGSize(width: 16.0, height: 16.0)
                        
                        let iconSize = verifiedIconView.update(
                            transition: .immediate,
                            component: AnyComponent(verifiedIconComponent),
                            environment: {},
                            containerSize: containerSize
                        )
                        transition.updateFrame(view: verifiedIconView, frame: CGRect(origin: CGPoint(x: iconOrigin, y: floorToScreenPixels(titleFrame.maxY - lastLineRect.height * 0.5 - iconSize.height / 2.0) - UIScreenPixel), size: iconSize))
                    } else if let verifiedIconView = strongSelf.verifiedIconView {
                        strongSelf.verifiedIconView = nil
                        verifiedIconView.removeFromSuperview()
                    }
                    
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        strongSelf.mutedIconNode.isHidden = false
                        transition.updateFrame(node: strongSelf.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin - 5.0, y: floorToScreenPixels(titleFrame.maxY - lastLineRect.height * 0.5 - currentMutedIconImage.size.height / 2.0)), size: currentMutedIconImage.size))
                        nextTitleIconOrigin += currentMutedIconImage.size.width + 1.0
                    } else {
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    let separatorInset: CGFloat
                    if case let .groupReference(groupReferenceData) = item.content, groupReferenceData.hiddenByDefault {
                        separatorInset = 0.0
                    } else if (!nextIsPinned && isPinned) || last {
                            separatorInset = 0.0
                    } else {
                        separatorInset = editingOffset + leftInset + rawContentRect.origin.x
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: layoutOffset + itemHeight - separatorHeight), size: CGSize(width: params.width - separatorInset, height: separatorHeight)))
                    if let inlineNavigationLocation = item.interaction.inlineNavigationLocation {
                        transition.updateAlpha(node: strongSelf.separatorNode, alpha: 1.0 - inlineNavigationLocation.progress)
                    } else {
                        transition.updateAlpha(node: strongSelf.separatorNode, alpha: 1.0)
                    }
                    
                    if case let .peer(peerData) = item.content, let customMessageListData = peerData.customMessageListData {
                        if customMessageListData.hideSeparator {
                            strongSelf.separatorNode.isHidden = true
                        }
                    }
                    
                    transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.contentSize.width, height: itemHeight)))
                    let backgroundColor: UIColor
                    let highlightedBackgroundColor: UIColor
                    if item.selected {
                        backgroundColor = theme.itemSelectedBackgroundColor
                        highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                    } else if isPinned {
                        if case let .groupReference(groupReferenceData) = item.content, groupReferenceData.hiddenByDefault {
                            backgroundColor = theme.itemBackgroundColor
                            highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                        } else {
                            backgroundColor = theme.pinnedItemBackgroundColor
                            highlightedBackgroundColor = theme.pinnedItemHighlightedBackgroundColor
                        }
                    } else {
                        if case let .peer(peerData) = item.content, peerData.customMessageListData != nil {
                            backgroundColor = .clear
                        } else {
                            backgroundColor = theme.itemBackgroundColor
                        }
                        highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                    }
                    
                    if animated {
                        transition.updateBackgroundColor(node: strongSelf.backgroundNode, color: backgroundColor)
                    } else {
                        strongSelf.backgroundNode.backgroundColor = backgroundColor
                    }
                    
                    if let inlineNavigationLocation = item.interaction.inlineNavigationLocation {
                        transition.updateAlpha(node: strongSelf.backgroundNode, alpha: 1.0 - inlineNavigationLocation.progress)
                    } else {
                        transition.updateAlpha(node: strongSelf.backgroundNode, alpha: 1.0)
                    }
                    
                    strongSelf.highlightedBackgroundNode.backgroundColor = highlightedBackgroundColor
                    let topNegativeInset: CGFloat = 0.0
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layoutOffset - separatorHeight - topNegativeInset), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height + separatorHeight + topNegativeInset))
                    
                    if let peerPresence = peerPresence {
                        strongSelf.peerPresenceManager?.reset(presence: EnginePeer.Presence(status: peerPresence.status, lastActivity: 0), isOnline: online)
                    }
                    
                    strongSelf.updateLayout(size: CGSize(width: layout.contentSize.width, height: itemHeight), leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.editing {
                        strongSelf.setRevealOptions((left: [], right: []), enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                    } else {
                        strongSelf.setRevealOptions((left: peerLeftRevealOptions, right: peerRevealOptions), enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                    }
                    if !strongSelf.customAnimationInProgress {
                        strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: true)
                    }
                    
                    strongSelf.view.accessibilityLabel = strongSelf.accessibilityLabel
                    strongSelf.view.accessibilityValue = strongSelf.accessibilityValue
                    
                    if !customActions.isEmpty {
                        strongSelf.view.accessibilityCustomActions = customActions.map({ action -> UIAccessibilityCustomAction in
                            return ChatListItemAccessibilityCustomAction(name: action.name, target: strongSelf, selector: #selector(strongSelf.performLocalAccessibilityCustomAction(_:)), key: action.key)
                        })
                    } else {
                        strongSelf.view.accessibilityCustomActions = nil
                    }
                    
                    strongSelf.avatarTapRecognizer?.isEnabled = item.interaction.inlineNavigationLocation == nil
                    
                    if case .loading = item.content {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            strongSelf.addSubnode(shimmerNode)
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - 1.0))
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }
                        
                        var shapes: [ShimmerEffectNode.Shape] = []
                        
                        let titleLineWidth: CGFloat = 180.0
                        let dateLineWidth: CGFloat = 36.0
                        let textFirstLineWidth: CGFloat = 240.0
                        let textSecondLineWidth: CGFloat = 200.0
                        let lineDiameter: CGFloat = 10.0
                        
                        shapes.append(.circle(avatarFrame))
                        
                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let textFrame = strongSelf.textNode.textNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: textFrame.minX, y: textFrame.minY + 7.0), width: textFirstLineWidth, diameter: lineDiameter))
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: textFrame.minX, y: textFrame.minY + 7.0 + lineDiameter + 9.0), width: textSecondLineWidth, diameter: lineDiameter))
                        
                        let dateFrame = strongSelf.dateNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: dateFrame.maxX - dateLineWidth, y: dateFrame.minY + 3.0), width: dateLineWidth, diameter: lineDiameter))
                        
                        shimmerNode.update(backgroundColor: item.presentationData.theme.list.plainBackgroundColor, foregroundColor: item.presentationData.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: shimmerNode.frame.size)
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    @objc private func compoundTextButtonPressed() {
        guard let item else {
            return
        }
        guard case let .peer(peerData) = item.content else {
            return
        }
        guard let topicItem = peerData.topForumTopicItems.first else {
            return
        }
        guard case let .chatList(index) = item.index else {
            return
        }
        item.interaction.openForumThread(index.messageIndex.id.peerId, topicItem.id)
    }
    
    @objc private func actionButtonPressed() {
        guard let item else {
            return
        }
        guard case let .peer(peerData) = item.content else {
            return
        }
        if case let .user(user) = peerData.peer.peer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
            item.interaction.openWebApp(user)
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.clipsToBounds = true
        if self.skipFadeout {
            self.skipFadeout = false
        } else {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.layoutParams?.0 {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    private func updateVideoVisibility() {
        let isVisible = self.visibilityStatus && self.trackingIsInHierarchy
        self.avatarVideoNode?.updateVisibility(isVisible)
      
        if let videoNode = self.avatarVideoNode {
            videoNode.updateLayout(size: self.avatarNode.frame.size, cornerRadius: self.avatarNode.frame.size.width / 2.0, transition: .immediate)
            videoNode.frame = self.avatarNode.bounds
        }
    }
        
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        transition.updateBounds(node: self.contextContainer, bounds: self.contextContainer.frame.offsetBy(dx: -offset, dy: 0.0))
    }
    
    override public func touchesToOtherItemsPrevented() {
        super.touchesToOtherItemsPrevented()
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(nil, nil)
        }
    }
    
    override public func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            switch item.index {
            case let .chatList(index):
                item.interaction.setPeerIdWithRevealedOptions(index.messageIndex.id.peerId, nil)
            case .forum:
                break
            }
        }
    }
    
    override public func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            switch item.index {
            case let .chatList(index):
                item.interaction.setPeerIdWithRevealedOptions(nil, index.messageIndex.id.peerId)
            case .forum:
                break
            }
        }
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        var close = true
        if case let .chatList(index) = item.index {
            switch option.key {
            case RevealOptionKey.pin.rawValue:
                switch item.content {
                case .loading:
                    break
                case .peer:
                    let itemId: EngineChatList.PinnedItem.Id = .peer(index.messageIndex.id.peerId)
                    item.interaction.setItemPinned(itemId, true)
                case .groupReference:
                    break
                }
            case RevealOptionKey.unpin.rawValue:
                switch item.content {
                case .loading:
                    break
                case .peer:
                    let itemId: EngineChatList.PinnedItem.Id = .peer(index.messageIndex.id.peerId)
                    item.interaction.setItemPinned(itemId, false)
                case .groupReference:
                    break
                }
            case RevealOptionKey.mute.rawValue:
                item.interaction.setPeerMuted(index.messageIndex.id.peerId, true)
                close = false
            case RevealOptionKey.unmute.rawValue:
                item.interaction.setPeerMuted(index.messageIndex.id.peerId, false)
                close = false
            case RevealOptionKey.delete.rawValue:
                var joined = false
                if case let .peer(peerData) = item.content, let message = peerData.messages.first {
                    for media in message.media {
                        if let action = media as? TelegramMediaAction, action.action == .peerJoined {
                            joined = true
                        }
                    }
                }
                item.interaction.deletePeer(index.messageIndex.id.peerId, joined)
            case RevealOptionKey.archive.rawValue:
                item.interaction.updatePeerGrouping(index.messageIndex.id.peerId, true)
                close = false
                self.skipFadeout = true
                self.customAnimationInProgress = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                    self.customAnimationInProgress = false
                }
            case RevealOptionKey.unarchive.rawValue:
                item.interaction.updatePeerGrouping(index.messageIndex.id.peerId, false)
                close = false
                self.skipFadeout = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                }
            case RevealOptionKey.toggleMarkedUnread.rawValue:
                item.interaction.togglePeerMarkedUnread(index.messageIndex.id.peerId, animated)
                close = false
            case RevealOptionKey.hide.rawValue:
                item.interaction.toggleArchivedFolderHiddenByDefault()
                close = false
                self.skipFadeout = true
                self.customAnimationInProgress = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                    self.customAnimationInProgress = false
                }
            case RevealOptionKey.unhide.rawValue:
                item.interaction.toggleArchivedFolderHiddenByDefault()
                close = false
            case RevealOptionKey.hidePsa.rawValue:
                if let item = self.item, case let .peer(peerData) = item.content {
                    item.interaction.hidePsa(peerData.peer.peerId)
                }
                close = false
                self.skipFadeout = true
                self.customAnimationInProgress = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                    self.customAnimationInProgress = false
                }
            case RevealOptionKey.edit.rawValue:
                item.interaction.editPeer(item)
                close = true
            default:
                break
            }
        } else if case let .forum(_, _, threadId, _, _) = item.index, case let .forum(peerId) = item.chatListLocation {
            switch option.key {
            case RevealOptionKey.delete.rawValue:
                item.interaction.deletePeerThread(peerId, threadId)
            case RevealOptionKey.mute.rawValue:
                item.interaction.setPeerThreadMuted(peerId, threadId, true)
                close = false
            case RevealOptionKey.unmute.rawValue:
                item.interaction.setPeerThreadMuted(peerId, threadId, false)
                close = false
            case RevealOptionKey.close.rawValue:
                item.interaction.setPeerThreadStopped(peerId, threadId, true)
            case RevealOptionKey.open.rawValue:
                item.interaction.setPeerThreadStopped(peerId, threadId, false)
            case RevealOptionKey.pin.rawValue:
                item.interaction.setPeerThreadPinned(peerId, threadId, true)
            case RevealOptionKey.unpin.rawValue:
                item.interaction.setPeerThreadPinned(peerId, threadId, false)
            case RevealOptionKey.hide.rawValue:
                item.interaction.setPeerThreadHidden(peerId, threadId, true)
                close = false
                self.skipFadeout = true
                self.customAnimationInProgress = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                    self.customAnimationInProgress = false
                }
            case RevealOptionKey.unhide.rawValue:
                item.interaction.setPeerThreadHidden(peerId, threadId, false)
            default:
                break
            }
        }
        if close {
            self.setRevealOptionsOpened(false, animated: true)
            self.revealOptionsInteractivelyClosed()
        }
    }
    
    override public func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point) {
            return true
        }
        return false
    }
    
    func flashHighlight() {
        if self.highlightedBackgroundNode.supernode == nil {
            self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            self.highlightedBackgroundNode.alpha = 0.0
        }
        self.highlightedBackgroundNode.layer.removeAllAnimations()
        self.highlightedBackgroundNode.layer.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, delay: 0.7, completion: { [weak self] _ in
            self?.updateIsHighlighted(transition: .immediate)
        })
    }
    
    func playArchiveAnimation() {
        guard let item = self.item, case .groupReference = item.content else {
            return
        }
        self.avatarNode.playArchiveAnimation()
    }
    
    override public func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let item = self.item {
            if case .groupReference = item.content {
                self.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, currentValue - (self.currentItemHeight ?? 0.0), 0.0)
            } else {
                var separatorFrame = self.separatorNode.frame
                separatorFrame.origin.y = currentValue - UIScreenPixel
                self.separatorNode.frame = separatorFrame
            }
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let action = action as? ChatListItemAccessibilityCustomAction {
            self.revealOptionSelected(ItemListRevealOption(key: action.key, title: "", icon: .none, color: .black, textColor: .white), animated: false)
        }
    }
    
    override public func snapshotForReordering() -> UIView? {
        self.backgroundNode.alpha = 0.9
        let result = self.view.snapshotContentTree()
        self.backgroundNode.alpha = 1.0
        return result
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let item = self.item, self.frame.height > 0.0 else {
            return nil
        }
        
        if let compoundTextButtonNode = self.compoundTextButtonNode, let compoundHighlightingNode = self.compoundHighlightingNode, compoundHighlightingNode.alpha != 0.0 {
            let localPoint = self.view.convert(point, to: compoundHighlightingNode.view)
            var matches = false
            for rect in compoundHighlightingNode.rects {
                if rect.contains(localPoint) {
                    matches = true
                    break
                }
            }
            if matches {
                return compoundTextButtonNode.view
            }
        }
        
        if let _ = item.interaction.inlineNavigationLocation {
        } else {
            if self.avatarNode.storyStats != nil {
                if let result = self.avatarNode.view.hitTest(self.view.convert(point, to: self.avatarNode.view), with: event) {
                    return result
                }
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    @objc private func avatarStoryTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            guard let item = self.item else {
                return
            }
            switch item.content {
            case .loading:
                break
            case let .peer(peerData):
                item.interaction.openStories(.peer(peerData.peer.peerId), self)
            case .groupReference:
                item.interaction.openStories(.archive, self)
            }
        }
    }
}

private class StarView: UIView {
    let outline = SimpleLayer()
    let foreground = SimpleLayer()
    
    var outlineColor: UIColor = .white {
        didSet {
            self.outline.layerTintColor = self.outlineColor.cgColor
        }
    }
    
    override init(frame: CGRect) {
        self.outline.contents = UIImage(bundleImageName: "Premium/Stars/StarMediumOutline")?.cgImage
        self.foreground.contents = UIImage(bundleImageName: "Premium/Stars/StarMedium")?.cgImage
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.outline)
        self.layer.addSublayer(self.foreground)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    func setOutlineColor(_ color: UIColor, transition: ContainedViewLayoutTransition) {
        if case let .animated(duration, curve) = transition, color != self.outlineColor {
            let snapshotLayer = SimpleLayer()
            snapshotLayer.layerTintColor = self.outlineColor.cgColor
            snapshotLayer.contents = self.outline.contents
            snapshotLayer.frame = self.outline.bounds
            self.layer.insertSublayer(snapshotLayer, above: self.outline)
            snapshotLayer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                snapshotLayer?.removeFromSuperlayer()
            })
        }
        self.outlineColor = color
    }
    
    override func layoutSubviews() {
        self.outline.frame = self.bounds
        self.foreground.frame = self.bounds
    }
}
