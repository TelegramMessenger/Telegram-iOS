import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

extension TelegramTheme {
    convenience init?(apiTheme: Api.Theme) {
        switch apiTheme {
            case let .theme(flags, id, accessHash, slug, title, document, installCount):
                self.init(id: id, accessHash: accessHash, slug: slug, title: title, file: document.flatMap(telegramMediaFileFromApiDocument), isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, installCount: installCount)
            default:
                return nil
        }
    }
}
