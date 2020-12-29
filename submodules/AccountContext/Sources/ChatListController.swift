import Foundation
import UIKit
import Postbox
import Display

public protocol ChatListController: ViewController {
    var context: AccountContext { get }
    var lockViewFrame: CGRect? { get }
    
    var isSearchActive: Bool { get }
    func activateSearch(filter: ChatListSearchFilter, query: String?)
    func deactivateSearch(animated: Bool)
    func activateCompose()
    func maybeAskForPeerChatRemoval(peer: RenderedPeer, joined: Bool, deleteGloballyIfPossible: Bool, completion: @escaping (Bool) -> Void, removed: @escaping () -> Void)
}
