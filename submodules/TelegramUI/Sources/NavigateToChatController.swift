import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import GalleryUI
import InstantPageUI
import ChatListUI
import PeerAvatarGalleryUI
import SettingsUI
import ChatPresentationInterfaceState

public func navigateToChatControllerImpl(_ params: NavigateToChatControllerParams) {
    var found = false
    var isFirst = true
    if params.useExisting {
        for controller in params.navigationController.viewControllers.reversed() {
            if let controller = controller as? ChatControllerImpl, controller.chatLocation == params.chatLocation && (controller.subject != .scheduledMessages || controller.subject == params.subject) {
                if let updateTextInputState = params.updateTextInputState {
                    controller.updateTextInputState(updateTextInputState)
                }
                if let subject = params.subject, case let .message(messageSubject, _, timecode) = subject {
                    if case let .id(messageId) = messageSubject {
                        let navigationController = params.navigationController
                        let animated = params.animated
                        controller.navigateToMessage(messageLocation: .id(messageId, timecode), animated: isFirst, completion: { [weak navigationController, weak controller] in
                            if let navigationController = navigationController, let controller = controller {
                                let _ = navigationController.popToViewController(controller, animated: animated)
                            }
                        }, customPresentProgress: { [weak navigationController] c, a in
                            (navigationController?.viewControllers.last as? ViewController)?.present(c, in: .window(.root), with: a)
                        })
                    }
                } else if params.scrollToEndIfExists && isFirst {
                    controller.scrollToEndOfHistory()
                    let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                    params.completion(controller)
                } else if let search = params.activateMessageSearch {
                    controller.activateSearch(domain: search.0, query: search.1)
                    let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                    params.completion(controller)
                } else if let reportReason = params.reportReason {
                    controller.beginReportSelection(reason: reportReason)
                    let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                    params.completion(controller)
                } else {
                    let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                    params.completion(controller)
                }
                controller.purposefulAction = params.purposefulAction
                if params.activateInput {
                    controller.activateInput()
                }
                if params.changeColors {
                    controller.presentThemeSelection()
                }
                if let botStart = params.botStart {
                    controller.updateChatPresentationInterfaceState(interactive: false, { state -> ChatPresentationInterfaceState in
                        return state.updatedBotStartPayload(botStart.payload)
                    })
                }
                if let attachBotStart = params.attachBotStart {
                    controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload)
                }
                params.setupController(controller)
                found = true
                break
            }
            isFirst = false
        }
    }
    if !found {
        let controller: ChatControllerImpl
        if let chatController = params.chatController as? ChatControllerImpl {
            controller = chatController
            if let botStart = params.botStart {
                controller.updateChatPresentationInterfaceState(interactive: false, { state -> ChatPresentationInterfaceState in
                    return state.updatedBotStartPayload(botStart.payload)
                })
            }
            if let attachBotStart = params.attachBotStart {
                controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload)
            }
        } else {
            controller = ChatControllerImpl(context: params.context, chatLocation: params.chatLocation, chatLocationContextHolder: params.chatLocationContextHolder, subject: params.subject, botStart: params.botStart, attachBotStart: params.attachBotStart, peekData: params.peekData, peerNearbyData: params.peerNearbyData, chatListFilter: params.chatListFilter, chatNavigationStack: params.chatNavigationStack)
        }
        controller.purposefulAction = params.purposefulAction
        if let search = params.activateMessageSearch {
            controller.activateSearch(domain: search.0, query: search.1)
        }
        let resolvedKeepStack: Bool
        switch params.keepStack {
            case .default:
                resolvedKeepStack = params.context.sharedContext.immediateExperimentalUISettings.keepChatNavigationStack
            case .always:
                resolvedKeepStack = true
            case .never:
                resolvedKeepStack = false
        }
        if resolvedKeepStack {
            params.navigationController.pushViewController(controller, animated: params.animated, completion: {
                params.completion(controller)
            })
        } else {
            let viewControllers = params.navigationController.viewControllers.filter({ controller in
                if controller is ChatListController {
                    if let parentGroupId = params.parentGroupId {
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
                params.navigationController.replaceAllButRootController(controller, animated: params.animated, animationOptions: params.options, completion: {
                    params.completion(controller)
                })
            } else {
                if params.useBackAnimation {
                    params.navigationController.viewControllers = [controller] + params.navigationController.viewControllers
                    params.navigationController.replaceControllers(controllers: viewControllers + [controller], animated: params.animated, options: params.options, completion: {
                        params.completion(controller)
                    })
                } else {
                    params.navigationController.replaceControllersAndPush(controllers: viewControllers, controller: controller, animated: params.animated, options: params.options, completion: {
                        params.completion(controller)
                    })
                }
            }
        }
        if params.activateInput {
            controller.activateInput()
        }
        if params.changeColors {
            Queue.mainQueue().after(0.1) {
                controller.presentThemeSelection()
            }
        }
    }
    
    params.navigationController.currentWindow?.forEachController { controller in
        if let controller = controller as? NotificationContainerController {
            controller.removeItems { item in
                if let item = item as? ChatMessageNotificationItem {
                    for message in item.messages {
                        switch params.chatLocation {
                        case let .peer(peerId):
                            if message.id.peerId == peerId {
                                return true
                            }
                        case let .replyThread(replyThreadMessage):
                            if message.id.peerId == replyThreadMessage.messageId.peerId {
                                return true
                            }
                        case .feed:
                            break
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
