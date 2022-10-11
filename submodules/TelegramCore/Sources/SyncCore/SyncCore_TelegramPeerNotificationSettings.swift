import Foundation
import Postbox

private let cloudSoundMapping: [Int32: Int64] = [
    2: 5078299559046677200,
    3: 5078299559046677201,
    4: 5078299559046677202,
    5: 5078299559046677203,
    6: 5078299559046677204,
    7: 5078299559046677205,
    8: 5078299559046677206,
    9: 5078299559046677207,
    100: 5078299559046677208,
    101: 5078299559046677209,
    102: 5078299559046677210,
    103: 5078299559046677211,
    104: 5078299559046677212,
    105: 5078299559046677213,
    106: 5078299559046677214,
    107: 5078299559046677215,
    108: 5078299559046677216,
    109: 5078299559046677217,
    110: 5078299559046677218,
    111: 5078299559046677219
]

public let defaultCloudPeerNotificationSound: PeerMessageSound = .cloud(fileId: cloudSoundMapping[100]!)

public enum CloudSoundBuiltinCategory {
    case modern
    case classic
    
    public init?(id: Int64) {
        for (key, value) in cloudSoundMapping {
            if value == id {
                if key < 50 {
                    self = .classic
                    return
                } else {
                    self = .modern
                    return
                }
            }
        }
        return nil
    }
}

private func getCloudSoundOrDefault(id: Int32, isModern: Bool) -> Int64 {
    if isModern {
        if let value = cloudSoundMapping[id + 100] {
            return value
        }
    } else {
        if let value = cloudSoundMapping[id + 2] {
            return value
        }
    }
    
    return cloudSoundMapping[100]!
}

public func getCloudLegacySound(id: Int64) -> (id: Int32, category: CloudSoundBuiltinCategory)? {
    for (key, value) in cloudSoundMapping {
        if value == id {
            if key < 50 {
                return (key - 2, .classic)
            } else {
                return (key - 100, .modern)
            }
        }
    }
    return nil
}

public enum PeerMuteState: Codable, Equatable {
    case `default`
    case unmuted
    case muted(until: Int32)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        switch try container.decode(Int32.self, forKey: "m.v") {
        case 0:
            self = .default
        case 1:
            self = .muted(until: try container.decode(Int32.self, forKey: "m.u"))
        case 2:
            self = .unmuted
        default:
            assertionFailure()
            self = .default
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        switch self {
        case .default:
            try container.encode(0 as Int32, forKey: "m.v")
        case let .muted(until):
            try container.encode(1 as Int32, forKey: "m.v")
            try container.encode(until, forKey: "m.u")
        case .unmuted:
            try container.encode(2 as Int32, forKey: "m.v")
        }
    }
    
    fileprivate static func decodeInline(_ decoder: PostboxDecoder) -> PeerMuteState {
        switch decoder.decodeInt32ForKey("m.v", orElse: 0) {
            case 0:
                return .default
            case 1:
                return .muted(until: decoder.decodeInt32ForKey("m.u", orElse: 0))
            case 2:
                return .unmuted
            default:
                return .default
        }
    }
    
    fileprivate func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .default:
                encoder.encodeInt32(0, forKey: "m.v")
            case let .muted(until):
                encoder.encodeInt32(1, forKey: "m.v")
                encoder.encodeInt32(until, forKey: "m.u")
            case .unmuted:
                encoder.encodeInt32(2, forKey: "m.v")
        }
    }
}

private enum PeerMessageSoundValue: Int32, Codable {
    case none = 0
    case bundledModern = 1
    case bundledClassic = 2
    case `default` = 3
    case cloud = 4
}

public enum PeerMessageSound: Equatable, Codable {
    public enum Id: Hashable {
        case none
        case `default`
        case bundledModern(id: Int32)
        case bundledClassic(id: Int32)
        case cloud(fileId: Int64)
    }
    
    case none
    case `default`
    case bundledModern(id: Int32)
    case bundledClassic(id: Int32)
    case cloud(fileId: Int64)
    
