import Foundation

@propertyWrapper
public struct EsimApiUrl: Decodable {
    
    public var wrappedValue: URL?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let stringValue = try container.decode(String.self)
        wrappedValue = URL(string: stringValue)
    }
}
