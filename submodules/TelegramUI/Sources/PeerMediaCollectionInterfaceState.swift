import Foundation
import Postbox
import TelegramPresentationData
import ChatInterfaceState

enum PeerMediaCollectionMode: Int32 {
    case photoOrVideo
    case file
    case webpage
    case music
}

struct PeerMediaCollectionInterfaceState: Equatable {
    let peer: Peer?
    let selectionState: ChatInterfaceSelectionState?
    let mode: PeerMediaCollectionMode
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        self.peer = nil
        self.selectionState = nil
        self.mode = .photoOrVideo
    }
    
    init(peer: Peer?, selectionState: ChatInterfaceSelectionState?, mode: PeerMediaCollectionMode, theme: PresentationTheme, strings: PresentationStrings) {
        self.peer = peer
        self.selectionState = selectionState
        self.mode = mode
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
        
        if lhs.theme !== rhs.theme {
            return false
        }
        
        if lhs.strings !== rhs.strings {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedMessages(_ messageIds: [MessageId]) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for messageId in messageIds {
            selectedIds.insert(messageId)
        }
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, theme: self.theme, strings: self.strings)
    }
    
    func withToggledSelectedMessages(_ messageIds: [MessageId], value: Bool) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        for messageId in messageIds {
            if value {
                selectedIds.insert(messageId)
            } else {
                selectedIds.remove(messageId)
            }
        }
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), mode: self.mode, theme: self.theme, strings: self.strings)
    }
    
    func withSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState ?? ChatInterfaceSelectionState(selectedIds: Set()), mode: self.mode, theme: self.theme, strings: self.strings)
    }
    
    func withoutSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: nil, mode: self.mode, theme: self.theme, strings: self.strings)
    }
    
    func withUpdatedPeer(_ peer: Peer?) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: peer, selectionState: self.selectionState, mode: self.mode, theme: self.theme, strings: self.strings)
    }
    
    func withMode(_ mode: PeerMediaCollectionMode) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: mode, theme: self.theme, strings: self.strings)
    }
    
    func updatedTheme(_ theme: PresentationTheme) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: self.mode, theme: theme, strings: self.strings)
    }
    func updatedStrings(_ strings: PresentationStrings) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: self.mode, theme: self.theme, strings: strings)
    }
}
