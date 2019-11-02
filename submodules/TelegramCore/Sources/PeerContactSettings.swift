import Foundation
import Postbox
import TelegramApi

import SyncCore

extension PeerStatusSettings {
    init(apiSettings: Api.PeerSettings) {
        switch apiSettings {
            case let .peerSettings(flags):
                var result = PeerStatusSettings()
                if (flags & (1 << 1)) != 0 {
                    result.insert(.canAddContact)
                }
                if (flags & (1 << 0)) != 0 {
                    result.insert(.canReport)
                }
                if (flags & (1 << 2)) != 0 {
                    result.insert(.canBlock)
                }
                if (flags & (1 << 3)) != 0 {
                    result.insert(.canShareContact)
                }
                if (flags & (1 << 4)) != 0 {
                    result.insert(.addExceptionWhenAddingContact)
                }
                if (flags & (1 << 5)) != 0 {
                    result.insert(.canReportIrrelevantGeoLocation)
                }
                self = result
        }
    }
}
