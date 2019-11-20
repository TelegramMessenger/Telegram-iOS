import Foundation
import Display
import AlertUI
import AccountContext
import SwiftSignalKit

public func textAlertController(context: AccountContext, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true) -> AlertController {
    return textAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: context.sharedContext.currentPresentationData.with { $0 }), themeSignal: context.sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset)
}

public func richTextAlertController(context: AccountContext, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, dismissAutomatically: Bool = true) -> AlertController {
    return richTextAlertController(alertContext: AlertControllerContext(theme: AlertControllerTheme(presentationData: context.sharedContext.currentPresentationData.with { $0 }), themeSignal: context.sharedContext.presentationData |> map { presentationData in AlertControllerTheme(presentationData: presentationData) }), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, dismissAutomatically: dismissAutomatically)
}
