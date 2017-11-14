import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public final class LoggingSettings: PreferencesEntry, Equatable {
    public let logToFile: Bool
    public let logToConsole: Bool
    
    public static var defaultSettings = LoggingSettings(logToFile: false, logToConsole: false)
    
    public init(logToFile: Bool, logToConsole: Bool) {
        self.logToFile = logToFile
        self.logToConsole = logToConsole
    }
    
    public init(decoder: PostboxDecoder) {
        self.logToFile = decoder.decodeInt32ForKey("logToFile", orElse: 0) != 0
        self.logToConsole = decoder.decodeInt32ForKey("logToConsole", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.logToFile ? 1 : 0, forKey: "logToFile")
        encoder.encodeInt32(self.logToConsole ? 1 : 0, forKey: "logToConsole")
    }
    
    public func withUpdatedLogToFile(_ logToFile: Bool) -> LoggingSettings {
        return LoggingSettings(logToFile: logToFile, logToConsole: self.logToConsole)
    }
    
    public func withUpdatedLogToConsole(_ logToConsole: Bool) -> LoggingSettings {
        return LoggingSettings(logToFile: self.logToFile, logToConsole: logToConsole)
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LoggingSettings else {
            return false
        }
        
        return self == to
    }
    
    public static func ==(lhs: LoggingSettings, rhs: LoggingSettings) -> Bool {
        if lhs.logToFile != rhs.logToFile {
            return false
        }
        if lhs.logToConsole != rhs.logToConsole {
            return false
        }
        return true
    }
}

public func updateLoggingSettings(postbox: Postbox, _ f: @escaping (LoggingSettings) -> LoggingSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        var updated: LoggingSettings?
        modifier.updatePreferencesEntry(key: PreferencesKeys.loggingSettings, { current in
            if let current = current as? LoggingSettings {
                updated = f(current)
                return updated
            } else {
                updated = f(LoggingSettings.defaultSettings)
                return updated
            }
        })
        
        if let updated = updated {
            Logger.shared.logToFile = updated.logToFile
            Logger.shared.logToConsole = updated.logToConsole
        }
    }
}
