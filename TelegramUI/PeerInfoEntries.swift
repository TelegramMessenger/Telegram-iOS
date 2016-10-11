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
    var hashValue: Int { get }
}

struct IntPeerInfoEntryStableId: PeerInfoEntryStableId {
    let value: Int
    
    func isEqual(to: PeerInfoEntryStableId) -> Bool {
        if let to = to as? IntPeerInfoEntryStableId, to.value == self.value {
            return true
        } else {
            return false
        }
    }
    
    var hashValue: Int {
        return self.value.hashValue
    }
}

protocol PeerInfoEntry {
    var section: PeerInfoSection { get }
    var stableId: PeerInfoEntryStableId { get }
    func isEqual(to: PeerInfoEntry) -> Bool
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem
}

enum PeerInfoNavigationButton {
    case none
    case edit
    case done
}

protocol PeerInfoState {
    func isEqual(to: PeerInfoState) -> Bool
    
    var navigationButton: PeerInfoNavigationButton { get }
}

func peerInfoEntries(view: PeerView) -> [PeerInfoEntry] {
    if let user = view.peers[view.peerId] as? TelegramUser {
        return userInfoEntries(view: view)
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                return channelBroadcastInfoEntries(view: view)
            case .group:
                return groupInfoEntries(view: view)
        }
    } else if let group = view.peers[view.peerId] as? TelegramGroup {
        return groupInfoEntries(view: view)
    }
    return []
}
