import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public final class NavigationContainer: ASDisplayNode, UIGestureRecognizerDelegate {
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
            if let _ = localIsReady {
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
        let type: PendingChild.TransitionType
        let previous: Child
        let coordinator: NavigationTransitionCoordinator
        
        init(type: PendingChild.TransitionType, previous: Child, coordinator: NavigationTransitionCoordinator) {
            self.type = type
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
    
    private let isFlat: Bool
    public private(set) var controllers: [ViewController] = []
    private var state: State = State(layout: nil, canBeClosed: nil, top: nil, transition: nil, pending: nil)
    
    private var ignoreInputHeight: Bool = false
    
    public private(set) var isReady: Bool = false
    public var isReadyUpdated: (() -> Void)?
    public var controllerRemoved: (ViewController) -> Void
    public var keyboardViewManager: KeyboardViewManager? {
        didSet {
        }
    }
    
    public var canHaveKeyboardFocus: Bool = false {
        didSet {
            if self.canHaveKeyboardFocus != oldValue {
                if !self.canHaveKeyboardFocus {
                    self.view.endEditing(true)
                    self.performUpdate(transition: .animated(duration: 0.5, curve: .spring))
                }
            }
        }
    }
    
    public var isInFocus: Bool = false {
        didSet {
            if self.isInFocus != oldValue {
                self.inFocusUpdated(isInFocus: self.isInFocus)
            }
        }
    }
    
    public func inFocusUpdated(isInFocus: Bool) {
        self.state.top?.value.isInFocus = isInFocus
    }
    
    public var overflowInset: CGFloat = 0.0
    
    private var currentKeyboardLeftEdge: CGFloat = 0.0
    private var additionalKeyboardLeftEdgeOffset: CGFloat = 0.0
    
    var statusBarStyle: StatusBarStyle = .Ignore
    var statusBarStyleUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    private var panRecognizer: InteractiveTransitionGestureRecognizer?
    
    public init(isFlat: Bool, controllerRemoved: @escaping (ViewController) -> Void) {
        self.isFlat = isFlat
        self.controllerRemoved = controllerRemoved
        
        super.init()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)), allowedDirections: { [weak self] _ in
            guard let strongSelf = self, strongSelf.controllers.count > 1 else {
                return []
            }
            return .right
        })
        if #available(iOS 13.4, *) {
            panRecognizer.allowedScrollTypesMask = .continuous
        }
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
        
        /*self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if strongSelf.state.transition != nil {
                return true
            }
            return false
        }*/
    }
    
    func hasNonReadyControllers() -> Bool {
        if let pending = self.state.pending, !pending.isReady {
            return true
        }
        return false
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.panRecognizer, let gestureRecognizer = self.panRecognizer, gestureRecognizer.numberOfTouches == 0 {
            let translation = gestureRecognizer.velocity(in: gestureRecognizer.view)
            if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                return false
            }
            if translation.x < 4.0 {
                return false
            }
            if self.controllers.count == 1 {
                return false
            }
            return true
        } else {
            return true
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let _ = otherGestureRecognizer as? InteractiveTransitionGestureRecognizer {
            return false
        }
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
                
                if !topController.attemptNavigation({
                }) {
                    return
                }
                
                topController.viewWillDisappear(true)
                let topNode = topController.displayNode
                var bottomControllerLayout = layout
                if bottomController.view.disableAutomaticKeyboardHandling.isEmpty {
                    bottomControllerLayout = bottomControllerLayout.withUpdatedInputHeight(nil)
                }
                bottomController.containerLayoutUpdated(bottomControllerLayout, transition: .immediate)
                bottomController.viewWillAppear(true)
                let bottomNode = bottomController.displayNode
                
                let navigationTransitionCoordinator = NavigationTransitionCoordinator(transition: .Pop, isInteractive: true, isFlat: self.isFlat, container: self, topNode: topNode, topNavigationBar: topController.navigationBar, bottomNode: bottomNode, bottomNavigationBar: bottomController.navigationBar, didUpdateProgress: { [weak self, weak bottomController] progress, transition, topFrame, bottomFrame in
                    if let strongSelf = self {
                        if let top = strongSelf.state.top {
                            strongSelf.syncKeyboard(leftEdge: top.value.displayNode.frame.minX, transition: transition)
                            
                            var updatedStatusBarStyle = strongSelf.statusBarStyle
                            if let bottomController = bottomController, progress >= 0.3 {
                                updatedStatusBarStyle = bottomController.statusBar.statusBarStyle
                            } else {
                                updatedStatusBarStyle = top.value.statusBar.statusBarStyle
                            }
                            if strongSelf.statusBarStyle != updatedStatusBarStyle {
                                strongSelf.statusBarStyle = updatedStatusBarStyle
                                strongSelf.statusBarStyleUpdated?(.animated(duration: 0.3, curve: .easeInOut))
                            }
                        }
                    }
                })
                bottomController.displayNode.recursivelyEnsureDisplaySynchronously(true)
                self.state.transition = TopTransition(type: .pop, previous: Child(value: bottomController, layout: layout), coordinator: navigationTransitionCoordinator)
            }
        case .changed:
            if let navigationTransitionCoordinator = self.state.transition?.coordinator, !navigationTransitionCoordinator.animatingCompletion {
                let translation = recognizer.translation(in: self.view).x
                let progress = max(0.0, min(1.0, translation / self.view.frame.width))
                navigationTransitionCoordinator.updateProgress(progress, transition: .immediate, completion: {})
            }
        case .ended, .cancelled:
            if let navigationTransitionCoordinator = self.state.transition?.coordinator, !navigationTransitionCoordinator.animatingCompletion {
                let velocity = recognizer.velocity(in: self.view).x
                
                if velocity > 1000 || navigationTransitionCoordinator.progress > 0.2 {
                    self.state.top?.value.viewWillLeaveNavigation()
                    navigationTransitionCoordinator.animateCompletion(velocity, completion: { [weak self] in
                        guard let strongSelf = self, let _ = strongSelf.state.layout, let _ = strongSelf.state.transition, let top = strongSelf.state.top else {
                            return
                        }
                        
                        let topController = top.value
                        
                        if viewTreeContainsFirstResponder(view: top.value.view) {
                            strongSelf.ignoreInputHeight = true
                        }
                        strongSelf.keyboardViewManager?.dismissEditingWithoutAnimation(view: topController.view)
                        
                        strongSelf.state.transition = nil
                        
                        strongSelf.controllerRemoved(top.value)
                        strongSelf.ignoreInputHeight = false
                    })
                } else {
                    navigationTransitionCoordinator.animateCancel({ [weak self] in
                        guard let strongSelf = self, let top = strongSelf.state.top, let transition = strongSelf.state.transition else {
                            return
                        }
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
    
    public func update(layout: ContainerViewLayout, canBeClosed: Bool, controllers: [ViewController], transition: ContainedViewLayoutTransition) {
        self.state.layout = layout
        self.state.canBeClosed = canBeClosed
        
        var controllersUpdated = false
        if self.controllers.count != controllers.count {
            controllersUpdated = true
        } else {
            for i in 0 ..< controllers.count {
                if self.controllers[i] !== controllers[i] {
                    controllersUpdated = true
                    break
                }
            }
        }
        if controllersUpdated {
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
        
            if controllers.last !== self.state.top?.value {
                self.state.top?.value.statusBar.alphaUpdated = nil
                if let controller = controllers.last {
                    controller.statusBar.alphaUpdated = { [weak self, weak controller] transition in
                        guard let strongSelf = self, let controller = controller else {
                            return
                        }
                        if strongSelf.state.top?.value === controller && strongSelf.state.transition == nil {
                            strongSelf.statusBarStyleUpdated?(transition)
                        }
                    }
                }
                
                if controllers.last !== self.state.pending?.value.value {
                    self.state.pending = nil
                    if let last = controllers.last {
                        let transitionType: PendingChild.TransitionType
                        if !previousControllers.contains(where: { $0 === last }) {
                            transitionType = .push
                        } else {
                            transitionType = .pop
                        }
                        var updatedLayout = layout
                        if last.view.disableAutomaticKeyboardHandling.isEmpty {
                            updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                        }
                        self.state.pending = PendingChild(value: self.makeChild(layout: updatedLayout, value: last), transitionType: transitionType, transition: transition, update: { [weak self] pendingChild in
                            self?.pendingChildIsReady(pendingChild)
                        })
                    }
                }
            }
        }
        
        var statusBarTransition = transition
        
        var ignoreInputHeight = false
        if let pending = self.state.pending {
            if pending.isReady {
                self.state.pending = nil
                let previous = self.state.top
                previous?.value.isInFocus = false
                self.state.top = pending.value
                var updatedLayout = layout
                if pending.value.value.view.disableAutomaticKeyboardHandling.isEmpty {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
                if case .regular = layout.metrics.widthClass, pending.value.layout.inputHeight == nil {
                    ignoreInputHeight = true
                }
                self.topTransition(from: previous, to: pending.value, transitionType: pending.transitionType, layout: updatedLayout, transition: pending.transition)
                self.state.top?.value.isInFocus = self.isInFocus
                statusBarTransition = pending.transition
                if !self.isReady {
                    self.isReady = true
                    self.isReadyUpdated?()
                }
            }
        }
        
        if controllers.isEmpty && self.state.top != nil {
            let previous = self.state.top
            previous?.value.isInFocus = false
            self.state.top = nil
            self.topTransition(from: previous, to: nil, transitionType: .pop, layout: layout, transition: .immediate)
        }
        
        var updatedStatusBarStyle = self.statusBarStyle
        if let top = self.state.top {
            var updatedLayout = layout
            if let _ = self.state.transition, top.value.view.disableAutomaticKeyboardHandling.isEmpty {
                if !viewTreeContainsFirstResponder(view: top.value.view) {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
            if ignoreInputHeight {
                updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
            }
            self.applyLayout(layout: updatedLayout, to: top, isMaster: true, transition: transition)
            if let childTransition = self.state.transition, childTransition.coordinator.isInteractive {
                switch childTransition.type {
                case .push:
                    if childTransition.coordinator.progress >= 0.3 {
                        updatedStatusBarStyle = top.value.statusBar.statusBarStyle
                    } else {
                        updatedStatusBarStyle = childTransition.previous.value.statusBar.statusBarStyle
                    }
                case .pop:
                    if childTransition.coordinator.progress >= 0.3 {
                        updatedStatusBarStyle = childTransition.previous.value.statusBar.statusBarStyle
                    } else {
                        updatedStatusBarStyle = top.value.statusBar.statusBarStyle
                    }
                }
            } else {
                updatedStatusBarStyle = top.value.statusBar.statusBarStyle
            }
        } else {
            updatedStatusBarStyle = .Ignore
        }
        if self.statusBarStyle != updatedStatusBarStyle {
            self.statusBarStyle = updatedStatusBarStyle
            self.statusBarStyleUpdated?(statusBarTransition)
        }
    }
    
    private func topTransition(from fromValue: Child?, to toValue: Child?, transitionType: PendingChild.TransitionType, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if case .animated = transition, let fromValue = fromValue, let toValue = toValue {
            if let currentTransition = self.state.transition {
                currentTransition.coordinator.performCompletion(completion: {
                })
            }
            
            fromValue.value.viewWillLeaveNavigation()
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
            
            let topTransition = TopTransition(type: transitionType, previous: fromValue, coordinator: NavigationTransitionCoordinator(transition: mappedTransitionType, isInteractive: false, isFlat: self.isFlat, container: self, topNode: topController.displayNode, topNavigationBar: topController.navigationBar, bottomNode: bottomController.displayNode, bottomNavigationBar: bottomController.navigationBar, didUpdateProgress: { [weak self] _, transition, topFrame, bottomFrame in
                guard let strongSelf = self else {
                    return
                }
                switch transitionType {
                case .push:
                    if let _ = strongSelf.state.transition, let top = strongSelf.state.top, viewTreeContainsFirstResponder(view: top.value.view) {
                        strongSelf.syncKeyboard(leftEdge: topFrame.minX, transition: transition)
                    } else {
                        if let hasActiveInput = strongSelf.state.top?.value.hasActiveInput, hasActiveInput {
                        } else {
                            strongSelf.syncKeyboard(leftEdge: topFrame.minX - bottomFrame.width, transition: transition)
                        }
                    }
                case .pop:
                    strongSelf.syncKeyboard(leftEdge: topFrame.minX, transition: transition)
                }
            }))
            self.state.transition = topTransition
            
            topTransition.coordinator.animateCompletion(0.0, completion: { [weak self, weak topTransition] in
                guard let strongSelf = self, let topTransition = topTransition, strongSelf.state.transition === topTransition else {
                    return
                }
                
                if viewTreeContainsFirstResponder(view: topTransition.previous.value.view) {
                    strongSelf.ignoreInputHeight = true
                }
                strongSelf.keyboardViewManager?.dismissEditingWithoutAnimation(view: topTransition.previous.value.view)
                strongSelf.state.transition = nil
                
                topTransition.previous.value.setIgnoreAppearanceMethodInvocations(true)
                topTransition.previous.value.displayNode.removeFromSupernode()
                topTransition.previous.value.setIgnoreAppearanceMethodInvocations(false)
                topTransition.previous.value.viewDidDisappear(true)
                if let toValue = strongSelf.state.top, let layout = strongSelf.state.layout {
                    toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                    strongSelf.applyLayout(layout: layout, to: toValue, isMaster: true, transition: .immediate)
                    toValue.value.viewDidAppear(true)
                }
                
                strongSelf.ignoreInputHeight = false
            })
        } else {
            if let fromValue = fromValue {
                if viewTreeContainsFirstResponder(view: fromValue.value.view) {
                    self.ignoreInputHeight = true
                }
                
                fromValue.value.viewWillLeaveNavigation()
                fromValue.value.viewWillDisappear(false)
                
                self.keyboardViewManager?.dismissEditingWithoutAnimation(view: fromValue.value.view)
                
                fromValue.value.setIgnoreAppearanceMethodInvocations(true)
                fromValue.value.displayNode.removeFromSupernode()
                fromValue.value.setIgnoreAppearanceMethodInvocations(false)
                fromValue.value.viewDidDisappear(false)
            }
            if let toValue = toValue {
                self.applyLayout(layout: layout, to: toValue, isMaster: true, transition: .immediate)
                toValue.value.displayNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                toValue.value.viewWillAppear(false)
                toValue.value.setIgnoreAppearanceMethodInvocations(true)
                self.addSubnode(toValue.value.displayNode)
                toValue.value.setIgnoreAppearanceMethodInvocations(false)
                toValue.value.displayNode.recursivelyEnsureDisplaySynchronously(true)
                toValue.value.viewDidAppear(false)
            }
            self.ignoreInputHeight = false
        }
    }
    
    private func makeChild(layout: ContainerViewLayout, value: ViewController) -> Child {
        var updatedLayout = layout
        if value.view.disableAutomaticKeyboardHandling.isEmpty {
            updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
        }
        value.containerLayoutUpdated(updatedLayout, transition: .immediate)
        return Child(value: value, layout: updatedLayout)
    }
    
    private func applyLayout(layout: ContainerViewLayout, to child: Child, isMaster: Bool, transition: ContainedViewLayoutTransition) {
        var childFrame = CGRect(origin: CGPoint(), size: layout.size)
        
        var updatedLayout = layout
        
        var shouldSyncKeyboard = false
        if let transition = self.state.transition {
            childFrame.origin.x = child.value.displayNode.frame.origin.x
            switch transition.type {
            case .pop:
                if transition.previous.value === child.value {
                    shouldSyncKeyboard = true
                }
            case .push:
                break
            }
            if updatedLayout.inputHeight != nil {
                if !self.canHaveKeyboardFocus && child.value.view.disableAutomaticKeyboardHandling.isEmpty {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
        } else {
            if isMaster {
                shouldSyncKeyboard = true
            }
            
            if updatedLayout.inputHeight != nil && child.value.view.disableAutomaticKeyboardHandling.isEmpty {
                if !self.canHaveKeyboardFocus || self.ignoreInputHeight {
                    updatedLayout = updatedLayout.withUpdatedInputHeight(nil)
                }
            }
        }
        if child.value.displayNode.frame != childFrame {
            transition.updateFrame(node: child.value.displayNode, frame: childFrame)
        }
        if shouldSyncKeyboard && isMaster {
            self.syncKeyboard(leftEdge: childFrame.minX, transition: transition)
        }
        if child.layout != updatedLayout {
            child.layout = updatedLayout
            child.value.containerLayoutUpdated(updatedLayout, transition: transition)
        }
    }
    
    public func updateAdditionalKeyboardLeftEdgeOffset(_ offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.additionalKeyboardLeftEdgeOffset = offset
        self.syncKeyboard(leftEdge: self.currentKeyboardLeftEdge, transition: transition)
    }
    
    private func syncKeyboard(leftEdge: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentKeyboardLeftEdge = leftEdge
        self.keyboardViewManager?.update(leftEdge: self.additionalKeyboardLeftEdgeOffset + leftEdge, transition: transition)
    }
    
    private func pendingChildIsReady(_ child: PendingChild) {
        if let pending = self.state.pending, pending === child {
            pending.isReady = true
            self.performUpdate(transition: .immediate)
        }
    }
    
    private func performUpdate(transition: ContainedViewLayoutTransition) {
        if let layout = self.state.layout, let canBeClosed = self.state.canBeClosed {
            self.update(layout: layout, canBeClosed: canBeClosed, controllers: self.controllers, transition: transition)
        }
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        if self.state.transition != nil {
            return self.view
        }
        return super.hitTest(point, with: event)
    }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        if let controller = self.controllers.last {
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        if let transition = self.state.transition {
            let controller = transition.previous.value
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        return supportedOrientations
    }
}
