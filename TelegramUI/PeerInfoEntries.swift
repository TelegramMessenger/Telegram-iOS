import Foundation
import Postbox
import TelegramCore
import Display

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
    var section: ItemListSectionId { get }
    var stableId: PeerInfoEntryStableId { get }
    func isEqual(to: PeerInfoEntry) -> Bool
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem
}

struct PeerInfoNavigationButton {
    let title: String
    let action: (PeerInfoState?) -> PeerInfoState?
}

protocol PeerInfoState {
    func isEqual(to: PeerInfoState) -> Bool
}

struct PeerInfoEntries {
    let entries: [PeerInfoEntry]
    let leftNavigationButton: PeerInfoNavigationButton?
    let rightNavigationButton: PeerInfoNavigationButton?
}

func peerInfoEntries(view: PeerView, state: PeerInfoState?) -> PeerInfoEntries {
    /*if let user = view.peers[view.peerId] as? TelegramUser {
        return userInfoEntries(view: view, state: state)
    } else if let secretChat = view.peers[view.peerId] as? TelegramSecretChat {
        return userInfoEntries(view: view, state: state)
    } else if let channel = view.peers[view.peerId] as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                return channelBroadcastInfoEntries(view: view)
            case .group:
                return groupInfoEntries(view: view, state: state)
        }
    } else if let group = view.peers[view.peerId] as? TelegramGroup {
        return groupInfoEntries(view: view, state: state)
    }*/
    return PeerInfoEntries(entries: [], leftNavigationButton: nil, rightNavigationButton: nil)
}
