import UIKit
import NGExtensions
import NGLocalization
import NGTheme

public extension NGAlertController {
    class func showRetryableErrorAlert(message: String?, ngTheme: NGThemeColors, from vc: UIViewController, onRetry: (() -> ())?) {
        showErrorAlert(message: message, ngTheme: ngTheme, from: vc) { alert in
            alert.addAction(title: ngLocalized("Nicegram.Alert.TryAgain"), style: .preferred(ngTheme: ngTheme), execute: onRetry)
        }
    }
    
    class func showErrorAlert(message: String?, ngTheme: NGThemeColors, from vc: UIViewController, configureActions: ((NGAlertController) -> ())? = nil) {
        showDefaultAlert(
            title: nil,
            image: UIImage(named: "ng.error.alert"),
            subtitle: mapErrorDescription(message).attributedString,
            description: nil,
            ngTheme: ngTheme,
            from: vc
        ) { alert in
            alert.addAction(title: ngLocalized("Nicegram.Alert.Ok"), style: .preferred(ngTheme: ngTheme), execute: nil)
            configureActions?(alert)
        }
    }
    
    class func showDefaultAlert(title: NSAttributedString?, image: UIImage?, subtitle: NSAttributedString?, description: NSAttributedString?, ngTheme: NGThemeColors, from vc: UIViewController, configureActions: ((NGAlertController) -> ())) {
        let alert = NGAlertController(ngTheme: ngTheme)
        
        let contentView = NGAlertDefaultContentView(ngTheme: ngTheme)
        contentView.display(title: title, image: image, subtitle: subtitle, description: description)
        alert.setContentView(contentView)
        
        configureActions(alert)
        
        vc.present(alert, animated: true)
    }
}

private extension String {
    var attributedString: NSAttributedString {
        return NSAttributedString(string: self)
    }
}
                      
                      
