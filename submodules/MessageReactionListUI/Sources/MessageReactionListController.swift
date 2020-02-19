import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import MergeLists
import ItemListPeerItem
import ItemListUI

public final class MessageReactionListController: ViewController {
    private let context: AccountContext
    private let messageId: MessageId
    private let presentationData: PresentationData
    private let initialReactions: [MessageReaction]
    
    private var controllerNode: MessageReactionListControllerNode {
        return self.displayNode as! MessageReactionListControllerNode
    }
    
    private var animatedIn: Bool = false
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, messageId: MessageId, initialReactions: [MessageReaction]) {
        self.context = context
        self.messageId = messageId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.initialReactions = initialReactions
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = MessageReactionListControllerNode(context: self.context, presentationData: self.presentationData, messageId: messageId, initialReactions: initialReactions, dismiss: { [weak self] in
            self?.dismiss()
        })
        
        super.displayNodeDidLoad()
        
        self._ready.set(self.controllerNode.isReady.get())
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}

private struct MessageReactionListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private struct MessageReactionListEntry: Comparable, Identifiable {
    let index: Int
    let item: MessageReactionListCategoryItem
    
    var stableId: PeerId {
        return self.item.peer.id
    }
    
    static func <(lhs: MessageReactionListEntry, rhs: MessageReactionListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData) -> ListViewItem {
        return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: self.item.peer, height: .peerList, nameStyle: .distinctBold, presence: nil, text: .none, label: .text(self.item.reaction, .custom(Font.regular(19.0))), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), revealOptions: nil, switchValue: nil, enabled: true, selectable: false, sectionId: 0, action: {
            
        }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in }, noInsets: true, tag: nil)
    }
}

private func preparedTransition(from fromEntries: [MessageReactionListEntry], to toEntries: [MessageReactionListEntry], context: AccountContext, presentationData: PresentationData) -> MessageReactionListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData), directionHint: nil) }
    
    return MessageReactionListTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

private let headerHeight: CGFloat = 60.0
private let itemHeight: CGFloat = 50.0

private func topInsetForLayout(layout: ContainerViewLayout, itemCount: Int) -> CGFloat {
    let contentHeight = CGFloat(itemCount) * itemHeight
    let minimumItemHeights: CGFloat = max(contentHeight, itemHeight * 5.0)
    
    return max(layout.size.height - layout.intrinsicInsets.bottom - minimumItemHeights, headerHeight)
}

