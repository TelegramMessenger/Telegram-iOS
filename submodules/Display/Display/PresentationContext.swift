import UIKit
import SwiftSignalKit

public struct PresentationSurfaceLevel: RawRepresentable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let root = PresentationSurfaceLevel(rawValue: 0)
}

public enum PresentationContextType {
    case current
    case window(PresentationSurfaceLevel)
}

public final class PresentationContext {
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
    
    weak var volumeControlStatusBarNodeView: UIView?
    
    var updateIsInteractionBlocked: ((Bool) -> Void)?
    var updateHasBlocked: ((Bool) -> Void)?
    
    var updateHasOpaqueOverlay: ((Bool) -> Void)?
    private(set) var hasOpaqueOverlay: Bool = false {
        didSet {
            if self.hasOpaqueOverlay != oldValue {
                self.updateHasOpaqueOverlay?(self.hasOpaqueOverlay)
            }
        }
    }
    
    private var modalPresentationValue: CGFloat = 0.0
    var updateModalTransition: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private var layout: ContainerViewLayout?
    
    private var ready: Bool {
        return self.view != nil && self.layout != nil
    }
    
    private(set) var controllers: [(ContainableController, PresentationSurfaceLevel)] = []
    
    private var presentationDisposables = DisposableSet()
    
    var topLevelSubview: UIView?
    
    var isCurrentlyOpaque: Bool {
        for (controller, _) in self.controllers {
            if controller.isOpaqueWhenInOverlay && controller.isViewLoaded {
                if traceIsOpaque(layer: controller.view.layer, rect: controller.view.bounds) {
                    return true
                }
            }
        }
        return false
    }
    
