import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

public struct CloudballonSettings: Codable, Equatable {
    public let showPeerId: Bool
    
    public static var defaultSettings: CloudballonSettings {
        return CloudballonSettings(showPeerId: true)
    }
    
    public init(showPeerId: Bool) {
        self.showPeerId = showPeerId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.showPeerId = (try container.decodeIfPresent(Int32.self, forKey: "spi") ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.showPeerId ? 1 : 0) as Int32, forKey: "spi")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(CloudballonSettings.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.cloudballonSettings)
        self.init(entry)
    }
    
    public func withUpdatedShowPeerId(_ showPeerId: Bool) -> CloudballonSettings {
        return CloudballonSettings(showPeerId: showPeerId)
    }
}

public func updateCloudballonSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (CloudballonSettings) -> CloudballonSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateCloudballonSettingsInternal(transaction: transaction, f)
    }
}

public func updateCloudballonSettingsInternal(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (CloudballonSettings) -> CloudballonSettings) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.cloudballonSettings, { entry in
        let currentSettings = CloudballonSettings(entry)
        return PreferencesEntry(f(currentSettings))
    })
}
