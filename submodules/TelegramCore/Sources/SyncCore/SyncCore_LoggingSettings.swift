import Postbox

public final class LoggingSettings: Codable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.logToFile = ((try? container.decode(Int32.self, forKey: "logToFile")) ?? 0) != 0
        self.logToConsole = ((try? container.decode(Int32.self, forKey: "logToConsole")) ?? 0) != 0
        self.redactSensitiveData = ((try? container.decode(Int32.self, forKey: "redactSensitiveData")) ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.logToFile ? 1 : 0) as Int32, forKey: "logToFile")
        try container.encode((self.logToConsole ? 1 : 0) as Int32, forKey: "logToConsole")
        try container.encode((self.redactSensitiveData ? 1 : 0) as Int32, forKey: "redactSensitiveData")
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
}
