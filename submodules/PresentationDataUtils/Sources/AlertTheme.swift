import Foundation
import Display
import AlertUI
import AccountContext
import SwiftSignalKit
import TelegramPresentationData

public func textAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true) -> AlertController {
    return textAlertController(sharedContext: context.sharedContext, updatedPresentationData: updatedPresentationData, forceTheme: forceTheme, title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, parseMarkdown: parseMarkdown, dismissOnOutsideTap: dismissOnOutsideTap)
}

public func textAlertController(sharedContext: SharedAccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, forceTheme: PresentationTheme? = nil, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true) -> AlertController {
    var presentationData = updatedPresentationData?.initial ?? sharedContext.currentPresentationData.with { $0 }
    if let forceTheme = forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    return textAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: presentationData), themeSignal: (updatedPresentationData?.signal ?? sharedContext.presentationData) |> map {
        presentationData in
        var presentationData = presentationData
        if let forceTheme = forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        return AlertControllerTheme(presentationData: presentationData)
    }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, parseMarkdown: parseMarkdown, dismissOnOutsideTap: dismissOnOutsideTap)
}

public func textAlertController(sharedContext: SharedAccountContext, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, dismissOnOutsideTap: Bool = true) -> AlertController {
    return textAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: sharedContext.currentPresentationData.with { $0 }), themeSignal: sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, dismissOnOutsideTap: dismissOnOutsideTap)
}

public func richTextAlertController(context: AccountContext, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, dismissAutomatically: Bool = true) -> AlertController {
    return richTextAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: context.sharedContext.currentPresentationData.with { $0 }), themeSignal: context.sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, dismissAutomatically: dismissAutomatically)
}
