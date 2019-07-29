import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences

private func defaultNavigationForPeerId(_ peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer) -> ChatControllerInteractionNavigateToPeer {
    if case .default = navigation {
        if let peerId = peerId {
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .chat(textInputState: nil, messageId: nil)
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

func openResolvedUrl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext = .generic, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)? = nil, sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)? = nil, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    switch resolvedUrl {
        case let .externalUrl(url):
            openExternalUrl(context: context, urlContext: urlContext, url: url, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: dismissInput)
        case let .peer(peerId, navigation):
            if let peerId = peerId {
                openPeer(peerId, defaultNavigationForPeerId(peerId, navigation: navigation))
            } else {
                present(textAlertController(context: context, title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case .inaccessiblePeer:
            present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Conversation_ErrorInaccessibleMessage, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload):
            let controller = PeerSelectionController(context: context, filter: [.onlyWriteable, .onlyGroups, .onlyManageable], title: presentationData.strings.UserInfo_InviteBotToGroup)
            controller.peerSelected = { [weak controller] peerId in
                if payload.isEmpty {
                    if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let _ = (addGroupMember(account: context.account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    } else {
                        let _ = (addChannelMember(account: context.account, peerId: peerId, memberId: botPeerId)
                        |> deliverOnMainQueue).start(completed: {
                            controller?.dismiss()
                        })
                    }
                } else {
                    let _ = (requestStartBotInGroup(account: context.account, botPeerId: botPeerId, groupPeerId: peerId, payload: payload)
                    |> deliverOnMainQueue).start(next: { result in
                        if let navigationController = navigationController {
                            navigateToChatController(navigationController: navigationController, context: context, chatLocation: .peer(peerId))
                        }
                        switch result {
                            case let .channelParticipant(participant):
                                context.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
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
            let controller = StickerPackPreviewController(context: context, stickerPack: .name(name), parentNavigationController: navigationController)
            controller.sendSticker = sendSticker
            present(controller, nil)
        case let .instantView(webpage, anchor):
            navigationController?.pushViewController(InstantPageController(context: context, webPage: webpage, sourcePeerType: .channel, anchor: anchor))
        case let .join(link):
            dismissInput()
            present(JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peerId in
                openPeer(peerId, .chat(textInputState: nil, messageId: nil))
            }), nil)
        case let .localization(identifier):
            dismissInput()
            present(LanguageLinkPreviewController(context: context, identifier: identifier), nil)
        case let .proxy(host, port, username, password, secret):
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .socks5(username: username, password: password))
            }

            dismissInput()
            present(ProxyServerActionSheetController(context: context, server: server), nil)
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
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    present(textAlertController(context: context, title: nil, text: presentationData.strings.AuthCode_Alert(formattedConfirmationCode(code)).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }
        case let .cancelAccountReset(phone, hash):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
            present(controller, nil)
            let _ = (requestCancelAccountResetData(network: context.account.network, hash: hash)
            |> deliverOnMainQueue).start(next: { [weak controller] data in
                controller?.dismiss()
                present(confirmPhoneNumberCodeController(context: context, phoneNumber: phone, codeData: data), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, error: { [weak controller] error in
                controller?.dismiss()
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Login_CodeFloodError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
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
                    let _ = (context.account.postbox.transaction({ transaction -> Void in
                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                            if let currentState = currentState as? ChatInterfaceState {
                                return currentState.withUpdatedComposeInputState(textInputState)
                            } else {
                                return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                            }
                        })
                    })
                    |> deliverOnMainQueue).start(completed: {
                        navigationController?.pushViewController(ChatController(context: context, chatLocation: .peer(peerId), messageId: nil))
                    })
                }
            }
            
            if let to = to {
                let query = to.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789").inverted)
                let _ = (context.account.postbox.searchContacts(query: query)
                |> deliverOnMainQueue).start(next: { (peers, _) in
                    for case let peer as TelegramUser in peers {
                        if peer.phone == query {
                            continueWithPeer(peer.id)
                            break
                        }
                    }
                })
            } else {
                let controller = PeerSelectionController(context: context, filter: [.onlyWriteable, .excludeDisabled])
                controller.peerSelected = { [weak controller] peerId in
                    if let strongController = controller {
                        strongController.dismiss()
                        continueWithPeer(peerId)
                    }
                }
                if let navigationController = navigationController {
                    context.sharedContext.applicationBindings.dismissNativeController()
                    (navigationController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                }
            }
        case let .wallpaper(parameter):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var controller: OverlayStatusController?
            
            let signal: Signal<TelegramWallpaper, GetWallpaperError>
            var options: WallpaperPresentationOptions?
            var color: UIColor?
            var intensity: Int32?
            switch parameter {
                case let .slug(slug, wallpaperOptions, patternColor, patternIntensity):
                    signal = getWallpaper(account: context.account, slug: slug)
                    options = wallpaperOptions
                    color = patternColor
                    intensity = patternIntensity
                    controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                    present(controller!, nil)
                case let .color(color):
                    signal = .single(.color(Int32(color.rgb)))
            }
            
            let _ = (signal
            |> deliverOnMainQueue).start(next: { [weak controller] wallpaper in
                controller?.dismiss()
                let galleryController = WallpaperGalleryController(context: context, source: .wallpaper(wallpaper, options, color, intensity, nil))
                present(galleryController, nil)
            }, error: { [weak controller] error in
                controller?.dismiss()
            })
            dismissInput()
    }
}
