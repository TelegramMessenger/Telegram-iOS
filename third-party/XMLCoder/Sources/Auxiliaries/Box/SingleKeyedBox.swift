// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by James Bean on 7/15/19.
//

/// A `Box` which contains a single `key` and `element` pair. This is useful for disambiguating elements which could either represent
/// an element nested in a keyed or unkeyed container, or an choice between multiple known-typed values (implemented in Swift using
/// enums with associated values).
struct SingleKeyedBox: SimpleBox {
    var key: String
    var element: Box
}

extension SingleKeyedBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return nil
    }
}
