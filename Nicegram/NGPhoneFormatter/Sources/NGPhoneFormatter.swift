import libphonenumber

public enum PhoneStyle {
    case international
}

public protocol PhoneFormatter {
    func format(phoneNumber: String, to: PhoneStyle) -> String?
    func countryCode(phoneNumber: String) -> String?
}

public class PhoneFormatterImpl: PhoneFormatter {
    
    //  MARK: - Dependencies
    
    private let formatter = NBAsYouTypeFormatter(regionCode: "US")!
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions
    
    public func format(phoneNumber: String, to: PhoneStyle) -> String? {
        formatter.clear()
        
        var phoneNumber = phoneNumber
        if !phoneNumber.hasPrefix("+") {
            phoneNumber = "+\(phoneNumber)"
        }
        
        return formatter.inputString(phoneNumber)
    }
    
    public func countryCode(phoneNumber: String) -> String? {
        return "US"
    }
}
