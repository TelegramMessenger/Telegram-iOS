import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import ChatPresentationInterfaceState
import ChatControllerInteraction
import WebUI
import AttachmentUI
import AccountContext
import TelegramNotices
import PresentationDataUtils
import UndoUI
import UrlHandling
import TelegramPresentationData
import ChatInterfaceState

func openWebAppImpl(
    context: AccountContext,
    parentController: ViewController,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    botPeer: EnginePeer,
    chatPeer: EnginePeer?,
    threadId: Int64?,
    buttonText: String,
    url: String,
    simple: Bool,
    source: ChatOpenWebViewSource,
    skipTermsOfService: Bool,
    payload: String?
) {
    if context.isFrozen {
        parentController.push(context.sharedContext.makeAccountFreezeInfoScreen(context: context))
        return
    }
    
    let presentationData: PresentationData
    if let parentController = parentController as? ChatControllerImpl {
        presentationData = parentController.presentationData
    } else {
        presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    }
    
    let botName: String
    let botAddress: String
    let botVerified: Bool
    if case let .inline(bot) = source {
        botName = bot.compactDisplayTitle
        botAddress = bot.addressName ?? ""
        botVerified = bot.isVerified
    } else {
        botName = botPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        botAddress = botPeer.addressName ?? ""
        botVerified = botPeer.isVerified
    }
    
    if source == .generic {
        if let parentController = parentController as? ChatControllerImpl {
            parentController.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedTitlePanelContext {
                    if !$0.contains(where: {
                        switch $0 {
                        case .requestInProgress:
                            return true
                        default:
                            return false
                        }
                    }) {
                        var updatedContexts = $0
                        updatedContexts.append(.requestInProgress)
                        return updatedContexts.sorted()
                    }
                    return $0
                }
            })
        }
    }
    
    let updateProgress = { [weak parentController] in
        Queue.mainQueue().async {
            if let parentController = parentController as? ChatControllerImpl {
                parentController.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if let index = $0.firstIndex(where: {
                            switch $0 {
                                case .requestInProgress:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.remove(at: index)
                            return updatedContexts
                        }
                        return $0
                    }
                })
            }
        }
    }
            
    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotAppSettings(id: botPeer.id))
    |> deliverOnMainQueue).start(next: { appSettings in
        let openWebView = { [weak parentController] in
            guard let parentController else {
                return
            }
            if source == .menu {
                if let parentController = parentController as? ChatControllerImpl {
                    parentController.updateChatPresentationInterfaceState(interactive: false) { state in
                        return state.updatedForceInputCommandsHidden(true)
                    }
                }
                
                if let navigationController = parentController.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                    for controller in minimizedContainer.controllers {
                        if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == botPeer.id && mainController.source == .menu {
                            navigationController.maximizeViewController(controller, animated: true)
                            return
                        }
                    }
                }
                
                var fullSize = false
                var isFullscreen = false
                if isTelegramMeLink(url), let internalUrl = parseFullInternalUrl(sharedContext: context.sharedContext, context: context, url: url), case .peer(_, .appStart) = internalUrl {
                    if url.contains("mode=fullscreen") {
                        isFullscreen = true
                        fullSize = true
                    } else {
                        fullSize = !url.contains("mode=compact")
                    }
                }
                
                var hasWebApp = false
                if case let .user(user) = botPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                    hasWebApp = true
                }
                
                var presentImpl: ((ViewController, Any?) -> Void)?
                let params = WebAppParameters(source: .menu, peerId: chatPeer?.id ?? botPeer.id, botId: botPeer.id, botName: botName, botVerified: botVerified, botAddress: botPeer.addressName ?? "", appName: hasWebApp ? "" : nil, url: url, queryId: nil, payload: nil, buttonText: buttonText, keepAliveSignal: nil, forceHasSettings: false, fullSize: fullSize, isFullscreen: isFullscreen, appSettings: appSettings)
                
                let controller = standaloneWebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, threadId: threadId, openUrl: { [weak parentController] url, concealed, forceUpdate, commit in
                    ChatControllerImpl.botOpenUrl(context: context, peerId: chatPeer?.id ?? botPeer.id, controller: parentController as? ChatControllerImpl, url: url, concealed: concealed, forceUpdate: forceUpdate, present: { c, a in
                        presentImpl?(c, a)
                    }, commit: commit)
                }, requestSwitchInline: { [weak parentController] query, chatTypes, completion in
                    ChatControllerImpl.botRequestSwitchInline(context: context, controller: parentController as? ChatControllerImpl, peerId: chatPeer?.id ?? botPeer.id, botAddress: botAddress, query: query, chatTypes: chatTypes, completion: completion)
                }, getInputContainerNode: { [weak parentController] in
                    if let parentController = parentController as? ChatControllerImpl, let layout = parentController.validLayout, case .compact = layout.metrics.widthClass {
                        return (parentController.chatDisplayNode.getWindowInputAccessoryHeight(), parentController.chatDisplayNode.inputPanelContainerNode, {
                            return parentController.chatDisplayNode.textInputPanelNode?.makeAttachmentMenuTransition(accessoryPanelNode: nil)
                        })
                    } else {
                        return nil
                    }
                }, completion: { [weak parentController] in
                    if let parentController = parentController as? ChatControllerImpl {
                        parentController.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                }, willDismiss: { [weak parentController] in
                    if let parentController = parentController as? ChatControllerImpl {
                        parentController.interfaceInteraction?.updateShowWebView { _ in
                            return false
                        }
                    }
                }, didDismiss: { [weak parentController] in
                    if let parentController = parentController as? ChatControllerImpl {
                        parentController.updateChatPresentationInterfaceState(interactive: false) { state in
                            return state.updatedForceInputCommandsHidden(false)
                        }
                    }
                }, getNavigationController: { [weak parentController] in
                    var navigationController: NavigationController?
                    if let parentController = parentController as? ChatControllerImpl {
                        navigationController = parentController.effectiveNavigationController
                    }
                    return navigationController ?? (context.sharedContext.mainWindow?.viewController as? NavigationController)
                })
                controller.navigationPresentation = .flatModal
                parentController.push(controller)
                
                presentImpl = { [weak controller] c, a in
                    controller?.present(c, in: .window(.root), with: a)
                }
            } else if simple {
                var isInline = false
                var botId = botPeer.id
                var botName = botName
                var botAddress = botPeer.addressName ?? ""
                var botVerified = botPeer.isVerified
                if case let .inline(bot) = source {
                    isInline = true
                    botId = bot.id
                    botName = bot.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    botAddress = bot.addressName ?? ""
                    botVerified = bot.isVerified
                }
                
                let messageActionCallbackDisposable: MetaDisposable
                if let parentController = parentController as? ChatControllerImpl {
                    messageActionCallbackDisposable = parentController.messageActionCallbackDisposable
                } else {
                    messageActionCallbackDisposable = MetaDisposable()
                }
                
                let webViewSignal: Signal<RequestWebViewResult, RequestWebViewError>
                let webViewSource: RequestSimpleWebViewSource
                if let payload {
                    webViewSource = .inline(startParam: payload)
                } else {
                    webViewSource = .generic
                }
                if url.isEmpty {
                    webViewSignal = context.engine.messages.requestMainWebView(peerId: chatPeer?.id ?? botId, botId: botId, source: webViewSource, themeParams: generateWebAppThemeParams(presentationData.theme))
                } else {
                    webViewSignal = context.engine.messages.requestSimpleWebView(botId: botId, url: url, source: webViewSource, themeParams: generateWebAppThemeParams(presentationData.theme))
                }
                
                messageActionCallbackDisposable.set(((webViewSignal
                |> afterDisposed {
                    updateProgress()
                })
                |> deliverOnMainQueue).start(next: { [weak parentController] result in
                    guard let parentController else {
                        return
                    }
                    var presentImpl: ((ViewController, Any?) -> Void)?
                    let source: WebAppParameters.Source
                    if isInline {
                        source = .inline
                    } else {
                        source = url.isEmpty ? .generic : .simple
                    }
                    let params = WebAppParameters(source: source, peerId: chatPeer?.id ?? botId, botId: botId, botName: botName, botVerified: botVerified, botAddress: botPeer.addressName ?? "", appName: "", url: result.url, queryId: nil, payload: payload, buttonText: buttonText, keepAliveSignal: nil, forceHasSettings: false, fullSize: result.flags.contains(.fullSize), isFullscreen: result.flags.contains(.fullScreen), appSettings: appSettings)
                    let controller = standaloneWebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, threadId: threadId, openUrl: { [weak parentController] url, concealed, forceUpdate, commit in
                        ChatControllerImpl.botOpenUrl(context: context, peerId: chatPeer?.id ?? botId, controller: parentController as? ChatControllerImpl, url: url, concealed: concealed, forceUpdate: forceUpdate, present: { c, a in
                            presentImpl?(c, a)
                        }, commit: commit)
                    }, requestSwitchInline: { [weak parentController] query, chatTypes, completion in
                        ChatControllerImpl.botRequestSwitchInline(context: context, controller: parentController as? ChatControllerImpl, peerId: chatPeer?.id ?? botId, botAddress: botAddress, query: query, chatTypes: chatTypes, completion: completion)
                    }, getNavigationController: { [weak parentController] in
                        var navigationController: NavigationController?
                        if let parentController = parentController as? ChatControllerImpl {
                            navigationController = parentController.effectiveNavigationController
                        }
                        return navigationController ?? (context.sharedContext.mainWindow?.viewController as? NavigationController)
                    })
                    controller.navigationPresentation = .flatModal
                    parentController.push(controller)
                    
                    presentImpl = { [weak controller] c, a in
                        controller?.present(c, in: .window(.root), with: a)
                    }
                }, error: { [weak parentController] error in
                    if let parentController {
                        parentController.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    }
                }))
            } else {
                let messageActionCallbackDisposable: MetaDisposable
                if let parentController = parentController as? ChatControllerImpl {
                    messageActionCallbackDisposable = parentController.messageActionCallbackDisposable
                } else {
                    messageActionCallbackDisposable = MetaDisposable()
                }
                
                messageActionCallbackDisposable.set(((context.engine.messages.requestWebView(peerId: chatPeer?.id ?? botPeer.id, botId: botPeer.id, url: !url.isEmpty ? url : nil, payload: nil, themeParams: generateWebAppThemeParams(presentationData.theme), fromMenu: false, replyToMessageId: nil, threadId: threadId)
                |> afterDisposed {
                    updateProgress()
                })
                |> deliverOnMainQueue).startStandalone(next: { [weak parentController] result in
                    guard let parentController else {
                        return
                    }
                    
                    var hasWebApp = false
                    if case let .user(user) = botPeer, let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                        hasWebApp = true
                    }
                    
                    var presentImpl: ((ViewController, Any?) -> Void)?
                    let params = WebAppParameters(source: .button, peerId: chatPeer?.id ?? botPeer.id, botId: botPeer.id, botName: botName, botVerified: botVerified, botAddress: botPeer.addressName ?? "", appName: hasWebApp ? "" : nil, url: result.url, queryId: result.queryId, payload: nil, buttonText: buttonText, keepAliveSignal: result.keepAliveSignal, forceHasSettings: false, fullSize: result.flags.contains(.fullSize), isFullscreen: result.flags.contains(.fullScreen), appSettings: appSettings)
                    let controller = standaloneWebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, threadId: threadId, openUrl: { [weak parentController] url, concealed, forceUpdate, commit in
                        ChatControllerImpl.botOpenUrl(context: context, peerId: chatPeer?.id ?? botPeer.id, controller: parentController as? ChatControllerImpl, url: url, concealed: concealed, forceUpdate: forceUpdate, present: { c, a in
                            presentImpl?(c, a)
                        }, commit: commit)
                    }, completion: { [weak parentController] in
                        if let parentController = parentController as? ChatControllerImpl {
                            parentController.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }
                    }, getNavigationController: { [weak parentController] in
                        var navigationController: NavigationController?
                        if let parentController = parentController as? ChatControllerImpl {
                            navigationController = parentController.effectiveNavigationController
                        }
                        return navigationController ?? (context.sharedContext.mainWindow?.viewController as? NavigationController)
                    })
                    controller.navigationPresentation = .flatModal
                    parentController.push(controller)
                    
                    presentImpl = { [weak controller] c, a in
                        controller?.present(c, in: .window(.root), with: a)
                    }
                }, error: { [weak parentController] error in
                    if let parentController {
                        parentController.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    }
                }))
            }
        }
        
        if skipTermsOfService {
            openWebView()
        } else {
            var botPeer = botPeer
            if case let .inline(bot) = source {
                botPeer = bot
            }
            let _ = (ApplicationSpecificNotice.getBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id)
            |> deliverOnMainQueue).startStandalone(next: { [weak parentController] value in
                guard let parentController else {
                    return
                }
                
                if value {
                    openWebView()
                } else {
                    let controller = webAppLaunchConfirmationController(context: context, updatedPresentationData: updatedPresentationData, peer: botPeer, completion: { _ in
                        let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                        openWebView()
                    }, showMore: nil, openTerms: {
                        if let navigationController = parentController.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.WebApp_LaunchTermsConfirmation_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    })
                    parentController.present(controller, in: .window(.root))
                }
            })
        }
    })
}

