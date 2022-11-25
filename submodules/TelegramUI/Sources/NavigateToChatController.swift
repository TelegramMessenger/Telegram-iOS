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
import AttachmentUI
import ForumCreateTopicScreen

public func navigateToChatControllerImpl(_ params: NavigateToChatControllerParams) {
    if case let .peer(peer) = params.chatLocation, case let .channel(channel) = peer, channel.flags.contains(.isForum) {
        for controller in params.navigationController.viewControllers.reversed() {
            if let controller = controller as? ChatListControllerImpl, case let .forum(peerId) = controller.location, peer.id == peerId {
                let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                if let activateMessageSearch = params.activateMessageSearch {
                    controller.activateSearch(query: activateMessageSearch.1)
                }
                return
            }
        }
        
        let controller = ChatListControllerImpl(context: params.context, location: .forum(peerId: peer.id), controlsHistoryPreload: false, enableDebugActions: false)
        
        let activateMessageSearch = params.activateMessageSearch
        params.navigationController.pushViewController(controller, completion: { [weak controller] in
            guard let controller, let activateMessageSearch else {
                return
            }
            controller.activateSearch(query: activateMessageSearch.1)
        })
        
        return
    }
    
    var found = false
    var isFirst = true
    if params.useExisting {
        for controller in params.navigationController.viewControllers.reversed() {
            if let controller = controller as? ChatControllerImpl, controller.chatLocation == params.chatLocation.asChatLocation && (controller.subject != .scheduledMessages || controller.subject == params.subject) {
                if let updateTextInputState = params.updateTextInputState {
                    controller.updateTextInputState(updateTextInputState)
                }
                var popAndComplete = true
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
                    popAndComplete = false
                } else if params.scrollToEndIfExists && isFirst {
                    controller.scrollToEndOfHistory()
                } else if let search = params.activateMessageSearch {
                    controller.activateSearch(domain: search.0, query: search.1)
                } else if let reportReason = params.reportReason {
                    controller.beginReportSelection(reason: reportReason)
                }
                
                if popAndComplete {
                    if let _ = params.navigationController.viewControllers.last as? AttachmentController, let controller = params.navigationController.viewControllers[params.navigationController.viewControllers.count - 2] as? ChatControllerImpl, controller.chatLocation == params.chatLocation.asChatLocation {
                        
                    } else {
                        let _ = params.navigationController.popToViewController(controller, animated: params.animated)
                    }
                    params.completion(controller)
                }
                
                controller.purposefulAction = params.purposefulAction
                if let activateInput = params.activateInput {
                    controller.activateInput(type: activateInput)
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
                    controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload, justInstalled: attachBotStart.justInstalled)
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
                controller.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload, justInstalled: attachBotStart.justInstalled)
            }
        } else {
            controller = ChatControllerImpl(context: params.context, chatLocation: params.chatLocation.asChatLocation, chatLocationContextHolder: params.chatLocationContextHolder, subject: params.subject, botStart: params.botStart, attachBotStart: params.attachBotStart, peekData: params.peekData, peerNearbyData: params.peerNearbyData, chatListFilter: params.chatListFilter, chatNavigationStack: params.chatNavigationStack)
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
                if controller is ForumCreateTopicScreen {
                    return false
                }
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
        if let activateInput = params.activateInput {
            controller.activateInput(type: activateInput)
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
                        case let .peer(peer):
                            if message.id.peerId == peer.id {
                                return true
                            }
                        case let .replyThread(replyThreadMessage):
                            if message.id.peerId == replyThreadMessage.messageId.peerId {
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

public func navigateToForumThreadImpl(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, messageId: EngineMessage.Id?, navigationController: NavigationController, activateInput: ChatControllerActivateInput?, keepStack: NavigateToChatKeepStack) -> Signal<Never, NoError> {
    return fetchAndPreloadReplyThreadInfo(context: context, subject: .groupMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))), atMessageId: messageId, preload: false)
    |> deliverOnMainQueue
    |> beforeNext { [weak context, weak navigationController] result in
        guard let context = context, let navigationController = navigationController else {
            return
        }
        
        var actualActivateInput: ChatControllerActivateInput? = result.isEmpty ? .text : nil
        if let activateInput = activateInput {
            actualActivateInput = activateInput
        }
        
        context.sharedContext.navigateToChatController(
            NavigateToChatControllerParams(
                navigationController: navigationController,
                context: context,
                chatLocation: .replyThread(result.message),
                chatLocationContextHolder: result.contextHolder,
                subject: messageId.flatMap { .message(id: .id($0), highlight: true, timecode: nil) },
                activateInput: actualActivateInput,
                keepStack: keepStack
            )
        )
    }
    |> ignoreValues
    |> `catch` { _ -> Signal<Never, NoError> in
        return .complete()
    }
}

public func chatControllerForForumThreadImpl(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64) -> Signal<ChatController, NoError> {
    return fetchAndPreloadReplyThreadInfo(context: context, subject: .groupMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))), atMessageId: nil, preload: false)
    |> deliverOnMainQueue
    |> `catch` { _ -> Signal<ReplyThreadInfo, NoError> in
        return .complete()
    }
    |> map { result in
        return ChatControllerImpl(
            context: context,
            chatLocation: .replyThread(message: result.message),
            chatLocationContextHolder: result.contextHolder
        )
    }
}

public func navigateToForumChannelImpl(context: AccountContext, peerId: EnginePeer.Id, navigationController: NavigationController) {
    let controller = ChatListControllerImpl(context: context, location: .forum(peerId: peerId), controlsHistoryPreload: false, enableDebugActions: false)
    controller.navigationPresentation = .master
    navigationController.pushViewController(controller)
}
