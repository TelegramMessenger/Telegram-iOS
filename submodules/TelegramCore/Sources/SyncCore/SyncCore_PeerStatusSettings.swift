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
        public static let canReportIrrelevantGeoLocation = Flags(rawValue: 1 << 6)
        public static let autoArchived = Flags(rawValue: 1 << 7)
        public static let suggestAddMembers = Flags(rawValue: 1 << 8)

    }
    
    public var flags: PeerStatusSettings.Flags
    public var geoDistance: Int32?
    public var requestChatTitle: String?
    public var requestChatDate: Int32?
    public var requestChatIsChannel: Bool?
    
    public init() {
        self.flags = PeerStatusSettings.Flags()
        self.geoDistance = nil
        self.requestChatTitle = nil
        self.requestChatDate = nil
    }
    
    public init(flags: PeerStatusSettings.Flags, geoDistance: Int32? = nil, requestChatTitle: String? = nil, requestChatDate: Int32? = nil, requestChatIsChannel: Bool? = nil) {
        self.flags = flags
        self.geoDistance = geoDistance
        self.requestChatTitle = requestChatTitle
        self.requestChatDate = requestChatDate
        self.requestChatIsChannel = requestChatIsChannel
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("flags", orElse: 0))
        self.geoDistance = decoder.decodeOptionalInt32ForKey("geoDistance")
        self.requestChatTitle = decoder.decodeOptionalStringForKey("requestChatTitle")
        self.requestChatDate = decoder.decodeOptionalInt32ForKey("requestChatDate")
        self.requestChatIsChannel = decoder.decodeOptionalBoolForKey("requestChatIsChannel")
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
    }
    
    public func contains(_ member: PeerStatusSettings.Flags) -> Bool {
        return self.flags.contains(member)
    }
}
