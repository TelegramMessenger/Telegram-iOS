import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display



/*func userInfoEntries(view: PeerView, state: PeerInfoState?) -> PeerInfoEntries {
    
    
    var leftNavigationButton: PeerInfoNavigationButton?
    var rightNavigationButton: PeerInfoNavigationButton?
    if editable {
        if let state = state as? UserInfoState, let _ = state.editingState {
            leftNavigationButton = PeerInfoNavigationButton(title: "Cancel", action: { state in
                if state == nil {
                    return UserInfoState(editingState: nil)
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(nil)
                } else {
                    return state
                }
            })
            rightNavigationButton = PeerInfoNavigationButton(title: "Done", action: { state in
                if state == nil {
                    return UserInfoState(editingState: nil)
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(nil)
                } else {
                    return state
                }
            })
        } else {
            let infoEditingName: ItemListAvatarAndNameInfoItemName
            if let peer = peerViewMainPeer(view) {
                infoEditingName = ItemListAvatarAndNameInfoItemName(peer.indexName)
            } else {
                infoEditingName = .personName(firstName: "", lastName: "")
            }
            rightNavigationButton = PeerInfoNavigationButton(title: "Edit", action: { state in
                if state == nil {
                    return UserInfoState(editingState: UserInfoEditingState(editingName: infoEditingName))
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(UserInfoEditingState(editingName: infoEditingName))
                } else {
                    return state
                }
            })
        }
    }
    
    return PeerInfoEntries(entries: entries, leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
}*/
