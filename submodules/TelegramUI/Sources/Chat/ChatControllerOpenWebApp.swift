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

public extension ChatControllerImpl {
    func openWebApp(buttonText: String, url: String, simple: Bool, source: ChatOpenWebViewSource) {
        guard let peerId = self.chatLocation.peerId, let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.chatDisplayNode.dismissInput()
        
        let botName: String
        let botAddress: String
        if case let .inline(bot) = source {
            botName = bot.compactDisplayTitle
            botAddress = bot.addressName ?? ""
        } else {
            botName = EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
            botAddress = peer.addressName ?? ""
        }
        
        if source == .generic {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
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
        
        let updateProgress = { [weak self] in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
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
        
        let openWebView = {
            if source == .menu {
                self.updateChatPresentationInterfaceState(interactive: false) { state in
                    return state.updatedForceInputCommandsHidden(true)
//                    return state.updatedShowWebView(true).updatedForceInputCommandsHidden(true)
                }
                
                if let navigationController = self.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                    for controller in minimizedContainer.controllers {
                        if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == peerId && mainController.source == .menu {
                            navigationController.maximizeViewController(controller, animated: true)
                            return
                        }
                    }
                }
                
                var fullSize = false
                if isTelegramMeLink(url), let internalUrl = parseFullInternalUrl(sharedContext: self.context.sharedContext, url: url), case .peer(_, .appStart) = internalUrl {
                    fullSize = !url.contains("?mode=compact")
                }
                
                let context = self.context
                let params = WebAppParameters(source: .menu, peerId: peerId, botId: peerId, botName: botName, url: url, queryId: nil, payload: nil, buttonText: buttonText, keepAliveSignal: nil, forceHasSettings: false, fullSize: fullSize)
                let controller = standaloneWebAppController(context: self.context, updatedPresentationData: self.updatedPresentationData, params: params, threadId: self.chatLocation.threadId, openUrl: { [weak self] url, concealed, commit in
                    self?.openUrl(url, concealed: concealed, forceExternal: true, commit: commit)
                }, requestSwitchInline: { [weak self] query, chatTypes, completion in
                    if let strongSelf = self {
                        if let chatTypes {
                            let controller = strongSelf.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: strongSelf.context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: chatTypes, hasContactSelector: false, hasCreation: false))
                            controller.peerSelected = { [weak self, weak controller] peer, _ in
                                if let strongSelf = self {
                                    completion()
                                    controller?.dismiss()
                                    strongSelf.controllerInteraction?.activateSwitchInline(peer.id, "@\(botAddress) \(query)", nil)
                                }
                            }
                            strongSelf.push(controller)
                        } else {
                            strongSelf.controllerInteraction?.activateSwitchInline(peerId, "@\(botAddress) \(query)", nil)
                        }
                    }
                }, getInputContainerNode: { [weak self] in
                    if let strongSelf = self, let layout = strongSelf.validLayout, case .compact = layout.metrics.widthClass {
                        return (strongSelf.chatDisplayNode.getWindowInputAccessoryHeight(), strongSelf.chatDisplayNode.inputPanelContainerNode, {
                            return strongSelf.chatDisplayNode.textInputPanelNode?.makeAttachmentMenuTransition(accessoryPanelNode: nil)
                        })
                    } else {
                        return nil
                    }
                }, completion: { [weak self] in
                    self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }, willDismiss: { [weak self] in
                    self?.interfaceInteraction?.updateShowWebView { _ in
                        return false
                    }
                }, didDismiss: { [weak self] in
                    if let strongSelf = self {
                        let isFocused = strongSelf.chatDisplayNode.textInputPanelNode?.isFocused ?? false
                        strongSelf.chatDisplayNode.insertSubnode(strongSelf.chatDisplayNode.inputPanelContainerNode, aboveSubnode: strongSelf.chatDisplayNode.inputContextPanelContainer)
                        if isFocused {
                            strongSelf.chatDisplayNode.textInputPanelNode?.ensureFocused()
                        }
                        
                        strongSelf.updateChatPresentationInterfaceState(interactive: false) { state in
                            return state.updatedForceInputCommandsHidden(false)
                        }
                    }
                }, getNavigationController: { [weak self] in
                    return self?.effectiveNavigationController ?? context.sharedContext.mainWindow?.viewController as? NavigationController
                })
                controller.navigationPresentation = .flatModal
                self.push(controller)
            } else if simple {
                var isInline = false
                var botId = peerId
                var botName = botName
                var botAddress = ""
                if case let .inline(bot) = source {
                    isInline = true
                    botId = bot.id
                    botName = bot.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
                    botAddress = bot.addressName ?? ""
                }
                
                self.messageActionCallbackDisposable.set(((self.context.engine.messages.requestSimpleWebView(botId: botId, url: url, source: isInline ? .inline : .generic, themeParams: generateWebAppThemeParams(self.presentationData.theme))
                |> afterDisposed {
                    updateProgress()
                })
                |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    let context = strongSelf.context
                    let params = WebAppParameters(source: isInline ? .inline : .simple, peerId: peerId, botId: botId, botName: botName, url: result.url, queryId: nil, payload: nil, buttonText: buttonText, keepAliveSignal: nil, forceHasSettings: false, fullSize: result.flags.contains(.fullSize))
                    let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, threadId: strongSelf.chatLocation.threadId, openUrl: { [weak self] url, concealed, commit in
                        self?.openUrl(url, concealed: concealed, forceExternal: true, commit: commit)
                    }, requestSwitchInline: { [weak self] query, chatTypes, completion in
                        if let strongSelf = self {
                            if let chatTypes {
                                let controller = strongSelf.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: strongSelf.context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: chatTypes, hasContactSelector: false, hasCreation: false))
                                controller.peerSelected = { [weak self, weak controller] peer, _ in
                                    if let strongSelf = self {
                                        completion()
                                        controller?.dismiss()
                                        strongSelf.controllerInteraction?.activateSwitchInline(peer.id, "@\(botAddress) \(query)", nil)
                                    }
                                }
                                strongSelf.push(controller)
                            } else {
                                strongSelf.controllerInteraction?.activateSwitchInline(peerId, "@\(botAddress) \(query)", nil)
                            }
                        }
                    }, getNavigationController: { [weak self] in
                        return self?.effectiveNavigationController ?? context.sharedContext.mainWindow?.viewController as? NavigationController
                    })
                    controller.navigationPresentation = .flatModal
                    strongSelf.currentWebAppController = controller
                    strongSelf.push(controller)
                }, error: { [weak self] error in
                    if let strongSelf = self {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    }
                }))
            } else {
                self.messageActionCallbackDisposable.set(((self.context.engine.messages.requestWebView(peerId: peerId, botId: peerId, url: !url.isEmpty ? url : nil, payload: nil, themeParams: generateWebAppThemeParams(self.presentationData.theme), fromMenu: buttonText == "Menu", replyToMessageId: nil, threadId: self.chatLocation.threadId)
                |> afterDisposed {
                    updateProgress()
                })
                |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    let context = strongSelf.context
                    let params = WebAppParameters(source: .generic, peerId: peerId, botId: peerId, botName: botName, url: result.url, queryId: result.queryId, payload: nil, buttonText: buttonText, keepAliveSignal: result.keepAliveSignal, forceHasSettings: false, fullSize: result.flags.contains(.fullSize))
                    let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, threadId: strongSelf.chatLocation.threadId, openUrl: { [weak self] url, concealed, commit in
                        self?.openUrl(url, concealed: concealed, forceExternal: true, commit: commit)
                    }, completion: { [weak self] in
                        self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }, getNavigationController: { [weak self] in
                        return self?.effectiveNavigationController ?? context.sharedContext.mainWindow?.viewController as? NavigationController
                    })
                    controller.navigationPresentation = .flatModal
                    strongSelf.currentWebAppController = controller
                    strongSelf.push(controller)
                }, error: { [weak self] error in
                    if let strongSelf = self {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    }
                }))
            }
        }
        
        var botPeer = EnginePeer(peer)
        if case let .inline(bot) = source {
            botPeer = bot
        }
        let _ = (ApplicationSpecificNotice.getBotGameNotice(accountManager: self.context.sharedContext.accountManager, peerId: botPeer.id)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }

            if value {
                openWebView()
            } else {
                let controller = webAppLaunchConfirmationController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: botPeer, completion: { _ in
                    let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                    openWebView()
                }, showMore: nil)
                strongSelf.present(controller, in: .window(.root))
            }
        })
    }
    
    func presentBotApp(botApp: BotApp, botPeer: EnginePeer, payload: String?, compact: Bool, concealed: Bool = false, commit: @escaping () -> Void = {}) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        self.attachmentController?.dismiss(animated: true, completion: nil)
        
        let openBotApp: (Bool, Bool) -> Void = { [weak self] allowWrite, justInstalled in
            guard let strongSelf = self else {
                return
            }
            commit()
            
            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
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
            
            let updateProgress = { [weak self] in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
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
            strongSelf.messageActionCallbackDisposable.set(((strongSelf.context.engine.messages.requestAppWebView(peerId: peerId, appReference: .id(id: botApp.id, accessHash: botApp.accessHash), payload: payload, themeParams: generateWebAppThemeParams(strongSelf.presentationData.theme), compact: compact, allowWrite: allowWrite)
            |> afterDisposed {
                updateProgress()
            })
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                let context = strongSelf.context
                let params = WebAppParameters(source: .generic, peerId: peerId, botId: botPeer.id, botName: botApp.title, url: result.url, queryId: 0, payload: payload, buttonText: "", keepAliveSignal: nil, forceHasSettings: botApp.flags.contains(.hasSettings), fullSize: result.flags.contains(.fullSize))
                let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, threadId: strongSelf.chatLocation.threadId, openUrl: { [weak self] url, concealed, commit in
                    self?.openUrl(url, concealed: concealed, forceExternal: true, commit: commit)
                }, requestSwitchInline: { [weak self] query, chatTypes, completion in
                    if let strongSelf = self {
                        if let chatTypes {
                            let controller = strongSelf.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: strongSelf.context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: chatTypes, hasContactSelector: false, hasCreation: false))
                            controller.peerSelected = { [weak self, weak controller] peer, _ in
                                if let strongSelf = self {
                                    completion()
                                    controller?.dismiss()
                                    strongSelf.controllerInteraction?.activateSwitchInline(peer.id, "@\(botAddress) \(query)", nil)
                                }
                            }
                            strongSelf.push(controller)
                        } else {
                            strongSelf.controllerInteraction?.activateSwitchInline(peerId, "@\(botAddress) \(query)", nil)
                        }
                    }
                }, completion: { [weak self] in
                    self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }, getNavigationController: { [weak self] in
                    return self?.effectiveNavigationController ?? context.sharedContext.mainWindow?.viewController as? NavigationController
                })
                controller.navigationPresentation = .flatModal
                strongSelf.currentWebAppController = controller
                strongSelf.push(controller)
                
                if justInstalled {
                    let content: UndoOverlayContent = .succeed(text: strongSelf.presentationData.strings.WebApp_ShortcutsSettingsAdded(botPeer.compactDisplayTitle).string, timeout: 5.0, customUndoText: nil)
                    controller.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in return false }), in: .current)
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    })]), in: .window(.root))
                }
            }))
        }
        
        let _ = combineLatest(
            queue: Queue.mainQueue(),
            ApplicationSpecificNotice.getBotGameNotice(accountManager: self.context.sharedContext.accountManager, peerId: botPeer.id),
            self.context.engine.messages.attachMenuBots(),
            self.context.engine.messages.getAttachMenuBot(botId: botPeer.id, cached: true)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<AttachMenuBot?, NoError> in
                return .single(nil)
            }
        ).startStandalone(next: { [weak self] noticed, attachMenuBots, attachMenuBot in
            guard let self else {
                return
            }
            
            var isAttachMenuBotInstalled: Bool?
            if let _ = attachMenuBot {
                if let _ = attachMenuBots.first(where: { $0.peer.id == botPeer.id && !$0.flags.contains(.notActivated) }) {
                    isAttachMenuBotInstalled = true
                } else {
                    isAttachMenuBotInstalled = false
                }
            }
            
            let context = self.context
            if !noticed || botApp.flags.contains(.notActivated) || isAttachMenuBotInstalled == false {
                if let isAttachMenuBotInstalled, let attachMenuBot {
                    if !isAttachMenuBotInstalled {
                        let controller = webAppTermsAlertController(context: context, updatedPresentationData: self.updatedPresentationData, bot: attachMenuBot, completion: { allowWrite in
                            let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                            let _ = (context.engine.messages.addBotToAttachMenu(botId: botPeer.id, allowWrite: allowWrite)
                            |> deliverOnMainQueue).startStandalone(error: { _ in
                            }, completed: {
                                openBotApp(allowWrite, true)
                            })
                        })
                        self.present(controller, in: .window(.root))
                    } else {
                        openBotApp(false, false)
                    }
                } else {
                    let controller = webAppLaunchConfirmationController(context: context, updatedPresentationData: self.updatedPresentationData, peer: botPeer, requestWriteAccess: botApp.flags.contains(.notActivated) && botApp.flags.contains(.requiresWriteAccess), completion: { allowWrite in
                        let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                        openBotApp(allowWrite, false)
                    }, showMore: { [weak self] in
                        if let self {
                            self.openResolved(result: .peer(botPeer._asPeer(), .info(nil)), sourceMessageId: nil)
                        }
                    })
                    self.present(controller, in: .window(.root))
                }
            } else {
                openBotApp(false, false)
            }
        })
    }
}
