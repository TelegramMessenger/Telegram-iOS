import Postbox

public let liveLocationIndefinitePeriod: Int32 = 0x7fffffff

public final class MapGeoAddress: PostboxCoding, Equatable {
    public let country: String
    public let state: String?
    public let city: String?
    public let street: String?
    
    public init(country: String, state: String?, city: String?, street: String?) {
        self.country = country
        self.state = state
        self.city = city
        self.street = street
    }
    
    public init(decoder: PostboxDecoder) {
        self.country = decoder.decodeStringForKey("gp_co", orElse: "")
        self.state = decoder.decodeOptionalStringForKey("gp_sta")
        self.city = decoder.decodeOptionalStringForKey("gp_ci")
        self.street = decoder.decodeOptionalStringForKey("gp_str")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(country, forKey: "gp_co")
        
        if let state = self.state {
            encoder.encodeString(state, forKey: "gp_sta")
        }
        
        if let city = self.city {
            encoder.encodeString(city, forKey: "gp_ci")
        }
        
        if let street = self.street {
            encoder.encodeString(street, forKey: "gp_str")
        }
    }
    
    public static func ==(lhs: MapGeoAddress, rhs: MapGeoAddress) -> Bool {
        if lhs.country != rhs.country {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.city != rhs.city {
            return false
        }
        if lhs.street != rhs.street {
            return false
        }
        return true
    }
}

public final class MapVenue: PostboxCoding, Equatable {
    public let title: String
    public let address: String?
    public let provider: String?
    public let id: String?
    public let type: String?
    
    public init(title: String, address: String?, provider: String?, id: String?, type: String?) {
        self.title = title
        self.address = address
        self.provider = provider
        self.id = id
        self.type = type
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("ti", orElse: "")
        self.address = decoder.decodeOptionalStringForKey("ad")
        self.provider = decoder.decodeOptionalStringForKey("pr")
        self.id = decoder.decodeOptionalStringForKey("id")
        self.type = decoder.decodeOptionalStringForKey("ty")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "ti")
        
        if let address = self.address {
            encoder.encodeString(address, forKey: "ad")
        } else {
            encoder.encodeNil(forKey: "ad")
        }
        if let provider = self.provider {
            encoder.encodeString(provider, forKey: "pr")
        } else {
            encoder.encodeNil(forKey: "pr")
        }
        if let id = self.id {
            encoder.encodeString(id, forKey: "id")
        } else {
            encoder.encodeNil(forKey: "id")
        }
        if let type = self.type {
            encoder.encodeString(type, forKey: "ty")
        } else {
            encoder.encodeNil(forKey: "ty")
        }
    }
    
    public static func ==(lhs: MapVenue, rhs: MapVenue) -> Bool {
        if lhs.address != rhs.address {
            return false
        }
        if lhs.provider != rhs.provider {
            return false
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        return true
    }
}

public final class TelegramMediaMap: Media, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let heading: Int32?
    public let accuracyRadius: Double?
    public let venue: MapVenue?
    public let address: MapGeoAddress?
    public let liveBroadcastingTimeout: Int32?
    public let liveProximityNotificationRadius: Int32?
    
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init(latitude: Double, longitude: Double, heading: Int32?, accuracyRadius: Double?, venue: MapVenue?, address: MapGeoAddress? = nil, liveBroadcastingTimeout: Int32? = nil, liveProximityNotificationRadius: Int32? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.accuracyRadius = accuracyRadius
        self.venue = venue
        self.address = address
        self.liveBroadcastingTimeout = liveBroadcastingTimeout
        self.liveProximityNotificationRadius = liveProximityNotificationRadius
    }
    
    public init(decoder: PostboxDecoder) {
        self.latitude = decoder.decodeDoubleForKey("la", orElse: 0.0)
        self.longitude = decoder.decodeDoubleForKey("lo", orElse: 0.0)
        self.heading = decoder.decodeOptionalInt32ForKey("hdg")
        self.accuracyRadius = decoder.decodeOptionalDoubleForKey("acc")
        self.venue = decoder.decodeObjectForKey("ve", decoder: { MapVenue(decoder: $0) }) as? MapVenue
        self.address = decoder.decodeObjectForKey("adr", decoder: { MapGeoAddress(decoder: $0) }) as? MapGeoAddress
        self.liveBroadcastingTimeout = decoder.decodeOptionalInt32ForKey("bt")
        self.liveProximityNotificationRadius = decoder.decodeOptionalInt32ForKey("pnr")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.latitude, forKey: "la")
        encoder.encodeDouble(self.longitude, forKey: "lo")
        if let heading = self.heading {
            encoder.encodeInt32(heading, forKey: "hdg")
        } else {
            encoder.encodeNil(forKey: "hdg")
        }
        if let accuracyRadius = self.accuracyRadius {
            encoder.encodeDouble(accuracyRadius, forKey: "acc")
        } else {
            encoder.encodeNil(forKey: "acc")
        }
        if let venue = self.venue {
            encoder.encodeObject(venue, forKey: "ve")
        } else {
            encoder.encodeNil(forKey: "ve")
        }
        if let address = self.address {
            encoder.encodeObject(address, forKey: "adr")
        } else {
            encoder.encodeNil(forKey: "adr")
        }
        if let liveBroadcastingTimeout = self.liveBroadcastingTimeout {
            encoder.encodeInt32(liveBroadcastingTimeout, forKey: "bt")
        } else {
            encoder.encodeNil(forKey: "bt")
        }
        if let liveProximityNotificationRadius = self.liveProximityNotificationRadius {
            encoder.encodeInt32(liveProximityNotificationRadius, forKey: "pnr")
        } else {
            encoder.encodeNil(forKey: "pnr")
        }
    }
    
    public static func ==(lhs: TelegramMediaMap, rhs: TelegramMediaMap) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaMap {
            if self.latitude != other.latitude || self.longitude != other.longitude {
                return false
            }
            if self.heading != other.heading {
                return false
            }
            if self.accuracyRadius != other.accuracyRadius {
                return false
            }
            if self.venue != other.venue {
                return false
            }
            if self.liveBroadcastingTimeout != other.liveBroadcastingTimeout {
                return false
            }
            if self.liveProximityNotificationRadius != other.liveProximityNotificationRadius {
                return false
            }
            return true
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
