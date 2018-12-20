import Foundation
import SwiftSignalKit
import TelegramCore
import Display

func openAddContact(account: Account, firstName: String = "", lastName: String = "", phoneNumber: String, label: String = "_$!<Mobile>!$_", present: @escaping (ViewController, Any?) -> Void, completed: @escaping () -> Void = {}) {
    let _ = (DeviceAccess.authorizationStatus(account: account, subject: .contacts)
    |> take(1)
    |> deliverOnMainQueue).start(next: { value in
        switch value {
            case .allowed:
                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: label, value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
                present(deviceContactInfoController(account: account, subject: .create(peer: nil, contactData: contactData, completion: { _, _,_  in }), completed: completed), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .notDetermined:
                DeviceAccess.authorizeAccess(to: .contacts)
            default:
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                    account.telegramApplicationContext.applicationBindings.openSettings()
                })]), nil)
        }
    })
}
