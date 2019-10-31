import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension MessageNotificationSettings {
    init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
            case .peerNotifySettingsEmpty:
                self = .defaultSettings
            case let .peerNotifySettings(_, showPreviews, _, muteUntil, sound):
                let displayPreviews: Bool
                if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                    displayPreviews = false
                } else {
                    displayPreviews = true
                }
                self = MessageNotificationSettings(enabled: muteUntil == 0, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? "2"))
        }
    }
}
