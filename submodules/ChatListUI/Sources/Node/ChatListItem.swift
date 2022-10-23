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
import TelegramUniversalVideoContent
import UniversalMediaPlayer
import GalleryUI
import HierarchyTrackingLayer
import TextNodeWithEntities
import ComponentFlow
import EmojiStatusComponent

public enum ChatListItemContent {
    public struct ThreadInfo: Equatable {
        public var id: Int64
        public var info: EngineMessageHistoryThread.Info
        public var isOwnedByMe: Bool
        public var isClosed: Bool
        
        public init(id: Int64, info: EngineMessageHistoryThread.Info, isOwnedByMe: Bool, isClosed: Bool) {
            self.id = id
            self.info = info
            self.isOwnedByMe = isOwnedByMe
            self.isClosed = isClosed
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

    case peer(messages: [EngineMessage], peer: EngineRenderedPeer, threadInfo: ThreadInfo?, combinedReadState: EnginePeerReadCounters?, isRemovedFromTotalUnreadCount: Bool, presence: EnginePeer.Presence?, hasUnseenMentions: Bool, hasUnseenReactions: Bool, draftState: DraftState?, inputActivities: [(EnginePeer, PeerInputActivity)]?, promoInfo: ChatListNodeEntryPromoInfo?, ignoreUnreadBadge: Bool, displayAsMessage: Bool, hasFailedMessages: Bool, forumTopicData: EngineChatList.ForumTopicData?)
    case groupReference(groupId: EngineChatList.Group, peers: [EngineChatList.GroupItem.Item], message: EngineMessage?, unreadCount: Int, hiddenByDefault: Bool)
    
    public var chatLocation: ChatLocation? {
        switch self {
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _, _, _, _):
                return .peer(id: peer.peerId)
            case .groupReference:
                return nil
        }
    }
}

public class ChatListItem: ListViewItem, ChatListSearchItemNeighbour {
    let presentationData: ChatListPresentationData
    let context: AccountContext
    let chatListLocation: ChatListControllerLocation
    let filterData: ChatListItemFilterData?
    let index: EngineChatList.Item.Index
    public let content: ChatListItemContent
    let editing: Bool
    let hasActiveRevealControls: Bool
    let selected: Bool
    let enableContextActions: Bool
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
        case .forum:
            return false
        }
    }
    
    public init(presentationData: ChatListPresentationData, context: AccountContext, chatListLocation: ChatListControllerLocation, filterData: ChatListItemFilterData?, index: EngineChatList.Item.Index, content: ChatListItemContent, editing: Bool, hasActiveRevealControls: Bool, selected: Bool, header: ListViewItemHeader?, enableContextActions: Bool, hiddenOffset: Bool, interaction: ChatListNodeInteraction) {
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
        self.enableContextActions = enableContextActions
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
            case let .peer(messages, peer, _, _, _, _, _, _, _, _, promoInfo, _, _, _, _):
                if let message = messages.last, let peer = peer.peer {
                    var threadId: Int64?
                    if case let .forum(_, _, threadIdValue, _, _) = self.index {
                        threadId = threadIdValue
                    }
                    self.interaction.messageSelected(peer, threadId, message, promoInfo)
                } else if let peer = peer.peer {
                    self.interaction.peerSelected(peer, nil, nil, promoInfo)
                } else if let peer = peer.peers[peer.peerId] {
                    self.interaction.peerSelected(peer, nil, nil, promoInfo)
                }
            case let .groupReference(groupId, _, _, _, _):
                self.interaction.groupSelected(groupId)
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
}

