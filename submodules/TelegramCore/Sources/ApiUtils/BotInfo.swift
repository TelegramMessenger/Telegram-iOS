import Foundation
import Postbox
import TelegramApi

extension BotMenuButton {
    init(apiBotMenuButton: Api.BotMenuButton) {
        switch apiBotMenuButton {
            case .botMenuButtonCommands, .botMenuButtonDefault:
                self = .commands
            case let .botMenuButton(text, url):
                self = .webView(text: text, url: url)
        }
    }
}

extension BotInfo {
    convenience init(apiBotInfo: Api.BotInfo) {
        switch apiBotInfo {
            case let .botInfo(_, description, commands, menuButton):
                self.init(description: description, photo: nil, commands: commands.map { command in
                    switch command {
                    case let .botCommand(command, description):
                        return BotCommand(text: command, description: description)
                    }
                }, menuButton: BotMenuButton(apiBotMenuButton: menuButton))
        }
    }
}
