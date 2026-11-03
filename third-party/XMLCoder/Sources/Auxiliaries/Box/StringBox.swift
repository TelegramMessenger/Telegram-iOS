// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

struct StringBox: Equatable {
    typealias Unboxed = String

    let unboxed: Unboxed

    init(_ unboxed: Unboxed) {
        self.unboxed = unboxed
    }

    init(xmlString: Unboxed) {
        self.init(xmlString)
    }
}

extension StringBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return unboxed.description
    }
}

extension StringBox: SimpleBox {}

extension StringBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
