import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private func messageFilterForTagMask(_ tagMask: MessageTags) -> Api.MessagesFilter? {
    if tagMask == .photoOrVideo {
        return Api.MessagesFilter.inputMessagesFilterPhotoVideo
    } else if tagMask == .file {
        return Api.MessagesFilter.inputMessagesFilterDocument
    } else if tagMask == .music {
        return Api.MessagesFilter.inputMessagesFilterMusic
    } else if tagMask == .webPage {
        return Api.MessagesFilter.inputMessagesFilterUrl
    } else if tagMask == .voiceOrInstantVideo {
        return Api.MessagesFilter.inputMessagesFilterRoundVoice
    } else {
        return nil
    }
}

enum FetchMessageHistoryHoleSource {
    case network(Network)
    case download(Download)
    
    func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>)) -> Signal<T, MTRpcError> {
        switch self {
            case let .network(network):
                return network.request(data)
            case let .download(download):
                return download.request(data)
        }
    }
}

func withResolvedAssociatedMessages(postbox: Postbox, source: FetchMessageHistoryHoleSource, storeMessages: [StoreMessage], _ f: @escaping (Transaction, [Peer], [StoreMessage]) -> Void) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var storedIds = Set<MessageId>()
        var referencedIds = Set<MessageId>()
        for message in storeMessages {
            guard case let .Id(id) = message.id else {
                continue
            }
            storedIds.insert(id)
            for attribute in message.attributes {
                referencedIds.formUnion(attribute.associatedMessageIds)
            }
        }
        referencedIds.subtract(storedIds)
        referencedIds = transaction.filterStoredMessageIds(referencedIds)
        
        if referencedIds.isEmpty {
            f(transaction, [], [])
            return .complete()
        } else {
            var signals: [Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>] = []
            for (peerId, messageIds) in messagesIdsGroupedByPeerId(referencedIds) {
                if let peer = transaction.getPeer(peerId) {
                    var signal: Signal<Api.messages.Messages, MTRpcError>?
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                        signal = source.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = source.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal
                        |> map { result in
                            switch result {
                                case let .messages(messages, chats, users):
                                    return (messages, chats, users)
                                case let .messagesSlice(_, messages, chats, users):
                                    return (messages, chats, users)
                                case let .channelMessages(_, _, _, messages, chats, users):
                                    return (messages, chats, users)
                                case .messagesNotModified:
                                    return ([], [], [])
                            }
                        }
                        |> `catch` { _ in
                            return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                        })
                    }
                }
            }
            
            let fetchMessages = combineLatest(signals)
            
            return fetchMessages
            |> mapToSignal { results -> Signal<Void, NoError> in
                var additionalPeers: [Peer] = []
                var additionalMessages: [StoreMessage] = []
                for (messages, chats, users) in results {
                    if !messages.isEmpty {
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message) {
                                additionalMessages.append(message)
                            }
                        }
                    }
                    for chat in chats {
                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                            additionalPeers.append(peer)
                        }
                    }
                    for user in users {
                        additionalPeers.append(TelegramUser(user: user))
                    }
                }
                return postbox.transaction { transaction -> Void in
                    f(transaction, additionalPeers, additionalMessages)
                }
            }
        }
    }
    |> switchToLatest
}

