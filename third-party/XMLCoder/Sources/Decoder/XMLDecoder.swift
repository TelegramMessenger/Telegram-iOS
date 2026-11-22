// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/20/17.
//

import Foundation

// MARK: - XML Decoder

/// `XMLDecoder` facilitates the decoding of XML into semantic `Decodable` types.
open class XMLDecoder {
    // MARK: Options

    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate

        /// Decode the `Date` as a UNIX timestamp from a XML number. This is the default strategy.
        case secondsSince1970

        /// Decode the `Date` as UNIX millisecond timestamp from a XML number.
        case millisecondsSince1970

        /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Decode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Decode the `Date` as a custom box decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Date)

        /// Decode the `Date` as a string parsed by the given formatter for the give key.
        static func keyFormatted(
            _ formatterForKey: @escaping (CodingKey) throws -> DateFormatter?
        ) -> XMLDecoder.DateDecodingStrategy {
            return .custom { decoder -> Date in
                guard let codingKey = decoder.codingPath.last else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No Coding Path Found"
                    ))
                }

                guard let container = try? decoder.singleValueContainer(),
                      let text = try? container.decode(String.self)
                else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Could not decode date text"
                    ))
                }

                guard let dateFormatter = try formatterForKey(codingKey) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "No date formatter for date text"
                    )
                }

                if let date = dateFormatter.date(from: text) {
                    return date
                } else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Cannot decode date string \(text)"
                    )
                }
            }
        }
    }

    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy {
        /// Defer to `Data` for decoding.
        case deferredToData

        /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
        case base64

        /// Decode the `Data` as a custom box decoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Data)

        /// Decode the `Data` as a custom box by the given closure for the give key.
        static func keyFormatted(
            _ formatterForKey: @escaping (CodingKey) throws -> Data?
        ) -> XMLDecoder.DataDecodingStrategy {
            return .custom { decoder -> Data in
                guard let codingKey = decoder.codingPath.last else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No Coding Path Found"
                    ))
                }

                guard let container = try? decoder.singleValueContainer(),
                      let text = try? container.decode(String.self)
                else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Could not decode date text"
                    ))
                }

                guard let data = try formatterForKey(codingKey) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Cannot decode data string \(text)"
                    )
                }

                return data
            }
        }
    }

    /// The strategy to use for non-XML-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatDecodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Decode the values from the given representation strings.
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the box of keys before decoding.
    public enum KeyDecodingStrategy {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys

        /// Convert from "snake_case_keys" to "camelCaseKeys" before attempting
        /// to match a key with the one specified by each type.
        ///
        /// The conversion to upper case uses `Locale.system`, also known as
        /// the ICU "root" locale. This means the result is consistent
        /// regardless of the current user's locale and language preferences.
        ///
        /// Converting from snake case to camel case:
        /// 1. Capitalizes the word starting after each `_`
        /// 2. Removes all `_`
        /// 3. Preserves starting and ending `_` (as these are often used to indicate private variables or other metadata).
        /// For example, `one_two_three` becomes `oneTwoThree`. `_one_two_three_` becomes `_oneTwoThree_`.
        ///
        /// - Note: Using a key decoding strategy has a nominal performance cost, as each string key has to be inspected for the `_` character.
        case convertFromSnakeCase

        /// Convert from "kebab-case" to "kebabCase" before attempting
        /// to match a key with the one specified by each type.
        case convertFromKebabCase

        /// Convert from "CodingKey" to "codingKey"
        case convertFromCapitalized

        /// Convert from "CODING_KEY" to "codingKey"
        case convertFromUppercase

        /// Provide a custom conversion from the key in the encoded XML to the
        /// keys specified by the decoded types.
        /// The full path to the current decoding position is provided for
        /// context (in case you need to locate this key within the payload).
        /// The returned key is used in place of the last component in the
        /// coding path before decoding.
        /// If the result of the conversion is a duplicate key, then only one
        /// box will be present in the container for the type to decode from.
        case custom((_ codingPath: [CodingKey]) -> CodingKey)

        static func _convertFromCapitalized(_ stringKey: String) -> String {
            guard !stringKey.isEmpty else {
                return stringKey
            }
            let firstLetter = stringKey.prefix(1).lowercased()
            let result = firstLetter + stringKey.dropFirst()
            return result
        }

        static func _convertFromUppercase(_ stringKey: String) -> String {
            _convert(stringKey.lowercased(), usingSeparator: "_")
        }

        static func _convertFromSnakeCase(_ stringKey: String) -> String {
            return _convert(stringKey, usingSeparator: "_")
        }

        static func _convertFromKebabCase(_ stringKey: String) -> String {
            return _convert(stringKey, usingSeparator: "-")
        }

        static func _convert(_ stringKey: String, usingSeparator separator: Character) -> String {
            guard !stringKey.isEmpty else {
                return stringKey
            }

            // Find the first non-separator character
            guard let firstNonSeparator = stringKey.firstIndex(where: { $0 != separator }) else {
                // Reached the end without finding a separator character
                return stringKey
            }

            // Find the last non-separator character
            var lastNonSeparator = stringKey.index(before: stringKey.endIndex)
            while lastNonSeparator > firstNonSeparator, stringKey[lastNonSeparator] == separator {
                stringKey.formIndex(before: &lastNonSeparator)
            }

            let keyRange = firstNonSeparator...lastNonSeparator
            let leadingSeparatorRange = stringKey.startIndex..<firstNonSeparator
            let trailingSeparatorRange = stringKey.index(after: lastNonSeparator)..<stringKey.endIndex

            let components = stringKey[keyRange].split(separator: separator)
            let joinedString: String
            if components.count == 1 {
                // No separators in key, leave the word as is - maybe it is already good
                joinedString = String(stringKey[keyRange])
            } else {
                joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
            }

            // Do a cheap isEmpty check before creating and appending potentially empty strings
            let result: String
            if leadingSeparatorRange.isEmpty, trailingSeparatorRange.isEmpty {
                result = joinedString
            } else if !leadingSeparatorRange.isEmpty, !trailingSeparatorRange.isEmpty {
                // Both leading and trailing underscores
                result = String(stringKey[leadingSeparatorRange]) + joinedString + String(stringKey[trailingSeparatorRange])
            } else if !leadingSeparatorRange.isEmpty {
                // Just leading
                result = String(stringKey[leadingSeparatorRange]) + joinedString
            } else {
                // Just trailing
                result = joinedString + String(stringKey[trailingSeparatorRange])
            }
            return result
        }
    }

    /// The strategy to use in decoding dates. Defaults to `.secondsSince1970`.
    open var dateDecodingStrategy: DateDecodingStrategy = .secondsSince1970

    /// The strategy to use in decoding binary data. Defaults to `.base64`.
    open var dataDecodingStrategy: DataDecodingStrategy = .base64

    /// The strategy to use in decoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw

    /// The strategy to use for decoding keys. Defaults to `.useDefaultKeys`.
    open var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys

    /// A node's decoding type
    public enum NodeDecoding {
        /// Decodes a node from attributes of form `nodeName="value"`.
        case attribute
        /// Decodes a node from elements of form `<nodeName>value</nodeName>`.
        case element
        /// Decodes a node from either elements of form `<nodeName>value</nodeName>` or attributes
        /// of form `nodeName="value"`, with elements taking priority.
        case elementOrAttribute
    }

    /// The strategy to use in encoding encoding attributes. Defaults to `.deferredToEncoder`.
    open var nodeDecodingStrategy: NodeDecodingStrategy = .deferredToDecoder

    /// Set of strategies to use for encoding of nodes.
    public enum NodeDecodingStrategy {
        /// Defer to `Encoder` for choosing an encoding. This is the default strategy.
        case deferredToDecoder

        /// Return a closure computing the desired node encoding for the value by its coding key.
        case custom((Decodable.Type, Decoder) -> ((CodingKey) -> NodeDecoding))

        func nodeDecodings(
            forType codableType: Decodable.Type,
            with decoder: Decoder
        ) -> ((CodingKey) -> NodeDecoding?) {
            switch self {
            case .deferredToDecoder:
                guard let dynamicType = codableType as? DynamicNodeDecoding.Type else {
                    return { _ in nil }
                }
                return dynamicType.nodeDecoding(for:)
            case let .custom(closure):
                return closure(codableType, decoder)
            }
        }
    }

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey: Any] = [:]

    /// The error context length. Non-zero length makes an error thrown from
    /// the XML parser with line/column location repackaged with a context
    /// around that location of specified length. For example, if an error was
    /// thrown indicating that there's an unexpected character at line 3, column
    /// 15 with `errorContextLength` set to 10, a new error type is rethrown
    /// containing 5 characters before column 15 and 5 characters after, all on
    /// line 3. Line wrapping should be handled correctly too as the context can
    /// span more than a few lines.
    open var errorContextLength: UInt = 0

    /** A boolean value that determines whether the parser reports the
     namespaces and qualified names of elements. The default value is `false`.
     */
    open var shouldProcessNamespaces: Bool = false

    /** A boolean value that determines whether the parser trims whitespaces
     and newlines from the end and the beginning of string values. The default
     value is `true`.
     */
    open var trimValueWhitespaces: Bool

    /** A boolean value that determines whether to remove pure whitespace elements
     that have sibling elements that aren't pure whitespace. The default value
     is `false`.
     */
    open var removeWhitespaceElements: Bool

    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    struct Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let dataDecodingStrategy: DataDecodingStrategy
        let nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy
        let keyDecodingStrategy: KeyDecodingStrategy
        let nodeDecodingStrategy: NodeDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level decoder.
    var options: Options {
        return Options(
            dateDecodingStrategy: dateDecodingStrategy,
            dataDecodingStrategy: dataDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy,
            nodeDecodingStrategy: nodeDecodingStrategy,
            userInfo: userInfo
        )
    }

    // MARK: - Constructing a XML Decoder

    /// Initializes `self` with default strategies.
    public init(trimValueWhitespaces: Bool = true, removeWhitespaceElements: Bool = false) {
        self.trimValueWhitespaces = trimValueWhitespaces
        self.removeWhitespaceElements = removeWhitespaceElements
    }

    // MARK: - Decoding Values

    /// Decodes a top-level box of the given type from the given XML representation.
    ///
    /// - parameter type: The type of the box to decode.
    /// - parameter data: The data to decode from.
    /// - returns: A box of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid XML.
    /// - throws: An error if any box throws an error during decoding.
    open func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
        let topLevel: Box = try XMLStackParser.parse(
            with: data,
            errorContextLength: errorContextLength,
            shouldProcessNamespaces: shouldProcessNamespaces,
            trimValueWhitespaces: trimValueWhitespaces,
            removeWhitespaceElements: removeWhitespaceElements
        )

        let decoder = XMLDecoderImplementation(
            referencing: topLevel,
            options: options,
            nodeDecodings: []
        )
        decoder.nodeDecodings = [
            options.nodeDecodingStrategy.nodeDecodings(
                forType: T.self,
                with: decoder
            ),
        ]

        defer {
            _ = decoder.nodeDecodings.removeLast()
        }

        return try decoder.unbox(topLevel)
    }
}

// MARK: TopLevelDecoder

#if canImport(Combine)
import protocol Combine.TopLevelDecoder
import protocol Combine.TopLevelEncoder
#elseif canImport(OpenCombine)
import protocol OpenCombine.TopLevelDecoder
import protocol OpenCombine.TopLevelEncoder
#endif

#if canImport(Combine) || canImport(OpenCombine)
extension XMLDecoder: TopLevelDecoder {}
extension XMLEncoder: TopLevelEncoder {}
#endif
