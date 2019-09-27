import Foundation
import TelegramCore

public struct WalletConfiguration {
    static var defaultValue: WalletConfiguration {
        return WalletConfiguration(config: nil)
    }
    
    public let config: String?
    
    fileprivate init(config: String?) {
        self.config = config
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String {
            return WalletConfiguration(config: config)
        } else {
            return .defaultValue
        }
    }
}
