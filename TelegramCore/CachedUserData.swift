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
    public let isBlocked: Bool
    public let commonGroupCount: Int32
    public let callsAvailable: Bool
    public let callsPrivate: Bool
    public let hasAccountPeerPhone: Bool?
    
    public let peerIds = Set<PeerId>()
    public let messageIds = Set<MessageId>()
    public let associatedHistoryMessageId: MessageId? = nil
    
    init() {
        self.about = nil
        self.botInfo = nil
        self.reportStatus = .unknown
        self.isBlocked = false
        self.commonGroupCount = 0
        self.callsAvailable = false
        self.callsPrivate = false
        self.hasAccountPeerPhone = nil
    }
    
    init(about: String?, botInfo: BotInfo?, reportStatus: PeerReportStatus, isBlocked: Bool, commonGroupCount: Int32, callsAvailable: Bool, callsPrivate: Bool, hasAccountPeerPhone: Bool?) {
        self.about = about
        self.botInfo = botInfo
        self.reportStatus = reportStatus
        self.isBlocked = isBlocked
        self.commonGroupCount = commonGroupCount
        self.callsAvailable = callsAvailable
        self.callsPrivate = callsPrivate
        self.hasAccountPeerPhone = hasAccountPeerPhone
    }
    
    public init(decoder: PostboxDecoder) {
        self.about = decoder.decodeOptionalStringForKey("a")
        self.botInfo = decoder.decodeObjectForKey("bi") as? BotInfo
        self.reportStatus = PeerReportStatus(rawValue: decoder.decodeInt32ForKey("r", orElse: 0))!
        self.isBlocked = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.commonGroupCount = decoder.decodeInt32ForKey("cg", orElse: 0)
        self.callsAvailable = decoder.decodeInt32ForKey("ca", orElse: 0) != 0
        self.callsPrivate = decoder.decodeInt32ForKey("cp", orElse: 0) != 0
        self.hasAccountPeerPhone = decoder.decodeOptionalInt32ForKey("hp").flatMap({ $0 != 0 })
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
        encoder.encodeInt32(self.isBlocked ? 1 : 0, forKey: "b")
        encoder.encodeInt32(self.commonGroupCount, forKey: "cg")
        encoder.encodeInt32(self.callsAvailable ? 1 : 0, forKey: "ca")
        encoder.encodeInt32(self.callsPrivate ? 1 : 0, forKey: "cp")
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
        
        return other.about == self.about && other.botInfo == self.botInfo && self.reportStatus == other.reportStatus && self.isBlocked == other.isBlocked && self.commonGroupCount == other.commonGroupCount && self.callsAvailable == other.callsAvailable && self.callsPrivate == other.callsPrivate && self.hasAccountPeerPhone == other.hasAccountPeerPhone
    }
    
    func withUpdatedAbout(_ about: String?) -> CachedUserData {
        return CachedUserData(about: about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedBotInfo(_ botInfo: BotInfo?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedReportStatus(_ reportStatus: PeerReportStatus) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedIsBlocked(_ isBlocked: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCommonGroupCount(_ commonGroupCount: Int32) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCallsAvailable(_ callsAvailable: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedCallsPrivate(_ callsPrivate: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: callsPrivate, hasAccountPeerPhone: self.hasAccountPeerPhone)
    }
    
    func withUpdatedHasAccountPeerPhone(_ hasAccountPeerPhone: Bool?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, hasAccountPeerPhone: hasAccountPeerPhone)
    }
}
