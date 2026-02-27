import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import PasswordSetupUI
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

func confirmRevenueWithdrawalController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peerId: EnginePeer.Id,
    present: @escaping (ViewController, Any?) -> Void,
    completion: @escaping (String) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    let inputState = AlertInputFieldComponent.ExternalState()

    let doneIsEnabled: Signal<Bool, NoError> = inputState.valueSignal
    |> map { value in
        return !value.isEmpty
    }
    
    let doneInProgressPromise = ValuePromise<Bool>(false)
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Monetization_Withdraw_EnterPassword_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Monetization_Withdraw_EnterPassword_Text))
        )
    ))

    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                placeholder: strings.Channel_OwnershipTransfer_PasswordPlaceholder,
                isSecureTextEntry: true,
                isInitiallyFocused: true,
                externalState: inputState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))
    
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    
    var dismissImpl: (() -> Void)?
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Monetization_Withdraw_EnterPassword_Done, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false, isEnabled: doneIsEnabled, progress: doneInProgressPromise.get())
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        doneInProgressPromise.set(true)

        let _ = (context.engine.peers.requestStarsRevenueWithdrawalUrl(peerId: peerId, ton: true, amount: nil, password: inputState.value)
        |> deliverOnMainQueue).start(next: { url in
            dismissImpl?()
            completion(url)
        }, error: { error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
            case .invalidPassword:
                inputState.animateError()
            case .limitExceeded:
                errorTextAndActions = (strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            default:
                errorTextAndActions = (strings.Login_UnknownError, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            }
            doneInProgressPromise.set(false)

            if let (text, actions) = errorTextAndActions {
                dismissImpl?()
                present(textAlertController(context: context, title: nil, text: text, actions: actions), nil)
            }
        })
    }
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    return alertController
}


public func revenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, initialError: RequestStarsRevenueWithdrawalError, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var title: String? = strings.OwnershipTransfer_SecurityCheck
    var text = strings.Monetization_Withdraw_SecurityRequirements
    
    var actions: [AlertScreen.Action] = [
        .init(title: strings.Common_OK, type: .default)
    ]
    switch initialError {
    case .requestPassword:
        return confirmRevenueWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, present: present, completion: completion)
    case .twoStepAuthTooFresh, .authSessionTooFresh:
        text = text + strings.Monetization_Withdraw_ComeBackLater
    case .twoStepAuthMissing:
        actions = [
            .init(title: strings.OwnershipTransfer_SetupTwoStepAuth, type: .default, action: {
                let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }),
            .init(title: strings.Common_Cancel)
        ]
    default:
        title = nil
        text = strings.Login_UnknownError
    }
    
    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        title: title,
        text: text,
        actions: actions
    )
}
