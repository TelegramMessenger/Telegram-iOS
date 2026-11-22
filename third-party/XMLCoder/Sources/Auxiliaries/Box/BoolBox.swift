// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

struct BoolBox: Equatable {
    typealias Unboxed = Bool

    let unboxed: Unboxed

    init(_ unboxed: Unboxed) {
        self.unboxed = unboxed
    }

    init?(xmlString: String) {
        switch xmlString.lowercased() {
        case "false", "0", "n", "no": self.init(false)
        case "true", "1", "y", "yes": self.init(true)
        case _: return nil
        }
    }
}

extension BoolBox: Box {
    var isNull: Bool {
        return false
    }

    /// # Lexical representation
    /// Boolean has a lexical representation consisting of the following
    /// legal literals {`true`, `false`, `1`, `0`}.
    ///
    /// # Canonical representation
    /// The canonical representation for boolean is the set of literals {`true`, `false`}.
    ///
    /// ---
    ///
    /// [Schema definition](https://www.w3.org/TR/xmlschema-2/#boolean)
    var xmlString: String? {
        return (unboxed) ? "true" : "false"
    }
}

extension BoolBox: SimpleBox {}

extension BoolBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
