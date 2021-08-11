import Foundation
import Postbox

public struct WalletCollectionItem: Equatable, PostboxCoding {
    public let info: Data
    public var exportCompleted: Bool
    public var state: Data?
    
    public init(info: Data, exportCompleted: Bool, state: Data?) {
        self.info = info
        self.exportCompleted = exportCompleted
        self.state = state
    }
    
    public init(decoder: PostboxDecoder) {
        self.info = decoder.decodeDataForKey("info") ?? Data()
        self.exportCompleted = decoder.decodeInt32ForKey("exportCompleted", orElse: 0) != 0
        self.state = decoder.decodeDataForKey("state")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeData(self.info, forKey: "info")
        encoder.encodeInt32(self.exportCompleted ? 1 : 0, forKey: "exportCompleted")
        if let state = self.state {
            encoder.encodeData(state, forKey: "state")
        } else {
            encoder.encodeNil(forKey: "state")
        }
    }
}

public struct WalletCollection: PreferencesEntry {
    public var wallets: [WalletCollectionItem]
    
    public init(wallets: [WalletCollectionItem]) {
        self.wallets = wallets
    }
    
    public init(decoder: PostboxDecoder) {
        self.wallets = decoder.decodeObjectArrayWithDecoderForKey("wallets")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.wallets, forKey: "wallets")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let other = to as? WalletCollection else {
            return false
        }
        if self.wallets != other.wallets {
            return false
        }
        return true
    }
}
