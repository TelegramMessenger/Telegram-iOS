import Foundation

struct BrowserHTTPAuthOrigin: Equatable {
    let scheme: String
    let host: String
    let port: Int

    init?(url: URL) {
        self.init(scheme: url.scheme, host: url.host, port: url.port)
    }

    init?(protectionSpace: URLProtectionSpace) {
        let port: Int?
        if protectionSpace.port > 0 {
            port = protectionSpace.port
        } else {
            port = nil
        }
        self.init(scheme: protectionSpace.protocol, host: protectionSpace.host, port: port)
    }

    init?(scheme: String?, host: String?, port: Int?) {
        guard let scheme = scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        guard let host = host?.lowercased(), !host.isEmpty else {
            return nil
        }
        let effectivePort: Int
        if let port {
            guard (1 ... 65535).contains(port) else {
                return nil
            }
            effectivePort = port
        } else if scheme == "http" {
            effectivePort = 80
        } else {
            effectivePort = 443
        }
        self.scheme = scheme
        self.host = host
        self.port = effectivePort
    }
}

func browserHTTPAuthChallengeMatchesTopLevelOrigin(topLevelUrl: URL?, protectionSpace: URLProtectionSpace) -> Bool {
    guard let topLevelUrl, let topLevelOrigin = BrowserHTTPAuthOrigin(url: topLevelUrl), let challengeOrigin = BrowserHTTPAuthOrigin(protectionSpace: protectionSpace) else {
        return false
    }
    return topLevelOrigin == challengeOrigin
}
