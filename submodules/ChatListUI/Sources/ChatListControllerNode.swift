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
    
    func update(context: AccountContext, size: CGSize, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData {
            self.currentParams = (size, presentationData)
                        
            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
            let timestamp1: Int32 = 100000
            let peers: [EnginePeer.Id: EnginePeer] = [:]
            let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _, _, _ in }, disabledPeerSelected: { _ in }, togglePeerSelected: { _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, hidePsa: { _ in }, activateChatPreview: { _, _, gesture in
                gesture?.cancel()
            }, present: { _ in })
            
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
                    associatedMessageIds: []
                )
                let readState = EnginePeerReadCounters()

                return ChatListItem(presentationData: chatListPresentationData, context: context, peerGroupId: .root, filterData: nil, index: EngineChatList.Item.Index(pinningIndex: 0, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1)), content: .peer(messages: [message], peer: EngineRenderedPeer(peer: peer1), combinedReadState: readState, isRemovedFromTotalUnreadCount: false, presence: nil, hasUnseenMentions: false, hasUnseenReactions: false, draftState: nil, inputActivities: nil, promoInfo: nil, ignoreUnreadBadge: false, displayAsMessage: false, hasFailedMessages: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction)
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
                    
                    context.fillEllipse(in: itemNodes[sampleIndex].avatarNode.frame.offsetBy(dx: 0.0, dy: currentY))
                    let titleFrame = itemNodes[sampleIndex].titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 60.0)
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: currentY + itemHeight - floor(itemNodes[sampleIndex].titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 60.0)
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 120.0)
                    fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX + 120.0 + 10.0, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 60.0)
                    
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
    private var presentationData: PresentationData
    private let becameEmpty: (ChatListFilter?) -> Void
    private let emptyAction: (ChatListFilter?) -> Void
    
    private var floatingHeaderOffset: CGFloat?
    
    private(set) var emptyNode: ChatListEmptyNode?
    var emptyShimmerEffectNode: ChatListShimmerNode?
    private var shimmerNodeOffset: CGFloat = 0.0
    let listNode: ChatListNode
    
    private var validLayout: (CGSize, UIEdgeInsets, CGFloat)?
    
    init(context: AccountContext, groupId: EngineChatList.Group, filter: ChatListFilter?, previewing: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, becameEmpty: @escaping (ChatListFilter?) -> Void, emptyAction: @escaping (ChatListFilter?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.becameEmpty = becameEmpty
        self.emptyAction = emptyAction
        
        self.listNode = ChatListNode(context: context, groupId: groupId, chatListFilter: filter, previewing: previewing, fillPreloadItems: controlsHistoryPreload, mode: .chatList, theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
        
        super.init()
        
        self.addSubnode(self.listNode)
        
        self.listNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let strongSelf = self else {
                return
            }
            var needsShimmerNode = false
            var shimmerNodeOffset: CGFloat = 0.0
            switch isEmptyState {
            case let .empty(isLoading, hasArchiveInfo):
                if hasArchiveInfo {
                    shimmerNodeOffset = 253.0
                }
                if isLoading {
                    needsShimmerNode = true
                    
                    if let emptyNode = strongSelf.emptyNode {
                        strongSelf.emptyNode = nil
                        transition.updateAlpha(node: emptyNode, alpha: 0.0, completion: { [weak emptyNode] _ in
                            emptyNode?.removeFromSupernode()
                        })
                    }
                } else {
                    if let currentNode = strongSelf.emptyNode {
                        currentNode.updateIsLoading(isLoading)
                    } else {
                        let emptyNode = ChatListEmptyNode(context: context, isFilter: filter != nil, isLoading: isLoading, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, action: {
                            self?.emptyAction(filter)
                        })
                        strongSelf.emptyNode = emptyNode
                        strongSelf.addSubnode(emptyNode)
                        if let (size, insets, _) = strongSelf.validLayout {
                            let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
                            emptyNode.frame = emptyNodeFrame
                            emptyNode.updateLayout(size: emptyNodeFrame.size, transition: .immediate)
                        }
                        emptyNode.alpha = 0.0
                        transition.updateAlpha(node: emptyNode, alpha: 1.0)
                    }
                }
                if !isLoading {
                    strongSelf.becameEmpty(filter)
                }
            case .notEmpty:
                if let emptyNode = strongSelf.emptyNode {
                    strongSelf.emptyNode = nil
                    transition.updateAlpha(node: emptyNode, alpha: 0.0, completion: { [weak emptyNode] _ in
                        emptyNode?.removeFromSupernode()
                    })
                }
            }
            if needsShimmerNode {
                strongSelf.shimmerNodeOffset = shimmerNodeOffset
                if strongSelf.emptyShimmerEffectNode == nil {
                    let emptyShimmerEffectNode = ChatListShimmerNode()
                    strongSelf.emptyShimmerEffectNode = emptyShimmerEffectNode
                    strongSelf.insertSubnode(emptyShimmerEffectNode, belowSubnode: strongSelf.listNode)
                    if let (size, insets, _) = strongSelf.validLayout, let offset = strongSelf.floatingHeaderOffset {
                        strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: .immediate)
                    }
                }
            } else if let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.emptyShimmerEffectNode = nil
                let emptyNodeTransition = transition.isAnimated ? transition : .animated(duration: 0.3, curve: .easeInOut)
                emptyNodeTransition.updateAlpha(node: emptyShimmerEffectNode, alpha: 0.0, completion: { [weak emptyShimmerEffectNode] _ in
                    emptyShimmerEffectNode?.removeFromSupernode()
                })
            }
        }
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.floatingHeaderOffset = offset
            if let (size, insets, _) = strongSelf.validLayout, let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: transition)
            }
        }
    }
    
    private func layoutEmptyShimmerEffectNode(node: ChatListShimmerNode, size: CGSize, insets: UIEdgeInsets, verticalOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        node.update(context: self.context, size: size, presentationData: self.presentationData, transition: .immediate)
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
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets, visualNavigationHeight)
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        self.listNode.visualInsets = UIEdgeInsets(top: visualNavigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        
        if let emptyNode = self.emptyNode {
            let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
            transition.updateFrame(node: emptyNode, frame: emptyNodeFrame)
            emptyNode.updateLayout(size: emptyNodeFrame.size, transition: transition)
        }
    }
}

