//
//  Created by Adam Stragner
//

import Foundation

internal extension URL {
    var isTON: Bool {
        if #available(iOS 13.0, *) {
            return !TonutilsProxy.SupportedDomain
                .allCases
                .map({ ".\($0)" })
                .filter({ (host ?? "").hasSuffix($0) })
                .isEmpty
        } else {
            return false
        }
    }
}
