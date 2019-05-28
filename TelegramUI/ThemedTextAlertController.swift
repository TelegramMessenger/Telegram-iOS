import Foundation
import Display
import TelegramCore

public func textAlertController(context: AccountContext, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal) -> AlertController {
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
