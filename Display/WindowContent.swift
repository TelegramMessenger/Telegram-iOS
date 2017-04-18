import Foundation
import AsyncDisplayKit

private class WindowRootViewController: UIViewController {
    var presentController: ((UIViewController, Bool, (() -> Void)?) -> Void)?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
}

private struct WindowLayout: Equatable {
    public let size: CGSize
    public let statusBarHeight: CGFloat?
    public let inputHeight: CGFloat?
    public let inputMinimized: Bool
}

private func ==(lhs: WindowLayout, rhs: WindowLayout) -> Bool {
    if !lhs.size.equalTo(rhs.size) {
        return false
    }
    
    if let lhsStatusBarHeight = lhs.statusBarHeight {
        if let rhsStatusBarHeight = rhs.statusBarHeight {
            if !lhsStatusBarHeight.isEqual(to: rhsStatusBarHeight) {
                return false
            }
        } else {
            return false
        }
    } else if let _ = rhs.statusBarHeight {
        return false
    }
    
    if let lhsInputHeight = lhs.inputHeight {
        if let rhsInputHeight = rhs.inputHeight {
            if !lhsInputHeight.isEqual(to: rhsInputHeight) {
                return false
            }
        } else {
            return false
        }
    } else if let _ = rhs.inputHeight {
        return false
    }
    
    if lhs.inputMinimized != rhs.inputMinimized {
        return false
    }
    
    return true
}

private struct UpdatingLayout {
    var layout: WindowLayout
    var transition: ContainedViewLayoutTransition
    
    mutating func update(transition: ContainedViewLayoutTransition, override: Bool) {
        var update = false
        if case .immediate = self.transition {
            update = true
        } else if override {
            update = true
        }
        if update {
            self.transition = transition
        }
    }
    
