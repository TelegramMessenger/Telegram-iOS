import Foundation
import AsyncDisplayKit

private class WindowRootViewController: UIViewController {
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
}

private struct WindowLayout: Equatable {
    public let size: CGSize
    public let statusBarHeight: CGFloat?
    public let inputHeight: CGFloat?
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
        
        self.layout = WindowLayout(size: size, statusBarHeight: self.layout.statusBarHeight, inputHeight: self.layout.inputHeight)
    }
    
    mutating func update(statusBarHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: statusBarHeight, inputHeight: self.layout.inputHeight)
    }
    
    mutating func update(inputHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: self.layout.statusBarHeight, inputHeight: inputHeight)
    }
}

private let orientationChangeDuration: Double = UIDevice.current().userInterfaceIdiom == .pad ? 0.4 : 0.3
private let statusBarHiddenInLandscape: Bool = UIDevice.current().userInterfaceIdiom == .phone

private func containedLayoutForWindowLayout(_ layout: WindowLayout) -> ContainerViewLayout {
    return ContainerViewLayout(size: layout.size, intrinsicInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight)
}

public class Window: UIWindow {
    private let statusBarManager: StatusBarManager
    private var statusBarChangeObserver: AnyObject?
    private var keyboardFrameChangeObserver: AnyObject?
    
    private var windowLayout: WindowLayout
    private var updatingLayout: UpdatingLayout?
    
    public var isUpdatingOrientationLayout = false
    
    private let presentationContext: PresentationContext
    
    private var tracingStatusBarsInvalidated = false
    
    private var statusBarHidden = false
    
    public convenience init() {
        self.init(frame: UIScreen.main().bounds)
    }
    
    public override init(frame: CGRect) {
        self.statusBarManager = StatusBarManager()
        self.windowLayout = WindowLayout(size: frame.size, statusBarHeight: UIApplication.shared().statusBarFrame.size.height, inputHeight: 0.0)
        self.presentationContext = PresentationContext()
        
        super.init(frame: frame)
        
        self.layer.setInvalidateTracingSublayers { [weak self] in
            self?.invalidateTracingStatusBars()
        }
        
        self.presentationContext.view = self
        self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
        
        super.rootViewController = WindowRootViewController()
        
        self.statusBarChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillChangeStatusBarFrame, object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self {
                let statusBarHeight: CGFloat = max(20.0, (notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue)?.cgRectValue().height ?? 20.0)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
                strongSelf.updateLayout { $0.update(statusBarHeight: statusBarHeight, transition: transition, overrideTransition: false) }
            }
        })
        
        self.keyboardFrameChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                let keyboardFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue() ?? CGRect()
                let keyboardHeight = max(0.0, UIScreen.main().bounds.size.height - keyboardFrame.minY)
                var duration: Double = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                if duration > DBL_EPSILON {
                    duration = 0.5
                }
                var curve: UInt = (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
                
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
        self.setNeedsLayout()
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.presentationContext.hitTest(point, with: event) {
            return result
        }
        return self.viewController?.view.hitTest(point, with: event)
    }
    
    public override var frame: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.frame.size != value.size
            super.frame = value
            
            if sizeUpdated {
                let transition: ContainedViewLayoutTransition
                if self.isRotating() {
                    transition = .animated(duration: orientationChangeDuration, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                self.updateLayout { $0.update(size: value.size, transition: transition, overrideTransition: true) }
            }
        }
    }
    
    public override var bounds: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.bounds.size != value.size
            super.bounds = value
            
            if sizeUpdated {
                let transition: ContainedViewLayoutTransition
                if self.isRotating() {
                    transition = .animated(duration: orientationChangeDuration, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                self.updateLayout { $0.update(size: value.size, transition: transition, overrideTransition: true) }
            }
        }
    }
    
    private var rootController: ContainableController?
    public var viewController: ContainableController? {
        get {
            return rootController
        }
        set(value) {
            if let rootController = self.rootController {
                rootController.view.removeFromSuperview()
            }
            self.rootController = value
            
            if let rootController = self.rootController {
                rootController.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
                
                self.addSubview(rootController.view)
            }
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.tracingStatusBarsInvalidated {
            self.tracingStatusBarsInvalidated = false
            
            if self.statusBarHidden {
                self.statusBarManager.surfaces = []
            } else {
                var statusBarSurfaces: [StatusBarSurface] = []
                for layers in self.layer.traceableLayerSurfaces() {
                    let surface = StatusBarSurface()
                    for layer in layers {
                        if let weakInfo = layer.traceableInfo() as? NSWeakReference {
                            if let statusBar = weakInfo.value as? StatusBar {
                                surface.addStatusBar(statusBar)
                            }
                        }
                    }
                    statusBarSurfaces.append(surface)
                }
                self.layer.adjustTraceableLayerTransforms(CGSize())
                self.statusBarManager.surfaces = statusBarSurfaces
            }
        }
        
        if !Window.isDeviceRotating() {
            if !self.isUpdatingOrientationLayout {
                self.commitUpdatingLayout()
            } else {
                self.addPostUpdateToInterfaceOrientationBlock(f: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.setNeedsLayout()
                    }
                })
            }
        } else {
            Window.addPostDeviceOrientationDidChange({ [weak self] in
                if let strongSelf = self {
                    strongSelf.setNeedsLayout()
                }
            })
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [(Void) -> Void] = []
    
    override public func _update(toInterfaceOrientation arg1: Int32, duration arg2: Double, force arg3: Bool) {
        self.isUpdatingOrientationLayout = true
        super._update(toInterfaceOrientation: arg1, duration: arg2, force: arg3)
        self.isUpdatingOrientationLayout = false
        
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: (Void) -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
    
    private func updateLayout(_ update: @noescape(inout UpdatingLayout) -> ()) {
        if self.updatingLayout == nil {
            self.updatingLayout = UpdatingLayout(layout: self.windowLayout, transition: .immediate)
        }
        update(&self.updatingLayout!)
        self.setNeedsLayout()
    }
    
    private func commitUpdatingLayout() {
        if let updatingLayout = self.updatingLayout {
            self.updatingLayout = nil
            if updatingLayout.layout != self.windowLayout {
                var statusBarHeight = UIApplication.shared().statusBarFrame.size.height
                var statusBarWasHidden = self.statusBarHidden
                if statusBarHiddenInLandscape && updatingLayout.layout.size.width > updatingLayout.layout.size.height {
                    statusBarHeight = 0.0
                    self.statusBarHidden = true
                } else {
                    self.statusBarHidden = false
                }
                if self.statusBarHidden != statusBarWasHidden {
                    self.tracingStatusBarsInvalidated = true
                    self.setNeedsLayout()
                }
                self.windowLayout = WindowLayout(size: updatingLayout.layout.size, statusBarHeight: statusBarHeight, inputHeight: updatingLayout.layout.inputHeight)
                
                self.rootController?.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
                
                self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
            }
        }
    }
    
    func present(_ controller: ViewController) {
        self.presentationContext.present(controller)
    }
}
