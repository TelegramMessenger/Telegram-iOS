import NGAuth
import NGSecondPhone
import UIKit

protocol HintRouterInput: AnyObject {
    func dismiss()
}

final class HintRouter: HintRouterInput {
    weak var parentViewController: HintViewController?

    func dismiss() {
        parentViewController?.dismiss(animated: false, completion: nil)
    }
}
