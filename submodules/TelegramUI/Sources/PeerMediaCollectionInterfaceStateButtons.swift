import Foundation
import UIKit

enum PeerMediaCollectionNavigationButtonAction {
    case beginMessageSelection
    case cancelMessageSelection
}

struct PeerMediaCollectionNavigationButton: Equatable {
    let action: PeerMediaCollectionNavigationButtonAction
    let buttonItem: UIBarButtonItem
    
    static func ==(lhs: PeerMediaCollectionNavigationButton, rhs: PeerMediaCollectionNavigationButton) -> Bool {
        return lhs.action == rhs.action
    }
}

func rightNavigationButtonForPeerMediaCollectionInterfaceState(_ interfaceState: PeerMediaCollectionInterfaceState, currentButton: PeerMediaCollectionNavigationButton?, target: Any?, selector: Selector?) -> PeerMediaCollectionNavigationButton? {
    if let _ = interfaceState.selectionState {
        if let currentButton = currentButton, currentButton.action == .cancelMessageSelection {
            return currentButton
        } else {
            return PeerMediaCollectionNavigationButton(action: .cancelMessageSelection, buttonItem: UIBarButtonItem(title: interfaceState.strings.Common_Cancel, style: .plain, target: target, action: selector))
        }
    } else {
        if let currentButton = currentButton, currentButton.action == .beginMessageSelection {
            return currentButton
        } else {
            return PeerMediaCollectionNavigationButton(action: .beginMessageSelection, buttonItem: UIBarButtonItem(title: interfaceState.strings.Common_Select, style: .plain, target: target, action: selector))
        }
    }
}
