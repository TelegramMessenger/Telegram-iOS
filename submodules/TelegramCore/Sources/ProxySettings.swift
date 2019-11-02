import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import SyncCore

public func updateProxySettingsInteractively(accountManager: AccountManager, _ f: @escaping (ProxySettings) -> ProxySettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateProxySettingsInteractively(transaction: transaction, f)
    }
}

extension ProxyServerSettings {
    var mtProxySettings: MTSocksProxySettings {
        switch self.connection {
            case let .socks5(username, password):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: username, password: password, secret: nil)
            case let .mtp(secret):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: nil, password: nil, secret: secret)
        }
    }
}

public func updateProxySettingsInteractively(transaction: AccountManagerModifier, _ f: @escaping (ProxySettings) -> ProxySettings) {
    transaction.updateSharedData(SharedDataKeys.proxySettings, { current in
        let previous = (current as? ProxySettings) ?? ProxySettings.defaultSettings
        let updated = f(previous)
        return updated
    })
}
