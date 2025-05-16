import Postbox
import Foundation

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

public enum BotSendMessageAccessGrantedType: Int32 {
    case attachMenu = 0
    case request = 1
}

public enum TelegramMediaActionType: PostboxCoding, Equatable {
    public enum ForumTopicEditComponent: PostboxCoding, Equatable {
        case title(String)
        case iconFileId(Int64?)
        case isClosed(Bool)
        case isHidden(Bool)
        
        public init(decoder: PostboxDecoder) {
            switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .title(decoder.decodeStringForKey("title", orElse: ""))
            case 1:
                self = .iconFileId(decoder.decodeOptionalInt64ForKey("fileId"))
            case 2:
                self = .isClosed(decoder.decodeBoolForKey("isClosed", orElse: false))
            case 3:
                self = .isHidden(decoder.decodeBoolForKey("isHidden", orElse: false))
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
            case let .isHidden(isHidden):
                encoder.encodeInt32(3, forKey: "_t")
                encoder.encodeBool(isHidden, forKey: "isHidden")
            }
        }
    }
    
    public struct CustomTextAttributes: Equatable {
        public var attributes: [(NSRange, NSAttributedString.Key, Any)]
        
        public init(attributes: [(NSRange, NSAttributedString.Key, Any)]) {
            self.attributes = attributes
        }
        
        public static func ==(lhs: CustomTextAttributes, rhs: CustomTextAttributes) -> Bool {
            return true
        }
    }
    
    public struct ConferenceCall: Equatable {
        public struct Flags: OptionSet {
            public var rawValue: Int32
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let isVideo = Flags(rawValue: 1 << 0)
            public static let isActive = Flags(rawValue: 1 << 1)
            public static let isMissed = Flags(rawValue: 1 << 2)
        }

        public let callId: Int64
        public let duration: Int32?
        public let flags: Flags
        public let otherParticipants: [PeerId]

        public init(callId: Int64, duration: Int32?, flags: Flags, otherParticipants: [PeerId]) {
            self.callId = callId
            self.duration = duration
            self.flags = flags
            self.otherParticipants = otherParticipants
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
    case messageAutoremoveTimeoutUpdated(period: Int32, autoSettingSource: PeerId?)
    case gameScore(gameId: Int64, score: Int32)
    case phoneCall(callId: Int64, discardReason: PhoneCallDiscardReason?, duration: Int32?, isVideo: Bool)
    case paymentSent(currency: String, totalAmount: Int64, invoiceSlug: String?, isRecurringInit: Bool, isRecurringUsed: Bool)
    case customText(text: String, entities: [MessageTextEntity], additionalAttributes: CustomTextAttributes?)
    case botDomainAccessGranted(domain: String)
    case botAppAccessGranted(appName: String?, type: BotSendMessageAccessGrantedType?)
    case botSentSecureValues(types: [SentSecureValueType])
    case peerJoined
    case phoneNumberRequest
    case geoProximityReached(from: PeerId, to: PeerId, distance: Int32)
    case groupPhoneCall(callId: Int64, accessHash: Int64, scheduleDate: Int32?, duration: Int32?)
    case inviteToGroupPhoneCall(callId: Int64, accessHash: Int64, peerIds: [PeerId])
    case setChatTheme(emoji: String)
    case joinedByRequest
    case webViewData(String)
    case giftPremium(currency: String, amount: Int64, months: Int32, cryptoCurrency: String?, cryptoAmount: Int64?, text: String?, entities: [MessageTextEntity]?)
    case topicCreated(title: String, iconColor: Int32, iconFileId: Int64?)
    case topicEdited(components: [ForumTopicEditComponent])
    case suggestedProfilePhoto(image: TelegramMediaImage?)
    case attachMenuBotAllowed
    case requestedPeer(buttonId: Int32, peerIds: [PeerId])
    case setChatWallpaper(wallpaper: TelegramWallpaper, forBoth: Bool)
    case setSameChatWallpaper(wallpaper: TelegramWallpaper)
    case giftCode(slug: String, fromGiveaway: Bool, isUnclaimed: Bool, boostPeerId: PeerId?, months: Int32, currency: String?, amount: Int64?, cryptoCurrency: String?, cryptoAmount: Int64?, text: String?, entities: [MessageTextEntity]?)
    case giveawayLaunched(stars: Int64?)
    case joinedChannel
    case giveawayResults(winners: Int32, unclaimed: Int32, stars: Bool)
    case boostsApplied(boosts: Int32)
    case paymentRefunded(peerId: PeerId, currency: String, totalAmount: Int64, payload: Data?, transactionId: String)
    case giftStars(currency: String, amount: Int64, count: Int64, cryptoCurrency: String?, cryptoAmount: Int64?, transactionId: String?)
    case prizeStars(amount: Int64, isUnclaimed: Bool, boostPeerId: PeerId?, transactionId: String?, giveawayMessageId: MessageId?)
    case starGift(gift: StarGift, convertStars: Int64?, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, converted: Bool, upgraded: Bool, canUpgrade: Bool, upgradeStars: Int64?, isRefunded: Bool, upgradeMessageId: Int32?, peerId: EnginePeer.Id?, senderId: EnginePeer.Id?, savedId: Int64?)
    case starGiftUnique(gift: StarGift, isUpgrade: Bool, isTransferred: Bool, savedToProfile: Bool, canExportDate: Int32?, transferStars: Int64?, isRefunded: Bool, peerId: EnginePeer.Id?, senderId: EnginePeer.Id?, savedId: Int64?, resaleStars: Int64?, canTransferDate: Int32?, canResaleDate: Int32?)
    case paidMessagesRefunded(count: Int32, stars: Int64)
    case paidMessagesPriceEdited(stars: Int64, broadcastMessagesAllowed: Bool)
    case conferenceCall(ConferenceCall)
    
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
            self = .messageAutoremoveTimeoutUpdated(period: decoder.decodeInt32ForKey("t", orElse: 0), autoSettingSource: decoder.decodeOptionalInt64ForKey("src").flatMap(PeerId.init))
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
            self = .customText(text: decoder.decodeStringForKey("text", orElse: ""), entities: decoder.decodeObjectArrayWithDecoderForKey("ent"), additionalAttributes: nil)
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
            self = .giftPremium(currency: decoder.decodeStringForKey("currency", orElse: ""), amount: decoder.decodeInt64ForKey("amount", orElse: 0), months: decoder.decodeInt32ForKey("months", orElse: 0), cryptoCurrency: decoder.decodeOptionalStringForKey("cryptoCurrency"), cryptoAmount: decoder.decodeOptionalInt64ForKey("cryptoAmount"), text: decoder.decodeOptionalStringForKey("text"), entities: decoder.decodeOptionalObjectArrayWithDecoderForKey("entities"))
        case 28:
            self = .topicCreated(title: decoder.decodeStringForKey("title", orElse: ""), iconColor: decoder.decodeInt32ForKey("iconColor", orElse: 0), iconFileId: decoder.decodeOptionalInt64ForKey("iconFileId"))
        case 29:
            self = .topicEdited(components: decoder.decodeObjectArrayWithDecoderForKey("components"))
        case 30:
            self = .suggestedProfilePhoto(image: decoder.decodeObjectForKey("image") as? TelegramMediaImage)
        case 31:
            self = .attachMenuBotAllowed
        case 32:
            var peerIds = decoder.decodeInt64ArrayForKey("pis").map { PeerId($0) }
            if peerIds.isEmpty {
                peerIds = [PeerId(decoder.decodeInt64ForKey("pi", orElse: 0))]
            }
            self = .requestedPeer(buttonId: decoder.decodeInt32ForKey("b", orElse: 0), peerIds: peerIds)
        case 33:
            if let wallpaper = decoder.decode(TelegramWallpaperNativeCodable.self, forKey: "wallpaper")?.value {
                self = .setChatWallpaper(wallpaper: wallpaper, forBoth: decoder.decodeBoolForKey("both", orElse: false))
            } else {
                self = .unknown
            }
        case 34:
            if let wallpaper = decoder.decode(TelegramWallpaperNativeCodable.self, forKey: "wallpaper")?.value {
                self = .setSameChatWallpaper(wallpaper: wallpaper)
            } else {
                self = .unknown
            }
        case 35:
            self = .botAppAccessGranted(appName: decoder.decodeOptionalStringForKey("app"), type: decoder.decodeOptionalInt32ForKey("atp").flatMap { BotSendMessageAccessGrantedType(rawValue: $0) })
        case 36:
            self = .giftCode(slug: decoder.decodeStringForKey("slug", orElse: ""), fromGiveaway: decoder.decodeBoolForKey("give", orElse: false), isUnclaimed: decoder.decodeBoolForKey("unclaimed", orElse: false), boostPeerId: decoder.decodeOptionalInt64ForKey("pi").flatMap { PeerId($0) }, months: decoder.decodeInt32ForKey("months", orElse: 0), currency: decoder.decodeOptionalStringForKey("currency"), amount: decoder.decodeOptionalInt64ForKey("amount"), cryptoCurrency: decoder.decodeOptionalStringForKey("cryptoCurrency"), cryptoAmount: decoder.decodeOptionalInt64ForKey("cryptoAmount"), text: decoder.decodeOptionalStringForKey("text"), entities: decoder.decodeOptionalObjectArrayWithDecoderForKey("entities"))
        case 37:
            self = .giveawayLaunched(stars: decoder.decodeOptionalInt64ForKey("stars"))
        case 38:
            self = .joinedChannel
        case 39:
            self = .giveawayResults(winners: decoder.decodeInt32ForKey("winners", orElse: 0), unclaimed: decoder.decodeInt32ForKey("unclaimed", orElse: 0), stars: decoder.decodeBoolForKey("stars", orElse: false))
        case 40:
            self = .boostsApplied(boosts: decoder.decodeInt32ForKey("boosts", orElse: 0))
        case 41:
            self = .paymentRefunded(peerId: PeerId(decoder.decodeInt64ForKey("pi", orElse: 0)), currency: decoder.decodeStringForKey("currency", orElse: ""), totalAmount: decoder.decodeInt64ForKey("amount", orElse: 0), payload: decoder.decodeDataForKey("payload"), transactionId: decoder.decodeStringForKey("transactionId", orElse: ""))
        case 42:
            self = .giftStars(currency: decoder.decodeStringForKey("currency", orElse: ""), amount: decoder.decodeInt64ForKey("amount", orElse: 0), count: decoder.decodeInt64ForKey("count", orElse: 0), cryptoCurrency: decoder.decodeOptionalStringForKey("cryptoCurrency"), cryptoAmount: decoder.decodeOptionalInt64ForKey("cryptoAmount"), transactionId: decoder.decodeOptionalStringForKey("transactionId"))
        case 43:
            let boostPeerId = decoder.decodeOptionalInt64ForKey("pi").flatMap { PeerId($0) }
            let giveawayMsgId = decoder.decodeOptionalInt32ForKey("giveawayMsgId")
            var giveawayMessageId: MessageId?
            if let boostPeerId, let giveawayMsgId {
                giveawayMessageId = MessageId(peerId: boostPeerId, namespace: Namespaces.Message.Cloud, id: giveawayMsgId)
            }
            self = .prizeStars(amount: decoder.decodeInt64ForKey("amount", orElse: 0), isUnclaimed: decoder.decodeBoolForKey("unclaimed", orElse: false), boostPeerId: boostPeerId, transactionId: decoder.decodeOptionalStringForKey("transactionId"), giveawayMessageId: giveawayMessageId)
        case 44:
            self = .starGift(gift: decoder.decodeObjectForKey("gift", decoder: { StarGift(decoder: $0) }) as! StarGift, convertStars: decoder.decodeOptionalInt64ForKey("convertStars"), text: decoder.decodeOptionalStringForKey("text"), entities: decoder.decodeOptionalObjectArrayWithDecoderForKey("entities"), nameHidden: decoder.decodeBoolForKey("nameHidden", orElse: false), savedToProfile: decoder.decodeBoolForKey("savedToProfile", orElse: false), converted: decoder.decodeBoolForKey("converted", orElse: false), upgraded: decoder.decodeBoolForKey("upgraded", orElse: false), canUpgrade: decoder.decodeBoolForKey("canUpgrade", orElse: false), upgradeStars: decoder.decodeOptionalInt64ForKey("upgradeStars"), isRefunded: decoder.decodeBoolForKey("isRefunded", orElse: false), upgradeMessageId: decoder.decodeOptionalInt32ForKey("upgradeMessageId"), peerId: decoder.decodeOptionalInt64ForKey("peerId").flatMap { EnginePeer.Id($0) }, senderId: decoder.decodeOptionalInt64ForKey("senderId").flatMap { EnginePeer.Id($0) }, savedId: decoder.decodeOptionalInt64ForKey("savedId"))
        case 45:
            self = .starGiftUnique(gift: decoder.decodeObjectForKey("gift", decoder: { StarGift(decoder: $0) }) as! StarGift, isUpgrade: decoder.decodeBoolForKey("isUpgrade", orElse: false), isTransferred: decoder.decodeBoolForKey("isTransferred", orElse: false), savedToProfile: decoder.decodeBoolForKey("savedToProfile", orElse: false), canExportDate: decoder.decodeOptionalInt32ForKey("canExportDate"), transferStars: decoder.decodeOptionalInt64ForKey("transferStars"), isRefunded: decoder.decodeBoolForKey("isRefunded", orElse: false), peerId: decoder.decodeOptionalInt64ForKey("peerId").flatMap { EnginePeer.Id($0) }, senderId: decoder.decodeOptionalInt64ForKey("senderId").flatMap { EnginePeer.Id($0) }, savedId: decoder.decodeOptionalInt64ForKey("savedId"), resaleStars: decoder.decodeOptionalInt64ForKey("resaleStars"), canTransferDate: decoder.decodeOptionalInt32ForKey("canTransferDate"), canResaleDate: decoder.decodeOptionalInt32ForKey("canResaleDate"))
        case 46:
            self = .paidMessagesRefunded(count: decoder.decodeInt32ForKey("count", orElse: 0), stars: decoder.decodeInt64ForKey("stars", orElse: 0))
        case 47:
            self = .paidMessagesPriceEdited(stars: decoder.decodeInt64ForKey("stars", orElse: 0), broadcastMessagesAllowed: decoder.decodeBoolForKey("brmsg", orElse: false))
        case 48:
            self = .conferenceCall(ConferenceCall(
                callId: decoder.decodeInt64ForKey("cid", orElse: 0),
                duration: decoder.decodeOptionalInt32ForKey("dur"),
                flags: ConferenceCall.Flags(rawValue: decoder.decodeInt32ForKey("flags", orElse: 0)),
                otherParticipants: decoder.decodeInt64ArrayForKey("part").map(PeerId.init)
            ))
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
        case let .messageAutoremoveTimeoutUpdated(timeout, autoSettingSource):
            encoder.encodeInt32(12, forKey: "_rawValue")
            encoder.encodeInt32(timeout, forKey: "t")
            if let autoSettingSource = autoSettingSource {
                encoder.encodeInt64(autoSettingSource.toInt64(), forKey: "src")
            } else {
                encoder.encodeNil(forKey: "src")
            }
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
        case let .customText(text, entities, _):
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
        case let .giftPremium(currency, amount, months, cryptoCurrency, cryptoAmount, text, entities):
            encoder.encodeInt32(27, forKey: "_rawValue")
            encoder.encodeString(currency, forKey: "currency")
            encoder.encodeInt64(amount, forKey: "amount")
            encoder.encodeInt32(months, forKey: "months")
            if let cryptoCurrency = cryptoCurrency, let cryptoAmount = cryptoAmount {
                encoder.encodeString(cryptoCurrency, forKey: "cryptoCurrency")
                encoder.encodeInt64(cryptoAmount, forKey: "cryptoAmount")
            } else {
                encoder.encodeNil(forKey: "cryptoCurrency")
                encoder.encodeNil(forKey: "cryptoAmount")
            }
            if let text, let entities {
                encoder.encodeString(text, forKey: "text")
                encoder.encodeObjectArray(entities, forKey: "entities")
            } else {
                encoder.encodeNil(forKey: "text")
                encoder.encodeNil(forKey: "entities")
            }
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
        case let .suggestedProfilePhoto(image):
            encoder.encodeInt32(30, forKey: "_rawValue")
            if let image = image {
                encoder.encodeObject(image, forKey: "image")
            }
        case .attachMenuBotAllowed:
            encoder.encodeInt32(31, forKey: "_rawValue")
        case let .requestedPeer(buttonId, peerIds):
            encoder.encodeInt32(32, forKey: "_rawValue")
            encoder.encodeInt32(buttonId, forKey: "b")
            encoder.encodeInt64Array(peerIds.map { $0.toInt64() }, forKey: "pis")
        case let .setChatWallpaper(wallpaper, forBoth):
            encoder.encodeInt32(33, forKey: "_rawValue")
            encoder.encode(TelegramWallpaperNativeCodable(wallpaper), forKey: "wallpaper")
            encoder.encodeBool(forBoth, forKey: "both")
        case let .setSameChatWallpaper(wallpaper):
            encoder.encodeInt32(34, forKey: "_rawValue")
            encoder.encode(TelegramWallpaperNativeCodable(wallpaper), forKey: "wallpaper")
        case let .botAppAccessGranted(appName, type):
            encoder.encodeInt32(35, forKey: "_rawValue")
            if let appName = appName {
                encoder.encodeString(appName, forKey: "app")
            } else {
                encoder.encodeNil(forKey: "app")
            }
            if let type = type {
                encoder.encodeInt32(type.rawValue, forKey: "atp")
            } else {
                encoder.encodeNil(forKey: "atp")
            }
        case let .giftCode(slug, fromGiveaway, unclaimed, boostPeerId, months, currency, amount, cryptoCurrency, cryptoAmount, text, entities):
            encoder.encodeInt32(36, forKey: "_rawValue")
            encoder.encodeString(slug, forKey: "slug")
            encoder.encodeBool(fromGiveaway, forKey: "give")
            encoder.encodeBool(unclaimed, forKey: "unclaimed")
            if let boostPeerId = boostPeerId {
                encoder.encodeInt64(boostPeerId.toInt64(), forKey: "pi")
            } else {
                encoder.encodeNil(forKey: "pi")
            }
            encoder.encodeInt32(months, forKey: "months")
            if let currency = currency {
                encoder.encodeString(currency, forKey: "currency")
            } else {
                encoder.encodeNil(forKey: "currency")
            }
            if let amount = amount {
                encoder.encodeInt64(amount, forKey: "amount")
            } else {
                encoder.encodeNil(forKey: "amount")
            }
            if let cryptoCurrency = cryptoCurrency {
                encoder.encodeString(cryptoCurrency, forKey: "cryptoCurrency")
            } else {
                encoder.encodeNil(forKey: "cryptoCurrency")
            }
            if let cryptoAmount = cryptoAmount {
                encoder.encodeInt64(cryptoAmount, forKey: "cryptoAmount")
            } else {
                encoder.encodeNil(forKey: "cryptoAmount")
            }
            if let text, let entities {
                encoder.encodeString(text, forKey: "text")
                encoder.encodeObjectArray(entities, forKey: "entities")
            } else {
                encoder.encodeNil(forKey: "text")
                encoder.encodeNil(forKey: "entities")
            }
        case let .giveawayLaunched(stars):
            encoder.encodeInt32(37, forKey: "_rawValue")
            if let stars = stars {
                encoder.encodeInt64(stars, forKey: "stars")
            } else {
                encoder.encodeNil(forKey: "stars")
            }
        case .joinedChannel:
            encoder.encodeInt32(38, forKey: "_rawValue")
        case let .giveawayResults(winners, unclaimed, stars):
            encoder.encodeInt32(39, forKey: "_rawValue")
            encoder.encodeInt32(winners, forKey: "winners")
            encoder.encodeInt32(unclaimed, forKey: "unclaimed")
            encoder.encodeBool(stars, forKey: "stars")
        case let .boostsApplied(boosts):
            encoder.encodeInt32(40, forKey: "_rawValue")
            encoder.encodeInt32(boosts, forKey: "boosts")
        case let .paymentRefunded(peerId, currency, totalAmount, payload, transactionId):
            encoder.encodeInt32(41, forKey: "_rawValue")
            encoder.encodeInt64(peerId.toInt64(), forKey: "pi")
            encoder.encodeString(currency, forKey: "currency")
            encoder.encodeInt64(totalAmount, forKey: "amount")
            if let payload {
                encoder.encodeData(payload, forKey: "payload")
            } else {
                encoder.encodeNil(forKey: "payload")
            }
            encoder.encodeString(transactionId, forKey: "transactionId")
        case let .giftStars(currency, amount, count, cryptoCurrency, cryptoAmount, transactionId):
            encoder.encodeInt32(42, forKey: "_rawValue")
            encoder.encodeString(currency, forKey: "currency")
            encoder.encodeInt64(amount, forKey: "amount")
            encoder.encodeInt64(count, forKey: "count")
            if let cryptoCurrency = cryptoCurrency, let cryptoAmount = cryptoAmount {
                encoder.encodeString(cryptoCurrency, forKey: "cryptoCurrency")
                encoder.encodeInt64(cryptoAmount, forKey: "cryptoAmount")
            } else {
                encoder.encodeNil(forKey: "cryptoCurrency")
                encoder.encodeNil(forKey: "cryptoAmount")
            }
            if let transactionId {
                encoder.encodeString(transactionId, forKey: "transactionId")
            } else {
                encoder.encodeNil(forKey: "transactionId")
            }
        case let .prizeStars(amount, isUnclaimed, boostPeerId, transactionId, giveawayMessageId):
            encoder.encodeInt32(43, forKey: "_rawValue")
            encoder.encodeInt64(amount, forKey: "amount")
            encoder.encodeBool(isUnclaimed, forKey: "unclaimed")
            if let boostPeerId = boostPeerId {
                encoder.encodeInt64(boostPeerId.toInt64(), forKey: "pi")
            } else {
                encoder.encodeNil(forKey: "pi")
            }
            if let transactionId {
                encoder.encodeString(transactionId, forKey: "transactionId")
            } else {
                encoder.encodeNil(forKey: "transactionId")
            }
            if let giveawayMessageId {
                encoder.encodeInt32(giveawayMessageId.id, forKey: "giveawayMsgId")
            } else {
                encoder.encodeNil(forKey: "giveawayMsgId")
            }
        case let .starGift(gift, convertStars, text, entities, nameHidden, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, isRefunded, upgradeMessageId, peerId, senderId, savedId):
            encoder.encodeInt32(44, forKey: "_rawValue")
            encoder.encodeObject(gift, forKey: "gift")
            if let convertStars {
                encoder.encodeInt64(convertStars, forKey: "convertStars")
            } else {
                encoder.encodeNil(forKey: "convertStars")
            }
            if let text, let entities {
                encoder.encodeString(text, forKey: "text")
                encoder.encodeObjectArray(entities, forKey: "entities")
            } else {
                encoder.encodeNil(forKey: "text")
                encoder.encodeNil(forKey: "entities")
            }
            encoder.encodeBool(nameHidden, forKey: "nameHidden")
            encoder.encodeBool(savedToProfile, forKey: "savedToProfile")
            encoder.encodeBool(converted, forKey: "converted")
            encoder.encodeBool(upgraded, forKey: "upgraded")
            encoder.encodeBool(canUpgrade, forKey: "canUpgrade")
            if let upgradeStars {
                encoder.encodeInt64(upgradeStars, forKey: "upgradeStars")
            } else {
                encoder.encodeNil(forKey: "upgradeStars")
            }
            encoder.encodeBool(isRefunded, forKey: "isRefunded")
            if let upgradeMessageId {
                encoder.encodeInt32(upgradeMessageId, forKey:  "upgradeMessageId")
            } else {
                encoder.encodeNil(forKey: "upgradeMessageId")
            }
            if let peerId {
                encoder.encodeInt64(peerId.toInt64(), forKey: "peerId")
            } else {
                encoder.encodeNil(forKey: "peerId")
            }
            if let senderId {
                encoder.encodeInt64(senderId.toInt64(), forKey: "senderId")
            } else {
                encoder.encodeNil(forKey: "senderId")
            }
            if let savedId {
                encoder.encodeInt64(savedId, forKey: "savedId")
            } else {
                encoder.encodeNil(forKey: "savedId")
            }
        case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, isRefunded, peerId, senderId, savedId, resaleStars, canTransferDate, canResaleDate):
            encoder.encodeInt32(45, forKey: "_rawValue")
            encoder.encodeObject(gift, forKey: "gift")
            encoder.encodeBool(isUpgrade, forKey: "isUpgrade")
            encoder.encodeBool(isTransferred, forKey: "isTransferred")
            encoder.encodeBool(savedToProfile, forKey: "savedToProfile")
            if let canExportDate {
                encoder.encodeInt32(canExportDate, forKey: "canExportDate")
            } else {
                encoder.encodeNil(forKey: "canExportDate")
            }
            if let transferStars {
                encoder.encodeInt64(transferStars, forKey: "transferStars")
            } else {
                encoder.encodeNil(forKey: "transferStars")
            }
            encoder.encodeBool(isRefunded, forKey: "isRefunded")
            if let peerId {
                encoder.encodeInt64(peerId.toInt64(), forKey: "peerId")
            } else {
                encoder.encodeNil(forKey: "peerId")
            }
            if let senderId {
                encoder.encodeInt64(senderId.toInt64(), forKey: "senderId")
            } else {
                encoder.encodeNil(forKey: "senderId")
            }
            if let savedId {
                encoder.encodeInt64(savedId, forKey: "savedId")
            } else {
                encoder.encodeNil(forKey: "savedId")
            }
            if let resaleStars {
                encoder.encodeInt64(resaleStars, forKey: "resaleStars")
            } else {
                encoder.encodeNil(forKey: "resaleStars")
            }
            if let canTransferDate {
                encoder.encodeInt32(canTransferDate, forKey: "canTransferDate")
            } else {
                encoder.encodeNil(forKey: "canTransferDate")
            }
            if let canResaleDate {
                encoder.encodeInt32(canResaleDate, forKey: "canResaleDate")
            } else {
                encoder.encodeNil(forKey: "canResaleDate")
            }
        case let .paidMessagesRefunded(count, stars):
            encoder.encodeInt32(46, forKey: "_rawValue")
            encoder.encodeInt32(count, forKey: "count")
            encoder.encodeInt64(stars, forKey: "stars")
        case let .paidMessagesPriceEdited(stars, broadcastMessagesAllowed):
            encoder.encodeInt32(47, forKey: "_rawValue")
            encoder.encodeInt64(stars, forKey: "stars")
            encoder.encodeBool(broadcastMessagesAllowed, forKey: "brmsg")
        case let .conferenceCall(conferenceCall):
            encoder.encodeInt32(48, forKey: "_rawValue")
            encoder.encodeInt64(conferenceCall.callId, forKey: "cid")
            if let duration = conferenceCall.duration {
                encoder.encodeInt32(duration, forKey: "dur")
            } else {
                encoder.encodeNil(forKey: "dur")
            }
            encoder.encodeInt32(conferenceCall.flags.rawValue, forKey: "flags")
            encoder.encodeInt64Array(conferenceCall.otherParticipants.map({ $0.toInt64() }), forKey: "part")
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
        case let .requestedPeer(_, peerIds):
            return peerIds
        case let .giftCode(_, _, _, boostPeerId, _, _, _, _, _, _, _):
            return boostPeerId.flatMap { [$0] } ?? []
        case let .paymentRefunded(peerId, _, _, _, _):
            return [peerId]
        case let .prizeStars(_, _, boostPeerId, _, _):
            return boostPeerId.flatMap { [$0] } ?? []
        case let .starGift(_, _, _, _, _, _, _, _, _, _, _, _, peerId, senderId, _):
            var peerIds: [PeerId] = []
            if let peerId {
                peerIds.append(peerId)
            }
            if let senderId {
                peerIds.append(senderId)
            }
            return peerIds
        case let .starGiftUnique(_, _, _, _, _, _, _, peerId, senderId, _, _, _, _):
            var peerIds: [PeerId] = []
            if let peerId {
                peerIds.append(peerId)
            }
            if let senderId {
                peerIds.append(senderId)
            }
            return peerIds
        case let .conferenceCall(conferenceCall):
            return conferenceCall.otherParticipants
        default:
            return []
        }
    }
}

public final class TelegramMediaAction: Media, Equatable {
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
    
    public static func ==(lhs: TelegramMediaAction, rhs: TelegramMediaAction) -> Bool {
        return lhs.isEqual(to: rhs)
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
