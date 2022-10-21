import Foundation
import Postbox
import TelegramCore
import WatchCommon
import TelegramPresentationData
import LegacyUI
import PhoneNumberFormat

private func legacyImageLocationUri(resource: MediaResource) -> String? {
    if let resource = resource as? CloudPeerPhotoSizeMediaResource {
        return resource.id.stringRepresentation
    }
    return nil
}

func makePeerIdFromBridgeIdentifier(_ identifier: Int64) -> PeerId? {
    if identifier < 0 && identifier > Int32.min {
        return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(-identifier))
    } else if identifier < Int64(Int32.min) * 2 && identifier > Int64(Int32.min) * 3 {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(Int32.min) &* 2 &- identifier))
    } else if identifier > 0 && identifier < Int32.max {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(identifier))
    } else {
        return nil
    }
}

func makeBridgeIdentifier(_ peerId: PeerId) -> Int64 {
    switch peerId.namespace {
        case Namespaces.Peer.CloudGroup:
            return -Int64(peerId.id._internalGetInt64Value())
        case Namespaces.Peer.CloudChannel:
            return Int64(Int32.min) * 2 - Int64(peerId.id._internalGetInt64Value())
        default:
            return Int64(peerId.id._internalGetInt64Value())
    }
}

func makeBridgeDeliveryState(_ message: Message?) -> TGBridgeMessageDeliveryState {
    if let message = message {
        if message.flags.contains(.Failed) {
            return .failed
        }
        else if message.flags.contains(.Sending) {
            return .pending
        }
    }
    return .delivered
}

private func makeBridgeImage(_ image: TelegramMediaImage?) -> TGBridgeImageMediaAttachment? {
    if let image = image, let representation = largestImageRepresentation(image.representations) {
        let bridgeImage = TGBridgeImageMediaAttachment()
        bridgeImage.imageId = image.imageId.id
        bridgeImage.dimensions = representation.dimensions.cgSize
        return bridgeImage
    } else {
        return nil
    }
}

func makeBridgeDocument(_ file: TelegramMediaFile?) -> TGBridgeDocumentMediaAttachment? {
    if let file = file {
        let bridgeDocument = TGBridgeDocumentMediaAttachment()
        bridgeDocument.documentId = file.fileId.id
        bridgeDocument.fileSize = Int32(file.size ?? 0)
        for attribute in file.attributes {
            switch attribute {
                case let .FileName(fileName):
                    bridgeDocument.fileName = fileName
                case .Animated:
                    bridgeDocument.isAnimated = true
                case let .ImageSize(size):
                    bridgeDocument.imageSize = NSValue(cgSize: size.cgSize)
                case let .Sticker(displayText, packReference, _):
                    bridgeDocument.isSticker = true
                    bridgeDocument.stickerAlt = displayText
                    if let packReference = packReference, case let .id(id, accessHash) = packReference {
                        bridgeDocument.stickerPackId = id
                        bridgeDocument.stickerPackAccessHash = accessHash
                    }
                case let .Audio(_, duration, title, performer, _):
                    bridgeDocument.duration = Int32(clamping: duration)
                    bridgeDocument.title = title
                    bridgeDocument.performer = performer
                default:
                    break
            }
        }
        return bridgeDocument
    }
    return nil
}