private func canArchivePeer(id: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Bool {
    if id.namespace == Namespaces.Peer.CloudUser && id.id._internalGetInt64Value() == 777000 {
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
        if case .chatList(.archive) = location {
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

private func forumRevealOptions(strings: PresentationStrings, theme: PresentationTheme, isMuted: Bool?, isClosed: Bool, isPinned: Bool, isEditing: Bool, canPin: Bool, canOpenClose: Bool, canDelete: Bool) -> [ItemListRevealOption] {
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
                if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
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

private let playIconImage = UIImage(bundleImageName: "Chat List/MiniThumbnailPlay")?.precomposed()

private final class ChatListMediaPreviewNode: ASDisplayNode {
    private let context: AccountContext
    private let message: EngineMessage
    private let media: EngineMedia
    
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
        
        var isRound = false
        var dimensions = CGSize(width: 100.0, height: 100.0)
        if case let .image(image) = self.media {
            self.playIcon.isHidden = true
            if let largest = largestImageRepresentation(image.representations) {
                dimensions = largest.dimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessagePhoto(account: self.context.account, photoReference: .message(message: MessageReference(self.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 36.0, height: 36.0), synchronousLoad: synchronousLoads)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        } else if case let .file(file) = self.media {
            if file.isInstantVideo {
                isRound = true
            }
            if file.isAnimated {
                self.playIcon.isHidden = true
            } else {
                self.playIcon.isHidden = false
            }
            if let mediaDimensions = file.dimensions {
                dimensions = mediaDimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessageVideo(postbox: self.context.account.postbox, videoReference: .message(message: MessageReference(self.message._asMessage()), media: file), synchronousLoad: synchronousLoads, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true)
                    self.imageNode.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        }
        
        let makeLayout = self.imageNode.asyncLayout()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: isRound ? size.width / 2.0 : 2.0), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()
    }
}

private let maxVideoLoopCount = 3

class ChatListItemNode: ItemListRevealOptionsItemNode {
    final class AuthorNode: ASDisplayNode {
        let authorNode: TextNode
        var titleTopicArrowNode: ASImageNode?
        var topicTitleNode: TextNode?
        var titleTopicIconView: ComponentHostView<Empty>?
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
        
        override init() {
            self.authorNode = TextNode()
            self.authorNode.displaysAsynchronously = true
            
            super.init()
            
            self.addSubnode(self.authorNode)
        }
        
        func asyncLayout() -> (_ context: AccountContext, _ constrainedWidth: CGFloat, _ theme: PresentationTheme, _ authorTitle: NSAttributedString?, _ topic: (title: NSAttributedString, iconId: Int64?, iconColor: Int32)?) -> (CGSize, () -> Void) {
            let makeAuthorLayout = TextNode.asyncLayout(self.authorNode)
            let makeTopicTitleLayout = TextNode.asyncLayout(self.topicTitleNode)
            
            return { [weak self] context, constrainedWidth, theme, authorTitle, topic in
                var maxTitleWidth = constrainedWidth
                if let _ = topic {
                    maxTitleWidth = floor(constrainedWidth * 0.7)
                }
                
                let authorTitleLayout = makeAuthorLayout(TextNodeLayoutArguments(attributedString: authorTitle, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTitleWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
                
                var remainingWidth = constrainedWidth - authorTitleLayout.0.size.width
                
                var topicTitleArguments: TextNodeLayoutArguments?
                var arrowIconImage: UIImage?
                if let topic = topic {
                    remainingWidth -= 22.0 + 2.0
                    
                    if authorTitle != nil {
                        arrowIconImage = PresentationResourcesChatList.topicArrowIcon(theme)
                        if let arrowIconImage = arrowIconImage {
                            remainingWidth -= arrowIconImage.size.width + 6.0 * 2.0
                        }
                    }
                    
                    topicTitleArguments = TextNodeLayoutArguments(attributedString: topic.title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: remainingWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0))
                }
                
                let topicTitleLayout = topicTitleArguments.flatMap(makeTopicTitleLayout)
                
                var size = authorTitleLayout.0.size
                if let topicTitleLayout = topicTitleLayout {
                    size.height = max(size.height, topicTitleLayout.0.size.height)
                    size.width += 10.0 + topicTitleLayout.0.size.width
                }
                
                return (size, {
                    guard let self else {
                        return
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
                    
                    if let topic {
                        let titleTopicIconView: ComponentHostView<Empty>
                        if let current = self.titleTopicIconView {
                            titleTopicIconView = current
                        } else {
                            titleTopicIconView = ComponentHostView<Empty>()
                            self.titleTopicIconView = titleTopicIconView
                            self.view.addSubview(titleTopicIconView)
                        }
                        
                        let titleTopicIconContent: EmojiStatusComponent.Content
                        if let fileId = topic.iconId, fileId != 0 {
                            titleTopicIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 36.0, height: 36.0), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: theme.list.itemAccentColor, loopMode: .count(2))
                        } else {
                            titleTopicIconContent = .topic(title: String(topic.title.string.prefix(1)), color: topic.iconColor, size: CGSize(width: 22.0, height: 22.0))
                        }
                        
                        let titleTopicIconComponent = EmojiStatusComponent(
                            context: context,
                            animationCache: context.animationCache,
                            animationRenderer: context.animationRenderer,
                            content: titleTopicIconContent,
                            isVisibleForAnimations: self.visibilityStatus,
                            action: nil
                        )
                        self.titleTopicIconComponent = titleTopicIconComponent
                        
                        let iconSize = titleTopicIconView.update(
                            transition: .immediate,
                            component: AnyComponent(titleTopicIconComponent),
                            environment: {},
                            containerSize: CGSize(width: 22.0, height: 22.0)
                        )
                        titleTopicIconView.frame = CGRect(origin: CGPoint(x: nextX, y: UIScreenPixel), size: iconSize)
                        nextX += iconSize.width + 2.0
                    } else {
                        if let titleTopicIconView = self.titleTopicIconView {
                            self.titleTopicIconView = nil
                            titleTopicIconView.removeFromSuperview()
                        }
                    }
                    
                    if let topicTitleLayout = topicTitleLayout {
                        let topicTitleNode = topicTitleLayout.1()
                        if topicTitleNode.supernode == nil {
                            self.addSubnode(topicTitleNode)
                            self.topicTitleNode = topicTitleNode
                        }
                        
                        topicTitleNode.frame = CGRect(origin: CGPoint(x: nextX - 1.0, y: 0.0), size: topicTitleLayout.0.size)
                    } else if let topicTitleNode = self.topicTitleNode {
                        self.topicTitleNode = nil
                        topicTitleNode.removeFromSupernode()
                    }
                })
            }
        }
    }
    
    var item: ChatListItem?
    
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    let contextContainer: ContextControllerSourceNode
    
    let avatarNode: AvatarNode
    var avatarIconView: ComponentHostView<Empty>?
    var avatarIconComponent: EmojiStatusComponent?
    var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private let playbackStartDisposable = MetaDisposable()
    private var videoLoopCount = 0
    
    let titleNode: TextNode
    let authorNode: AuthorNode
    let measureNode: TextNode
    private var currentItemHeight: CGFloat?
    let textNode: TextNodeWithEntities
    var dustNode: InvisibleInkDustNode?
    let inputActivitiesNode: ChatListInputActivitiesNode
    let dateNode: TextNode
    var dateStatusIconNode: ASImageNode?
    let separatorNode: ASDisplayNode
    let statusNode: ChatListStatusNode
    let badgeNode: ChatListBadgeNode
    let mentionBadgeNode: ChatListBadgeNode
    let onlineNode: PeerOnlineMarkerNode
    let pinnedIconNode: ASImageNode
    var secretIconNode: ASImageNode?
    var credibilityIconView: ComponentHostView<Empty>?
    var credibilityIconComponent: EmojiStatusComponent?
    let mutedIconNode: ASImageNode
    
    private var hierarchyTrackingLayer: HierarchyTrackingLayer?
    private var cachedDataDisposable = MetaDisposable()
    
    private var currentTextLeftCutout: CGFloat = 0.0
    private var currentMediaPreviewSpecs: [(message: EngineMessage, media: EngineMedia, size: CGSize)] = []
    private var mediaPreviewNodes: [EngineMedia.Id: ChatListMediaPreviewNode] = [:]
    
    var selectableControlNode: ItemListSelectableControlNode?
    var reorderControlNode: ItemListEditableReorderControlNode?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    
    private var cachedChatListText: (String, String)?
    private var cachedChatListSearchResult: CachedChatListSearchResult?
    
    var layoutParams: (ChatListItem, first: Bool, last: Bool, firstWithHeader: Bool, nextIsPinned: Bool, ListViewItemLayoutParams, countersSize: CGFloat)?
    
    private var isHighlighted: Bool = false
    private var skipFadeout: Bool = false
    
    private var onlineIsVoiceChat: Bool = false
    
    override var canBeSelected: Bool {
        if self.selectableControlNode != nil || self.item?.editing == true {
            return false
        } else {
            return super.canBeSelected
        }
    }
    
    override var defaultAccessibilityLabel: String? {
        get {
            return self.accessibilityLabel
        } set(value) {
        }
    }
    override var accessibilityAttributedLabel: NSAttributedString? {
        get {
            return self.accessibilityLabel.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    override var accessibilityAttributedValue: NSAttributedString? {
        get {
            return self.accessibilityValue.flatMap(NSAttributedString.init(string:))
        } set(value) {
        }
    }
    
    override var accessibilityLabel: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case let .groupReference(_, _, _, unreadCount, _):
                    var result = item.presentationData.strings.ChatList_ArchivedChatsTitle
                    let allCount = unreadCount
                    if allCount > 0 {
                        result += "\n\(item.presentationData.strings.VoiceOver_Chat_UnreadMessages(Int32(allCount)))"
                    }
                    return result
                case let .peer(_, peer, _, combinedReadState, _, _, _, _, _, _, _, _, _, _, _):
                    guard let chatMainPeer = peer.chatMainPeer else {
                        return nil
                    }
                    var result = ""
                    if item.context.account.peerId == chatMainPeer.id {
                        result += item.presentationData.strings.DialogList_SavedMessages
                    } else {
                        result += chatMainPeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    }
                    if let combinedReadState = combinedReadState, combinedReadState.count > 0 {
                        result += "\n\(item.presentationData.strings.VoiceOver_Chat_UnreadMessages(combinedReadState.count))"
                    }
                    return result
            }
        } set(value) {
        }
    }
    
    override var accessibilityValue: String? {
        get {
            guard let item = self.item else {
                return nil
            }
            switch item.content {
                case let .groupReference(_, peers, messageValue, _, _):
                    if let message = messageValue, let peer = peers.first?.peer {
                        let messages = [message]
                        var result = ""
                        if message.flags.contains(.Incoming) {
                            result += item.presentationData.strings.VoiceOver_ChatList_Message
                        } else {
                            result += item.presentationData.strings.VoiceOver_ChatList_OutgoingMessage
                        }
                        let (_, initialHideAuthor, messageText, _, _) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, messages: messages, chatPeer: peer, accountPeerId: item.context.account.peerId, isPeerGroup: false)
                        if message.flags.contains(.Incoming), !initialHideAuthor, let author = message.author, case .user = author {
                            result += "\n\(item.presentationData.strings.VoiceOver_ChatList_MessageFrom(author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)).string)"
                        }
                        result += "\n\(messageText)"
                        return result
                    } else if !peers.isEmpty {
                        var result = ""
                        var isFirst = true
                        for peer in peers {
                            if let chatMainPeer = peer.peer.chatMainPeer {
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
                case let .peer(messages, peer, _, combinedReadState, _, _, _, _, _, _, _, _, _, _, _):
                    if let message = messages.last {
                        var result = ""
                        if message.flags.contains(.Incoming) {
                            result += item.presentationData.strings.VoiceOver_ChatList_Message
                        } else {
                            result += item.presentationData.strings.VoiceOver_ChatList_OutgoingMessage
                        }
                        let (_, initialHideAuthor, messageText, _, _) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, messages: messages, chatPeer: peer, accountPeerId: item.context.account.peerId, isPeerGroup: false)
                        if message.flags.contains(.Incoming), !initialHideAuthor, let author = message.author, case .user = author {
                            result += "\n\(item.presentationData.strings.VoiceOver_ChatList_MessageFrom(author.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)).string)"
                        }
                        if !message.flags.contains(.Incoming), let combinedReadState = combinedReadState, combinedReadState.isOutgoingMessageIndexRead(message.index) {
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
    
    override var visibility: ListViewItemNodeVisibility {
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
                    self.videoLoopCount = 0
                }
                self.updateVideoVisibility()
                
                self.textNode.visibilityRect = self.visibilityStatus ? CGRect.infinite : nil
                
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
            }
        }
    }
    
    private var trackingIsInHierarchy: Bool = false {
        didSet {
            if self.trackingIsInHierarchy != oldValue {
                Queue.mainQueue().justDispatch {
                    if self.trackingIsInHierarchy {
                        self.videoLoopCount = 0
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
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.contextContainer = ContextControllerSourceNode()
        
        self.measureNode = TextNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = true
        
        self.authorNode = AuthorNode()
        self.authorNode.isUserInteractionEnabled = false
        
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.displaysAsynchronously = true
        
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
        
        self.contextContainer.addSubnode(self.avatarNode)
        self.contextContainer.addSubnode(self.onlineNode)
        
        self.contextContainer.addSubnode(self.titleNode)
        self.contextContainer.addSubnode(self.authorNode)
        self.contextContainer.addSubnode(self.textNode.textNode)
        self.contextContainer.addSubnode(self.dateNode)
        self.contextContainer.addSubnode(self.statusNode)
        self.contextContainer.addSubnode(self.pinnedIconNode)
        self.contextContainer.addSubnode(self.badgeNode)
        self.contextContainer.addSubnode(self.mentionBadgeNode)
        self.contextContainer.addSubnode(self.mutedIconNode)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.5, layoutParams.1, layoutParams.2, layoutParams.3, layoutParams.4)
                let _ = apply(false, false)
            }
        })
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.interaction.activateChatPreview(item, strongSelf.contextContainer, gesture, nil)
        }
    }
    
    deinit {
        self.cachedDataDisposable.dispose()
        self.playbackStartDisposable.dispose()
    }
    
    override func secondaryAction(at point: CGPoint) {
        guard let item = self.item else {
            return
        }
        item.interaction.activateChatPreview(item, self.contextContainer, nil, point)
    }
    
    func setupItem(item: ChatListItem, synchronousLoads: Bool) {
        let previousItem = self.item
        self.item = item
        
        var peer: EnginePeer?
        var displayAsMessage = false
        var enablePreview = true
        switch item.content {
            case let .peer(messages, peerValue, _, _, _, _, _, _, _, _, _, _, displayAsMessageValue, _, _):
                displayAsMessage = displayAsMessageValue
                if displayAsMessage, case let .user(author) = messages.last?.author {
                    peer = .user(author)
                } else {
                    peer = peerValue.chatMainPeer
                }
                if peerValue.peerId.namespace == Namespaces.Peer.SecretChat {
                    enablePreview = false
                }
            case let .groupReference(_, _, _, _, hiddenByDefault):
                if let previousItem = previousItem, case let .groupReference(_, _, _, _, previousHiddenByDefault) = previousItem.content, hiddenByDefault != previousHiddenByDefault {
                    UIView.transition(with: self.avatarNode.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                }
                self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: .archivedChatsIcon(hiddenByDefault: hiddenByDefault), emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoads)
        }
        
        if let peer = peer {
            var overrideImage: AvatarNodeImageOverride?
            if peer.id.isReplies {
                overrideImage = .repliesIcon
            } else if peer.id == item.context.account.peerId && !displayAsMessage {
                overrideImage = .savedMessagesIcon
            } else if peer.isDeleted {
                overrideImage = .deletedIcon
            }
            var isForum = false
            if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                isForum = true
            }
            self.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, clipStyle: isForum ? .roundedRect : .round, synchronousLoad: synchronousLoads, displayDimensions: CGSize(width: 60.0, height: 60.0))
            
            if peer.isPremium && peer.id != item.context.account.peerId {
                let context = item.context
                self.cachedDataDisposable.set((context.account.postbox.peerView(id: peer.id)
                |> deliverOnMainQueue).start(next: { [weak self] peerView in
                    guard let strongSelf = self else {
                        return
                    }
                    let cachedPeerData = peerView.cachedData
                    if let cachedPeerData = cachedPeerData as? CachedUserData {
                        if let photo = cachedPeerData.photo, let video = smallestVideoRepresentation(photo.videoRepresentations), let peerReference = PeerReference(peer._asPeer()) {
                            let videoId = photo.id?.id ?? peer.id.id._internalGetInt64Value()
                            let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: photo.representations, videoThumbnails: [], immediateThumbnailData: photo.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [])]))
                            let videoContent = NativeVideoContent(id: .profileVideo(videoId, nil), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, captureProtected: false)
                            if videoContent.id != strongSelf.videoContent?.id {
                                strongSelf.videoNode?.removeFromSupernode()
                                strongSelf.videoContent = videoContent
                            }
                            
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
                            strongSelf.videoContent = nil
                            
                            strongSelf.hierarchyTrackingLayer?.removeFromSuperlayer()
                            strongSelf.hierarchyTrackingLayer = nil
                        }
                                                
                        strongSelf.updateVideoVisibility()
                    } else {
                        let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).start()
                    }
                }))
            } else {
                self.cachedDataDisposable.set(nil)
                self.videoContent = nil
                
                self.videoNode?.removeFromSupernode()
                self.videoNode = nil
                
                self.hierarchyTrackingLayer?.removeFromSuperlayer()
                self.hierarchyTrackingLayer = nil
            }
        }
        
        self.contextContainer.isGestureEnabled = enablePreview && !item.editing
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
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
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
            
            if let item = self.item, case .chatList = item.index {
                self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted, voiceChat: self.onlineIsVoiceChat), color: nil, transition: transition)
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
            
            if let item = self.item, case let .chatList(index) = item.index {
                let onlineIcon: UIImage?
                if index.pinningIndex != nil {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned, voiceChat: self.onlineIsVoiceChat)
                } else {
                    onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular, voiceChat: self.onlineIsVoiceChat)
                }
                self.onlineNode.setImage(onlineIcon, color: nil, transition: transition)
            }
        }
    }
    
    override func tapped() {
        guard let item = self.item, item.editing else {
            return
        }
        if case let .peer(_, peer, _, _, _, _, _, _, _, _, promoInfo, _, _, _, _) = item.content {
            if promoInfo == nil, let mainPeer = peer.peer {
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
        let titleLayout = TextNode.asyncLayout(self.titleNode)
        let authorLayout = self.authorNode.asyncLayout()
        let makeMeasureLayout = TextNode.asyncLayout(self.measureNode)
        let inputActivitiesLayout = self.inputActivitiesNode.asyncLayout()
        let badgeLayout = self.badgeNode.asyncLayout()
        let mentionBadgeLayout = self.mentionBadgeNode.asyncLayout()
        let onlineLayout = self.onlineNode.asyncLayout()
        let selectableControlLayout = ItemListSelectableControlNode.asyncLayout(self.selectableControlNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        
        let currentItem = self.layoutParams?.0
        let currentChatListText = self.cachedChatListText
        let currentChatListSearchResult = self.cachedChatListSearchResult
        
        return { item, params, first, last, firstWithHeader, nextIsPinned in
            let titleFont = Font.medium(floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let badgeFont = Font.with(size: floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
            
            let account = item.context.account
            var messages: [EngineMessage]
            enum ContentPeer {
                case chat(EngineRenderedPeer)
                case group([EngineChatList.GroupItem.Item])
            }
            let contentPeer: ContentPeer
            let combinedReadState: EnginePeerReadCounters?
            let unreadCount: (count: Int32, unread: Bool, muted: Bool, mutedCount: Int32?)
            let isRemovedFromTotalUnreadCount: Bool
            let peerPresence: EnginePeer.Presence?
            let draftState: ChatListItemContent.DraftState?
            let hasUnseenMentions: Bool
            let hasUnseenReactions: Bool
            let inputActivities: [(EnginePeer, PeerInputActivity)]?
            let isPeerGroup: Bool
            let promoInfo: ChatListNodeEntryPromoInfo?
            let displayAsMessage: Bool
            let hasFailedMessages: Bool
            var threadInfo: ChatListItemContent.ThreadInfo?
            var forumTopicData: EngineChatList.ForumTopicData?
            
            var groupHiddenByDefault = false
            
            switch item.content {
                case let .peer(messagesValue, peerValue, threadInfoValue, combinedReadStateValue, isRemovedFromTotalUnreadCountValue, peerPresenceValue, hasUnseenMentionsValue, hasUnseenReactionsValue, draftStateValue, inputActivitiesValue, promoInfoValue, ignoreUnreadBadge, displayAsMessageValue, _, forumTopicDataValue):
                    messages = messagesValue
                    contentPeer = .chat(peerValue)
                    combinedReadState = combinedReadStateValue
                    if let combinedReadState = combinedReadState, promoInfoValue == nil && !ignoreUnreadBadge {
                        unreadCount = (combinedReadState.count, combinedReadState.isUnread, isRemovedFromTotalUnreadCountValue || combinedReadState.isMuted, nil)
                    } else {
                        unreadCount = (0, false, false, nil)
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
                    threadInfo = threadInfoValue
                    hasUnseenMentions = hasUnseenMentionsValue
                    hasUnseenReactions = hasUnseenReactionsValue
                    forumTopicData = forumTopicDataValue
                    
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
                case let .groupReference(_, peers, messageValue, unreadCountValue, hiddenByDefault):
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
                    hasUnseenMentions = false
                    hasUnseenReactions = false
                    inputActivities = nil
                    isPeerGroup = true
                    groupHiddenByDefault = hiddenByDefault
                    unreadCount = (Int32(unreadCountValue), unreadCountValue != 0, true, nil)
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
            var badgeContent = ChatListBadgeContent.none
            var mentionBadgeContent = ChatListBadgeContent.none
            var statusState = ChatListStatusNodeState.none
            
            var currentBadgeBackgroundImage: UIImage?
            var currentMentionBadgeImage: UIImage?
            var currentPinnedIconImage: UIImage?
            var currentMutedIconImage: UIImage?
            var currentCredibilityIconContent: EmojiStatusComponent.Content?
            var currentSecretIconImage: UIImage?
            
            var selectableControlSizeAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            var reorderControlSizeAndApply: (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode)?
            
            let editingOffset: CGFloat
            var reorderInset: CGFloat = 0.0
            if item.editing {
                let sizeAndApply = selectableControlLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, item.selected, true)
                if promoInfo == nil && !isPeerGroup {
                    selectableControlSizeAndApply = sizeAndApply
                }
                editingOffset = sizeAndApply.0
                
                if case let .chatList(index) = item.index, index.pinningIndex != nil, promoInfo == nil, !isPeerGroup {
                    let sizeAndApply = reorderControlLayout(item.presentationData.theme)
                    reorderControlSizeAndApply = sizeAndApply
                    reorderInset = sizeAndApply.0
                }
            } else {
                editingOffset = 0.0
            }
            
            let enableChatListPhotos = true
            
            let avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            
            let avatarLeftInset: CGFloat
            if case .forum = item.index {
                avatarLeftInset = 50.0
            } else {
                avatarLeftInset = 18.0 + avatarDiameter
            }
            
            let badgeDiameter = floor(item.presentationData.fontSize.baseDisplaySize * 20.0 / 17.0)
            
            let leftInset: CGFloat = params.leftInset + avatarLeftInset
            
            enum ContentData {
                case chat(itemPeer: EngineRenderedPeer, threadInfo: ChatListItemContent.ThreadInfo?, peer: EnginePeer?, hideAuthor: Bool, messageText: String, spoilers: [NSRange]?, customEmojiRanges: [(NSRange, ChatTextInputTextCustomEmojiAttribute)]?)
                case group(peers: [EngineChatList.GroupItem.Item])
            }
            
            let contentData: ContentData
            
            var hideAuthor = false
            switch contentPeer {
                case let .chat(itemPeer):
                    var (peer, initialHideAuthor, messageText, spoilers, customEmojiRanges) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, messages: messages, chatPeer: itemPeer, accountPeerId: item.context.account.peerId, enableMediaEmoji: !enableChatListPhotos, isPeerGroup: isPeerGroup)
                    
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
            
            let attributedText: NSAttributedString
            var hasDraft = false
            
            var inlineAuthorPrefix: String?
            if case .groupReference = item.content {
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
            
            let contentImageSide: CGFloat = max(10.0, min(20.0, floor(item.presentationData.fontSize.baseDisplaySize * 18.0 / 17.0)))
            let contentImageSize = CGSize(width: contentImageSide, height: contentImageSide)
            let contentImageSpacing: CGFloat = 2.0
            let contentImageTrailingSpace: CGFloat = 5.0
            var contentImageSpecs: [(message: EngineMessage, media: EngineMedia, size: CGSize)] = []
            var forumThread: (title: String, iconId: Int64?, iconColor: Int32)?
            
            switch contentData {
                case let .chat(itemPeer, _, _, _, text, spoilers, customEmojiRanges):
                    var isUser = false
                    if case .user = itemPeer.chatMainPeer {
                        isUser = true
                    }

                    var peerText: String?
                    if case .groupReference = item.content {
                        if let messagePeer = itemPeer.chatMainPeer {
                            peerText = messagePeer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                        }
                    } else if let message = messages.last, let author = message.author?._asPeer(), let peer = itemPeer.chatMainPeer, !isUser {
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
                
                    if let _ = peerText, case let .channel(channel) = itemPeer.chatMainPeer, channel.flags.contains(.isForum), threadInfo == nil {
                        if let forumTopicData = forumTopicData {
                            forumThread = (forumTopicData.title, forumTopicData.iconFileId, forumTopicData.iconColor)
                        } else if let threadInfo = threadInfo?.info {
                            forumThread = (threadInfo.title, threadInfo.icon, threadInfo.iconColor)
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
                    
                    if inlineAuthorPrefix == nil, let draftState = draftState {
                        hasDraft = true
                        authorAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Draft, font: textFont, textColor: theme.messageDraftTextColor)
                        
                        let draftText = stringWithAppliedEntities(draftState.text, entities: draftState.entities, baseColor: theme.messageTextColor, linkColor: theme.messageTextColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, message: nil)
                        
                        attributedText = foldLineBreaks(draftText)
                    } else if let message = messages.first {
                        var composedString: NSMutableAttributedString
                        
                        if let peerText = peerText {
                            authorAttributedString = NSAttributedString(string: peerText, font: textFont, textColor: theme.authorNameColor)
                        }
                        
                        let entities = (message._asMessage().textEntitiesAttribute?.entities ?? []).filter { entity in
                            switch entity.type {
                            case .Spoiler, .CustomEmoji:
                                return true
                            default:
                                return false
                            }
                        }
                        let messageString: NSAttributedString
                        if !message.text.isEmpty && entities.count > 0 {
                            messageString = stringWithAppliedEntities(trimToLineCount(message.text, lineCount: authorAttributedString == nil ? 2 : 1), entities: entities, baseColor: theme.messageTextColor, linkColor: theme.messageTextColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message._asMessage())
                        } else if spoilers != nil || customEmojiRanges != nil {
                            let mutableString = NSMutableAttributedString(string: messageText, font: textFont, textColor: theme.messageTextColor)
                            if let spoilers = spoilers {
                                for range in spoilers {
                                    mutableString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true, range: range)
                                }
                            }
                            if let customEmojiRanges = customEmojiRanges {
                                for (range, attribute) in customEmojiRanges {
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
                        
                        if let searchQuery = item.interaction.searchTextHighightState {
                            if let cached = currentChatListSearchResult, cached.matches(text: composedString.string, searchQuery: searchQuery) {
                                chatListSearchResult = cached
                            } else {
                                let (ranges, text) = findSubstringRanges(in: composedString.string, query: searchQuery)
                                chatListSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                            }
                        } else {
                            chatListSearchResult = nil
                        }
                        
                        if let chatListSearchResult = chatListSearchResult, let firstRange = chatListSearchResult.resultRanges.first {
                            for range in chatListSearchResult.resultRanges {
                                let stringRange = NSRange(range, in: chatListSearchResult.text)
                                if stringRange.location >= 0 && stringRange.location + stringRange.length <= composedString.length {
                                    composedString.addAttribute(.foregroundColor, value: theme.messageHighlightedTextColor, range: stringRange)
                                }
                            }
                            
                            let firstRangeOrigin = chatListSearchResult.text.distance(from: chatListSearchResult.text.startIndex, to: firstRange.lowerBound)
                            if firstRangeOrigin > 24 {
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
                        }
                        
                        attributedText = composedString
                        
                        var displayMediaPreviews = true
                        if message._asMessage().containsSecretMedia {
                            displayMediaPreviews = false
                        } else if let _ = message.peers[message.id.peerId] as? TelegramSecretChat {
                            displayMediaPreviews = false
                        }
                        if displayMediaPreviews {
                            let contentImageFillSize = CGSize(width: 8.0, height: contentImageSize.height)
                            _ = contentImageFillSize
                            for message in messages {
                                if contentImageSpecs.count >= 3 {
                                    break
                                }
                                inner: for media in message.media {
                                    if let image = media as? TelegramMediaImage {
                                        if let _ = largestImageRepresentation(image.representations) {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append((message, .image(image), fitSize))
                                        }
                                        break inner
                                    } else if let file = media as? TelegramMediaFile {
                                        if file.isVideo, !file.isVideoSticker, let _ = file.dimensions {
                                            let fitSize = contentImageSize
                                            contentImageSpecs.append((message, .file(file), fitSize))
                                        }
                                        break inner
                                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                        let imageTypes = ["photo", "video", "embed", "gif", "document", "telegram_album"]
                                        if let image = content.image, let type = content.type, imageTypes.contains(type) {
                                            if let _ = largestImageRepresentation(image.representations) {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append((message, .image(image), fitSize))
                                            }
                                            break inner
                                        } else if let file = content.file {
                                            if file.isVideo, !file.isInstantVideo, let _ = file.dimensions {
                                                let fitSize = contentImageSize
                                                contentImageSpecs.append((message, .file(file), fitSize))
                                            }
                                            break inner
                                        }
                                    }
                                }
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
                    attributedText = textString
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
                    if let threadInfo = threadInfo {
                        titleAttributedString = NSAttributedString(string: threadInfo.info.title, font: titleFont, textColor: theme.titleColor)
                    } else if let message = messages.last, case let .user(author) = message.author, displayAsMessage {
                        titleAttributedString = NSAttributedString(string: author.id == account.peerId ? item.presentationData.strings.DialogList_You : EnginePeer.user(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: titleFont, textColor: theme.titleColor)
                    } else if isPeerGroup {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.ChatList_ArchivedChatsTitle, font: titleFont, textColor: theme.titleColor)
                    } else if itemPeer.chatMainPeer?.id == item.context.account.peerId {
                        titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_SavedMessages, font: titleFont, textColor: theme.titleColor)
                    } else if let id = itemPeer.chatMainPeer?.id, id.isReplies {
                         titleAttributedString = NSAttributedString(string: item.presentationData.strings.DialogList_Replies, font: titleFont, textColor: theme.titleColor)
                    } else if let displayTitle = itemPeer.chatMainPeer?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder) {
                        let textColor: UIColor
                        if case let .chatList(index) = item.index, index.messageIndex.id.peerId.namespace == Namespaces.Peer.SecretChat {
                            textColor = theme.secretTitleColor
                        } else {
                            textColor = theme.titleColor
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
            case let .groupReference(_, _, message, _, _):
                topIndex = message?.index
            case let .peer(messages, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                topIndex = messages.first?.index
            }
            if let topIndex {
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
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.presentationData.theme, diameter: badgeDiameter)
                        badgeTextColor = theme.unreadBadgeInactiveTextColor
                    } else {
                        currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.presentationData.theme, diameter: badgeDiameter)
                        badgeTextColor = theme.unreadBadgeActiveTextColor
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
                } else if case let .chatList(chatListIndex) = item.index, chatListIndex.pinningIndex != nil, promoInfo == nil, currentBadgeBackgroundImage == nil {
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
            if !isPeerGroup && !isAccountPeer {
                if displayAsMessage {
                    switch item.content {
                    case let .peer(messages, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                        if let peer = messages.last?.author {
                            if case let .user(user) = peer, let emojiStatus = user.emojiStatus, !premiumConfiguration.isPremiumDisabled {
                                currentCredibilityIconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                            } else if peer.isScam {
                                currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                            } else if peer.isFake {
                                currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                            } else if peer.isVerified {
                                currentCredibilityIconContent = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                            } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                                currentCredibilityIconContent = .premium(color: item.presentationData.theme.list.itemAccentColor)
                            }
                        }
                    default:
                        break
                    }
                } else if case let .chat(itemPeer) = contentPeer, let peer = itemPeer.chatMainPeer {
                    if case let .user(user) = peer, let emojiStatus = user.emojiStatus, !premiumConfiguration.isPremiumDisabled {
                        currentCredibilityIconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 32.0, height: 32.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .count(2))
                    } else if peer.isScam {
                        currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased())
                    } else if peer.isFake {
                        currentCredibilityIconContent = .text(color: item.presentationData.theme.chat.message.incoming.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased())
                    } else if peer.isVerified {
                        currentCredibilityIconContent = .verified(fillColor: item.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
                    } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled {
                        currentCredibilityIconContent = .premium(color: item.presentationData.theme.list.itemAccentColor)
                    }
                }
            }
            if let currentSecretIconImage = currentSecretIconImage {
                titleIconsWidth += currentSecretIconImage.size.width + 2.0
            }
            if let currentCredibilityIconContent = currentCredibilityIconContent {
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
            
            let layoutOffset: CGFloat = 0.0
            
            let rawContentWidth = params.width - leftInset - params.rightInset - 10.0 - editingOffset
            
            let (dateLayout, dateApply) = dateLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (badgeLayout, badgeApply) = badgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentBadgeBackgroundImage, badgeContent)
            
            let (mentionBadgeLayout, mentionBadgeApply) = mentionBadgeLayout(CGSize(width: rawContentWidth, height: CGFloat.greatestFiniteMagnitude), badgeDiameter, badgeFont, currentMentionBadgeImage, mentionBadgeContent)
            
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
            badgeSize = max(badgeSize, reorderInset)
            
            var effectiveAuthorTitle = (hideAuthor && !hasDraft) ? nil : authorAttributedString
            
            var forumThreadTitle: (title: NSAttributedString, iconId: Int64?, iconColor: Int32)?
            if let _ = effectiveAuthorTitle, let forumThread {
                if authorIsCurrentChat {
                    effectiveAuthorTitle = nil
                }
                forumThreadTitle = (NSAttributedString(string: forumThread.title, font: textFont, textColor: theme.authorNameColor), forumThread.iconId, forumThread.iconColor)
            }
            let (authorLayout, authorApply) = authorLayout(item.context, rawContentWidth - badgeSize, item.presentationData.theme, effectiveAuthorTitle, forumThreadTitle)
            
            var textCutout: TextNodeCutout?
            if !textLeftCutout.isZero {
                textCutout = TextNodeCutout(topLeft: CGSize(width: textLeftCutout, height: 10.0), topRight: nil, bottomRight: nil)
            }
            let (textLayout, textApply) = textLayout(TextNodeLayoutArguments(attributedString: textAttributedString, backgroundColor: nil, maximumNumberOfLines: authorAttributedString == nil ? 2 : 1, truncationType: .end, constrainedSize: CGSize(width: rawContentWidth - badgeSize, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: textCutout, insets: UIEdgeInsets(top: 2.0, left: 1.0, bottom: 2.0, right: 1.0)))
            
            let maxTitleLines: Int
            switch item.index {
            case .forum:
                maxTitleLines = 2
            case .chatList:
                maxTitleLines = 1
            }
                        
            let titleRectWidth = rawContentWidth - dateLayout.size.width - 10.0 - statusWidth - titleIconsWidth
            let (titleLayout, titleApply) = titleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: maxTitleLines, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
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

            let peerRevealOptions: [ItemListRevealOption]
            let peerLeftRevealOptions: [ItemListRevealOption]
            switch item.content {
                case let .peer(_, renderedPeer, _, _, _, presence, _, _, _, _, _, _, displayAsMessage, _, _):
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
                    
                    if item.enableContextActions {
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
                                peerRevealOptions = forumRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isMuted: (currentMutedIconImage != nil), isClosed: isClosed, isPinned: isPinned, isEditing: item.editing, canPin: channel.flags.contains(.isCreator) || channel.adminRights != nil, canOpenClose: canOpenClose, canDelete: canDelete)
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
                    } else {
                        peerRevealOptions = []
                        peerLeftRevealOptions = []
                    }
                case .groupReference:
                    peerRevealOptions = groupReferenceRevealOptions(strings: item.presentationData.strings, theme: item.presentationData.theme, isEditing: item.editing, hiddenByDefault: groupHiddenByDefault)
                    peerLeftRevealOptions = []
            }
            
            let (onlineLayout, onlineApply) = onlineLayout(online, onlineIsVoiceChat)
            var animateContent = false
            if let currentItem = currentItem, currentItem.content.chatLocation == item.content.chatLocation {
                animateContent = true
            }
            
            let (measureLayout, measureApply) = makeMeasureLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleRectWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleSpacing: CGFloat = -1.0
            let authorSpacing: CGFloat = -3.0
            var itemHeight: CGFloat = 8.0 * 2.0 + 1.0
            itemHeight -= 21.0
            itemHeight += titleLayout.size.height
            itemHeight += measureLayout.size.height * 3.0
            itemHeight += titleSpacing
            itemHeight += authorSpacing
                        
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: layoutOffset + 8.0), size: CGSize(width: rawContentWidth, height: itemHeight - 12.0 - 9.0))
            
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
                    strongSelf.onlineIsVoiceChat = onlineIsVoiceChat
                    
                    strongSelf.contextContainer.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                   
                    if case .groupReference = item.content {
                        strongSelf.layer.sublayerTransform = CATransform3DMakeTranslation(0.0, layout.contentSize.height - itemHeight, 0.0)
                    }
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.presentationData.theme.chatList.itemSeparatorColor
                    }
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
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
                    transition.updateFrame(node: strongSelf.avatarNode, frame: avatarFrame)
                    strongSelf.updateVideoVisibility()
                    
                    if let threadInfo = threadInfo {
                        let avatarIconView: ComponentHostView<Empty>
                        if let current = strongSelf.avatarIconView {
                            avatarIconView = current
                        } else {
                            avatarIconView = ComponentHostView<Empty>()
                            strongSelf.avatarIconView = avatarIconView
                            strongSelf.contextContainer.view.addSubview(avatarIconView)
                        }
                        
                        let avatarIconContent: EmojiStatusComponent.Content
                        if let fileId = threadInfo.info.icon, fileId != 0 {
                            avatarIconContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 48.0, height: 48.0), placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor, themeColor: item.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                        } else {
                            avatarIconContent = .topic(title: String(threadInfo.info.title.prefix(1)), color: threadInfo.info.iconColor, size: CGSize(width: 32.0, height: 32.0))
                        }
                        
                        let avatarIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: avatarIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus,
                            action: nil
                        )
                        strongSelf.avatarIconComponent = avatarIconComponent
                        
                        let iconSize = avatarIconView.update(
                            transition: .immediate,
                            component: AnyComponent(avatarIconComponent),
                            environment: {},
                            containerSize: CGSize(width: 32.0, height: 32.0)
                        )
                        transition.updateFrame(view: avatarIconView, frame: CGRect(origin: CGPoint(x: editingOffset + params.leftInset + floor((leftInset - params.leftInset - iconSize.width) / 2.0) + revealOffset, y: contentRect.origin.y + 2.0), size: iconSize))
                    } else if let avatarIconView = strongSelf.avatarIconView {
                        strongSelf.avatarIconView = nil
                        avatarIconView.removeFromSuperview()
                    }
                    
                    if case .forum = item.index {
                        strongSelf.avatarNode.isHidden = true
                    } else {
                        strongSelf.avatarNode.isHidden = false
                    }
                    
                    let onlineFrame: CGRect
                    if onlineIsVoiceChat {
                        onlineFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX - onlineLayout.width + 1.0 - UIScreenPixel, y: avatarFrame.maxY - onlineLayout.height + 1.0 - UIScreenPixel), size: onlineLayout)
                    } else {
                        onlineFrame = CGRect(origin: CGPoint(x: avatarFrame.maxX - onlineLayout.width - 2.0, y: avatarFrame.maxY - onlineLayout.height - 2.0), size: onlineLayout)
                    }
                    transition.updateFrame(node: strongSelf.onlineNode, frame: onlineFrame)
                    
                    let onlineIcon: UIImage?
                    if strongSelf.reallyHighlighted {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .highlighted, voiceChat: onlineIsVoiceChat)
                    } else if case let .chatList(index) = item.index, index.pinningIndex != nil {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .pinned, voiceChat: onlineIsVoiceChat)
                    } else {
                        onlineIcon = PresentationResourcesChatList.recentStatusOnlineIcon(item.presentationData.theme, state: .regular, voiceChat: onlineIsVoiceChat)
                    }
                    strongSelf.onlineNode.setImage(onlineIcon, color: item.presentationData.theme.list.itemCheckColors.foregroundColor, transition: .immediate)
                                  
                    let _ = measureApply()
                    let _ = dateApply()
                    
                    let _ = textApply(TextNodeWithEntities.Arguments(
                        context: item.context,
                        cache: item.interaction.animationCache,
                        renderer: item.interaction.animationRenderer,
                        placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor,
                        attemptSynchronous: synchronousLoads
                    ))
                    
                    let _ = authorApply()
                    let _ = titleApply()
                    let _ = badgeApply(animateBadges, !isMuted)
                    let _ = mentionBadgeApply(animateBadges, true)
                    let _ = onlineApply(animateContent && animateOnline)
                    
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateLayout.size.width, y: contentRect.origin.y + 2.0), size: dateLayout.size))
                    
                    var statusOffset: CGFloat = 0.0
                    if let dateIconImage {
                        statusOffset += 2.0 + dateIconImage.size.width + 4.0
                        
                        let dateStatusIconNode: ASImageNode
                        if let current = strongSelf.dateStatusIconNode {
                            dateStatusIconNode = current
                        } else {
                            dateStatusIconNode = ASImageNode()
                            strongSelf.dateStatusIconNode = dateStatusIconNode
                            strongSelf.contextContainer.addSubnode(dateStatusIconNode)
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
                    
                    if let _ = currentBadgeBackgroundImage {
                        let badgeFrame = CGRect(x: contentRect.maxX - badgeLayout.width, y: contentRect.maxY - badgeLayout.height - 2.0, width: badgeLayout.width, height: badgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.badgeNode, frame: badgeFrame)
                    }
                    
                    if currentMentionBadgeImage != nil || currentBadgeBackgroundImage != nil {
                        let mentionBadgeOffset: CGFloat
                        if badgeLayout.width.isZero {
                            mentionBadgeOffset = contentRect.maxX - mentionBadgeLayout.width
                        } else {
                            mentionBadgeOffset = contentRect.maxX - badgeLayout.width - 6.0 - mentionBadgeLayout.width
                        }
                        
                        let badgeFrame = CGRect(x: mentionBadgeOffset, y: contentRect.maxY - mentionBadgeLayout.height - 2.0, width: mentionBadgeLayout.width, height: mentionBadgeLayout.height)
                        
                        transition.updateFrame(node: strongSelf.mentionBadgeNode, frame: badgeFrame)
                    }
                    
                    if let currentPinnedIconImage = currentPinnedIconImage {
                        strongSelf.pinnedIconNode.image = currentPinnedIconImage
                        strongSelf.pinnedIconNode.isHidden = false
                        
                        let pinnedIconSize = currentPinnedIconImage.size
                        let pinnedIconFrame = CGRect(x: contentRect.maxX - pinnedIconSize.width, y: contentRect.maxY - pinnedIconSize.height - 2.0, width: pinnedIconSize.width, height: pinnedIconSize.height)
                        
                        strongSelf.pinnedIconNode.frame = pinnedIconFrame
                    } else {
                        strongSelf.pinnedIconNode.image = nil
                        strongSelf.pinnedIconNode.isHidden = true
                    }
                    
                    var titleOffset: CGFloat = 0.0
                    if let currentSecretIconImage = currentSecretIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.secretIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.contextContainer.addSubnode(iconNode)
                            strongSelf.secretIconNode = iconNode
                        }
                        iconNode.image = currentSecretIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: contentRect.origin.y + floor((titleLayout.size.height - currentSecretIconImage.size.height) / 2.0)), size: currentSecretIconImage.size))
                        titleOffset += currentSecretIconImage.size.width + 3.0
                    } else if let secretIconNode = strongSelf.secretIconNode {
                        strongSelf.secretIconNode = nil
                        secretIconNode.removeFromSupernode()
                    }
                    
                    let contentDelta = CGPoint(x: contentRect.origin.x - (strongSelf.titleNode.frame.minX - titleOffset), y: contentRect.origin.y - (strongSelf.titleNode.frame.minY - UIScreenPixel))
                    let titleFrame = CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: contentRect.origin.y + UIScreenPixel), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    let authorNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x - 1.0, y: contentRect.minY + titleLayout.size.height), size: authorLayout)
                    strongSelf.authorNode.frame = authorNodeFrame
                    let textNodeFrame = CGRect(origin: CGPoint(x: contentRect.origin.x - 1.0, y: contentRect.minY + titleLayout.size.height - 1.0 + UIScreenPixel + (authorLayout.height.isZero ? 0.0 : (authorLayout.height - 3.0))), size: textLayout.size)
                    strongSelf.textNode.textNode.frame = textNodeFrame
                    
                    if !textLayout.spoilers.isEmpty {
                        let dustNode: InvisibleInkDustNode
                        if let current = strongSelf.dustNode {
                            dustNode = current
                        } else {
                            dustNode = InvisibleInkDustNode(textNode: nil)
                            dustNode.isUserInteractionEnabled = false
                            strongSelf.dustNode = dustNode
                            strongSelf.contextContainer.insertSubnode(dustNode, aboveSubnode: strongSelf.textNode.textNode)
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
                            strongSelf.contextContainer.addSubnode(strongSelf.inputActivitiesNode)
                        } else {
                            animateInputActivitiesFrame = true
                        }
                        
                        if strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 1.0
                            strongSelf.textNode.textNode.alpha = 0.0
                            strongSelf.authorNode.alpha = 0.0
                            strongSelf.dustNode?.alpha = 0.0
                            
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.textNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                strongSelf.dustNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                            }
                        }
                    } else {
                        if !strongSelf.inputActivitiesNode.alpha.isZero {
                            strongSelf.inputActivitiesNode.alpha = 0.0
                            strongSelf.textNode.textNode.alpha = 1.0
                            strongSelf.authorNode.alpha = 1.0
                            strongSelf.dustNode?.alpha = 1.0
                            if animated || animateContent {
                                strongSelf.inputActivitiesNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, completion: { value in
                                    if let strongSelf = self, value {
                                        strongSelf.inputActivitiesNode.removeFromSupernode()
                                    }
                                })
                                strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.authorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                strongSelf.dustNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                            } else {
                                strongSelf.inputActivitiesNode.removeFromSupernode()
                            }
                        }
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
                    
                    var mediaPreviewOffset = textNodeFrame.origin.offsetBy(dx: 1.0, dy: floor((measureLayout.size.height - contentImageSize.height) / 2.0))
                    var validMediaIds: [EngineMedia.Id] = []
                    for (message, media, mediaSize) in contentImageSpecs {
                        guard let mediaId = media.id else {
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
                            strongSelf.contextContainer.addSubnode(previewNode)
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
                    
                    if !contentDelta.x.isZero || !contentDelta.y.isZero {
                        let titlePosition = strongSelf.titleNode.position
                        transition.animatePosition(node: strongSelf.titleNode, from: CGPoint(x: titlePosition.x - contentDelta.x, y: titlePosition.y - contentDelta.y))
                        
                        transition.animatePositionAdditive(node: strongSelf.textNode.textNode, offset: CGPoint(x: -contentDelta.x, y: -contentDelta.y))
                        if let dustNode = strongSelf.dustNode {
                            transition.animatePositionAdditive(node: dustNode, offset: CGPoint(x: -contentDelta.x, y: -contentDelta.y))
                        }
                        
                        let authorPosition = strongSelf.authorNode.position
                        transition.animatePosition(node: strongSelf.authorNode, from: CGPoint(x: authorPosition.x - contentDelta.x, y: authorPosition.y - contentDelta.y))
                    }
                    
                    if crossfadeContent {
                        strongSelf.authorNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.titleNode.recursivelyEnsureDisplaySynchronously(true)
                        strongSelf.textNode.textNode.recursivelyEnsureDisplaySynchronously(true)
                    }
                    
                    var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleLayout.size.width + 3.0 + titleOffset
                    
                    if let currentCredibilityIconContent = currentCredibilityIconContent {
                        let credibilityIconView: ComponentHostView<Empty>
                        if let current = strongSelf.credibilityIconView {
                            credibilityIconView = current
                        } else {
                            credibilityIconView = ComponentHostView<Empty>()
                            strongSelf.credibilityIconView = credibilityIconView
                            strongSelf.contextContainer.view.addSubview(credibilityIconView)
                        }
                        
                        let credibilityIconComponent = EmojiStatusComponent(
                            context: item.context,
                            animationCache: item.interaction.animationCache,
                            animationRenderer: item.interaction.animationRenderer,
                            content: currentCredibilityIconContent,
                            isVisibleForAnimations: strongSelf.visibilityStatus,
                            action: nil
                        )
                        strongSelf.credibilityIconComponent = credibilityIconComponent
                        
                        let iconSize = credibilityIconView.update(
                            transition: .immediate,
                            component: AnyComponent(credibilityIconComponent),
                            environment: {},
                            containerSize: CGSize(width: 20.0, height: 20.0)
                        )
                        transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: floorToScreenPixels(titleFrame.midY - iconSize.height / 2.0) - UIScreenPixel), size: iconSize))
                        nextTitleIconOrigin += credibilityIconView.bounds.width + 4.0
                    } else if let credibilityIconView = strongSelf.credibilityIconView {
                        strongSelf.credibilityIconView = nil
                        credibilityIconView.removeFromSuperview()
                    }
                    
                    if let currentMutedIconImage = currentMutedIconImage {
                        strongSelf.mutedIconNode.image = currentMutedIconImage
                        strongSelf.mutedIconNode.isHidden = false
                        transition.updateFrame(node: strongSelf.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin - 5.0, y: titleFrame.minY - 1.0 - UIScreenPixel), size: currentMutedIconImage.size))
                        nextTitleIconOrigin += currentMutedIconImage.size.width + 1.0
                    } else {
                        strongSelf.mutedIconNode.image = nil
                        strongSelf.mutedIconNode.isHidden = true
                    }
                    
                    let separatorInset: CGFloat
                    if case let .groupReference(_, _, _, _, hiddenByDefault) = item.content, hiddenByDefault {
                        separatorInset = 0.0
                    } else if (!nextIsPinned && isPinned) || last {
                            separatorInset = 0.0
                    } else {
                        separatorInset = editingOffset + leftInset + rawContentRect.origin.x
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: layoutOffset + itemHeight - separatorHeight), size: CGSize(width: params.width - separatorInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.contentSize.width, height: itemHeight)))
                    let backgroundColor: UIColor
                    let highlightedBackgroundColor: UIColor
                    if item.selected {
                        backgroundColor = theme.itemSelectedBackgroundColor
                        highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                    } else if isPinned {
                        if case let .groupReference(_, _, _, _, hiddenByDefault) = item.content, hiddenByDefault {
                            backgroundColor = theme.itemBackgroundColor
                            highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                        } else {
                            backgroundColor = theme.pinnedItemBackgroundColor
                            highlightedBackgroundColor = theme.pinnedItemHighlightedBackgroundColor
                        }
                    } else {
                        backgroundColor = theme.itemBackgroundColor
                        highlightedBackgroundColor = theme.itemHighlightedBackgroundColor
                    }
                    if animated {
                        transition.updateBackgroundColor(node: strongSelf.backgroundNode, color: backgroundColor)
                    } else {
                        strongSelf.backgroundNode.backgroundColor = backgroundColor
                    }
                    strongSelf.highlightedBackgroundNode.backgroundColor = highlightedBackgroundColor
                    let topNegativeInset: CGFloat = 0.0
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layoutOffset - separatorHeight - topNegativeInset), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height + separatorHeight + topNegativeInset))
                    
                    if let peerPresence = peerPresence {
                        strongSelf.peerPresenceManager?.reset(presence: EnginePeer.Presence(status: peerPresence.status, lastActivity: 0), isOnline: online)
                    }
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    if item.editing {
                        strongSelf.setRevealOptions((left: [], right: []))
                    } else {
                        strongSelf.setRevealOptions((left: peerLeftRevealOptions, right: peerRevealOptions))
                    }
                    strongSelf.setRevealOptionsOpened(item.hasActiveRevealControls, animated: true)
                    
                    strongSelf.view.accessibilityLabel = strongSelf.accessibilityLabel
                    strongSelf.view.accessibilityValue = strongSelf.accessibilityValue
                    
                    if !customActions.isEmpty {
                        strongSelf.view.accessibilityCustomActions = customActions.map({ action -> UIAccessibilityCustomAction in
                            return ChatListItemAccessibilityCustomAction(name: action.name, target: strongSelf, selector: #selector(strongSelf.performLocalAccessibilityCustomAction(_:)), key: action.key)
                        })
                    } else {
                        strongSelf.view.accessibilityCustomActions = nil
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
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
        guard let item = self.item else {
            return
        }
        
        let isVisible = self.visibilityStatus && self.trackingIsInHierarchy
        if isVisible, let videoContent = self.videoContent, self.videoLoopCount != maxVideoLoopCount {
            if self.videoNode == nil {
                let context = item.context
                let mediaManager = context.sharedContext.mediaManager
                let videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .embedded)
                videoNode.clipsToBounds = true
                videoNode.isUserInteractionEnabled = false
                videoNode.isHidden = true
                videoNode.playbackCompleted = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.videoLoopCount += 1
                        if strongSelf.videoLoopCount == maxVideoLoopCount {
                            if let videoNode = strongSelf.videoNode {
                                strongSelf.videoNode = nil
                                videoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak videoNode] _ in
                                    videoNode?.removeFromSupernode()
                                })
                            }
                        }
                    }
                }
                
                if let _ = videoContent.startTimestamp {
                    self.playbackStartDisposable.set((videoNode.status
                    |> map { status -> Bool in
                        if let status = status, case .playing = status.status {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> filter { playing in
                        return playing
                    }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        if let strongSelf = self {
                            Queue.mainQueue().after(0.15) {
                                strongSelf.videoNode?.isHidden = false
                            }
                        }
                    }))
                } else {
                    self.playbackStartDisposable.set(nil)
                    videoNode.isHidden = false
                }
                videoNode.layer.cornerRadius = self.avatarNode.frame.size.width / 2.0
                if #available(iOS 13.0, *) {
                    videoNode.layer.cornerCurve = .circular
                }
                
                videoNode.canAttachContent = true
                videoNode.play()
                
