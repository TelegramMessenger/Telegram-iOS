// Copyright (c) 2018-2023 XMLCoder contributors
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT
//
//  Created by Alkenso (Vladimir Vashurkin) on 08.06.2023.
//

import Foundation

extension CodingKey {
    internal var isInlined: Bool { stringValue == "" }
}
