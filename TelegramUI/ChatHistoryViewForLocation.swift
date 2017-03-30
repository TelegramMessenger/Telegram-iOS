import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

func chatHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, peerId: PeerId, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    switch location {
        case let .Initial(count):
            var preloaded = false
            var fadeIn = false
            let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            if let tagMask = tagMask {
                signal = account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: MessageIndex.upperBound(peerId: peerId), count: count, anchorIndex: MessageIndex.upperBound(peerId: peerId), fixedCombinedReadState: nil, tagMask: tagMask, orderStatistics: orderStatistics)
            } else {
                signal = account.viewTracker.aroundUnreadMessageHistoryViewForPeerId(peerId, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
            return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                for data in view.additionalData {
                    if case let .cachedPeerData(peerIdValue, value) = data, peerIdValue == peerId {
                        cachedData = value
                        break
                    }
                }
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
                } else {
                    var scrollPosition: ChatHistoryViewScrollPosition?
                    
                    if let maxReadIndex = view.maxReadIndex, tagMask == nil {
                        let aroundIndex = maxReadIndex
                        scrollPosition = .Unread(index: maxReadIndex)
                        
                        var targetIndex = 0
                        for i in 0 ..< view.entries.count {
                            if view.entries[i].index >= aroundIndex {
                                targetIndex = i
                                break
                            }
                        }
                        
                        let maxIndex = min(view.entries.count, targetIndex + count / 2)
                        if maxIndex >= targetIndex {
                            for i in targetIndex ..< maxIndex {
                                if case .HoleEntry = view.entries[i] {
                                    fadeIn = true
                                    return .Loading(initialData: initialData)
                                }
                            }
                        }
                    } else {
                        var messageCount = 0
                        for entry in view.entries.reversed() {
                            if case .HoleEntry = entry {
                                fadeIn = true
                                return .Loading(initialData: initialData)
                            } else {
                                messageCount += 1
                            }
                            if messageCount >= 1 {
                                break
                            }
                        }
                    }
                    
                    preloaded = true
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
                }
            }
        case let .InitialSearch(messageId, count):
            var preloaded = false
            var fadeIn = false
            return account.viewTracker.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: messageId, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                for data in view.additionalData {
                    if case let .cachedPeerData(peerIdValue, value) = data, peerIdValue == peerId {
                        cachedData = value
                        break
                    }
                }
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
                } else {
                    let anchorIndex = view.anchorIndex
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if view.entries[i].index >= anchorIndex {
                            targetIndex = i
                            break
                        }
                    }
                    
                    let maxIndex = min(view.entries.count, targetIndex + count / 2)
                    if maxIndex >= targetIndex {
                        for i in targetIndex ..< maxIndex {
                            if case .HoleEntry = view.entries[i] {
                                fadeIn = true
                                return .Loading(initialData: initialData)
                            }
                        }
                    }
                    
                    preloaded = true
                    //case Index(index: MessageIndex, position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .Index(index: anchorIndex, position: .Center(.Bottom), directionHint: .Down, animated: false), initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
                }
            }
        case let .Navigation(index, anchorIndex):
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                for data in view.additionalData {
                    if case let .cachedPeerData(peerIdValue, value) = data, peerIdValue == peerId {
                        cachedData = value
                        break
                    }
                }
                
                let genericType: ViewUpdateType
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
            }
        case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let chatScrollPosition = ChatHistoryViewScrollPosition.Index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                for data in view.additionalData {
                    if case let .cachedPeerData(peerIdValue, value) = data, peerIdValue == peerId {
                        cachedData = value
                        break
                    }
                }
                
                let genericType: ViewUpdateType
                let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData))
            }
        }
}
