import NGCore
import NGToast
import UIKit

public struct ToastState {
    public let image: UIImage?
    public let title: String?
    public let backgroundColor: UIColor
    
    init(image: UIImage?, title: String?, backgroundColor: UIColor) {
        self.image = image
        self.title = title
        self.backgroundColor = backgroundColor
    }
}

public struct Toasts {
    public static func show(_ state: ToastState) {
        DispatchQueue.main.async {
            let toast = NGToast()
            
            let contentView = NGToastDefaultContentView()
            contentView.backgroundColor = state.backgroundColor
            contentView.display(image: state.image, title: state.title)
            toast.setContentView(contentView)
            
            toast.show()
        }
    }
}

public extension ToastState {
    static func success() -> ToastState {
        return ToastState(
            image: UIImage(named: "ng.toast.success"),
            title: ngLocalized("Nicegram.Alert.Success"),
            backgroundColor: .ngGreenOne
        )
    }
    
    static func error(message: String) -> ToastState {
        return ToastState(
            image: UIImage(named: "ng.warning"),
            title: message,
            backgroundColor: .ngRedAlert
        )
    }
    
    static func error(_ error: Error) -> ToastState {
        return ToastState.error(message: error.localizedDescription)
    }
}
