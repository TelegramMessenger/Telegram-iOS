import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import AlertUI
import PresentationDataUtils
import CountrySelectionUI
import PhoneNumberFormat
import CoreTelephony
import MessageUI
import AuthorizationUI

public func ChangePhoneNumberController(context: AccountContext) -> ViewController {
    var dismissImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let requestDisposable = MetaDisposable()
    let changePhoneDisposable = MetaDisposable()
    
    let controller = AuthorizationSequencePhoneEntryController(sharedContext: context.sharedContext, account: nil, countriesConfiguration: context.currentCountriesConfiguration.with { $0 }, isTestingEnvironment: false, otherAccountPhoneNumbers: (nil, []), network: context.account.network, presentationData: presentationData, openUrl: { _ in }, back: {
        dismissImpl?()
    })
    controller.loginWithNumber = { [weak controller] phoneNumber, _ in
        controller?.inProgress = true
        
        requestDisposable.set((context.engine.accountData.requestChangeAccountPhoneNumberVerification(phoneNumber: phoneNumber)
        |> deliverOnMainQueue).start(next: { [weak controller] next in
            controller?.inProgress = false
            
            var dismissImpl: (() -> Void)?
            let codeController = AuthorizationSequenceCodeEntryController(presentationData: presentationData, back: {
                dismissImpl?()
            })
            codeController.loginWithCode = { [weak codeController] code in
                codeController?.inProgress = true
                
                changePhoneDisposable.set((context.engine.accountData.requestChangeAccountPhoneNumber(phoneNumber: phoneNumber, phoneCodeHash: next.hash, phoneCode: code)
                |> deliverOnMainQueue).start(error: { [weak codeController] error in
                    if case .invalidCode = error {
                        codeController?.animateError(text: presentationData.strings.Login_WrongCodeError)
                    } else {
                        var resetCode = false
                        let text: String
                        switch error {
                            case .generic:
                                text = presentationData.strings.Login_UnknownError
                            case .invalidCode:
                                resetCode = true
                                text = presentationData.strings.Login_InvalidCodeError
                            case .codeExpired:
                                resetCode = true
                                text = presentationData.strings.Login_CodeExpiredError
                            case .limitExceeded:
                                resetCode = true
                                text = presentationData.strings.Login_CodeFloodError
                        }
                        
                        if resetCode {
                            codeController?.resetCode()
                        }
                        
                        codeController?.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }, completed: { [weak codeController] in
                    codeController?.present(OverlayStatusController(theme: presentationData.theme, type: .success), in: .window(.root))
                    
                    let _ = dismissServerProvidedSuggestion(account: context.account, suggestion: .validatePhoneNumber).start()
                    
                    if let navigationController = codeController?.navigationController as? NavigationController {
                        var viewControllers = navigationController.viewControllers
                        viewControllers.removeAll(where: { c in
                            if c is AuthorizationSequencePhoneEntryController {
                                return true
                            } else if c is AuthorizationSequenceCodeEntryController {
                                return true
                            } else {
                                return false
                            }
                        })
                        navigationController.setViewControllers(viewControllers, animated: true)
                    }
                }))
            }
            codeController.openFragment = { url in
                context.sharedContext.applicationBindings.openUrl(url)
            }
            codeController.updateData(number: formatPhoneNumber(context: context, number: phoneNumber), email: nil, codeType: next.type, nextType: nil, timeout: next.timeout, termsOfService: nil)
            dismissImpl = { [weak codeController] in
                codeController?.dismiss()
            }
            controller?.push(codeController)
        }, error: { [weak controller] error in
            controller?.inProgress = false
                            
            let text: String
            var actions: [TextAlertAction] = []
            switch error {
            case .limitExceeded:
                text = presentationData.strings.Login_CodeFloodError
                actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {}))
            case .invalidPhoneNumber:
                text = presentationData.strings.Login_InvalidPhoneError
                actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {}))
            case .phoneNumberOccupied:
                text = presentationData.strings.ChangePhone_ErrorOccupied(formatPhoneNumber(context: context, number: phoneNumber)).string
                actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {}))
            case .phoneBanned:
                text = presentationData.strings.Login_PhoneBannedError
                actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {}))
                actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Login_PhoneNumberHelp, action: { [weak controller] in
                    let formattedNumber = formatPhoneNumber(context: context, number: phoneNumber)
                    let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                    let systemVersion = UIDevice.current.systemVersion
                    let locale = Locale.current.identifier
                    let carrier = CTCarrier()
                    let mnc = carrier.mobileNetworkCode ?? "none"
                    
                    if MFMailComposeViewController.canSendMail() {
                        let composeController = MFMailComposeViewController()
                        composeController.setToRecipients(["login@stel.com"])
                        composeController.setSubject(presentationData.strings.Login_PhoneBannedEmailSubject(formattedNumber).string)
                        composeController.setMessageBody(presentationData.strings.Login_PhoneBannedEmailBody(formattedNumber, appVersion, systemVersion, locale, mnc).string, isHTML: false)
                        composeController.mailComposeDelegate = controller
                        
                        controller?.view.window?.rootViewController?.present(composeController, animated: true, completion: nil)
                    } else {
                        controller?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }))
            case .generic:
                text = presentationData.strings.Login_UnknownError
                actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {}))
            }
            
            controller?.dismissConfirmation()
            controller?.present(textAlertController(context: context, title: nil, text: text, actions: actions), in: .window(.root))
        }))
    }
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    Queue.mainQueue().justDispatch {
        controller.updateData(countryCode: AuthorizationSequenceController.defaultCountryCode(), countryName: nil, number: "")
        controller.updateCountryCode()
    }
    
    return controller
}
