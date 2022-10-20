import Foundation
import TelegramApi

public struct AccountSessionFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let isOfficial = AccountSessionFlags(rawValue: (1 << 1))
    public static let passwordPending = AccountSessionFlags(rawValue: (1 << 2))
    public static let acceptsSecretChats = AccountSessionFlags(rawValue: (1 << 3))
    public static let acceptsIncomingCalls = AccountSessionFlags(rawValue: (1 << 4))
}

public struct RecentAccountSession: Equatable {
    public let hash: Int64
    public let deviceModel: String
    public let platform: String
    public let systemVersion: String
    public let apiId: Int32
    public let appName: String
    public let appVersion: String
    public let creationDate: Int32
    public let activityDate: Int32
    public let ip: String
    public let country: String
    public let region: String
    public let flags: AccountSessionFlags
    
    public var isCurrent: Bool {
        return self.hash == 0
    }
    
    public static func ==(lhs: RecentAccountSession, rhs: RecentAccountSession) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.deviceModel != rhs.deviceModel {
            return false
        }
        if lhs.platform != rhs.platform {
            return false
        }
        if lhs.systemVersion != rhs.systemVersion {
            return false
        }
        if lhs.apiId != rhs.apiId {
            return false
        }
        if lhs.appName != rhs.appName {
            return false
        }
        if lhs.appVersion != rhs.appVersion {
            return false
        }
        if lhs.creationDate != rhs.creationDate {
            return false
        }
        if lhs.activityDate != rhs.activityDate {
            return false
        }
        if lhs.ip != rhs.ip {
            return false
        }
        if lhs.country != rhs.country {
            return false
        }
        if lhs.region != rhs.region {
            return false
        }
        if lhs.flags != rhs.flags {
            return false
        }
        return true
    }
    
    func withUpdatedAcceptsSecretChats(_ accepts: Bool) -> RecentAccountSession {
        var flags = self.flags
        if accepts {
            flags.insert(.acceptsSecretChats)
        } else {
            flags.remove(.acceptsSecretChats)
        }
        return RecentAccountSession(hash: self.hash, deviceModel: self.deviceModel, platform: self.platform, systemVersion: self.systemVersion, apiId: self.apiId, appName: self.appName, appVersion: self.appVersion, creationDate: self.creationDate, activityDate: self.activityDate, ip: self.ip, country: self.country, region: self.region, flags: flags)
    }
    
    func withUpdatedAcceptsIncomingCalls(_ accepts: Bool) -> RecentAccountSession {
        var flags = self.flags
        if accepts {
            flags.insert(.acceptsIncomingCalls)
        } else {
            flags.remove(.acceptsIncomingCalls)
        }
        return RecentAccountSession(hash: self.hash, deviceModel: self.deviceModel, platform: self.platform, systemVersion: self.systemVersion, apiId: self.apiId, appName: self.appName, appVersion: self.appVersion, creationDate: self.creationDate, activityDate: self.activityDate, ip: self.ip, country: self.country, region: self.region, flags: flags)
    }
}

extension RecentAccountSession {
    init(apiAuthorization: Api.Authorization) {
        switch apiAuthorization {
            case let .authorization(flags, hash, deviceModel, platform, systemVersion, apiId, appName, appVersion, dateCreated, dateActive, ip, country, region):
                var accountSessionFlags: AccountSessionFlags = []
                if (flags & (1 << 1)) != 0 {
                    accountSessionFlags.insert(.isOfficial)
                }
                if (flags & (1 << 2)) != 0 {
                    accountSessionFlags.insert(.passwordPending)
                }
                if (flags & (1 << 3)) == 0 {
                    accountSessionFlags.insert(.acceptsSecretChats)
                }
                if (flags & (1 << 4)) == 0 {
                    accountSessionFlags.insert(.acceptsIncomingCalls)
                }
                self.init(hash: hash, deviceModel: deviceModel, platform: platform, systemVersion: systemVersion, apiId: apiId, appName: appName, appVersion: appVersion, creationDate: dateCreated, activityDate: dateActive, ip: ip, country: country, region: region, flags: accountSessionFlags)
        }
    }
}
