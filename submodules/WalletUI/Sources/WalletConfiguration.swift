import Foundation
import TelegramCore

public struct WalletConfiguration {
    static var defaultValue: WalletConfiguration {
        return WalletConfiguration(config: nil, blockchainName: nil, disableProxy: false)
    }
    
    public let config: String?
    public let blockchainName: String?
    public let disableProxy: Bool
    
    fileprivate init(config: String?, blockchainName: String?, disableProxy: Bool) {
        self.config = config
        self.blockchainName = blockchainName
        self.disableProxy = disableProxy
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String, let blockchainName = data["wallet_blockchain_name"] as? String {
            var disableProxy = false
            if let value = data["wallet_disable_proxy"] as? String {
                disableProxy = value != "0"
            } else if let value = data["wallet_disable_proxy"] as? Int {
                disableProxy = value != 0
            }
            return WalletConfiguration(config: config, blockchainName: blockchainName, disableProxy: disableProxy)
        } else {
            return .defaultValue
        }
    }
}