func fetchMessageHistoryHole(accountPeerId: PeerId, source: FetchMessageHistoryHoleSource, postbox: Postbox, hole: MessageHistoryHole, direction: MessageHistoryViewRelativeHoleDirection, tagMask: MessageTags?, limit: Int = 100) -> Signal<Void, NoError> {
    assert(tagMask == nil || tagMask!.rawValue != 0)
    return postbox.stateView()
    |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
        if let state = view.state as? AuthorizedAccountState {
            return .single(state)
        } else {
            return .complete()
        }
    }
    |> take(1)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return postbox.loadedPeerWithId(hole.maxIndex.id.peerId)
        |> take(1)
        |> mapToSignal { peer in
            if let inputPeer = forceApiInputPeer(peer) {
                print("fetchMessageHistoryHole for \(peer.debugDisplayTitle) \(direction)")
                let request: Signal<Api.messages.Messages, MTRpcError>
                var maxIndexRequest: Signal<Api.messages.Messages?, MTRpcError> = .single(nil)
                var implicitelyFillHole = false
                if let tagMask = tagMask {
                    if tagMask == MessageTags.unseenPersonalMessage {
                        let offsetId: Int32
                        let addOffset: Int32
                        let selectedLimit = limit
                        let maxId: Int32
                        let minId: Int32
                        
                        switch direction {
                            case .UpperToLower:
                                offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                addOffset = 0
                                maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                minId = 1
                            case .LowerToUpper:
                                offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                                addOffset = Int32(-selectedLimit)
                                maxId = Int32.max
                                minId = hole.min - 1
                            case let .AroundId(id):
                                offsetId = id.id
                                addOffset = Int32(-selectedLimit / 2)
                                maxId = Int32.max
                                minId = 1
                            case let .AroundIndex(index):
                                offsetId = index.id.id
                                addOffset = Int32(-selectedLimit / 2)
                                maxId = Int32.max
                                minId = 1
                        }
                        request = source.request(Api.functions.messages.getUnreadMentions(peer: inputPeer, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                    } else if tagMask == .liveLocation {
                        let selectedLimit = limit
                        
                        switch direction {
                            case .UpperToLower:
                                implicitelyFillHole = true
                            default:
                                assertionFailure()
                        }
                        request = source.request(Api.functions.messages.getRecentLocations(peer: inputPeer, limit: Int32(selectedLimit), hash: 0))
                    } else if let filter = messageFilterForTagMask(tagMask) {
                        let offsetId: Int32
                        let addOffset: Int32
                        let selectedLimit = limit
                        let maxId: Int32
                        let minId: Int32
                        
                        switch direction {
                            case .UpperToLower:
                                offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                addOffset = 0
                                maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                minId = 1
                            case .LowerToUpper:
                                offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                                addOffset = Int32(-selectedLimit)
                                maxId = Int32.max
                                minId = hole.min - 1
                            case let .AroundId(id):
                                offsetId = id.id
                                addOffset = Int32(-selectedLimit / 2)
                                maxId = Int32.max
                                minId = 1
                            case let .AroundIndex(index):
                                offsetId = index.id.id
                                addOffset = Int32(-selectedLimit / 2)
                                maxId = Int32.max
                                minId = 1
                        }
                        request = source.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", fromId: nil, filter: filter, minDate: 0, maxDate: hole.maxIndex.timestamp, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: 0))
                    } else {
                        assertionFailure()
                        request = .never()
                    }
                } else {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = limit
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                        case .UpperToLower:
                            offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                            addOffset = 0
                            maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                            minId = 1
                        case .LowerToUpper:
                            offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = Int32.max
                            minId = hole.min - 1
                            if hole.maxIndex.timestamp == Int32.max {
                                let innerOffsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                let innerMaxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                maxIndexRequest = source.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: innerOffsetId, offsetDate: hole.maxIndex.timestamp, addOffset: 0, limit: 1, maxId: innerMaxId, minId: 1, hash: 0))
                                    |> map(Optional.init)
                            }
                        case let .AroundId(id):
                            offsetId = id.id
                            addOffset = Int32(-selectedLimit / 2)
                            maxId = Int32.max
                            minId = 1
                        case let .AroundIndex(index):
                            offsetId = index.id.id
                            addOffset = Int32(-selectedLimit / 2)
                            maxId = Int32.max
                            minId = 1
                    }
                    
                    request = source.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: hole.maxIndex.timestamp, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: 0))
                }
                
                return combineLatest(request |> retryRequest, maxIndexRequest |> retryRequest)
                |> mapToSignal { result, maxIndexResult in
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    var channelPts: Int32?
                    switch result {
                        case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .channelMessages(_, pts, _, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                            channelPts = pts
                        case .messagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    var updatedMaxIndex: MessageIndex?
                    if let maxIndexResult = maxIndexResult {
                        let maxIndexMessages: [Api.Message]
                        switch maxIndexResult {
                            case let .messages(apiMessages, _, _):
                                maxIndexMessages = apiMessages
                            case let .messagesSlice(_, apiMessages, _, _):
                                maxIndexMessages = apiMessages
                            case let .channelMessages(_, _, _, apiMessages, _, _):
                                maxIndexMessages = apiMessages
                            case .messagesNotModified:
                                maxIndexMessages = []
                        }
                        if !maxIndexMessages.isEmpty {
                            assert(maxIndexMessages.count == 1)
                            if let storeMessage = StoreMessage(apiMessage: maxIndexMessages[0]), case let .Id(id) = storeMessage.id {
                                updatedMaxIndex = MessageIndex(id: id, timestamp: storeMessage.timestamp)
                            }
                        }
                    }
                    
                    var storeMessages: [StoreMessage] = []
                    
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message) {
                            if let channelPts = channelPts {
                                var attributes = storeMessage.attributes
                                attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                            } else {
                                storeMessages.append(storeMessage)
                            }
                        }
                    }
                    
                    return withResolvedAssociatedMessages(postbox: postbox, source: source, storeMessages: storeMessages, { transaction, additionalPeers, additionalMessages in
                        let fillDirection: HoleFillDirection
                        switch direction {
                            case .UpperToLower:
                                fillDirection = .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: nil)
                            case .LowerToUpper:
                                fillDirection = .LowerToUpper(updatedMaxIndex: updatedMaxIndex, clippingMinIndex: nil)
                            case let .AroundId(id):
                                fillDirection = .AroundId(id, lowerComplete: false, upperComplete: false)
                            case let .AroundIndex(index):
                                fillDirection = .AroundId(index.id, lowerComplete: false, upperComplete: false)
                        }
                        
                        var completeFill = messages.count == 0 || implicitelyFillHole
                        if tagMask == .liveLocation {
                            completeFill = false
                        }
                        transaction.fillMultipleHoles(hole, fillType: HoleFill(complete: completeFill, direction: fillDirection), tagMask: tagMask, messages: storeMessages)
                        let _ = transaction.addMessages(additionalMessages, location: .Random)
                        
                        var peers: [Peer] = additionalPeers
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                        
                        print("fetchMessageHistoryHole for \(peer.debugDisplayTitle) done")
                        
                        return
                    })
                }
            } else {
                return .complete()
            }
        }
    }
}

