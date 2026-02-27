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
import AlertCheckComponent

public func chatAgeRestrictionAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    parentController: ViewController,
    completion: @escaping (Bool) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let checkState = AlertCheckComponent.ExternalState()
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.SensitiveContent_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.SensitiveContent_Text))
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "check",
        component: AnyComponent(
            AlertCheckComponent(title: strings.SensitiveContent_ShowAlways, initialValue: false, externalState: checkState)
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
            .init(title: strings.SensitiveContent_ViewAnyway, type: .default, action: {
                completion(checkState.value)
            }),
            .init(title: strings.Common_Cancel)
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    return alertController
}
