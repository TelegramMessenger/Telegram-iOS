import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private func isViewVisibleInHierarchy(_ view: UIView, _ initial: Bool = true) -> Bool {
    guard let window = view.window else {
        return false
    }
    if view.isHidden || view.alpha == 0.0 {
        return false
    }
    if view.superview === window {
        return true
    } else if let superview = view.superview {
        if initial && view.frame.minY >= superview.frame.height {
            return false
        } else {
            return isViewVisibleInHierarchy(superview, false)
        }
    } else {
        return false
    }
}

final class GlobalOverlayPresentationContext {
    private let statusBarHost: StatusBarHost?
    
    private var controllers: [ContainableController] = []
    
    private var presentationDisposables = DisposableSet()
    private var layout: ContainerViewLayout?
    
    private var ready: Bool {
        return self.currentPresentationView() != nil && self.layout != nil
    }
    
    init(statusBarHost: StatusBarHost?) {
        self.statusBarHost = statusBarHost
    }
    
    private func currentPresentationView() -> UIView? {
        if let statusBarHost = self.statusBarHost {
            if let keyboardWindow = statusBarHost.keyboardWindow, let keyboardView = statusBarHost.keyboardView, !keyboardView.frame.height.isZero, isViewVisibleInHierarchy(keyboardView) {
                return keyboardWindow
            } else {
                return statusBarHost.statusBarWindow
            }
        }
        return nil
    }
    
    func present(_ controller: ContainableController) {
        let controllerReady = controller.ready.get()
        |> filter({ $0 })
        |> take(1)
        |> deliverOnMainQueue
        |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(true))
        
        if let _ = self.currentPresentationView(), let initialLayout = self.layout {
            controller.view.frame = CGRect(origin: CGPoint(), size: initialLayout.size)
            controller.containerLayoutUpdated(initialLayout, transition: .immediate)
            
            self.presentationDisposables.add(controllerReady.start(next: { [weak self] _ in
                if let strongSelf = self {
                    if strongSelf.controllers.contains(where: { $0 === controller }) {
                        return
                    }
                    
                    strongSelf.controllers.append(controller)
                    if let view = strongSelf.currentPresentationView(), let layout = strongSelf.layout {
                        (controller as? UIViewController)?.navigation_setDismiss({ [weak controller] in
                            if let strongSelf = self, let controller = controller {
                                strongSelf.dismiss(controller)
                            }
                        }, rootController: nil)
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(true)
                        if layout != initialLayout {
                            controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                            view.addSubview(controller.view)
                            controller.containerLayoutUpdated(layout, transition: .immediate)
                        } else {
                            view.addSubview(controller.view)
                        }
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(false)
                        view.layer.invalidateUpTheTree()
                        controller.viewWillAppear(false)
                        controller.viewDidAppear(false)
                    }
                }
            }))
        } else {
            self.controllers.append(controller)
        }
    }
    
    deinit {
        self.presentationDisposables.dispose()
    }
    
    private func dismiss(_ controller: ContainableController) {
        if let index = self.controllers.index(where: { $0 === controller }) {
            self.controllers.remove(at: index)
            controller.viewWillDisappear(false)
            controller.view.removeFromSuperview()
            controller.viewDidDisappear(false)
        }
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let wasReady = self.ready
        self.layout = layout
        
        if wasReady != self.ready {
            self.readyChanged(wasReady: wasReady)
        } else if self.ready {
            for controller in self.controllers {
                controller.containerLayoutUpdated(layout, transition: transition)
            }
        }
    }
    
    private func readyChanged(wasReady: Bool) {
        if !wasReady {
            self.addViews()
        } else {
            self.removeViews()
        }
    }
    
    private func addViews() {
        if let view = self.currentPresentationView(), let layout = self.layout {
            for controller in self.controllers {
                controller.viewWillAppear(false)
                view.addSubview(controller.view)
                controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                controller.containerLayoutUpdated(layout, transition: .immediate)
                controller.viewDidAppear(false)
            }
        }
    }
    
    private func removeViews() {
        for controller in self.controllers {
            controller.viewWillDisappear(false)
            controller.view.removeFromSuperview()
            controller.viewDidDisappear(false)
        }
    }
    
    func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for controller in self.controllers.reversed() {
            if controller.isViewLoaded {
                if let result = controller.view.hitTest(point, with: event) {
                    return result
                }
            }
        }
        return nil
    }
    
    func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        if self.ready {
            for controller in self.controllers {
                controller.updateToInterfaceOrientation(orientation)
            }
        }
    }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        var mask = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
        
        for controller in self.controllers {
            mask = mask.intersection(controller.combinedSupportedOrientations(currentOrientationToLock: currentOrientationToLock))
        }
        
        return mask
    }
    
    func combinedDeferScreenEdgeGestures() -> UIRectEdge {
        var edges: UIRectEdge = []
        
        for controller in self.controllers {
            edges = edges.union(controller.deferScreenEdgeGestures)
        }
        
        return edges
    }
}
