import UIKit
import NGExtensions
import NGLocalization

public extension NGToast {
    class func showErrorToast(message: String?, from view: UIView? = nil) {
        showDefaultToast(
            backgroundColor: .ngRedAlert,
            image: UIImage(named: "ng.warning"),
            title: mapErrorDescription(message),
            from: view
        )
    }
    
    class func showCopiedToast(from view: UIView? = nil) {
        showDefaultToast(
            backgroundColor: .ngGreenOne,
            image: UIImage(named: "ng.toast.success"),
            title: ngLocalized("Nicegram.Alert.Copied"),
            from: view
        )
    }
    
    class func showSuccessToast(from view: UIView? = nil) {
        showDefaultToast(
            backgroundColor: .ngGreenOne,
            image: UIImage(named: "ng.toast.success"),
            title: ngLocalized("Nicegram.Alert.Success"),
            from: view
        )
    }
    
    class func showDefaultToast(backgroundColor: UIColor, image: UIImage?, title: String?, from view: UIView? = nil) {
        let toast = NGToast()
        
        let contentView = NGToastDefaultContentView()
        contentView.backgroundColor = backgroundColor
        contentView.display(image: image, title: title)
        toast.setContentView(contentView)
        
        if let view = view {
            toast.show(from: view)
        } else {
            toast.show()
        }
    }
}