func makeBridgeMedia(message: Message, strings: PresentationStrings, chatPeer: Peer? = nil, filterUnsupportedActions: Bool = true) -> [TGBridgeMediaAttachment] {
    var bridgeMedia: [TGBridgeMediaAttachment] = []
    
    if let forward = message.forwardInfo {
        let bridgeForward = TGBridgeForwardedMessageMediaAttachment()
        bridgeForward.peerId = forward.author.flatMap({ makeBridgeIdentifier($0.id) }) ?? 0
        if let sourceMessageId = forward.sourceMessageId {
            bridgeForward.mid = sourceMessageId.id
        }
        bridgeForward.date = forward.date
        bridgeMedia.append(bridgeForward)
    }
    
    for attribute in message.attributes {
        if let reply = attribute as? ReplyMessageAttribute, let replyMessage = message.associatedMessages[reply.messageId] {
            let bridgeReply = TGBridgeReplyMessageMediaAttachment()
            bridgeReply.mid = reply.messageId.id
            bridgeReply.message = makeBridgeMessage(replyMessage, strings: strings)
            bridgeMedia.append(bridgeReply)
        } else if let entities = attribute as? TextEntitiesMessageAttribute {
            var bridgeEntities: [Any] = []
            for entity in entities.entities {
                var bridgeEntity: TGBridgeMessageEntity? = nil
                switch entity.type {
                    case .Url:
                        bridgeEntity = TGBridgeMessageEntityUrl()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .TextUrl:
                        bridgeEntity = TGBridgeMessageEntityTextUrl()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Email:
                        bridgeEntity = TGBridgeMessageEntityEmail()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Mention:
                        bridgeEntity = TGBridgeMessageEntityMention()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Hashtag:
                        bridgeEntity = TGBridgeMessageEntityHashtag()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .BotCommand:
                        bridgeEntity = TGBridgeMessageEntityBotCommand()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Bold:
                        bridgeEntity = TGBridgeMessageEntityBold()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Italic:
                        bridgeEntity = TGBridgeMessageEntityItalic()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Code:
                        bridgeEntity = TGBridgeMessageEntityCode()
                        bridgeEntity?.range = NSRange(entity.range)
                    case .Pre:
                        bridgeEntity = TGBridgeMessageEntityPre()
                        bridgeEntity?.range = NSRange(entity.range)
                    default:
                        break
                }
                if let bridgeEntity = bridgeEntity {
                    bridgeEntities.append(bridgeEntity)
                }
            }
            if !bridgeEntities.isEmpty {
                let attachment = TGBridgeMessageEntitiesAttachment()
                attachment.entities = bridgeEntities
                bridgeMedia.append(attachment)
            }
        }
    }
    
    for m in message.media {
        if let image = m as? TelegramMediaImage, let bridgeImage = makeBridgeImage(image) {
            bridgeMedia.append(bridgeImage)
        }
        else if let file = m as? TelegramMediaFile {
            if file.isVideo {
                let bridgeVideo = TGBridgeVideoMediaAttachment()
                bridgeVideo.videoId = file.fileId.id
                
                for attribute in file.attributes {
                    switch attribute {
                        case let .Video(duration, size, flags):
                            bridgeVideo.duration = Int32(clamping: duration)
                            bridgeVideo.dimensions = size.cgSize
                            bridgeVideo.round = flags.contains(.instantRoundVideo)
                        default:
                            break
                    }
                }
                
                bridgeMedia.append(bridgeVideo)
            } else if file.isVoice {
                let bridgeAudio = TGBridgeAudioMediaAttachment()
                bridgeAudio.audioId = file.fileId.id
                bridgeAudio.fileSize = Int32(clamping: file.size ?? 0)
                
                for attribute in file.attributes {
                    switch attribute {
                        case let .Audio(_, duration, _, _, _):
                            bridgeAudio.duration = Int32(clamping: duration)
                        default:
                            break
                    }
                }
                
                bridgeMedia.append(bridgeAudio)
            } else if let bridgeDocument = makeBridgeDocument(file) {
                bridgeMedia.append(bridgeDocument)
            }
        } else if let action = m as? TelegramMediaAction {
            var bridgeAction: TGBridgeActionMediaAttachment? = nil
            var consumed = false
            switch action.action {
                case let .groupCreated(title):
                    bridgeAction = TGBridgeActionMediaAttachment()
                    if chatPeer is TelegramGroup {
                        bridgeAction?.actionType = .createChat
                        bridgeAction?.actionData = ["title": title]
                    } else if let channel = chatPeer as? TelegramChannel {
                        if case .group = channel.info {
                            bridgeAction?.actionType = .createChat
                            bridgeAction?.actionData = ["title": title]
                        } else {
                            bridgeAction?.actionType = .channelCreated
                        }
                    }
                case let .phoneCall(_, discardReason, _, _):
                    let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
                    let incoming = message.flags.contains(.Incoming)
                    var compactTitle: String = ""
                    var subTitle: String = ""
                    if let discardReason = discardReason {
                        switch discardReason {
                            case .busy, .disconnect:
                                compactTitle = strings.Notification_CallCanceled
                                subTitle = strings.Notification_CallCanceledShort
                            case .missed:
                                compactTitle = incoming ? strings.Notification_CallMissed : strings.Notification_CallCanceled
                                subTitle = incoming ? strings.Notification_CallMissedShort : strings.Notification_CallCanceledShort
                            case .hangup:
                                break
                        }
                    }
                    if compactTitle.isEmpty {
                        compactTitle = incoming ? strings.Notification_CallIncoming : strings.Notification_CallOutgoing
                        subTitle = incoming ? strings.Notification_CallIncomingShort : strings.Notification_CallOutgoingShort
                    }
                    bridgeAttachment.compactTitle = compactTitle
                    bridgeAttachment.title = strings.Watch_Message_Call
                    bridgeAttachment.subtitle = subTitle
                    bridgeMedia.append(bridgeAttachment)
                    consumed = true
                default:
                    break
            }
            if let bridgeAction = bridgeAction {
                bridgeMedia.append(bridgeAction)
            } else if !consumed && !filterUnsupportedActions {
                let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
                bridgeAttachment.compactTitle = ""
                bridgeAttachment.title = ""
                bridgeMedia.append(bridgeAttachment)
            }
        } else if let poll = m as? TelegramMediaPoll {
            let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
            bridgeAttachment.compactTitle = strings.Watch_Message_Poll
            bridgeAttachment.title = strings.Watch_Message_Poll
            bridgeAttachment.subtitle = poll.text
            bridgeMedia.append(bridgeAttachment)
        } else if let contact = m as? TelegramMediaContact {
            let bridgeContact = TGBridgeContactMediaAttachment()
            if let peerId = contact.peerId {
                bridgeContact.uid = Int32(clamping: makeBridgeIdentifier(peerId))
            }
            bridgeContact.firstName = contact.firstName
            bridgeContact.lastName = contact.lastName
            bridgeContact.phoneNumber = contact.phoneNumber
            bridgeContact.prettyPhoneNumber = formatPhoneNumber(contact.phoneNumber)
            bridgeMedia.append(bridgeContact)
        } else if let map = m as? TelegramMediaMap {
            let bridgeLocation = TGBridgeLocationMediaAttachment()
            bridgeLocation.latitude = map.latitude
            bridgeLocation.longitude = map.longitude
            if let venue = map.venue {
                let bridgeVenue = TGBridgeVenueAttachment()
                bridgeVenue.title = venue.title
                bridgeVenue.address = venue.address
                bridgeVenue.provider = venue.provider
                bridgeVenue.venueId = venue.id
                bridgeLocation.venue = bridgeVenue
            }
            bridgeMedia.append(bridgeLocation)
        } else if let webpage = m as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                let bridgeWebpage = TGBridgeWebPageMediaAttachment()
                bridgeWebpage.webPageId = webpage.id?.id ?? 0
                bridgeWebpage.url = content.url
                bridgeWebpage.displayUrl = content.displayUrl
                bridgeWebpage.pageType = content.type
                bridgeWebpage.siteName = content.websiteName
                bridgeWebpage.title = content.title
                bridgeWebpage.pageDescription = content.text
                bridgeWebpage.photo = makeBridgeImage(content.image)
                bridgeWebpage.embedUrl = content.embedUrl
                bridgeWebpage.embedType = content.embedType
                bridgeWebpage.embedSize = content.embedSize?.cgSize ?? CGSize()
                bridgeWebpage.duration = NSNumber(integerLiteral: content.duration ?? 0)
                bridgeWebpage.author = content.author
                bridgeMedia.append(bridgeWebpage)
            }
        } else if let game = m as? TelegramMediaGame {
            let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
            bridgeAttachment.compactTitle = game.title
            bridgeAttachment.title = strings.Watch_Message_Game
            bridgeAttachment.subtitle = game.title
            bridgeMedia.append(bridgeAttachment)
        } else if let invoice = m as? TelegramMediaInvoice {
            let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
            bridgeAttachment.compactTitle = invoice.title
            bridgeAttachment.title = strings.Watch_Message_Invoice
            bridgeAttachment.subtitle = invoice.title
            bridgeMedia.append(bridgeAttachment)
        } else if let _ = m as? TelegramMediaUnsupported {
            let bridgeAttachment = TGBridgeUnsupportedMediaAttachment()
            bridgeAttachment.compactTitle = strings.Watch_Message_Unsupported
            bridgeAttachment.title = strings.Watch_Message_Unsupported
            bridgeAttachment.subtitle = ""
            bridgeMedia.append(bridgeAttachment)
        }
    }
    return bridgeMedia
}

