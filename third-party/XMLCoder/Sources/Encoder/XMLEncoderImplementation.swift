// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/22/17.
//

import Foundation

class XMLEncoderImplementation: Encoder {
    // MARK: Properties

    /// The encoder's storage.
    var storage: XMLEncodingStorage

    /// Options set on the top-level encoder.
    let options: XMLEncoder.Options

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey]

    public var nodeEncodings: [(CodingKey) -> XMLEncoder.NodeEncoding?]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    init(
        options: XMLEncoder.Options,
        nodeEncodings: [(CodingKey) -> XMLEncoder.NodeEncoding?],
        codingPath: [CodingKey] = []
    ) {
        self.options = options
        storage = XMLEncodingStorage()
        self.codingPath = codingPath
        self.nodeEncodings = nodeEncodings
    }

    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    var canEncodeNewValue: Bool {
        // Every time a new value gets encoded, the key it's encoded for is
        // pushed onto the coding path (even if it's a nil key from an unkeyed container).
        // At the same time, every time a container is requested, a new value
        // gets pushed onto the storage stack.
        // If there are more values on the storage stack than on the coding path,
        // it means the value is requesting more than one container, which
        // violates the precondition.
        //
        // This means that anytime something that can request a new container
        // goes onto the stack, we MUST push a key onto the coding path.
        // Things which will not request containers do not need to have the
        // coding path extended for them (but it doesn't matter if it is,
        // because they will not reach here).
        return storage.count == codingPath.count
    }

    // MARK: - Encoder Methods

    public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        guard canEncodeNewValue else {
            return mergeWithExistingKeyedContainer(keyedBy: Key.self)
        }
        if Key.self is XMLChoiceCodingKey.Type {
            return choiceContainer(keyedBy: Key.self)
        } else {
            return keyedContainer(keyedBy: Key.self)
        }
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: SharedBox<UnkeyedBox>
        if canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = storage.pushUnkeyedContainer()
        } else {
            guard let container = storage.lastContainer as? SharedBox<UnkeyedBox> else {
                preconditionFailure(
                    """
                    Attempt to push new unkeyed encoding container when already previously encoded \
                    at this path.
                    """
                )
            }

            topContainer = container
        }

        return XMLUnkeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }

    private func keyedContainer<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = XMLKeyedEncodingContainer<Key>(
            referencing: self,
            codingPath: codingPath,
            wrapping: storage.pushKeyedContainer()
        )
        return KeyedEncodingContainer(container)
    }

    private func choiceContainer<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = XMLChoiceEncodingContainer<Key>(
            referencing: self,
            codingPath: codingPath,
            wrapping: storage.pushChoiceContainer()
        )
        return KeyedEncodingContainer(container)
    }

    private func mergeWithExistingKeyedContainer<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        switch storage.lastContainer {
        case let keyed as SharedBox<KeyedBox>:
            let container = XMLKeyedEncodingContainer<Key>(
                referencing: self,
                codingPath: codingPath,
                wrapping: keyed
            )
            return KeyedEncodingContainer(container)
        case let choice as SharedBox<ChoiceBox>:
            _ = storage.popContainer()
            let keyed = KeyedBox(
                elements: KeyedBox.Elements([choice.withShared { ($0.key, $0.element) }]),
                attributes: []
            )
            let container = XMLKeyedEncodingContainer<Key>(
                referencing: self,
                codingPath: codingPath,
                wrapping: storage.pushKeyedContainer(keyed)
            )
            return KeyedEncodingContainer(container)
        default:
            preconditionFailure(
                """
                No existing keyed encoding container to merge with.
                """
            )
        }
    }
}

extension XMLEncoderImplementation {
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    func box() -> SimpleBox {
        return NullBox()
    }

    func box(_ value: Bool) -> SimpleBox {
        return BoolBox(value)
    }

    func box(_ value: Decimal) -> SimpleBox {
        return DecimalBox(value)
    }

    func box<T: BinaryInteger & SignedInteger & Encodable>(_ value: T) -> SimpleBox {
        return IntBox(value)
    }

    func box<T: BinaryInteger & UnsignedInteger & Encodable>(_ value: T) -> SimpleBox {
        return UIntBox(value)
    }

    func box(_ value: Float) throws -> SimpleBox {
        return try box(value, FloatBox.self)
    }

    func box(_ value: Double) throws -> SimpleBox {
        return try box(value, DoubleBox.self)
    }

    func box<T: BinaryFloatingPoint & Encodable, B: ValueBox>(
        _ value: T,
        _: B.Type
    ) throws -> SimpleBox where B.Unboxed == T {
        guard value.isInfinite || value.isNaN else {
            return B(value)
        }
        guard case let .convertToString(
            positiveInfinity: posInfString,
            negativeInfinity: negInfString,
            nan: nanString
        ) = options.nonConformingFloatEncodingStrategy else {
            throw EncodingError._invalidFloatingPointValue(value, at: codingPath)
        }
        if value == T.infinity {
            return StringBox(posInfString)
        } else if value == -T.infinity {
            return StringBox(negInfString)
        } else {
            return StringBox(nanString)
        }
    }

    func box(_ value: String) -> SimpleBox {
        return StringBox(value)
    }

    func box(_ value: Date) throws -> Box {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            try value.encode(to: self)
            return storage.popContainer()
        case .secondsSince1970:
            return DateBox(value, format: .secondsSince1970)
        case .millisecondsSince1970:
            return DateBox(value, format: .millisecondsSince1970)
        case .iso8601:
            return DateBox(value, format: .iso8601)
        case let .formatted(formatter):
            return DateBox(value, format: .formatter(formatter))
        case let .custom(closure):
            let depth = storage.count
            try closure(value, self)

            guard storage.count > depth else {
                return KeyedBox()
            }

            return storage.popContainer()
        }
    }

    func box(_ value: Data) throws -> Box {
        switch options.dataEncodingStrategy {
        case .deferredToData:
            try value.encode(to: self)
            return storage.popContainer()
        case .base64:
            return DataBox(value, format: .base64)
        case let .custom(closure):
            let depth = storage.count
            try closure(value, self)

            guard storage.count > depth else {
                return KeyedBox()
            }

            return storage.popContainer()
        }
    }

    func box(_ value: URL) -> SimpleBox {
        return URLBox(value)
    }

    func box<T: Encodable>(_ value: T) throws -> Box {
        if T.self == Date.self || T.self == NSDate.self,
           let value = value as? Date
        {
            return try box(value)
        } else if T.self == Data.self || T.self == NSData.self,
                  let value = value as? Data
        {
            return try box(value)
        } else if T.self == URL.self || T.self == NSURL.self,
                  let value = value as? URL
        {
            return box(value)
        } else if T.self == Decimal.self || T.self == NSDecimalNumber.self,
                  let value = value as? Decimal
        {
            return box(value)
        }

        let depth = storage.count
        try value.encode(to: self)

        // The top container should be a new container.
        guard storage.count > depth else {
            return KeyedBox()
        }

        let lastContainer = storage.popContainer()

        guard let sharedBox = lastContainer as? TypeErasedSharedBoxProtocol else {
            return lastContainer
        }

        return sharedBox.typeErasedUnbox()
    }
}
