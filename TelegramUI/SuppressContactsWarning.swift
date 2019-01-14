import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore

func presentContactsWarningSuppression(account: Account, present: (ViewController, Any?) -> Void) {
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    present(textAlertController(account: account, title: presentationData.strings.Contacts_PermissionsSuppressWarningTitle, text: presentationData.strings.Contacts_PermissionsSuppressWarningText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Contacts_PermissionsKeepDisabled, action: {
        ApplicationSpecificNotice.setContactsPermissionWarning(postbox: account.postbox, value: Int32(Date().timeIntervalSince1970))
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Contacts_PermissionsEnable, action: {
        let _ = (DeviceAccess.authorizationStatus(account: account, subject: .contacts)
        |> take(1)
        |> deliverOnMainQueue).start(next: { status in
            switch status {
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .contacts, account: account)
                case .denied, .restricted:
                    account.telegramApplicationContext.applicationBindings.openSettings()
                default:
                    break
            }
        })
    })]), nil)
}
