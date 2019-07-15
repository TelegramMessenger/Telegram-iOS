import Foundation
import UIKit
import Display
import TelegramCore
import Postbox

public enum NavigateToChatKeepStack {
    case `default`
    case always
    case never
}

public func navigateToChatController(navigationController: NavigationController, chatController: ChatController? = nil, context: AccountContext, chatLocation: ChatLocation, messageId: MessageId? = nil, botStart: ChatControllerInitialBotStart? = nil, updateTextInputState: ChatTextInputState? = nil, activateInput: Bool = false, keepStack: NavigateToChatKeepStack = .default, purposefulAction: (() -> Void)? = nil, scrollToEndIfExists: Bool = false, animated: Bool = true, options: NavigationAnimationOptions = [], parentGroupId: PeerGroupId? = nil, completion: @escaping () -> Void = {}) {
    var found = false
    var isFirst = true
    for controller in navigationController.viewControllers.reversed() {
        if let controller = controller as? ChatController, controller.chatLocation == chatLocation {
            if let updateTextInputState = updateTextInputState {
                controller.updateTextInputState(updateTextInputState)
            }
            if let messageId = messageId {
                controller.navigateToMessage(messageLocation: .id(messageId), animated: isFirst, completion: { [weak navigationController, weak controller] in
                    if let navigationController = navigationController, let controller = controller {
                        let _ = navigationController.popToViewController(controller, animated: animated)
                    }
                }, customPresentProgress: { [weak navigationController] c, a in
                    (navigationController?.viewControllers.last as? ViewController)?.present(c, in: .window(.root), with: a)
                })
            } else if scrollToEndIfExists && isFirst {
                controller.scrollToEndOfHistory()
                let _ = navigationController.popToViewController(controller, animated: animated)
                completion()
            } else {
                let _ = navigationController.popToViewController(controller, animated: animated)
                completion()
            }
            controller.purposefulAction = purposefulAction
            if activateInput {
                controller.activateInput()
            }
            if let botStart = botStart {
                controller.updateChatPresentationInterfaceState(interactive: false) { state -> ChatPresentationInterfaceState in
                    return state.updatedBotStartPayload(botStart.payload)
                }
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
            if let botStart = botStart {
                controller.updateChatPresentationInterfaceState(interactive: false) { state -> ChatPresentationInterfaceState in
                    return state.updatedBotStartPayload(botStart.payload)
                }
            }
        } else {
            controller = ChatController(context: context, chatLocation: chatLocation, messageId: messageId, botStart: botStart)
        }
        controller.purposefulAction = purposefulAction
        let resolvedKeepStack: Bool
        switch keepStack {
            case .default:
                resolvedKeepStack = context.sharedContext.immediateExperimentalUISettings.keepChatNavigationStack
            case .always:
                resolvedKeepStack = true
            case .never:
                resolvedKeepStack = false
        }
        if resolvedKeepStack {
            navigationController.pushViewController(controller, animated: animated, completion: completion)
        } else {
            let viewControllers = navigationController.viewControllers.filter({ controller in
                if controller is ChatListController {
                    if let parentGroupId = parentGroupId {
                        return parentGroupId != .root
                    } else {
                        return true
                    }
                } else if controller is TabBarController {
                    return true
                } else {
                    return false
                }
            })
            if viewControllers.isEmpty {
                navigationController.replaceAllButRootController(controller, animated: animated, animationOptions: options, completion: completion)
            } else {
                navigationController.replaceControllersAndPush(controllers: viewControllers, controller: controller, animated: animated, options: options, completion: completion)
            }
        }
        if activateInput {
            controller.activateInput()
        }
    }
    
    navigationController.currentWindow?.forEachController { controller in
        if let controller = controller as? NotificationContainerController {
            controller.removeItems { item in
                if let item = item as? ChatMessageNotificationItem {
                    for message in item.messages {
                        switch chatLocation {
                            case let .peer(peerId):
                                if message.id.peerId == peerId {
                                    return true
                                }
                        }
                    }
                }
                return false
            }
        }
    }
}

private func findOpaqueLayer(rootLayer: CALayer, layer: CALayer) -> Bool {
    if layer.isHidden || layer.opacity < 0.8 {
        return false
    }
    
    if !layer.isHidden, let backgroundColor = layer.backgroundColor, backgroundColor.alpha > 0.8 {
        let coveringRect = layer.convert(layer.bounds, to: rootLayer)
        let intersection = coveringRect.intersection(rootLayer.bounds)
        let intersectionArea = intersection.width * intersection.height
        let rootArea = rootLayer.bounds.width * rootLayer.bounds.height
        if !rootArea.isZero && intersectionArea / rootArea > 0.8 {
            return true
        }
    }
    
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            if findOpaqueLayer(rootLayer: rootLayer, layer: sublayer) {
                return true
            }
        }
    }
    return false
}

public func isInlineControllerForChatNotificationOverlayPresentation(_ controller: ViewController) -> Bool {
    if controller is InstantPageController {
        return true
    }
    return false
}

public func isOverlayControllerForChatNotificationOverlayPresentation(_ controller: ContainableController) -> Bool {
    if controller is GalleryController || controller is AvatarGalleryController || controller is WallpaperGalleryController || controller is InstantPageGalleryController || controller is InstantVideoController || controller is NavigationController {
        return true
    }
    
    if controller.isViewLoaded {
        if let backgroundColor = controller.view.backgroundColor, !backgroundColor.isEqual(UIColor.clear) {
            return true
        }
        
        if findOpaqueLayer(rootLayer: controller.view.layer, layer: controller.view.layer) {
            return true
        }
    }
    
    return false
}
