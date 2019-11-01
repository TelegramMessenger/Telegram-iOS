import Foundation
import Postbox

public final class CachedUserData: CachedPeerData {
    public let about: String?
    public let botInfo: BotInfo?
    public let peerStatusSettings: PeerStatusSettings?
    public let pinnedMessageId: MessageId?
    public let isBlocked: Bool
    public let commonGroupCount: Int32
    public let callsAvailable: Bool
    public let callsPrivate: Bool
    public let canPinMessages: Bool
    public let hasScheduledMessages: Bool
    
    public let peerIds = Set<PeerId>()
    public let messageIds: Set<MessageId>
    public let associatedHistoryMessageId: MessageId? = nil
    
    public init() {
        self.about = nil
        self.botInfo = nil
        self.peerStatusSettings = nil
        self.pinnedMessageId = nil
        self.isBlocked = false
        self.commonGroupCount = 0
        self.callsAvailable = false
        self.callsPrivate = false
        self.canPinMessages = false
        self.hasScheduledMessages = false
        self.messageIds = Set()
    }
    
    public init(about: String?, botInfo: BotInfo?, peerStatusSettings: PeerStatusSettings?, pinnedMessageId: MessageId?, isBlocked: Bool, commonGroupCount: Int32, callsAvailable: Bool, callsPrivate: Bool, canPinMessages: Bool, hasScheduledMessages: Bool) {
        self.about = about
        self.botInfo = botInfo
        self.peerStatusSettings = peerStatusSettings
        self.pinnedMessageId = pinnedMessageId
        self.isBlocked = isBlocked
        self.commonGroupCount = commonGroupCount
        self.callsAvailable = callsAvailable
        self.callsPrivate = callsPrivate
        self.canPinMessages = canPinMessages
        self.hasScheduledMessages = hasScheduledMessages
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
    }
    
    public init(decoder: PostboxDecoder) {
        self.about = decoder.decodeOptionalStringForKey("a")
        self.botInfo = decoder.decodeObjectForKey("bi") as? BotInfo
        if let value = decoder.decodeOptionalInt32ForKey("pcs") {
            self.peerStatusSettings = PeerStatusSettings(rawValue: value)
        } else {
            self.peerStatusSettings = nil
        }
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
        self.hasScheduledMessages = decoder.decodeBoolForKey("hsm", orElse: false)
        
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
        if let peerStatusSettings = self.peerStatusSettings {
            encoder.encodeInt32(peerStatusSettings.rawValue, forKey: "pcs")
        } else {
            encoder.encodeNil(forKey: "pcs")
        }
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
        encoder.encodeBool(self.hasScheduledMessages, forKey: "hsm")
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
        
        return other.about == self.about && other.botInfo == self.botInfo && self.peerStatusSettings == other.peerStatusSettings && self.isBlocked == other.isBlocked && self.commonGroupCount == other.commonGroupCount && self.callsAvailable == other.callsAvailable && self.callsPrivate == other.callsPrivate && self.hasScheduledMessages == other.hasScheduledMessages
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedUserData {
        return CachedUserData(about: about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedBotInfo(_ botInfo: BotInfo?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedIsBlocked(_ isBlocked: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedCommonGroupCount(_ commonGroupCount: Int32) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedCallsAvailable(_ callsAvailable: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedCallsPrivate(_ callsPrivate: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedCanPinMessages(_ canPinMessages: Bool) -> CachedUserData {
        return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: canPinMessages, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> CachedUserData {
         return CachedUserData(about: self.about, botInfo: self.botInfo, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, isBlocked: self.isBlocked, commonGroupCount: self.commonGroupCount, callsAvailable: self.callsAvailable, callsPrivate: self.callsPrivate, canPinMessages: self.canPinMessages, hasScheduledMessages: hasScheduledMessages)
    }
}
