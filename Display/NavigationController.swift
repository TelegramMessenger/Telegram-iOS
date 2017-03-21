import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private class NavigationControllerView: UIView {
    override class var layerClass: AnyClass {
        return CATracingLayer.self
    }
}

open class NavigationController: NavigationControllerProxy, ContainableController, UIGestureRecognizerDelegate {
    public private(set) weak var overlayPresentingController: ViewController?
    
    private var containerLayout = ContainerViewLayout()
    
    private var navigationTransitionCoordinator: NavigationTransitionCoordinator?
    
    private var currentPushDisposable = MetaDisposable()
    private var currentPresentDisposable = MetaDisposable()
    
    private var statusBarChangeObserver: AnyObject?
    
    //private var layout: NavigationControllerLayout?
    //private var pendingLayout: (NavigationControllerLayout, Double, Bool)?
    
    private var _presentedViewController: UIViewController?
    open override var presentedViewController: UIViewController? {
        return self._presentedViewController
    }
    
    private var _viewControllers: [UIViewController] = []
    open override var viewControllers: [UIViewController] {
        get {
            return self._viewControllers
        } set(value) {
            self.setViewControllers(_viewControllers, animated: false)
        }
    }
    
    open override var topViewController: UIViewController? {
        return self._viewControllers.last
    }
    
