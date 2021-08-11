import Postbox

public final class LoggingSettings: PreferencesEntry, Equatable {
    public let logToFile: Bool
    public let logToConsole: Bool
    public let redactSensitiveData: Bool
    
    #if DEBUG
    public static var defaultSettings = LoggingSettings(logToFile: true, logToConsole: true, redactSensitiveData: true)
    #else
    public static var defaultSettings = LoggingSettings(logToFile: false, logToConsole: false, redactSensitiveData: true)
    #endif
    
    public init(logToFile: Bool, logToConsole: Bool, redactSensitiveData: Bool) {
        self.logToFile = logToFile
        self.logToConsole = logToConsole
        self.redactSensitiveData = redactSensitiveData
    }
    
    public init(decoder: PostboxDecoder) {
        self.logToFile = decoder.decodeInt32ForKey("logToFile", orElse: 0) != 0
        self.logToConsole = decoder.decodeInt32ForKey("logToConsole", orElse: 0) != 0
        self.redactSensitiveData = decoder.decodeInt32ForKey("redactSensitiveData", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.logToFile ? 1 : 0, forKey: "logToFile")
        encoder.encodeInt32(self.logToConsole ? 1 : 0, forKey: "logToConsole")
        encoder.encodeInt32(self.redactSensitiveData ? 1 : 0, forKey: "redactSensitiveData")
    }
    
    public func withUpdatedLogToFile(_ logToFile: Bool) -> LoggingSettings {
        return LoggingSettings(logToFile: logToFile, logToConsole: self.logToConsole, redactSensitiveData: self.redactSensitiveData)
    }
    
    public func withUpdatedLogToConsole(_ logToConsole: Bool) -> LoggingSettings {
        return LoggingSettings(logToFile: self.logToFile, logToConsole: logToConsole, redactSensitiveData: self.redactSensitiveData)
    }
    
    public func withUpdatedRedactSensitiveData(_ redactSensitiveData: Bool) -> LoggingSettings {
        return LoggingSettings(logToFile: self.logToFile, logToConsole: self.logToConsole, redactSensitiveData: redactSensitiveData)
    }
    
    public static func ==(lhs: LoggingSettings, rhs: LoggingSettings) -> Bool {
        if lhs.logToFile != rhs.logToFile {
            return false
        }
        if lhs.logToConsole != rhs.logToConsole {
            return false
        }
        if lhs.redactSensitiveData != rhs.redactSensitiveData {
            return false
        }
        return true
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LoggingSettings else {
            return false
        }
        
        return self == to
    }
}
