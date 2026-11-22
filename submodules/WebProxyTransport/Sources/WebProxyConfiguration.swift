import CommonCrypto
import Foundation

public struct WebProxyConfiguration: Equatable, Hashable {
    public static let port: UInt16 = 443
    public static let maximumPathLength = 128

    public let host: String
    public let path: String
    public let secret: Data

    public init?(host: String, path: String = "", secret: Data) {
        guard let host = Self.canonicalHost(host), let path = Self.canonicalPath(path), Self.isValidSecret(secret) else {
            return nil
        }
        self.host = host
        self.path = path
        self.secret = secret
    }

    /// The marker BASE_PATH.md §3 puts in front of a base-path link's secret.
    ///
    /// Deliberately not `0xDD`: a client without base-path support reads a 17-byte secret
    /// beginning with `0xDD` as an ordinary padded secret and accepts the link, having
    /// normalized `host/path` down to an empty host. With `0x70` it instead sees a secret
    /// it cannot classify and reports an unsupported proxy type.
    public static let secretMarker: UInt8 = 0x70

    public static func isValidSecret(_ secret: Data) -> Bool {
        return secret.count == 16 || (secret.count == 17 && secret.first == 0xdd)
    }

    /// Decodes a secret as written in a link or typed into the editor, reporting whether
    /// it carried the `0x70` marker.
    ///
    /// BASE_PATH.md §3's inverse rule - strip a leading `0x70` from a value of at least 17
    /// bytes - is unambiguous because a canonical secret is 16 bytes, 17 beginning with
    /// `0xDD`, or 21+ beginning with `0xEE`.
    public static func parseMarkedSecret(_ value: String) -> (secret: Data, isMarked: Bool)? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Hex first: a plain 32-character secret is also well-formed base64url, and hex is
        // the canonical root form. A hex value that is not a secret still falls through, so
        // a marked secret whose encoding happens to be all hex digits is not lost.
        if let hex = self.hexBytes(value), let result = self.unmarkedSecret(hex) {
            return result
        }
        guard let bytes = self.base64UrlBytes(value) else {
            return nil
        }
        return self.unmarkedSecret(bytes)
    }

    public static func parseSecret(_ value: String) -> Data? {
        return self.parseMarkedSecret(value)?.secret
    }

    /// The link form of `secret`: plain hex at the root, `0x70`-marked base64url under a
    /// base path. A path-bearing link must use the marked form (BASE_PATH.md §3).
    public static func linkSecretString(_ secret: Data, path: String) -> String {
        if path.isEmpty {
            return secret.map { String(format: "%02x", $0) }.joined()
        }
        return (Data([self.secretMarker]) + secret).webProxyBase64Url
    }

    private static func unmarkedSecret(_ bytes: Data) -> (secret: Data, isMarked: Bool)? {
        let isMarked = bytes.count >= 17 && bytes.first == self.secretMarker
        let secret = isMarked ? Data(bytes.dropFirst()) : bytes
        guard self.isValidSecret(secret) else {
            return nil
        }
        return (secret, isMarked)
    }

    private static func hexBytes(_ value: String) -> Data? {
        guard !value.isEmpty, value.count % 2 == 0, value.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        var result = Data()
        result.reserveCapacity(value.count / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index ..< next], radix: 16) else {
                return nil
            }
            result.append(byte)
            index = next
        }
        return result
    }

    private static func base64UrlBytes(_ value: String) -> Data? {
        guard !value.isEmpty else {
            return nil
        }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    public static func canonicalHost(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("@"),
              !trimmed.contains(":"),
              let components = URLComponents(string: "https://\(trimmed)"),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              let host = components.url?.host?.lowercased(),
              !host.isEmpty,
              host.utf8.count <= 253 else {
            return nil
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" && label.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "-")
            }
        }), !lastLabelIsNumeric(labels) else {
            return nil
        }
        return host
    }

    public static func canonicalPath(_ value: String) -> String? {
        var path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty {
            return ""
        }
        guard !path.hasPrefix("/") else {
            return nil
        }
        if path.hasSuffix("/") {
            path.removeLast()
        }
        guard !path.isEmpty, path.count <= maximumPathLength else {
            return nil
        }
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.allSatisfy({ segment in
            guard let first = segment.first, first.isASCII, first.isLetter || first.isNumber else {
                return false
            }
            return segment.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_")
            }
        }) else {
            return nil
        }
        return path
    }

    public static func canonicalAddress(_ value: String) -> (host: String, path: String)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(of: "/") else {
            guard let host = canonicalHost(trimmed) else {
                return nil
            }
            return (host, "")
        }
        guard let host = canonicalHost(String(trimmed[trimmed.startIndex ..< separator])),
              let path = canonicalPath(String(trimmed[trimmed.index(after: separator)...])) else {
            return nil
        }
        return (host, path)
    }

    private static func lastLabelIsNumeric(_ labels: [Substring]) -> Bool {
        guard let label = labels.last, !label.isEmpty else {
            return false
        }
        let hexadecimal = label.count >= 2 && label.first == "0" && (label[label.index(after: label.startIndex)] == "x" || label[label.index(after: label.startIndex)] == "X")
        let digits = hexadecimal ? label.dropFirst(2) : label[...]
        return digits.allSatisfy { character in
            character.isASCII && (character.isNumber || (hexadecimal && character.isHexDigit))
        }
    }

    public var address: String {
        return self.path.isEmpty ? self.host : "\(self.host)/\(self.path)"
    }

    public var base: String {
        return self.path.isEmpty ? "/" : "/\(self.path)/"
    }

    public var secretHex: String {
        return self.secret.map { String(format: "%02x", $0) }.joined()
    }

    public func bridgeCapability() -> String {
        let context: Data
        if self.path.isEmpty {
            context = Data("tdesktop-web-proxy-bridge-v1\n\(self.host)".utf8)
        } else {
            context = Data("tdesktop-web-proxy-bridge-v2\n\(self.host)\n\(self.path)".utf8)
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.secret.withUnsafeBytes { keyBytes in
            context.withUnsafeBytes { contextBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, self.secret.count, contextBytes.baseAddress, context.count, &digest)
            }
        }
        return Data(digest).webProxyBase64Url
    }

    public func bridgeURL(nonce: String) -> URL? {
        guard nonce.utf8.count == 43 else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = self.base
        components.queryItems = [URLQueryItem(name: "bridge", value: self.bridgeCapability())]
        components.fragment = "android=\(nonce)"
        return components.url
    }
}

extension Data {
    var webProxyBase64Url: String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
