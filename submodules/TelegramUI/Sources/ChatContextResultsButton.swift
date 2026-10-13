import Foundation

import AccountContext
import ChatPresentationInterfaceState
import SwiftSignalKit
import TelegramCore

/// The button a bot can put above its inline results: `switch_pm` or `switch_webview` in
/// `messages.botResults`, `InlineQueryResultsButton` in the Bot API. It does not depend on how the
/// results are presented, so a gallery (`.media`) answer carries it exactly like a list answer.
enum ChatContextResultsButton {
    case switchPeer(ChatContextResultSwitchPeer)
    case webView(ChatContextResultWebView)

    init?(results: ChatContextResultCollection) {
        if let switchPeer = results.switchPeer {
            self = .switchPeer(switchPeer)
        } else if let webView = results.webView {
            self = .webView(webView)
        } else {
            return nil
        }
    }

    var title: String {
        switch self {
        case let .switchPeer(switchPeer):
            return switchPeer.text
        case let .webView(webView):
            return webView.text
        }
    }

    func activate(context: AccountContext, interfaceInteraction: ChatPanelInterfaceInteraction, botId: EnginePeer.Id) {
        switch self {
        case let .switchPeer(switchPeer):
            interfaceInteraction.botSwitchChatWithPayload(botId, switchPeer.startParam)
        case let .webView(webView):
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: botId))
            |> deliverOnMainQueue).startStandalone(next: { bot in
                if let bot {
                    interfaceInteraction.openWebView(webView.text, webView.url, true, .inline(bot: bot))
                }
            })
        }
    }
}
