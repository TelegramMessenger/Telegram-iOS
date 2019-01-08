import Foundation
import TelegramCore
import Postbox
import Display
import SwiftSignalKit

private func defaultNavigationForPeerId(_ peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer) -> ChatControllerInteractionNavigateToPeer {
    if case .default = navigation {
        if let peerId = peerId {
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .info
            } else {
                return .chat(textInputState: nil, messageId: nil)
            }
        } else {
            return .info
        }
    } else {
        return navigation
    }
}

func openResolvedUrl(_ resolvedUrl: ResolvedUrl, account: Account, context: OpenURLContext = .generic, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)? = nil, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void) {
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    switch resolvedUrl {
        case let .externalUrl(url):
            openExternalUrl(account: account, context: context, url: url, presentationData: account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: account.telegramApplicationContext, navigationController: navigationController, dismissInput: dismissInput)
        case let .peer(peerId, navigation):
            if let peerId = peerId {
                openPeer(peerId, defaultNavigationForPeerId(peerId, navigation: navigation))
            } else {
                
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload):
            let controller = PeerSelectionController(account: account, filter: [.onlyWriteable, .onlyGroups, .onlyManageable], title: presentationData.strings.UserInfo_InviteBotToGroup)
            controller.peerSelected = { [weak controller] peerId in
                if payload.isEmpty {
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let _ = (addGroupMember(account: account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    } else {
                        let _ = (addChannelMember(account: account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    }
                } else {
                    let _ = (requestStartBotInGroup(account: account, botPeerId: botPeerId, groupPeerId: peerId, payload: payload)
                    |> deliverOnMainQueue).start(next: { result in
                        if let navigationController = navigationController {
                            navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(peerId))
                        }
                        switch result {
                            case let .channelParticipant(participant):
                                account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
                            case .none:
                                break
                        }
                        controller?.dismiss()
                    }, error: { _ in
                        
                    })
                }
            }
            dismissInput()
            present(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
        case let .channelMessage(peerId, messageId):
            openPeer(peerId, .chat(textInputState: nil, messageId: messageId))
        case let .stickerPack(name):
            dismissInput()
            let controller = StickerPackPreviewController(account: account, stickerPack: .name(name), parentNavigationController: navigationController)
            controller.sendSticker = sendFile
            present(controller, nil)
        case let .instantView(webpage, anchor):
            navigationController?.pushViewController(InstantPageController(account: account, webPage: webpage, anchor: anchor))
        case let .join(link):
            dismissInput()
            present(JoinLinkPreviewController(account: account, link: link, navigateToPeer: { peerId in
                openPeer(peerId, .chat(textInputState: nil, messageId: nil))
            }), nil)
        case let .localization(identifier):
            dismissInput()
            present(LanguageLinkPreviewController(account: account, identifier: identifier), nil)
        case let .proxy(host, port, username, password, secret):
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .socks5(username: username, password: password))
            }

            dismissInput()
            present(ProxyServerActionSheetController(account: account, server: server), nil)
        case let .confirmationCode(code):
            if let topController = navigationController?.topViewController as? ChangePhoneNumberCodeController {
                topController.applyCode(code)
            } else {
                var found = false
                navigationController?.currentWindow?.forEachController({ controller in
                    if let controller = controller as? SecureIdPlaintextFormController {
                        controller.applyPhoneCode(code)
                        found = true
                    }
                })
                if !found {
                    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                    present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.AuthCode_Alert(formattedConfirmationCode(code)).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }
        case let .cancelAccountReset(phone, hash):
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            present(controller, nil)
            let _ = (requestCancelAccountResetData(network: account.network, hash: hash)
            |> deliverOnMainQueue).start(next: { [weak controller] data in
                controller?.dismiss()
                present(confirmPhoneNumberCodeController(account: account, phoneNumber: phone, codeData: data), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, error: { [weak controller] error in
                controller?.dismiss()
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Login_CodeFloodError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            dismissInput()
        case let .share(url, text, to):
            let continueWithPeer: (PeerId) -> Void = { peerId in
                let textInputState: ChatTextInputState?
                if let text = text, !text.isEmpty {
                    if let url = url, !url.isEmpty {
                        let urlString = NSMutableAttributedString(string: "\(url)\n")
                        let textString = NSAttributedString(string: "\(text)")
                        let selectionRange: Range<Int> = urlString.length ..< (urlString.length + textString.length)
                        urlString.append(textString)
                        textInputState = ChatTextInputState(inputText: urlString, selectionRange: selectionRange)
                    } else {
                        textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(text)"))
                    }
                } else if let url = url, !url.isEmpty {
                    textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(url)"))
                } else {
                    textInputState = nil
                }
                
                if let textInputState = textInputState {
                    let _ = (account.postbox.transaction({ transaction -> Void in
                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                            if let currentState = currentState as? ChatInterfaceState {
                                return currentState.withUpdatedComposeInputState(textInputState)
                            } else {
                                return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                            }
                        })
                    })
                    |> deliverOnMainQueue).start(completed: {
                        navigationController?.pushViewController(ChatController(account: account, chatLocation: .peer(peerId), messageId: nil))
                    })
                }
            }
            
            if let to = to {
                let query = to.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789").inverted)
                let _ = (account.postbox.searchContacts(query: query)
                |> deliverOnMainQueue).start(next: { (peers, _) in
                    for case let peer as TelegramUser in peers {
                        if peer.phone == query {
                            continueWithPeer(peer.id)
                            break
                        }
                    }
                })
            } else {
                let controller = PeerSelectionController(account: account)
                controller.peerSelected = { [weak controller] peerId in
                    if let strongController = controller {
                        strongController.dismiss()
                        continueWithPeer(peerId)
                    }
                }
                if let navigationController = navigationController {
                    account.telegramApplicationContext.applicationBindings.dismissNativeController()
                    (navigationController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                }
            }
        case let .wallpaper(slug):
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            present(controller, nil)
            let _ = (getWallpaper(account: account, slug: slug)
            |> deliverOnMainQueue).start(next: { [weak controller] wallpaper in
                controller?.dismiss()
                let wallpaperController = WallpaperListPreviewController(account: account, source: .wallpaper(wallpaper))
                present(wallpaperController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, error: { [weak controller] error in
                controller?.dismiss()
                
//                let text: String
//                switch error {
//                case .limitExceeded:
//                    text = presentationData.strings.Login_CodeFloodError
//                case .generic:
//                    text = presentationData.strings.Login_UnknownError
//                }
//                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
//                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            dismissInput()
    }
}
