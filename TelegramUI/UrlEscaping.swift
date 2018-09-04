import Foundation

func doesUrlMatchText(url: String, text: String) -> Bool {
    if url == text {
        return true
    }
    return false
}

private let whitelistedHosts: Set<String> = Set([
    "t.me",
    "telegram.me"
])

func isConcealedUrlWhitelisted(_ url: URL) -> Bool {
    if let host = url.host, whitelistedHosts.contains(host) {
        return true
    }
    return false
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: generalDelimitersToEncode + subDelimitersToEncode)
        
        return allowed
    }()
}
