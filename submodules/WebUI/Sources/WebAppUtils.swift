import Foundation

func makeWebAppTelegramLink(pathFull: String) -> String? {
    guard pathFull.hasPrefix("/"), !pathFull.hasPrefix("//") else {
        return nil
    }
    if pathFull.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
        return nil
    }
    if pathFull.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) {
        return nil
    }
    if pathFull.contains("#") {
        return nil
    }
    
    let urlString = "https://t.me\(pathFull)"
    guard let url = URL(string: urlString) else {
        return nil
    }
    guard url.scheme?.lowercased() == "https" else {
        return nil
    }
    guard url.host?.lowercased() == "t.me" else {
        return nil
    }
    guard url.user == nil, url.password == nil, url.fragment == nil else {
        return nil
    }
    return url.absoluteString
}

func isAllowedBotMediaUrl(_ urlString: String) -> Bool {
    guard let escaped = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: escaped) else {
        return false
    }
    guard url.scheme?.lowercased() == "https" else {
        return false
    }
    if url.user != nil || url.password != nil {
        return false
    }
    guard var host = url.host?.lowercased(), !host.isEmpty else {
        return false
    }
    if host.hasPrefix("[") && host.hasSuffix("]") {
        host = String(host.dropFirst().dropLast())
    }

    // Strict canonical dotted-decimal IPv4 (4 octets, no leading zeros, each 0-255).
    // Do NOT use inet_pton here: Darwin's inet_pton accepts "0177.0.0.1" as
    // decimal 177.0.0.1, but getaddrinfo (used by URLSession) interprets the
    // same string as octal 127.0.0.1 — the divergence is a loopback bypass.
    if let v4Bytes = parseCanonicalIPv4(host) {
        return isPublicIPv4(v4Bytes)
    }

    // IPv6 only — host must contain ":" so we don't accidentally hand a
    // numeric-looking hostname to inet_pton.
    if host.contains(":") {
        var v6 = in6_addr()
        if host.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
            let bytes = withUnsafeBytes(of: &v6) { ptr -> [UInt8] in
                return Array(ptr)
            }
            return isPublicIPv6(bytes)
        }
        return false
    }

    // Strict DNS-name validation. Anything that doesn't look like a real
    // FQDN is rejected — this catches non-canonical numeric IP forms
    // (decimal-32 like "2130706433", octal like "0177.0.0.1", hex like
    // "0x7f.0.0.1", short forms like "127.1") that the OS resolver may
    // still treat as 127.0.0.1 even when inet_pton would accept them as
    // a different value or reject outright.
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2 else { return false }
    for label in labels {
        guard !label.isEmpty, label.count <= 63 else { return false }
        if label.first == "-" || label.last == "-" { return false }
        for ch in label {
            guard ch.isASCII else { return false }
            if !(ch.isLetter || ch.isNumber || ch == "-") { return false }
        }
    }
    guard let tld = labels.last, tld.count >= 2, tld.contains(where: { $0.isLetter }) else {
        return false
    }

    if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
        return false
    }
    return true
}

private func parseCanonicalIPv4(_ host: String) -> [UInt8]? {
    let parts = host.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return nil }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(4)
    for part in parts {
        guard !part.isEmpty, part.count <= 3 else { return nil }
        if part.count > 1 && part.first == "0" { return nil }      // no leading zeros (octal-spoof)
        guard part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let value = UInt8(part) else { return nil }          // also caps at 255
        bytes.append(value)
    }
    return bytes
}

private func isPublicIPv4(_ bytes: [UInt8]) -> Bool {
    guard bytes.count == 4 else { return false }
    let a = bytes[0]
    let b = bytes[1]
    if a == 0 { return false }                          // 0.0.0.0/8
    if a == 10 { return false }                         // 10.0.0.0/8
    if a == 127 { return false }                        // 127.0.0.0/8 loopback
    if a == 169 && b == 254 { return false }            // 169.254.0.0/16 link-local
    if a == 172 && (b & 0xf0) == 16 { return false }    // 172.16.0.0/12
    if a == 192 && b == 168 { return false }            // 192.168.0.0/16
    if a == 100 && (b & 0xc0) == 64 { return false }    // 100.64.0.0/10 CGNAT
    if a >= 224 { return false }                        // multicast + reserved + 255.255.255.255
    return true
}

private func isPublicIPv6(_ bytes: [UInt8]) -> Bool {
    guard bytes.count == 16 else { return false }
    if bytes.allSatisfy({ $0 == 0 }) { return false }                       // ::
    let loopback: [UInt8] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]
    if bytes == loopback { return false }                                   // ::1
    if bytes[0] == 0xff { return false }                                    // ff00::/8 multicast
    if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return false }       // fe80::/10 link-local
    if (bytes[0] & 0xfe) == 0xfc { return false }                           // fc00::/7 unique-local
    let v4MappedPrefix: [UInt8] = [0,0,0,0,0,0,0,0,0,0,0xff,0xff]
    if Array(bytes.prefix(12)) == v4MappedPrefix {                          // ::ffff:a.b.c.d
        return isPublicIPv4(Array(bytes.suffix(4)))
    }
    if Array(bytes.prefix(12)).allSatisfy({ $0 == 0 }) {                    // ::a.b.c.d (deprecated)
        return isPublicIPv4(Array(bytes.suffix(4)))
    }
    return true
}
