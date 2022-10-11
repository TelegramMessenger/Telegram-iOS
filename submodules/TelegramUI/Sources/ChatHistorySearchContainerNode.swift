import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MergeLists
import AccountContext
import SearchUI
import TelegramUIPreferences
import ListMessageItem

private enum ChatHistorySearchEntryStableId: Hashable {
    case messageId(MessageId)
}

private enum ChatHistorySearchEntry: Comparable, Identifiable {
    case message(Message, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationFontSize)
    
    var stableId: ChatHistorySearchEntryStableId {
        switch self {
            case let .message(message, _, _, _, _):
                return .messageId(message.id)
        }
    }
    
    static func ==(lhs: ChatHistorySearchEntry, rhs: ChatHistorySearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsFontSize):
                if case let .message(rhsMessage, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsFontSize) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsFontSize != rhsFontSize {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatHistorySearchEntry, rhs: ChatHistorySearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, _, _, _, _):
                if case let .message(rhsMessage, _, _, _, _) = rhs {
                    return lhsMessage.index < rhsMessage.index
                } else {
                    return false
                }
        }
    }
    
    func item(context: AccountContext, peerId: PeerId, interaction: ChatControllerInteraction) -> ListViewItem {
        switch self {
            case let .message(message, theme, strings, dateTimeFormat, fontSize):
            return ListMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: .builtin(WallpaperSettings())), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, disableAnimations: false, largeEmoji: false, chatBubbleCorners: PresentationChatBubbleCorners(mainRadius: 0.0, auxiliaryRadius: 0.0, mergeBubbleCorners: false)), context: context, chatLocation: .peer(id: peerId), interaction: ListMessageItemInteraction(controllerInteraction: interaction), message: message, selection: .none, displayHeader: true)
        }
    }
}

private struct ChatHistorySearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let query: String
    let displayingResults: Bool
}

private func chatHistorySearchContainerPreparedTransition(from fromEntries: [ChatHistorySearchEntry], to toEntries: [ChatHistorySearchEntry], query: String, displayingResults: Bool, context: AccountContext, peerId: PeerId, interaction: ChatControllerInteraction) -> ChatHistorySearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, peerId: peerId, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, peerId: peerId, interaction: interaction), directionHint: nil) }
    
    return ChatHistorySearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, query: query, displayingResults: displayingResults)
}

final class ChatHistorySearchContainerNode: SearchDisplayControllerContentNode {
    private let context: AccountContext
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private let emptyResultsTitleNode: ImmediateTextNode
    private let emptyResultsTextNode: ImmediateTextNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var currentEntries: [ChatHistorySearchEntry]?
    var currentMessages: [MessageId: Message]?
    
    private var currentQuery: String?
    private let searchQuery = Promise<String?>()
    private let searchQueryDisposable = MetaDisposable()
    private let searchDisposable = MetaDisposable()
    
    private let _isSearching = ValuePromise<Bool>(false, ignoreRepeated: true)
    override var isSearching: Signal<Bool, NoError> {
        return self._isSearching.get()
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationFontSize)>
    
    private var enqueuedTransitions: [(ChatHistorySearchContainerTransition, Bool)] = []
    
    public override var hasDim: Bool {
        return true
    }
    
