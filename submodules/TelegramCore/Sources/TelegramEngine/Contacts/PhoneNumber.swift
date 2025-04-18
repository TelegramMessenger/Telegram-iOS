
public struct PhoneNumberWithLabel: Equatable {
    public let label: String
    public let number: String
    
    public init(label: String, number: String) {
        self.label = label
        self.number = number
    }
    
    public static func ==(lhs: PhoneNumberWithLabel, rhs: PhoneNumberWithLabel) -> Bool {
        return lhs.label == rhs.label && lhs.number == rhs.number
    }
}
