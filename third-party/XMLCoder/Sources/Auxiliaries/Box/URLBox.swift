// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/21/18.
//

import Foundation

struct URLBox: Equatable {
    typealias Unboxed = URL

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

extension URLBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return unboxed.absoluteString
    }
}

extension URLBox: SimpleBox {}

extension URLBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
