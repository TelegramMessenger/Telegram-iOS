import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class NamedGeoPlace: Coding {
    public let country: String?
    public let state: String?
    public let city: String?
    public let district: String?
    public let street: String?
    
    public init(country: String?, state: String?, city: String?, district: String?, street: String?) {
        self.country = country
        self.state = state
        self.city = city
        self.district = district
        self.street = street
    }
    
    public init(decoder: Decoder) {
        self.country = decoder.decodeOptionalStringForKey("gp_co")
        self.state = decoder.decodeOptionalStringForKey("gp_sta")
        self.city = decoder.decodeOptionalStringForKey("gp_ci")
        self.district = decoder.decodeOptionalStringForKey("gp_dis")
        self.street = decoder.decodeOptionalStringForKey("gp_str")
    }
    
    public func encode(_ encoder: Encoder) {
        if let country = self.country {
            encoder.encodeString(country, forKey: "gp_co")
        }
        
        if let state = self.state {
            encoder.encodeString(state, forKey: "gp_sta")
        }
        
        if let city = self.city {
            encoder.encodeString(city, forKey: "gp_ci")
        }
        
        if let district = self.district {
            encoder.encodeString(district, forKey: "gp_dis")
        }
        
        if let street = self.street {
            encoder.encodeString(street, forKey: "gp_str")
        }
    }
}

public final class MapVenue: Coding {
    public let title: String
    public let address: String?
    public let provider: String?
    public let id: String?
    
    public init(title: String, address: String?, provider: String?, id: String?) {
        self.title = title
        self.address = address
        self.provider = provider
        self.id = id
    }
    
    public init(decoder: Decoder) {
        self.title = decoder.decodeStringForKey("ti", orElse: "")
        self.address = decoder.decodeOptionalStringForKey("ad")
        self.provider = decoder.decodeOptionalStringForKey("pr")
        self.id = decoder.decodeOptionalStringForKey("id")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.title, forKey: "ti")
        
        if let address = self.address {
            encoder.encodeString(address, forKey: "ad")
        }
        if let provider = self.provider {
            encoder.encodeString(provider, forKey: "pr")
        }
        if let id = self.id {
            encoder.encodeString(id, forKey: "id")
        }
    }
}

public final class TelegramMediaMap: Media {
    public let latitude: Double
    public let longitude: Double
    public let geoPlace: NamedGeoPlace?
    public let venue: MapVenue?
    
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init(latitude: Double, longitude: Double, geoPlace: NamedGeoPlace?, venue: MapVenue?) {
        self.latitude = latitude
        self.longitude = longitude
        self.geoPlace = geoPlace
        self.venue = venue
    }
    
    public init(decoder: Decoder) {
        self.latitude = decoder.decodeDoubleForKey("la", orElse: 0.0)
        self.longitude = decoder.decodeDoubleForKey("lo", orElse: 0.0)
        self.geoPlace = decoder.decodeObjectForKey("gp", decoder: { NamedGeoPlace(decoder: $0) }) as? NamedGeoPlace
        self.venue = decoder.decodeObjectForKey("ve", decoder: { MapVenue(decoder: $0) }) as? MapVenue
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeDouble(self.latitude, forKey: "la")
        encoder.encodeDouble(self.longitude, forKey: "lo")
        if let geoPlace = self.geoPlace {
            encoder.encodeObject(geoPlace, forKey: "gp")
        }
        if let venue = self.venue {
            encoder.encodeObject(venue, forKey: "ve")
        }
    }
    
    public func isEqual(_ other: Media) -> Bool {
        if let other = other as? TelegramMediaMap {
            if self.latitude == other.latitude && self.longitude == other.longitude {
                return true
            }
        }
        return false
    }
}

public func telegramMediaMapFromApiGeoPoint(_ geo: Api.GeoPoint, title: String?, address: String?, provider: String?, venueId: String?) -> TelegramMediaMap {
    var venue: MapVenue?
    if let title = title {
        venue = MapVenue(title: title, address: address, provider: provider, id: venueId)
    }
    switch geo {
        case let .geoPoint(long, lat):
            return TelegramMediaMap(latitude: lat, longitude: long, geoPlace: nil, venue: venue)
        case .geoPointEmpty:
            return TelegramMediaMap(latitude: 0.0, longitude: 0.0, geoPlace: nil, venue: venue)
    }
}