    init(context: AccountContext, peerId: PeerId, threadId: Int64?, tagMask: MessageTags, interfaceInteraction: ChatControllerInteraction) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings, self.presentationData.dateTimeFormat, self.presentationData.listsFontSize))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.emptyResultsTitleNode = ImmediateTextNode()
        self.emptyResultsTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.SharedMedia_SearchNoResults, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.freeTextColor)
        self.emptyResultsTitleNode.textAlignment = .center
        self.emptyResultsTitleNode.isHidden = true
        
        self.emptyResultsTextNode = ImmediateTextNode()
        self.emptyResultsTextNode.maximumNumberOfLines = 0
        self.emptyResultsTextNode.textAlignment = .center
        self.emptyResultsTextNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.addSubnode(self.emptyResultsTitleNode)
        self.addSubnode(self.emptyResultsTextNode)
        
        self.listNode.isHidden = true
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let previousEntriesValue = Atomic<[ChatHistorySearchEntry]?>(value: nil)
        
        self.searchQueryDisposable.set((self.searchQuery.get()
        |> deliverOnMainQueue).start(next: { [weak self] query in
            if let strongSelf = self {
                let signal: Signal<([ChatHistorySearchEntry], [MessageId: Message])?, NoError>
                if let query = query, !query.isEmpty {
                    let foundRemoteMessages: Signal<[Message], NoError> = context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: tagMask, topMsgId: threadId.flatMap { makeThreadIdMessageId(peerId: peerId, threadId: $0) }, minDate: nil, maxDate: nil), query: query, state: nil)
                    |> map { $0.0.messages }
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    
                    signal = combineLatest(foundRemoteMessages, themeAndStringsPromise.get())
                    |> map { messages, themeAndStrings -> ([ChatHistorySearchEntry], [MessageId: Message])? in
                        if messages.isEmpty {
                            return ([], [:])
                        } else {
                            return (messages.map { message -> ChatHistorySearchEntry in
                                return .message(message, themeAndStrings.0, themeAndStrings.1, themeAndStrings.2, themeAndStrings.3)
                            }, Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { lhs, _ in lhs }))
                        }
                    }
                    
                    strongSelf._isSearching.set(true)
                } else {
                    signal = .single(nil)
                    strongSelf._isSearching.set(false)
                }
                
                strongSelf.searchDisposable.set((signal
                |> deliverOnMainQueue).start(next: { entriesAndMessages in
                    if let strongSelf = self {
                        let previousEntries = previousEntriesValue.swap(entriesAndMessages?.0)
                        
                        let firstTime = previousEntries == nil
                        let transition = chatHistorySearchContainerPreparedTransition(from: previousEntries ?? [], to: entriesAndMessages?.0 ?? [], query: query ?? "", displayingResults: entriesAndMessages?.0 != nil, context: context, peerId: peerId, interaction: interfaceInteraction)
                        strongSelf.currentEntries = entriesAndMessages?.0
                        strongSelf.currentMessages = entriesAndMessages?.1
                        strongSelf.enqueueTransition(transition, firstTime: firstTime)
                        strongSelf._isSearching.set(false)
                    }
                }))
            }
        }))
        
        self.listNode.beganInteractiveDragging = { [weak self] _ in
            self?.dismissInput?()
        }
        
        self.presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.listsFontSize)))
                
                strongSelf.emptyResultsTitleNode.attributedText = NSAttributedString(string: presentationData.strings.SharedMedia_SearchNoResults, font: Font.semibold(17.0), textColor: presentationData.theme.list.freeTextColor, paragraphAlignment: .center)
                
                if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                }
            }
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.searchQueryDisposable.dispose()
        self.searchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstValidLayout = self.containerLayout == nil
        self.containerLayout = (layout, navigationBarHeight)
        
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        let padding: CGFloat = 16.0
        let emptyTitleSize = self.emptyResultsTitleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let emptyTextSize = self.emptyResultsTextNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        let insets = layout.insets(options: [.input])
        let emptyTextSpacing: CGFloat = 8.0
        let emptyTotalHeight = emptyTitleSize.height + emptyTextSize.height + emptyTextSpacing
        let emptyTitleY = navigationBarHeight + floorToScreenPixels((layout.size.height - navigationBarHeight - max(insets.bottom, layout.intrinsicInsets.bottom) - emptyTotalHeight) / 2.0)
        
        transition.updateFrame(node: self.emptyResultsTitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTitleSize.width) / 2.0, y: emptyTitleY), size: emptyTitleSize))
        transition.updateFrame(node: self.emptyResultsTextNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + padding + (layout.size.width - layout.safeInsets.left - layout.safeInsets.right - padding * 2.0 - emptyTextSize.width) / 2.0, y: emptyTitleY + emptyTitleSize.height + emptyTextSpacing), size: emptyTextSize))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom, right: layout.safeInsets.right), duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        
        if firstValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: ChatHistorySearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.containerLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, firstTime) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            if firstTime {
            } else {
            }
            
            let displayingResults = transition.displayingResults
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if displayingResults != !strongSelf.listNode.isHidden || strongSelf.currentQuery != transition.query {
                        strongSelf.currentQuery = transition.query
                        
                        strongSelf.listNode.isHidden = !displayingResults
                        strongSelf.dimNode.isHidden = displayingResults
                        strongSelf.backgroundColor = displayingResults ? strongSelf.presentationData.theme.list.plainBackgroundColor : nil
                        
                        strongSelf.emptyResultsTextNode.attributedText = NSAttributedString(string: strongSelf.presentationData.strings.SharedMedia_SearchNoResultsDescription(transition.query).string, font: Font.regular(15.0), textColor: strongSelf.presentationData.theme.list.freeTextColor)
                        
                        let emptyResults = displayingResults && strongSelf.currentEntries?.isEmpty ?? false
                        strongSelf.emptyResultsTitleNode.isHidden = !emptyResults
                        strongSelf.emptyResultsTextNode.isHidden = !emptyResults
                        
                        if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    }
                }
            })
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func messageForGallery(_ id: MessageId) -> Message? {
        if let currentEntries = self.currentEntries {
            for entry in currentEntries {
                switch entry {
                case let .message(message, _, _, _, _):
                    if message.id == id {
                        return message
                    }
                }
            }
        }
        return nil
    }
    
    func updateHiddenMedia() {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? GridMessageItemNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            } else if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            } else if let itemNode = itemNode as? GridMessageItemNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
}

