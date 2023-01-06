import Foundation

public struct WorldTimeResponseDto: Decodable {
    public let datetime: Date
    public let abbreviation: String
    public let timezone: String
    public let unixtime: Double
}

public enum RequestedCity: String {
    case moscow
}

public enum RequestedRegion: String {
    case europe
}

public struct WorldTimeEndpoint: Endpoint {
    public typealias Content = WorldTimeResponseDto
    
    private let baseUrl: URL
    private let city: RequestedCity
    private let region: RequestedRegion
    
    public init(
        baseUrl: URL,
        city: RequestedCity,
        region: RequestedRegion
    ) {
        self.baseUrl = baseUrl
        self.city = city
        self.region = region
    }
    
    public func makeRequest() -> URLRequest {
        let url = baseUrl.appendingPathComponent("timezone/\(region)/\(city)")
        return .get(url)
    }
}

extension URLRequest {
    static func get(_ url: URL) -> URLRequest {
        return URLRequest(url: url)
    }
}
