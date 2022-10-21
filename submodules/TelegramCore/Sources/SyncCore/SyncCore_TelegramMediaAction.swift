import Postbox

public enum PhoneCallDiscardReason: Int32 {
    case missed = 0
    case disconnect = 1
    case hangup = 2
    case busy = 3
}

public enum SentSecureValueType: Int32 {
    case personalDetails = 0
    case passport = 1
    case driversLicense = 2
    case idCard = 3
    case address = 4
    case bankStatement = 5
    case utilityBill = 6
    case rentalAgreement = 7
    case phone = 8
    case email = 9
    case internalPassport = 10
    case passportRegistration = 11
    case temporaryRegistration = 12
}

public enum TelegramMediaActionType: PostboxCoding, Equatable {
    public enum ForumTopicEditComponent: PostboxCoding, Equatable {
        case title(String)
        case iconFileId(Int64?)
        case isClosed(Bool)
        
        public init(decoder: PostboxDecoder) {
            switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .title(decoder.decodeStringForKey("title", orElse: ""))
            case 1:
                self = .iconFileId(decoder.decodeOptionalInt64ForKey("fileId"))
            case 2:
                self = .isClosed(decoder.decodeBoolForKey("isClosed", orElse: false))
            default:
                assertionFailure()
                self = .title("")
            }
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            switch self {
            case let .title(title):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeString(title, forKey: "title")
            case let .iconFileId(fileId):
                encoder.encodeInt32(1, forKey: "_t")
                if let fileId = fileId {
                    encoder.encodeInt64(fileId, forKey: "fileId")
                } else {
                    encoder.encodeNil(forKey: "fileId")
                }
            case let .isClosed(isClosed):
                encoder.encodeInt32(2, forKey: "_t")
                encoder.encodeBool(isClosed, forKey: "isClosed")
            }
        }
    }
    
    case unknown
    case groupCreated(title: String)
    case addedMembers(peerIds: [PeerId])
    case removedMembers(peerIds: [PeerId])
    case photoUpdated(image: TelegramMediaImage?)
    case titleUpdated(title: String)
    case pinnedMessageUpdated
    case joinedByLink(inviter: PeerId)
    case channelMigratedFromGroup(title: String, groupId: PeerId)
    case groupMigratedToChannel(channelId: PeerId)
    case historyCleared
    case historyScreenshot
    case messageAutoremoveTimeoutUpdated(Int32)
    case gameScore(gameId: Int64, score: Int32)
    case phoneCall(callId: Int64, discardReason: PhoneCallDiscardReason?, duration: Int32?, isVideo: Bool)
    case paymentSent(currency: String, totalAmount: Int64, invoiceSlug: String?, isRecurringInit: Bool, isRecurringUsed: Bool)
    case customText(text: String, entities: [MessageTextEntity])
    case botDomainAccessGranted(domain: String)
    case botSentSecureValues(types: [SentSecureValueType])
    case peerJoined
    case phoneNumberRequest
    case geoProximityReached(from: PeerId, to: PeerId, distance: Int32)
    case groupPhoneCall(callId: Int64, accessHash: Int64, scheduleDate: Int32?, duration: Int32?)
    case inviteToGroupPhoneCall(callId: Int64, accessHash: Int64, peerIds: [PeerId])
    case setChatTheme(emoji: String)
    case joinedByRequest
    case webViewData(String)
    case giftPremium(currency: String, amount: Int64, months: Int32)
    case topicCreated(title: String, iconColor: Int32, iconFileId: Int64?)
    case topicEdited(components: [ForumTopicEditComponent])
    
    public init(decoder: PostboxDecoder) {
        let rawValue: Int32 = decoder.decodeInt32ForKey("_rawValue", orElse: 0)
        switch rawValue {
        case 1:
            self = .groupCreated(title: decoder.decodeStringForKey("title", orElse: ""))
        case 2:
            self = .addedMembers(peerIds: PeerId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("peerIds")!))
        case 3:
            self = .removedMembers(peerIds: PeerId.decodeArrayFromBuffer(decoder.decodeBytesForKeyNoCopy("peerIds")!))
        case 4:
            self = .photoUpdated(image: decoder.decodeObjectForKey("image") as? TelegramMediaImage)
        case 5:
            self = .titleUpdated(title: decoder.decodeStringForKey("title", orElse: ""))
        case 6:
            self = .pinnedMessageUpdated
        case 7:
            self = .joinedByLink(inviter: PeerId(decoder.decodeInt64ForKey("inviter", orElse: 0)))
        case 8:
            self = .channelMigratedFromGroup(title: decoder.decodeStringForKey("title", orElse: ""), groupId: PeerId(decoder.decodeInt64ForKey("groupId", orElse: 0)))
        case 9:
            self = .groupMigratedToChannel(channelId: PeerId(decoder.decodeInt64ForKey("channelId", orElse: 0)))
        case 10:
            self = .historyCleared
        case 11:
            self = .historyScreenshot
        case 12:
            self = .messageAutoremoveTimeoutUpdated(decoder.decodeInt32ForKey("t", orElse: 0))
        case 13:
            self = .gameScore(gameId: decoder.decodeInt64ForKey("i", orElse: 0), score: decoder.decodeInt32ForKey("s", orElse: 0))
        case 14:
            var discardReason: PhoneCallDiscardReason?
            if let value = decoder.decodeOptionalInt32ForKey("dr") {
                discardReason = PhoneCallDiscardReason(rawValue: value)
            }
            self = .phoneCall(callId: decoder.decodeInt64ForKey("i", orElse: 0), discardReason: discardReason, duration: decoder.decodeInt32ForKey("d", orElse: 0), isVideo: decoder.decodeInt32ForKey("vc", orElse: 0) != 0)
        case 15:
            self = .paymentSent(currency: decoder.decodeStringForKey("currency", orElse: ""), totalAmount: decoder.decodeInt64ForKey("ta", orElse: 0), invoiceSlug: decoder.decodeOptionalStringForKey("invoiceSlug"), isRecurringInit: decoder.decodeBoolForKey("isRecurringInit", orElse: false), isRecurringUsed: decoder.decodeBoolForKey("isRecurringUsed", orElse: false))
        case 16:
            self = .customText(text: decoder.decodeStringForKey("text", orElse: ""), entities: decoder.decodeObjectArrayWithDecoderForKey("ent"))
        case 17:
            self = .botDomainAccessGranted(domain: decoder.decodeStringForKey("do", orElse: ""))
        case 18:
            self = .botSentSecureValues(types: decoder.decodeInt32ArrayForKey("ty").map { value -> SentSecureValueType in
                return SentSecureValueType(rawValue: value) ?? .personalDetails
            })
        case 19:
            self = .peerJoined
        case 20:
            self = .phoneNumberRequest
        case 21:
            self = .geoProximityReached(from: PeerId(decoder.decodeInt64ForKey("fromId", orElse: 0)), to: PeerId(decoder.decodeInt64ForKey("toId", orElse: 0)), distance: (decoder.decodeInt32ForKey("dst", orElse: 0)))
        case 22:
            self = .groupPhoneCall(callId: decoder.decodeInt64ForKey("callId", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), scheduleDate: decoder.decodeOptionalInt32ForKey("scheduleDate"), duration: decoder.decodeOptionalInt32ForKey("duration"))
        case 23:
            var peerIds: [PeerId] = []
            if let peerId = decoder.decodeOptionalInt64ForKey("peerId") {
                peerIds.append(PeerId(peerId))
            } else {
                peerIds = decoder.decodeInt64ArrayForKey("peerIds").map(PeerId.init)
            }
            self = .inviteToGroupPhoneCall(callId: decoder.decodeInt64ForKey("callId", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), peerIds: peerIds)
        case 24:
            self = .setChatTheme(emoji: decoder.decodeStringForKey("emoji", orElse: ""))
        case 25:
            self = .joinedByRequest
        case 26:
            self = .webViewData(decoder.decodeStringForKey("t", orElse: ""))
        case 27:
            self = .giftPremium(currency: decoder.decodeStringForKey("currency", orElse: ""), amount: decoder.decodeInt64ForKey("amount", orElse: 0), months: decoder.decodeInt32ForKey("months", orElse: 0))
        case 28:
            self = .topicCreated(title: decoder.decodeStringForKey("title", orElse: ""), iconColor: decoder.decodeInt32ForKey("iconColor", orElse: 0), iconFileId: decoder.decodeOptionalInt64ForKey("iconFileId"))
        case 29:
            self = .topicEdited(components: decoder.decodeObjectArrayWithDecoderForKey("components"))
        default:
            self = .unknown
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .unknown:
            break
        case let .groupCreated(title):
            encoder.encodeInt32(1, forKey: "_rawValue")
            encoder.encodeString(title, forKey: "title")
        case let .addedMembers(peerIds):
            encoder.encodeInt32(2, forKey: "_rawValue")
            let buffer = WriteBuffer()
            PeerId.encodeArrayToBuffer(peerIds, buffer: buffer)
            encoder.encodeBytes(buffer, forKey: "peerIds")
        case let .removedMembers(peerIds):
            encoder.encodeInt32(3, forKey: "_rawValue")
            let buffer = WriteBuffer()
            PeerId.encodeArrayToBuffer(peerIds, buffer: buffer)
            encoder.encodeBytes(buffer, forKey: "peerIds")
        case let .photoUpdated(image):
            encoder.encodeInt32(4, forKey: "_rawValue")
            if let image = image {
                encoder.encodeObject(image, forKey: "image")
            }
        case let .titleUpdated(title):
            encoder.encodeInt32(5, forKey: "_rawValue")
            encoder.encodeString(title, forKey: "title")
        case .pinnedMessageUpdated:
            encoder.encodeInt32(6, forKey: "_rawValue")
        case let .joinedByLink(inviter):
            encoder.encodeInt32(7, forKey: "_rawValue")
            encoder.encodeInt64(inviter.toInt64(), forKey: "inviter")
        case let .channelMigratedFromGroup(title, groupId):
            encoder.encodeInt32(8, forKey: "_rawValue")
            encoder.encodeString(title, forKey: "title")
            encoder.encodeInt64(groupId.toInt64(), forKey: "groupId")
        case let .groupMigratedToChannel(channelId):
            encoder.encodeInt32(9, forKey: "_rawValue")
            encoder.encodeInt64(channelId.toInt64(), forKey: "channelId")
        case .historyCleared:
            encoder.encodeInt32(10, forKey: "_rawValue")
        case .historyScreenshot:
            encoder.encodeInt32(11, forKey: "_rawValue")
        case let .messageAutoremoveTimeoutUpdated(timeout):
            encoder.encodeInt32(12, forKey: "_rawValue")
            encoder.encodeInt32(timeout, forKey: "t")
        case let .gameScore(gameId, score):
            encoder.encodeInt32(13, forKey: "_rawValue")
            encoder.encodeInt64(gameId, forKey: "i")
            encoder.encodeInt32(score, forKey: "s")
        case let .paymentSent(currency, totalAmount, invoiceSlug, isRecurringInit, isRecurringUsed):
            encoder.encodeInt32(15, forKey: "_rawValue")
            encoder.encodeString(currency, forKey: "currency")
            encoder.encodeInt64(totalAmount, forKey: "ta")
            if let invoiceSlug = invoiceSlug {
                encoder.encodeString(invoiceSlug, forKey: "invoiceSlug")
            } else {
                encoder.encodeNil(forKey: "invoiceSlug")
            }
            encoder.encodeBool(isRecurringInit, forKey: "isRecurringInit")
            encoder.encodeBool(isRecurringUsed, forKey: "isRecurringUsed")
        case let .phoneCall(callId, discardReason, duration, isVideo):
            encoder.encodeInt32(14, forKey: "_rawValue")
            encoder.encodeInt64(callId, forKey: "i")
            if let discardReason = discardReason {
                encoder.encodeInt32(discardReason.rawValue, forKey: "dr")
            } else {
                encoder.encodeNil(forKey: "dr")
            }
            if let duration = duration {
                encoder.encodeInt32(duration, forKey: "d")
            } else {
                encoder.encodeNil(forKey: "d")
            }
            encoder.encodeInt32(isVideo ? 1 : 0, forKey: "vc")
        case let .customText(text, entities):
            encoder.encodeInt32(16, forKey: "_rawValue")
            encoder.encodeString(text, forKey: "text")
            encoder.encodeObjectArray(entities, forKey: "ent")
        case let .botDomainAccessGranted(domain):
            encoder.encodeInt32(17, forKey: "_rawValue")
            encoder.encodeString(domain, forKey: "do")
        case let .botSentSecureValues(types):
            encoder.encodeInt32(18, forKey: "_rawValue")
            encoder.encodeInt32Array(types.map { $0.rawValue }, forKey: "ty")
        case .peerJoined:
            encoder.encodeInt32(19, forKey: "_rawValue")
        case .phoneNumberRequest:
            encoder.encodeInt32(20, forKey: "_rawValue")
        case let .geoProximityReached(from, to, distance):
            encoder.encodeInt32(21, forKey: "_rawValue")
            encoder.encodeInt64(from.toInt64(), forKey: "fromId")
            encoder.encodeInt64(to.toInt64(), forKey: "toId")
            encoder.encodeInt32(distance, forKey: "dst")
        case let .groupPhoneCall(callId, accessHash, scheduleDate, duration):
            encoder.encodeInt32(22, forKey: "_rawValue")
            encoder.encodeInt64(callId, forKey: "callId")
            encoder.encodeInt64(accessHash, forKey: "accessHash")
            if let scheduleDate = scheduleDate {
                encoder.encodeInt32(scheduleDate, forKey: "scheduleDate")
            } else {
                encoder.encodeNil(forKey: "scheduleDate")
            }
            if let duration = duration {
                encoder.encodeInt32(duration, forKey: "duration")
            } else {
                encoder.encodeNil(forKey: "duration")
            }
        case let .inviteToGroupPhoneCall(callId, accessHash, peerIds):
            encoder.encodeInt32(23, forKey: "_rawValue")
            encoder.encodeInt64(callId, forKey: "callId")
            encoder.encodeInt64(accessHash, forKey: "accessHash")
            encoder.encodeInt64Array(peerIds.map { $0.toInt64() }, forKey: "peerIds")
        case let .setChatTheme(emoji):
            encoder.encodeInt32(24, forKey: "_rawValue")
            encoder.encodeString(emoji, forKey: "emoji")
        case .joinedByRequest:
            encoder.encodeInt32(25, forKey: "_rawValue")
        case let .webViewData(text):
            encoder.encodeInt32(26, forKey: "_rawValue")
            encoder.encodeString(text, forKey: "t")
        case let .giftPremium(currency, amount, months):
            encoder.encodeInt32(27, forKey: "_rawValue")
            encoder.encodeString(currency, forKey: "currency")
            encoder.encodeInt64(amount, forKey: "amount")
            encoder.encodeInt32(months, forKey: "months")
        case let .topicCreated(title, iconColor, iconFileId):
            encoder.encodeInt32(28, forKey: "_rawValue")
            encoder.encodeString(title, forKey: "title")
            encoder.encodeInt32(iconColor, forKey: "iconColor")
            if let iconFileId = iconFileId {
                encoder.encodeInt64(iconFileId, forKey: "iconFileId")
            } else {
                encoder.encodeNil(forKey: "iconFileId")
            }
        case let .topicEdited(components):
            encoder.encodeInt32(29, forKey: "_rawValue")
            encoder.encodeObjectArray(components, forKey: "components")
        }
    }
    
    public var peerIds: [PeerId] {
        switch self {
        case let .addedMembers(peerIds):
            return peerIds
        case let .removedMembers(peerIds):
            return peerIds
        case let .joinedByLink(inviter):
            return [inviter]
        case let .channelMigratedFromGroup(_, groupId):
            return [groupId]
        case let .groupMigratedToChannel(channelId):
            return [channelId]
        case let .geoProximityReached(from, to, _):
            return [from, to]
        case let .inviteToGroupPhoneCall(_, _, peerIds):
            return peerIds
        default:
            return []
        }
    }
}

public final class TelegramMediaAction: Media {
    public let id: MediaId? = nil
    public var peerIds: [PeerId] {
        return self.action.peerIds
    }
    
    public let action: TelegramMediaActionType

    public func preventsAutomaticMessageSendingFailure() -> Bool {
        if case .historyScreenshot = self.action {
            return true
        }
        return false
    }
    
    public init(action: TelegramMediaActionType) {
        self.action = action
    }
    
    public init(decoder: PostboxDecoder) {
        self.action = TelegramMediaActionType(decoder: decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        self.action.encode(encoder)
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaAction {
            return self.action == other.action
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