//                self.contextContainer.insertSubnode(videoNode, aboveSubnode: self.avatarNode)
                self.avatarNode.addSubnode(videoNode)
                self.videoNode = videoNode
            }
        } else if let videoNode = self.videoNode {
            self.videoNode = nil
            videoNode.removeFromSupernode()
        }
        
        if let videoNode = self.videoNode {
            videoNode.updateLayout(size: self.avatarNode.frame.size, transition: .immediate)
            videoNode.frame = self.avatarNode.bounds
        }
    }
        
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let item = self.item, let params = self.layoutParams?.5, let currentItemHeight = self.currentItemHeight, let countersSize = self.layoutParams?.6 {
            let editingOffset: CGFloat
            if let selectableControlNode = self.selectableControlNode {
                editingOffset = selectableControlNode.bounds.size.width
                var selectableControlFrame = selectableControlNode.frame
                selectableControlFrame.origin.x = params.leftInset + offset
                transition.updateFrame(node: selectableControlNode, frame: selectableControlFrame)
            } else {
                editingOffset = 0.0
            }
            
            let layoutOffset: CGFloat = 0.0
            
            if let reorderControlNode = self.reorderControlNode {
                var reorderControlFrame = reorderControlNode.frame
                reorderControlFrame.origin.x = params.width - params.rightInset - reorderControlFrame.size.width + offset
                transition.updateFrame(node: reorderControlNode, frame: reorderControlFrame)
            }
            
            let avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            
            let avatarLeftInset: CGFloat
            if case .forum = item.index {
                avatarLeftInset = 50.0
            } else {
                avatarLeftInset = 18.0 + avatarDiameter
            }
            
            let leftInset: CGFloat = params.leftInset + avatarLeftInset
            
            let rawContentWidth = params.width - leftInset - params.rightInset - 10.0 - editingOffset
            let rawContentRect = CGRect(origin: CGPoint(x: 2.0, y: layoutOffset + 8.0), size: CGSize(width: rawContentWidth, height: currentItemHeight - 12.0 - 9.0))
            
            let contentRect = rawContentRect.offsetBy(dx: editingOffset + leftInset + offset, dy: 0.0)
            
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = leftInset - avatarLeftInset + editingOffset + 10.0 + offset
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            if let videoNode = self.videoNode {
                transition.updateFrame(node: videoNode, frame: CGRect(origin: .zero, size: avatarFrame.size))
            }
            
            if let avatarIconView = self.avatarIconView {
                var avatarIconFrame = avatarIconView.frame
                avatarIconFrame.origin.x = params.leftInset + floor((leftInset - params.leftInset - avatarIconFrame.width) / 2.0) + offset
                transition.updateFrame(view: avatarIconView, frame: avatarIconFrame)
            }
            
            var onlineFrame = self.onlineNode.frame
            if self.onlineIsVoiceChat {
                onlineFrame.origin.x = avatarFrame.maxX - onlineFrame.width + 1.0 - UIScreenPixel
            } else {
                onlineFrame.origin.x = avatarFrame.maxX - onlineFrame.width - 2.0
            }
            transition.updateFrame(node: self.onlineNode, frame: onlineFrame)
            
            var titleOffset: CGFloat = 0.0
            if let secretIconNode = self.secretIconNode, let image = secretIconNode.image {
                transition.updateFrame(node: secretIconNode, frame: CGRect(origin: CGPoint(x: contentRect.minX, y: secretIconNode.frame.minY), size: image.size))
                titleOffset += image.size.width + 3.0
            }
            
            let titleFrame = self.titleNode.frame
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + titleOffset, y: titleFrame.origin.y), size: titleFrame.size))
            
            let authorFrame = self.authorNode.frame
            transition.updateFrame(node: self.authorNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x - 1.0, y: authorFrame.origin.y), size: authorFrame.size))
            
            transition.updateFrame(node: self.inputActivitiesNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x, y: self.inputActivitiesNode.frame.minY), size: self.inputActivitiesNode.bounds.size))
            
            var textFrame = self.textNode.textNode.frame
            textFrame.origin.x = contentRect.origin.x
            transition.updateFrameAdditive(node: self.textNode.textNode, frame: textFrame)
            
            if let dustNode = self.dustNode {
                transition.updateFrameAdditive(node: dustNode, frame: textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0))
            }
            
            var mediaPreviewOffsetX = textFrame.origin.x
            let contentImageSpacing: CGFloat = 2.0
            for (_, media, mediaSize) in self.currentMediaPreviewSpecs {
                guard let mediaId = media.id else {
                    continue
                }
                if let previewNode = self.mediaPreviewNodes[mediaId] {
                    transition.updateFrameAdditive(node: previewNode, frame: CGRect(origin: CGPoint(x: mediaPreviewOffsetX, y: previewNode.frame.minY), size: mediaSize))
                }
                mediaPreviewOffsetX += mediaSize.width + contentImageSpacing
            }
            
            let dateFrame = self.dateNode.frame
            transition.updateFrame(node: self.dateNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width, y: dateFrame.minY), size: dateFrame.size))
            
            let statusFrame = self.statusNode.frame
            
            var statusOffset: CGFloat = 0.0
            if let dateStatusIconNode = self.dateStatusIconNode, let dateIconImage = dateStatusIconNode.image {
                statusOffset += 2.0 + dateIconImage.size.width + 4.0
                var dateStatusX: CGFloat = contentRect.origin.x
                dateStatusX += contentRect.size.width
                dateStatusX += -dateFrame.size.width - 4.0 - dateIconImage.size.width
                
                let dateStatusY: CGFloat = dateStatusIconNode.frame.minY
                
                transition.updateFrame(node: dateStatusIconNode, frame: CGRect(origin: CGPoint(x: dateStatusX, y: dateStatusY), size: dateIconImage.size))
            }
            
            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: contentRect.origin.x + contentRect.size.width - dateFrame.size.width - statusFrame.size.width - statusOffset, y: statusFrame.minY), size: statusFrame.size))
            
            var nextTitleIconOrigin: CGFloat = contentRect.origin.x + titleFrame.size.width + 3.0 + titleOffset
            
            if let credibilityIconView = self.credibilityIconView {
                transition.updateFrame(view: credibilityIconView, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin, y: credibilityIconView.frame.origin.y), size: credibilityIconView.bounds.size))
                nextTitleIconOrigin += credibilityIconView.bounds.size.width + 4.0
            }
            
            let mutedIconFrame = self.mutedIconNode.frame
            transition.updateFrameAdditive(node: self.mutedIconNode, frame: CGRect(origin: CGPoint(x: nextTitleIconOrigin - 5.0, y: mutedIconFrame.minY), size: mutedIconFrame.size))
            nextTitleIconOrigin += mutedIconFrame.size.width + 3.0
            
            let badgeFrame = self.badgeNode.frame
            let updatedBadgeFrame = CGRect(origin: CGPoint(x: contentRect.maxX - badgeFrame.size.width, y: contentRect.maxY - badgeFrame.size.height - 2.0), size: badgeFrame.size)
            transition.updateFrame(node: self.badgeNode, frame: updatedBadgeFrame)
            
            var mentionBadgeFrame = self.mentionBadgeNode.frame
            if updatedBadgeFrame.width.isZero || self.badgeNode.isHidden {
                mentionBadgeFrame.origin.x = updatedBadgeFrame.minX - mentionBadgeFrame.width
            } else {
                mentionBadgeFrame.origin.x = updatedBadgeFrame.minX - 6.0 - mentionBadgeFrame.width
            }
            transition.updateFrame(node: self.mentionBadgeNode, frame: mentionBadgeFrame)
            
            let pinnedIconSize = self.pinnedIconNode.bounds.size
            if pinnedIconSize != CGSize.zero {
                let badgeOffset: CGFloat
                if countersSize.isZero {
                    badgeOffset = contentRect.maxX - pinnedIconSize.width
                } else {
                    badgeOffset = contentRect.maxX - updatedBadgeFrame.size.width - 6.0 - pinnedIconSize.width
                }
                
                let badgeBackgroundWidth = pinnedIconSize.width
                let badgeBackgroundFrame = CGRect(x: badgeOffset, y: self.pinnedIconNode.frame.origin.y, width: badgeBackgroundWidth, height: pinnedIconSize.height)
                transition.updateFrame(node: self.pinnedIconNode, frame: badgeBackgroundFrame)
            }
        }
    }
    
    override func touchesToOtherItemsPrevented() {
        super.touchesToOtherItemsPrevented()
        if let item = self.item {
            item.interaction.setPeerIdWithRevealedOptions(nil, nil)
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            switch item.index {
            case let .chatList(index):
                item.interaction.setPeerIdWithRevealedOptions(index.messageIndex.id.peerId, nil)
            case .forum:
                break
            }
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            switch item.index {
            case let .chatList(index):
                item.interaction.setPeerIdWithRevealedOptions(nil, index.messageIndex.id.peerId)
            case .forum:
                break
            }
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        var close = true
        if case let .chatList(index) = item.index {
            switch option.key {
            case RevealOptionKey.pin.rawValue:
                switch item.content {
                case .peer:
                    let itemId: EngineChatList.PinnedItem.Id = .peer(index.messageIndex.id.peerId)
                    item.interaction.setItemPinned(itemId, true)
                case .groupReference:
                    break
                }
            case RevealOptionKey.unpin.rawValue:
                switch item.content {
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
                if case let .peer(messages, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = item.content, let message = messages.first {
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
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
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
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                }
            case RevealOptionKey.unhide.rawValue:
                item.interaction.toggleArchivedFolderHiddenByDefault()
                close = false
            case RevealOptionKey.hidePsa.rawValue:
                if let item = self.item, case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _, _, _, _) = item.content {
                    item.interaction.hidePsa(peer.peerId)
                }
                close = false
                self.skipFadeout = true
                self.animateRevealOptionsFill {
                    self.revealOptionsInteractivelyClosed()
                }
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
            default:
                break
            }
        }
        if close {
            self.setRevealOptionsOpened(false, animated: true)
            self.revealOptionsInteractivelyClosed()
        }
    }
    
    override func isReorderable(at point: CGPoint) -> Bool {
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
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
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
    
    override func snapshotForReordering() -> UIView? {
        self.backgroundNode.alpha = 0.9
        let result = self.view.snapshotContentTree()
        self.backgroundNode.alpha = 1.0
        return result
    }
}
