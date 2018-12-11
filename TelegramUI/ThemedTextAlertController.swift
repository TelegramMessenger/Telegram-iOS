import Foundation
import Display
import TelegramCore

public func textAlertController(account: Account, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal) -> AlertController {
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    
    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: theme), title: title, text: text, actions: actions)
    _ = account.telegramApplicationContext.presentationData.start(next: { [weak controller] presentationData in
        if let strongController = controller {
            strongController.theme = AlertControllerTheme(presentationTheme: presentationData.theme)
        }
    })
    
    return controller
}
