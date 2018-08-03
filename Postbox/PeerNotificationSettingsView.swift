import Foundation

final class MutablePeerNotificationSettingsView: MutablePostboxView {
    let peerIds: Set<PeerId>
    var notificationSettings: [PeerId: PeerNotificationSettings]
    
    init(postbox: Postbox, peerIds: Set<PeerId>) {
        self.peerIds = peerIds
        self.notificationSettings = [:]
        for peerId in peerIds {
            if let settings = postbox.peerNotificationSettingsTable.getEffective(peerId) {
                self.notificationSettings[peerId] = settings
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if !transaction.currentUpdatedPeerNotificationSettings.isEmpty {
            var updated = false
            for peerId in self.peerIds {
                if let settings = transaction.currentUpdatedPeerNotificationSettings[peerId] {
                    self.notificationSettings[peerId] = settings
                    updated = true
                }
            }
            return updated
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerNotificationSettingsView(self)
    }
}

public final class PeerNotificationSettingsView: PostboxView {
    public let peerIds: Set<PeerId>
    public let notificationSettings: [PeerId: PeerNotificationSettings]
    
    init(_ view: MutablePeerNotificationSettingsView) {
        self.peerIds = view.peerIds
        self.notificationSettings = view.notificationSettings
    }
}

