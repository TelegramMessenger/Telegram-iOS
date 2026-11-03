// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/21/17.
//

import Foundation

// MARK: - Error Utilities

extension DecodingError {
    /// Returns a `.typeMismatch` error describing the expected type.
    ///
    /// - parameter path: The path of `CodingKey`s taken to decode a value of this type.
    /// - parameter expectation: The type expected to be encountered.
    /// - parameter reality: The value that was encountered instead of the expected type.
    /// - returns: A `DecodingError` with the appropriate path and debug description.
    static func typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: Box) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(_typeDescription(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    /// Returns a description of the type of `value` appropriate for an error message.
    ///
    /// - parameter value: The value whose type to describe.
    /// - returns: A string describing `value`.
    /// - precondition: `value` is one of the types below.
    static func _typeDescription(of box: Box) -> String {
        switch box {
        case is NullBox:
            return "a null value"
        case is BoolBox:
            return "a boolean value"
        case is DecimalBox:
            return "a decimal value"
        case is IntBox:
            return "a signed integer value"
        case is UIntBox:
            return "an unsigned integer value"
        case is FloatBox:
            return "a floating-point value"
        case is DoubleBox:
            return "a double floating-point value"
        case is UnkeyedBox:
            return "a array value"
        case is KeyedBox:
            return "a dictionary value"
        case _:
            return "\(type(of: box))"
        }
    }
}
