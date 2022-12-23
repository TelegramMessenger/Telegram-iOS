import UIKit

public class NicegramNavigationController: UINavigationController {
    
    public override func viewDidLoad() {
        self.interactivePopGestureRecognizer?.delegate = self
        self.delegate = self
        
        super.viewDidLoad()
    }
}

extension NicegramNavigationController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.viewControllers.count > 1
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension NicegramNavigationController: UINavigationControllerDelegate {
    public func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}

public func makeDefaultNavigationController() -> UINavigationController {
    let controller = NicegramNavigationController()
    controller.setNavigationBarHidden(true, animated: false)
    return controller
}
