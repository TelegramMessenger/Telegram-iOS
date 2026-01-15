import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import TextFormat
import AccountContext
import PresentationDataUtils
import PasswordSetupUI
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

private func commitOwnershipTransferController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    present: @escaping (ViewController, Any?) -> Void,
    commit: @escaping (String) -> Signal<MessageActionCallbackResult, MessageActionCallbackError>,
    completion: @escaping (MessageActionCallbackResult) -> Void
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
            AlertTitleComponent(title: strings.OwnershipTransfer_EnterPassword)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.OwnershipTransfer_EnterPasswordText))
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
            .init(title: strings.OwnershipTransfer_Transfer, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false, isEnabled: doneIsEnabled, progress: doneInProgressPromise.get())
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        doneInProgressPromise.set(true)

        let _ = (commit(inputState.value)
        |> deliverOnMainQueue).start(next: { result in
            dismissImpl?()
            completion(result)
        }, error: { error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
            case .invalidPassword:
                inputState.animateError()
            case .limitExceeded:
                errorTextAndActions = (strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            case .userBlocked, .restricted:
                errorTextAndActions = (presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
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


public func ownershipTransferController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    initialError: MessageActionCallbackError,
    present: @escaping (ViewController, Any?) -> Void,
    commit: @escaping (String) -> Signal<MessageActionCallbackResult, MessageActionCallbackError>,
    completion: @escaping (MessageActionCallbackResult) -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var title: String? = strings.OwnershipTransfer_SecurityCheck
    var text = strings.OwnershipTransfer_SecurityRequirements
    
    var actions: [AlertScreen.Action] = [
        .init(title: strings.Common_OK, type: .default)
    ]
    switch initialError {
        case .requestPassword:
            return commitOwnershipTransferController(context: context, updatedPresentationData: updatedPresentationData, present: present, commit: commit, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.OwnershipTransfer_ComeBackLater
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
        case .userBlocked, .restricted:
            title = nil
            text = presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted
        default:
            title = nil
            text = presentationData.strings.Login_UnknownError
    }
    
    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        title: title,
        text: text,
        actions: actions
    )
}