func makeBridgeChat(_ entry: ChatListEntry, strings: PresentationStrings) -> (TGBridgeChat, [Int64 : TGBridgeUser])? {
    if case let .MessageEntry(index, messages, readState, _, _, renderedPeer, _, _, _, hasFailed, _) = entry {
        guard index.messageIndex.id.peerId.namespace != Namespaces.Peer.SecretChat else {
            return nil
        }
        let message = messages.last
        let (bridgeChat, participants) = makeBridgeChat(renderedPeer.peer)
        bridgeChat.date = TimeInterval(index.messageIndex.timestamp)
        if let message = message {
            if let author = message.author {
                bridgeChat.fromUid = Int32(clamping: makeBridgeIdentifier(author.id))
            }
            bridgeChat.text = message.text
            bridgeChat.outgoing = !message.flags.contains(.Incoming)
            bridgeChat.deliveryState = makeBridgeDeliveryState(message)
            bridgeChat.deliveryError = hasFailed
            bridgeChat.media = makeBridgeMedia(message: message, strings: strings, filterUnsupportedActions: false)
        }
        bridgeChat.unread = readState?.state.isUnread ?? false
        bridgeChat.unreadCount = readState?.state.count ?? 0
        
        var bridgeUsers: [Int64 : TGBridgeUser] = participants
        if let bridgeUser = makeBridgeUser(message?.author, presence: nil) {
            bridgeUsers[bridgeUser.identifier] = bridgeUser
        }
        if let user = renderedPeer.peer as? TelegramUser, user.id != message?.author?.id, let bridgeUser = makeBridgeUser(user, presence: nil) {
            bridgeUsers[bridgeUser.identifier] = bridgeUser
        }
        
        return (bridgeChat, bridgeUsers)
    }
    return nil
}

