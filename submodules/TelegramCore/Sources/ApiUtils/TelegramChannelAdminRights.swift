import Foundation
import Postbox
import TelegramApi


extension TelegramChatAdminRights {
    init?(apiAdminRights: Api.ChatAdminRights) {
        switch apiAdminRights {
            case let .chatAdminRights(flags):
                if flags == 0 {
                    return nil
                }
                let filteredFlags = flags & (~(1 << 12))
                self.init(rights: TelegramChatAdminRightsFlags(rawValue: filteredFlags))
        }
    }
    
    var apiAdminRights: Api.ChatAdminRights {
        var filteredFlags = self.rights.rawValue
        filteredFlags |= 1 << 12
        return .chatAdminRights(flags: filteredFlags)
    }
}
