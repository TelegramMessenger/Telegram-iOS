import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ActivityIndicator
import AccountContext
import SearchBarNode
import SearchUI
import ContextUI

private final class ChatListControllerNodeView: UITracingLayerView, PreviewingHostView {
    var previewingDelegate: PreviewingHostViewDelegate? {
        return PreviewingHostViewDelegate(controllerForLocation: { [weak self] sourceView, point in
            return self?.controller?.previewingController(from: sourceView, for: point)
        }, commitController: { [weak self] controller in
            self?.controller?.previewingCommit(controller)
        })
    }
    
    weak var controller: ChatListControllerImpl?
}

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

private final class ChatListContainerItemNode: ASDisplayNode {
    private var presentationData: PresentationData
    private let becameEmpty: (ChatListFilter?) -> Void
    private let emptyAction: (ChatListFilter?) -> Void
    
    private var emptyNode: ChatListEmptyNode?
    let listNode: ChatListNode
    
    private var validLayout: (CGSize, UIEdgeInsets, CGFloat)?
    
    init(context: AccountContext, groupId: PeerGroupId, filter: ChatListFilter?, previewing: Bool, presentationData: PresentationData, becameEmpty: @escaping (ChatListFilter?) -> Void, emptyAction: @escaping (ChatListFilter?) -> Void) {
        self.presentationData = presentationData
        self.becameEmpty = becameEmpty
        self.emptyAction = emptyAction
        
        self.listNode = ChatListNode(context: context, groupId: groupId, chatListFilter: filter, previewing: previewing, controlsHistoryPreload: false, mode: .chatList, theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)
        
        super.init()
        
        self.addSubnode(self.listNode)
        
        self.listNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let strongSelf = self else {
                return
            }
            switch isEmptyState {
            case let .empty(isLoading):
                if let currentNode = strongSelf.emptyNode {
                    currentNode.updateIsLoading(isLoading)
                } else {
                    let emptyNode = ChatListEmptyNode(isFilter: filter != nil, isLoading: isLoading, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, action: {
                        self?.emptyAction(filter)
                    })
                    strongSelf.emptyNode = emptyNode
                    strongSelf.addSubnode(emptyNode)
                    if let (size, insets, _) = strongSelf.validLayout {
                        let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top - insets.bottom))
                        emptyNode.frame = emptyNodeFrame
                        emptyNode.updateLayout(size: emptyNodeFrame.size, transition: .immediate)
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
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.listNode.updateThemeAndStrings(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)
        
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
    private let groupId: PeerGroupId
    private let previewing: Bool
    private let filterBecameEmpty: (ChatListFilter?) -> Void
    private let filterEmptyAction: (ChatListFilter?) -> Void
    
    private var presentationData: PresentationData
    
    private var itemNodes: [ChatListFilterTabEntryId: ChatListContainerItemNode] = [:]
    private var pendingItemNode: (ChatListFilterTabEntryId, ChatListContainerItemNode, Disposable)?
    private var availableFilters: [ChatListContainerNodeFilter] = [.all]
    private var selectedId: ChatListFilterTabEntryId
    
    private(set) var transitionFraction: CGFloat = 0.0
    private var transitionFractionOffset: CGFloat = 0.0
    private var disableItemNodeOperationsWhileAnimating: Bool = false
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat, visualNavigationHeight: CGFloat, cleanNavigationBarHeight: CGFloat, isReorderingFilters: Bool, isEditing: Bool)?
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    private let _ready = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private var currentItemNodeValue: ChatListContainerItemNode?
    var currentItemNode: ChatListNode {
        return self.currentItemNodeValue!.listNode
    }
    
    private let currentItemStateValue = Promise<ChatListNodeState>()
    var currentItemState: Signal<ChatListNodeState, NoError> {
        return self.currentItemStateValue.get()
    }
    
    var currentItemFilterUpdated: ((ChatListFilterTabEntryId, CGFloat, ContainedViewLayoutTransition, Bool) -> Void)?
    var currentItemFilter: ChatListFilterTabEntryId {
        return self.currentItemNode.chatListFilter.flatMap { .filter($0.id) } ?? .all
    }
    
    private func applyItemNodeAsCurrent(id: ChatListFilterTabEntryId, itemNode: ChatListContainerItemNode) {
        if let previousItemNode = self.currentItemNodeValue {
            previousItemNode.listNode.activateSearch = nil
            previousItemNode.listNode.presentAlert =  nil
            previousItemNode.listNode.present =  nil
            previousItemNode.listNode.toggleArchivedFolderHiddenByDefault =  nil
            previousItemNode.listNode.deletePeerChat =  nil
            previousItemNode.listNode.peerSelected = nil
            previousItemNode.listNode.groupSelected =  nil
            previousItemNode.listNode.updatePeerGrouping =  nil
            previousItemNode.listNode.contentOffsetChanged =  nil
            previousItemNode.listNode.contentScrollingEnded =  nil
            previousItemNode.listNode.activateChatPreview =  nil
            previousItemNode.listNode.addedVisibleChatsWithPeerIds = nil
            
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
        itemNode.listNode.deletePeerChat = { [weak self] peerId in
            self?.deletePeerChat?(peerId)
        }
        itemNode.listNode.peerSelected = { [weak self] peerId, a, b in
            self?.peerSelected?(peerId, a, b)
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
        
        self.currentItemStateValue.set(itemNode.listNode.state)
    }
    
    var activateSearch: (() -> Void)?
    var presentAlert: ((String) -> Void)?
    var present: ((ViewController) -> Void)?
    var toggleArchivedFolderHiddenByDefault: (() -> Void)?
    var deletePeerChat: ((PeerId) -> Void)?
    var peerSelected: ((Peer, Bool, Bool) -> Void)?
    var groupSelected: ((PeerGroupId) -> Void)?
    var updatePeerGrouping: ((PeerId, Bool) -> Void)?
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    var activateChatPreview: ((ChatListItem, ASDisplayNode, ContextGesture?) -> Void)?
    var addedVisibleChatsWithPeerIds: (([PeerId]) -> Void)?
    
    init(context: AccountContext, groupId: PeerGroupId, previewing: Bool, presentationData: PresentationData, filterBecameEmpty: @escaping (ChatListFilter?) -> Void, filterEmptyAction: @escaping (ChatListFilter?) -> Void) {
        self.context = context
        self.groupId = groupId
        self.previewing = previewing
        self.filterBecameEmpty = filterBecameEmpty
        self.filterEmptyAction = filterEmptyAction
        
        self.presentationData = presentationData
        
        self.selectedId = .all
        
        super.init()
        
        let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: nil, previewing: self.previewing, presentationData: presentationData, becameEmpty: { [weak self] filter in
            self?.filterBecameEmpty(filter)
        }, emptyAction: { [weak self] filter in
            self?.filterEmptyAction(filter)
        })
        self.itemNodes[.all] = itemNode
        self.addSubnode(itemNode)
        
        self._ready.set(itemNode.listNode.ready)
        
        self.applyItemNodeAsCurrent(id: .all, itemNode: itemNode)
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, let index = strongSelf.availableFilters.firstIndex(where: { $0.id == strongSelf.selectedId }) else {
                return []
            }
            var directions: InteractiveTransitionGestureRecognizerDirections = [.leftCenter, .rightCenter]
            if strongSelf.availableFilters.count > 1 {
                if index == 0 {
                    directions.remove(.rightCenter)
                }
                if index == strongSelf.availableFilters.count - 1 {
                    directions.remove(.leftCenter)
                }
            } else {
                directions = []
            }
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
            self.transitionFractionOffset = 0.0
            if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout, let itemNode = self.itemNodes[self.selectedId] {
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
                if selectedIndex <= 0 {
                    transitionFraction = min(0.0, transitionFraction)
                }
                if selectedIndex >= self.availableFilters.count - 1 {
                    transitionFraction = max(0.0, transitionFraction)
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
            self.availableFilters = availableFilters
            if let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout {
                self.update(layout: layout, navigationBarHeight: navigationBarHeight, visualNavigationHeight: visualNavigationHeight, cleanNavigationBarHeight: cleanNavigationBarHeight, isReorderingFilters: isReorderingFilters, isEditing: isEditing, transition: .immediate)
            }
        }
    }
    
    func switchToFilter(id: ChatListFilterTabEntryId) {
        guard let (layout, navigationBarHeight, visualNavigationHeight, cleanNavigationBarHeight, isReorderingFilters, isEditing) = self.validLayout else {
            return
        }
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
            } else if self.pendingItemNode == nil {
                let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: self.availableFilters[index].filter, previewing: self.previewing, presentationData: self.presentationData, becameEmpty: { [weak self] filter in
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
        
        transition.updateAlpha(node: self, alpha: isReorderingFilters ? 0.5 : 1.0)
        self.isUserInteractionEnabled = !isReorderingFilters
        
        self.panRecognizer?.isEnabled = !isEditing
        
        if let selectedIndex = self.availableFilters.firstIndex(where: { $0.id == self.selectedId }) {
            var validNodeIds: [ChatListFilterTabEntryId] = []
            for i in max(0, selectedIndex - 1) ... min(self.availableFilters.count - 1, selectedIndex + 1) {
                let id = self.availableFilters[i].id
                validNodeIds.append(id)
                
                if self.itemNodes[id] == nil && !self.disableItemNodeOperationsWhileAnimating {
                    let itemNode = ChatListContainerItemNode(context: self.context, groupId: self.groupId, filter: self.availableFilters[i].filter, previewing: self.previewing, presentationData: self.presentationData, becameEmpty: { [weak self] filter in
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
    private let groupId: PeerGroupId
    private var presentationData: PresentationData
    
    let containerNode: ChatListContainerNode
    var navigationBar: NavigationBar?
    weak var controller: ChatListControllerImpl?
    
    var toolbar: Toolbar?
    private var toolbarNode: ToolbarNode?
    var toolbarActionSelected: ((ToolbarActionOption) -> Void)?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    var isReorderingFilters: Bool = false
    var isEditing: Bool = false
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer, Bool) -> Void)?
    var requestOpenRecentPeerOptions: ((Peer) -> Void)?
    var requestOpenMessageFromSearch: ((Peer, MessageId) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var peerContextAction: ((Peer, ChatListSearchContextActionSource, ASDisplayNode, ContextGesture?) -> Void)?
    var dismissSelfIfCompletedPresentation: (() -> Void)?
    var isEmptyUpdated: ((Bool) -> Void)?
    var emptyListAction: (() -> Void)?

    let debugListView = ListView()
    
    init(context: AccountContext, groupId: PeerGroupId, filter: ChatListFilter?, previewing: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, controller: ChatListControllerImpl) {
        self.context = context
        self.groupId = groupId
        self.presentationData = presentationData
        
        var filterBecameEmpty: ((ChatListFilter?) -> Void)?
        var filterEmptyAction: ((ChatListFilter?) -> Void)?
        self.containerNode = ChatListContainerNode(context: context, groupId: groupId, previewing: previewing, presentationData: presentationData, filterBecameEmpty: { filter in
            filterBecameEmpty?(filter)
        }, filterEmptyAction: { filter in
            filterEmptyAction?(filter)
        })
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return ChatListControllerNodeView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.debugListView)
        
        filterBecameEmpty = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if case .group = strongSelf.groupId {
                strongSelf.dismissSelfIfCompletedPresentation?()
            }
        }
        filterEmptyAction = { [weak self] filter in
            guard let strongSelf = self else {
                return
            }
            strongSelf.emptyListAction?()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        (self.view as? ChatListControllerNodeView)?.controller = self.controller
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.containerNode.updatePresentationData(presentationData)
        self.searchDisplayController?.updatePresentationData(presentationData)
        
        if let toolbarNode = self.toolbarNode {
            toolbarNode.updateTheme(TabBarControllerTheme(rootControllerTheme: self.presentationData.theme))
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
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right,  bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: TabBarControllerTheme(rootControllerTheme: self.presentationData.theme), displaySeparator: true, left: { [weak self] in
                    self?.toolbarActionSelected?(.left)
                }, right: { [weak self] in
                    self?.toolbarActionSelected?(.right)
                }, middle: { [weak self] in
                    self?.toolbarActionSelected?(.middle)
                })
                toolbarNode.frame = tabBarFrame
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
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
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: cleanNavigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, _, _, cleanNavigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChatListSearchContainerNode(context: self.context, filter: [], groupId: self.groupId, openPeer: { [weak self] peer, dismissSearch in
            self?.requestOpenPeerFromSearch?(peer, dismissSearch)
        }, openDisabledPeer: { _ in
        }, openRecentPeerOptions: { [weak self] peer in
            self?.requestOpenRecentPeerOptions?(peer)
        }, openMessage: { [weak self] peer, messageId in
            if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                requestOpenMessageFromSearch(peer, messageId)
            }
        }, addContact: { [weak self] phoneNumber in
            if let requestAddContact = self?.requestAddContact {
                requestAddContact(phoneNumber)
            }
        }, peerContextAction: self.peerContextAction, present: { [weak self] c in
            self?.controller?.present(c, in: .window(.root))
        }), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        self.containerNode.accessibilityElementsHidden = true
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: cleanNavigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
            self.containerNode.accessibilityElementsHidden = false
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