    mutating func update(size: CGSize, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: size, statusBarHeight: self.layout.statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(statusBarHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(inputHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: self.layout.statusBarHeight, inputHeight: inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(inputMinimized: Bool, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: self.layout.statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: inputMinimized)
    }
}

private let orientationChangeDuration: Double = UIDevice.current.userInterfaceIdiom == .pad ? 0.4 : 0.3
private let statusBarHiddenInLandscape: Bool = UIDevice.current.userInterfaceIdiom == .phone

private func containedLayoutForWindowLayout(_ layout: WindowLayout) -> ContainerViewLayout {
    var inputHeight: CGFloat? = layout.inputHeight
    if let inputHeightValue = inputHeight, layout.inputMinimized {
        inputHeight = floor(0.85 * inputHeightValue)
    }
    
    return ContainerViewLayout(size: layout.size, intrinsicInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: inputHeight)
}

public final class WindowHostView {
    public let view: UIView
    public let isRotating: () -> Bool
    
    let updateSupportedInterfaceOrientations: (UIInterfaceOrientationMask) -> Void
    
    var present: ((ViewController) -> Void)?
    var updateSize: ((CGSize) -> Void)?
    var layoutSubviews: (() -> Void)?
    var updateToInterfaceOrientation: (() -> Void)?
    var isUpdatingOrientationLayout = false
    var hitTest: ((CGPoint, UIEvent?) -> UIView?)?
    
    init(view: UIView, isRotating: @escaping () -> Bool, updateSupportedInterfaceOrientations: @escaping (UIInterfaceOrientationMask) -> Void) {
        self.view = view
        self.isRotating = isRotating
        self.updateSupportedInterfaceOrientations = updateSupportedInterfaceOrientations
    }
}

public struct WindowTracingTags {
    public static let statusBar: Int32 = 0
    public static let keyboard: Int32 = 1
}

public protocol WindowHost {
    func present(_ controller: ViewController)
}

public class Window1 {
    public let hostView: WindowHostView
    
    private let statusBarHost: StatusBarHost?
    private let statusBarManager: StatusBarManager?
    private let keyboardManager: KeyboardManager?
    private var statusBarChangeObserver: AnyObject?
    private var keyboardFrameChangeObserver: AnyObject?
    
    private var windowLayout: WindowLayout
    private var updatingLayout: UpdatingLayout?
    
    private let presentationContext: PresentationContext
    
    private var tracingStatusBarsInvalidated = false
    
    private var statusBarHidden = false
    
    public init(hostView: WindowHostView, statusBarHost: StatusBarHost?) {
        self.hostView = hostView
        
        self.statusBarHost = statusBarHost
        let statusBarHeight: CGFloat
        if let statusBarHost = statusBarHost {
            self.statusBarManager = StatusBarManager(host: statusBarHost)
            statusBarHeight = statusBarHost.statusBarFrame.size.height
            self.keyboardManager = KeyboardManager(host: statusBarHost)
        } else {
            self.statusBarManager = nil
            self.keyboardManager = nil
            statusBarHeight = 20.0
        }
        
        let minimized: Bool
        if let keyboardManager = self.keyboardManager {
            minimized = keyboardManager.minimized
        } else {
            minimized = false
        }
        
        self.windowLayout = WindowLayout(size: self.hostView.view.bounds.size, statusBarHeight: statusBarHeight, inputHeight: 0.0, inputMinimized: minimized)
        self.presentationContext = PresentationContext()
        
        self.hostView.present = { [weak self] controller in
            self?.present(controller)
        }
        
        self.hostView.updateSize = { [weak self] size in
            self?.updateSize(size)
        }
        
        self.hostView.view.layer.setInvalidateTracingSublayers { [weak self] in
            self?.invalidateTracingStatusBars()
        }
        
        self.hostView.layoutSubviews = { [weak self] in
            self?.layoutSubviews()
        }
        
        self.hostView.updateToInterfaceOrientation = { [weak self] in
            self?.updateToInterfaceOrientation()
        }
        
        self.hostView.hitTest = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
        
        self.keyboardManager?.minimizedUpdated = { [weak self] in
            if let strongSelf = self {
                strongSelf.updateLayout { current in
                    current.update(inputMinimized: strongSelf.keyboardManager!.minimized, transition: .immediate, overrideTransition: false)
                }
            }
        }
        
        self.presentationContext.view = self.hostView.view
        self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
        
        self.statusBarChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillChangeStatusBarFrame, object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self {
                let statusBarHeight: CGFloat = max(20.0, (notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue)?.cgRectValue.height ?? 20.0)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
                strongSelf.updateLayout { $0.update(statusBarHeight: statusBarHeight, transition: transition, overrideTransition: false) }
            }
        })
        
        self.keyboardFrameChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                let keyboardFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect()
                let keyboardHeight = max(0.0, UIScreen.main.bounds.size.height - keyboardFrame.minY)
                var duration: Double = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                if duration > Double.ulpOfOne {
                    duration = 0.5
                }
                let curve: UInt = (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
                
                let transitionCurve: ContainedViewLayoutTransitionCurve
                if curve == 7 {
                    transitionCurve = .spring
                } else {
                    transitionCurve = .easeInOut
                }
                
                strongSelf.updateLayout { $0.update(inputHeight: keyboardHeight.isLessThanOrEqualTo(0.0) ? nil : keyboardHeight, transition: .animated(duration: duration, curve: transitionCurve), overrideTransition: false) }
            }
        })
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let statusBarChangeObserver = self.statusBarChangeObserver {
            NotificationCenter.default.removeObserver(statusBarChangeObserver)
        }
        if let keyboardFrameChangeObserver = self.keyboardFrameChangeObserver {
            NotificationCenter.default.removeObserver(keyboardFrameChangeObserver)
        }
    }
    
    private func invalidateTracingStatusBars() {
        self.tracingStatusBarsInvalidated = true
        self.hostView.view.setNeedsLayout()
    }
    
    public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for view in self.hostView.view.subviews.reversed() {
            if NSStringFromClass(type(of: view)) == "UITransitionView" {
                if let result = view.hitTest(point, with: event) {
                    return result
                }
            }
        }
        
        if let result = self._topLevelOverlayController?.view.hitTest(point, with: event) {
            return result
        }
        
        if let result = self.presentationContext.hitTest(point, with: event) {
            return result
        }
        return self.viewController?.view.hitTest(point, with: event)
    }
    
    func updateSize(_ value: CGSize) {
        let transition: ContainedViewLayoutTransition
        if self.hostView.isRotating() {
            transition = .animated(duration: orientationChangeDuration, curve: .easeInOut)
        } else {
            transition = .immediate
        }
        self.updateLayout { $0.update(size: value, transition: transition, overrideTransition: true) }
    }
    
    private var _rootController: ContainableController?
    public var viewController: ContainableController? {
        get {
            return _rootController
        }
        set(value) {
            if let rootController = self._rootController {
                rootController.view.removeFromSuperview()
            }
            self._rootController = value
            
            if let rootController = self._rootController {
                rootController.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
                
                self.hostView.view.addSubview(rootController.view)
            }
        }
    }
    
    private var _topLevelOverlayController: ContainableController?
    public var topLevelOverlayController: ContainableController? {
        get {
            return _topLevelOverlayController
        }
        set(value) {
            if let topLevelOverlayController = self._topLevelOverlayController {
                topLevelOverlayController.view.removeFromSuperview()
            }
            self._topLevelOverlayController = value
            
            if let topLevelOverlayController = self._topLevelOverlayController {
                topLevelOverlayController.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
                
                self.hostView.view.addSubview(topLevelOverlayController.view)
            }
            
            self.presentationContext.topLevelSubview = self._topLevelOverlayController?.view
        }
    }
    
    private func layoutSubviews() {
        if self.tracingStatusBarsInvalidated, let statusBarManager = statusBarManager, let keyboardManager = keyboardManager {
            self.tracingStatusBarsInvalidated = false
            
            if self.statusBarHidden {
                statusBarManager.surfaces = []
            } else {
                var statusBarSurfaces: [StatusBarSurface] = []
                for layers in self.hostView.view.layer.traceableLayerSurfaces(withTag: WindowTracingTags.statusBar) {
                    let surface = StatusBarSurface()
                    for layer in layers {
                        let traceableInfo = layer.traceableInfo()
                        if let statusBar = traceableInfo?.userData as? StatusBar {
                            surface.addStatusBar(statusBar)
                        }
                    }
                    statusBarSurfaces.append(surface)
                }
                self.hostView.view.layer.adjustTraceableLayerTransforms(CGSize())
                statusBarManager.surfaces = statusBarSurfaces
            }
            
            var keyboardSurfaces: [KeyboardSurface] = []
            for layers in self.hostView.view.layer.traceableLayerSurfaces(withTag: WindowTracingTags.keyboard) {
                for layer in layers {
                    if let view = layer.delegate as? UITracingLayerView {
                        keyboardSurfaces.append(KeyboardSurface(host: view))
                    }
                }
            }
            keyboardManager.surfaces = keyboardSurfaces
            self.hostView.updateSupportedInterfaceOrientations(self.presentationContext.combinedSupportedOrientations())
        }
        
        if !UIWindow.isDeviceRotating() {
            if !self.hostView.isUpdatingOrientationLayout {
                self.commitUpdatingLayout()
            } else {
                self.addPostUpdateToInterfaceOrientationBlock(f: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.hostView.view.setNeedsLayout()
                    }
                })
            }
        } else {
            UIWindow.addPostDeviceOrientationDidChange({ [weak self] in
                if let strongSelf = self {
                    strongSelf.hostView.view.setNeedsLayout()
                }
            })
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [(Void) -> Void] = []
    
    private func updateToInterfaceOrientation() {
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: @escaping (Void) -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
    
    private func updateLayout(_ update: (inout UpdatingLayout) -> ()) {
        if self.updatingLayout == nil {
            self.updatingLayout = UpdatingLayout(layout: self.windowLayout, transition: .immediate)
        }
        update(&self.updatingLayout!)
        self.hostView.view.setNeedsLayout()
    }
    
    private func commitUpdatingLayout() {
        if let updatingLayout = self.updatingLayout {
            self.updatingLayout = nil
            if updatingLayout.layout != self.windowLayout {
                var statusBarHeight: CGFloat?
                if let statusBarHost = self.statusBarHost {
                    statusBarHeight = statusBarHost.statusBarFrame.size.height
                } else {
                    statusBarHeight = 20.0
                }
                let statusBarWasHidden = self.statusBarHidden
                if statusBarHiddenInLandscape && updatingLayout.layout.size.width > updatingLayout.layout.size.height {
                    statusBarHeight = nil
                    self.statusBarHidden = true
                } else {
                    self.statusBarHidden = false
                }
                if self.statusBarHidden != statusBarWasHidden {
                    self.tracingStatusBarsInvalidated = true
                    self.hostView.view.setNeedsLayout()
                }
                self.windowLayout = WindowLayout(size: updatingLayout.layout.size, statusBarHeight: statusBarHeight, inputHeight: updatingLayout.layout.inputHeight, inputMinimized: updatingLayout.layout.inputMinimized)
                
                self._rootController?.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
                self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
            }
        }
    }
    
    public func present(_ controller: ViewController) {
        self.presentationContext.present(controller)
    }
}
