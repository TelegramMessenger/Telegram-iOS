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
    
    public let peerIds = Set<PeerId>()
    public let messageIds = Set<MessageId>()
    public let associatedHistoryPeerId: PeerId? = nil
    
    init() {
        self.about = nil
        self.botInfo = nil
        self.reportStatus = .unknown
        self.isBlocked = false
        self.commonGroupCount = 0
    }
    
    init(about: String?, botInfo: BotInfo?, reportStatus: PeerReportStatus, isBlocked: Bool, commonGroupCount: Int32) {
        self.about = about
        self.botInfo = botInfo
        self.reportStatus = reportStatus
        self.isBlocked = isBlocked
        self.commonGroupCount = commonGroupCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.about = decoder.decodeOptionalStringForKey("a")
        self.botInfo = decoder.decodeObjectForKey("bi") as? BotInfo
        self.reportStatus = PeerReportStatus(rawValue: decoder.decodeInt32ForKey("r", orElse: 0))!
        self.isBlocked = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.commonGroupCount = decoder.decodeInt32ForKey("cg", orElse: 0)
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
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedUserData else {
            return false
        }
        
        return other.about == self.about && other.botInfo == self.botInfo && self.reportStatus == other.reportStatus && self.isBlocked == other.isBlocked && self.commonGroupCount == other.commonGroupCount
    }
    
    func withUpdatedAbout(_ about: String?) -> CachedUserData {
        return CachedUserData(about: about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount)
    }
    
    func withUpdatedBotInfo(_ botInfo: BotInfo?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount)
    }
    
    func withUpdatedReportStatus(_ reportStatus: PeerReportStatus) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: reportStatus, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount)
    }
    
    func withUpdatedIsBlocked(_ isBlocked: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: isBlocked, commonGroupCount: self.commonGroupCount)
    }
    
    func withUpdatedCommonGroupCount(_ commonGroupCount: Int32) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, reportStatus: self.reportStatus, isBlocked: self.isBlocked, commonGroupCount: commonGroupCount)
    }
}
