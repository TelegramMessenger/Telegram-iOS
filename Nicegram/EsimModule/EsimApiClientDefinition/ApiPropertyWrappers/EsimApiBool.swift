import Foundation

@propertyWrapper
public struct EsimApiBool: Decodable {
    
    public var wrappedValue: Bool
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            wrappedValue = (intValue > 0)
        } else {
            wrappedValue = try container.decode(Bool.self)
        }
    }
}
