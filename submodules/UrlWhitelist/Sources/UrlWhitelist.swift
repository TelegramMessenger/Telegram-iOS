import Foundation
import UrlEscaping

private let whitelistedHosts: Set<String> = Set([
    "t.me",
    "telegram.me",
    "telegra.ph",
    "telesco.pe",
    "fragment.com"
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

/// `url` with the `http://` the external-URL opener (`openExternalUrlImpl`) supplies when it has no scheme.
private func externalUrlStringWithScheme(_ url: String) -> String {
    if !url.contains("://") && !url.hasPrefix("mailto:") {
        return "http://" + url
    }
    return url
}

/// The address the external-URL opener parses `url` into.
public func canonicalExternalUrl(from url: String) -> URL? {
    let urlWithScheme = externalUrlStringWithScheme(url)
    if let parsed = URL(string: urlWithScheme) {
        return parsed
    } else if let encoded = (urlWithScheme as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) {
        return URL(string: encoded)
    }
    return nil
}

/// Every character that may appear in a URL, unencoded.
private let urlCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%")

/// The address the external-URL opener makes of `url` when that address has a login part
/// (`user[:password]@`) in front of its host, otherwise nil.
///
/// A shared link has no use for one, and what precedes the `@` is what a reader takes for the
/// destination: in `https://telegram.org∕test∕@evil.org` the `∕` (U+2215) are not slashes, so the
/// authority runs on to the `@`, `telegram.org∕test∕` is the user name and the link opens evil.org.
/// Opening such a link is confirmed with a prompt showing `urlRemovingLoginPart` of it.
///
/// The scheme is supplied and the address parsed exactly as in `canonicalExternalUrl`, so whenever
/// the opener's address has a login part, this reports it. Where Foundation rejects the address
/// (before iOS 17 it rejects every character invalid in a URL, non-ASCII ones included, which later
/// versions encode), the opener's fallback encoding loses the authority altogether; the check then
/// encodes the invalid characters as later versions do and judges that, which can only add a prompt.
///
/// `tel:` and `calshow:` links leave the opener before it parses anything, and `mailto:` ones after,
/// so they are never reported; the prefixes are matched exactly as the opener matches them.
///
/// This stays out of `parseUrl`'s `concealed`, which also titles shared-link lists with the whole
/// address instead of the host, the one part of such a link that is true.
public func externalUrlWithLoginPart(_ url: String) -> URL? {
    let lowercasedUrl = url.lowercased()
    if lowercasedUrl.hasPrefix("tel:") || lowercasedUrl.hasPrefix("calshow:") {
        return nil
    }
    let urlWithScheme = externalUrlStringWithScheme(url)
    var parsedUrlValue = URL(string: urlWithScheme)
    if parsedUrlValue == nil, let encoded = urlWithScheme.addingPercentEncoding(withAllowedCharacters: urlCharacters) {
        parsedUrlValue = URL(string: encoded)
    }
    guard let parsedUrl = parsedUrlValue, parsedUrl.scheme != "mailto" else {
        return nil
    }
    if parsedUrl.user == nil && parsedUrl.password == nil {
        return nil
    }
    return parsedUrl
}

/// `url` without its login part, which is the address it really opens.
public func urlRemovingLoginPart(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }
    components.user = nil
    components.password = nil
    return components.url ?? url
}

/// What a menu or prompt naming `url` shows when a login part hides the host it opens: the address without the
/// login part (see `externalUrlWithLoginPart`). Nil for any other link, which keeps its usual text.
public func displayUrlRevealingLoginPart(_ url: String) -> String? {
    return externalUrlWithLoginPart(url).map { urlRemovingLoginPart($0).absoluteString }
}

/// Login-part links the user has accepted from a prompt that showed `urlRemovingLoginPart` of them.
/// Every such link leaves through the external-URL opener, which would otherwise ask a second time.
/// An entry is consumed by the first open of the same address, or lapses after a minute: a prompt whose
/// link then leaves another way (the "Open in Browser" menu opens it directly) never consumes it.
private final class LoginPartConfirmations: @unchecked Sendable {
    private static let lifetime: CFAbsoluteTime = 60.0

    private let lock = NSLock()
    private var acceptedAt: [String: CFAbsoluteTime] = [:]

    func note(_ url: URL) {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.lock.lock()
        self.acceptedAt = self.acceptedAt.filter { timestamp - $0.value < LoginPartConfirmations.lifetime }
        self.acceptedAt[url.absoluteString] = timestamp
        self.lock.unlock()
    }

    func consume(_ url: URL) -> Bool {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard let acceptedAt = self.acceptedAt.removeValue(forKey: url.absoluteString) else {
            return false
        }
        return timestamp - acceptedAt < LoginPartConfirmations.lifetime
    }
}

private let loginPartConfirmations = LoginPartConfirmations()

/// Records that the user accepted opening `url`, a result of `externalUrlWithLoginPart`, from a prompt
/// that showed where it really goes.
public func noteLoginPartConfirmed(_ url: URL) {
    loginPartConfirmations.note(url)
}

/// Whether the user has just accepted opening `url` (see `noteLoginPartConfirmed`). Answers true once.
public func consumeLoginPartConfirmation(_ url: URL) -> Bool {
    return loginPartConfirmations.consume(url)
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
    
    if url.hasPrefix("tg://premium_multigift") || url.hasPrefix("tg://premium_offer") {
        concealed = false
    }
    
    return (rawDisplayUrl, concealed)
}
