//
//  Created by Adam Stragner
//

import Foundation
import WebKit

/// `WKWebView` does not allow the addition of a custom` WKURLSchemeHandler` for the `HTTP` and `HTTPS` schemes.
/// However, this workaround enables us to accomplish this task.
internal extension WKWebView {
    static let _swizzle: Void = {
        let origin = class_getClassMethod(WKWebView.self, #selector(WKWebView.handlesURLScheme(_:)))
        let swizzled = class_getClassMethod(
            WKWebView.self,
            #selector(WKWebView.swizzled_handlesURLScheme(_:))
        )

        guard let origin, let swizzled
        else {
            return
        }

        method_exchangeImplementations(origin, swizzled)
        return ()
    }()

    @objc(swizzled_handlesURLScheme:)
    private static func swizzled_handlesURLScheme(_ urlScheme: String) -> Bool {
        guard !TonutilsURLSchemeHandler.schemas.contains(urlScheme)
        else {
            return false
        }

        return swizzled_handlesURLScheme(urlScheme)
    }
}
