
final class MutablePendingPeerNotificationSettingsView: MutablePostboxView {
    var entries: [PeerId: PeerNotificationSettings] = [:]
    
    init(postbox: PostboxImpl) {
        for peerId in postbox.pendingPeerNotificationSettingsIndexTable.getAll() {
            if let value = postbox.peerNotificationSettingsTable.getPending(peerId) {
                self.entries[peerId] = value
            } else {
                assertionFailure()
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for peerId in transaction.currentUpdatedPendingPeerNotificationSettings {
            if let value = postbox.peerNotificationSettingsTable.getPending(peerId) {
                self.entries[peerId] = value
                updated = true
            } else if self.entries[peerId] != nil {
                self.entries.removeValue(forKey: peerId)
                updated = true
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return PendingPeerNotificationSettingsView(self)
    }
}

public final class PendingPeerNotificationSettingsView: PostboxView {
    public let entries: [PeerId: PeerNotificationSettings]
    
    init(_ view: MutablePendingPeerNotificationSettingsView) {
        self.entries = view.entries
    }
}

