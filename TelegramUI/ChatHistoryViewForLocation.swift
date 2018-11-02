import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

func chatHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, chatLocation: ChatLocation, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    switch location {
        case let .Initial(count):
            var preloaded = false
            var fadeIn = false
            let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            if let tagMask = tagMask {
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics)
            } else {
                signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocation, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
            return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                
                let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, originalScrollPosition: nil, initialData: combinedInitialData)
                } else {
                    if view.isLoading {
                        return .Loading(initialData: combinedInitialData)
                    }
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
                                if case let .HoleEntry(hole) = view.entries[i] {
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
                                    if let combinedReadStates = view.combinedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[hole.0.maxIndex.id.peerId], readState.count == incomingCount {
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
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
                }
            }
        case let .InitialSearch(searchLocation, count):
            var preloaded = false
            var fadeIn = false
            
            let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            switch searchLocation {
                case let .index(index):
                    signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: .message(index), anchorIndex: .message(index), count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
                case let .id(id):
                    signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(chatLocation, count: count, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
            
            return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                
                let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                
                if preloaded {
                    return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, originalScrollPosition: nil, initialData: combinedInitialData)
                } else {
                    let anchorIndex = view.anchorIndex
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if anchorIndex.isLessOrEqual(to: view.entries[i].index) {
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
                    return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .index(index: anchorIndex, position: .center(.bottom), directionHint: .Down, animated: false), originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
                }
            }
        case let .Navigation(index, anchorIndex, count):
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                
                let genericType: ViewUpdateType
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
            }
        case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: 200, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                
                let genericType: ViewUpdateType
                let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, originalScrollPosition: chatScrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData))
            }
        }
}

private func extractAdditionalData(view: MessageHistoryView, chatLocation: ChatLocation) -> (
    cachedData: CachedPeerData?,
    cachedDataMessages: [MessageId: Message]?,
    readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    ) {
    var cachedData: CachedPeerData?
    var cachedDataMessages: [MessageId: Message]?
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData] = [:]
    var notificationSettings: PeerNotificationSettings?
        
    loop: for data in view.additionalData {
        switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
                break loop
            default:
                break
        }
    }
        
    for data in view.additionalData {
        switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
            case let .cachedPeerData(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    cachedData = value
                }
            case let .cachedPeerDataMessages(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    cachedDataMessages = value
                }
            case let .totalUnreadState(totalUnreadState):
                switch chatLocation {
                    case let .peer(peerId):
                        if let combinedReadStates = view.combinedReadStates {
                            if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                                readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadChatCount: totalUnreadState.count(for: .filtered, in: .chats, with: [.regularChatsAndPrivateGroups]), notificationSettings: notificationSettings)
                            }
                        }
                    case .group:
                        break
                }
            default:
                break
        }
    }
        
    return (cachedData, cachedDataMessages, readStateData)
}
