import Foundation

final class MutablePeerNotificationSettingsView: MutablePostboxView {
    let peerIds: Set<PeerId>
    var notificationSettings: [PeerId: PeerNotificationSettings]
    
    init(postbox: Postbox, peerIds: Set<PeerId>) {
        self.peerIds = peerIds
        self.notificationSettings = [:]
        for peerId in peerIds {
            var notificationPeerId = peerId
            if let peer = postbox.peerTable.get(peerId), let associatedPeerId = peer.associatedPeerId {
                notificationPeerId = associatedPeerId
            }
            if let settings = postbox.peerNotificationSettingsTable.getEffective(notificationPeerId) {
                self.notificationSettings[peerId] = settings
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if !transaction.currentUpdatedPeerNotificationSettings.isEmpty {
            var updated = false
            for peerId in self.peerIds {
                var notificationPeerId = peerId
                if let peer = postbox.peerTable.get(peerId), let associatedPeerId = peer.associatedPeerId {
                    notificationPeerId = associatedPeerId
                }
                if let (_, settings) = transaction.currentUpdatedPeerNotificationSettings[notificationPeerId] {
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

