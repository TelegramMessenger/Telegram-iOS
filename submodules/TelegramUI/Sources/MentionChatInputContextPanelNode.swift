import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import TextFormat
import AccountContext
import LocalizedPeerData
import ItemListUI
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatContextQuery
import ChatInputContextPanelNode
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent

private struct MentionChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let peer: EnginePeer
    let revealed: Bool
    
    var stableId: Int64 {
        return self.peer.id.toInt64()
    }
    
    static func ==(lhs: MentionChatInputContextPanelEntry, rhs: MentionChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.peer == rhs.peer && lhs.revealed == rhs.revealed
    }
    
    static func <(lhs: MentionChatInputContextPanelEntry, rhs: MentionChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, inverted: Bool, setPeerIdRevealed: @escaping (EnginePeer.Id?) -> Void, peerSelected: @escaping (EnginePeer) -> Void, removeRequested: @escaping (EnginePeer.Id) -> Void) -> ListViewItem {
        return MentionChatInputPanelItem(context: context, presentationData: ItemListPresentationData(presentationData), inverted: inverted, peer: self.peer._asPeer(), revealed: self.revealed, setPeerIdRevealed: setPeerIdRevealed, peerSelected: peerSelected, removeRequested: removeRequested)
    }
}

private struct CommandChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [MentionChatInputContextPanelEntry], to toEntries: [MentionChatInputContextPanelEntry], context: AccountContext, presentationData: PresentationData, inverted: Bool, forceUpdate: Bool, setPeerIdRevealed: @escaping (EnginePeer.Id?) -> Void, peerSelected: @escaping (EnginePeer) -> Void, removeRequested: @escaping (EnginePeer.Id) -> Void) -> CommandChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries, allUpdated: forceUpdate)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, inverted: inverted, setPeerIdRevealed: setPeerIdRevealed, peerSelected: peerSelected, removeRequested: removeRequested), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, inverted: inverted, setPeerIdRevealed: setPeerIdRevealed, peerSelected: peerSelected, removeRequested: removeRequested), directionHint: nil) }
    
    return CommandChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

enum MentionChatInputContextPanelMode {
    case input
    case search
}

final class MentionChatInputContextPanelNode: ChatInputContextPanelNode {
    let mode: MentionChatInputContextPanelMode
    
    private let backgroundView: GlassBackgroundView
    private let listView: ListView
    private var currentEntries: [MentionChatInputContextPanelEntry]?
    
    private var currentResults: [EnginePeer] = []
    private var revealedPeerId: EnginePeer.Id?
    
