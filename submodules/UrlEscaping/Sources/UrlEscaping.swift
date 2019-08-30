import Foundation

public func doesUrlMatchText(url: String, text: String, fullText: String) -> Bool {
    if fullText.range(of: "\u{202e}") != nil {
        return false
    }
    if url == text {
        return true
    }
    return false
}

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

public extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: generalDelimitersToEncode + subDelimitersToEncode)
        
        return allowed
    }()
}

public func isValidUrl(_ url: String) -> Bool {
    if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: escapedUrl), ["http", "https"].contains(url.scheme), let host = url.host, host.contains(".") && url.user == nil {
        let components = host.components(separatedBy: ".")
        let domain = (components.first ?? "")
        if domain.isEmpty {
            return false
        }
        return true
    } else {
        return false
    }
}

public func explicitUrl(_ url: String) -> String {
    var url = url
    if !url.hasPrefix("http") && !url.hasPrefix("https") {
        url = "https://\(url)"
    }
    return url
}

public func urlEncodedStringFromString(_ string: String) -> String {
    var nsString: NSString = string as NSString
    if let value = nsString.replacingPercentEscapes(using: String.Encoding.utf8.rawValue) {
        nsString = value as NSString
    }
    
    let result = CFURLCreateStringByAddingPercentEscapes(nil, nsString as CFString, nil, "?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ " as CFString, CFStringConvertNSStringEncodingToEncoding(String.Encoding.utf8.rawValue))!
    return result as String
}
