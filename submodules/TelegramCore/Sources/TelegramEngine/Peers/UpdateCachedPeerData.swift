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
            
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                return .single(false)
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
                            peerStatusSettings = PeerStatusSettings(flags: [], managingBot: nil)
                        } else {
                            peerStatusSettings = PeerStatusSettings(flags: [.canReport], managingBot: nil)
                        }
                    } else {
                        peerStatusSettings = PeerStatusSettings(flags: [], managingBot: nil)
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
                |> retryRequestIfNotFrozen
                |> mapToSignal { peerSettings -> Signal<Bool, NoError> in
                    guard let peerSettings else {
                        return .single(false)
                    }
                    return postbox.transaction { transaction -> Bool in
                        let parsedPeers: AccumulatedPeers
                        
                        let peerStatusSettings: PeerStatusSettings
                        switch peerSettings {
                        case let .peerSettings(settings, chats, users):
                            peerStatusSettings = PeerStatusSettings(apiSettings: settings)
                            parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        }
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
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
                return (.inputUserSelf, rawPeer, rawPeerId)
            } else {
                return (apiInputUser(peer), peer, peer.id)
            }
        }
        |> mapToSignal { inputUser, maybePeer, peerId -> Signal<Bool, NoError> in
            if let inputUser = inputUser {
                let editableBotInfo: Signal<EditableBotInfo?, NoError>
                if let user = maybePeer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    let flags: Int32 = (1 << 0)
                    editableBotInfo = network.request(Api.functions.bots.getBotInfo(flags: flags, bot: inputUser, langCode: ""))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.bots.BotInfo?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<EditableBotInfo?, NoError> in
                        if let result = result {
                            switch result {
                            case let .botInfo(name, about, description):
                                return .single(EditableBotInfo(name: name, about: about, description: description))
                            }
                        } else {
                            return .single(nil)
                        }
                    }
                } else {
                    editableBotInfo = .single(nil)
                }
                
                let botPreview: Signal<CachedUserData.BotPreview?, NoError>
                if let user = maybePeer as? TelegramUser, let botInfo = user.botInfo {
                    if botInfo.flags.contains(.canEdit) {
                        botPreview = _internal_requestBotAdminPreview(network: network, peerId: user.id, inputUser: inputUser, language: nil)
                    } else {
                        botPreview = _internal_requestBotUserPreview(network: network, peerId: user.id, inputUser: inputUser)
                    }
                } else {
                    botPreview = .single(nil)
                }
                
                var additionalConnectedBots: Signal<Api.account.ConnectedBots?, NoError> = .single(nil)
                if rawPeerId == accountPeerId {
                    additionalConnectedBots = network.request(Api.functions.account.getConnectedBots())
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.account.ConnectedBots?, NoError> in
                        return .single(nil)
                    }
                }

                return combineLatest(
                    network.request(Api.functions.users.getFullUser(id: inputUser))
                    |> retryRequest,
                    editableBotInfo,
                    botPreview,
                    additionalConnectedBots
                )
                |> mapToSignal { result, editableBotInfo, botPreview, additionalConnectedBots -> Signal<Bool, NoError> in
                    return postbox.transaction { transaction -> Bool in
                        switch result {
                        case let .userFull(fullUser, chats, users):
                            var accountUser: Api.User?
                            var parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                            for user in users {
                                if user.peerId == accountPeerId {
                                    accountUser = user
                                }
                            }
                            let _ = accountUser
                            
                            var mappedConnectedBot: TelegramAccountConnectedBot?
                            
                            if let additionalConnectedBots {
                                switch additionalConnectedBots {
                                case let .connectedBots(connectedBots, users):
                                    parsedPeers = parsedPeers.union(with: AccumulatedPeers(transaction: transaction, chats: [], users: users))
                                    
                                    if let apiBot = connectedBots.first {
                                        switch apiBot {
                                        case let .connectedBot(_, botId, recipients, rights):
                                            mappedConnectedBot = TelegramAccountConnectedBot(
                                                id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)),
                                                recipients: TelegramBusinessRecipients(apiValue: recipients),
                                                rights: TelegramBusinessBotRights(apiValue: rights)
                                            )
                                        }
                                    }
                                }
                            }
                            
                            switch fullUser {
                            case let .userFull(_, _, _, _, _, _, _, _, userFullNotifySettings, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                                transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: userFullNotifySettings)])
                            }
                            transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                switch fullUser {
                                    case let .userFull(userFullFlags, userFullFlags2, _, userFullAbout, userFullSettings, personalPhoto, profilePhoto, fallbackPhoto, _, userFullBotInfo, userFullPinnedMsgId, userFullCommonChatsCount, _, userFullTtlPeriod, userFullThemeEmoticon, _, groupAdminRights, channelAdminRights, userWallpaper, _, businessWorkHours, businessLocation, greetingMessage, awayMessage, businessIntro, birthday, personalChannelId, personalChannelMessage, starGiftsCount, starRefProgram, verification, sendPaidMessageStars, disallowedStarGifts):
                                        let botInfo = userFullBotInfo.flatMap(BotInfo.init(apiBotInfo:))
                                        let isBlocked = (userFullFlags & (1 << 0)) != 0
                                        let voiceCallsAvailable = (userFullFlags & (1 << 4)) != 0
                                        let videoCallsAvailable = (userFullFlags & (1 << 13)) != 0
                                        let voiceMessagesAvailable = (userFullFlags & (1 << 20)) == 0
                                        let readDatesPrivate = (userFullFlags & (1 << 30)) != 0
                                        let premiumRequired = (userFullFlags & (1 << 29)) != 0
                                        let translationsDisabled = (userFullFlags & (1 << 23)) != 0
                                        let adsEnabled = (userFullFlags2 & (1 << 7)) != 0
                                        let canViewRevenue = (userFullFlags2 & (1 << 9)) != 0
                                        let botCanManageEmojiStatus = (userFullFlags2 & (1 << 10)) != 0
                                        let displayGiftButton = (userFullFlags2 & (1 << 16)) != 0
                                    
                                        var flags: CachedUserFlags = previous.flags
                                        if premiumRequired {
                                            flags.insert(.premiumRequired)
                                        } else {
                                            flags.remove(.premiumRequired)
                                        }
                                        if readDatesPrivate {
                                            flags.insert(.readDatesPrivate)
                                        } else {
                                            flags.remove(.readDatesPrivate)
                                        }
                                        if translationsDisabled {
                                            flags.insert(.translationHidden)
                                        } else {
                                            flags.remove(.translationHidden)
                                        }
                                        if adsEnabled {
                                            flags.insert(.adsEnabled)
                                        } else {
                                            flags.remove(.adsEnabled)
                                        }
                                        if canViewRevenue {
                                            flags.insert(.canViewRevenue)
                                        } else {
                                            flags.remove(.canViewRevenue)
                                        }
                                        if botCanManageEmojiStatus {
                                            flags.insert(.botCanManageEmojiStatus)
                                        } else {
                                            flags.remove(.botCanManageEmojiStatus)
                                        }
                                        if displayGiftButton {
                                            flags.insert(.displayGiftButton)
                                        } else {
                                            flags.remove(.displayGiftButton)
                                        }
                                    
                                        let callsPrivate = (userFullFlags & (1 << 5)) != 0
                                        let canPinMessages = (userFullFlags & (1 << 7)) != 0
                                        let pinnedMessageId = userFullPinnedMsgId.flatMap({ MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) })
                                    
                                        let peerStatusSettings = PeerStatusSettings(apiSettings: userFullSettings)
                                        
                                        let hasScheduledMessages = (userFullFlags & 1 << 12) != 0
                                        
                                        let autoremoveTimeout: CachedPeerAutoremoveTimeout = .known(CachedPeerAutoremoveTimeout.Value(userFullTtlPeriod))
                                    
                                        let personalPhoto = personalPhoto.flatMap { telegramMediaImageFromApiPhoto($0) }
                                        let photo = profilePhoto.flatMap { telegramMediaImageFromApiPhoto($0) }
                                        let fallbackPhoto = fallbackPhoto.flatMap { telegramMediaImageFromApiPhoto($0) }
                                                                        
                                        let wallpaper = userWallpaper.flatMap { TelegramWallpaper(apiWallpaper: $0) }
                                    
                                        var mappedBusinessHours: TelegramBusinessHours?
                                        if let businessWorkHours {
                                            mappedBusinessHours = TelegramBusinessHours(apiWorkingHours: businessWorkHours)
                                        }
                                        
                                        var mappedBusinessLocation: TelegramBusinessLocation?
                                        if let businessLocation {
                                            mappedBusinessLocation = TelegramBusinessLocation(apiLocation: businessLocation)
                                        }
                                    
                                        var mappedGreetingMessage: TelegramBusinessGreetingMessage?
                                        if let greetingMessage {
                                            mappedGreetingMessage = TelegramBusinessGreetingMessage(apiGreetingMessage: greetingMessage)
                                        }
                                    
                                        var mappedAwayMessage: TelegramBusinessAwayMessage?
                                        if let awayMessage {
                                            mappedAwayMessage = TelegramBusinessAwayMessage(apiAwayMessage: awayMessage)
                                        }
                                    
                                        var mappedBusinessIntro: TelegramBusinessIntro?
                                        if let businessIntro {
                                            mappedBusinessIntro = TelegramBusinessIntro(apiBusinessIntro: businessIntro)
                                        }
                                    
                                        var mappedBirthday: TelegramBirthday?
                                        if let birthday {
                                            mappedBirthday = TelegramBirthday(apiBirthday: birthday)
                                        }
                                    
                                        var personalChannel: TelegramPersonalChannel?
                                        if let personalChannelId {
                                            let channelPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(personalChannelId))
                                            
                                            var subscriberCount: Int32?
                                            for chat in chats {
                                                if chat.peerId == channelPeerId {
                                                    if case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _) = chat {
                                                        subscriberCount = participantsCount
                                                    }
                                                }
                                            }
                                            
                                            personalChannel = TelegramPersonalChannel(
                                                peerId: channelPeerId,
                                                subscriberCount: subscriberCount,
                                                topMessageId: personalChannelMessage
                                            )
                                        }
                                    
                                        var mappedStarRefProgram: TelegramStarRefProgram?
                                        if let starRefProgram {
                                            mappedStarRefProgram = TelegramStarRefProgram(apiStarRefProgram: starRefProgram)
                                        }
                                    
                                        let verification = verification.flatMap { PeerVerification(apiBotVerification: $0) }
                                        
                                        let sendPaidMessageStars = sendPaidMessageStars.flatMap { StarsAmount(value: $0, nanos: 0) }
                                    
                                        var disallowedGifts: TelegramDisallowedGifts = []
                                        if case let .disallowedGiftsSettings(giftFlags) = disallowedStarGifts {
                                            if (giftFlags & (1 << 0)) != 0 {
                                                disallowedGifts.insert(.unlimited)
                                            }
                                            if (giftFlags & (1 << 1)) != 0 {
                                                disallowedGifts.insert(.limited)
                                            }
                                            if (giftFlags & (1 << 2)) != 0 {
                                                disallowedGifts.insert(.unique)
                                            }
                                            if (giftFlags & (1 << 3)) != 0 {
                                                disallowedGifts.insert(.premium)
                                            }
                                        }
                                    
                                        let botGroupAdminRights = groupAdminRights.flatMap { TelegramChatAdminRights(apiAdminRights: $0) }
                                        let botChannelAdminRights = channelAdminRights.flatMap { TelegramChatAdminRights(apiAdminRights: $0) }
                                    
                                        return previous.withUpdatedAbout(userFullAbout)
                                            .withUpdatedBotInfo(botInfo)
                                            .withUpdatedEditableBotInfo(editableBotInfo)
                                            .withUpdatedCommonGroupCount(userFullCommonChatsCount)
                                            .withUpdatedIsBlocked(isBlocked)
                                            .withUpdatedVoiceCallsAvailable(voiceCallsAvailable)
                                            .withUpdatedVideoCallsAvailable(videoCallsAvailable)
                                            .withUpdatedCallsPrivate(callsPrivate)
                                            .withUpdatedCanPinMessages(canPinMessages)
                                            .withUpdatedPeerStatusSettings(peerStatusSettings)
                                            .withUpdatedPinnedMessageId(pinnedMessageId)
                                            .withUpdatedHasScheduledMessages(hasScheduledMessages)
                                            .withUpdatedAutoremoveTimeout(autoremoveTimeout)
                                            .withUpdatedThemeEmoticon(userFullThemeEmoticon)
                                            .withUpdatedPhoto(.known(photo))
                                            .withUpdatedPersonalPhoto(.known(personalPhoto))
                                            .withUpdatedFallbackPhoto(.known(fallbackPhoto))
                                            .withUpdatedVoiceMessagesAvailable(voiceMessagesAvailable)
                                            .withUpdatedWallpaper(wallpaper)
                                            .withUpdatedFlags(flags)
                                            .withUpdatedBusinessHours(mappedBusinessHours)
                                            .withUpdatedBusinessLocation(mappedBusinessLocation)
                                            .withUpdatedGreetingMessage(mappedGreetingMessage)
                                            .withUpdatedAwayMessage(mappedAwayMessage)
                                            .withUpdatedConnectedBot(mappedConnectedBot)
                                            .withUpdatedBusinessIntro(mappedBusinessIntro)
                                            .withUpdatedBirthday(mappedBirthday)
                                            .withUpdatedPersonalChannel(personalChannel)
                                            .withUpdatedBotPreview(botPreview)
                                            .withUpdatedStarGiftsCount(starGiftsCount)
                                            .withUpdatedStarRefProgram(mappedStarRefProgram)
                                            .withUpdatedVerification(verification)
                                            .withUpdatedSendPaidMessageStars(sendPaidMessageStars)
                                            .withUpdatedDisallowedGifts(disallowedGifts)
                                            .withUpdatedBotGroupAdminRights(botGroupAdminRights)
                                            .withUpdatedBotChannelAdminRights(botChannelAdminRights)
                                }
                            })
                        }
                        return true
                    }
                }
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                return network.request(Api.functions.messages.getFullChat(chatId: peerId.id._internalGetInt64Value()))
                |> retryRequestIfNotFrozen
                |> mapToSignal { result -> Signal<Bool, NoError> in
                    guard let result else {
                        return .single(false)
                    }
                    return postbox.transaction { transaction -> Bool in
                        switch result {
                        case let .chatFull(fullChat, chats, users):
                            switch fullChat {
                            case let .chatFull(_, _, _, _, _, notifySettings, _, _, _, _, _, _, _, _, _, _, _, _):
                                transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                            case .channelFull:
                                break
                            }
                            
                            switch fullChat {
                            case let .chatFull(chatFullFlags, _, chatFullAbout, chatFullParticipants, chatFullChatPhoto, _, chatFullExportedInvite, chatFullBotInfo, chatFullPinnedMsgId, _, chatFullCall, chatTtlPeriod, chatFullGroupcallDefaultJoinAs, chatFullThemeEmoticon, chatFullRequestsPending, _, allowedReactions, reactionsLimit):
                                var botInfos: [CachedPeerBotInfo] = []
                                for botInfo in chatFullBotInfo ?? [] {
                                    switch botInfo {
                                    case let .botInfo(_, userId, _, _, _, _, _, _, _, _):
                                        if let userId = userId {
                                            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                            let parsedBotInfo = BotInfo(apiBotInfo: botInfo)
                                            botInfos.append(CachedPeerBotInfo(peerId: peerId, botInfo: parsedBotInfo))
                                        }
                                    }
                                }
                                let participants = CachedGroupParticipants(apiParticipants: chatFullParticipants)
                                
                                let autoremoveTimeout: CachedPeerAutoremoveTimeout = .known(CachedPeerAutoremoveTimeout.Value(chatTtlPeriod))
                                
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
                            
                                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                                
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
                                        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
                                            break
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
                                    
                                    let mappedReactionSettings = PeerReactionSettings(allowedReactions: mappedAllowedReactions, maxReactionCount: reactionsLimit, starsAllowed: nil)
                                    
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
                                        .withUpdatedAutoremoveTimeout(autoremoveTimeout)
                                        .withUpdatedReactionSettings(.known(mappedReactionSettings))
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
                
                
                let participantSignal: Signal<Api.channels.ChannelParticipant?, NoError>
                if let channel = maybePeer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                    participantSignal = .single(nil)
                } else {
                    participantSignal = network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
                    |> map(Optional.init)
                    |> `catch` { error -> Signal<Api.channels.ChannelParticipant?, NoError> in
                        return .single(nil)
                    }
                }
                
                return combineLatest(fullChannelSignal, participantSignal)
                |> mapToSignal { result, participantResult -> Signal<Bool, NoError> in
                    return postbox.transaction { transaction -> Bool in
                        if let result = result {
                            switch result {
                                case let .chatFull(fullChat, chats, users):
                                    switch fullChat {
                                    case let .channelFull(_, _, _, _, _, _, _, _, _, _, _, _, _, notifySettings, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                                        transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                                    case .chatFull:
                                        break
                                    }
                                    
                                    switch fullChat {
                                        case let .channelFull(flags, flags2, _, about, participantsCount, adminsCount, kickedCount, bannedCount, _, _, _, _, chatPhoto, _, apiExportedInvite, apiBotInfos, migratedFromChatId, migratedFromMaxId, pinnedMsgId, stickerSet, minAvailableMsgId, _, linkedChatId, location, slowmodeSeconds, slowmodeNextSendDate, statsDc, _, inputCall, ttl, pendingSuggestions, groupcallDefaultJoinAs, themeEmoticon, requestsPending, _, defaultSendAs, allowedReactions, reactionsLimit, _, wallpaper, appliedBoosts, boostsUnrestrict, emojiSet, verification, starGiftsCount, sendPaidMessageStars):
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
                                            if (flags2 & Int32(1 << 1)) != 0 {
                                                channelFlags.insert(.antiSpamEnabled)
                                            }
                                            if (flags2 & Int32(1 << 3)) != 0 {
                                                channelFlags.insert(.translationHidden)
                                            }
                                            if (flags2 & Int32(1 << 11)) != 0 {
                                                channelFlags.insert(.adsRestricted)
                                            }
                                            if (flags2 & Int32(1 << 12)) != 0 {
                                                channelFlags.insert(.canViewRevenue)
                                            }
                                            if (flags2 & Int32(1 << 14)) != 0 {
                                                channelFlags.insert(.paidMediaAllowed)
                                            }
                                            if (flags2 & Int32(1 << 15)) != 0 {
                                                channelFlags.insert(.canViewStarsRevenue)
                                            }
                                            if (flags2 & Int32(1 << 19)) != 0 {
                                                channelFlags.insert(.starGiftsAvailable)
                                            }
                                            if (flags2 & Int32(1 << 20)) != 0 {
                                                channelFlags.insert(.paidMessagesAvailable)
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
                                                case let .botInfo(_, userId, _, _, _, _, _, _, _, _):
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
                                            
                                            var parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                                            
                                            if let participantResult = participantResult {
                                                switch participantResult {
                                                case let .channelParticipant(_, chats, users):
                                                    parsedPeers = parsedPeers.union(with: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                                                }
                                            }
                                            
                                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                                            
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
                                                    case let .channelParticipantSelf(flags, _, inviterId, invitedDate, _):
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
                                        
                                            let emojiPack: StickerPackCollectionInfo? = emojiSet.flatMap { apiSet -> StickerPackCollectionInfo in
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
                                                    case .inputGroupCallSlug, .inputGroupCallInviteMessage:
                                                        break
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
                                                let starsAllowed: Bool = (flags2 & (1 << 16)) != 0
                                                let mappedReactionSettings = PeerReactionSettings(allowedReactions: mappedAllowedReactions, maxReactionCount: reactionsLimit, starsAllowed: starsAllowed)
                                                
                                                let membersHidden = (flags2 & (1 << 2)) != 0
                                                let forumViewAsMessages = (flags2 & (1 << 6)) != 0
                                                
                                                let wallpaper = wallpaper.flatMap { TelegramWallpaper(apiWallpaper: $0) }
                                                
                                                let verification = verification.flatMap { PeerVerification(apiBotVerification: $0) }
                                                
                                                let parsedSendPaidMessageStars = sendPaidMessageStars.flatMap { StarsAmount(value: $0, nanos: 0) }
                                                                                                
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
                                                    .withUpdatedReactionSettings(.known(mappedReactionSettings))
                                                    .withUpdatedMembersHidden(.known(PeerMembersHidden(value: membersHidden)))
                                                    .withUpdatedViewForumAsMessages(.known(forumViewAsMessages))
                                                    .withUpdatedWallpaper(wallpaper)
                                                    .withUpdatedBoostsToUnrestrict(boostsUnrestrict)
                                                    .withUpdatedAppliedBoosts(appliedBoosts)
                                                    .withUpdatedEmojiPack(emojiPack)
                                                    .withUpdatedVerification(verification)
                                                    .withUpdatedStarGiftsCount(starGiftsCount)
                                                    .withUpdatedSendPaidMessageStars(parsedSendPaidMessageStars)
                                            })
                                        
                                            if let minAvailableMessageId = minAvailableMessageId, minAvailableMessageIdUpdated {
                                                var resourceIds: [MediaResourceId] = []
                                                transaction.deleteMessagesInRange(peerId: peerId, namespace: minAvailableMessageId.namespace, minId: 1, maxId: minAvailableMessageId.id, forEachMedia: { media in
                                                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                                                })
                                                if !resourceIds.isEmpty {
                                                    let _ = postbox.mediaBox.removeCachedResources(Array(Set(resourceIds))).start()
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

func _internal_requestBotAdminPreview(network: Network, peerId: PeerId, inputUser: Api.InputUser, language: String?) -> Signal<CachedUserData.BotPreview?, NoError> {
    return network.request(Api.functions.bots.getPreviewInfo(bot: inputUser, langCode: language ?? ""))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.bots.PreviewInfo?, NoError> in
        return .single(nil)
    }
    |> map { result -> CachedUserData.BotPreview? in
        guard let result else {
            return nil
        }
        switch result {
        case let .previewInfo(media, langCodes):
            return CachedUserData.BotPreview(
                items: media.compactMap { item -> CachedUserData.BotPreview.Item? in
                    switch item {
                    case let .botPreviewMedia(date, media):
                        let value = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                        if let media = value.media {
                            return CachedUserData.BotPreview.Item(media: media, timestamp: date)
                        } else {
                            return nil
                        }
                    }
                },
                alternativeLanguageCodes: langCodes
            )
        }
    }
}

func _internal_requestBotUserPreview(network: Network, peerId: PeerId, inputUser: Api.InputUser) -> Signal<CachedUserData.BotPreview?, NoError> {
    return network.request(Api.functions.bots.getPreviewMedias(bot: inputUser))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.BotPreviewMedia]?, NoError> in
        return .single(nil)
    }
    |> map { result -> CachedUserData.BotPreview? in
        guard let result else {
            return nil
        }
        return CachedUserData.BotPreview(
            items: result.compactMap { item -> CachedUserData.BotPreview.Item? in
                switch item {
                case let .botPreviewMedia(date, media):
                    let value = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                    if let media = value.media {
                        return CachedUserData.BotPreview.Item(media: media, timestamp: date)
                    } else {
                        return nil
                    }
                }
            },
            alternativeLanguageCodes: []
        )
    }
}
