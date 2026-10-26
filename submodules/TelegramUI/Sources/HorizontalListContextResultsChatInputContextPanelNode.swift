import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import StickerPackPreviewUI
import StickerPeekUI
import ContextUI
import ChatPresentationInterfaceState
import UndoUI
import PremiumUI
import ChatControllerInteraction
import ChatContextResultPeekContent
import ChatInputContextPanelNode
import BatchVideoRendering
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters

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
    
    func item(context: AccountContext, batchVideoContext: QueueLocalObject<BatchVideoRenderingContext>, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> ListViewItem {
        return HorizontalListContextResultsChatInputPanelItem(context: context, theme: self.theme, result: self.result, batchVideoContext: batchVideoContext, resultSelected: resultSelected)
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

private func preparedTransition(from fromEntries: [HorizontalListContextResultsChatInputContextPanelEntry], to toEntries: [HorizontalListContextResultsChatInputContextPanelEntry], hasMore: Bool, context: AccountContext, batchVideoContext: QueueLocalObject<BatchVideoRenderingContext>, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> HorizontalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, batchVideoContext: batchVideoContext, resultSelected: resultSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, batchVideoContext: batchVideoContext, resultSelected: resultSelected), directionHint: nil) }
    
    return HorizontalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates, entryCount: toEntries.count, hasMore: hasMore)
}

