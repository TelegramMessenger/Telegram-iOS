import Foundation
import Postbox

public enum MediaArea: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case type
        case coordinates
        case value
    }
        
    public struct Coordinates: Codable, Equatable {
        private enum CodingKeys: CodingKey {
            case x
            case y
            case width
            case height
            case rotation
        }
        
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var rotation: Double
        
        public init(
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            rotation: Double
        ) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.rotation = rotation
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.x = try container.decode(Double.self, forKey: .x)
            self.y = try container.decode(Double.self, forKey: .y)
            self.width = try container.decode(Double.self, forKey: .width)
            self.height = try container.decode(Double.self, forKey: .height)
            self.rotation = try container.decode(Double.self, forKey: .rotation)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.x, forKey: .x)
            try container.encode(self.y, forKey: .y)
            try container.encode(self.width, forKey: .width)
            try container.encode(self.height, forKey: .height)
            try container.encode(self.rotation, forKey: .rotation)
        }
    }
    
    public struct Venue: Codable, Equatable {
        private enum CodingKeys: CodingKey {
            case latitude
            case longitude
            case venue
            case queryId
            case resultId
        }
        
        public let latitude: Double
        public let longitude: Double
        public let venue: MapVenue?
        public let queryId: Int64?
        public let resultId: String?
        
        public init(
            latitude: Double,
            longitude: Double,
            venue: MapVenue?,
            queryId: Int64?,
            resultId: String?
        ) {
            self.latitude = latitude
            self.longitude = longitude
            self.venue = venue
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
            
            try container.encodeIfPresent(self.queryId, forKey: .queryId)
            try container.encodeIfPresent(self.resultId, forKey: .resultId)
        }
    }
    
    case venue(coordinates: Coordinates, venue: Venue)
    
    private enum MediaAreaType: Int32 {
        case venue
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
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .venue(coordinates, venue):
            try container.encode(MediaAreaType.venue.rawValue, forKey: .type)
            try container.encode(coordinates, forKey: .coordinates)
            try container.encode(venue, forKey: .value)
        }
    }
}

public extension MediaArea {
    var coordinates: Coordinates {
        switch self {
        case let .venue(coordinates, _):
            return coordinates
        }
    }
}