func makeBridgeChat(_ peer: Peer?, view: PeerView? = nil) -> (TGBridgeChat, [Int64 : TGBridgeUser]) {
    let bridgeChat = TGBridgeChat()
    var bridgeUsers: [Int64 : TGBridgeUser] = [:]
    if let peer = peer {
        bridgeChat.identifier = makeBridgeIdentifier(peer.id)
        bridgeChat.userName = peer.addressName
    }
    if let group = peer as? TelegramGroup {
        bridgeChat.isGroup = true
        bridgeChat.groupTitle = group.title
        bridgeChat.participantsCount = Int32(clamping: group.participantCount)
        
        if let representation = smallestImageRepresentation(group.photo) {
            bridgeChat.groupPhotoSmall = legacyImageLocationUri(resource: representation.resource)
        }
        if let representation = largestImageRepresentation(group.photo) {
            bridgeChat.groupPhotoBig = legacyImageLocationUri(resource: representation.resource)
        }
        if let view = view, let cachedData = view.cachedData as? CachedGroupData, let participants = cachedData.participants {
            bridgeChat.participantsCount = Int32(clamping: participants.participants.count)
            var bridgeParticipants: [Int64] = []
            for participant in participants.participants {
                if let user = view.peers[participant.peerId], let bridgeUser = makeBridgeUser(user, presence: view.peerPresences[user.id]) {
                    bridgeParticipants.append(bridgeUser.identifier)
                    bridgeUsers[bridgeUser.identifier] = bridgeUser
                }
            }
            bridgeChat.participants = bridgeParticipants
        }
    } else if let channel = peer as? TelegramChannel {
        bridgeChat.isChannel = true
        bridgeChat.groupTitle = channel.title
        if case .group = channel.info {
            bridgeChat.isChannelGroup = true
        }
        bridgeChat.verified = channel.flags.contains(.isVerified)
        
        if let representation = smallestImageRepresentation(channel.photo) {
            bridgeChat.groupPhotoSmall = legacyImageLocationUri(resource: representation.resource)
        }
        if let representation = largestImageRepresentation(channel.photo) {
            bridgeChat.groupPhotoBig = legacyImageLocationUri(resource: representation.resource)
        }
        if let view = view, let cachedData = view.cachedData as? CachedChannelData {
            bridgeChat.about = cachedData.about
        }
    }
    
    //            _hasLeftGroup = [aDecoder decodeBoolForKey:TGBridgeChatHasLeftGroupKey];
    //            _isKickedFromGroup = [aDecoder decodeBoolForKey:TGBridgeChatIsKickedFromGroupKey];
    return (bridgeChat, bridgeUsers)
}

func makeBridgeUser(_ peer: Peer?, presence: PeerPresence? = nil, cachedData: CachedPeerData? = nil) -> TGBridgeUser? {
    if let user = peer as? TelegramUser {
        let bridgeUser = TGBridgeUser()
        bridgeUser.identifier = makeBridgeIdentifier(user.id)
        bridgeUser.firstName = user.firstName
        bridgeUser.lastName = user.lastName
        bridgeUser.userName = user.addressName
        bridgeUser.phoneNumber = user.phone
        if let phone = user.phone {
            bridgeUser.prettyPhoneNumber = formatPhoneNumber(phone)
        }
        if let presence = presence as? TelegramUserPresence {
            let timestamp = 0
            switch presence.status {
                case .recently:
                    bridgeUser.lastSeen = -2
                case .lastWeek:
                    bridgeUser.lastSeen = -3
                case .lastMonth:
                    bridgeUser.lastSeen = -4
                case .none:
                    bridgeUser.lastSeen = -5
                case let .present(statusTimestamp):
                    if statusTimestamp > timestamp {
                        bridgeUser.online = true
                    }
                    bridgeUser.lastSeen = TimeInterval(statusTimestamp)
            }
        }
        if let cachedData = cachedData as? CachedUserData {
            bridgeUser.about = cachedData.about
        }
        if let representation = smallestImageRepresentation(user.photo) {
            bridgeUser.photoSmall = legacyImageLocationUri(resource: representation.resource)
        }
        if let representation = largestImageRepresentation(user.photo) {
            bridgeUser.photoBig = legacyImageLocationUri(resource: representation.resource)
        }
        if user.botInfo != nil {
            bridgeUser.kind = .bot
            bridgeUser.botKind = .generic
        }
        bridgeUser.verified = user.flags.contains(.isVerified)
        return bridgeUser
    } else {
        return nil
    }
}

