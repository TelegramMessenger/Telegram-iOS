import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func fetchAndUpdateSupplementalCachedPeerData(peerId rawPeerId: PeerId, accountPeerId: PeerId, network: Network, postbox: Postbox) -> Signal<Bool, NoError> {
    return postbox.combinedView(keys: [.basicPeer(rawPeerId)])
    |> mapToSignal { views -> Signal<Peer, NoError> in
        guard let view = views.views[.basicPeer(rawPeerId)] as? BasicPeerView else {
            return .complete()
        }
        guard let peer = view.peer else {
            return .complete()
        }
        return .single(peer)
    }
    |> take(1)
    |> mapToSignal { _ -> Signal<Bool, NoError> in
        return postbox.transaction { transaction -> Signal<Bool, NoError> in
            guard let rawPeer = transaction.getPeer(rawPeerId) else {
                return .single(false)
            }
            
            let peer: Peer
            if let secretChat = rawPeer as? TelegramSecretChat {
                guard let user = transaction.getPeer(secretChat.regularPeerId) else {
                    return .single(false)
                }
                peer = user
            } else {
                peer = rawPeer
            }
                
            let cachedData = transaction.getPeerCachedData(peerId: peer.id)
            
            if let cachedData = cachedData as? CachedUserData {
                if cachedData.peerStatusSettings != nil {
                    return .single(true)
                }
            } else if let cachedData = cachedData as? CachedGroupData {
                if cachedData.peerStatusSettings != nil {
                    return .single(true)
                }
            } else if let cachedData = cachedData as? CachedChannelData {
                if cachedData.peerStatusSettings != nil {
                    return .single(true)
                }
            } else if let cachedData = cachedData as? CachedSecretChatData {
                if cachedData.peerStatusSettings != nil {
                    return .single(true)
                }
            }
            
            if peer.id.namespace == Namespaces.Peer.SecretChat {
                return postbox.transaction { transaction -> Bool in
                    var peerStatusSettings: PeerStatusSettings
                    if let peer = transaction.getPeer(peer.id), let associatedPeerId = peer.associatedPeerId, !transaction.isPeerContact(peerId: associatedPeerId) {
                        if let peer = peer as? TelegramSecretChat, case .creator = peer.role {
                            peerStatusSettings = PeerStatusSettings(flags: [])
                        } else {
                            peerStatusSettings = PeerStatusSettings(flags: [.canReport])
                        }
                    } else {
                        peerStatusSettings = PeerStatusSettings(flags: [])
                    }
                    
                    transaction.updatePeerCachedData(peerIds: [peer.id], update: { peerId, current in
                        if let current = current as? CachedSecretChatData {
                            return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                        } else {
                            return CachedSecretChatData(peerStatusSettings: peerStatusSettings)
                        }
                    })
                    
                    return true
                }
            } else if let inputPeer = apiInputPeer(peer) {
                return network.request(Api.functions.messages.getPeerSettings(peer: inputPeer))
                |> retryRequest
                |> mapToSignal { peerSettings -> Signal<Bool, NoError> in
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    
                    let peerStatusSettings: PeerStatusSettings
                    switch peerSettings {
                        case let .peerSettings(settings, chats, users):
                            peerStatusSettings = PeerStatusSettings(apiSettings: settings)
                            for chat in chats {
                                if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                    peers.append(peer)
                                }
                            }
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                peerPresences[telegramUser.id] = user
                            }
                    }
   
                    return postbox.transaction { transaction -> Bool in
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                        
                        transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                            switch peer.id.namespace {
                                case Namespaces.Peer.CloudUser:
                                    let previous: CachedUserData
                                    if let current = current as? CachedUserData {
                                        previous = current
                                    } else {
                                        previous = CachedUserData()
                                    }
                                    return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                                case Namespaces.Peer.CloudGroup:
                                    let previous: CachedGroupData
                                    if let current = current as? CachedGroupData {
                                        previous = current
                                    } else {
                                        previous = CachedGroupData()
                                    }
                                    return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                                case Namespaces.Peer.CloudChannel:
                                    let previous: CachedChannelData
                                    if let current = current as? CachedChannelData {
                                        previous = current
                                    } else {
                                        previous = CachedChannelData()
                                    }
                                    return previous.withUpdatedPeerStatusSettings(peerStatusSettings)
                                default:
                                    break
                            }
                            return current
                        })
                        return true
                    }
                }
            } else {
                return .single(false)
            }
        }
        |> switchToLatest
    }
}

