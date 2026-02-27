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
import AlertMultilineInputFieldComponent

public func chatTextLinkEditController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    text: String,
    link: String?,
    apply: @escaping (String?) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let inputState = AlertMultilineInputFieldComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: link != nil ? strings.TextFormat_EditLinkTitle : strings.TextFormat_AddLinkTitle)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.TextFormat_AddLinkText(text).string))
        )
    ))
    
    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertMultilineInputFieldComponent(
                context: context,
                initialValue: link.flatMap { NSAttributedString(string: $0) },
                placeholder: strings.TextFormat_AddLinkPlaceholder,
                returnKeyType: .done,
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
            .init(title: strings.Common_Done, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false)
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        let updatedLink = explicitUrl(inputState.value.string)
        if !updatedLink.isEmpty && isValidUrl(updatedLink, validSchemes: ["http": true, "https": true, "tg": false, "ton": false, "tonsite": true]) {
            dismissImpl?()
            apply(updatedLink)
        } else if inputState.value.string.isEmpty {
            dismissImpl?()
            apply("")
        } else {
            inputState.animateError()
        }
    }
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    return alertController
}
