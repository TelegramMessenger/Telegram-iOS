import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Resources {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func preUpload(id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<MediaResourceData, NoError>, onComplete: (()->Void)? = nil) {
            return self.account.messageMediaPreuploadManager.add(network: self.account.network, postbox: self.account.postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete)
        }

        public func collectCacheUsageStats(peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
            return _internal_collectCacheUsageStats(account: self.account, peerId: peerId, additionalCachePaths: additionalCachePaths, logFilesPath: logFilesPath)
        }

        public func clearCachedMediaResources(mediaResourceIds: Set<WrappedMediaResourceId>) -> Signal<Void, NoError> {
            return _internal_clearCachedMediaResources(account: self.account, mediaResourceIds: mediaResourceIds)
        }
    }
}
