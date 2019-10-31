import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension ExportedInvitation {
    init?(apiExportedInvite: Api.ExportedChatInvite) {
        switch apiExportedInvite {
            case .chatInviteEmpty:
                return nil
            case let .chatInviteExported(link):
                self = ExportedInvitation(link: link)
        }
    }
}
