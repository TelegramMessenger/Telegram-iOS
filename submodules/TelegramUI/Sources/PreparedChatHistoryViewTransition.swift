import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Display
import MergeLists
import AccountContext

func preparedChatHistoryViewTransition(from fromView: ChatHistoryView?, to toView: ChatHistoryView, reason: ChatHistoryViewTransitionReason, reverse: Bool, chatLocation: ChatLocation, controllerInteraction: ChatControllerInteraction, scrollPosition: ChatHistoryViewScrollPosition?, scrollAnimationCurve: ListViewAnimationCurve?, initialData: InitialMessageHistoryData?, keyboardButtonsMessage: Message?, cachedData: CachedPeerData?, cachedDataMessages: [MessageId: Message]?, readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?, flashIndicators: Bool, updatedMessageSelection: Bool, messageTransitionNode: ChatMessageTransitionNode?, allUpdated: Bool) -> ChatHistoryViewTransition {
    var mergeResult: (deleteIndices: [Int], indicesAndItems: [(Int, ChatHistoryEntry, Int?)], updateIndices: [(Int, ChatHistoryEntry, Int)])
    let allUpdated = allUpdated || (fromView?.associatedData != toView.associatedData)
    if reverse {
        mergeResult = mergeListsStableWithUpdatesReversed(leftList: fromView?.filteredEntries ?? [], rightList: toView.filteredEntries, allUpdated: allUpdated)
    } else {
        mergeResult = mergeListsStableWithUpdates(leftList: fromView?.filteredEntries ?? [], rightList: toView.filteredEntries, allUpdated: allUpdated)
    }

    if let messageTransitionNode = messageTransitionNode, messageTransitionNode.hasOngoingTransitions, let previousEntries = fromView?.filteredEntries {
        for i in 0 ..< mergeResult.updateIndices.count {
            switch mergeResult.updateIndices[i].1 {
            case let .MessageEntry(message, presentationData, flag, monthLocation, messageSelection, entryAttributes):
                if messageTransitionNode.isAnimatingMessage(stableId: message.stableId) {
                    var updatedMessage = message
                    mediaLoop: for media in message.media {
                        if let webpage = media as? TelegramMediaWebpage, case .Loaded = webpage.content {
                            var filterMedia = false
                            switch previousEntries[mergeResult.updateIndices[i].2] {
                            case let .MessageEntry(previousMessage, _, _, _, _, _):
                                if previousMessage.media.contains(where: { value in
                                    if let value = value as? TelegramMediaWebpage, case .Loaded = value.content {
                                        return true
                                    } else {
                                        return false
                                    }
                                }) {
                                    if messageTransitionNode.hasScheduledUpdateMessageAfterAnimationCompleted(stableId: message.stableId) {
                                        filterMedia = true
                                    }
                                } else {
                                    filterMedia = true
                                }
                            default:
                                break
                            }

                            if filterMedia {
                                updatedMessage = message.withUpdatedMedia(message.media.filter {
                                    $0 !== media
                                })
                                messageTransitionNode.scheduleUpdateMessageAfterAnimationCompleted(stableId: message.stableId)
                            }

                            break mediaLoop
                        }
                    }
                    mergeResult.updateIndices[i].1 = .MessageEntry(updatedMessage, presentationData, flag, monthLocation, messageSelection, entryAttributes)
                }
            default:
                break
            }
        }
    }
    
    var adjustedDeleteIndices: [ListViewDeleteItem] = []
    let previousCount: Int
    if let fromView = fromView {
        previousCount = fromView.filteredEntries.count
    } else {
        previousCount = 0
    }
    for index in mergeResult.deleteIndices {
        adjustedDeleteIndices.append(ListViewDeleteItem(index: previousCount - 1 - index, directionHint: nil))
    }
    
    var adjustedIndicesAndItems: [ChatHistoryViewTransitionInsertEntry] = []
    var adjustedUpdateItems: [ChatHistoryViewTransitionUpdateEntry] = []
    let updatedCount = toView.filteredEntries.count
    
    var options: ListViewDeleteAndInsertOptions = []
    var animateIn = false
    var maxAnimatedInsertionIndex = -1
    var stationaryItemRange: (Int, Int)?
    var scrollToItem: ListViewScrollToItem?
    
    switch reason {
    case let .Initial(fadeIn):
        if fadeIn {
            animateIn = true
        } else {
            let _ = options.insert(.LowLatency)
            let _ = options.insert(.Synchronous)
            let _ = options.insert(.PreferSynchronousResourceLoading)
        }
    case .InteractiveChanges:
        let _ = options.insert(.AnimateAlpha)
        let _ = options.insert(.AnimateInsertion)
        
        for (index, _, _) in mergeResult.indicesAndItems.sorted(by: { $0.0 > $1.0 }) {
            let adjustedIndex = updatedCount - 1 - index
            if adjustedIndex == maxAnimatedInsertionIndex + 1 {
                maxAnimatedInsertionIndex += 1
            }
        }
    case .Reload:
        stationaryItemRange = (0, Int.max)
    case .HoleReload:
        stationaryItemRange = (0, Int.max)
    }
    
    for (index, entry, previousIndex) in mergeResult.indicesAndItems {
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
        
        adjustedIndicesAndItems.append(ChatHistoryViewTransitionInsertEntry(index: adjustedIndex, previousIndex: adjustedPrevousIndex, entry: entry, directionHint: directionHint))
    }
    
    for (index, entry, previousIndex) in mergeResult.updateIndices {
        let adjustedIndex = updatedCount - 1 - index
        let adjustedPreviousIndex = previousCount - 1 - previousIndex
        
        let directionHint: ListViewItemOperationDirectionHint? = nil
        adjustedUpdateItems.append(ChatHistoryViewTransitionUpdateEntry(index: adjustedIndex, previousIndex: adjustedPreviousIndex, entry: entry, directionHint: directionHint))
    }
    
    var scrolledToIndex: MessageHistoryAnchorIndex?
    var scrolledToSomeIndex = false
    
    let curve: ListViewAnimationCurve = scrollAnimationCurve ?? .Default(duration: nil)
    
    if let scrollPosition = scrollPosition {
        switch scrollPosition {
            case let .unread(unreadIndex):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case .UnreadEntry = entry {
                        scrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: false, curve: curve, directionHint: .Down)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = toView.filteredEntries.count - 1
                    for entry in toView.filteredEntries {
                        if entry.index >= unreadIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: false, curve: curve,  directionHint: .Down)
                            break
                        }
                        index -= 1
                    }
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.index < unreadIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: false, curve: curve, directionHint: .Down)
                            break
                        }
                        index += 1
                    }
                }
            case let .positionRestoration(scrollIndex, relativeOffset):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if entry.index >= scrollIndex {
                        scrollToItem = ListViewScrollToItem(index: index, position: .top(relativeOffset), animated: false, curve: curve,  directionHint: .Down)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if entry.index < scrollIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: curve, directionHint: .Down)
                            break
                        }
                        index += 1
                    }
                }
            case let .index(scrollIndex, position, directionHint, animated, highlight, displayLink):
                if case .center = position, highlight {
                    scrolledToIndex = scrollIndex
                }
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if scrollIndex.isLessOrEqual(to: entry.index) {
                        scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: curve, directionHint: directionHint, displayLink: displayLink)
                        break
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if !scrollIndex.isLess(than: entry.index) {
                            scrolledToSomeIndex = true
                            scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: curve, directionHint: directionHint)
                            break
                        }
                        index += 1
                    }
                }
        }
    } else if case .Initial = reason, scrollToItem == nil {
        var index = toView.filteredEntries.count - 1
        for entry in toView.filteredEntries {
            if case let .MessageEntry(message, _, _, _, _, _) = entry {
                if let _ = message.adAttribute {
                    scrollToItem = ListViewScrollToItem(index: index + 1, position: .top(0.0), animated: false, curve: curve, directionHint: .Down)
                    break
                }
            }
            index -= 1
        }
    }
    
    if updatedMessageSelection {
        options.insert(.Synchronous)
    }
    
    return ChatHistoryViewTransition(historyView: toView, deleteItems: adjustedDeleteIndices, insertEntries: adjustedIndicesAndItems, updateEntries: adjustedUpdateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: initialData, keyboardButtonsMessage: keyboardButtonsMessage, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, scrolledToIndex: scrolledToIndex, scrolledToSomeIndex: scrolledToSomeIndex || scrolledToIndex != nil, animateIn: animateIn, reason: reason, flashIndicators: flashIndicators)
}
