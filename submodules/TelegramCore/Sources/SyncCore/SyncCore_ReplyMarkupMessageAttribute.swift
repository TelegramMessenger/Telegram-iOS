import Postbox

public enum ReplyMarkupButtonRequestPeerType: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case discriminator = "d"
        case user = "u"
        case group = "g"
        case channel = "c"
    }
    
    enum Discriminator: Int32 {
        case user = 0
        case group = 1
        case channel = 2
    }
    
    public struct User: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case isBot = "b"
            case isPremium = "p"
        }
        
        public var isBot: Bool?
        public var isPremium: Bool?
        
        public init(isBot: Bool?, isPremium: Bool?) {
            self.isBot = isBot
            self.isPremium = isPremium
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot)
            self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(self.isBot, forKey: .isBot)
            try container.encodeIfPresent(self.isPremium, forKey: .isPremium)
        }
    }
    
    public struct Group: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case isCreator = "cr"
            case hasUsername = "un"
            case isForum = "fo"
            case botParticipant = "bo"
            case userAdminRights = "ur"
            case botAdminRights = "br"
        }
        
        public var isCreator: Bool
        public var hasUsername: Bool?
        public var isForum: Bool?
        public var botParticipant: Bool
        public var userAdminRights: TelegramChatAdminRights?
        public var botAdminRights: TelegramChatAdminRights?
        
        public init(
            isCreator: Bool,
            hasUsername: Bool?,
            isForum: Bool?,
            botParticipant: Bool,
            userAdminRights: TelegramChatAdminRights?,
            botAdminRights: TelegramChatAdminRights?
        ) {
            self.isCreator = isCreator
            self.hasUsername = hasUsername
            self.isForum = isForum
            self.botParticipant = botParticipant
            self.userAdminRights = userAdminRights
            self.botAdminRights = botAdminRights
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isCreator = try container.decode(Bool.self, forKey: .isCreator)
            self.hasUsername = try container.decodeIfPresent(Bool.self, forKey: .hasUsername)
            self.isForum = try container.decodeIfPresent(Bool.self, forKey: .isForum)
            self.botParticipant = try container.decode(Bool.self, forKey: .botParticipant)
            self.userAdminRights = try container.decodeIfPresent(TelegramChatAdminRights.self, forKey: .userAdminRights)
            self.botAdminRights = try container.decodeIfPresent(TelegramChatAdminRights.self, forKey: .botAdminRights)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.isCreator, forKey: .isCreator)
            try container.encodeIfPresent(self.hasUsername, forKey: .hasUsername)
            try container.encodeIfPresent(self.isForum, forKey: .isForum)
            try container.encode(self.botParticipant, forKey: .botParticipant)
            try container.encodeIfPresent(self.userAdminRights, forKey: .userAdminRights)
            try container.encodeIfPresent(self.botAdminRights, forKey: .botAdminRights)
        }
    }
    
    public struct Channel: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case isCreator = "cr"
            case hasUsername = "un"
            case userAdminRights = "ur"
            case botAdminRights = "br"
        }
        
        public var isCreator: Bool
        public var hasUsername: Bool?
        public var userAdminRights: TelegramChatAdminRights?
        public var botAdminRights: TelegramChatAdminRights?
        
        public init(
            isCreator: Bool,
            hasUsername: Bool?,
            userAdminRights: TelegramChatAdminRights?,
            botAdminRights: TelegramChatAdminRights?
        ) {
            self.isCreator = isCreator
            self.hasUsername = hasUsername
            self.userAdminRights = userAdminRights
            self.botAdminRights = botAdminRights
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isCreator = try container.decode(Bool.self, forKey: .isCreator)
            self.hasUsername = try container.decodeIfPresent(Bool.self, forKey: .hasUsername)
            self.userAdminRights = try container.decodeIfPresent(TelegramChatAdminRights.self, forKey: .userAdminRights)
            self.botAdminRights = try container.decodeIfPresent(TelegramChatAdminRights.self, forKey: .botAdminRights)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.isCreator, forKey: .isCreator)
            try container.encodeIfPresent(self.hasUsername, forKey: .hasUsername)
            try container.encodeIfPresent(self.userAdminRights, forKey: .userAdminRights)
            try container.encodeIfPresent(self.botAdminRights, forKey: .botAdminRights)
        }
    }
    
    case user(User)
    case group(Group)
    case channel(Channel)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        switch try container.decode(Int32.self, forKey: .discriminator) {
        case Discriminator.user.rawValue:
            self = .user(try container.decode(User.self, forKey: .user))
        case Discriminator.group.rawValue:
            self = .group(try container.decode(Group.self, forKey: .group))
        case Discriminator.channel.rawValue:
            self = .channel(try container.decode(Channel.self, forKey: .channel))
        default:
            assertionFailure()
            self = .user(User(isBot: nil, isPremium: nil))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .user(user):
            try container.encode(Discriminator.user.rawValue, forKey: .discriminator)
            try container.encode(user, forKey: .user)
        case let .group(group):
            try container.encode(Discriminator.group.rawValue, forKey: .discriminator)
            try container.encode(group, forKey: .group)
        case let .channel(channel):
            try container.encode(Discriminator.channel.rawValue, forKey: .discriminator)
            try container.encode(channel, forKey: .channel)
        }
    }
}

