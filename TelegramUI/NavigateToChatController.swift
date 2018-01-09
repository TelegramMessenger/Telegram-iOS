import Foundation
import Display
import TelegramCore
import Postbox

public func navigateToChatController(navigationController: NavigationController, account: Account, chatLocation: ChatLocation, messageId: MessageId? = nil, animated: Bool = true) {
    var found = false
    var isFirst = true
    for controller in navigationController.viewControllers.reversed() {
        if let controller = controller as? ChatController, controller.chatLocation == chatLocation {
            if let messageId = messageId {
                controller.navigateToMessage(id: messageId, animated: isFirst, completion: { [weak navigationController, weak controller] in
                    if let navigationController = navigationController, let controller = controller {
                        let _ = navigationController.popToViewController(controller, animated: animated)
                    }
                })
            } else {
                let _ = navigationController.popToViewController(controller, animated: animated)
            }
            found = true
            break
        }
        isFirst = false
    }
    
    if !found {
        navigationController.pushViewController(ChatController(account: account, chatLocation: chatLocation, messageId: messageId))
    }
}

public func isOverlayControllerForChatNotificationOverlayPresentation(_ controller: ViewController) -> Bool {
    if controller is GalleryController || controller is AvatarGalleryController || controller is ThemeGalleryController || controller is InstantPageGalleryController {
        return true
    } else {
        return false
    }
}
