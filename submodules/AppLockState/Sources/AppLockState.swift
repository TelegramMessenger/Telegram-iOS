import Foundation
import MonotonicTime

public struct PreciseTime: Codable, Equatable {
    public let sec: Int64
    public let usec: Int32
    
    public init(sec: Int64, usec: Int32) {
        self.sec = sec
        self.usec = usec
    }
    
    public func absDiff(with other: PreciseTime) -> Double {
        return abs(Double(self.sec - other.sec) + Double(self.usec - other.usec) / 1_000_000.0)
    }
}

public struct MonotonicTimestamp: Codable, Equatable {
    public var bootTimestamp: PreciseTime
    public var uptime: Int32

    public init() {
        var bootTimestamp = timeval()
        self.uptime = getDeviceUptimeSeconds(&bootTimestamp)
        self.bootTimestamp = PreciseTime(sec: Int64(bootTimestamp.tv_sec), usec: bootTimestamp.tv_usec)
    }
}

public struct UnlockAttempts: Codable, Equatable {
    public var count: Int32
    public var timestamp: MonotonicTimestamp

    public init(count: Int32, timestamp: MonotonicTimestamp) {
        self.count = count
        self.timestamp = timestamp
    }
}

public struct LockState: Codable, Equatable {
    public var isLocked: Bool
    public var autolockTimeout: Int32?
    public var unlockAttempts: UnlockAttempts?
    public var applicationActivityTimestamp: MonotonicTimestamp?

    public init(isLocked: Bool = false, autolockTimeout: Int32? = nil, unlockAttemts: UnlockAttempts? = nil, applicationActivityTimestamp: MonotonicTimestamp? = nil) {
        self.isLocked = isLocked
        self.autolockTimeout = autolockTimeout
        self.unlockAttempts = unlockAttemts
        self.applicationActivityTimestamp = applicationActivityTimestamp
    }
}

public func appLockStatePath(rootPath: String) -> String {
    return rootPath + "/lockState.json"
}

public func isAppLocked(state: LockState) -> Bool {
    if state.isLocked {
        return true
    } else if let autolockTimeout = state.autolockTimeout {
        let timestamp = MonotonicTimestamp()
        
        if let applicationActivityTimestamp = state.applicationActivityTimestamp {
            if timestamp.bootTimestamp.absDiff(with: applicationActivityTimestamp.bootTimestamp) > 0.1 {
                return true
            }
            if timestamp.uptime < applicationActivityTimestamp.uptime {
                return true
            }
            if timestamp.uptime >= applicationActivityTimestamp.uptime + autolockTimeout {
                return true
            }
        } else {
            return true
        }
    }
    return false
}
