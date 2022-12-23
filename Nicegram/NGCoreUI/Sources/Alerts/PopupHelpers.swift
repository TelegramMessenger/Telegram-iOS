import NGAlert
import NGCore
import NGTheme
import UIKit

public struct AlertState {
    let title: String?
    let description: String
    let image: UIImage?
    let actions: [Action]
    
    public init(title: String? = nil, description: String, image: UIImage?, actions: [Action]) {
        self.title = title
        self.description = description
        self.image = image
        self.actions = actions
    }
    
    public struct Action {
        let title: String
        let style: ActionStyle
        let handler: (() -> Void)?
        
        public init(title: String, style: ActionStyle, handler: (() -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }
    
    public enum ActionStyle {
        case preferred
        case gradientAction
        case cancel
    }
}

public struct Alerts {
    public static func show(_ state: AlertState) {
        DispatchQueue.main.async {
            let ngTheme = NGThemeColors(theme: .dark)
            
            let alert = NGAlertController(ngTheme: ngTheme)
            
            let contentView = NGAlertDefaultContentView(ngTheme: ngTheme)
            contentView.display(
                title: state.title?.attributedString,
                image: state.image,
                subtitle: nil,
                description: state.description.attributedString
            )
            alert.setContentView(contentView)
            
            for action in state.actions {
                let style: NGAlertController.ActionStyle
                switch action.style {
                case .preferred:
                    style = .preferred(ngTheme: ngTheme)
                case .gradientAction:
                    style = .gradientAction()
                case .cancel:
                    style = .yes(ngTheme: ngTheme)
                }
                alert.addAction(title: action.title, style: style, execute: action.handler)
            }
            
            if let topController = UIApplication.topViewController {
                topController.present(alert, animated: true)
            }
        }
    }
}

private extension String {
    var attributedString: NSAttributedString {
        return NSAttributedString(string: self)
    }
}

//  MARK: - TopViewController

private extension UIApplication {
    static var topViewController: UIViewController? {
        return shared.windows.first?.rootViewController?.visibleViewController
    }
}

private extension UIViewController {
    var visibleViewController: UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.topViewController?.visibleViewController
        } else if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.visibleViewController
        } else if let presentedViewController = presentedViewController {
            return presentedViewController.visibleViewController
        } else {
            return self
        }
    }
}
