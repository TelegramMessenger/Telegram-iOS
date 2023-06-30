import Foundation
import Postbox
import TelegramApi


extension MessageNotificationSettings {
    init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
        case let .peerNotifySettings(_, showPreviews, _, muteUntil, iosSound, _, desktopSound, storiesMuted, storiesHideSender, storiesIosSound, _, storiesDesktopSound):
            let sound: Api.NotificationSound?
            let storiesSound: Api.NotificationSound?
            #if os(iOS)
            sound = iosSound
            storiesSound = storiesIosSound
            #elseif os(macOS)
            sound = desktopSound
            storiesSound = storiesDesktopSound
            #endif
            
            let displayPreviews: Bool
            if let showPreviews = showPreviews, case .boolFalse = showPreviews {
                displayPreviews = false
            } else {
                displayPreviews = true
            }
            
            let storiesMutedValue: PeerStoryNotificationSettings.Mute
            if let storiesMuted = storiesMuted {
                storiesMutedValue = storiesMuted == .boolTrue ? .muted : .unmuted
            } else {
                storiesMutedValue = .default
            }
            
            var storiesHideSenderValue: PeerStoryNotificationSettings.HideSender
            if let storiesHideSender = storiesHideSender {
                storiesHideSenderValue = storiesHideSender == .boolTrue ? .hide : .show
            } else {
                storiesHideSenderValue = .default
            }
            
            self = MessageNotificationSettings(
                enabled: muteUntil == 0,
                displayPreviews: displayPreviews,
                sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault),
                storySettings: PeerStoryNotificationSettings(
                    mute: storiesMutedValue,
                    hideSender: storiesHideSenderValue,
                    sound: PeerMessageSound(apiSound: sound ?? .notificationSoundDefault)
                )
            )
        }
    }
}