    var currentlyBlocksBackgroundWhenInOverlay: Bool {
        for (controller, _) in self.controllers {
            if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                return true
            }
        }
        return false
    }
    
    private func topLevelSubview(for level: PresentationSurfaceLevel) -> UIView? {
        var topController: ContainableController?
        for (controller, controllerLevel) in self.controllers.reversed() {
            if !controller.isViewLoaded || controller.view.superview == nil {
                continue
            }
            if controllerLevel.rawValue > level.rawValue {
                topController = controller
            } else {
                break
            }
        }
        if let topController = topController {
            return topController.view
        } else {
            return self.topLevelSubview
        }
    }
    
    private var nextBlockInteractionToken = 0
    private var blockInteractionTokens = Set<Int>()
    
    private func addBlockInteraction() -> Int {
        let token = self.nextBlockInteractionToken
        self.nextBlockInteractionToken += 1
        let wasEmpty = self.blockInteractionTokens.isEmpty
        self.blockInteractionTokens.insert(token)
        if wasEmpty {
            self.updateIsInteractionBlocked?(true)
        }
        return token
    }
    
    private func removeBlockInteraction(_ token: Int) {
        let wasEmpty = self.blockInteractionTokens.isEmpty
        self.blockInteractionTokens.remove(token)
        if !wasEmpty && self.blockInteractionTokens.isEmpty {
            self.updateIsInteractionBlocked?(false)
        }
    }
    
    private func layoutForController(containerLayout: ContainerViewLayout, controller: ContainableController) -> (ContainerViewLayout, CGRect) {
        if controller.isModalWhenInOverlay, case .regular = containerLayout.metrics.widthClass  {
            let topInset = (containerLayout.statusBarHeight ?? 0.0) + 20.0
            var updatedLayout = containerLayout
            updatedLayout.statusBarHeight = nil
            updatedLayout.size = CGSize(width: min(containerLayout.size.width - 90.0, 750.0), height: min(containerLayout.size.height - 90.0, 940.0))
            updatedLayout.safeInsets = UIEdgeInsets()
            updatedLayout.intrinsicInsets = UIEdgeInsets()
            return (updatedLayout, CGRect(origin: CGPoint(x: (containerLayout.size.width - updatedLayout.size.width) / 2.0, y: (containerLayout.size.height - updatedLayout.size.height) / 2.0), size: updatedLayout.size))
        } else {
            return (containerLayout, CGRect(origin: CGPoint(), size: containerLayout.size))
        }
    }
    
    public func present(_ controller: ContainableController, on level: PresentationSurfaceLevel, blockInteraction: Bool = false, completion: @escaping () -> Void) {
        let controllerReady = controller.ready.get()
        |> filter({ $0 })
        |> take(1)
        |> deliverOnMainQueue
        |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(true))
        
        if let _ = self.view, let initialLayout = self.layout {
            if let controller = controller as? ViewController {
                if controller.lockOrientation {
                    let orientations: UIInterfaceOrientationMask
                    if initialLayout.size.width < initialLayout.size.height {
                        orientations = .portrait
                    } else {
                        orientations = .landscape
                    }
                    
                    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: orientations, compactSize: orientations)
                }
            }
            let (controllerLayout, controllerFrame) = self.layoutForController(containerLayout: initialLayout, controller: controller)
            controller.view.frame = controllerFrame
            controller.containerLayoutUpdated(controllerLayout, transition: .immediate)
            var blockInteractionToken: Int?
            if blockInteraction {
                blockInteractionToken = self.addBlockInteraction()
            }
            self.presentationDisposables.add((controllerReady |> afterDisposed { [weak self] in
                Queue.mainQueue().async {
                    if let blockInteractionToken = blockInteractionToken {
                        self?.removeBlockInteraction(blockInteractionToken)
                    }
                    completion()
                }
            }).start(next: { [weak self] _ in
                if let strongSelf = self {
                    if let blockInteractionToken = blockInteractionToken {
                        strongSelf.removeBlockInteraction(blockInteractionToken)
                    }
                    if strongSelf.controllers.contains(where: { $0.0 === controller }) {
                        return
                    }
                    
                    var insertIndex: Int?
                    for i in (0 ..< strongSelf.controllers.count).reversed() {
                        if strongSelf.controllers[i].1.rawValue > level.rawValue {
                            insertIndex = i
                        }
                    }
                    strongSelf.controllers.insert((controller, level), at: insertIndex ?? strongSelf.controllers.count)
                    if let view = strongSelf.view, let layout = strongSelf.layout {
                        let (updatedControllerLayout, updatedControllerFrame) = strongSelf.layoutForController(containerLayout: layout, controller: controller)
                        
                        (controller as? UIViewController)?.navigation_setDismiss({ [weak controller] in
                            if let strongSelf = self, let controller = controller {
                                strongSelf.dismiss(controller)
                            }
                        }, rootController: nil)
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(true)
                        if updatedControllerLayout != controllerLayout {
                            controller.view.frame = updatedControllerFrame
                            if let topLevelSubview = strongSelf.topLevelSubview(for: level) {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                view.addSubview(controller.view)
                            }
                            controller.containerLayoutUpdated(updatedControllerLayout, transition: .immediate)
                        } else {
                            if let topLevelSubview = strongSelf.topLevelSubview(for: level) {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                view.addSubview(controller.view)
                            }
                        }
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(false)
                        view.layer.invalidateUpTheTree()
                        strongSelf.updateViews()
                        controller.viewWillAppear(false)
                        if let controller = controller as? PresentableController {
                            controller.viewDidAppear(completion: { [weak self] in
                                self?.notifyAccessibilityScreenChanged()
                            })
                        } else {
                            controller.viewDidAppear(false)
                            strongSelf.notifyAccessibilityScreenChanged()
                        }
                        
                        if controller.isModalWhenInOverlay, case .regular = layout.metrics.widthClass {
                            let springDuration: Double = 0.52
                            let springDamping: CGFloat = 110.0
                            
                            controller.view.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: layout.size.height - controllerFrame.minY)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, additive: true)
                        
                            strongSelf.dimView?.frame = CGRect(origin: CGPoint(), size: layout.size)
                            strongSelf.dimView?.alpha = 1.0
                            strongSelf.dimView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }))
        } else {
            self.controllers.append((controller, level))
            self.updateViews()
        }
    }
    
    deinit {
        self.presentationDisposables.dispose()
    }
    
    private func dismiss(_ controller: ContainableController) {
        if let index = self.controllers.firstIndex(where: { $0.0 === controller }) {
            self.controllers.remove(at: index)
            if controller.isModalWhenInOverlay, let layout = self.layout, case .regular = layout.metrics.widthClass {
                let (controllerLayout, controllerFrame) = self.layoutForController(containerLayout: layout, controller: controller)
                
                let springDuration: Double = 0.52
                let springDamping: CGFloat = 110.0
                controller.view.layer.animateSpring(from: NSValue(cgPoint: CGPoint()), to: NSValue(cgPoint: CGPoint(x: 0.0, y: layout.size.height - controllerFrame.minY)), keyPath: "position", duration: springDuration, initialVelocity: 0.0, damping: springDamping, removeOnCompletion: false, additive: true, completion: { finished in
                    controller.viewWillDisappear(false)
                    controller.view.removeFromSuperview()
                    controller.viewDidDisappear(false)
                    self.updateViews()
                })
            } else {
                controller.viewWillDisappear(false)
                controller.view.removeFromSuperview()
                controller.viewDidDisappear(false)
                self.updateViews()
            }
            
            let previousAlpha = self.dimView?.alpha ?? 0.0
            self.dimView?.alpha = 0.0
            self.dimView?.layer.animateAlpha(from: previousAlpha, to: 0.0, duration: 0.2)
        }
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let wasReady = self.ready
        self.layout = layout
        
        if wasReady != self.ready {
            self.readyChanged(wasReady: wasReady)
        } else if self.ready {
            self.dimView?.frame = CGRect(origin: CGPoint(), size: layout.size)
            for (controller, _) in self.controllers {
                let (controllerLayout, controllerFrame) = self.layoutForController(containerLayout: layout, controller: controller)
                controller.view.frame = controllerFrame
                controller.containerLayoutUpdated(controllerLayout, transition: transition)
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
    
    var dimView: UIView?
    
    private func addViews() {
        if let view = self.view, let layout = self.layout {
            let dimView: UIView
            if let currentDimView = self.dimView {
                dimView = currentDimView
            } else {
                dimView = UIView()
                dimView.alpha = 0.0
                dimView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.dimView = dimView
            }
            view.addSubview(dimView)
            
            for (controller, _) in self.controllers {
                controller.viewWillAppear(false)
                if let topLevelSubview = self.topLevelSubview {
                    view.insertSubview(controller.view, belowSubview: topLevelSubview)
                } else {
                    view.addSubview(controller.view)
                }
                let (controllerLayout, controllerFrame) = self.layoutForController(containerLayout: layout, controller: controller)
                controller.view.frame = controllerFrame
                controller.containerLayoutUpdated(controllerLayout, transition: .immediate)
                if let controller = controller as? PresentableController {
                    controller.viewDidAppear(completion: { [weak self] in
                        self?.notifyAccessibilityScreenChanged()
                    })
                } else {
                    controller.viewDidAppear(false)
                    self.notifyAccessibilityScreenChanged()
                }
            }
            self.updateViews()
        }
    }
    
    private func removeViews() {
        for (controller, _) in self.controllers {
            controller.viewWillDisappear(false)
            controller.view.removeFromSuperview()
            controller.viewDidDisappear(false)
        }
    }
    
    private weak var currentModalController: ContainableController?
    
    private func updateViews() {
        self.hasOpaqueOverlay = self.currentlyBlocksBackgroundWhenInOverlay
        var modalController: ContainableController?
        var topHasOpaque = false
        for (controller, _) in self.controllers.reversed() {
            if controller.isModalWhenInOverlay {
                if modalController == nil {
                    modalController = controller
                }
            }
            if topHasOpaque {
                controller.displayNode.accessibilityElementsHidden = true
            } else {
                if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                    topHasOpaque = true
                }
                controller.displayNode.accessibilityElementsHidden = false
            }
        }
        
        if self.currentModalController !== modalController {
            if let currentModalController = self.currentModalController {
                currentModalController.updateTransitionWhenPresentedAsModal = nil
                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                    currentModalController.displayNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                }
                currentModalController.displayNode.layer.cornerRadius = 0.0
            }
            self.currentModalController = modalController
            if let modalController = modalController {
                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                    if let layout = self.layout, case .regular = layout.metrics.widthClass {
                        modalController.displayNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    } else {
                        modalController.displayNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    }
                }
                modalController.displayNode.layer.cornerRadius = 10.0
                modalController.updateTransitionWhenPresentedAsModal = { [weak self, weak modalController] value, transition in
                    guard let strongSelf = self, let modalController = modalController, modalController === strongSelf.currentModalController else {
                        return
                    }
                    if strongSelf.modalPresentationValue != value {
                        strongSelf.modalPresentationValue = value
                        strongSelf.updateModalTransition?(value, transition)
                    }
                }
            } else {
                if self.modalPresentationValue != 0.0 {
                    self.modalPresentationValue = 0.0
                    self.updateModalTransition?(0.0, .animated(duration: 0.3, curve: .spring))
                }
            }
        }
    }
    
    private func notifyAccessibilityScreenChanged() {
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
    }
    
    func hitTest(view: UIView, point: CGPoint, with event: UIEvent?) -> UIView? {
        for (controller, _) in self.controllers.reversed() {
            if controller.isViewLoaded {
                if let result = controller.view.hitTest(view.convert(point, to: controller.view), with: event) {
                    return result
                }
            }
        }
        return nil
    }
    
    func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        if self.ready {
            for (controller, _) in self.controllers {
                controller.updateToInterfaceOrientation(orientation)
            }
        }
    }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        var mask = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
        
        for (controller, _) in self.controllers {
            mask = mask.intersection(controller.combinedSupportedOrientations(currentOrientationToLock: currentOrientationToLock))
        }
        
        return mask
    }
    
    func combinedDeferScreenEdgeGestures() -> UIRectEdge {
        var edges: UIRectEdge = []
        
        for (controller, _) in self.controllers {
            edges = edges.union(controller.deferScreenEdgeGestures)
        }
        
        return edges
    }
    
    func combinedPrefersOnScreenNavigationHidden() -> Bool {
        var hidden: Bool = false
        
        for (controller, _) in self.controllers {
            if let controller = controller as? ViewController {
                hidden = hidden || controller.prefersOnScreenNavigationHidden
            }
        }
        
        return hidden
    }
}
