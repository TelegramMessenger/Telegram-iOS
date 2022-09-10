import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences

public struct PtgSettings: Codable, Equatable {
    public let showPeerId: Bool
    public let suppressForeignAgentNotice: Bool
    public let enableForeignAgentNoticeSearchFiltering: Bool // makes sense only if suppressForeignAgentNotice is true
    
    public static var defaultSettings: PtgSettings {
        return PtgSettings(showPeerId: true, suppressForeignAgentNotice: true, enableForeignAgentNoticeSearchFiltering: true)
    }
    
    public var effectiveEnableForeignAgentNoticeSearchFiltering: Bool {
        return self.suppressForeignAgentNotice && self.enableForeignAgentNoticeSearchFiltering
    }
    
    public init(showPeerId: Bool, suppressForeignAgentNotice: Bool, enableForeignAgentNoticeSearchFiltering: Bool) {
        self.showPeerId = showPeerId
        self.suppressForeignAgentNotice = suppressForeignAgentNotice
        self.enableForeignAgentNoticeSearchFiltering = enableForeignAgentNoticeSearchFiltering
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.showPeerId = (try container.decodeIfPresent(Int32.self, forKey: "spi") ?? 1) != 0
        self.suppressForeignAgentNotice = (try container.decodeIfPresent(Int32.self, forKey: "sfan") ?? 1) != 0
        self.enableForeignAgentNoticeSearchFiltering = (try container.decodeIfPresent(Int32.self, forKey: "efansf") ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.showPeerId ? 1 : 0) as Int32, forKey: "spi")
        try container.encode((self.suppressForeignAgentNotice ? 1 : 0) as Int32, forKey: "sfan")
        try container.encode((self.enableForeignAgentNoticeSearchFiltering ? 1 : 0) as Int32, forKey: "efansf")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgSettings.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.ptgSettings)
        self.init(entry)
    }
    
    public func withUpdated(showPeerId: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering)
    }
    
    public func withUpdated(suppressForeignAgentNotice: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: self.enableForeignAgentNoticeSearchFiltering)
    }
    
    public func withUpdated(enableForeignAgentNoticeSearchFiltering: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, suppressForeignAgentNotice: self.suppressForeignAgentNotice, enableForeignAgentNoticeSearchFiltering: enableForeignAgentNoticeSearchFiltering)
    }
}
