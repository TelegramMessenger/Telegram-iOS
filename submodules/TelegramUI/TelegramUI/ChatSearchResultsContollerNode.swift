import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MergeLists
import ChatListUI
import AccountContext

private enum ChatListSearchEntryStableId: Hashable {
    case messageId(MessageId)
    
    public static func ==(lhs: ChatListSearchEntryStableId, rhs: ChatListSearchEntryStableId) -> Bool {
        switch lhs {
            case let .messageId(messageId):
                if case .messageId(messageId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ChatListSearchEntry: Comparable, Identifiable {
    case message(Message, RenderedPeer, CombinedPeerReadState?, ChatListPresentationData)
    
    public var stableId: ChatListSearchEntryStableId {
        switch self {
            case let .message(message, _, _, _):
                return .messageId(message.id)
        }
    }
    
    public static func ==(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, lhsPeer, lhsCombinedPeerReadState, lhsPresentationData):
                if case let .message(rhsMessage, rhsPeer, rhsCombinedPeerReadState, rhsPresentationData) = rhs {
                    if lhsMessage.id != rhsMessage.id {
                        return false
                    }
                    if lhsMessage.stableVersion != rhsMessage.stableVersion {
                        return false
                    }
                    if lhsPeer != rhsPeer {
                        return false
                    }
                    if lhsPresentationData !== rhsPresentationData {
                        return false
                    }
                    if lhsCombinedPeerReadState != rhsCombinedPeerReadState {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    public static func <(lhs: ChatListSearchEntry, rhs: ChatListSearchEntry) -> Bool {
        switch lhs {
            case let .message(lhsMessage, _, _, _):
                if case let .message(rhsMessage, _, _, _) = rhs {
                    return lhsMessage.index < rhsMessage.index
                }
        }
        return false
    }
    
    public func item(context: AccountContext, interaction: ChatListNodeInteraction) -> ListViewItem {
        switch self {
            case let .message(message, peer, readState, presentationData):
                return ChatListItem(presentationData: presentationData, context: context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: message.index), content: .peer(message: message, peer: peer, combinedReadState: readState, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: true, displayAsMessage: true), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction)
        }
    }
}

public struct ChatListSearchContainerTransition {
    public let deletions: [ListViewDeleteItem]
    public let insertions: [ListViewInsertItem]
    public let updates: [ListViewUpdateItem]
    
    public init(deletions: [ListViewDeleteItem], insertions: [ListViewInsertItem], updates: [ListViewUpdateItem]) {
        self.deletions = deletions
        self.insertions = insertions
        self.updates = updates
    }
}

private func chatListSearchContainerPreparedTransition(from fromEntries: [ChatListSearchEntry], to toEntries: [ChatListSearchEntry], context: AccountContext, interaction: ChatListNodeInteraction) -> ChatListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction), directionHint: nil) }
    
    return ChatListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates)
}

class ChatSearchResultsControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let messages: [Message]
    
    private var interaction: ChatListNodeInteraction?
    
    private let listNode: ListView
    
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var resultSelected: ((Int) -> Void)?
    
    private let presentationDataPromise: Promise<ChatListPresentationData>
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, searchQuery: String, messages: [Message]) {
        self.context = context
        self.messages = messages
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationDataPromise = Promise(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations))
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.isOpaque = false
        self.addSubnode(self.listNode)
        
        let signal = self.presentationDataPromise.get()
        |> map { presentationData -> [ChatListSearchEntry] in
            var entries: [ChatListSearchEntry] = []
            
            for message in messages {
                var peer = RenderedPeer(message: message)
                if let group = message.peers[message.id.peerId] as? TelegramGroup, let migrationReference = group.migrationReference {
                    if let channelPeer = message.peers[migrationReference.peerId] {
                        peer = RenderedPeer(peer: channelPeer)
                    }
                }
                entries.append(.message(message, peer, nil, presentationData))
            }
            
            return entries
        }
        
        let interaction = ChatListNodeInteraction(activateSearch: {
        }, peerSelected: { _ in
        }, togglePeerSelected: { _ in
        }, messageSelected: { [weak self] peer, message, _ in
            if let strongSelf = self {
                if let index = strongSelf.messages.firstIndex(where: { $0.index == message.index }) {
                    strongSelf.resultSelected?(strongSelf.messages.count - index - 1)
                }
                strongSelf.listNode.clearHighlightAnimated(true)
            }
        }, groupSelected: { _ in
        }, addContact: { [weak self] phoneNumber in
        }, setPeerIdWithRevealedOptions: { _, _ in
        }, setItemPinned: { _, _ in
        }, setPeerMuted: { _, _ in
        }, deletePeer: { _ in
        }, updatePeerGrouping: { _, _ in
        }, togglePeerMarkedUnread: { _, _ in
        }, toggleArchivedFolderHiddenByDefault: {
        }, activateChatPreview: { _, _, _ in
        })
        interaction.searchTextHighightState = searchQuery
        self.interaction = interaction
        
        let previousEntries = Atomic<[ChatListSearchEntry]?>(value: nil)
        self.disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                let previousEntries = previousEntries.swap(entries)
                
                let firstTime = previousEntries == nil
                let transition = chatListSearchContainerPreparedTransition(from: previousEntries ?? [], to: entries, context: context, interaction: interaction)
                strongSelf.enqueueTransition(transition, firstTime: firstTime)
            }
        }))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        let previousTheme = self.presentationData.theme
        self.presentationData = presentationData
        self.presentationDataPromise.set(.single(ChatListPresentationData(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)))
    }
    
    private func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            options.insert(.PreferSynchronousResourceLoading)
            
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            })
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        let topInset = navigationBarHeight
        
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
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: layout.safeInsets.left, bottom: layout.insets(options: [.input]).bottom, right: layout.safeInsets.right), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
}
