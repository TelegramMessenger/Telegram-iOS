import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ActivityIndicator
import AccountContext
import SearchBarNode
import SearchUI
import ContextUI
import AnimationCache
import MultiAnimationRenderer
import TelegramUIPreferences
import ActionPanelComponent
import ComponentDisplayAdapters
import ComponentFlow
import ChatFolderLinkPreviewScreen
import ChatListHeaderComponent
import StoryPeerListComponent

public enum ChatListContainerNodeFilter: Equatable {
    case all
    case filter(ChatListFilter)
    
    public var id: ChatListFilterTabEntryId {
        switch self {
        case .all:
            return .all
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
    
    public var filter: ChatListFilter? {
        switch self {
        case .all:
            return nil
        case let .filter(filter):
            return filter
        }
    }
}

private final class ShimmerEffectNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

private final class ChatListShimmerNode: ASDisplayNode {
    private let backgroundColorNode: ASDisplayNode
    private let effectNode: ShimmerEffectNode
    private let maskNode: ASImageNode
    private var currentParams: (size: CGSize, presentationData: PresentationData)?
    
    override init() {
        self.backgroundColorNode = ASDisplayNode()
        self.effectNode = ShimmerEffectNode()
        self.maskNode = ASImageNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundColorNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.maskNode)
    }
    
    func update(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, size: CGSize, isInlineMode: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData {
            self.currentParams = (size, presentationData)
                        
            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil))
            let timestamp1: Int32 = 100000
            let peers: [EnginePeer.Id: EnginePeer] = [:]
            let interaction = ChatListNodeInteraction(context: context, animationCache: animationCache, animationRenderer: animationRenderer, activateSearch: {}, peerSelected: { _, _, _, _ in }, disabledPeerSelected: { _, _ in }, togglePeerSelected: { _, _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, setPeerThreadMuted: { _, _, _ in }, deletePeer: { _, _ in }, deletePeerThread: { _, _ in }, setPeerThreadStopped: { _, _, _ in }, setPeerThreadPinned: { _, _, _ in }, setPeerThreadHidden: { _, _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, toggleThreadsSelection: { _, _ in }, hidePsa: { _ in }, activateChatPreview: { _, _, _, gesture, _ in
                gesture?.cancel()
            }, present: { _ in }, openForumThread: { _, _ in }, openStorageManagement: {}, openPasswordSetup: {}, openPremiumIntro: {}, openActiveSessions: {}, performActiveSessionAction: { _, _ in }, openChatFolderUpdates: {}, hideChatFolderUpdates: {}, openStories: { _, _ in })
            interaction.isInlineMode = isInlineMode
            
            let items = (0 ..< 2).map { _ -> ChatListItem in
                let message = EngineMessage(
                    stableId: 0,
                    stableVersion: 0,
                    id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    groupInfo: nil,
                    threadId: nil,
                    timestamp: timestamp1,
                    flags: [],
                    tags: [],
                    globalTags: [],
                    localTags: [],
                    forwardInfo: nil,
                    author: peer1,
                    text: "Text",
                    attributes: [],
                    media: [],
                    peers: peers,
                    associatedMessages: [:],
                    associatedMessageIds: [],
                    associatedMedia: [:],
                    associatedThreadInfo: nil,
                    associatedStories: [:]
                )
                let readState = EnginePeerReadCounters()

                return ChatListItem(presentationData: chatListPresentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: 0, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1))), content: .peer(ChatListItemContent.PeerData(
                    messages: [message],
                    peer: EngineRenderedPeer(peer: peer1),
                    threadInfo: nil,
                    combinedReadState: readState,
                    isRemovedFromTotalUnreadCount: false,
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    draftState: nil,
                    inputActivities: nil,
                    promoInfo: nil,
                    ignoreUnreadBadge: false,
                    displayAsMessage: false,
                    hasFailedMessages: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    autoremoveTimeout: nil,
                    storyState: nil
                )), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction)
            }
            
            var itemNodes: [ChatListItemNode] = []
            for i in 0 ..< items.count {
                items[i].nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 100.0), synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: (i == items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    if let itemNode = node as? ChatListItemNode {
                        itemNodes.append(itemNode)
                    }
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
            }
            
