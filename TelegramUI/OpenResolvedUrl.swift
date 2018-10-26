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

func openResolvedUrl(_ resolvedUrl: ResolvedUrl, account: Account, context: OpenURLContext = .generic, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)? = nil, present: (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void) {
    switch resolvedUrl {
        case let .externalUrl(url):
            openExternalUrl(account: account, context: context, url: url, presentationData: account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: account.telegramApplicationContext, navigationController: navigationController, dismissInput: dismissInput)
        case let .peer(peerId, navigation):
            if let peerId = peerId {
                openPeer(peerId, defaultNavigationForPeerId(peerId, navigation: navigation))
            } else {
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload):
            let controller = PeerSelectionController(account: account, filter: [.onlyWriteable, .onlyGroups])
            controller.peerSelected = { [weak controller] peerId in
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
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .socks5(username: username, password: password))
            }

            dismissInput()
            present(ProxyServerActionSheetController(account: account, theme: presentationData.theme, strings: presentationData.strings, server: server), nil)
    }
}
