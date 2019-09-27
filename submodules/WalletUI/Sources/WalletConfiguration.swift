import Foundation
import TelegramCore

public struct WalletConfiguration {
    static var defaultValue: WalletConfiguration {
        return WalletConfiguration(enabled: false)
    }
    
    public let enabled: Bool
    
    fileprivate init(enabled: Bool) {
        self.enabled = enabled
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let enabled = data["wallet_enabled"] as? Bool, let _ = data["wallet_config"] as? String {
            return WalletConfiguration(enabled: enabled)
        } else {
            return .defaultValue
        }
    }
    
    public static func config(appConfiguration: AppConfiguration) -> String? {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String {
            return config
        } else {
            return nil
        }
    }
}
