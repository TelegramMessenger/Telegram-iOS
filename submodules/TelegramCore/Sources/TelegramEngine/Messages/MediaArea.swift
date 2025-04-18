import Foundation
import Postbox

public enum MediaArea: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case type
        case coordinates
        case value
        case flags
        case temperature
        case color
    }
        
    public struct Coordinates: Codable, Equatable {
        private enum CodingKeys: CodingKey {
            case x
            case y
            case width
            case height
            case rotation
            case cornerRadius
        }
        
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var rotation: Double
        public var cornerRadius: Double?
        
        public init(
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            rotation: Double,
            cornerRadius: Double?
        ) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.rotation = rotation
            self.cornerRadius = cornerRadius
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.x = try container.decode(Double.self, forKey: .x)
            self.y = try container.decode(Double.self, forKey: .y)
            self.width = try container.decode(Double.self, forKey: .width)
            self.height = try container.decode(Double.self, forKey: .height)
            self.rotation = try container.decode(Double.self, forKey: .rotation)
            self.cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.x, forKey: .x)
            try container.encode(self.y, forKey: .y)
            try container.encode(self.width, forKey: .width)
            try container.encode(self.height, forKey: .height)
            try container.encode(self.rotation, forKey: .rotation)
            try container.encodeIfPresent(self.cornerRadius, forKey: .cornerRadius)
        }
    }
    
    public struct Venue: Codable, Equatable {
        private enum CodingKeys: CodingKey {
            case latitude
            case longitude
            case venue
            case address
            case queryId
            case resultId
        }
        
        public let latitude: Double
        public let longitude: Double
        public let venue: MapVenue?
        public let address: MapGeoAddress?
        public let queryId: Int64?
        public let resultId: String?
        
        public init(
            latitude: Double,
            longitude: Double,
            venue: MapVenue?,
            address: MapGeoAddress?,
            queryId: Int64?,
            resultId: String?
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.venue = venue
            self.address = address
            self.queryId = queryId
            self.resultId = resultId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.latitude = try container.decode(Double.self, forKey: .latitude)
            self.longitude = try container.decode(Double.self, forKey: .longitude)
            
            if let venueData = try container.decodeIfPresent(Data.self, forKey: .venue) {
                self.venue = PostboxDecoder(buffer: MemoryBuffer(data: venueData)).decodeRootObject() as? MapVenue
            } else {
                self.venue = nil
            }
            
            if let addressData = try container.decodeIfPresent(Data.self, forKey: .address) {
                self.address = PostboxDecoder(buffer: MemoryBuffer(data: addressData)).decodeRootObject() as? MapGeoAddress
            } else {
                self.address = nil
            }
            
            self.queryId = try container.decodeIfPresent(Int64.self, forKey: .queryId)
            self.resultId = try container.decodeIfPresent(String.self, forKey: .resultId)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.latitude, forKey: .latitude)
            try container.encode(self.longitude, forKey: .longitude)
            
            if let venue = self.venue {
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(venue)
                let venueData = encoder.makeData()
                try container.encode(venueData, forKey: .venue)
            }
            
            if let address = self.address {
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(address)
                let addressData = encoder.makeData()
                try container.encode(addressData, forKey: .address)
            }
            
            try container.encodeIfPresent(self.queryId, forKey: .queryId)
            try container.encodeIfPresent(self.resultId, forKey: .resultId)
        }
    }
    
    case venue(coordinates: Coordinates, venue: Venue)
    case reaction(coordinates: Coordinates, reaction: MessageReaction.Reaction, flags: ReactionFlags)
    case channelMessage(coordinates: Coordinates, messageId: EngineMessage.Id)
    case link(coordinates: Coordinates, url: String)
    case weather(coordinates: Coordinates, emoji: String, temperature: Double, color: Int32)
    case starGift(coordinates: Coordinates, slug: String)
   
    public struct ReactionFlags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let isDark = ReactionFlags(rawValue: 1 << 0)
        public static let isFlipped = ReactionFlags(rawValue: 1 << 1)
    }
    
    private enum MediaAreaType: Int32 {
        case venue
        case reaction
        case channelMessage
        case link
        case weather
        case starGift
    }
    
    public enum DecodingError: Error {
        case generic
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        guard let type = MediaAreaType(rawValue: try container.decode(Int32.self, forKey: .type)) else {
            throw DecodingError.generic
        }
        switch type {
        case .venue:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let venue = try container.decode(MediaArea.Venue.self, forKey: .value)
            self = .venue(coordinates: coordinates, venue: venue)
        case .reaction:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let reaction = try container.decode(MessageReaction.Reaction.self, forKey: .value)
            let flags = ReactionFlags(rawValue: try container.decodeIfPresent(Int32.self, forKey: .flags) ?? 0)
            self = .reaction(coordinates: coordinates, reaction: reaction, flags: flags)
        case .channelMessage:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let messageId = try container.decode(MessageId.self, forKey: .value)
            self = .channelMessage(coordinates: coordinates, messageId: messageId)
        case .link:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let url = try container.decode(String.self, forKey: .value)
            self = .link(coordinates: coordinates, url: url)
        case .weather:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let emoji = try container.decode(String.self, forKey: .value)
            let temperature = try container.decode(Double.self, forKey: .temperature)
            let color = try container.decodeIfPresent(Int32.self, forKey: .color) ?? 0
            self = .weather(coordinates: coordinates, emoji: emoji, temperature: temperature, color: color)
        case .starGift:
            let coordinates = try container.decode(MediaArea.Coordinates.self, forKey: .coordinates)
            let slug = try container.decode(String.self, forKey: .value)
            self = .starGift(coordinates: coordinates, slug: slug)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .venue(coordinates, venue):
            try container.encode(MediaAreaType.venue.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(venue, forKey: .value)
        case let .reaction(coordinates, reaction, flags):
            try container.encode(MediaAreaType.reaction.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(reaction, forKey: .value)
            try container.encode(flags.rawValue, forKey: .flags)
        case let .channelMessage(coordinates, messageId):
            try container.encode(MediaAreaType.channelMessage.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(messageId, forKey: .value)
        case let .link(coordinates, url):
            try container.encode(MediaAreaType.link.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(url, forKey: .value)
        case let .weather(coordinates, emoji, temperature, color):
            try container.encode(MediaAreaType.weather.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(emoji, forKey: .value)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(color, forKey: .color)
        case let .starGift(coordinates, slug):
            try container.encode(MediaAreaType.starGift.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(slug, forKey: .value)
        }
    }
}

public extension MediaArea {
    var coordinates: Coordinates {
        switch self {
        case let .venue(coordinates, _):
            return coordinates
        case let .reaction(coordinates, _, _):
            return coordinates
        case let .channelMessage(coordinates, _):
            return coordinates
        case let .link(coordinates, _):
            return coordinates
        case let .weather(coordinates, _, _, _):
            return coordinates
        case let .starGift(coordinates, _):
            return coordinates
        }
    }
}
