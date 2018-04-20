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
            present(ProxyServerActionSheetController(account: account, theme: presentationData.theme, strings: presentationData.strings, server: ProxyServerSettings(host: host, port: port, username: username, password: password)), nil)
    }
}