public extension ChatControllerImpl {
    func openWebApp(buttonText: String, url: String, simple: Bool, source: ChatOpenWebViewSource) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.chatDisplayNode.dismissInput()
        
        self.context.sharedContext.openWebApp(context: self.context, parentController: self, updatedPresentationData: self.updatedPresentationData, botPeer: EnginePeer(peer), chatPeer: EnginePeer(peer), threadId: self.chatLocation.threadId, buttonText: buttonText, url: url, simple: simple, source: source, skipTermsOfService: false, payload: nil)
    }
    
    fileprivate static func botRequestSwitchInline(context: AccountContext, controller: ChatControllerImpl?, peerId: EnginePeer.Id, botAddress: String, query: String, chatTypes: [ReplyMarkupButtonRequestPeerType]?, completion:  @escaping () -> Void) -> Void {
        let activateSwitchInline: (EnginePeer?) -> Void = { selectedPeer in
            var chatController: ChatControllerImpl?
            if let current = controller {
                chatController = current
            } else if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                for controller in navigationController.viewControllers.reversed() {
                    if let controller = controller as? ChatControllerImpl {
                        chatController = controller
                        break
                    }
                }
            }
            let inputString = "@\(botAddress) \(query)"
            if let chatController {
                chatController.controllerInteraction?.activateSwitchInline(selectedPeer?.id ?? peerId, inputString, nil)
            } else if let selectedPeer, let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                let textInputState = ChatTextInputState(inputText: NSAttributedString(string: inputString))
                let _ = (ChatInterfaceState.update(engine: context.engine, peerId: selectedPeer.id, threadId: nil, { currentState in
                    return currentState.withUpdatedComposeInputState(textInputState)
                })
                |> deliverOnMainQueue).startStandalone(completed: { [weak navigationController] in
                    guard let navigationController else {
                        return
                    }
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(selectedPeer), subject: nil, updateTextInputState: textInputState, peekData: nil))
                })
            }
        }
    
        if let chatTypes {
            let peerController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: chatTypes, hasContactSelector: false, hasCreation: false))
            peerController.peerSelected = { [weak peerController] peer, _ in
                completion()
                peerController?.dismiss()
                activateSwitchInline(peer)
            }
            if let controller {
                controller.push(peerController)
            } else {
                ((context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface)?.viewControllers.last as? ViewController)?.push(peerController)
            }
        } else {
            activateSwitchInline(nil)
        }
    }
    
    private static func botOpenPeer(context: AccountContext, peerId: EnginePeer.Id, navigation: ChatControllerInteractionNavigateToPeer, navigationController: NavigationController) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                return
            }
            switch navigation {
            case .default:
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always))
            case let .chat(_, subject, peekData):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject, keepStack: .always, peekData: peekData))
            case .info:
                if peer.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) == nil {
                    if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        navigationController.pushViewController(infoController)
                    }
                }
            case let .withBotStartPayload(startPayload):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botStart: startPayload))
            case let .withAttachBot(attachBotStart):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
            case let .withBotApp(botAppStart):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botAppStart: botAppStart, keepStack: .always))
            }
        })
    }
    
    fileprivate static func botOpenUrl(context: AccountContext, peerId: EnginePeer.Id, controller: ChatControllerImpl?, url: String, concealed: Bool, forceUpdate: Bool, present: @escaping (ViewController, Any?) -> Void, commit: @escaping () -> Void = {}) {
        if let controller {
            controller.openUrl(url, concealed: concealed, forceExternal: true, commit: commit)
        } else {
            let _ = openUserGeneratedUrl(context: context, peerId: peerId, url: url, concealed: concealed, present: { c in
                present(c, nil)
            }, openResolved: { result in
                var navigationController: NavigationController?
                if let main = context.sharedContext.mainWindow?.viewController as? NavigationController {
                    navigationController = main
                }
                if case let .peer(peer, navigation) = result, case let .withBotApp(botApp) = navigation, let botPeer = peer.flatMap(EnginePeer.init), let parentController = navigationController?.viewControllers.last as? ViewController {
                    self.presentBotApp(context: context, parentController: parentController, botApp: botApp.botApp, botPeer: botPeer, payload: botApp.payload, mode: botApp.mode)
                } else {
                    context.sharedContext.openResolvedUrl(result, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: forceUpdate, openPeer: { peer, navigation in
                        if let navigationController {
                            ChatControllerImpl.botOpenPeer(context: context, peerId: peer.id, navigation: navigation, navigationController: navigationController)
                        }
                        commit()
                    }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: { peerId, invite, call in
                    }, present: { c, a in
                        present(c, a)
                    }, dismissInput: {
                        context.sharedContext.mainWindow?.viewController?.view.endEditing(false)
                    }, contentContext: nil, progress: nil, completion: nil)
                }
            })
        }
    }
    
    func presentBotApp(botApp: BotApp?, botPeer: EnginePeer, payload: String?, mode: ResolvedStartAppMode, concealed: Bool = false, commit: @escaping () -> Void = {}) {
        ChatControllerImpl.presentBotApp(context: self.context, parentController: self, botApp: botApp, botPeer: botPeer, payload: payload, mode: mode, concealed: concealed, commit: commit)
    }
    
    fileprivate static func presentBotApp(context: AccountContext, parentController: ViewController, botApp: BotApp?, botPeer: EnginePeer, payload: String?, mode: ResolvedStartAppMode, concealed: Bool = false, commit: @escaping () -> Void = {}) {
        let chatController = parentController as? ChatControllerImpl
        let peerId: EnginePeer.Id
        let threadId = chatController?.chatLocation.threadId
        if let chatPeerId = chatController?.chatLocation.peerId {
            peerId = chatPeerId
        } else {
            peerId = botPeer.id
        }

        chatController?.attachmentController?.dismiss(animated: true, completion: nil)
        
        let updatedPresentationData = chatController?.updatedPresentationData
        let presentationData = updatedPresentationData?.0 ?? context.sharedContext.currentPresentationData.with { $0 }
        
        if let botApp {
            let openBotApp: (Bool, Bool, BotAppSettings?) -> Void = { [weak parentController, weak chatController] allowWrite, justInstalled, appSettings in
                commit()
                
                chatController?.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if !$0.contains(where: {
                            switch $0 {
                            case .requestInProgress:
                                return true
                            default:
                                return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.append(.requestInProgress)
                            return updatedContexts.sorted()
                        }
                        return $0
                    }
                })
                
                let updateProgress = { [weak chatController] in
                    Queue.mainQueue().async {
                        if let chatController {
                            chatController.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedTitlePanelContext {
                                    if let index = $0.firstIndex(where: {
                                        switch $0 {
                                        case .requestInProgress:
                                            return true
                                        default:
                                            return false
                                        }
                                    }) {
                                        var updatedContexts = $0
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    }
                                    return $0
                                }
                            })
                        }
                    }
                }
                
                let botAddress = botPeer.addressName ?? ""
                let _ = ((context.engine.messages.requestAppWebView(peerId: peerId, appReference: .id(id: botApp.id, accessHash: botApp.accessHash), payload: payload, themeParams: generateWebAppThemeParams(presentationData.theme), compact: mode == .compact, fullscreen: mode == .fullscreen, allowWrite: allowWrite)
                |> afterDisposed {
                    updateProgress()
                })
                |> deliverOnMainQueue).startStandalone(next: { [weak parentController, weak chatController] result in
                    let params = WebAppParameters(source: .generic, peerId: peerId, botId: botPeer.id, botName: botApp.title, botVerified: botPeer.isVerified, botAddress: botPeer.addressName ?? "", appName: botApp.shortName, url: result.url, queryId: 0, payload: payload, buttonText: "", keepAliveSignal: nil, forceHasSettings: botApp.flags.contains(.hasSettings), fullSize: result.flags.contains(.fullSize), isFullscreen: result.flags.contains(.fullScreen), appSettings: appSettings)
                    var presentImpl: ((ViewController, Any?) -> Void)?
                    let controller = standaloneWebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, threadId: threadId, openUrl: { url, concealed, forceUpdate, commit in
                        ChatControllerImpl.botOpenUrl(context: context, peerId: peerId, controller: chatController, url: url, concealed: concealed, forceUpdate: forceUpdate, present: { c, a in
                            presentImpl?(c, a)
                        }, commit: commit)
                    }, requestSwitchInline: { query, chatTypes, completion in
                        ChatControllerImpl.botRequestSwitchInline(context: context, controller: chatController, peerId: peerId, botAddress: botAddress, query: query, chatTypes: chatTypes, completion: completion)
                    }, completion: {
                        chatController?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }, getNavigationController: {
                        if let navigationController = parentController?.navigationController as? NavigationController {
                            return navigationController
                        } else {
                            return context.sharedContext.mainWindow?.viewController as? NavigationController
                        }
                    })
                    controller.navigationPresentation = .flatModal
                    parentController?.push(controller)
                        
                    presentImpl = { [weak controller] c, a in
                        controller?.present(c, in: .window(.root), with: a)
                    }
                    
                    if justInstalled {
                        let content: UndoOverlayContent = .succeed(text: presentationData.strings.WebApp_ShortcutsSettingsAdded(botPeer.compactDisplayTitle).string, timeout: 5.0, customUndoText: nil)
                        controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in return false }), in: .current)
                    }
                }, error: { [weak parentController] error in
                    parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                })
            }
            
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                ApplicationSpecificNotice.getBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id),
                context.engine.messages.attachMenuBots(),
                context.engine.messages.getAttachMenuBot(botId: botPeer.id, cached: true)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<AttachMenuBot?, NoError> in
                    return .single(nil)
                },
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotAppSettings(id: botPeer.id))
            ).startStandalone(next: { [weak parentController, weak chatController] noticed, attachMenuBots, attachMenuBot, appSettings in
                var isAttachMenuBotInstalled: Bool?
                if let _ = attachMenuBot {
                    if let _ = attachMenuBots.first(where: { $0.peer.id == botPeer.id && !$0.flags.contains(.notActivated) }) {
                        isAttachMenuBotInstalled = true
                    } else {
                        isAttachMenuBotInstalled = false
                    }
                }
                
                if !noticed || botApp.flags.contains(.notActivated) || isAttachMenuBotInstalled == false {
                    if let isAttachMenuBotInstalled, let attachMenuBot {
                        if !isAttachMenuBotInstalled {
                            let controller = webAppTermsAlertController(context: context, updatedPresentationData: updatedPresentationData, bot: attachMenuBot, completion: { allowWrite in
                                let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                                let _ = (context.engine.messages.addBotToAttachMenu(botId: botPeer.id, allowWrite: allowWrite)
                                |> deliverOnMainQueue).startStandalone(error: { _ in
                                }, completed: {
                                    openBotApp(allowWrite, true, appSettings)
                                })
                            })
                            parentController?.present(controller, in: .window(.root))
                        } else {
                            openBotApp(false, false, appSettings)
                        }
                    } else {
                        let controller = webAppLaunchConfirmationController(context: context, updatedPresentationData: updatedPresentationData, peer: botPeer, requestWriteAccess: botApp.flags.contains(.notActivated) && botApp.flags.contains(.requiresWriteAccess), completion: { allowWrite in
                            let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                            openBotApp(allowWrite, false, appSettings)
                        }, showMore: chatController == nil ? nil : { [weak chatController] in
                            if let chatController {
                                chatController.openResolved(result: .peer(botPeer._asPeer(), .info(nil)), sourceMessageId: nil)
                            }
                        }, openTerms: {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.WebApp_LaunchTermsConfirmation_URL, forceExternal: false, presentationData: presentationData, navigationController: parentController?.navigationController as? NavigationController, dismissInput: {})
                        })
                        parentController?.present(controller, in: .window(.root))
                    }
                } else {
                    openBotApp(false, false, appSettings)
                }
            })
        } else {
            context.sharedContext.openWebApp(context: context, parentController: parentController, updatedPresentationData: updatedPresentationData, botPeer: botPeer, chatPeer: nil, threadId: nil, buttonText: "", url: "", simple: true, source: .generic, skipTermsOfService: false, payload: payload)
        }
    }
}
