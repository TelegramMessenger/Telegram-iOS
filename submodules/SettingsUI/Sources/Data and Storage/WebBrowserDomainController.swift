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

public func webBrowserDomainController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, apply: @escaping (String?) -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let inputState = AlertInputFieldComponent.ExternalState()
    
    let doneIsEnabled: Signal<Bool, NoError> = inputState.valueSignal
    |> map { value in
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    let doneInProgressPromise = ValuePromise<Bool>(false)
                
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.WebBrowser_Exceptions_Create_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebBrowser_Exceptions_Create_Text))
        )
    ))
        
    let domainRegex = try? NSRegularExpression(pattern: "^(https?://)?([a-zA-Z0-9-]+\\.?)*([a-zA-Z]*)?(:)?(/)?$", options: [])
    let pathRegex = try? NSRegularExpression(pattern: "^(https?://)?([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,6}/", options: [])
    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                initialValue: nil,
                placeholder: strings.WebBrowser_Exceptions_Create_Placeholder,
                characterLimit: nil,
                hasClearButton: true,
                keyboardType: .URL,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                isInitiallyFocused: true,
                externalState: inputState,
                shouldChangeText: { updatedText in
                    guard let domainRegex, let pathRegex else {
                        return true
                    }
                    let domainMatches = domainRegex.matches(in: updatedText, options: [], range: NSRange(location: 0, length: updatedText.utf16.count))
                    let pathMatches = pathRegex.matches(in: updatedText, options: [], range: NSRange(location: 0, length: updatedText.utf16.count))
                    if domainMatches.count > 0, pathMatches.count == 0 {
                        return true
                    } else {
                        return false
                    }
                },
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
    
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Common_Done, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false, isEnabled: doneIsEnabled, progress: doneInProgressPromise.get())
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        let updatedLink = explicitUrl(inputState.value)
        if !updatedLink.isEmpty && isValidUrl(updatedLink, validSchemes: ["http": true, "https": true]) {
            doneInProgressPromise.set(true)
            apply(updatedLink)
        } else {
            inputState.animateError()
        }
    }
    return alertController
}