func _internal_fetchAndUpdateCachedPeerData(accountPeerId: PeerId, peerId rawPeerId: PeerId, network: Network, postbox: Postbox) -> Signal<Bool, NoError> {
    return postbox.combinedView(keys: [.basicPeer(rawPeerId)])
    |> mapToSignal { views -> Signal<Bool, NoError> in
        if accountPeerId == rawPeerId {
            return .single(true)
        }
        guard let view = views.views[.basicPeer(rawPeerId)] as? BasicPeerView else {
            return .complete()
        }
        guard let _ = view.peer else {
            return .complete()
        }
        return .single(true)
    }
    |> take(1)
    |> mapToSignal { _ -> Signal<Bool, NoError> in
        return postbox.transaction { transaction -> (Api.InputUser?, Peer?, PeerId) in
            guard let rawPeer = transaction.getPeer(rawPeerId) else {
                if rawPeerId == accountPeerId {
                    return (.inputUserSelf, transaction.getPeer(rawPeerId), rawPeerId)
                } else {
                    return (nil, nil, rawPeerId)
                }
            }
            
            let peer: Peer
            if let secretChat = rawPeer as? TelegramSecretChat {
                guard let user = transaction.getPeer(secretChat.regularPeerId) else {
                    return (nil, nil, rawPeerId)
                }
                peer = user
            } else {
                peer = rawPeer
            }
            
            if rawPeerId == accountPeerId {
                return (.inputUserSelf, transaction.getPeer(rawPeerId), rawPeerId)
            } else {
                return (apiInputUser(peer), peer, peer.id)
            }
        }
        |> mapToSignal { inputUser, maybePeer, peerId -> Signal<Bool, NoError> in
            if let inputUser = inputUser {
                return network.request(Api.functions.users.getFullUser(id: inputUser))
                |> retryRequest
                |> mapToSignal { result -> Signal<Bool, NoError> in
                    return postbox.transaction { transaction -> Bool in
                        switch result {
                        case let .userFull(fullUser, chats, users):
                            var accountUser: Api.User?
                            var peers: [Peer] = []
                            var peerPresences: [PeerId: Api.User] = [:]
                            for chat in chats {
                                if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                    peers.append(peer)
                                }
                            }
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                peerPresences[telegramUser.id] = user
                                if telegramUser.id == accountPeerId {
                                    accountUser = user
                                }
                            }
                            
                            switch fullUser {
                            case let .userFull(_, _, _, _, _, userFullNotifySettings, _, _, _, _, _, _, _, _, _, _):
                                updatePeers(transaction: transaction, peers: peers, update: { previous, updated -> Peer in
                                    if previous?.id == accountPeerId, let accountUser = accountUser, let user = TelegramUser.merge(previous as? TelegramUser, rhs: accountUser) {
                                        return user
                                    }
                                    return updated
                                })
                                transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: userFullNotifySettings)])
                                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                            }
                            transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                switch fullUser {
                                    case let .userFull(userFullFlags, _, userFullAbout, userFullSettings, profilePhoto, _, userFullBotInfo, userFullPinnedMsgId, userFullCommonChatsCount, _, userFullTtlPeriod, userFullThemeEmoticon, _, _, _, userPremiumGiftOptions):
                                        let botInfo = userFullBotInfo.flatMap(BotInfo.init(apiBotInfo:))
                                        let isBlocked = (userFullFlags & (1 << 0)) != 0
                                        let voiceCallsAvailable = (userFullFlags & (1 << 4)) != 0
                                        let videoCallsAvailable = (userFullFlags & (1 << 13)) != 0
                                        let voiceMessagesAvailable = (userFullFlags & (1 << 20)) == 0
                                    
                                        let callsPrivate = (userFullFlags & (1 << 5)) != 0
                                        let canPinMessages = (userFullFlags & (1 << 7)) != 0
                                        let pinnedMessageId = userFullPinnedMsgId.flatMap({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) })
                                    

                                        let peerStatusSettings = PeerStatusSettings(apiSettings: userFullSettings)
                                        
                                        let hasScheduledMessages = (userFullFlags & 1 << 12) != 0
                                        
                                        let autoremoveTimeout: CachedPeerAutoremoveTimeout = .known(CachedPeerAutoremoveTimeout.Value(userFullTtlPeriod))
                                    
                                        let photo = profilePhoto.flatMap { telegramMediaImageFromApiPhoto($0) }
                                    
                                        let premiumGiftOptions: [CachedPremiumGiftOption]
                                        if let userPremiumGiftOptions = userPremiumGiftOptions {
                                            premiumGiftOptions = userPremiumGiftOptions.map { apiOption in
                                                let option: CachedPremiumGiftOption
                                                switch apiOption {
                                                    case let .premiumGiftOption(_, months, currency, amount, botUrl, storeProduct):
                                                        option = CachedPremiumGiftOption(months: months, currency: currency, amount: amount, botUrl: botUrl, storeProductId: storeProduct)
                                                }
                                                return option
                                            }
                                        } else {
                                            premiumGiftOptions = []
                                        }
                                    
                                        return previous.withUpdatedAbout(userFullAbout).withUpdatedBotInfo(botInfo).withUpdatedCommonGroupCount(userFullCommonChatsCount).withUpdatedIsBlocked(isBlocked).withUpdatedVoiceCallsAvailable(voiceCallsAvailable).withUpdatedVideoCallsAvailable(videoCallsAvailable).withUpdatedCallsPrivate(callsPrivate).withUpdatedCanPinMessages(canPinMessages).withUpdatedPeerStatusSettings(peerStatusSettings).withUpdatedPinnedMessageId(pinnedMessageId).withUpdatedHasScheduledMessages(hasScheduledMessages)
                                            .withUpdatedAutoremoveTimeout(autoremoveTimeout)
                                            .withUpdatedThemeEmoticon(userFullThemeEmoticon)
                                            .withUpdatedPhoto(photo)
                                            .withUpdatedPremiumGiftOptions(premiumGiftOptions)
                                            .withUpdatedVoiceMessagesAvailable(voiceMessagesAvailable)
                                }
                            })
                        }
                        return true
                    }
                }
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                return network.request(Api.functions.messages.getFullChat(chatId: peerId.id._internalGetInt64Value()))
                |> retryRequest
                |> mapToSignal { result -> Signal<Bool, NoError> in
                    return postbox.transaction { transaction -> Bool in
                        switch result {
                        case let .chatFull(fullChat, chats, users):
                            switch fullChat {
                            case let .chatFull(_, _, _, _, _, notifySettings, _, _, _, _, _, _, _, _, _, _, _):
                                transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                            case .channelFull:
                                break
                            }
                            
                            switch fullChat {
                            case let .chatFull(chatFullFlags, _, chatFullAbout, chatFullParticipants, chatFullChatPhoto, _, chatFullExportedInvite, chatFullBotInfo, chatFullPinnedMsgId, _, chatFullCall, _, chatFullGroupcallDefaultJoinAs, chatFullThemeEmoticon, chatFullRequestsPending, _, allowedReactions):
                                var botInfos: [CachedPeerBotInfo] = []
                                for botInfo in chatFullBotInfo ?? [] {
                                    switch botInfo {
                                    case let .botInfo(_, userId, _, _, _, _, _):
                                        if let userId = userId {
                                            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                            let parsedBotInfo = BotInfo(apiBotInfo: botInfo)
                                            botInfos.append(CachedPeerBotInfo(peerId: peerId, botInfo: parsedBotInfo))
                                        }
                                    }
                                }
                                let participants = CachedGroupParticipants(apiParticipants: chatFullParticipants)
                                
                                var invitedBy: PeerId?
                                if let participants = participants {
                                    for participant in participants.participants {
                                        if participant.peerId == accountPeerId {
                                            if participant.invitedBy != accountPeerId {
                                                invitedBy = participant.invitedBy
                                            }
                                            break
                                        }
                                    }
                                }
                                
                                let photo: TelegramMediaImage? = chatFullChatPhoto.flatMap(telegramMediaImageFromApiPhoto)
                                
                                let exportedInvitation = chatFullExportedInvite.flatMap { ExportedInvitation(apiExportedInvite: $0) }
                                let pinnedMessageId = chatFullPinnedMsgId.flatMap({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) })
                            
                                var peers: [Peer] = []
                                var peerPresences: [PeerId: Api.User] = [:]
                                for chat in chats {
                                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                        peers.append(groupOrChannel)
                                    }
                                }
                                for user in users {
                                    if let telegramUser = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                        peers.append(telegramUser)
                                        peerPresences[telegramUser.id] = user
                                    }
                                }
                                
                                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                    return updated
                                })
                                
                                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                                
                                var flags = CachedGroupFlags()
                                if (chatFullFlags & 1 << 7) != 0 {
                                    flags.insert(.canChangeUsername)
                                }
                                
                                var hasScheduledMessages = false
                                if (chatFullFlags & 1 << 8) != 0 {
                                    hasScheduledMessages = true
                                }
                                                                
                                let groupCallDefaultJoinAs = chatFullGroupcallDefaultJoinAs
                                
                                transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                                    let previous: CachedGroupData
                                    if let current = current as? CachedGroupData {
                                        previous = current
                                    } else {
                                        previous = CachedGroupData()
                                    }
                                    
                                    var updatedActiveCall: CachedChannelData.ActiveCall?
                                    if let inputCall = chatFullCall {
                                        switch inputCall {
                                        case let .inputGroupCall(id, accessHash):
                                            updatedActiveCall = CachedChannelData.ActiveCall(id: id, accessHash: accessHash, title: previous.activeCall?.title, scheduleTimestamp: previous.activeCall?.scheduleTimestamp, subscribedToScheduled: previous.activeCall?.subscribedToScheduled ?? false, isStream: previous.activeCall?.isStream)
                                        }
                                    }
                                    
                                    let mappedAllowedReactions: PeerAllowedReactions
                                    if let allowedReactions = allowedReactions {
                                        switch allowedReactions {
                                        case .chatReactionsAll:
                                            mappedAllowedReactions = .all
                                        case let .chatReactionsSome(reactions):
                                            mappedAllowedReactions = .limited(reactions.compactMap(MessageReaction.Reaction.init(apiReaction:)))
                                        case .chatReactionsNone:
                                            mappedAllowedReactions = .empty
                                        }
                                    } else {
                                        mappedAllowedReactions = .empty
                                    }
                                    
                                    return previous.withUpdatedParticipants(participants)
                                        .withUpdatedExportedInvitation(exportedInvitation)
                                        .withUpdatedBotInfos(botInfos)
                                        .withUpdatedPinnedMessageId(pinnedMessageId)
                                        .withUpdatedAbout(chatFullAbout)
                                        .withUpdatedFlags(flags)
                                        .withUpdatedHasScheduledMessages(hasScheduledMessages)
                                        .withUpdatedInvitedBy(invitedBy)
                                        .withUpdatedPhoto(photo)
                                        .withUpdatedActiveCall(updatedActiveCall)
                                        .withUpdatedCallJoinPeerId(groupCallDefaultJoinAs?.peerId)
                                        .withUpdatedThemeEmoticon(chatFullThemeEmoticon)
                                        .withUpdatedInviteRequestsPending(chatFullRequestsPending)
                                        .withUpdatedAllowedReactions(.known(mappedAllowedReactions))
                                })
                            case .channelFull:
                                break
                            }
                        }
                        return true
                    }
                }
            } else if let inputChannel = maybePeer.flatMap(apiInputChannel) {
                let fullChannelSignal = network.request(Api.functions.channels.getFullChannel(channel: inputChannel))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.messages.ChatFull?, NoError> in
                    if error.errorDescription == "CHANNEL_PRIVATE" {
                        return .single(nil)
                    }
                    return .single(nil)
                }
                let participantSignal = network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.channels.ChannelParticipant?, NoError> in
                    return .single(nil)
                }
                
                return combineLatest(fullChannelSignal, participantSignal)
                |> mapToSignal { result, participantResult -> Signal<Bool, NoError> in
                    return postbox.transaction { transaction -> Bool in
                        if let result = result {
                            switch result {
                                case let .chatFull(fullChat, chats, users):
                                    switch fullChat {
                                        case let .channelFull(_, _, _, _, _, _, _, _, _, _, _, _, _, notifySettings, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                                            transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                                        case .chatFull:
                                            break
                                    }
                                    
                                    switch fullChat {
                                        case let .channelFull(flags, flags2, _, about, participantsCount, adminsCount, kickedCount, bannedCount, _, _, _, _, chatPhoto, _, apiExportedInvite, apiBotInfos, migratedFromChatId, migratedFromMaxId, pinnedMsgId, stickerSet, minAvailableMsgId, _, linkedChatId, location, slowmodeSeconds, slowmodeNextSendDate, statsDc, _, inputCall, ttl, pendingSuggestions, groupcallDefaultJoinAs, themeEmoticon, requestsPending, _, defaultSendAs, allowedReactions):
                                            var channelFlags = CachedChannelFlags()
                                            if (flags & (1 << 3)) != 0 {
                                                channelFlags.insert(.canDisplayParticipants)
                                            }
                                            if (flags & (1 << 6)) != 0 {
                                                channelFlags.insert(.canChangeUsername)
                                            }
                                            if (flags & (1 << 10)) == 0 {
                                                channelFlags.insert(.preHistoryEnabled)
                                            }
                                            if (flags & (1 << 20)) != 0 {
                                                channelFlags.insert(.canViewStats)
                                            }
                                            if (flags & (1 << 7)) != 0 {
                                                channelFlags.insert(.canSetStickerSet)
                                            }
                                            if (flags & (1 << 16)) != 0 {
                                                channelFlags.insert(.canChangePeerGeoLocation)
                                            }
                                            if (flags2 & (1 << 0)) != 0 {
                                                channelFlags.insert(.canDeleteHistory)
                                            }
                                        
                                            let sendAsPeerId = defaultSendAs?.peerId
                                            
                                            let linkedDiscussionPeerId: PeerId?
                                            if let linkedChatId = linkedChatId, linkedChatId != 0 {
                                                linkedDiscussionPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(linkedChatId)))
                                            } else {
                                                linkedDiscussionPeerId = nil
                                            }

                                            let autoremoveTimeout: CachedPeerAutoremoveTimeout = .known(CachedPeerAutoremoveTimeout.Value(ttl))
                                           
                                            let peerGeoLocation: PeerGeoLocation?
                                            if let location = location {
                                                peerGeoLocation = PeerGeoLocation(apiLocation: location)
                                            } else {
                                                peerGeoLocation = nil
                                            }
                                            
                                            var botInfos: [CachedPeerBotInfo] = []
                                            for botInfo in apiBotInfos {
                                                switch botInfo {
                                                case let .botInfo(_, userId, _, _, _, _, _):
                                                    if let userId = userId {
                                                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                                        let parsedBotInfo = BotInfo(apiBotInfo: botInfo)
                                                        botInfos.append(CachedPeerBotInfo(peerId: peerId, botInfo: parsedBotInfo))
                                                    }
                                                }
                                            }
                                            
                                            var pinnedMessageId: MessageId?
                                            if let pinnedMsgId = pinnedMsgId {
                                                pinnedMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: pinnedMsgId)
                                            }
                                                                                        
                                            var minAvailableMessageId: MessageId?
                                            if let minAvailableMsgId = minAvailableMsgId {
                                                minAvailableMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: minAvailableMsgId)
                                                
                                                if let pinnedMsgId = pinnedMsgId, pinnedMsgId < minAvailableMsgId {
                                                    pinnedMessageId = nil
                                                }
                                            }
                                            
                                            var migrationReference: ChannelMigrationReference?
                                            if let migratedFromChatId = migratedFromChatId, let migratedFromMaxId = migratedFromMaxId {
                                                migrationReference = ChannelMigrationReference(maxMessageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(migratedFromChatId)), namespace: Namespaces.Message.Cloud, id: migratedFromMaxId))
                                            }
                                            
                                            var peers: [Peer] = []
                                            var peerPresences: [PeerId: Api.User] = [:]
                                            for chat in chats {
                                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                                    peers.append(groupOrChannel)
                                                }
                                            }
                                            for user in users {
                                                if let telegramUser = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                                    peers.append(telegramUser)
                                                    peerPresences[telegramUser.id] = user
                                                }
                                            }
                                            
                                            if let participantResult = participantResult {
                                                switch participantResult {
                                                case let .channelParticipant(_, chats, users):
                                                    for user in users {
                                                        if let telegramUser = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                                            peers.append(telegramUser)
                                                            peerPresences[telegramUser.id] = user
                                                        }
                                                    }
                                                    for chat in chats {
                                                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                                            peers.append(groupOrChannel)
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                                return updated
                                            })
                                            
                                            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                                            
                                            let stickerPack: StickerPackCollectionInfo? = stickerSet.flatMap { apiSet -> StickerPackCollectionInfo in
                                                let namespace: ItemCollectionId.Namespace
                                                switch apiSet {
                                                    case let .stickerSet(flags, _, _, _, _, _, _, _, _, _, _, _):
                                                        if (flags & (1 << 3)) != 0 {
                                                            namespace = Namespaces.ItemCollection.CloudMaskPacks
                                                        } else if (flags & (1 << 7)) != 0 {
                                                            namespace = Namespaces.ItemCollection.CloudEmojiPacks
                                                        } else {
                                                            namespace = Namespaces.ItemCollection.CloudStickerPacks
                                                        }
                                                }
                                                
                                                return StickerPackCollectionInfo(apiSet: apiSet, namespace: namespace)
                                            }
                                            
                                            var hasScheduledMessages = false
                                            if (flags & (1 << 19)) != 0 {
                                                hasScheduledMessages = true
                                            }
                                            
                                            var invitedBy: PeerId?
                                            var invitedOn: Int32?
                                            if let participantResult = participantResult {
                                                switch participantResult {
                                                case let .channelParticipant(participant, _, _):
                                                    switch participant {
                                                    case let .channelParticipantSelf(flags, _, inviterId, invitedDate):
                                                        invitedBy = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))
                                                        if (flags & (1 << 0)) != 0 {
                                                            invitedOn = invitedDate
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                            }
                                            
                                            let photo = telegramMediaImageFromApiPhoto(chatPhoto)
                                            
                                            var minAvailableMessageIdUpdated = false
                                            transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                                                var previous: CachedChannelData
                                                if let current = current as? CachedChannelData {
                                                    previous = current
                                                } else {
                                                    previous = CachedChannelData()
                                                }
                                                
                                                previous = previous.withUpdatedIsNotAccessible(false)
                                                
                                                minAvailableMessageIdUpdated = previous.minAvailableMessageId != minAvailableMessageId
                                                
                                                var updatedActiveCall: CachedChannelData.ActiveCall?
                                                if let inputCall = inputCall {
                                                    switch inputCall {
                                                    case let .inputGroupCall(id, accessHash):
                                                        updatedActiveCall = CachedChannelData.ActiveCall(id: id, accessHash: accessHash, title: previous.activeCall?.title, scheduleTimestamp: previous.activeCall?.scheduleTimestamp, subscribedToScheduled: previous.activeCall?.subscribedToScheduled ?? false, isStream: previous.activeCall?.isStream)
                                                    }
                                                }
                                                
                                                let mappedAllowedReactions: PeerAllowedReactions
                                                if let allowedReactions = allowedReactions {
                                                    switch allowedReactions {
                                                    case .chatReactionsAll:
                                                        mappedAllowedReactions = .all
                                                    case let .chatReactionsSome(reactions):
                                                        mappedAllowedReactions = .limited(reactions.compactMap(MessageReaction.Reaction.init(apiReaction:)))
                                                    case .chatReactionsNone:
                                                        mappedAllowedReactions = .empty
                                                    }
                                                } else {
                                                    mappedAllowedReactions = .empty
                                                }
                                                
                                                return previous.withUpdatedFlags(channelFlags)
                                                    .withUpdatedAbout(about)
                                                    .withUpdatedParticipantsSummary(CachedChannelParticipantsSummary(memberCount: participantsCount, adminCount: adminsCount, bannedCount: bannedCount, kickedCount: kickedCount))
                                                    .withUpdatedExportedInvitation(apiExportedInvite.flatMap { ExportedInvitation(apiExportedInvite: $0) })
                                                    .withUpdatedBotInfos(botInfos)
                                                    .withUpdatedPinnedMessageId(pinnedMessageId)
                                                    .withUpdatedStickerPack(stickerPack)
                                                    .withUpdatedMinAvailableMessageId(minAvailableMessageId)
                                                    .withUpdatedMigrationReference(migrationReference)
                                                    .withUpdatedLinkedDiscussionPeerId(.known(linkedDiscussionPeerId))
                                                    .withUpdatedPeerGeoLocation(peerGeoLocation)
                                                    .withUpdatedSlowModeTimeout(slowmodeSeconds)
                                                    .withUpdatedSlowModeValidUntilTimestamp(slowmodeNextSendDate)
                                                    .withUpdatedHasScheduledMessages(hasScheduledMessages)
                                                    .withUpdatedStatsDatacenterId(statsDc ?? 0)
                                                    .withUpdatedInvitedBy(invitedBy)
                                                    .withUpdatedInvitedOn(invitedOn)
                                                    .withUpdatedPhoto(photo)
                                                    .withUpdatedActiveCall(updatedActiveCall)
                                                    .withUpdatedCallJoinPeerId(groupcallDefaultJoinAs?.peerId)
                                                    .withUpdatedAutoremoveTimeout(autoremoveTimeout)
                                                    .withUpdatedPendingSuggestions(pendingSuggestions ?? [])
                                                    .withUpdatedThemeEmoticon(themeEmoticon)
                                                    .withUpdatedInviteRequestsPending(requestsPending)
                                                    .withUpdatedSendAsPeerId(sendAsPeerId)
                                                    .withUpdatedAllowedReactions(.known(mappedAllowedReactions))
                                            })
                                        
                                            if let minAvailableMessageId = minAvailableMessageId, minAvailableMessageIdUpdated {
                                                var resourceIds: [MediaResourceId] = []
                                                transaction.deleteMessagesInRange(peerId: peerId, namespace: minAvailableMessageId.namespace, minId: 1, maxId: minAvailableMessageId.id, forEachMedia: { media in
                                                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                                                })
                                                if !resourceIds.isEmpty {
                                                    let _ = postbox.mediaBox.removeCachedResources(Set(resourceIds)).start()
                                                }
                                            }
                                        case .chatFull:
                                            break
                                    }
                            }
                        } else {
                            transaction.updatePeerCachedData(peerIds: [peerId], update: { _, _ in
                                var updated = CachedChannelData()
                                updated = updated.withUpdatedIsNotAccessible(true)
                                return updated
                            })
                        }
                        return true
                    }
                }
            } else {
                return .single(false)
            }
        }
    }
}

extension CachedPeerAutoremoveTimeout.Value {
    init?(_ apiValue: Int32?) {
        if let value = apiValue {
            self.init(peerValue: value)
        } else {
            return nil
        }
    }
}
