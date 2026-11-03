// Copyright (c) 2017-2020 Shawn Moore and XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Shawn Moore on 11/20/17.
//

import Foundation

// MARK: - Decoding Storage

struct XMLDecodingStorage {
    // MARK: Properties

    /// The container stack.
    /// Elements may be any one of the XML types (StringBox, KeyedBox).
    private var containers: [Box] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    init() {}

    // MARK: - Modifying the Stack

    var count: Int {
        return containers.count
    }

    func topContainer() -> Box? {
        return containers.last
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

    @discardableResult
    mutating func popContainer() -> Box? {
        guard !containers.isEmpty else {
            return nil
        }
        return containers.removeLast()
    }
}
