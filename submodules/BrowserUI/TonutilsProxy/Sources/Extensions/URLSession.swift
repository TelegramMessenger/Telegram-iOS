//
//  Created by Adam Stragner
//

import Foundation

internal extension URLSession {
    static let `default` = URLSession(configuration: .default)
    static var proxyable: URLSession?

    static func proxyable(with connectionProxyDictionary: [AnyHashable: Any]) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.connectionProxyDictionary = connectionProxyDictionary
        return URLSession(configuration: configuration)
    }
}
