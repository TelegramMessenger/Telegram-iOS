// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

import Foundation

struct DecimalBox: Equatable {
    typealias Unboxed = Decimal

    let unboxed: Unboxed

    init(_ unboxed: Unboxed) {
        self.unboxed = unboxed
    }

    init?(xmlString: String) {
        guard let unboxed = Unboxed(string: xmlString) else {
            return nil
        }
        self.init(unboxed)
    }
}

extension DecimalBox: Box {
    var isNull: Bool {
        return false
    }

    /// # Lexical representation
    /// Decimal has a lexical representation consisting of a finite-length sequence of
    /// decimal digits separated by a period as a decimal indicator.
    /// An optional leading sign is allowed. If the sign is omitted, `"+"` is assumed.
    /// Leading and trailing zeroes are optional. If the fractional part is zero,
    /// the period and following zero(es) can be omitted.
    /// For example: `-1.23`, `12678967.543233`, `+100000.00`, `210`.
    ///
    /// # Canonical representation
    /// The canonical representation for decimal is defined by prohibiting certain
    /// options from the Lexical representation. Specifically, the preceding optional
    /// `"+"` sign is prohibited. The decimal point is required. Leading and trailing
    /// zeroes are prohibited subject to the following: there must be at least one
    /// digit to the right and to the left of the decimal point which may be a zero.
    ///
    /// ---
    ///
    /// [Schema definition](https://www.w3.org/TR/xmlschema-2/#decimal)
    var xmlString: String? {
        return "\(unboxed)"
    }
}

extension DecimalBox: SimpleBox {}

extension DecimalBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
