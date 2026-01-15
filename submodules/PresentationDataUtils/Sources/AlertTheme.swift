import Foundation
import Display
import AlertUI
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import AlertComponent

public func textAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    forceTheme: PresentationTheme? = nil,
    title: String?,
    text: String,
    actions: [TextAlertAction],
    actionLayout: TextAlertContentActionLayout = .horizontal,
    allowInputInset: Bool = true,
    parseMarkdown: Bool = false,
    dismissOnOutsideTap: Bool = true,
    linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil
) -> ViewController {
    return textAlertController(sharedContext: context.sharedContext, updatedPresentationData: updatedPresentationData, forceTheme: forceTheme, title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, parseMarkdown: parseMarkdown, dismissOnOutsideTap: dismissOnOutsideTap, linkAction: linkAction)
}

public func textAlertController(
    sharedContext: SharedAccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    forceTheme: PresentationTheme? = nil,
    title: String?,
    text: String,
    actions: [TextAlertAction],
    actionLayout: TextAlertContentActionLayout = .horizontal,
    allowInputInset: Bool = true,
    parseMarkdown: Bool = false,
    dismissOnOutsideTap: Bool = true,
    linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil
) -> ViewController {
    var presentationData = updatedPresentationData?.initial ?? sharedContext.currentPresentationData.with { $0 }
    if let forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    let updatedPresentationDataSignal = (updatedPresentationData?.signal ?? sharedContext.presentationData) |> map {
        presentationData in
        var presentationData = presentationData
        if let forceTheme = forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        return presentationData
    }
    
    let mappedActions: [AlertScreen.Action] = actions.map { action in
        let mappedType: AlertScreen.Action.ActionType
        switch action.type {
        case .genericAction:
            mappedType = .generic
        case .defaultAction:
            mappedType = .default
        case .destructiveAction:
            mappedType = .destructive
        case .defaultDestructiveAction:
            mappedType = .defaultDestructive
        }
        return AlertScreen.Action(
            title: action.title,
            type: mappedType,
            action: action.action
        )
    }
    
    let controller = AlertScreen(
        configuration: AlertScreen.Configuration(
            actionAlignment: actionLayout == .vertical ? .vertical : .default,
            dismissOnOutsideTap: dismissOnOutsideTap,
            allowInputInset: allowInputInset
        ),
        title: title,
        text: text,
        textAction: { attributes in
            linkAction?(attributes, 0)
        },
        actions: mappedActions,
        updatedPresentationData: (initial: presentationData, signal: updatedPresentationDataSignal)
    )
    return controller
}

public func richTextAlertController(
    context: AccountContext,
    title: NSAttributedString?,
    text: NSAttributedString,
    actions: [TextAlertAction],
    actionLayout: TextAlertContentActionLayout = .horizontal,
    allowInputInset: Bool = true,
    dismissAutomatically: Bool = true
) -> AlertController {
    return richTextAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: context.sharedContext.currentPresentationData.with { $0 }), themeSignal: context.sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, dismissAutomatically: dismissAutomatically)
}

public func textWithEntitiesAlertController(
    context: AccountContext,
    title: NSAttributedString?,
    text: NSAttributedString,
    actions: [TextAlertAction],
    actionLayout: TextAlertContentActionLayout = .horizontal,
    allowInputInset: Bool = true,
    dismissAutomatically: Bool = true
) -> AlertController {
    return textWithEntitiesAlertController(
        alertContext: AlertControllerContext(
            theme: AlertControllerTheme(presentationData: context.sharedContext.currentPresentationData.with { $0 }),
            themeSignal: context.sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }
        ),
        title: title,
        text: text,
        actions: actions,
        actionLayout: actionLayout,
        allowInputInset: allowInputInset,
        dismissAutomatically: dismissAutomatically
    )
}

