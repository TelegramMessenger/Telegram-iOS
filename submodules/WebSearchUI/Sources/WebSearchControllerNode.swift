import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import GalleryUI
import ChatListSearchItemHeader
import SegmentedControlNode
import AppBundle

private struct WebSearchContextResultStableId: Hashable {
    let result: ChatContextResult
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(result.id)
    }
    
    static func ==(lhs: WebSearchContextResultStableId, rhs: WebSearchContextResultStableId) -> Bool {
        return lhs.result == rhs.result
    }
}

private struct WebSearchEntry: Comparable, Identifiable {
    let index: Int
    let result: ChatContextResult
    
    var stableId: WebSearchContextResultStableId {
        return WebSearchContextResultStableId(result: self.result)
    }
    
    static func ==(lhs: WebSearchEntry, rhs: WebSearchEntry) -> Bool {
        return lhs.index == rhs.index && lhs.result == rhs.result
    }
    
    static func <(lhs: WebSearchEntry, rhs: WebSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, interfaceState: WebSearchInterfaceState, controllerInteraction: WebSearchControllerInteraction) -> GridItem {
        return WebSearchItem(account: account, theme: theme, interfaceState: interfaceState, result: self.result, controllerInteraction: controllerInteraction)
    }
}

private struct WebSearchTransition {
    let deleteItems: [Int]
    let insertItems: [GridNodeInsertItem]
    let updateItems: [GridNodeUpdateItem]
    let entryCount: Int
    let hasMore: Bool
}

private func preparedTransition(from fromEntries: [WebSearchEntry], to toEntries: [WebSearchEntry], hasMore: Bool, account: Account, theme: PresentationTheme, interfaceState: WebSearchInterfaceState, controllerInteraction: WebSearchControllerInteraction) -> WebSearchTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, theme: theme, interfaceState: interfaceState, controllerInteraction: controllerInteraction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, interfaceState: interfaceState, controllerInteraction: controllerInteraction)) }
    
    return WebSearchTransition(deleteItems: deleteIndices, insertItems: insertions, updateItems: updates, entryCount: toEntries.count, hasMore: hasMore)
}

private func gridNodeLayoutForContainerLayout(_ layout: ContainerViewLayout) -> GridNodeLayoutType {
    let itemsPerRow: Int
    if case .compact = layout.metrics.widthClass {
        switch layout.orientation {
            case .portrait:
                itemsPerRow = 3
            case .landscape:
                itemsPerRow = 5
        }
    } else {
        itemsPerRow = 3
    }
    
    let side = floorToScreenPixels((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - CGFloat(itemsPerRow - 1)) / CGFloat(itemsPerRow))
    return .fixed(itemSize: CGSize(width: side, height: side), fillWidth: true, lineSpacing: 1.0, itemSpacing: 1.0)
}


private struct WebSearchRecentQueryStableId: Hashable {
    let query: String
}

private struct WebSearchRecentQueryEntry: Comparable, Identifiable {
    let index: Int
    let query: String
    
    var stableId: WebSearchRecentQueryStableId {
        return WebSearchRecentQueryStableId(query: self.query)
    }
    
    static func ==(lhs: WebSearchRecentQueryEntry, rhs: WebSearchRecentQueryEntry) -> Bool {
        return lhs.index == rhs.index && lhs.query == rhs.query
    }
    
    static func <(lhs: WebSearchRecentQueryEntry, rhs: WebSearchRecentQueryEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: WebSearchControllerInteraction, header: ListViewItemHeader) -> ListViewItem {
        return WebSearchRecentQueryItem(account: account, theme: theme, strings: strings, query: self.query, tapped: { query in
            controllerInteraction.setSearchQuery(query)
        }, deleted: { query in
            controllerInteraction.deleteRecentQuery(query)
        }, header: header)
    }
}

private struct WebSearchRecentTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedWebSearchRecentTransition(from fromEntries: [WebSearchRecentQueryEntry], to toEntries: [WebSearchRecentQueryEntry], account: Account, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: WebSearchControllerInteraction, header: ListViewItemHeader) -> WebSearchRecentTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, controllerInteraction: controllerInteraction, header: header), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, controllerInteraction: controllerInteraction, header: header), directionHint: nil) }
    
    return WebSearchRecentTransition(deletions: deletions, insertions: insertions, updates: updates)
}

