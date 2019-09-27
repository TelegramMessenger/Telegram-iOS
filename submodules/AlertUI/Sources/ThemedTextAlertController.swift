import Foundation
import UIKit
import Display
import AccountContext

public func textAlertController(context: AccountContext, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset)
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationTheme: presentationData.theme)
    })
    controller.dismissed = {
        presentationDataDisposable.dispose()
    }
    
    return controller
}

public func richTextAlertController(context: AccountContext, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, dismissAutomatically: Bool = true) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationTheme: presentationData.theme)
    
    var dismissImpl: (() -> Void)?
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            if dismissAutomatically {
                dismissImpl?()
            }
            action.action()
        })
    }, actionLayout: actionLayout), allowInputInset: allowInputInset)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationTheme: presentationData.theme)
    })
    controller.dismissed = {
        presentationDataDisposable.dispose()
    }
    
    return controller
}
