// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by James Bean on 7/18/19.
//

/// A `Box` which represents an element which is known to contain an XML choice element.
struct ChoiceBox {
    var key: String = ""
    var element: Box = NullBox()
}

extension ChoiceBox: Box {
    var isNull: Bool {
        return false
    }

    var xmlString: String? {
        return nil
    }
}

extension ChoiceBox: SimpleBox {}

extension ChoiceBox {
    init?(_ keyedBox: KeyedBox) {
        guard
            let firstKey = keyedBox.elements.keys.first,
            let firstElement = keyedBox.elements[firstKey].first
        else {
            return nil
        }
        self.init(key: firstKey, element: firstElement)
    }

    init(_ singleKeyedBox: SingleKeyedBox) {
        self.init(key: singleKeyedBox.key, element: singleKeyedBox.element)
    }
}
