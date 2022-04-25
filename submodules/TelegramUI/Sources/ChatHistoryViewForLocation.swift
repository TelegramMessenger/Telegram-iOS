import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import AccountContext
import ChatInterfaceState

func preloadedChatHistoryViewForLocation(_ location: ChatHistoryLocationInput, context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    var isScheduled = false
    if case .scheduledMessages = subject {
        isScheduled = true
    }
    
    var tagMask = tagMask
    if case .pinnedMessages = subject {
        tagMask = .pinned
    }
    
    return (chatHistoryViewForLocation(location, ignoreMessagesInTimestampRange: nil, context: context, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, scheduled: isScheduled, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, appendMessagesFromTheSameGroup: false, additionalData: additionalData, orderStatistics: orderStatistics)
    |> castError(Bool.self)
    |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
        switch update {
            case let .Loading(_, type):
                if case .Generic(.FillHole) = type {
                    return .fail(true)
                }
            case let .HistoryView(_, type, _, _, _, _, _):
                if case .Generic(.FillHole) = type {
                    return .fail(true)
                }
        }
        return .single(update)
    })
    |> restartIfError
}

func chatHistoryViewForLocation(_ location: ChatHistoryLocationInput, ignoreMessagesInTimestampRange: ClosedRange<Int32>?, context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, scheduled: Bool, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, appendMessagesFromTheSameGroup: Bool, additionalData: [AdditionalMessageHistoryViewData], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    let account = context.account
    if scheduled {
        var first = true
        var chatScrollPosition: ChatHistoryViewScrollPosition?
        if case let .Scroll(index, _, sourceIndex, position, animated, highlight) = location.content {
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            chatScrollPosition = .index(index: index, position: position, directionHint: directionHint, animated: animated, highlight: highlight)
        }
        return account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), additionalData: additionalData)
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
        let ignoreRelatedChats: Bool
        if let tagMask = tagMask, case .pinned = tagMask {
            ignoreRelatedChats = true
        } else {
            ignoreRelatedChats = false
        }
        
        switch location.content {
            case let .Initial(count):
                var preloaded = false
                var fadeIn = false
                let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
                if let tagMask = tagMask {
                    signal = account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, index: .upperBound, anchorIndex: .upperBound, count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: nil, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics)
                } else {
                    signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData)
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
                        
                        let canScrollToRead: Bool
                        if case .replyThread = chatLocation {
                            canScrollToRead = true
                        } else if view.isAddedToChatList {
                            canScrollToRead = true
                        } else {
                            canScrollToRead = false
                        }
                        
                        if let maxReadIndex = view.maxReadIndex, tagMask == nil, canScrollToRead {
                            let aroundIndex = maxReadIndex
                            scrollPosition = .unread(index: maxReadIndex)
                            
                            if case .peer = chatLocation {
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
                            }
                        } else if view.isAddedToChatList, tagMask == nil, let historyScrollState = (initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState).flatMap(ChatInterfaceState.parse)?.historyScrollState {
                            scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                        } else {
                            if case .peer = chatLocation, !view.isAddedToChatList {
                                if view.holeEarlier && view.entries.count <= 2 {
                                    fadeIn = true
                                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                                }
                            }
                            if view.entries.isEmpty && (view.holeEarlier || view.holeLater) {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        }
                        
                        preloaded = true
                        return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                    }
                }
            case let .InitialSearch(searchLocation, count, highlight):
                var preloaded = false
                var fadeIn = false
                
                let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
                switch searchLocation {
                    case let .index(index):
                        signal = account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, index: .message(index), anchorIndex: .message(index), count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: nil, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData)
                    case let .id(id):
                        signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, ignoreRelatedChats: ignoreRelatedChats, messageId: id, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData)
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
                        return .HistoryView(view: view, type: reportUpdateType, scrollPosition: .index(index: anchorIndex, position: .center(.bottom), directionHint: .Down, animated: false, highlight: highlight), flashIndicators: false, originalScrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData), id: location.id)
                    }
                }
            case let .Navigation(index, anchorIndex, count, _):
                var first = true
                return account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, index: index, anchorIndex: anchorIndex, count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
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
            case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated, highlight):
                let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
                let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated, highlight: highlight)
                var first = true
                return account.viewTracker.aroundMessageHistoryViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder), ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, index: index, anchorIndex: anchorIndex, count: 128, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, orderStatistics: orderStatistics, additionalData: additionalData)
                |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
                    let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
                    
                    let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
                    
                    if view.isLoading {
                        return ChatHistoryViewUpdate.Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    
                    let genericType: ViewUpdateType
                    let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
                    if first {
                        first = false
                        genericType = ViewUpdateType.UpdateVisible
                    } else {
                        genericType = updateType
                    }
                    return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, flashIndicators: animated, originalScrollPosition: chatScrollPosition, initialData: combinedInitialData, id: location.id)
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
    var cachedDataMessages: [MessageId: Message] = [:]
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
                if chatLocation.peerId == peerIdValue {
                    cachedData = value
                }
            case let .cachedPeerDataMessages(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    if let value = value {
                        for (_, message) in value {
                            cachedDataMessages[message.id] = message
                        }
                    }
                }
            case let .message(_, messages):
                for message in messages {
                    cachedDataMessages[message.id] = message
                }
            case let .totalUnreadState(totalUnreadState):
            switch chatLocation {
            case let .peer(peerId):
                if let combinedReadStates = view.fixedReadStates {
                    if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                        readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalState: totalUnreadState, notificationSettings: notificationSettings)
                    }
                }
            case .replyThread, .feed:
                break
                }
            default:
                break
        }
    }
        
    return (cachedData, cachedDataMessages, readStateData)
}