func groupBoundaryPeer(_ peerId: PeerId, accountPeerId: PeerId) -> Api.Peer {
    switch peerId.namespace {
        case Namespaces.Peer.CloudUser:
            return Api.Peer.peerUser(userId: peerId.id)
        case Namespaces.Peer.CloudGroup:
            return Api.Peer.peerChat(chatId: peerId.id)
        case Namespaces.Peer.CloudChannel:
            return Api.Peer.peerChannel(channelId: peerId.id)
        default:
            return Api.Peer.peerUser(userId: accountPeerId.id)
    }
}

func fetchGroupFeedHole(source: FetchMessageHistoryHoleSource, accountPeerId: PeerId, postbox: Postbox, groupId: PeerGroupId, minIndex: MessageIndex, maxIndex: MessageIndex, direction: MessageHistoryViewRelativeHoleDirection, limit: Int = 100) -> Signal<Void, NoError> {
    /*feed*/
    return .complete()
    /*return postbox.transaction { transaction -> (Peer?, Peer?) in
            return (transaction.getPeer(minIndex.id.peerId), transaction.getPeer(maxIndex.id.peerId))
        }
        |> mapToSignal { lowerPeer, upperPeer in
            print("fetchGroupFeedHole for \(groupId)")
            
            let request: Signal<Api.messages.FeedMessages, MTRpcError>
            
            let offsetPosition: Api.FeedPosition?
            let addOffset: Int32
            let selectedLimit = limit
            var maxPositionAndClipIndex: (Api.FeedPosition, MessageIndex)?
            var minPositionAndClipIndex: (Api.FeedPosition, MessageIndex)?
            
            let lowerInputPeer: Api.Peer = groupBoundaryPeer(minIndex.id.peerId, accountPeerId: accountPeerId)
            let upperInputPeer: Api.Peer = groupBoundaryPeer(maxIndex.id.peerId, accountPeerId: accountPeerId)
            
            switch direction {
                case .UpperToLower:
                    let upperIndex = maxIndex.successor()
                    if upperIndex.timestamp != Int32.max {
                        offsetPosition = .feedPosition(date: min(upperIndex.timestamp, Int32.max - 1), peer: upperInputPeer, id: min(upperIndex.id.id, Int32.max - 1))
                        maxPositionAndClipIndex = (.feedPosition(date: min(upperIndex.timestamp, Int32.max - 1), peer: upperInputPeer, id: min(upperIndex.id.id, Int32.max - 1)), maxIndex)
                    } else {
                        offsetPosition = nil
                        maxPositionAndClipIndex = nil
                    }
                    addOffset = 0
                    //minPosition = .feedPosition(date: 1, peer: lowerInputPeer, id: 1)
                case .LowerToUpper:
                    let lowerIndex = minIndex.predecessor()
                    offsetPosition = .feedPosition(date: minIndex.timestamp, peer: lowerInputPeer, id: lowerIndex.id.id)
                    addOffset = Int32(-selectedLimit)
                    //maxPosition = .feedPosition(date: Int32.max, peer: emptyInputPeer, id: Int32.max)
                    minPositionAndClipIndex = (.feedPosition(date: minIndex.timestamp, peer: lowerInputPeer, id: max(0, minIndex.id.id - 1)), minIndex)
                case .AroundId:
                    preconditionFailure()
                case let .AroundIndex(index):
                    let upperIndex = maxIndex.successor()
                    let lowerIndex = minIndex.predecessor()
                    
                    offsetPosition = .feedPosition(date: index.timestamp, peer: groupBoundaryPeer(index.id.peerId, accountPeerId: accountPeerId), id: index.id.id)
                    addOffset = Int32(-selectedLimit / 2)
                    if maxIndex.timestamp <= Int32.max - 1 {
                        //maxPositionAndClipIndex = (.feedPosition(date: upperIndex.timestamp, peer: upperInputPeer, id: upperIndex.id.id), maxIndex)
                    }
                    if minIndex.timestamp >= 2 {
                        //minPositionAndClipIndex = (.feedPosition(date: lowerIndex.timestamp, peer: lowerInputPeer, id: lowerIndex.id.id), minIndex)
                    }
            }
            
            var flags: Int32 = 0
            if offsetPosition != nil {
                flags |= (1 << 0)
            }
            if maxPositionAndClipIndex != nil {
                flags |= (1 << 1)
            }
            if minPositionAndClipIndex != nil {
                flags |= (1 << 2)
            }
            
            request = source.request(Api.functions.channels.getFeed(flags: flags, feedId: groupId.rawValue, offsetPosition: offsetPosition, addOffset: addOffset, limit: Int32(selectedLimit), maxPosition: maxPositionAndClipIndex?.0, minPosition: minPositionAndClipIndex?.0, hash: 0))
            
            return request
                |> retryRequest
                |> mapToSignal { result in
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    var updatedMinIndex: MessageIndex?
                    var updatedMaxIndex: MessageIndex?
                    switch result {
                        case let .feedMessages(_, resultMaxPosition, resultMinPosition, _, apiMessages, apiChats, apiUsers):
                            if let resultMaxPosition = resultMaxPosition {
                                switch resultMaxPosition {
                                    case let .feedPosition(date, peer, id):
                                        let index = MessageIndex(id: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: date).successor()
                                        if index < maxIndex {
                                            updatedMaxIndex = index
                                        } else {
                                            //assertionFailure()
                                            updatedMaxIndex = maxIndex
                                        }
                                }
                            }
                            if let resultMinPosition = resultMinPosition {
                                switch resultMinPosition {
                                    case let .feedPosition(date, peer, id):
                                        let index = MessageIndex(id: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: date).predecessor()
                                        if index > minIndex {
                                            updatedMinIndex = index
                                        } else {
                                            //assertionFailure()
                                            updatedMinIndex = minIndex
                                        }
                                }
                            }
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case .feedMessagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    
                    return postbox.transaction { transaction in
                        var storeMessages: [StoreMessage] = []
                        
                        loop: for message in messages {
                            if let storeMessage = StoreMessage(apiMessage: message), let messageIndex = storeMessage.index {
                                if let minClipIndex = minPositionAndClipIndex?.1 {
                                    if messageIndex < minClipIndex {
                                        continue loop
                                    }
                                }
                                if let maxClipIndex = maxPositionAndClipIndex?.1 {
                                    if messageIndex > maxClipIndex {
                                        continue loop
                                    }
                                }
                                storeMessages.append(storeMessage)
                            }
                        }
                        
                        var complete = false
                        let fillDirection: HoleFillDirection
                        switch direction {
                            case .UpperToLower:
                                if updatedMinIndex == nil {
                                    complete = true
                                }
                                fillDirection = .UpperToLower(updatedMinIndex: nil, clippingMaxIndex: updatedMinIndex)
                            case .LowerToUpper:
                                if updatedMaxIndex == nil {
                                    complete = true
                                }
                                fillDirection = .LowerToUpper(updatedMaxIndex: nil, clippingMinIndex: updatedMaxIndex)
                            case let .AroundId(id):
                                fillDirection = .AroundId(id, lowerComplete: false, upperComplete: false)
                            case let .AroundIndex(index):
                                fillDirection = .AroundIndex(index, lowerComplete: updatedMinIndex == nil, upperComplete: updatedMaxIndex == nil, clippingMinIndex: updatedMinIndex, clippingMaxIndex: updatedMaxIndex)
                        }
                        
                        transaction.fillMultipleGroupFeedHoles(groupId: groupId, mainHoleMaxIndex: maxIndex, fillType: HoleFill(complete: messages.count == 0 || complete, direction: fillDirection), messages: storeMessages)
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        transaction.updatePeerPresences(peerPresences)
                        
                        print("fetchGroupFeedHole for \(groupId) done")
                        
                        return
                    }
            }
    }*/
}