            self.backgroundColorNode.backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            
            self.maskNode.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(presentationData.theme.chatList.backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                var currentY: CGFloat = 0.0
                let fakeLabelPlaceholderHeight: CGFloat = 8.0
                
                func fillLabelPlaceholderRect(origin: CGPoint, width: CGFloat) {
                    let startPoint = origin
                    let diameter = fakeLabelPlaceholderHeight
                    context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                    context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                }
                
                while currentY < size.height {
                    let sampleIndex = 0
                    let itemHeight: CGFloat = itemNodes[sampleIndex].contentSize.height
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    
                    if !isInlineMode {
                        if !itemNodes[sampleIndex].avatarNode.isHidden {
                            context.fillEllipse(in: itemNodes[sampleIndex].avatarNode.view.convert(itemNodes[sampleIndex].avatarNode.bounds, to: itemNodes[sampleIndex].view).offsetBy(dx: 0.0, dy: currentY))
                        }
                    }
                    
                    let titleFrame = itemNodes[sampleIndex].titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    if isInlineMode {
                        fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX + 22.0, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0 - 22.0)
                    } else {
                        fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                    }
                    
                    let textFrame = itemNodes[sampleIndex].textNode.textNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    
                    if isInlineMode {
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: textFrame.minX, y: titleFrame.minY + 2.0), size: CGSize(width: 16.0, height: 16.0)))
                    }
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + itemHeight - floor(itemNodes[sampleIndex].titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 60.0)
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 120.0)
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX + 120.0 + 10.0, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 60.0)
                    
                    let dateFrame = itemNodes[sampleIndex].dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: dateFrame.minY), width: 30.0)
                    
                    context.setBlendMode(.normal)
                    context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                    context.fill(itemNodes[sampleIndex].separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                    
                    currentY += itemHeight
                }
            })
            
            self.effectNode.update(backgroundColor: presentationData.theme.list.mediaPlaceholderColor, foregroundColor: presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(node: self.backgroundColorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}

private final class ChatListContainerItemNode: ASDisplayNode {
    private final class TopPanelItem {
        let view = ComponentView<Empty>()
        var size: CGSize?
        
        init() {
        }
    }
    
    private let context: AccountContext
    private weak var controller: ChatListControllerImpl?
    private let location: ChatListControllerLocation
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private var presentationData: PresentationData
    private let becameEmpty: (ChatListFilter?) -> Void
    private let emptyAction: (ChatListFilter?) -> Void
    private let secondaryEmptyAction: () -> Void
    private let openArchiveSettings: () -> Void
    private let isInlineMode: Bool
    
    private var floatingHeaderOffset: CGFloat?
    
    private(set) var emptyNode: ChatListEmptyNode?
    var emptyShimmerEffectNode: ChatListShimmerNode?
    private var shimmerNodeOffset: CGFloat = 0.0
    let listNode: ChatListNode
    
    private var topPanel: TopPanelItem?
    
    private var pollFilterUpdatesDisposable: Disposable?
    private var chatFilterUpdatesDisposable: Disposable?
    private var peerDataDisposable: Disposable?
    
    private var chatFolderUpdates: ChatFolderUpdates?
    
    private var canReportPeer: Bool = false
    
    private(set) var validLayout: (size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat)?
    private var scrollingOffset: (navigationHeight: CGFloat, offset: CGFloat)?
    
    init(context: AccountContext, controller: ChatListControllerImpl?, location: ChatListControllerLocation, filter: ChatListFilter?, chatListMode: ChatListNodeMode, previewing: Bool, isInlineMode: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, becameEmpty: @escaping (ChatListFilter?) -> Void, emptyAction: @escaping (ChatListFilter?) -> Void, secondaryEmptyAction: @escaping () -> Void, openArchiveSettings: @escaping () -> Void, autoSetReady: Bool) {
        self.context = context
        self.controller = controller
        self.location = location
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.presentationData = presentationData
        self.becameEmpty = becameEmpty
        self.emptyAction = emptyAction
        self.secondaryEmptyAction = secondaryEmptyAction
        self.openArchiveSettings = openArchiveSettings
        self.isInlineMode = isInlineMode
        
        self.listNode = ChatListNode(context: context, location: location, chatListFilter: filter, previewing: previewing, fillPreloadItems: controlsHistoryPreload, mode: chatListMode, theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, animationCache: animationCache, animationRenderer: animationRenderer, disableAnimations: true, isInlineMode: isInlineMode, autoSetReady: autoSetReady)
        
        if let controller, case .chatList(groupId: .root) = controller.location {
            self.listNode.scrollHeightTopInset = ChatListNavigationBar.searchScrollHeight + ChatListNavigationBar.storiesScrollHeight
        }
        
        super.init()
        
        self.addSubnode(self.listNode)
        
        self.listNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let strongSelf = self else {
                return
            }
            var needsShimmerNode = false
            var shimmerNodeOffset: CGFloat = 0.0
            
            var needsEmptyNode = false
            var hasOnlyArchive = false
            var hasOnlyGeneralThread = false
            var isLoading = false
            
            switch isEmptyState {
            case let .empty(isLoadingValue, hasArchiveInfo):
                if hasArchiveInfo {
                    shimmerNodeOffset = 253.0
                }
                if isLoadingValue {
                    needsShimmerNode = true
                    needsEmptyNode = false
                    isLoading = isLoadingValue
                } else {
                    needsEmptyNode = true
                }
                if !isLoadingValue {
                    strongSelf.becameEmpty(filter)
                }
            case let .notEmpty(_, onlyHasArchiveValue, onlyGeneralThreadValue):
                needsEmptyNode = onlyHasArchiveValue || onlyGeneralThreadValue
                hasOnlyArchive = onlyHasArchiveValue
                hasOnlyGeneralThread = onlyGeneralThreadValue
            }
            
            if needsEmptyNode {
                if let currentNode = strongSelf.emptyNode {
                    currentNode.updateIsLoading(isLoading)
                } else {
                    let subject: ChatListEmptyNode.Subject
                    if let filter = filter {
                        var showEdit = true
                        if case let .filter(_, _, _, data) = filter {
                            if data.excludeRead && data.includePeers.peers.isEmpty && data.includePeers.pinnedPeers.isEmpty {
                                showEdit = false
                            }
                        }
                        subject = .filter(showEdit: showEdit)
                    } else {
                        if case .forum = location {
                            subject = .forum(hasGeneral: hasOnlyGeneralThread)
                        } else {
                            if case .chatList(groupId: .archive) = location {
                                subject = .archive
                            } else {
                                subject = .chats(hasArchive: hasOnlyArchive)
                            }
                        }
                    }
                    
                    let emptyNode = ChatListEmptyNode(context: context, subject: subject, isLoading: isLoading, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, action: {
                        self?.emptyAction(filter)
                    }, secondaryAction: {
                        self?.secondaryEmptyAction()
                    }, openArchiveSettings: {
                        self?.openArchiveSettings()
                    })
                    strongSelf.emptyNode = emptyNode
                    strongSelf.listNode.addSubnode(emptyNode)
                    if let (size, insets, _, _, _, _, _) = strongSelf.validLayout {
                        let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
                        emptyNode.frame = emptyNodeFrame
                        emptyNode.updateLayout(size: size, insets: insets,  transition: .immediate)
                        
                        if let scrollingOffset = strongSelf.scrollingOffset {
                            emptyNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: .immediate)
                        }
                    }
                    emptyNode.alpha = 0.0
                    transition.updateAlpha(node: emptyNode, alpha: 1.0)
                }
            } else if let emptyNode = strongSelf.emptyNode {
                strongSelf.emptyNode = nil
                transition.updateAlpha(node: emptyNode, alpha: 0.0, completion: { [weak emptyNode] _ in
                    emptyNode?.removeFromSupernode()
                })
            }
            
            
            if needsShimmerNode {
                strongSelf.shimmerNodeOffset = shimmerNodeOffset
                if strongSelf.emptyShimmerEffectNode == nil {
                    let emptyShimmerEffectNode = ChatListShimmerNode()
                    strongSelf.emptyShimmerEffectNode = emptyShimmerEffectNode
                    strongSelf.insertSubnode(emptyShimmerEffectNode, belowSubnode: strongSelf.listNode)
                    if let (size, insets, _, _, _, _, _) = strongSelf.validLayout, let offset = strongSelf.floatingHeaderOffset {
                        strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: .immediate)
                    }
                }
            } else if let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.emptyShimmerEffectNode = nil
                let emptyNodeTransition = transition.isAnimated ? transition : .animated(duration: 0.3, curve: .easeInOut)
                emptyNodeTransition.updateAlpha(node: emptyShimmerEffectNode, alpha: 0.0, completion: { [weak emptyShimmerEffectNode] _ in
                    emptyShimmerEffectNode?.removeFromSupernode()
                })
                strongSelf.listNode.alpha = 0.0
                emptyNodeTransition.updateAlpha(node: strongSelf.listNode, alpha: 1.0)
            }
        }
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.floatingHeaderOffset = offset
            if let (size, insets, _, _, _, _, _) = strongSelf.validLayout, let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: transition)
            }
            strongSelf.layoutAdditionalPanels(transition: transition)
        }
        
        if let filter, case let .filter(id, _, _, data) = filter, data.isShared {
            self.pollFilterUpdatesDisposable = self.context.engine.peers.pollChatFolderUpdates(folderId: id).start()
            self.chatFilterUpdatesDisposable = (self.context.engine.peers.subscribedChatFolderUpdates(folderId: id)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                var update = false
                if let result, result.availableChatsToJoin != 0 {
                    if self.chatFolderUpdates?.availableChatsToJoin != result.availableChatsToJoin {
                        update = true
                    }
                    self.chatFolderUpdates = result
                } else {
                    if self.chatFolderUpdates != nil {
                        self.chatFolderUpdates = nil
                        update = true
                    }
                }
                if update {
                    if let (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                        self.updateLayout(size: size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
        
        if case let .forum(peerId) = location {
            self.peerDataDisposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.StatusSettings(id: peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] statusSettings in
                guard let self else {
                    return
                }
                var canReportPeer = false
                if let statusSettings, statusSettings.flags.contains(.canReport) {
                    canReportPeer = true
                }
                if self.canReportPeer != canReportPeer {
                    self.canReportPeer = canReportPeer
                    if let (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                        self.updateLayout(size: size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
    }
    
    deinit {
        self.pollFilterUpdatesDisposable?.dispose()
        self.chatFilterUpdatesDisposable?.dispose()
        self.peerDataDisposable?.dispose()
    }
    
    private func layoutEmptyShimmerEffectNode(node: ChatListShimmerNode, size: CGSize, insets: UIEdgeInsets, verticalOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        node.update(context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, size: size, isInlineMode: self.isInlineMode, presentationData: self.presentationData, transition: .immediate)
        transition.updateFrameAdditive(node: node, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: size))
    }
    
    private func layoutAdditionalPanels(transition: ContainedViewLayoutTransition) {
        guard let (size, insets, visualNavigationHeight, _, _, _, _) = self.validLayout, let offset = self.floatingHeaderOffset else {
            return
        }
        
        let _ = size
        let _ = insets
        
        if let topPanel = self.topPanel, let topPanelSize = topPanel.size {
            let minY: CGFloat = visualNavigationHeight - 44.0 + topPanelSize.height
            
            if let topPanelView = topPanel.view.view {
                var animateIn = false
                var topPanelTransition = transition
                if topPanelView.bounds.isEmpty {
                    topPanelTransition = .immediate
                    animateIn = true
                }
                topPanelTransition.updateFrame(view: topPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: max(minY, offset - topPanelSize.height)), size: topPanelSize))
                if animateIn {
                    transition.animatePositionAdditive(layer: topPanelView.layer, offset: CGPoint(x: 0.0, y: -topPanelView.bounds.height))
                }
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listNode.updateThemeAndStrings(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
        
        self.emptyNode?.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset)
        
        var listInsets = insets
        var additionalTopInset: CGFloat = 0.0
        
        if let chatFolderUpdates = self.chatFolderUpdates {
            let topPanel: TopPanelItem
            var topPanelTransition = Transition(transition)
            if let current = self.topPanel {
                topPanel = current
            } else {
                topPanelTransition = .immediate
                topPanel = TopPanelItem()
                self.topPanel = topPanel
            }
            
            let title: String = self.presentationData.strings.ChatList_PanelNewChatsAvailable(Int32(chatFolderUpdates.availableChatsToJoin))
            
            let topPanelHeight: CGFloat = 44.0
            
            let _ = topPanel.view.update(
                transition: topPanelTransition,
                component: AnyComponent(ActionPanelComponent(
                    theme: self.presentationData.theme,
                    title: title,
                    color: .accent,
                    action: { [weak self] in
                        guard let self, let chatFolderUpdates = self.chatFolderUpdates else {
                            return
                        }
                        
                        self.listNode.push?(ChatFolderLinkPreviewScreen(context: self.context, subject: .updates(chatFolderUpdates), contents: chatFolderUpdates.chatFolderLinkContents))
                    },
                    dismissAction: { [weak self] in
                        guard let self, let chatFolderUpdates = self.chatFolderUpdates else {
                            return
                        }
                        let _ = self.context.engine.peers.hideChatFolderUpdates(folderId: chatFolderUpdates.folderId).start()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: topPanelHeight)
            )
            if let topPanelView = topPanel.view.view {
                if topPanelView.superview == nil {
                    self.view.addSubview(topPanelView)
                }
            }
            
            topPanel.size = CGSize(width: size.width, height: topPanelHeight)
            listInsets.top += topPanelHeight
            additionalTopInset += topPanelHeight
        } else if self.canReportPeer {
            let topPanel: TopPanelItem
            var topPanelTransition = Transition(transition)
            if let current = self.topPanel {
                topPanel = current
            } else {
                topPanelTransition = .immediate
                topPanel = TopPanelItem()
                self.topPanel = topPanel
            }
            
            let title: String = self.presentationData.strings.Conversation_ReportSpamAndLeave
            
            let topPanelHeight: CGFloat = 44.0
            
            let _ = topPanel.view.update(
                transition: topPanelTransition,
                component: AnyComponent(ActionPanelComponent(
                    theme: self.presentationData.theme,
                    title: title,
                    color: .destructive,
                    action: { [weak self] in
                        guard let self, case let .forum(peerId) = self.location else {
                            return
                        }
                        
                        let actionSheet = ActionSheetController(presentationData: self.presentationData)
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: self.presentationData.strings.Conversation_ReportSpamGroupConfirmation),
                                ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ReportSpamAndLeave, color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    if let self {
                                        self.controller?.setInlineChatList(location: nil)
                                        let _ = self.context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: true).start()
                                    }
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        self.listNode.present?(actionSheet)
                    },
                    dismissAction: { [weak self] in
                        guard let self, case let .forum(peerId) = self.location else {
                            return
                        }
                        let _ = self.context.engine.peers.dismissPeerStatusOptions(peerId: peerId).start()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: topPanelHeight)
            )
            if let topPanelView = topPanel.view.view {
                if topPanelView.superview == nil {
                    self.view.addSubview(topPanelView)
                }
            }
            
            topPanel.size = CGSize(width: size.width, height: topPanelHeight)
            listInsets.top += topPanelHeight
            additionalTopInset += topPanelHeight
        } else {
            if let topPanel = self.topPanel {
                self.topPanel = nil
                if let topPanelView = topPanel.view.view {
                    transition.updatePosition(layer: topPanelView.layer, position: CGPoint(x: topPanelView.layer.position.x, y: topPanelView.layer.position.y - topPanelView.layer.bounds.height), completion: { [weak topPanelView] _ in
                        topPanelView?.removeFromSuperview()
                    })
                }
            }
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: listInsets, duration: duration, curve: curve)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, visibleTopInset: visualNavigationHeight + additionalTopInset, originalTopInset: originalNavigationHeight + additionalTopInset, storiesInset: storiesInset, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction)
        
        if let emptyNode = self.emptyNode {
            let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            transition.updateFrame(node: emptyNode, frame: emptyNodeFrame)
            emptyNode.updateLayout(size: emptyNodeFrame.size, insets: listInsets, transition: transition)
            
            if let scrollingOffset = self.scrollingOffset {
                emptyNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: transition)
            }
        }
        
        self.layoutAdditionalPanels(transition: transition)
    }
    
    func updateScrollingOffset(navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.scrollingOffset = (navigationHeight, offset)
        
        if let emptyNode = self.emptyNode {
            emptyNode.updateScrollingOffset(navigationHeight: navigationHeight, offset: offset, transition: transition)
        }
    }
}

public final class ChatListContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private weak var controller: ChatListControllerImpl?
    let location: ChatListControllerLocation
    private let chatListMode: ChatListNodeMode
    private let previewing: Bool
    private let isInlineMode: Bool
    private let controlsHistoryPreload: Bool
    private let filterBecameEmpty: (ChatListFilter?) -> Void
    private let filterEmptyAction: (ChatListFilter?) -> Void
    private let secondaryEmptyAction: () -> Void
    private let openArchiveSettings: () -> Void
    
    fileprivate var onStoriesLockedUpdated: ((Bool) -> Void)?
    
    fileprivate var onFilterSwitch: (() -> Void)?
    
    private var presentationData: PresentationData
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private var itemNodes: [ChatListFilterTabEntryId: ChatListContainerItemNode] = [:]
    private var pendingItemNode: (ChatListFilterTabEntryId, ChatListContainerItemNode, Disposable)?
    private(set) var availableFilters: [ChatListContainerNodeFilter] = [.all] {
        didSet {
            self.availableFiltersPromise.set(self.availableFilters)
        }
    }
    private let availableFiltersPromise = ValuePromise<[ChatListContainerNodeFilter]>([.all], ignoreRepeated: true)
    var availableFiltersSignal: Signal<[ChatListContainerNodeFilter], NoError> {
        return self.availableFiltersPromise.get()
    }
    
    private var filtersLimit: Int32? = nil
    private var selectedId: ChatListFilterTabEntryId
    
    var hintUpdatedStoryExpansion: Bool = false
    var ignoreStoryUnlockedScrolling: Bool = false
    var tempTopInset: CGFloat = 0.0 {
        didSet {
            for (_, itemNode) in self.itemNodes {
                itemNode.listNode.tempTopInset = self.tempTopInset
            }
            if let pendingItemNode = self.pendingItemNode {
                pendingItemNode.1.listNode.tempTopInset = self.tempTopInset
            }
        }
    }
    
    var initialScrollingOffset: CGFloat?
    
    public private(set) var transitionFraction: CGFloat = 0.0
    private var transitionFractionOffset: CGFloat = 0.0
    private var disableItemNodeOperationsWhileAnimating: Bool = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, insets: UIEdgeInsets, isReorderingFilters: Bool, isEditing: Bool, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat)?
    
    private var scrollingOffset: (navigationHeight: CGFloat, offset: CGFloat)?
    
    private var enableAdjacentFilterLoading: Bool = false
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    let leftSeparatorLayer: SimpleLayer
    
    private let _ready = Promise<Bool>()
    public var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private let _validLayoutReady = Promise<Bool>()
    var validLayoutReady: Signal<Bool, NoError> {
        return _validLayoutReady.get()
    }
    
    private var currentItemNodeValue: ChatListContainerItemNode?
    public var currentItemNode: ChatListNode {
        return self.currentItemNodeValue!.listNode
    }
    
    private let currentItemStateValue = Promise<(state: ChatListNodeState, filterId: Int32?)>()
    var currentItemState: Signal<(state: ChatListNodeState, filterId: Int32?), NoError> {
        return self.currentItemStateValue.get()
    }
    
    public var currentItemFilterUpdated: ((ChatListFilterTabEntryId, CGFloat, ContainedViewLayoutTransition, Bool) -> Void)?
    public var currentItemFilter: ChatListFilterTabEntryId {
        return self.currentItemNode.chatListFilter.flatMap { .filter($0.id) } ?? .all
    }
    
    private var didSetupContentOffset = false
    private var isSettingUpContentOffset = false
    
    private func applyItemNodeAsCurrent(id: ChatListFilterTabEntryId, itemNode: ChatListContainerItemNode) {
        if let previousItemNode = self.currentItemNodeValue {
            previousItemNode.listNode.activateSearch = nil
            previousItemNode.listNode.presentAlert = nil
            previousItemNode.listNode.present = nil
            previousItemNode.listNode.push = nil
            previousItemNode.listNode.toggleArchivedFolderHiddenByDefault = nil
            previousItemNode.listNode.hidePsa = nil
            previousItemNode.listNode.deletePeerChat = nil
            previousItemNode.listNode.deletePeerThread = nil
            previousItemNode.listNode.setPeerThreadStopped = nil
            previousItemNode.listNode.setPeerThreadPinned = nil
            previousItemNode.listNode.setPeerThreadHidden = nil
            previousItemNode.listNode.peerSelected = nil
            previousItemNode.listNode.groupSelected = nil
            previousItemNode.listNode.updatePeerGrouping = nil
            previousItemNode.listNode.contentOffsetChanged = nil
            previousItemNode.listNode.contentScrollingEnded = nil
            previousItemNode.listNode.didBeginInteractiveDragging = nil
            previousItemNode.listNode.endedInteractiveDragging = { _ in }
            previousItemNode.listNode.shouldStopScrolling = nil
            previousItemNode.listNode.activateChatPreview = nil
            previousItemNode.listNode.openStories = nil
            previousItemNode.listNode.addedVisibleChatsWithPeerIds = nil
            previousItemNode.listNode.didBeginSelectingChats = nil
            previousItemNode.listNode.canExpandHiddenItems = nil
            
            previousItemNode.accessibilityElementsHidden = true
        }
        self.currentItemNodeValue = itemNode
        itemNode.accessibilityElementsHidden = false
        
        itemNode.listNode.activateSearch = { [weak self] in
            self?.activateSearch?()
        }
        itemNode.listNode.presentAlert = { [weak self] text in
            self?.presentAlert?(text)
        }
        itemNode.listNode.present = { [weak self] c in
            self?.present?(c)
        }
        itemNode.listNode.push = { [weak self] c in
            self?.push?(c)
        }
        itemNode.listNode.toggleArchivedFolderHiddenByDefault = { [weak self] in
            self?.toggleArchivedFolderHiddenByDefault?()
        }
        itemNode.listNode.hidePsa = { [weak self] peerId in
            self?.hidePsa?(peerId)
        }
        itemNode.listNode.deletePeerChat = { [weak self] peerId, joined in
            self?.deletePeerChat?(peerId, joined)
        }
        itemNode.listNode.deletePeerThread = { [weak self] peerId, threadId in
            self?.deletePeerThread?(peerId, threadId)
        }
        itemNode.listNode.setPeerThreadStopped = { [weak self] peerId, threadId, isStopped in
            self?.setPeerThreadStopped?(peerId, threadId, isStopped)
        }
        itemNode.listNode.setPeerThreadPinned = { [weak self] peerId, threadId, isPinned in
            self?.setPeerThreadPinned?(peerId, threadId, isPinned)
        }
        itemNode.listNode.setPeerThreadHidden = { [weak self] peerId, threadId, isHidden in
            self?.setPeerThreadHidden?(peerId, threadId, isHidden)
        }
        itemNode.listNode.peerSelected = { [weak self] peerId, threadId, animated, activateInput, promoInfo in
            self?.peerSelected?(peerId, threadId, animated, activateInput, promoInfo)
        }
        itemNode.listNode.groupSelected = { [weak self] groupId in
            self?.groupSelected?(groupId)
        }
        itemNode.listNode.updatePeerGrouping = { [weak self] peerId, group in
            self?.updatePeerGrouping?(peerId, group)
        }
        itemNode.listNode.contentOffsetChanged = { [weak self, weak itemNode] offset in
            guard let self, let itemNode else {
                return
            }
            if self.isSettingUpContentOffset {
                return
            }
            
            if !self.didSetupContentOffset, let initialScrollingOffset = self.initialScrollingOffset {
                self.initialScrollingOffset = nil
                self.didSetupContentOffset = true
                self.isSettingUpContentOffset = true
                
                let _ = itemNode.listNode.scrollToOffsetFromTop(initialScrollingOffset, animated: false)
                
                let offset = itemNode.listNode.visibleContentOffset()
                self.contentOffset = offset
                self.contentOffsetChanged?(offset, self.currentItemNode)
                
                self.isSettingUpContentOffset = false
                return
            }
            
            if !self.isInlineMode, itemNode.listNode.isTracking && !self.currentItemNode.startedScrollingAtUpperBound && self.tempTopInset == 0.0 {
                if case let .known(value) = offset {
                    if value < -1.0 {
                        if let controller = self.controller, let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
                            self.currentItemNode.startedScrollingAtUpperBound = true
                            self.tempTopInset = ChatListNavigationBar.storiesScrollHeight
                        }
                    }
                }
            }
            
            self.contentOffset = offset
            self.contentOffsetChanged?(offset, self.currentItemNode)
            
            if !self.isInlineMode, self.currentItemNode.startedScrollingAtUpperBound && self.tempTopInset != 0.0 {
                if case let .known(value) = offset {
                    if value > 4.0 {
                        self.currentItemNode.startedScrollingAtUpperBound = false
                        self.tempTopInset = 0.0
                    } else if value <= -ChatListNavigationBar.storiesScrollHeight {
                    } else if value > -82.0 {
                    }
                } else if case .unknown = offset {
                    self.currentItemNode.startedScrollingAtUpperBound = false
                    self.tempTopInset = 0.0
                }
            }
        }
        itemNode.listNode.didBeginInteractiveDragging = { [weak self] listView in
            guard let self else {
                return
            }
            
            self.didBeginInteractiveDragging?(listView)
            
            if self.isInlineMode {
                return
            }
            
            guard let validLayout = self.validLayout else {
                return
            }
            
            let tempTopInset: CGFloat
            if validLayout.inlineNavigationLocation != nil {
                tempTopInset = 0.0
            } else if self.currentItemNode.startedScrollingAtUpperBound && !self.isInlineMode {
                if let controller = self.controller, let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
                    tempTopInset = ChatListNavigationBar.storiesScrollHeight
                } else {
                    tempTopInset = 0.0
                }
            } else {
                tempTopInset = 0.0
            }
            if self.tempTopInset != tempTopInset {
                self.tempTopInset = tempTopInset
                self.hintUpdatedStoryExpansion = true
                self.currentItemNode.contentOffsetChanged?(self.currentItemNode.visibleContentOffset())
                self.hintUpdatedStoryExpansion = false
            }
        }
        itemNode.listNode.endedInteractiveDragging = { [weak self] _ in
            guard let self else {
                return
            }
            self.endedInteractiveDragging?(self.currentItemNode)
        }
        itemNode.listNode.shouldStopScrolling = { [weak self] velocity in
            guard let self else {
                return false
            }
            return self.shouldStopScrolling?(self.currentItemNode, velocity) ?? false
        }
        itemNode.listNode.contentScrollingEnded = { [weak self] listView in
            guard let self else {
                return false
            }
            
            return self.contentScrollingEnded?(listView) ?? false
            //DispatchQueue.main.async { [weak self] in
            //    let _ = self?.contentScrollingEnded?(listView)
            //}
            
            //return false
        }
        itemNode.listNode.activateChatPreview = { [weak self] item, threadId, sourceNode, gesture, location in
            self?.activateChatPreview?(item, threadId, sourceNode, gesture, location)
        }
        itemNode.listNode.openStories = { [weak self] subject, itemNode in
            self?.openStories?(subject, itemNode)
        }
        itemNode.listNode.addedVisibleChatsWithPeerIds = { [weak self] ids in
            self?.addedVisibleChatsWithPeerIds?(ids)
        }
        itemNode.listNode.didBeginSelectingChats = { [weak self] in
            self?.didBeginSelectingChats?()
        }
        itemNode.listNode.canExpandHiddenItems = { [weak self] in
            guard let self, let canExpandHiddenItems = self.canExpandHiddenItems else {
                return false
            }
            return canExpandHiddenItems()
        }
        
        self.currentItemStateValue.set(itemNode.listNode.state |> map { state in
            let filterId: Int32?
            switch id {
            case .all:
                filterId = nil
            case let .filter(filter):
                filterId = filter
            }
            return (state, filterId)
        })
        
        let enablePreload = context.sharedContext.accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]))
        |> map { sharedData -> Bool in
            var automaticMediaDownloadSettings: MediaAutoDownloadSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) {
                automaticMediaDownloadSettings = value
            } else {
                automaticMediaDownloadSettings = MediaAutoDownloadSettings.defaultSettings
            }
            return automaticMediaDownloadSettings.energyUsageSettings.autodownloadInBackground
        }
        |> distinctUntilChanged
        
        if self.controlsHistoryPreload, case .chatList(groupId: .root) = self.location {
            self.context.account.viewTracker.chatListPreloadItems.set(combineLatest(queue: .mainQueue(),
                context.sharedContext.enablePreloads.get(),
                itemNode.listNode.preloadItems.get(),
                enablePreload
            )
            |> map { enablePreloads, preloadItems, enablePreload -> Set<ChatHistoryPreloadItem> in
                if !enablePreloads || !enablePreload {
                    return Set()
                } else {
                    return Set(preloadItems)
                }
            })
        }
    }
    
    public var activateSearch: (() -> Void)?
    var presentAlert: ((String) -> Void)?
    var present: ((ViewController) -> Void)?
    var push: ((ViewController) -> Void)?
    var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    var hidePsa: ((EnginePeer.Id) -> Void)?
    var deletePeerChat: ((EnginePeer.Id, Bool) -> Void)?
    var deletePeerThread: ((EnginePeer.Id, Int64) -> Void)?
    var setPeerThreadStopped: ((EnginePeer.Id, Int64, Bool) -> Void)?
    var setPeerThreadPinned: ((EnginePeer.Id, Int64, Bool) -> Void)?
    var setPeerThreadHidden: ((EnginePeer.Id, Int64, Bool) -> Void)?
    public var peerSelected: ((EnginePeer, Int64?, Bool, Bool, ChatListNodeEntryPromoInfo?) -> Void)?
    var groupSelected: ((EngineChatList.Group) -> Void)?
    var updatePeerGrouping: ((EnginePeer.Id, Bool) -> Void)?
    var contentOffset: ListViewVisibleContentOffset?
    public var contentOffsetChanged: ((ListViewVisibleContentOffset, ListView) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    var didBeginInteractiveDragging: ((ListView) -> Void)?
    var endedInteractiveDragging: ((ListView) -> Void)?
    var shouldStopScrolling: ((ListView, CGFloat) -> Bool)?
    var activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    var openStories: ((ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void)?
    var addedVisibleChatsWithPeerIds: (([EnginePeer.Id]) -> Void)?
    var didBeginSelectingChats: (() -> Void)?
    var canExpandHiddenItems: (() -> Bool)?
    public var displayFilterLimit: (() -> Void)?
    
    public init(context: AccountContext, controller: ChatListControllerImpl?, location: ChatListControllerLocation, chatListMode: ChatListNodeMode = .chatList(appendContacts: true), previewing: Bool, controlsHistoryPreload: Bool, isInlineMode: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, filterBecameEmpty: @escaping (ChatListFilter?) -> Void, filterEmptyAction: @escaping (ChatListFilter?) -> Void, secondaryEmptyAction: @escaping () -> Void, openArchiveSettings: @escaping () -> Void) {
        self.context = context
        self.controller = controller
        self.location = location
        self.chatListMode = chatListMode
        self.previewing = previewing
        self.isInlineMode = isInlineMode
        self.filterBecameEmpty = filterBecameEmpty
        self.filterEmptyAction = filterEmptyAction
        self.secondaryEmptyAction = secondaryEmptyAction
        self.openArchiveSettings = openArchiveSettings
        self.controlsHistoryPreload = controlsHistoryPreload
        
        self.presentationData = presentationData
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        self.selectedId = .all
        
        self.leftSeparatorLayer = SimpleLayer()
        self.leftSeparatorLayer.isHidden = true
        self.leftSeparatorLayer.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor.cgColor
        
        super.init()
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        let itemNode = ChatListContainerItemNode(context: self.context, controller: self.controller, location: self.location, filter: nil, chatListMode: chatListMode, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
            self?.filterBecameEmpty(filter)
        }, emptyAction: { [weak self] filter in
            self?.filterEmptyAction(filter)
        }, secondaryEmptyAction: { [weak self] in
            self?.secondaryEmptyAction()
        }, openArchiveSettings: { [weak self] in
            self?.openArchiveSettings()
        }, autoSetReady: true)
        self.itemNodes[.all] = itemNode
        self.addSubnode(itemNode)
        
        self._ready.set(itemNode.listNode.ready)
        
        self.applyItemNodeAsCurrent(id: .all, itemNode: itemNode)
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let self, self.availableFilters.count > 1 || (self.controller?.isStoryPostingAvailable == true && !(self.context.sharedContext.callManager?.hasActiveCall ?? false)) else {
                return []
            }
            guard case .chatList(.root) = self.location else {
                return []
            }
            switch self.currentItemNode.visibleContentOffset() {
            case let .known(value):
                if value < -self.currentItemNode.tempTopInset {
                    return []
                }
            case .none, .unknown:
                break
            }
            if !self.currentItemNode.isNavigationInAFinalState {
                return []
            }
            if self.availableFilters.count > 1 {
                return [.leftCenter, .rightCenter]
            } else {
                return [.rightEdge]
            }
        }, edgeWidth: .widthMultiplier(factor: 1.0 / 6.0, min: 22.0, max: 80.0))
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
        
        self.view.layer.addSublayer(self.leftSeparatorLayer)
    }
    
    deinit {
        self.pendingItemNode?.2.dispose()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let filtersLimit = self.filtersLimit.flatMap({ $0 + 1 }) ?? Int32(self.availableFilters.count)
        let maxFilterIndex = min(Int(filtersLimit), self.availableFilters.count) - 1
        
        switch recognizer.state {
        case .began:
            self.onFilterSwitch?()
            
            self.transitionFractionOffset = 0.0
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout, let itemNode = self.itemNodes[self.selectedId] {
                for (id, itemNode) in self.itemNodes {
                    if id != selectedId {
                        itemNode.emptyNode?.restartAnimation()
                        
                        if let controller = self.controller, let chatListDisplayNode = controller.displayNode as? ChatListControllerNode, let navigationBarComponentView = chatListDisplayNode.navigationBarView.view as? ChatListNavigationBar.View, let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
                            let scrollOffset = clippedScrollOffset
                            
                            let _ = itemNode.listNode.scrollToOffsetFromTop(scrollOffset, animated: false)
                        }
                    }
                }
                
                if let presentationLayer = itemNode.layer.presentation() {
                    self.transitionFraction = presentationLayer.frame.minX / layout.size.width
                    self.transitionFractionOffset = self.transitionFraction
                    if !self.transitionFraction.isZero {
                        for (_, itemNode) in self.itemNodes {
                            itemNode.layer.removeAllAnimations()
                        }
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                        self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, true)
                    }
                }
            }
        case .changed:
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
                let translation = recognizer.translation(in: self.view)
                var transitionFraction = translation.x / layout.size.width
                
                var transition: ContainedViewLayoutTransition = .immediate
                
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    let range: CGFloat = 600.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
                     
                if case .compact = layout.metrics.widthClass, self.controller?.isStoryPostingAvailable == true && !(self.context.sharedContext.callManager?.hasActiveCall ?? false) {
                    let cameraIsAlreadyOpened = self.controller?.hasStoryCameraTransition ?? false
                    if selectedIndex <= 0 && translation.x > 0.0 {
                        transitionFraction = 0.0
                        self.controller?.storyCameraPanGestureChanged(transitionFraction: translation.x / layout.size.width)
                    } else if translation.x <= 0.0 && cameraIsAlreadyOpened {
                        self.controller?.storyCameraPanGestureChanged(transitionFraction: 0.0)
                    }
                    
                    if cameraIsAlreadyOpened {
                        transitionFraction = 0.0
                        return
                    }
                } else {
                    if selectedIndex <= 0 && translation.x > 0.0 {
                        let overscroll = translation.x
                        transitionFraction = rubberBandingOffset(offset: overscroll, bandingStart: 0.0) / layout.size.width
                    }
                }
                
                if selectedIndex >= maxFilterIndex && translation.x < 0.0 {
                    let overscroll = -translation.x
                    transitionFraction = -rubberBandingOffset(offset: overscroll, bandingStart: 0.0) / layout.size.width
                    
                    if let filtersLimit = self.filtersLimit, selectedIndex >= filtersLimit - 1 {
                        transitionFraction = 0.0
                        self.transitionFractionOffset = 0.0
                        recognizer.isEnabled = false
                        recognizer.isEnabled = true
                        
                        transition = .animated(duration: 0.45, curve: .spring)
                        self.displayFilterLimit?()
                    }
                }
                self.transitionFraction = transitionFraction + self.transitionFractionOffset
                if let currentItemNode = self.currentItemNodeValue {
                    let isNavigationHidden = currentItemNode.listNode.isNavigationHidden
                    for (_, itemNode) in self.itemNodes {
                        if itemNode !== currentItemNode {
                            itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: isNavigationHidden)
                        }
                    }
                }
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
            }
        case .cancelled, .ended:
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
                let translation = recognizer.translation(in: self.view)
                let velocity = recognizer.velocity(in: self.view)
                var directionIsToRight: Bool?
                if abs(velocity.x) > 10.0 {
                    if translation.x < 0.0 {
                        if velocity.x >= 0.0 {
                            directionIsToRight = nil
                        } else {
                            directionIsToRight = true
                        }
                    } else {
                        if velocity.x <= 0.0 {
                            directionIsToRight = nil
                        } else {
                            directionIsToRight = false
                        }
                    }
                } else {
                    if abs(translation.x) > layout.size.width / 2.0 {
                        directionIsToRight = translation.x > layout.size.width / 2.0
                    }
                }
                
                let hasStoryCameraTransition = self.controller?.hasStoryCameraTransition ?? false
                if hasStoryCameraTransition {
                    self.controller?.storyCameraPanGestureEnded(transitionFraction: translation.x / layout.size.width, velocity: velocity.x)
                }
                var applyNodeAsCurrent: ChatListFilterTabEntryId?
                
                if let directionIsToRight = directionIsToRight {
                    var updatedIndex = selectedIndex
                    if directionIsToRight {
                        updatedIndex = min(updatedIndex + 1, maxFilterIndex)
                    } else {
                        updatedIndex = max(updatedIndex - 1, 0)
                    }
                    let switchToId = self.availableFilters[updatedIndex].id
                    if switchToId != self.selectedId, let itemNode = self.itemNodes[switchToId] {
                        let _ = itemNode
                        self.selectedId = switchToId
                        applyNodeAsCurrent = switchToId
                    }
                }
                self.transitionFraction = 0.0
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
                self.disableItemNodeOperationsWhileAnimating = true
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: transition)
                DispatchQueue.main.async {
                    self.disableItemNodeOperationsWhileAnimating = false
                    if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                    }
                }
                                    
                if let switchToId = applyNodeAsCurrent, let itemNode = self.itemNodes[switchToId] {
                    self.applyItemNodeAsCurrent(id: switchToId, itemNode: itemNode)
                }
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
            }
        default:
            break
        }
    }
    
    func fixContentOffset(offset: CGFloat) {
        self.currentItemNode.fixContentOffset(offset: offset)
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        if let validLayout = self.validLayout {
            if let _ = validLayout.inlineNavigationLocation {
                self.backgroundColor = self.presentationData.theme.chatList.backgroundColor.mixedWith(self.presentationData.theme.chatList.pinnedItemBackgroundColor, alpha: validLayout.inlineNavigationTransitionFraction)
            } else {
                self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
            }
        }
        
        self.leftSeparatorLayer.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor.cgColor
        
        for (_, itemNode) in self.itemNodes {
            itemNode.updatePresentationData(presentationData)
        }
    }
    
    func playArchiveAnimation() {
        if let itemNode = self.itemNodes[self.selectedId] {
            itemNode.listNode.forEachVisibleItemNode { node in
                if let node = node as? ChatListItemNode {
                    node.playArchiveAnimation()
                }
            }
        }
    }
    
    public func scrollToTop(animated: Bool, adjustForTempInset: Bool) {
        if let itemNode = self.itemNodes[self.selectedId] {
            itemNode.listNode.scrollToPosition(.top(adjustForTempInset: adjustForTempInset), animated: animated)
        }
    }
    
    func updateSelectedChatLocation(data: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        for (_, itemNode) in self.itemNodes {
            itemNode.listNode.updateSelectedChatLocation(data, progress: progress, transition: transition)
        }
    }
    
    func updateState(onlyCurrent: Bool = true, _ f: (ChatListNodeState) -> ChatListNodeState) {
        self.currentItemNode.updateState(f)
        let updatedState = self.currentItemNode.currentState
        for (id, itemNode) in self.itemNodes {
            if id != self.selectedId {
                if onlyCurrent {
                    itemNode.listNode.updateState { state in
                        var state = state
                        state.editing = updatedState.editing
                        state.selectedPeerIds = updatedState.selectedPeerIds
                        return state
                    }
                } else {
                    itemNode.listNode.updateState(f)
                }
            }
        }
    }
    
    public func updateAvailableFilters(_ availableFilters: [ChatListContainerNodeFilter], limit: Int32?) {
        if self.availableFilters != availableFilters {
            let apply: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.availableFilters = availableFilters
                strongSelf.filtersLimit = limit
                if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = strongSelf.validLayout {
                    strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                }
            }
            if !availableFilters.contains(where: { $0.id == self.selectedId }) {
                self.switchToFilter(id: .all, completion: {
                    apply()
                })
            } else {
                apply()
            }
        }
    }
    
    public func updateEnableAdjacentFilterLoading(_ value: Bool) {
        if value != self.enableAdjacentFilterLoading {
            self.enableAdjacentFilterLoading = value
            
            if self.enableAdjacentFilterLoading, let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
            }
        }
    }
    
    public func switchToFilter(id: ChatListFilterTabEntryId, animated: Bool = true, completion: (() -> Void)? = nil) {
        self.onFilterSwitch?()
        if id != self.selectedId, let index = self.availableFilters.firstIndex(where: { $0.id == id }) {
            if let itemNode = self.itemNodes[id] {
                guard let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout else {
                    return
                }
                
                if let controller = self.controller, let chatListDisplayNode = controller.displayNode as? ChatListControllerNode, let navigationBarComponentView = chatListDisplayNode.navigationBarView.view as? ChatListNavigationBar.View, let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
                    let scrollOffset = clippedScrollOffset
                    
                    let _ = itemNode.listNode.scrollToOffsetFromTop(scrollOffset, animated: false)
                }
                
                self.selectedId = id
                self.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: transition)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
                itemNode.emptyNode?.restartAnimation()
                completion?()
            } else if self.pendingItemNode == nil {
                let itemNode = ChatListContainerItemNode(context: self.context, controller: self.controller, location: self.location, filter: self.availableFilters[index].filter, chatListMode: self.chatListMode, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
                    self?.filterBecameEmpty(filter)
                }, emptyAction: { [weak self] filter in
                    self?.filterEmptyAction(filter)
                }, secondaryEmptyAction: { [weak self] in
                    self?.secondaryEmptyAction()
                }, openArchiveSettings: { [weak self] in
                    self?.openArchiveSettings()
                }, autoSetReady: !animated)
                let disposable = MetaDisposable()
                self.pendingItemNode = (id, itemNode, disposable)
                
                if !animated {
                    self.selectedId = id
                    self.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                    self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, false)
                }
                
                disposable.set((itemNode.listNode.ready
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self, weak itemNode] _ in
                    guard let strongSelf = self, let itemNode = itemNode, itemNode === strongSelf.pendingItemNode?.1 else {
                        return
                    }
                    
                    strongSelf.pendingItemNode = nil
                    itemNode.listNode.tempTopInset = strongSelf.tempTopInset
                    
                    if let controller = strongSelf.controller, let chatListDisplayNode = controller.displayNode as? ChatListControllerNode, let navigationBarComponentView = chatListDisplayNode.navigationBarView.view as? ChatListNavigationBar.View, let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
                        let scrollOffset = clippedScrollOffset
                        
                        let _ = itemNode.listNode.scrollToOffsetFromTop(scrollOffset, animated: false)
                    }
                    
                    guard let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = strongSelf.validLayout else {
                        strongSelf.itemNodes[id] = itemNode
                        strongSelf.addSubnode(itemNode)
                        
                        strongSelf.selectedId = id
                        strongSelf.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                        strongSelf.currentItemFilterUpdated?(strongSelf.currentItemFilter, strongSelf.transitionFraction, .immediate, false)
                        
                        completion?()
                        return
                    }
                    
                    let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.35, curve: .spring) : .immediate
                    if let previousIndex = strongSelf.availableFilters.firstIndex(where: { $0.id == strongSelf.selectedId }), let index = strongSelf.availableFilters.firstIndex(where: { $0.id == id }) {
                        let previousId = strongSelf.selectedId
                        let offsetDirection: CGFloat = index < previousIndex ? 1.0 : -1.0
                        let offset = offsetDirection * layout.size.width
                        
                        var validNodeIds: [ChatListFilterTabEntryId] = []
                        for i in max(0, index - 1) ... min(strongSelf.availableFilters.count - 1, index + 1) {
                            validNodeIds.append(strongSelf.availableFilters[i].id)
                        }
                        
                        var removeIds: [ChatListFilterTabEntryId] = []
                        for (id, _) in strongSelf.itemNodes {
                            if !validNodeIds.contains(id) {
                                removeIds.append(id)
                            }
                        }
                        for id in removeIds {
                            if let itemNode = strongSelf.itemNodes.removeValue(forKey: id) {
                                if id == previousId {
                                    transition.updateFrame(node: itemNode, frame: itemNode.frame.offsetBy(dx: offset, dy: 0.0), completion: { [weak itemNode] _ in
                                        itemNode?.removeFromSupernode()
                                    })
                                } else {
                                    itemNode.removeFromSupernode()
                                }
                            }
                        }
                        
                        strongSelf.itemNodes[id] = itemNode
                        strongSelf.addSubnode(itemNode)
                        
                        let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size)
                        itemNode.frame = itemFrame
                        
                        transition.animatePositionAdditive(node: itemNode, offset: CGPoint(x: -offset, y: 0.0))
                                                
                        itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                        if let scrollingOffset = strongSelf.scrollingOffset {
                            itemNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: .immediate)
                        }
                        
                        strongSelf.selectedId = id
                        if let currentItemNode = strongSelf.currentItemNodeValue {
                            itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: currentItemNode.listNode.isNavigationHidden)
                        }
                        strongSelf.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                        
                        strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                        
                        strongSelf.currentItemFilterUpdated?(strongSelf.currentItemFilter, strongSelf.transitionFraction, transition, false)
                    }
                    
                    completion?()
                }))
                
                if let (layout, _, visualNavigationHeight, originalNavigationHeight, _, insets, _, _, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                    itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .immediate)
                    
                    if let scrollingOffset = self.scrollingOffset {
                        itemNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: .immediate)
                    }
                    return
                }
            }
        }
    }
    
    func updateScrollingOffset(navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.scrollingOffset = (navigationHeight, offset)
        for (_, itemNode) in self.itemNodes {
            itemNode.updateScrollingOffset(navigationHeight: navigationHeight, offset: offset, transition: transition)
        }
    }
    
    public func update(layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, insets: UIEdgeInsets, isReorderingFilters: Bool, isEditing: Bool, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset)
        
        self._validLayoutReady.set(.single(true))
        
        transition.updateAlpha(node: self, alpha: isReorderingFilters ? 0.5 : 1.0)
        self.isUserInteractionEnabled = !isReorderingFilters
        
        if let _ = inlineNavigationLocation {
            transition.updateBackgroundColor(node: self, color: self.presentationData.theme.chatList.backgroundColor.mixedWith(self.presentationData.theme.chatList.pinnedItemBackgroundColor, alpha: inlineNavigationTransitionFraction))
        } else {
            transition.updateBackgroundColor(node: self, color: self.presentationData.theme.chatList.backgroundColor)
        }
        
        self.panRecognizer?.isEnabled = !isEditing
        
        transition.updateFrame(layer: self.leftSeparatorLayer, frame: CGRect(origin: CGPoint(x: -UIScreenPixel, y: 0.0), size: CGSize(width: UIScreenPixel, height: layout.size.height)))
        
        if let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
            var validNodeIds: [ChatListFilterTabEntryId] = []
            for i in max(0, selectedIndex - 1) ... min(self.availableFilters.count - 1, selectedIndex + 1) {
                let id = self.availableFilters[i].id
                validNodeIds.append(id)
                
                if self.itemNodes[id] == nil && self.enableAdjacentFilterLoading && !self.disableItemNodeOperationsWhileAnimating {
                    let itemNode = ChatListContainerItemNode(context: self.context, controller: self.controller, location: self.location, filter: self.availableFilters[i].filter, chatListMode: self.chatListMode, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
                        self?.filterBecameEmpty(filter)
                    }, emptyAction: { [weak self] filter in
                        self?.filterEmptyAction(filter)
                    }, secondaryEmptyAction: { [weak self] in
                        self?.secondaryEmptyAction()
                    }, openArchiveSettings: { [weak self] in
                        self?.openArchiveSettings()
                    }, autoSetReady: false)
                    itemNode.listNode.tempTopInset = self.tempTopInset
                    self.itemNodes[id] = itemNode
                }
            }
            
            var removeIds: [ChatListFilterTabEntryId] = []
            var animateSlidingIds: [ChatListFilterTabEntryId] = []
            var slidingOffset: CGFloat?
            for (id, itemNode) in self.itemNodes {
                if !validNodeIds.contains(id) {
                    removeIds.append(id)
                }
                guard let index = self.availableFilters.firstIndex(where: { $0.id == id }) else {
                    continue
                }
                let indexDistance = CGFloat(index - selectedIndex) + self.transitionFraction
                
                let wasAdded = itemNode.supernode == nil
                var nodeTransition = transition
                if wasAdded {
                    self.addSubnode(itemNode)
                    nodeTransition = .immediate
                }
                
                let itemFrame = CGRect(origin: CGPoint(x: indexDistance * layout.size.width, y: 0.0), size: layout.size)
                if !wasAdded && slidingOffset == nil {
                    slidingOffset = itemNode.frame.minX - itemFrame.minX
                }
                nodeTransition.updateFrame(node: itemNode, frame: itemFrame, completion: { _ in
                })
                
                var itemInlineNavigationTransitionFraction = inlineNavigationTransitionFraction
                if indexDistance != 0 {
                    if itemInlineNavigationTransitionFraction != 0.0 || itemInlineNavigationTransitionFraction != 1.0 {
                        itemInlineNavigationTransitionFraction = itemNode.validLayout?.inlineNavigationTransitionFraction ?? 0.0
                    }
                }
                
                itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: itemInlineNavigationTransitionFraction, storiesInset: storiesInset, transition: nodeTransition)
                if let scrollingOffset = self.scrollingOffset {
                    itemNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: nodeTransition)
                }
                
                if wasAdded, case .animated = transition {
                    animateSlidingIds.append(id)
                }
            }
            if let slidingOffset = slidingOffset {
                for id in animateSlidingIds {
                    if let itemNode = self.itemNodes[id] {
                        transition.animatePositionAdditive(node: itemNode, offset: CGPoint(x: slidingOffset, y: 0.0), completion: {
                        })
                    }
                }
            }
            if !self.disableItemNodeOperationsWhileAnimating {
                for id in removeIds {
                    if let itemNode = self.itemNodes.removeValue(forKey: id) {
                        itemNode.removeFromSupernode()
                    }
                }
            }
        }
    }
}

