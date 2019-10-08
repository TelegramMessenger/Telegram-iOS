import Foundation

public struct WalletConfiguration {
    public static var defaultValue: WalletConfiguration {
        return WalletConfiguration(config: nil, blockchainName: nil, disableProxy: false)
    }
    
    public let config: String?
    public let blockchainName: String?
    public let disableProxy: Bool
    
    public init(config: String?, blockchainName: String?, disableProxy: Bool) {
        self.config = config
        self.blockchainName = blockchainName
        self.disableProxy = disableProxy
    }
}
