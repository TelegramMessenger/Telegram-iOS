import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

public func quickReplyNameAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, text: String, subtext: String, value: String?, characterLimit: Int, apply: @escaping (String?) -> Void) -> (controller: AlertScreen, displayError: (String) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let inputState = AlertInputFieldComponent.ExternalState()
    
    var applyImpl: (() -> Void)?
    
    let errorPromise = ValuePromise<String?>(nil)
    let contentSignal = errorPromise.get()
    |> map { error in
        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
        content.append(AnyComponentWithIdentity(
            id: "title",
            component: AnyComponent(
                AlertTitleComponent(title: text)
            )
        ))
        if let error {
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(error), color: .destructive)
                )
            ))
        } else {
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(subtext))
                )
            ))
        }
            
        content.append(AnyComponentWithIdentity(
            id: "input",
            component: AnyComponent(
                AlertInputFieldComponent(
                    context: context,
                    initialValue: nil,
                    placeholder: strings.QuickReply_ShortcutPlaceholder,
                    characterLimit: characterLimit,
                    hasClearButton: false,
                    keyboardType: .URL,
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
        
        return content
    }
        
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        contentSignal: contentSignal,
        actionsSignal: .single([
            .init(title: strings.Common_Cancel, action: {
                apply(nil)
            }),
            .init(title: strings.Common_Done, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false)
        ]),
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        apply(inputState.value)
    }
    
    let displayError = { [weak inputState] error in
        errorPromise.set(error)
        inputState?.animateError()
        HapticFeedback().error()
    }
    
    return (alertController, displayError)
}
