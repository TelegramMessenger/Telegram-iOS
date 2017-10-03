import Foundation
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display

private struct CommandChatInputContextPanelEntryStableId: Hashable {
    let command: PeerCommand
    
    var hashValue: Int {
        return command.command.text.hashValue ^ command.peer.id.hashValue
    }
    
    static func ==(lhs: CommandChatInputContextPanelEntryStableId, rhs: CommandChatInputContextPanelEntryStableId) -> Bool {
        return lhs.command == rhs.command
    }
}

private struct CommandChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let command: PeerCommand
    
    var stableId: CommandChatInputContextPanelEntryStableId {
        return CommandChatInputContextPanelEntryStableId(command: self.command)
    }
    
    static func ==(lhs: CommandChatInputContextPanelEntry, rhs: CommandChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.command == rhs.command
    }
    
    static func <(lhs: CommandChatInputContextPanelEntry, rhs: CommandChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, commandSelected: @escaping (PeerCommand, Bool) -> Void) -> ListViewItem {
        return CommandChatInputPanelItem(account: account, command: self.command, commandSelected: commandSelected)
    }
}

private struct CommandChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [CommandChatInputContextPanelEntry], to toEntries: [CommandChatInputContextPanelEntry], account: Account, commandSelected: @escaping (PeerCommand, Bool) -> Void) -> CommandChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, commandSelected: commandSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, commandSelected: commandSelected), directionHint: nil) }
    
    return CommandChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class CommandChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private var currentEntries: [CommandChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(CommandChatInputContextPanelTransition, Bool)] = []
    private var hasValidLayout = false
    
    override init(account: Account) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = .white
        self.listView.limitHitTestToNodes = true
        
        super.init(account: account)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
    }
    
    func updateResults(_ results: [PeerCommand]) {
        var entries: [CommandChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<CommandChatInputContextPanelEntryStableId>()
        for command in results {
            let entry = CommandChatInputContextPanelEntry(index: index, command: command)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, account: self.account, commandSelected: { [weak self] command, sendImmediately in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                if sendImmediately {
                    interfaceInteraction.sendBotCommand(command.peer, "/" + command.command.text)
                } else {
                    interfaceInteraction.updateTextInputState { textInputState in
                        if let (range, type, _) = textInputStateContextQueryRangeAndType(textInputState) {
                            var inputText = textInputState.inputText
                        
                            let replacementText = command.command.text + " "
                            inputText.replaceSubrange(range, with: replacementText)
                            
                            guard let lowerBound = range.lowerBound.samePosition(in: inputText.utf16) else {
                                return textInputState
                            }
                            let utfLowerIndex = inputText.utf16.distance(from: inputText.utf16.startIndex, to: lowerBound)
                            
                            let replacementLength = replacementText.utf16.distance(from: replacementText.utf16.startIndex, to: replacementText.utf16.endIndex)
                            
                            let utfUpperPosition = utfLowerIndex + replacementLength
                            
                            return ChatTextInputState(inputText: inputText, selectionRange: utfUpperPosition ..< utfUpperPosition)
                        }
                        return textInputState
                    }
                }
            }
        })
        self.currentEntries = entries
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: CommandChatInputContextPanelTransition, firstTime: Bool) {
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
                options.insert(.AnimateCrossfade)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: self.listView.bounds.size)
            
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
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize) -> CGFloat {
        var minimumItemHeights: CGFloat = floor(MentionChatInputPanelItemNode.itemHeight * 3.5)
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size)
        
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