func fetchChatListHole(postbox: Postbox, network: Network, accountPeerId: PeerId, groupId: PeerGroupId?, hole: ChatListHole) -> Signal<Void, NoError> {
    let location: FetchChatListLocation
    if let groupId = groupId {
        location = .group(groupId)
    } else {
        location = .general
    }
    return fetchChatList(postbox: postbox, network: network, location: location, upperBound: hole.index)
    |> mapToSignal { fetchedChats -> Signal<Void, NoError> in
        return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), storeMessages: fetchedChats.storeMessages, { transaction, additionalPeers, additionalMessages in
            for peer in fetchedChats.peers {
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated -> Peer in
                    return updated
                })
            }
            
            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: fetchedChats.peerPresences)
            transaction.updateCurrentPeerNotificationSettings(fetchedChats.notificationSettings)
            let _ = transaction.addMessages(fetchedChats.storeMessages, location: .UpperHistoryBlock)
            transaction.resetIncomingReadStates(fetchedChats.readStates)
            
            transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: fetchedChats.lowerNonPinnedIndex.flatMap(ChatListHole.init))
            
            for (feedGroupId, lowerIndex) in fetchedChats.feeds {
                if let hole = postbox.seedConfiguration.initializeChatListWithHole.groups {
                    transaction.replaceChatListHole(groupId: feedGroupId, index: hole.index, hole: lowerIndex.flatMap(ChatListHole.init))
                }
            }
            
            for (peerId, chatState) in fetchedChats.chatStates {
                if let chatState = chatState as? ChannelState {
                    if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                        transaction.setPeerChatState(peerId, state: current.withUpdatedPts(chatState.pts))
                    } else {
                        transaction.setPeerChatState(peerId, state: chatState)
                    }
                } else {
                    transaction.setPeerChatState(peerId, state: chatState)
                }
            }
            
            if let replacePinnedItemIds = fetchedChats.pinnedItemIds {
                transaction.setPinnedItemIds(replacePinnedItemIds)
            }
            
            for (peerId, summary) in fetchedChats.mentionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
            }
        })
    }
}

