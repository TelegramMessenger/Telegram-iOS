
public struct StringCodingKey: CodingKey, ExpressibleByStringLiteral {
    public var stringValue: String

    public init?(stringValue: String) {
        self.stringValue = stringValue
    }

    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    public init(stringLiteral: String) {
        self.stringValue = stringLiteral
    }

    public var intValue: Int? {
        return nil
    }

    public init?(intValue: Int) {
        return nil
    }
}
