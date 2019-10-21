import Foundation
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import LightweightAccountData

private func accountInfo(account: Account) -> Signal<StoredAccountInfo, NoError> {
    let peerName = account.postbox.transaction { transaction -> String in
        guard let peer = transaction.getPeer(account.peerId) else {
            return ""
        }
        if let addressName = peer.addressName {
            return "\(addressName)"
        }
        return peer.debugDisplayTitle
    }
    
    let primaryDatacenterId = Int32(account.network.datacenterId)
    let context = account.network.context
    
    var datacenters: [Int32: AccountDatacenterInfo] = [:]
    for nId in context.knownDatacenterIds() {
        if let id = nId as? Int {
            if let authInfo = context.authInfoForDatacenter(withId: id), let authKey = authInfo.authKey {
                let transportScheme = context.chooseTransportSchemeForConnection(toDatacenterId: id, schemes: context.transportSchemesForDatacenter(withId: id, media: true, enforceMedia: false, isProxy: false))
                var addressList: [AccountDatacenterAddress] = []
                if let transportScheme = transportScheme, let address = transportScheme.address, let host = address.host {
                    let secret: Data? = address.secret
                    addressList.append(AccountDatacenterAddress(host: host, port: Int32(address.port), isMedia: address.preferForMedia, secret: secret))
                }
                datacenters[Int32(id)] = AccountDatacenterInfo(masterKey: AccountDatacenterKey(id: authInfo.authKeyId, data: authKey), addressList: addressList)
            }
        }
    }
    
    let notificationKey = masterNotificationsKey(account: account, ignoreDisabled: false)
    
    return combineLatest(peerName, notificationKey)
    |> map { peerName, notificationKey -> StoredAccountInfo in
        return StoredAccountInfo(id: account.id.int64, primaryId: primaryDatacenterId, isTestingEnvironment: account.testingEnvironment, peerName: peerName, datacenters: datacenters, notificationKey: AccountNotificationKey(id: notificationKey.id, data: notificationKey.data))
    }
}

func sharedAccountInfos(accountManager: AccountManager, accounts: Signal<[Account], NoError>) -> Signal<StoredAccountInfos, NoError> {
    return combineLatest(accountManager.sharedData(keys: [SharedDataKeys.proxySettings]), accounts)
    |> mapToSignal { sharedData, accounts -> Signal<StoredAccountInfos, NoError> in
        let proxySettings = sharedData.entries[SharedDataKeys.proxySettings] as? ProxySettings
        let proxy = proxySettings?.effectiveActiveServer.flatMap { proxyServer -> AccountProxyConnection? in
            var username: String?
            var password: String?
            var secret: Data?
            switch proxyServer.connection {
                case let .socks5(usernameValue, passwordValue):
                    username = usernameValue
                    password = passwordValue
                case let .mtp(secretValue):
                    secret = secretValue
            }
            return AccountProxyConnection(host: proxyServer.host, port: proxyServer.port, username: username, password: password, secret: secret)
        }
        
        return combineLatest(accounts.map(accountInfo))
        |> map { infos -> StoredAccountInfos in
            return StoredAccountInfos(proxy: proxy, accounts: infos)
        }
    }
}

func storeAccountsData(rootPath: String, accounts: StoredAccountInfos) {
    guard let data = try? JSONEncoder().encode(accounts) else {
        Logger.shared.log("storeAccountsData", "Error encoding data")
        return
    }
    guard let _ = try? data.write(to: URL(fileURLWithPath: rootPath + "/accounts-shared-data")) else {
        Logger.shared.log("storeAccountsData", "Error saving data")
        return
    }
}
