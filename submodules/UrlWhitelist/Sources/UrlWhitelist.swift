import Foundation

private let whitelistedHosts: Set<String> = Set([
    "t.me",
    "telegram.me"
])

public func isConcealedUrlWhitelisted(_ url: URL) -> Bool {
    if let host = url.host, whitelistedHosts.contains(host) {
        return true
    }
    return false
}
