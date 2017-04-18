import SwiftSignalKit

public enum PresentationContextType {
    case current
    case window
}

final class PresentationContext {
    private var _view: UIView?
    var view: UIView? {
        get {
            return self._view
        } set(value) {
            let wasReady = self.ready
            self._view = value
            if wasReady != self.ready {
                if !wasReady {
                    self.addViews()
                } else {
                    self.removeViews()
                }
            }
        }
    }
    
    private var layout: ContainerViewLayout?
    
    private var ready: Bool {
        return self.view != nil && self.layout != nil
    }
    
    private var controllers: [ViewController] = []
    
    private var presentationDisposables = DisposableSet()
    
    var topLevelSubview: UIView?
    
    public func present(_ controller: ViewController) {
        let controllerReady = controller.ready.get()
            |> filter({ $0 })
            |> take(1)
            |> deliverOnMainQueue
            |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(true))
        
        if let _ = self.view, let initialLayout = self.layout {
            controller.view.frame = CGRect(origin: CGPoint(), size: initialLayout.size)
            controller.containerLayoutUpdated(initialLayout, transition: .immediate)
        
            self.presentationDisposables.add(controllerReady.start(next: { [weak self] _ in
                if let strongSelf = self {
                    if strongSelf.controllers.contains(where: { $0 === controller }) {
                        return
                    }
                    
                    strongSelf.controllers.append(controller)
                    if let view = strongSelf.view, let layout = strongSelf.layout {
                        controller.navigation_setDismiss({ [weak strongSelf, weak controller] in
                            if let strongSelf = strongSelf, let controller = controller {
                                strongSelf.dismiss(controller)
                            }
                        }, rootController: nil)
                        controller.setIgnoreAppearanceMethodInvocations(true)
                        if layout != initialLayout {
                            controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                            if let topLevelSubview = strongSelf.topLevelSubview {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                view.addSubview(controller.view)
                            }
                            controller.containerLayoutUpdated(layout, transition: .immediate)
                        } else {
                            if let topLevelSubview = strongSelf.topLevelSubview {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                view.addSubview(controller.view)
                            }
                        }
                        controller.setIgnoreAppearanceMethodInvocations(false)
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
    
    private func dismiss(_ controller: ViewController) {
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
        if let view = self.view, let layout = self.layout {
            for controller in self.controllers {
                controller.viewWillAppear(false)
                if let topLevelSubview = self.topLevelSubview {
                    view.insertSubview(controller.view, belowSubview: topLevelSubview)
                } else {
                    view.addSubview(controller.view)
                }
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
    
    func combinedSupportedOrientations() -> UIInterfaceOrientationMask {
        var mask: UIInterfaceOrientationMask = .all
        
        for controller in self.controllers {
            mask = mask.intersection(controller.supportedInterfaceOrientations)
        }
        
        return mask
    }
}
