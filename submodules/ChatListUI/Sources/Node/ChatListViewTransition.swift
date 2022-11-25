import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import MergeLists
import SearchUI
import TelegramUIPreferences

struct ChatListNodeView {
    let originalList: EngineChatList
    let filteredEntries: [ChatListNodeEntry]
    let isLoading: Bool
    let filter: ChatListFilter?
}

enum ChatListNodeViewTransitionReason {
    case initial
    case interactiveChanges
    case holeChanges
    case reload
}

struct ChatListNodeViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: ChatListNodeEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatListNodeViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: ChatListNodeEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct ChatListNodeViewTransition {
    let chatListView: ChatListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertEntries: [ChatListNodeViewTransitionInsertEntry]
    let updateEntries: [ChatListNodeViewTransitionUpdateEntry]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
    let adjustScrollToFirstItem: Bool
    let animateCrossfade: Bool
}

enum ChatListNodeViewScrollPosition {
    case index(index: ChatListIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

func preparedChatListNodeViewTransition(from fromView: ChatListNodeView?, to toView: ChatListNodeView, reason: ChatListNodeViewTransitionReason, previewing: Bool, disableAnimations: Bool, account: Account, scrollPosition: ChatListNodeViewScrollPosition?, searchMode: Bool) -> Signal<ChatListNodeViewTransition, NoError> {
    return Signal<ChatListNodeViewTransition, NoError> { subscriber in
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromView?.filteredEntries ?? [], rightList: toView.filteredEntries)
        
        var adjustedDeleteIndices: [ListViewDeleteItem] = []
        let previousCount: Int
        if let fromView = fromView {
            previousCount = fromView.filteredEntries.count
        } else {
            previousCount = 0
        }
        for index in deleteIndices {
            adjustedDeleteIndices.append(ListViewDeleteItem(index: previousCount - 1 - index, directionHint: nil))
        }
        var adjustedIndicesAndItems: [ChatListNodeViewTransitionInsertEntry] = []
        var adjustedUpdateItems: [ChatListNodeViewTransitionUpdateEntry] = []
        let updatedCount = toView.filteredEntries.count
        
        var options: ListViewDeleteAndInsertOptions = []
        var maxAnimatedInsertionIndex = -1
        var scrollToItem: ListViewScrollToItem?
        
        switch reason {
        case .initial:
            let _ = options.insert(.LowLatency)
            let _ = options.insert(.Synchronous)
        case .interactiveChanges:
            for (index, _, _) in indicesAndItems.sorted(by: { $0.0 > $1.0 }) {
                let adjustedIndex = updatedCount - 1 - index
                if adjustedIndex == maxAnimatedInsertionIndex + 1 {
                    maxAnimatedInsertionIndex += 1
                }
            }
            
            var minTimestamp: Int32?
            var maxTimestamp: Int32?
            for (_, item, _) in indicesAndItems {
                if case .PeerEntry = item, case let .index(index) = item.sortIndex, case let .chatList(chatListIndex) = index, chatListIndex.pinningIndex == nil {
                    let timestamp = chatListIndex.messageIndex.timestamp
                    
                    if minTimestamp == nil || timestamp < minTimestamp! {
                        minTimestamp = timestamp
                    }
                    if maxTimestamp == nil || timestamp > maxTimestamp! {
                        maxTimestamp = timestamp
                    }
                }
            }
            
            let _ = options.insert(.AnimateAlpha)
            if !disableAnimations {
                let _ = options.insert(.AnimateInsertion)
            }
        case .reload:
            break
        case .holeChanges:
            break
        }
        
        for (index, entry, previousIndex) in indicesAndItems {
            let adjustedIndex = updatedCount - 1 - index
            
            let adjustedPrevousIndex: Int?
            if let previousIndex = previousIndex {
                adjustedPrevousIndex = previousCount - 1 - previousIndex
            } else {
                adjustedPrevousIndex = nil
            }
            
            var directionHint: ListViewItemOperationDirectionHint?
            if maxAnimatedInsertionIndex >= 0 && adjustedIndex <= maxAnimatedInsertionIndex {
                directionHint = .Down
            }
            
            adjustedIndicesAndItems.append(ChatListNodeViewTransitionInsertEntry(index: adjustedIndex, previousIndex: adjustedPrevousIndex, entry: entry, directionHint: directionHint))
        }
        
        for (index, entry, previousIndex) in updateIndices {
            let adjustedIndex = updatedCount - 1 - index
            let adjustedPreviousIndex = previousCount - 1 - previousIndex
            
            let directionHint: ListViewItemOperationDirectionHint? = nil
            adjustedUpdateItems.append(ChatListNodeViewTransitionUpdateEntry(index: adjustedIndex, previousIndex: adjustedPreviousIndex, entry: entry, directionHint: directionHint))
        }
        
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .index(scrollIndex, position, directionHint, animated):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if entry.sortIndex >= .index(.chatList(scrollIndex)) {
                        scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default(duration: nil), directionHint: directionHint)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.sortIndex < .index(.chatList(scrollIndex)) {
                            scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default(duration: nil), directionHint: directionHint)
                            break
                        }
                        index += 1
                    }
                }
            }
        }
        
        var fromEmptyView: Bool
        fromEmptyView = false
        var animateCrossfade: Bool
        animateCrossfade = false
        if let fromView = fromView {
            var wasSingleHeader = false
            if fromView.filteredEntries.count == 1, case .HeaderEntry = fromView.filteredEntries[0] {
                wasSingleHeader = true
            }
            var isSingleHeader = false
            if toView.filteredEntries.count == 1, case .HeaderEntry = toView.filteredEntries[0] {
                isSingleHeader = true
            }
            if (wasSingleHeader || isSingleHeader), case .interactiveChanges = reason {
                if wasSingleHeader != isSingleHeader {
                    if wasSingleHeader {
                        animateCrossfade = true
                        options.remove(.AnimateInsertion)
                        options.remove(.AnimateAlpha)
                    } else {
                        let _ = options.insert(.AnimateInsertion)
                    }
                }
            } else if fromView.filteredEntries.isEmpty || fromView.filter != toView.filter {
                var updateEmpty = true
                if !fromView.filteredEntries.isEmpty, let fromFilter = fromView.filter, let toFilter = toView.filter, case var .filter(_, _, _, fromData) = fromFilter, case let .filter(_, _, _, toData) = toFilter, fromData.includePeers.pinnedPeers != toData.includePeers.pinnedPeers {
                    fromData.includePeers = toData.includePeers
                    if fromData == toData {
                        options.insert(.AnimateInsertion)
                        updateEmpty = false
                    }
                }
                
                if updateEmpty {
                    options.remove(.AnimateInsertion)
                    options.remove(.AnimateAlpha)
                    fromEmptyView = true
                }
            }
        } else {
            fromEmptyView = true
        }
        
        if let fromView = fromView, !fromView.isLoading, toView.isLoading {
            options.remove(.AnimateInsertion)
            options.remove(.AnimateAlpha)
        }
        
        var adjustScrollToFirstItem = false
        if !previewing && !searchMode && fromEmptyView && scrollToItem == nil && toView.filteredEntries.count >= 2 {
            adjustScrollToFirstItem = true
        }
        
        subscriber.putNext(ChatListNodeViewTransition(chatListView: toView, deleteItems: adjustedDeleteIndices, insertEntries: adjustedIndicesAndItems, updateEntries: adjustedUpdateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: nil, adjustScrollToFirstItem: adjustScrollToFirstItem, animateCrossfade: animateCrossfade))
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}