func makeBridgePeers(_ message: Message) -> [Int64 : Any] {
    var bridgeUsers: [Int64 : Any] = [:]
    for (_, peer) in message.peers {
        if peer is TelegramUser, let bridgeUser = makeBridgeUser(peer, presence: nil) {
            bridgeUsers[bridgeUser.identifier] = bridgeUser
        } else if peer is TelegramGroup || peer is TelegramChannel {
            let bridgeChat = makeBridgeChat(peer)
            bridgeUsers[bridgeChat.0.identifier] = bridgeChat.0
        }
    }
    if let author = message.author, let bridgeUser = makeBridgeUser(author) {
        bridgeUsers[bridgeUser.identifier] = bridgeUser
    }
    return bridgeUsers
}

func makeBridgeMessage(_ entry: MessageHistoryEntry, strings: PresentationStrings) -> (TGBridgeMessage, [Int64 : TGBridgeUser])? {
    guard let bridgeMessage = makeBridgeMessage(entry.message, strings: strings) else {
        return nil
    }
    if entry.message.id.namespace == Namespaces.Message.Local && !entry.message.flags.contains(.Failed) {
        return nil
    }
    
    bridgeMessage.unread = !entry.isRead
    
    var bridgeUsers: [Int64 : TGBridgeUser] = [:]
    if let bridgeUser = makeBridgeUser(entry.message.author, presence: nil) {
        bridgeUsers[bridgeUser.identifier] = bridgeUser
    }
    for (_, peer) in entry.message.peers {
        if let bridgeUser = makeBridgeUser(peer, presence: nil) {
            bridgeUsers[bridgeUser.identifier] = bridgeUser
        }
    }
    
    return (bridgeMessage, bridgeUsers)
}

func makeBridgeMessage(_ message: Message, strings: PresentationStrings, chatPeer: Peer? = nil) -> TGBridgeMessage? {
    var chatPeer = chatPeer
    if chatPeer == nil {
        chatPeer = message.peers[message.id.peerId]
    }
    
    let bridgeMessage = TGBridgeMessage()
    bridgeMessage.identifier = message.id.id
    bridgeMessage.date = TimeInterval(message.timestamp)
    bridgeMessage.randomId = message.globallyUniqueId ?? 0
//    bridgeMessage.unread = false
    bridgeMessage.outgoing = !message.flags.contains(.Incoming)
    if let author = message.author {
        bridgeMessage.fromUid = makeBridgeIdentifier(author.id)
    }
    bridgeMessage.toUid = makeBridgeIdentifier(message.id.peerId)
    bridgeMessage.cid = makeBridgeIdentifier(message.id.peerId)
    bridgeMessage.text = message.text
    bridgeMessage.deliveryState = makeBridgeDeliveryState(message)
    bridgeMessage.media = makeBridgeMedia(message: message, strings: strings, chatPeer: chatPeer)
    return bridgeMessage
}

func makeVenue(from bridgeVenue: TGBridgeVenueAttachment?) -> MapVenue? {
    if let bridgeVenue = bridgeVenue {
        return MapVenue(title: bridgeVenue.title, address: bridgeVenue.address, provider: bridgeVenue.provider, id: bridgeVenue.venueId, type: "")
    }
    return nil
}

func makeBridgeLocationVenue(_ contextResult: ChatContextResultMessage) -> TGBridgeLocationVenue? {
    if case let .mapLocation(mapMedia, _) = contextResult {
        let bridgeVenue = TGBridgeLocationVenue()
        bridgeVenue.coordinate = CLLocationCoordinate2D(latitude: mapMedia.latitude, longitude: mapMedia.longitude)
        if let venue = mapMedia.venue {
            bridgeVenue.name = venue.title
            bridgeVenue.address = venue.address
            bridgeVenue.provider = venue.provider
            bridgeVenue.identifier = venue.id
        }
        return bridgeVenue
    }
    return nil
}