class WebSearchControllerNode: ASDisplayNode {
    private weak var controller: WebSearchController?
    private let context: AccountContext
    private let peer: EnginePeer?
    private let chatLocation: ChatLocation?
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var presentationData: PresentationData
    private let mode: WebSearchMode
    private let attachment: Bool
    
    private let controllerInteraction: WebSearchControllerInteraction
    private var webSearchInterfaceState: WebSearchInterfaceState
    private let webSearchInterfaceStatePromise: ValuePromise<WebSearchInterfaceState>
    
    private let segmentedContainerNode: ASDisplayNode
    private let segmentedBackgroundNode: ASDisplayNode
    private let segmentedSeparatorNode: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode
    
    private let toolbarBackgroundNode: ASDisplayNode
    private let toolbarSeparatorNode: ASDisplayNode
    private let cancelButton: HighlightableButtonNode
    private let sendButton: HighlightableButtonNode
    private let badgeNode: WebSearchBadgeNode
    
    private let attributionNode: ASImageNode
    
    private let recentQueriesNode: ListView
    private var enqueuedRecentTransitions: [(WebSearchRecentTransition, Bool)] = []
    
    private var gridNode: GridNode
    private var enqueuedTransitions: [(WebSearchTransition, Bool)] = []
    private var dequeuedInitialTransitionOnLayout = false
    
    private(set) var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [WebSearchEntry]?
    private var hasMore = false
    private var isLoadingMore = false
    
    private let hiddenMediaId = Promise<String?>(nil)
    private var hiddenMediaDisposable: Disposable?
    
    private let results = ValuePromise<ChatContextResultCollection?>(nil, ignoreRepeated: true)
    
    private let disposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    
    private var recentDisposable: Disposable?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestUpdateInterfaceState: (Bool, (WebSearchInterfaceState) -> WebSearchInterfaceState) -> Void = { _, _ in }
    var cancel: (() -> Void)?
    var dismissInput: (() -> Void)?
    
    var presentStickers: ((@escaping (TelegramMediaFile, Bool, UIView, CGRect) -> Void) -> TGPhotoPaintStickersScreen?)?
    var getCaptionPanelView: () -> TGCaptionPanelView? = { return nil }
    
