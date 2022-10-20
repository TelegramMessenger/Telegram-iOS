public enum NumberTypeDTO: Decodable {
    case local
    case mobile
    case unknown(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let stringValue = try container.decode(String.self)
        switch stringValue {
        case "local":
            self = .local
        case "mobile":
            self = .mobile
        default:
            self = .unknown(stringValue)
        }
    }
}
