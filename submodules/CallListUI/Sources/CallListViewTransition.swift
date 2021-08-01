import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display
import MergeLists
import ItemListUI
import AccountContext

struct CallListNodeView {
    let originalView: EngineCallList
    let filteredEntries: [CallListNodeEntry]
    let presentationData: ItemListPresentationData
}

enum CallListNodeViewTransitionReason {
    case initial
    case interactiveChanges
    case reload
    case reloadAnimated
}

struct CallListNodeViewTransitionInsertEntry {
    let index: Int
    let previousIndex: Int?
    let entry: CallListNodeEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct CallListNodeViewTransitionUpdateEntry {
    let index: Int
    let previousIndex: Int
    let entry: CallListNodeEntry
    let directionHint: ListViewItemOperationDirectionHint?
}

struct CallListNodeViewTransition {
    let callListView: CallListNodeView
    let deleteItems: [ListViewDeleteItem]
    let insertEntries: [CallListNodeViewTransitionInsertEntry]
    let updateEntries: [CallListNodeViewTransitionUpdateEntry]
    let options: ListViewDeleteAndInsertOptions
    let scrollToItem: ListViewScrollToItem?
    let stationaryItemRange: (Int, Int)?
}

enum CallListNodeViewScrollPosition {
    case index(index: EngineMessage.Index, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

func preparedCallListNodeViewTransition(from fromView: CallListNodeView?, to toView: CallListNodeView, reason: CallListNodeViewTransitionReason, disableAnimations: Bool, context: AccountContext, scrollPosition: CallListNodeViewScrollPosition?) -> Signal<CallListNodeViewTransition, NoError> {
    return Signal { subscriber in
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromView?.filteredEntries ?? [], rightList: toView.filteredEntries, allUpdated: fromView?.presentationData != toView.presentationData)
        
        var adjustedDeleteIndices: [ListViewDeleteItem] = []
        let previousCount: Int
        if let fromView = fromView {
            previousCount = fromView.filteredEntries.count
        } else {
            previousCount = 0;
        }
        for index in deleteIndices {
            adjustedDeleteIndices.append(ListViewDeleteItem(index: previousCount - 1 - index, directionHint: nil))
        }
        var adjustedIndicesAndItems: [CallListNodeViewTransitionInsertEntry] = []
        var adjustedUpdateItems: [CallListNodeViewTransitionUpdateEntry] = []
        let updatedCount = toView.filteredEntries.count
        
        var options: ListViewDeleteAndInsertOptions = []
        var maxAnimatedInsertionIndex = -1
        let stationaryItemRange: (Int, Int)? = nil
        var scrollToItem: ListViewScrollToItem? = nil
        
        var wasEmpty = false
        if let fromView = fromView, fromView.originalView.items.isEmpty {
            wasEmpty = true
        }
        
        switch reason {
        case .initial:
            let _ = options.insert(.LowLatency)
            let _ = options.insert(.Synchronous)
            let _ = options.insert(.PreferSynchronousResourceLoading)
        case .interactiveChanges:
            if wasEmpty {
                let _ = options.insert(.Synchronous)
                let _ = options.insert(.PreferSynchronousResourceLoading)
            } else {
                let _ = options.insert(.AnimateAlpha)
                if !disableAnimations {
                    let _ = options.insert(.AnimateInsertion)
                }
                
                for (index, _, _) in indicesAndItems.sorted(by: { $0.0 > $1.0 }) {
                    let adjustedIndex = updatedCount - 1 - index
                    if adjustedIndex == maxAnimatedInsertionIndex + 1 {
                        maxAnimatedInsertionIndex += 1
                    }
                }
            }
        case .reload:
            break
        case .reloadAnimated:
            let _ = options.insert(.LowLatency)
            let _ = options.insert(.Synchronous)
            let _ = options.insert(.AnimateCrossfade)
            let _ = options.insert(.PreferSynchronousResourceLoading)
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
            
            adjustedIndicesAndItems.append(CallListNodeViewTransitionInsertEntry(index: adjustedIndex, previousIndex: adjustedPrevousIndex, entry: entry, directionHint: directionHint))
        }
        
        for (index, entry, previousIndex) in updateIndices {
            let adjustedIndex = updatedCount - 1 - index
            let adjustedPreviousIndex = previousCount - 1 - previousIndex
            
            let directionHint: ListViewItemOperationDirectionHint? = nil
            adjustedUpdateItems.append(CallListNodeViewTransitionUpdateEntry(index: adjustedIndex, previousIndex: adjustedPreviousIndex, entry: entry, directionHint: directionHint))
        }
        
        if let scrollPosition = scrollPosition {
            switch scrollPosition {
            case let .index(scrollIndex, position, directionHint, animated):
                var index = toView.filteredEntries.count - 1
                for entry in toView.filteredEntries {
                    if case let .message(messageIndex) = entry.sortIndex {
                        if messageIndex >= scrollIndex {
                            scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default(duration: nil), directionHint: directionHint)
                            break
                        }
                    }
                    index -= 1
                }
                
                if scrollToItem == nil {
                    var index = 0
                    for entry in toView.filteredEntries.reversed() {
                        if case let .message(messageIndex) = entry.sortIndex {
                            if messageIndex < scrollIndex {
                                scrollToItem = ListViewScrollToItem(index: index, position: position, animated: animated, curve: .Default(duration: nil), directionHint: directionHint)
                                break
                            }
                        }
                        index += 1
                    }
                }
            }
        }
        
        subscriber.putNext(CallListNodeViewTransition(callListView: toView, deleteItems: adjustedDeleteIndices, insertEntries: adjustedIndicesAndItems, updateEntries: adjustedUpdateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange))
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
}
