import Foundation
import UIKit
import Display
import TelegramCore

public enum ChatListControllerLocation: Equatable {
    case chatList(groupId: EngineChatList.Group)
    case forum(peerId: EnginePeer.Id)
}

public protocol ChatListController: ViewController {
    var context: AccountContext { get }
    var lockViewFrame: CGRect? { get }
    
    var isSearchActive: Bool { get }
    func activateSearch(filter: ChatListSearchFilter, query: String?)
    func deactivateSearch(animated: Bool)
    func activateCompose()
    func maybeAskForPeerChatRemoval(peer: EngineRenderedPeer, joined: Bool, deleteGloballyIfPossible: Bool, completion: @escaping (Bool) -> Void, removed: @escaping () -> Void)
    
    func playSignUpCompletedAnimation()
    
    func navigateToFolder(folderId: Int32, completion: @escaping () -> Void)
    
    func openStories(peerId: EnginePeer.Id)
    func openStoriesFromNotification(peerId: EnginePeer.Id, storyId: Int32)
}
