import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import WebProxyTransport

public func updateProxySettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ProxySettings) -> ProxySettings) -> Signal<Bool, NoError> {
    return accountManager.transaction { transaction -> Bool in
        return updateProxySettingsInteractively(transaction: transaction, f)
    }
}

extension ProxyServerSettings {
    var isWebProxy: Bool {
        if case .web = self.connection {
            return true
        } else {
            return false
        }
    }

    var mtProxySettings: MTSocksProxySettings {
        switch self.connection {
            case let .socks5(username, password):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: username, password: password, secret: nil)
            case let .mtp(secret):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: nil, password: nil, secret: secret)
            case let .web(secret, _):
                return MTSocksProxySettings(ip: WebProxyConfiguration.canonicalHost(self.host) ?? self.host, port: WebProxyConfiguration.port, username: nil, password: nil, secret: secret, webProxy: true)
        }
    }

    var webProxyConfiguration: WebProxyConfiguration? {
        guard case let .web(secret, path) = self.connection else {
            return nil
        }
        return WebProxyConfiguration(host: self.host, path: path, secret: secret)
    }
}

extension ProxyServerSettings {
    public var webProxyAddress: String? {
        guard case let .web(_, path) = self.connection else {
            return nil
        }
        return path.isEmpty ? self.host : "\(self.host)/\(path)"
    }
}

public func canonicalWebProxyHost(_ value: String) -> String? {
    return WebProxyConfiguration.canonicalHost(value)
}

public func canonicalWebProxyAddress(_ value: String) -> (host: String, path: String)? {
    return WebProxyConfiguration.canonicalAddress(value)
}

public func parseWebProxySecret(_ value: String) -> Data? {
    return WebProxyConfiguration.parseSecret(value)
}

public func webProxySecretString(_ secret: Data) -> String {
    return secret.map { String(format: "%02x", $0) }.joined()
}

public func makeWebProxySettings(address: String, secret: String) -> ProxyServerSettings? {
    guard let address = canonicalWebProxyAddress(address), let data = parseWebProxySecret(secret) else {
        return nil
    }
    return ProxyServerSettings(host: address.host, port: Int32(WebProxyConfiguration.port), connection: .web(secret: data, path: address.path))
}

/// Decodes the `server` and `secret` parameters of a `webproxy` link.
///
/// A link that carries a base path **must** mark its secret with the leading `0x70` byte;
/// an unmarked secret there is rejected (BASE_PATH.md §3). The rule exists so that no link
/// can be silently accepted by a client without base-path support, which would normalize
/// `host/path` to an empty host and offer to connect to a pathless proxy. Hand entry in the
/// editor is not bound by it - the hazard is specific to a shared link - so
/// `makeWebProxySettings(address:secret:)` stays lenient.
/// The `webproxy` query rule, so that every entry point accepts exactly the same set of
/// links. `host` is a legacy input alias for `server` (ANDROID.md); generated links always
/// use `server`, and exactly one of the two must appear alongside exactly one `secret`.
/// Items with any other name are ignored, so a trailing `&`, which `URLComponents` keeps
/// as an empty-name item, or a tracking parameter does not make a shared link dead.
/// Keeping this in one place matters: when `UrlHandling` had its own laxer loop, a link
/// with both `server` and `host` was rejected in the proxy editor and accepted from a
/// chat, resolving to whichever came last.
public func parseWebProxyLinkQueryItems(_ items: [URLQueryItem]) -> (host: String, path: String, secret: Data)? {
    let hostItems = items.filter { $0.name == "server" || $0.name == "host" }
    let secretItems = items.filter { $0.name == "secret" }
    guard hostItems.count == 1,
          secretItems.count == 1,
          let address = hostItems[0].value,
          let secret = secretItems[0].value else {
        return nil
    }
    return parseWebProxyLinkComponents(address: address, secret: secret)
}

public func parseWebProxyLinkComponents(address: String, secret: String) -> (host: String, path: String, secret: Data)? {
    guard let address = canonicalWebProxyAddress(address),
          let decoded = WebProxyConfiguration.parseMarkedSecret(secret),
          address.path.isEmpty || decoded.isMarked else {
        return nil
    }
    return (address.host, address.path, decoded.secret)
}

public func parseWebProxySettingsLink(_ value: String) -> ProxyServerSettings? {
    guard let components = URLComponents(string: value),
          components.fragment == nil,
          components.user == nil,
          components.password == nil else {
        return nil
    }

    let scheme = components.scheme?.lowercased()
    let isTelegramLink = scheme == "https"
        && components.host?.lowercased() == "t.me"
        && components.path == "/webproxy"
        && (components.port == nil || components.port == Int(WebProxyConfiguration.port))
    let isTelegramScheme = scheme == "tg"
        && components.host?.lowercased() == "webproxy"
        && (components.path.isEmpty || components.path == "/")
        && components.port == nil
    guard isTelegramLink || isTelegramScheme else {
        return nil
    }

    guard let link = parseWebProxyLinkQueryItems(components.queryItems ?? []) else {
        return nil
    }
    return ProxyServerSettings(host: link.host, port: Int32(WebProxyConfiguration.port), connection: .web(secret: link.secret, path: link.path))
}

public func webProxySettingsLink(_ settings: ProxyServerSettings) -> String? {
    guard case let .web(secret, path) = settings.connection,
          let configuration = WebProxyConfiguration(host: settings.host, path: path, secret: secret) else {
        return nil
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "t.me"
    components.path = "/webproxy"
    components.percentEncodedQueryItems = [
        URLQueryItem(name: "server", value: webProxyPercentEncodedAddress(configuration.address)),
        URLQueryItem(name: "secret", value: WebProxyConfiguration.linkSecretString(secret, path: configuration.path))
    ]
    return components.string
}

private func webProxyPercentEncodedAddress(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

public func updateProxySettingsInteractively(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (ProxySettings) -> ProxySettings) -> Bool {
    var hasChanges = false
    transaction.updateSharedData(SharedDataKeys.proxySettings, { current in
        let previous = current?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
        let updated = f(previous)
        hasChanges = previous != updated
        return PreferencesEntry(updated)
    })
    return hasChanges
}
