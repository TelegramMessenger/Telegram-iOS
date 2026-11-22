// Copyright © 2017-2021 Shawn Moore and XMLCoder contributors.
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/22/17.
//

import Foundation

/// `XMLEncoder` facilitates the encoding of `Encodable` values into XML.
open class XMLEncoder {
    // MARK: Options

    /// The formatting of the output XML data.
    public struct OutputFormatting: OptionSet, Sendable {
        /// The format's default value.
        public let rawValue: UInt

        /// Creates an OutputFormatting value with the given raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Produce human-readable XML with indented output.
        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)

        /// Produce XML with keys sorted in lexicographic order.
        public static let sortedKeys = OutputFormatting(rawValue: 1 << 1)

        /// Produce XML with no short-hand annotation for empty elements, e.g., use `<p></p>` over `</p>`
        public static let noEmptyElements = OutputFormatting(rawValue: 1 << 2)
    }

    /// The indentation to use when XML is pretty-printed.
    public enum PrettyPrintIndentation {
        case spaces(Int)
        case tabs(Int)
    }

    /// A node's encoding type. Specifies how a node will be encoded.
    public enum NodeEncoding : Sendable {
        case attribute
        case element
        case both

        public static let `default`: NodeEncoding = .element
    }

    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferredToDate

        /// Encode the `Date` as a UNIX timestamp (as a XML number).
        case secondsSince1970

        /// Encode the `Date` as UNIX millisecond timestamp (as a XML number).
        case millisecondsSince1970

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)

        /// Encode the `Date` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        case custom((Date, Encoder) throws -> ())
    }

    /// The strategy to use for encoding `String` values.
    public enum StringEncodingStrategy {
        /// Defer to `String` for choosing an encoding. This is the default strategy.
        case deferredToString

        /// Encode the `String` as a CData-encoded string.
        case cdata
    }

    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData

        /// Encoded the `Data` as a Base64-encoded string. This is the default strategy.
        case base64

        /// Encode the `Data` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        case custom((Data, Encoder) throws -> ())
    }

    /// The strategy to use for non-XML-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatEncodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before encoding.
    public enum KeyEncodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys

        /// Convert from "camelCaseKeys" to "snake_case_keys" before writing a key to XML payload.
        ///
        /// Capital characters are determined by testing membership in
        /// `CharacterSet.uppercaseLetters` and `CharacterSet.lowercaseLetters`
        /// (Unicode General Categories Lu and Lt).
        /// The conversion to lower case uses `Locale.system`, also known as
        /// the ICU "root" locale. This means the result is consistent
        /// regardless of the current user's locale and language preferences.
        ///
        /// Converting from camel case to snake case:
        /// 1. Splits words at the boundary of lower-case to upper-case
        /// 2. Inserts `_` between words
        /// 3. Lowercases the entire string
        /// 4. Preserves starting and ending `_`.
        ///
        /// For example, `oneTwoThree` becomes `one_two_three`. `_oneTwoThree_` becomes `_one_two_three_`.
        ///
        /// - Note: Using a key encoding strategy has a nominal performance cost, as each string key has to be converted.
        case convertToSnakeCase

        /// Same as convertToSnakeCase, but using `-` instead of `_`
        /// For example, `oneTwoThree` becomes `one-two-three`.
        case convertToKebabCase

        /// Capitalize the first letter only
        /// `oneTwoThree` becomes  `OneTwoThree`
        case capitalized

        /// Uppercase ize all letters
        /// `oneTwoThree` becomes  `ONETWOTHREE`
        case uppercased

        /// Lowercase all letters
        /// `oneTwoThree` becomes  `onetwothree`
        case lowercased

        /// Provide a custom conversion to the key in the encoded XML from the
        /// keys specified by the encoded types.
        /// The full path to the current encoding position is provided for
        /// context (in case you need to locate this key within the payload).
        /// The returned key is used in place of the last component in the
        /// coding path before encoding.
        /// If the result of the conversion is a duplicate key, then only one
        /// value will be present in the result.
        case custom((_ codingPath: [CodingKey]) -> CodingKey)

        static func _convertToSnakeCase(_ stringKey: String) -> String {
            return _convert(stringKey, usingSeparator: "_")
        }

        static func _convertToKebabCase(_ stringKey: String) -> String {
            return _convert(stringKey, usingSeparator: "-")
        }

        static func _convert(_ stringKey: String, usingSeparator separator: String) -> String {
            guard !stringKey.isEmpty else {
                return stringKey
            }

            var words: [Range<String.Index>] = []
            // The general idea of this algorithm is to split words on
            // transition from lower to upper case, then on transition of >1
            // upper case characters to lowercase
            //
            // myProperty -> my_property
            // myURLProperty -> my_url_property
            //
            // We assume, per Swift naming conventions, that the first character of the key is lowercase.
            var wordStart = stringKey.startIndex
            var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex

            // Find next uppercase character
            while let upperCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.uppercaseLetters, options: [], range: searchRange) {
                let untilUpperCase = wordStart..<upperCaseRange.lowerBound
                words.append(untilUpperCase)

                // Find next lowercase character
                searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
                guard let lowerCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.lowercaseLetters, options: [], range: searchRange) else {
                    // There are no more lower case letters. Just end here.
                    wordStart = searchRange.lowerBound
                    break
                }

                // Is the next lowercase letter more than 1 after the uppercase?
                // If so, we encountered a group of uppercase letters that we
                // should treat as its own word
                let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
                if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                    // The next character after capital is a lower case character and therefore not a word boundary.
                    // Continue searching for the next upper case for the boundary.
                    wordStart = upperCaseRange.lowerBound
                } else {
                    // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                    let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                    words.append(upperCaseRange.lowerBound..<beforeLowerIndex)

                    // Next word starts at the capital before the lowercase we just found
                    wordStart = beforeLowerIndex
                }
                searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
            }
            words.append(wordStart..<searchRange.upperBound)
            let result = words.map { range in
                stringKey[range].lowercased()
            }.joined(separator: separator)
            return result
        }

        static func _convertToCapitalized(_ stringKey: String) -> String {
            return stringKey.capitalizingFirstLetter()
        }

        static func _convertToLowercased(_ stringKey: String) -> String {
            return stringKey.lowercased()
        }

        static func _convertToUppercased(_ stringKey: String) -> String {
            return stringKey.uppercased()
        }
    }

    @available(*, deprecated, renamed: "NodeEncodingStrategy")
    public typealias NodeEncodingStrategies = NodeEncodingStrategy

    public typealias XMLNodeEncoderClosure = @Sendable (CodingKey) -> NodeEncoding?
    public typealias XMLEncodingClosure = @Sendable (Encodable.Type, Encoder) -> XMLNodeEncoderClosure

    /// Set of strategies to use for encoding of nodes.
    public enum NodeEncodingStrategy {
        /// Defer to `Encoder` for choosing an encoding. This is the default strategy.
        case deferredToEncoder

        /// Return a closure computing the desired node encoding for the value by its coding key.
        case custom(XMLEncodingClosure)

        func nodeEncodings(
            forType codableType: Encodable.Type,
            with encoder: Encoder
        ) -> ((CodingKey) -> NodeEncoding?) {
            return encoderClosure(codableType, encoder)
        }

        var encoderClosure: XMLEncodingClosure {
            switch self {
            case .deferredToEncoder: return NodeEncodingStrategy.defaultEncoder
            case let .custom(closure): return closure
            }
        }

        static let defaultEncoder: XMLEncodingClosure = { codableType, _ in
            guard let dynamicType = codableType as? DynamicNodeEncoding.Type else {
                return { _ in nil }
            }
            #if compiler(>=6.1)
                return dynamicType.nodeEncoding(for:)
            #else
                return { (@Sendable key: CodingKey) in
                    dynamicType.nodeEncoding(for: key)
                }
            #endif
        }
    }

    /// Characters and their escaped representations to be escaped in attributes
    open var charactersEscapedInAttributes = [
        ("&", "&amp;"),
        ("<", "&lt;"),
        (">", "&gt;"),
        ("'", "&apos;"),
        ("\"", "&quot;"),
    ]

    /// Characters and their escaped representations to be escaped in elements
    open var charactersEscapedInElements = [
        ("&", "&amp;"),
        ("<", "&lt;"),
        (">", "&gt;"),
        ("'", "&apos;"),
        ("\"", "&quot;"),
    ]

    /// The output format to produce. Defaults to `[]`.
    open var outputFormatting: OutputFormatting = []

    /// The indentation to use when XML is printed. Defaults to `.spaces(4)`.
    open var prettyPrintIndentation: PrettyPrintIndentation = .spaces(4)

    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
    open var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    open var dataEncodingStrategy: DataEncodingStrategy = .base64

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw

    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
    open var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys

    /// The strategy to use in encoding encoding attributes. Defaults to `.deferredToEncoder`.
    open var nodeEncodingStrategy: NodeEncodingStrategy = .deferredToEncoder

    /// The strategy to use in encoding strings. Defaults to `.deferredToString`.
    open var stringEncodingStrategy: StringEncodingStrategy = .deferredToString

    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    struct Options {
        let dateEncodingStrategy: DateEncodingStrategy
        let dataEncodingStrategy: DataEncodingStrategy
        let nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy
        let keyEncodingStrategy: KeyEncodingStrategy
        let nodeEncodingStrategy: NodeEncodingStrategy
        let stringEncodingStrategy: StringEncodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level encoder.
    var options: Options {
        return Options(dateEncodingStrategy: dateEncodingStrategy,
                       dataEncodingStrategy: dataEncodingStrategy,
                       nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
                       keyEncodingStrategy: keyEncodingStrategy,
                       nodeEncodingStrategy: nodeEncodingStrategy,
                       stringEncodingStrategy: stringEncodingStrategy,
                       userInfo: userInfo)
    }

    // MARK: - Constructing a XML Encoder

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Encoding Values

    /// Encodes the given top-level value and returns its XML representation.
    ///
    /// - parameter value: The value to encode.
    /// - parameter withRootKey: the key used to wrap the encoded values. The
    ///   default value is inferred from the name of the root type.
    /// - parameter rootAttributes: the list of attributes to be added to the root node
    /// - parameter header: the XML header to start the encoded data with.
    /// - returns: A new `Data` value containing the encoded XML data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming
    /// floating-point value is encountered during encoding, and the encoding
    /// strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<T: Encodable>(_ value: T,
                                   withRootKey rootKey: String? = nil,
                                   rootAttributes: [String: String]? = nil,
                                   header: XMLHeader? = nil,
                                   doctype: XMLDocumentType? = nil) throws -> Data
    {
        let encoder = XMLEncoderImplementation(options: options, nodeEncodings: [])
        encoder.nodeEncodings.append(options.nodeEncodingStrategy.nodeEncodings(forType: T.self, with: encoder))

        let topLevel = try encoder.box(value)
        let attributes = rootAttributes?.map(XMLCoderElement.Attribute.init) ?? []

        let elementOrNone: XMLCoderElement?

        let rootKey = rootKey ?? "\(T.self)".convert(for: keyEncodingStrategy)

        let isStringBoxCDATA = stringEncodingStrategy == .cdata

        if let keyedBox = topLevel as? KeyedBox {
            elementOrNone = XMLCoderElement(
                key: rootKey,
                isStringBoxCDATA: isStringBoxCDATA,
                box: keyedBox,
                attributes: attributes
            )
        } else if let unkeyedBox = topLevel as? UnkeyedBox {
            elementOrNone = XMLCoderElement(
                key: rootKey,
                isStringBoxCDATA: isStringBoxCDATA,
                box: unkeyedBox,
                attributes: attributes
            )
        } else if let choiceBox = topLevel as? ChoiceBox {
            elementOrNone = XMLCoderElement(
                key: rootKey,
                isStringBoxCDATA: isStringBoxCDATA,
                box: choiceBox,
                attributes: attributes
            )
        } else {
            fatalError("Unrecognized top-level element of type: \(type(of: topLevel))")
        }

        guard let element = elementOrNone else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Unable to encode the given top-level value to XML."
            ))
        }

        return element.toXMLString(
            with: header,
            doctype: doctype,
            escapedCharacters: (
                elements: charactersEscapedInElements,
                attributes: charactersEscapedInAttributes
            ),
            formatting: outputFormatting,
            indentation: prettyPrintIndentation
        ).data(using: .utf8, allowLossyConversion: true)!
    }

    // MARK: - TopLevelEncoder

    #if canImport(Combine) || canImport(OpenCombine)
    open func encode<T>(_ value: T) throws -> Data where T: Encodable {
        return try encode(value, withRootKey: nil, rootAttributes: nil, header: nil)
    }
    #endif
}

private extension String {
    func convert(for encodingStrategy: XMLEncoder.KeyEncodingStrategy) -> String {
        switch encodingStrategy {
        case .useDefaultKeys:
            return self
        case .convertToSnakeCase:
            return XMLEncoder.KeyEncodingStrategy._convertToSnakeCase(self)
        case .convertToKebabCase:
            return XMLEncoder.KeyEncodingStrategy._convertToKebabCase(self)
        case .custom:
            return self
        case .capitalized:
            return XMLEncoder.KeyEncodingStrategy._convertToCapitalized(self)
        case .uppercased:
            return XMLEncoder.KeyEncodingStrategy._convertToUppercased(self)
        case .lowercased:
            return XMLEncoder.KeyEncodingStrategy._convertToLowercased(self)
        }
    }
}
