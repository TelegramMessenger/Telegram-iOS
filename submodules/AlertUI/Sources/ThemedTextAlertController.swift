import Foundation
import UIKit
import Display
import SwiftSignalKit

public final class AlertControllerContext {
    public let theme: AlertControllerTheme
    public let themeSignal: Signal<AlertControllerTheme, NoError>
    
    public init(theme: AlertControllerTheme, themeSignal: Signal<AlertControllerTheme, NoError>) {
        self.theme = theme
        self.themeSignal = themeSignal
    }
}

public func textAlertController(alertContext: AlertControllerContext, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true) -> AlertController {
    let controller = standardTextAlertController(theme: alertContext.theme, title: title, text: text, actions: actions, actionLayout: actionLayout, allowInputInset: allowInputInset, parseMarkdown: parseMarkdown, dismissOnOutsideTap: dismissOnOutsideTap)
    let presentationDataDisposable = alertContext.themeSignal.start(next: { [weak controller] theme in
        controller?.theme = theme
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }
    
    return controller
}

public func richTextAlertController(alertContext: AlertControllerContext, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, dismissAutomatically: Bool = true) -> AlertController {
    let theme = alertContext.theme
    
    var dismissImpl: (() -> Void)?
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            if dismissAutomatically {
                dismissImpl?()
            }
            action.action()
        })
    }, actionLayout: actionLayout, dismissOnOutsideTap: true), allowInputInset: allowInputInset)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    
    let presentationDataDisposable = alertContext.themeSignal.start(next: { [weak controller] theme in
        controller?.theme = theme
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }
    
    return controller
}
