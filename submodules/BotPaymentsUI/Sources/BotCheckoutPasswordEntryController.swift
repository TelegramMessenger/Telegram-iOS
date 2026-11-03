import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

func botCheckoutPasswordEntryController(context: AccountContext, strings: PresentationStrings, passwordTip: String?, cartTitle: String, period: Int32, requiresBiometrics: Bool, completion: @escaping (TemporaryTwoStepPasswordToken) -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    let inputState = AlertInputFieldComponent.ExternalState()
    let doneInProgressPromise = ValuePromise<Bool>(false)
    let doneIsEnabled: Signal<Bool, NoError> = combineLatest(inputState.valueSignal, doneInProgressPromise.get())
    |> map { value, isInProgress in
        return !value.isEmpty && !isInProgress
    }

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Checkout_PasswordEntry_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Checkout_PasswordEntry_Text(cartTitle).string))
        )
    ))

    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                placeholder: passwordTip ?? "",
                isSecureTextEntry: true,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                isInitiallyFocused: true,
                externalState: inputState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))

    var isVerifying = false
    let disposable = MetaDisposable()
    var dismissImpl: (() -> Void)?
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Checkout_PasswordEntry_Pay, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false, isEnabled: doneIsEnabled, progress: doneInProgressPromise.get())
        ],
        updatedPresentationData: (initial: presentationData, signal: context.sharedContext.presentationData)
    )
    alertController.dismissed = { _ in
        disposable.dispose()
    }

    applyImpl = {
        let password = inputState.value
        guard !isVerifying, !password.isEmpty else {
            return
        }

        isVerifying = true
        doneInProgressPromise.set(true)

        disposable.set((context.engine.auth.requestTemporaryTwoStepPasswordToken(password: password, period: period, requiresBiometrics: requiresBiometrics)
        |> deliverOnMainQueue).start(next: { token in
            completion(token)
            dismissImpl?()
        }, error: { _ in
            inputState.animateError()
            isVerifying = false
            doneInProgressPromise.set(false)
        }))
    }
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    return alertController
}
