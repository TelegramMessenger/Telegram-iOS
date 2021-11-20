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
    public var requestChatPeerId: PeerId?
    public var requestChatDate: Int32?
    
    public init() {
        self.flags = PeerStatusSettings.Flags()
        self.geoDistance = nil
        self.requestChatPeerId = nil
        self.requestChatDate = nil
    }
    
    public init(flags: PeerStatusSettings.Flags, geoDistance: Int32? = nil, requestChatPeerId: PeerId? = nil, requestChatDate: Int32? = nil) {
        self.flags = flags
        self.geoDistance = geoDistance
        self.requestChatPeerId = requestChatPeerId
        self.requestChatDate = requestChatDate
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("flags", orElse: 0))
        self.geoDistance = decoder.decodeOptionalInt32ForKey("geoDistance")
        self.requestChatPeerId = decoder.decodeOptionalInt64ForKey("requestChatPeerId").map { PeerId($0) }
        self.requestChatDate = decoder.decodeOptionalInt32ForKey("requestChatDate")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "flags")
        if let geoDistance = self.geoDistance {
            encoder.encodeInt32(geoDistance, forKey: "geoDistance")
        } else {
            encoder.encodeNil(forKey: "geoDistance")
        }
        if let requestChatPeerId = self.requestChatPeerId {
            encoder.encodeInt64(requestChatPeerId.toInt64(), forKey: "requestChatPeerId")
        } else {
            encoder.encodeNil(forKey: "requestPeerId")
        }
        if let requestChatDate = self.requestChatDate {
            encoder.encodeInt32(requestChatDate, forKey: "requestChatDate")
        } else {
            encoder.encodeNil(forKey: "requestChatDate")
        }
    }
    
    public func contains(_ member: PeerStatusSettings.Flags) -> Bool {
        return self.flags.contains(member)
    }
}
