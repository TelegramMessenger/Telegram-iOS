import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import UrlEscaping
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

func voiceChatTitleEditController(
    context: AccountContext,
    forceTheme: PresentationTheme?,
    title: String,
    text: String,
    placeholder: String,
    doneButtonTitle: String? = nil,
    value: String?,
    maxLength: Int,
    apply: @escaping (String?) -> Void
) -> ViewController {
    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
    if let forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    let strings = presentationData.strings

    let inputState = AlertInputFieldComponent.ExternalState()

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))

    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                initialValue: value,
                placeholder: placeholder,
                characterLimit: maxLength,
                hasClearButton: true,
                isInitiallyFocused: true,
                externalState: inputState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))

    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: doneButtonTitle ?? strings.Common_Done, type: .default, action: {
                applyImpl?()
            })
        ],
        updatedPresentationData: (presentationData, .single(presentationData))
    )
    applyImpl = {
        let previousValue = value ?? ""
        let newValue = inputState.value.trimmingCharacters(in: .whitespacesAndNewlines)
        apply(previousValue != newValue || value == nil ? newValue : nil)
    }
    return alertController
}

func voiceChatUserNameController(
    context: AccountContext,
    forceTheme: PresentationTheme?,
    title: String,
    firstNamePlaceholder: String,
    lastNamePlaceholder: String,
    doneButtonTitle: String? = nil,
    firstName: String?,
    lastName: String?,
    maxLength: Int,
    apply: @escaping ((String, String)?) -> Void
) -> ViewController {
    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
    if let forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    let strings = presentationData.strings

    let firstNameState = AlertInputFieldComponent.ExternalState()
    let lastNameState = AlertInputFieldComponent.ExternalState()

    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: title)
        )
    ))
    
    var nextImpl: (() -> Void)?
    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "firstName",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                initialValue: firstName,
                placeholder: firstNamePlaceholder,
                characterLimit: maxLength,
                hasClearButton: true,
                returnKeyType: .next,
                isInitiallyFocused: true,
                externalState: firstNameState,
                returnKeyAction: {
                    nextImpl?()
                }
            )
        )
    ))
    
    content.append(AnyComponentWithIdentity(
        id: "lastName",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                initialValue: lastName,
                placeholder: lastNamePlaceholder,
                characterLimit: maxLength,
                hasClearButton: true,
                isInitiallyFocused: false,
                externalState: lastNameState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))

    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: doneButtonTitle ?? strings.Common_Done, type: .default, action: {
                applyImpl?()
            })
        ],
        updatedPresentationData: (presentationData, .single(presentationData))
    )
    nextImpl = {
        lastNameState.activateInput()
    }
    applyImpl = {
        let previousFirstName = firstName ?? ""
        let previousLastName = lastName ?? ""
        let newFirstName = firstNameState.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLastName = lastNameState.value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if newFirstName.isEmpty {
            firstNameState.animateError()
            return
        }
                
        if previousFirstName != newFirstName || previousLastName != newLastName {
            apply((newFirstName, newLastName))
        } else {
            apply(nil)
        }
    }
    return alertController
}
