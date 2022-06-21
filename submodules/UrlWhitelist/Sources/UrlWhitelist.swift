import Foundation

private let whitelistedHosts: Set<String> = Set([
    "t.me",
    "telegram.me",
    "telegra.ph",
    "telesco.pe"
])

public func isConcealedUrlWhitelisted(_ url: URL) -> Bool {
    if var host = url.host?.lowercased() {
        let www = "www."
        if host.hasPrefix(www) {
            host.removeFirst(www.count)
        }
        if whitelistedHosts.contains(host) {
            return true
        }
    }
    if let host = url.host?.lowercased(), host == "telegram.org" {
        let whitelistedNativePrefixes: Set<String> = Set([
            "/blog/",
            "/tour/"
        ])

        for nativePrefix in whitelistedNativePrefixes {
            if url.path.starts(with: nativePrefix) {
                return true
            }
        }
    }
    return false
}

public func parseUrl(url: String, wasConcealed: Bool) -> (string: String, concealed: Bool) {
    var parsedUrlValue: URL?
    if url.hasPrefix("tel:") {
        return (url, false)
    } else if url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://"), let parsed = URL(string: url) {
        parsedUrlValue = parsed
    } else if let parsed = URL(string: "https://" + url) {
        parsedUrlValue = parsed
    } else if let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsed = URL(string: encoded) {
        parsedUrlValue = parsed
    }
    let host = parsedUrlValue?.host ?? url
    
    let rawHost = (host as NSString).removingPercentEncoding ?? host
    var latin = CharacterSet()
    latin.insert(charactersIn: "A"..."Z")
    latin.insert(charactersIn: "a"..."z")
    latin.insert(charactersIn: "0"..."9")
    var punctuation = CharacterSet()
    punctuation.insert(charactersIn: ".-/+_?=")
    var hasLatin = false
    var hasNonLatin = false
    for c in rawHost {
        if c.unicodeScalars.allSatisfy(punctuation.contains) {
        } else if c.unicodeScalars.allSatisfy(latin.contains) {
            hasLatin = true
        } else {
            hasNonLatin = true
        }
    }
    var concealed = wasConcealed
    if hasLatin && hasNonLatin {
        concealed = true
    }
    
    var rawDisplayUrl: String
    if hasNonLatin {
        rawDisplayUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
    } else {
        rawDisplayUrl = url
    }
    
    if let parsedUrlValue = parsedUrlValue, isConcealedUrlWhitelisted(parsedUrlValue) {
        concealed = false
    }
    
    let whitelistedSchemes: [String] = [
        "tel",
    ]
    if let parsedUrlValue = parsedUrlValue, let scheme = parsedUrlValue.scheme, whitelistedSchemes.contains(scheme) {
        concealed = false
    }
    
    return (rawDisplayUrl, concealed)
}
