// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Max Desiatov on 05/10/2019.
//

struct DoubleBox: Equatable, ValueBox {
    typealias Unboxed = Double

    let unboxed: Unboxed

    init(_ value: Unboxed) {
        unboxed = value
    }

    init?(xmlString: String) {
        guard let unboxed = Double(xmlString) else { return nil }

        self.init(unboxed)
    }
}

extension DoubleBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        guard !unboxed.isNaN else {
            return "NaN"
        }

        guard !unboxed.isInfinite else {
            return (unboxed > 0.0) ? "INF" : "-INF"
        }

        return unboxed.description
    }
}

extension DoubleBox: SimpleBox {}

extension DoubleBox: CustomStringConvertible {
    var description: String {
        return unboxed.description
    }
}
