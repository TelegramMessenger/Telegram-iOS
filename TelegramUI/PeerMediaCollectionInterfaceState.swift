import Foundation
import Postbox

enum PeerMediaCollectionMode {
    case photoOrVideo
    case file
    case music
    case webpage
}

func titleForPeerMediaCollectionMode(_ mode: PeerMediaCollectionMode) -> String {
    switch mode {
        case .photoOrVideo:
            return "Shared Media"
        case .file:
            return "Shared Files"
        case .music:
            return "Shared Music"
        case .webpage:
            return "Shared Links"
    }
}

struct PeerMediaCollectionInterfaceState: Equatable {
    let peer: Peer?
    let selectionState: ChatInterfaceSelectionState?
    let mode: PeerMediaCollectionMode
    let selectingMode: Bool
    
    init() {
        self.peer = nil
        self.selectionState = nil
        self.mode = .photoOrVideo
        self.selectingMode = false
    }
    
    init(peer: Peer?, selectionState: ChatInterfaceSelectionState?, mode: PeerMediaCollectionMode, selectingMode: Bool) {
        self.peer = peer
        self.selectionState = selectionState
        self.mode = mode
        self.selectingMode = selectingMode
    }
    
    static func ==(lhs: PeerMediaCollectionInterfaceState, rhs: PeerMediaCollectionInterfaceState) -> Bool {
        if let peer = lhs.peer {
            if rhs.peer == nil || !peer.isEqual(rhs.peer!) {
                return false
            }
        } else if let _ = rhs.peer {
            return false
        }
        
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        
        if lhs.mode != rhs.mode {
            return false
        }
        
        if lhs.selectingMode != rhs.selectingMode {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.contains(messageId) {
            let _ = selectedIds.remove(messageId)
        } else {
            selectedIds.insert(messageId)
        }
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState ?? ChatInterfaceSelectionState(selectedIds: Set()), mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withoutSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: nil, mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withUpdatedPeer(_ peer: Peer?) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: peer, selectionState: self.selectionState, mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withToggledSelectingMode() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: self.mode, selectingMode: !self.selectingMode)
    }
    
    func withMode(_ mode: PeerMediaCollectionMode) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: mode, selectingMode: self.selectingMode)
    }
}
