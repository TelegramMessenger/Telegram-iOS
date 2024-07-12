//
//  Created by Adam Stragner
//

import Foundation
import WebKit

public extension WKWebViewConfiguration {
    func setURLSchemeHandler(_ urlSchemeHandler: TonutilsURLSchemeHandler) {
        let _ = WKWebView._swizzle
        TonutilsURLSchemeHandler.schemas.forEach({
            setURLSchemeHandler(urlSchemeHandler, forURLScheme: $0)
        })
    }
}
