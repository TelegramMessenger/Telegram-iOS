import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

private struct StickersChatInputContextPanelEntryStableId: Hashable {
    let text: String
    
    var hashValue: Int {
        return self.text.hashValue
    }
    
    static func ==(lhs: StickersChatInputContextPanelEntryStableId, rhs: StickersChatInputContextPanelEntryStableId) -> Bool {
        return lhs.text == rhs.text
    }
}

private struct StickersChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let theme: PresentationTheme
    let text: String
    
    var stableId: StickersChatInputContextPanelEntryStableId {
        return StickersChatInputContextPanelEntryStableId(text: self.text)
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> StickersChatInputContextPanelEntry {
        return StickersChatInputContextPanelEntry(index: self.index, theme: theme, text: self.text)
    }
    
    static func ==(lhs: StickersChatInputContextPanelEntry, rhs: StickersChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.text == rhs.text && lhs.theme === rhs.theme
    }
    
    static func <(lhs: StickersChatInputContextPanelEntry, rhs: StickersChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, hashtagSelected: @escaping (String) -> Void) -> ListViewItem {
        return StickersChatInputPanelItem(theme: self.theme, text: self.text, hashtagSelected: hashtagSelected)
    }
}

private struct StickersChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [StickersChatInputContextPanelEntry], to toEntries: [StickersChatInputContextPanelEntry], account: Account, hashtagSelected: @escaping (String) -> Void) -> StickersChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, hashtagSelected: hashtagSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, hashtagSelected: hashtagSelected), directionHint: nil) }
    
    return StickersChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class StickersChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private var currentEntries: [StickersChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(StickersChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = theme.list.plainBackgroundColor
        self.listView.limitHitTestToNodes = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        
        super.init(context: context, theme: theme, strings: strings)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
    }
    
    func updateResults(_ results: [String]) {
        var entries: [StickersChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<StickersChatInputContextPanelEntryStableId>()
        for text in results {
            let entry = StickersChatInputContextPanelEntry(index: index, theme: self.theme, text: text)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries ?? [], to: entries)
    }
    
    private func prepareTransition(from: [StickersChatInputContextPanelEntry]? , to: [StickersChatInputContextPanelEntry]) {
        let firstTime = from == nil
        let transition = preparedTransition(from: from ?? [], to: to, account: self.context.account, hashtagSelected: { [weak self] text in
          
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: StickersChatInputContextPanelTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
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
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                options.insert(.AnimateTopItemPosition)
                options.insert(.AnimateCrossfade)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0)
            insets.left = validLayout.1
            insets.right = validLayout.2
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: validLayout.0, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
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
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize) -> CGFloat {
        let minimumItemHeights: CGFloat = floor(MentionChatInputPanelItemNode.itemHeight * 3.5)
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset)
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size)
        insets.left = leftInset
        insets.right = rightInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
        case .immediate:
            break
        case let .animated(animationDuration, animationCurve):
            duration = animationDuration
            switch animationCurve {
                case .easeInOut, .custom:
                    break
                case .spring:
                    curve = 7
            }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            self.listView.keepBottomItemOverscrollBackground = self.theme.list.plainBackgroundColor
            
            let new = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            self.prepareTransition(from: self.currentEntries, to: new)
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

