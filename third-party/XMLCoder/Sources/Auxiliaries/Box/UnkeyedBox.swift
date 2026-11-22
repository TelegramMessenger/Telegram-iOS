// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 11/20/18.
//

typealias UnkeyedBox = [Box]

extension Array: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return nil
    }
}