final class ChatListControllerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let location: ChatListControllerLocation
    private var presentationData: PresentationData
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    let mainContainerNode: ChatListContainerNode
    
    var effectiveContainerNode: ChatListContainerNode {
        if let inlineStackContainerNode = self.inlineStackContainerNode {
            return inlineStackContainerNode
        } else {
            return self.mainContainerNode
        }
    }
    
    private(set) var inlineStackContainerTransitionFraction: CGFloat = 0.0
    private(set) var inlineStackContainerNode: ChatListContainerNode?
    private var inlineContentPanRecognizer: InteractiveTransitionGestureRecognizer?
    var temporaryContentOffsetChangeTransition: ContainedViewLayoutTransition?
    
    private var tapRecognizer: UITapGestureRecognizer?
    var navigationBar: NavigationBar?
    let navigationBarView = ComponentView<Empty>()
    weak var controller: ChatListControllerImpl?
    
    var toolbar: Toolbar?
    private var toolbarNode: ToolbarNode?
    var toolbarActionSelected: ((ToolbarActionOption) -> Void)?
    
    private var isSearchDisplayControllerActive: Bool = false
    private var skipSearchDisplayControllerLayout: Bool = false
    private(set) var searchDisplayController: SearchDisplayController?
    
    var isReorderingFilters: Bool = false
    var didBeginSelectingChatsWhileEditing: Bool = false
    var isEditing: Bool = false
    
    var tempAllowAvatarExpansion: Bool = false
    private var tempDisableStoriesAnimations: Bool = false
    private var tempNavigationScrollingTransition: ContainedViewLayoutTransition?
    
    private var allowOverscrollStoryExpansion: Bool = false
    private var currentOverscrollStoryExpansionTimestamp: Double?
    
    private var allowOverscrollItemExpansion: Bool = false
    private var currentOverscrollItemExpansionTimestamp: Double?
    
    private var containerLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, storiesInset: CGFloat)?
    
    var contentScrollingEnded: ((ListView) -> Bool)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((EnginePeer, Int64?, Bool) -> Void)?
    var requestOpenRecentPeerOptions: ((EnginePeer) -> Void)?
    var requestOpenMessageFromSearch: ((EnginePeer, Int64?, EngineMessage.Id, Bool) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    var dismissSelfIfCompletedPresentation: (() -> Void)?
    var isEmptyUpdated: ((Bool) -> Void)?
    var emptyListAction: ((EnginePeer.Id?) -> Void)?
    var cancelEditing: (() -> Void)?

    let debugListView = ListView()
    
    init(context: AccountContext, location: ChatListControllerLocation, previewing: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, controller: ChatListControllerImpl) {
        self.context = context
        self.location = location
        self.presentationData = presentationData
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        var filterBecameEmpty: ((ChatListFilter?) -> Void)?
        var filterEmptyAction: ((ChatListFilter?) -> Void)?
        var secondaryEmptyAction: (() -> Void)?
        var openArchiveSettings: (() -> Void)?
        self.mainContainerNode = ChatListContainerNode(context: context, controller: controller, location: location, previewing: previewing, controlsHistoryPreload: controlsHistoryPreload, isInlineMode: false, presentationData: presentationData, animationCache: animationCache, animationRenderer: animationRenderer, filterBecameEmpty: { filter in
            filterBecameEmpty?(filter)
        }, filterEmptyAction: { filter in
            filterEmptyAction?(filter)
        }, secondaryEmptyAction: {
            secondaryEmptyAction?()
        }, openArchiveSettings: {
            openArchiveSettings?()
        })
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.mainContainerNode)
        
        self.mainContainerNode.contentOffsetChanged = { [weak self] offset, listView in
            self?.contentOffsetChanged(offset: offset, listView: listView, isPrimary: true)
        }
        self.mainContainerNode.contentScrollingEnded = { [weak self] listView in
            return self?.contentScrollingEnded(listView: listView, isPrimary: true) ?? false
        }
        self.mainContainerNode.didBeginInteractiveDragging = { [weak self] listView in
            self?.didBeginInteractiveDragging(listView: listView, isPrimary: true)
        }
        self.mainContainerNode.endedInteractiveDragging = { [weak self] listView in
            self?.endedInteractiveDragging(listView: listView, isPrimary: true)
        }
        self.mainContainerNode.shouldStopScrolling = { [weak self] listView, velocity in
            return self?.shouldStopScrolling(listView: listView, velocity: velocity, isPrimary: true) ?? false
        }
        
        self.addSubnode(self.debugListView)
        
        filterBecameEmpty = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if case .chatList(.archive) = strongSelf.location {
                strongSelf.dismissSelfIfCompletedPresentation?()
            }
        }
        filterEmptyAction = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.emptyListAction?(nil)
        }
        
        secondaryEmptyAction = { [weak self] in
            guard let strongSelf = self, case let .forum(peerId) = strongSelf.location, let controller = strongSelf.controller else {
                return
            }
            
            let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false))
            (controller.navigationController as? NavigationController)?.replaceController(controller, with: chatController, animated: false)
        }
        
        openArchiveSettings = { [weak self] in
            guard let self, let controller = self.controller else {
                return
            }
            controller.push(self.context.sharedContext.makeArchiveSettingsController(context: self.context))
        }
        
        self.mainContainerNode.onFilterSwitch = { [weak self] in
            if let strongSelf = self {
                strongSelf.controller?.dismissAllUndoControllers()
            }
        }
        
        self.mainContainerNode.onStoriesLockedUpdated = { [weak self] isLocked in
            guard let self else {
                return
            }
            if isLocked {
                self.controller?.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                //self.controller?.requestLayout(transition: .immediate)
            } else {
                self.controller?.requestLayout(transition: .immediate)
            }
        }
        
        self.mainContainerNode.canExpandHiddenItems = { [weak self] in
            guard let self, let controller = self.controller else {
                return false
            }
            
            if let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    if navigationBarComponentView.storiesUnlocked {
                        return true
                    }
                }
                return false
            } else {
                return true
            }
        }
        
        let inlineContentPanRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.inlineContentPanGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, strongSelf.inlineStackContainerNode != nil else {
                return []
            }
            let directions: InteractiveTransitionGestureRecognizerDirections = [.rightCenter]
            return directions
        }, edgeWidth: .widthMultiplier(factor: 1.0 / 6.0, min: 22.0, max: 80.0))
        inlineContentPanRecognizer.delegate = self
        inlineContentPanRecognizer.delaysTouchesBegan = false
        inlineContentPanRecognizer.cancelsTouchesInView = true
        self.inlineContentPanRecognizer = inlineContentPanRecognizer
        self.view.addGestureRecognizer(inlineContentPanRecognizer)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.view.addGestureRecognizer(tapRecognizer)
        tapRecognizer.isEnabled = false
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelEditing?()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func inlineContentPanGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            break
        case .changed:
            if let inlineStackContainerNode = self.inlineStackContainerNode {
                let translation = recognizer.translation(in: self.view)
                var transitionFraction = translation.x / inlineStackContainerNode.bounds.width
                transitionFraction = 1.0 - max(0.0, min(1.0, transitionFraction))
                self.inlineStackContainerTransitionFraction = transitionFraction
                self.controller?.requestLayout(transition: .immediate)
            }
        case .cancelled, .ended:
            if let inlineStackContainerNode = self.inlineStackContainerNode {
                let translation = recognizer.translation(in: self.view)
                let velocity = recognizer.velocity(in: self.view)
                var directionIsToRight: Bool?
                if abs(velocity.x) > 10.0 {
                    if translation.x > 0.0 {
                        if velocity.x <= 0.0 {
                            directionIsToRight = nil
                        } else {
                            directionIsToRight = true
                        }
                    } else {
                        if velocity.x >= 0.0 {
                            directionIsToRight = nil
                        } else {
                            directionIsToRight = false
                        }
                    }
                } else {
                    if abs(translation.x) > inlineStackContainerNode.bounds.width / 2.0 {
                        directionIsToRight = translation.x > inlineStackContainerNode.bounds.width / 2.0
                    }
                }
                
                if let directionIsToRight = directionIsToRight, directionIsToRight {
                    self.controller?.setInlineChatList(location: nil)
                } else {
                    self.inlineStackContainerTransitionFraction = 1.0
                    self.controller?.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        default:
            break
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.mainContainerNode.updatePresentationData(presentationData)
        self.inlineStackContainerNode?.updatePresentationData(presentationData)
        self.searchDisplayController?.updatePresentationData(presentationData)
        
        if let toolbarNode = self.toolbarNode {
            toolbarNode.updateTheme(ToolbarTheme(rootControllerTheme: self.presentationData.theme))
        }
    }
    
    private func updateNavigationBar(layout: ContainerViewLayout, deferScrollApplication: Bool, transition: Transition) -> (navigationHeight: CGFloat, storiesInset: CGFloat) {
        let headerContent = self.controller?.updateHeaderContent()
        
        var tabsNode: ASDisplayNode?
        var tabsNodeIsSearch = false
        
        if let value = self.controller?.searchTabsNode {
            tabsNode = value
            tabsNodeIsSearch = true
        } else if let value = self.controller?.tabsNode, self.controller?.hasTabs == true {
            tabsNode = value
        }
        
        var effectiveStorySubscriptions: EngineStorySubscriptions?
        if let controller = self.controller, case .forum = controller.location {
            effectiveStorySubscriptions = nil
        } else {
            if let controller = self.controller, let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
                effectiveStorySubscriptions = controller.orderedStorySubscriptions
            } else {
                effectiveStorySubscriptions = EngineStorySubscriptions(accountItem: nil, items: [], hasMoreToken: nil)
            }
        }
        
        let navigationBarSize = self.navigationBarView.update(
            transition: transition,
            component: AnyComponent(ChatListNavigationBar(
                context: self.context,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                sideInset: layout.safeInsets.left,
                isSearchActive: self.isSearchDisplayControllerActive,
                primaryContent: headerContent?.primaryContent,
                secondaryContent: headerContent?.secondaryContent,
                secondaryTransition: self.inlineStackContainerTransitionFraction,
                storySubscriptions: effectiveStorySubscriptions,
                storiesIncludeHidden: self.location == .chatList(groupId: .archive),
                uploadProgress: self.controller?.storyUploadProgress,
                tabsNode: tabsNode,
                tabsNodeIsSearch: tabsNodeIsSearch,
                accessoryPanelContainer: self.controller?.accessoryPanelContainer,
                accessoryPanelContainerHeight: self.controller?.accessoryPanelContainerHeight ?? 0.0,
                activateSearch: { [weak self] searchContentNode in
                    guard let self, let controller = self.controller else {
                        return
                    }
                    
                    var isForum = false
                    if case .forum = controller.location {
                        isForum = true
                    }
                    
                    let filter: ChatListSearchFilter = isForum ? .topics : .chats
                    
                    controller.activateSearch(
                        filter: filter,
                        query: nil,
                        skipScrolling: false,
                        searchContentNode: searchContentNode
                    )
                },
                openStatusSetup: { [weak self] sourceView in
                    guard let self, let controller = self.controller else {
                        return
                    }
                    controller.openStatusSetup(sourceView: sourceView)
                },
                allowAutomaticOrder: { [weak self] in
                    guard let self, let controller = self.controller else {
                        return
                    }
                    controller.allowAutomaticOrder()
                }
            )),
            environment: {},
            containerSize: layout.size
        )
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            if deferScrollApplication {
                navigationBarComponentView.deferScrollApplication = true
            }
            
            if navigationBarComponentView.superview == nil {
                self.view.addSubview(navigationBarComponentView)
            }
            transition.setFrame(view: navigationBarComponentView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
            
            return (navigationBarSize.height, 0.0)
        } else {
            return (0.0, 0.0)
        }
    }
    
    private func updateNavigationScrolling(navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var mainOffset: CGFloat
        if let contentOffset = self.mainContainerNode.contentOffset, case let .known(value) = contentOffset {
            mainOffset = value
        } else {
            mainOffset = navigationHeight
        }
        
        self.mainContainerNode.updateScrollingOffset(navigationHeight: navigationHeight, offset: mainOffset, transition: transition)
        
        mainOffset = min(mainOffset, ChatListNavigationBar.searchScrollHeight)
        if abs(mainOffset) < 0.1 {
            mainOffset = 0.0
        }
        
        let resultingOffset: CGFloat
        if let inlineStackContainerNode = self.inlineStackContainerNode {
            var inlineOffset: CGFloat
            if let contentOffset = inlineStackContainerNode.contentOffset, case let .known(value) = contentOffset {
                inlineOffset = value
            } else {
                inlineOffset = navigationHeight
            }
            inlineOffset = min(inlineOffset, ChatListNavigationBar.searchScrollHeight)
            if abs(inlineOffset) < 0.1 {
                inlineOffset = 0.0
            }
            
            resultingOffset = mainOffset * (1.0 - self.inlineStackContainerTransitionFraction) + inlineOffset * self.inlineStackContainerTransitionFraction
        } else {
            resultingOffset = mainOffset
        }
        
        var offset = resultingOffset
        if self.isSearchDisplayControllerActive {
            offset = 0.0
        }
        
        var allowAvatarsExpansion: Bool = true
        if !self.mainContainerNode.currentItemNode.startedScrollingAtUpperBound && !self.tempAllowAvatarExpansion {
            if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                if !navigationBarComponentView.storiesUnlocked {
                    allowAvatarsExpansion = false
                }
            }
        }
        
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.applyScroll(offset: offset, allowAvatarsExpansion: allowAvatarsExpansion, forceUpdate: false, transition: Transition(transition).withUserData(ChatListNavigationBar.AnimationHint(
                disableStoriesAnimations: self.tempDisableStoriesAnimations,
                crossfadeStoryPeers: false
            )))
        }
        
        let mainDelta: CGFloat
        if let _ = self.inlineStackContainerNode {
            mainDelta = resultingOffset - max(0.0, mainOffset)
        } else {
            mainDelta = 0.0
        }
        transition.updateSublayerTransformOffset(layer: self.mainContainerNode.layer, offset: CGPoint(x: 0.0, y: -mainDelta))
    }
    
    func requestNavigationBarLayout(transition: Transition) {
        guard let (layout, _, _, _, _) = self.containerLayout else {
            return
        }
        let _ = self.updateNavigationBar(layout: layout, deferScrollApplication: false, transition: transition)
    }
    
    func scrollToStories(animated: Bool) {
        if self.inlineStackContainerNode != nil {
            return
        }
        
        if let controller = self.controller, let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
            let _ = storySubscriptions
        
            self.tempAllowAvatarExpansion = true
            self.tempDisableStoriesAnimations = !animated
            self.tempNavigationScrollingTransition = animated ? .animated(duration: 0.3, curve: .custom(0.33, 0.52, 0.25, 0.99)) : .immediate
            self.mainContainerNode.scrollToTop(animated: animated, adjustForTempInset: true)
            self.tempAllowAvatarExpansion = false
            self.tempDisableStoriesAnimations = false
            tempNavigationScrollingTransition = nil
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, storiesInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var navigationBarHeight = navigationBarHeight
        var visualNavigationHeight = visualNavigationHeight
        var cleanNavigationBarHeight = cleanNavigationBarHeight
        var storiesInset = storiesInset
        
        let navigationBarLayout = self.updateNavigationBar(layout: layout, deferScrollApplication: true, transition: Transition(transition))
        self.mainContainerNode.initialScrollingOffset = ChatListNavigationBar.searchScrollHeight + navigationBarLayout.storiesInset
        
        navigationBarHeight = navigationBarLayout.navigationHeight
        visualNavigationHeight = navigationBarLayout.navigationHeight
        cleanNavigationBarHeight = navigationBarLayout.navigationHeight
        storiesInset = navigationBarLayout.storiesInset
        
        self.containerLayout = (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, storiesInset)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        if let toolbar = self.toolbar {
            var tabBarHeight: CGFloat
            var options: ContainerViewLayoutInsetOptions = []
            if layout.metrics.widthClass == .regular {
                options.insert(.input)
            }
            
            var heightInset: CGFloat = 0.0
            if case .forum = self.location {
                heightInset = 4.0
            }
            
            let bottomInset: CGFloat = layout.insets(options: options).bottom
            if !layout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
                insets.bottom += 34.0
            } else {
                tabBarHeight = 49.0 - heightInset + bottomInset
                insets.bottom += 49.0 - heightInset
            }
            
            let toolbarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight))
            
            if let toolbarNode = self.toolbarNode {
                transition.updateFrame(node: toolbarNode, frame: toolbarFrame)
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(rootControllerTheme: self.presentationData.theme), displaySeparator: true, left: { [weak self] in
                    self?.toolbarActionSelected?(.left)
                }, right: { [weak self] in
                    self?.toolbarActionSelected?(.right)
                }, middle: { [weak self] in
                    self?.toolbarActionSelected?(.middle)
                })
                toolbarNode.frame = toolbarFrame
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
                self.addSubnode(toolbarNode)
                self.toolbarNode = toolbarNode
                if transition.isAnimated {
                    toolbarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        } else if let toolbarNode = self.toolbarNode {
            self.toolbarNode = nil
            transition.updateAlpha(node: toolbarNode, alpha: 0.0, completion: { [weak toolbarNode] _ in
                toolbarNode?.removeFromSupernode()
            })
        }
        
        var childrenLayout = layout
        childrenLayout.intrinsicInsets = UIEdgeInsets(top: visualNavigationHeight, left: childrenLayout.intrinsicInsets.left, bottom: childrenLayout.intrinsicInsets.bottom, right: childrenLayout.intrinsicInsets.right)
        self.controller?.presentationContext.containerLayoutUpdated(childrenLayout, transition: transition)
        
        transition.updateFrame(node: self.mainContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        var mainNavigationBarHeight = navigationBarHeight
        var cleanMainNavigationBarHeight = cleanNavigationBarHeight
        var mainInsets = insets
        if self.inlineStackContainerNode != nil && "".isEmpty {
            mainNavigationBarHeight = visualNavigationHeight
            cleanMainNavigationBarHeight = visualNavigationHeight
            mainInsets.top = visualNavigationHeight
        }
        self.mainContainerNode.update(layout: layout, navigationBarHeight: mainNavigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: navigationBarHeight, cleanNavigationBarHeight: cleanMainNavigationBarHeight, insets: mainInsets, isReorderingFilters: self.isReorderingFilters, isEditing: self.isEditing, inlineNavigationLocation: self.inlineStackContainerNode?.location, inlineNavigationTransitionFraction: self.inlineStackContainerTransitionFraction, storiesInset: storiesInset, transition: transition)
        
        if let inlineStackContainerNode = self.inlineStackContainerNode {
            var inlineStackContainerNodeTransition = transition
            var animateIn = false
            if inlineStackContainerNode.supernode == nil {
                self.insertSubnode(inlineStackContainerNode, aboveSubnode: self.mainContainerNode)
                inlineStackContainerNodeTransition = .immediate
                animateIn = true
            }
            
            let inlineSideInset: CGFloat = layout.safeInsets.left + 72.0
            var inlineStackFrame = CGRect(origin: CGPoint(x: inlineSideInset, y: 0.0), size: CGSize(width: layout.size.width - inlineSideInset, height: layout.size.height))
            inlineStackFrame.origin.x += (1.0 - self.inlineStackContainerTransitionFraction) * inlineStackFrame.width
            inlineStackContainerNodeTransition.updateFrame(node: inlineStackContainerNode, frame: inlineStackFrame)
            var inlineLayout = layout
            inlineLayout.size.width -= inlineSideInset
            inlineLayout.safeInsets.left = 0.0
            inlineLayout.intrinsicInsets.left = 0.0
            inlineLayout.additionalInsets.left = 0.0
            
            var inlineInsets = insets
            inlineInsets.left = 0.0
            
            let inlineNavigationHeight: CGFloat = navigationBarLayout.navigationHeight - navigationBarLayout.storiesInset
            
            inlineStackContainerNode.update(layout: inlineLayout, navigationBarHeight: inlineNavigationHeight, visualNavigationHeight: inlineNavigationHeight, originalNavigationHeight: inlineNavigationHeight, cleanNavigationBarHeight: inlineNavigationHeight, insets: inlineInsets, isReorderingFilters: self.isReorderingFilters, isEditing: self.isEditing, inlineNavigationLocation: nil, inlineNavigationTransitionFraction: 0.0, storiesInset: storiesInset, transition: inlineStackContainerNodeTransition)
            
            if animateIn {
                transition.animatePosition(node: inlineStackContainerNode, from: CGPoint(x: inlineStackContainerNode.position.x + inlineStackContainerNode.bounds.width + UIScreenPixel, y: inlineStackContainerNode.position.y))
            }
        }
        
        self.tapRecognizer?.isEnabled = self.isReorderingFilters
        
        if let searchDisplayController = self.searchDisplayController {
            if !self.skipSearchDisplayControllerLayout {
                searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: transition)
            }
        }
        
        self.updateNavigationScrolling(navigationHeight: navigationBarLayout.navigationHeight, transition: transition)
        
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.deferScrollApplication = false
            navigationBarComponentView.applyCurrentScroll(transition: Transition(transition))
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode, displaySearchFilters: Bool, hasDownloads: Bool, initialFilter: ChatListSearchFilter, navigationController: NavigationController?) -> (ASDisplayNode, (Bool) -> Void)? {
        guard let (containerLayout, _, _, cleanNavigationBarHeight, _) = self.containerLayout, self.searchDisplayController == nil else {
            return nil
        }
        
        let effectiveLocation = self.inlineStackContainerNode?.location ?? self.location
        
        let filter: ChatListNodePeersFilter = []
        if case .forum = effectiveLocation {
            //filter.insert(.excludeRecent)
        }
        
        let contentNode = ChatListSearchContainerNode(context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, filter: filter, requestPeerType: nil, location: effectiveLocation, displaySearchFilters: displaySearchFilters, hasDownloads: hasDownloads, initialFilter: initialFilter, openPeer: { [weak self] peer, _, threadId, dismissSearch in
            self?.requestOpenPeerFromSearch?(peer, threadId, dismissSearch)
        }, openDisabledPeer: { _, _ in
        }, openRecentPeerOptions: { [weak self] peer in
            self?.requestOpenRecentPeerOptions?(peer)
        }, openMessage: { [weak self] peer, threadId, messageId, deactivateOnAction in
            if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                requestOpenMessageFromSearch(peer, threadId, messageId, deactivateOnAction)
            }
        }, addContact: { [weak self] phoneNumber in
            if let requestAddContact = self?.requestAddContact {
                requestAddContact(phoneNumber)
            }
        }, peerContextAction: self.peerContextAction, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, presentInGlobalOverlay: { [weak self] c, a in
            self?.controller?.presentInGlobalOverlay(c, with: a)
        }, navigationController: navigationController, parentController: { [weak self] in
            return self?.controller
        })
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, contentNode: contentNode, cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        self.mainContainerNode.accessibilityElementsHidden = true
        self.inlineStackContainerNode?.accessibilityElementsHidden = true
                
        return (contentNode.filterContainerNode, { [weak self] focus in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.isSearchDisplayControllerActive = true
            
            strongSelf.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: cleanNavigationBarHeight, transition: .immediate)
            strongSelf.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
                guard let self else {
                    return
                }
                
                if isSearchBar {
                    if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                        navigationBarComponentView.addSubnode(subnode)
                    }
                } else {
                    self.insertSubnode(subnode, aboveSubnode: self.debugListView)
                }
            }, placeholder: placeholderNode, focus: focus)
            
            strongSelf.controller?.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
        })
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) -> (() -> Void)? {
        if let searchDisplayController = self.searchDisplayController {
            self.isSearchDisplayControllerActive = false
            self.searchDisplayController = nil
            self.mainContainerNode.accessibilityElementsHidden = false
            self.inlineStackContainerNode?.accessibilityElementsHidden = false
            
            return { [weak self, weak placeholderNode] in
                if let strongSelf = self, let placeholderNode, let (layout, _, _, cleanNavigationBarHeight, _) = strongSelf.containerLayout {
                    searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
                    
                    searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                    
                    strongSelf.controller?.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        } else {
            return nil
        }
    }
    
    func clearHighlightAnimated(_ animated: Bool) {
        self.mainContainerNode.currentItemNode.clearHighlightAnimated(true)
        self.inlineStackContainerNode?.currentItemNode.clearHighlightAnimated(true)
    }
    
    private var contentOffsetSyncLockedIn: Bool = false
    
    func willScrollToTop() {
        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
            navigationBarComponentView.applyScroll(offset: 0.0, allowAvatarsExpansion: false, transition: Transition(animation: .curve(duration: 0.3, curve: .slide)))
        }
    }
    
    private func contentOffsetChanged(offset: ListViewVisibleContentOffset, listView: ListView, isPrimary: Bool) {
        guard let containerLayout = self.containerLayout else {
            return
        }
        self.updateNavigationScrolling(navigationHeight: containerLayout.navigationBarHeight, transition: self.tempNavigationScrollingTransition ?? .immediate)
        
        if listView.isDragging {
            var overscrollSelectedId: EnginePeer.Id?
            var overscrollHiddenChatItemsAllowed = false
            if let controller = self.controller, let componentView = controller.chatListHeaderView(), let storyPeerListView = componentView.storyPeerListView() {
                overscrollSelectedId = storyPeerListView.overscrollSelectedId
                overscrollHiddenChatItemsAllowed = storyPeerListView.overscrollHiddenChatItemsAllowed
            }
            
            if let chatListNode = listView as? ChatListNode {
                if chatListNode.hasItemsToBeRevealed() {
                    overscrollSelectedId = nil
                }
            }
            
            if let controller = self.controller {
                if let peerId = overscrollSelectedId {
                    if self.allowOverscrollStoryExpansion && self.inlineStackContainerNode == nil && isPrimary {
                        let timestamp = CACurrentMediaTime()
                        if let _ = self.currentOverscrollStoryExpansionTimestamp {
                        } else {
                            self.currentOverscrollStoryExpansionTimestamp = timestamp
                        }
                        
                        if let currentOverscrollStoryExpansionTimestamp = self.currentOverscrollStoryExpansionTimestamp, currentOverscrollStoryExpansionTimestamp <= timestamp - 0.0 {
                            self.allowOverscrollStoryExpansion = false
                            self.currentOverscrollStoryExpansionTimestamp = nil
                            self.allowOverscrollItemExpansion = false
                            self.currentOverscrollItemExpansionTimestamp = nil
                            HapticFeedback().tap()
                            
                            controller.openStories(peerId: peerId)
                        }
                    }
                } else {
                    if !overscrollHiddenChatItemsAllowed {
                        var manuallyAllow = false
                        
                        if isPrimary {
                            if let storySubscriptions = controller.orderedStorySubscriptions, shouldDisplayStoriesInChatListHeader(storySubscriptions: storySubscriptions, isHidden: controller.location == .chatList(groupId: .archive)) {
                            } else {
                                manuallyAllow = true
                            }
                        } else {
                            manuallyAllow = true
                        }
                        
                        if manuallyAllow, case let .known(value) = offset, value + listView.tempTopInset <= -40.0 {
                            overscrollHiddenChatItemsAllowed = true
                        }
                    }
                
                    if overscrollHiddenChatItemsAllowed {
                        if self.allowOverscrollItemExpansion {
                            let timestamp = CACurrentMediaTime()
                            if let _ = self.currentOverscrollItemExpansionTimestamp {
                            } else {
                                self.currentOverscrollItemExpansionTimestamp = timestamp
                            }
                            
                            if let currentOverscrollItemExpansionTimestamp = self.currentOverscrollItemExpansionTimestamp, currentOverscrollItemExpansionTimestamp <= timestamp - 0.0 {
                                self.allowOverscrollItemExpansion = false
                                
                                if isPrimary {
                                    self.mainContainerNode.currentItemNode.revealScrollHiddenItem()
                                } else {
                                    self.inlineStackContainerNode?.currentItemNode.revealScrollHiddenItem()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func shouldStopScrolling(listView: ListView, velocity: CGFloat, isPrimary: Bool) -> Bool {
        if abs(velocity) > 0.8 {
            return false
        }
        
        if !isPrimary || self.inlineStackContainerNode == nil {
        } else {
            return false
        }
        
        guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
            return false
        }
        
        if let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
            let searchScrollOffset = clippedScrollOffset
            if searchScrollOffset > 0.0 && searchScrollOffset < ChatListNavigationBar.searchScrollHeight {
                return true
            } else if clippedScrollOffset < 0.0 && clippedScrollOffset > -listView.tempTopInset {
                return true
            }
        }
        
        return false
    }
    
    private func didBeginInteractiveDragging(listView: ListView, isPrimary: Bool) {
        if isPrimary {
            if let chatListNode = listView as? ChatListNode, !chatListNode.hasItemsToBeRevealed() {
                self.allowOverscrollStoryExpansion = true
            } else {
                self.allowOverscrollStoryExpansion = false
            }
        }
        self.allowOverscrollItemExpansion = true
    }
    
    private func endedInteractiveDragging(listView: ListView, isPrimary: Bool) {
        if isPrimary {
            self.allowOverscrollStoryExpansion = false
            self.currentOverscrollStoryExpansionTimestamp = nil
        }
        self.allowOverscrollItemExpansion = false
        self.currentOverscrollItemExpansionTimestamp = nil
    }
    
    private func contentScrollingEnded(listView: ListView, isPrimary: Bool) -> Bool {
        if !isPrimary || self.inlineStackContainerNode == nil {
        } else {
            return false
        }
        
        guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
            return false
        }
        
        if let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
            let searchScrollOffset = clippedScrollOffset
            if searchScrollOffset > 0.0 && searchScrollOffset < ChatListNavigationBar.searchScrollHeight {
                if searchScrollOffset < ChatListNavigationBar.searchScrollHeight * 0.5 {
                    let _ = listView.scrollToOffsetFromTop(0.0, animated: true)
                } else {
                    let _ = listView.scrollToOffsetFromTop(ChatListNavigationBar.searchScrollHeight, animated: true)
                }
                return true
            } else if clippedScrollOffset < 0.0 && clippedScrollOffset > -listView.tempTopInset {
                if navigationBarComponentView.storiesUnlocked {
                    let _ = listView.scrollToOffsetFromTop(-listView.tempTopInset, animated: true)
                } else {
                    let _ = listView.scrollToOffsetFromTop(0.0, animated: true)
                }
                return true
            }
        }
        
        return false
    }
    
    func makeInlineChatList(location: ChatListControllerLocation) -> ChatListContainerNode {
        var forumPeerId: EnginePeer.Id?
        if case let .forum(peerId) = location {
            forumPeerId = peerId
        }
        
        let inlineStackContainerNode = ChatListContainerNode(context: self.context, controller: self.controller, location: location, previewing: false, controlsHistoryPreload: false, isInlineMode: true, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, filterBecameEmpty: { _ in }, filterEmptyAction: { [weak self] _ in self?.emptyListAction?(forumPeerId) }, secondaryEmptyAction: {}, openArchiveSettings: {})
        return inlineStackContainerNode
    }
    
    func setInlineChatList(inlineStackContainerNode: ChatListContainerNode?) {
        if let inlineStackContainerNode = inlineStackContainerNode {
            if self.inlineStackContainerNode !== inlineStackContainerNode {
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    if navigationBarComponentView.storiesUnlocked {
                        let _ = self.mainContainerNode.currentItemNode.scrollToOffsetFromTop(self.mainContainerNode.currentItemNode.tempTopInset, animated: true)
                    }
                }
                
                inlineStackContainerNode.leftSeparatorLayer.isHidden = false
                
                inlineStackContainerNode.presentAlert = self.mainContainerNode.presentAlert
                inlineStackContainerNode.present = self.mainContainerNode.present
                inlineStackContainerNode.push = self.mainContainerNode.push
                inlineStackContainerNode.deletePeerChat = self.mainContainerNode.deletePeerChat
                inlineStackContainerNode.deletePeerThread = self.mainContainerNode.deletePeerThread
                inlineStackContainerNode.setPeerThreadStopped = self.mainContainerNode.setPeerThreadStopped
                inlineStackContainerNode.setPeerThreadPinned = self.mainContainerNode.setPeerThreadPinned
                inlineStackContainerNode.setPeerThreadHidden = self.mainContainerNode.setPeerThreadHidden
                inlineStackContainerNode.peerSelected = self.mainContainerNode.peerSelected
                inlineStackContainerNode.groupSelected = self.mainContainerNode.groupSelected
                inlineStackContainerNode.updatePeerGrouping = self.mainContainerNode.updatePeerGrouping
                
                inlineStackContainerNode.contentOffsetChanged = { [weak self] offset, listView in
                    self?.contentOffsetChanged(offset: offset, listView: listView, isPrimary: false)
                }
                inlineStackContainerNode.didBeginInteractiveDragging = { [weak self] listView in
                    self?.didBeginInteractiveDragging(listView: listView, isPrimary: false)
                }
                inlineStackContainerNode.endedInteractiveDragging = { [weak self] listView in
                    self?.endedInteractiveDragging(listView: listView, isPrimary: false)
                }
                inlineStackContainerNode.shouldStopScrolling = { [weak self] listView, velocity in
                    return self?.shouldStopScrolling(listView: listView, velocity: velocity, isPrimary: false) ?? false
                }
                inlineStackContainerNode.contentScrollingEnded = { [weak self] listView in
                    return self?.contentScrollingEnded(listView: listView, isPrimary: false) ?? false
                }
                
                inlineStackContainerNode.activateChatPreview = self.mainContainerNode.activateChatPreview
                inlineStackContainerNode.openStories = self.mainContainerNode.openStories
                inlineStackContainerNode.addedVisibleChatsWithPeerIds = self.mainContainerNode.addedVisibleChatsWithPeerIds
                inlineStackContainerNode.didBeginSelectingChats = self.mainContainerNode.didBeginSelectingChats
                inlineStackContainerNode.displayFilterLimit = nil
                
                let previousInlineStackContainerNode = self.inlineStackContainerNode
                
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View, let clippedScrollOffset = navigationBarComponentView.clippedScrollOffset {
                    let scrollOffset = max(0.0, clippedScrollOffset)
                    inlineStackContainerNode.initialScrollingOffset = scrollOffset
                }
                
                self.inlineStackContainerNode = inlineStackContainerNode
                self.inlineStackContainerTransitionFraction = 1.0
                
                if let _ = self.containerLayout {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    
                    if let contentOffset = self.mainContainerNode.contentOffset, case let .known(offset) = contentOffset, offset < 0.0 {
                        if let containerLayout = self.containerLayout {
                            self.updateNavigationScrolling(navigationHeight: containerLayout.navigationBarHeight, transition: transition)
                            self.mainContainerNode.scrollToTop(animated: true, adjustForTempInset: false)
                        }
                    }
                    
                    if let previousInlineStackContainerNode {
                        transition.updatePosition(node: previousInlineStackContainerNode, position: CGPoint(x: previousInlineStackContainerNode.position.x + previousInlineStackContainerNode.bounds.width + UIScreenPixel, y: previousInlineStackContainerNode.position.y), completion: { [weak previousInlineStackContainerNode] _ in
                            previousInlineStackContainerNode?.removeFromSupernode()
                        })
                    }
                    
                    self.controller?.requestLayout(transition: transition)
                } else {
                    previousInlineStackContainerNode?.removeFromSupernode()
                }
            }
        } else {
            if let inlineStackContainerNode = self.inlineStackContainerNode {
                self.inlineStackContainerNode = nil
                self.inlineStackContainerTransitionFraction = 0.0
                
                if let _ = self.containerLayout {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                    
                    transition.updatePosition(node: inlineStackContainerNode, position: CGPoint(x: inlineStackContainerNode.position.x + inlineStackContainerNode.bounds.width + UIScreenPixel, y: inlineStackContainerNode.position.y), completion: { [weak inlineStackContainerNode] _ in
                        inlineStackContainerNode?.removeFromSupernode()
                    })
                    
                    self.temporaryContentOffsetChangeTransition = transition
                    self.tempNavigationScrollingTransition = transition
                    self.controller?.requestLayout(transition: transition)
                    self.temporaryContentOffsetChangeTransition = nil
                    self.tempNavigationScrollingTransition = nil
                } else {
                    inlineStackContainerNode.removeFromSupernode()
                }
            }
        }
    }
    
    func playArchiveAnimation() {
        self.mainContainerNode.playArchiveAnimation()
    }
    
    func scrollToTop() {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.contentNode.scrollToTop()
        } else if let inlineStackContainerNode = self.inlineStackContainerNode {
            inlineStackContainerNode.scrollToTop(animated: true, adjustForTempInset: false)
        } else {
            self.mainContainerNode.scrollToTop(animated: true, adjustForTempInset: false)
        }
    }
    
    func scrollToTopIfStoriesAreExpanded() {
        if let contentOffset = self.mainContainerNode.contentOffset, case let .known(offset) = contentOffset, offset < 0.0 {
            self.mainContainerNode.scrollToTop(animated: true, adjustForTempInset: false)
            self.mainContainerNode.tempTopInset = 0.0
        }
    }
}

func shouldDisplayStoriesInChatListHeader(storySubscriptions: EngineStorySubscriptions, isHidden: Bool) -> Bool {
    if !storySubscriptions.items.isEmpty {
        return true
    }
    if !isHidden, let accountItem = storySubscriptions.accountItem {
        if accountItem.hasPending || accountItem.storyCount != 0 {
            return true
        }
    }
    return false
}
