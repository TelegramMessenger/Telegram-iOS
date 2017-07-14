import Foundation

import TelegramCorePrivateModule

public struct MonotonicTime {
    public func getBootTimestamp() -> Int64 {
        return MonotonicGetBootTimestamp()
    }
    
    public func getUptime() -> Int64 {
        return MonotonicGetUptime()
    }
}
