import Foundation
import Postbox
import TelegramCore
import Display

protocol PeerInfoSection {
    var rawValue: UInt32 { get }
    func isEqual(to: PeerInfoSection) -> Bool
    func isOrderedBefore(_ section: PeerInfoSection) -> Bool
}

protocol PeerInfoEntryStableId {
    func isEqual(to: PeerInfoEntryStableId) -> Bool
}

protocol PeerInfoEntry {
    var section: PeerInfoSection { get }
    var stableId: Int { get }
    func isEqual(to: PeerInfoEntry) -> Bool
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem
}

func peerInfoEntries(view: PeerView) -> [PeerInfoEntry] {
    if let user = view.peers[view.peerId] as? TelegramUser {
        return userInfoEntries(view: view)
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                return channelBroadcastInfoEntries(view: view)
            case .group:
                return []
        }
    } else if let group = view.peers[view.peerId] as? TelegramGroup {
        return groupInfoEntries(view: view)
    }
    return []
}
