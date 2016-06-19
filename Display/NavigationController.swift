import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private struct NavigationControllerLayout {
    let layout: ViewControllerLayout
    let statusBarHeight: CGFloat
}

public class NavigationController: NavigationControllerProxy, WindowContentController, UIGestureRecognizerDelegate, StatusBarSurfaceProvider {
    
    private let statusBarSurface: StatusBarSurface = StatusBarSurface()
    private var navigationTransitionCoordinator: NavigationTransitionCoordinator?
    
    private var currentPushDisposable = MetaDisposable()
    
    private var statusBarChangeObserver: AnyObject?
    
    private var layout: NavigationControllerLayout?
    private var pendingLayout: (NavigationControllerLayout, Double, Bool)?
    
    private var _presentedViewController: UIViewController?
    public override var presentedViewController: UIViewController? {
        return self._presentedViewController
    }
    
    private var _viewControllers: [UIViewController] = []
    public override var viewControllers: [UIViewController] {
        get {
            return self._viewControllers
        } set(value) {
            self.setViewControllers(_viewControllers, animated: false)
        }
    }
    
    public override var topViewController: UIViewController? {
        return self._viewControllers.last
    }
    
    public override init() {
        super.init()
        
        self.statusBarChangeObserver = NotificationCenter.default().addObserver(forName: NSNotification.Name.UIApplicationWillChangeStatusBarFrame, object: nil, queue: OperationQueue.main(), using: { [weak self] notification in
            if let strongSelf = self {
                let statusBarHeight: CGFloat = max(20.0, (notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue)?.cgRectValue().height ?? 20.0)
                
                let previousLayout: NavigationControllerLayout?
                if let pendingLayout = strongSelf.pendingLayout {
                    previousLayout = pendingLayout.0
                } else {
                    previousLayout = strongSelf.layout
                }
                
                strongSelf.pendingLayout = (NavigationControllerLayout(layout: ViewControllerLayout(size: previousLayout?.layout.size ?? CGSize(), insets: previousLayout?.layout.insets ?? UIEdgeInsets(), inputViewHeight: 0.0, statusBarHeight: statusBarHeight), statusBarHeight: statusBarHeight), (strongSelf.pendingLayout?.2 ?? false) ? (strongSelf.pendingLayout?.1 ?? 0.3) : max(strongSelf.pendingLayout?.1 ?? 0.0, 0.35), true)
                
                strongSelf.view.setNeedsLayout()
            }
        })
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = UIView()
        //super.loadView()
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
                    
                    var bottomStatusBar: StatusBar?
                    if let bottomController = bottomController as? ViewController {
                        bottomStatusBar = bottomController.statusBar
                    }
                    
                    if let bottomStatusBar = bottomStatusBar {
                        self.statusBarSurface.insertStatusBar(bottomStatusBar, atIndex: 0)
                    }
                    
                    (self.view.window as? Window)?.updateStatusBars()
                    
                    let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, container: self.view, topView: topView, topNavigationBar: (topController as? ViewController)?.navigationBar, bottomView: bottomView, bottomNavigationBar: (bottomController as? ViewController)?.navigationBar)
                    self.navigationTransitionCoordinator = navigationTransitionCoordinator
                }
            case UIGestureRecognizerState.changed:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                    let translation = recognizer.translation(in: self.view).x
                    navigationTransitionCoordinator.progress = max(0.0, min(1.0, translation / self.view.frame.width))
                }
            case UIGestureRecognizerState.ended:
                if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
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
                                
                                if let topStatusBar = (topController as? ViewController)?.statusBar {
                                    self.statusBarSurface.removeStatusBar(topStatusBar)
                                }
                                
                                (self.view.window as? Window)?.updateStatusBars()
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
                                
                                if let bottomStatusBar = (bottomController as? ViewController)?.statusBar {
                                    self.statusBarSurface.removeStatusBar(bottomStatusBar)
                                }
                                (self.view.window as? Window)?.updateStatusBars()
                            }
                        })
                    }
                }
            case .cancelled:
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
                            
                            if let bottomStatusBar = (bottomController as? ViewController)?.statusBar {
                                self.statusBarSurface.removeStatusBar(bottomStatusBar)
                            }
                            (self.view.window as? Window)?.updateStatusBars()
                        }
                    })
                }
            default:
                break
        }
    }
    
    public func pushViewController(_ controller: ViewController) {
        let layout: NavigationControllerLayout
        if let currentLayout = self.layout {
            layout = currentLayout
        } else {
            layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0, statusBarHeight: 20.0), statusBarHeight: 20.0)
        }
        controller.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
        self.currentPushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                strongSelf.pushViewController(controller, animated: true)
            }
        }))
    }
    
    public override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        self.currentPushDisposable.set(nil)
        
        var controllers = self.viewControllers
        controllers.append(viewController)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public override func popViewController(animated: Bool) -> UIViewController? {
        var controller: UIViewController?
        var controllers = self.viewControllers
        if controllers.count != 0 {
            controller = controllers[controllers.count - 1] as UIViewController
            controllers.remove(at: controllers.count - 1)
            self.setViewControllers(controllers, animated: animated)
        }
        return controller
    }
    
    public override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        if viewControllers.count > 0 {
            let topViewController = viewControllers[viewControllers.count - 1] as UIViewController
            
            if let controller = topViewController as? WindowContentController {
                let layout: NavigationControllerLayout
                if let currentLayout = self.layout {
                    layout = currentLayout
                } else {
                    layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0, statusBarHeight: 20.0), statusBarHeight: 20.0)
                }
                
                controller.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
            } else {
                topViewController.view.frame = CGRect(origin: CGPoint(), size: self.view.bounds.size)
            }
        }
        
        if animated && self.viewControllers.count != 0 && viewControllers.count != 0 && self.viewControllers.last! !== viewControllers.last! {
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
            
            if let topController = topController as? ViewController {
                self.statusBarSurface.addStatusBar(topController.statusBar)
            }
            (self.view.window as? Window)?.updateStatusBars()
            
            navigationTransitionCoordinator.animateCompletion(0.0, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.navigationTransitionCoordinator = nil
                        
                    topController.setIgnoreAppearanceMethodInvocations(true)
                    bottomController.setIgnoreAppearanceMethodInvocations(true)
                    strongSelf.setViewControllers(viewControllers, animated: false)
                    topController.setIgnoreAppearanceMethodInvocations(false)
                    bottomController.setIgnoreAppearanceMethodInvocations(false)
                    
                    bottomController.viewDidDisappear(true)
                    topController.viewDidAppear(true)
                    
                    if let bottomController = bottomController as? ViewController {
                        strongSelf.statusBarSurface.removeStatusBar(bottomController.statusBar)
                    }
                    (strongSelf.view.window as? Window)?.updateStatusBars()
                }
            })
        } else {
            var previousStatusBar: StatusBar?
            if let previousController = self.viewControllers.last as? ViewController {
                previousStatusBar = previousController.statusBar
            }
            var newStatusBar: StatusBar?
            if let newController = viewControllers.last as? ViewController {
                newStatusBar = newController.statusBar
            }
            
            if previousStatusBar !== newStatusBar {
                if let previousStatusBar = previousStatusBar {
                    self.statusBarSurface.removeStatusBar(previousStatusBar)
                }
                if let newStatusBar = newStatusBar {
                    self.statusBarSurface.addStatusBar(newStatusBar)
                }
            }
            
            if let topController = self.viewControllers.last where topController.isViewLoaded() {
                topController.navigation_setNavigationController(nil)
                topController.view.removeFromSuperview()
            }
            
            self._viewControllers = viewControllers
            
            if let topController = viewControllers.last {
                topController.navigation_setNavigationController(self)
                self.view.addSubview(topController.view)
            }
            
            //super.setViewControllers(viewControllers, animated: animated)
        }
    }
    
    private func childControllerLayoutForLayout(_ layout: NavigationControllerLayout) -> ViewControllerLayout {
        return ViewControllerLayout(size: layout.layout.size, insets: layout.layout.insets, inputViewHeight: 0.0, statusBarHeight: layout.statusBarHeight)
    }
    
    public func setParentLayout(_ layout: ViewControllerLayout, duration: Double, curve: UInt) {
        let previousLayout: NavigationControllerLayout?
        if let pendingLayout = self.pendingLayout {
            previousLayout = pendingLayout.0
        } else {
            previousLayout = self.layout
        }
        
        self.pendingLayout = (NavigationControllerLayout(layout: ViewControllerLayout(size: layout.size, insets: layout.insets, inputViewHeight: layout.inputViewHeight, statusBarHeight: previousLayout?.statusBarHeight ?? 20.0), statusBarHeight: previousLayout?.statusBarHeight ?? 20.0), duration, false)
        
        self.view.setNeedsLayout()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let pendingLayout = self.pendingLayout {
            self.layout = pendingLayout.0
            
            if pendingLayout.1 > DBL_EPSILON {
                animateRotation(self.view, toFrame: CGRect(x: 0.0, y: 0.0, width: pendingLayout.0.layout.size.width, height: pendingLayout.0.layout.size.height), duration: pendingLayout.1)
            }
            else {
                self.view.frame = CGRect(x: 0.0, y: 0.0, width: pendingLayout.0.layout.size.width, height: pendingLayout.0.layout.size.height)
            }
            
            /*if pendingLayout.1 > DBL_EPSILON {
                animateRotation(self._navigationBar, toFrame: self.navigationBarFrame(pendingLayout.0), duration: pendingLayout.1)
            }
            else {
                self._navigationBar.frame = self.navigationBarFrame(pendingLayout.0)
            }*/
            
            if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                //navigationTransitionView.frame = CGRectMake(0.0, 0.0, toSize.width, toSize.height)
                
                if self.viewControllers.count >= 2 {
                    let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                    
                    if let controller = bottomController as? WindowContentController {
                        let layout: NavigationControllerLayout
                        if let currentLayout = self.layout {
                            layout = currentLayout
                        } else {
                            layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0, statusBarHeight: 20.0), statusBarHeight: 20.0)
                        }
                        
                        controller.setParentLayout(self.childControllerLayoutForLayout(pendingLayout.0), duration: pendingLayout.1, curve: 0)
                    } else {
                        bottomController.view.frame = CGRect(x: 0.0, y: 0.0, width: pendingLayout.0.layout.size.width, height: pendingLayout.0.layout.size.height)
                    }
                }
                
                //self._navigationBar.setInteractivePopProgress(navigationTransitionCoordinator.progress)
            }
            
            if let topViewController = self.topViewController {
                if let controller = topViewController as? WindowContentController {
                    controller.setParentLayout(self.childControllerLayoutForLayout(pendingLayout.0), duration: pendingLayout.1, curve: 0)
                } else {
                    topViewController.view.frame = CGRect(x: 0.0, y: 0.0, width: pendingLayout.0.layout.size.width, height: pendingLayout.0.layout.size.height)
                }
            }
            
            if let presentedViewController = self.presentedViewController {
                if let controller = presentedViewController as? WindowContentController {
                    controller.setParentLayout(self.childControllerLayoutForLayout(pendingLayout.0), duration: pendingLayout.1, curve: 0)
                } else {
                    presentedViewController.view.frame = CGRect(x: 0.0, y: 0.0, width: pendingLayout.0.layout.size.width, height: pendingLayout.0.layout.size.height)
                }
            }
            
            if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                navigationTransitionCoordinator.updateProgress()
            }
            
            self.pendingLayout = nil
        }
    }
    
    override public func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let controller = viewControllerToPresent as? NavigationController {
            controller.navigation_setPresenting(self)
            self._presentedViewController = controller
            
            self.view.endEditing(true)
            
            let layout: NavigationControllerLayout
            if let currentLayout = self.layout {
                layout = currentLayout
            } else {
                layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0, statusBarHeight: 20.0), statusBarHeight: 20.0)
            }
            
            controller.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
            
            if flag {
                controller.view.frame = self.view.bounds.offsetBy(dx: 0.0, dy: self.view.bounds.height)
                self.view.addSubview(controller.view)
                (self.view.window as? Window)?.updateStatusBars()
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                    controller.view.frame = self.view.bounds
                    (self.view.window as? Window)?.updateStatusBars()
                }, completion: { _ in
                    if let completion = completion {
                        completion()
                    }
                })
            } else {
                self.view.addSubview(controller.view)
                (self.view.window as? Window)?.updateStatusBars()
                
                if let completion = completion {
                    completion()
                }
            }
        } else {
            preconditionFailure("NavigationController can't present \(viewControllerToPresent). Only subclasses of NavigationController are allowed.")
        }
    }
    
    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let controller = self.presentedViewController {
            if flag {
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                    controller.view.frame = self.view.bounds.offsetBy(dx: 0.0, dy: self.view.bounds.height)
                    (self.view.window as? Window)?.updateStatusBars()
                }, completion: { _ in
                    controller.view.removeFromSuperview()
                    self._presentedViewController = nil
                    (self.view.window as? Window)?.updateStatusBars()
                    if let completion = completion {
                        completion()
                    }
                })
            } else {
                self._presentedViewController = nil
                (self.view.window as? Window)?.updateStatusBars()
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
        return otherGestureRecognizer is UIPanGestureRecognizer
    }
    
    func statusBarSurfaces() -> [StatusBarSurface] {
        var surfaces: [StatusBarSurface] = [self.statusBarSurface]
        if let controller = self.presentedViewController as? StatusBarSurfaceProvider {
            surfaces.append(contentsOf: controller.statusBarSurfaces())
        }
        return surfaces
    }
}
