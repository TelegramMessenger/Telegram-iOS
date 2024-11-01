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
import AccountContext
import ItemListUI
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatContextQuery
import ChatInputContextPanelNode

private enum HashtagChatInputContextPanelEntryStableId: Hashable {
    case generic
    case peer
    case hashtag(String)
}

private struct HashtagChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let theme: PresentationTheme
    let peer: EnginePeer?
    let title: String
    let text: String?
    let badge: String?
    let hashtag: String
    let revealed: Bool
    let isAdditionalRecent: Bool
    
    var stableId: HashtagChatInputContextPanelEntryStableId {
        switch self.index {
        case 0:
            return .generic
        case 1:
            return .peer
        default:
            return .hashtag(self.title)
        }
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> HashtagChatInputContextPanelEntry {
        return HashtagChatInputContextPanelEntry(index: self.index, theme: theme, peer: peer, title: self.title, text: self.text, badge: self.badge, hashtag: self.hashtag, revealed: self.revealed, isAdditionalRecent: self.isAdditionalRecent)
    }
    
    static func ==(lhs: HashtagChatInputContextPanelEntry, rhs: HashtagChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.peer == rhs.peer && lhs.title == rhs.title && lhs.text == rhs.text && lhs.badge == rhs.badge && lhs.hashtag == rhs.hashtag && lhs.theme === rhs.theme && lhs.revealed == rhs.revealed && lhs.isAdditionalRecent == rhs.isAdditionalRecent
    }
    
    static func <(lhs: HashtagChatInputContextPanelEntry, rhs: HashtagChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, presentationData: PresentationData, setHashtagRevealed: @escaping (String?) -> Void, hashtagSelected: @escaping (String) -> Void, removeRequested: @escaping (String) -> Void) -> ListViewItem {
        return HashtagChatInputPanelItem(context: context, presentationData: ItemListPresentationData(presentationData), peer: self.peer, title: self.title, text: self.text, badge: self.badge, hashtag: self.hashtag, revealed: self.revealed, isAdditionalRecent: self.isAdditionalRecent, setHashtagRevealed: setHashtagRevealed, hashtagSelected: hashtagSelected, removeRequested: removeRequested)
    }
}

