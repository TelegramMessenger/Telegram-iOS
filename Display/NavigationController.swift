import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private struct NavigationControllerLayout {
    let layout: ViewControllerLayout
    let statusBarHeight: CGFloat
}

public class NavigationController: NavigationControllerProxy, WindowContentController, UIGestureRecognizerDelegate {
    private var _navigationBar: NavigationBar!
    private var navigationTransitionCoordinator: NavigationTransitionCoordinator?
    
    private var currentPushDisposable = MetaDisposable()
    
    private var statusBarChangeObserver: AnyObject?
    
    private var layout: NavigationControllerLayout?
    private var pendingLayout: (NavigationControllerLayout, NSTimeInterval, Bool)?
    
    public override init() {
        self._navigationBar = nil
        
        super.init()
        
        self._navigationBar = NavigationBar()
    
        self._navigationBar.frame = CGRect(x: 0.0, y: 0.0, width: 320.0, height: 44.0)
        self._navigationBar.proxy = self.navigationBar as? NavigationBarProxy
        self._navigationBar.backPressed = { [weak self] in
            if let strongSelf = self {
                if strongSelf.viewControllers.count > 1 {
                    strongSelf.popViewControllerAnimated(true)
                }
            }
            return
        }
        
        self.statusBarChangeObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillChangeStatusBarFrameNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { [weak self] notification in
            if let strongSelf = self {
                let statusBarHeight: CGFloat = (notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue)?.CGRectValue().height ?? 20.0
                
                let previousLayout: NavigationControllerLayout?
                if let pendingLayout = strongSelf.pendingLayout {
                    previousLayout = pendingLayout.0
                } else {
                    previousLayout = strongSelf.layout
                }
                
                strongSelf.pendingLayout = (NavigationControllerLayout(layout: ViewControllerLayout(size: previousLayout?.layout.size ?? CGSize(), insets: previousLayout?.layout.insets ?? UIEdgeInsets(), inputViewHeight: 0.0), statusBarHeight: statusBarHeight), (strongSelf.pendingLayout?.2 ?? false) ? (strongSelf.pendingLayout?.1 ?? 0.3) : max(strongSelf.pendingLayout?.1 ?? 0.0, 0.35), true)
                
                strongSelf.view.setNeedsLayout()
            }
        })
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        super.loadView()
        
        self.navigationBar.superview?.insertSubview(_navigationBar.view, aboveSubview: self.navigationBar)
        self.navigationBar.removeFromSuperview()
        
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
                    
                    let navigationTransitionCoordinator = NavigationTransitionCoordinator(container: self.view, topView: topView, bottomView: bottomView, navigationBar: self._navigationBar)
                    self.navigationTransitionCoordinator = navigationTransitionCoordinator
                    
                    self._navigationBar.beginInteractivePopProgress(bottomController.navigationItem, evenMorePreviousItem: self.viewControllers.count >= 3 ? (self.viewControllers[self.viewControllers.count - 3] as UIViewController).navigationItem : nil)
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
                            
                            self._navigationBar.endInteractivePopProgress()
                            
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
                            
                            self._navigationBar.endInteractivePopProgress()
                            
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
    
    public func pushViewController(controller: ViewController) {
        let layout: NavigationControllerLayout
        if let currentLayout = self.layout {
            layout = currentLayout
        } else {
            layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0), statusBarHeight: 20.0)
        }
        controller.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
        self.currentPushDisposable.set((controller.ready.get() |> take(1)).start(next: {[weak self] _ in
            if let strongSelf = self {
                strongSelf.pushViewController(controller, animated: true)
            }
        }))
    }
    
    public override func pushViewController(viewController: UIViewController, animated: Bool) {
        self.currentPushDisposable.set(nil)
        
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
                let layout: NavigationControllerLayout
                if let currentLayout = self.layout {
                    layout = currentLayout
                } else {
                    layout = NavigationControllerLayout(layout: ViewControllerLayout(size: self.view.bounds.size, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0), inputViewHeight: 0.0), statusBarHeight: 20.0)
                }
                
                controller.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
            } else {
                topViewController.view.frame = CGRect(origin: CGPoint(), size: self.view.bounds.size)
            }
        }
        
        super.setViewControllers(viewControllers, animated: animated)
    }
    
    private func navigationBarFrame(layout: NavigationControllerLayout) -> CGRect {
        return CGRect(x: 0.0, y: layout.statusBarHeight - 20.0, width: layout.layout.size.width, height: 20.0 + (layout.layout.size.height >= layout.layout.size.width ? 44.0 : 32.0))
    }
    
    private func childControllerLayoutForLayout(layout: NavigationControllerLayout) -> ViewControllerLayout {
        var insets = layout.layout.insets
        insets.top = self.navigationBarFrame(layout).maxY
        return ViewControllerLayout(size: layout.layout.size, insets: insets, inputViewHeight: 0.0)
    }
    
    public func setParentLayout(layout: ViewControllerLayout, duration: NSTimeInterval, curve: UInt) {
        let previousLayout: NavigationControllerLayout?
        if let pendingLayout = self.pendingLayout {
            previousLayout = pendingLayout.0
        } else {
            previousLayout = self.layout
        }
        
        self.pendingLayout = (NavigationControllerLayout(layout: layout, statusBarHeight: previousLayout?.statusBarHeight ?? 20.0), duration, false)
        
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
            
            if pendingLayout.1 > DBL_EPSILON {
                animateRotation(self._navigationBar, toFrame: self.navigationBarFrame(pendingLayout.0), duration: pendingLayout.1)
            }
            else {
                self._navigationBar.frame = self.navigationBarFrame(pendingLayout.0)
            }
            
            if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                //navigationTransitionView.frame = CGRectMake(0.0, 0.0, toSize.width, toSize.height)
                
                if self.viewControllers.count >= 2 {
                    let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                    
                    if let controller = bottomController as? WindowContentController {
                        controller.setParentLayout(self.childControllerLayoutForLayout(pendingLayout.0), duration: pendingLayout.1, curve: 0)
                    } else {
                        bottomController.view.frame = CGRectMake(0.0, 0.0, pendingLayout.0.layout.size.width, pendingLayout.0.layout.size.height)
                    }
                }
                
                self._navigationBar.setInteractivePopProgress(navigationTransitionCoordinator.progress)
            }
            
            if let topViewController = self.topViewController {
                if let controller = topViewController as? WindowContentController {
                    controller.setParentLayout(self.childControllerLayoutForLayout(pendingLayout.0), duration: pendingLayout.1, curve: 0)
                } else {
                    topViewController.view.frame = CGRectMake(0.0, 0.0, pendingLayout.0.layout.size.width, pendingLayout.0.layout.size.height)
                }
            }
            
            if let navigationTransitionCoordinator = self.navigationTransitionCoordinator {
                navigationTransitionCoordinator.updateProgress()
            }
            
            self.pendingLayout = nil
        }
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer
    }
}