func fetchCallListHole(network: Network, postbox: Postbox, accountPeerId: PeerId, holeIndex: MessageIndex, limit: Int32 = 100) -> Signal<Void, NoError> {
    let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
    offset = single((holeIndex.timestamp, min(holeIndex.id.id, Int32.max - 1) + 1, Api.InputPeer.inputPeerEmpty), NoError.self)
    return offset
    |> mapToSignal { (timestamp, id, peer) -> Signal<Void, NoError> in
        let searchResult = network.request(Api.functions.messages.search(flags: 0, peer: .inputPeerEmpty, q: "", fromId: nil, filter: .inputMessagesFilterPhoneCalls(flags: 0), minDate: 0, maxDate: holeIndex.timestamp, offsetId: 0, addOffset: 0, limit: limit, maxId: holeIndex.id.id, minId: 0, hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            let messages: [Api.Message]
            let chats: [Api.Chat]
            let users: [Api.User]
            switch result {
                case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case .messagesNotModified:
                    messages = []
                    chats = []
                    users = []
            }
            return postbox.transaction { transaction -> Void in
                var storeMessages: [StoreMessage] = []
                var topIndex: MessageIndex?
                
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message) {
                        storeMessages.append(storeMessage)
                        if let index = storeMessage.index, topIndex == nil || index < topIndex! {
                            topIndex = index
                        }
                    }
                }
                
                var updatedIndex: MessageIndex?
                if let topIndex = topIndex {
                    updatedIndex = topIndex.predecessor()
                }
                
                transaction.replaceGlobalMessageTagsHole(globalTags: [.Calls, .MissedCalls], index: holeIndex, with: updatedIndex, messages: storeMessages)
                
                var peers: [Peer] = []
                var peerPresences: [PeerId: PeerPresence] = [:]
                for chat in chats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    if let presence = TelegramUserPresence(apiUser: user) {
                        peerPresences[telegramUser.id] = presence
                    }
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
            }
        }
        return searchResult
    }
}
