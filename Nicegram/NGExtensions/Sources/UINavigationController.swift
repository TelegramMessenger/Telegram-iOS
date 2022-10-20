import UIKit

public extension UINavigationController {
    func popTo(_ vc: UIViewController, thenPush newVc: UIViewController, animated: Bool) {
        var viewControllers = viewControllers
        guard let currentIndex = viewControllers.firstIndex(of: vc) else { return }
        viewControllers = Array(viewControllers.prefix(currentIndex + 1))
        viewControllers.append(newVc)
        setViewControllers(viewControllers, animated: animated)
    }
}