public enum ReplyMarkupButtonAction: PostboxCoding, Equatable {
    public struct PeerTypes: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let users = PeerTypes(rawValue: 1 << 0)
        public static let bots = PeerTypes(rawValue: 1 << 1)
        public static let channels = PeerTypes(rawValue: 1 << 2)
        public static let groups = PeerTypes(rawValue: 1 << 3)
        
        public var requestPeerTypes: [ReplyMarkupButtonRequestPeerType]? {
            if self.isEmpty {
                return nil
            }
            
            var types: [ReplyMarkupButtonRequestPeerType] = []
            if self.contains(.users) {
                types.append(.user(.init(isBot: false, isPremium: nil)))
            }
            if self.contains(.bots) {
                types.append(.user(.init(isBot: true, isPremium: nil)))
            }
            if self.contains(.channels) {
                types.append(.channel(.init(isCreator: false, hasUsername: nil, userAdminRights: nil, botAdminRights: nil)))
            }
            if self.contains(.groups) {
                types.append(.group(.init(isCreator: false, hasUsername: nil, isForum: nil, botParticipant: false, userAdminRights: nil, botAdminRights: nil)))
            }
            return types
        }
    }
    
    case text
    case url(String)
    case callback(requiresPassword: Bool, data: MemoryBuffer)
    case requestPhone
    case requestMap
    case switchInline(samePeer: Bool, query: String, peerTypes: PeerTypes)
    case openWebApp
    case payment
    case urlAuth(url: String, buttonId: Int32)
    case setupPoll(isQuiz: Bool?)
    case openUserProfile(peerId: PeerId)
    case openWebView(url: String, simple: Bool)
    case requestPeer(peerType: ReplyMarkupButtonRequestPeerType, buttonId: Int32)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .text
            case 1:
                self = .url(decoder.decodeStringForKey("u", orElse: ""))
            case 2:
                self = .callback(requiresPassword: decoder.decodeInt32ForKey("p", orElse: 0) != 0, data: decoder.decodeBytesForKey("d") ?? MemoryBuffer())
            case 3:
                self = .requestPhone
            case 4:
                self = .requestMap
            case 5:
                self = .switchInline(samePeer: decoder.decodeInt32ForKey("s", orElse: 0) != 0, query: decoder.decodeStringForKey("q", orElse: ""), peerTypes: PeerTypes(rawValue: decoder.decodeInt32ForKey("pt", orElse: 0)))
            case 6:
                self = .openWebApp
            case 7:
                self = .payment
            case 8:
                self = .urlAuth(url: decoder.decodeStringForKey("u", orElse: ""), buttonId: decoder.decodeInt32ForKey("b", orElse: 0))
            case 9:
                self = .setupPoll(isQuiz: decoder.decodeOptionalInt32ForKey("isq").flatMap { $0 != 0 })
            case 10:
                self = .openUserProfile(peerId: PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0)))
            case 11:
                self = .openWebView(url: decoder.decodeStringForKey("u", orElse: ""), simple: decoder.decodeInt32ForKey("s", orElse: 0) != 0)
            case 12:
                self = .requestPeer(peerType: decoder.decode(ReplyMarkupButtonRequestPeerType.self, forKey: "pt") ?? ReplyMarkupButtonRequestPeerType.user(ReplyMarkupButtonRequestPeerType.User(isBot: nil, isPremium: nil)), buttonId: decoder.decodeInt32ForKey("b", orElse: 0))
            default:
                self = .text
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .text:
            encoder.encodeInt32(0, forKey: "v")
        case let .url(url):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeString(url, forKey: "u")
        case let .callback(requiresPassword, data):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeInt32(requiresPassword ? 1 : 0, forKey: "p")
            encoder.encodeBytes(data, forKey: "d")
        case .requestPhone:
            encoder.encodeInt32(3, forKey: "v")
        case .requestMap:
            encoder.encodeInt32(4, forKey: "v")
        case let .switchInline(samePeer, query, peerTypes):
            encoder.encodeInt32(5, forKey: "v")
            encoder.encodeInt32(samePeer ? 1 : 0, forKey: "s")
            encoder.encodeString(query, forKey: "q")
            encoder.encodeInt32(peerTypes.rawValue, forKey: "pt")
        case .openWebApp:
            encoder.encodeInt32(6, forKey: "v")
        case .payment:
            encoder.encodeInt32(7, forKey: "v")
        case let .urlAuth(url, buttonId):
            encoder.encodeInt32(8, forKey: "v")
            encoder.encodeString(url, forKey: "u")
            encoder.encodeInt32(buttonId, forKey: "b")
        case let .setupPoll(isQuiz):
            encoder.encodeInt32(9, forKey: "v")
            if let isQuiz = isQuiz {
                encoder.encodeInt32(isQuiz ? 1 : 0, forKey: "isq")
            } else {
                encoder.encodeNil(forKey: "isq")
            }
        case let .openUserProfile(peerId):
            encoder.encodeInt32(10, forKey: "v")
            encoder.encodeInt64(peerId.toInt64(), forKey: "peerId")
        case let .openWebView(url, simple):
            encoder.encodeInt32(11, forKey: "v")
            encoder.encodeString(url, forKey: "u")
            encoder.encodeInt32(simple ? 1 : 0, forKey: "s")
        case let .requestPeer(peerType, buttonId):
            encoder.encodeInt32(12, forKey: "v")
            encoder.encodeInt32(buttonId, forKey: "b")
            encoder.encode(peerType, forKey: "pt")
        }
    }
}