    public override init() {
        super.init()
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.currentPushDisposable.dispose()
        self.currentPresentDisposable.dispose()
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if !self.isViewLoaded {
            self.loadView()
        }
        self.containerLayout = layout
        self.view.frame = CGRect(origin: self.view.frame.origin, size: layout.size)
        
        let containedLayout = ContainerViewLayout(size: layout.size, intrinsicInsets: layout.intrinsicInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight)
        
        /*for controller in self.viewControllers {
            if let controller = controller as? ContainableController {
                controller.containerLayoutUpdated(containedLayout, transition: transition) 
            } else {
                controller.viewWillTransition(to: layout.size, with: SystemContainedControllerTransitionCoordinator())
            }
        }*/
        
        if let topViewController = self.topViewController {
            if let topViewController = topViewController as? ContainableController {
                topViewController.containerLayoutUpdated(containedLayout, transition: transition)
            } else {
                topViewController.view.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            }
        }
        
        if let presentedViewController = self.presentedViewController {
            if let presentedViewController = presentedViewController as? ContainableController {
                presentedViewController.containerLayoutUpdated(containedLayout, transition: transition)
            } else {
                presentedViewController.view.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            }
        }
        
        if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
            navigationTransitionCoordinator.updateProgress()
        }
    }
    
    open override func loadView() {
        self.view = NavigationControllerView()
        self.view.clipsToBounds = true
        
        self.navigationBar.removeFromSuperview()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delegate = self
        panRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(panRecognizer)
        
        if self.topViewController != nil {
            self.topViewController?.view.frame = CGRect(origin: CGPoint(), size: self.view.frame.size)
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case UIGestureRecognizerState.began:
                if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                    let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                    let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                    
                    topController.viewWillDisappear(true)
                    let topView = topController.view!
                    bottomController.viewWillAppear(true)
                    let bottomView = bottomController.view!
                    
                    let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, container: self.view, topView: topView, topNavigationBar: (topController as? ViewController)?.navigationBar, bottomView: bottomView, bottomNavigationBar: (bottomController as? ViewController)?.navigationBar)
                    self.navigationTransitionCoordinator = navigationTransitionCoordinator
                }
            case UIGestureRecognizerState.changed:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator, !navigationTransitionCoordinator.animatingCompletion {
                    let translation = recognizer.translation(in: self.view).x
                    navigationTransitionCoordinator.progress = max(0.0, min(1.0, translation / self.view.frame.width))
                }
            case UIGestureRecognizerState.ended:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator, !navigationTransitionCoordinator.animatingCompletion {
                    let velocity = recognizer.velocity(in: self.view).x
                    
                    if velocity > 1000 || navigationTransitionCoordinator.progress > 0.2 {
                        navigationTransitionCoordinator.animateCompletion(velocity, completion: {
                            self.navigationTransitionCoordinator = nil
                            
                            //self._navigationBar.endInteractivePopProgress()
                            
                            if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                                let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                                let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                                
                                topController.setIgnoreAppearanceMethodInvocations(true)
                                bottomController.setIgnoreAppearanceMethodInvocations(true)
                                let _ = self.popViewController(animated: false)
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
                            
                            //self._navigationBar.endInteractivePopProgress()
                            
                            if self.viewControllers.count >= 2 && self.navigationTransitionCoordinator == nil {
                                let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                                let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                                
                                topController.viewDidAppear(true)
                                bottomController.viewDidDisappear(true)
                            }
                        })
                    }
                }
            case .cancelled:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator, !navigationTransitionCoordinator.animatingCompletion {
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
    
    public func pushViewController(_ controller: ViewController) {
        self.view.endEditing(true)
        let appliedLayout = self.containerLayout.withUpdatedInputHeight(nil)
        controller.containerLayoutUpdated(appliedLayout, transition: .immediate)
        self.currentPushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                if strongSelf.containerLayout.withUpdatedInputHeight(nil) != appliedLayout {
                    controller.containerLayoutUpdated(strongSelf.containerLayout.withUpdatedInputHeight(nil), transition: .immediate)
                }
                strongSelf.pushViewController(controller, animated: true)
            }
        }))
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        self.currentPushDisposable.set(nil)
        
        var controllers = self.viewControllers
        controllers.append(viewController)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public func replaceTopController(_ controller: ViewController, animated: Bool, ready: ValuePromise<Bool>? = nil) {
        self.view.endEditing(true)
        controller.containerLayoutUpdated(self.containerLayout, transition: .immediate)
        self.currentPushDisposable.set((controller.ready.get() |> take(1)).start(next: { [weak self] _ in
            if let strongSelf = self {
                ready?.set(true)
                var controllers = strongSelf.viewControllers
                controllers.removeLast()
                controllers.append(controller)
                strongSelf.setViewControllers(controllers, animated: animated)
            }
        }))
    }
    
    public func replaceAllButRootController(_ controller: ViewController, animated: Bool, ready: ValuePromise<Bool>? = nil) {
        self.view.endEditing(true)
        controller.containerLayoutUpdated(self.containerLayout, transition: .immediate)
        self.currentPushDisposable.set((controller.ready.get() |> take(1)).start(next: { [weak self] _ in
            if let strongSelf = self {
                ready?.set(true)
                var controllers = strongSelf.viewControllers
                while controllers.count > 1 {
                    controllers.removeLast()
                }
                controllers.append(controller)
                strongSelf.setViewControllers(controllers, animated: animated)
            }
        }))
    }

    public func popToRoot(animated: Bool) {
        var controllers = self.viewControllers
        while controllers.count > 1 {
            controllers.removeLast()
        }
        self.setViewControllers(controllers, animated: animated)
    }
    
    override open func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        var poppedControllers: [UIViewController] = []
        var found = false
        var controllers = self.viewControllers
        while !controllers.isEmpty {
            if controllers[controllers.count - 1] === viewController {
                found = true
                break
            }
            poppedControllers.insert(controllers[controllers.count - 1], at: 0)
            controllers.removeLast()
        }
        if found {
            self.setViewControllers(controllers, animated: animated)
            return poppedControllers
        } else {
            return nil
        }
    }
    
    open override func popViewController(animated: Bool) -> UIViewController? {
        var controller: UIViewController?
        var controllers = self.viewControllers
        if controllers.count != 0 {
            controller = controllers[controllers.count - 1] as UIViewController
            controllers.remove(at: controllers.count - 1)
            self.setViewControllers(controllers, animated: animated)
        }
        return controller
    }
    
    open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        for controller in viewControllers {
            controller.navigation_setNavigationController(self)
        }
        
        if viewControllers.count > 0 {
            let topViewController = viewControllers[viewControllers.count - 1] as UIViewController
            
            if let controller = topViewController as? ContainableController {
                controller.containerLayoutUpdated(self.containerLayout, transition: .immediate)
            } else {
                topViewController.view.frame = CGRect(origin: CGPoint(), size: self.view.bounds.size)
            }
        }
        
        if animated && self.viewControllers.count != 0 && viewControllers.count != 0 && self.viewControllers.last! !== viewControllers.last! {
            if self.viewControllers.contains(where: { $0 === viewControllers.last }) {
                let bottomController = viewControllers.last! as UIViewController
                let topController = self.viewControllers.last! as UIViewController
                
                if let bottomController = bottomController as? ViewController {
                    if viewControllers.count >= 2 {
                        bottomController.navigationBar.previousItem = viewControllers[viewControllers.count - 2].navigationItem
                    } else {
                        bottomController.navigationBar.previousItem = nil
                    }
                }
                
                bottomController.viewWillDisappear(true)
                let bottomView = bottomController.view!
                topController.viewWillAppear(true)
                let topView = topController.view!
                
                let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, container: self.view, topView: topView, topNavigationBar: (topController as? ViewController)?.navigationBar, bottomView: bottomView, bottomNavigationBar: (bottomController as? ViewController)?.navigationBar)
                self.navigationTransitionCoordinator = navigationTransitionCoordinator
                
                navigationTransitionCoordinator.animateCompletion(0.0, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.navigationTransitionCoordinator = nil
                        
                        topController.setIgnoreAppearanceMethodInvocations(true)
                        bottomController.setIgnoreAppearanceMethodInvocations(true)
                        strongSelf.setViewControllers(viewControllers, animated: false)
                        topController.setIgnoreAppearanceMethodInvocations(false)
                        bottomController.setIgnoreAppearanceMethodInvocations(false)
                        
                        topController.viewDidDisappear(true)
                        bottomController.viewDidAppear(true)
                        
                        topView.removeFromSuperview()
                    }
                })
            } else {
                let topController = viewControllers.last! as UIViewController
                let bottomController = self.viewControllers.last! as UIViewController
                
                if let topController = topController as? ViewController {
                    topController.navigationBar.previousItem = bottomController.navigationItem
                }
                
                bottomController.viewWillDisappear(true)
                let bottomView = bottomController.view!
                topController.viewWillAppear(true)
                let topView = topController.view!
                
                let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Push, container: self.view, topView: topView, topNavigationBar: (topController as? ViewController)?.navigationBar, bottomView: bottomView, bottomNavigationBar: (bottomController as? ViewController)?.navigationBar)
                self.navigationTransitionCoordinator = navigationTransitionCoordinator
                
                topView.isUserInteractionEnabled = false
                
                navigationTransitionCoordinator.animateCompletion(0.0, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.navigationTransitionCoordinator = nil
                        
                        topController.setIgnoreAppearanceMethodInvocations(true)
                        bottomController.setIgnoreAppearanceMethodInvocations(true)
                        strongSelf.setViewControllers(viewControllers, animated: false)
                        topController.setIgnoreAppearanceMethodInvocations(false)
                        bottomController.setIgnoreAppearanceMethodInvocations(false)
                        
                        topController.view.isUserInteractionEnabled = true
                        
                        bottomController.viewDidDisappear(true)
                        topController.viewDidAppear(true)
                        
                        bottomView.removeFromSuperview()
                    }
                })
            }
        } else {
            if let topController = self.viewControllers.last , topController.isViewLoaded {
                topController.navigation_setNavigationController(nil)
                topController.viewWillDisappear(false)
                topController.view.removeFromSuperview()
                topController.viewDidDisappear(false)
            }
            
            self._viewControllers = viewControllers
            
            if let topController = viewControllers.last {
                if let topController = topController as? ViewController {
                    if viewControllers.count >= 2 {
                        topController.navigationBar.previousItem = viewControllers[viewControllers.count - 2].navigationItem
                    } else {
                        topController.navigationBar.previousItem = nil
                    }
                }
                
                topController.navigation_setNavigationController(self)
                topController.viewWillAppear(false)
                self.view.addSubview(topController.view)
                topController.viewDidAppear(false)
            }
        }
    }
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let controller = viewControllerToPresent as? NavigationController {
            controller.navigation_setDismiss({ [weak self] in
                if let strongSelf = self {
                    strongSelf.dismiss(animated: false, completion: nil)
                }
            }, rootController: self.view!.window!.rootViewController)
            self._presentedViewController = controller
            
            self.view.endEditing(true)
            controller.containerLayoutUpdated(self.containerLayout, transition: .immediate)
            
            var ready: Signal<Bool, Void> = .single(true)
            
            if let controller = controller.topViewController as? ViewController {
                ready = controller.ready.get() |> filter { $0 } |> take(1) |> deliverOnMainQueue
            }
            
            self.currentPresentDisposable.set(ready.start(next: { [weak self] _ in
                if let strongSelf = self {
                    if flag {
                        controller.view.frame = strongSelf.view.bounds.offsetBy(dx: 0.0, dy: strongSelf.view.bounds.height)
                        strongSelf.view.addSubview(controller.view)
                        UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                            controller.view.frame = strongSelf.view.bounds
                        }, completion: { _ in
                            if let completion = completion {
                                completion()
                            }
                        })
                    } else {
                        controller.view.frame = strongSelf.view.bounds
                        strongSelf.view.addSubview(controller.view)
                        
                        if let completion = completion {
                            completion()
                        }
                    }
                }
            }))
        } else {
            preconditionFailure("NavigationController can't present \(viewControllerToPresent). Only subclasses of NavigationController are allowed.")
        }
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let controller = self.presentedViewController {
            if flag {
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                    controller.view.frame = self.view.bounds.offsetBy(dx: 0.0, dy: self.view.bounds.height)
                }, completion: { _ in
                    controller.view.removeFromSuperview()
                    self._presentedViewController = nil
                    if let completion = completion {
                        completion()
                    }
                })
            } else {
                controller.view.removeFromSuperview()
                self._presentedViewController = nil
                if let completion = completion {
                    completion()
                }
            }
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
