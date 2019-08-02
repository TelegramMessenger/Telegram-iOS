import Foundation
import UIKit
import Display
import TelegramCore

public func textAlertController(context: AccountContextImpl, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: title, text: text, actions: actions)
    let presentationDataDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
        controller?.theme = AlertControllerTheme(presentationTheme: presentationData.theme)
    })
    controller.dismissed = {
        presentationDataDisposable.dispose()
    }
    
    return controller
}

public func richTextAlertController(context: AccountContextImpl, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal) -> AlertController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationTheme: presentationData.theme)
    
    var dismissImpl: (() -> Void)?
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout))
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
