import Foundation
import Display
import TelegramCore
import Postbox

func navigateToChatController(navigationController: NavigationController, account: Account, peerId: PeerId) {
    var found = false
    for controller in navigationController.viewControllers {
        if let controller = controller as? ChatController, controller.peerId == peerId {
            navigationController.popToViewController(controller, animated: true)
            found = true
            break
        }
    }
    
    if !found {
        navigationController.pushViewController(ChatController(account: account, peerId: peerId))
    }
}
