//
//  XMLAttribute.swift
//  XMLCoder
//
//  Created by Benjamin Wetherfield on 6/3/20.
//

protocol XMLAttributeProtocol {}

/** Property wrapper specifying that a given property should be encoded and decoded as an XML attribute.

 For example, this type
 ```swift
 struct Book: Codable {
     @Attribute var id: Int
 }
 ```

 will encode value `Book(id: 42)` as `<Book id="42"></Book>`. And vice versa,
 it will decode the former into the latter.
 */
@propertyWrapper
public struct Attribute<Value>: XMLAttributeProtocol {
    public var wrappedValue: Value

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension Attribute: Codable where Value: Codable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        try wrappedValue = .init(from: decoder)
    }
}

extension Attribute: Equatable where Value: Equatable {}
extension Attribute: Hashable where Value: Hashable {}
extension Attribute: Sendable where Value: Sendable {}

extension Attribute: ExpressibleByIntegerLiteral where Value: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Value.IntegerLiteralType

    public init(integerLiteral value: Value.IntegerLiteralType) {
        wrappedValue = Value(integerLiteral: value)
    }
}

extension Attribute: ExpressibleByUnicodeScalarLiteral where Value: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: Value.UnicodeScalarLiteralType) {
        wrappedValue = Value(unicodeScalarLiteral: value)
    }

    public typealias UnicodeScalarLiteralType = Value.UnicodeScalarLiteralType
}

extension Attribute: ExpressibleByExtendedGraphemeClusterLiteral where Value: ExpressibleByExtendedGraphemeClusterLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = Value.ExtendedGraphemeClusterLiteralType

    public init(extendedGraphemeClusterLiteral value: Value.ExtendedGraphemeClusterLiteralType) {
        wrappedValue = Value(extendedGraphemeClusterLiteral: value)
    }
}

extension Attribute: ExpressibleByStringLiteral where Value: ExpressibleByStringLiteral {
    public typealias StringLiteralType = Value.StringLiteralType

    public init(stringLiteral value: Value.StringLiteralType) {
        wrappedValue = Value(stringLiteral: value)
    }
}

extension Attribute: ExpressibleByBooleanLiteral where Value: ExpressibleByBooleanLiteral {
    public typealias BooleanLiteralType = Value.BooleanLiteralType

    public init(booleanLiteral value: Value.BooleanLiteralType) {
        wrappedValue = Value(booleanLiteral: value)
    }
}

extension Attribute: ExpressibleByNilLiteral where Value: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        wrappedValue = Value(nilLiteral: ())
    }
}

protocol XMLOptionalAttributeProtocol: XMLAttributeProtocol {
    init()
}

extension Attribute: XMLOptionalAttributeProtocol where Value: AnyOptional {
    init() {
        wrappedValue = Value()
    }
}
