import Foundation
import TelegramCore
import Postbox
import Display

func openResolvedUrl(_ resolvedUrl: ResolvedUrl, account: Account, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, present: (ViewController, Any?) -> Void) {
    switch resolvedUrl {
        case let .externalUrl(url):
            openExternalUrl(account: account, url: url, presentationData: account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: account.telegramApplicationContext, navigationController: navigationController)
        case let .peer(peerId):
            openPeer(peerId, .chat(textInputState: nil, messageId: nil))
        case let .botStart(peerId, payload):
            openPeer(peerId, .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(peerId, payload):
            break
        case let .channelMessage(peerId, messageId):
            openPeer(peerId, .chat(textInputState: nil, messageId: messageId))
        case let .stickerPack(name):
            present(StickerPackPreviewController(account: account, stickerPack: .name(name)), nil)
        case let .instantView(webpage, anchor):
            navigationController?.pushViewController(InstantPageController(account: account, webPage: webpage, anchor: anchor))
        case let .join(link):
            present(JoinLinkPreviewController(account: account, link: link, navigateToPeer: { peerId in
                openPeer(peerId, .chat(textInputState: nil, messageId: nil))
            }), nil)
        case let .proxy(host, port, username, password):
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            let alertText: String
            if let username = username, let password = password {
                alertText = presentationData.strings.Settings_ApplyProxyAlertCredentials(host, "\(port)", username, password).0
            } else {
                alertText = presentationData.strings.Settings_ApplyProxyAlert(host, "\(port)").0
            }
            present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: alertText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                let _ = applyProxySettings(postbox: account.postbox, network: account.network, settings: ProxySettings(host: host, port: port, username: username, password: password, useForCalls: false)).start()
            })]), nil)
    }
}
