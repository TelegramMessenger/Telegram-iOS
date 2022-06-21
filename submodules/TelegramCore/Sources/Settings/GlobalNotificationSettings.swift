import Foundation
import Postbox
import TelegramApi


extension MessageNotificationSettings {
    init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
        case let .peerNotifySettings(_, showPreviews, _, muteUntil, iosSound, _, desktopSound):
            let sound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            #elseif os(macOS)
            sound = desktopSound
            #endif
            let displayPreviews: Bool
            if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                displayPreviews = false
            } else {
                displayPreviews = true
            }
            self = MessageNotificationSettings(enabled: muteUntil == 0, displayPreviews: displayPreviews, sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault))
        }
    }
}
