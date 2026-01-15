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
import MultilineTextComponent
import BalancedTextComponent
import TextFieldComponent
import ComponentDisplayAdapters
import TextFormat
import ComponentFlow
import AlertComponent
import AlertMultilineInputFieldComponent

public func factCheckAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    value: String,
    entities: [MessageTextEntity],
    apply: @escaping (String, [MessageTextEntity]) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let inputState = AlertMultilineInputFieldComponent.ExternalState()
    
    let doneIsEnabled: Signal<Bool, NoError>
    if !value.isEmpty {
        doneIsEnabled = .single(true)
    } else {
        doneIsEnabled = inputState.valueSignal
        |> map { value in
            return !value.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var characterLimit: Int = 1024
    if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["factcheck_length_limit"] as? Double {
        characterLimit = Int(value)
    }
    
    let initialValue = chatInputStateStringWithAppliedEntities(value, entities: entities)
    
    var presentImpl: ((ViewController) -> Void)?
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.FactCheck_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertMultilineInputFieldComponent(
                context: context,
                initialValue: initialValue,
                placeholder: strings.FactCheck_Placeholder,
                characterLimit: characterLimit,
                formatMenuAvailability: .available([.bold, .italic]),
                emptyLineHandling: .oneConsecutive,
                isInitiallyFocused: true,
                externalState: inputState,
                present: { c in
                    presentImpl?(c)
                }
            )
        )
    ))
    
    let doneIsRemove: Signal<Bool, NoError>
    if !value.isEmpty {
        doneIsRemove = inputState.valueSignal
        |> map { value in
            return value.string.isEmpty
        }
        |> distinctUntilChanged
    } else {
        doneIsRemove = .single(false)
    }
    
    let actionsSignal: Signal<[AlertScreen.Action], NoError> = doneIsRemove
    |> map { doneIsRemove in
        var actions: [AlertScreen.Action] = []
        actions.append(.init(title: strings.Common_Cancel))
        
        let doneTitle: String = doneIsRemove ? strings.FactCheck_Remove : strings.Common_Done
        let doneType: AlertScreen.Action.ActionType = doneIsRemove ? .defaultDestructive : .default
        actions.append(
            .init(id: "done", title: doneTitle, type: doneType, action: {
                let (text, entities) = inputState.textAndEntities
                apply(text, entities)
            }, isEnabled: doneIsEnabled)
        )
        
        return actions
    }
    
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }

    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        contentSignal: .single(content),
        actionsSignal: actionsSignal,
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    presentImpl = { [weak alertController] c in
        alertController?.present(c, in: .window(.root))
    }
    return alertController
}
