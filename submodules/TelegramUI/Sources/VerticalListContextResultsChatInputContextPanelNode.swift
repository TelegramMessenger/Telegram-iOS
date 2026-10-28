import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SwiftSignalKit
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatInputContextPanelNode
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import EdgeEffect
import ChatMessageWidgetBubbleContentNode

private enum VerticalChatContextResultsEntryStableId: Hashable {
    case action
    case result(ChatContextResult)
    /// A result drawn as a widget preview: another identity, so a change of how it draws is a delete and an insert.
    case widgetResult(ChatContextResult)
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .action:
                hasher.combine(0)
            case let .result(result):
                hasher.combine(result.id.hashValue)
            case let .widgetResult(result):
                hasher.combine(1)
                hasher.combine(result.id.hashValue)
        }
    }
    
    static func ==(lhs: VerticalChatContextResultsEntryStableId, rhs: VerticalChatContextResultsEntryStableId) -> Bool {
        switch lhs {
            case .action:
                if case .action = rhs {
                    return true
                } else {
                    return false
                }
            case let .result(lhsResult):
                if case let .result(rhsResult) = rhs, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
            case let .widgetResult(lhsResult):
                if case let .widgetResult(rhsResult) = rhs, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum VerticalListContextResultsChatInputContextPanelEntry: Comparable, Identifiable {
    case action(PresentationTheme, String)
    case result(Int, PresentationTheme, ChatContextResult)
    /// widget-sandbox v0.2 (v0.2 W3): a widget result, with how it draws and the height its widget last reported.
    case widgetResult(Int, PresentationTheme, ChatContextResult, TelegramMediaWidget, ChatContextResultWidgetAppearance, CGFloat?)
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> VerticalListContextResultsChatInputContextPanelEntry {
        switch self {
        case let .action(_, value):
            return .action(theme, value)
        case let .result(index, _, result):
            return .result(index, theme, result)
        case let .widgetResult(index, _, result, widget, appearance, reportedHeight):
            return .widgetResult(index, theme, result, widget, appearance, reportedHeight)
        }
    }
    
    var stableId: VerticalChatContextResultsEntryStableId {
        switch self {
            case .action:
                return .action
            case let .result(_, _, result):
                return .result(result)
            case let .widgetResult(_, _, result, _, _, _):
                return .widgetResult(result)
        }
    }
    
    static func ==(lhs: VerticalListContextResultsChatInputContextPanelEntry, rhs: VerticalListContextResultsChatInputContextPanelEntry) -> Bool {
        switch lhs {
        case let .action(lhsTheme, lhsTitle):
                if case let .action(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme && lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .result(lhsIndex, lhsTheme, lhsResult):
                if case let .result(rhsIndex, rhsTheme, rhsResult) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsResult == rhsResult {
                    return true
                } else {
                    return false
                }
            case let .widgetResult(lhsIndex, lhsTheme, lhsResult, _, lhsAppearance, lhsReportedHeight):
                // The widget is the result's own (`lhsResult == rhsResult` compares it).
                if case let .widgetResult(rhsIndex, rhsTheme, rhsResult, _, rhsAppearance, rhsReportedHeight) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsResult == rhsResult, lhsAppearance == rhsAppearance, lhsReportedHeight == rhsReportedHeight {
                    return true
                } else {
                    return false
                }
        }
    }
    
    /// The position of a result entry; nil for the action row, which comes first.
    private var resultIndex: Int? {
        switch self {
        case .action:
            return nil
        case let .result(index, _, _):
            return index
        case let .widgetResult(index, _, _, _, _, _):
            return index
        }
    }
    
    static func <(lhs: VerticalListContextResultsChatInputContextPanelEntry, rhs: VerticalListContextResultsChatInputContextPanelEntry) -> Bool {
        guard let index = lhs.resultIndex else {
            return true
        }
        guard let rhsIndex = rhs.resultIndex else {
            return false
        }
        return index < rhsIndex
    }
    
    func item(engine: TelegramEngine, strings: PresentationStrings, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool, widgetHeightReported: @escaping (String, CGFloat) -> Void) -> ListViewItem {
        switch self {
            case let .action(theme, title):
                return VerticalListContextResultsChatInputPanelButtonItem(theme: theme, title: title, pressed: actionSelected)
            case let .result(_, theme, result):
                return VerticalListContextResultsChatInputPanelItem(engine: engine, theme: theme, result: result, resultSelected: resultSelected)
            case let .widgetResult(_, theme, result, widget, appearance, reportedHeight):
                return VerticalListContextResultsChatInputPanelWidgetItem(theme: theme, strings: strings, result: result, widget: widget, appearance: appearance, reportedHeight: reportedHeight, resultSelected: resultSelected, heightReported: widgetHeightReported)
        }
    }
}

private struct VerticalListContextResultsChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [VerticalListContextResultsChatInputContextPanelEntry], to toEntries: [VerticalListContextResultsChatInputContextPanelEntry], engine: TelegramEngine, strings: PresentationStrings, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool, widgetHeightReported: @escaping (String, CGFloat) -> Void) -> VerticalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)

    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, strings: strings, actionSelected: actionSelected, resultSelected: resultSelected, widgetHeightReported: widgetHeightReported), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(engine: engine, strings: strings, actionSelected: actionSelected, resultSelected: resultSelected, widgetHeightReported: widgetHeightReported), directionHint: nil) }
    
    return VerticalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class VerticalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let backgroundView: GlassBackgroundView
    private let listView: ListView
    private let listMaskView: UIImageView
    private var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [VerticalListContextResultsChatInputContextPanelEntry]?
    
    /// Each with whether it is the first and whether it crossfades the list (a row's new height does not).
    private var enqueuedTransitions: [(VerticalListContextResultsChatInputContextPanelTransition, Bool, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    private let loadMoreDisposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    
    /// widget-sandbox v0.2 (v0.2 W3): how widget results draw, from the chat's interface state once laid out, and the
    /// height each result's widget last reported (by result id), which its row is laid out from.
    private var widgetAppearance: ChatContextResultWidgetAppearance
    private var widgetPreviewHeights: [String: CGFloat] = [:]
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.widgetAppearance = ChatContextResultWidgetAppearance(theme: theme, wallpaper: .builtin(WallpaperSettings()), fontSize: fontSize, cornerRadius: 16.0)
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.layer.anchorPoint = CGPoint()
        
        self.listView = ListViewImpl()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.limitHitTestToNodes = true
        self.listView.isHidden = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listMaskView = UIImageView()
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.view.addSubview(self.backgroundView)
        self.addSubnode(self.listView)
        self.listView.view.mask = self.listMaskView
        
        self.listView.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self, !strongSelf.isLoadingMore, case let .known(value) = offset, value < 40.0 else {
                return
            }
            strongSelf.loadMore()
        }
        
        self.backgroundView.isHidden = true
        self.listView.visibleContentOffsetChanged = { [weak self] offset, _ in
            guard let self else {
                return
            }
            var topOffset: CGFloat = 0.0
            switch offset {
            case let .known(offset):
                topOffset = max(0.0, -offset + self.listView.insets.top)
            case .unknown:
                break
            case .none:
                break
            }
            
            self.backgroundView.isHidden = false
            self.backgroundView.layer.position = CGPoint(x: 0.0, y: topOffset)
        }
    }
    
    deinit {
        self.loadMoreDisposable.dispose()
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
        
    private func updateInternalResults(_ results: ChatContextResultCollection, crossfade: Bool = true) {
        var entries: [VerticalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<VerticalChatContextResultsEntryStableId>()
        // One row: a response that carries both switch_pm and switch_webview still has a single button,
        // and there is only one `.action` stable id for it.
        if let button = ChatContextResultsButton(results: results) {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .action(self.theme, button.title)
            entries.append(entry)
            resultIds.insert(entry.stableId)
        }
        let widgetsEnabled = chatMessageWidgetRenderingEnabled()
        for result in results.results {
            let entry: VerticalListContextResultsChatInputContextPanelEntry
            if let widget = messageWidgetPreviewWidget(result.message, renderingEnabled: widgetsEnabled) {
                entry = .widgetResult(index, self.theme, result, widget, self.widgetAppearance, self.widgetPreviewHeights[result.id])
            } else {
                entry = .result(index, self.theme, result)
            }
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        prepareTransition(from: self.currentEntries, to: entries, results: results, crossfade: crossfade)
    }
    
    private func prepareTransition(from: [VerticalListContextResultsChatInputContextPanelEntry]?, to: [VerticalListContextResultsChatInputContextPanelEntry], results: ChatContextResultCollection, crossfade: Bool = true) {
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: from ?? [], to: to, engine: self.context.engine, strings: self.strings, actionSelected: { [weak self] in
            // Resolved at tap time: an `.action` entry compares only its title, so a later answer with the same
            // button text keeps this closure, and the captured `results` would carry the old payload or bot.
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction, let results = strongSelf.currentProcessedResults {
                ChatContextResultsButton(results: results)?.activate(context: strongSelf.context, interfaceInteraction: interfaceInteraction, botId: results.botId)
            }
        }, resultSelected: { [weak self] result, node, rect in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                strongSelf.listView.clearHighlightAnimated(true)
                return interfaceInteraction.sendContextResult(results, result, node, rect)
            } else {
                return false
            }
        }, widgetHeightReported: { [weak self] resultId, height in
            self?.widgetPreviewHeightReported(resultId: resultId, height: height)
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime, crossfade: crossfade)
    }
    
    private func enqueueTransition(_ transition: VerticalListContextResultsChatInputContextPanelTransition, firstTime: Bool, crossfade: Bool) {
        enqueuedTransitions.append((transition, firstTime, crossfade))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, firstTime, crossfade) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
            } else if crossfade {
                options.insert(.AnimateTopItemPosition)
                options.insert(.AnimateCrossfade)
            } else {
                // One row's new height: a plain re-layout. The top item's position animation would stop the list's
                // scrolling and spring it, and the crossfade snapshots and fades the whole list.
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0, bottomInset: validLayout.3, hasSwitchPeer: self.currentExternalResults.flatMap(ChatContextResultsButton.init(results:)) != nil)
            insets.left = validLayout.1
            insets.right = validLayout.2
            insets.bottom = validLayout.3
            self.updateListVisualInsets(insets)
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listView.bounds.size, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    var topItemOffset: CGFloat?
                    strongSelf.listView.forEachItemNode { itemNode in
                        if topItemOffset == nil {
                            topItemOffset = itemNode.frame.minY
                        }
                    }
                    
                    if let topItemOffset {
                        let offset = strongSelf.listView.bounds.size.height - topItemOffset
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                        transition.animatePositionAdditive(layer: strongSelf.listView.layer, offset: CGPoint(x: 0.0, y: offset))
                        transition.animatePositionAdditive(layer: strongSelf.backgroundView.layer, offset: CGPoint(x: 0.0, y: offset))
                    }
                    strongSelf.listView.isHidden = false
                }
            })
        }
    }
    
    /// A widget result's widget reported a new height: its row lays out again from it.
    private func widgetPreviewHeightReported(resultId: String, height: CGFloat) {
        guard self.widgetPreviewHeights[resultId] != height else {
            return
        }
        self.widgetPreviewHeights[resultId] = height
        if let currentProcessedResults = self.currentProcessedResults {
            // One row's height: no crossfade, which would snapshot and fade the whole list over it.
            self.updateInternalResults(currentProcessedResults, crossfade: false)
        }
    }
    
    /// The list's top inset only places its first result: the rows scroll up into that room and show there, so a row is
    /// visible up to the panel's top and a widget result's preview runs until the row leaves the panel (v0.2 W3). The
    /// bottom inset stays: it holds the input panel and, with it, the keyboard, which hides what is under it.
    private func updateListVisualInsets(_ insets: UIEdgeInsets) {
        self.listView.visualInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: insets.bottom, right: 0.0)
    }
    
    private func topInsetForLayout(size: CGSize, bottomInset: CGFloat, hasSwitchPeer: Bool) -> CGFloat {
        var minimumItemHeights: CGFloat = floor(VerticalListContextResultsChatInputPanelItemNode.itemHeight * 3.5)
        if hasSwitchPeer {
            minimumItemHeights += VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight(style: .regular)
        }
        
        return max(size.height - bottomInset - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        self.backgroundView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 32.0))
        self.backgroundView.update(
            size: self.backgroundView.bounds.size,
            cornerRadius: 20.0,
            isDark: interfaceState.theme.overallDarkAppearance,
            tintColor: .init(kind: .panel),
            transition: ComponentTransition(transition)
        )
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size, bottomInset: bottomInset, hasSwitchPeer: self.currentExternalResults.flatMap(ChatContextResultsButton.init(results:)) != nil)
        insets.left = leftInset
        insets.right = rightInset
        insets.bottom = bottomInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        let listMaskHeight: CGFloat = bottomInset + 1.0
        if self.listMaskView.image?.size.height != listMaskHeight {
            let baseGradientAlpha: CGFloat = 0.65
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.0
            let colors: [UIColor] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return UIColor(white: 0.0, alpha: 0.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 0.0, alpha: 1.0 - baseGradientAlpha * value)
                }
            }
            let locations: [CGFloat] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
            
            self.listMaskView.image = generateGradientImage(
                size: CGSize(width: 8.0, height: listMaskHeight),
                colors: colors,
                locations: locations
            )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
        }
        transition.updateFrame(view: self.listMaskView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.updateListVisualInsets(insets)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        let widgetAppearance = ChatContextResultWidgetAppearance(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper, fontSize: interfaceState.fontSize, cornerRadius: interfaceState.bubbleCorners.mainRadius)
        if self.widgetAppearance != widgetAppearance {
            self.widgetAppearance = widgetAppearance
            self.theme = interfaceState.theme
            if let currentProcessedResults = self.currentProcessedResults {
                self.updateInternalResults(currentProcessedResults)
            }
        } else if self.theme !== interfaceState.theme, let currentProcessedResults = self.currentProcessedResults {
            self.theme = interfaceState.theme
            
            let new = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            prepareTransition(from: self.currentEntries, to: new, results: currentProcessedResults)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        var topItemOffset: CGFloat?
        self.listView.forEachItemNode { itemNode in
            if topItemOffset == nil {
                topItemOffset = itemNode.frame.minY
            }
        }
        
        if let topItemOffset {
            let offset = (self.listView.bounds.size.height - topItemOffset)
            
            let position = self.listView.layer.position
            self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animatePosition(from: self.backgroundView.layer.position, to: CGPoint(x: self.backgroundView.layer.position.x, y: self.backgroundView.layer.position.y + offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        } else {
            completion()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewFrame = self.listView.frame
        return self.listView.hitTest(CGPoint(x: point.x - listViewFrame.minX, y: point.y - listViewFrame.minY), with: event)
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
    
    override var topItemFrame: CGRect? {
        var topItemFrame: CGRect?
        self.listView.forEachItemNode { itemNode in
            if topItemFrame == nil {
                topItemFrame = itemNode.frame
            }
        }
        return topItemFrame
    }
}
