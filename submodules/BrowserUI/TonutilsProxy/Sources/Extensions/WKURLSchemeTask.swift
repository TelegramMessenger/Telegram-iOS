//
//  Created by Adam Stragner
//

import Foundation
import WebKit

internal extension WKURLSchemeTask {
    var identifier: AnyHashable {
        AnyHashable(request)
    }
}
