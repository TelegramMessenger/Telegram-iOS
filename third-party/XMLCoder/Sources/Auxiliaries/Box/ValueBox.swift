// Copyright (c) 2019-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Max Desiatov on 05/10/2019.
//

protocol ValueBox: SimpleBox {
    associatedtype Unboxed

    init(_ value: Unboxed)
}
