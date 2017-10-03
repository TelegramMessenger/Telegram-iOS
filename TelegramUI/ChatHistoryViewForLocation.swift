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
                signal = account.viewTracker.aroundMessageOfInterestHistoryViewForPeerId(peerId, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
            return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                var cachedDataMessages: [MessageId: Message]?
                var readStateData: ChatHistoryCombinedInitialReadStateData?
                var notificationSettings: PeerNotificationSettings?
                for data in view.additionalData {
                    switch data {
                        case let .peerNotificationSettings(value):
                            notificationSettings = value
                        default:
                            break
                    }
                }
                for data in view.additionalData {
                    switch data {
                        case let .cachedPeerData(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedData = value
                            }
                        case let .cachedPeerDataMessages(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedDataMessages = value
                            }
                        case let .totalUnreadCount(totalUnreadCount):
                            if let readState = view.combinedReadState {
                                readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount, notificationSettings: notificationSettings)
                            }
                        default:
                            break
                    }
                }
                
                let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: combinedInitialData)
                } else {
                    var scrollPosition: ChatHistoryViewScrollPosition?
                    
                    if let maxReadIndex = view.maxReadIndex, tagMask == nil {
                        let aroundIndex = maxReadIndex
                        scrollPosition = .unread(index: maxReadIndex)
                        
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
                                    var incomingCount: Int32 = 0
                                    inner: for entry in view.entries.reversed() {
                                        switch entry {
                                            case .HoleEntry:
                                                break inner
                                            case let .MessageEntry(message, _, _, _):
                                                if message.flags.contains(.Incoming) {
                                                    incomingCount += 1
                                                }
                                        }
                                    }
                                    if let combinedReadState = view.combinedReadState, combinedReadState.count == incomingCount {
                                        
                                    } else {
                                        fadeIn = true
                                        return .Loading(initialData: combinedInitialData)
                                    }
                                }
                            }
                        }
                    } else if let historyScrollState = (initialData?.chatInterfaceState as? ChatInterfaceState)?.historyScrollState, tagMask == nil {
                        scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                    } else {
                        var messageCount = 0
                        for entry in view.entries.reversed() {
                            if case .HoleEntry = entry {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData)
                            } else {
                                messageCount += 1
                            }
                            if messageCount >= 1 {
                                break
                            }
                        }
                    }
                    
                    preloaded = true
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
                }
            }
        case let .InitialSearch(searchLocation, count):
            var preloaded = false
            var fadeIn = false
            
            let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            switch searchLocation {
                case let .index(index):
                    signal = account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: index, fixedCombinedReadState: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
                case let .id(id):
                    signal = account.viewTracker.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
            
            return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                var cachedDataMessages: [MessageId: Message]?
                var readStateData: ChatHistoryCombinedInitialReadStateData?
                var notificationSettings: PeerNotificationSettings?
                for data in view.additionalData {
                    switch data {
                        case let .peerNotificationSettings(value):
                            notificationSettings = value
                        default:
                            break
                    }
                }
                for data in view.additionalData {
                    switch data {
                        case let .cachedPeerData(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedData = value
                            }
                        case let .cachedPeerDataMessages(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedDataMessages = value
                            }
                        case let .totalUnreadCount(totalUnreadCount):
                            if let readState = view.combinedReadState {
                                readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount, notificationSettings: notificationSettings)
                            }
                        default:
                            break
                    }
                }
                
                let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: combinedInitialData)
                } else {
                    let anchorIndex = view.anchorIndex
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if view.entries[i].index >= anchorIndex {
                            targetIndex = i
                            break
                        }
                    }
                    
                    if !view.entries.isEmpty {
                        let minIndex = max(0, targetIndex - count / 2)
                        let maxIndex = min(view.entries.count, targetIndex + count / 2)
                        for i in minIndex ..< maxIndex {
                            if case .HoleEntry = view.entries[i] {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData)
                            }
                        }
                    }
                    
                    preloaded = true
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .index(index: anchorIndex, position: .center(.bottom), directionHint: .Down, animated: false), initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
                }
            }
        case let .Navigation(index, anchorIndex):
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                var cachedDataMessages: [MessageId: Message]?
                var readStateData: ChatHistoryCombinedInitialReadStateData?
                var notificationSettings: PeerNotificationSettings?
                for data in view.additionalData {
                    switch data {
                        case let .peerNotificationSettings(value):
                            notificationSettings = value
                        default:
                            break
                    }
                }
                for data in view.additionalData {
                    switch data {
                        case let .cachedPeerData(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedData = value
                            }
                        case let .cachedPeerDataMessages(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedDataMessages = value
                            }
                        case let .totalUnreadCount(totalUnreadCount):
                            if let readState = view.combinedReadState {
                                readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount, notificationSettings: notificationSettings)
                            }
                        default:
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
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
            }
        case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, count: 140, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                var cachedData: CachedPeerData?
                var cachedDataMessages: [MessageId: Message]?
                var readStateData: ChatHistoryCombinedInitialReadStateData?
                var notificationSettings: PeerNotificationSettings?
                for data in view.additionalData {
                    switch data {
                        case let .peerNotificationSettings(value):
                            notificationSettings = value
                        default:
                            break
                    }
                }
                for data in view.additionalData {
                    switch data {
                        case let .cachedPeerData(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedData = value
                            }
                        case let .cachedPeerDataMessages(peerIdValue, value):
                            if peerIdValue == peerId {
                                cachedDataMessages = value
                            }
                        case let .totalUnreadCount(totalUnreadCount):
                            if let readState = view.combinedReadState {
                                readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount, notificationSettings: notificationSettings)
                            }
                        default:
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
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
            }
        }
}