final class ChatListContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let context: AccountContext
    private let groupId: EngineChatList.Group
    private let previewing: Bool
    private let controlsHistoryPreload: Bool
    private let filterBecameEmpty: (ChatListFilter?) -> Void
    private let filterEmptyAction: (ChatListFilter?) -> Void
    
    fileprivate var onFilterSwitch: (() -> Void)?
    
    private var presentationData: PresentationData
    
    private var itemNodes: [ChatListFilterTabEntryId: ChatListContainerItemNode] = [:]
    private var pendingItemNode: (ChatListFilterTabEntryId, ChatListContainerItemNode, Disposable)?
    private var availableFilters: [ChatListContainerNodeFilter] = [.all]
    private var selectedId: ChatListFilterTabEntryId
    
    private(set) var transitionFraction: CGFloat = 0.0
    private var transitionFractionOffset: CGFloat = 0.0
    private var disableItemNodeOperationsWhileAnimating: Bool = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, isReorderingFilters: Bool, isEditing: Bool)?
    
    private var enableAdjacentFilterLoading: Bool = false
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    private let _ready = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return _ready.get()
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
            previousItemNode.listNode.toggleArchivedFolderHiddenByDefault = nil
            previousItemNode.listNode.hidePsa = nil
            previousItemNode.listNode.deletePeerChat = nil
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
        itemNode.listNode.toggleArchivedFolderHiddenByDefault = { [weak self] in
            self?.toggleArchivedFolderHiddenByDefault?()
        }
        itemNode.listNode.hidePsa = { [weak self] peerId in
            self?.hidePsa?(peerId)
        }
        itemNode.listNode.deletePeerChat = { [weak self] peerId, joined in
            self?.deletePeerChat?(peerId, joined)
        }
        itemNode.listNode.peerSelected = { [weak self] peerId, animated, activateInput, promoInfo in
            self?.peerSelected?(peerId, animated, activateInput, promoInfo)
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
        itemNode.listNode.activateChatPreview = { [weak self] item, sourceNode, gesture in
            self?.activateChatPreview?(item, sourceNode, gesture)
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
        
        if self.controlsHistoryPreload {
            self.context.account.viewTracker.chatListPreloadItems.set(combineLatest(queue: .mainQueue(),
                context.sharedContext.hasOngoingCall.get(),
                itemNode.listNode.preloadItems.get()
            )
            |> map { hasOngoingCall, preloadItems -> [ChatHistoryPreloadItem] in
                if hasOngoingCall {
                    return []
                } else {
                    return preloadItems
                }
            })
        }
    }
    
    var activateSearch: (() -> Void)?
    var presentAlert: ((String) -> Void)?
    var present: ((ViewController) -> Void)?
    var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    var hidePsa: ((EnginePeer.Id) -> Void)?
    var deletePeerChat: ((EnginePeer.Id, Bool) -> Void)?
    var peerSelected: ((EnginePeer, Bool, Bool, ChatListNodeEntryPromoInfo?) -> Void)?
    var groupSelected: ((EngineChatList.Group) -> Void)?
    var updatePeerGrouping: ((EnginePeer.Id, Bool) -> Void)?
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    var activateChatPreview: ((ChatListItem, ASDisplayNode, ContextGesture?) -> Void)?
    var addedVisibleChatsWithPeerIds: (([EnginePeer.Id]) -> Void)?
    var didBeginSelectingChats: (() -> Void)?
    
    init(context: AccountContext, groupId: EngineChatList.Group, previewing: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, filterBecameEmpty: @escaping (ChatListFilter?) -> Void, filterEmptyAction: @escaping (ChatListFilter?) -> Void) {
        self.context = context
        self.groupId = groupId
        self.previewing = previewing
        self.filterBecameEmpty = filterBecameEmpty
        self.filterEmptyAction = filterEmptyAction
        self.controlsHistoryPreload = controlsHistoryPreload
        
        self.presentationData = presentationData
        
        self.selectedId = .all
        
        super.init()
        
        let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: nil, previewing: self.previewing, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: presentationData, becameEmpty: { [weak self] filter in
            self?.filterBecameEmpty(filter)
        }, emptyAction: { [weak self] filter in
            self?.filterEmptyAction(filter)
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
        switch recognizer.state {
        case .began:
            self.onFilterSwitch?()
            
            self.transitionFractionOffset = 0.0
            if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout, let itemNode = self.itemNodes[self.selectedId] {
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
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
                        self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, true)
                    }
                }
            }
        case .changed:
            if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
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
                if selectedIndex >= self.availableFilters.count - 1 && translation.x < 0.0 {
                    let overscroll = -translation.x
                    transitionFraction = -rubberBandingOffset(offset: overscroll, bandingStart: 0.0) / layout.size.width
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
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, .immediate, false)
            }
        case .cancelled, .ended:
            if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout, let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
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
                        updatedIndex = min(updatedIndex + 1, self.availableFilters.count - 1)
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
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: transition)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
                DispatchQueue.main.async {
                    self.disableItemNodeOperationsWhileAnimating = false
                    if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout {
                        self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
                    }
                }
            }
        default:
            break
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
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
    
    func updateState(_ f: (ChatListNodeState) -> ChatListNodeState) {
        self.currentItemNode.updateState(f)
        let updatedState = self.currentItemNode.currentState
        for (id, itemNode) in self.itemNodes {
            if id != self.selectedId {
                itemNode.listNode.updateState { state in
                    var state = state
                    state.editing = updatedState.editing
                    state.selectedPeerIds = updatedState.selectedPeerIds
                    return state
                }
            }
        }
    }
    
    func updateAvailableFilters(_ availableFilters: [ChatListContainerNodeFilter]) {
        if self.availableFilters != availableFilters {
            let apply: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.availableFilters = availableFilters
                if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = strongSelf.validLayout {
                    strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
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
            
            if self.enableAdjacentFilterLoading, let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout {
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
            }
        }
    }
    
    func switchToFilter(id: ChatListFilterTabEntryId, completion: (() -> Void)? = nil) {
        guard let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout else {
            return
        }
        self.onFilterSwitch?()
        if id != self.selectedId, let index = self.availableFilters.firstIndex(where: { $0.id == id }) {
            if let itemNode = self.itemNodes[id] {
                self.selectedId = id
                if let currentItemNode = self.currentItemNodeValue {
                    itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: currentItemNode.listNode.isNavigationHidden)
                }
                self.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: transition)
                self.currentItemFilterUpdated?(self.currentItemFilter, self.transitionFraction, transition, false)
                itemNode.emptyNode?.restartAnimation()
                completion?()
            } else if self.pendingItemNode == nil {
                let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: self.availableFilters[index].filter, previewing: self.previewing, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, becameEmpty: { [weak self] filter in
                    self?.filterBecameEmpty(filter)
                }, emptyAction: { [weak self] filter in
                    self?.filterEmptyAction(filter)
                })
                let disposable = MetaDisposable()
                self.pendingItemNode = (id, itemNode, disposable)
                
                disposable.set((itemNode.listNode.ready
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self, weak itemNode] _ in
                    guard let strongSelf = self, let itemNode = itemNode, itemNode === strongSelf.pendingItemNode?.1 else {
                        return
                    }
                    guard let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = strongSelf.validLayout else {
                        return
                    }
                    strongSelf.pendingItemNode = nil
                    
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                    
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
                        
                        var insets = layout.insets(options: [.input])
                        insets.top += navigationBarHeight
                        
                        insets.left += layout.safeInsets.left
                        insets.right += layout.safeInsets.right
                        
                        itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, transition: .immediate)
                        
                        strongSelf.selectedId = id
                        if let currentItemNode = strongSelf.currentItemNodeValue {
                            itemNode.listNode.adjustScrollOffsetForNavigation(isNavigationHidden: currentItemNode.listNode.isNavigationHidden)
                        }
                        strongSelf.applyItemNodeAsCurrent(id: id, itemNode: itemNode)
                        
                        strongSelf.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
                        
                        strongSelf.currentItemFilterUpdated?(strongSelf.currentItemFilter, strongSelf.transitionFraction, transition, false)
                    }
                    
                    completion?()
                }))
            }
        }
    }
    
    func update(layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, isReorderingFilters: Bool, isEditing: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        if isEditing {
            if !layout.safeInsets.left.isZero {
                insets.bottom += 34.0
            } else {
                insets.bottom += 49.0
            }
        }
        
        transition.updateAlpha(node: self, alpha: isReorderingFilters ? 0.5 : 1.0)
        self.isUserInteractionEnabled = !isReorderingFilters
        
        self.panRecognizer?.isEnabled = !isEditing
        
        if let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
            var validNodeIds: [ChatListFilterTabEntryId] = []
            for i in max(0, selectedIndex - 1) ... min(self.availableFilters.count - 1, selectedIndex + 1) {
                let id = self.availableFilters[i].id
                validNodeIds.append(id)
                
                if self.itemNodes[id] == nil && self.enableAdjacentFilterLoading && !self.disableItemNodeOperationsWhileAnimating {
                    let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: self.availableFilters[i].filter, previewing: self.previewing, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, becameEmpty: { [weak self] filter in
                        self?.filterBecameEmpty(filter)
                    }, emptyAction: { [weak self] filter in
                        self?.filterEmptyAction(filter)
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
                
                itemNode.updateLayout(size: layout.size, insets: insets, visualNavigationHeight: visualNavigationHeight, transition: nodeTransition)
                
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

final class ChatListControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let groupId: EngineChatList.Group
    private var presentationData: PresentationData
    
    let containerNode: ChatListContainerNode
    let inlineTabContainerNode: ChatListFilterTabInlineContainerNode
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
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((EnginePeer, Bool) -> Void)?
    var requestOpenRecentPeerOptions: ((EnginePeer) -> Void)?
    var requestOpenMessageFromSearch: ((EnginePeer, EngineMessage.Id, Bool) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var peerContextAction: ((EnginePeer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?
    var dismissSelfIfCompletedPresentation: (() -> Void)?
    var isEmptyUpdated: ((Bool) -> Void)?
    var emptyListAction: (() -> Void)?
    var cancelEditing: (() -> Void)?

    let debugListView = ListView()
    
    init(context: AccountContext, groupId: EngineChatList.Group, filter: ChatListFilter?, previewing: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, controller: ChatListControllerImpl) {
        self.context = context
        self.groupId = groupId
        self.presentationData = presentationData
        
        var filterBecameEmpty: ((ChatListFilter?) -> Void)?
        var filterEmptyAction: ((ChatListFilter?) -> Void)?
        self.containerNode = ChatListContainerNode(context: context, groupId: groupId, previewing: previewing, controlsHistoryPreload: controlsHistoryPreload, presentationData: presentationData, filterBecameEmpty: { filter in
            filterBecameEmpty?(filter)
        }, filterEmptyAction: { filter in
            filterEmptyAction?(filter)
        })
        
        self.inlineTabContainerNode = ChatListFilterTabInlineContainerNode()
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.containerNode)
        self.addSubnode(self.inlineTabContainerNode)
        
        self.addSubnode(self.debugListView)
        
        filterBecameEmpty = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if case .archive = strongSelf.groupId {
                strongSelf.dismissSelfIfCompletedPresentation?()
            }
        }
        filterEmptyAction = { [weak self] filter in
            guard let strongSelf = self else {
                return
            }
            strongSelf.emptyListAction?()
        }
        
        self.containerNode.onFilterSwitch = { [weak self] in
            if let strongSelf = self {
                strongSelf.controller?.dismissAllUndoControllers()
            }
        }
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
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.containerNode.updatePresentationData(presentationData)
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
            let bottomInset: CGFloat = layout.insets(options: options).bottom
            if !layout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
                insets.bottom += 34.0
            } else {
                tabBarHeight = 49.0 + bottomInset
                insets.bottom += 49.0
            }
            
            let tabBarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight))
            
            if let toolbarNode = self.toolbarNode {
                transition.updateFrame(node: toolbarNode, frame: tabBarFrame)
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(rootControllerTheme: self.presentationData.theme), displaySeparator: true, left: { [weak self] in
                    self?.toolbarActionSelected?(.left)
                }, right: { [weak self] in
                    self?.toolbarActionSelected?(.right)
                }, middle: { [weak self] in
                    self?.toolbarActionSelected?(.middle)
                })
                toolbarNode.frame = tabBarFrame
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
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
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.containerNode.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: self.isReorderingFilters, isEditing: self.isEditing, transition: transition)
        
        transition.updateFrame(node: self.inlineTabContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - layout.intrinsicInsets.bottom - 8.0 - 40.0), size: CGSize(width: layout.size.width, height: 40.0)))
        
        self.tapRecognizer?.isEnabled = self.isReorderingFilters
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode, displaySearchFilters: Bool, hasDownloads: Bool, initialFilter: ChatListSearchFilter, navigationController: NavigationController?) -> (ASDisplayNode, (Bool) -> Void)? {
        guard let (containerLayout, _, _, cleanNavigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return nil
        }
        
        let filter: ChatListNodePeersFilter = []
        
        let contentNode = ChatListSearchContainerNode(context: self.context, filter: filter, groupId: self.groupId, displaySearchFilters: displaySearchFilters, hasDownloads: hasDownloads, initialFilter: initialFilter, openPeer: { [weak self] peer, _, dismissSearch in
            self?.requestOpenPeerFromSearch?(peer, dismissSearch)
        }, openDisabledPeer: { _ in
        }, openRecentPeerOptions: { [weak self] peer in
            self?.requestOpenRecentPeerOptions?(peer)
        }, openMessage: { [weak self] peer, messageId, deactivateOnAction in
            if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                requestOpenMessageFromSearch(peer, messageId, deactivateOnAction)
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
        self.containerNode.accessibilityElementsHidden = true
                
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
            self.containerNode.accessibilityElementsHidden = false
            
            return { [weak self] in
                if let strongSelf = self, let (layout, _, _, cleanNavigationBarHeight) = strongSelf.containerLayout {
                    searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
        } else {
            return nil
        }
    }
    
    func playArchiveAnimation() {
        self.containerNode.playArchiveAnimation()
    }
    
    func scrollToTop() {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.contentNode.scrollToTop()
        } else {
            self.containerNode.scrollToTop()
        }
    }
}
