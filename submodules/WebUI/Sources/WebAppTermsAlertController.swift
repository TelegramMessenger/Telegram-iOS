import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import ComponentFlow
import AlertComponent
import AlertCheckComponent

public func webAppTermsAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    bot: AttachMenuBot,
    completion: @escaping (Bool) -> Void,
    dismissed: @escaping () -> Void = {}
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.WebApp_DisclaimerTitle)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.WebApp_DisclaimerText))
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "check",
        component: AnyComponent(
            AlertCheckComponent(title: strings.WebApp_DisclaimerAgree, initialValue: false, externalState: checkState, linkAction: {
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: strings.WebApp_Disclaimer_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
            })
        )
    ))
    
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: content,
        actions: [
            .init(title: strings.WebApp_DisclaimerContinue, type: .default, action: {
                completion(checkState.value)
            }, isEnabled: checkState.valueSignal),
            .init(title: strings.Common_Cancel)
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    return alertController
}
