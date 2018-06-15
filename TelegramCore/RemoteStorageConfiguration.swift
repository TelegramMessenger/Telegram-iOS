import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public final class RemoteStorageConfiguration: PreferencesEntry {
    public let webDocumentsHostDatacenterId: Int32
    
    init(webDocumentsHostDatacenterId: Int32) {
        self.webDocumentsHostDatacenterId = webDocumentsHostDatacenterId
    }
    
    public init(decoder: PostboxDecoder) {
        self.webDocumentsHostDatacenterId = decoder.decodeInt32ForKey("webDocumentsHostDatacenterId", orElse: 4)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.webDocumentsHostDatacenterId, forKey: "webDocumentsHostDatacenterId")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? RemoteStorageConfiguration else {
            return false
        }
        if self.webDocumentsHostDatacenterId != to.webDocumentsHostDatacenterId {
            return false
        }
        return true
    }
}

public func currentWebDocumentsHostDatacenterId(postbox: Postbox, isTestingEnvironment: Bool) -> Signal<Int32, NoError> {
    return postbox.transaction { transaction -> Int32 in
        if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration) as? RemoteStorageConfiguration {
            return entry.webDocumentsHostDatacenterId
        } else {
            if isTestingEnvironment {
                return 2
            } else {
                return 4
            }
        }
    }
}

func updateRemoteStorageConfiguration(transaction: Transaction, configuration: RemoteStorageConfiguration) {
    let current = transaction.getPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration) as? RemoteStorageConfiguration
    if let current = current, current.isEqual(to: configuration) {
        return
    }
    
    transaction.setPreferencesEntry(key: PreferencesKeys.remoteStorageConfiguration, value: configuration)
}
