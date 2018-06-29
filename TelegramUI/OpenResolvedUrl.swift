import Foundation
import TelegramCore
import Postbox
import Display
import SwiftSignalKit

func openResolvedUrl(_ resolvedUrl: ResolvedUrl, account: Account, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, present: (ViewController, Any?) -> Void) {
    switch resolvedUrl {
        case let .externalUrl(url):
            openExternalUrl(account: account, url: url, presentationData: account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: account.telegramApplicationContext, navigationController: navigationController)
        case let .peer(peerId):
            openPeer(peerId, .chat(textInputState: nil, messageId: nil))
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload):
            let controller = PeerSelectionController(account: account, filter: [.onlyWriteable, .onlyGroups])
            controller.peerSelected = { [weak controller] peerId in
                let _ = (requestStartBotInGroup(account: account, botPeerId: botPeerId, groupPeerId: peerId, payload: payload)
                |> deliverOnMainQueue).start(completed: {
                    if let navigationController = navigationController {
                        navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(peerId))
                    }
                    controller?.dismiss()
                })
            }
            present(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
        case let .channelMessage(peerId, messageId):
            openPeer(peerId, .chat(textInputState: nil, messageId: messageId))
        case let .stickerPack(name):
            present(StickerPackPreviewController(account: account, stickerPack: .name(name), parentNavigationController: navigationController), nil)
        case let .instantView(webpage, anchor):
            navigationController?.pushViewController(InstantPageController(account: account, webPage: webpage, anchor: anchor))
        case let .join(link):
            present(JoinLinkPreviewController(account: account, link: link, navigateToPeer: { peerId in
                openPeer(peerId, .chat(textInputState: nil, messageId: nil))
            }), nil)
        case let .proxy(host, port, username, password, secret):
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: port, connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: port, connection: .socks5(username: username, password: password))
            }
            navigationController?.view.window?.endEditing(true)
            present(ProxyServerActionSheetController(account: account, theme: presentationData.theme, strings: presentationData.strings, server: server), nil)
    }
}
