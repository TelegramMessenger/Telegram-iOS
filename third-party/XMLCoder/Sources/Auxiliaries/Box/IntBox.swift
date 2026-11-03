// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

struct IntBox: Equatable {
    typealias Unboxed = Int64

    let unboxed: Unboxed

    init<Integer: SignedInteger>(_ unboxed: Integer) {
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

extension IntBox: Box {
    var isNull: Bool {
        return false
    }

    /// # Lexical representation
    /// Integer has a lexical representation consisting of a finite-length sequence of
    /// decimal digits with an optional leading sign. If the sign is omitted, `"+"` is assumed.
    /// For example: `-1`, `0`, `12678967543233`, `+100000`.
    ///
    /// # Canonical representation
    /// The canonical representation for integer is defined by prohibiting certain
    /// options from the Lexical representation. Specifically, the preceding optional
    /// `"+"` sign is prohibited and leading zeroes are prohibited.
    ///
    /// ---
    ///
    /// [Schema definition](https://www.w3.org/TR/xmlschema-2/#integer)
    var xmlString: String? {
        return unboxed.description
    }
}

extension IntBox: SimpleBox {}

extension IntBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
