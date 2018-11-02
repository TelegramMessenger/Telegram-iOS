import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class CachedUserData: CachedPeerData {
    public let about: String?
    public let botInfo: BotInfo?
    public let reportStatus: PeerReportStatus
    public let pinnedMessageId: MessageId?
    public let isBlocked: Bool
    public let commonGroupCount: Int32
    public let callsAvailable: Bool
    public let callsPrivate: Bool
    public let canPinMessages: Bool
    public let hasAccountPeerPhone: Bool?
    
    public let peerIds = Set<PeerId>()
    public let messageIds: Set<MessageId>
    public let associatedHistoryMessageId: MessageId? = nil
    
    init() {
        self.about = nil
        self.botInfo = nil
        self.reportStatus = .unknown
        self.pinnedMessageId = nil
        self.isBlocked = false
        self.commonGroupCount = 0
        self.callsAvailable = false
        self.callsPrivate = false
        self.canPinMessages = false
        self.hasAccountPeerPhone = nil
        self.messageIds = Set()
    }
    
    init(about: String?, botInfo: BotInfo?, reportStatus: PeerReportStatus, pinnedMessageId: MessageId?, isBlocked: Bool, commonGroupCount: Int32, callsAvailable: Bool, callsPrivate: Bool, canPinMessages: Bool, hasAccountPeerPhone: Bool?) {
        self.about = about
        self.botInfo = botInfo
        self.reportStatus = reportStatus
        self.pinnedMessageId = pinnedMessageId
        self.isBlocked = isBlocked
        self.commonGroupCount = commonGroupCount
        self.callsAvailable = callsAvailable
        self.callsPrivate = callsPrivate
        self.canPinMessages = canPinMessages
        self.hasAccountPeerPhone = hasAccountPeerPhone
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
    }
    
    public init(decoder: PostboxDecoder) {
        self.about = decoder.decodeOptionalStringForKey("a")
        self.botInfo = decoder.decodeObjectForKey("bi") as? BotInfo
        self.reportStatus = PeerReportStatus(rawValue: decoder.decodeInt32ForKey("r", orElse: 0))!
        if let pinnedMessagePeerId = decoder.decodeOptionalInt64ForKey("pm.p"), let pinnedMessageNamespace = decoder.decodeOptionalInt32ForKey("pm.n"), let pinnedMessageId = decoder.decodeOptionalInt32ForKey("pm.i") {
            self.pinnedMessageId = MessageId(peerId: PeerId(pinnedMessagePeerId), namespace: pinnedMessageNamespace, id: pinnedMessageId)
        } else {
            self.pinnedMessageId = nil
        }
        self.isBlocked = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.commonGroupCount = decoder.decodeInt32ForKey("cg", orElse: 0)
        self.callsAvailable = decoder.decodeInt32ForKey("ca", orElse: 0) != 0
        self.callsPrivate = decoder.decodeInt32ForKey("cp", orElse: 0) != 0
        self.canPinMessages = decoder.decodeInt32ForKey("cpm", orElse: 0) != 0
        self.hasAccountPeerPhone = decoder.decodeOptionalInt32ForKey("hp").flatMap({ $0 != 0 })
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let about = self.about {
            encoder.encodeString(about, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        if let botInfo = self.botInfo {
            encoder.encodeObject(botInfo, forKey: "bi")
        } else {
            encoder.encodeNil(forKey: "bi")
        }
        encoder.encodeInt32(self.reportStatus.rawValue, forKey: "r")
        if let pinnedMessageId = self.pinnedMessageId {
            encoder.encodeInt64(pinnedMessageId.peerId.toInt64(), forKey: "pm.p")
            encoder.encodeInt32(pinnedMessageId.namespace, forKey: "pm.n")
            encoder.encodeInt32(pinnedMessageId.id, forKey: "pm.i")
        } else {
            encoder.encodeNil(forKey: "pm.p")
            encoder.encodeNil(forKey: "pm.n")
            encoder.encodeNil(forKey: "pm.i")
        }
        encoder.encodeInt32(self.isBlocked ? 1 : 0, forKey: "b")
        encoder.encodeInt32(self.commonGroupCount, forKey: "cg")
        encoder.encodeInt32(self.callsAvailable ? 1 : 0, forKey: "ca")
        encoder.encodeInt32(self.callsPrivate ? 1 : 0, forKey: "cp")
        encoder.encodeInt32(self.canPinMessages ? 1 : 0, forKey: "cpm")
        if let hasAccountPeerPhone = self.hasAccountPeerPhone {
            encoder.encodeInt32(hasAccountPeerPhone ? 1 : 0, forKey: "hp")
        } else {
            encoder.encodeNil(forKey: "hp")
        }
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedUserData else {
            return false
        }
        
        if other.pinnedMessageId != self.pinnedMessageId {
            return false
        }
        if other.canPinMessages != self.canPinMessages {
            return false
        }
        
        return other.about == self.about && other.botInfo == self.botInfo && self.reportStatus == other.reportStatus && self.isBlocked == other.isBlocked && self.commonGroupCount == other.commonGroupCount && self.callsAvailable == other.callsAvailable && self.callsPrivate == other.callsPrivate && self.hasAccountPeerPhone == other.hasAccountPeerPhone
    }
    
    func withUpdatedAbout(_ about: String?) -> CachedUserData {
        return CachedUserData(about: about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedBotInfo(_ botInfo: BotInfo?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedReportStatus(_ reportStatus: PeerReportStatus) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedIsBlocked(_ isBlocked: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCommonGroupCount(_ commonGroupCount: Int32) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCallsAvailable(_ callsAvailable: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCallsPrivate(_ callsPrivate: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCanPinMessages(_ canPinMessages: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: canPinMessages, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedHasAccountPeerPhone(_ hasAccountPeerPhone: Bool?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasAccountPeerPhone: hasAccountPeerPhone)
    }
}
