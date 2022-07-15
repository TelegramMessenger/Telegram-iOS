import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SwiftSignalKit
import ChatPresentationInterfaceState

private enum VerticalChatContextResultsEntryStableId: Hashable {
    case action
    case result(ChatContextResult)
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .action:
                hasher.combine(0)
            case let .result(result):
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
        }
    }
}

private enum VerticalListContextResultsChatInputContextPanelEntry: Comparable, Identifiable {
    case action(PresentationTheme, String)
    case result(Int, PresentationTheme, ChatContextResult)
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> VerticalListContextResultsChatInputContextPanelEntry {
        switch self {
        case let .action(_, value):
            return .action(theme, value)
        case let .result(index, _, result):
            return .result(index, theme, result)
        }
    }
    
    var stableId: VerticalChatContextResultsEntryStableId {
        switch self {
            case .action:
                return .action
            case let .result(_, _, result):
                return .result(result)
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
        }
    }
    
    static func <(lhs: VerticalListContextResultsChatInputContextPanelEntry, rhs: VerticalListContextResultsChatInputContextPanelEntry) -> Bool {
        switch lhs {
            case .action:
                return true
            case let .result(index, _, _):
                switch rhs {
                    case .action:
                        return false
                    case let .result(rhsIndex, _, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(account: Account, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> ListViewItem {
        switch self {
            case let .action(theme, title):
                return VerticalListContextResultsChatInputPanelButtonItem(theme: theme, title: title, pressed: actionSelected)
            case let .result(_, theme, result):
                return VerticalListContextResultsChatInputPanelItem(account: account, theme: theme, result: result, resultSelected: resultSelected)
        }
    }
}

private struct VerticalListContextResultsChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [VerticalListContextResultsChatInputContextPanelEntry], to toEntries: [VerticalListContextResultsChatInputContextPanelEntry], account: Account, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult, ASDisplayNode, CGRect) -> Bool) -> VerticalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, actionSelected: actionSelected, resultSelected: resultSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, actionSelected: actionSelected, resultSelected: resultSelected), directionHint: nil) }
    
    return VerticalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class VerticalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private var currentExternalResults: ChatContextResultCollection?
    private var currentProcessedResults: ChatContextResultCollection?
    private var currentEntries: [VerticalListContextResultsChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(VerticalListContextResultsChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    private let loadMoreDisposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = theme.list.plainBackgroundColor
        self.listView.limitHitTestToNodes = true
        self.listView.isHidden = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
        
        self.listView.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self, !strongSelf.isLoadingMore, case let .known(value) = offset, value < 40.0 else {
                return
            }
            strongSelf.loadMore()
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
        
    private func updateInternalResults(_ results: ChatContextResultCollection) {
        var entries: [VerticalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<VerticalChatContextResultsEntryStableId>()
        if let switchPeer = results.switchPeer {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .action(self.theme, switchPeer.text)
            entries.append(entry)
            resultIds.insert(entry.stableId)
        }
        for result in results.results {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .result(index, self.theme, result)
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        prepareTransition(from: self.currentEntries, to: entries, results: results)
    }
    
    private func prepareTransition(from: [VerticalListContextResultsChatInputContextPanelEntry]?, to: [VerticalListContextResultsChatInputContextPanelEntry], results: ChatContextResultCollection) {
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: from ?? [], to: to, account: self.context.account, actionSelected: { [weak self] in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction, let switchPeer = results.switchPeer {
                interfaceInteraction.botSwitchChatWithPayload(results.botId, switchPeer.startParam)
            }
        }, resultSelected: { [weak self] result, node, rect in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                strongSelf.listView.clearHighlightAnimated(true)
                return interfaceInteraction.sendContextResult(results, result, node, rect)
            } else {
                return false
            }
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: VerticalListContextResultsChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            if firstTime {
            } else {
                options.insert(.AnimateTopItemPosition)
                options.insert(.AnimateCrossfade)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0, hasSwitchPeer: self.currentExternalResults?.switchPeer != nil)
            insets.left = validLayout.1
            insets.right = validLayout.2
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listView.bounds.size, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    var topItemOffset: CGFloat?
                    strongSelf.listView.forEachItemNode { itemNode in
                        if topItemOffset == nil {
                            topItemOffset = itemNode.frame.minY
                        }
                    }
                    
                    if let topItemOffset = topItemOffset {
                        let position = strongSelf.listView.layer.position
                        strongSelf.listView.position = CGPoint(x: position.x, y: position.y + (strongSelf.listView.bounds.size.height - topItemOffset))
                        ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring).animateView {
                            strongSelf.listView.position = position
                        }
                    }
                    
                    strongSelf.listView.isHidden = false
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize, hasSwitchPeer: Bool) -> CGFloat {
        var minimumItemHeights: CGFloat = floor(VerticalListContextResultsChatInputPanelItemNode.itemHeight * 3.5)
        if hasSwitchPeer {
            minimumItemHeights += VerticalListContextResultsChatInputPanelButtonItemNode.itemHeight
        }
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size, hasSwitchPeer: self.currentExternalResults?.switchPeer != nil)
        insets.left = leftInset
        insets.right = rightInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        if self.theme !== interfaceState.theme, let currentProcessedResults = self.currentProcessedResults {
            self.theme = interfaceState.theme
            self.listView.keepBottomItemOverscrollBackground = self.theme.list.plainBackgroundColor
            
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
        
        if let topItemOffset = topItemOffset {
            let position = self.listView.layer.position
            self.listView.layer.animatePosition(from: position, to: CGPoint(x: position.x, y: position.y + (self.listView.bounds.size.height - topItemOffset)), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
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
