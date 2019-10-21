import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

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
