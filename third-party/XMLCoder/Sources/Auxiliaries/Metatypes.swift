// Copyright (c) 2018-2020 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Max Desiatov on 30/12/2018.
//

/// Type-erased protocol helper for a metatype check in generic `decode`
/// overload. If you custom sequence type is not decoded correctly, try
/// making it confirm to `XMLDecodableSequence`. Default conformances for
/// `Array` and `Dictionary` are already provided by the XMLCoder library.
public protocol XMLDecodableSequence {
    init()
}

extension Array: XMLDecodableSequence {}

extension Dictionary: XMLDecodableSequence {}

/// Type-erased protocol helper for a metatype check in generic `decode`
/// overload.
protocol AnyOptional {
    init()
}

extension Optional: AnyOptional {
    init() {
        self = nil
    }
}
