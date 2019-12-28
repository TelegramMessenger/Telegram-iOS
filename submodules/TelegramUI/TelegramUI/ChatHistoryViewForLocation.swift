import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import AccountContext

func preloadedChatHistoryViewForLocation(_ location: ChatHistoryLocationInput, account: Account, chatLocation: ChatLocation, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    return chatHistoryViewForLocation(location, account: account, chatLocation: chatLocation, scheduled: false, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, additionalData: additionalData, orderStatistics: orderStatistics)
    |> castError(Bool.self)
    |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
        switch update {
            case let .Loading(value):
                if case .Generic(.FillHole) = value.type {
                    return .fail(true)
                }
            case let .HistoryView(value):
                if case .Generic(.FillHole) = value.type {
                    return .fail(true)
                }
        }
        return .single(update)
    }
    |> restartIfError
}

func chatHistoryViewForLocation(_ location: ChatHistoryLocationInput, account: Account, chatLocation: ChatLocation, scheduled: Bool, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    if scheduled {
        var first = true
        var chatScrollPosition: ChatHistoryViewScrollPosition?
        if case let .Scroll(index, _, sourceIndex, position, animated) = location.content {
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            chatScrollPosition = .index(index: index, position: position, directionHint: directionHint, animated: animated)
        }
        return account.viewTracker.scheduledMessagesViewForLocation(chatLocation, additionalData: additionalData)
        |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
            
            if view.isLoading {
                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
            }

            let type: ChatHistoryViewUpdateType
            let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
            if first {
                first = false
                if chatScrollPosition == nil {
                    type = .Initial(fadeIn: false)
                } else {
                    type = .Generic(type: .UpdateVisible)
                }
            } else {
                type = .Generic(type: .Generic)
            }
            return .HistoryView(view: view, type: type, scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: chatScrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
        }
    } else {
        switch location.content {
            case let .Initial(count):
                var preloaded = false
                var fadeIn = false
                let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
                if let tagMask = tagMask {
                    signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics)
                } else {
                    signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocation, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
                }
                return signal
                |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                    
                    if preloaded {
                        return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: combinedInitialData, id: location.id)
                    } else {
                        if view.isLoading {
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
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
                            
                            let maxIndex = targetIndex + count / 2
                            let minIndex = targetIndex - count / 2
                            if minIndex <= 0 && view.holeEarlier {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                            if maxIndex >= targetIndex {
                                if view.holeLater {
                                    fadeIn = true
                                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                }
                                if view.holeEarlier {
                                    var incomingCount: Int32 = 0
                                    inner: for entry in view.entries.reversed() {
                                        if !entry.message.flags.intersection(.IsIncomingMask).isEmpty {
                                            incomingCount += 1
                                        }
                                    }
                                    if case let .peer(peerId) = chatLocation, let combinedReadStates = view.fixedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId], readState.count == incomingCount {
                                    } else {
                                        fadeIn = true
                                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                    }
                                }
                            }
                        } else if let historyScrollState = (initialData?.chatInterfaceState as? ChatInterfaceState)?.historyScrollState, tagMask == nil {
                            scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                        } else {
                            if view.entries.isEmpty && (view.holeEarlier || view.holeLater) {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        }
                        
                        preloaded = true
                        return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
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
                        return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: combinedInitialData, id: location.id)
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
                            if minIndex == 0 && view.holeEarlier {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                            if maxIndex == view.entries.count && view.holeLater {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        } else if view.holeEarlier || view.holeLater {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                        
                        var reportUpdateType: ChatHistoryViewUpdateType = .Initial(fadeIn: fadeIn)
                        if case .FillHole = updateType {
                            reportUpdateType = .Generic(type: updateType)
                        }
                        
                        preloaded = true
                        return .HistoryView(view: view, type: reportUpdateType, scrollPosition: .index(index: anchorIndex, position: .center(.bottom), directionHint: .Down, animated: false), flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
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
                    return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                }
            case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
                let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
                let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
                var first = true
                return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: 128, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
                |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let genericType: ViewUpdateType
                    let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
                    if first {
                        first = false
                        genericType = ViewUpdateType.UpdateVisible
                    } else {
                        genericType = updateType
                    }
                    return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, flashIndicators: animated, originalScrollPosition: chatScrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                }
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
                        if let combinedReadStates = view.fixedReadStates {
                            if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                                readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalState: totalUnreadState, notificationSettings: notificationSettings)
                            }
                        }
                    /*case .group:
                        break*/
                }
            default:
                break
        }
    }
        
    return (cachedData, cachedDataMessages, readStateData)
}
