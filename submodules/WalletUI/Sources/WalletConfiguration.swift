import Foundation
import TelegramCore

public struct WalletConfiguration {
    static var defaultValue: WalletConfiguration {
        return WalletConfiguration(config: nil, blockchainName: nil)
    }
    
    public let config: String?
    public let blockchainName: String?
    
    fileprivate init(config: String?, blockchainName: String?) {
        self.config = config
        self.blockchainName = blockchainName
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String, let blockchainName = data["wallet_blockchain_name"] as? String {
            return WalletConfiguration(config: config, blockchainName: blockchainName)
        } else {
            return .defaultValue
        }
    }
}