struct ReplyThreadInfo {
    var message: ChatReplyThreadMessage
    var isChannelPost: Bool
    var isEmpty: Bool
    var scrollToLowerBoundMessage: MessageIndex?
    var contextHolder: Atomic<ChatLocationContextHolder?>
}

enum ReplyThreadSubject {
    case channelPost(MessageId)
    case groupMessage(MessageId)
}

func fetchAndPreloadReplyThreadInfo(context: AccountContext, subject: ReplyThreadSubject, atMessageId: MessageId?) -> Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError> {
    let message: Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError>
    switch subject {
    case .channelPost(let messageId), .groupMessage(let messageId):
        message = context.engine.messages.fetchChannelReplyThreadMessage(messageId: messageId, atMessageId: atMessageId)
    }
    
    return message
    |> mapToSignal { replyThreadMessage -> Signal<ReplyThreadInfo, FetchChannelReplyThreadMessageError> in
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        
        let input: ChatHistoryLocationInput
        var scrollToLowerBoundMessage: MessageIndex?
        switch replyThreadMessage.initialAnchor {
        case .automatic:
            if let atMessageId = atMessageId {
                input = ChatHistoryLocationInput(
                    content: .InitialSearch(location: .id(atMessageId), count: 40, highlight: true),
                    id: 0
                )
            } else {
                input = ChatHistoryLocationInput(
                    content: .Initial(count: 40),
                    id: 0
                )
            }
        case let .lowerBoundMessage(index):
            input = ChatHistoryLocationInput(
                content: .Navigation(index: .message(index), anchorIndex: .message(index), count: 40, highlight: false),
                id: 0
            )
            scrollToLowerBoundMessage = index
        }
        
        if replyThreadMessage.isNotAvailable {
            return .single(ReplyThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: false,
                scrollToLowerBoundMessage: nil,
                contextHolder: chatLocationContextHolder
            ))
        }
        
        let preloadSignal = preloadedChatHistoryViewForLocation(
            input,
            context: context,
            chatLocation: .replyThread(message: replyThreadMessage),
            subject: nil,
            chatLocationContextHolder: chatLocationContextHolder,
            fixedCombinedReadStates: nil,
            tagMask: nil,
            additionalData: []
        )
        return preloadSignal
        |> map { historyView -> Bool? in
            switch historyView {
            case .Loading:
                return nil
            case let .HistoryView(view, _, _, _, _, _, _):
                return view.entries.isEmpty
            }
        }
        |> mapToSignal { value -> Signal<Bool, NoError> in
            if let value = value {
                return .single(value)
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> map { isEmpty -> ReplyThreadInfo in
            return ReplyThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: isEmpty,
                scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                contextHolder: chatLocationContextHolder
            )
        }
        |> castError(FetchChannelReplyThreadMessageError.self)
    }
}
