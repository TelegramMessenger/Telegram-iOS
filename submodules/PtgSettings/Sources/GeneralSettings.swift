import Foundation
import Postbox
import TelegramCore

extension ApplicationSpecificSharedDataKeys {
    public static let ptgSettings = applicationSpecificPreferencesKey(102)
}

public struct PtgSettings: Codable, Equatable {
    public let showPeerId: Bool
    public let showChannelCreationDate: Bool
    public let suppressForeignAgentNotice: Bool
    public let preferAppleVoiceToText: Bool
    public let testToolsEnabled: Bool?
    
    public static var defaultSettings: PtgSettings {
        return PtgSettings(showPeerId: true, showChannelCreationDate: true, suppressForeignAgentNotice: true, preferAppleVoiceToText: false, testToolsEnabled: nil)
    }
    
    public init(showPeerId: Bool, showChannelCreationDate: Bool, suppressForeignAgentNotice: Bool, preferAppleVoiceToText: Bool, testToolsEnabled: Bool?) {
        self.showPeerId = showPeerId
        self.showChannelCreationDate = showChannelCreationDate
        self.suppressForeignAgentNotice = suppressForeignAgentNotice
        self.preferAppleVoiceToText = preferAppleVoiceToText
        self.testToolsEnabled = testToolsEnabled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.showPeerId = (try container.decodeIfPresent(Int32.self, forKey: "spi") ?? 1) != 0
        self.showChannelCreationDate = (try container.decodeIfPresent(Int32.self, forKey: "sccd") ?? 1) != 0
        self.suppressForeignAgentNotice = (try container.decodeIfPresent(Int32.self, forKey: "sfan") ?? 1) != 0
        self.preferAppleVoiceToText = (try container.decodeIfPresent(Int32.self, forKey: "pavtt") ?? 0) != 0
        self.testToolsEnabled = try container.decodeIfPresent(Int32.self, forKey: "test").flatMap({ $0 != 0 })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.showPeerId ? 1 : 0) as Int32, forKey: "spi")
        try container.encode((self.showChannelCreationDate ? 1 : 0) as Int32, forKey: "sccd")
        try container.encode((self.suppressForeignAgentNotice ? 1 : 0) as Int32, forKey: "sfan")
        try container.encode((self.preferAppleVoiceToText ? 1 : 0) as Int32, forKey: "pavtt")
        try container.encodeIfPresent(self.testToolsEnabled.flatMap({ ($0 ? 1 : 0) as Int32 }), forKey: "test")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgSettings.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.ptgSettings)
        self.init(entry)
    }
}
