import Postbox

public struct PeerStatusSettings: PostboxCoding, Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let canReport = Flags(rawValue: 1 << 1)
        public static let canShareContact = Flags(rawValue: 1 << 2)
        public static let canBlock = Flags(rawValue: 1 << 3)
        public static let canAddContact = Flags(rawValue: 1 << 4)
        public static let addExceptionWhenAddingContact = Flags(rawValue: 1 << 5)
        public static let autoArchived = Flags(rawValue: 1 << 7)
        public static let suggestAddMembers = Flags(rawValue: 1 << 8)

    }
    
    public struct ManagingBot: Codable, Equatable {
        public var id: PeerId
        public var manageUrl: String?
        public var isPaused: Bool
        public var canReply: Bool
        
        public init(id: PeerId, manageUrl: String?, isPaused: Bool, canReply: Bool) {
            self.id = id
            self.manageUrl = manageUrl
            self.isPaused = isPaused
            self.canReply = canReply
        }
    }
    
    public var flags: PeerStatusSettings.Flags
    public var geoDistance: Int32?
    public var requestChatTitle: String?
    public var requestChatDate: Int32?
    public var requestChatIsChannel: Bool?
    public var managingBot: ManagingBot?
    public var paidMessageStars: StarsAmount?
    public var registrationDate: String?
    public var phoneCountry: String?
    public var nameChangeDate: Int32?
    public var photoChangeDate: Int32?
    
    public init() {
        self.flags = PeerStatusSettings.Flags()
        self.geoDistance = nil
        self.requestChatTitle = nil
        self.requestChatDate = nil
        self.managingBot = nil
        self.paidMessageStars = nil
        self.registrationDate = nil
        self.phoneCountry = nil
        self.nameChangeDate = nil
        self.photoChangeDate = nil
    }
    
    public init(
        flags: PeerStatusSettings.Flags,
        geoDistance: Int32? = nil,
        requestChatTitle: String? = nil,
        requestChatDate: Int32? = nil,
        requestChatIsChannel: Bool? = nil,
        managingBot: ManagingBot? = nil,
        paidMessageStars: StarsAmount? = nil,
        registrationDate: String? = nil,
        phoneCountry: String? = nil,
        nameChangeDate: Int32? = nil,
        photoChangeDate: Int32? = nil
    ) {
        self.flags = flags
        self.geoDistance = geoDistance
        self.requestChatTitle = requestChatTitle
        self.requestChatDate = requestChatDate
        self.requestChatIsChannel = requestChatIsChannel
        self.managingBot = managingBot
        self.paidMessageStars = paidMessageStars
        self.registrationDate = registrationDate
        self.phoneCountry = phoneCountry
        self.nameChangeDate = nameChangeDate
        self.photoChangeDate = photoChangeDate
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("flags", orElse: 0))
        self.geoDistance = decoder.decodeOptionalInt32ForKey("geoDistance")
        self.requestChatTitle = decoder.decodeOptionalStringForKey("requestChatTitle")
        self.requestChatDate = decoder.decodeOptionalInt32ForKey("requestChatDate")
        self.requestChatIsChannel = decoder.decodeOptionalBoolForKey("requestChatIsChannel")
        self.managingBot = decoder.decodeCodable(ManagingBot.self, forKey: "managingBot")
        self.paidMessageStars = decoder.decodeCodable(StarsAmount.self, forKey: "paidMessageStars")
        self.registrationDate = decoder.decodeOptionalStringForKey("registrationDate")
        self.phoneCountry = decoder.decodeOptionalStringForKey("phoneCountry")
        self.nameChangeDate = decoder.decodeOptionalInt32ForKey("nameChangeDate")
        self.photoChangeDate = decoder.decodeOptionalInt32ForKey("photoChangeDate")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "flags")
        if let geoDistance = self.geoDistance {
            encoder.encodeInt32(geoDistance, forKey: "geoDistance")
        } else {
            encoder.encodeNil(forKey: "geoDistance")
        }
        if let requestChatTitle = self.requestChatTitle {
            encoder.encodeString(requestChatTitle, forKey: "requestChatTitle")
        } else {
            encoder.encodeNil(forKey: "requestChatTitle")
        }
        if let requestChatDate = self.requestChatDate {
            encoder.encodeInt32(requestChatDate, forKey: "requestChatDate")
        } else {
            encoder.encodeNil(forKey: "requestChatDate")
        }
        if let requestChatIsChannel = self.requestChatIsChannel {
            encoder.encodeBool(requestChatIsChannel, forKey: "requestChatIsChannel")
        } else {
            encoder.encodeNil(forKey: "requestChatIsChannel")
        }
        if let managingBot = self.managingBot {
            encoder.encodeCodable(managingBot, forKey: "managingBot")
        } else {
            encoder.encodeNil(forKey: "managingBot")
        }
        if let paidMessageStars = self.paidMessageStars {
            encoder.encodeCodable(paidMessageStars, forKey: "paidMessageStars")
        } else {
            encoder.encodeNil(forKey: "paidMessageStars")
        }
        if let registrationDate = self.registrationDate {
            encoder.encodeString(registrationDate, forKey: "registrationDate")
        } else {
            encoder.encodeNil(forKey: "registrationDate")
        }
        if let phoneCountry = self.phoneCountry {
            encoder.encodeString(phoneCountry, forKey: "phoneCountry")
        } else {
            encoder.encodeNil(forKey: "phoneCountry")
        }
        if let nameChangeDate = self.nameChangeDate {
            encoder.encodeInt32(nameChangeDate, forKey: "nameChangeDate")
        } else {
            encoder.encodeNil(forKey: "nameChangeDate")
        }
        if let photoChangeDate = self.photoChangeDate {
            encoder.encodeInt32(photoChangeDate, forKey: "photoChangeDate")
        } else {
            encoder.encodeNil(forKey: "photoChangeDate")
        }
    }
    
    public func contains(_ member: PeerStatusSettings.Flags) -> Bool {
        return self.flags.contains(member)
    }
}
