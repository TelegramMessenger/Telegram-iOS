import UIKit

protocol SpecialOfferRouterInput: AnyObject {
    func open(url: URL)
    func dismiss()
}

final class SpecialOfferRouter: SpecialOfferRouterInput {
    weak var parentViewController: SpecialOfferViewController!
    
    func open(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.openURL(url)
        }
    }

    func dismiss() {
        parentViewController.dismiss(animated: true, completion: nil)
    }
}
