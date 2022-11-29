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

enum ChatListContainerNodeFilter: Equatable {
    case all
    case filter(ChatListFilter)
    
    var id: ChatListFilterTabEntryId {
        switch self {
        case .all:
            return .all
        case let .filter(filter):
            return .filter(filter.id)
        }
    }
    
    var filter: ChatListFilter? {
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
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: []))
            let timestamp1: Int32 = 100000
            let peers: [EnginePeer.Id: EnginePeer] = [:]
            let interaction = ChatListNodeInteraction(context: context, animationCache: animationCache, animationRenderer: animationRenderer, activateSearch: {}, peerSelected: { _, _, _, _ in }, disabledPeerSelected: { _, _ in }, togglePeerSelected: { _, _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, setPeerThreadMuted: { _, _, _ in }, deletePeer: { _, _ in }, deletePeerThread: { _, _ in }, setPeerThreadStopped: { _, _, _ in }, setPeerThreadPinned: { _, _, _ in }, setPeerThreadHidden: { _, _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, toggleThreadsSelection: { _, _ in }, hidePsa: { _ in }, activateChatPreview: { _, _, _, gesture, _ in
                gesture?.cancel()
            }, present: { _ in }, openForumThread: { _, _ in })
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
                    associatedThreadInfo: nil
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
                    autoremoveTimeout: nil
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
    private let context: AccountContext
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private var presentationData: PresentationData
    private let becameEmpty: (ChatListFilter?) -> Void
    private let emptyAction: (ChatListFilter?) -> Void
    private let secondaryEmptyAction: () -> Void
    private let isInlineMode: Bool
    
    private var floatingHeaderOffset: CGFloat?
    
    private(set) var emptyNode: ChatListEmptyNode?
    var emptyShimmerEffectNode: ChatListShimmerNode?
    private var shimmerNodeOffset: CGFloat = 0.0
    let listNode: ChatListNode
    
    private(set) var validLayout: (size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat)?
    
    init(context: AccountContext, location: ChatListControllerLocation, filter: ChatListFilter?, previewing: Bool, isInlineMode: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, becameEmpty: @escaping (ChatListFilter?) -> Void, emptyAction: @escaping (ChatListFilter?) -> Void, secondaryEmptyAction: @escaping () -> Void) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.presentationData = presentationData
        self.becameEmpty = becameEmpty
        self.emptyAction = emptyAction
        self.secondaryEmptyAction = secondaryEmptyAction
        self.isInlineMode = isInlineMode
        
        self.listNode = ChatListNode(context: context, location: location, chatListFilter: filter, previewing: previewing, fillPreloadItems: controlsHistoryPreload, mode: .chatList, theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, animationCache: animationCache, animationRenderer: animationRenderer, disableAnimations: true, isInlineMode: isInlineMode)
        
        super.init()
        
        self.addSubnode(self.listNode)
        
        self.listNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let strongSelf = self else {
                return
            }
            var needsShimmerNode = false
            var shimmerNodeOffset: CGFloat = 0.0
            
            var needsEmptyNode = false
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
            case let .notEmpty(_, onlyGeneralThreadValue):
                needsEmptyNode = onlyGeneralThreadValue
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
                            subject = .chats
                        }
                    }
                    
                    let emptyNode = ChatListEmptyNode(context: context, subject: subject, isLoading: isLoading, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, action: {
                        self?.emptyAction(filter)
                    }, secondaryAction: {
                        self?.secondaryEmptyAction()
                    })
                    strongSelf.emptyNode = emptyNode
                    strongSelf.addSubnode(emptyNode)
                    if let (size, insets, _, _, _, _) = strongSelf.validLayout {
                        let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
                        emptyNode.frame = emptyNodeFrame
                        emptyNode.updateLayout(size: emptyNodeFrame.size, transition: .immediate)
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
                    if let (size, insets, _, _, _, _) = strongSelf.validLayout, let offset = strongSelf.floatingHeaderOffset {
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
            if let (size, insets, _, _, _, _) = strongSelf.validLayout, let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: transition)
            }
        }
    }
    
    private func layoutEmptyShimmerEffectNode(node: ChatListShimmerNode, size: CGSize, insets: UIEdgeInsets, verticalOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        node.update(context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, size: size, isInlineMode: self.isInlineMode, presentationData: self.presentationData, transition: .immediate)
        transition.updateFrameAdditive(node: node, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: size))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listNode.updateThemeAndStrings(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
        
        self.emptyNode?.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, visibleTopInset: visualNavigationHeight, originalTopInset: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction)
        
        if let emptyNode = self.emptyNode {
            let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
            transition.updateFrame(node: emptyNode, frame: emptyNodeFrame)
            emptyNode.updateLayout(size: emptyNodeFrame.size, transition: transition)
        }
    }
}

