import Foundation
import Display

private enum NotificationMuteOption {
    case `default`
    case enable
    case interval(Int32)
    case disable
}

func notificationMuteSettingsController(presentationData: PresentationData, updateSettings: @escaping (Int32?) -> Void) -> ViewController {
    let controller = ActionSheetController(presentationTheme: presentationData.theme)
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
        .default,
        .enable,
        .interval(1 * 60 * 60),
        .interval(8 * 60 * 60),
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
                    notificationAction(0)
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
    
    controller.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
    return controller
}