private struct HashtagChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [HashtagChatInputContextPanelEntry], to toEntries: [HashtagChatInputContextPanelEntry], context: AccountContext, presentationData: PresentationData, setHashtagRevealed: @escaping (String?) -> Void, hashtagSelected: @escaping (String) -> Void, removeRequested: @escaping (String) -> Void) -> HashtagChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, setHashtagRevealed: setHashtagRevealed, hashtagSelected: hashtagSelected, removeRequested: removeRequested), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, setHashtagRevealed: setHashtagRevealed, hashtagSelected: hashtagSelected, removeRequested: removeRequested), directionHint: nil) }
    
    return HashtagChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class HashtagChatInputContextPanelNode: ChatInputContextPanelNode {
    private let listView: ListView
    private var currentEntries: [HashtagChatInputContextPanelEntry]?
    
    private var currentResults: [String] = []
    private var currentQuery: String = ""
    private var currentPeer: EnginePeer?
    private var revealedHashtag: String?
    
    private var enqueuedTransitions: [(HashtagChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.stackFromBottom = true
        self.listView.keepBottomItemOverscrollBackground = theme.list.plainBackgroundColor
        self.listView.limitHitTestToNodes = true
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.isOpaque = false
        self.clipsToBounds = true
        
        self.addSubnode(self.listView)
    }
    
    func updateResults(_ results: [String], query: String, peer: EnginePeer?) {
        self.currentResults = results
        self.currentQuery = query
        self.currentPeer = peer
        
        var entries: [HashtagChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<HashtagChatInputContextPanelEntryStableId>()
        
        var isAdditionalRecent = false
        if let peer, let _ = peer.addressName {
            isAdditionalRecent = true
        }
        if query.count >= 4 {
            if let peer, let addressName = peer.addressName {
                let genericEntry = HashtagChatInputContextPanelEntry(
                    index: 0,
                    theme: self.theme,
                    peer: nil,
                    title: self.strings.Chat_HashtagSuggestion_UseGeneric_Title("#\(query)").string,
                    text: self.strings.Chat_HashtagSuggestion_UseGeneric_Text,
                    badge: nil,
                    hashtag: query,
                    revealed: false,
                    isAdditionalRecent: false
                )
                stableIds.insert(genericEntry.stableId)
                entries.append(genericEntry)
                
                var isGroup = false
                if case let .channel(channel) = peer, case .group = channel.info {
                    isGroup = true
                }
                let peerEntry = HashtagChatInputContextPanelEntry(
                    index: 1,
                    theme: self.theme,
                    peer: peer,
                    title: self.strings.Chat_HashtagSuggestion_UseLocal_Title("#\(query)@\(addressName)").string,
                    text: isGroup ? self.strings.Chat_HashtagSuggestion_UseLocal_Group_Text : self.strings.Chat_HashtagSuggestion_UseLocal_Channel_Text,
                    badge: self.strings.ChatList_ContextMenuBadgeNew,
                    hashtag: "\(query)@\(addressName)",
                    revealed: false,
                    isAdditionalRecent: false
                )
                stableIds.insert(peerEntry.stableId)
                entries.append(peerEntry)
            }
        }
        
        index = 2
        
        for hashtag in results {
            if hashtag == query {
                continue
            }
            if !hashtag.hasPrefix(query) {
                continue
            }
            let entry = HashtagChatInputContextPanelEntry(
                index: index,
                theme: self.theme,
                peer: hashtag.contains("@") ? peer : nil,
                title: "#\(hashtag)",
                text: nil,
                badge: nil,
                hashtag: hashtag,
                revealed: hashtag == self.revealedHashtag,
                isAdditionalRecent: isAdditionalRecent && !hashtag.contains("@")
            )
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries, to: entries)
    }
    
    private func prepareTransition(from: [HashtagChatInputContextPanelEntry]? , to: [HashtagChatInputContextPanelEntry]) {
        let firstTime = from == nil
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let transition = preparedTransition(from: from ?? [], to: to, context: self.context, presentationData: presentationData, setHashtagRevealed: { [weak self] text in
            if let strongSelf = self {
                strongSelf.revealedHashtag = text
                strongSelf.updateResults(strongSelf.currentResults, query: strongSelf.currentQuery, peer: strongSelf.currentPeer)
            }
        }, hashtagSelected: { [weak self] text in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                    var hashtagQueryRange: NSRange?
                    inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                        if type == [.hashtag] {
                            hashtagQueryRange = range
                            break inner
                        }
                    }
                    
                    if let range = hashtagQueryRange {
                        let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                        
                        let replacementText = text
                        inputText.replaceCharacters(in: range, with: replacementText)
                        
                        let selectionPosition = range.lowerBound + (replacementText as NSString).length
                        
                        return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                    }
                    return (textInputState, inputMode)
                }
            }
        }, removeRequested: { [weak self] text in
            if let strongSelf = self {
                let _ = strongSelf.context.engine.messages.removeRecentlyUsedHashtag(string: text).startStandalone()
                strongSelf.revealedHashtag = nil
            }
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
    }
    
    private func enqueueTransition(_ transition: HashtagChatInputContextPanelTransition, firstTime: Bool) {
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
                if transition.insertions.isEmpty && transition.deletions.isEmpty && transition.updates.count <= 2 {
                    options.insert(.AnimateInsertion)
                } else {
                    options.insert(.AnimateCrossfade)
                }
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
                        strongSelf.listView.position = CGPoint(x: position.x, y: position.y + (strongSelf.listView.bounds.size.height - topItemOffset))
                        ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring).animateView {
                            strongSelf.listView.position = position
                        }
                    }
                }
            })
        }
    }
    
    private func topInsetForLayout(size: CGSize) -> CGFloat {
        let minimumItemHeights: CGFloat = floor(MentionChatInputPanelItemNode.itemHeight * 3.5)
        
        return max(size.height - minimumItemHeights, 0.0)
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        
        var insets = UIEdgeInsets()
        insets.top = self.topInsetForLayout(size: size)
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
