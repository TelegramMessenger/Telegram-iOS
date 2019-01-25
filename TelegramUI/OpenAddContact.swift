import Foundation
import SwiftSignalKit
import TelegramCore
import Display

func openAddContact(context: AccountContext, firstName: String = "", lastName: String = "", phoneNumber: String, label: String = "_$!<Mobile>!$_", present: @escaping (ViewController, Any?) -> Void, completed: @escaping () -> Void = {}) {
    let _ = (DeviceAccess.authorizationStatus(context: context, subject: .contacts)
    |> take(1)
    |> deliverOnMainQueue).start(next: { value in
        switch value {
            case .allowed:
                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: [DeviceContactPhoneNumberData(label: label, value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
                present(deviceContactInfoController(context: context, subject: .create(peer: nil, contactData: contactData, completion: { _, _,_  in }), completed: completed), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .notDetermined:
                DeviceAccess.authorizeAccess(to: .contacts)
            default:
                let presentationData = context.currentPresentationData.with { $0 }
                present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                    context.sharedContext.applicationBindings.openSettings()
                })]), nil)
        }
    })
}
