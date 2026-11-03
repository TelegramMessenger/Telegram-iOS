import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting

private enum NotificationMuteOption {
    case `default`
    case enable
    case interval(Int32)
    case disable
}

public struct NotificationSoundSettings {
    public var value: PeerMessageSound?
    
    public init(value: PeerMessageSound? = nil) {
        self.value = value
    }
}

public func notificationMuteSettingsController(presentationData: PresentationData, notificationSoundList: NotificationSoundList?, notificationSettings: MessageNotificationSettings, soundSettings: NotificationSoundSettings?, openSoundSettings: @escaping () -> Void, updateSettings: @escaping (Int32?) -> Void) -> ViewController {
    let controller = ActionSheetController(presentationData: presentationData)
    let dismissAction: () -> Void = { [weak controller] in
        controller?.dismissAnimated()
    }
    let notificationAction: (Int32?) -> Void = { muteUntil in
        let muteInterval: Int32?
        if let muteUntil = muteUntil {
            if muteUntil <= 0 {
                muteInterval = 0
            } else if muteUntil == Int32.max {
                muteInterval = Int32.max
            } else {
                muteInterval = muteUntil
            }
        } else {
            muteInterval = nil
        }
        
        updateSettings(muteInterval)
    }
    
    let options: [NotificationMuteOption] = [
        .enable,
        .interval(1 * 60 * 60),
        .interval(2 * 24 * 60 * 60),
        .disable
    ]
    var items: [ActionSheetItem] = []
    for option in options {
        let item: ActionSheetButtonItem
        switch option {
            case .default:
                item = ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsDefault, action: {
                    dismissAction()
                    notificationAction(nil)
                })
                break
            case .enable:
                item = ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsEnable, action: {
                    dismissAction()
                    if notificationSettings.enabled {
                        notificationAction(nil)
                    } else {
                        notificationAction(0)
                    }
                })
            case let .interval(value):
                item = ActionSheetButtonItem(title: muteForIntervalString(strings: presentationData.strings, value: value), action: {
                    dismissAction()
                    notificationAction(value)
                })
            case .disable:
                item = ActionSheetButtonItem(title: presentationData.strings.UserInfo_NotificationsDisable, action: {
                    dismissAction()
                    notificationAction(Int32.max)
                })
        }
        items.append(item)
    }
    if let soundSettings = soundSettings {
        items.append(ActionSheetButtonItem(title: soundSettings.value.flatMap({ presentationData.strings.Notification_Exceptions_Sound(localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: $0)).string }) ?? presentationData.strings.GroupInfo_SetSound, action: {
            dismissAction()
            openSoundSettings()
        }))
    }
    
    controller.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
    ])
    return controller
}
