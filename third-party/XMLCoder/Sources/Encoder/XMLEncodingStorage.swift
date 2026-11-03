// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/22/17.
//

import Foundation

// MARK: - Encoding Storage and Containers

struct XMLEncodingStorage {
    // MARK: Properties

    /// The container stack.
    private var containers: [Box] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    init() {}

    // MARK: - Modifying the Stack

    var count: Int {
        return containers.count
    }

    var lastContainer: Box? {
        return containers.last
    }

    mutating func pushKeyedContainer(_ keyedBox: KeyedBox = KeyedBox()) -> SharedBox<KeyedBox> {
        let container = SharedBox(keyedBox)
        containers.append(container)
        return container
    }

    mutating func pushChoiceContainer() -> SharedBox<ChoiceBox> {
        let container = SharedBox(ChoiceBox())
        containers.append(container)
        return container
    }

    mutating func pushUnkeyedContainer() -> SharedBox<UnkeyedBox> {
        let container = SharedBox(UnkeyedBox())
        containers.append(container)
        return container
    }

    mutating func push(container: Box) {
        if let keyedBox = container as? KeyedBox {
            containers.append(SharedBox(keyedBox))
        } else if let unkeyedBox = container as? UnkeyedBox {
            containers.append(SharedBox(unkeyedBox))
        } else {
            containers.append(container)
        }
    }

    mutating func popContainer() -> Box {
        precondition(!containers.isEmpty, "Empty container stack.")
        return containers.popLast()!
    }
}
