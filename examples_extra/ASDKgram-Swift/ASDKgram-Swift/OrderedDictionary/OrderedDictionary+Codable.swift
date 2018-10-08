//
//  OrderedDictionary+Codable.swift
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if swift(>=4.1)

extension OrderedDictionary: Encodable where Key: Encodable, Value: Encodable {
    
    /// __inheritdoc__
    public func encode(to encoder: Encoder) throws {
        // Encode the ordered dictionary as an array of alternating key-value pairs.
        var container = encoder.unkeyedContainer()
        
        for (key, value) in self {
            try container.encode(key)
            try container.encode(value)
        }
    }
    
}

extension OrderedDictionary: Decodable where Key: Decodable, Value: Decodable {
    
    /// __inheritdoc__
    public init(from decoder: Decoder) throws {
        // Decode the ordered dictionary from an array of alternating key-value pairs.
        self.init()
    
        var container = try decoder.unkeyedContainer()
        
        while !container.isAtEnd {
            let key = try container.decode(Key.self)
            guard !container.isAtEnd else { throw DecodingError.unkeyedContainerReachedEndBeforeValue(decoder.codingPath) }
            let value = try container.decode(Value.self)
            
            self[key] = value
        }
    }
    
}
    
#else

extension OrderedDictionary: Encodable {

    /// __inheritdoc__
    public func encode(to encoder: Encoder) throws {
        // Since Swift 4.0 lacks the protocol conditional conformance support, we have to make the
        // whole OrderedDictionary type conform to Encodable and assert that the key and value
        // types conform to Encodable. Furthermore, we leverage a trick of super encoders to be
        // able to encode objects without knowing their exact types. This trick was used in the
        // standard library for encoding/decoding Dictionary before Swift 4.1.
        
        _assertTypeIsEncodable(Key.self, in: type(of: self))
        _assertTypeIsEncodable(Value.self, in: type(of: self))

        var container = encoder.unkeyedContainer()

        for (key, value) in self {
            let keyEncoder = container.superEncoder()
            try (key as! Encodable).encode(to: keyEncoder)

            let valueEncoder = container.superEncoder()
            try (value as! Encodable).encode(to: valueEncoder)
        }
    }

    private func _assertTypeIsEncodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
        guard T.self is Encodable.Type else {
            if T.self == Encodable.self || T.self == Codable.self {
                preconditionFailure("\(wrappingType) does not conform to Encodable because Encodable does not conform to itself. You must use a concrete type to encode or decode.")
            } else {
                preconditionFailure("\(wrappingType) does not conform to Encodable because \(T.self) does not conform to Encodable.")
            }
        }
    }

}

extension OrderedDictionary: Decodable {

    /// __inheritdoc__
    public init(from decoder: Decoder) throws {
        // Since Swift 4.0 lacks the protocol conditional conformance support, we have to make the
        // whole OrderedDictionary type conform to Decodable and assert that the key and value
        // types conform to Decodable. Furthermore, we leverage a trick of super decoders to be
        // able to decode objects without knowing their exact types. This trick was used in the
        // standard library for encoding/decoding Dictionary before Swift 4.1.
        
        self.init()

        _assertTypeIsDecodable(Key.self, in: type(of: self))
        _assertTypeIsDecodable(Value.self, in: type(of: self))

        var container = try decoder.unkeyedContainer()

        let keyMetaType = (Key.self as! Decodable.Type)
        let valueMetaType = (Value.self as! Decodable.Type)

        while !container.isAtEnd {
            let keyDecoder = try container.superDecoder()
            let key = try keyMetaType.init(from: keyDecoder) as! Key

            guard !container.isAtEnd else { throw DecodingError.unkeyedContainerReachedEndBeforeValue(decoder.codingPath) }

            let valueDecoder = try container.superDecoder()
            let value = try valueMetaType.init(from: valueDecoder) as! Value

            self[key] = value
        }
    }

    private func _assertTypeIsDecodable<T>(_ type: T.Type, in wrappingType: Any.Type) {
        guard T.self is Decodable.Type else {
            if T.self == Decodable.self || T.self == Codable.self {
                preconditionFailure("\(wrappingType) does not conform to Decodable because Decodable does not conform to itself. You must use a concrete type to encode or decode.")
            } else {
                preconditionFailure("\(wrappingType) does not conform to Decodable because \(T.self) does not conform to Decodable.")
            }
        }
    }

}

#endif

fileprivate extension DecodingError {
    
    fileprivate static func unkeyedContainerReachedEndBeforeValue(_ codingPath: [CodingKey]) -> DecodingError {
        return DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Unkeyed container reached end before value in key-value pair."
            )
        )
    }
    
}
