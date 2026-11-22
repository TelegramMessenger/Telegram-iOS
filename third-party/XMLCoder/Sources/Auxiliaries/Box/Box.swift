// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Vincent Esche on 12/17/18.
//

protocol Box {
    var isNull: Bool { get }
    var xmlString: String? { get }
}

/// A box that only describes a single atomic value.
protocol SimpleBox: Box {
    // A simple tagging protocol, for now.
}

protocol TypeErasedSharedBoxProtocol {
    func typeErasedUnbox() -> Box
}

protocol SharedBoxProtocol: TypeErasedSharedBoxProtocol {
    associatedtype B: Box
    func unbox() -> B
}

extension SharedBoxProtocol {
    func typeErasedUnbox() -> Box {
        return unbox()
    }
}
