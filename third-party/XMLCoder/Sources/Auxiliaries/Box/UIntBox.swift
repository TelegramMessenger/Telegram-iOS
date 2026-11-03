// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

struct UIntBox: Equatable {
    typealias Unboxed = UInt64

    let unboxed: Unboxed

    init<Integer: UnsignedInteger>(_ unboxed: Integer) {
        self.unboxed = Unboxed(unboxed)
    }

    init?(xmlString: String) {
        guard let unboxed = Unboxed(xmlString) else {
            return nil
        }
        self.init(unboxed)
    }

    func unbox<Integer: BinaryInteger>() -> Integer? {
        return Integer(exactly: unboxed)
    }
}

extension UIntBox: Box {
    var isNull: Bool {
        return false
    }

    /// # Lexical representation
    /// Unsigned integer has a lexical representation consisting of an optional
    /// sign followed by a finite-length sequence of decimal digits.
    /// If the sign is omitted, the positive sign (`"+"`) is assumed.
    /// If the sign is present, it must be `"+"` except for lexical forms denoting zero,
    /// which may be preceded by a positive (`"+"`) or a negative (`"-"`) sign.
    /// For example: `1`, `0`, `12678967543233`, `+100000`.
    ///
    /// # Canonical representation
    /// The canonical representation for nonNegativeInteger is defined by prohibiting
    /// certain options from the Lexical representation. Specifically,
    /// the the optional `"+"` sign is prohibited and leading zeroes are prohibited.
    ///
    /// ---
    ///
    /// [Schema definition](https://www.w3.org/TR/xmlschema-2/#nonNegativeInteger)
    var xmlString: String? {
        return unboxed.description
    }
}

extension UIntBox: SimpleBox {}

extension UIntBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