    private var enqueuedTransitions: [(CommandChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, mode: MentionChatInputContextPanelMode, chatPresentationContext: ChatPresentationContext) {
        self.mode = mode
        
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.layer.anchorPoint = CGPoint()
        
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.limitHitTestToNodes = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        
        self.view.addSubview(self.backgroundView)
        self.addSubnode(self.listView)
        
        if mode == .search {
            self.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        }
        
        self.backgroundView.isHidden = true
        self.listView.visibleContentOffsetChanged = { [weak self] offset in
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
    
    func updateResults(_ results: [EnginePeer]) {
        self.currentResults = results
        
        var entries: [MentionChatInputContextPanelEntry] = []
        var index = 0
        var peerIdSet = Set<Int64>()
        for peer in results {
            let peerId = peer.id.toInt64()
            if peerIdSet.contains(peerId) {
                continue
            }
            peerIdSet.insert(peerId)
            entries.append(MentionChatInputContextPanelEntry(index: index, peer: peer, revealed: self.revealedPeerId == peer.id))
            index += 1
        }
        self.updateToEntries(entries: entries, forceUpdate: false)
    }
    
    private func updateToEntries(entries: [MentionChatInputContextPanelEntry], forceUpdate: Bool) {
        let firstTime = self.currentEntries == nil
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let transition = preparedTransition(from: self.currentEntries ?? [], to: entries, context: self.context, presentationData: presentationData, inverted: self.mode == .search, forceUpdate: forceUpdate, setPeerIdRevealed: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.revealedPeerId = peerId
                strongSelf.updateResults(strongSelf.currentResults)
            }
        }, peerSelected: { [weak self] peer in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                switch strongSelf.mode {
                    case .input:
                        interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                            var mentionQueryRange: NSRange?
                            inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                                if type == [.mention] {
                                    mentionQueryRange = range
                                    break inner
                                }
                            }
                            
                            if let range = mentionQueryRange {
                                let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                                
                                if let addressName = peer.addressName, !addressName.isEmpty {
                                    let replacementText = addressName + " "
                                    
                                    inputText.replaceCharacters(in: range, with: replacementText)
                                    
                                    let selectionPosition = range.lowerBound + (replacementText as NSString).length
                                    
                                    return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                                } else if !peer.compactDisplayTitle.isEmpty {
                                    let replacementText = NSMutableAttributedString()
                                    replacementText.append(NSAttributedString(string: peer.compactDisplayTitle, attributes: [ChatTextInputAttributes.textMention: ChatTextInputTextMentionAttribute(peerId: peer.id)]))
                                    replacementText.append(NSAttributedString(string: " "))
                                    
                                    let updatedRange = NSRange(location: range.location - 1, length: range.length + 1)
                                    
                                    inputText.replaceCharacters(in: updatedRange, with: replacementText)
                                    
                                    let selectionPosition = updatedRange.lowerBound + replacementText.length
                                    
                                    return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                                }
                            }
                            return (textInputState, inputMode)
                        }
                    case .search:
                        interfaceInteraction.beginMessageSearch(.member(peer._asPeer()), "")
                }
            }
        }, removeRequested: { [weak self] peerId in
            if let strongSelf = self {
                let _ = strongSelf.context.engine.peers.removeRecentlyUsedInlineBot(peerId: peerId).startStandalone()
                
                strongSelf.revealedPeerId = nil
                strongSelf.currentResults = strongSelf.currentResults.filter { $0.id != peerId }
                strongSelf.updateResults(strongSelf.currentResults)
            }
        })
        self.currentEntries = entries
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: CommandChatInputContextPanelTransition, firstTime: Bool) {
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
                //options.insert(.Synchronous)
                //options.insert(.LowLatency)
            } else {
                options.insert(.AnimateTopItemPosition)
                options.insert(.AnimateCrossfade)
            }
            
            var insets = UIEdgeInsets()
            insets.top = topInsetForLayout(size: validLayout.0, bottomInset: validLayout.3)
            insets.left = validLayout.1
            insets.right = validLayout.2
            insets.bottom = validLayout.3
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: validLayout.0, insets: insets, duration: 0.0, curve: .Default(duration: nil))
            
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
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize, bottomInset: CGFloat) -> CGFloat {
        let minimumItemHeights: CGFloat = floor(MentionChatInputPanelItemNode.itemHeight * 3.5)
        
        return max(size.height - bottomInset - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme
            
            if let currentEntries = self.currentEntries {
                self.updateToEntries(entries: currentEntries, forceUpdate: true)
            }
        }
        
        transition.updateBounds(layer: self.backgroundView.layer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 32.0)))
        self.backgroundView.update(
            size: self.backgroundView.bounds.size,
            cornerRadius: 20.0,
            isDark: interfaceState.theme.overallDarkAppearance,
            tintColor: .init(kind: .panel, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)),
            transition: ComponentTransition(transition)
        )
        
        var insets = UIEdgeInsets()
        insets.top = topInsetForLayout(size: size, bottomInset: bottomInset)
        insets.left = leftInset
        insets.right = rightInset
        insets.bottom = bottomInset
        
        transition.updateFrame(node: self.listView, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: duration, curve: curve, customAnimationTransition: nil)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
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
        
        if let topItemOffset {
            let offset = (self.listView.bounds.size.height - topItemOffset)
            
            self.listView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
        } else {
            completion()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let listViewFrame = self.listView.frame
        return self.listView.hitTest(CGPoint(x: point.x - listViewFrame.minX, y: point.y - listViewFrame.minY), with: event)
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
