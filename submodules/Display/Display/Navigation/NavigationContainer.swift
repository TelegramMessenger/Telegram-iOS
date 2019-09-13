import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

final class NavigationContainer: ASDisplayNode, UIGestureRecognizerDelegate {
    private final class Child {
        let value: ViewController
        var layout: ContainerViewLayout
        
        init(value: ViewController, layout: ContainerViewLayout) {
            self.value = value
            self.layout = layout
        }
    }
    
    private final class PendingChild {
        enum TransitionType {
            case push
            case pop
        }
        
        let value: Child
        let transitionType: TransitionType
        let transition: ContainedViewLayoutTransition
        let disposable: MetaDisposable = MetaDisposable()
        var isReady: Bool = false
        
        init(value: Child, transitionType: TransitionType, transition: ContainedViewLayoutTransition, update: @escaping (PendingChild) -> Void) {
            self.value = value
            self.transitionType = transitionType
            self.transition = transition
            var localIsReady: Bool?
            self.disposable.set((value.value.ready.get()
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                if localIsReady == nil {
                    localIsReady = true
                } else if let strongSelf = self {
                    update(strongSelf)
                }
            }))
            if let localIsReady = localIsReady {
                self.isReady = true
            } else {
                localIsReady = false
            }
        }
        
        deinit {
            self.disposable.dispose()
        }
    }
    
    private final class TopTransition {
        let previous: Child
        let coordinator: NavigationTransitionCoordinator
        
        init(previous: Child, coordinator: NavigationTransitionCoordinator) {
            self.previous = previous
            self.coordinator = coordinator
        }
    }
    
    private struct State {
        var layout: ContainerViewLayout?
        var canBeClosed: Bool?
        var top: Child?
        var transition: TopTransition?
        var pending: PendingChild?
    }
    
    private(set) var controllers: [ViewController] = []
    private var state: State = State(layout: nil, canBeClosed: nil, top: nil, transition: nil, pending: nil)
    
    private(set) var isReady: Bool = false
    var isReadyUpdated: (() -> Void)?
    var controllerRemoved: (ViewController) -> Void
    var keyboardManager: KeyboardManager? {
        didSet {
            if self.keyboardManager !== oldValue {
                self.keyboardManager?.surfaces = self.state.top?.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
            }
        }
    }
    
    init(controllerRemoved: @escaping (ViewController) -> Void) {
        self.controllerRemoved = controllerRemoved
        
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard let layout = self.state.layout else {
                return
            }
            guard self.state.transition == nil else {
                return
            }
            let beginGesture = self.controllers.count > 1
            
            if beginGesture {
                let topController = self.controllers[self.controllers.count - 1]
                let bottomController = self.controllers[self.controllers.count - 2]
                
                if let topController = topController as? ViewController {
                    if !topController.attemptNavigation({ [weak self] in
                        //let _ = self?.popViewController(animated: true)
                    }) {
                        return
                    }
                }
                
                topController.viewWillDisappear(true)
                let topView = topController.view!
                bottomController.containerLayoutUpdated(layout, transition: .immediate)
                bottomController.viewWillAppear(true)
                let bottomView = bottomController.view!
                
                let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, container: self.view, topView: topView, topNavigationBar: topController.navigationBar, bottomView: bottomView, bottomNavigationBar: bottomController.navigationBar, didUpdateProgress: { [weak self] progress, transition in
                    if let strongSelf = self {
                        strongSelf.keyboardManager?.surfaces = strongSelf.state.top?.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
                        /*for i in 0 ..< strongSelf._viewControllers.count {
                            if let controller = strongSelf._viewControllers[i].controller as? ViewController {
                                if i < strongSelf._viewControllers.count - 1 {
                                    controller.updateNavigationCustomData((strongSelf.viewControllers[i + 1] as? ViewController)?.customData, progress: 1.0 - progress, transition: transition)
                                } else {
                                    controller.updateNavigationCustomData(nil, progress: 1.0 - progress, transition: transition)
                                }
                            }
                        }*/
                    }
                })
                bottomController.displayNode.recursivelyEnsureDisplaySynchronously(true)
                self.state.transition = TopTransition(previous: Child(value: bottomController, layout: layout), coordinator: navigationTransitionCoordinator)
            }
        case .changed:
            if let navigationTransitionCoordinator = self.state.transition?.coordinator, !navigationTransitionCoordinator.animatingCompletion {
                let translation = recognizer.translation(in: self.view).x
                let progress = max(0.0, min(1.0, translation / self.view.frame.width))
                navigationTransitionCoordinator.progress = progress
            }
        case .ended, .cancelled:
            if let navigationTransitionCoordinator = self.state.transition?.coordinator, !navigationTransitionCoordinator.animatingCompletion {
                let velocity = recognizer.velocity(in: self.view).x
                
                if velocity > 1000 || navigationTransitionCoordinator.progress > 0.2 {
                    //(self.view as! NavigationControllerView).inTransition = true
                    navigationTransitionCoordinator.animateCompletion(velocity, completion: { [weak self] in
                        guard let strongSelf = self, let layout = strongSelf.state.layout, let transition = strongSelf.state.transition, let top = strongSelf.state.top else {
                            return
                        }
                        //(self.view as! NavigationControllerView).inTransition = false
                        
                        let topController = top.value
                        let bottomController = transition.previous.value
                        strongSelf.keyboardManager?.updateInteractiveInputOffset(layout.size.height, transition: .immediate, completion: {})
                        topController.view.endEditing(true)
                        
                        strongSelf.state.transition = nil
                        
                        strongSelf.controllerRemoved(top.value)
                        
                        //topController.viewDidDisappear(true)
                        //bottomController.viewDidAppear(true)
                    })
                } else {
                    /*if self.viewControllers.count >= 2 {
                        let topController = self.viewControllers[self.viewControllers.count - 1] as UIViewController
                        let bottomController = self.viewControllers[self.viewControllers.count - 2] as UIViewController
                        
                        topController.viewWillAppear(true)
                        bottomController.viewWillDisappear(true)
                    }*/
                    
                    //(self.view as! NavigationControllerView).inTransition = true
                    navigationTransitionCoordinator.animateCancel({ [weak self] in
                        guard let strongSelf = self, let top = strongSelf.state.top, let transition = strongSelf.state.transition else {
                            return
                        }
                        //(self.view as! NavigationControllerView).inTransition = false
                        strongSelf.state.transition = nil
                            
                        top.value.viewDidAppear(true)
                        transition.previous.value.viewDidDisappear(true)
                    })
                }
            }
        default:
            break
        }
    }
    
    func update(layout: ContainerViewLayout, canBeClosed: Bool, controllers: [ViewController], transition: ContainedViewLayoutTransition) {
        let previousControllers = self.controllers
        self.controllers = controllers
        
        for i in 0 ..< controllers.count {
            if i == 0 {
                if canBeClosed {
                    controllers[i].navigationBar?.previousItem = .close
                } else {
                    controllers[i].navigationBar?.previousItem = nil
                }
            } else {
                controllers[i].navigationBar?.previousItem = .item(controllers[i - 1].navigationItem)
            }
        }
        
        self.state.layout = layout
        self.state.canBeClosed = canBeClosed
        
        if controllers.last !== self.state.top?.value {
            if controllers.last !== self.state.pending?.value.value {
                self.state.pending = nil
                if let last = controllers.last {
                    let transitionType: PendingChild.TransitionType
                    if !previousControllers.contains(where: { $0 === last }) {
                        transitionType = .push
                    } else {
                        transitionType = .pop
                    }
                    self.state.pending = PendingChild(value: self.makeChild(layout: layout, value: last), transitionType: transitionType, transition: transition, update: { [weak self] pendingChild in
                        self?.pendingChildIsReady(pendingChild)
                    })
                }
            }
        }
        
        if let pending = self.state.pending {
            if pending.isReady {
                self.state.pending = nil
                let previous = self.state.top
                self.state.top = pending.value
                self.topTransition(from: previous, to: pending.value, transitionType: pending.transitionType, layout: layout, transition: pending.transition)
                if !self.isReady {
                    self.isReady = true
                    self.isReadyUpdated?()
                }
            }
        }
        
        if controllers.isEmpty && self.state.top != nil {
            let previous = self.state.top
            self.state.top = nil
            self.topTransition(from: previous, to: nil, transitionType: .pop, layout: layout, transition: .immediate)
        }
        
        if let top = self.state.top {
            self.applyLayout(layout: layout, to: top, transition: transition)
        }
        
        if self.state.transition == nil {
            self.keyboardManager?.surfaces = self.state.top?.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
        }
    }
    
    private func topTransition(from fromValue: Child?, to toValue: Child?, transitionType: PendingChild.TransitionType, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if case .animated = transition, let fromValue = fromValue, let toValue = toValue {
            self.keyboardManager?.surfaces = fromValue.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
            if let currentTransition = self.state.transition {
                assertionFailure()
            }
            
            fromValue.value.viewWillDisappear(true)
            toValue.value.viewWillAppear(true)
            toValue.value.setIgnoreAppearanceMethodInvocations(true)
            if let layout = self.state.layout {
                toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
            }
            let mappedTransitionType: NavigationTransition
            let topController: ViewController
            let bottomController: ViewController
            switch transitionType {
            case .push:
                mappedTransitionType = .Push
                self.addSubnode(toValue.value.displayNode)
                topController = toValue.value
                bottomController = fromValue.value
            case .pop:
                mappedTransitionType = .Pop
                self.insertSubnode(toValue.value.displayNode, belowSubnode: fromValue.value.displayNode)
                topController = fromValue.value
                bottomController = toValue.value
            }
            toValue.value.setIgnoreAppearanceMethodInvocations(false)
            
            let topTransition = TopTransition(previous: fromValue, coordinator: NavigationTransitionCoordinator(transition: mappedTransitionType, container: self.view, topView: topController.view, topNavigationBar: topController.navigationBar, bottomView: bottomController.view, bottomNavigationBar: bottomController.navigationBar, didUpdateProgress: nil))
            self.state.transition = topTransition
            
            topTransition.coordinator.animateCompletion(0.0, completion: { [weak self, weak topTransition] in
                guard let strongSelf = self, let topTransition = topTransition, strongSelf.state.transition === topTransition else {
                    return
                }
                strongSelf.state.transition = nil
                
                topTransition.previous.value.setIgnoreAppearanceMethodInvocations(true)
                topTransition.previous.value.displayNode.removeFromSupernode()
                topTransition.previous.value.setIgnoreAppearanceMethodInvocations(false)
                topTransition.previous.value.viewDidDisappear(true)
                if let toValue = strongSelf.state.top, let layout = strongSelf.state.layout {
                    toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                    strongSelf.applyLayout(layout: layout, to: toValue, transition: .immediate)
                    toValue.value.viewDidAppear(true)
                    strongSelf.keyboardManager?.surfaces = toValue.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
                }
            })
        } else {
            self.keyboardManager?.surfaces = toValue?.value.view.flatMap({ [KeyboardSurface(host: $0)] }) ?? []
            if let fromValue = fromValue {
                fromValue.value.viewWillDisappear(false)
                fromValue.value.setIgnoreAppearanceMethodInvocations(true)
                fromValue.value.displayNode.removeFromSupernode()
                fromValue.value.setIgnoreAppearanceMethodInvocations(false)
                fromValue.value.viewDidDisappear(false)
            }
            if let toValue = toValue {
                self.applyLayout(layout: layout, to: toValue, transition: .immediate)
                toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                toValue.value.viewWillAppear(false)
                toValue.value.setIgnoreAppearanceMethodInvocations(true)
                self.addSubnode(toValue.value.displayNode)
                toValue.value.setIgnoreAppearanceMethodInvocations(false)
                toValue.value.viewDidAppear(false)
            }
        }
    }
    
    private func makeChild(layout: ContainerViewLayout, value: ViewController) -> Child {
        value.containerLayoutUpdated(layout, transition: .immediate)
        return Child(value: value, layout: layout)
    }
    
    private func applyLayout(layout: ContainerViewLayout, to child: Child, transition: ContainedViewLayoutTransition) {
        if child.layout != layout {
            child.layout = layout
            child.value.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    private func pendingChildIsReady(_ child: PendingChild) {
        if let pending = self.state.pending, pending === child {
            pending.isReady = true
            self.performUpdate()
        }
    }
    
    private func performUpdate() {
        if let layout = self.state.layout, let canBeClosed = self.state.canBeClosed {
            self.update(layout: layout, canBeClosed: canBeClosed, controllers: self.controllers, transition: .immediate)
        }
    }
}
