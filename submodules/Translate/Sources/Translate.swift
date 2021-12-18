import Foundation
import UIKit
import Display
import AccountContext

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func translateText(context: AccountContext, text: String) {
    guard !text.isEmpty else {
        return
    }
    if #available(iOS 15.0, *) {
        let textView = UITextView()
        textView.text = text
        textView.isEditable = false
        if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController, let topController = navigationController.topViewController as? ViewController {
            topController.view.addSubview(textView)
            textView.selectAll(nil)
            textView.perform(NSSelectorFromString(["_", "trans", "late:"].joined(separator: "")), with: nil)
            
            DispatchQueue.main.async {
                textView.removeFromSuperview()
            }
        }
    }
}