public struct ReplyMarkupButton: PostboxCoding, Equatable {
    public let title: String
    public let titleWhenForwarded: String?
    public let action: ReplyMarkupButtonAction
    
    public init(title: String, titleWhenForwarded: String?, action: ReplyMarkupButtonAction) {
        self.title = title
        self.titleWhenForwarded = titleWhenForwarded
        self.action = action
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey(".t", orElse: "")
        self.titleWhenForwarded = decoder.decodeOptionalStringForKey(".tf")
        self.action = ReplyMarkupButtonAction(decoder: decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: ".t")
        if let titleWhenForwarded = self.titleWhenForwarded {
            encoder.encodeString(titleWhenForwarded, forKey: ".tf")
        } else {
            encoder.encodeNil(forKey: ".tf")
        }
        self.action.encode(encoder)
    }
    
    public static func ==(lhs: ReplyMarkupButton, rhs: ReplyMarkupButton) -> Bool {
        return lhs.title == rhs.title && lhs.action == rhs.action
    }
}

public struct ReplyMarkupRow: PostboxCoding, Equatable {
    public let buttons: [ReplyMarkupButton]
    
    public init(buttons: [ReplyMarkupButton]) {
        self.buttons = buttons
    }
    
    public init(decoder: PostboxDecoder) {
        self.buttons = decoder.decodeObjectArrayWithDecoderForKey("b")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.buttons, forKey: "b")
    }
    
    public static func ==(lhs: ReplyMarkupRow, rhs: ReplyMarkupRow) -> Bool {
        return lhs.buttons == rhs.buttons
    }
}

public struct ReplyMarkupMessageFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let once = ReplyMarkupMessageFlags(rawValue: 1 << 0)
    public static let personal = ReplyMarkupMessageFlags(rawValue: 1 << 1)
    public static let setupReply = ReplyMarkupMessageFlags(rawValue: 1 << 2)
    public static let inline = ReplyMarkupMessageFlags(rawValue: 1 << 3)
    public static let fit = ReplyMarkupMessageFlags(rawValue: 1 << 4)
    public static let persistent = ReplyMarkupMessageFlags(rawValue: 1 << 5)
}

public class ReplyMarkupMessageAttribute: MessageAttribute, Equatable {
    public let rows: [ReplyMarkupRow]
    public let flags: ReplyMarkupMessageFlags
    public let placeholder: String?
    
    public init(rows: [ReplyMarkupRow], flags: ReplyMarkupMessageFlags, placeholder: String?) {
        self.rows = rows
        self.flags = flags
        self.placeholder = placeholder
    }
    
    public required init(decoder: PostboxDecoder) {
        self.rows = decoder.decodeObjectArrayWithDecoderForKey("r")
        self.flags = ReplyMarkupMessageFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.placeholder = decoder.decodeOptionalStringForKey("pl")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.rows, forKey: "r")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let placeholder = self.placeholder {
            encoder.encodeString(placeholder, forKey: "pl")
        } else {
            encoder.encodeNil(forKey: "pl")
        }
    }
    
    public static func ==(lhs: ReplyMarkupMessageAttribute, rhs: ReplyMarkupMessageAttribute) -> Bool {
        return lhs.flags == rhs.flags && lhs.rows == rhs.rows && lhs.placeholder == rhs.placeholder
    }
}
