import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

private struct ChatContextResultStableId: Hashable {
    let result: ChatContextResult
    
    var hashValue: Int {
        return result.id.hashValue
    }
    
    static func ==(lhs: ChatContextResultStableId, rhs: ChatContextResultStableId) -> Bool {
        return lhs.result == rhs.result
    }
}

private struct HorizontalListContextResultsChatInputContextPanelEntry: Equatable, Comparable, Identifiable {
    let index: Int
    let result: ChatContextResult
    
    var stableId: ChatContextResultStableId {
        return ChatContextResultStableId(result: self.result)
    }
    
    static func ==(lhs: HorizontalListContextResultsChatInputContextPanelEntry, rhs: HorizontalListContextResultsChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.result == rhs.result
    }
    
    static func <(lhs: HorizontalListContextResultsChatInputContextPanelEntry, rhs: HorizontalListContextResultsChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, resultSelected: @escaping (ChatContextResult) -> Void) -> ListViewItem {
        return HorizontalListContextResultsChatInputPanelItem(account: account, result: self.result, resultSelected: resultSelected)
    }
}

private struct HorizontalListContextResultsChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [HorizontalListContextResultsChatInputContextPanelEntry], to toEntries: [HorizontalListContextResultsChatInputContextPanelEntry], account: Account, resultSelected: @escaping (ChatContextResult) -> Void) -> HorizontalListContextResultsChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, resultSelected: resultSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, resultSelected: resultSelected), directionHint: nil) }
    
    return HorizontalListContextResultsChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class HorizontalListContextResultsChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private let separatorNode: ASDisplayNode
    private var currentResults: ChatContextResultCollection?
    private var currentEntries: [HorizontalListContextResultsChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(HorizontalListContextResultsChatInputContextPanelTransition, Bool)] = []
    private var hasValidLayout = false
    
    override init(account: Account) {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = UIColor(rgb: 0xbdc2c7)
        self.separatorNode.isHidden = true
        
        self.listView = ListView()
        self.listView.isOpaque = true
        self.listView.backgroundColor = .white
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(M_PI / 2.0), 0.0, 0.0, 1.0)
        self.listView.isHidden = true
        
        super.init(account: account)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
        self.addSubnode(self.separatorNode)
    }
    
    func updateResults(_ results: ChatContextResultCollection) {
        self.currentResults = results
        var entries: [HorizontalListContextResultsChatInputContextPanelEntry] = []
        var index = 0
        var resultIds = Set<ChatContextResultStableId>()
        for result in results.results {
            let entry = HorizontalListContextResultsChatInputContextPanelEntry(index: index, result: result)
            if resultIds.contains(entry.stableId) {
                continue
            } else {
                resultIds.insert(entry.stableId)
            }
            entries.append(entry)
            index += 1
        }
        
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, account: self.account, resultSelected: { [weak self] result in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.sendContextResult(results, result)
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
            
            let options = ListViewDeleteAndInsertOptions()
            if firstTime {
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                //options.insert(.AnimateTopItemPosition)
            }
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self, firstTime {
                    let position = strongSelf.listView.position
                    strongSelf.listView.isHidden = false
                    strongSelf.listView.layer.animatePosition(from: CGPoint(x: position.x, y: position.y + strongSelf.listView.bounds.size.width), to: position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    
                    strongSelf.separatorNode.isHidden = false
                    let separatorPosition = strongSelf.separatorNode.layer.position
                    strongSelf.separatorNode.layer.animatePosition(from: CGPoint(x: separatorPosition.x, y: separatorPosition.y + strongSelf.listView.bounds.size.width), to: separatorPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            })
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let listHeight: CGFloat = 105.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - listHeight), size: CGSize(width: size.width, height: UIScreenPixel)))
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: listHeight, height: size.width)
        
        //transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        transition.updatePosition(node: self.listView, position: CGPoint(x: size.width / 2.0, y: size.height - listHeight / 2.0))
        
        let insets = UIEdgeInsets()
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
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: listHeight, height: size.width), insets: insets, duration: duration, curve: listViewCurve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hasValidLayout {
            hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
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
