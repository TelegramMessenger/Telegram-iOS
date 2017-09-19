import Foundation

final class MutablePeerNotificationSettingsView: MutablePostboxView {
    let peerId: PeerId
    var notificationSettings: PeerNotificationSettings?
    
    init(postbox: Postbox, peerId: PeerId) {
        self.peerId = peerId
        self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if let notificationSettings = transaction.currentUpdatedPeerNotificationSettings[self.peerId] {
            self.notificationSettings = notificationSettings
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerNotificationSettingsView(self)
    }
}

public final class PeerNotificationSettingsView: PostboxView {
    public let peerId: PeerId
    public let notificationSettings: PeerNotificationSettings?
    
    init(_ view: MutablePeerNotificationSettingsView) {
        self.peerId = view.peerId
        self.notificationSettings = view.notificationSettings
    }
}

