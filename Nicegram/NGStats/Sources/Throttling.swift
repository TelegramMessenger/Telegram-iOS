import Foundation
import NGRemoteConfig
import Postbox

class ChatStatsThrottlingService {
    
    //  MARK: - Dependencies
    
    private let remoteConfig = RemoteConfigServiceImpl.shared
    private let metaStorage = ChatStatsMetaStorage()
    
    //  MARK: - Lifecycle
    
    init() {
        metaStorage.removeItems { !self.shouldSkipShare(sharedAt: $0) }
    }
    
    //  MARK: - Public Functions
    
    func shouldSkipShare(peerId: PeerId) -> Bool {
        let peerId = peerId.id._internalGetInt64Value()
        
        let sharedAt = metaStorage.getSharedAt(peerId: peerId)
        return shouldSkipShare(sharedAt: sharedAt)
    }
    
    func markAsShared(peerId: PeerId) {
        let peerId = peerId.id._internalGetInt64Value()
        
        metaStorage.setSharedAt(Date(), peerId: peerId)
    }

    //  MARK: - Private Functions

    private func getShareChannelsConfig() -> ShareChannelsConfig {
        let remoteValue = RemoteConfigServiceImpl.shared.get(ShareChannelsConfig.self, byKey: "shareChannelsConfig")
        let defaultValue = ShareChannelsConfig(throttlingInterval: 86400)
        return remoteValue ?? defaultValue
    }
    
    private func shouldSkipShare(sharedAt: Date?) -> Bool {
        let sharedAt = sharedAt ?? .distantPast
        let currentDate = Date()
        let throttlingInterval = getShareChannelsConfig().throttlingInterval
        
        return (sharedAt.addingTimeInterval(throttlingInterval) > currentDate)
    }

}

private struct ShareChannelsConfig: Decodable {
    let throttlingInterval: TimeInterval
}
