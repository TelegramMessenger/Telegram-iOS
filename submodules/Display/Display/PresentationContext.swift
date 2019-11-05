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
    
    var updateHasOpaqueOverlay: ((Bool) -> Void)?
    private(set) var hasOpaqueOverlay: Bool = false {
        didSet {
            if self.hasOpaqueOverlay != oldValue {
                self.updateHasOpaqueOverlay?(self.hasOpaqueOverlay)
            }
        }
    }
    
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
            controller.view.frame = CGRect(origin: CGPoint(), size: initialLayout.size)
            controller.containerLayoutUpdated(initialLayout, transition: .immediate)
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
                        (controller as? UIViewController)?.navigation_setDismiss({ [weak controller] in
                            if let strongSelf = self, let controller = controller {
                                strongSelf.dismiss(controller)
                            }
                        }, rootController: nil)
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(true)
                        if layout != initialLayout {
                            controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                            if let topLevelSubview = strongSelf.topLevelSubview(for: level) {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                if let volumeControlStatusBarNodeView = strongSelf.volumeControlStatusBarNodeView {
                                    view.insertSubview(controller.view, belowSubview: volumeControlStatusBarNodeView)
                                } else {
                                    view.addSubview(controller.view)
                                }
                            }
                            controller.containerLayoutUpdated(layout, transition: .immediate)
                        } else {
                            if let topLevelSubview = strongSelf.topLevelSubview(for: level) {
                                view.insertSubview(controller.view, belowSubview: topLevelSubview)
                            } else {
                                if let volumeControlStatusBarNodeView = strongSelf.volumeControlStatusBarNodeView {
                                    view.insertSubview(controller.view, belowSubview: volumeControlStatusBarNodeView)
                                } else {
                                    view.addSubview(controller.view)
                                }
                            }
                        }
                        (controller as? UIViewController)?.setIgnoreAppearanceMethodInvocations(false)
                        view.layer.invalidateUpTheTree()
                        controller.viewWillAppear(false)
                        if let controller = controller as? PresentableController {
                            controller.viewDidAppear(completion: { [weak self] in
                                self?.notifyAccessibilityScreenChanged()
                            })
                        } else {
                            controller.viewDidAppear(false)
                            strongSelf.notifyAccessibilityScreenChanged()
                        }
                    }
                    strongSelf.updateViews()
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
        if let index = self.controllers.index(where: { $0.0 === controller }) {
            self.controllers.remove(at: index)
            controller.viewWillDisappear(false)
            controller.view.removeFromSuperview()
            controller.viewDidDisappear(false)
            self.updateViews()
        }
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let wasReady = self.ready
        self.layout = layout
        
        if wasReady != self.ready {
            self.readyChanged(wasReady: wasReady)
        } else if self.ready {
            for (controller, _) in self.controllers {
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
            for (controller, _) in self.controllers {
                controller.viewWillAppear(false)
                if let topLevelSubview = self.topLevelSubview {
                    view.insertSubview(controller.view, belowSubview: topLevelSubview)
                } else {
                    if let volumeControlStatusBarNodeView = self.volumeControlStatusBarNodeView {
                        view.insertSubview(controller.view, belowSubview: volumeControlStatusBarNodeView)
                    } else {
                        view.addSubview(controller.view)
                    }
                }
                controller.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                controller.containerLayoutUpdated(layout, transition: .immediate)
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
    
    private func updateViews() {
        self.hasOpaqueOverlay = self.currentlyBlocksBackgroundWhenInOverlay
        var topHasOpaque = false
        for (controller, _) in self.controllers.reversed() {
            if topHasOpaque {
                controller.displayNode.accessibilityElementsHidden = true
            } else {
                if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                    topHasOpaque = true
                }
                controller.displayNode.accessibilityElementsHidden = false
            }
        }
    }
    
    private func notifyAccessibilityScreenChanged() {
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
    }
    
    func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (controller, _) in self.controllers.reversed() {
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
}
