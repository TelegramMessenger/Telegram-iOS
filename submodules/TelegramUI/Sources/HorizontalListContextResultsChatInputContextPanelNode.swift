import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import StickerPackPreviewUI
import ContextUI
import ChatPresentationInterfaceState
import UndoUI

private struct ChatContextResultStableId: Hashable {
    let result: ChatContextResult

    func hash(into hasher: inout Hasher) {
        hasher.combine(result.id.hashValue)
    }
    
    static func ==(lhs: ChatContextResultStableId, rhs: ChatContextResultStableId) -> Bool {
        return lhs.result == rhs.result
    }
}

private struct HorizontalListContextResultsChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let theme: PresentationTheme
    let result: ChatContextResult
    
    var stableId: ChatContextResultStableId {
        return ChatContextResultStableId(result: self.result)
    }
    
    static func ==(lhs: HorizontalListContextResultsChatInputContextPanelEntry, rhs: HorizontalListContextResultsChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.theme === rhs.theme && lhs.result == rhs.result
    }
    
    static func <(lhs: HorizontalListContextResultsChatInputContextPanelEntry, rhs: HorizontalListContextResultsChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> ListViewItem {
        return HorizontalListContextResultsChatInputPanelItem(account: account, theme: self.theme, result: self.result, resultSelected: resultSelected)
    }
}

private struct HorizontalListContextResultsChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let entryCount: Int
    let hasMore: Bool
}

private final class HorizontalListContextResultsOpaqueState {
    let entryCount: Int
    let hasMore: Bool
    
    init(entryCount: Int, hasMore: Bool) {
        self.entryCount = entryCount
        self.hasMore = hasMore
    }
}

private func preparedTransition(from fromEntries: [HorizontalListContextResultsChatInputContextPanelEntry], to toEntries: [HorizontalListContextResultsChatInputContextPanelEntry], hasMore: Bool, account: Account, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> HorizontalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, resultSelected: resultSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, resultSelected: resultSelected), directionHint: nil) }
    
    return HorizontalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates, entryCount: toEntries.count, hasMore: hasMore)
}

