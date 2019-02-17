import Foundation

struct AccountNotificationKey: Codable {
    let id: Data
    let data: Data
}

struct AccountDatacenterKey: Codable {
    let id: Int64
    let data: Data
}

struct AccountDatacenterAddress: Codable {
    let host: String
    let port: Int32
    let isMedia: Bool
    let secret: Data?
}

struct AccountDatacenterInfo: Codable {
    let masterKey: AccountDatacenterKey
    let addressList: [AccountDatacenterAddress]
}

struct AccountProxyConnection: Codable {
    let host: String
    let port: Int32
    let username: String?
    let password: String?
    let secret: Data?
}

struct StoredAccountInfo: Codable {
    let id: Int64
    let primaryId: Int32
    let isTestingEnvironment: Bool
    let peerName: String
    let datacenters: [Int32: AccountDatacenterInfo]
    let notificationKey: AccountNotificationKey
}

struct StoredAccountInfos: Codable {
    let proxy: AccountProxyConnection?
    let accounts: [StoredAccountInfo]
}

func loadAccountsData(rootPath: String) -> StoredAccountInfos {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: rootPath + "/accounts-shared-data")) else {
        return StoredAccountInfos(proxy: nil, accounts: [])
    }
    guard let value = try? JSONDecoder().decode(StoredAccountInfos.self, from: data) else {
        return StoredAccountInfos(proxy: nil, accounts: [])
    }
    return value
}