final class ChatListContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    let location: ChatListControllerLocation
    private let previewing: Bool
    private let isInlineMode: Bool
    private let controlsHistoryPreload: Bool
    private let filterBecameEmpty: (ChatListFilter?) -> Void
    private let filterEmptyAction: (ChatListFilter?) -> Void
    private let secondaryEmptyAction: () -> Void
    
    fileprivate var onFilterSwitch: (() -> Void)?
    
    private var presentationData: PresentationData
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private var itemNodes: [ChatListFilterTabEntryId: ChatListContainerItemNode] = [:]
    private var pendingItemNode: (ChatListFilterTabEntryId, ChatListContainerItemNode, Disposable)?
    private(set) var availableFilters: [ChatListContainerNodeFilter] = [.all]
    private var filtersLimit: Int32? = nil
    private var selectedId: ChatListFilterTabEntryId
    
    private(set) var transitionFraction: CGFloat = 0.0
    private var transitionFractionOffset: CGFloat = 0.0
    private var disableItemNodeOperationsWhileAnimating: Bool = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, insets: UIEdgeInsets, isReorderingFilters: Bool, isEditing: Bool, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat)?
    
    private var enableAdjacentFilterLoading: Bool = false
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    let leftSeparatorLayer: SimpleLayer
    
    private let _ready = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private let _validLayoutReady = Promise<Bool>()
    var validLayoutReady: Signal<Bool, NoError> {
        return _validLayoutReady.get()
    }
    
    private var currentItemNodeValue: ChatListContainerItemNode?
    var currentItemNode: ChatListNode {
        return self.currentItemNodeValue!.listNode
    }
    
    private let currentItemStateValue = Promise<(state: ChatListNodeState, filterId: Int32?)>()
    var currentItemState: Signal<(state: ChatListNodeState, filterId: Int32?), NoError> {
        return self.currentItemStateValue.get()
    }
    
    var currentItemFilterUpdated: ((ChatListFilterTabEntryId, CGFloat, ContainedViewLayoutTransition, Bool) -> Void)?
    var currentItemFilter: ChatListFilterTabEntryId {
        return self.currentItemNode.chatListFilter.flatMap { .filter($0.id) } ?? .all
    }
    
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
            previousItemNode.listNode.activateChatPreview = nil
            previousItemNode.listNode.addedVisibleChatsWithPeerIds = nil
            previousItemNode.listNode.didBeginSelectingChats = nil
            
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
        itemNode.listNode.contentOffsetChanged = { [weak self] offset in
            self?.contentOffsetChanged?(offset)
        }
        itemNode.listNode.contentScrollingEnded = { [weak self] listView in
            return self?.contentScrollingEnded?(listView) ?? false
        }
        itemNode.listNode.activateChatPreview = { [weak self] item, threadId, sourceNode, gesture, location in
            self?.activateChatPreview?(item, threadId, sourceNode, gesture, location)
        }
        itemNode.listNode.addedVisibleChatsWithPeerIds = { [weak self] ids in
            self?.addedVisibleChatsWithPeerIds?(ids)
        }
        itemNode.listNode.didBeginSelectingChats = { [weak self] in
            self?.didBeginSelectingChats?()
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
        
        if self.controlsHistoryPreload, case .chatList(groupId: .root) = self.location {
            self.context.account.viewTracker.chatListPreloadItems.set(combineLatest(queue: .mainQueue(),
                context.sharedContext.hasOngoingCall.get(),
                itemNode.listNode.preloadItems.get()
            )
            |> map { hasOngoingCall, preloadItems -> Set<ChatHistoryPreloadItem> in
                if hasOngoingCall {
                    return Set()
                } else {
                    return Set(preloadItems)
                }
            })
        }
    }
    
    var activateSearch: (() -> Void)?
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
    var peerSelected: ((EnginePeer, Int64?, Bool, Bool, ChatListNodeEntryPromoInfo?) -> Void)?
    var groupSelected: ((EngineChatList.Group) -> Void)?
    var updatePeerGrouping: ((EnginePeer.Id, Bool) -> Void)?
    fileprivate var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    fileprivate var contentScrollingEnded: ((ListView) -> Bool)?
    var activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    var addedVisibleChatsWithPeerIds: (([EnginePeer.Id]) -> Void)?
    var didBeginSelectingChats: (() -> Void)?
    var displayFilterLimit: (() -> Void)?
    
    init(context: AccountContext, location: ChatListControllerLocation, previewing: Bool, controlsHistoryPreload: Bool, isInlineMode: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, filterBecameEmpty: @escaping (ChatListFilter?) -> Void, filterEmptyAction: @escaping (ChatListFilter?) -> Void, secondaryEmptyAction: @escaping () -> Void) {
        self.context = context
        self.location = location
        self.previewing = previewing
        self.isInlineMode = isInlineMode
        self.filterBecameEmpty = filterBecameEmpty
        self.filterEmptyAction = filterEmptyAction
        self.secondaryEmptyAction = secondaryEmptyAction
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
        
        let itemNode = ChatListContainerItemNode(context: self.context, location: self.location, filter: nil, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
            self?.filterBecameEmpty(filter)
        }, emptyAction: { [weak self] filter in
            self?.filterEmptyAction(filter)
        }, secondaryEmptyAction: { [weak self] in
            self?.secondaryEmptyAction()
        })
        self.itemNodes[.all] = itemNode
        self.addSubnode(itemNode)
        
        self._ready.set(itemNode.listNode.ready)
        
        self.applyItemNodeAsCurrent(id: .all, itemNode: itemNode)
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, strongSelf.availableFilters.count > 1 else {
                return []
            }
            switch strongSelf.currentItemNode.visibleContentOffset() {
            case let .known(value):
                if value < -1.0 {
                    return []
                }
            case .none, .unknown:
                break
            }
            if !strongSelf.currentItemNode.isNavigationInAFinalState {
                return []
            }
            let directions: InteractiveTransitionGestureRecognizerDirections = [.leftCenter, .rightCenter]
            return directions
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
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let filtersLimit = self.filtersLimit.flatMap({ $0 + 1 }) ?? Int32(self.availableFilters.count)
        let maxFilterIndex = min(Int(filtersLimit), self.availableFilters.count) - 1
        
        switch recognizer.state {
        case .began:
            self.onFilterSwitch?()
            
            self.transitionFractionOffset = 0.0
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout, let itemNode = self.itemNodes[self.selectedId] {
                for (id, itemNode) in self.itemNodes {
                    if id != selectedId {
                        itemNode.emptyNode?.restartAnimation()
                    }
                }
                if let presentationLayer = itemNode.layer.presentation() {
                    self.transitionFraction = presentationLayer.frame.minX / layout.size.width
                    self.transitionFractionOffset = self.transitionFraction
                    if !self.transitionFraction.isZero {
                        for (_, itemNode) in self.itemNodes {
                            itemNode.layer.removeAllAnimations()
                        }
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
                        self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, true)
                    }
                }
            }
        case .changed:
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
                let translation = recognizer.translation(in: self.view)
                var transitionFraction = translation.x / layout.size.width
                
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    let range: CGFloat = 600.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
                
                if selectedIndex <= 0 && translation.x > 0.0 {
                    let overscroll = translation.x
                    transitionFraction = rubberBandingOffset(offset: overscroll, bandingStart: 0.0) / layout.size.width
                }
                
                if selectedIndex >= maxFilterIndex && translation.x < 0.0 {
                    let overscroll = -translation.x
                    transitionFraction = -rubberBandingOffset(offset: overscroll, bandingStart: 0.0) / layout.size.width
                    
                    if let filtersLimit = self.filtersLimit, selectedIndex >= filtersLimit - 1 {
                        transitionFraction = 0.0
                        recognizer.isEnabled = false
                        recognizer.isEnabled = true
                        
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
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, false)
            }
        case .cancelled, .ended:
            if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
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
                if let directionIsToRight = directionIsToRight {
                    var updatedIndex = selectedIndex
                    if directionIsToRight {
                        updatedIndex = min(updatedIndex + 1, maxFilterIndex)
                    } else {
                        updatedIndex = max(updatedIndex - 1, 0)
                    }
                    let switchToId = self.availableFilters[updatedIndex].id
                    if switchToId != self.selectedId, let itemNode = self.itemNodes[switchToId] {
                        self.selectedId = switchToId
                        self.applyItemNodeAsCurrent(id: switchToId, itemNode: itemNode)
                    }
                }
                self.transitionFraction = 0.0
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.45, curve: .spring)
                self.disableItemNodeOperationsWhileAnimating = true
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: transition)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
                DispatchQueue.main.async {
                    self.disableItemNodeOperationsWhileAnimating = false
                    if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout {
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
                    }
                }
            }
        default:
            break
        }
    }
    
    func fixContentOffset(offset: CGFloat) {
        self.currentItemNode.fixContentOffset(offset: offset)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
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
    
    func scrollToTop() {
        if let itemNode = self.itemNodes[self.selectedId] {
            itemNode.listNode.scrollToPosition(.top)
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
    
    func updateAvailableFilters(_ availableFilters: [ChatListContainerNodeFilter], limit: Int32?) {
        if self.availableFilters != availableFilters {
            let apply: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.availableFilters = availableFilters
                strongSelf.filtersLimit = limit
                if let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = strongSelf.validLayout {
                    strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
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
    
    func updateEnableAdjacentFilterLoading(_ value: Bool) {
        if value != self.enableAdjacentFilterLoading {
            self.enableAdjacentFilterLoading = value
            
            if self.enableAdjacentFilterLoading, let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout {
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
            }
        }
    }
    
    func switchToFilter(id: ChatListFilterTabEntryId, animated: Bool = true, completion: (() -> Void)? = nil) {
        self.onFilterSwitch?()
        if id != self.selectedId, let index = self.availableFilters.firstIndex(where: { $0.id == id }) {
            if let itemNode = self.itemNodes[id] {
                guard let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = self.validLayout else {
                    return
                }
                self.selectedId = id
                if let currentItemNode = self.currentItemNodeValue {
                    itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: currentItemNode.listNode.isNavigationHidden)
                }
                self.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: transition)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
                itemNode.emptyNode?.restartAnimation()
                completion?()
            } else if self.pendingItemNode == nil {
                let itemNode = ChatListContainerItemNode(context: self.context, location: self.location, filter: self.availableFilters[index].filter, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
                    self?.filterBecameEmpty(filter)
                }, emptyAction: { [weak self] filter in
                    self?.filterEmptyAction(filter)
                }, secondaryEmptyAction: { [weak self] in
                    self?.secondaryEmptyAction()
                })
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
                    
                    guard let (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction) = strongSelf.validLayout else {
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
                                                
                        itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
                        
                        strongSelf.selectedId = id
                        if let currentItemNode = strongSelf.currentItemNodeValue {
                            itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: currentItemNode.listNode.isNavigationHidden)
                        }
                        strongSelf.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                        
                        strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: insets, isReorderingFilters: isReorderingFilters, isEditing: isEditing, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, transition: .immediate)
                        
                        strongSelf.currentItemFilterUpdated?(strongSelf.currentItemFilter, strongSelf.transitionFraction, transition, false)
                    }
                    
                    completion?()
                }))
            }
        }
    }
    
    func update(layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, insets: UIEdgeInsets, isReorderingFilters: Bool, isEditing: Bool, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight, visualNavigationHeight, originalNavigationHeight, cleanNavigationBarHeight, insets, isReorderingFilters, isEditing, inlineNavigationLocation, inlineNavigationTransitionFraction)
        
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
                    let itemNode = ChatListContainerItemNode(context: self.context, location: self.location, filter: self.availableFilters[i].filter, previewing: self.previewing, isInlineMode: self.isInlineMode, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, becameEmpty: { [weak self] filter in
                        self?.filterBecameEmpty(filter)
                    }, emptyAction: { [weak self] filter in
                        self?.filterEmptyAction(filter)
                    }, secondaryEmptyAction: { [weak self] in
                        self?.secondaryEmptyAction()
                    })
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
                
                itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: itemInlineNavigationTransitionFraction, transition: nodeTransition)
                
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
    private(set) var temporaryContentOffsetChangeTransition: ContainedViewLayoutTransition?
    
    private var tapRecognizer: UITapGestureRecognizer?
    var navigationBar: NavigationBar?
    weak var controller: ChatListControllerImpl?
    
    var toolbar: Toolbar?
    private var toolbarNode: ToolbarNode?
    var toolbarActionSelected: ((ToolbarActionOption) -> Void)?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    var isReorderingFilters: Bool = false
    var didBeginSelectingChatsWhileEditing: Bool = false
    var isEditing: Bool = false
    
    private var containerLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat)?
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
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
        self.mainContainerNode = ChatListContainerNode(context: context, location: location, previewing: previewing, controlsHistoryPreload: controlsHistoryPreload, isInlineMode: false, presentationData: presentationData, animationCache: animationCache, animationRenderer: animationRenderer, filterBecameEmpty: { filter in
            filterBecameEmpty?(filter)
        }, filterEmptyAction: { filter in
            filterEmptyAction?(filter)
        }, secondaryEmptyAction: {
            secondaryEmptyAction?()
        })
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.mainContainerNode)
        
        self.mainContainerNode.contentOffsetChanged = { [weak self] offset in
            self?.contentOffsetChanged(offset: offset, isPrimary: true)
        }
        self.mainContainerNode.contentScrollingEnded = { [weak self] listView in
            return self?.contentScrollingEnded(listView: listView, isPrimary: true) ?? false
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
        
        self.mainContainerNode.onFilterSwitch = { [weak self] in
            if let strongSelf = self {
                strongSelf.controller?.dismissAllUndoControllers()
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
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight)
        
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
        self.mainContainerNode.update(layout: layout, navigationBarHeight: mainNavigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: navigationBarHeight, cleanNavigationBarHeight: cleanMainNavigationBarHeight, insets: mainInsets, isReorderingFilters: self.isReorderingFilters, isEditing: self.isEditing, inlineNavigationLocation: self.inlineStackContainerNode?.location, inlineNavigationTransitionFraction: self.inlineStackContainerTransitionFraction, transition: transition)
        
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
            
            inlineStackContainerNode.update(layout: inlineLayout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: navigationBarHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, insets: inlineInsets, isReorderingFilters: self.isReorderingFilters, isEditing: self.isEditing, inlineNavigationLocation: nil, inlineNavigationTransitionFraction: 0.0, transition: inlineStackContainerNodeTransition)
            
            if animateIn {
                transition.animatePosition(node: inlineStackContainerNode, from: CGPoint(x: inlineStackContainerNode.position.x + inlineStackContainerNode.bounds.width + UIScreenPixel, y: inlineStackContainerNode.position.y))
            }
        }
        
        self.tapRecognizer?.isEnabled = self.isReorderingFilters
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode, displaySearchFilters: Bool, hasDownloads: Bool, initialFilter: ChatListSearchFilter, navigationController: NavigationController?) -> (ASDisplayNode, (Bool) -> Void)? {
        guard let (containerLayout, _, _, cleanNavigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return nil
        }
        
        let effectiveLocation = self.inlineStackContainerNode?.location ?? self.location
        
        let filter: ChatListNodePeersFilter = []
        if case .forum = effectiveLocation {
            //filter.insert(.excludeRecent)
        }
        
        let contentNode = ChatListSearchContainerNode(context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, filter: filter, location: effectiveLocation, displaySearchFilters: displaySearchFilters, hasDownloads: hasDownloads, initialFilter: initialFilter, openPeer: { [weak self] peer, _, threadId, dismissSearch in
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
        }, navigationController: navigationController)
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: contentNode, cancel: { [weak self] in
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
            strongSelf.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: cleanNavigationBarHeight, transition: .immediate)
            strongSelf.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                    if isSearchBar {
                        strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode, focus: focus)
        })
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) -> (() -> Void)? {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
            self.mainContainerNode.accessibilityElementsHidden = false
            self.inlineStackContainerNode?.accessibilityElementsHidden = false
            
            return { [weak self] in
                if let strongSelf = self, let (layout, _, _, cleanNavigationBarHeight) = strongSelf.containerLayout {
                    searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
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
    
    private func contentOffsetChanged(offset: ListViewVisibleContentOffset, isPrimary: Bool) {
        guard let inlineStackContainerNode = self.inlineStackContainerNode else {
            self.contentOffsetChanged?(offset)
            return
        }
        guard let containerLayout = self.containerLayout else {
            return
        }
        
        if !isPrimary {
            self.contentOffsetChanged?(offset)
            if "".isEmpty {
                return
            }
        } else {
            if "".isEmpty {
                return
            }
        }
        
        let targetNode: ChatListContainerNode
        if isPrimary {
            targetNode = inlineStackContainerNode
        } else {
            targetNode = self.mainContainerNode
        }
        
        switch offset {
        case let .known(value) where (value <= containerLayout.navigationBarHeight - 76.0 - 46.0 - 8.0 + UIScreenPixel || self.contentOffsetSyncLockedIn):
            if case let .known(otherValue) = targetNode.currentItemNode.visibleContentOffset(), abs(otherValue - value) <= UIScreenPixel {
                self.contentOffsetSyncLockedIn = true
            }
        default:
            break
        }
        
        switch offset {
        case let .known(value) where self.contentOffsetSyncLockedIn:
            var targetValue = value
            if targetValue > containerLayout.navigationBarHeight - 76.0 - 46.0 - 8.0 {
                targetValue = containerLayout.navigationBarHeight - 76.0 - 46.0 - 8.0
            }
            
            targetNode.fixContentOffset(offset: targetValue)
            
            self.contentOffsetChanged?(offset)
        default:
            if !isPrimary {
                self.contentOffsetChanged?(offset)
            }
        }
    }
    
    private func contentScrollingEnded(listView: ListView, isPrimary: Bool) -> Bool {
        guard let inlineStackContainerNode = self.inlineStackContainerNode else {
            return self.contentScrollingEnded?(listView) ?? false
        }
        
        self.contentOffsetSyncLockedIn = false
        
        if isPrimary {
            return false
        }
        
        let _ = inlineStackContainerNode
        
        return self.contentScrollingEnded?(listView) ?? false
    }
    
    func makeInlineChatList(location: ChatListControllerLocation) -> ChatListContainerNode {
        var forumPeerId: EnginePeer.Id?
        if case let .forum(peerId) = location {
            forumPeerId = peerId
        }
        
        let inlineStackContainerNode = ChatListContainerNode(context: self.context, location: location, previewing: false, controlsHistoryPreload: false, isInlineMode: true, presentationData: self.presentationData, animationCache: self.animationCache, animationRenderer: self.animationRenderer, filterBecameEmpty: { _ in }, filterEmptyAction: { [weak self] _ in self?.emptyListAction?(forumPeerId) }, secondaryEmptyAction: {})
        return inlineStackContainerNode
    }
    
    func setInlineChatList(inlineStackContainerNode: ChatListContainerNode?) {
        if let inlineStackContainerNode = inlineStackContainerNode {
            if self.inlineStackContainerNode !== inlineStackContainerNode {
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
                
                inlineStackContainerNode.contentOffsetChanged = { [weak self] offset in
                    self?.contentOffsetChanged(offset: offset, isPrimary: false)
                }
                inlineStackContainerNode.contentScrollingEnded = { [weak self] listView in
                    return self?.contentScrollingEnded(listView: listView, isPrimary: false) ?? false
                }
                
                inlineStackContainerNode.activateChatPreview = self.mainContainerNode.activateChatPreview
                inlineStackContainerNode.addedVisibleChatsWithPeerIds = self.mainContainerNode.addedVisibleChatsWithPeerIds
                inlineStackContainerNode.didBeginSelectingChats = self.mainContainerNode.didBeginSelectingChats
                inlineStackContainerNode.displayFilterLimit = nil
                
                let previousInlineStackContainerNode = self.inlineStackContainerNode
                
                self.inlineStackContainerNode = inlineStackContainerNode
                self.inlineStackContainerTransitionFraction = 1.0
                
                if let _ = self.containerLayout {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    
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
                
                self.mainContainerNode.contentScrollingEnded = self.contentScrollingEnded
                
                if let _ = self.containerLayout {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                    
                    transition.updatePosition(node: inlineStackContainerNode, position: CGPoint(x: inlineStackContainerNode.position.x + inlineStackContainerNode.bounds.width + UIScreenPixel, y: inlineStackContainerNode.position.y), completion: { [weak inlineStackContainerNode] _ in
                        inlineStackContainerNode?.removeFromSupernode()
                    })
                    
                    self.temporaryContentOffsetChangeTransition = transition
                    self.controller?.requestLayout(transition: transition)
                    self.temporaryContentOffsetChangeTransition = nil
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
            inlineStackContainerNode.scrollToTop()
        } else {
            self.mainContainerNode.scrollToTop()
        }
    }
}