final class HorizontalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private var strings: PresentationStrings
    
    private let listView: ListView
    private let separatorNode: ASDisplayNode
    private var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [HorizontalListContextResultsChatInputContextPanelEntry]?
    private var isLoadingMore = false
    private let loadMoreDisposable = MetaDisposable()
    
    private var enqueuedTransitions: [(HorizontalListContextResultsChatInputContextPanelTransition, Bool)] = []
    private var hasValidLayout = false
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.strings = strings
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
        self.separatorNode.isHidden = true
        
        self.listView = ListView()
        self.listView.isOpaque = true
        self.listView.backgroundColor = theme.list.plainBackgroundColor
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(CGFloat.pi / 2.0), 0.0, 0.0, 1.0)
        self.listView.isHidden = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
        self.addSubnode(self.separatorNode)
        
        self.listView.displayedItemRangeChanged = { [weak self] displayedRange, opaqueTransactionState in
            if let strongSelf = self, let state = opaqueTransactionState as? HorizontalListContextResultsOpaqueState {
                if let visible = displayedRange.visibleRange {
                    if state.hasMore && visible.lastIndex >= state.entryCount - 10 {
                        strongSelf.loadMore()
                    }
                }
            }
        }
    }
    
    deinit {
        self.loadMoreDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.view.disablesInteractiveKeyboardGestureRecognizer = true
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            if let strongSelf = self {
                let convertedPoint = strongSelf.listView.view.convert(point, from: strongSelf.view)
                
                if !strongSelf.listView.bounds.contains(convertedPoint) {
                    return nil
                }
                
                var selectedItemNodeAndContent: (ASDisplayNode, PeekControllerContent)?
                strongSelf.listView.forEachItemNode { itemNode in
                    if itemNode.frame.contains(convertedPoint), let itemNode = itemNode as? HorizontalListContextResultsChatInputPanelItemNode, let item = itemNode.item {
                        if case let .internalReference(internalReference) = item.result, let file = internalReference.file, file.isSticker {
                            var menuItems: [ContextMenuItem] = []
                            menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_Send, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                f(.default)
                                
                                let _ = item.resultSelected(item.result, itemNode, itemNode.bounds)
                            })))
                            for case let .Sticker(_, packReference, _) in file.attributes {
                                guard let packReference = packReference else {
                                    continue
                                }
                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let strongSelf = self {
                                        let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.interfaceInteraction?.getNavigationController(), sendSticker: { file, sourceNode, sourceRect in
                                            if let strongSelf = self {
                                                return strongSelf.interfaceInteraction?.sendSticker(file, false, sourceNode, sourceRect) ?? false
                                            } else {
                                                return false
                                            }
                                        })
                                                    
                                        strongSelf.interfaceInteraction?.getNavigationController()?.view.window?.endEditing(true)
                                        strongSelf.interfaceInteraction?.presentController(controller, nil)
                                    }
                                })))
                            }
                            selectedItemNodeAndContent = (itemNode, StickerPreviewPeekContent(account: item.account, item: .found(FoundStickerItem(file: file, stringRepresentations: [])), menu: menuItems))
                        } else {
                            var menuItems: [ContextMenuItem] = []
                            if case let .internalReference(internalReference) = item.result, let file = internalReference.file, file.isAnimated {
                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Preview_SaveGif, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    f(.dismissWithoutContent)
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let _ = addSavedGif(postbox: strongSelf.context.account.postbox, fileReference: .standalone(media: file)).start()
                                    
                                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                    strongSelf.interfaceInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: strongSelf.strings.Gallery_GifSaved), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), nil)
                                })))
                            }
                            menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.ShareMenu_Send, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                let _ = item.resultSelected(item.result, itemNode, itemNode.bounds)
                            })))
                            selectedItemNodeAndContent = (itemNode, ChatContextResultPeekContent(account: item.account, contextResult: item.result, menu: menuItems))
                        }
                    }
                }
                return .single(selectedItemNodeAndContent)
            }
            return nil
        }, present: { [weak self] content, sourceNode in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = PeekController(presentationData: presentationData, content: content, sourceNode: {
                    return sourceNode
                })
                strongSelf.interfaceInteraction?.presentGlobalOverlayController(controller, nil)
                return controller
            }
            return nil
        }))
    }
    
    func updateResults(_ results: ChatContextResultCollection) {
        if self.currentExternalResults == results {
            return
        }
        self.currentExternalResults = results
        self.currentProcessedResults = results
        
        self.isLoadingMore = false
        self.loadMoreDisposable.set(nil)
        self.updateInternalResults(results)
    }
    
    private func loadMore() {
        guard !self.isLoadingMore, let currentProcessedResults = self.currentProcessedResults, let nextOffset = currentProcessedResults.nextOffset else {
            return
        }
        self.isLoadingMore = true
        let geoPoint = currentProcessedResults.geoPoint.flatMap { geoPoint -> (Double, Double) in
            return (geoPoint.latitude, geoPoint.longitude)
        }
        self.loadMoreDisposable.set((self.context.engine.messages.requestChatContextResults(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, location: .single(geoPoint), offset: nextOffset)
        |> map { results -> ChatContextResultCollection? in
            return results?.results
        }
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
            for result in nextResults.results {
                if !existingIds.contains(result.id) {
                    results.append(result)
                    existingIds.insert(result.id)
                }
            }
            let mergedResults = ChatContextResultCollection(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, geoPoint: currentProcessedResults.geoPoint, queryId: nextResults.queryId, nextOffset: nextResults.nextOffset, presentation: currentProcessedResults.presentation, switchPeer: currentProcessedResults.switchPeer, results: results, cacheTimeout: currentProcessedResults.cacheTimeout)
            strongSelf.currentProcessedResults = mergedResults
            strongSelf.updateInternalResults(mergedResults)
        }))
    }
    
    private func updateInternalResults(_ results: ChatContextResultCollection) {
        var entries: [HorizontalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<ChatContextResultStableId>()
        for result in results.results {
            let entry = HorizontalListContextResultsChatInputContextPanelEntry(index: index, theme: self.theme, result: result)
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, hasMore: results.nextOffset != nil, account: self.context.account, resultSelected: { [weak self] result, node, rect in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                return interfaceInteraction.sendContextResult(results, result, node, rect)
            } else {
                return false
            }
        })
        self.currentEntries = entries
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: HorizontalListContextResultsChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.Synchronous)
            options.insert(.LowLatency)
            options.insert(.PreferSynchronousResourceLoading)
            if firstTime {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                //options.insert(.AnimateTopItemPosition)
                //options.insert(.AnimateCrossfade)
            }
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: HorizontalListContextResultsOpaqueState(entryCount: transition.entryCount, hasMore: transition.hasMore), completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    let position = strongSelf.listView.position
                    let separatorPosition = strongSelf.separatorNode.layer.position
                    
                    strongSelf.listView.isHidden = false
                    strongSelf.separatorNode.isHidden = false
                    
                    strongSelf.listView.position = CGPoint(x: position.x, y: position.y + strongSelf.listView.bounds.size.width)
                    strongSelf.separatorNode.position = CGPoint(x: separatorPosition.x, y: separatorPosition.y + strongSelf.listView.bounds.size.width)
                    ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring).animateView {
                        strongSelf.listView.position = position
                        strongSelf.separatorNode.position = separatorPosition
                    }
                }
            })
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let listHeight: CGFloat = 105.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - listHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: listHeight, height: size.width)
        
        //transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        transition.updatePosition(node: self.listView, position: CGPoint(x: size.width / 2.0, y: size.height - listHeight / 2.0))
        
        var insets = UIEdgeInsets()
        insets.top = leftInset
        insets.bottom = rightInset

        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: listHeight, height: size.width), insets: insets, duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
            self.listView.backgroundColor = theme.list.plainBackgroundColor
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        let position = self.listView.layer.position
        self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + self.listView.bounds.size.width), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
        let separatorPosition = self.separatorNode.layer.position
        self.separatorNode.layer.animatePosition(from: separatorPosition, to: CGPoint(x: separatorPosition.x, y: separatorPosition.y + listView.bounds.size.width), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewBounds = self.listView.bounds
        let listViewPosition = self.listView.position
        let listViewFrame = CGRect(origin: CGPoint(x: listViewPosition.x - listViewBounds.height / 2.0, y: listViewPosition.y - listViewBounds.width / 2.0), size: CGSize(width: listViewBounds.height, height: listViewBounds.width))
        if !listViewFrame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
