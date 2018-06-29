import Foundation
import Display
import TelegramCore
import Postbox

public func navigateToChatController(navigationController: NavigationController, chatController: ChatController? = nil, account: Account, chatLocation: ChatLocation, messageId: MessageId? = nil, botStart: ChatControllerInitialBotStart? = nil, animated: Bool = true) {
    var found = false
    var isFirst = true
    for controller in navigationController.viewControllers.reversed() {
        if let controller = controller as? ChatController, controller.chatLocation == chatLocation {
            if let messageId = messageId {
                controller.navigateToMessage(messageLocation: .id(messageId), animated: isFirst, completion: { [weak navigationController, weak controller] in
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
        let controller: ChatController
        if let chatController = chatController {
            controller = chatController
        } else {
            controller = ChatController(account: account, chatLocation: chatLocation, messageId: messageId, botStart: botStart)
        }
        if account.telegramApplicationContext.immediateExperimentalUISettings.keepChatNavigationStack {
            navigationController.pushViewController(controller)
        } else {
            navigationController.replaceAllButRootController(controller, animated: animated)
        }
    }
}

public func isOverlayControllerForChatNotificationOverlayPresentation(_ controller: ViewController) -> Bool {
    if controller is GalleryController || controller is AvatarGalleryController || controller is ThemeGalleryController || controller is InstantPageGalleryController {
        return true
    }
    
    if controller.isNodeLoaded {
        if let backgroundColor = controller.displayNode.backgroundColor, !backgroundColor.isEqual(UIColor.clear) {
            return true
        }
    }
    
    return false
}
