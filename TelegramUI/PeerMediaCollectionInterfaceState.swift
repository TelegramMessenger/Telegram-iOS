import Foundation
import Postbox

enum PeerMediaCollectionMode: Int32 {
    case photoOrVideo
    case file
    case webpage
    case music
}

func titleForPeerMediaCollectionMode(_ mode: PeerMediaCollectionMode, strings: PresentationStrings) -> String {
    switch mode {
        case .photoOrVideo:
            return strings.SharedMedia_TitleAll
        case .file:
            return strings.SharedMedia_TitleFile
        case .music:
            return strings.SharedMedia_TitleAudio
        case .webpage:
            return strings.SharedMedia_TitleLink
    }
}

struct PeerMediaCollectionInterfaceState: Equatable {
    let peer: Peer?
    let selectionState: ChatInterfaceSelectionState?
    let mode: PeerMediaCollectionMode
    let selectingMode: Bool
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        self.peer = nil
        self.selectionState = nil
        self.mode = .photoOrVideo
        self.selectingMode = false
    }
    
    init(peer: Peer?, selectionState: ChatInterfaceSelectionState?, mode: PeerMediaCollectionMode, selectingMode: Bool, theme: PresentationTheme, strings: PresentationStrings) {
        self.peer = peer
        self.selectionState = selectionState
        self.mode = mode
        self.selectingMode = selectingMode
        self.theme = theme
        self.strings = strings
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
        
        if lhs.theme !== rhs.theme {
            return false
        }
        
        if lhs.strings !== rhs.strings {
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
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
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
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
    }
    
    func withSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState ?? ChatInterfaceSelectionState(selectedIds: Set()), mode: self.mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
    }
    
    func withoutSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: nil, mode: self.mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
    }
    
    func withUpdatedPeer(_ peer: Peer?) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: peer, selectionState: self.selectionState, mode: self.mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
    }
    
    func withToggledSelectingMode() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: self.mode, selectingMode: !self.selectingMode, theme: self.theme, strings: self.strings)
    }
    
    func withMode(_ mode: PeerMediaCollectionMode) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: mode, selectingMode: self.selectingMode, theme: self.theme, strings: self.strings)
    }
}
