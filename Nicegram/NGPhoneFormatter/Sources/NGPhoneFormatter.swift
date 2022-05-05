public enum PhoneStyle {
    case international
}

public protocol NGPhoneFormatter {
    func format(phoneNumber: String, to: PhoneStyle) -> String?
    func countryCode(phoneNumber: String) -> String?
}

public class NGPhoneFormatterMock: NGPhoneFormatter {
    
    public init() {}
    
    public func format(phoneNumber: String, to: PhoneStyle) -> String? {
        return phoneNumber
    }
    
    public func countryCode(phoneNumber: String) -> String? {
        return "US"
    }
}
