import Foundation
import Postbox
import TelegramApi

import SyncCore

extension BotInfo {
    convenience init(apiBotInfo: Api.BotInfo) {
        switch apiBotInfo {
        case let .botInfo(_, description, commands):
            self.init(description: description, commands: commands.map { command in
                switch command {
                case let .botCommand(command, description):
                    return BotCommand(text: command, description: description)
                }
            })
        }
    }
}
