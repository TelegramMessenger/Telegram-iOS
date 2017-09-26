import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

private enum VerticalChatContextResultsEntryStableId: Hashable {
    case action
    case result(ChatContextResult)
    
    var hashValue: Int {
        switch self {
            case .action:
                return 0
            case let .result(result):
                return result.id.hashValue
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
    case action(String)
    case result(Int, ChatContextResult)
    
    var stableId: VerticalChatContextResultsEntryStableId {
        switch self {
            case .action:
                return .action
            case let .result(_, result):
                return .result(result)
        }
    }
    
    static func ==(lhs: VerticalListContextResultsChatInputContextPanelEntry, rhs: VerticalListContextResultsChatInputContextPanelEntry) -> Bool {
        switch lhs {
            case let .action(title):
                if case .action(title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .result(index, result):
                if case .result(index, result) = rhs {
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
            case let .result(index, _):
                switch rhs {
                    case .action:
                        return false
                    case let .result(rhsIndex, _):
                        return index < rhsIndex
                }
        }
    }
    
    func item(account: Account, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult) -> Void) -> ListViewItem {
        switch self {
            case let .action(title):
                return VerticalListContextResultsChatInputPanelButtonItem(title: title, pressed: actionSelected)
            case let .result(_, result):
                return VerticalListContextResultsChatInputPanelItem(account: account, result: result, resultSelected: resultSelected)
        }
    }
}

private struct VerticalListContextResultsChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [VerticalListContextResultsChatInputContextPanelEntry], to toEntries: [VerticalListContextResultsChatInputContextPanelEntry], account: Account, actionSelected: @escaping () -> Void, resultSelected: @escaping (ChatContextResult) -> Void) -> VerticalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, actionSelected: actionSelected, resultSelected: resultSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, actionSelected: actionSelected, resultSelected: resultSelected), directionHint: nil) }
    
    return VerticalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class VerticalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private var currentResults: ChatContextResultCollection?
    private var currentEntries: [VerticalListContextResultsChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(VerticalListContextResultsChatInputContextPanelTransition, Bool)] = []
    private var hasValidLayout = false
    
    override init(account: Account) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = .white
        self.listView.limitHitTestToNodes = true
        self.listView.isHidden = true
        
        super.init(account: account)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
    }
    
    func updateResults(_ results: ChatContextResultCollection) {
        self.currentResults = results
        var entries: [VerticalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<VerticalChatContextResultsEntryStableId>()
        if let switchPeer = results.switchPeer {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .action(switchPeer.text)
            entries.append(entry)
            resultIds.insert(entry.stableId)
        }
        for result in results.results {
            let entry: VerticalListContextResultsChatInputContextPanelEntry = .result(index, result)
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, account: self.account, actionSelected: { [weak self] in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction, let switchPeer = results.switchPeer {
                interfaceInteraction.botSwitchChatWithPayload(results.botId, switchPeer.startParam)
            }
        }, resultSelected: { [weak self] result in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.sendContextResult(results, result)
            }
        })
        self.currentEntries = entries
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: VerticalListContextResultsChatInputContextPanelTransition, firstTime: Bool) {
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
            if firstTime {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                options.insert(.AnimateTopItemPosition)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: self.listView.bounds.size, hasSwitchPeer: self.currentResults?.switchPeer != nil)
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: self.listView.bounds.size, insets: insets, duration: 0.0, curve: .Default)
            
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
                        strongSelf.listView.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + (strongSelf.listView.bounds.size.height - topItemOffset)), to: position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size, hasSwitchPeer: self.currentResults?.switchPeer != nil)
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                case .easeInOut:
                    break
                case .spring:
                    curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
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
}
