import Foundation

public struct AccountNotificationKey: Codable {
    public let id: Data
    public let data: Data
    
    public init(id: Data, data: Data) {
        self.id = id
        self.data = data
    }
}

public struct AccountDatacenterKey: Codable {
    public let id: Int64
    public let data: Data
    
    public init(id: Int64, data: Data) {
        self.id = id
        self.data = data
    }
}

public struct AccountDatacenterAddress: Codable {
    public let host: String
    public let port: Int32
    public let isMedia: Bool
    public let secret: Data?
    
    public init(host: String, port: Int32, isMedia: Bool, secret: Data?) {
        self.host = host
        self.port = port
        self.isMedia = isMedia
        self.secret = secret
    }
}

public struct AccountDatacenterInfo: Codable {
    public let masterKey: AccountDatacenterKey
    public let ephemeralMainKey: AccountDatacenterKey?
    public let ephemeralMediaKey: AccountDatacenterKey?
    public let addressList: [AccountDatacenterAddress]
    
    public init(masterKey: AccountDatacenterKey, ephemeralMainKey: AccountDatacenterKey?, ephemeralMediaKey: AccountDatacenterKey?, addressList: [AccountDatacenterAddress]) {
        self.masterKey = masterKey
        self.ephemeralMainKey = ephemeralMainKey
        self.ephemeralMediaKey = ephemeralMediaKey
        self.addressList = addressList
    }
}

public struct AccountProxyConnection: Codable {
    public let host: String
    public let port: Int32
    public let username: String?
    public let password: String?
    public let secret: Data?
    
    public init(host: String, port: Int32, username: String?, password: String?, secret: Data?) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.secret = secret
    }
}

public struct StoredAccountInfo: Codable {
    public let id: Int64
    public let primaryId: Int32
    public let isTestingEnvironment: Bool
    public let peerName: String
    public let datacenters: [Int32: AccountDatacenterInfo]
    public let notificationKey: AccountNotificationKey
    
    public init(id: Int64, primaryId: Int32, isTestingEnvironment: Bool, peerName: String, datacenters: [Int32: AccountDatacenterInfo], notificationKey: AccountNotificationKey) {
        self.id = id
        self.primaryId = primaryId
        self.isTestingEnvironment = isTestingEnvironment
        self.peerName = peerName
        self.datacenters = datacenters
        self.notificationKey = notificationKey
    }
}

public struct StoredAccountInfos: Codable {
    public let proxy: AccountProxyConnection?
    public let accounts: [StoredAccountInfo]
    
    public init(proxy: AccountProxyConnection?, accounts: [StoredAccountInfo]) {
        self.proxy = proxy
        self.accounts = accounts
    }
}

public func loadAccountsData(rootPath: String) -> StoredAccountInfos {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: rootPath + "/accounts-shared-data")) else {
        return StoredAccountInfos(proxy: nil, accounts: [])
    }
    guard let value = try? JSONDecoder().decode(StoredAccountInfos.self, from: data) else {
        return StoredAccountInfos(proxy: nil, accounts: [])
    }
    return value
}
