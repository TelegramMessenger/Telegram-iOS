import Foundation

@propertyWrapper
public struct EsimApiDate: Decodable {
    private let formatter = DateFormatter.esimApiDateFormatter
    
    public var wrappedValue: Date
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let string = try container.decode(String.self)
        if let dateFromString = formatter.date(from: string) {
            wrappedValue = dateFromString
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected \(formatter.dateFormat ?? ""), but found \(string) instead")
        }
    }
}

@propertyWrapper
public struct EsimApiOptionalDate: Decodable {
    private let formatter = DateFormatter.esimApiDateFormatter
    
    public var wrappedValue: Date?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            if let dateFromString = formatter.date(from: string) {
                wrappedValue = dateFromString
            } else {
                wrappedValue = nil
            }
        } else {
            wrappedValue = nil
        }
    }
}

private extension DateFormatter {
    static var esimApiDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .init(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }
}
