import UIKit

protocol ScanQRRouterInput: AnyObject {
    func routeToShareItems(items: [Any], sourceView: UIView?)
    func dismiss()
}

final class ScanQRRouter: ScanQRRouterInput {
    weak var parentViewController: ScanQRViewController?
    
    func routeToShareItems(items: [Any], sourceView: UIView?) {
        parentViewController?.presentShareSheet(items: items, sourceView: sourceView)
    }

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}