    public var id: Id {
        switch self {
        case .none:
            return .none
        case .default:
            return .default
        case let .bundledModern(id):
            return .bundledModern(id: id)
        case let .bundledClassic(id):
            return .bundledClassic(id: id)
        case let .cloud(fileId):
            return .cloud(fileId: fileId)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        switch try container.decode(Int32.self, forKey: "s.v") {
        case PeerMessageSoundValue.none.rawValue:
            self = .none
        case PeerMessageSoundValue.bundledModern.rawValue:
            self = .cloud(fileId: getCloudSoundOrDefault(id: (try? container.decode(Int32.self, forKey: "s.i")) ?? 0, isModern: true))
        case PeerMessageSoundValue.bundledClassic.rawValue:
            self = .cloud(fileId: getCloudSoundOrDefault(id: (try? container.decode(Int32.self, forKey: "s.i")) ?? 0, isModern: false))
        case PeerMessageSoundValue.default.rawValue:
            self = .default
        case PeerMessageSoundValue.cloud.rawValue:
            do {
                self = .cloud(fileId: try container.decode(Int64.self, forKey: "s.cloud.fileId"))
            } catch {
                self = .default
            }
        default:
            assertionFailure()
            self = defaultCloudPeerNotificationSound
        }
    }
    
    static func decodeInline(_ container: KeyedDecodingContainer<StringCodingKey>) throws -> PeerMessageSound {
        switch try container.decode(Int32.self, forKey: "s.v") {
        case PeerMessageSoundValue.none.rawValue:
            return .none
        case PeerMessageSoundValue.bundledModern.rawValue:
            return .cloud(fileId: getCloudSoundOrDefault(id: (try? container.decode(Int32.self, forKey: "s.i")) ?? 0, isModern: true))
        case PeerMessageSoundValue.bundledClassic.rawValue:
            return .cloud(fileId: getCloudSoundOrDefault(id: (try? container.decode(Int32.self, forKey: "s.i")) ?? 0, isModern: false))
        case PeerMessageSoundValue.default.rawValue:
            return .default
        case PeerMessageSoundValue.cloud.rawValue:
            do {
                return .cloud(fileId: try container.decode(Int64.self, forKey: "s.cloud.fileId"))
            } catch {
                return .default
            }
        default:
            assertionFailure()
            return defaultCloudPeerNotificationSound
        }
    }

    static func decodeInline(_ container: PostboxDecoder) -> PeerMessageSound {
        switch container.decodeInt32ForKey("s.v", orElse: 0) {
        case PeerMessageSoundValue.none.rawValue:
            return .none
        case PeerMessageSoundValue.bundledModern.rawValue:
            return .cloud(fileId: getCloudSoundOrDefault(id: container.decodeInt32ForKey("s.i", orElse: 0), isModern: true))
        case PeerMessageSoundValue.bundledClassic.rawValue:
            return .cloud(fileId: getCloudSoundOrDefault(id: container.decodeInt32ForKey("s.i", orElse: 0), isModern: false))
        case PeerMessageSoundValue.default.rawValue:
            return .default
        case PeerMessageSoundValue.cloud.rawValue:
            return .cloud(fileId: container.decodeInt64ForKey("s.cloud.fileId", orElse: 0))
        default:
            assertionFailure()
            return defaultCloudPeerNotificationSound
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        switch self {
        case .none:
            try container.encode(PeerMessageSoundValue.none.rawValue, forKey: "s.v")
        case let .bundledModern(id):
            try container.encode(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s.v")
            try container.encode(id, forKey: "s.i")
        case let .bundledClassic(id):
            try container.encode(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s.v")
            try container.encode(id, forKey: "s.i")
        case let .cloud(fileId):
            try container.encode(PeerMessageSoundValue.cloud.rawValue, forKey: "s.v")
            try container.encode(fileId, forKey: "s.cloud.fileId")
        case .default:
            try container.encode(PeerMessageSoundValue.default.rawValue, forKey: "s.v")
        }
    }

    func encodeInline(_ container: inout KeyedEncodingContainer<StringCodingKey>) throws {
        switch self {
        case .none:
            try container.encode(PeerMessageSoundValue.none.rawValue, forKey: "s.v")
        case let .bundledModern(id):
            try container.encode(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s.v")
            try container.encode(id, forKey: "s.i")
        case let .bundledClassic(id):
            try container.encode(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s.v")
            try container.encode(id, forKey: "s.i")
        case let .cloud(fileId):
            try container.encode(PeerMessageSoundValue.cloud.rawValue, forKey: "s.v")
            try container.encode(fileId, forKey: "s.cloud.fileId")
        case .default:
            try container.encode(PeerMessageSoundValue.default.rawValue, forKey: "s.v")
        }
    }
    
    func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
        case .none:
            encoder.encodeInt32(PeerMessageSoundValue.none.rawValue, forKey: "s.v")
        case let .bundledModern(id):
            encoder.encodeInt32(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s.v")
            encoder.encodeInt32(id, forKey: "s.i")
        case let .bundledClassic(id):
            encoder.encodeInt32(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s.v")
            encoder.encodeInt32(id, forKey: "s.i")
        case let .cloud(fileId):
            encoder.encodeInt32(PeerMessageSoundValue.cloud.rawValue, forKey: "s.v")
            encoder.encodeInt64(fileId, forKey: "s.cloud.fileId")
        case .default:
            encoder.encodeInt32(PeerMessageSoundValue.default.rawValue, forKey: "s.v")
        }
    }
    
    public static func ==(lhs: PeerMessageSound, rhs: PeerMessageSound) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .bundledModern(id):
            if case .bundledModern(id) = rhs {
                return true
            } else {
                return false
            }
        case let .bundledClassic(id):
            if case .bundledClassic(id) = rhs {
                return true
            } else {
                return false
            }
        case .default:
            if case .default = rhs {
                return true
            } else {
                return false
            }
        case let .cloud(fileId):
            if case .cloud(fileId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public enum PeerNotificationDisplayPreviews: Equatable, Codable {
    case `default`
    case show
    case hide
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        switch try container.decode(Int32.self, forKey: "p.v") {
        case 0:
            self = .default
        case 1:
            self = .show
        case 2:
            self = .hide
        default:
            assertionFailure()
            self = .default
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        switch self {
        case .default:
            try container.encode(0 as Int32, forKey: "p.v")
        case .show:
            try container.encode(1 as Int32, forKey: "p.v")
        case .hide:
            try container.encode(2 as Int32, forKey: "p.v")
        }
    }
    
    static func decodeInline(_ decoder: PostboxDecoder) -> PeerNotificationDisplayPreviews {
        switch decoder.decodeInt32ForKey("p.v", orElse: 0) {
            case 0:
                return .default
            case 1:
                return .show
            case 2:
                return .hide
            default:
                assertionFailure()
                return .default
        }
    }
    
    func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .default:
                encoder.encodeInt32(0, forKey: "p.v")
            case .show:
                encoder.encodeInt32(1, forKey: "p.v")
            case .hide:
                encoder.encodeInt32(2, forKey: "p.v")
        }
    }
}

public final class TelegramPeerNotificationSettings: PeerNotificationSettings, Codable, Equatable {
    public let muteState: PeerMuteState
    public let messageSound: PeerMessageSound
    public let displayPreviews: PeerNotificationDisplayPreviews
    
    public static var defaultSettings: TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: .default)
    }
    
    public func isRemovedFromTotalUnreadCount(`default`: Bool) -> Bool {
        switch self.muteState {
            case .unmuted:
                return false
            case .muted:
                return true
            case .default:
                return `default`
        }
    }
    
    public var behavior: PeerNotificationSettingsBehavior {
        if case let .muted(untilTimestamp) = self.muteState, untilTimestamp < Int32.max {
            return .reset(atTimestamp: untilTimestamp, toValue: self.withUpdatedMuteState(.unmuted))
        } else {
            return .none
        }
    }
    
    public init(muteState: PeerMuteState, messageSound: PeerMessageSound, displayPreviews: PeerNotificationDisplayPreviews) {
        self.muteState = muteState
        self.messageSound = messageSound
        self.displayPreviews = displayPreviews
    }
    
    public init(decoder: PostboxDecoder) {
        self.muteState = PeerMuteState.decodeInline(decoder)
        self.messageSound = PeerMessageSound.decodeInline(decoder)
        self.displayPreviews = PeerNotificationDisplayPreviews.decodeInline(decoder)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.muteState = try container.decode(PeerMuteState.self, forKey: "muteState")
        self.messageSound = try container.decode(PeerMessageSound.self, forKey: "messageSound")
        self.displayPreviews = try container.decode(PeerNotificationDisplayPreviews.self, forKey: "displayPreviews")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.muteState, forKey: "muteState")
        try container.encode(self.messageSound, forKey: "messageSound")
        try container.encode(self.displayPreviews, forKey: "displayPreviews")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        self.muteState.encodeInline(encoder)
        self.messageSound.encodeInline(encoder)
        self.displayPreviews.encodeInline(encoder)
    }
    
    public func isEqual(to: PeerNotificationSettings) -> Bool {
        if let to = to as? TelegramPeerNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public func withUpdatedMuteState(_ muteState: PeerMuteState) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: muteState, messageSound: self.messageSound, displayPreviews: self.displayPreviews)
    }
    
    public func withUpdatedMessageSound(_ messageSound: PeerMessageSound) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: self.muteState, messageSound: messageSound, displayPreviews: self.displayPreviews)
    }
    
    public func withUpdatedDisplayPreviews(_ displayPreviews: PeerNotificationDisplayPreviews) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: self.muteState, messageSound: self.messageSound, displayPreviews: displayPreviews)
    }
    
    public static func ==(lhs: TelegramPeerNotificationSettings, rhs: TelegramPeerNotificationSettings) -> Bool {
        return lhs.muteState == rhs.muteState && lhs.messageSound == rhs.messageSound && lhs.displayPreviews == rhs.displayPreviews
    }
}