    init(controller: WebSearchController, context: AccountContext, presentationData: PresentationData, controllerInteraction: WebSearchControllerInteraction, peer: EnginePeer?, chatLocation: ChatLocation?, mode: WebSearchMode, attachment: Bool) {
        self.controller = controller
        self.context = context
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.peer = peer
        self.chatLocation = chatLocation
        self.mode = mode
        self.attachment = attachment
        
        self.webSearchInterfaceState = WebSearchInterfaceState(presentationData: context.sharedContext.currentPresentationData.with { $0 })
        self.webSearchInterfaceStatePromise = ValuePromise(self.webSearchInterfaceState, ignoreRepeated: true)
        
        self.segmentedContainerNode = ASDisplayNode()
        self.segmentedContainerNode.clipsToBounds = true
        
        self.segmentedBackgroundNode = ASDisplayNode()
        self.segmentedSeparatorNode = ASDisplayNode()
        
        let items = [
            strings.WebSearch_Images,
            strings.WebSearch_GIFs
        ]
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: theme), items: items.map { SegmentedControlItem(title: $0) }, selectedIndex: 0)
        
        self.toolbarBackgroundNode = ASDisplayNode()
        self.toolbarSeparatorNode = ASDisplayNode()
        
        self.attributionNode = ASImageNode()
        
        self.cancelButton = HighlightableButtonNode()
        self.sendButton = HighlightableButtonNode()
        
        self.badgeNode = WebSearchBadgeNode(theme: theme)
        
        self.gridNode = GridNode()
        self.gridNode.backgroundColor = theme.list.plainBackgroundColor
        
        self.recentQueriesNode = ListView()
        self.recentQueriesNode.backgroundColor = theme.list.plainBackgroundColor
        self.recentQueriesNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.gridNode)
        if !attachment {
            self.addSubnode(self.recentQueriesNode)
        }
        self.addSubnode(self.segmentedContainerNode)
        self.segmentedContainerNode.addSubnode(self.segmentedBackgroundNode)
        self.segmentedContainerNode.addSubnode(self.segmentedSeparatorNode)
        if case .media = mode {
            self.segmentedContainerNode.addSubnode(self.segmentedControlNode)
        }
        if !attachment {
            self.addSubnode(self.toolbarBackgroundNode)
            self.addSubnode(self.toolbarSeparatorNode)
            self.addSubnode(self.cancelButton)
            self.addSubnode(self.sendButton)
            self.addSubnode(self.attributionNode)
            self.addSubnode(self.badgeNode)
        }
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self, let scope = WebSearchScope(rawValue: Int32(index)) {
                let _ = updateWebSearchSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager) { _ -> WebSearchSettings in
                    return WebSearchSettings(scope: scope)
                    }.start()
                strongSelf.requestUpdateInterfaceState(true) { current in
                    return current.withUpdatedScope(scope)
                }
            }
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.sendButton.addTarget(self, action: #selector(self.sendPressed), forControlEvents: .touchUpInside)
        
        self.applyPresentationData()
        
        self.disposable.set((combineLatest(self.results.get(), self.webSearchInterfaceStatePromise.get())
        |> deliverOnMainQueue).start(next: { [weak self] results, interfaceState in
            if let strongSelf = self {
                strongSelf.updateInternalResults(results, interfaceState: interfaceState)
            }
        }))
        
        if !attachment {
            let previousRecentItems = Atomic<[WebSearchRecentQueryEntry]?>(value: nil)
            self.recentDisposable = (combineLatest(webSearchRecentQueries(engine: self.context.engine), self.webSearchInterfaceStatePromise.get())
            |> deliverOnMainQueue).start(next: { [weak self] queries, interfaceState in
                if let strongSelf = self {
                    var entries: [WebSearchRecentQueryEntry] = []
                    for i in 0 ..< queries.count {
                        entries.append(WebSearchRecentQueryEntry(index: i, query: queries[i]))
                    }
                    
                    let header = ChatListSearchItemHeader(type: .recentPeers, theme: interfaceState.presentationData.theme, strings: interfaceState.presentationData.strings, actionTitle: interfaceState.presentationData.strings.WebSearch_RecentSectionClear, action: {
                        let _ = clearRecentWebSearchQueries(engine: strongSelf.context.engine).start()
                    })
                    
                    let previousEntries = previousRecentItems.swap(entries)
                    
                    let transition = preparedWebSearchRecentTransition(from: previousEntries ?? [], to: entries, account: strongSelf.context.account, theme: interfaceState.presentationData.theme, strings: interfaceState.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction, header: header)
                    strongSelf.enqueueRecentTransition(transition, firstTime: previousEntries == nil)
                }
            })
        }
        
        self.recentQueriesNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        
        self.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self, let bottom = visibleItems.bottom, let entries = strongSelf.currentEntries {
                if bottom.0 >= entries.count - 8 {
                    strongSelf.loadMore()
                }
            }
        }
        self.gridNode.scrollingInitiated = { [weak self] in
            self?.dismissInput?()
        }
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self, strongSelf.badgeNode.alpha > 0.0 {
                if highlighted {
                    strongSelf.badgeNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.badgeNode.alpha = 0.4
                } else {
                    strongSelf.badgeNode.alpha = 1.0
                    strongSelf.badgeNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.hiddenMediaDisposable = (self.hiddenMediaId.get()
        |> deliverOnMainQueue).start(next: { [weak self] id in
            if let strongSelf = self {
                strongSelf.controllerInteraction.hiddenMediaId = id
                
                strongSelf.gridNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? WebSearchItemNode {
                        itemNode.updateHiddenMedia()
                    }
                }
            }
        })
    }
    
    deinit {
        self.disposable.dispose()
        self.recentDisposable?.dispose()
        self.loadMoreDisposable.dispose()
        self.hiddenMediaDisposable?.dispose()
    }
    
    func updatePresentationData(theme: PresentationTheme, strings: PresentationStrings) {
        let themeUpdated = theme !== self.theme
        self.theme = theme
        self.strings = strings
        
        self.applyPresentationData(themeUpdated: themeUpdated)
    }
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: transition)
        transition.updateAlpha(node: self.segmentedBackgroundNode, alpha: alpha)
    }
    
    func applyPresentationData(themeUpdated: Bool = true) {
        self.cancelButton.setTitle(self.strings.Common_Cancel, with: Font.regular(17.0), with: self.theme.rootController.navigationBar.accentTextColor, for: .normal)
        
        if let selectionState = self.controllerInteraction.selectionState {
            let sendEnabled = selectionState.count() > 0
            let color = sendEnabled ? self.theme.rootController.navigationBar.accentTextColor : self.theme.rootController.navigationBar.disabledButtonColor
            self.sendButton.setTitle(self.strings.MediaPicker_Send, with: Font.medium(17.0), with: color, for: .normal)
        }
        
        if themeUpdated {
            self.gridNode.backgroundColor = self.theme.list.plainBackgroundColor
            self.segmentedBackgroundNode.backgroundColor = self.theme.list.plainBackgroundColor
            self.segmentedSeparatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
            self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: self.theme))
            self.toolbarBackgroundNode.backgroundColor = self.theme.rootController.navigationBar.opaqueBackgroundColor
            self.toolbarSeparatorNode.backgroundColor = self.theme.rootController.navigationBar.separatorColor
        }
        
        let gifProviderImage: UIImage?
        if let gifProvider = self.webSearchInterfaceState.gifProvider {
            switch gifProvider {
                case "tenor":
                    gifProviderImage = generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Tenor"), color: self.theme.list.itemSecondaryTextColor)
                case "giphy":
                    gifProviderImage = generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Giphy"), color: self.theme.list.itemSecondaryTextColor)
                default:
                    gifProviderImage = nil
            }
        } else {
            gifProviderImage = nil
        }
        let previousGifProviderImage = self.attributionNode.image
        self.attributionNode.image = gifProviderImage
        
        if previousGifProviderImage == nil, let validLayout = self.containerLayout {
            self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
        }
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let hasQuery = !(self.webSearchInterfaceState.state?.query ?? "").isEmpty
        
        let segmentedHeight: CGFloat = self.segmentedControlNode.supernode != nil ? 44.0 : 5.0
        let panelY: CGFloat = insets.top - UIScreenPixel - 4.0
        
        transition.updateSublayerTransformOffset(layer: self.segmentedContainerNode.layer, offset: CGPoint(x: 0.0, y: !hasQuery ? -44.0 : 0.0), completion: nil)
        transition.updateFrame(node: self.segmentedContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelY), size: CGSize(width: layout.size.width, height: segmentedHeight)))
        
        transition.updateFrame(node: self.segmentedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: segmentedHeight)))
        transition.updateFrame(node: self.segmentedSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: segmentedHeight - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 10.0 * 2.0), transition: transition)
        transition.updateFrame(node: self.segmentedControlNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layout.size.width - layout.safeInsets.left - layout.safeInsets.right - controlSize.width) / 2.0), y: 5.0), size: controlSize))
        
        insets.top -= 4.0
        
        let toolbarHeight: CGFloat = 44.0
        let toolbarY = layout.size.height - toolbarHeight - insets.bottom
        transition.updateFrame(node: self.toolbarBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: toolbarY), size: CGSize(width: layout.size.width, height: toolbarHeight + insets.bottom)))
        transition.updateFrame(node: self.toolbarSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: toolbarY), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        if let image = self.attributionNode.image {
            self.attributionNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - image.size.width) / 2.0), y: toolbarY + floor((toolbarHeight - image.size.height) / 2.0)), size: image.size)
            transition.updateAlpha(node: self.attributionNode, alpha: self.webSearchInterfaceState.state?.scope == .gifs ? 1.0 : 0.0)
        }
        
        let toolbarPadding: CGFloat = 10.0
        let cancelSize = self.cancelButton.measure(CGSize(width: layout.size.width, height: toolbarHeight))
        transition.updateFrame(node: self.cancelButton, frame: CGRect(origin: CGPoint(x: toolbarPadding + layout.safeInsets.left, y: toolbarY), size: CGSize(width: cancelSize.width, height: toolbarHeight)))
        
        let sendSize = self.sendButton.measure(CGSize(width: layout.size.width, height: toolbarHeight))
        let sendFrame = CGRect(origin: CGPoint(x: layout.size.width - toolbarPadding - layout.safeInsets.right - sendSize.width, y: toolbarY), size: CGSize(width: sendSize.width, height: toolbarHeight))
        transition.updateFrame(node: self.sendButton, frame: sendFrame)
        
        if let selectionState = self.controllerInteraction.selectionState {
            self.sendButton.isHidden = false
            
            let previousSendEnabled = self.sendButton.isEnabled
            let sendEnabled = selectionState.count() > 0
            self.sendButton.isEnabled = sendEnabled
            if sendEnabled != previousSendEnabled {
                let color = sendEnabled ? self.theme.rootController.navigationBar.accentTextColor : self.theme.rootController.navigationBar.disabledButtonColor
                self.sendButton.setTitle(self.strings.MediaPicker_Send, with: Font.medium(17.0), with: color, for: .normal)
            }
            
            let selectedCount = selectionState.count()
            let badgeText = String(selectedCount)
            if selectedCount > 0 && (self.badgeNode.text != badgeText || self.badgeNode.alpha < 1.0) {
                if transition.isAnimated {
                    var incremented = true
                    if let previousCount = Int(self.badgeNode.text) {
                        incremented = selectedCount > previousCount || self.badgeNode.alpha < 1.0
                    }
                    self.badgeNode.animateBump(incremented: incremented)
                }
                self.badgeNode.text = badgeText
                
                let badgeSize = self.badgeNode.measure(layout.size)
                transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: CGPoint(x: sendFrame.minX - badgeSize.width - 6.0, y: toolbarY + 11.0), size: badgeSize))
                transition.updateAlpha(node: self.badgeNode, alpha: 1.0)
            } else if selectedCount == 0 {
                if transition.isAnimated {
                    self.badgeNode.animateOut()
                }
                let badgeSize = CGSize(width: 22.0, height: 22.0)
                transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: CGPoint(x: sendFrame.minX - badgeSize.width - 6.0, y: toolbarY + 11.0), size: badgeSize))
                transition.updateAlpha(node: self.badgeNode, alpha: 0.0)
            }
        } else {
            self.sendButton.isHidden = true
        }
        
        let previousBounds = self.gridNode.bounds
        self.gridNode.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: layout.size.width, height: layout.size.height)
        self.gridNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        insets.top += segmentedHeight
        insets.bottom += toolbarHeight
        
        let gridInsets = UIEdgeInsets(top: insets.top, left: layout.safeInsets.left, bottom: insets.bottom, right: layout.safeInsets.right)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: gridInsets, preloadSize: 400.0, type: gridNodeLayoutForContainerLayout(layout)), transition: .immediate), itemTransition: .immediate, stationaryItems: .none,updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        self.recentQueriesNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.recentQueriesNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.dequeuedInitialTransitionOnLayout {
            self.dequeuedInitialTransitionOnLayout = true
            self.dequeueTransition()
        }
    }
    
    func updateInterfaceState(_ interfaceState: WebSearchInterfaceState, animated: Bool) {
        let previousGifProvider = self.webSearchInterfaceState.gifProvider
        self.webSearchInterfaceState = interfaceState
        self.webSearchInterfaceStatePromise.set(self.webSearchInterfaceState)
    
        if let state = interfaceState.state {
            self.segmentedControlNode.selectedIndex = Int(state.scope.rawValue)
        }
        
        if previousGifProvider != interfaceState.gifProvider {
            self.applyPresentationData(themeUpdated: false)
        }
        
        if let validLayout = self.containerLayout {
            self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
        }
    }
    
    func updateSelectionState(animated: Bool) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? WebSearchItemNode {
                itemNode.updateSelectionState(animated: animated)
            }
        }
        
        if let validLayout = self.containerLayout {
            self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
        }
    }
    
    func updateResults(_ results: ChatContextResultCollection?, immediate: Bool = false) {
        if self.currentExternalResults == results {
            return
        }
        let previousResults = self.currentExternalResults
        self.currentExternalResults = results
        self.currentProcessedResults = results
        
        self.isLoadingMore = false
        self.loadMoreDisposable.set(nil)
        
        if immediate && previousResults?.query == results?.query && previousResults?.botId != results?.botId {
            let previousNode = self.gridNode
            
            let gridNode = GridNode()
            gridNode.backgroundColor = theme.list.plainBackgroundColor
            gridNode.frame = previousNode.frame
            
            gridNode.visibleItemsUpdated = { [weak self] visibleItems in
                if let strongSelf = self, let bottom = visibleItems.bottom, let entries = strongSelf.currentEntries {
                    if bottom.0 >= entries.count - 8 {
                        strongSelf.loadMore()
                    }
                }
            }
            gridNode.scrollingInitiated = { [weak self] in
                self?.dismissInput?()
            }
            
            if self.recentQueriesNode.supernode != nil {
                self.insertSubnode(gridNode, belowSubnode: self.recentQueriesNode)
            } else {
                self.insertSubnode(gridNode, aboveSubnode: previousNode)
            }
            self.gridNode = gridNode
            self.currentEntries = nil
            let directionMultiplier: CGFloat
            if let state = self.webSearchInterfaceState.state {
                switch state.scope {
                    case .images:
                        directionMultiplier = 1.0
                    case .gifs:
                        directionMultiplier = -1.0
                }
            } else {
                directionMultiplier = 1.0
            }
            
            previousNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -directionMultiplier * self.bounds.width, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak previousNode] _ in
                previousNode?.removeFromSupernode()
            })
            gridNode.layer.animatePosition(from: CGPoint(x: directionMultiplier * bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        } else if previousResults?.botId != results?.botId || previousResults?.query != results?.query {
            self.scrollToTop()
        }
        
        self.results.set(results)
    }
    
    func clearResults() {
        self.results.set(nil)
    }
    
    private func loadMore() {
        guard !self.isLoadingMore, let currentProcessedResults = self.currentProcessedResults, currentProcessedResults.results.count > 55, let nextOffset = currentProcessedResults.nextOffset else {
            return
        }
        self.isLoadingMore = true
        let geoPoint = currentProcessedResults.geoPoint.flatMap { geoPoint -> (Double, Double) in
            return (geoPoint.latitude, geoPoint.longitude)
        }
        self.loadMoreDisposable.set((self.context.engine.messages.requestChatContextResults(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, location: .single(geoPoint), offset: nextOffset)
            |> deliverOnMainQueue).start(next: { [weak self] nextResults in
                guard let strongSelf = self, let nextResults = nextResults else {
                    return
                }
                strongSelf.isLoadingMore = false
                var results: [ChatContextResult] = []
                var existingIds = Set<String>()
                for result in currentProcessedResults.results {
                    results.append(result)
                    existingIds.insert(result.id)
                }
                for result in nextResults.results.results {
                    if !existingIds.contains(result.id) {
                        results.append(result)
                        existingIds.insert(result.id)
                    }
                }
                let mergedResults = ChatContextResultCollection(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, geoPoint: currentProcessedResults.geoPoint, queryId: nextResults.results.queryId, nextOffset: nextResults.results.nextOffset, presentation: currentProcessedResults.presentation, switchPeer: currentProcessedResults.switchPeer, results: results, cacheTimeout: currentProcessedResults.cacheTimeout)
                strongSelf.currentProcessedResults = mergedResults
                strongSelf.results.set(mergedResults)
            }))
    }
    
    private func updateInternalResults(_ results: ChatContextResultCollection?, interfaceState: WebSearchInterfaceState) {
        var entries: [WebSearchEntry] = []
        var hasMore = false
        if let state = interfaceState.state, state.query.isEmpty {
        } else if let results = results {
            hasMore = results.nextOffset != nil
            
            var index = 0
            var resultIds = Set<WebSearchContextResultStableId>()
            for result in results.results {
                let entry = WebSearchEntry(index: index, result: result)
                if resultIds.contains(entry.stableId) {
                    continue
                } else {
                    resultIds.insert(entry.stableId)
                }
                entries.append(entry)
                index += 1
            }
        }
        
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, hasMore: hasMore, account: self.context.account, theme: interfaceState.presentationData.theme, interfaceState: interfaceState, controllerInteraction: self.controllerInteraction)
        self.currentEntries = entries
        
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: WebSearchTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            if let state = self.webSearchInterfaceState.state {
                self.recentQueriesNode.isHidden = !state.query.isEmpty
            }
            
            self.hasMore = transition.hasMore
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deleteItems, insertItems: transition.insertItems, updateItems: transition.updateItems, scrollToItem: nil, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, synchronousLoads: true), completion: { _ in })
        }
    }
    
    private func enqueueRecentTransition(_ transition: WebSearchRecentTransition, firstTime: Bool) {
        enqueuedRecentTransitions.append((transition, firstTime))
        
        if self.containerLayout != nil {
            while !self.enqueuedRecentTransitions.isEmpty {
                self.dequeueRecentTransition()
            }
        }
    }
    
    private func dequeueRecentTransition() {
        if let (transition, firstTime) = self.enqueuedRecentTransitions.first {
            self.enqueuedRecentTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
                options.insert(.PreferSynchronousDrawing)
            } else {
                options.insert(.AnimateInsertion)
            }
            
            self.recentQueriesNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
            })
        }
    }
    
    @objc private func cancelPressed() {
        self.cancel?()
    }
    
    @objc private func sendPressed() {
        self.controllerInteraction.sendSelected(nil, false, nil)
        
        self.cancel?()
    }
    
    func scrollToTop(animated: Bool = false) {
        self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.gridNode.scrollView.contentInset.top), animated: animated)
    }
    
    func openResult(currentResult: ChatContextResult, present: @escaping (ViewController, Any?) -> Void) {
        self.view.endEditing(true)
        
        if self.controllerInteraction.selectionState != nil {
            if let state = self.webSearchInterfaceState.state, state.scope == .images {
                if let results = self.currentProcessedResults?.results {
                    presentLegacyWebSearchGallery(context: self.context, peer: self.peer, chatLocation: self.chatLocation, presentationData: self.presentationData, results: results, current: currentResult, selectionContext: self.controllerInteraction.selectionState, editingContext: self.controllerInteraction.editingState, updateHiddenMedia: { [weak self] id in
                        self?.hiddenMediaId.set(.single(id))
                    }, initialLayout: self.containerLayout?.0, transitionHostView: { [weak self] in
                        return self?.gridNode.view
                    }, transitionView: { [weak self] result in
                        return self?.transitionNode(for: result)?.transitionView()
                    }, completed: { [weak self] result in
                        if let strongSelf = self {
                            strongSelf.controllerInteraction.sendSelected(result, false, nil)
                            strongSelf.cancel?()
                        }
                    }, presentStickers: self.presentStickers, getCaptionPanelView: self.getCaptionPanelView, present: present)
                }
            } else {
                if let results = self.currentProcessedResults?.results {
                    var entries: [WebSearchGalleryEntry] = []
                    var centralIndex: Int = 0
                    for i in 0 ..< results.count {
                        entries.append(WebSearchGalleryEntry(index: entries.count, result: results[i]))
                        if results[i] == currentResult {
                            centralIndex = i
                        }
                    }
                    
                    let controller = WebSearchGalleryController(context: self.context, peer: self.peer, selectionState: self.controllerInteraction.selectionState, editingState: self.controllerInteraction.editingState, entries: entries, centralIndex: centralIndex, replaceRootController: { (controller, _) in
                        
                    }, baseNavigationController: nil, sendCurrent: { [weak self] result in
                        if let strongSelf = self {
                            strongSelf.controllerInteraction.sendSelected(result, false, nil)
                            strongSelf.cancel?()
                        }
                    })
                    self.hiddenMediaId.set((controller.hiddenMedia |> deliverOnMainQueue)
                    |> map { entry in
                        return entry?.result.id
                    })
                    present(controller, WebSearchGalleryControllerPresentationArguments(transitionArguments: { [weak self] entry -> GalleryTransitionArguments? in
                        if let strongSelf = self {
                            var transitionNode: WebSearchItemNode?
                            strongSelf.gridNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? WebSearchItemNode, itemNode.item?.result.id == entry.result.id {
                                    transitionNode = itemNode
                                }
                            }
                            if let transitionNode = transitionNode {
                                return GalleryTransitionArguments(transitionNode: (transitionNode, transitionNode.bounds, { [weak transitionNode] in
                                        return (transitionNode?.transitionView().snapshotContentTree(unhide: true), nil)
                                }), addToTransitionSurface: { view in
                                    if let strongSelf = self {
                                        strongSelf.gridNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.gridNode.view)
                                    }
                                })
                            }
                        }
                        return nil
                    }))
                }
            }
        } else {
            presentLegacyWebSearchEditor(context: self.context, theme: self.theme, result: currentResult, initialLayout: self.containerLayout?.0, updateHiddenMedia: { [weak self] id in
                self?.hiddenMediaId.set(.single(id))
            }, transitionHostView: { [weak self] in
                return self?.gridNode.view
            }, transitionView: { [weak self] result in
                return self?.transitionNode(for: result)?.transitionView()
            }, completed: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.controllerInteraction.avatarCompleted(result)
                    strongSelf.cancel?()
                }
            }, present: present)
        }
    }
    
    private func transitionNode(for result: ChatContextResult) -> WebSearchItemNode? {
        var transitionNode: WebSearchItemNode?
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? WebSearchItemNode, itemNode.item?.result.id == result.id {
                transitionNode = itemNode
            }
        }
        return transitionNode
    }
}