final class HorizontalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let backgroundContainerView: GlassBackgroundContainerView
    private let backgroundView: GlassBackgroundView
    private let listClippingView: UIView
    private let listView: ListView
    private let buttonTitleNode: ImmediateTextNode
    private let buttonSeparatorNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [HorizontalListContextResultsChatInputContextPanelEntry]?
    private var isLoadingMore = false
    private let loadMoreDisposable = MetaDisposable()
    
    private var enqueuedTransitions: [(HorizontalListContextResultsChatInputContextPanelTransition, Bool)] = []
    private var hasValidLayout = false
    private var layoutContent: (hasButton: Bool, hasResults: Bool)?
    
    private let batchVideoContext: QueueLocalObject<BatchVideoRenderingContext>
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.backgroundContainerView = GlassBackgroundContainerView()
        self.backgroundView = GlassBackgroundView()
        self.backgroundContainerView.contentView.addSubview(self.backgroundView)
        self.listClippingView = UIView()
        self.listClippingView.clipsToBounds = true
        
        self.listView = ListViewImpl()
        self.listView.isOpaque = false
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(CGFloat.pi / 2.0), 0.0, 0.0, 1.0)
        self.listView.isHidden = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.buttonTitleNode = ImmediateTextNode()
        self.buttonTitleNode.maximumNumberOfLines = 1
        self.buttonTitleNode.truncationType = .end
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.isHidden = true
        
        self.buttonSeparatorNode = ASDisplayNode()
        self.buttonSeparatorNode.isHidden = true
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isHidden = true
        
        self.batchVideoContext = QueueLocalObject(queue: .mainQueue(), generate: {
            return BatchVideoRenderingContext(context: context)
        })
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = false
        self.layer.allowsGroupOpacity = true
        
        self.view.addSubview(self.backgroundContainerView)
        self.listClippingView.addSubview(self.listView.view)
        self.backgroundView.contentView.addSubview(self.listClippingView)
        self.backgroundView.contentView.addSubview(self.buttonSeparatorNode.view)
        self.backgroundView.contentView.addSubview(self.buttonTitleNode.view)
        self.backgroundView.contentView.addSubview(self.buttonNode.view)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.buttonTitleNode.layer.removeAnimation(forKey: "opacity")
                self.buttonTitleNode.alpha = 0.4
            } else {
                self.buttonTitleNode.alpha = 1.0
                self.buttonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
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
        self.view.addGestureRecognizer(PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point -> Signal<(UIView, CGRect, PeekControllerContent)?, NoError>? in
            if let strongSelf = self {
                let convertedPoint = strongSelf.listView.view.convert(point, from: strongSelf.view)
                
                if !strongSelf.listView.bounds.contains(convertedPoint) {
                    return nil
                }
                
                var selectedItemNodeAndContent: (UIView, CGRect, PeekControllerContent)?
                selectedItemNodeAndContent = nil
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
                                        let controller = StickerPackScreen(context: strongSelf.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: strongSelf.interfaceInteraction?.getNavigationController(), sendSticker: { file, sourceView, sourceRect in
                                            if let strongSelf = self {
                                                return strongSelf.interfaceInteraction?.sendSticker(file, false, sourceView, sourceRect, nil, []) ?? false
                                            } else {
                                                return false
                                            }
                                        })
                                                    
                                        strongSelf.interfaceInteraction?.getNavigationController()?.view.window?.endEditing(true)
                                        strongSelf.interfaceInteraction?.presentController(controller, nil)
                                    }
                                })))
                            }
                            selectedItemNodeAndContent = (itemNode.view, itemNode.bounds, StickerPreviewPeekContent(context: item.context, theme: strongSelf.theme, strings: strongSelf.strings, item: .found(FoundStickerItem(file: file, stringRepresentations: [])), menu: menuItems, openPremiumIntro: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                strongSelf.interfaceInteraction?.getNavigationController()?.pushViewController(controller)
                            }))
                        } else if let batchVideoContext = strongSelf.batchVideoContext.unsafeGet() {
                            var menuItems: [ContextMenuItem] = []
                            if case let .internalReference(internalReference) = item.result, let file = internalReference.file, file.isAnimated {
                                menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.Preview_SaveGif, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                                }, action: { _, f in
                                    f(.dismissWithoutContent)
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let context = strongSelf.context
                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                    let interfaceInteraction = strongSelf.interfaceInteraction
                                    let _ = (toggleGifSaved(account: context.account, fileReference: .standalone(media: file), saved: true)
                                    |> deliverOnMainQueue).startStandalone(next: { result in
                                        switch result {
                                            case .generic:
                                            interfaceInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                                            case let .limitExceeded(limit, premiumLimit):
                                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                                let text: String
                                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                                    text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                                } else {
                                                    text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                                }
                                                interfaceInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                                                    if case .info = action {
                                                        let controller = PremiumIntroScreen(context: context, source: .savedGifs)
                                                        interfaceInteraction?.getNavigationController()?.pushViewController(controller)
                                                        return true
                                                    }
                                                    return false
                                                }), nil)
                                        }
                                    })
                                })))
                            }
                            menuItems.append(.action(ContextMenuActionItem(text: strongSelf.strings.ShareMenu_Send, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                let _ = item.resultSelected(item.result, itemNode, itemNode.bounds)
                            })))
                            selectedItemNodeAndContent = (itemNode.view, itemNode.bounds, ChatContextResultPeekContent(context: item.context, contextResult: item.result, menu: menuItems, batchVideoContext: batchVideoContext))
                        }
                    }
                }
                return .single(selectedItemNodeAndContent)
            }
            return nil
        }, present: { [weak self] content, sourceView, sourceRect in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = makePeekController(presentationData: presentationData, content: content, sourceView: {
                    return (sourceView, sourceRect)
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
    
    @objc private func buttonPressed() {
        guard let results = self.currentProcessedResults, let interfaceInteraction = self.interfaceInteraction else {
            return
        }
        ChatContextResultsButton(results: results)?.activate(context: self.context, interfaceInteraction: interfaceInteraction, botId: results.botId)
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
        |> deliverOnMainQueue).startStrict(next: { [weak self] nextResults in
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
            let mergedResults = ChatContextResultCollection(botId: currentProcessedResults.botId, peerId: currentProcessedResults.peerId, query: currentProcessedResults.query, geoPoint: currentProcessedResults.geoPoint, queryId: nextResults.queryId, nextOffset: nextResults.nextOffset, presentation: currentProcessedResults.presentation, switchPeer: currentProcessedResults.switchPeer, webView: currentProcessedResults.webView, results: results, cacheTimeout: currentProcessedResults.cacheTimeout)
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
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, hasMore: results.nextOffset != nil, context: self.context, batchVideoContext: self.batchVideoContext, resultSelected: { [weak self] result, node, rect in
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
                    strongSelf.listView.isHidden = false
                    
                    strongSelf.layer.allowsGroupOpacity = true
                    strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            })
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let defaultListHeight: CGFloat = 105.0
        let sideInset: CGFloat = 8.0
        let innerInset: CGFloat = 4.0
        let cornerRadius: CGFloat = 8.0
        let innerRadius: CGFloat = cornerRadius - innerInset
        
        // The bot's switch_pm / switch_webview button is a row above the strip, in the same glass panel.
        // A gallery answer may carry the button and no results at all; the panel is then the row alone.
        let button = self.currentProcessedResults.flatMap(ChatContextResultsButton.init(results:))
        let hasResults = !(self.currentProcessedResults?.results.isEmpty ?? true)
        let buttonHeight: CGFloat = button != nil ? VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight(style: .regular) : 0.0
        
        // Above the node's top edge the panel sits under the navigation bar, where it cannot be tapped. When
        // there is less room than a full strip (landscape with the keyboard up), the strip shrinks instead,
        // down to half its height: its items take their size from the strip's height.
        let availableHeight = size.height - bottomInset - 8.0
        let listHeight = min(defaultListHeight, max(floor(defaultListHeight / 2.0), availableHeight - buttonHeight))
        
        // A part the panel did not show before is placed at its final frame and faded in. An animated
        // transition would grow the row out of a zero frame, and a strip appearing under a lone button row
        // would ride up from below the growing panel, over the input field, so the panel is then laid out
        // in place.
        let previousContent = self.layoutContent
        self.layoutContent = (hasButton: button != nil, hasResults: hasResults)
        let buttonAppeared = button != nil && previousContent?.hasButton != true
        let resultsAppeared = hasResults && previousContent?.hasResults == false
        let panelTransition: ContainedViewLayoutTransition = resultsAppeared ? .immediate : transition
        let buttonTransition: ContainedViewLayoutTransition = buttonAppeared ? .immediate : panelTransition
        
        let panelHeight = buttonHeight + (hasResults ? listHeight : 0.0)
        let panelFrame = CGRect(x: sideInset, y: size.height - bottomInset - 8.0 - panelHeight, width: size.width - sideInset * 2.0, height: panelHeight)
        let listFrame = CGRect(x: 0.0, y: buttonHeight, width: panelFrame.width, height: listHeight)
        
        let transformedListFrame = CGSize(width: listFrame.height, height: listFrame.width).centered(in: listFrame)
        self.listView.bounds = CGRect(origin: CGPoint(), size: transformedListFrame.size)
        panelTransition.updatePosition(node: self.listView, position: CGRect(origin: CGPoint(x: -innerInset, y: -innerInset), size: listFrame.size).center)
        
        panelTransition.updateFrame(view: self.listClippingView, frame: listFrame.insetBy(dx: innerInset, dy: innerInset))
        self.listClippingView.layer.cornerRadius = innerRadius
        self.listClippingView.isHidden = !hasResults
        
        if let button {
            let buttonFrame = CGRect(x: 0.0, y: 0.0, width: panelFrame.width, height: buttonHeight)
            
            // Kept clear of the safe area, as the strip's items are through the list insets.
            let titleInsetLeft = max(0.0, leftInset - sideInset) + 8.0
            let titleInsetRight = max(0.0, rightInset - sideInset) + 8.0
            let titleAreaWidth = max(0.0, buttonFrame.width - titleInsetLeft - titleInsetRight)
            
            self.buttonTitleNode.attributedText = NSAttributedString(string: button.title, font: Font.regular(15.0), textColor: interfaceState.theme.chat.inputPanel.panelControlColor)
            let titleSize = self.buttonTitleNode.updateLayout(CGSize(width: titleAreaWidth, height: buttonFrame.height))
            buttonTransition.updateFrame(node: self.buttonTitleNode, frame: CGRect(origin: CGPoint(x: titleInsetLeft + floor((titleAreaWidth - titleSize.width) / 2.0), y: floor((buttonFrame.height - titleSize.height) / 2.0)), size: titleSize))
            
            self.buttonSeparatorNode.backgroundColor = interfaceState.theme.list.itemPlainSeparatorColor
            buttonTransition.updateFrame(node: self.buttonSeparatorNode, frame: CGRect(x: 0.0, y: buttonFrame.maxY - UIScreenPixel, width: buttonFrame.width, height: UIScreenPixel))
            
            buttonTransition.updateFrame(node: self.buttonNode, frame: buttonFrame)
            self.buttonNode.accessibilityLabel = button.title
        }
        self.buttonTitleNode.isHidden = button == nil
        self.buttonSeparatorNode.isHidden = button == nil || !hasResults
        self.buttonNode.isHidden = button == nil
        
        if transition.isAnimated && previousContent != nil {
            if buttonAppeared {
                self.buttonTitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            if buttonAppeared || resultsAppeared {
                self.buttonSeparatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            if resultsAppeared {
                self.listClippingView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
        
        let backgroundContainerInset: CGFloat = 32.0
        let backgroundContainerFrame = panelFrame.insetBy(dx: -backgroundContainerInset, dy: -backgroundContainerInset)
        panelTransition.updateFrame(view: self.backgroundContainerView, frame: backgroundContainerFrame)
        self.backgroundContainerView.update(size: backgroundContainerFrame.size, isDark: interfaceState.theme.overallDarkAppearance, transition: ComponentTransition(panelTransition))
        
        panelTransition.updateFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: panelFrame.size).offsetBy(dx: backgroundContainerInset, dy: backgroundContainerInset))
        self.backgroundView.update(size: panelFrame.size, cornerRadius: cornerRadius, isDark: interfaceState.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: ComponentTransition(panelTransition))
        
        var insets = UIEdgeInsets()
        insets.top = leftInset
        insets.bottom = rightInset

        let (duration, curve) = listViewAnimationDurationAndCurve(transition: panelTransition)
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
            self.listView.backgroundColor = self.theme.list.plainBackgroundColor
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        ComponentTransition.easeInOut(duration: 0.3).setAlpha(view: self.backgroundContainerView, alpha: 0.01, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if result === self.view {
            return nil
        }
        return result
    }
}