private final class MessageReactionListControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let dismiss: () -> Void
    
    private let listContext: MessageReactionListContext
    
    private let dimNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentHeaderContainerNode: ASDisplayNode
    private let contentHeaderContainerBackgroundNode: ASImageNode
    private let contentHeaderContainerSeparatorNode: ASDisplayNode
    private var categoryItemNodes: [MessageReactionCategoryNode] = []
    private let categoryScrollNode: ASScrollNode
    private let listNode: ListView
    private var placeholderNode: MessageReactionListLoadingPlaceholder?
    private var placeholderNodeIsAnimatingOut = false
    
    private var validLayout: ContainerViewLayout?
    
    private var currentCategory: MessageReactionListCategory = .all
    private var currentState: MessageReactionListState?
    
    private var enqueuedTransactions: [MessageReactionListTransaction] = []
    
    private let disposable = MetaDisposable()
    
    let isReady = Promise<Bool>()
    
    private var forceHeaderTransition: ContainedViewLayoutTransition?
    
    init(context: AccountContext, presentationData: PresentationData, messageId: MessageId, initialReactions: [MessageReaction], dismiss: @escaping () -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.dismiss = dismiss
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
        
        self.contentHeaderContainerNode = ASDisplayNode()
        self.contentHeaderContainerBackgroundNode = ASImageNode()
        self.contentHeaderContainerBackgroundNode.displaysAsynchronously = false
        
        self.contentHeaderContainerSeparatorNode = ASDisplayNode()
        self.contentHeaderContainerSeparatorNode.backgroundColor = self.presentationData.theme.list.itemPlainSeparatorColor
        
        self.categoryScrollNode = ASScrollNode()
        self.contentHeaderContainerBackgroundNode.displayWithoutProcessing = true
        self.contentHeaderContainerBackgroundNode.image = generateImage(CGSize(width: 10.0, height: 10.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(presentationData.theme.rootController.navigationBar.backgroundColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height / 2.0), size: CGSize(width: size.width, height: size.height / 2.0)))
        })?.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
        
        self.listNode = ListView()
        self.listNode.limitHitTestToNodes = true
        
        self.placeholderNode = MessageReactionListLoadingPlaceholder(theme: presentationData.theme, itemHeight: itemHeight)
        self.placeholderNode?.isUserInteractionEnabled = false
        
        self.listContext = MessageReactionListContext(postbox: self.context.account.postbox, network: self.context.account.network, messageId: messageId, initialReactions: initialReactions)
        
        super.init()
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.backgroundNode)
        
        self.listNode.stackFromBottom = false
        self.addSubnode(self.listNode)
        self.placeholderNode.flatMap(self.addSubnode)
        
        self.addSubnode(self.contentHeaderContainerNode)
        self.contentHeaderContainerNode.addSubnode(self.contentHeaderContainerBackgroundNode)
        self.contentHeaderContainerNode.addSubnode(self.contentHeaderContainerSeparatorNode)
        self.contentHeaderContainerNode.addSubnode(self.categoryScrollNode)
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let layout = strongSelf.validLayout else {
                return
            }
            
            let transition = strongSelf.forceHeaderTransition ?? listTransition
            strongSelf.forceHeaderTransition = nil
            
            let topOffset = offset
            transition.updateFrame(node: strongSelf.contentHeaderContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topOffset - headerHeight), size: CGSize(width: layout.size.width, height: headerHeight)))
            transition.updateFrame(node: strongSelf.contentHeaderContainerBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: headerHeight)))
            transition.updateFrame(node: strongSelf.contentHeaderContainerSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: headerHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
            if let placeholderNode = strongSelf.placeholderNode {
                transition.updateFrame(node: placeholderNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topOffset), size: placeholderNode.bounds.size))
            }
            transition.updateFrame(node: strongSelf.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topOffset - headerHeight / 2.0), size: CGSize(width: layout.size.width, height: layout.size.height + 300.0)))
        }
        
        self.disposable.set((self.listContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.updateState(state)
        }))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTapGesture)))
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = layout
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateBounds(node: self.listNode, bounds: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height))
        transition.updatePosition(node: self.listNode, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
        
        var currentCategoryItemCount = 0
        if let currentState = self.currentState {
            for (category, categoryState) in currentState.states {
                if category == self.currentCategory {
                    currentCategoryItemCount = categoryState.count
                    break
                }
            }
        }
        
        var insets = UIEdgeInsets()
        insets.top = topInsetForLayout(layout: layout, itemCount: currentCategoryItemCount)
        insets.bottom = layout.intrinsicInsets.bottom
        
        if let placeholderNode = self.placeholderNode, !self.placeholderNodeIsAnimatingOut {
            let placeholderHeight = min(CGFloat(currentCategoryItemCount) * itemHeight, layout.size.height) + UIScreenPixel
            placeholderNode.frame = CGRect(origin: placeholderNode.frame.origin, size: CGSize(width: layout.size.width, height: placeholderHeight))
            placeholderNode.updateLayout(size: CGSize(width: layout.size.width, height: placeholderHeight))
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let sideInset: CGFloat = 12.0
        let spacing: CGFloat = 6.0
        var leftX = sideInset
        for itemNode in self.categoryItemNodes {
            let itemSize = itemNode.updateLayout()
            itemNode.frame = CGRect(origin: CGPoint(x: leftX, y: 0.0), size: itemSize)
            leftX += spacing + itemSize.width
        }
        leftX += sideInset
        self.categoryScrollNode.view.contentSize = CGSize(width: leftX, height: 60.0)
        self.categoryScrollNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: 60.0))
        
        if isFirstLayout {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.dimNode.layer.animatePosition(from: CGPoint(x: self.dimNode.position.x, y: self.dimNode.position.y - self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
        })
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.dimNode.layer.animatePosition(from: self.dimNode.position, to: CGPoint(x: self.dimNode.position.x, y: self.dimNode.position.y - self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false)
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func updateState(_ state: MessageReactionListState) {
        if self.currentState != state {
            self.currentState = state
            
            self.updateItems()
            
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(layout: validLayout, transition: .immediate)
            }
        }
    }
    
    private var currentEntries: [MessageReactionListEntry]?
    private func updateItems() {
        var entries: [MessageReactionListEntry] = []
        
        var index = 0
        let states = self.currentState?.states ?? []
        for (category, categoryState) in states {
            if self.categoryItemNodes.count <= index {
                let itemNode = MessageReactionCategoryNode(theme: self.presentationData.theme, category: category, count: categoryState.count, action: { [weak self] in
                    self?.setCategory(category)
                })
                self.categoryItemNodes.append(itemNode)
                self.categoryScrollNode.addSubnode(itemNode)
                if category == self.currentCategory {
                    itemNode.isSelected = true
                } else {
                    itemNode.isSelected = false
                }
            }
            
            if category == self.currentCategory {
                for item in categoryState.items {
                    entries.append(MessageReactionListEntry(index: entries.count, item: item))
                }
            }
            index += 1
        }
        let transaction = preparedTransition(from: self.currentEntries ?? [], to: entries, context: self.context, presentationData: self.presentationData)
        let previousWasEmpty = self.currentEntries == nil || self.currentEntries?.count == 0
        let isEmpty = entries.isEmpty
        self.currentEntries = entries
        
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
        
        if previousWasEmpty && !isEmpty {
            if let placeholderNode = self.placeholderNode {
                self.placeholderNodeIsAnimatingOut = true
                placeholderNode.allowsGroupOpacity = true
                placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.placeholderNode?.removeFromSupernode()
                    strongSelf.placeholderNode = nil
                })
            }
            self.listNode.forEachItemNode({ itemNode in
                itemNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
            })
        }
    }
    
    func setCategory(_ category: MessageReactionListCategory) {
        if self.currentCategory != category {
            self.currentCategory = category
            
            for itemNode in self.categoryItemNodes {
                itemNode.isSelected = category == itemNode.category
            }
            
            //self.forceHeaderTransition = .animated(duration: 0.3, curve: .spring)
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(layout: validLayout, transition: .animated(duration: 0.3, curve: .spring))
            }
            
            self.updateItems()
        }
    }
    
    private func dequeueTransaction() {
        guard let layout = self.validLayout, let transaction = self.enqueuedTransactions.first else {
            return
        }
            
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        options.insert(.Synchronous)
        options.insert(.PreferSynchronousResourceLoading)
        options.insert(.PreferSynchronousDrawing)
        
        var currentCategoryItemCount = 0
        if let currentState = self.currentState {
            for (category, categoryState) in currentState.states {
                if category == self.currentCategory {
                    currentCategoryItemCount = categoryState.count
                    break
                }
            }
        }
        
        var insets = UIEdgeInsets()
        insets.top = topInsetForLayout(layout: layout, itemCount: currentCategoryItemCount)
        insets.bottom = layout.intrinsicInsets.bottom
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listNode.bounds.size, insets: insets, duration: 0.3, curve: .Default(duration: 0.3))
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil, completion: { [weak self] _ in
            self?.isReady.set(.single(true))
        })
    }
    
    @objc private func dimNodeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for itemNode in self.categoryItemNodes {
            if let result = itemNode.hitTest(self.view.convert(point, to: itemNode.view), with: event) {
                return result
            }
        }
        if let result = self.listNode.hitTest(self.view.convert(point, to: self.listNode.view), with: event) {
            return result
        }
        if point.y >= self.contentHeaderContainerNode.frame.minY && point.y < self.bounds.height {
            return self.listNode.view
        }
        if point.y >= 0 && point.y < self.contentHeaderContainerNode.frame.minY {
            return self.dimNode.view
        }
        return nil
    }
}
