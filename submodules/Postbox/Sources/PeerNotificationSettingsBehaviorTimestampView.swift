import Foundation

final class MutablePeerNotificationSettingsBehaviorTimestampView: MutablePostboxView {
    fileprivate var earliestTimestamp: Int32?
    
    init(postbox: PostboxImpl) {
        self.earliestTimestamp = postbox.peerNotificationSettingsBehaviorTable.getEarliest()?.1
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.currentUpdatedPeerNotificationBehaviorTimestamps.isEmpty {
            let earliestTimestamp = postbox.peerNotificationSettingsBehaviorTable.getEarliest()?.1
            if self.earliestTimestamp != earliestTimestamp {
                self.earliestTimestamp = earliestTimestamp
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*let earliestTimestamp = postbox.peerNotificationSettingsBehaviorTable.getEarliest()?.1
        if self.earliestTimestamp != earliestTimestamp {
            self.earliestTimestamp = earliestTimestamp
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return PeerNotificationSettingsBehaviorTimestampView(self)
    }
}

public final class PeerNotificationSettingsBehaviorTimestampView: PostboxView {
    public let earliestTimestamp: Int32?
    
    init(_ view: MutablePeerNotificationSettingsBehaviorTimestampView) {
        self.earliestTimestamp = view.earliestTimestamp
    }
}
