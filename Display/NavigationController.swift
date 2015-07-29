import Foundation
import UIKit
import AsyncDisplayKit

public class NavigationController: NavigationControllerProxy, WindowContentController, UIGestureRecognizerDelegate {
    private var _navigationBar: NavigationBar?
    private var navigationTransitionCoordinator: NavigationTransitionCoordinator?
    
    public override init() {
        super.init()
        self._navigationBar = NavigationBar()
        self._navigationBar?.frame = CGRect(x: 0.0, y: 0.0, width: 320.0, height: 44.0)
        self._navigationBar?.proxy = self.navigationBar as? NavigationBarProxy
        self._navigationBar?.backPressed = { [weak self] in
            if self?.viewControllers.count > 1 {
                self?.popViewControllerAnimated(true)
            }
            return
        }
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        super.loadView()
        
        if let _navigationBar = self._navigationBar {
            self.navigationBar.superview?.insertSubview(_navigationBar.view, aboveSubview: self.navigationBar)
        }
        self.navigationBar.removeFromSuperview()
        
        self._navigationBar?.frame = navigationBarFrame(self.view.frame.size)
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: Selector("panGesture:"))
        panRecognizer.delegate = self
        panRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(panRecognizer)
        
        if self.topViewController != nil {
            self.topViewController?.view.frame = CGRect(origin: CGPoint(), size: self.view.frame.size)
        }
    }
    
    func panGesture(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case UIGestureRecognizerState.Began:
                if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                    let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                    let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                    
                    topController.viewWillDisappear(true)
                    let topView = topController.view
                    bottomController.viewWillAppear(true)
                    let bottomView = bottomController.view
                    
                    let navigationTransitionCoordinator = NavigationTransitionCoordinator(container: self.view, topView: topView, bottomView: bottomView, navigationBar: self._navigationBar!)
                    self.navigationTransitionCoordinator = navigationTransitionCoordinator
                    
                    self._navigationBar?.beginInteractivePopProgress(bottomController.navigationItem, evenMorePreviousItem: self.viewControllers.count >= 3 ? (self.viewControllers[self.viewControllers.count - 3] as UIViewController).navigationItem : nil)
                }
            case UIGestureRecognizerState.Changed:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                    let translation = recognizer.translationInView(self.view).x
                    navigationTransitionCoordinator.progress = max(0.0, min(1.0, translation / self.view.frame.width))
                }
            case UIGestureRecognizerState.Ended:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                    let velocity = recognizer.velocityInView(self.view).x
                    
                    if velocity > 1000 || navigationTransitionCoordinator.progress > 0.2 {
                        navigationTransitionCoordinator.animateCompletion(velocity, completion: {
                            self.navigationTransitionCoordinator = nil
                            
                            self._navigationBar?.endInteractivePopProgress()
                            
                            if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                                let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                                let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                                
                                topController.setIgnoreAppearanceMethodInvocations(true)
                                bottomController.setIgnoreAppearanceMethodInvocations(true)
                                self.popViewControllerAnimated(false)
                                topController.setIgnoreAppearanceMethodInvocations(false)
                                bottomController.setIgnoreAppearanceMethodInvocations(false)
                                
                                topController.viewDidDisappear(true)
                                bottomController.viewDidAppear(true)
                            }
                        })
                    }
                    else {
                        if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                            let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                            let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                            
                            topController.viewWillAppear(true)
                            bottomController.viewWillDisappear(true)
                        }
                        
                        navigationTransitionCoordinator.animateCancel({
                            self.navigationTransitionCoordinator = nil
                            
                            self._navigationBar?.endInteractivePopProgress()
                            
                            if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                                let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                                let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                                
                                topController.viewDidAppear(true)
                                bottomController.viewDidDisappear(true)
                            }
                        })
                    }
                }
            case .Cancelled:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                    if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                        let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                        let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                        
                        topController.viewWillAppear(true)
                        bottomController.viewWillDisappear(true)
                    }
                    
                    navigationTransitionCoordinator.animateCancel({
                        self.navigationTransitionCoordinator = nil
                        
                        if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                            let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                            let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                            
                            topController.viewDidAppear(true)
                            bottomController.viewDidDisappear(true)
                        }
                    })
                }
            default:
                break
        }
    }
    
    public override func pushViewController(viewController: UIViewController, animated: Bool) {
        var controllers = self.viewControllers
        controllers.append(viewController)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public override func popViewControllerAnimated(animated: Bool) -> UIViewController? {
        var controller: UIViewController?
        var controllers = self.viewControllers
        if controllers.count != 0 {
            controller = controllers[controllers.count - 1] as UIViewController
            controllers.removeAtIndex(controllers.count - 1)
            self.setViewControllers(controllers, animated: animated)
        }
        return controller
    }
    
    public override func setViewControllers(viewControllers: [UIViewController], animated: Bool) {
        if viewControllers.count > 0 {
            let topViewController = viewControllers[viewControllers.count - 1] as UIViewController
            
            if let controller = topViewController as? WindowContentController {
                controller.setViewSize(self.view.bounds.size, duration: 0.0)
            } else {
                topViewController.view.frame = CGRect(origin: CGPoint(), size: self.view.bounds.size)
            }
        }
        
        super.setViewControllers(viewControllers, animated: animated)
    }
    
    private func navigationBarFrame(size: CGSize) -> CGRect {
        let condensedBar = (size.height < size.width || size.height <= 320.0) && size.height < 768.0
        return CGRect(x: 0.0, y: 0.0, width: size.width, height: 20.0 + (size.height >= size.width ? 44.0 : 32.0))
    }
    
    public func setViewSize(toSize: CGSize, duration: NSTimeInterval) {
        if duration > DBL_EPSILON {
            animateRotation(self.view, toFrame: CGRect(x: 0.0, y: 0.0, width: toSize.width, height: toSize.height), duration: duration)
        }
        else {
            self.view.frame = CGRect(x: 0.0, y: 0.0, width: toSize.width, height: toSize.height)
        }
        
        if duration > DBL_EPSILON {
            animateRotation(self._navigationBar, toFrame: self.navigationBarFrame(toSize), duration: duration)
        }
        else {
            self._navigationBar?.frame = self.navigationBarFrame(toSize)
        }
        
        if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
            //navigationTransitionView.frame = CGRectMake(0.0, 0.0, toSize.width, toSize.height)
            
            if self.viewControllers.count >= 2 {
                let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                
                if let controller = bottomController as? WindowContentController {
                    controller.setViewSize(toSize, duration: duration)
                }
                bottomController.view.frame = CGRectMake(0.0, 0.0, toSize.width, toSize.height)
            }
        }
        
        if let topViewController = self.topViewController {
            if let controller = topViewController as? WindowContentController {
                controller.setViewSize(toSize, duration: duration)
            } else {
                topViewController.view.frame = CGRectMake(0.0, 0.0, toSize.width, toSize.height)
            }
        }
        
        if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
            navigationTransitionCoordinator.updateProgress()
        }
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
