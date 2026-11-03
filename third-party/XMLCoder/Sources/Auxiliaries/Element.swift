//
//  XMLElementNode.swift
//  XMLCoder
//
//  Created by Benjamin Wetherfield on 6/4/20.
//

protocol XMLElementProtocol {}

/** Property wrapper specifying that a given property should be encoded and decoded as an XML element.

 For example, this type
 ```swift
 struct Book: Codable {
     @Element var id: Int
 }
 ```

 will encode value `Book(id: 42)` as `<Book><id>42</id></Book>`. And vice versa,
 it will decode the former into the latter.
 */
@propertyWrapper
public struct Element<Value>: XMLElementProtocol {
    public var wrappedValue: Value

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension Element: Codable where Value: Codable {
    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        try wrappedValue = .init(from: decoder)
    }
}

extension Element: Equatable where Value: Equatable {}
extension Element: Hashable where Value: Hashable {}
extension Element: Sendable where Value: Sendable {}
